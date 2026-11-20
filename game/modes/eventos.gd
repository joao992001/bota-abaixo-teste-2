extends Node2D
## Eventos dinâmicos da Demolição: de tempos em tempos (frequência nos AJUSTES) um evento é anunciado
## 2 s antes (faixa + som) e muda a arena por alguns segundos. Cada evento pode ser ligado/desligado
## na tela ESCOLHER EVENTOS. Números em data/modos.json → demolicao.eventos.
## Robôs leem: gravity_mult, wind, slip. O desenho (caixas, vigas, ventania) fica neste nó, dentro do mundo.

const Kit := preload("res://ui/kit.gd")
var main: Node
var cfg: Dictionary
var enabled := {}            # id -> bool
var timer := 0.0
var current := {}            # evento ativo (ou anunciado)
var phase := ""              # "", "aviso", "ativo"
var phase_t := 0.0
var gravity_mult := 1.0
var wind := 0.0
var slip := 1.0
var falling: Array = []      # caixas/vigas caindo: {kind, pos, vy}
var marks: Array = []        # colunas marcadas para viga: {col, t}
var spawn_t := 0.0
var spawned := 0             # quantas coisas o evento soltou (testes)
var dark: CanvasModulate = null
var lights: Array = []
var menu_sel := 0

func setup(m: Node) -> void:
	main = m
	cfg = Data.read_json("data/modos.json")["demolicao"]["eventos"]
	for e in cfg["lista"]:
		enabled[e["id"]] = true

func reset_round() -> void:
	_end_event()
	falling.clear()
	marks.clear()
	var lvl: int = main.event_level
	timer = float(cfg["primeiro_s"][lvl])
	phase = ""

func update(dt: float) -> void:
	queue_redraw()
	if main.event_level <= 0 or main.state != main.S.RUN or main.countdown > 0.0:
		return
	_update_falling(dt)
	match phase:
		"":
			timer -= dt
			if timer <= 0.0:
				var pool: Array = cfg["lista"].filter(func(e): return enabled.get(e["id"], true))
				if pool.is_empty():
					timer = 999.0
					return
				current = pool[main.rng.randi() % pool.size()]
				phase = "aviso"
				phase_t = float(cfg["aviso_s"])
				main.demo.banner = "EVENTO: %s!" % String(current["nome"]).to_upper()
				main.demo.banner_t = 2.0
				Audio.play("evento")
		"aviso":
			phase_t -= dt
			if phase_t <= 0.0:
				phase = "ativo"
				phase_t = float(current["dur"])
				_start_event()
		"ativo":
			phase_t -= dt
			_tick_event(dt)
			if phase_t <= 0.0:
				_end_event()
				Audio.play("evento_fim", 1.0, -4.0)
				phase = ""
				timer = float(cfg["intervalo_s"][main.event_level]) * main.rng.randf_range(0.8, 1.2)

func active_name() -> String:
	return String(current.get("nome", "")) if phase == "ativo" else ""

func _start_event() -> void:
	match current["id"]:
		"gravidade": gravity_mult = float(current["mult"])
		"ventania": wind = float(current["forca"]) * (1.0 if main.rng.randf() < 0.5 else -1.0)
		"sabao": slip = float(current["atrito"])
		"martelao":
			for r in main.robots:
				if r.alive:
					r.fx_t["martelao"] = float(current["dur"])
			Audio.play("martelao")
		"apagao": _lights_on()
		"tremores": Audio.play("terremoto")
	spawn_t = 0.0
	spawned = 0

func _end_event() -> void:
	gravity_mult = 1.0
	wind = 0.0
	slip = 1.0
	if dark != null and is_instance_valid(dark):
		dark.queue_free()
		for l in lights:
			if is_instance_valid(l):
				l.queue_free()
		lights.clear()
		dark = null
		main.bg.modulate = Color(main.level.prop("fundo", "#ffffff")) if main.level.prop("fundo", "") != "" else Color.WHITE
	current = {} if phase != "aviso" else current

func _tick_event(dt: float) -> void:
	spawn_t -= dt
	var lv = main.level
	match current["id"]:
		"caixas":
			if spawn_t <= 0.0:
				spawn_t = 0.35
				var pr: Rect2 = main.demo.play_rect()
				var col: int = main.rng.randi_range(int(pr.position.x / 64.0) + 1, int(pr.end.x / 64.0) - 2)
				falling.append({"kind": "caixa", "pos": Vector2(col * 64 + 32, pr.position.y - 60), "vy": 0.0})
		"dinamite":
			if spawn_t <= 0.0:
				spawn_t = 0.55
				var pr: Rect2 = main.demo.play_rect()
				var x: float = main.rng.randf_range(pr.position.x + 100, pr.end.x - 100)
				spawned += 1
				main.demo.dynamites.append({"pos": Vector2(x, pr.position.y - 40), "vel": Vector2(main.rng.randf_range(-60, 60), 80), "t": 0.0, "owner": -1})
		"tremores":
			if spawn_t <= 0.0 and lv.blocks.size() > 0:
				spawn_t = 0.45
				var keys: Array = lv.blocks.keys().filter(func(k): return lv.blocks[k]["warn"] <= 0.0)
				if keys.size() > 0:
					lv.blocks[keys[main.rng.randi() % keys.size()]]["warn"] = 0.8
					main.shake(2.0)
		"vigas":
			if spawn_t <= 0.0:
				spawn_t = 1.1
				var pr: Rect2 = main.demo.play_rect()
				marks.append({"col": main.rng.randi_range(int(pr.position.x / 64.0) + 1, int(pr.end.x / 64.0) - 3), "t": 1.2, "y": pr.position.y})
	for m in marks:
		m["t"] -= dt
		if m["t"] <= 0.0:
			falling.append({"kind": "viga", "pos": Vector2(m["col"] * 64 + 64, float(m.get("y", 0.0)) - 80.0), "vy": 400.0})
			Audio.play("pistao_aviso", 0.8, -6.0)
	marks = marks.filter(func(m): return m["t"] > 0.0)
	for l in lights:
		if is_instance_valid(l) and is_instance_valid(l.get_meta("robot")):
			l.global_position = l.get_meta("robot").global_position + Vector2(0, -40)

