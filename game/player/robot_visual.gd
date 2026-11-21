extends Node2D
## Visual cut-out do robô (estilo papel e giz). Partes em PNG 4x (art/out/game/robo); pernas e braços desenhados aqui.
## A animação é toda por código e só lê o estado do robô: nunca atrasa nem trava o controle.
## Tela das partes: 128x128 (px de jogo), origem do robô (pés no chão) em (64,120). Frente local = +x.
##
## Pose (Dictionary) usada pelo desenho:
##   expr, body_off (Vector2), lean (rad, + = para a frente), feet [Vector2, Vector2] (deslocamento dos pés),
##   knee [Vector2, Vector2] (dobra das pernas), hb_off / hf_off (mão de trás / da frente), hammer_ang, ant (antena)

const Kit := preload("res://ui/kit.gd")
const ORIGIN := Vector2(64, 120)
const GRIP := Vector2(32, 56)          # pega dentro da textura da marreta (64x64)
const HAMMER_REST := 0.35
const STRIDE := 46.0
const HELD_TOOLS := ["furadeira", "laser", "soprador", "congelador", "estilingue", "laco", "gancho", "relogio"]
const TOOL_GRIP := {"laser": Vector2(19, 46), "congelador": Vector2(19, 46), "soprador": Vector2(18, 48), "furadeira": Vector2(24, 44),
	"estilingue": Vector2(30, 54), "laco": Vector2(24, 40), "gancho": Vector2(14, 52), "relogio": Vector2(32, 52)}
const TOOL_SIZE := 44.0                   # px percorridos por ciclo de passada (pés não deslizam)

