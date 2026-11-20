extends Node2D
## Visual cut-out do robô (estilo papel e giz). Partes em PNG 4x (art/out/game/robo); pernas e braços desenhados aqui.
## A animação é toda por código e só lê o estado do robô: nunca atrasa nem trava o controle.
## Tela das partes: 128x128 (px de jogo), origem do robô (pés no chão) em (64,120). Frente local = +x.
##
## Pose (Dictionary) usada pelo desenho:
##   expr, body_off (Vector2), lean (rad, + = para a frente), feet [Vector2, Vector2] (deslocamento dos pés),
##   knee [Vector2, Vector2] (dobra das pernas), hb_off / hf_off (mão de trás / da frente), hammer_ang, ant (antena)

const ORIGIN := Vector2(64, 120)
const GRIP := Vector2(32, 56)          # pega dentro da textura da marreta (64x64)
const HAMMER_REST := 0.35
const STRIDE := 46.0                   # px percorridos por ciclo de passada (pés não deslizam)

# aparência
var color_idx := 0
var acc := 0
var model := 0
var has_hammer := true
# estado da animação
var expression := "normal"
var sq := Vector2.ONE                  # squash/stretch visual
var shown_facing := 1.0                # vira passando por 0 (giro rápido)
var phase := 0.0
var run_k := 0.0
var air_k := 0.0
var wall_k := 0.0
var vy := 0.0
var lean := 0.0
var ant := 0.0
var ant_v := 0.0
var blink_t := 2.0
var t := 0.0
var hammer_t := 0.0
var hit_done := false
var prev_vel := Vector2.ZERO
var step_side := 0
var robot = null

func setup(col_idx: int, accessory: int, mdl := 0) -> void:
	color_idx = col_idx
	acc = accessory
	model = mdl
	blink_t = randf_range(0.5, 3.0)

func land() -> void:
	sq = Vector2(1.28, 0.78)

func stretch() -> void:
	sq = Vector2(0.78, 1.28)

func look() -> Dictionary:
	var lk := {"color": color_idx, "model": model, "acc": acc, "hammer": has_hammer}
	if robot != null and robot.has_method("fx_flags"):
		lk["fx"] = robot.fx_flags()
	return lk

func tick(r, dt: float) -> void:
	robot = r
	t += dt
	var c: Dictionary = Data.ctrl
	var v: Vector2 = r.velocity
	var on_floor: bool = r.is_on_floor()
	var spd := absf(v.x)
	sq = sq.lerp(Vector2.ONE, minf(dt * 11.0, 1.0))
	shown_facing = move_toward(shown_facing, float(r.facing), dt * 16.0)
	run_k = move_toward(run_k, clampf(spd / float(c["max_run"]), 0.0, 1.0) if on_floor else 0.0, dt * 8.0)
	air_k = move_toward(air_k, 0.0 if on_floor else 1.0, dt * 10.0)
	wall_k = move_toward(wall_k, 1.0 if r.wall_sliding else 0.0, dt * 12.0)
	vy = v.y
	# passada pela distância percorrida + poeirinha a cada passo
	if on_floor and spd > 30.0:
		var before := int(phase / PI)
		phase += spd * dt / STRIDE * TAU
		if int(phase / PI) != before and spd > 300.0:
			r.main.dust(r.position + Vector2(-r.facing * 10, 0), 0.45)
	# marretada em 3 tempos (preparo, golpe, volta)
	hammer_t = r.hammer_anim
	has_hammer = r.hammer_left > 0 or hammer_t > 0.0
	var hk := 1.0 - hammer_t / float(c["hammer_time"]) if hammer_t > 0.0 else 0.0
	if hammer_t <= 0.0:
		hit_done = false
	elif hk >= 0.45 and not hit_done:
		hit_done = true
		sq = Vector2(1.15, 0.88)
		r.main.spark(r.position + Vector2(r.facing * 40, -30), 5)
		r.main.shake(5.0)
	# inclinação: corre para a frente, freia para trás, apoia na parede para trás
	var target := run_k * 0.14
	if on_floor and spd > 120.0 and signf(v.x) != float(r.facing):
		target = -0.18
	target -= wall_k * 0.16
	if hammer_t > 0.0:
		target += _hammer_lean(hk)
	lean = lerpf(lean, target, minf(dt * 12.0, 1.0))
	# antena como mola (reage à aceleração)
	var a := (v - prev_vel) / maxf(dt, 0.001)
	prev_vel = v
	var ax := clampf(a.x * float(r.facing), -9000.0, 9000.0)
	ant_v += (-150.0 * ant - 7.0 * ant_v - ax * 0.0045 - clampf(a.y, -9000, 9000) * 0.0008) * dt
	ant = clampf(ant + ant_v * dt, -0.8, 0.8)
	# piscar
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = randf_range(1.8, 4.2)
	if r.alive and not r.finished:
		if hammer_t > 0.0 or (v.y < -200.0 and not on_floor):
			expression = "esforco"
		elif r.main.danger_near(r) or v.y > 1000.0:
			expression = "susto"
		else:
			expression = "piscar" if blink_t < 0.0 else "normal"
	var fx := shown_facing if absf(shown_facing) > 0.2 else 0.2 * signf(shown_facing + 0.0001)
	scale = Vector2(sq.x * fx, sq.y)
	queue_redraw()