## Caixas e vigas caindo: acertam robôs (Amassômetro), caixas viram chão, vigas quebram o que pegam.
func _update_falling(dt: float) -> void:
	var lv = main.level
	for f in falling:
		f["vy"] = minf(f["vy"] + 1800.0 * dt, 1100.0)
		f["pos"].y += f["vy"] * dt
		var p: Vector2 = f["pos"]
		var half := Vector2(30, 30) if f["kind"] == "caixa" else Vector2(64, 22)
		var box := Rect2(p - half, half * 2.0)
		for r in main.robots:
			if r.alive and r.rect().intersects(box) and r.invuln <= 0.0 and r.stun_t <= 0.0:
				r.take_hit(1 if r.position.x >= p.x else -1, f["kind"], -1)
				main.spark(r.rect().get_center(), 5)
				Audio.play("bonk", 0.8)
		var cell := Vector2i(int(p.x / 64.0), int(floor((p.y + half.y) / 64.0)))
		if f["kind"] == "caixa":
			if cell.y >= 1 and lv.is_solid(cell) and p.y + half.y >= cell.y * 64.0:
				lv.add_block(cell + Vector2i.UP)
				main.dust(Vector2(cell.x * 64 + 32, cell.y * 64), 0.8)
				Audio.play("caixote_pancada", 0.8)
				f["pos"].y = 99999.0
		else:
			for dx in [-1, 0]:
				var bc := Vector2i(int(p.x / 64.0) + dx, int(floor((p.y + half.y) / 64.0)))
				if lv.blocks.has(bc):
					main.demo.break_reason = "viga"
					lv.break_block(bc)
					main.demo.break_reason = ""
					main.shake(3.0)
	falling = falling.filter(func(f): return f["pos"].y < lv.rows * 64 + 100)

func _lights_on() -> void:
	dark = CanvasModulate.new()
	dark.color = Color(0.13, 0.13, 0.24)
	main.add_child(dark)
	main.bg.modulate = Color(0.25, 0.25, 0.4)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	for r in main.robots:
		var l := PointLight2D.new()
		l.texture = tex
		l.texture_scale = 2.6
		l.energy = 1.4
		l.color = Color(1.0, 0.95, 0.8)
		l.set_meta("robot", r)
		main.world.add_child(l)
		lights.append(l)

func _draw() -> void:
	var lv = main.level
	# colunas marcadas (viga vai cair)
	for m in marks:
		var x: float = m["col"] * 64.0
		var a := 0.25 + 0.25 * sin(Time.get_ticks_msec() / 60.0)
		draw_rect(Rect2(x, 0, 128, lv.rows * 64), Color(0.83, 0.13, 0.21, a * 0.35))
		draw_rect(Rect2(x, 0, 128, 10), Color("#d42035"))
	for f in falling:
		var p: Vector2 = f["pos"]
		if f["kind"] == "caixa":
			draw_texture_rect(Data.tex("cenario/caixote_1"), Rect2(p - Vector2(32, 32), Vector2(64, 64)), false)
		else:
			draw_texture_rect(Data.tex("cenario/plataforma_aco"), Rect2(p - Vector2(64, 20), Vector2(128, 40)), false)
	# ventania: riscos de vento
	if wind != 0.0:
		var tt := Time.get_ticks_msec() / 1000.0
		for k in 26:
			var pr: Rect2 = main.demo.play_rect()
			var y := pr.position.y + fposmod(k * 137.0, pr.size.y)
			var x := pr.position.x + fposmod(k * 311.0 + tt * wind * 3.0, pr.size.x + 200.0) - 100.0
			draw_line(Vector2(x, y), Vector2(x - signf(wind) * 70.0, y), Color(1, 1, 1, 0.55), 3.0, true)

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
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
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
			ci.draw_rect(Rect2(r.position.x + 60, y - 28, 40, 40), Color("#1f3a40"), false, 4.0)
			if en:
				ci.draw_polyline(PackedVector2Array([Vector2(r.position.x + 66, y - 8), Vector2(r.position.x + 78, y + 6), Vector2(r.position.x + 98, y - 26)]), Color("#3c9a46"), 6.0, true)
			Kit.text(ci, Vector2(r.position.x + 130, y), String(e["nome"]).to_upper(), 34, Color("#1f3a40") if en else Color("#9aa4ae"))
			Kit.text(ci, Vector2(r.position.x + 600, y), e["dica"], 24, Color("#4a5a60") if en else Color("#b0b8bf"))
		else:
			Kit.text(ci, Vector2(r.position.x, y), "VOLTAR  ▸", 36, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  PULAR liga/desliga  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)