# aparência
var color_idx := 0
var acc := 0
var model := 0
var has_hammer := true
var skin := {}                         # personalização da Garagem (vazio = robô padrão na cor do jogador)
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
var hanging := false
var grip := 1.0
var on_wall := false
var sweat_t := 0.0
var drops: Array = []                  # gotas de suor quando a aderência está acabando
var hang_snap := Vector2.ZERO          # ao agarrar a borda: o desenho começa onde o robô estava e desliza até a quina
var smoke_t := 0.0

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
	var lk := {"color": color_idx, "model": model, "acc": acc, "hammer": has_hammer, "skin": skin}
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
	var face_to := float(r.facing)
	if r.wall_sliding and r.wall_side != 0 and not r.hanging:
		face_to = -float(r.wall_side)   # de costas para a parede, pronto para o pulo de parede
	shown_facing = move_toward(shown_facing, face_to, dt * 16.0)
	run_k = move_toward(run_k, clampf(spd / float(c["max_run"]), 0.0, 1.0) if on_floor else 0.0, dt * 8.0)
	air_k = move_toward(air_k, 0.0 if on_floor else 1.0, dt * 10.0)
	wall_k = move_toward(wall_k, 1.0 if r.wall_sliding else 0.0, dt * 12.0)
	vy = v.y
	# passada pela distância percorrida + poeirinha a cada passo
	if on_floor and spd > 30.0:
		var before := int(phase / PI)
		phase += spd * dt / STRIDE * TAU
		if int(phase / PI) != before:
			if spd > 250.0 and int(phase / PI) % 2 == 0:
				Audio.play("passo", 0.92 + r.pid * 0.08, -8.0)   # 1 passo por passada, baixinho
			if spd > 300.0:
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
	target += wall_k * 0.12   # de costas para a parede, inclina para longe dela
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
	hang_snap = hang_snap.lerp(Vector2.ZERO, minf(dt * 18.0, 1.0))
	position = hang_snap
	hanging = r.hanging
	grip = r.grip
	on_wall = r.wall_sliding
	if r.hanging or (r.wall_sliding and r.grip < 0.5):
		expression = "esforco"
	if (r.hanging or r.wall_sliding) and r.grip < 0.35:
		expression = "susto"
		sweat_t -= dt
		if sweat_t <= 0.0:
			sweat_t = 0.25
			drops.append({"p": Vector2(randf_range(-14, 14), -86), "v": Vector2(randf_range(-40, 40), -60), "t": 0.0})
	for d in drops:
		d["t"] += dt
		d["v"].y += 500.0 * dt
		d["p"] += d["v"] * dt
	drops = drops.filter(func(d): return d["t"] < 0.6)
	# piscando enquanto invulnerável
	modulate.a = 0.45 if r.invuln > 0.0 and fmod(t, 0.16) < 0.08 else 1.0
	# muito amassado: solta fumaça (e faísca acima de 120%)
	if r.dmg >= 80.0 and r.alive:
		smoke_t -= dt
		if smoke_t <= 0.0:
			smoke_t = 0.5 if r.dmg < 120.0 else 0.25
			r.main.dust(r.position + Vector2(randf_range(-10, 10), -78), 0.55)
			if r.dmg >= 120.0:
				r.main.spark(r.position + Vector2(0, -70), 1)
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
	# pendurado na borda: as duas mãos na quina, corpo esticado embaixo, pés raspando na parede
	var tremble := 0.0
	if hanging or on_wall:
		tremble = clampf((0.45 - grip) / 0.45, 0.0, 1.0)
	if hanging:
		var slip := clampf((0.3 - grip) / 0.3, 0.0, 1.0) * 6.0   # as mãos escorregam no fim
		p["hb_abs"] = Vector2(14, -60 + slip) + Vector2(sin(t * 55.0), cos(t * 47.0)) * 1.5 * tremble
		p["hf_abs"] = Vector2(23, -61 + slip) + Vector2(cos(t * 51.0), sin(t * 43.0)) * 1.5 * tremble
		lean = lerpf(lean, 0.1, 0.5)
		bob = 5.0 + sin(t * 3.0) * 1.0
		var scr := 2.0 + 10.0 * tremble   # pés tentam escalar quando cansa
		for i in 2:
			var ph := t * (6.0 + 14.0 * tremble) + i * PI
			feet[i] = Vector2(8.0 + i * 3.0, -2.0 - maxf(sin(ph), 0.0) * scr)
			knee[i] = Vector2(5, 0)
		p["hammer_ang"] = -2.7   # marreta pendurada para trás, longe da parede
	# escorregando na parede (de costas para ela): mão de trás espalmada na parede, pé de trás apoiado
	if wall_k > 0.0 and not hanging:
		var shake := Vector2(sin(t * 60.0), cos(t * 53.0)) * 1.6 * tremble
		hb = hb.lerp(Vector2(-16, -18) + shake, wall_k)
		hf = hf.lerp(Vector2(6, -16), wall_k)
		feet[0] = feet[0].lerp(Vector2(-12, -10), wall_k)
		feet[1] = feet[1].lerp(Vector2(4, 0), wall_k)
		knee[0] = knee[0].lerp(Vector2(-3, 0), wall_k)
	# usando item: ferramenta na mão com o braço esticado, recuo no disparo; arremesso com o braço
	var us: Dictionary = robot.fx_flags().get("usando", {}) if robot != null and robot.has_method("fx_flags") else {}
	var uk: String = us.get("kind", "")
	if uk in HELD_TOOLS:
		var kick := 0.0
		var fire: float = us.get("fire", -1.0)
		if uk in ["laser", "congelador", "estilingue", "gancho", "laco"] and fire >= 0.0:
			kick = clampf(1.0 - fire / 0.18, 0.0, 1.0)   # coice do disparo
		var buzz := Vector2(sin(t * 80.0), cos(t * 71.0)) * (1.6 if uk in ["furadeira", "soprador"] else 0.0)
		if uk == "laser" and fire < 0.0:
			buzz = Vector2(sin(t * 90.0), 0) * 1.4 * float(us.get("k", 0.0)) * 2.0   # tremendo na carga
		p["hf_abs"] = Vector2(21 - 9.0 * kick, -34 - 4.0 * kick) + buzz
		p["hb_abs"] = Vector2(13 - 7.0 * kick, -31 - 3.0 * kick) + buzz * 0.6
		p["tool"] = uk
		p["tool_ang"] = -0.35 * kick
		lean = lerpf(lean, 0.06 - 0.12 * kick, 0.5)
		for i in 2:
			feet[i] = feet[i].lerp(Vector2(-4.0 + i * 8.0, 0), 0.6)   # pés firmes
	elif uk == "arremesso":
		var k: float = us.get("k", 0.0)
		hb = Vector2(-14, -30).lerp(Vector2(20, -18), clampf((k - 0.15) / 0.35, 0.0, 1.0))
		lean = lerpf(lean, -0.1 if k < 0.25 else 0.14, 0.4)
	elif uk == "aponta":
		hb = Vector2(18, -52) + Vector2(sin(t * 60.0), 0) * 1.2
	# furadeira / laser / teletransporte: braços esticados para a frente
	if robot != null and robot.forced_t > 0.0 and not (uk in HELD_TOOLS):
		hb = Vector2(16, -6)
		hf = Vector2(20, -4)
		for i in 2:
			feet[i] = Vector2(-6.0 + i * 4.0, -2.0)
	# botas de mola: a mola estica no ar e encolhe ao tocar o chão
	p["spring_k"] = 1.0 + 0.5 * air_k - 0.4 * clampf(1.0 - sq.y, 0.0, 1.0)
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
	if not p.has("hammer_ang") or not hanging:
		p["hammer_ang"] = ang
	p["ant"] = ant
	return p

