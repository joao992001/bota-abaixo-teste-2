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
var wall_dust := 0.0
var vis: Node2D

func setup(p: int, col_idx: int, m: Node, acc := 0, model := 0) -> void:
	pid = p
	color_idx = col_idx
	main = m
	c = Data.ctrl
	hammer_left = int(Data.scoring["hammer"]["uses_per_round"])
	collision_layer = 0
	collision_mask = 1 | 2 | (1 << (2 + p))
	var hb: Array = c["hitbox"]
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(hb[0], hb[1])
	cs.shape = r
	cs.position = Vector2(0, -float(hb[1]) / 2.0)
	add_child(cs)
	floor_snap_length = 6.0
	vis = Vis.new()
	vis.setup(col_idx, acc, model)
	add_child(vis)

func rect() -> Rect2:
	var hb: Array = c["hitbox"]
	return Rect2(position.x - hb[0] / 2.0, position.y - hb[1], hb[0], hb[1])

func f(key: String) -> float:
	return float(c[key])

func _physics_process(dt: float) -> void:
	if not alive:
		_dead_fall(dt)
		return
	if not active or finished:
		vis.tick(self, dt)
		return
	var ix := PlayerInput.axis_x(pid)
	var on_floor := is_on_floor()
	# timers
	coyote = maxf(coyote - dt, 0.0)
	buffer = maxf(buffer - dt, 0.0)
	wall_lock = maxf(wall_lock - dt, 0.0)
	hammer_anim = maxf(hammer_anim - dt, 0.0)
	if PlayerInput.pressed(pid, "jump"):
		buffer = f("jump_buffer_time")
	if on_floor and not spring:
		coyote = f("coyote_time")
	# forças de peças (esteira)
	ext_vx = 0.0
	if on_floor and floor_piece != null and is_instance_valid(floor_piece):
		ext_vx = floor_piece.belt_vx(self, ix)
	# horizontal
	if wall_lock <= 0.0:
		if ix != 0.0:
			facing = int(signf(ix))
		var a := f("accel_ground") if ix != 0.0 else f("decel_ground")
		if not on_floor:
			a *= f("air_mult")
		own_vx = move_toward(own_vx, ix * f("max_run"), a * dt)
	# pulo / parede
	var wall_dir := 0 if on_floor else _wall_dir()
	if buffer > 0.0 and not spring:
		if on_floor or coyote > 0.0:
			_jump(ix)
		elif wall_dir != 0:
			_wall_jump(wall_dir)
	# sustain: velocidade de subida mantida enquanto segura, até var_jump_time
	if var_jump > 0.0:
		if PlayerInput.held(pid, "jump"):
			velocity.y = minf(velocity.y, -f("jump_speed"))
			var_jump -= dt
		else:
			var_jump = 0.0
	# gravidade
	if var_jump <= 0.0:
		var g := f("gravity")
		if not spring and PlayerInput.held(pid, "jump") and absf(velocity.y) < f("half_grav_threshold"):
			g *= 0.5
		velocity.y += g * dt
	if spring and velocity.y >= 0.0:
		spring = false
	var max_fall := f("fast_max_fall") if PlayerInput.held(pid, "down") else f("max_fall")
	wall_sliding = wall_dir != 0 and int(signf(ix)) == wall_dir and velocity.y > 0.0
	if wall_sliding:
		max_fall = f("wall_slide_speed")
		wall_dust -= dt
		if wall_dust <= 0.0:
			wall_dust = 0.08
			main.dust(position + Vector2(wall_dir * 24, -40), 0.5)
	velocity.y = minf(velocity.y, max_fall)
	# marreta (não trava o movimento)
	if PlayerInput.pressed(pid, "hammer") and hammer_anim <= 0.0:
		hammer_anim = f("hammer_time")
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
	var landed := is_on_floor() and not was_on_floor
	was_on_floor = is_on_floor()
	if landed:
		vis.land()
		main.dust(position)
	if floor_piece != null and is_instance_valid(floor_piece):
		floor_piece.on_stand(self)
	main.check_contacts(self)
	vis.tick(self, dt)

func _jump(ix: float) -> void:
	velocity.y = -f("jump_speed")
	own_vx += ix * f("jump_h_boost")
	var_jump = f("var_jump_time")
	buffer = 0.0
	coyote = 0.0
	vis.stretch()
	main.dust(position)

func _wall_jump(wd: int) -> void:
	velocity.y = -f("jump_speed")
	own_vx = -wd * f("wall_jump_h_speed")
	facing = -wd
	wall_lock = f("wall_jump_lock_time")
	var_jump = f("var_jump_time")
	buffer = 0.0
	vis.stretch()

func _wall_dir() -> int:
	if test_move(global_transform, Vector2(2, 0)):
		return 1
	if test_move(global_transform, Vector2(-2, 0)):
		return -1
	return 0

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
	# + g·dt/2 compensa a integração por passos (altura final = tiles)
	velocity.y = -sqrt(2.0 * f("gravity") * tiles * 64.0) - f("gravity") / (2.0 * Engine.physics_ticks_per_second)
	spring = true
	var_jump = 0.0
	coyote = 0.0
	buffer = 0.0
	vis.stretch()

## Eliminado: o robô desmonta em peças (main.break_robot) e some.
func eliminate() -> void:
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
	var g: Rect2 = main.level.goal_rect
	var floor_pos := Vector2(g.get_center().x, g.end.y)
	facing = 1 if floor_pos.x >= position.x else -1
	var tw := create_tween()
	# desce até o chão (se chegou pulando), pulinho de alegria no centro da porta, entra e some
	tw.tween_property(self, "position", floor_pos, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(vis, "position", Vector2(0, -16), 0.13).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(vis, "position", Vector2.ZERO, 0.13).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "scale", Vector2(0.85, 0.85), 0.25)
	tw.parallel().tween_property(self, "modulate", Color(0.35, 0.3, 0.3, 0.0), 0.25)
	tw.tween_callback(func(): visible = false)
