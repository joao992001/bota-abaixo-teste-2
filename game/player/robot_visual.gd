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
## Spells (modes/spells.gd): textura, tamanho na mão e ponto de pega (em px da arte de design, que é 2x a textura/2)
const SPELL_TOOLS := {"S01": ["s01_canhao", Vector2(52, 26), Vector2(30, 34)], "S03": ["s03_canhao", Vector2(54, 27), Vector2(26, 40)],
	"S06": ["s06_ima", Vector2(42, 30), Vector2(14, 40)]}
const SPELL_HELD := {"S01": "s01_canhao", "S03": "s03_canhao", "S06": "s06_ima", "S10": "icone_engenharia", "S11": "s11_portal",
	"S13": "icone_transformacao"}

# aparência
var color_idx := 0
var model := 0
var has_hammer := true
# estado da animação
var expression := "normal"
var sq := Vector2.ONE                  # squash/stretch visual (saída das molas)
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
var prev_vel := Vector2.ZERO
var robot = null
var hanging := false
var grip := 1.0
var on_wall := false
var sweat_t := 0.0
var drops: Array = []                  # gotas de suor quando a aderência está acabando
var hang_snap := Vector2.ZERO          # ao agarrar a borda: o desenho começa onde o robô estava e desliza até a quina
var smoke_t := 0.0
# molas: [valor, velocidade]. Tudo que muda de pose passa por uma mola: chega com inércia e um leve "passar do ponto".
var s_lean := [0.0, 0.0]
var s_bob := [0.0, 0.0]
var s_sqx := [1.0, 0.0]
var s_sqy := [1.0, 0.0]
var s_hb := [Vector2.ZERO, Vector2.ZERO]
var s_hf := [Vector2.ZERO, Vector2.ZERO]
var s_ham := [HAMMER_REST, 0.0]
var s_rot := [0.0, 0.0]
# ações
var atk_kind := ""
var jab_alt := false                   # golpes rápidos alternam (de cima / de baixo)
var smear_from := 0.0                  # rastro do golpe: do ângulo do preparo até o atual
var smear_a := 0.0
var hurt_t := 0.0
var hurt_s := 0.0
var hurt_lean := 0.0
var flash_t := 0.0
var tumble := 0.0                      # giro acumulado do arremesso (rad)
var tumbling := false
var flip_t := -1.0                     # pulo duplo (0..1): chute, cambalhota, abre
var heavy_was_cd := false
var land_t := 0.0                      # amortecimento depois de pousar arremessado
var dodge_ground := false
var dodge_dir := Vector2.ZERO
var dodged_flash := 0.0
var idle_t := 0.0
var fidget_t := -1.0
var fidget_kind := 0
var next_fidget := 5.0
var dmg_level := 0
var spark_t := 0.0
var panel := [0.0, 0.0]               # plaquinha solta (amassado forte) balançando como pêndulo
var ghosts: Array = []                 # rastro (esquiva, arremesso forte, marretada)
var ghost_i := 0
var ghost_tick := 0
const DMG_STEPS := [35.0, 75.0, 120.0]
const PIVOT := Vector2(0, -44)

func setup(col_idx: int, mdl := 0) -> void:
	color_idx = col_idx
	model = mdl
	blink_t = randf_range(0.5, 3.0)
	next_fidget = randf_range(4.0, 7.0)

func _ready() -> void:
	for k in 5:
		var g := Node2D.new()
		g.top_level = true
		g.z_index = -1
		g.visible = false
		g.set_meta("snap", {})
		g.draw.connect(_draw_ghost.bind(g))
		add_child(g)
		ghosts.append(g)

# ---------------------------------------------------------------- gatilhos (chamados pelo robô)
func land(hard := 0.0, launched := false) -> void:
	s_sqx[0] = 1.18 + 0.3 * hard + (0.12 if launched else 0.0)
	s_sqy[0] = 0.84 - 0.22 * hard - (0.08 if launched else 0.0)
	s_bob[1] += 90.0 + 160.0 * hard
	if launched:
		land_t = 0.28
		tumbling = false
		tumble = round(tumble / TAU) * TAU

func stretch() -> void:
	s_sqx[0] = 0.8
	s_sqy[0] = 1.24

## Pulo duplo do propulsor em 3 tempos: CHUTE (pernas esticadas, braços para cima, jato nos pés),
## CAMBALHOTA encolhida (abraça os joelhos, marreta colada) e ABRE (braços abertos, volta a cair).
const DJ_LEN := 0.42
const DJ_KICK := 0.12
const DJ_OPEN := 0.72

func double_jump() -> void:
	flip_t = 0.0
	s_sqx[0] = 0.72
	s_sqy[0] = 1.34
	if robot != null:
		var m = robot.main
		m.ring_fx(robot.position + Vector2(0, 10), 1.0)
		m.ring_fx(robot.position + Vector2(0, 26), 0.6)
		m.dust(robot.position + Vector2(-10, 14), 0.5)
		m.dust(robot.position + Vector2(10, 14), 0.5)

## Apertou a marretada ainda recarregando: a marreta treme e faz "clanc".
func denied() -> void:
	s_ham[1] += 18.0
	Audio.play("menu_negado", 0.8, -8.0)

## Marretada cancelada no preparo: a marreta desce de volta (a mola leva) e some o rastro.
func heavy_cancel() -> void:
	smear_a = 0.0
	s_sqx[0] = 0.9
	s_sqy[0] = 1.08
	Audio.play("marreta_vento", 0.6, -10.0)

func attack(kind: String) -> void:
	atk_kind = kind
	if kind == "rapido":
		jab_alt = not jab_alt
	idle_t = 0.0
	fidget_t = -1.0

func dodge(dir: Vector2, ground: bool) -> void:
	dodge_dir = dir
	dodge_ground = ground
	flip_t = -1.0
	s_sqx[0] = 1.3
	s_sqy[0] = 0.78
	_snap_ghost(0.55)

func hurt(strength: float, dir: int) -> void:
	hurt_t = 0.24
	hurt_s = strength
	flash_t = 0.08
	var fs := signf(shown_facing) if shown_facing != 0.0 else 1.0
	hurt_lean = (float(dir) * fs if dir != 0 else -1.0) * (0.25 + 0.3 * strength)
	s_sqx[0] = 0.72
	s_sqy[0] = 1.22
	s_lean[1] += hurt_lean * 14.0
	flip_t = -1.0
	fidget_t = -1.0

func launch(v: Vector2) -> void:
	tumbling = v.length() >= float(Data.ctrl["arremesso"]["giro_min_vel"])
	flip_t = -1.0
	if tumbling:
		_snap_ghost(0.4)

func look() -> Dictionary:
	var lk := {"color": color_idx, "model": model, "hammer": has_hammer, "dmg": dmg_level,
		"ham_cd": robot != null and robot.get("heavy_cd") != null and robot.heavy_cd > 0.0}
	if robot != null and robot.has_method("fx_flags"):
		lk["fx"] = robot.fx_flags()
	return lk