func _draw() -> void:
	draw_robot(self, look(), current_pose())
	_draw_tag()
	# suor
	for d in drops:
		draw_circle(d["p"], 2.6, Color(0.55, 0.8, 1.0, 1.0 - d["t"] / 0.6))
	# medidor de aderência (parede/borda): anel que esvazia acima da cabeça
	if (hanging or on_wall or (robot != null and not robot.is_on_floor() and grip < 0.999)) and grip < 0.999 and robot != null and robot.alive:
		var c := Vector2(0, -104)
		var col := Color("#5cc45c").lerp(Color("#f2c84b"), clampf((0.7 - grip) / 0.35, 0.0, 1.0)).lerp(Color("#d42035"), clampf((0.35 - grip) / 0.3, 0.0, 1.0))
		if grip < 0.3 and fmod(t, 0.2) < 0.1:
			col = Color.WHITE
		var sx := signf(scale.x) if scale.x != 0.0 else 1.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / maxf(absf(scale.x), 0.2) * sx, 1.0 / maxf(scale.y, 0.2)))
		draw_circle(c, 13.0, Color(0.12, 0.18, 0.2, 0.55))
		draw_arc(c, 10.0, -PI / 2.0, -PI / 2.0 + TAU * grip, 24, col, 5.0, true)
		draw_set_transform(Vector2.ZERO)

## Setinha na cor do jogador acima da cabeça ("P1"): identifica quem é quem mesmo com robôs da Garagem.
func _draw_tag() -> void:
	if robot == null or not robot.alive or not robot.get("active"):
		return
	var sx := signf(scale.x) if scale.x != 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / maxf(absf(scale.x), 0.2) * sx, 1.0 / maxf(scale.y, 0.2)))
	var meter: bool = (hanging or on_wall or not robot.is_on_floor()) and grip < 0.999
	var y := -150.0 if meter else -116.0
	var col: Color = Data.COLORS[color_idx % Data.COLORS.size()]
	draw_colored_polygon(PackedVector2Array([Vector2(-9, y), Vector2(9, y), Vector2(0, y + 10)]), col)
	draw_polyline(PackedVector2Array([Vector2(-9, y), Vector2(9, y), Vector2(0, y + 10), Vector2(-9, y)]), Data.INK, 2.0, true)
	Kit.text(self, Vector2(-30, y - 4), "P%d" % (robot.pid + 1), 22, col, HORIZONTAL_ALIGNMENT_CENTER, 60, 5, Data.INK)
	draw_set_transform(Vector2.ZERO)

## Poses prontas para telas (entrada e vitória).
static func idle_pose(time: float) -> Dictionary:
	return {"expr": "piscar" if fmod(time, 3.3) < 0.12 else "normal", "body_off": Vector2(0, sin(time * 2.4) * 0.8),
		"lean": 0.0, "feet": [Vector2.ZERO, Vector2.ZERO], "knee": [Vector2(1.5, 0), Vector2(1.5, 0)],
		"hb_off": Vector2(0, sin(time * 2.4) * 0.6), "hf_off": Vector2.ZERO, "hammer_ang": HAMMER_REST,
		"ant": sin(time * 3.1) * 0.12}

