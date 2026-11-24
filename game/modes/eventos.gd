extends Node2D
## EVENTOS GLOBAIS (Relatório 04): cada evento tem AVISO (com o lugar marcado) → ATIVO → TÉRMINO/restauração.
## Intensidade nos AJUSTES: 0 desligados, 1 baixa, 2 normal, 3 alta (muda o ritmo). Cada evento pode ser
## desligado na tela ESCOLHER EVENTOS. Números em data/modos.json → demolicao.eventos.
## Etapa 1: G01 Sirene de Demolição (o ciclo da obra do Canteiro) e G10 Carga Especial Chegando.
## Robôs ainda leem wind e gravity_mult (ficam neutros até os eventos que os usam).

const Kit := preload("res://ui/kit.gd")
var main: Node
var cfg: Dictionary
var enabled := {}            # id -> bool
var timer := 0.0
var current := {}            # evento anunciado/ativo
var phase := ""              # "", "aviso", "ativo"
var phase_t := 0.0
var gravity_mult := 1.0
var wind := 0.0
var manual := false          # Laboratório: só dispara pelo painel
var menu_sel := 0
var spots: Array = []        # G10: os 2 pontos anunciados (holofotes)
var fired: Array = []        # ids disparados (testes)
var t := 0.0

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["demolicao"]["eventos"]
	for e in cfg["lista"]:
		enabled[e["id"]] = true

func reset_round() -> void:
	_end_event()
	phase = ""
	var lvl: int = main.event_level
	timer = float(cfg["primeiro_s"][lvl]) * main.rng.randf_range(0.85, 1.15)

func _canteiro():
	if main.demo == null:
		return null
	var ct = main.demo.canteiro
	return ct if ct != null and is_instance_valid(ct) else null

## Evento pode rodar nesta arena agora? (G01 só existe com estrutura destrutível; G10 precisa de 2 pontos.)
func eligible(e: Dictionary) -> bool:
	if not enabled.get(e["id"], true):
		return false
	match e["id"]:
		"G01":
			return _canteiro() != null and _canteiro().can_alert()
		"G10":
			return main.demo != null and main.demo.spells != null and (main.demo.items_on or manual) and main.demo.spells.spawn_points().size() >= 2
	return false

func update(dt: float) -> void:
	t += dt
	queue_redraw()
	if main.event_level <= 0 or main.state != main.S.RUN or main.countdown > 0.0:
		return
	match phase:
		"":
			if manual:
				return
			timer -= dt
			if timer <= 0.0:
				var pool: Array = cfg["lista"].filter(func(e): return eligible(e))
				if pool.is_empty():
					timer = 3.0
					return
				# não repete o mesmo evento seguido se houver outro
				var other := pool.filter(func(e): return fired.is_empty() or e["id"] != fired[-1])
				var e: Dictionary = (other if not other.is_empty() else pool)[main.rng.randi() % (other if not other.is_empty() else pool).size()]
				_announce(e, float(e["aviso_s"]))
		"aviso":
			phase_t -= dt
			if phase_t <= 0.0:
				phase = "ativo"
				phase_t = float(current["dur"])
				_start_event()
		"ativo":
			phase_t -= dt
			if current["id"] == "G01":
				var ct = _canteiro()
				if ct == null or ct.cycle_state == "calma":
					phase_t = 0.0   # a laje cedeu (ou a arena sumiu): termina já
			if phase_t <= 0.0:
				_end_event()
				Audio.play("evento_fim", 1.0, -4.0)
				phase = ""
				timer = float(cfg["intervalo_s"][main.event_level]) * main.rng.randf_range(0.8, 1.2)

## Anúncio: faixa + som + o LUGAR marcado (G01: fita zebrada no trecho; G10: dois holofotes).
func _announce(e: Dictionary, aviso: float) -> void:
	current = e
	phase = "aviso"
	phase_t = aviso
	fired.append(e["id"])
	main.demo.banner = String(e["nome"]).to_upper() + "!"
	main.demo.banner_t = 2.0
	Audio.play("evento")
	match e["id"]:
		"G01":
			# a sirene e a fita começam já no aviso; o colapso acontece no fim do aviso do Canteiro
			_canteiro().start_alert(aviso + float(e["dur"]) * 0.5)
		"G10":
			spots = _pick_spots()

## Dispara um evento agora (painel do Laboratório): aviso curto e depois ativo.
func trigger(e: Dictionary) -> void:
	_end_event()
	if not eligible(e):
		Audio.play("menu_negado")
		return
	_announce(e, 0.8)

func active_name() -> String:
	return String(current.get("nome", "")) if phase == "ativo" else ""

