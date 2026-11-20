extends Node2D
## Partida: ENTRADA → ESCOLHA → CONSTRUÇÃO → CORRIDA → PLACAR → (próxima rodada | VITÓRIA).
## Tempos e pontos em data/scoring.json; peças em data/pieces.json.
## Debug: F1 hitboxes/info · F2 pula fase · F3 troca peça · F4 troca dono · clique esq. coloca, dir. remove · F5 jogador parado · F6 câmera lenta.

const Level := preload("res://level/level.gd")
const Background := preload("res://level/background.gd")
const Robot := preload("res://player/robot.gd")
const Hud := preload("res://ui/hud.gd")
const Debris := preload("res://fx/debris.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const PIECE_SCRIPTS := {
	"P01": preload("res://pieces/viga.gd"),
	"P02": preload("res://pieces/mola.gd"),
	"P03": preload("res://pieces/serra.gd"),
	"P04": preload("res://pieces/esteira.gd"),
}
const T := 64
const MILESTONE := 1

enum S { JOIN, PICK, BUILD, RUN, SCORE, WIN }
var state := S.JOIN
var timer := 0.0
var round_no := 0
var players: Array = []      # {dev, color, score, piece, sel, unlock, cursor, ghost, placed, rep}
var pieces: Array = []
var conveyor: Array = []
var pick_order: Array = []
var robots: Array = []
var finish_order: Array = []
var round_kills := {}
var round_hammer := {}
var round_points: Array = []
var no_finish_streak := 0
var embargo_msg := ""
var countdown := 0.0
var end_delay := -1.0
var winner := -1
var debug := false
var debug_piece := 0
var debug_owner := 0
var floaters: Array = []     # textos flutuantes {pos, text, color, t}
var puffs: Array = []        # poeira {pos, t, r}
var sparks: Array = []       # estrelinhas {pos, vel, t, rot}
var shake_amt := 0.0
const SHAKE_ON := true
var door_open := 0.0
var cam_lock: Array = []      # [zoom, centro] fixa a câmera (capturas de animação)

var world: Node2D
var level: Level
var bg: Background
var bg_layer: CanvasLayer
var camera: Camera2D
var pieces_root: Node2D
var robots_root: Node2D
var overlay: Node2D
var conveyor_root: Node2D
var hud: Hud
var rng := RandomNumberGenerator.new()
var cam_zoom := 1.0
var cam_center := Vector2(960, 512)
const CAM_MAX := 1.9

func _ready() -> void:
	rng.randomize()
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg = Background.new()
	bg_layer.add_child(bg)
	camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	add_child(camera)
	camera.make_current()
	world = Node2D.new()
	world.position = Vector2(0, Data.ARENA_Y)
	add_child(world)
	level = Level.new()
	world.add_child(level)
	level.load_level("canteiro")
	pieces_root = Node2D.new()
	world.add_child(pieces_root)
	robots_root = Node2D.new()
	world.add_child(robots_root)
	overlay = Node2D.new()
	overlay.draw.connect(_draw_overlay)
	world.add_child(overlay)
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	hud = Hud.new()
	hud.main = self
	hud_layer.add_child(hud)
	var conv_layer := CanvasLayer.new()
	conv_layer.layer = 2
	add_child(conv_layer)
	conveyor_root = Node2D.new()
	conv_layer.add_child(conveyor_root)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest" or a.begins_with("--shot") or a.begins_with("--anim"):
			var drv: Node = load("res://tests/driver.gd").new()
			drv.main = self
			add_child(drv)
			break

func implemented_ids() -> Array:
	return Data.piece_ids(MILESTONE, PIECE_SCRIPTS.keys())

func player_color(p: int) -> Color:
	if p >= 0 and p < players.size():
		return Data.COLORS[players[p]["color"]]
	return Data.COLORS[clampi(p, 0, 3)]

func timers(key: String) -> float:
	return float(Data.scoring["timers"][key])

