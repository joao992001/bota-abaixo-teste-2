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
	check(ms is AudioStreamWAV and ms.loop_mode == AudioStreamWAV.LOOP_FORWARD, "música da partida em loop")
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

func demolicao_test() -> void:
	print("== Demolição")
	main.mode = "demolicao"
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
	check(r1.stun_t > 0.0, "marretada atordoa o rival")
	await frames(20)
	check(r1.position.x - x1 > 120.0, "marretada empurra o rival (%.0f px)" % (r1.position.x - x1))
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
	check(stomped and r0.velocity.y < 0.0, "pular na cabeça atordoa e quica")
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
	await menus_test()

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
	check(main.state == S.ARENAS, "Demolição abre a escolha de arena")
	await tap("v0", "right")
	await tap("v0", "right")
	await tap("v0", "jump")
	check(main.state == S.JOIN and main.mode == "demolicao" and int(main.demo.cfg["rounds_to_win"]) == 3 and main.arena_choice == "esteiras", "arena Fábrica de Esteiras escolhida, vence com 3 ★")
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
	await tap("v0", "jump")
	check(main.state == S.OPTIONS, "OPÇÕES abre")
	await tap("v0", "down")
	await tap("v0", "jump")
	check(not main.shake_on, "tremor da tela desliga")
	await tap("v0", "jump")
	await tap("v0", "back")
	check(main.state == S.MENU and main.shake_on, "voltar ao menu (tremor religado)")

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
	for i in 60 * 45:
		await frames(1)
		if main.state != S.RUN:
			won = main.demo.round_winner == 1
			break
	check(won, "bot difícil derruba um jogador parado em até 45 s")
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
	main.demo.t = 6.0
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