static func _spring(sp: Array, target, dt: float, f: float, z: float):
	var w := TAU * f
	sp[1] += (-2.0 * z * w * sp[1] - w * w * (sp[0] - target)) * dt
	sp[0] += sp[1] * dt
	return sp[0]

static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

# ---------------------------------------------------------------- quadro a quadro
func tick(r, dt: float) -> void:
	robot = r
	if r.hitstop > 0.0:
		# impacto: tudo congela por um instante; quem apanhou treme
		var amp := 3.0 if hurt_t > 0.0 else 1.0
		position = hang_snap + Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.5)
		flash_t = maxf(flash_t - dt * 0.3, 0.0)
		queue_redraw()
		return
	t += dt
	var c: Dictionary = Data.ctrl
	var v: Vector2 = r.velocity
	var on_floor: bool = r.is_on_floor()
	var spd := absf(v.x)
	var face_to := float(r.facing)
	if r.wall_sliding and r.wall_side != 0 and not r.hanging:
		face_to = -float(r.wall_side)   # de costas para a parede, pronto para o pulo de parede
	if signf(face_to) != signf(shown_facing):
		# virada: troca de lado na hora (controle responsivo) com um "pivô" achatado que volta na mola
		shown_facing = face_to
		s_sqx[0] = 0.7
		s_sqy[0] = 1.06
		s_lean[1] -= 3.0
	run_k = move_toward(run_k, clampf(spd / float(c["max_run"]), 0.0, 1.0) if on_floor else 0.0, dt * 7.0)
	air_k = move_toward(air_k, 0.0 if on_floor else 1.0, dt * 9.0)
	wall_k = move_toward(wall_k, 1.0 if r.wall_sliding else 0.0, dt * 12.0)
	vy = v.y
	hurt_t = maxf(hurt_t - dt, 0.0)
	flash_t = maxf(flash_t - dt, 0.0)
	land_t = maxf(land_t - dt, 0.0)
	dodged_flash = maxf(dodged_flash - dt * 3.0, 0.0)
	if flip_t >= 0.0:
		flip_t += dt / DJ_LEN
		if flip_t >= 1.0 or on_floor or r.stun_t > 0.0:
			# acabou (ou pousou no meio): termina o giro PARA A FRENTE até ficar de pé, nunca desgira
			var cur := float(s_rot[0])
			tumble = ceil(cur / TAU - 0.15) * TAU if flip_t < 1.0 else round(cur / TAU) * TAU
			flip_t = -1.0
	if r.atk == "":
		atk_kind = ""
	# passada pela distância percorrida + poeirinha a cada passo
	if on_floor and spd > 30.0 and r.dodge_t <= 0.0:
		var before := int(phase / PI)
		phase += spd * dt / STRIDE * TAU
		if int(phase / PI) != before:
			if spd > 250.0 and int(phase / PI) % 2 == 0:
				Audio.play("passo", 0.92 + r.pid * 0.08, -8.0)   # 1 passo por passada, baixinho
			if spd > 300.0:
				r.main.dust(r.position + Vector2(-r.facing * 10, 0), 0.45)
	has_hammer = r.hammer_left > 0 or r.atk != ""
	# marretada pesada recarregou: brilho na marreta + "plim"
	if heavy_was_cd and r.heavy_cd <= 0.0:
		r.main.spark(r.position + Vector2(r.facing * 22, -78), 3)
		Audio.play("item", 1.7, -12.0)
	heavy_was_cd = r.heavy_cd > 0.0
	# arremesso: gira enquanto voa rápido sem controle; ao recuperar, volta de pé com um "pop"
	if tumbling:
		var sp := v.length()
		if r.stun_t <= 0.0 and (r.recover_t < r.recover_len * 0.55 or sp < 420.0):
			tumbling = false
			tumble = round(tumble / TAU) * TAU
			s_sqx[0] = 1.15
			s_sqy[0] = 0.85
			r.main.ring_fx(r.position + Vector2(0, -44), 0.55)
		else:
			var fs := signf(shown_facing) if shown_facing != 0.0 else 1.0
			tumble += signf(v.x) * fs * clampf(sp / 85.0, 4.0, 22.0) * dt
			ghost_tick += 1
			if sp > 900.0 and ghost_tick % 3 == 0:
				_snap_ghost(0.32)
	if r.dodge_t > 0.0:
		ghost_tick += 1
		if ghost_tick % 2 == 0:
			_snap_ghost(0.45)
	if r.atk == "pesado" and r.atk_hit and r.atk_t < float(c["ataque_pesado"]["preparo"]) + float(c["ataque_pesado"]["ativo"]) + 0.03:
		_snap_ghost(0.3)
	# antena como mola (reage à aceleração)
	var a := (v - prev_vel) / maxf(dt, 0.001)
	prev_vel = v
	var ax := clampf(a.x * float(r.facing), -9000.0, 9000.0)
	ant_v += (-150.0 * ant - 6.0 * ant_v - ax * 0.0045 - clampf(a.y, -9000, 9000) * 0.0008) * dt
	ant = clampf(ant + ant_v * dt, -0.9, 0.9)
	# plaquinha solta (muito amassado): pêndulo que reage ao movimento
	panel[1] += (-60.0 * sin(panel[0]) - 2.5 * panel[1] - ax * 0.004) * dt
	panel[0] = clampf(panel[0] + panel[1] * dt, -1.4, 1.4)
	# ocioso: depois de um tempo parado, um tique (gira a marreta / espreguiça)
	if on_floor and run_k < 0.05 and r.atk == "" and r.dodge_t <= 0.0 and hurt_t <= 0.0 and not r.hanging:
		idle_t += dt
		if fidget_t < 0.0 and idle_t > next_fidget:
			fidget_t = 0.0
			fidget_kind = (fidget_kind + 1) % 2
			next_fidget = randf_range(5.0, 8.0)
			idle_t = 0.0
	else:
		idle_t = 0.0
		fidget_t = -1.0
	if fidget_t >= 0.0:
		fidget_t += dt / 1.1
		if fidget_t >= 1.0:
			fidget_t = -1.0
	_update_damage(r, dt)
	# piscar
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = randf_range(1.8, 4.2) * (0.5 if dmg_level >= 2 else 1.0)
	if r.alive and not r.finished:
		if hurt_t > 0.0:
			expression = "eliminado" if hurt_s > 0.6 and hurt_t > 0.1 else "susto"
		elif tumbling or r.stun_t > 0.0:
			expression = "susto"
		elif land_t > 0.0 or r.atk != "" or r.dodge_t > 0.0 or (v.y < -200.0 and not on_floor):
			expression = "esforco"
		elif r.main.danger_near(r) or v.y > 1000.0:
			expression = "susto"
		elif fidget_t >= 0.0 and fidget_kind == 1:
			expression = "vitoria"
		else:
			expression = "piscar" if blink_t < 0.0 else "normal"
	hang_snap = hang_snap.lerp(Vector2.ZERO, minf(dt * 18.0, 1.0))
	position = hang_snap
	if land_t > 0.0 and hurt_t <= 0.0:
		position += Vector2(randf_range(-0.6, 0.6), 0)
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
	# piscando enquanto invulnerável; clarão branco no golpe
	var al := 0.45 if r.invuln > 0.0 and fmod(t, 0.16) < 0.08 else 1.0
	var fl := 1.0 + 2.2 * (flash_t / 0.08) + 0.8 * dodged_flash
	modulate = Color(fl, fl, fl, al)
	_pose_springs(r, dt, on_floor, v)
	scale = Vector2(sq.x * signf(shown_facing + 0.0001), sq.y)
	queue_redraw()