# ---------------------------------------------------------------- loop
func _physics_process(dt: float) -> void:
	match state:
		S.JOIN: _join_update()
		S.PICK: _pick_update(dt)
		S.BUILD: _build_update(dt)
		S.RUN: _run_update(dt)
		S.SCORE:
			timer -= dt
			if timer <= 0.0:
				_after_score()
		S.WIN:
			for i in players.size():
				if PlayerInput.pressed(i, "start") or PlayerInput.pressed(i, "jump"):
					start_match()
					break
	for fl in floaters:
		fl["t"] += dt
	floaters = floaters.filter(func(x): return x["t"] < 1.2)
	for p in puffs:
		p["t"] += dt
	puffs = puffs.filter(func(x): return x["t"] < 0.45)
	for s in sparks:
		s["t"] += dt
		s["pos"] += s["vel"] * dt
		s["vel"] *= 0.9
	sparks = sparks.filter(func(x): return x["t"] < 0.4)
	# portas do elevador abrem com robô por perto ou chegando
	var near := false
	for r in robots:
		if r.visible and r.position.distance_to(level.goal_rect.get_center()) < 170.0:
			near = true
	door_open = move_toward(door_open, 1.0 if near else 0.0, dt * 5.0)
	level.door_open = door_open
	_update_camera(dt)
	overlay.queue_redraw()
	hud.queue_redraw()

# ---------------------------------------------------------------- câmera
## Na corrida, aproxima para enquadrar todos os robôs ainda em jogo (1x a CAM_MAX); nas outras fases mostra a obra inteira.
func _update_camera(dt: float) -> void:
	var tz := 1.0
	var tc := Vector2(960, 512)
	if state == S.RUN:
		var box := Rect2()
		var first := true
		for r in robots:
			if r.alive and not r.finished:
				var p: Vector2 = r.rect().get_center()
				box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
				first = false
		if not first:
			box = box.grow_individual(380, 300, 380, 220)
			tz = clampf(minf(1920.0 / box.size.x, 1024.0 / box.size.y), 1.0, CAM_MAX)
			tc = box.get_center()
		else:
			tz = cam_zoom
			tc = cam_center
	var k := 1.0 - exp(-dt * 3.0)
	if cam_lock.size() == 2:
		tz = cam_lock[0]
		tc = cam_lock[1]
		k = 1.0
	cam_zoom = lerpf(cam_zoom, tz, k)
	cam_center = cam_center.lerp(tc, k)
	var hw := 960.0 / cam_zoom
	var hh := 512.0 / cam_zoom
	cam_center.x = clampf(cam_center.x, hw, 1920.0 - hw)
	cam_center.y = clampf(cam_center.y, hh, 1024.0 - hh)
	camera.zoom = Vector2(cam_zoom, cam_zoom)
	camera.position = cam_center + Vector2(0, Data.ARENA_Y) - Vector2(0, 28) / cam_zoom
	shake_amt = move_toward(shake_amt, 0.0, dt * 40.0)
	camera.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amt
	# fundo em paralaxe (camada própria, move menos que o mundo)
	var zb := 1.0 + (cam_zoom - 1.0) * 0.4
	var bc := Vector2(960, 540) + (cam_center - Vector2(960, 512)) * 0.5
	bc.x = clampf(bc.x, 960.0 / zb, 1920.0 - 960.0 / zb)
	bc.y = clampf(bc.y, 540.0 / zb, 1080.0 - 540.0 / zb)
	bg_layer.scale = Vector2(zb, zb)
	bg_layer.offset = Vector2(960, 540) - bc * zb

func to_screen(p: Vector2) -> Vector2:
	return (p + world.position - camera.position) * cam_zoom + Vector2(960, 540)

# ---------------------------------------------------------------- entrada
func _join_update() -> void:
	for dev in PlayerInput.all_devices():
		if dev in PlayerInput.slots:
			continue
		if PlayerInput.dev_pressed(dev, "jump") and players.size() < 4:
			add_player(dev)
	for i in players.size():
		if PlayerInput.pressed(i, "left"):
			_cycle_color(i, -1)
		if PlayerInput.pressed(i, "right"):
			_cycle_color(i, 1)
		if PlayerInput.pressed(i, "up"):
			players[i]["model"] = posmod(players[i]["model"] - 1, Data.MODELS.size())
		if PlayerInput.pressed(i, "down"):
			players[i]["model"] = posmod(players[i]["model"] + 1, Data.MODELS.size())
		if PlayerInput.pressed(i, "hammer"):
			players[i]["acc"] = posmod(players[i]["acc"] + 1, Data.ACCS.size())
	if players.size() >= 2:
		for i in players.size():
			if PlayerInput.pressed(i, "start"):
				start_match()
				return

