extends Node2D
## FASE EM ETAPAS (cartilha do mapa, docs/manuais/derruba/mapa_cartilha.md): a virada é o ÚNICO momento de roteiro,
## cronometrada e sempre igual. Etapa 1 → AVISO ("A OBRA VAI CEDER!", tudo treme com fita) → DESABA (a estrutura toda
## cai em pedaços) → QUEDA (ninguém é eliminado; um funil leva todos para o buraco do teto da etapa 2; gravidade mais leve)
## → ETAPA 2 (câmera, KO e área de jogo passam para a etapa 2; nascimentos 5–8).
## Números: data/modos.json → demolicao.etapas. Área de cada etapa no .lvl: "etapa1:" / "etapa2:" (col,linha,larg,alt)
## e o buraco por onde se cai: "buraco: col0,col1".

var main: Node
var cfg: Dictionary
var etapa := 1
var state := "etapa"          # etapa · aviso · queda
var t := 0.0                  # tempo de rodada contado para a virada
var st_t := 0.0
var hole := Vector2.ZERO      # faixa x (px) do buraco do teto da etapa 2

func setup(m: Node) -> void:
	main = m
	cfg = m.demo.cfg["etapas"]
	var h := String(m.level.prop("buraco", "")).split(",")
	if h.size() >= 2:
		hole = Vector2(float(h[0]) * 64.0, float(h[1]) * 64.0)
	else:
		var a2: Rect2 = m.level.etapa_rect(2)
		hole = Vector2(a2.position.x, a2.end.x)

func virada_s() -> float:
	return float(cfg["virada_s"])

func update(dt: float) -> void:
	if main.state != main.S.RUN or main.countdown > 0.0:
		return
	var lv = main.level
	var ct = main.demo.canteiro
	match state:
		"etapa":
			if etapa != 1:
				return
			t += dt
			if t >= virada_s() - float(cfg["aviso_s"]):
				state = "aviso"
				st_t = float(cfg["aviso_s"])
				main.demo.banner = "A OBRA VAI CEDER!"
				main.demo.banner_t = st_t
				Audio.play("alarme", 0.8, 0.0)
				if ct != null and is_instance_valid(ct):
					ct.warn_all(st_t)
		"aviso":
			st_t -= dt
			main.shake(1.5 + 4.0 * (1.0 - st_t / float(cfg["aviso_s"])))
			if fmod(st_t, 0.6) < dt:
				Audio.play("pistao_aviso", 0.7, -4.0)
			if st_t <= 0.0:
				_desaba()
		"queda":
			st_t += dt
			main.events.gravity_mult *= float(cfg["gravidade_queda"])
			var a2: Rect2 = lv.etapa_rect(2)
			var landed := true
			for r in main.robots:
				if not r.alive:
					continue
				r.invuln = maxf(r.invuln, 0.5)
				r.velocity.y = minf(r.velocity.y, float(cfg["queda_vmax"]))   # queda lenta e legível (cena)
				# arco natural: a velocidade de lado calculada no desabamento leva cada um para dentro do buraco
				if r.position.y < a2.position.y + 120.0:
					var vx: float = r.get_meta("queda_vx", 0.0)
					var tx := clampf(r.position.x, hole.x + 60.0, hole.y - 60.0)
					if absf(tx - r.position.x) > 1.0 and r.position.y > a2.position.y - 220.0:
						vx = clampf((tx - r.position.x) * 4.0, -float(cfg["funil_vel"]), float(cfg["funil_vel"]))   # correção final suave
					r.push_vx = vx
				if not (r.is_on_floor() and a2.has_point(r.position)):
					landed = false
			if (landed and st_t > 0.5) or st_t >= float(cfg["queda_max_s"]):
				_chega()

