extends Node
## Teste automático (--autotest) e capturas de tela (--shot=<pasta>), com controles virtuais.
## Uso: godot --headless --path game --fixed-fps 60 -- --autotest

var main: Node
var fails := 0
var S

func _ready() -> void:
	S = main.S
	_run.call_deferred()

func _run() -> void:
	var shot := ""
	var anim := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot = a.substr(7)
		if a.begins_with("--anim="):
			anim = a.substr(7)
	if anim != "":
		await anim_frames(anim)
		get_tree().quit(0)
	elif shot != "":
		await shots(shot)
		get_tree().quit(0)
	else:
		await autotest()
		print("RESULTADO: %s (%d falhas)" % ["OK" if fails == 0 else "FALHOU", fails])
		get_tree().quit(1 if fails > 0 else 0)

# ---------------------------------------------------------------- utilidades
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func vset(dev: String, a: String, v: bool) -> void:
	PlayerInput.virtual[dev][a] = v

func tap(dev: String, a: String) -> void:
	vset(dev, a, true)
	await frames(2)
	vset(dev, a, false)
	await frames(2)

func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		fails += 1

func clear_inputs() -> void:
	for d in PlayerInput.virtual:
		PlayerInput.virtual[d] = {}

func reset_run() -> void:
	clear_inputs()
	for pc in main.pieces.duplicate():
		main.remove_piece(pc)
	main.start_run()
	main.countdown = 0.0
	main.timer = 999.0
	for r in main.robots:
		r.active = true
	await frames(2)

func put(r, pos: Vector2) -> void:
	r.position = pos
	r.velocity = Vector2.ZERO
	r.own_vx = 0.0

func place(id: String, owner: int, c: Vector2i, rot := 0) -> Node2D:
	var pc: Node2D = main.make_piece(id, owner, c, rot)
	main.place_piece(pc)
	return pc

func col_x(c: int) -> float:
	return c * 64 + 32.0

# robô de teste: segue para a direita e pula buracos e paredes (só para testes)
func steer(devs: Array, frames_max: int, trace := false) -> void:
	var hold := {}
	for i in frames_max:
		for k in devs.size():
			var r = main.robots[k]
			var d: String = devs[k]
			if not r.alive or r.finished:
				PlayerInput.virtual[d] = {}
				continue
			vset(d, "right", true)
			var row := int((r.position.y + 2) / 64.0)
			var ahead := int((r.position.x + 40) / 64.0)
			var gap: bool = not main.level.is_solid(Vector2i(ahead, row))
			var wall: bool = main.level.is_solid(Vector2i(ahead, row - 1))
			if r.is_on_floor() and (gap or wall) and hold.get(d, 0) <= 0:
				hold[d] = 14
			vset(d, "jump", hold.get(d, 0) > 0)
			hold[d] = hold.get(d, 0) - 1
		await frames(1)
		if trace and i % 10 == 0:
			print("    t=%d " % i, main.robots.map(func(r): return "(%.0f,%.0f %s%s)" % [r.position.x, r.position.y, "F" if r.is_on_floor() else "-", "" if r.alive else " MORTO"]))
		if main.state != S.RUN or main.end_delay >= 0.0:
			break

