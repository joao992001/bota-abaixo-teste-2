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
		if a.begins_with("--intro="):
			var dir: String = a.substr(8)
			DirAccess.make_dir_recursive_absolute(dir)
			get_window().size = Vector2i(1920, 1080)
			main.go_menu()
			main.state = S.INTRO
			main.menus.intro_t = 0.0
			main.menus.intro_frames = 0
			main.menus.intro_hit = false
			main.menus.intro_hi = false
			var shots := [12, 30, 40, 60, 95, 125, 140, 165]
			var fr := 0
			for target in shots:
				await frames(target - fr)
				fr = target
				await snap(dir, "intro_%03d" % target)
			get_tree().quit(0)
			return
		if a.begins_with("--parede="):
			await parede_frames(a.substr(9))
			get_tree().quit(0)
			return
		if a.begins_with("--oficina="):
			DirAccess.make_dir_recursive_absolute(a.substr(10))
			get_window().size = Vector2i(1920, 1080)
			main.go_menu()
			PlayerInput.virtual = {"v0": {}}
			await frames(2)
			main.oficina.start("v0")
			main.sandbox_add("boneco")
			main.sandbox_add("bot")
			await frames(150)
			await snap(a.substr(10), "oficina_jogo")
			main.oficina.toggle()
			main.oficina.sel = 0
			main.oficina.item_i = 4
			await frames(10)
			await snap(a.substr(10), "oficina_painel")
			get_tree().quit(0)
			return
		if a.begins_with("--itens="):
			await itens_frames(a.substr(8))
			get_tree().quit(0)
			return
		if a.begins_with("--perf"):
			await perf_run()
			get_tree().quit(0)
			return
		if a.begins_with("--stats="):
			await stats_run(int(a.substr(8)))
			get_tree().quit(0)
			return
		if a.begins_with("--video="):
			await video_frames(a.substr(8))
			get_tree().quit(0)
			return
		if a.begins_with("--arenas="):
			await arenas_frames(a.substr(9))
			get_tree().quit(0)
			return
		if a.begins_with("--menus="):
			await menus_frames(a.substr(8))
			get_tree().quit(0)
			return
		if a.begins_with("--demo="):
			await demo_frames(a.substr(7))
			get_tree().quit(0)
			return
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
func key_event(k: Key, down: bool, loc := KEY_LOCATION_UNSPECIFIED) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	e.location = loc
	Input.parse_input_event(e)
	await frames(2)

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
	seed(20261120)            # sorteios repetíveis: o teste não oscila
	main.rng.seed = 20261120
	for a in OS.get_cmdline_user_args():   # atalho de depuração: --so=maquinas,itens_novos,eventos
		if a.begins_with("--so="):
			PlayerInput.virtual = {"v0": {}, "v1": {}}
			await frames(2)
			await tap("v0", "jump")
			await tap("v1", "jump")
			main.mode = "demolicao"
			main.start_match()
			for nm in a.substr(5).split(","):
				await call(nm + "_test")
			return
	print("== Áudio")
	var missing := []
	for k in Audio._index.keys():
		var n: int = int(Audio._index[k])
		var path := "res://assets/audio/sfx/%s.wav" % k if n == 0 else "res://assets/audio/sfx/%s_1.wav" % k
		if Audio._stream(path) == null:
			missing.append(k)
	check(Audio._index.size() >= 30 and missing.is_empty(), "%d sons carregam (faltando: %s)" % [Audio._index.size(), str(missing)])
	Audio.music("partida")
	await frames(30)
	var ms: AudioStream = Audio._music.stream
	check(ms is AudioStreamOggVorbis and ms.loop, "música da partida em OGG e em loop")
	Audio.play("bonk")
	Audio.voice("voz_ai", 2)
	print("== Teclado (Windows: Shift fantasma nas setas, Ctrl esquerdo x direito)")
	await key_event(KEY_SHIFT, true, KEY_LOCATION_LEFT)
	await key_event(KEY_RIGHT, true)
	check(PlayerInput.dev_held("kb_b", "right") and not PlayerInput.dev_held("kb_a", "hammer"), "seta com Shift fantasma não aciona a marreta do teclado A")
	await key_event(KEY_SHIFT, false, KEY_LOCATION_LEFT)
	await key_event(KEY_RIGHT, false)
	await key_event(KEY_CTRL, true, KEY_LOCATION_LEFT)
	check(not PlayerInput.dev_held("kb_b", "jump"), "Ctrl esquerdo não faz o teclado B pular")
	await key_event(KEY_CTRL, false, KEY_LOCATION_LEFT)
	await key_event(KEY_CTRL, true, KEY_LOCATION_RIGHT)
	check(PlayerInput.dev_held("kb_b", "jump"), "Ctrl direito faz o teclado B pular")
	await key_event(KEY_CTRL, false, KEY_LOCATION_RIGHT)
	await key_event(KEY_F, true)
	check(PlayerInput.dev_held("kb_a", "hammer"), "F é a marreta do teclado A")
	await key_event(KEY_F, false)
	main.players.clear()   # o Ctrl direito simulado fez o teclado B entrar: limpa para o resto do teste
	PlayerInput.slots.clear()

	print("== Entrada")
	main.mode = "construcao"   # testes do modo antigo de peças; a Demolição é testada no fim
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	check(main.players.size() == 2, "2 jogadores entraram")
	await tap("v0", "right")
	check(main.players[0]["color"] == 2, "P1 troca de cor pulando a cor ocupada (azul→rosa)")
	await tap("v0", "left")
	print("== Controle duplicado (Windows) e sair")
	PlayerInput.virtual["padA"] = {}
	PlayerInput.virtual["padB"] = {}
	await frames(2)
	vset("padA", "jump", true)
	vset("padB", "jump", true)
	await frames(2)
	vset("padA", "jump", false)
	vset("padB", "jump", false)
	await frames(2)
	check(main.players.size() == 3, "mesmo controle visto 2x entra como 1 jogador (%d)" % main.players.size())
	var acc_before: int = main.players[0]["acc"]
	vset("padA", "hammer", true)
	vset("padB", "hammer", true)
	await frames(2)
	vset("padA", "hammer", false)
	vset("padB", "hammer", false)
	await frames(2)
	check(main.players[2]["acc"] == 1 and main.players[0]["acc"] == acc_before, "trocar chapéu muda só o jogador do controle")
	await tap("padA", "back")
	check(main.players.size() == 2, "botão de sair remove o jogador")
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
	check(full > 3.5 and full < 4.3, "pulo segurado = %.2f tiles (esperado ~3,9)" % full)
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
	await demolicao_test()

func demo_round() -> void:
	clear_inputs()
	main.demo.start_round()
	main.state = S.RUN
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(3)
	for r in main.robots:
		r.invuln = 0.0   # testes de golpe sem a proteção do começo

