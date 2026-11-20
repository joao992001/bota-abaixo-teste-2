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
var model := 0
var has_hammer := true
var expression := "normal"
var sq := Vector2.ONE
var facing := 1
var hammer := 0.0
var run_t := 0.0
var moving := false
var airborne := false

func setup(col_idx: int, accessory: int, mdl := 0) -> void:
	color_idx = col_idx
	acc = accessory
	model = mdl

func land() -> void:
	sq = Vector2(1.25, 0.8)

func stretch() -> void:
	sq = Vector2(0.8, 1.25)

func tick(robot, dt: float) -> void:
	sq = sq.lerp(Vector2.ONE, minf(dt * 12.0, 1.0))
	facing = robot.facing
	hammer = robot.hammer_anim
	has_hammer = robot.hammer_left > 0 or robot.hammer_anim > 0.0
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
	draw_robot(self, color_idx, expression, hammer, run_t, moving, acc, airborne, Transform2D.IDENTITY, model, has_hammer)

## Desenha o robô montado em qualquer CanvasItem (também nas telas de entrada e vitória).
## Partes em PNG 4x (art/out/game/robo); pernas e braços grossos desenhados aqui, como em versoes.png.
static func draw_robot(ci: CanvasItem, col_idx: int, expr: String, hammer_t: float, run_t: float, moving: bool, accessory: int, air := false, base := Transform2D.IDENTITY, model := 0, has_hammer := true) -> void:
	var mname: String = Data.MODELS[model]
	var body := Data.tex("robo/corpo_%s_p%d" % [mname, col_idx + 1])
	if body == null or Data.robot_meta.is_empty():
		return
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := Color(Data.robot_meta["membros"][col_idx])
	var bob := (absf(sin(run_t)) * -3.0) if moving else sin(run_t) * 0.8
	var up := Vector2(0, bob)
	var q := Vector2(0.25, 0.25)
	var hf := _v(g["hand_front"]) + up
	var hb := _v(g["hand_back"]) + Vector2(sin(run_t) * 4.0 if moving else 0.0, bob)
	# marreta (atrás): parada erguida; na marretada gira para a frente e para baixo
	if has_hammer:
		var ang := 0.35
		if hammer_t > 0.0:
			var k := 1.0 - hammer_t / float(Data.ctrl["hammer_time"])
			ang = lerpf(-0.6, 2.3, clampf(k * 1.6, 0.0, 1.0))
		ci.draw_set_transform_matrix(base * Transform2D(ang, q, 0.0, hf))
		ci.draw_texture(Data.tex("robo/marreta"), -GRIP * 4.0)
		ci.draw_set_transform_matrix(base)
	# pernas + botas
	var foot := Data.tex("robo/pe")
	var hips: Array = g["hips"]
	for i in 2:
		var s := -1 if i == 0 else 1
		var hip := _v(hips[i]) + up
		var fp := Vector2(hip.x + s * 4.0, -4.0)
		if moving:
			var ph: float = run_t + (0.0 if s < 0 else PI)
			fp += Vector2(cos(ph) * 7.0, minf(sin(ph), 0.0) * 6.0)
		elif air:
			fp += Vector2(-s * 2.0, -4.0)
		_limb(ci, base, hip, fp, limb, Vector2(-1.5 * s, 0))
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q * 0.72, 0.0, fp + Vector2(s * 1.5, 0.5)))
		ci.draw_texture(foot, -Vector2(12, 7) * 4.0, limb)
		ci.draw_set_transform_matrix(base)
	var sh: Array = g["shoulders"]
	_limb(ci, base, _v(sh[0]) + up, hb, limb, Vector2(0, 3))
	# corpo, rosto, antena ou chapéu
	ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, up))
	ci.draw_texture(body, -ORIGIN * 4.0)
	ci.draw_texture(Data.tex("robo/rosto_%s_%s" % [mname, expr]), -ORIGIN * 4.0)
	if accessory <= 0:
		ci.draw_texture(Data.tex("robo/antena_" + mname), -ORIGIN * 4.0)
	ci.draw_set_transform_matrix(base)
	if accessory > 0:
		var h: Array = g["hat"]
		var hs := float(h[2]) * 0.25
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(hs, hs), 0.0, _v(h) + up))
		ci.draw_texture(Data.tex("robo/acc_" + Data.ACCS[accessory]), -Vector2(64, 64) * 4.0)
		ci.draw_set_transform_matrix(base)
	_limb(ci, base, _v(sh[1]) + up, hf, limb, Vector2(0, 3))
	var hand := Data.tex("robo/mao")
	for p in [hb, hf]:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, p))
		ci.draw_texture(hand, -Vector2(8, 8) * 4.0)
	ci.draw_set_transform_matrix(base)

static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) - ORIGIN

## Membro grosso de "macarrão" com riscos de giz.
static func _limb(ci: CanvasItem, base: Transform2D, a: Vector2, b: Vector2, col: Color, bend: Vector2) -> void:
	var m := (a + b) / 2.0 + bend
	var pts := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		pts.append(a.lerp(m, t).lerp(m.lerp(b, t), t))
	ci.draw_set_transform_matrix(base)
	ci.draw_polyline(pts, col, 3.4, true)
	var streak := PackedVector2Array()
	for p in pts:
		streak.append(p + Vector2(-0.6, 0))
	ci.draw_polyline(streak, col.lightened(0.15), 0.6, true)