# ---------------------------------------------------------------- teste
func autotest() -> void:
	print("== Entrada")
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	check(main.players.size() == 2, "2 jogadores entraram")
	await tap("v0", "right")
	check(main.players[0]["color"] == 2, "P1 troca de cor pulando a cor ocupada (azul→rosa)")
	await tap("v0", "left")
	await tap("v0", "start")
	check(main.state == S.PICK, "Start com 2 jogadores vai para ESCOLHA")

	print("== Escolha")
	check(main.conveyor.size() == 4, "esteira com jogadores + 2 peças")
	for i in 120:
		var d := "v0" if i % 2 == 0 else "v1"
		vset(d, "jump", i % 4 < 2)
		await frames(1)
		if main.state != S.PICK:
			break
	clear_inputs()
	check(main.state == S.BUILD, "todos escolheram → CONSTRUÇÃO")
	check(main.players.all(func(p): return p["piece"] != ""), "cada jogador tem uma peça")

	print("== Construção")
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	check(main.pieces.size() == 2, "2 peças colocadas")
	check(main.state == S.RUN, "todos colocaram → CORRIDA")
	check(main.pieces[0].owner_id == 0 and main.pieces[1].owner_id == 1, "peças têm dono")
	var bad: Node2D = main.make_piece("P02", 0, Vector2i(2, 11))
	check(not main.can_place(bad), "proibido construir no spawn (x)")
	bad.free()

	print("== Pulo")
	await reset_run()
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	put(r0, Vector2(col_x(21), 768))
	put(r1, Vector2(col_x(22), 768))
	await frames(5)
	var miny := 9999.0
	vset("v0", "jump", true)
	for i in 50:
		await frames(1)
		miny = minf(miny, r0.position.y)
	vset("v0", "jump", false)
	var full := (768 - miny) / 64.0
	check(full > 3.0 and full < 3.8, "pulo segurado = %.2f tiles (esperado ~3,5)" % full)
	await frames(40)
	miny = 9999.0
	vset("v0", "jump", true)
	await frames(1)
	vset("v0", "jump", false)
	for i in 40:
		await frames(1)
		miny = minf(miny, r0.position.y)
	var short := (768 - miny) / 64.0
	check(short < full * 0.6, "toque rápido = %.2f tiles (pulo variável)" % short)

	print("== Corrida")
	await reset_run()
	r0 = main.robots[0]
	put(r0, Vector2(col_x(20), 768))
	vset("v0", "right", true)
	await frames(20)
	check(absf(r0.velocity.x - float(Data.ctrl["max_run"])) < 1.0, "velocidade máxima %.0f px/s" % r0.velocity.x)
	vset("v0", "right", false)

	print("== P01 Viga")
	await reset_run()
	r0 = main.robots[0]
	r1 = main.robots[1]
	place("P01", 0, Vector2i(21, 9))
	put(r0, Vector2(col_x(22), 768))
	put(r1, Vector2(col_x(22), 768))
	await frames(3)
	vset("v0", "jump", true)
	vset("v1", "jump", true)
	await frames(30)
	clear_inputs()
	await frames(40)
	check(absf(r0.position.y - 576) < 2 and r0.is_on_floor(), "dono atravessou por baixo e pisou em cima (y=%.0f)" % r0.position.y)
	check(absf(r1.position.y - 768) < 2, "rival bateu a cabeça (y=%.0f)" % r1.position.y)

	print("== P02 Mola")
	await reset_run()
	r0 = main.robots[0]
	r1 = main.robots[1]
	place("P02", 0, Vector2i(22, 11))
	put(r0, Vector2(col_x(22), 690))
	put(r1, Vector2(col_x(22), 690))
	var m0 := 9999.0
	var m1 := 9999.0
	for i in 70:
		await frames(1)
		m0 = minf(m0, r0.position.y)
		m1 = minf(m1, r1.position.y)
	check(absf((704 - m0) / 64.0 - 5.0) < 0.35, "dono lançado %.2f tiles (esperado 5)" % ((704 - m0) / 64.0))
	check(absf((704 - m1) / 64.0 - 3.0) < 0.35, "rival lançado %.2f tiles (esperado 3)" % ((704 - m1) / 64.0))

	print("== P03 Serra + pontos de eliminação")
	await reset_run()
	r0 = main.robots[0]
	r1 = main.robots[1]
	place("P03", 0, Vector2i(23, 11))
	put(r0, Vector2(col_x(21), 768))
	put(r1, Vector2(col_x(21), 768))
	vset("v0", "right", true)
	vset("v1", "right", true)
	await frames(18)
	clear_inputs()
	check(r0.alive, "dono atravessa a própria serra")
	check(not r1.alive, "rival eliminado pela serra")
	main.start_score()
	check(main.round_points[0]["kills"] == int(Data.scoring["points"]["kill_by_owned_piece"]), "dono ganha +3 pela eliminação")
	main.players[0]["score"] = 0
	main.players[1]["score"] = 0
	main.state = S.RUN

	print("== P04 Esteira")
	await reset_run()
	r0 = main.robots[0]
	r1 = main.robots[1]
	place("P04", 0, Vector2i(21, 11))
	put(r0, Vector2(col_x(21) + 10, 704))
	put(r1, Vector2(col_x(21) + 10, 704))
	var x0: float = r0.position.x
	await frames(25)
	check(absf(r0.position.x - x0) < 3, "dono parado não se move (dx=%.0f)" % (r0.position.x - x0))
	check(r1.position.x - x0 > 60, "rival empurrado na direção marcada (dx=%.0f)" % (r1.position.x - x0))
	put(r0, Vector2(1500, 704))
	vset("v0", "left", true)
	await frames(8)
	check(r0.velocity.x < -float(Data.ctrl["max_run"]) - 100, "dono andando contra a seta: esteira a favor (vx=%.0f)" % r0.velocity.x)
	clear_inputs()

	print("== Marreta")
	await reset_run()
	r0 = main.robots[0]
	r1 = main.robots[1]
	place("P01", 0, Vector2i(22, 11))
	put(r0, Vector2(1370, 768))
	put(r1, Vector2(1370, 768))
	await frames(3)
	await tap("v0", "hammer")
	check(main.pieces.size() == 1, "dono não marreta a própria peça")
	await tap("v1", "hammer")
	check(main.pieces.size() == 0, "rival destrói a peça com a marreta")
	check(main.round_hammer.get(1, 0) == 1 and r1.hammer_left == 0, "marreta conta +1 e só 1 uso por rodada")

	print("== Rodada completa")
	await reset_run()
	await steer(["v0", "v1"], 900)
	check(main.finish_order.size() == 2, "rota sem peças: os 2 chegaram ao elevador (%s)" % str(main.finish_order))
	await frames(70)
	check(main.state == S.SCORE, "corrida → PLACAR")
	var first: int = main.finish_order[0] if main.finish_order.size() > 0 else 0
	check(main.players[first]["score"] == 5 and main.players[1 - first]["score"] == 0, "todos chegaram: só o +5 do primeiro (%s)" % str(main.players.map(func(p): return p["score"])))
	main.timer = 0.0
	await frames(2)
	check(main.state == S.PICK and main.round_no == 2, "placar → próxima rodada")

	print("== Vitória")
	main.players[0]["score"] = 50
	main.players[1]["score"] = 0
	await reset_run()
	await steer(["v0"], 600)
	main.timer = 0.0
	await frames(80)
	check(main.state == S.SCORE and main.players[0]["score"] >= 60, "P1 chegou sozinho: %d pontos" % main.players[0]["score"])
	main.timer = 0.0
	await frames(2)
	check(main.state == S.WIN and main.winner == 0, "60+ pontos → VITÓRIA")
	await tap("v0", "jump")
	check(main.state == S.PICK and main.round_no == 1, "jogar de novo zera a partida")