## Dano visível: o corpo vai ficando amassado (3 estágios), solta faísca, fumaça e parafusos.
func _update_damage(r, dt: float) -> void:
	var lvl := 0
	for k in DMG_STEPS.size():
		if r.dmg >= DMG_STEPS[k]:
			lvl = k + 1
	if lvl > dmg_level and r.alive:
		# passou de estágio: tranco, parafuso voando e barulho de lata
		s_sqx[0] = 1.2
		s_sqy[0] = 0.82
		r.main.spark(r.position + Vector2(0, -56), 4 + lvl * 2)
		r.main.pop_bolt(r.position + Vector2(randf_range(-12, 12), -60), -r.facing)
		Audio.play("caixote_pancada", 1.5 - lvl * 0.15, -3.0)
	dmg_level = lvl
	if lvl >= 2 and r.alive:
		spark_t -= dt
		if spark_t <= 0.0:
			spark_t = randf_range(0.9, 1.6) if lvl == 2 else randf_range(0.3, 0.7)
			r.main.spark(r.position + Vector2(randf_range(-14, 14), randf_range(-70, -30)), 1)
	if lvl >= 3 and r.alive:
		smoke_t -= dt
		if smoke_t <= 0.0:
			smoke_t = 0.45 if r.dmg < 160.0 else 0.22
			r.main.dust(r.position + Vector2(randf_range(-10, 10), -78), 0.55)

## Calcula os alvos de inclinação, quique, squash, mãos e marreta e passa tudo pelas molas.
func _pose_springs(r, dt: float, on_floor: bool, v: Vector2) -> void:
	var c: Dictionary = Data.ctrl
	var spd := absf(v.x)
	var lean_t := run_k * 0.16
	if on_floor and spd > 160.0 and signf(v.x) != float(r.facing) and r.dodge_t <= 0.0:
		lean_t = -0.22   # freando / virando: derrapa
		if fmod(t, 0.08) < dt:
			r.main.dust(r.position + Vector2(float(r.facing) * 14.0, 0), 0.4)
	lean_t += wall_k * 0.12
	if not on_floor and r.dodge_t <= 0.0:
		lean_t += clampf(v.x * float(r.facing) / 2400.0, -0.12, 0.18)
	var sqx_t := 1.0
	var sqy_t := 1.0
	# respiração parada / passada correndo
	sqy_t += sin(t * 2.3) * 0.018 * (1.0 - run_k) * (1.0 - air_k)
	sqx_t -= sin(t * 2.3) * 0.012 * (1.0 - run_k) * (1.0 - air_k)
	if on_floor and run_k > 0.1:
		var contact := pow(absf(cos(phase)), 6.0)
		sqy_t -= 0.05 * contact * run_k
		sqx_t += 0.04 * contact * run_k
	if not on_floor and r.dodge_t <= 0.0 and flip_t < 0.0:
		var st := clampf(absf(v.y) / 1400.0, 0.0, 0.16)
		sqy_t += st
		sqx_t -= st * 0.7
	var ham_t := HAMMER_REST
	if on_floor and run_k > 0.1:
		ham_t += sin(phase) * 0.22 * run_k
	elif not on_floor:
		ham_t = lerpf(HAMMER_REST, -0.9 if v.y > 0.0 else 0.9, clampf(absf(v.y) / 900.0, 0.0, 1.0))
	# golpes
	var hp: Dictionary = c["ataque_pesado"]
	var rp: Dictionary = c["ataque_rapido"]
	if r.atk == "pesado":
		var pre := float(hp["preparo"])
		if not r.atk_hit:
			var k := clampf(r.atk_t / pre, 0.0, 1.0)
			lean_t = -0.3 * _ease_out(k)
			sqx_t = 1.0 + 0.1 * k
			sqy_t = 1.0 - 0.1 * k
		elif r.atk_t < pre + float(hp["ativo"]):
			lean_t = 0.5
			sqx_t = 0.9
			sqy_t = 1.12
		else:
			lean_t = 0.42 if not r.atk_landed else 0.1
	elif r.atk == "rapido":
		var pre := float(rp["preparo"])
		lean_t = -0.08 if not r.atk_hit else (0.26 if r.atk_t < pre + float(rp["ativo"]) + 0.04 else 0.08)
	if r.dodge_t > 0.0:
		lean_t = 0.55 if dodge_ground else 0.2
		sqx_t = 1.22
		sqy_t = 0.82
	if hurt_t > 0.0:
		lean_t = hurt_lean
	if land_t > 0.0:
		sqx_t = 1.12
		sqy_t = 0.88
		lean_t = 0.2
	lean = _spring(s_lean, lean_t, dt, 3.6, 0.42)
	var bob_t := 0.0
	if r.dodge_t > 0.0 and dodge_ground:
		bob_t = 9.0
	_spring(s_bob, bob_t, dt, 4.5, 0.35)
	sq = Vector2(_spring(s_sqx, sqx_t, dt, 4.2, 0.28), _spring(s_sqy, sqy_t, dt, 4.2, 0.28))
	sq = sq.clamp(Vector2(0.55, 0.55), Vector2(1.6, 1.6))
	_spring(s_ham, ham_t, dt, 4.0, 0.42)
	if tumbling:
		s_rot[0] = tumble
		s_rot[1] = 0.0
	else:
		_spring(s_rot, tumble, dt, 7.0 if on_floor else 3.2, 0.5 if on_floor else 0.38)   # volta de pé com um balanço

## Rastro: copia a pose atual para um "fantasma" na cor do jogador que some aos poucos.
func _snap_ghost(alpha: float) -> void:
	if ghosts.is_empty() or not is_inside_tree():
		return
	var g: Node2D = ghosts[ghost_i % ghosts.size()]
	ghost_i += 1
	g.set_meta("snap", {"xf": get_global_transform(), "pose": current_pose(), "look": look(), "a": alpha, "t": 0.0})
	g.visible = true
	g.queue_redraw()