static func _hammer_lean(k: float) -> float:
	if k < 0.25:
		return -0.14 * (k / 0.25)
	if k < 0.55:
		return lerpf(-0.14, 0.3, (k - 0.25) / 0.3)
	return lerpf(0.3, 0.0, (k - 0.55) / 0.45)

func current_pose() -> Dictionary:
	var p := idle_pose(t)
	p["expr"] = expression
	var r := run_k
	var bob := -absf(sin(phase)) * 3.5 * r + sin(t * 2.4) * 0.8 * (1.0 - r)
	var feet := [Vector2.ZERO, Vector2.ZERO]
	var knee := [Vector2(1.5, 0), Vector2(1.5, 0)]
	var hb := Vector2(0, sin(t * 2.4) * 0.6 * (1.0 - r))
	var hf := Vector2.ZERO
	# corrida
	for i in 2:
		var ph := phase + (0.0 if i == 0 else PI)
		feet[i] = Vector2(cos(ph) * 9.0 * r, -maxf(sin(ph), 0.0) * 8.0 * r)
		knee[i] = Vector2(1.5 + 4.5 * r * maxf(sin(ph), 0.0), 0)
	hb += Vector2(-cos(phase) * 7.0 * r, -absf(sin(phase)) * 2.0 * r)
	hf += Vector2(cos(phase) * 3.0 * r, 0)
	# ar: encolhe subindo, agita os braços caindo
	var a := air_k
	if a > 0.0:
		var fall := clampf(vy / 700.0, -1.0, 1.0)
		var up := maxf(-fall, 0.0)
		var down := maxf(fall, 0.0)
		for i in 2:
			var s := -1.0 if i == 0 else 1.0
			feet[i] = feet[i].lerp(Vector2(2.0 + s * 1.0, -9.0) * up + Vector2(s * 3.0, 2.0) * down, a)
			knee[i] = knee[i].lerp(Vector2(6.0, 0) * up + Vector2(1.0, 0) * down, a)
		hb = hb.lerp(Vector2(-3, -12) * up + Vector2(sin(t * 22.0) * 5.0, -15.0 + cos(t * 22.0) * 4.0) * down, a)
		hf = hf.lerp(Vector2(0, -6) * up + Vector2(cos(t * 20.0) * 3.0, -6.0) * down, a)
	# parede: mão e pés apoiados
	if wall_k > 0.0:
		hf += Vector2(10, -14) * wall_k
		for i in 2:
			feet[i] += Vector2(7, -3) * wall_k
	# marretada
	var ang := HAMMER_REST
	if hammer_t > 0.0:
		var k := 1.0 - hammer_t / float(Data.ctrl["hammer_time"])
		if k < 0.25:
			var e := k / 0.25
			ang = lerpf(HAMMER_REST, -1.3, e)
			hf += Vector2(-4, -7) * e
		elif k < 0.55:
			var e := pow((k - 0.25) / 0.3, 2.0)
			ang = lerpf(-1.3, 2.4, e)
			hf += Vector2(-4, -7).lerp(Vector2(10, 8), e)
		else:
			var e := (k - 0.55) / 0.45
			ang = lerpf(2.4, HAMMER_REST, e * e * (3.0 - 2.0 * e))
			hf += Vector2(10, 8).lerp(Vector2.ZERO, e)
	p["body_off"] = Vector2(0, bob)
	p["lean"] = lean
	p["feet"] = feet
	p["knee"] = knee
	p["hb_off"] = hb
	p["hf_off"] = hf
	p["hammer_ang"] = ang
	p["ant"] = ant
	return p

