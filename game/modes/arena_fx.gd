extends Node2D
## Mecânicas especiais de cada arena da Demolição, lidas do cabeçalho do .lvl:
##   plataformas: x,y,largura,dx,dy,periodo ; ...   (tiles; plataformas de aço que vão e voltam)
##   mare_inicio / mare_vel / mare_topo             (lama sobe a partir de mare_inicio s, mare_vel tiles/s)
##   bola: pivo_x,pivo_y,comprimento,amplitude_graus,periodo  (bola de demolição em pêndulo)
##   esteira_inverte: segundos                       (esteiras do mapa invertem; aviso 1,2 s antes)
## As plataformas são AnimatableBody2D: a física da Godot carrega quem está em cima.

const T := 64
var main: Node
var level: Node
var t := 0.0
var plats: Array = []      # {body, start, delta, period, w, pos}
var goo_y := 99999.0       # altura da lama (y do topo; mundo)
var goo_on := false
var ball := {}             # {pivot, len, amp, period, pos, vel}
var flip_every := 0.0
var flip_t := 0.0
var bubble_t := 0.5

func setup(m: Node, lv: Node) -> void:
	main = m
	level = lv
	var tint: String = lv.prop("fundo", "")
	main.bg.modulate = Color(tint) if tint != "" else Color.WHITE
	# plataformas
	var spec: String = lv.prop("plataformas", "")
	for part in spec.split(";", false):
		var v := part.split(",")
		if v.size() < 6:
			continue
		var w := int(v[2])
		var body := AnimatableBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = true
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(w * T, 24)
		cs.shape = rs
		cs.position = Vector2(w * T / 2.0, 12)
		body.add_child(cs)
		var start := Vector2(float(v[0]) * T, float(v[1]) * T)
		body.position = start
		add_child(body)
		plats.append({"body": body, "start": start, "delta": Vector2(float(v[3]), float(v[4])) * T, "period": float(v[5]), "w": w})
	if plats.size() > 0:
		lv.extra_solid = Callable(self, "_cell_on_platform")
	# maré de lama
	if lv.prop("mare_inicio", "") != "":
		goo_on = true
		goo_y = lv.rows * T + 40.0
	# bola de demolição
	var bs: String = lv.prop("bola", "")
	if bs != "":
		var b := bs.split(",")
		ball = {"pivot": Vector2(float(b[0]) * T + T / 2.0, float(b[1]) * T), "len": float(b[2]) * T,
			"amp": deg_to_rad(float(b[3])), "period": float(b[4]), "pos": Vector2.ZERO, "vel": Vector2.ZERO}
		_ball_step(0.0)
	flip_every = float(lv.prop("esteira_inverte", "0"))
	flip_t = flip_every

func _cell_on_platform(c: Vector2i) -> bool:
	var cr := Rect2(Vector2(c * T), Vector2(T, T))
	for p in plats:
		var pr := Rect2(p["body"].position, Vector2(p["w"] * T, 24))
		if pr.intersects(cr):
			return true
	return false

## Plataforma embaixo deste ponto (para itens pousarem e andarem junto).
func platform_at(pt: Vector2):
	for p in plats:
		var pr := Rect2(p["body"].position + Vector2(0, -4), Vector2(p["w"] * T, 30))
		if pr.has_point(pt):
			return p
	return null

func update(dt: float, running: bool) -> void:
	t += dt
	for p in plats:
		var k := 0.5 - 0.5 * cos(TAU * t / float(p["period"]))
		p["body"].position = p["start"] + p["delta"] * k
	if not running:
		queue_redraw()
		return
	# esteiras invertem
	if flip_every > 0.0:
		flip_t -= dt
		if flip_t < 1.2 and not level.belt_warn:
			Audio.play("alarme")
		level.belt_warn = flip_t < 1.2
		if flip_t <= 0.0:
			flip_t = flip_every
			level.belt_warn = false
			level.flip_belts()
			main.shake(3.0)
	# lama sobe
	if goo_on and main.demo.t >= float(level.prop("mare_inicio", "6")):
		var top := float(level.prop("mare_topo", "2")) * T
		goo_y = maxf(goo_y - float(level.prop("mare_vel", "0.25")) * T * dt, top)
		bubble_t -= dt
		if bubble_t <= 0.0:
			bubble_t = randf_range(0.35, 0.9)
			Audio.play("lama", 1.0, -6.0)
		for r in main.robots:
			if r.alive and r.position.y - 20.0 > goo_y:
				r.last_hit = 0.0
				main.kill(r, -1, null)
		for cell in level.blocks.keys():
			if cell.y * T > goo_y + T:
				level.break_block(cell)
	# bola de demolição
	if not ball.is_empty():
		var before_x: float = ball["pos"].x - ball["pivot"].x
		_ball_step(dt)
		if signf(before_x) != signf(ball["pos"].x - ball["pivot"].x):
			Audio.play("bola_vento")
		var bp: Vector2 = ball["pos"]
		for r in main.robots:
			if r.alive and r.rect().grow(4).intersects(Rect2(bp - Vector2(46, 46), Vector2(92, 92))) and r.stun_t <= 0.2:
				var dir := 1 if ball["vel"].x >= 0.0 else -1
				r.knock(dir, 1250.0, 700.0, 0.6)
				main.spark(r.rect().get_center(), 8)
				main.shake(9.0)
		for cell in level.blocks.keys():
			if (Vector2(cell * T) + Vector2(32, 32)).distance_to(bp) < 70.0:
				level.break_block(cell)
	queue_redraw()

func _ball_step(_dt: float) -> void:
	var ang: float = ball["amp"] * sin(TAU * t / float(ball["period"]))
	var w: float = ball["amp"] * cos(TAU * t / float(ball["period"])) * TAU / float(ball["period"])
	var dirv := Vector2(sin(ang), cos(ang))
	ball["pos"] = ball["pivot"] + dirv * float(ball["len"])
	ball["vel"] = Vector2(cos(ang), -sin(ang)) * w * float(ball["len"])

func _draw() -> void:
	# cabos e plataformas
	var tex := Data.tex("cenario/plataforma_aco")
	for p in plats:
		var pos: Vector2 = p["body"].position
		var w: float = p["w"] * T
		for cx in [pos.x + 16, pos.x + w - 16]:
			draw_line(Vector2(cx, -200), Vector2(cx, pos.y + 6), Color("#5a6370"), 3.0, true)
		draw_texture_rect(tex, Rect2(pos + Vector2(0, -6), Vector2(w, 40)), false)
	# bola + corrente
	if not ball.is_empty():
		var a: Vector2 = ball["pivot"]
		var b: Vector2 = ball["pos"]
		var n := 14
		for i in n:
			var p := a.lerp(b, (i + 0.5) / n)
			draw_circle(p, 6.5, Color("#5a6370"))
			draw_circle(p, 3.5, Color("#8e98a8"))
		draw_set_transform(b, -atan2(b.x - a.x, b.y - a.y))
		draw_texture_rect(Data.tex("cenario/bola_demolicao"), Rect2(-60, -60, 120, 120), false)
		draw_set_transform(Vector2.ZERO)
		draw_circle(a, 12, Color("#3e4752"))
	# lama subindo
	if goo_on and goo_y < level.rows * T + 30:
		var lama := Data.tex("cenario/lama")
		var y := goo_y - 24.0
		var x := -fposmod(t * 20.0, 64.0)
		while x < level.cols * T:
			draw_texture_rect(lama, Rect2(x, y, 64, 64), false)
			x += 64.0
		draw_rect(Rect2(0, y + 60, level.cols * T, level.rows * T + 200 - y), Color("#7a5fb3"))
