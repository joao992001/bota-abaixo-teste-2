extends CharacterBody2D
## Robô: velocidade calculada à mão com os números de data/controller.json + move_and_slide.
## Ordem por frame: input → timers → forças de peças → horizontal → pulo/parede → sustain → gravidade → mover → contatos.

const Vis := preload("res://player/robot_visual.gd")

var pid := 0
var color_idx := 0
var main: Node
var c: Dictionary
var active := false
var alive := true
var finished := false
var own_vx := 0.0
var ext_vx := 0.0
var coyote := 0.0
var buffer := 0.0
var var_jump := 0.0
var wall_lock := 0.0
var hammer_anim := 0.0
var hammer_left := 1
var facing := 1
var spring := false
var floor_piece = null
var was_on_floor := true
var spin := 0.0
var wall_sliding := false
var stun_t := 0.0            # atordoado: ignora o controle (pisão na cabeça, marretada)
var item := ""               # item guardado (dinamite), usado com o botão de item
var fx_t := {"martelao": 0.0, "mola": 0.0, "ima": 0.0, "foguete": 0.0, "patins": 0.0, "escudo": 0.0, "molabomba": 0.0, "balao": 0.0, "armadura": 0.0, "ventosa": 0.0, "turbo": 0.0, "bolha": 0.0}   # efeitos com tempo
var glue_t := 0.0             # pisou na cola: lento
var caught := false           # Fuga: foi pego pela tela ou pela lama (esse sai de vez)
var speed_k := 1.0            # multiplicador da corrida (Rei da Obra: o rei anda mais devagar)
var forced_t := 0.0           # movimento forçado (investida da furadeira, carga do laser, teletransporte)
var forced_vel := Vector2.ZERO
var thrusting := false        # bota-foguete ligada neste quadro (desenho da chama)
var grip := 1.0               # aderência na parede/borda (1 = cheia); gasta segurando, recarrega no chão
var wall_side := 0            # lado da parede em que está escorregando (desenho)
var frozen_t := 0.0           # congelado (raio congelante): indefeso, desliza
var god := false              # Oficina: invencível (não leva golpe)
var push_vx := 0.0            # empurrão externo deste quadro (ímã); zera a cada quadro
var shield := 0              # capacete de aço: golpes que ainda aguenta
var fall_reason := ""
var last_hit := 99.0
var stomp_immune := 0.0
var dmg := 0.0                # Amassômetro (%): quanto mais amassado, mais longe cada golpe arremessa
var invuln := 0.0             # invulnerável (começo da rodada, voltando da água/vida)
var air_jumps := 1            # pulo duplo do propulsor (recarrega no chão, na parede e na borda)
var plank_t := 0.0            # descendo por uma tábua fina (▼)
var drop_t := 0.0             # descendo pendurado no guindaste (desenho do cabo)
var hanging := false          # agarrado na borda de um caixote
var hang_dir := 0
var hang_t := 0.0
var hang_from := Vector2.ZERO   # posição de onde o robô veio ao agarrar (desliza até a borda, sem tranco)
var climb_t := -1.0             # subindo na borda (0..1); -1 = não está subindo
var climb_from := Vector2.ZERO
var climb_to := Vector2.ZERO
const GRAB_CHARS := ["d", "T", "#", "o", "<", ">", "F", "f", "B", "P"]   # bordas que dá para agarrar (fixas no mapa)
var last_cause := ""          # o que atingiu este robô por último (marretada, pisão, explosão, bola, chão quebrado...)
var last_attacker := -1       # quem causou (jogador), -1 = cenário      # depois de levar pisão, um tempo sem poder levar outro         # segundos desde o último golpe (para saber se caiu sozinho)
var wall_dust := 0.0
var vis: Node2D

func setup(p: int, col_idx: int, m: Node, model := 0) -> void:
	pid = p
	color_idx = col_idx
	main = m
	c = Data.ctrl
	hammer_left = 999
	collision_layer = 0
	collision_mask = 1 | 2 | (1 << (2 + p))
	var hb: Array = c["hitbox"]
	# caixa com os cantos chanfrados: desliza sobre a emenda de caixotes empilhados (o canto reto
	# "tropeçava" na emenda e o robô ficava preso no meio da parede, como se fosse chão)
	var cs := CollisionShape2D.new()
	var shp := ConvexPolygonShape2D.new()
	var w := float(hb[0]) / 2.0
	var h := float(hb[1])
	shp.points = PackedVector2Array([Vector2(-w + 4, -h), Vector2(w - 4, -h), Vector2(w, -h + 8), Vector2(w, -8),
		Vector2(w - 4, 0), Vector2(-w + 4, 0), Vector2(-w, -8), Vector2(-w, -h + 8)])
	cs.shape = shp
	add_child(cs)
	floor_snap_length = 6.0
	floor_block_on_wall = false   # a Godot marcava a parede como "chão" e o robô descia grudado nela
	vis = Vis.new()
	vis.setup(col_idx, model)
	add_child(vis)