func add_player(dev: String) -> void:
	var used := players.map(func(p): return p["color"])
	var col := 0
	while col in used:
		col += 1
	players.append({"dev": dev, "color": col, "acc": 0, "model": players.size() % Data.MODELS.size(), "score": 0})
	PlayerInput.slots.append(dev)

func _cycle_color(i: int, d: int) -> void:
	var used := players.map(func(p): return p["color"])
	var col: int = players[i]["color"]
	for _k in 4:
		col = posmod(col + d, 4)
		if not (col in used):
			players[i]["color"] = col
			return

func start_match() -> void:
	for p in players:
		p["score"] = 0
	for pc in pieces:
		pc.queue_free()
	pieces.clear()
	round_no = 0
	no_finish_streak = 0
	winner = -1
	start_pick()

# ---------------------------------------------------------------- escolha
func start_pick() -> void:
	_clear_robots()
	round_no += 1
	embargo_msg = ""
	state = S.PICK
	timer = timers("pick_seconds")
	var pool := implemented_ids()
	conveyor = []
	for i in players.size() + int(Data.scoring["conveyor_extra_pieces"]):
		conveyor.append(pool[rng.randi() % pool.size()])
	var keyed := []
	for i in players.size():
		keyed.append([players[i]["score"], rng.randf(), i])
	keyed.sort()
	pick_order = keyed.map(func(k): return k[2])
	for k in pick_order.size():
		var p: Dictionary = players[pick_order[k]]
		p["piece"] = ""
		p["sel"] = k % conveyor.size()
		p["unlock"] = k * timers("pick_seconds") * 0.12
	_rebuild_conveyor()

func _rebuild_conveyor() -> void:
	for ch in conveyor_root.get_children():
		ch.queue_free()
	var n := conveyor.size()
	for i in n:
		if conveyor[i] == "":
			continue
		var pc := make_piece(conveyor[i], -1, Vector2i.ZERO)
		var sz := Vector2(pc.size_tiles() * T)
		pc.position = conveyor_slot(i) - sz / 2.0
		conveyor_root.add_child(pc)

func conveyor_slot(i: int) -> Vector2:
	var n := conveyor.size()
	return Vector2(960 + (i - (n - 1) / 2.0) * 250, 560)

func _pick_update(dt: float) -> void:
	timer -= dt
	var elapsed := timers("pick_seconds") - timer
	for i in pick_order:
		var p: Dictionary = players[i]
		if p["piece"] != "":
			continue
		if PlayerInput.pressed(i, "left"):
			p["sel"] = posmod(p["sel"] - 1, conveyor.size())
		if PlayerInput.pressed(i, "right"):
			p["sel"] = posmod(p["sel"] + 1, conveyor.size())
		if PlayerInput.pressed(i, "jump") and elapsed >= p["unlock"] and conveyor[p["sel"]] != "":
			p["piece"] = conveyor[p["sel"]]
			conveyor[p["sel"]] = ""
			_rebuild_conveyor()
	var all_done := players.all(func(p): return p["piece"] != "")
	if all_done or timer <= 0.0:
		for i in pick_order:
			if players[i]["piece"] == "":
				var left := conveyor.filter(func(x): return x != "")
				players[i]["piece"] = left[rng.randi() % left.size()]
				conveyor[conveyor.find(players[i]["piece"])] = ""
		_rebuild_conveyor()
		start_build()

# ---------------------------------------------------------------- construção
func start_build() -> void:
	for ch in conveyor_root.get_children():
		ch.queue_free()
	state = S.BUILD
	timer = timers("build_seconds")
	for i in players.size():
		var p: Dictionary = players[i]
		p["placed"] = false
		p["rep"] = 0.0
		p["cursor"] = Vector2i(9 + i * 4, 5)
		p["ghost"] = make_piece(p["piece"], i, p["cursor"])
		p["ghost"].modulate = Color(1, 1, 1, 0.7)
		pieces_root.add_child(p["ghost"])

func make_piece(id: String, owner: int, c: Vector2i, r: int = 0) -> Node2D:
	var pc: Node2D = PIECE_SCRIPTS[id].new()
	pc.main = self
	pc.setup(id, owner, players[owner]["color"] if owner >= 0 and owner < players.size() else (owner if owner >= 0 else 4), c, r)
	return pc

func can_place(pc: Node2D) -> bool:
	for c in pc.cells():
		if not level.can_build(c):
			return false
		for other in pieces:
			if c in other.cells():
				return false
	return true

