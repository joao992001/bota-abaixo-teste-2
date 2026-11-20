extends Node2D
## Visual cut-out do robô: corpo, rosto (expressão), pés, mãos, marreta e acessório como partes separadas
## (PNGs 2x de art/out/game/robo). Squash/stretch e virar de lado por escala; nunca mexe na hitbox.
## Tela das partes: 128x128 (px de jogo) com a origem do robô (pés no chão) em (64,120).

const ORIGIN := Vector2(64, 120)
const HAND := Vector2(94, 94)      # mão da marreta (pega)
const HAND2 := Vector2(40, 98)
const GRIP := Vector2(32, 54)      # pega dentro da textura da marreta (64x64)
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
static func draw_robot(ci: CanvasItem, col_idx: int, expr: String, hammer_t: float, run_t: float, moving: bool, accessory: int, air := false, base := Transform2D.IDENTITY) -> void:
	var body := Data.tex("robo/corpo_p%d" % (col_idx + 1))
	if body == null:
		return
	var bob := (absf(sin(run_t)) * -3.0) if moving else sin(run_t) * 1.0
	var lean := 0.08 if moving else 0.0
	# marreta (atrás do corpo): parada no ombro; na marretada gira para a frente e para baixo
	var ang := REST
	if hammer_t > 0.0:
		var k := 1.0 - hammer_t / float(Data.ctrl["hammer_time"])
		ang = lerpf(-0.6, 2.3, clampf(k * 1.6, 0.0, 1.0))
	var hand := HAND - ORIGIN + Vector2(0, bob)
	ci.draw_set_transform_matrix(base * Transform2D(ang, Vector2(0.5, 0.5), 0.0, hand))
	ci.draw_texture(Data.tex("robo/marreta"), -GRIP * 2.0)
	# pés: alternam na corrida; no ar ficam juntos e para baixo
	var foot := Data.tex("robo/pe")
	for s in [-1, 1]:
		var off := Vector2.ZERO
		if moving:
			var ph: float = run_t + (0.0 if s < 0 else PI)
			off = Vector2(cos(ph) * 7.0, minf(sin(ph), 0.0) * 6.0)
		elif air:
			off = Vector2(s * -3, 3)
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.5, 0.5), 0.0, Vector2(s * 12, -7) + off))
		ci.draw_texture(foot, -Vector2(16, 11) * 2.0)
	# corpo + rosto + acessório (mesma tela)
	ci.draw_set_transform_matrix(base * Transform2D(lean, Vector2(0.5, 0.5), 0.0, Vector2(0, bob)))
	ci.draw_texture(body, -ORIGIN * 2.0)
	ci.draw_texture(Data.tex("robo/rosto_" + expr), -ORIGIN * 2.0)
	if accessory > 0:
		ci.draw_texture(Data.tex("robo/acc_" + Data.ACCS[accessory]), -ORIGIN * 2.0)
	# mãos
	var h := Data.tex("robo/mao")
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.5, 0.5), 0.0, hand))
	ci.draw_texture(h, -Vector2(12, 12) * 2.0)
	var swing := sin(run_t) * 4.0 if moving else 0.0
	ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(0.5, 0.5), 0.0, HAND2 - ORIGIN + Vector2(swing, bob)))
	ci.draw_texture(h, -Vector2(12, 12) * 2.0)
	ci.draw_set_transform_matrix(base)