func _draw() -> void:
	draw_robot(self, look(), current_pose())

## Poses prontas para telas (entrada e vitória).
static func idle_pose(time: float) -> Dictionary:
	return {"expr": "piscar" if fmod(time, 3.3) < 0.12 else "normal", "body_off": Vector2(0, sin(time * 2.4) * 0.8),
		"lean": 0.0, "feet": [Vector2.ZERO, Vector2.ZERO], "knee": [Vector2(1.5, 0), Vector2(1.5, 0)],
		"hb_off": Vector2(0, sin(time * 2.4) * 0.6), "hf_off": Vector2.ZERO, "hammer_ang": HAMMER_REST,
		"ant": sin(time * 3.1) * 0.12}

static func victory_pose(time: float) -> Dictionary:
	var hop := -absf(sin(time * 6.0)) * 8.0
	var p := idle_pose(time)
	p["expr"] = "vitoria"
	p["body_off"] = Vector2(0, hop)
	p["feet"] = [Vector2(-1, hop * 0.6), Vector2(1, hop * 0.6)]
	p["knee"] = [Vector2(4, 0), Vector2(4, 0)]
	p["hb_off"] = Vector2(-2, -22 + sin(time * 12.0) * 4.0)
	p["hf_off"] = Vector2(2, -16 + cos(time * 12.0) * 4.0)
	p["hammer_ang"] = -0.3 + sin(time * 12.0) * 0.35
	p["ant"] = sin(time * 12.0) * 0.35
	return p

## Desenha o robô montado em qualquer CanvasItem. look = {color, model, acc, hammer}; pose = ver topo.
static func draw_robot(ci: CanvasItem, lk: Dictionary, pose: Dictionary, base := Transform2D.IDENTITY) -> void:
	var col_idx: int = lk["color"]
	var mname: String = Data.MODELS[lk["model"]]
	var body := Data.tex("robo/corpo_%s_p%d" % [mname, col_idx + 1])
	if body == null or Data.robot_meta.is_empty():
		return
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := Color(Data.robot_meta["membros"][col_idx])
	var q := Vector2(0.25, 0.25)
	# corpo inclina em torno do quadril
	var hips: Array = g["hips"]
	var pivot := (_v(hips[0]) + _v(hips[1])) / 2.0
	var bx := Transform2D(0.0, pose["body_off"] + pivot) * Transform2D(pose["lean"], Vector2.ZERO) * Transform2D(0.0, -pivot)
	var sh: Array = g["shoulders"]
	var hf: Vector2 = bx * _v(g["hand_front"]) + pose["hf_off"]
	var hb: Vector2 = bx * _v(g["hand_back"]) + pose["hb_off"]
	# marreta (atrás do corpo)
	var fx: Dictionary = lk.get("fx", {})
	if lk.get("hammer", true):
		var big: bool = fx.get("martelao", false)
		ci.draw_set_transform_matrix(base * Transform2D(pose["hammer_ang"], q * (1.55 if big else 1.0), 0.0, hf))
		ci.draw_texture(Data.tex("robo/marreta"), -GRIP * 4.0, Color(1.0, 0.82, 0.3) if big else Color.WHITE)
	# pernas + botas
	var foot := Data.tex("robo/pe")
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip: Vector2 = bx * _v(hips[i])
		var fp: Vector2 = Vector2(_v(hips[i]).x + s * 4.0, -4.0) + pose["feet"][i]
		_limb(ci, base, hip, fp, limb, pose["knee"][i])
		if fx.get("mola", false):
			ci.draw_set_transform_matrix(base)
			for k in 3:
				ci.draw_arc(fp + Vector2(s * 1.5, 4.0 + k * 3.0), 5.0, 0.0, TAU, 12, Color("#8e98a8"), 1.6, true)
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q * 0.72, 0.0, fp + Vector2(s * 1.5, 0.5)))
		ci.draw_texture(foot, -Vector2(12, 7) * 4.0, limb)
	_limb(ci, base, bx * _v(sh[0]), hb, limb, Vector2(0, 3))
	# corpo + rosto + antena (mola) ou chapéu
	ci.draw_set_transform_matrix(base * bx * Transform2D(0.0, q, 0.0, -ORIGIN))
	ci.draw_texture(body, Vector2.ZERO)
	ci.draw_texture(Data.tex("robo/rosto_%s_%s" % [mname, pose["expr"]]), Vector2.ZERO)
	var accessory: int = lk.get("acc", 0)
	if accessory <= 0:
		var ab := _v(g["antenna"])
		ci.draw_set_transform_matrix(base * bx * Transform2D(pose["ant"], ab) * Transform2D(0.0, q, 0.0, -ab - ORIGIN))
		ci.draw_texture(Data.tex("robo/antena_" + mname), Vector2.ZERO)
	else:
		var h: Array = g["hat"]
		var hs := float(h[2]) * 0.25
		ci.draw_set_transform_matrix(base * bx * Transform2D(pose["ant"] * 0.15, Vector2(hs, hs), 0.0, _v(h)))
		ci.draw_texture(Data.tex("robo/acc_" + Data.ACCS[accessory]), -Vector2(64, 64) * 4.0)
	var ha: Array = g["hat"]
	if fx.get("capacete", false):
		var size := 64.0 * (60.0 * float(ha[2]) / 52.0)
		ci.draw_set_transform_matrix(base * bx)
		ci.draw_texture_rect(Data.tex("itens/capacete"), Rect2(_v(ha) - Vector2(size / 2.0, size * 45.0 / 64.0), Vector2(size, size)), false)
	if fx.get("item", "") == "dinamite":
		ci.draw_set_transform_matrix(base * bx)
		var bobd := sin(Time.get_ticks_msec() / 150.0) * 2.0
		ci.draw_texture_rect(Data.tex("itens/dinamite"), Rect2(_v(ha) + Vector2(-11, -38 + bobd), Vector2(22, 22)), false)
	_limb(ci, base, bx * _v(sh[1]), hf, limb, Vector2(0, 3))
	var hand := Data.tex("robo/mao")
	for p in [hb, hf]:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, p))
		ci.draw_texture(hand, -Vector2(8, 8) * 4.0)
	ci.draw_set_transform_matrix(base)