func _build_update(dt: float) -> void:
	timer -= dt
	for i in players.size():
		var p: Dictionary = players[i]
		if p["placed"]:
			continue
		var g: Node2D = p["ghost"]
		var d := Vector2i.ZERO
		var dirs := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT, "up": Vector2i.UP, "down": Vector2i.DOWN}
		var any_held := false
		for a in dirs:
			if PlayerInput.pressed(i, a):
				d += dirs[a]
				p["rep"] = 0.22
			elif PlayerInput.held(i, a):
				any_held = true
		if d == Vector2i.ZERO and any_held:
			p["rep"] -= dt
			if p["rep"] <= 0.0:
				p["rep"] = 0.07
				for a in dirs:
					if PlayerInput.held(i, a):
						d += dirs[a]
		if PlayerInput.pressed(i, "hammer"):
			g.rotate_piece()
		var sz: Vector2i = g.size_tiles()
		var cur: Vector2i = p["cursor"] + d
		cur.x = clampi(cur.x, 0, level.cols - sz.x)
		cur.y = clampi(cur.y, 0, level.rows - sz.y)
		p["cursor"] = cur
		g.move_to(cur)
		if PlayerInput.pressed(i, "jump") and can_place(g):
			place_piece(g)
			p["placed"] = true
	var all_done := players.all(func(p): return p["placed"])
	if all_done or timer <= 0.0:
		for p in players:
			if not p["placed"]:
				p["ghost"].queue_free()
		start_run()

func place_piece(pc: Node2D) -> void:
	pc.activate(round_no)
	if pc.get_parent() == null:
		pieces_root.add_child(pc)
	pieces.append(pc)

# ---------------------------------------------------------------- corrida
func _clear_robots() -> void:
	for r in robots:
		r.queue_free()
	robots.clear()

func start_run() -> void:
	_clear_robots()
	state = S.RUN
	timer = timers("run_seconds")
	countdown = 1.5
	end_delay = -1.0
	finish_order = []
	round_kills = {}
	round_hammer = {}
	for i in players.size():
		var r: CharacterBody2D = Robot.new()
		r.setup(i, players[i]["color"], self, players[i]["acc"], players[i]["model"])
		r.position = level.spawns.get(i + 1, level.spawns[1])
		robots_root.add_child(r)
		robots.append(r)

func _run_update(dt: float) -> void:
	if countdown > 0.0:
		countdown -= dt
		if countdown <= 0.0:
			for r in robots:
				r.active = true
		return
	if end_delay >= 0.0:
		end_delay -= dt
		if end_delay < 0.0:
			start_score()
		return
	timer -= dt
	if timer <= 0.0:
		for r in robots:
			if r.alive and not r.finished:
				kill(r, -1, null)
	if robots.all(func(r): return not r.alive or r.finished):
		end_delay = 1.0

func check_contacts(r: CharacterBody2D) -> void:
	if state != S.RUN or not r.alive or r.finished:
		return
	for pc in pieces:
		pc.interact(r)
		if not r.alive:
			return
	var rr: Rect2 = r.rect()
	for h in level.hazard_rects:
		if rr.intersects(h):
			kill(r, -1, null)
			return
	if rr.intersects(level.goal_rect):
		finish(r)
	elif r.position.y > level.rows * T + 100:
		kill(r, -1, null)

func kill(r: CharacterBody2D, owner: int, pc: Node2D) -> void:
	if not r.alive or r.finished:
		return
	r.eliminate()
	if owner >= 0 and owner != r.pid:
		round_kills[owner] = round_kills.get(owner, 0) + 1
		if pc != null:
			pc.kills += 1
		float_text(r.position + Vector2(0, -90), "+%d" % int(Data.scoring["points"]["kill_by_owned_piece"]), player_color(owner))

func finish(r: CharacterBody2D) -> void:
	r.finish()
	finish_order.append(r.pid)
	float_text(r.position + Vector2(0, -100), "1º!" if finish_order.size() == 1 else "%dº" % finish_order.size(), player_color(r.pid))