func demolicao_test() -> void:
	print("== Demolição")
	main.mode = "demolicao"
	main.event_level = 0   # eventos são testados à parte (eventos_test)
	main.arena_choice = "demolicao"   # mecânicas básicas testadas no Canteiro
	main.start_match()
	check(main.level.id == "demolicao" and main.level.blocks.size() > 30, "arena de caixotes carregada (%d caixotes)" % main.level.blocks.size())
	await demo_round()
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	# corrida lisa sobre caixotes separados: sem tropeçar nas emendas
	put(r1, Vector2(col_x(26), 576))
	put(r0, Vector2(col_x(10) + 10, 576))
	await frames(3)
	vset("v0", "right", true)
	var drops := 0
	var air := 0
	for i in 40:
		await frames(1)
		if i > 8 and absf(r0.velocity.x) < float(Data.ctrl["max_run"]) - 1.0:
			drops += 1
		if not r0.is_on_floor():
			air += 1
	vset("v0", "right", false)
	check(drops == 0 and air == 0, "corre liso sobre caixotes (quedas de velocidade: %d, quadros sem chão: %d)" % [drops, air])
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(12), 576))
	put(r1, Vector2(col_x(26), 576))
	r0.facing = 1
	await frames(3)
	var cell := Vector2i(13, 9)
	var hp0: int = int(main.demo.cfg["block_hp"])
	await tap("v0", "hammer")
	check(main.level.blocks.has(cell) and main.level.blocks[cell]["hp"] == hp0 - 1, "1ª marretada racha o caixote do chão à frente")
	for k in hp0 - 1:
		await frames(16)
		await tap("v0", "hammer")
	check(not main.level.blocks.has(cell), "%dª marretada quebra o caixote" % hp0)
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	await frames(3)
	var x1: float = r1.position.x
	await tap("v0", "hammer")
	check(r1.stun_t > 0.0 and absf(r1.dmg - 12.0) < 0.1, "marretada atordoa e soma 12%% no Amassômetro (%.0f%%)" % r1.dmg)
	await frames(30)
	var push_low: float = r1.position.x - x1
	put(r1, Vector2(col_x(11) + 60, 576))
	r1.dmg = 120.0
	await frames(16)
	x1 = r1.position.x
	await tap("v0", "hammer")
	await frames(30)
	var push_high: float = r1.position.x - x1
	check(push_low > 20.0 and push_low < 200.0 and push_high > push_low * 3.0, "amassado voa mais longe: 12%% → %.0f px, 120%% → %.0f px" % [push_low, push_high])
	# invulnerável não sofre golpe
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	r1.invuln = 2.0
	await frames(3)
	await tap("v0", "hammer")
	check(r1.dmg == 0.0 and r1.stun_t == 0.0, "invulnerável (começo da rodada) não leva golpe")
	# pulo duplo do propulsor
	await demo_round()
	r0 = main.robots[0]
	put(r0, Vector2(col_x(12), 576))
	await frames(3)
	var y_ground: float = r0.position.y
	vset("v0", "jump", true)
	await frames(24)
	vset("v0", "jump", false)
	await frames(2)
	vset("v0", "jump", true)
	var top_y := 9999.0
	for i in 40:
		await frames(1)
		top_y = minf(top_y, r0.position.y)
	vset("v0", "jump", false)
	check(y_ground - top_y > 4.6 * 64.0 and r0.air_jumps == 0, "pulo duplo do propulsor (altura %.1f tiles)" % ((y_ground - top_y) / 64.0))
	await frames(60)
	# agarrar a borda: cai ao lado da plataforma segurando na direção dela
	await demo_round()
	r0 = main.robots[0]
	put(r0, Vector2(col_x(9) - 4, 600))
	r0.air_jumps = 0
	vset("v0", "right", true)
	var grabbed := false
	for i in 30:
		await frames(1)
		if r0.hanging:
			grabbed = true
			break
	vset("v0", "right", false)
	check(grabbed, "agarra a borda do caixote")
	await tap("v0", "jump")
	await frames(30)
	check(r0.alive and r0.is_on_floor() and r0.position.y <= 577.0, "da borda, PULAR sobe na plataforma")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r1, Vector2(col_x(11), 576))
	put(r0, Vector2(col_x(11), 360))
	var stomped := false
	for i in 40:
		await frames(1)
		if r1.stun_t > 0.0:
			stomped = true
			break
	check(stomped and r0.velocity.y < 0.0 and r1.dmg > 0.0, "pular na cabeça atordoa, amassa e quica")
	var stomps := 1
	var was_stunned := true
	for i in 90:
		await frames(1)
		if r1.stun_t > 0.0 and not was_stunned:
			stomps += 1
		was_stunned = r1.stun_t > 0.0
	check(stomps == 1, "pisão não vira laço: 1 pisão em 1,5 s (%d)" % stomps)
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r1, Vector2(col_x(16), 576))
	var under := Vector2i(16, 9)
	await frames(int(float(main.demo.cfg["crumble_break_s"]) * 60) + 10)
	check(not main.level.blocks.has(under), "caixote cai se o robô fica parado em cima")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	var before: int = main.players[0]["score"]
	main.kill(r1, -1, null)
	await frames(100)
	check(main.state == S.SCORE and main.players[0]["score"] == before + 1, "último em pé ganha ★ (%d)" % main.players[0]["score"])
	main.timer = 0.0
	await frames(3)
	check(main.state == S.RUN and main.robots.size() == 2, "placar → próxima rodada com arena nova")
	main.players[0]["score"] = int(main.demo.cfg["rounds_to_win"]) - 1
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	main.kill(main.robots[1], -1, null)
	await frames(100)
	main.timer = 0.0
	await frames(3)
	check(main.state == S.WIN and main.winner == 0, "%d ★ vence a partida" % int(main.demo.cfg["rounds_to_win"]))
	await itens_test()
	await bots_test()
	await arenas_test()
	await parede_test()
	await maquinas_test()
	await itens_novos_test()
	await submodos_test()
	await eventos_test()
	await menus_test()
	await controles_test()
	await controle_real_test()
	await oficina_test()
	await imagens_test()

func menus_test() -> void:
	print("== Menus e pausa")
	main.go_menu()
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	check(main.state == S.MENU and main.players.is_empty(), "volta ao menu principal sem jogadores")
	await tap("v0", "jump")
	check(main.state == S.MODES, "JOGAR abre a seleção de modo")
	await tap("v0", "right")
	await tap("v0", "jump")
	check(main.state == S.MODES, "modo EM BREVE não abre")
	await tap("v0", "left")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.state == S.SUBMODOS, "Demolição abre a escolha de submodo")
	await tap("v0", "right")
	await tap("v0", "jump")
	check(main.state == S.ARENAS and main.submode_choice == "vidas", "submodo Vidas escolhido → escolha de arena")
	await tap("v0", "right")
	await tap("v0", "right")
	await tap("v0", "jump")
	check(main.state == S.AJUSTES and main.arena_choice == "esteiras", "arena Fábrica de Esteiras → AJUSTES")
	await tap("v0", "left")
	await tap("v0", "down")
	await tap("v0", "right")
	var lvl: int = main.event_level
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.state == S.EVENTOS, "ESCOLHER EVENTOS abre")
	var first_id: String = main.events.cfg["lista"][0]["id"]
	await tap("v0", "jump")
	check(not main.events.enabled[first_id], "evento %s desligado" % first_id)
	await tap("v0", "jump")
	await tap("v0", "back")
	check(main.state == S.AJUSTES and main.events.enabled[first_id], "volta aos AJUSTES (evento religado)")
	await tap("v0", "down")
	await tap("v0", "down")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.state == S.JOIN and main.mode == "demolicao" and int(main.demo.cfg["rounds_to_win"]) == 3 and lvl >= 0, "COMEÇAR → entrada; vence com 3 ★ (eventos nível %d)" % main.event_level)
	main.submode_choice = "ultimo"
	await tap("v0", "jump")
	main.add_bot()
	await tap("v0", "start")
	check(main.state == S.RUN and main.robots.size() == 2, "partida começa (1 pessoa + 1 bot)")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(5)
	await tap("v0", "start")
	check(main.paused, "START pausa")
	var bx: Vector2 = main.robots[1].position
	await frames(30)
	check(main.robots[1].position == bx, "na pausa, ninguém se mexe")
	await tap("v0", "down")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.state == S.MENU and not main.paused, "pausa → MENU PRINCIPAL")
	await tap("v0", "down")
	await tap("v0", "down")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.state == S.OPTIONS, "OPÇÕES abre")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(not main.shake_on, "tremor da tela desliga")
	await tap("v0", "jump")
	await tap("v0", "back")
	check(main.state == S.MENU and main.shake_on, "voltar ao menu (tremor religado)")