func rect() -> Rect2:
	var hb: Array = c["hitbox"]
	return Rect2(position.x - hb[0] / 2.0, position.y - hb[1], hb[0], hb[1])

func f(key: String) -> float:
	return float(c[key])

func _physics_process(dt: float) -> void:
	if main.paused:
		return
	if not alive:
		_dead_fall(dt)
		return
	if not active or finished:
		vis.tick(self, dt)
		return
	var ix := _ix()
	var on_floor := is_on_floor()
	stun_t = maxf(stun_t - dt, 0.0)
	frozen_t = maxf(frozen_t - dt, 0.0)
	invuln = maxf(invuln - dt, 0.0)
	drop_t = maxf(drop_t - dt, 0.0) if not is_on_floor() else 0.0
	# ▼ em cima de uma tábua fina: desce por ela (desliga a colisão de mão única por um instante)
	if plank_t > 0.0:
		plank_t -= dt
		if plank_t <= 0.0 and collision_mask != 0:
			collision_mask |= 2
	elif on_floor and _held("down") and stun_t <= 0.0:
		var lv = main.level
		var under := Vector2i(int(position.x / 64.0), int((position.y + 4.0) / 64.0))
		if lv.ch_at(under) == "=":
			plank_t = 0.28
			collision_mask &= ~2
			position.y += 6.0
			velocity.y = 220.0
			vis.stretch()
			main.dust(position, 0.6)
	last_hit += dt
	if climb_t >= 0.0:
		_climb_update(dt)
		vis.tick(self, dt)
		return
	if forced_t > 0.0:
		forced_t -= dt
		hanging = false
		velocity = forced_vel
		own_vx = forced_vel.x
		move_and_slide()
		if forced_t <= 0.0 and forced_vel.y < -100.0:
			velocity.y = forced_vel.y * 0.4
		was_on_floor = is_on_floor()
		main.check_contacts(self)
		vis.tick(self, dt)
		return
	if hanging:
		_hang_update(dt)
		vis.tick(self, dt)
		return
	for k in fx_t:
		fx_t[k] = maxf(fx_t[k] - dt, 0.0)
	if _pressed("item") and item != "":
		main.use_item(self)
	# timers
	coyote = maxf(coyote - dt, 0.0)
	buffer = maxf(buffer - dt, 0.0)
	wall_lock = maxf(wall_lock - dt, 0.0)
	hammer_anim = maxf(hammer_anim - dt, 0.0)
	if _pressed("jump"):
		buffer = f("jump_buffer_time")
	if on_floor and not spring:
		coyote = f("coyote_time")
	# forças de peças (esteira)
	ext_vx = 0.0
	if on_floor and floor_piece != null and is_instance_valid(floor_piece):
		ext_vx = floor_piece.belt_vx(self, ix)
	ext_vx += push_vx
	push_vx = 0.0
	if main.events != null and main.events.wind != 0.0 and hanging == false:
		ext_vx += main.events.wind * (1.0 if on_floor else 1.3)   # evento Ventania
	# horizontal
	if wall_lock <= 0.0:
		if ix != 0.0:
			facing = int(signf(ix))
		var a := f("accel_ground") if ix != 0.0 else f("decel_ground")
		if not on_floor:
			a *= f("air_mult")
		if stun_t > 0.0:
			a *= 0.25   # empurrado: desliza longe
		if on_floor and main.events != null:
			a *= main.events.slip   # evento Sabão: chão escorregadio
		own_vx = move_toward(own_vx, ix * f("max_run") * speed_k * (float(main.demo.item_cfg("patins")["vel"]) if fx_t["patins"] > 0.0 else 1.0) * (float(main.demo.item_cfg("turbo")["vel"]) if fx_t["turbo"] > 0.0 else 1.0), a * dt)
	# pulo / parede
	var wall_dir := 0 if on_floor else _wall_dir()
	if on_floor:
		air_jumps = 1
	if buffer > 0.0 and not spring:
		if on_floor or coyote > 0.0:
			_jump(ix)
		elif wall_dir != 0 and grip > 0.05:
			_wall_jump(wall_dir)
			if main.mode == "demolicao":
				grip = maxf(grip - 0.2, 0.0)   # cada pulo de parede gasta um pouco
		elif air_jumps > 0 and stun_t <= 0.0 and main.mode == "demolicao":
			_air_jump(ix)
	# sustain: velocidade de subida mantida enquanto segura, até var_jump_time
	if var_jump > 0.0:
		if _held("jump"):
			velocity.y = minf(velocity.y, -_jump_speed())
			var_jump -= dt
		else:
			var_jump = 0.0
	# gravidade
	if var_jump <= 0.0:
		var g := f("gravity")
		if main.events != null:
			g *= main.events.gravity_mult   # evento Gravidade Baixa
		if not spring and _held("jump") and absf(velocity.y) < f("half_grav_threshold"):
			g *= 0.5
		velocity.y += g * dt
	thrusting = false
	if fx_t["foguete"] > 0.0 and not on_floor and _held("jump") and var_jump <= 0.0 and velocity.y > -300.0:
		thrusting = true
		var fc: Dictionary = main.demo.item_cfg("foguete")
		if velocity.y > -float(fc["sobe_max"]):
			velocity.y -= float(fc["empuxo"]) * dt   # bota-foguete: segura PULAR no ar
		if Engine.get_physics_frames() % 4 == 0:
			main.spark(position + Vector2(0, 4), 1)
		if Engine.get_physics_frames() % 18 == 0:
			Audio.play("foguete", _pitch(), -8.0)
	if glue_t > 0.0:
		glue_t -= dt
		var vmax: float = float(main.demo.item_cfg("cola")["vel_max"])
		own_vx = clampf(own_vx, -vmax, vmax)
		if velocity.y < -560.0 and on_floor == false and var_jump > 0.0:
			velocity.y = -560.0
	if spring and velocity.y >= 0.0:
		spring = false
	var max_fall := f("fast_max_fall") if _held("down") else f("max_fall")
	if fx_t["balao"] > 0.0:
		max_fall = float(main.demo.item_cfg("balao")["queda_max"])   # balão: cai devagar
	if fx_t["ventosa"] > 0.0:
		grip = 1.0   # ventosa: gruda sem cansar
		if wall_dir != 0 and _held("up"):
			velocity.y = -float(main.demo.item_cfg("ventosa")["sobe"])   # sobe pela parede
	wall_sliding = wall_dir != 0 and int(signf(ix)) == wall_dir and velocity.y > 0.0 and grip > 0.0
	wall_side = wall_dir if wall_sliding else 0
	if main.mode == "demolicao":
		var ad: Dictionary = main.demo.cfg["aderencia"]
		if on_floor:
			grip = move_toward(grip, 1.0, dt / float(ad["recarga_s"]))
		elif wall_sliding:
			grip = maxf(grip - dt / float(ad["parede_s"]), 0.0)
			if grip <= 0.0:
				Audio.play("parede", _pitch() * 0.8)   # escorregou: a mão soltou
	if wall_sliding:
		air_jumps = 1
		max_fall = f("wall_slide_speed")
		wall_dust -= dt
		if wall_dust <= 0.0:
			wall_dust = 0.08
			main.dust(position + Vector2(wall_dir * 24, -40), 0.5)
			Audio.play("parede", _pitch(), -4.0)
	velocity.y = minf(velocity.y, max_fall)
	# marreta (não trava o movimento)
	if _pressed("hammer") and hammer_anim <= 0.0:
		hammer_anim = f("hammer_time")
		Audio.play("marreta_vento", _pitch())
		main.try_hammer(self)
	# mover
	velocity.x = own_vx + ext_vx
	_corner_correction(dt)
	move_and_slide()
	if is_on_wall():
		var n := get_wall_normal()
		if signf(own_vx) == -signf(n.x):
			own_vx = 0.0
	if is_on_ceiling():
		var_jump = 0.0
		velocity.y = maxf(velocity.y, 0.0)
	floor_piece = null
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var o := col.get_collider()
		if o != null and o.has_meta("piece") and col.get_normal().y < -0.7:
			floor_piece = o.get_meta("piece")
	if not is_on_floor() and main.mode == "demolicao":
		_try_grab(ix)
	var landed := is_on_floor() and not was_on_floor
	was_on_floor = is_on_floor()
	if landed:
		Audio.play("aterrissa", _pitch(), -5.0)
		vis.land()
		main.dust(position)
	if floor_piece != null and is_instance_valid(floor_piece):
		floor_piece.on_stand(self)
	main.check_contacts(self)
	vis.tick(self, dt)