func _draw_ghost(g: Node2D) -> void:
	var sn: Dictionary = g.get_meta("snap")
	if sn.is_empty():
		return
	draw_robot(g, sn["look"], sn["pose"], sn["xf"])

func _process(dt: float) -> void:
	var col: Color = Data.COLORS[color_idx % Data.COLORS.size()]
	for g in ghosts:
		if not g.visible:
			continue
		var sn: Dictionary = g.get_meta("snap")
		sn["t"] = float(sn["t"]) + dt
		var k: float = sn["t"] / 0.22
		if k >= 1.0:
			g.visible = false
			continue
		g.modulate = Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, float(sn["a"]) * (1.0 - k))

func current_pose() -> Dictionary:
	var p := idle_pose(t)
	p["expr"] = expression
	var r := run_k
	var c: Dictionary = Data.ctrl
	var ant_extra := 0.0
	var bob := -absf(sin(phase)) * 5.0 * r + sin(t * 2.3) * 1.0 * (1.0 - r) + float(s_bob[0])
	var feet := [Vector2.ZERO, Vector2.ZERO]
	var knee := [Vector2(1.5, 0), Vector2(1.5, 0)]
	var hb := Vector2(0, sin(t * 2.3 + 0.6) * 0.8 * (1.0 - r))
	var hf := Vector2(0, sin(t * 2.3 + 1.1) * 0.6 * (1.0 - r))
	# corrida: pés em elipse (sobe na passagem, empurra atrás), joelho dobra na subida, braços opostos às pernas
	for i in 2:
		var ph := phase + (0.0 if i == 0 else PI)
		var lift := maxf(sin(ph), 0.0)
		feet[i] = Vector2(cos(ph) * 11.0 * r, -lift * 10.0 * r - maxf(-sin(ph), 0.0) * 1.2 * r)
		knee[i] = Vector2(1.5 + 7.0 * r * lift, 0)
	hb += Vector2(-cos(phase) * 9.0 * r, -2.0 * r - absf(sin(phase)) * 3.0 * r)
	hf += Vector2(cos(phase) * 5.0 * r, -1.0 * r)
	# ar: sobe encolhido com os braços para cima; no alto abre; caindo agita os braços e estica as pernas
	var a := air_k
	if a > 0.0:
		var fall := clampf(vy / 800.0, -1.0, 1.0)
		var up := maxf(-fall, 0.0)
		var down := maxf(fall, 0.0)
		var apex := 1.0 - clampf(absf(vy) / 260.0, 0.0, 1.0)
		for i in 2:
			var sg := -1.0 if i == 0 else 1.0
			var air_f := Vector2(2.0 + sg * 1.0, -11.0) * up + Vector2(sg * 5.0, 3.0) * down + Vector2(sg * 7.0, -5.0) * apex
			feet[i] = feet[i].lerp(air_f, a)
			knee[i] = knee[i].lerp(Vector2(7.0, 0) * up + Vector2(0.5, 0) * down + Vector2(4.0, 0) * apex, a)
		hb = hb.lerp(Vector2(-4, -16) * up + Vector2(sin(t * 24.0) * 6.0, -18.0 + cos(t * 24.0) * 5.0) * down + Vector2(-12, -8) * apex, a)
		hf = hf.lerp(Vector2(2, -10) * up + Vector2(cos(t * 21.0) * 4.0, -8.0) * down + Vector2(8, -6) * apex, a)
	# pulo duplo: chute com jato → cambalhota encolhida → abre os braços
	if flip_t >= 0.0:
		var k := flip_t
		if k < DJ_KICK:
			var u := _ease_out(k / DJ_KICK)
			for i in 2:
				feet[i] = feet[i].lerp(Vector2(-3.0 + i * 6.0, 6.0), u)   # pernas esticadas para baixo
				knee[i] = knee[i].lerp(Vector2(0.5, 0), u)
			hb = hb.lerp(Vector2(-6, -34), u)                           # braços para cima
			hf = hf.lerp(Vector2(6, -32), u)
			p["jet"] = 1.0
			p["rot"] = 0.0
			p["dj_ham"] = lerpf(HAMMER_REST, -0.2, u)
		elif k < DJ_OPEN:
			var v := (k - DJ_KICK) / (DJ_OPEN - DJ_KICK)
			var e := v * v * v * (v * (v * 6.0 - 15.0) + 10.0)          # começa e termina devagar
			p["rot"] = TAU * e
			var tuck := clampf(sin(PI * v) * 1.6, 0.0, 1.0)
			for i in 2:
				feet[i] = Vector2(-3.0 + i * 6.0, 6.0).lerp(Vector2(3.0 + i * 5.0, -24.0), tuck)
				knee[i] = Vector2(0.5, 0).lerp(Vector2(12.0, 0), tuck)
			hb = Vector2(-6, -34).lerp(Vector2(3, -18), tuck)          # abraça os joelhos
			hf = Vector2(6, -32).lerp(Vector2(9, -16), tuck)
			p["jet"] = maxf(1.0 - v * 2.5, 0.0)
			p["dj_ham"] = lerpf(-0.2, 2.5, tuck)                         # marreta junto dos joelhos
			p["tuck"] = tuck                                             # encolhe no eixo do corpo (vira "bola")
			bob += 6.0 * tuck                                            # corpo desce até os joelhos
		else:
			var w := _ease_out((k - DJ_OPEN) / (1.0 - DJ_OPEN))
			p["rot"] = TAU
			for i in 2:
				feet[i] = Vector2(3.0 + i * 5.0, -24.0).lerp(feet[i], w)
				knee[i] = Vector2(12.0, 0).lerp(knee[i], w)
			hb = Vector2(-20, -18).lerp(hb, w * 0.6)                    # abre os braços para se equilibrar
			hf = Vector2(18, -16).lerp(hf, w * 0.6)
			p["dj_ham"] = lerpf(2.5, HAMMER_REST, w)
	# idle: tique de ocioso
	if fidget_t >= 0.0:
		var k := fidget_t
		if fidget_kind == 0:
			# gira a marreta no ar e pega de volta
			hf += Vector2(0, -16.0 * sin(PI * k))
			bob += -3.0 * sin(PI * clampf((k - 0.75) / 0.25, 0.0, 1.0))
		else:
			# espreguiça: braços para cima, fica na ponta dos pés
			var u := sin(PI * k)
			hb += Vector2(-2, -26) * u
			hf += Vector2(2, -22) * u
			bob -= 3.0 * u
			ant_extra = sin(t * 10.0) * 0.3 * u
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
	# spell: preparo (puxa o braço / mira), disparo com coice; fora disso a spell fica guardada na mão de trás
	var sf: Dictionary = robot.fx_flags() if robot != null and robot.has_method("fx_flags") else {}
	var sid: String = sf.get("spell", "")
	var prep: float = sf.get("prep", -1.0)
	var fire: float = sf.get("fire", -1.0)
	var aiming := prep >= 0.0 or (fire >= 0.0 and fire < 0.32)
	if sid != "" and aiming and not sf.get("armor", false):
		var kick := clampf(1.0 - fire / 0.22, 0.0, 1.0) if fire >= 0.0 and prep < 0.0 else 0.0
		var buzz := Vector2(sin(t * 80.0), cos(t * 71.0)) * 1.4 * maxf(prep, 0.0)   # treme carregando
		match sid:
			"S01":
				if prep >= 0.0:   # puxa o punho para trás, corpo carregando
					p["hf_abs"] = Vector2(20, -40).lerp(Vector2(2, -38), ease(prep, 0.5)) + buzz
					p["hb_abs"] = Vector2(14, -34) + buzz * 0.5
					lean = lerpf(lean, -0.16 * prep, 0.5)
				else:             # SOCO: braço esticado à frente, corpo vai junto
					p["hf_abs"] = Vector2(26 - 8.0 * (1.0 - kick), -40)
					p["hb_abs"] = Vector2(-10, -32)
					lean = lerpf(lean, 0.18 * kick + 0.04, 0.6)
				p["tool"] = "S01"
			"S03", "S06":
				p["hf_abs"] = Vector2(21 - 9.0 * kick, -38 - 4.0 * kick) + buzz
				p["hb_abs"] = Vector2(13 - 7.0 * kick, -35 - 3.0 * kick) + buzz * 0.6
				p["tool"] = sid
				p["tool_ang"] = -0.35 * kick
				lean = lerpf(lean, 0.06 - 0.14 * kick, 0.5)
			"S10":   # aponta onde o andaime abre
				p["hf_abs"] = Vector2(24, -46 - 10.0 * kick)
			"S11":   # estala os dedos para cima
				p["hf_abs"] = Vector2(10, -62 + 6.0 * kick)
				p["hb_abs"] = Vector2(-8, -60 + 6.0 * kick)
		for i in 2:
			feet[i] = feet[i].lerp(Vector2(-6.0 + i * 10.0, 0), 0.6)   # pés firmes
	elif sf.get("armor", false) and fire >= 0.0 and fire < 0.3:
		lean = lerpf(lean, -0.1 * (1.0 - fire / 0.3), 0.5)   # coice do jato de fogo
		p["hf_abs"] = Vector2(22, -40)
	# subindo na borda: empurra a quina com as mãos e levanta o joelho
	if robot != null and robot.climb_t >= 0.0:
		var k: float = robot.climb_t
		p["hb_abs"] = Vector2(10, -48 + 40 * k)
		p["hf_abs"] = Vector2(18, -50 + 40 * k)
		feet[1] = Vector2(10, -22 * (1.0 - k))
		knee[1] = Vector2(9, 0)
		lean = 0.3
	var ang: float = s_ham[0]
	if p.has("dj_ham"):
		ang = float(p["dj_ham"])
		s_ham[0] = ang
		s_ham[1] = 0.0
	if fidget_t >= 0.0 and fidget_kind == 0:
		ang = HAMMER_REST + TAU * smoothstep(0.1, 0.8, fidget_t)
	if robot != null:
		var hp: Dictionary = c["ataque_pesado"]
		var rp: Dictionary = c["ataque_rapido"]
		var at: float = robot.atk_t
		if robot.atk == "pesado":
			var pre := float(hp["preparo"])
			var act := float(hp["ativo"])
			if not robot.atk_hit:
				# preparo: levanta a marreta bem alto atrás da cabeça, agacha e treme no fim
				var k := clampf(at / pre, 0.0, 1.0)
				var e := _ease_out(k)
				ang = lerpf(HAMMER_REST, -2.75, e)
				hf = hf.lerp(Vector2(-8, -24), e)
				hb = hb.lerp(Vector2(-2, -20), e)
				bob += 4.0 * e
				for i in 2:
					feet[i] = feet[i].lerp(Vector2(-6.0 + i * 14.0, 0), e)
					knee[i] = knee[i].lerp(Vector2(6, 0), e)
				if k > 0.7:
					bob += sin(t * 90.0) * 1.2
				p["glint"] = clampf((k - 0.6) / 0.4, 0.0, 1.0)
				smear_from = ang
				smear_a = 0.0
			elif at < pre + act:
				# golpe: desce com tudo por cima da cabeça
				var k := clampf((at - pre) / act, 0.0, 1.0)
				ang = lerpf(-2.75, 2.35, k * k)
				hf = Vector2(-8, -24).lerp(Vector2(14, 6), k)
				hb = Vector2(-2, -20).lerp(Vector2(8, 4), k)
				for i in 2:
					feet[i] = Vector2(-8.0 + i * 18.0, 0)
					knee[i] = Vector2(7, 0)
				smear_from = -2.75
				smear_a = 1.0
			else:
				var rec := at - pre - act
				var stuck := 0.0 if robot.atk_landed else clampf(1.0 - rec / (float(hp["recupera_erro"]) * 0.7), 0.0, 1.0)
				if stuck > 0.0:
					# errou: a marreta fica cravada no chão e ele puxa com esforço
					ang = 2.35 + sin(t * 40.0) * 0.04 * stuck
					hf = Vector2(14, 6) + Vector2(-2, 0) * sin(t * 30.0) * stuck
					hb = Vector2(8, 4)
					bob += 5.0 * stuck
					for i in 2:
						feet[i] = Vector2(-8.0 + i * 18.0, 0)
						knee[i] = Vector2(8, 0)
				smear_a = maxf(smear_a - 0.25, 0.0)
			s_ham[0] = ang
			s_ham[1] = 0.0
			s_hf[0] = hf
			s_hb[0] = hb
		elif robot.atk == "rapido":
			var pre := float(rp["preparo"])
			var act := float(rp["ativo"])
			var wind := -0.5 if not jab_alt else 2.5
			var hit_ang := 1.8 if not jab_alt else -0.35
			var hf_hit := Vector2(18, 0) if not jab_alt else Vector2(16, -20)
			match String(robot.atk_dir):
				"cima":   # varre por cima da cabeça
					wind = 2.2
					hit_ang = -0.7
					hf_hit = Vector2(6, -38)
				"baixo":  # marreta para baixo no ar
					wind = -2.5
					hit_ang = 3.0
					hf_hit = Vector2(6, 16)
				"corrida":  # investida: braço todo à frente
					wind = -0.9
					hit_ang = 1.6
					hf_hit = Vector2(26, -4)
				_:
					if int(robot.combo_i) == 2:   # 3º golpe da sequência: giro grande que arremessa
						wind = -2.6
						hit_ang = 2.3
						hf_hit = Vector2(20, 4)
			if not robot.atk_hit:
				var k := _ease_out(at / pre)
				ang = lerpf(float(s_ham[0]), wind, k)
				hf = hf.lerp(Vector2(-6, -8) if not jab_alt else Vector2(-2, 6), k)
				smear_from = ang
				smear_a = 0.0
			elif at < pre + act:
				var k := _ease_out((at - pre) / act)
				ang = lerpf(wind, hit_ang, k)
				hf = hf.lerp(hf_hit, k)
				hb = hb.lerp(Vector2(-10, -6), k)
				feet[1] = feet[1].lerp(Vector2(10, 0), k)
				smear_from = wind
				smear_a = 1.0 if (int(robot.combo_i) == 2 or String(robot.atk_dir) != "frente") else 0.8
			else:
				smear_a = maxf(smear_a - 0.3, 0.0)
				ang = float(s_ham[0])
				hf = s_hf[0]
			if robot.atk_t <= pre + act:
				s_ham[0] = ang
				s_ham[1] = 0.0
				s_hf[0] = hf
		else:
			smear_a = maxf(smear_a - 0.3, 0.0)
		# esquiva: no chão desliza baixo, no ar encolhe e vai na direção
		if robot.dodge_t > 0.0:
			if dodge_ground:
				feet[0] = Vector2(-22, -2)
				feet[1] = Vector2(14, 0)
				knee[0] = Vector2(-2, 0)
				knee[1] = Vector2(9, 0)
				hb = Vector2(-22, -26)
				hf = Vector2(-14, -22)
				ang = -2.2
			else:
				p["rot"] = atan2(dodge_dir.y, absf(dodge_dir.x) + 0.001) * 0.7 + 0.35
				for i in 2:
					feet[i] = Vector2(-2.0 + i * 6.0, -16.0)
					knee[i] = Vector2(9, 0)
				hb = Vector2(-16, -12)
				hf = Vector2(-10, -14)
				ang = -1.9
			s_ham[0] = ang
			s_ham[1] = 0.0
			p["guard"] = clampf(robot.guard_t / 0.13, 0.0, 1.0)
		# atingido / arremessado: braços e pernas abertos, se debatendo
		if hurt_t > 0.0 or tumbling or robot.stun_t > 0.0:
			var fl := 1.0 if tumbling else 0.6
			hb = Vector2(-16, -22) + Vector2(sin(t * 31.0), cos(t * 27.0)) * 6.0 * fl
			hf = Vector2(14, -20) + Vector2(cos(t * 29.0), sin(t * 33.0)) * 6.0 * fl
			for i in 2:
				feet[i] = Vector2(-10.0 + i * 20.0, -6.0) + Vector2(sin(t * 25.0 + i), 0) * 4.0 * fl
				knee[i] = Vector2(-3.0 + i * 6.0, 0)
			ang = float(s_ham[0]) + sin(t * 20.0) * 0.5 * fl
		# recuperou o controle no ar: abre os braços para se equilibrar
		elif not robot.is_on_floor() and robot.recover_t > 0.0:
			var u: float = robot.recover_t / maxf(robot.recover_len, 0.01)
			hb = hb.lerp(Vector2(-20, -18), u)
			hf = hf.lerp(Vector2(18, -18), u)
		# pouso depois de arremessado: agacha fundo e absorve
		if land_t > 0.0:
			var u := land_t / 0.28
			for i in 2:
				feet[i] = Vector2(-9.0 + i * 18.0, 0)
				knee[i] = Vector2(10, 0) * u + knee[i] * (1.0 - u)
			bob += 8.0 * u
			hb = hb.lerp(Vector2(-18, 6), u)
			hf = hf.lerp(Vector2(16, 8), u)
	# mãos com inércia (seguem o alvo com uma molinha) e o dano deixa os braços bambos
	var wob := Vector2(sin(t * 13.0), cos(t * 11.0)) * (1.2 if dmg_level >= 2 else 0.0)
	var dt := 1.0 / 60.0
	if robot == null or robot.atk == "" or (robot.atk == "rapido" and robot.atk_t > float(c["ataque_rapido"]["preparo"]) + float(c["ataque_rapido"]["ativo"])):
		hf = _spring(s_hf, hf, dt * 0.5, 6.0, 0.5) + wob
	if robot == null or robot.atk != "pesado":
		hb = _spring(s_hb, hb, dt * 0.5, 6.0, 0.5) - wob
	if not p.has("rot") and absf(float(s_rot[0]) - round(float(s_rot[0]) / TAU) * TAU) > 0.001:
		p["rot"] = s_rot[0]
	elif p.has("rot"):
		s_rot[0] = p["rot"]
		s_rot[1] = 0.0
		tumble = round(float(p["rot"]) / TAU) * TAU if flip_t < 0.0 else tumble
	# botas de mola: a mola estica no ar e encolhe ao tocar o chão
	p["spring_k"] = 1.0 + 0.5 * air_k - 0.4 * clampf(1.0 - sq.y, 0.0, 1.0)
	p["body_off"] = Vector2(0, bob)
	p["lean"] = lean
	p["feet"] = feet
	p["knee"] = knee
	p["hb_off"] = hb
	p["hf_off"] = hf
	if not p.has("hammer_ang") or not hanging:
		p["hammer_ang"] = ang
	p["ant"] = ant + ant_extra + 0.12 * dmg_level
	p["smear"] = [smear_from, ang, smear_a]
	p["panel"] = panel[0]
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

