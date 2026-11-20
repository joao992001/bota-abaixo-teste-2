extends Node2D
## Visual do robô: squash/stretch e expressão. Formas simples até a arte cut-out entrar.

const Piece := preload("res://pieces/piece.gd")

var color_idx := 0
var pid := 0
var expression := "normal"
var sq := Vector2.ONE
var facing := 1
var hammer := 0.0
var run_t := 0.0
var moving := false

func setup(col_idx: int, p: int) -> void:
	color_idx = col_idx
	pid = p

func land() -> void:
	sq = Vector2(1.25, 0.8)

func stretch() -> void:
	sq = Vector2(0.8, 1.25)

func tick(robot, dt: float) -> void:
	sq = sq.lerp(Vector2.ONE, minf(dt * 12.0, 1.0))
	facing = robot.facing
	hammer = robot.hammer_anim
	moving = absf(robot.velocity.x) > 40 and robot.is_on_floor()
	run_t += dt * (12.0 if moving else 2.0)
	if robot.alive and not robot.finished:
		if robot.hammer_anim > 0.0 or (robot.velocity.y < -200 and not robot.is_on_floor()):
			expression = "esforco"
		elif robot.main.danger_near(robot) or robot.velocity.y > 1000:
			expression = "susto"
		else:
			expression = "normal"
	scale = sq
	queue_redraw()

func _draw() -> void:
	draw_robot(self, Data.COLORS[color_idx], pid, expression, facing, hammer, run_t, moving)

static func draw_robot(ci: CanvasItem, col: Color, sym: int, expr: String, face: int, hammer_t: float, run_t: float, moving: bool) -> void:
	var ink := Data.INK
	var bob := sin(run_t) * (3.0 if moving else 1.5)
	# pés
	for s in [-1, 1]:
		var fx: float = s * 13 + (sin(run_t + (0 if s < 0 else PI)) * 8 if moving else 0)
		ci.draw_circle(Vector2(fx, -7), 10, ink)
		ci.draw_circle(Vector2(fx, -7), 6, col.darkened(0.3))
	# corpo (cabeça grande ~60%)
	var body := Rect2(-22, -48 + bob, 44, 38)
	ci.draw_rect(body.grow(5), ink)
	ci.draw_circle(Vector2(0, -52 + bob), 31, ink)
	ci.draw_rect(body, col)
	ci.draw_circle(Vector2(0, -52 + bob), 26, col)
	ci.draw_rect(Rect2(body.position.x + 30, body.position.y, 14, body.size.y), col.darkened(0.18))
	Piece.draw_symbol(ci, sym, Vector2(-2, -24 + bob), 6.0, ink)
	# olhos
	var ex := 7.0 * face
	var eye_y := -56.0 + bob
	if expr == "eliminado":
		for s in [-1, 1]:
			var e := Vector2(ex + s * 11, eye_y)
			ci.draw_line(e + Vector2(-6, -6), e + Vector2(6, 6), ink, 4)
			ci.draw_line(e + Vector2(-6, 6), e + Vector2(6, -6), ink, 4)
	else:
		var eh := 12.0 if expr != "susto" else 14.0
		for s in [-1, 1]:
			var e := Vector2(ex + s * 11, eye_y)
			_oval(ci, e, 9, eh + 2, ink)
			_oval(ci, e, 7, eh, Color.WHITE)
			var pr := 3.5 if expr == "susto" else 4.5
			if expr == "vitoria":
				ci.draw_arc(e + Vector2(0, 3), 5, PI, TAU, 8, ink, 3)
			else:
				ci.draw_circle(e + Vector2(2.5 * face, 2), pr, ink)
		if expr == "esforco":
			ci.draw_line(Vector2(ex - 19, eye_y - 15), Vector2(ex - 4, eye_y - 10), ink, 4)
			ci.draw_line(Vector2(ex + 19, eye_y - 15), Vector2(ex + 4, eye_y - 10), ink, 4)
	# boca
	var m := Vector2(ex, -36 + bob)
	match expr:
		"susto": _oval(ci, m, 5, 6, ink)
		"vitoria": ci.draw_arc(m + Vector2(0, -3), 8, 0.2, PI - 0.2, 10, ink, 4)
		"esforco": ci.draw_rect(Rect2(m - Vector2(8, 2), Vector2(16, 5)), ink)
		"eliminado": ci.draw_arc(m + Vector2(0, 5), 7, PI + 0.3, TAU - 0.3, 10, ink, 4)
		_: ci.draw_arc(m + Vector2(0, -4), 6, 0.4, PI - 0.4, 8, ink, 3.5)
	# marreta
	var ang := -1.9 if hammer_t <= 0.0 else lerpf(-2.4, 0.4, 1.0 - hammer_t / 0.25)
	var pivot := Vector2(18 * face, -28 + bob)
	var dir := Vector2.from_angle(ang if face > 0 else PI - ang)
	var head := pivot + dir * 30
	ci.draw_line(pivot, head, ink, 8)
	ci.draw_line(pivot, head, Color("#c98b4e"), 4)
	var perp := dir.orthogonal()
	var hp := PackedVector2Array([head + perp * 12 - dir * 7, head + perp * 12 + dir * 7, head - perp * 12 + dir * 7, head - perp * 12 - dir * 7])
	ci.draw_colored_polygon(hp, ink)
	var hp2 := PackedVector2Array()
	for p in hp:
		hp2.append(head + (p - head) * 0.7)
	ci.draw_colored_polygon(hp2, Color("#9aa3af"))
	ci.draw_circle(pivot, 6, ink)
	ci.draw_circle(pivot, 3.5, col)

static func _oval(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(pts, col)