func _held(a: String) -> bool:
	return stun_t <= 0.0 and PlayerInput.held(pid, a)

func _pressed(a: String) -> bool:
	return stun_t <= 0.0 and PlayerInput.pressed(pid, a)

func _ix() -> float:
	return 0.0 if stun_t > 0.0 else PlayerInput.axis_x(pid)

func _jump_speed() -> float:
	var js := float(c["jump_speed"])
	if fx_t["mola"] > 0.0:
		js *= float(main.demo.item_cfg("mola")["jump_mult"])
	return js

## O capacete de aço aguenta o golpe? (gasta o escudo)
func absorb() -> bool:
	if shield <= 0:
		return false
	shield -= 1
	Audio.play("capacete")
	main.spark(rect().get_center() + Vector2(0, -30), 8)
	main.float_text(position + Vector2(0, -110), "BLOQUEOU!", Color.WHITE)
	vis.land()
	return true

func fx_flags() -> Dictionary:
	return {"martelao": fx_t["martelao"] > 0.0, "mola": fx_t["mola"] > 0.0, "capacete": shield > 0, "item": item,
		"ima": fx_t["ima"] > 0.0, "foguete": fx_t["foguete"] > 0.0, "patins": fx_t["patins"] > 0.0, "escudo": fx_t["escudo"] > 0.0, "foguete_on": thrusting, "cola": glue_t > 0.0,
		"furando": main.demo.tools != null and main.demo.tools.drilling(pid) if main.mode == "demolicao" else false,
		"usando": main.demo.tools.using(pid) if main.mode == "demolicao" and main.demo.tools != null else {}}