func _pick_spots() -> Array:
	var pts: Array = main.demo.spells.spawn_points()
	pts.shuffle()
	var a: Vector2 = pts[0]["pos"]
	var b: Vector2 = pts[1]["pos"]
	for q in pts:   # o segundo o mais longe possível do primeiro (disputa dos dois lados)
		if q["pos"].distance_to(a) > b.distance_to(a):
			b = q["pos"]
	return [a, b]

func _start_event() -> void:
	match current["id"]:
		"G10":
			var sp = main.demo.spells
			for p in spots:
				sp.spawn_box(p, true)
			Audio.play("elevador", 1.2, -4.0)

func _end_event() -> void:
	gravity_mult = 1.0
	wind = 0.0
	spots.clear()
	current = {}

# ---------------------------------------------------------------- desenho
func _draw() -> void:
	if phase == "" or current.is_empty():
		return
	if current["id"] == "G10" and phase == "aviso":
		# holofotes varrendo e pousando nos dois pontos anunciados
		var k := 1.0 - clampf(phase_t / float(current["aviso_s"]), 0.0, 1.0)
		for i in spots.size():
			var p: Vector2 = spots[i]
			var top := Vector2(p.x + (1.0 - k) * (240.0 if i == 0 else -240.0) * sin(t * 2.0), p.y - 900.0)
			var w := 70.0
			var beam := PackedVector2Array([top + Vector2(-14, 0), top + Vector2(14, 0), p + Vector2(w, 0), p + Vector2(-w, 0)])
			draw_colored_polygon(beam, Color(1.0, 0.95, 0.7, 0.16 + 0.08 * sin(t * 10.0)))
			draw_set_transform(p + Vector2(0, -4), 0.0, Vector2(1.0, 0.28))
			draw_circle(Vector2.ZERO, w, Color(1.0, 0.95, 0.7, 0.35))
			draw_set_transform(Vector2.ZERO)
			# seta quicando sobre o ponto
			var ay := p.y - 120.0 - absf(sin(t * 6.0)) * 18.0
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 22, ay - 26), Vector2(p.x + 22, ay - 26), Vector2(p.x, ay)]), Color("#f2c84b"))
			draw_polyline(PackedVector2Array([Vector2(p.x - 22, ay - 26), Vector2(p.x + 22, ay - 26), Vector2(p.x, ay), Vector2(p.x - 22, ay - 26)]), Color("#2a1a2e"), 4.0, true)

# ---------------------------------------------------------------- tela ESCOLHER EVENTOS
func menu_update(m: Node) -> void:
	var n: int = cfg["lista"].size() + 1
	menu_sel = posmod(menu_sel + m.move_v(), n)
	if m.confirm() or m.move_h() != 0:
		if menu_sel < n - 1:
			var id: String = cfg["lista"][menu_sel]["id"]
			enabled[id] = not enabled.get(id, true)
		elif m.confirm():
			main.state = main.S.AJUSTES
	if m.pressed("back"):
		main.state = main.S.AJUSTES

func menu_draw(ci: CanvasItem, m: Node) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.16, 0.1, 0.18, 0.45))
	Kit.ribbon(ci, Rect2(560, 20, 800, 128), "ESCOLHER EVENTOS", 54)
	var list: Array = cfg["lista"]
	var r := Rect2(360, 170, 1200, 840)
	Kit.paper(ci, r)
	for i in list.size() + 1:
		var y := r.position.y + 50 + i * 78
		var on := i == menu_sel
		if on:
			ci.draw_rect(Rect2(r.position.x + 30, y - 40, r.size.x - 60, 70), Color(0.95, 0.78, 0.29, 0.5))
		if i < list.size():
			var e: Dictionary = list[i]
			var en: bool = enabled.get(e["id"], true)
			ci.draw_rect(Rect2(r.position.x + 60, y - 28, 40, 40), Color("#2a1a2e"), false, 4.0)
			if en:
				ci.draw_polyline(PackedVector2Array([Vector2(r.position.x + 66, y - 8), Vector2(r.position.x + 78, y + 6), Vector2(r.position.x + 98, y - 26)]), Color("#3c9a46"), 6.0, true)
			Kit.text(ci, Vector2(r.position.x + 130, y), String(e["nome"]).to_upper(), 34, Color("#2a1a2e") if en else Color("#9aa4ae"))
			Kit.text(ci, Vector2(r.position.x + 640, y), e["dica"], 24, Color("#6b5a70") if en else Color("#b0b8bf"))
		else:
			Kit.text(ci, Vector2(r.position.x, y), "VOLTAR  ▸", 36, Color("#2a1a2e"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  PULAR liga/desliga  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)