# ---------------------------------------------------------------- capturas
func snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
	print("captura: ", name)

func shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {"v0": {}, "v1": {}, "v2": {}, "v3": {}}
	await frames(2)
	for d in ["v0", "v1", "v2", "v3"]:
		await tap(d, "jump")
	await frames(10)
	await snap(dir, "1_entrada")
	await tap("v0", "start")
	await frames(30)
	await tap("v2", "right")
	await snap(dir, "2_escolha")
	main.skip_phase()
	await frames(3)
	# peças de exemplo já na obra
	place("P01", 2, Vector2i(9, 9))
	place("P03", 1, Vector2i(19, 11))
	place("P02", 3, Vector2i(8, 11))
	place("P04", 0, Vector2i(21, 11))
	for k in 4:
		main.players[k]["cursor"] = [Vector2i(14, 6), Vector2i(19, 4), Vector2i(6, 6), Vector2i(23, 8)][k]
	await frames(3)
	await snap(dir, "3_construcao")
	main.skip_phase()
	await frames(2)
	for pc in main.pieces.duplicate():
		if pc.placed_round == main.round_no and pc.cell.y < 9:
			main.remove_piece(pc)
	main.countdown = 0.01
	await steer(["v0", "v1", "v2", "v3"], 50)
	await snap(dir, "4_corrida")
	# prancha: 4 robôs espalhados pela obra (posições escolhidas, sem física)
	var spots := [Vector2(560, 768), Vector2(930, 520), Vector2(680, 576), Vector2(1335, 768)]
	for k in 4:
		var r = main.robots[k]
		r.active = false
		r.set_physics_process(false)
		r.visible = true
		r.scale = Vector2.ONE
		r.position = spots[k]
		r.facing = 1 if k != 3 else -1
	main.robots[1].vis.expression = "esforco"
	main.robots[0].vis.expression = "vitoria"
	main.robots[3].vis.expression = "susto"
	main.robots[1].vis.sq = Vector2(0.85, 1.18)
	for k in 4:
		main.robots[k].vis.scale = Vector2(main.robots[k].vis.sq.x * main.robots[k].facing, main.robots[k].vis.sq.y)
		main.robots[k].vis.queue_redraw()
	main.dust(Vector2(905, 768))
	await frames(90)
	main.dust(Vector2(905, 704))
	await frames(4)
	await snap(dir, "prancha_canteiro")
	await steer(["v0", "v1", "v2", "v3"], 600)
	await frames(80)
	await snap(dir, "5_placar")
	# prancha dos robôs desenhada pelo próprio motor (mesma montagem do jogo)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var sheet := Node2D.new()
	sheet.draw.connect(func():
		sheet.draw_texture_rect(Data.tex("cenario/fundo_canteiro"), Rect2(0, 0, 1920, 1080), false)
		var Vis = load("res://player/robot_visual.gd")
		sheet.draw_rect(Rect2(0, 0, 1920, 1080), Color("#9fe3ee"))
		var ex := ["normal", "esforco", "susto", "vitoria", "eliminado"]
		for k in 4:  # os 4 modelos em azul, como em versoes.png
			Vis.draw_robot(sheet, {"color": 0, "model": k, "acc": 0}, Vis.idle_pose(0.5), Transform2D(0.0, Vector2(4.2, 4.2), 0.0, Vector2(230 + k * 480, 520)))
		for k in 4:  # cores, chapéus e expressões
			var po: Dictionary = Vis.idle_pose(0.5)
			po["expr"] = ex[k + 1]
			Vis.draw_robot(sheet, {"color": k, "model": (k + 1) % 4, "acc": (k + 1) % 4}, po, Transform2D(0.0, Vector2(2.2, 2.2), 0.0, Vector2(200 + k * 250, 1010)))
		for k in 4:
			Vis.draw_robot(sheet, {"color": k, "model": k, "acc": 0}, Vis.victory_pose(0.3 + k * 0.2), Transform2D(0.0, Vector2(1, 1), 0.0, Vector2(1260 + k * 150, 1000)))
	)
	layer.add_child(sheet)
	await frames(3)
	await snap(dir, "prancha_robos")