func try_hammer(r: CharacterBody2D) -> void:
	if r.hammer_left <= 0:
		return
	var reach := float(Data.ctrl["hammer_reach_px"])
	var rr: Rect2 = r.rect()
	var hit := Rect2(rr.end.x if r.facing > 0 else rr.position.x - reach, rr.position.y, reach, rr.size.y)
	var own_ok: bool = Data.scoring["hammer"]["can_smash_own"]
	for pc in pieces:
		if pc.owner_id < 0 or (pc.owner_id == r.pid and not own_ok):
			continue
		if hit.intersects(pc.world_rect()):
			r.hammer_left -= 1
			round_hammer[r.pid] = round_hammer.get(r.pid, 0) + 1
			float_text(pc.world_rect().get_center(), "+%d" % int(Data.scoring["points"]["hammer_smash"]), player_color(r.pid))
			for k in 4:
				dust(pc.world_rect().get_center() + Vector2(rng.randf_range(-40, 40), rng.randf_range(-10, 30)))
			remove_piece(pc)
			return

func remove_piece(pc: Node2D) -> void:
	pieces.erase(pc)
	pc.queue_free()

func robot_near(owner: int, pos: Vector2, dist: float, is_owner: bool) -> bool:
	for r in robots:
		if r.alive and not r.finished and (r.pid == owner) == is_owner:
			if r.rect().get_center().distance_to(pos) < dist:
				return true
	return false

func danger_near(r: CharacterBody2D) -> bool:
	var c: Vector2 = r.rect().get_center()
	for pc in pieces:
		if pc.is_hazard_for(r.pid) and pc.world_rect().get_center().distance_to(c) < 1.6 * T:
			return true
	for h in level.hazard_rects:
		if h.get_center().distance_to(c) < 1.3 * T:
			return true
	return false

# ---------------------------------------------------------------- placar
func start_score() -> void:
	state = S.SCORE
	timer = timers("score_seconds")
	var pts: Dictionary = Data.scoring["points"]
	var easy: Dictionary = Data.scoring["rules"]["too_easy"]
	var n := players.size()
	var all_finished := finish_order.size() == n
	round_points = []
	for i in n:
		var b := {"finish": 0, "first": 0, "kills": 0, "hammer": 0}
		if i in finish_order:
			if not (all_finished and easy["enabled"] and easy["zero_finish_points"]):
				b["finish"] = int(pts["finish"])
			if finish_order[0] == i and (not all_finished or not easy["enabled"] or easy["keeps_first_bonus"]):
				b["first"] = int(pts["first_bonus"])
		b["kills"] = mini(round_kills.get(i, 0) * int(pts["kill_by_owned_piece"]), int(pts["kill_cap_per_round"]))
		b["hammer"] = round_hammer.get(i, 0) * int(pts["hammer_smash"])
		b["total"] = b["finish"] + b["first"] + b["kills"] + b["hammer"]
		b["all_finished"] = all_finished
		players[i]["score"] += b["total"]
		round_points.append(b)
	# embargo: ninguém chega por N rodadas → demole a peça que mais eliminou
	var emb: Dictionary = Data.scoring["rules"]["embargo"]
	no_finish_streak = no_finish_streak + 1 if finish_order.is_empty() else 0
	if emb["enabled"] and no_finish_streak >= int(emb["embargo_after_rounds"]) and not pieces.is_empty():
		var best: Node2D = pieces[0]
		for pc in pieces:
			if pc.kills > best.kills or (pc.kills == best.kills and pc.placed_round < best.placed_round):
				best = pc
		embargo_msg = "Embargo! A peça que mais eliminou foi demolida."
		remove_piece(best)
		no_finish_streak = 0

func _after_score() -> void:
	var target := int(Data.scoring["target_points"])
	var best := -1
	for i in players.size():
		if players[i]["score"] >= target and (best < 0 or players[i]["score"] > players[best]["score"]):
			best = i
	if best >= 0:
		winner = best
		state = S.WIN
		_clear_robots()
	else:
		start_pick()

# ---------------------------------------------------------------- efeitos
func float_text(pos: Vector2, text: String, col: Color) -> void:
	floaters.append({"pos": pos, "text": text, "color": col, "t": 0.0})

func dust(pos: Vector2, size := 1.0) -> void:
	for k in (3 if size >= 1.0 else 1):
		puffs.append({"pos": pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-8, 0)) * size, "t": 0.0, "r": rng.randf_range(7, 12) * size})

## Estrelinhas de impacto (marretada, eliminação).
func spark(pos: Vector2, n := 5) -> void:
	for k in n:
		var a := rng.randf_range(0, TAU)
		sparks.append({"pos": pos, "vel": Vector2.from_angle(a) * rng.randf_range(120, 320), "t": 0.0, "rot": rng.randf_range(0, TAU)})