static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) - ORIGIN

## Membro grosso de "macarrão" com risco de giz.
static func _limb(ci: CanvasItem, base: Transform2D, a: Vector2, b: Vector2, col: Color, bend: Vector2) -> void:
	var m := (a + b) / 2.0 + bend
	var pts := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		pts.append(a.lerp(m, k).lerp(m.lerp(b, k), k))
	ci.draw_set_transform_matrix(base)
	ci.draw_polyline(pts, col, 3.4, true)
	var streak := PackedVector2Array()
	for p in pts:
		streak.append(p + Vector2(-0.6, 0))
	ci.draw_polyline(streak, col.lightened(0.15), 0.6, true)

## Partes soltas para o robô "desmontar" na eliminação: [{tex, rect (local), modulate}].
static func parts(lk: Dictionary) -> Array:
	var mname: String = Data.MODELS[lk["model"]]
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := Color(Data.robot_meta["membros"][lk["color"]])
	var out := [
		{"tex": [Data.tex("robo/corpo_%s_p%d" % [mname, lk["color"] + 1]), Data.tex("robo/rosto_%s_eliminado" % mname)],
			"rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE},
	]
	if lk.get("acc", 0) > 0:
		var h: Array = g["hat"]
		var hs := float(h[2])
		out.append({"tex": [Data.tex("robo/acc_" + Data.ACCS[lk["acc"]])], "rect": Rect2(_v(h) - Vector2(64, 64) * hs, Vector2(128, 128) * hs), "mod": Color.WHITE})
	else:
		out.append({"tex": [Data.tex("robo/antena_" + mname)], "rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	if lk.get("hammer", true):
		out.append({"tex": [Data.tex("robo/marreta")], "rect": Rect2(_v(g["hand_front"]) - GRIP, Vector2(64, 64)), "mod": Color.WHITE})
	for hp in [g["hand_back"], g["hand_front"]]:
		out.append({"tex": [Data.tex("robo/mao")], "rect": Rect2(_v(hp) - Vector2(8, 8), Vector2(16, 16)), "mod": Color.WHITE})
	for hip in g["hips"]:
		out.append({"tex": [Data.tex("robo/pe")], "rect": Rect2(Vector2(_v(hip).x - 9, -9), Vector2(17, 10)), "mod": limb})
	return out