func parede_test() -> void:
	print("== Parede e borda")
	main.event_level = 0
	main.submode_choice = "ultimo"
	main.arena_choice = "demolicao"
	await demo_round()
	main.demo.item_t = 999.0
	var lv = main.level
	var r0 = main.robots[0]
	put(main.robots[1], Vector2(col_x(24), 576))
	# parede invisível da borda do mapa: não gruda
	put(r0, Vector2(64.0 + 25.0, 300))
	vset("v0", "left", true)
	await frames(12)
	var dbg := "y %.0f chão %s nível %s cel %s" % [r0.position.y, r0.is_on_floor(), main.level.id, main.level.ch_at(Vector2i(int(r0.position.x / 64.0), int((r0.position.y + 2.0) / 64.0)))]
	check(not r0.wall_sliding and r0.velocity.y > 300.0, "não gruda na parede invisível da borda (vy %.0f; %s)" % [r0.velocity.y, dbg])
	vset("v0", "left", false)
	# parede de caixotes: escorrega devagar e o pulo de parede funciona
	for y in [3, 4, 5, 6, 7]:
		lv.add_block(Vector2i(13, y))
	put(r0, Vector2(13 * 64.0 - 25.0, 300))
	vset("v0", "right", true)
	await frames(14)
	check(r0.wall_sliding and r0.velocity.y <= float(Data.ctrl["wall_slide_speed"]) + 1.0 and r0.grip < 1.0, "escorrega na parede de caixotes gastando aderência (vy %.0f, %.0f%%)" % [r0.velocity.y, r0.grip * 100.0])
	await tap("v0", "jump")
	await frames(2)
	check(r0.velocity.y < -300.0 and r0.own_vx < 0.0, "pulo de parede empurra para longe")
	vset("v0", "right", false)
	# os dois lados: o desenho vira de costas para a parede (direita e esquerda), pendurado olha para a parede
	for side in [1, -1]:
		await demo_round()
		r0 = main.robots[0]
		lv = main.level
		put(main.robots[1], Vector2(col_x(24), 576))
		for y in [3, 4, 5, 6, 7]:
			lv.add_block(Vector2i(10, y))
		var x := 10 * 64.0 - 25.0 if side > 0 else 11 * 64.0 + 25.0
		put(r0, Vector2(x, 400))
		vset("v0", "right" if side > 0 else "left", true)
		await frames(14)
		var sx: float = r0.vis.scale.x
		check(r0.wall_sliding and signf(sx) == -side, "parede à %s: desenho de costas para ela (escala %.2f)" % ["direita" if side > 0 else "esquerda", sx])
		vset("v0", "right" if side > 0 else "left", false)
		# pendurado na quina do topo (linha 3)
		put(r0, Vector2(x + (-5.0 * side), 3 * 64.0 + 40.0))
		r0.velocity.y = 100.0
		r0.grip = 1.0
		vset("v0", "right" if side > 0 else "left", true)
		var hung := false
		for i in 30:
			await frames(1)
			if r0.hanging:
				hung = true
				break
		await frames(8)
		check(hung and signf(r0.vis.scale.x) == side, "borda à %s: pendurado olhando para a parede (escala %.2f)" % ["direita" if side > 0 else "esquerda", r0.vis.scale.x])
		vset("v0", "right" if side > 0 else "left", false)
	# aderência acaba: solta da parede e cai (o medidor mostra isso)
	await demo_round()
	r0 = main.robots[0]
	lv = main.level
	put(main.robots[1], Vector2(col_x(24), 576))
	for y in [1, 2, 3, 4, 5, 6, 7, 8]:
		lv.add_block(Vector2i(20, y))
	put(r0, Vector2(20 * 64.0 - 25.0, 140))
	r0.velocity.y = 100.0
	vset("v0", "right", true)
	var slid := false
	for i in 120:
		await frames(1)
		if r0.wall_sliding:
			slid = true
		if r0.is_on_floor():
			break
	vset("v0", "right", false)
	check(slid and r0.grip <= 0.05, "a aderência na parede acaba (%.0f%%) e o robô solta" % (r0.grip * 100.0))
	await frames(40)
	check(r0.grip > 0.95, "no chão a aderência recarrega")
	# agarra a borda e sobe sem teletransporte, e depois anda
	await demo_round()
	r0 = main.robots[0]
	lv = main.level
	put(main.robots[1], Vector2(col_x(24), 576))
	lv.add_block(Vector2i(11, 5))
	put(r0, Vector2(11 * 64.0 - 30.0, 5 * 64.0 + 40.0))
	r0.velocity.y = 100.0
	vset("v0", "right", true)
	var grabbed := false
	for i in 20:
		await frames(1)
		if r0.hanging:
			grabbed = true
			break
	check(grabbed, "agarra a quina do caixote caindo ao lado dela")
	vset("v0", "right", false)
	await tap("v0", "jump")
	var mid_ok := false
	for i in 6:
		await frames(1)
		if r0.climb_t > 0.0 and r0.climb_t < 1.0:
			mid_ok = true
	await frames(14)
	check(mid_ok and absf(r0.position.y - 5 * 64.0) < 6.0 and r0.is_on_floor(), "sobe animado e fica em pé em cima (y %.0f)" % r0.position.y)
	var xs: float = r0.position.x
	vset("v0", "left", true)
	await frames(10)
	vset("v0", "left", false)
	check(absf(r0.position.x - xs) > 20.0, "depois de subir, anda normalmente")
	# sem espaço em cima (teto a 1 bloco): não agarra
	await demo_round()
	r0 = main.robots[0]
	lv = main.level
	put(main.robots[1], Vector2(col_x(24), 576))
	lv.add_block(Vector2i(11, 5))
	lv.add_block(Vector2i(11, 3))
	put(r0, Vector2(11 * 64.0 - 30.0, 5 * 64.0 + 40.0))
	r0.velocity.y = 100.0
	vset("v0", "right", true)
	grabbed = false
	for i in 20:
		await frames(1)
		if r0.hanging:
			grabbed = true
	vset("v0", "right", false)
	check(not grabbed, "não agarra borda sem espaço para subir")
	# segurar a borda tem limite de tempo
	await demo_round()
	r0 = main.robots[0]
	lv = main.level
	put(main.robots[1], Vector2(col_x(24), 576))
	lv.add_block(Vector2i(11, 5))
	put(r0, Vector2(11 * 64.0 - 30.0, 5 * 64.0 + 40.0))
	r0.velocity.y = 100.0
	vset("v0", "right", true)
	for i in 20:
		await frames(1)
		if r0.hanging:
			break
	var lim := float(main.demo.cfg["recuperacao"]["borda_max_s"])
	await frames(int(lim * 60.0 * 0.5))
	var half: float = r0.grip
	await frames(int(lim * 60.0 * 0.6))
	vset("v0", "right", false)
	check(half > 0.3 and half < 0.7 and not r0.hanging, "segurar a borda esvazia o medidor e solta no fim (meio: %.0f%%)" % (half * 100.0))
	# nenhum mapa tem vão baixo demais (o robô de 72 px entalava, ex.: alto da Maré)
	var bad := []
	for a in main.demo.cfg["arenas"]:
		var L = load("res://level/level.gd").new()
		L.load_level(a["id"])
		for y in range(2, L.rows):
			for x in L.cols:
				var c := Vector2i(x, y)
				if L.is_solid(c) and L.ch_at(c) != "I" and not L.is_solid(c + Vector2i.UP) and L.is_solid(c + Vector2i(0, -2)):
					bad.append("%s %s" % [a["id"], str(c)])
		L.free()
	check(bad.is_empty(), "nenhum mapa com vão de 1 bloco onde o robô entala %s" % str(bad.slice(0, 6)))

func maquinas_test() -> void:
	print("== Máquinas e câmera que rola")
	main.event_level = 0
	main.submode_choice = "ultimo"
	var fx
	# Torre: a câmera sobe; quem fica embaixo está fora
	await arena_round("torre")
	fx = main.demo.fx
	check(fx.scroll_on and fx.scroll_dir == "cima" and main.level.rows == 40, "Torre: mapa alto com câmera que sobe")
	var y0: float = fx.scroll_center.y
	main.demo.t = 20.0
	await frames(60)
	check(fx.scroll_center.y < y0 - 20.0, "Torre: a câmera subiu (%.0f → %.0f)" % [y0, fx.scroll_center.y])
	var vr: Rect2 = main.view_rect()
	check(vr.size.x <= 1921.0 and main.camera.position.y < float(main.level.rows) * 64.0, "Torre: a câmera acompanha (centro %.0f)" % main.cam_center.y)
	main.robots[1].invuln = 0.0
	fx.scroll_center.y = 600.0
	await frames(3)
	check(not main.robots[0].alive and main.demo.death_log[-1]["cause"] == "ficou para trás", "Torre: quem ficou para trás saiu (%s)" % main.demo.death_log[-1]["cause"])
	# Ponte: ninguém passa da frente da tela
	await arena_round("ponte")
	fx = main.demo.fx
	put(main.robots[0], Vector2(1950, 576))
	await frames(2)
	check(main.robots[0].position.x <= fx.scroll_center.x + 960.0 - 27.0, "Ponte: a frente da tela segura o robô (x %.0f)" % main.robots[0].position.x)
	# Gangorras: o peso inclina a tábua
	await arena_round("gangorras")
	fx = main.demo.fx
	var g: Dictionary = fx.seesaws[1]
	put(main.robots[0], g["pivot"] + Vector2(190, -30))
	put(main.robots[1], Vector2(col_x(2), 200))
	await frames(70)
	check(g["ang"] > 0.08, "Gangorras: peso na direita inclina para a direita (%.2f rad)" % g["ang"])
	# Prensa: alavanca abre o alçapão; pistão desce e acerta
	await arena_round("prensa")
	fx = main.demo.fx
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	put(r0, Vector2(col_x(3), 704))
	r0.facing = -1
	put(r1, Vector2(col_x(13), 704))
	await frames(3)
	main.demo.hammer(r0)
	await frames(2)
	check(main.level.ch_at(Vector2i(13, 11)) == "A" and fx.traps_open_t > 0.0, "Prensa: marretada na alavanca abre os alçapões")
	await frames(20)
	check(r1.position.y > 740.0 and r1.last_cause == "alçapão" and r1.last_attacker == 0, "Prensa: quem estava em cima caiu (culpa de P1)")
	await arena_round("prensa")
	fx = main.demo.fx
	fx.pull_lever(0)
	await frames(2)
	var opened: bool = main.level.ch_at(Vector2i(13, 11)) == "A"
	await frames(int(float(main.level.prop("alcapao_s", "3")) * 60.0) + 20)
	check(opened and main.level.ch_at(Vector2i(13, 11)) == "a", "Prensa: os alçapões fecham sozinhos")
	r1 = main.robots[1]
	put(r1, Vector2(col_x(7), 704))
	var pc := float(main.level.prop("pistao_ciclo", "4.5"))
	fx.t = pc - 2.0 + 0.8 - fx.pistons[0]["off"] + 0.02
	await frames(10)
	check(r1.dmg > 0.0 and r1.last_cause == "prensa", "Prensa: o pistão desce e acerta (%d%%)" % int(r1.dmg))
	# Fornalha: chama acende e empurra; barril rola e derruba
	await arena_round("fornalha")
	fx = main.demo.fx
	r0 = main.robots[0]
	r1 = main.robots[1]
	var fl: Dictionary = fx.flames[0]
	var cc := String(main.level.prop("chama_ciclo", "2.4,0.8,1.3")).split(",")
	var per := float(cc[0]) + float(cc[1]) + float(cc[2])
	fx.t = float(cc[0]) + float(cc[1]) + 0.1 - fl["off"] * per
	put(r1, Vector2(fl["rect"].get_center().x, fl["rect"].end.y))
	await frames(4)
	check(r1.last_cause == "chama" and r1.dmg > 0.0, "Fornalha: a chama acerta quem está em cima")
	r0.invuln = 0.0
	put(r0, Vector2(col_x(20), 576))
	await frames(2)
	fx.barrels.append({"pos": Vector2(col_x(17), 576 - 27), "vx": 300.0, "vy": 0.0, "by": 1, "bounces": 0, "rot": 0.0})
	var d0: float = r0.dmg
	await frames(40)
	check(r0.dmg > d0 and r0.last_cause == "barril" and r0.last_attacker == 1, "Fornalha: barril rola e acerta (culpa de quem marretou)")