## Setinha na cor do jogador acima da cabeça ("P1"): identifica quem é quem (fica acima do topo de cada modelo).
func _draw_tag() -> void:
	if robot == null or not robot.alive or not robot.get("active"):
		return
	var sx := signf(scale.x) if scale.x != 0.0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0 / maxf(absf(scale.x), 0.2) * sx, 1.0 / maxf(scale.y, 0.2)))
	var meter: bool = (hanging or on_wall or not robot.is_on_floor()) and grip < 0.999
	var top := float(Data.model_meta(model)["top"]) - ORIGIN.y
	var y := (top - 48.0) if meter else (top - 14.0)
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

## Desenha o robô montado em qualquer CanvasItem. look = {color, model, hammer, fx}; pose = ver topo.
static func draw_robot(ci: CanvasItem, lk: Dictionary, pose: Dictionary, base := Transform2D.IDENTITY) -> void:
	var col_idx: int = lk["color"]
	var mname: String = Data.MODELS[lk["model"]]
	var body := Data.tex("robo/corpo_%s_p%d" % [mname, col_idx + 1])
	if body == null or Data.robot_meta.is_empty():
		return
	if pose.has("rot"):   # mortal, giro do arremesso, esquiva no ar: gira em torno do meio do corpo
		base = base * Transform2D(float(pose["rot"]), PIVOT) * Transform2D(0.0, -PIVOT)
	var tk := float(pose.get("tuck", 0.0))
	if tk > 0.0:   # cambalhota: achata no eixo do próprio corpo (depois do giro), não no da tela
		base = base * Transform2D(0.0, Vector2(1.0 + 0.2 * tk, 1.0 - 0.3 * tk), 0.0, PIVOT * Vector2(0, 1) * (0.3 * tk))
	if pose.has("spin"):   # comemoração "pião": achata na horizontal passando pelo meio
		var sp: float = pose["spin"]
		base = base * Transform2D(0.0, Vector2(signf(sp) * maxf(absf(sp), 0.32), 1.0), 0.0, Vector2.ZERO)
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := Color(Data.robot_meta["membros"][col_idx])
	var lw := float(g["limb_w"])
	var q := Vector2(0.25, 0.25)
	var hand_q: Vector2 = q * float(g["hand_s"])
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
	# rastro do golpe (arco branco por onde a cabeça da marreta passou)
	var smear: Array = pose.get("smear", [0.0, 0.0, 0.0])
	if float(smear[2]) > 0.01 and tool == "":
		var a0 := float(smear[0])
		var a1 := float(smear[1])
		var poly := PackedVector2Array()
		var n := 10
		for i in n + 1:
			var aa := lerpf(a0, a1, float(i) / n)
			poly.append(hf + Vector2(sin(aa), -cos(aa)) * 46.0)
		for i in range(n, -1, -1):
			var aa := lerpf(a0, a1, float(i) / n)
			var w := 46.0 - 18.0 * pow(float(i) / n, 0.5)
			poly.append(hf + Vector2(sin(aa), -cos(aa)) * w)
		ci.draw_set_transform_matrix(base)
		if poly.size() >= 3 and absf(a1 - a0) > 0.2:
			ci.draw_colored_polygon(poly, Color(1, 1, 1, 0.55 * float(smear[2])))
	var sf: Dictionary = fx
	var armor: bool = sf.get("armor", false)
	var asm := float(sf.get("assemble", 1.0)) if armor else 0.0
	if armor:   # armadura fornalha: membros grossos de ferro escuro
		lw *= 1.0 + 0.9 * asm
		limb = limb.lerp(Color("#5f4438"), 0.75 * asm)
	if lk.get("hammer", true) and tool == "" and not armor:
		ci.draw_set_transform_matrix(base * Transform2D(pose["hammer_ang"], q, 0.0, hf))
		var hcol := Color(0.58, 0.62, 0.72) if lk.get("ham_cd", false) else Color.WHITE
		ci.draw_texture(Data.tex("robo/marreta"), -GRIP * 4.0, hcol)
	var eye: Vector2 = (_v(g["eyes"][0]) + _v(g["eyes"][1])) / 2.0
	if armor:   # costas da armadura (tanque + chaminé) atrás do corpo
		_armor_piece(ci, base * bx, "s13_costas", asm, eye + Vector2(-5, 0), sf)
	# pernas + botas
	var foot := Data.tex("robo/pe")
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var hip: Vector2 = bx * _v(hips[i])
		var fp: Vector2 = Vector2(_v(hips[i]).x + s * 4.0, -4.0) + pose["feet"][i]
		_limb(ci, base, hip, fp, limb, pose["knee"][i], lw)
		ci.draw_set_transform_matrix(base * Transform2D(0.0, q * (0.72 + 0.2 * asm), 0.0, fp + Vector2(s * 1.5, 0.5)))
		ci.draw_texture(foot, -Vector2(12, 7) * 4.0, limb)
	# jato do propulsor saindo dos pés (pulo duplo)
	var jet := float(pose.get("jet", 0.0))
	if jet > 0.01:
		ci.draw_set_transform_matrix(base)
		var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() / 25.0)
		for i in 2:
			var fp2: Vector2 = Vector2(_v(hips[i]).x + (-1.0 if i == 0 else 1.0) * 4.0, -4.0) + pose["feet"][i] + Vector2(0, 6)
			var L := 30.0 * jet * flick
			ci.draw_colored_polygon(PackedVector2Array([fp2 + Vector2(-6, 0), fp2 + Vector2(6, 0), fp2 + Vector2(0, L)]), Color("#f6a23a"))
			ci.draw_colored_polygon(PackedVector2Array([fp2 + Vector2(-3, 0), fp2 + Vector2(3, 0), fp2 + Vector2(0, L * 0.55)]), Color("#fff1b8"))
	_limb(ci, base, bx * _v(sh[0]), hb, limb, Vector2(0, 3), lw)
	# corpo + rosto + antena (mola)
	ci.draw_set_transform_matrix(base * bx * Transform2D(0.0, q, 0.0, -ORIGIN))
	ci.draw_texture(body, Vector2.ZERO)
	var dl: int = lk.get("dmg", 0)
	if dl > 0:
		var dtex := Data.tex("robo/dano%d_%s" % [dl, mname])
		if dtex != null:
			ci.draw_texture(dtex, Vector2.ZERO)
	ci.draw_texture(Data.tex("robo/rosto_%s_%s" % [mname, pose["expr"]]), Vector2.ZERO)
	if dl >= 3:
		# plaquinha solta pendurada por um parafuso, balançando
		var hinge := (_v(sh[1]) + _v(hips[1])) / 2.0 + Vector2(-2, -4)
		ci.draw_set_transform_matrix(base * bx * Transform2D(float(pose.get("panel", 0.0)) + 0.35, hinge))
		ci.draw_rect(Rect2(-5, 0, 11, 14), limb.lightened(0.25))
		ci.draw_rect(Rect2(-5, 11, 11, 3), limb)
		ci.draw_circle(Vector2(0, 2), 1.8, Color("#c9d1d8"))
	var ab := _v(g["antenna"])
	ci.draw_set_transform_matrix(base * bx * Transform2D(pose["ant"], ab) * Transform2D(0.0, q, 0.0, -ab - ORIGIN))
	ci.draw_texture(Data.tex("robo/antena_" + mname), Vector2.ZERO)
	var tnow := Time.get_ticks_msec() / 1000.0
	if armor:   # frente da armadura por cima do corpo; o rosto do robô aparece na vigia
		_armor_piece(ci, base * bx, "s13_frente", asm, eye, sf)
		var drop := Vector2(0, -(1.0 - asm) * 30.0)
		ci.draw_set_transform_matrix(base * bx)
		ci.draw_circle(eye + drop, 10.0, Color("#2b3d4f"))
		ci.draw_set_transform_matrix(base * bx * Transform2D(0.0, q, 0.0, -ORIGIN))
		ci.draw_texture(Data.tex("robo/rosto_%s_%s" % [mname, pose["expr"]]), Vector2.ZERO)
		ci.draw_set_transform_matrix(base * bx)
		ci.draw_arc(eye + drop, 10.4, 0, TAU, 20, Color("#c9a03a"), 3.0, true)
		ci.draw_arc(eye + drop + Vector2(-1.5, -1.5), 6.4, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.6), 1.6, true)
	var held: String = SPELL_HELD.get(String(sf.get("spell", "")), "")
	if held != "" and tool == "" and not armor and not sf.get("fading", false):
		# a spell guardada aparece na mão de trás, balançando
		ci.draw_set_transform_matrix(base * Transform2D(-0.3 + sin(tnow * 4.0) * 0.12, Vector2.ONE, 0.0, hb + Vector2(-2, -8)))
		var tx := Data.tex("spells/" + held)
		var hs := Vector2(30, 30) if tx.get_width() == tx.get_height() else Vector2(34, 34.0 * tx.get_height() / tx.get_width())
		ci.draw_texture_rect(tx, Rect2(-hs / 2.0, hs), false)
	if tool != "" and SPELL_TOOLS.has(tool):
		# arma da spell presa na mão da frente (ponto de pega embaixo da mão)
		var spec: Array = SPELL_TOOLS[tool]
		var tx := Data.tex("spells/" + spec[0])
		var sz: Vector2 = spec[1]
		var dsz := Vector2(tx.get_width(), tx.get_height()) / 2.0   # tamanho de design
		var grip: Vector2 = spec[2] * sz / dsz
		ci.draw_set_transform_matrix(base * Transform2D(float(pose.get("tool_ang", 0.0)), hf))
		ci.draw_texture_rect(tx, Rect2(-grip, sz), false)
		if tool == "S06" and float(sf.get("fire", -1.0)) >= 0.0:
			for k in 3:
				var rr := 8.0 + fposmod(tnow * 60.0 + k * 7.0, 20.0)
				ci.draw_arc(Vector2(sz.x - grip.x, 0), rr, -0.9, 0.9, 8, Color(0.85, 0.29, 0.35, 1.0 - rr / 28.0), 2.0, true)
		var pk := float(sf.get("prep", -1.0))
		if pk > 0.0 and tool == "S01":   # pistão carregando: vapor saindo
			for k in 3:
				var u := fposmod(tnow * 3.0 + k * 0.33, 1.0)
				ci.draw_circle(Vector2(-grip.x + 4.0, -6.0 - u * 18.0), 3.0 + u * 4.0, Color(1, 1, 1, 0.6 * (1.0 - u) * pk))
	_limb(ci, base, bx * _v(sh[1]), hf, limb, Vector2(0, 3), lw)
	# brilho na cabeça da marreta no fim do preparo da pesada
	var gl := float(pose.get("glint", 0.0))
	if gl > 0.0:
		var head := hf + Vector2(sin(float(pose["hammer_ang"])), -cos(float(pose["hammer_ang"]))) * 40.0
		ci.draw_set_transform_matrix(base * Transform2D(Time.get_ticks_msec() / 200.0, head))
		var st := Data.tex("cenario/brilho")
		var sz := 10.0 + 18.0 * gl
		ci.draw_texture_rect(st, Rect2(-sz / 2, -sz / 2, sz, sz), false, Color(1, 1, 0.8, gl))
	# janela de proteção da esquiva: contorno branco discreto
	var gd := float(pose.get("guard", 0.0))
	if gd > 0.0:
		ci.draw_set_transform_matrix(base)
		ci.draw_arc(PIVOT, 46.0, 0, TAU, 32, Color(1, 1, 1, 0.45 * gd), 3.0, true)
	var hand := Data.tex("robo/mao")
	for p in [hb, hf]:
		ci.draw_set_transform_matrix(base * Transform2D(0.0, hand_q, 0.0, p))
		ci.draw_texture(hand, -Vector2(8, 8) * 4.0)
	ci.draw_set_transform_matrix(base)

