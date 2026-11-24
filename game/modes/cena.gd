extends Node2D
## CENA VIVA da fase (cartilha do mapa, camadas C0–C4): camadas paradas (PNG exportados da prancha aprovada por
## art/src/cenarios/fase1_jogo.py) com paralaxe + tudo o que mexe animado aqui. Fica ATRÁS do mapa; a camada da frente
## (C4) é o nó `front` (na frente dos robôs, discreta). Uma cena por fase: prop "cena: fase1" no .lvl.
## Etapa 1 (Térreo): céu, nuvens andando, pássaros, cidade, grua com carrinho e balde balançando, prédio com solda piscando,
## operários andando (se assustam quando a obra treme), névoa no vão. Etapa 2 (Fundação): fundo escuro com o buraco,
## feixes de luz com poeira, lanternas nas galerias, ratinhos, palco desenhado sobre os tiles, lâmpadas e gotas na frente.

var main: Node
var key := "fase1"
var a1 := Rect2()
var a2 := Rect2()
var t := 0.0
var tex := {}
var clouds: Array = []     # {x, y, s, v, small}
var birds: Array = []      # {x, y, v, ph}
var walkers: Array = []    # {tex, x, x0, x1, y, v, s, jump}
var motes: Array = []      # poeira nos feixes {x, y, v, ph}
var rats: Array = []       # {x, v, x0, x1}
var miners: Array = []     # {x, x0, x1, y, v}
var front: Node2D
var _rng := RandomNumberGenerator.new()

func setup(m: Node) -> void:
	main = m
	key = String(m.level.prop("cena", "fase1"))
	a1 = m.level.etapa_rect(1)
	a2 = m.level.etapa_rect(2)
	for n in ["e1_longe", "e1_perto", "e1_frente", "e2_fundo", "e2_palco", "nuvem", "nuvem_p", "balde",
			"carrinho_grua", "npc_tabua", "npc_carrinho", "npc", "npc_lanterna"]:
		tex[n] = Data.tex("%s/%s" % [key, n])
	_rng.seed = 77
	for i in 6:
		clouds.append({"x": _rng.randf_range(0, a1.size.x), "y": _rng.randf_range(60, 420), "s": _rng.randf_range(0.7, 1.2),
			"v": _rng.randf_range(8, 22), "small": i % 2 == 1})
	for i in 5:
		birds.append({"x": _rng.randf_range(0, a1.size.x), "y": _rng.randf_range(220, 420), "v": _rng.randf_range(50, 90), "ph": _rng.randf() * TAU})
	# operários nos andares do prédio (y do andar na camada) e no topo da laje lá atrás
	for w in [["npc_tabua", 1400, 1700, 480, 0.55], ["npc", 1300, 1900, 720, 0.55], ["npc_carrinho", 1380, 1880, 840, 0.55], ["npc_tabua", 40, 420, 1088, 0.5]]:
		walkers.append({"tex": w[0], "x": _rng.randf_range(w[1], w[2]), "x0": w[1], "x1": w[2], "y": w[3], "v": _rng.randf_range(40, 70) * (1 if _rng.randf() < 0.5 else -1), "s": w[4], "jump": 0.0})
	for i in 50:
		motes.append({"x": _rng.randf_range(560, 2000), "y": _rng.randf_range(140, 960), "v": _rng.randf_range(8, 24), "ph": _rng.randf() * TAU})
	rats = [{"x": 500.0, "v": 160.0, "x0": 220.0, "x1": 1100.0}, {"x": 2000.0, "v": -140.0, "x0": 1500.0, "x1": 2330.0}]
	miners = [{"x": 330.0, "x0": 320.0, "x1": 540.0, "y": 930.0, "v": 26.0}, {"x": 2100.0, "x0": 2010.0, "x1": 2230.0, "y": 930.0, "v": -22.0}]
	front = Node2D.new()
	front.z_index = 3
	front.draw.connect(_draw_front)
	add_child(front)

func _process(dt: float) -> void:
	if main == null or main.paused:
		return
	t += dt
	for c in clouds:
		c["x"] = fposmod(c["x"] + c["v"] * dt, a1.size.x + 400.0)
	for b in birds:
		b["x"] = fposmod(b["x"] + b["v"] * dt, a1.size.x + 200.0)
	var scared: bool = main.shake_amt > 6.0
	for w in walkers:
		if scared and w["jump"] <= 0.0:
			w["jump"] = 0.5   # tremeu a obra: o operário pula de susto
		w["jump"] = maxf(w["jump"] - dt, 0.0)
		if w["jump"] <= 0.0:
			w["x"] += w["v"] * dt
			if w["x"] < w["x0"] or w["x"] > w["x1"]:
				w["v"] = -w["v"]
				w["x"] = clampf(w["x"], w["x0"], w["x1"])
	for m in motes:
		m["y"] += m["v"] * dt
		if m["y"] > 960.0:
			m["y"] = 140.0
	for r in rats:
		r["x"] += r["v"] * dt
		if r["x"] < r["x0"] or r["x"] > r["x1"]:
			r["v"] = -r["v"]
	for m in miners:
		m["x"] += m["v"] * dt
		if m["x"] < m["x0"] or m["x"] > m["x1"]:
			m["v"] = -m["v"]
	queue_redraw()
	front.queue_redraw()