## Pulo duplo do propulsor (um no ar; recarrega no chão, na parede e na borda).
func _air_jump(ix: float) -> void:
	air_jumps -= 1
	Audio.play("pulo", _pitch() * 1.25)
	velocity.y = -_jump_speed() * float(main.demo.cfg["recuperacao"]["pulo_duplo"])
	own_vx = maxf(absf(own_vx), absf(ix) * f("max_run") * 0.8) * (signf(ix) if ix != 0.0 else signf(own_vx))
	var_jump = f("var_jump_time") * 0.6
	buffer = 0.0
	vis.stretch()
	main.dust(position + Vector2(0, -6), 0.7)

## Agarra a quina de um caixote: caindo, segurando na direção dela, com as mãos na altura do topo.
## Só bordas fixas do mapa (não plataforma que anda nem gangorra) e com espaço para ficar em pé em cima.
func _try_grab(ix: float) -> void:
	if velocity.y < -40.0 or stun_t > 0.0 or ix == 0.0 or PlayerInput.held(pid, "down") or grip < 0.15:
		return
	var dir := int(signf(ix))
	var lv = main.level
	var cell := Vector2i(int(floor((position.x + dir * 32.0) / 64.0)), int(floor((position.y - 66.0) / 64.0)))
	if not (lv.ch_at(cell) in GRAB_CHARS) or not _room_above(cell):
		return
	var top := cell.y * 64.0
	var head := position.y - 72.0
	if head < top - 26.0 or head > top + 16.0:
		return
	var target := Vector2(cell.x * 64.0 + (-24.0 if dir > 0 else 64.0 + 24.0), top + 58.0)
	for yy in [target.y - 70.0, target.y - 36.0, target.y - 2.0]:
		for xx in [target.x - 22.0, target.x + 22.0]:
			if lv.is_solid(Vector2i(int(floor(xx / 64.0)), int(floor(yy / 64.0)))):
				return   # a posição de pendurar está ocupada
	hanging = true
	wall_sliding = false   # não está mais escorregando: o desenho vira para a parede
	wall_side = 0
	hang_dir = dir
	hang_t = 0.0
	hang_from = position
	facing = dir
	air_jumps = 1
	velocity = Vector2.ZERO
	own_vx = 0.0
	position = target
	reset_physics_interpolation()
	vis.hang_snap = hang_from - target   # o desenho desliza da posição antiga até a borda
	Audio.play("parede", _pitch())

## Em cima da célula cabe o robô inteiro (72 px = 2 células livres; fora do mapa no alto conta como livre).
func _room_above(cell: Vector2i) -> bool:
	var lv = main.level
	for k in [1, 2]:
		var c2 := cell + Vector2i(0, -k)
		if c2.y < 0 or lv.is_solid(c2):
			return false
	return true