## Placa da Armadura Fornalha (S13): arte de design 150x130 em escala 0,48 (o robô "vira" a fornalha), vigia (75,50) em `at`.
## Montagem: cai de cima e assenta; nos últimos instantes pisca avisando que vai desmontar.
static func _armor_piece(ci: CanvasItem, xf: Transform2D, name: String, asm: float, at: Vector2, sf: Dictionary) -> void:
	var drop := Vector2(0, -(1.0 - asm) * 30.0)
	var mod := Color(1, 1, 1, asm)
	if float(sf.get("armor_end", 0.0)) > 0.0 and fmod(Time.get_ticks_msec() / 1000.0, 0.16) < 0.08:
		mod = Color(1.6, 1.4, 1.2, asm)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture_rect(Data.tex("spells/" + name), Rect2(at - Vector2(36, 24) + drop, Vector2(72, 62.4)), false, mod)

static func _v(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) - ORIGIN

## Membro grosso de "macarrão" com risco de giz.
static func _limb(ci: CanvasItem, base: Transform2D, a: Vector2, b: Vector2, col: Color, bend: Vector2, w := 3.4) -> void:
	var m := (a + b) / 2.0 + bend
	var pts := PackedVector2Array()
	for i in 7:
		var k := i / 6.0
		pts.append(a.lerp(m, k).lerp(m.lerp(b, k), k))
	ci.draw_set_transform_matrix(base)
	ci.draw_polyline(pts, col, w, true)
	var streak := PackedVector2Array()
	for p in pts:
		streak.append(p + Vector2(-0.6, 0))
	ci.draw_polyline(streak, col.lightened(0.15), w * 0.18, true)