## A estrutura inteira desaba: começa a queda.
func _desaba() -> void:
	var lv = main.level
	state = "queda"
	st_t = 0.0
	var ct = main.demo.canteiro
	if ct != null and is_instance_valid(ct):
		ct.collapse_all()
	main.events.stop_all()
	lv.ko_off = true
	lv.area = lv.etapa_rect(1).merge(lv.etapa_rect(2))
	main.shake(18.0)
	Audio.play("terremoto", 1.0, 2.0)
	Audio.play("explosao", 0.6, -2.0)
	var a2: Rect2 = lv.etapa_rect(2)
	var g: float = float(Data.ctrl["gravity"]) * float(cfg["gravidade_queda"])
	var vivos: Array = main.robots.filter(func(r): return r.alive)
	for i in vivos.size():
		var r = vivos[i]
		r.hanging = false
		r.invuln = maxf(r.invuln, 1.0)
		r.spell_lock = true   # sem controle durante a queda (cena)
		# cada um cai num ponto diferente do buraco, no tempo que leva para chegar ao teto
		var tx: float = lerpf(hole.x + 140.0, hole.y - 140.0, (i + 0.5) / maxf(vivos.size(), 1.0))
		if absf(r.position.x - tx) < 200.0:
			tx = clampf(r.position.x, hole.x + 100.0, hole.y - 100.0)
		tx = _over_floor(tx, a2)   # cai sempre em cima de piso (nunca num vão)
		var dy: float = maxf(a2.position.y - r.position.y, 120.0)
		var vm := float(cfg["queda_vmax"])
		var d1 := vm * vm / (2.0 * maxf(g, 1.0))   # acelera até a velocidade limite e depois cai constante
		var tf := sqrt(2.0 * dy / maxf(g, 1.0)) if dy <= d1 else vm / maxf(g, 1.0) + (dy - d1) / vm
		r.set_meta("queda_vx", clampf((tx - r.position.x) / tf, -float(cfg["funil_vel"]), float(cfg["funil_vel"])))
		r.velocity.y = minf(r.velocity.y, -180.0)   # pulinho de susto antes de cair
	var mc = main.demo.mecs
	if mc != null and is_instance_valid(mc):
		mc.desaba(1)
	var sp = main.demo.spells
	if sp != null and is_instance_valid(sp):
		for r in vivos:   # voo (jetpack) e transformações acabam: ninguém escapa da queda
			var sid: String = sp.flags(r).get("spell", "")
			if sid in ["S16", "S13", "S14", "S15", "S31", "S33", "S34"]:
				sp.clear(r)
		for b in sp.boxes:   # caixas do Térreo caem pelo buraco (nunca em cima do teto da Fundação)
			b["pos"].x = _over_floor(clampf(b["pos"].x, hole.x + 80.0, hole.y - 80.0), a2)
			b["vy"] = 0.0

## x mais perto de tx que tem piso embaixo na etapa 2 (os vãos entre as lajes são KO).
func _over_floor(tx: float, a2: Rect2) -> float:
	var lv = main.level
	for k in 24:
		for sg in [1, -1]:
			var x: float = tx + sg * k * 32.0
			var c := int(floor(x / 64.0))
			for row in range(int(a2.position.y / 64.0) + 4, int(a2.end.y / 64.0)):
				if lv.is_solid(Vector2i(c, row)) and lv.is_solid(Vector2i(c - 1, row)) and lv.is_solid(Vector2i(c + 1, row)):
					return x
	return tx

## Todos pousaram na etapa 2: câmera, KO e área de jogo passam para ela.
func _chega() -> void:
	var lv = main.level
	state = "etapa"
	etapa = 2
	lv.etapa_n = 2
	lv.area = lv.etapa_rect(2)
	lv.ko_off = false
	main.demo.banner = String(lv.prop("etapa2_nome", "ETAPA 2")).to_upper() + "!"
	main.demo.banner_t = 2.0
	main.shake(10.0)
	Audio.play("caixote_quebra", 0.6, 0.0)
	for r in main.robots:
		r.spell_lock = false
		if r.has_meta("queda_vx"):
			r.remove_meta("queda_vx")
		if r.alive:
			r.invuln = maxf(r.invuln, float(cfg["invuln_chegada_s"]))
			main.dust(r.position, 1.2)
			if not lv.area.grow(64).has_point(r.position) or r.position.y < lv.area.position.y + 140.0:   # ficou fora ou em cima do teto: nasce embaixo
				main.demo.respawn(r)

## Nascimento na etapa atual (spawns 1–4 na etapa 1, 5–8 na etapa 2).
func spawn_index(i: int) -> int:
	return i + (4 if etapa == 2 else 0)