func _hang_update(dt: float) -> void:
	hang_t += dt
	velocity = Vector2.ZERO
	var lv = main.level
	var cell := Vector2i(int(floor((position.x + hang_dir * 32.0) / 64.0)), int(floor((position.y - 58.0) / 64.0)))
	var max_t := float(main.demo.cfg["recuperacao"]["borda_max_s"])
	grip = maxf(grip - dt / max_t, 0.0)   # segurar a borda cansa (o medidor acima da cabeça esvazia)
	if not lv.is_solid(cell) or grip <= 0.0 or PlayerInput.pressed(pid, "down") or PlayerInput.axis_x(pid) == -hang_dir:
		hanging = false   # caixote quebrou, cansou ou soltou
		if PlayerInput.axis_x(pid) == -hang_dir:
			own_vx = -hang_dir * 220.0   # soltou para trás: afasta um pouco da parede
		return
	if PlayerInput.pressed(pid, "jump") or PlayerInput.pressed(pid, "up"):
		if not _room_above(cell):
			# sem espaço para subir: pula para longe da parede
			hanging = false
			velocity.y = -_jump_speed() * 0.8
			own_vx = -hang_dir * f("wall_jump_h_speed") * 0.7
			wall_lock = f("wall_jump_lock_time")
			Audio.play("pulo", _pitch())
			return
		# escalada animada: sobe e passa por cima da quina (~0,16 s), sem teletransporte
		hanging = false
		climb_t = 0.0
		climb_from = position
		climb_to = Vector2(cell.x * 64.0 + 32.0 - hang_dir * 6.0, cell.y * 64.0 - 1.0)
		Audio.play("pulo", _pitch())
		vis.stretch()

func _climb_update(dt: float) -> void:
	climb_t = minf(climb_t + dt / 0.16, 1.0)
	var k := climb_t
	# primeiro sobe (corpo passa da quina), depois avança por cima
	var up := clampf(k / 0.6, 0.0, 1.0)
	var fwd := clampf((k - 0.35) / 0.65, 0.0, 1.0)
	var y := lerpf(climb_from.y, climb_to.y, 1.0 - pow(1.0 - up, 2.0))
	var x := lerpf(climb_from.x, climb_to.x, fwd * fwd * (3.0 - 2.0 * fwd))
	position = Vector2(x, y)
	velocity = Vector2.ZERO
	if climb_t >= 1.0:
		climb_t = -1.0
		position = climb_to
		velocity = Vector2(0, -120)
		own_vx = hang_dir * 160.0
		main.dust(position, 0.6)

## Golpe com o Amassômetro: soma dano e o empurrão cresce com ele. kind = chave em demolicao.amassometro.
## Retorna false se não pegou (invulnerável ou capacete).
func take_hit(dir: int, kind: String, by := -1) -> bool:
	if invuln > 0.0 or god:
		return false
	last_hit = 0.0
	last_cause = {"marretada": "marretada", "martelao": "marretada", "explosao": "explosão", "bola": "bola"}.get(kind, kind)
	last_attacker = by
	hanging = false
	if absorb():
		return false
	var am: Dictionary = main.demo.cfg["amassometro"]
	var k: Dictionary = am[kind]
	dmg += float(k["dano"])
	var kx := minf(float(k["kx"]) + dmg * float(k["kx_por"]), float(am["max_kx"]))
	var ky := float(k["ky"]) + dmg * float(k["ky_por"])
	if main.demo.rule() == "fuga":   # na Fuga o empurrão atrapalha, mas não decide sozinho
		kx *= 0.6
		ky *= 0.7
	var stun := minf(float(am["stun_base"]) + dmg * float(am["stun_por"]), float(am["stun_max"]))
	if frozen_t > 0.0:
		# pancada em quem está congelado: o gelo estilhaça e o empurrão é maior
		var mult := float(main.demo.item_cfg("congelador")["quebra_mult"])
		kx = minf(kx * mult, float(am["max_kx"]) * 1.2)
		ky *= mult
		frozen_t = 0.0
		stun_t = 0.0
		main.demo.tools.shatter(rect().get_center())
	main.float_text(position + Vector2(0, -100), "+%d%%" % int(k["dano"]), main.dmg_color(dmg))
	_apply_knock(dir, kx, ky, stun)
	PlayerInput.vibrate(pid, 0.35 + dmg / 300.0, 0.15 + dmg / 250.0, 0.12 + minf(dmg, 150.0) / 1000.0)
	return true