## Partes soltas para o robô "desmontar" na eliminação: [{tex, rect (local), modulate}].
static func parts(lk: Dictionary) -> Array:
	var mname: String = Data.MODELS[lk["model"]]
	var g: Dictionary = Data.robot_meta["modelos"][mname]
	var limb := Color(Data.robot_meta["membros"][lk["color"]])
	var out := []
	out.append({"tex": [Data.tex("robo/corpo_%s_p%d" % [mname, lk["color"] + 1]), Data.tex("robo/rosto_%s_eliminado" % mname)],
		"rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	out.append({"tex": [Data.tex("robo/antena_" + mname)], "rect": Rect2(-ORIGIN, Vector2(128, 128)), "mod": Color.WHITE})
	if lk.get("hammer", true):
		out.append({"tex": [Data.tex("robo/marreta")], "rect": Rect2(_v(g["hand_front"]) - GRIP, Vector2(64, 64)), "mod": Color.WHITE})
	var hs := 16.0 * float(g["hand_s"])
	for hp in [g["hand_back"], g["hand_front"]]:
		out.append({"tex": [Data.tex("robo/mao")], "rect": Rect2(_v(hp) - Vector2(hs, hs) / 2.0, Vector2(hs, hs)), "mod": Color.WHITE})
	for hip in g["hips"]:
		out.append({"tex": [Data.tex("robo/pe")], "rect": Rect2(Vector2(_v(hip).x - 9, -9), Vector2(17, 10)), "mod": limb})
	return out