static func victory_pose(time: float, danca := 0) -> Dictionary:
	var hop := -absf(sin(time * 6.0)) * 8.0
	var p := idle_pose(time)
	match danca:
		1:   # marreteiro: bate a ferramenta no chão sem parar
			var k := fposmod(time * 2.2, 1.0)
			var sw := -2.4 + 2.6 * smoothstep(0.0, 0.35, k) - 2.6 * smoothstep(0.55, 1.0, k)
			p["expr"] = "vitoria" if k > 0.3 else "esforco"
			p["lean"] = 0.18 * smoothstep(0.0, 0.35, k)
			p["body_off"] = Vector2(0, -3.0 * (1.0 - smoothstep(0.0, 0.3, k)))
			p["hammer_ang"] = sw
			p["hf_off"] = Vector2(6, -14 + 16 * smoothstep(0.0, 0.35, k))
			p["hb_off"] = Vector2(-2, -18)
			p["ant"] = sin(time * 14.0) * 0.4
			return p
		2:   # pião: gira no lugar (o desenho vira de lado a lado) com os braços abertos
			p["expr"] = "vitoria"
			p["spin"] = cos(time * 9.0)
			p["body_off"] = Vector2(0, -absf(sin(time * 9.0)) * 4.0)
			p["hb_off"] = Vector2(-10, -12)
			p["hf_off"] = Vector2(10, -12)
			p["hammer_ang"] = -1.2
			p["ant"] = sin(time * 18.0) * 0.5
			return p
		3:   # robozinho: braços travados em ângulos, cabeça para os lados
			var st := int(time * 4.0) % 4
			p["expr"] = "vitoria" if st % 2 == 0 else "normal"
			p["lean"] = [-0.12, 0.0, 0.12, 0.0][st]
			p["hb_off"] = [Vector2(-6, -20), Vector2(-4, 0), Vector2(-6, -20), Vector2(-4, 0)][st]
			p["hf_off"] = [Vector2(4, 0), Vector2(6, -20), Vector2(4, 0), Vector2(6, -20)][st]
			p["feet"] = [Vector2(-2, [0, -6, 0, 0][st]), Vector2(2, [0, 0, 0, -6][st])]
			p["hammer_ang"] = [0.35, -1.0, 0.35, -1.0][st]
			p["ant"] = [0.4, -0.4, 0.4, -0.4][st]
			return p
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
	var spring_h := 0.0
	if lk.get("fx", {}).get("mola", false):
		spring_h = 11.5 * float(pose.get("spring_k", 1.0))
		base = base * Transform2D(0.0, Vector2(0, -spring_h))   # botas de mola: o robô fica em cima das molas
	var col_idx: int = lk["color"]
	var sk: Dictionary = lk.get("skin", {})
	var custom := not sk.is_empty()
	var mname: String = Data.MODELS[sk.get("model", lk["model"]) if custom else lk["model"]]
	var body := Data.tex(("robo/corpo_%s" % mname) if custom else ("robo/corpo_%s_p%d" % [mname, col_idx + 1]))
	if body == null or Data.robot_meta.is_empty():
		return
	if pose.has("spin"):   # comemoração "pião": achata na horizontal passando pelo meio
		var sp: float = pose["spin"]
		base = base * Transform2D(0.0, Vector2(signf(sp) * maxf(absf(sp), 0.32), 1.0), 0.0, Vector2.ZERO)
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := limb_color(sk) if custom else Color(Data.robot_meta["membros"][col_idx])
	var tool_tex := Data.tool_tex(sk.get("ferramenta", 0)) if custom else "robo/marreta"
	var q := Vector2(0.25, 0.25)
	# corpo inclina em torno do quadril
	var hips: Array = g["hips"]
	var pivot := (_v(hips[0]) + _v(hips[1])) / 2.0
	var bx := Transform2D(0.0, pose["body_off"] + pivot) * Transform2D(pose["lean"], Vector2.ZERO) * Transform2D(0.0, -pivot)
	var sh: Array = g["shoulders"]
	var hf: Vector2 = pose["hf_abs"] if pose.has("hf_abs") else bx * _v(g["hand_front"]) + pose["hf_off"]
	var hb: Vector2 = pose["hb_abs"] if pose.has("hb_abs") else bx * _v(g["hand_back"]) + pose["hb_off"]
	# marreta (atrás do corpo)
	var fx: Dictionary = lk.get("fx", {})
	var tool: String = pose.get("tool", "")
	if lk.get("hammer", true) and tool == "":
		var big: bool = fx.get("martelao", false)
		ci.draw_set_transform_matrix(base * Transform2D(pose["hammer_ang"], q * (1.55 if big else 1.0), 0.0, hf))
		ci.draw_texture(Data.tex(tool_tex), -GRIP * 4.0, Color(1.0, 0.82, 0.3) if big else Color.WHITE)
	# pernas + botas
	var foot := Data.tex("robo/pe")
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip: Vector2 = bx * _v(hips[i])
		var fp: Vector2 = Vector2(_v(hips[i]).x + s * 4.0, -4.0) + pose["feet"][i]
		_limb(ci, base, hip, fp, limb, pose["knee"][i])
		var now := Time.get_ticks_msec() / 1000.0
		if fx.get("mola", false):
			# bota de mola (mesma arte do ícone do item): cano da bota no pé, mola embaixo que estica e encolhe
			ci.draw_set_transform_matrix(base)
			var tex := Data.tex("itens/mola")
			var k := 0.5
			var anchor := fp + Vector2(s * 1.5, 1.0)
			var stretch := float(pose.get("spring_k", 1.0))
			# cano + bota (região de cima do ícone: y 0..40)
			ci.draw_texture_rect_region(tex, Rect2(anchor - Vector2(34, 38) * k, Vector2(64, 40) * k), Rect2(0, 0, 192, 120))
			# mola + sola (y 40..64), esticada conforme o pulo
			ci.draw_texture_rect_region(tex, Rect2(anchor + Vector2(-34, 2) * k, Vector2(64 * k, 24 * k * stretch)), Rect2(0, 120, 192, 72))
		var foot_col := limb
		if fx.get("foguete", false):
			foot_col = Color("#d42035")   # bota-foguete vermelha
		if not fx.get("mola", false):   # com as botas de mola, a bota substitui o pé
			ci.draw_set_transform_matrix(base * Transform2D(0.0, q * (0.82 if fx.get("foguete", false) else 0.72), 0.0, fp + Vector2(s * 1.5, 0.5)))
			ci.draw_texture(foot, -Vector2(12, 7) * 4.0, foot_col)
		if fx.get("foguete", false):
			ci.draw_set_transform_matrix(base)
			var noz := fp + Vector2(s * 1.5 - 3.0, 4.0)
			ci.draw_rect(Rect2(noz - Vector2(3, 0), Vector2(8, 4)), Color("#3e4752"))
			ci.draw_colored_polygon(PackedVector2Array([fp + Vector2(s * 1.5 - 8.0, -3.0), fp + Vector2(s * 1.5 - 12.0, 3.0), fp + Vector2(s * 1.5 - 6.0, 2.0)]), Color("#f2c84b"))
			var fl: float = (9.0 + sin(now * 50.0 + i) * 3.0) if fx.get("foguete_on", false) else (2.5 + sin(now * 30.0 + i) * 1.0)
			ci.draw_colored_polygon(PackedVector2Array([noz + Vector2(-3, 4), noz + Vector2(1, 4 + fl), noz + Vector2(5, 4)]), Color("#f6a23a"))
			ci.draw_colored_polygon(PackedVector2Array([noz + Vector2(-1, 4), noz + Vector2(1, 4 + fl * 0.6), noz + Vector2(3, 4)]), Color("#fff1b8"))
		if fx.get("patins", false):
			# patins: base vermelha com faixa e duas rodinhas girando embaixo do pé
			ci.draw_set_transform_matrix(base)
			var sp := fp + Vector2(s * 1.5, 4.0)
			var plate := Rect2(sp + Vector2(-11, -2), Vector2(24, 7))
			ci.draw_rect(plate.grow(1.5), Color("#2a1a2e"))
			ci.draw_rect(plate, Color("#e8503a"))
			ci.draw_rect(Rect2(plate.position + Vector2(0, 2), Vector2(24, 2)), Color("#ffcf3a"))
			for wx in [-6.0, 8.0]:
				var wc: Vector2 = sp + Vector2(float(wx), 8.0)
				ci.draw_circle(wc, 4.6, Color("#2a1a2e"))
				ci.draw_circle(wc, 3.2, Color("#9fd8ff"))
				var spin: float = now * 25.0 + float(wx)
				ci.draw_line(wc, wc + Vector2.from_angle(spin) * 3.0, Color("#2a1a2e"), 1.4)
		if fx.get("cola", false):
			ci.draw_set_transform_matrix(base)
			ci.draw_circle(fp + Vector2(s * 1.5, 3.0), 5.5, Color(0.97, 0.96, 0.9))
			ci.draw_circle(fp + Vector2(s * 1.5 + 4.0, 5.0), 3.0, Color(0.97, 0.96, 0.9))
			ci.draw_rect(Rect2(fp + Vector2(s * 1.5 - 1.0, 6.0), Vector2(2, 3.0 + 2.0 * fposmod(now * 1.5 + i * 0.5, 1.0))), Color(0.97, 0.96, 0.9))
	_limb(ci, base, bx * _v(sh[0]), hb, limb, Vector2(0, 3))
	# corpo + rosto + antena (mola) ou chapéu
	ci.draw_set_transform_matrix(base * bx * Transform2D(0.0, q, 0.0, -ORIGIN))
	if custom:
		ci.draw_texture(body, Vector2.ZERO, body_color(sk))
		var pat: int = sk.get("padrao", 0)
		if pat > 0:
			ci.draw_texture(Data.tex("robo/padrao_%s_%s" % [Data.PADROES[pat], mname]), Vector2.ZERO, _pal(sk.get("cor2", 9)))
		ci.draw_texture(Data.tex("robo/detalhe_" + mname), Vector2.ZERO)
	else:
		ci.draw_texture(body, Vector2.ZERO)
	ci.draw_texture(Data.tex("robo/rosto_%s_%s" % [mname, pose["expr"]]), Vector2.ZERO)
	var face_item: int = sk.get("rosto", 0) if custom else 0
	if face_item > 0 and pose["expr"] != "eliminado":
		var ey: Array = g["eyes"]
		var e0 := _v(ey[0])
		var e1 := _v(ey[1])
		var fs := e0.distance_to(e1) / 22.0
		ci.draw_set_transform_matrix(base * bx * Transform2D(0.0, (e0 + e1) / 2.0))
		ci.draw_texture_rect(Data.tex("robo/rosto_item_" + Data.ROSTOS[face_item]), Rect2(Vector2(-32, -16) * fs, Vector2(64, 32) * fs), false)
	var accessory: int = sk.get("chapeu", 0) if custom else lk.get("acc", 0)
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
	var held: String = fx.get("item", "")
	var tnow := Time.get_ticks_msec() / 1000.0
	if fx.get("ima", false):
		held = "ima"
	if held != "" and not fx.get("furando", false) and tool == "":
		# o item guardado aparece na mão de trás, balançando
		ci.draw_set_transform_matrix(base * Transform2D(-0.3 + sin(tnow * 4.0) * 0.12, Vector2.ONE, 0.0, hb + Vector2(-2, -8)))
		ci.draw_texture_rect(Data.tex("itens/" + held), Rect2(-16, -16, 32, 32), false)
		if held == "dinamite" and fmod(tnow, 0.16) < 0.08:
			ci.draw_circle(Vector2(8, -12), 2.2, Color("#fff4c8"))
		if held == "ima":
			for k in 2:
				var rr := 10.0 + fposmod(tnow * 30.0 + k * 9.0, 18.0)
				ci.draw_arc(Vector2(0, -6), rr, -2.4, -0.7, 8, Color(0.83, 0.13, 0.21, 1.0 - rr / 28.0), 1.4, true)
	if fx.get("martelao", false) and fmod(tnow, 0.9) < 0.15:
		ci.draw_set_transform_matrix(base)
		var gl := hf + Vector2.from_angle(pose["hammer_ang"] - 1.2) * 14.0
		ci.draw_line(gl - Vector2(5, 0), gl + Vector2(5, 0), Color.WHITE, 1.6, true)
		ci.draw_line(gl - Vector2(0, 5), gl + Vector2(0, 5), Color.WHITE, 1.6, true)
	if tool != "":
		# ferramenta presa na mão da frente (o cabo fica embaixo da mão)
		var sc := TOOL_SIZE / 64.0
		var grip: Vector2 = TOOL_GRIP[tool]
		ci.draw_set_transform_matrix(base * Transform2D(float(pose.get("tool_ang", 0.0)), hf))
		ci.draw_texture_rect(Data.tex("itens/" + tool), Rect2(-grip * sc, Vector2(TOOL_SIZE, TOOL_SIZE)), false)
		if tool == "furadeira":
			# broca girando na ponta
			var tip := (Vector2(62, 26) - grip) * sc
			var spin := Time.get_ticks_msec() / 1000.0 * 60.0
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-2, -6), tip + Vector2(20, 0), tip + Vector2(-2, 6)]), Color("#c9d1d8"))
			for k in 4:
				var u := fposmod(spin * 0.1 + k * 0.25, 1.0)
				var x := lerpf(-1.0, 18.0, u)
				var hh := lerpf(6.0, 0.8, u)
				ci.draw_line(tip + Vector2(x, -hh), tip + Vector2(x + 4.0, hh), Color("#5a6370"), 1.6, true)
	_limb(ci, base, bx * _v(sh[1]), hf, limb, Vector2(0, 3))
	var hand := Data.tex("robo/mao")
	for p in [hb, hf]:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q, 0.0, p))
		ci.draw_texture(hand, -Vector2(8, 8) * 4.0)
	ci.draw_set_transform_matrix(base)