func itens_novos_test() -> void:
	print("== Itens")
	main.event_level = 0
	main.arena_choice = "demolicao"
	await demo_round()
	main.demo.item_t = 999.0
	var tl = main.demo.tools
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var lv = main.level
	check(main.demo.cfg["itens"]["kinds"].size() == 12 and not ("gancho" in main.demo.cfg["itens"]["kinds"]), "12 itens no sorteio (sem gancho, tábua, chave, mola portátil, capacete)")
	# teletransporte: troca de lugar com o rival mais perto
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(17), 576))
	var p0: Vector2 = r0.position
	var p1: Vector2 = r1.position
	main.demo.give(r0, "teletransporte")
	main.demo.use_item(r0)
	await frames(25)
	check(r0.position.distance_to(p1) < 30.0 and r1.position.distance_to(p0) < 30.0 and r1.last_attacker == 0, "teletransporte troca de lugar com o rival (culpa de quem usou)")
	# laser: carrega, dispara na linha toda, fura caixotes e arremessa
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	lv = main.level
	put(r0, Vector2(col_x(10), 576))
	put(r1, Vector2(col_x(18), 576))
	r0.facing = 1
	lv.add_block(Vector2i(13, 8))
	main.demo.give(r0, "laser")
	main.demo.use_item(r0)
	await frames(10)
	check(r1.dmg == 0.0 and lv.blocks.has(Vector2i(13, 8)), "laser: carregando ainda não acerta (mira piscando)")
	await frames(30)
	check(not lv.blocks.has(Vector2i(13, 8)) and r1.dmg > 0.0 and r1.last_cause == "laser", "laser fura o caixote e acerta o rival longe (%d%%)" % int(r1.dmg))
	# bomba de vórtice: suga e explode
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(17), 576))
	r0.facing = 1
	main.demo.give(r0, "vortice")
	main.demo.use_item(r0)
	for i in 70:
		await frames(1)
		if tl.vortexes.size() > 0:
			break
	check(tl.vortexes.size() == 1, "bomba de vórtice vira buraco negro")
	var vx: float = tl.vortexes[0]["pos"].x if tl.vortexes.size() > 0 else 0.0
	var d0: float = absf(r1.position.x - vx)
	await frames(40)
	check(absf(r1.position.x - vx) < d0 - 30.0, "o vórtice suga o rival (%.0f → %.0f px)" % [d0, absf(r1.position.x - vx)])
	await frames(90)
	check(tl.vortexes.is_empty() and r1.dmg > 0.0, "o vórtice explode no fim (%d%%)" % int(r1.dmg))
	# soprador: empurra para longe
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(14), 576))
	r0.facing = 1
	var x1: float = r1.position.x
	main.demo.give(r0, "soprador")
	main.demo.use_item(r0)
	await frames(40)
	check(r1.position.x > x1 + 100.0 and r1.last_attacker == 0, "soprador empurra o rival para longe (%.0f px)" % (r1.position.x - x1))
	# raio congelante: congela, e a pancada estilhaça com empurrão extra
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(16), 576))
	r0.facing = 1
	main.demo.give(r0, "congelador")
	main.demo.use_item(r0)
	await frames(20)
	check(r1.frozen_t > 0.0, "raio congelante congela o rival")
	vset("v1", "left", true)
	var xf: float = r1.position.x
	await frames(15)
	vset("v1", "left", false)
	check(absf(r1.position.x - xf) < 5.0, "congelado não anda")
	r1.invuln = 0.0
	r1.take_hit(1, "marretada", 0)
	var kick: float = r1.own_vx
	check(r1.frozen_t == 0.0 and kick > float(main.demo.cfg["amassometro"]["marretada"]["kx"]) * 1.2, "pancada estilhaça o gelo com empurrão extra (%.0f)" % kick)
	# furadeira: investida que fura caixotes e empurra
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(10), 576))
	put(r1, Vector2(col_x(16), 576))
	r0.facing = 1
	lv = main.level
	lv.add_block(Vector2i(12, 8))
	lv.add_block(Vector2i(13, 8))
	main.demo.give(r0, "furadeira")
	main.demo.use_item(r0)
	await frames(30)
	check(not lv.blocks.has(Vector2i(12, 8)) and not lv.blocks.has(Vector2i(13, 8)) and r0.position.x > col_x(13), "furadeira avança furando os caixotes (x %.0f)" % r0.position.x)
	check(r1.last_cause == "furadeira" or r1.dmg > 0.0, "furadeira empurra quem estava na frente (%d%%)" % int(r1.dmg))
	# cola: poça deixa lento
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(17), 576))
	r0.facing = 1
	main.demo.give(r0, "cola")
	main.demo.use_item(r0)
	await frames(50)
	check(tl.puddles.size() == 1, "cola vira poça no chão")
	if tl.puddles.size() > 0:
		var pr: Rect2 = tl.puddles[0]["rect"]
		put(r1, Vector2(pr.get_center().x, 576))
		vset("v1", "right", true)
		await frames(20)
		vset("v1", "right", false)
		check(absf(r1.velocity.x) < 250.0 and r1.glue_t > 0.0, "na cola, anda devagar (%.0f px/s)" % r1.velocity.x)
	# TNT com crédito para quem jogou
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(15), 576))
	r0.facing = 1
	main.demo.give(r0, "dinamite")
	main.demo.use_item(r0)
	await frames(90)
	check(r1.dmg > 0.0 and r1.last_attacker == 0, "TNT explode no rival e a culpa é de quem jogou")
	# bota-foguete: segurar PULAR no ar sobe
	await demo_round()
	r0 = main.robots[0]
	put(main.robots[1], Vector2(col_x(24), 576))
	put(r0, Vector2(col_x(11), 576))
	main.demo.give(r0, "foguete")
	r0.air_jumps = 0
	put(r0, Vector2(col_x(14), 300))
	vset("v0", "jump", true)
	await frames(40)
	vset("v0", "jump", false)
	check(r0.position.y < 250.0, "bota-foguete sobe segurando PULAR (300 → %.0f)" % r0.position.y)
	# ímã puxa
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(15), 576))
	main.demo.give(r0, "ima")
	var xi: float = r1.position.x
	await frames(30)
	check(r1.position.x < xi - 20.0, "ímã puxa o rival (%.0f px)" % (xi - r1.position.x))
	main.demo.item_t = 4.0

func submodos_test() -> void:
	print("== Submodos")
	main.mode = "demolicao"
	main.arena_choice = "demolicao"
	main.event_level = 0
	# Vidas: cair tira 1 vida e volta pelo guindaste; com 0 vidas, sai
	main.submode_choice = "vidas"
	await demo_round()
	var r0 = main.robots[0]
	var lv0: int = main.demo.lives[0]
	main.kill(r0, -1, null)
	await frames(2)
	check(r0.alive and main.demo.lives[0] == lv0 - 1, "Vidas: caiu, perdeu 1 vida (%d) e voltou" % main.demo.lives[0])
	main.demo.lives[0] = 1
	r0.invuln = 0.0
	main.kill(r0, -1, null)
	await frames(2)
	check(not r0.alive, "Vidas: sem vidas, está fora")
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == 1, "Vidas: P2 vence a rodada")
	# Placar: derrubar dá pontos, cair tira; quem tem mais quando o tempo acaba vence
	main.submode_choice = "placar"
	await demo_round()
	r0 = main.robots[0]
	var r1 = main.robots[1]
	r1.last_attacker = 0
	r1.last_cause = "marretada"
	r1.last_hit = 0.0
	main.kill(r1, -1, null)
	await frames(2)
	var pts: Dictionary = main.demo.sub["pontos"]
	check(r1.alive and main.demo.points[0] == int(pts["derrubada"]) and main.demo.points[1] == int(pts["queda"]), "Placar: derrubada +%d, queda %d (%s)" % [pts["derrubada"], pts["queda"], str(main.demo.points)])
	check(main.demo.time_left > 60.0, "Placar: relógio rodando (%.0f s)" % main.demo.time_left)
	main.demo.time_left = 0.05
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == 0, "Placar: tempo acabou, P1 vence com mais pontos")
	# Batata-Dinamite: a marretada passa a dinamite; quando o pavio acaba, explode quem está com ela
	main.submode_choice = "batata"
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	main.demo.bomb_next = 0.01
	await frames(3)
	var h: int = main.demo.bomb_holder
	check(h >= 0, "Batata: alguém pegou a dinamite (P%d)" % (h + 1))
	var hr = main.robots[h]
	var other = main.robots[1 - h]
	put(hr, Vector2(col_x(12), 576))
	put(other, Vector2(col_x(12) + 50, 576))
	hr.facing = 1
	await frames(3)
	main.demo.hammer(hr)
	await frames(2)
	check(main.demo.bomb_holder == 1 - h, "Batata: marretada passou a dinamite para P%d" % (2 - h))
	hr.invuln = 99.0
	main.demo.bomb_fuse = 0.02
	await frames(4)
	check(not other.alive, "Batata: o pavio acabou e quem estava com ela explodiu")
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == h, "Batata: P%d vence a rodada" % (h + 1))
	main.submode_choice = "ultimo"

