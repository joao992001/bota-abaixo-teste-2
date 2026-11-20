extends Node2D
## Visual cut-out do robô: corpo, rosto (expressão), pés, mãos, marreta e acessório como partes separadas
## (PNGs 2x de art/out/game/robo). Squash/stretch e virar de lado por escala; nunca mexe na hitbox.
## Tela das partes: 128x128 (px de jogo) com a origem do robô (pés no chão) em (64,120).

const ORIGIN := Vector2(64, 120)
const HAND := Vector2(86, 93)      # mão da marreta (pega)
const HAND2 := Vector2(43, 97)
const GRIP := Vector2(32, 56)      # pega dentro da textura da marreta (64x64)
const REST := 0.75                 # ângulo da marreta parada (rad, horário)

var color_idx := 0
var acc := 0
var expression := "normal"
var sq := Vector2.ONE
var facing := 1
var hammer := 0.0
var run_t := 0.0
var moving := false
var airborne := false

func setup(col_idx: int, accessory: int) -> void:
	color_idx = col_idx
	acc = accessory

func land() -> void:
	sq = Vector2(1.25, 0.8)

func stretch() -> void:
	sq = Vector2(0.8, 1.25)

func tick(robot, dt: float) -> void:
	sq = sq.lerp(Vector2.ONE, minf(dt * 12.0, 1.0))
	facing = robot.facing
	hammer = robot.hammer_anim
	moving = absf(robot.velocity.x) > 40 and robot.is_on_floor()
	airborne = not robot.is_on_floor()
	run_t += dt * (14.0 if moving else 2.5)
	if robot.alive and not robot.finished:
		if robot.hammer_anim > 0.0 or (robot.velocity.y < -200 and airborne):
			expression = "esforco"
		elif robot.main.danger_near(robot) or robot.velocity.y > 1000:
			expression = "susto"
		else:
			expression = "normal"
	scale = Vector2(sq.x * facing, sq.y)
	queue_redraw()

func _draw() -> void:
	draw_robot(self, color_idx, expression, hammer, run_t, moving, acc, airborne)

## Desenha o robô montado em qualquer CanvasItem (também usado nas telas de entrada e vitória).
## Partes em PNG 4x; pernas e braços finos desenhados aqui (traço de "macarrão", como na ref1).
static func draw_robot(ci: CanvasItem, col_idx: int, expr: String, hammer_t: float, run_t: float, moving: bool, accessory: int, air := false, base := Transform2D.IDENTITY) -> void:
	var body := Data.tex("robo/corpo_p%d" % (col_idx + 1))
	if body == null:
		return
	var col: Color = Data.COLORS[col_idx]
	var bob := (absf(sin(run_t)) * -3.0) if moving else sin(run_t) * 0.8
	var up := Vector2(0, bob)
	var q := Vector2(0.25, 0.25)
	# marreta (atrás): parada no ombro; na marretada gira para a frente e para baixo
	var ang := REST
	if hammer_t > 0.0:
		var k := 1.0 - hammer_t / float(Data.ctrl["hammer_time"])
		ang = lerpf(-0.7, 2.3, clampf(k * 1.6, 0.0, 1.0))
	var hand := HAND - ORIGIN + up
	ci.draw_set_transform_matrix(base * Transform2D(ang, q, 0.0, hand))
	ci.draw_texture(Data.tex("robo/marreta"), -GRIP * 4.0)
	ci.draw_set_transform_matrix(base)
	# pernas + botas
	var foot := Data.tex("robo/pe")
	for s in [-1, 1]:
		var hip := Vector2(s * 6, -20) + up
		var fp := Vector2(s * 7, -4.5)
		if moving:
			var ph: float = run_t + (0.0 if s < 0 else PI)
			fp += Vector2(cos(ph) * 7.0, minf(sin(ph), 0.0) * 6.0)
		elif air:
			fp += Vector2(-s * 2.0, -3.0)
		_limb(ci, hip, fp, col, Vector2(-2.0, 0))
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, fp + Vector2(1.5, -0.5)))
		ci.draw_texture(foot, -Vector2(12, 8) * 4.0)
		ci.draw_set_transform_matrix(base)
	# braço de trás
	var swing := sin(run_t) * 4.0 if moving else 0.0
	var hand2 := HAND2 - ORIGIN + Vector2(swing, bob)
	_limb(ci, Vector2(-8, -32) + up, hand2, col, Vector2(0, 3))
	# corpo, rosto, antena/acessório
	ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, up))
	ci.draw_texture(body, -ORIGIN * 4.0)
	ci.draw_texture(Data.tex("robo/rosto_" + expr), -ORIGIN * 4.0)
	if accessory > 0:
		ci.draw_texture(Data.tex("robo/acc_" + Data.ACCS[accessory]), -ORIGIN * 4.0)
	else:
		ci.draw_texture(Data.tex("robo/antena"), -ORIGIN * 4.0)
	ci.draw_set_transform_matrix(base)
	# braço da frente segurando a marreta
	_limb(ci, Vector2(9, -32) + up, hand, col, Vector2(0, 3))
	var h := Data.tex("robo/mao")
	for p in [hand2, hand]:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, p))
		ci.draw_texture(h, -Vector2(8, 8) * 4.0)
	ci.draw_set_transform_matrix(base)

static func _limb(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, bend: Vector2) -> void:
	var m := (a + b) / 2.0 + bend
	var pts := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	ci.draw_polyline(pts, Color("#1c1418"), 6.4, true)
	ci.draw_polyline(pts, col, 2.6, true)