static func _pal(i: int) -> Color:
	return Data.PALETA[posmod(i, Data.PALETA.size())]

## Cor que pinta o corpo neutro (a base da arte é #f2f2f2: compensa para a cor sair fiel).
static func body_color(sk: Dictionary) -> Color:
	var c := _pal(sk.get("cor", 0))
	return Color(c.r * 1.06, c.g * 1.06, c.b * 1.06)

## Braços e pernas: a cor do corpo escurecida puxando para o roxo (como na arte original).
static func limb_color(sk: Dictionary) -> Color:
	return _pal(sk.get("cor", 0)).darkened(0.42).lerp(Color("#3a2a5a"), 0.18)

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
	var sk: Dictionary = lk.get("skin", {})
	var custom := not sk.is_empty()
	var mname: String = Data.MODELS[sk.get("model", lk["model"]) if custom else lk["model"]]
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := limb_color(sk) if custom else Color(Data.robot_meta["membros"][lk["color"]])
	var out := []
	if custom:
		var tx := [Data.tex("robo/corpo_" + mname)]
		var md := [body_color(sk)]
		if int(sk.get("padrao", 0)) > 0:
			tx.append(Data.tex("robo/padrao_%s_%s" % [Data.PADROES[sk["padrao"]], mname]))
			md.append(_pal(sk.get("cor2", 9)))
		tx.append_array([Data.tex("robo/detalhe_" + mname), Data.tex("robo/rosto_%s_eliminado" % mname)])
		md.append_array([Color.WHITE, Color.WHITE])
		out.append({"tex": tx, "mods": md, "rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	else:
		out.append({"tex": [Data.tex("robo/corpo_%s_p%d" % [mname, lk["color"] + 1]), Data.tex("robo/rosto_%s_eliminado" % mname)],
			"rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	var hat_i: int = sk.get("chapeu", 0) if custom else lk.get("acc", 0)
	if hat_i > 0:
		var h: Array = g["hat"]
		var hs := float(h[2])
		out.append({"tex": [Data.tex("robo/acc_" + Data.ACCS[hat_i])], "rect": Rect2(_v(h) - Vector2(64, 64) * hs, Vector2(128, 128) * hs), "mod": Color.WHITE})
	else:
		out.append({"tex": [Data.tex("robo/antena_" + mname)], "rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	if lk.get("hammer", true):
		out.append({"tex": [Data.tex(Data.tool_tex(sk.get("ferramenta", 0)) if custom else "robo/marreta")], "rect": Rect2(_v(g["hand_front"]) - GRIP, Vector2(64, 64)), "mod": Color.WHITE})
	for hp in [g["hand_back"], g["hand_front"]]:
		out.append({"tex": [Data.tex("robo/mao")], "rect": Rect2(_v(hp) - Vector2(8, 8), Vector2(16, 16)), "mod": Color.WHITE})
	for hip in g["hips"]:
		out.append({"tex": [Data.tex("robo/pe")], "rect": Rect2(Vector2(_v(hip).x - 9, -9), Vector2(17, 10)), "mod": limb})
	return out