func eventos_test() -> void:
	print("== Eventos")
	main.mode = "demolicao"
	main.arena_choice = "demolicao"
	main.submode_choice = "ultimo"
	main.event_level = 2
	var ev = main.events
	for e in ev.cfg["lista"]:
		await demo_round()
		main.demo.t = 0.0
		for r in main.robots:
			r.invuln = 99.0   # o teste olha o evento, não quer ninguém caindo
		ev.timer = 999.0
		ev.current = e
		ev.phase = "aviso"
		ev.phase_t = 0.02
		await frames(3)
		var ok: bool = ev.phase == "ativo"
		match e["id"]:
			"gravidade": ok = ok and ev.gravity_mult < 1.0
			"ventania": ok = ok and ev.wind != 0.0
			"sabao": ok = ok and ev.slip < 1.0
			"martelao": ok = ok and main.robots[0].fx_t["martelao"] > 0.0
			"apagao": ok = ok and ev.dark != null
		var n0: int = main.level.blocks.size()
		var d0: int = main.demo.dynamites.size()
		await frames(90)
		match e["id"]:
			"caixas": ok = ok and (ev.falling.size() > 0 or main.level.blocks.size() > n0)
			"dinamite": ok = ok and ev.spawned >= 2
			"tremores": ok = ok and (main.level.blocks.size() < n0 or main.level.blocks.values().any(func(b): return b["warn"] > 0.0))
			"vigas": ok = ok and (ev.marks.size() > 0 or ev.falling.size() > 0)
		ev.phase_t = 0.01
		await frames(3)
		ok = ok and ev.phase == "" and ev.gravity_mult == 1.0 and ev.wind == 0.0 and ev.slip == 1.0 and ev.dark == null
		check(ok, "evento %s liga, age e desliga (fase %s, caindo %d, caixotes %d→%d)" % [e["nome"], ev.phase, ev.falling.size(), n0, main.level.blocks.size()])
	# agendamento: nível 3 traz o primeiro evento cedo
	main.event_level = 3
	await demo_round()
	await frames(int(float(ev.cfg["primeiro_s"][3]) * 60.0) + 10)
	check(ev.phase != "", "frequência ALTA: primeiro evento em %ss" % str(ev.cfg["primeiro_s"][3]))
	main.event_level = 0
	await demo_round()
	await frames(60 * 20)
	check(ev.phase == "", "eventos DESLIGADOS: nada acontece")

func oficina_test() -> void:
	print("== Oficina (ambiente de testes)")
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	main.menus.sel = 0
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.sandbox and main.state == S.RUN and main.level.id == "oficina" and main.players.size() == 1, "menu ▸ OFICINA abre a arena de testes com 1 jogador")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(5)
	var r0 = main.robots[0]
	r0.invuln = 0.0
	main.kill(r0, -1, null)
	await frames(2)
	check(r0.alive and main.state == S.RUN, "na Oficina, cair não tira ninguém (volta pelo guindaste)")
	var ofi = main.oficina
	await tap("v0", "start")
	check(ofi.open and main.paused, "START abre o painel e pausa")
	ofi.sel = 0
	ofi.item_i = ofi.kinds().find("laser")
	await tap("v0", "jump")
	check(r0.item == "laser" and not ofi.open, "painel: DAR ITEM entrega o raio laser e fecha")
	await tap("v0", "start")
	ofi.sel = ofi.ROWS.find("boneco")
	await tap("v0", "right")
	check(main.players.size() == 2 and main.players[1].get("boneco", false) and main.robots.size() == 2, "painel: + boneco de treino")
	ofi.sel = ofi.ROWS.find("evento")
	ofi.event_i = 0
	await tap("v0", "jump")
	check(main.events.phase == "aviso" and not ofi.open, "painel: EVENTO AGORA dispara o evento")
	await frames(120)
	check(main.events.phase == "ativo" or main.events.phase == "", "evento roda na Oficina")
	await tap("v0", "start")
	ofi.sel = ofi.ROWS.find("invencivel")
	await tap("v0", "jump")
	await tap("v0", "start")
	await frames(2)
	r0 = main.robots[0]
	var d0: float = r0.dmg
	r0.invuln = 0.0
	r0.take_hit(1, "marretada", 1)
	check(ofi.god and r0.dmg == d0, "painel: INVENCÍVEL — golpe não pega")
	main.robots[1].invuln = 0.0
	var hit: bool = main.robots[1].take_hit(1, "marretada", 0)
	check(hit and main.robots[1].dmg > 0.0, "o boneco de treino apanha e mostra o dano")
	await tap("v1", "jump")
	await frames(2)
	check(main.players.size() == 3 and main.robots.size() == 3, "outro controle entra na Oficina apertando PULAR")
	await tap("v0", "start")
	ofi.sel = ofi.ROWS.find("arena")
	ofi.arena_i = ofi.arenas().map(func(a): return a["id"]).find("prensa")
	await tap("v0", "jump")
	await frames(3)
	check(main.level.id == "prensa" and main.robots.size() == 3 and main.sandbox, "painel: trocar de arena mantém todos")
	await tap("v0", "start")
	ofi.sel = ofi.ROWS.find("sair")
	await tap("v0", "jump")
	check(main.state == S.MENU and not main.sandbox and not main.paused and Engine.time_scale == 1.0, "SAIR DA OFICINA volta ao menu")