# ---------------------------------------------------------------- animação (quadros para GIF)
var _frame_no := 0

func grab(dir: String, prefix: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%04d.png" % [prefix, _frame_no]))
	_frame_no += 1

func anim_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {"v0": {}, "v1": {}, "v2": {}, "v3": {}}
	await frames(2)
	for d in ["v0", "v1", "v2", "v3"]:
		await tap(d, "jump")
	await tap("v0", "start")
	main.skip_phase()
	await frames(2)
	main.skip_phase()
	await frames(2)
	main.countdown = 0.0
	main.timer = 999.0
	for r in main.robots:
		r.active = true
	# --- cena 1: corrida, giro, pulo, parede, marretada e queda nos espinhos
	main.cam_lock = [1.7, Vector2(565, 723)]
	_frame_no = 0
	for f in 300:
		var a := {"v0": {}, "v1": {}, "v2": {}, "v3": {}}
		# Lata (P1): anda, freia e vira, pula, marreta e cai no poço
		if f >= 40 and f < 80: a["v0"]["right"] = true
		if f >= 80 and f < 100: a["v0"]["left"] = true
		if f >= 115 and f < 130: a["v0"]["jump"] = true
		if f >= 150 and f < 153: a["v0"]["hammer"] = true
		if f >= 190: a["v0"]["right"] = true
		# TV (P2): pulos
		if f % 70 >= 10 and f % 70 < 24: a["v1"]["jump"] = true
		# Baixinho (P3): pula na parede da esquerda e desliza
		if f < 140: a["v2"]["left"] = true
		if (f >= 20 and f < 34) or (f >= 100 and f < 112): a["v2"]["jump"] = true
		if f >= 160 and f < 200: a["v2"]["right"] = true
		# Pescoção (P4): marretadas
		if f % 60 >= 30 and f % 60 < 33: a["v3"]["hammer"] = true
		PlayerInput.virtual = a
		await frames(1)
		if f % 2 == 0:
			await grab(dir, "a")
	# --- cena 2: marretada numa peça rival, chegada ao elevador com a porta abrindo
	_frame_no = 0
	await reset_run()
	main.cam_lock = [2.0, Vector2(1440, 740)]
	place("P04", 0, Vector2i(21, 11))
	var rs: Array = main.robots
	put(rs[0], Vector2(-400, 768))
	put(rs[2], Vector2(-400, 768))
	put(rs[3], Vector2(1306, 768))
	put(rs[1], Vector2(1240, 704))
	rs[1].position = Vector2(1250, 768)
	for f in 140:
		var a := {"v0": {}, "v1": {}, "v2": {}, "v3": {}}
		if f >= 20 and f < 23: a["v3"]["hammer"] = true
		if f >= 50: a["v1"]["right"] = true
		if f >= 56 and f < 70: a["v1"]["jump"] = true
		PlayerInput.virtual = a
		await frames(1)
		if f % 2 == 0:
			await grab(dir, "b")
	# --- cena 3: tela de vitória (dancinha)
	_frame_no = 0
	main.cam_lock = []
	main.winner = 2
	main.state = S.WIN
	main._clear_robots()
	for f in 60:
		await frames(1)
		if f % 2 == 0:
			await grab(dir, "c")
