extends Node2D
## Fundo da arena (camada própria, com paralaxe): imagem do tema (assets/temas/<tema>/fundo.png, ou o Canteiro)
## e animações leves de ambiente por tema — poeira na luz (fábrica), gaivotas e brilho no mar (porto),
## estrelas piscando e neon (cidade). Coordenadas da tela 1920x1080.

var texture: Texture2D = null
var theme := "canteiro"
var t := 0.0
var _rng := RandomNumberGenerator.new()
var motes: Array = []      # fábrica: {pos, vel, a}
var gulls: Array = []      # porto: {x, y, s, ph}
var stars: Array = []      # cidade: {pos, r, ph}

func _ready() -> void:
	set_theme("canteiro")

func set_theme(name: String) -> void:
	theme = name
	var tex := Data.tex("temas/%s/fundo" % name) if name != "canteiro" else null
	texture = tex if tex != null else Data.tex("cenario/fundo_canteiro")
	_rng.seed = hash(name)
	motes.clear()
	gulls.clear()
	stars.clear()
	match name:
		"fabrica":
			for i in 46:
				motes.append({"pos": Vector2(_rng.randf_range(0, 1920), _rng.randf_range(160, 900)),
					"vel": Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-14, -4)), "a": _rng.randf_range(0.2, 0.6)})
		"porto":
			for i in 5:
				gulls.append({"x": _rng.randf_range(0, 1920), "y": _rng.randf_range(80, 420), "s": _rng.randf_range(40, 90), "ph": _rng.randf() * TAU})
		"cidade":
			for i in 60:
				stars.append({"pos": Vector2(_rng.randf_range(0, 1920), _rng.randf_range(0, 500)), "r": _rng.randf_range(1.5, 3.2), "ph": _rng.randf() * TAU})
	queue_redraw()

func _process(dt: float) -> void:
	if theme == "canteiro":
		return
	t += dt
	for m in motes:
		m["pos"] += m["vel"] * dt
		if m["pos"].y < 140.0:
			m["pos"] = Vector2(_rng.randf_range(0, 1920), 900.0)
	for g in gulls:
		g["x"] += g["s"] * dt
		if g["x"] > 2000.0:
			g["x"] = -80.0
			g["y"] = _rng.randf_range(80, 420)
	queue_redraw()

func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, Rect2(0, 0, 1920, 1080), false)
	else:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("#3aa7a3"))
	match theme:
		"fabrica":
			for m in motes:
				draw_circle(m["pos"], 2.6, Color(1.0, 0.97, 0.88, m["a"] * (0.6 + 0.4 * sin(t * 2.0 + m["pos"].x))))
		"porto":
			for g in gulls:
				var p := Vector2(g["x"], g["y"] + sin(t * 1.5 + g["ph"]) * 10.0)
				var flap := sin(t * 7.0 + g["ph"]) * 8.0
				draw_polyline(PackedVector2Array([p + Vector2(-16, -flap), p + Vector2(-6, 0), p, p + Vector2(6, 0), p + Vector2(16, -flap)]), Color("#f8f5ee"), 3.0, true)
			for k in 14:   # brilho no mar
				var x := fposmod(k * 151.0 + t * 30.0, 1960.0) - 20.0
				var y := 700.0 + (k % 5) * 40.0
				draw_line(Vector2(x, y), Vector2(x + 26, y), Color(1, 1, 1, 0.35 + 0.3 * sin(t * 3.0 + k)), 3.0)
		"cidade":
			for s in stars:
				draw_circle(s["pos"], s["r"], Color(1.0, 0.97, 0.86, 0.35 + 0.55 * absf(sin(t * 1.3 + s["ph"]))))
			# neon do outdoor pulsando
			var on := 0.55 + 0.45 * absf(sin(t * 2.2))
			draw_rect(Rect2(772, 432, 276, 96), Color(1.0, 0.48, 0.72, 0.25 * on), false, 10.0)