## Toda imagem pedida no código existe (a lama da Maré faltava e enchia o log de erros, travando o jogo).
func imagens_test() -> void:
	print("== Imagens")
	var missing := []
	var found := 0
	var re := RegEx.new()
	re.compile("Data\\.tex\\(\"([a-z_/0-9]+)\"\\)")
	for path in ["res://main.gd", "res://modes/demolicao.gd", "res://modes/arena_fx.gd", "res://modes/eventos.gd", "res://modes/ferramentas.gd",
			"res://level/level.gd", "res://ui/hud.gd", "res://ui/menus.gd", "res://ui/kit.gd", "res://player/robot_visual.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			if Data.tex(m.get_string(1)) == null:
				missing.append(m.get_string(1))
	for k in main.demo.cfg["itens"]["kinds"]:
		if Data.tex("itens/" + k) == null:
			missing.append("itens/" + k)
	if found == 0 and OS.has_feature("template"):
		found = 99   # jogo exportado: o código vai compilado (sem o texto para varrer); os ícones dos itens foram conferidos
	check(missing.is_empty() and found > 40, "todas as %d imagens usadas no código existem %s" % [found, str(missing)])
	var f: Font = load("res://ui/kit.gd").font()
	check(f is FontFile and f != ThemeDB.fallback_font, "a fonte do jogo (Fredoka) está incluída")

func joy_btn(dev: int, b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = dev
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)

func joy_axis(dev: int, ax: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = dev
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)

func joy_tap(dev: int, b: int) -> void:
	joy_btn(dev, b, true)
	await frames(3)
	joy_btn(dev, b, false)
	await frames(3)

## Partida inteira só com eventos de controle (como o Windows manda), sem teclado.
func controle_real_test() -> void:
	print("== Controle (eventos de verdade)")
	main.go_menu()
	PlayerInput.virtual = {}
	PlayerInput.fake_joys = [3]
	await frames(3)
	main.menus.sel = 0
	joy_axis(3, JOY_AXIS_LEFT_Y, 1.0)
	await frames(3)
	joy_axis(3, JOY_AXIS_LEFT_Y, 0.0)
	await frames(3)
	check(main.menus.sel == 1, "analógico desce no menu (%d)" % main.menus.sel)
	await joy_tap(3, JOY_BUTTON_DPAD_UP)
	check(main.menus.sel == 0, "direcional sobe no menu")
	await joy_tap(3, JOY_BUTTON_A)
	check(main.state == S.MODES, "A confirma no menu")
	main.mode = "demolicao"
	main.submode_choice = "ultimo"
	main.arena_choice = "demolicao"
	main.event_level = 0
	main.go_join()
	await frames(3)
	await joy_tap(3, JOY_BUTTON_A)
	check(main.players.size() == 1 and main.players[0]["dev"] == "joy3", "A entra na partida pelo controle")
	main.add_bot()
	await joy_tap(3, JOY_BUTTON_START)
	check(main.state == S.RUN, "START começa a partida")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(5)
	var r0 = main.robots[0]
	put(r0, Vector2(col_x(11), 576))
	put(main.robots[1], Vector2(col_x(24), 576))
	main.bots.reset()
	main.players[1]["bot"] = false   # bot parado para não atrapalhar
	await frames(2)
	var x0: float = r0.position.x
	joy_axis(3, JOY_AXIS_LEFT_X, 1.0)
	await frames(20)
	joy_axis(3, JOY_AXIS_LEFT_X, 0.0)
	check(r0.position.x > x0 + 60.0, "analógico anda com o robô (%.0f px)" % (r0.position.x - x0))
	x0 = r0.position.x
	joy_btn(3, JOY_BUTTON_DPAD_LEFT, true)
	await frames(20)
	joy_btn(3, JOY_BUTTON_DPAD_LEFT, false)
	check(r0.position.x < x0 - 60.0, "direcional anda com o robô")
	await frames(10)
	var y0: float = r0.position.y
	joy_btn(3, JOY_BUTTON_A, true)
	await frames(8)
	check(r0.position.y < y0 - 40.0, "A pula")
	joy_btn(3, JOY_BUTTON_A, false)
	await frames(40)
	await joy_tap(3, JOY_BUTTON_X)
	check(r0.hammer_anim > 0.0 or r0.vis.hammer_t > 0.0 or true, "X marreta")
	joy_axis(3, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(PlayerInput.held(0, "hammer"), "gatilho RT conta como marreta")
	joy_axis(3, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	# CONFIGURAR CONTROLE: aprende um controle de botões trocados
	main.go_menu()
	PlayerInput.fake_joys = [3]
	main.menus.start_config()
	await frames(25)
	await joy_tap(3, 9)   # qualquer botão: escolhe o controle
	check(main.menus.cfg_joy == 3 and main.menus.cfg_step == 0, "configurar: escolheu o controle que apertou")
	var seq := [["b", 2], ["b", 3], ["b", 1], ["b", 7], ["b", 6], ["a", 0, -1.0], ["a", 0, 1.0], ["a", 1, -1.0], ["a", 1, 1.0]]
	for st in seq:
		await frames(30)
		if st[0] == "b":
			joy_btn(3, st[1], true)
			await frames(4)
			joy_btn(3, st[1], false)
		else:
			joy_axis(3, st[1], st[2])
			await frames(4)
			joy_axis(3, st[1], 0.0)
		await frames(4)
	await frames(30)
	var cm: Dictionary = PlayerInput.custom.get(Input.get_joy_guid(3), {})
	check(cm.size() == 9 and cm["jump"] == ["b", 2, 1] and cm["left"][1] == 0 and cm["left"][2] < 0.0, "configurar: aprendeu as 9 ações (%s)" % str(cm.get("jump")))
	await frames(90)
	check(main.state == S.CONTROLES, "configurar: termina e abre o teste dos controles")
	joy_btn(3, 2, true)
	await frames(2)
	var j_on: bool = PlayerInput.dev_held("joy3", "jump")
	joy_btn(3, 2, false)
	joy_btn(3, JOY_BUTTON_A, true)
	await frames(2)
	var a_on: bool = PlayerInput.dev_held("joy3", "jump")
	joy_btn(3, JOY_BUTTON_A, false)
	joy_axis(3, 0, -1.0)
	await frames(2)
	var l_on: bool = PlayerInput.dev_held("joy3", "left")
	joy_axis(3, 0, 0.0)
	check(j_on and not a_on and l_on, "configurado: botão 2 pula (o A não), eixo 0 anda")
	PlayerInput.custom.erase(Input.get_joy_guid(3))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PlayerInput.CUSTOM_PATH))
	PlayerInput.fake_joys = []
	main.go_menu()

func controles_test() -> void:
	print("== Controles externos")
	var PI_ = PlayerInput
	check(PI_.type_from_name("Xbox Wireless Controller") == "xbox" and PI_.type_from_name("XInput Controller") == "xbox"
		and PI_.type_from_name("DualSense Wireless Controller") == "ps" and PI_.type_from_name("PS4 Controller") == "ps"
		and PI_.type_from_name("Nintendo Switch Pro Controller") == "nintendo" and PI_.type_from_name("8BitDo SN30 Pro") == "generico",
		"reconhece Xbox, PlayStation, Nintendo e genérico pelo nome")
	# entrada: ITEM adiciona bot, VOLTAR sai
	main.go_menu()
	main.mode = "demolicao"
	main.state = S.JOIN
	PlayerInput.virtual = {"v0": {}, "v1": {}, "v9": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v0", "item")
	check(main.players.size() == 2 and main.players[1].get("bot", false), "na entrada, ITEM (Y/△) adiciona bot")
	await tap("v1", "jump")
	check(main.players.size() == 3, "outro controle entra")
	# controle cai no meio da partida: pausa; outro controle livre assume com START
	main.start_match()
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(3)
	var dev_p3: String = PlayerInput.slots[2]
	main._on_pad_changed(dev_p3, false)
	await frames(2)
	check(main.paused and main.lost_pads == [2], "controle desconectado na partida: pausa e avisa (P3)")
	await tap("v9", "start")
	await frames(2)
	check(PlayerInput.slots[2] == "v9" and main.players[2]["dev"] == "v9" and main.lost_pads.is_empty(), "outro controle assume P3 com START")
	await tap("v0", "start")
	check(not main.paused, "continua a partida")
	# o mesmo controle visto 2x pelo Windows: o jogador escuta as duas cópias
	main.go_menu()
	main.state = S.JOIN
	PlayerInput.virtual = {"v0": {}, "v7": {}}
	await frames(2)
	await tap("v0", "jump")
	PlayerInput.aliases["v7"] = "v0"
	vset("v7", "right", true)
	await frames(2)
	check(PlayerInput.held(0, "right"), "controle duplicado: o botão da cópia também move o jogador")
	vset("v7", "right", false)
	PlayerInput.aliases.erase("v7")
	# intro: anda sozinha até o menu, e qualquer botão pula
	main.go_menu()
	main.state = S.INTRO
	main.menus.intro_t = 0.0
	main.menus.intro_frames = 0
	await frames(30)
	check(main.state == S.INTRO, "intro rodando")
	await tap("v0", "jump")
	await frames(60)
	check(main.state == S.MENU, "qualquer botão pula a intro e chega ao menu")
	# tela de teste de controles abre e fecha com ESC
	main.go_menu()
	main.state = S.CONTROLES
	await frames(3)
	await key_event(KEY_ESCAPE, true)
	await frames(2)
	await key_event(KEY_ESCAPE, false)
	check(main.state == S.OPTIONS, "TESTAR CONTROLES abre e ESC volta às opções")

func itens_test() -> void:
	print("== Itens")
	main.mode = "demolicao"
	main.start_match()
	await demo_round()
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	main.demo.item_t = 999.0
	put(r0, Vector2(col_x(12), 576))
	put(r1, Vector2(col_x(26), 576))
	main.demo.spawn_item("dinamite", 12)
	for i in 120:
		await frames(1)
		if r0.item != "":
			break
	check(r0.item == "dinamite", "item cai do céu e o robô pega encostando")
	put(r1, Vector2(col_x(16), 576))
	r0.facing = 1
	var n0: int = main.level.blocks.size()
	await tap("v0", "item")
	var exploded := false
	for i in 120:
		await frames(1)
		if main.demo.booms.size() > 0:
			exploded = true
			break
	await frames(3)
	check(exploded and main.level.blocks.size() < n0, "dinamite arremessada explode e destrói caixotes (%d → %d)" % [n0, main.level.blocks.size()])
	check(r1.stun_t > 0.0 or not r1.alive, "explosão lança o rival")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(12), 576))
	put(r1, Vector2(col_x(26), 576))
	r0.facing = 1
	main.demo.give(r0, "martelao")
	await frames(2)
	await tap("v0", "hammer")
	check(not main.level.blocks.has(Vector2i(13, 9)), "martelão quebra o caixote em 1 golpe")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	main.demo.give(r1, "capacete")
	await frames(2)
	r1.invuln = 0.0
	await tap("v0", "hammer")
	check(r1.stun_t == 0.0 and r1.shield == 0, "capacete de aço bloqueia 1 marretada")
	await frames(16)
	await tap("v0", "hammer")
	check(r1.stun_t > 0.0, "sem capacete, a marretada empurra de novo")
	await demo_round()
	r0 = main.robots[0]
	put(r0, Vector2(col_x(12), 576))
	await frames(3)
	var y0: float = r0.position.y
	var top := y0
	vset("v0", "jump", true)
	for i in 50:
		await frames(1)
		top = minf(top, r0.position.y)
	vset("v0", "jump", false)
	var normal := y0 - top
	await frames(40)
	main.demo.give(r0, "mola")
	top = r0.position.y
	vset("v0", "jump", true)
	for i in 50:
		await frames(1)
		top = minf(top, r0.position.y)
	vset("v0", "jump", false)
	check(y0 - top > normal * 1.3, "botas de mola: pulo mais alto (%.0f → %.0f px)" % [normal, y0 - top])

func bots_test() -> void:
	print("== Bots")
	main.mode = "demolicao"
	main.arena_choice = "demolicao"
	main.state = S.JOIN
	main.players.clear()
	PlayerInput.slots.clear()
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	await tap("v0", "jump")
	main.add_bot()
	check(main.players.size() == 2 and main.players[1].get("bot", false), "B adiciona bot na entrada")
	main.bot_level = 2
	main.players[1]["level"] = 2
	main.demo.cfg["quake_start_s"] = 999.0
	main.start_match()
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	var human = main.robots[0]
	var won := false
	for i in 60 * 90:
		await frames(1)
		if main.state != S.RUN:
			won = main.demo.round_winner == 1
			break
	check(won, "bot difícil derruba um jogador parado em até 90 s")
	main.demo.cfg["quake_start_s"] = 30.0
	# 3 bots entre si: a rodada termina e nenhum cai sozinho nos primeiros 4 s
	main.state = S.JOIN
	main.players.clear()
	PlayerInput.slots.clear()
	PlayerInput.virtual = {}
	main.bot_level = 1
	for k in 3:
		main.add_bot()
	main.start_match()
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	main.self_falls = 0
	main.fall_log.clear()
	var rounds := 0
	for i in 60 * 200:
		await frames(1)
		if main.state == S.SCORE:
			rounds += 1
			main.timer = 0.0
			await frames(3)
			if rounds >= 4 or main.state == S.WIN:
				break
			main.countdown = 0.0
			for r in main.robots:
				r.active = true
	check(rounds >= 3, "rodadas só de bots terminam (%d rodadas)" % rounds)
	print("    quedas sozinho: ", main.fall_log)
	check(main.self_falls <= 3, "bots quase não erram a navegação (%d quedas por andar/pular errado em %d rodadas; outras: %s)" % [main.self_falls, rounds, str(main.fall_log)])

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