## Empurrão direto (modo Clássico e mecânicas antigas).
func knock(dir: int, vx: float, vy: float, stun: float) -> void:
	if invuln > 0.0:
		return
	last_hit = 0.0
	hanging = false
	if absorb():
		return
	_apply_knock(dir, vx, vy, stun)

func _apply_knock(dir: int, vx: float, vy: float, stun: float) -> void:
	own_vx = dir * vx
	velocity.y = -vy
	Audio.voice("voz_ai", vis.model)
	var_jump = 0.0
	stun_t = maxf(stun_t, stun)
	vis.stretch()

## Tom dos sons do robô por jogador (P1 mais grave → P4 mais agudo).
func _pitch() -> float:
	return 0.92 + pid * 0.08

func _jump(ix: float) -> void:
	Audio.play("pulo_mola" if fx_t["mola"] > 0.0 else "pulo", _pitch())
	velocity.y = -_jump_speed()
	own_vx += ix * f("jump_h_boost")
	var_jump = f("var_jump_time")
	buffer = 0.0
	coyote = 0.0
	vis.stretch()
	main.dust(position)

func _wall_jump(wd: int) -> void:
	Audio.play("pulo", _pitch() * 1.08)
	velocity.y = -_jump_speed()
	own_vx = -wd * f("wall_jump_h_speed")
	facing = -wd
	wall_lock = f("wall_jump_lock_time")
	var_jump = f("var_jump_time")
	buffer = 0.0
	vis.stretch()

func _wall_dir() -> int:
	for d in [1, -1]:
		if test_move(global_transform, Vector2(2 * d, 0)) and _real_wall(d):
			return d
	return 0

## Na Demolição, a parede invisível da borda do mapa não serve para escorregar/pular (parecia grudar no nada).
func _real_wall(d: int) -> bool:
	if main.mode != "demolicao":
		return true
	var lv = main.level
	var x := int(floor((position.x + d * 27.0) / 64.0))
	var hits := 0
	for yy in [position.y - 60.0, position.y - 36.0, position.y - 10.0]:
		var c := Vector2i(x, int(floor(yy / 64.0)))
		var ch: String = lv.ch_at(c)
		if ch == "I":
			return false
		if lv.is_solid(c):
			hits += 1
	return hits > 0 or lv.extra_solid.is_valid()   # plataforma que anda também é parede

func _corner_correction(dt: float) -> void:
	if velocity.y >= 0.0:
		return
	var up := Vector2(0, velocity.y * dt)
	if not test_move(global_transform, up):
		return
	for s in range(1, int(f("corner_correction_px")) + 1):
		for d in [-1, 1]:
			var shift := Vector2(d * s, 0)
			if not test_move(global_transform, shift) and not test_move(global_transform.translated(shift), up):
				position.x += d * s
				return

func launch(tiles: float) -> void:
	Audio.play("pulo_mola", _pitch())
	# + g·dt/2 compensa a integração por passos (altura final = tiles)
	velocity.y = -sqrt(2.0 * f("gravity") * tiles * 64.0) - f("gravity") / (2.0 * Engine.physics_ticks_per_second)
	spring = true
	var_jump = 0.0
	coyote = 0.0
	buffer = 0.0
	vis.stretch()

## Eliminado: o robô desmonta em peças (main.break_robot) e some.
func eliminate() -> void:
	PlayerInput.vibrate(pid, 0.8, 1.0, 0.45)
	Audio.play("eliminado", _pitch())
	alive = false
	active = false
	collision_mask = 0
	main.break_robot(self)
	visible = false

func _dead_fall(_dt: float) -> void:
	pass

## Chegou: dá um pulinho de alegria, anda até o meio do elevador e some lá dentro.
func finish() -> void:
	finished = true
	active = false
	vis.expression = "vitoria"
	Audio.play("elevador")
	Audio.voice("voz_eba", vis.model)
	var g: Rect2 = main.level.goal_rect
	var floor_pos := Vector2(g.get_center().x, g.end.y)
	facing = 1 if floor_pos.x >= position.x else -1
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# desce até o chão (se chegou pulando), pulinho de alegria no centro da porta, entra e some
	tw.tween_property(self, "position", floor_pos, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(vis, "position", Vector2(0, -16), 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(vis, "position", Vector2.ZERO, 0.13).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "scale", Vector2(0.85, 0.85), 0.25)
	tw.parallel().tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 0.0), 0.25)
	tw.tween_callback(func(): visible = false)