## Deslocamento de paralaxe da camada (f = quanto a camada acompanha a câmera: 0 = presa ao mundo).
func _par(area: Rect2, f: float) -> Vector2:
	return (main.cam_center - area.get_center()) * f

func _layer(name: String, area: Rect2, f: float, grow := 0.0) -> void:
	var tx: Texture2D = tex.get(name)
	if tx == null:
		return
	var r := area.grow_individual(area.size.x * grow, area.size.y * grow, area.size.x * grow, area.size.y * grow)
	r.position += _par(area, f)
	draw_texture_rect(tx, r, false)

## Ponto da camada (coordenadas do PNG) → mundo, com a mesma paralaxe/escala da camada.
func _lp(area: Rect2, f: float, grow: float, p: Vector2) -> Vector2:
	var k := 1.0 + 2.0 * grow
	return area.position - area.size * grow + p * k + _par(area, f)

func _view() -> Rect2:
	return main.view_rect().grow(200)

func _draw() -> void:
	var v := _view()
	if v.intersects(a1):
		_draw_e1()
	# terra entre as etapas (aparece durante a queda)
	var gap := Rect2(a1.position.x - 600, a1.end.y - 40, a1.size.x + 1200, a2.position.y - a1.end.y + 80)
	if v.intersects(gap):
		draw_rect(gap, Color("#6b5a48"))
		for k in 30:
			var px := gap.position.x + fmod(k * 197.0, gap.size.x)
			var py := gap.position.y + fmod(k * 61.0, gap.size.y)
			draw_circle(Vector2(px, py), 6.0 + fmod(k * 3.7, 10.0), Color("#5a4a3a"))
	if v.intersects(a2):
		_draw_e2()

func _draw_e1() -> void:
	_layer("e1_longe", a1, 0.3, 0.06)
	for c in clouds:
		var p := _lp(a1, 0.3, 0.06, Vector2(c["x"] - 200.0, c["y"]))
		var tx: Texture2D = tex["nuvem_p" if c["small"] else "nuvem"]
		var sz := Vector2(tx.get_width(), tx.get_height()) / 2.0 * float(c["s"])
		draw_texture_rect(tx, Rect2(p, sz), false)
	for b in birds:
		var p := _lp(a1, 0.3, 0.06, Vector2(b["x"] - 100.0, b["y"]))
		var fl := sin(t * 9.0 + b["ph"]) * 6.0
		draw_polyline(PackedVector2Array([p + Vector2(-10, 0), p + Vector2(-4, -fl), p, p + Vector2(4, -fl), p + Vector2(10, 0)]), Color("#5a7a86"), 3.0, true)
	_layer("e1_perto", a1, 0.12, 0.04)
	for sp in [Vector2(1560, 590), Vector2(1820, 830), Vector2(1480, 950)]:   # solda piscando (pulsos irregulares)
		var on := fmod(t * 3.0 + sp.x * 0.01, 1.7) < 0.5
		if on:
			var p := _lp(a1, 0.12, 0.04, sp)
			draw_circle(p, 22.0, Color(1.0, 0.96, 0.78, 0.45))
			draw_circle(p, 6.0 + 2.0 * sin(t * 40.0), Color.WHITE)
	for w in walkers:
		var tx: Texture2D = tex[w["tex"]]
		var hop: float = -sin(w["jump"] / 0.5 * PI) * 30.0 if w["jump"] > 0.0 else -absf(sin(t * 8.0 + w["x"])) * 3.0
		var p := _lp(a1, 0.12, 0.04, Vector2(w["x"], w["y"] + hop))
		var sz := Vector2(tx.get_width(), tx.get_height()) / 2.0 * float(w["s"])
		draw_set_transform(p, 0.0, Vector2(-1.0 if w["v"] < 0.0 else 1.0, 1.0))
		draw_texture_rect(tx, Rect2(Vector2(-sz.x * 0.4, -sz.y), sz), false)
		draw_set_transform(Vector2.ZERO)
	# carrinho correndo na lança + cabo + balde balançando
	var tx_ := 900.0 + sin(t * 0.18) * 520.0
	var pc := _lp(a1, 0.12, 0.04, Vector2(tx_, 172))
	var cable := 220.0 + sin(t * 0.4) * 60.0
	var sw := sin(t * 1.3) * 0.08
	var pb := pc + Vector2(sin(sw), cos(sw)) * cable
	draw_texture_rect(tex["carrinho_grua"], Rect2(pc - Vector2(35, 15), Vector2(70, 30)), false)
	draw_line(pc, pb, Color("#3a3a46"), 3.0, true)
	draw_set_transform(pb, sw, Vector2.ONE)
	draw_texture_rect(tex["balde"], Rect2(-45, -8, 90, 90), false)
	draw_set_transform(Vector2.ZERO)
	# névoa no vão (abaixo da laje): profundidade e o vazio do KO
	var ny := a1.position.y + 15.0 * 64.0
	for k in 6:
		draw_rect(Rect2(a1.position.x - 400, ny + k * 70, a1.size.x + 800, 70), Color(0.89, 0.93, 0.92, 0.1 + 0.1 * k))