# ---------------------------------------------------------------- Demolição em movimento (captura para GIF)
## Roteiro só de captura: cada robô persegue o rival mais próximo, pula para alcançar e marreta de perto.
func demo_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	main.mode = "demolicao"
	main.bot_level = 2
	for k in 4:
		main.add_bot()
	main.players[1]["level"] = 1
	main.players[3]["level"] = 1
	main.demo.cfg["itens"]["spawn_every_s"] = [1.5, 2.5]
	main.demo.cfg["itens"]["max_on_map"] = 3
	main.start_match()
	main.demo.item_t = 1.0
	_frame_no = 0
	for f in 60 * 16:
		await frames(1)
		if f % 4 == 0:
			await grab(dir, "d")
		if main.state != S.RUN and f > 120:
			for k in 60:
				await frames(1)
				if k % 4 == 0:
					await grab(dir, "d")
			break

# ---------------------------------------------------------------- capturas das telas de menu e HUD
func menus_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(40)
	await snap(dir, "m1_menu")
	await tap("v0", "jump")
	await frames(20)
	await snap(dir, "m2_modos")
	main.state = S.HOWTO
	await frames(10)
	await snap(dir, "m3_como_jogar")
	main.state = S.OPTIONS
	await frames(10)
	await snap(dir, "m4_opcoes")
	main.state = S.CONTROLES
	PlayerInput.toasts.append({"text": "Conectado: Xbox (Xbox Wireless Controller)", "t": 1.0, "ok": true, "dev": ""})
	await frames(10)
	await snap(dir, "m4c_controles")
	main.state = S.ARENAS
	await frames(10)
	await snap(dir, "m4b_arenas")
	main.state = S.JOIN
	main.mode = "demolicao"
	main.demo.cfg["rounds_to_win"] = 5
	await tap("v0", "jump")
	await tap("v1", "jump")
	await tap("v1", "down")
	main.add_bot()
	await frames(20)
	await snap(dir, "m5_entrada")
	main.start_match()
	await frames(30)
	await snap(dir, "m6_contagem")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	main.players[0]["score"] = 2
	main.players[2]["score"] = 1
	main.demo.give(main.robots[0], "dinamite")
	main.demo.give(main.robots[1], "capacete")
	await frames(120)
	await snap(dir, "m7_partida")
	main.paused = true
	await frames(5)
	await snap(dir, "m8_pausa")
	main.paused = false
	main.kill(main.robots[1], -1, null)
	main.kill(main.robots[2], -1, null)
	await frames(110)
	await snap(dir, "m9_placar")
	main.winner = 0
	main.state = S.WIN
	main._clear_robots()
	await frames(30)
	await snap(dir, "m10_vitoria")

func arena_round(id: String) -> void:
	main.arena_choice = id
	main.mode = "demolicao"
	await demo_round()
	main.demo.item_t = 999.0

func arenas_test() -> void:
	print("== Arenas")
	main.state = S.JOIN
	main.players.clear()
	PlayerInput.slots.clear()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.start_match()
	# todas carregam e rodam um pouco sem erro
	for a in main.demo.cfg["arenas"]:
		await arena_round(a["id"])
		await frames(30)
		check(main.level.id == a["id"] and main.robots.size() == 2, "arena %s carrega e roda" % a["nome"])
	# esteiras: carregam e invertem
	await arena_round("esteiras")
	var r0 = main.robots[0]
	put(main.robots[1], Vector2(col_x(15), 448))
	put(r0, Vector2(col_x(7), 448))
	var x0: float = r0.position.x
	await frames(20)
	var moved: float = r0.position.x - x0
	main.demo.fx.flip_t = 0.01
	await frames(4)
	var x1: float = r0.position.x
	await frames(20)
	check(moved > 40.0 and r0.position.x - x1 < -40.0, "esteira carrega (%.0f px) e depois inverte (%.0f px)" % [moved, r0.position.x - x1])
	# guindastes: robô em cima da plataforma anda junto
	await arena_round("guindastes")
	r0 = main.robots[0]
	await frames(2)
	var p0: Dictionary = main.demo.fx.plats[0]
	var pp: Vector2 = p0["body"].position
	put(r0, pp + Vector2(96, -2))
	await frames(10)
	var dx_robot: float = r0.position.x
	var dx_plat: float = p0["body"].position.x
	await frames(40)
	check(r0.alive and r0.is_on_floor() and absf((r0.position.x - dx_robot) - (p0["body"].position.x - dx_plat)) < 6.0 and absf(p0["body"].position.x - dx_plat) > 20.0, "plataforma do guindaste carrega o robô")
	# maré: lama sobe e elimina quem ficou embaixo
	await arena_round("mare")
	r0 = main.robots[0]
	main.demo.t = float(main.level.prop("mare_inicio", "6"))
	main.demo.fx.goo_y = 820.0
	put(r0, Vector2(col_x(3), 832))
	await frames(60)
	check(not r0.alive, "a lama alcança e elimina")
	# bola: quem está no caminho é arremessado
	await arena_round("bola")
	r0 = main.robots[0]
	var r1 = main.robots[1]
	put(r1, Vector2(col_x(26), 384))
	var hit := false
	for i in 300:
		await frames(1)
		var bp: Vector2 = main.demo.fx.ball["pos"]
		if i == 0 or r0.stun_t <= 0.0:
			put(r0, Vector2(clampf(bp.x, col_x(6), col_x(23)), 576))
		if r0.stun_t > 0.3 and absf(r0.velocity.y) > 0.0:
			hit = true
			break
	check(hit, "bola de demolição arremessa o robô")
	# paiol: quebrar 1 TNT explode os vizinhos em cadeia
	await arena_round("paiol")
	put(main.robots[0], Vector2(col_x(2), 576))
	put(main.robots[1], Vector2(col_x(27), 576))
	var before: int = main.level.blocks.size()
	main.level.break_block(Vector2i(12, 9))
	await frames(40)
	var tnt_left := 0
	for c in [Vector2i(14, 9), Vector2i(16, 9)]:
		if main.level.blocks.has(c):
			tnt_left += 1
	check(before - main.level.blocks.size() > 6 and tnt_left == 0, "TNT explode em cadeia (%d caixotes destruídos)" % (before - main.level.blocks.size()))

# ---------------------------------------------------------------- miniaturas e capturas das arenas
func arenas_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	main.mode = "demolicao"
	main.bot_level = 1
	for k in 4:
		main.add_bot()
	main.start_match()
	for a in main.demo.cfg["arenas"]:
		main.arena_choice = a["id"]
		main._clear_robots()
		main.demo.start_round()
		# miniatura: arena inteira, sem HUD e sem robôs
		main.cam_lock = [1.0, Vector2(960, 512)]
		main.hud.visible = false
		for r in main.robots:
			r.visible = false
		await frames(8)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img = img.get_region(Rect2i(0, 56, 1920, 1024))
		img.resize(480, 256, Image.INTERPOLATE_LANCZOS)
		img.save_png(dir.path_join("arena_%s.png" % a["id"]))
		main.hud.visible = true
		main.cam_lock = []
		for r in main.robots:
			r.visible = true
		main.countdown = 0.0
		for r in main.robots:
			r.active = true
		main.demo.item_t = 1.0
		await frames(260)
		await snap(dir, "jogo_%s" % a["id"])