## Tremor leve de câmera (desligável em SHAKE_ON).
func shake(amount: float) -> void:
	if SHAKE_ON:
		shake_amt = maxf(shake_amt, amount)

## Robô eliminado desmonta: partes voando + poeira + estrelas.
func break_robot(r: CharacterBody2D) -> void:
	var d: Node2D = Debris.new()
	d.setup(RobotVis.parts(r.vis.look()), r.position, r.facing, Vector2(r.velocity.x * 0.3, 0))
	world.add_child(d)
	dust(r.position + Vector2(0, -30))
	spark(r.position + Vector2(0, -40), 7)
	shake(8.0)

func _draw_overlay() -> void:
	var puff := Data.tex("cenario/poeira")
	for p in puffs:
		var k: float = p["t"] / 0.45
		var sz: float = p["r"] * 3.0 * (0.8 + k * 0.7)
		overlay.draw_texture_rect(puff, Rect2(p["pos"] + Vector2(-sz / 2, -sz * 0.75 - k * 14), Vector2(sz, sz)), false, Color(1, 1, 1, 1.0 - k * k))
	var star := Data.tex("cenario/brilho")
	for sp in sparks:
		var k: float = sp["t"] / 0.4
		var sz := 22.0 * (1.0 - k * 0.6)
		overlay.draw_set_transform(sp["pos"], sp["rot"] + k * 3.0)
		overlay.draw_texture_rect(star, Rect2(-sz / 2, -sz / 2, sz, sz), false, Color(1, 1, 1, 1.0 - k))
	overlay.draw_set_transform(Vector2.ZERO)
	if state == S.BUILD:
		for i in players.size():
			var p: Dictionary = players[i]
			if p["placed"]:
				continue
			var g: Node2D = p["ghost"]
			var r: Rect2 = g.world_rect().grow(4)
			var col := player_color(i)
			overlay.draw_rect(r, Data.INK, false, 8)
			overlay.draw_rect(r, col, false, 4)
			if not can_place(g):
				overlay.draw_line(r.position, r.end, Color(1, 1, 1, 0.9), 6)
				overlay.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Color(1, 1, 1, 0.9), 6)
	if debug:
		for r in robots:
			overlay.draw_rect(r.rect(), Color(0, 1, 0, 0.8), false, 2)
		for pc in pieces:
			overlay.draw_rect(pc.world_rect(), Color(1, 1, 0, 0.8), false, 2)
			if pc.has_method("hazard_rect"):
				overlay.draw_rect(pc.hazard_rect(), Color(1, 0, 0, 0.9), false, 2)
		for h in level.hazard_rects:
			overlay.draw_rect(h, Color(1, 0, 0, 0.9), false, 2)
		overlay.draw_rect(level.goal_rect, Color(0, 1, 1, 0.9), false, 2)

# ---------------------------------------------------------------- debug
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F1: debug = not debug
			KEY_F2: skip_phase()
			KEY_F3: debug_piece = (debug_piece + 1) % implemented_ids().size()
			KEY_F4: debug_owner = (debug_owner + 1) % maxi(players.size(), 1)
			KEY_F5:
				if state == S.JOIN and players.size() < 4:
					PlayerInput.virtual["parado%d" % players.size()] = {}
					add_player("parado%d" % players.size())
			KEY_F6: Engine.time_scale = 0.3 if Engine.time_scale == 1.0 else 1.0
	elif e is InputEventMouseButton and e.pressed and state != S.JOIN:
		var c := Vector2i((world.get_local_mouse_position() / T).floor())
		if e.button_index == MOUSE_BUTTON_LEFT:
			var pc := make_piece(implemented_ids()[debug_piece], debug_owner, c)
			var ok := true
			for cc in pc.cells():
				if level.ch_at(cc) == "#":
					ok = false
			if ok:
				place_piece(pc)
			else:
				pc.free()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			for pc in pieces:
				if c in pc.cells():
					remove_piece(pc)
					break

func skip_phase() -> void:
	match state:
		S.JOIN:
			while players.size() < 2:
				PlayerInput.virtual["parado%d" % players.size()] = {}
				add_player("parado%d" % players.size())
			start_match()
		S.PICK, S.BUILD, S.SCORE: timer = 0.0
		S.RUN:
			countdown = 0.0
			timer = 0.0
			for r in robots:
				r.active = true
		S.WIN: start_match()