func _draw_e2() -> void:
	_layer("e2_fundo", a2, 0.15, 0.05)
	# lanternas dos mineradores nas galerias e ratinhos
	for m in miners:
		var p := _lp(a2, 0.15, 0.05, Vector2(m["x"], m["y"]))
		var tx: Texture2D = tex["npc_lanterna"]
		var sz := Vector2(tx.get_width(), tx.get_height()) / 2.0 * 0.45
		draw_set_transform(p, 0.0, Vector2(-1.0 if m["v"] < 0.0 else 1.0, 1.0))
		draw_texture_rect(tx, Rect2(Vector2(-sz.x * 0.2, -sz.y), sz), false)
		draw_set_transform(Vector2.ZERO)
	# feixes de luz pelo buraco (tremulam) com poeira
	var hx0 := float(main.level.prop("buraco", "10,30").split(",")[0]) * 64.0
	for k in 5:
		var x := hx0 + 80.0 + k * 150.0
		var a := 0.07 + 0.03 * sin(t * 1.7 + k)
		var top := a2.position.y + 120.0
		var bot := a2.position.y + 15.0 * 64.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + 60, top), Vector2(x - 140 + k * 40, bot), Vector2(x - 240 + k * 40, bot)]), Color(1.0, 0.95, 0.77, a))
	for m in motes:
		var p := a2.position + Vector2(m["x"] + sin(t + m["ph"]) * 10.0, m["y"])
		draw_circle(p, 2.5, Color(1.0, 0.96, 0.8, 0.45))
	_layer("e2_palco", a2, 0.0, 0.0)
	var fy := a2.position.y + 15.0 * 64.0
	for r in rats:
		var p := Vector2(r["x"], fy - 6)
		var d := signf(r["v"])
		draw_set_transform(p, 0.0, Vector2(d, 1))
		draw_circle(Vector2.ZERO, 9.0, Color("#8d98a4"))
		draw_circle(Vector2(10, -3), 6.0, Color("#8d98a4"))
		draw_circle(Vector2(13, -5), 1.6, Color("#d94a3a"))
		draw_line(Vector2(-9, 0), Vector2(-20, -4 + sin(t * 20.0) * 3.0), Color("#8d98a4"), 2.0, true)
		draw_set_transform(Vector2.ZERO)

func _draw_front() -> void:
	var v := _view()
	if v.intersects(a1):
		var tx: Texture2D = tex.get("e1_frente")
		if tx != null:
			front.draw_texture_rect(tx, Rect2(a1.position + _par(a1, -0.12), Vector2(640, 200)), false, Color(1, 1, 1, 0.9))
	if v.intersects(a2):
		for k in 4:   # lâmpadas penduradas balançando (com brilho) e gotas
			var x := a2.position.x + 380.0 + k * 600.0
			var l := 180.0 + 60.0 * (k % 2)
			var ang := sin(t * 1.2 + k) * 0.08
			var top := Vector2(x, a2.position.y + 128.0)
			var lp := top + Vector2(sin(ang), cos(ang)) * l
			front.draw_line(top, lp, Color("#2a1a2e"), 3.0, true)
			front.draw_circle(lp + Vector2(0, 14), 70.0, Color(1.0, 0.91, 0.66, 0.12))
			front.draw_colored_polygon(PackedVector2Array([lp + Vector2(-16, 0), lp + Vector2(16, 0), lp + Vector2(10, 12), lp + Vector2(-10, 12)]), Color("#3a3a46"))
			front.draw_circle(lp + Vector2(0, 14), 9.0, Color("#ffe7a8"))
			var dy := fmod(t * 300.0 + k * 170.0, 700.0)
			front.draw_circle(Vector2(x + 140.0, a2.position.y + 140.0 + dy), 3.0, Color(0.62, 0.89, 0.96, 0.8))