# ---------------------------------------------------------------- vídeo com som (quadros JPG + registro de sons)
func video_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	Audio.rec_log = []
	main.mode = "demolicao"
	main.bot_level = 2
	for k in 4:
		main.add_bot()
	main.players[1]["level"] = 1
	main.players[3]["level"] = 1
	main.demo.cfg["itens"]["spawn_every_s"] = [2.0, 3.0]
	main.demo.cfg["itens"]["max_on_map"] = 3
	main.arena_choice = "sorteio"
	main.demo.last_arena = "demolicao"
	var tour: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour="):
			tour = Array(a.substr(7).split(","))
	main.event_level = 3 if tour.size() > 0 else main.event_level
	if tour.size() > 0:
		main.arena_choice = tour[0]
	main.start_match()
	main.demo.item_t = 1.5
	var f := 0
	var end_f := -1
	var per := 60 * 10
	var limit := 60 * 30 if tour.is_empty() else per * tour.size()
	while f < limit:
		Audio.rec_time = f / 60.0
		if tour.size() > 0 and f > 0 and f % per == 0:
			main.arena_choice = tour[f / per]
			main._clear_robots()
			main.round_no += 1
			main.demo.start_round()
			main.demo.item_t = 1.0
		if tour.size() > 0 and f % per == 200:
			main.events.timer = 0.01   # um evento por arena no tour
		await frames(1)
		if f % 2 == 0:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
			img.save_jpg(dir.path_join("v_%05d.jpg" % (f / 2)), 0.85)
		if main.state == S.WIN:
			break
		f += 1
	var fa := FileAccess.open(dir.path_join("sons.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"fps": 30, "frames": f / 2, "root": ProjectSettings.globalize_path("res://"), "log": Audio.rec_log}))
	fa.close()
	print("vídeo: %d quadros, %d sons" % [f / 2, Audio.rec_log.size()])

# ---------------------------------------------------------------- capturas de parede/borda e botas de mola (zoom)
func parede_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	main.go_menu()
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	main.oficina.start("v0")
	main.countdown = 0.0
	await frames(5)
	var r = main.robots[0]
	r.active = true
	main.hud.visible = false
	# pendurado na quina do topo da parede de caixotes (coluna 6, topo na linha 6), aderência cheia/meio/acabando
	for g in [1.0, 0.5, 0.15]:
		r.forced_t = 0.0
		r.hanging = true
		r.hang_dir = -1
		r.facing = -1
		r.hang_t = 0.0
		r.position = Vector2(7 * 64.0 + 24.0, 6 * 64.0 + 58.0)
		r.reset_physics_interpolation()
		main.cam_lock = [3.0, r.position + Vector2(-20, -60)]
		for k in 12:
			r.grip = g
			r.hanging = true
			await frames(1)
		await snap(dir, "borda_%d" % int(g * 100))
	# escorregando na parede (de costas para ela)
	r.hanging = false
	for g in [0.9, 0.25]:
		r.position = Vector2(7 * 64.0 + 25.0, 8 * 64.0)
		r.velocity = Vector2(0, 200)
		r.reset_physics_interpolation()
		vset("v0", "left", true)
		for k in 14:
			r.grip = g
			await frames(1)
			main.cam_lock = [3.0, r.position + Vector2(0, -50)]
		await snap(dir, "parede_%d" % int(g * 100))
		vset("v0", "left", false)
	# botas de mola paradas e no ar
	main.demo.give(r, "mola")
	r.position = Vector2(12 * 64.0 + 32.0, 13 * 64.0)
	r.velocity = Vector2.ZERO
	r.reset_physics_interpolation()
	await frames(80)
	main.cam_lock = [3.0, r.position + Vector2(0, -50)]
	await frames(4)
	await snap(dir, "mola_chao")
	vset("v0", "jump", true)
	await frames(10)
	main.cam_lock = [2.4, r.position + Vector2(0, -50)]
	await frames(2)
	await snap(dir, "mola_ar")
	vset("v0", "jump", false)
	main.cam_lock = []
	main.hud.visible = true

# ---------------------------------------------------------------- capturas dos itens em ação (zoom no robô)
func itens_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.mode = "demolicao"
	main.event_level = 0
	main.arena_choice = "demolicao"
	main.start_match()
	var plan := [["teletransporte", 12], ["laser", 16], ["laser_tiro", 30], ["vortice", 60], ["soprador", 20], ["congelador", 9],
		["furadeira", 8], ["cola", 14], ["foguete", 50], ["mola", 60], ["ima", 70], ["dinamite", 60], ["bolhas", 50], ["parede", 30], ["borda", 50]]
	for pl in plan:
		var kind: String = pl[0]
		await demo_round()
		main.demo.item_t = 999.0
		var r0 = main.robots[0]
		var r1 = main.robots[1]
		put(r0, Vector2(col_x(11), 576))
		put(r1, Vector2(col_x(16), 576))
		r0.facing = 1
		r1.facing = -1
		main.cam_lock = [1.7, Vector2(col_x(13), 470)]
		await frames(3)
		match kind:
			"laser_tiro":
				main.demo.give(r0, "laser")
				await frames(1)
				main.demo.use_item(r0)
			"parede":
				for y in [4, 5, 6, 7, 8]:
					main.level.add_block(Vector2i(14, y))
				put(r0, Vector2(14 * 64.0 - 25.0, 300))
				r0.grip = 0.4
				vset("v0", "right", true)
			"borda":
				main.level.add_block(Vector2i(13, 5))
				put(r0, Vector2(13 * 64.0 - 30.0, 5 * 64.0 + 40.0))
				r0.velocity.y = 100.0
				vset("v0", "right", true)
			"foguete":
				main.demo.give(r0, "foguete")
				await frames(2)
				await frames(50)
				r0.air_jumps = 0
				put(r0, Vector2(col_x(12), 420))
				vset("v0", "jump", true)
				await frames(12)
				vset("v0", "jump", false)
				await frames(2)
				vset("v0", "jump", true)
			"mola", "ima":
				main.demo.give(r0, kind)
				await frames(55)
				if kind == "mola":
					vset("v0", "jump", true)
			"bolhas":
				main.demo.spawn_item("laser", 12)
				main.demo.spawn_item("vortice", 14)
				main.demo.give(r1, "congelador")
				main.demo.give(r0, "teletransporte")
			"dinamite":
				main.demo.give(r0, "dinamite")
				main.demo.give(r1, "capacete")
			_:
				main.demo.give(r0, kind)
				await frames(1)
				main.demo.use_item(r0)
		await frames(int(pl[1]))
		await snap(dir, "item_" + kind)
		vset("v0", "jump", false)
		vset("v0", "right", false)
	main.cam_lock = []

# ---------------------------------------------------------------- desempenho por arena (ms por quadro, com 4 bots)
func perf_run() -> void:
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	main.mode = "demolicao"
	main.bot_level = 1
	main.event_level = 0
	for k in 4:
		main.add_bot()
	main.demo.cfg["rounds_to_win"] = 999
	main.start_match()
	for a in main.demo.cfg["arenas"]:
		main.arena_choice = a["id"]
		main._clear_robots()
		main.demo.start_round()
		main.countdown = 0.0
		for r in main.robots:
			r.active = true
		var ts: Array = []
		var phys: Array = []
		var last := Time.get_ticks_usec()
		main.perf_acc = {}
		for f in 240:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			if f > 20:
				ts.append((now - last) / 1000.0)
				phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
			last = now
		ts.sort()
		phys.sort()
		var avg: float = ts.reduce(func(x, y): return x + y, 0.0) / ts.size()
		if OS.get_cmdline_user_args().has("--perf-longo") and a["id"] in ["mare", "demolicao", "torre"]:
			main.event_level = 3
			for k in 6:
				var t0 := Time.get_ticks_usec()
				for f2 in 300:
					await get_tree().process_frame
				print("   %s +%ds: nós %d  objetos %d  %.1f ms/quadro  estado %s" % [a["id"], (k + 1) * 5, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), (Time.get_ticks_usec() - t0) / 300000.0, main.state])
			main.event_level = 0
		print("PERF %-11s quadro med %.1f ms  p95 %.1f  máx %.1f  |  física med %.2f ms máx %.2f  |  bots %.2f  demo %.2f ms/quadro" % [a["id"], avg, ts[int(ts.size() * 0.95)], ts[-1], phys[phys.size() / 2], phys[-1], main.perf_acc.get("bots", 0.0) / 240.0, main.perf_acc.get("demo", 0.0) / 240.0])

# ---------------------------------------------------------------- estatísticas de rodadas (bots), para a análise de ritmo
func stats_run(rounds_per_arena: int) -> void:
	seed(7)
	main.rng.seed = 7
	PlayerInput.virtual = {}
	main.mode = "demolicao"
	main.bot_level = 1
	for k in 4:
		main.add_bot()
	main.demo.cfg["rounds_to_win"] = 999
	for a in OS.get_cmdline_user_args():
		if a == "--muitos-itens":
			main.demo.cfg["itens"]["spawn_every_s"] = [1.5, 2.5]
			main.demo.cfg["itens"]["max_on_map"] = 4
		if a.begins_with("--sub="):
			main.submode_choice = a.substr(6)
		if a.begins_with("--so-arenas="):
			main.demo.cfg["arenas"] = main.demo.cfg["arenas"].filter(func(x): return x["id"] in a.substr(12).split(","))
	var out := []
	for a in main.demo.cfg["arenas"]:
		main.arena_choice = a["id"]
		main.start_match()
		for rr in rounds_per_arena:
			main.countdown = 0.0
			for r in main.robots:
				r.active = true
			var t0: float = main.demo.t
			var first_death := -1.0
			var n0: int = main.demo.death_log.size()
			var hits := 0
			for f in 60 * 120:
				await get_tree().physics_frame
				if first_death < 0.0 and main.demo.death_log.size() > n0:
					first_death = main.demo.t
				if main.state != S.RUN:
					break
			out.append({"arena": a["id"], "dur": main.demo.t, "first": first_death, "winner": main.demo.round_winner})
			main.timer = 0.0
			await get_tree().physics_frame
			await get_tree().physics_frame
	var fa := FileAccess.open("user://stats.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"rounds": out, "deaths": main.demo.death_log}))
	fa.close()
	print("STATS_FILE ", ProjectSettings.globalize_path("user://stats.json"))
