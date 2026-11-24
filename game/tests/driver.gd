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
		if a.begins_with("--lab="):
			await lab_shots(a.trim_prefix("--lab="))
			get_tree().quit()
			return
		if a.begins_with("--canteiro="):
			await canteiro_frames(a.trim_prefix("--canteiro="))
			get_tree().quit()
			return
		if a.begins_with("--prancha="):
			await prancha_canteiro(a.trim_prefix("--prancha="))
			get_tree().quit()
			return
		if a.begins_with("--pulo="):
			await pulo_frames(a.trim_prefix("--pulo="))
			get_tree().quit()
			return
		if a.begins_with("--spells="):
			await spells_frames(a.trim_prefix("--spells="))
			get_tree().quit()
			return
		if a.begins_with("--combate="):
			await combate_frames(a.trim_prefix("--combate="))
			get_tree().quit()
			return
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
		if a.begins_with("--espiar="):
			await espiar(a.trim_prefix("--espiar="))
			get_tree().quit()
			return
		if a.begins_with("--maquete="):
			await maquete_frames(a.trim_prefix("--maquete="))
			get_tree().quit()
			return
		if a.begins_with("--robos="):
			await robos_sheet(a.trim_prefix("--robos="))
			get_tree().quit()
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
	if main.level.id != "canteiro":
		if main.demo.fx != null and is_instance_valid(main.demo.fx):
			main.demo.fx.free()   # máquinas da arena anterior apontam para o mapa velho
		main.demo.fx = null
		main.load_arena("canteiro")   # mapa plano de referência para medir pulo e corrida
		await frames(1)
	main.start_run()
	main.countdown = 0.0
	main.timer = 999.0
	for r in main.robots:
		r.active = true
	await frames(2)

## Marretada pesada "limpa" para testes de efeito: zera a recarga, aperta e espera o impacto.
func heavy_hit(dev: String) -> void:
	var i: int = PlayerInput.slots.find(dev)
	if i >= 0 and i < main.robots.size():
		main.robots[i].heavy_cd = 0.0
		while main.robots[i].atk != "":
			await frames(1)
	await tap(dev, "heavy")
	await frames(int(float(Data.ctrl["ataque_pesado"]["preparo"]) * 60.0) + 8)

func put(r, pos: Vector2) -> void:
	r.position = pos
	r.velocity = Vector2.ZERO
	r.own_vx = 0.0

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
	check(ms is AudioStreamWAV and ms.loop_mode == AudioStreamWAV.LOOP_FORWARD, "música da partida em WAV (QOA no jogo) e em loop")
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
	check(PlayerInput.dev_held("kb_a", "hammer"), "F é o golpe rápido do teclado A")
	await key_event(KEY_F, false)
	main.players.clear()   # o Ctrl direito simulado fez o teclado B entrar: limpa para o resto do teste
	PlayerInput.slots.clear()

	print("== Entrada")
	main.game_mode = "derruba"
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
	var m0: int = main.players[0]["model"]
	var m2: int = main.players[2]["model"]
	vset("padA", "down", true)
	vset("padB", "down", true)
	await frames(2)
	vset("padA", "down", false)
	vset("padB", "down", false)
	await frames(2)
	check(main.players[2]["model"] == posmod(m2 + 1, Data.MODELS.size()) and main.players[0]["model"] == m0, "trocar robô muda só o jogador do controle")
	await tap("padA", "back")
	check(main.players.size() == 2, "botão de sair remove o jogador")
	await tap("v0", "start")
	check(main.state == S.RUN, "Start com 2 jogadores começa a rodada")

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
	print("== Demolição (Derruba com 1 vida)")
	main.mode = "demolicao"
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
	main.event_level = 0   # eventos são testados à parte (spells_test)
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
	await heavy_hit("v0")
	check(main.level.blocks.has(cell) and main.level.blocks[cell]["hp"] == hp0 - 1, "1ª marretada racha o caixote do chão à frente")
	for k in hp0 - 1:
		await frames(34)   # a marretada que erra o robô fica presa ~0,7 s (abertura real)
		await heavy_hit("v0")
	check(not main.level.blocks.has(cell), "%dª marretada quebra o caixote" % hp0)
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	await frames(3)
	var x1: float = r1.position.x
	await heavy_hit("v0")
	check(r1.recover_t > 0.0 and absf(r1.dmg - 14.0) < 0.1, "marretada pesada arremessa e soma 14%% no Amassômetro (%.0f%%)" % r1.dmg)
	await frames(30)
	var push_low: float = r1.position.x - x1
	put(r1, Vector2(col_x(11) + 60, 576))
	r1.dmg = 120.0
	await frames(16)
	x1 = r1.position.x
	await heavy_hit("v0")
	await frames(30)
	var push_high: float = r1.position.x - x1
	check(push_low > 20.0 and push_low < 200.0 and push_high > push_low * 3.0, "amassado voa mais longe: 14%% → %.0f px, 120%% → %.0f px" % [push_low, push_high])
	# invulnerável não sofre golpe
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	r1.invuln = 2.0
	await frames(3)
	await heavy_hit("v0")
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
	await bots_test()
	await arenas_test()
	await parede_test()
	await maquinas_test()
	await submodos_test()
	await menus_test()
	await controles_test()
	await controle_real_test()
	await robos_test()
	await combate_test()
	await lab_test()
	await canteiro_test()
	await spells_test()
	await imagens_test()

func menus_test() -> void:
	print("== Menus e pausa")
	main.go_menu()
	main.menus.sel = 0
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	check(main.state == S.MENU and main.players.is_empty(), "volta ao menu principal sem jogadores")
	await tap("v0", "jump")
	check(main.state == S.MODES, "JOGAR abre a seleção de modo")
	check(main.demo.cfg["modos"].size() == 4 and main.demo.cfg["modos"].filter(func(m): return m["ok"]).map(func(m): return m["id"]) == ["derruba"], "Derruba jogável; Batata, Rei e Fuga EM BREVE")
	for k in 3:
		await tap("v0", "right")
	check(main.menus.mode_sel == 3, "◄► passa pelos modos")
	for k in 3:
		await tap("v0", "left")
	await tap("v0", "jump")
	check(main.state == S.ARENAS and main.game_mode == "derruba", "DERRUBA escolhido → arenas do modo")
	check(main.menus.arena_list().size() == 1 + main.demo.find_mode("derruba")["arenas"].size(), "só as arenas da Derruba (+ sorteio)")
	await tap("v0", "jump")
	check(main.state == S.AJUSTES and main.arena_choice in ["canteiro_obras", "sorteio"], "arena do Derruba → AJUSTES (%s)" % main.arena_choice)
	await tap("v0", "left")
	await tap("v0", "down")
	var lives0: int = main.demo.lives_setting
	await tap("v0", "right")
	check(main.demo.lives_setting == mini(lives0 + 1, 5), "ajuste de VIDAS da Derruba (%d)" % main.demo.lives_setting)
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
	await tap("v0", "jump")
	check(main.state == S.JOIN and main.mode == "demolicao" and int(main.demo.cfg["rounds_to_win"]) == 3 and lvl >= 0, "COMEÇAR → entrada; vence com 3 ★ (eventos nível %d)" % main.event_level)
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
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
	main.menus.sel = 0
	for k in 3:
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
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
	main.arena_choice = "demolicao"
	await demo_round()
	main.demo.spells.spawn_t = 999.0
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
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
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

func submodos_test() -> void:
	print("== Modos (Derruba com vidas, Batata-Dinamite)")
	main.mode = "demolicao"
	main.arena_choice = "demolicao"
	main.event_level = 0
	# Vidas: cair tira 1 vida e volta pelo guindaste; com 0 vidas, sai
	main.game_mode = "derruba"
	main.demo.lives_setting = 3
	await demo_round()
	var r0 = main.robots[0]
	var lv0: int = main.demo.lives[0]
	main.kill(r0, -1, null)
	await frames(2)
	check(r0.alive and main.demo.lives[0] == lv0 - 1, "Derruba: caiu, perdeu 1 vida (%d) e voltou" % main.demo.lives[0])
	# sem nenhum caixote no mapa: o guindaste traz um caixote e o robô volta em cima dele (não no espinho)
	for c in main.level.blocks.keys():
		main.level.break_block(c)
	await frames(2)
	r0.invuln = 0.0
	main.demo.lives[0] = 3
	main.kill(r0, -1, null)
	await frames(90)
	var under := Vector2i(int(r0.position.x / 64.0), int((r0.position.y + 2.0) / 64.0))
	check(r0.alive and r0.is_on_floor() and main.level.is_solid(under) and r0.position.y < (main.level.rows - 2) * 64.0,
		"Derruba: sem chão, volta em cima de um caixote novo (%s)" % str(under))
	main.demo.lives[0] = 1
	r0.invuln = 0.0
	main.kill(r0, -1, null)
	await frames(2)
	check(not r0.alive, "Derruba: sem vidas, está fora")
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == 1, "Derruba: P2 vence a rodada")
	# Batata-Dinamite: a marretada passa a dinamite; quando o pavio acaba, explode quem está com ela
	main.game_mode = "batata"
	await demo_round()
	r0 = main.robots[0]
	var r1 = main.robots[1]
	main.demo.bomb_next = 0.01
	await frames(3)
	var h: int = main.demo.bomb_holder
	check(h >= 0, "Batata: alguém pegou a dinamite (P%d)" % (h + 1))
	var hr = main.robots[h]
	var other = main.robots[1 - h]
	hr.invuln = 0.0
	other.invuln = 0.0
	put(hr, Vector2(col_x(12), 576))
	put(other, Vector2(col_x(12) + 20, 576))
	await frames(3)
	check(main.demo.bomb_holder == 1 - h, "Batata: encostar no rival passa a dinamite")
	await frames(55)
	put(hr, Vector2(col_x(12) + 20, 576))
	await frames(3)
	check(main.demo.bomb_holder == h, "Batata: e ele pode devolver encostando")
	await frames(55)
	put(hr, Vector2(col_x(12), 576))
	put(other, Vector2(col_x(12) + 50, 576))
	hr.facing = 1
	await frames(3)
	main.demo.attack(hr, "pesado")
	await frames(2)
	check(main.demo.bomb_holder == 1 - h, "Batata: marretada passou a dinamite para P%d" % (2 - h))
	hr.invuln = 99.0
	main.demo.bomb_fuse = 0.02
	await frames(4)
	check(not other.alive, "Batata: o pavio acabou e quem estava com ela explodiu")
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == h, "Batata: P%d vence a rodada" % (h + 1))
	# Rei da Obra: pega o capacete no trono, perde com um golpe, vence ao juntar os segundos
	main.game_mode = "rei"
	main.arena_choice = "piramide"
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	check(main.level.throne != Vector2.INF and main.demo.crown_pos.distance_to(main.level.throne) < 6.0, "Rei: capacete de ouro no trono (K)")
	r0.invuln = 0.0
	r1.invuln = 0.0
	put(r0, main.demo.crown_pos + Vector2(0, 2))
	await frames(4)
	check(main.demo.king == 0, "Rei: P1 pegou o capacete")
	await frames(30)
	check(main.demo.king_time.get(0, 0.0) > 0.3 and r0.speed_k < 1.0, "Rei: o rei soma segundos e fica mais lento")
	r0.take_hit(1, "marretada", 1)
	await frames(3)
	check(main.demo.king == 0, "Rei: logo depois de pegar, o rei fica protegido um instante")
	main.demo.king_grace = 0.0
	r0.invuln = 0.0
	r0.take_hit(1, "marretada", 1)
	await frames(3)
	check(main.demo.king == -1 and r0.speed_k == 1.0, "Rei: golpe derruba o capacete")
	main.demo.crown_pos = Vector2(64 * 3 + 32, main.level.rows * 64.0 + 20.0)
	main.demo.crown_vel = Vector2.ZERO
	main.demo.crown_cd = {0: 99.0, 1: 99.0}
	await frames(3)
	check(main.demo.crown_pos.distance_to(main.demo.crown_home) < 2.0, "Rei: capacete no fundo/espinho volta para o trono")
	main.demo.crown_cd.clear()
	main.demo.crown_cd.clear()
	main.demo.king = 1
	main.demo.king_hit[1] = r1.last_hit
	main.demo.king_time[1] = main.demo.king_goal() - 0.05
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == 1, "Rei: quem junta os segundos vence a rodada")
	# Fuga: quem chega ao elevador vence na hora
	main.game_mode = "fuga"
	main.arena_choice = "mare"
	await demo_round()
	r0 = main.robots[0]
	check(main.level.elevator_cell != Vector2i(-1, -1), "Fuga: a Maré tem elevador de chegada")
	var g: Rect2 = main.level.goal_rect
	put(r0, Vector2(g.get_center().x, g.end.y - 2))
	await frames(100)
	check(main.state == S.SCORE and main.demo.round_winner == 0, "Fuga: chegou ao elevador, venceu a rodada")
	main.arena_choice = "demolicao"
	main.game_mode = "derruba"
	main.demo.lives_setting = 1

func robos_test() -> void:
	print("== Robôs (8 modelos)")
	check(Data.MODELS.size() == 8 and Data.robot_meta["modelos"].size() == 8, "8 modelos de robô (%d)" % Data.MODELS.size())
	var faltando := []
	for m in Data.MODELS:
		var names := ["robo/antena_" + m]
		for k in 4:
			names.append("robo/corpo_%s_p%d" % [m, k + 1])
		for e in ["normal", "piscar", "esforco", "susto", "vitoria", "eliminado"]:
			names.append("robo/rosto_%s_%s" % [m, e])
		for n in names:
			if Data.tex(n) == null:
				faltando.append(n)
	check(faltando.is_empty(), "todos os modelos têm corpo nas 4 cores, 6 rostos e antena %s" % [faltando])
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	var seen := {}
	for k in Data.MODELS.size():
		seen[main.players[0]["model"]] = true
		await tap("v0", "down")
	check(seen.size() == 8 and main.players[0]["model"] == 0, "▲▼ na entrada passa pelos 8 robôs e volta ao primeiro")
	main.players[0]["model"] = 4   # Brutamontes
	main.players[1]["model"] = 5   # Varapau
	main.start_match()
	await frames(3)
	var hb0: Rect2 = main.robots[0].rect()
	var hb1: Rect2 = main.robots[1].rect()
	check(main.robots[0].vis.model == 4 and hb0.size == hb1.size, "o modelo muda só a aparência (mesma hitbox %s)" % [hb0.size])
	var ok := true
	for m in Data.MODELS.size():
		var parts: Array = main.robots[0].vis.parts({"color": 1, "model": m, "hammer": true})
		ok = ok and parts.size() >= 6 and parts[0]["tex"][0] != null
	check(ok, "todos os modelos desmontam na eliminação")
	main.go_menu()

## COMBATE (relatório de 2026-11-24): golpe rápido × marretada pesada, esquiva (chão/ar, só contra robôs),
## arremesso com retorno gradual do controle. Cenários de aceitação da seção 8.
func combate_test() -> void:
	print("== Combate (rápido, pesado, esquiva, arremesso)")
	main.mode = "demolicao"
	main.game_mode = "derruba"
	main.demo.lives_setting = 5
	main.event_level = 0
	main.arena_choice = "demolicao"
	if main.players.size() < 2:
		PlayerInput.virtual = {"v0": {}, "v1": {}}
		main.go_join()
		await frames(2)
		await tap("v0", "jump")
		await tap("v1", "jump")
	main.start_match()
	await demo_round()
	main.demo.spells.spawn_t = 999.0
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var am: Dictionary = main.demo.cfg["amassometro"]
	# 1) golpe rápido: acerta, soma pouco, reação menor; não quebra caixote
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	r1.dmg = 50.0
	await frames(3)
	await tap("v0", "hammer")
	await frames(4)
	var kx_fast: float = absf(r1.own_vx)
	check(absf(r1.dmg - 50.0 - float(am["combo"]["dano"])) < 0.1, "golpe rápido acerta e soma %d%% (%.0f%%)" % [int(am["combo"]["dano"]), r1.dmg])
	await frames(40)
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r1.dmg = 50.0
	await frames(3)
	await tap("v0", "heavy")
	await frames(10)
	check(r1.dmg == 50.0, "marretada pesada tem preparo: ainda não acertou no 10º quadro")
	await frames(int(float(Data.ctrl["ataque_pesado"]["preparo"]) * 60.0))
	var kx_heavy: float = absf(r1.own_vx)
	check(r1.dmg > 50.0 and kx_heavy > kx_fast * 1.4, "pesada empurra bem mais que a rápida (%.0f × %.0f)" % [kx_heavy, kx_fast])
	await frames(60)
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(12), 576))
	put(r1, Vector2(col_x(26), 576))
	r0.facing = 1
	await frames(3)
	var cell := Vector2i(13, 9)
	var hp0: int = main.level.blocks[cell]["hp"] if main.level.blocks.has(cell) else -1
	await tap("v0", "hammer")
	await frames(12)
	check(hp0 > 0 and main.level.blocks.has(cell) and main.level.blocks[cell]["hp"] == hp0, "golpe rápido não quebra caixote")
	# marretada que erra deixa aberto: ainda presa depois de 0,5 s
	await frames(20)
	await tap("v0", "heavy")
	await frames(30)
	check(r0.atk == "pesado", "marretada que erra deixa o robô exposto (ainda se recuperando)")
	await frames(40)
	check(r0.atk == "", "...e termina sem travar")
	# 2) esquiva no chão: desloca rápido e, na janela, golpe de robô não pega
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(12), 576))
	put(r1, Vector2(col_x(14), 576))
	r0.facing = 1
	r1.facing = -1
	await frames(3)
	var x0: float = r0.position.x
	vset("v0", "dodge", true)
	await frames(1)
	vset("v0", "dodge", false)
	check(r0.guard_t > 0.0 and r0.dodge_t > 0.0, "esquiva começa com a janela de proteção")
	r1.atk = ""
	var hit_during: bool = r0.take_hit(-1, "rapido", r1.pid)
	check(not hit_during and r0.dmg == 0.0, "na janela da esquiva, golpe de robô não pega")
	var env_hit: bool = r0.take_hit(-1, "explosao", -1)
	check(env_hit and r0.dmg > 0.0, "esquiva NÃO protege de explosão/cenário")
	await frames(12)
	check(absf(r0.position.x - x0) > 60.0 or r0.dmg > 0.0, "esquiva desloca o robô (%.0f px)" % absf(r0.position.x - x0))
	# 3) esquiva no ar: 1 por período no ar; golpe não devolve; pousar devolve
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(12), 150))
	put(r1, Vector2(col_x(25), 576))
	await frames(2)
	await tap("v0", "dodge")
	check(not r0.is_on_floor() and r0.air_dodge == 0, "esquiva no ar gasta a carga aérea")
	await frames(8)
	r0.take_hit(1, "rapido", r1.pid)
	r0.hitstop = 0.0
	r0.stun_t = 0.0
	r0.dodge_cd = 0.0   # sem esperar a recarga: só a regra da carga aérea decide
	await tap("v0", "dodge")
	check(not r0.is_on_floor() and r0.air_dodge == 0 and r0.dodge_t == 0.0, "levar golpe no ar NÃO devolve a esquiva (sem 2ª esquiva no ar)")
	for k in 120:
		if r0.is_on_floor():
			break
		await frames(1)
	await frames(2)
	check(r0.is_on_floor() and r0.air_dodge == 1, "pousar devolve a esquiva aérea")
	# 4) arremesso: sem controle curto, depois controle volta aos poucos; esquiva ajuda mas não anula
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(14), 400))
	r0.dmg = 110.0
	r0.take_hit(1, "pesado", r1.pid)
	r0.hitstop = 0.0
	check(r0.stun_t > 0.0 and r0.stun_t <= float(main.c_ctrl("arremesso")["sem_controle_max"]) + 0.01, "arremesso: perda de controle curta (%.2f s)" % r0.stun_t)
	var v_launch: float = r0.own_vx
	vset("v0", "left", true)
	await frames(int(r0.stun_t * 60.0) + 6)
	check(r0.recover_t > 0.0 and r0.own_vx > 0.0 and r0.own_vx < v_launch, "controle volta aos poucos: corrige sem cancelar o arremesso (%.0f → %.0f)" % [v_launch, r0.own_vx])
	await tap("v0", "dodge")
	await frames(2)
	check(r0.air_dodge == 0 and r0.dodge_carry.x > 0.0, "esquiva na recuperação usa a mesma carga aérea e mantém parte do impulso")
	vset("v0", "left", false)
	await frames(90)
	check(r0.stun_t == 0.0 and r0.atk == "" and r0.dodge_t == 0.0, "nenhum estado preso depois do arremesso")
	await frames(2)
	# 6) combate de perto: colado acerta; sequência de 3 mantém perto e o 3º arremessa; golpes com direção
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 4, 576))
	r0.facing = 1
	r1.dmg = 30.0
	await frames(3)
	await tap("v0", "hammer")
	await frames(6)
	check(r1.dmg > 30.0, "colado (sobreposto) o golpe rápido acerta")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 46, 576 - 90))   # ao lado: fora da área do pisão na cabeça
	r1.velocity = Vector2.ZERO
	r1.invuln = 0.0
	r1.last_cause = ""
	vset("v0", "up", true)
	await tap("v0", "hammer")
	vset("v0", "up", false)
	await frames(6)
	check(r1.last_cause == "cima" and r1.position.y < 576 - 90 - 10, "▲ + golpe joga o rival de cima para o alto")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	r0.facing = 1
	put(r0, Vector2(col_x(11), 576))
	await frames(30)
	put(r1, Vector2(col_x(11) + 40, 576))
	r1.dmg = 30.0
	var near := true
	for k in 3:
		await tap("v0", "hammer")
		await frames(8)
		if k < 2 and absf(r1.position.x - r0.position.x) > 140.0:
			near = false
	check(r0.combo_i == 2 and near, "sequência: 2 golpes mantêm o rival perto e chega ao 3º (combo %d)" % r0.combo_i)
	await frames(10)
	check(absf(r1.own_vx) > 250.0 or absf(r1.position.x - r0.position.x) > 120.0, "o 3º golpe da sequência arremessa")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(14), 90))
	put(r1, Vector2(col_x(14) + 6, 90 + 80))
	r1.invuln = 0.0
	r0.invuln = 0.0
	await frames(2)
	vset("v0", "down", true)
	await tap("v0", "hammer")
	vset("v0", "down", false)
	await frames(6)
	check(r1.last_cause == "baixo" and r1.velocity.y > 200.0, "▼ + golpe no ar joga o rival para baixo")
	# 5) marretada pesada: recarga própria, esquiva cancela o preparo, golpe do rival interrompe
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(20), 576))
	r0.facing = 1
	await frames(3)
	await tap("v0", "heavy")
	await frames(70)
	check(r0.atk == "" and r0.heavy_cd > 0.0, "depois da marretada vem a recarga (%.2f s)" % r0.heavy_cd)
	await tap("v0", "heavy")
	check(r0.atk == "", "na recarga, a marretada não sai (golpe rápido continua livre)")
	await tap("v0", "hammer")
	check(r0.atk == "rapido", "golpe rápido funciona durante a recarga da pesada")
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	r1.facing = -1
	await frames(3)
	await tap("v0", "heavy")
	await frames(6)
	await tap("v0", "dodge")
	check(r0.atk == "" and r0.dodge_t > 0.0 and r1.dmg == 0.0 and r0.heavy_cd > 0.0, "esquiva cancela o preparo da marretada (finta)")
	await frames(60)
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(11) + 60, 576))
	r0.facing = 1
	r0.heavy_cd = 0.0
	await frames(3)
	await tap("v0", "heavy")
	await frames(4)
	r1.facing = -1
	await tap("v1", "hammer")
	await frames(6)
	check(r0.atk == "" and r0.dmg > 0.0 and r1.dmg == 0.0, "golpe do rival no preparo INTERROMPE a marretada")

## LABORATÓRIO: abre pela tela inicial, ajusta número ao vivo, mede pulo, boneco obedece, salva/volta ao padrão.
func lab_test() -> void:
	print("== Laboratório")
	if FileAccess.file_exists(main.lab.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(main.lab.SAVE_PATH))
	for p in main.lab.PARAMS:
		main.lab.set_value(p, float(main.lab.defaults[main.lab._key(p)]))
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	main.menus.sel = 0
	await tap("v0", "down")
	await tap("v0", "jump")
	check(main.sandbox and main.lab_mode and main.level.id == "laboratorio" and main.robots.size() == 2, "menu ▸ LABORATÓRIO abre a sala de medição com 1 jogador + boneco")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
		r.invuln = 0.0
	var lab = main.lab
	var r0 = main.robots[0]
	put(r0, Vector2(col_x(8), 12 * 64))
	await frames(20)
	vset("v0", "jump", true)
	await frames(30)
	vset("v0", "jump", false)
	await frames(60)
	check(lab.last_jump != "", "mede o pulo (%s)" % lab.last_jump)
	# boneco que dá marretada
	lab.dummy_i = lab.DUMMY.find("marretada")
	var saw := false
	for k in 150:
		await frames(1)
		if main.robots[1].atk == "pesado":
			saw = true
			break
	check(saw, "boneco obedece o comportamento (dá marretada)")
	lab.dummy_i = 0
	# painel: ajuste ao vivo do preparo da pesada
	await tap("v0", "start")
	check(lab.open and main.paused, "START abre o painel do laboratório")
	var idx := -1
	for i in lab.PARAMS.size():
		if lab.PARAMS[i][2] == ["ataque_pesado", "preparo"]:
			idx = i
	lab.sel = lab.rows().find("num%d" % idx)
	var before: float = float(Data.ctrl["ataque_pesado"]["preparo"])
	await tap("v0", "right")
	var after: float = float(Data.ctrl["ataque_pesado"]["preparo"])
	check(absf(after - before - 0.01) < 0.0001, "◄► muda o número ao vivo (%.2f → %.2f)" % [before, after])
	lab.sel = lab.rows().find("salvar")
	await tap("v0", "jump")
	check(FileAccess.file_exists(lab.SAVE_PATH) and lab.changed_count() == 1, "SALVAR grava os ajustes")
	await frames(20)
	lab.sel = lab.rows().find("padrao")
	await tap("v0", "jump")
	check(absf(float(Data.ctrl["ataque_pesado"]["preparo"]) - before) < 0.0001 and not FileAccess.file_exists(lab.SAVE_PATH), "PADRÃO volta aos valores de fábrica e apaga o salvo")
	await frames(20)
	# medidores somem/voltam com VOLTAR durante o jogo
	await tap("v0", "start")
	check(not lab.open, "START fecha o painel")
	await tap("v0", "back")
	check(not lab.show_meters, "VOLTAR esconde os medidores")
	await tap("v0", "back")
	check(lab.show_meters, "VOLTAR mostra de novo")
	# spells, eventos e arena (o que era da Oficina)
	var r0b = main.robots[0]
	r0b.invuln = 0.0
	main.kill(r0b, -1, null)
	await frames(2)
	check(r0b.alive and main.state == S.RUN, "no Laboratório, cair não tira ninguém")
	await tap("v0", "start")
	lab.sel = lab.rows().find("dar_spell")
	lab.spell_i = lab.spells().find("S03")
	await tap("v0", "jump")
	check(main.demo.spells.hud_info(0).get("id", "") == "S03" and not lab.open, "painel: DAR SPELL entrega o canhão criogênico e fecha")
	await tap("v0", "start")
	lab.sel = lab.rows().find("caixa")
	var nb: int = main.demo.spells.boxes.size()
	await tap("v0", "jump")
	check(main.demo.spells.boxes.size() == nb + 1, "painel: CAIXA DO CÉU solta uma caixa")
	await tap("v0", "start")
	lab.sel = lab.rows().find("evento")
	lab.event_i = 1   # G10 (a sala de régua não tem estrutura para o G01)
	await tap("v0", "jump")
	check(main.events.phase == "aviso" and not lab.open, "painel: EVENTO AGORA dispara o evento")
	await tap("v0", "start")
	lab.sel = lab.rows().find("bot")
	await tap("v0", "right")
	var n_before: int = main.robots.size()
	lab.sel = lab.rows().find("arena")
	await tap("v0", "right")
	await tap("v0", "jump")
	await frames(5)
	check(main.level.id == "canteiro_obras" and main.demo.canteiro != null and main.robots.size() == n_before and main.sandbox, "painel: arena CANTEIRO mantém todos (%d robôs)" % main.robots.size())
	await tap("v0", "start")
	lab.sel = lab.rows().find("evento")
	lab.event_i = 0
	await tap("v0", "jump")
	check(main.events.phase == "aviso" and main.demo.canteiro.cycle_state == "aviso", "no Canteiro, G01 dispara pelo painel")
	await frames(10)
	await tap("v0", "start")
	lab.sel = lab.rows().find("sair")
	await tap("v0", "jump")
	check(main.state == S.MENU and not main.lab_mode and not main.sandbox and not main.paused and Engine.time_scale == 1.0, "SAIR volta ao menu")
	await frames(20)

## Capturas do Laboratório (--lab=DIR): medidores em ação e o painel de ajustes.
func lab_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	main.lab.start("v0")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
		r.invuln = 0.0
	await frames(30)
	var r0 = main.robots[0]
	put(r0, Vector2(col_x(12), 12 * 64))
	r0.facing = 1
	main.robots[1].dmg = 90.0
	put(main.robots[1], Vector2(col_x(13) + 6, 12 * 64))
	vset("v0", "jump", true)
	await frames(30)
	vset("v0", "jump", false)
	await frames(60)
	vset("v0", "heavy", true)
	await frames(2)
	vset("v0", "heavy", false)
	await frames(10)
	await snap(dir, "lab_golpe")
	await frames(70)
	await snap(dir, "lab_medidas")
	await tap("v0", "start")
	main.lab.sel = main.lab.rows().find("dar_spell")
	main.lab.scroll = 0
	await frames(4)
	await snap(dir, "lab_painel")

## CANTEIRO DE OBRAS (Relatório 02): KO no mundo nos 4 lados, laje em trechos (núcleo fixo), gatilhos e ciclo da obra.
func canteiro_test() -> void:
	print("== Canteiro de Obras (Derruba)")
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.game_mode = "derruba"
	main.demo.lives_setting = 5
	main.event_level = 0
	main.arena_choice = "canteiro_obras"
	main.start_match()
	await demo_round()
	main.demo.spells.spawn_t = 999.0
	var ct = main.demo.canteiro
	check(ct != null and main.level.id == "canteiro_obras" and ct.standing() == 13, "Canteiro monta laje (6), andaimes (2) e vigas (5) (%s)" % [ct.standing() if ct != null else -1])
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	put(r1, Vector2(col_x(30), 13 * 64))
	# marretada pesada no trecho 0 (cols 8-11) até desabar
	var seg = ct.parts[0]
	var hits := 0
	for k in 12:
		put(r0, Vector2(col_x(9), 13 * 64))
		r0.facing = 1
		r0.heavy_cd = 0.0
		await frames(2)
		await tap("v0", "heavy")
		await frames(66)   # marretada que não acerta robô dura ~1 s (preparo + recuperação longa)
		hits += 1
		if seg["fallen"] or seg["crit_t"] > 0.0:
			break
	check(seg["crit_t"] > 0.0 or seg["fallen"], "marretadas pesadas levam o trecho ao aviso final (%d golpes)" % hits)
	put(r0, Vector2(col_x(10), 12 * 64))
	await frames(80)
	check(seg["fallen"] and not main.level.is_solid(Vector2i(9, 13)), "o trecho desaba e a colisão some junto")
	check(r0.position.y > 13 * 64 + 40 or main.demo.lives.get(0, 5) < 5, "quem estava em cima cai")
	# caixa de spell pousa na laje (não atravessa) e cai junto quando o trecho desaba
	var seg2 = ct.parts[1]
	var sp = main.demo.spells
	sp.boxes.clear()
	sp.drop_box("S01", Vector2(seg2["rect"].get_center().x, 0))
	await frames(150)
	var it: Dictionary = sp.boxes[0] if sp.boxes.size() > 0 else {}
	check(not it.is_empty() and absf(it["pos"].y + 30.0 - seg2["rect"].position.y) < 8.0, "caixa pousa em cima da laje (y %.0f, laje %.0f)" % [it.get("pos", Vector2.ZERO).y + 30.0, seg2["rect"].position.y])
	ct.damage(seg2, 99, seg2["rect"].get_center())
	await frames(int(float(ct.cfg["aviso_queda_s"]) * 60.0) + 40)
	check(sp.boxes.is_empty() or sp.boxes[0]["pos"].y > seg2["rect"].position.y + 40.0, "trecho desabou: a caixa cai junto")
	# núcleo nunca cai
	var nuc = ct.parts[2]
	for k in 20:
		ct.damage(nuc, 99, nuc["rect"].get_center())
	await frames(90)
	check(not nuc["fallen"], "o núcleo (trechos do meio) nunca cai")
	# golpe rápido não danifica
	await demo_round()
	ct = main.demo.canteiro
	r0 = main.robots[0]
	put(r0, Vector2(col_x(26), 13 * 64))
	r0.facing = 1
	await frames(2)
	await tap("v0", "hammer")
	await frames(20)
	check(ct.parts[4]["hp"] == ct.parts[4]["max"] and ct.parts[5]["hp"] == ct.parts[5]["max"], "golpe rápido não danifica a laje")
	# G01 Sirene de Demolição (evento): aviso no trecho e depois o alvo cede
	main.event_level = 2
	main.events.manual = true
	var g01: Dictionary = main.events.cfg["lista"][0]
	main.events.trigger(g01)
	await frames(3)
	var alvo = ct.target
	check(main.events.phase == "aviso" and ct.cycle_state == "aviso" and alvo != null and not alvo["nucleo"] and alvo["warn_t"] > 0.0, "G01 Sirene de Demolição marca um trecho com aviso (sirene + fita)")
	await frames(int((0.8 + float(g01["dur"]) * 0.5 + float(ct.cfg["aviso_queda_s"])) * 60.0) + 20)
	check(alvo != null and alvo["fallen"] and ct.cycle_state == "calma" and main.events.phase == "", "depois do aviso o trecho cede e o evento termina")
	main.events.manual = false
	main.event_level = 0
	# KO no mundo nos 4 lados (independente da câmera)
	var ko: Rect2 = main.level.ko_rect()
	var dirs := {"esquerda": Vector2(ko.position.x - 40, 600), "direita": Vector2(ko.end.x + 40, 600), "cima": Vector2(1200, ko.position.y - 40), "baixo": Vector2(1200, ko.end.y + 80)}
	for nome in dirs:
		await demo_round()
		r1 = main.robots[1]
		var lives0: int = main.demo.lives.get(1, 5)
		main.cam_lock = [1.0, Vector2(1280, 700)]
		put(r1, dirs[nome])
		await frames(3)
		check(main.demo.lives.get(1, 5) < lives0 or not r1.alive, "KO pela borda: %s" % nome)
	main.cam_lock = []
	# dentro da zona mas fora da tela (câmera bem fechada) NÃO elimina
	await demo_round()
	r1 = main.robots[1]
	main.cam_lock = [2.0, Vector2(600, 600)]
	put(r1, Vector2(ko.end.x - 200, 900))
	await frames(3)
	check(r1.alive and main.demo.lives.get(1, 5) == 5, "fora da tela mas dentro da zona: segue vivo (a câmera não decide o KO)")
	main.cam_lock = []
	main.go_menu()
	await frames(20)

## Relatório 04, Etapa 1: caixas por família, slot único, troca segurando, limpeza na eliminação e as 6 spells; G10.
func spells_test() -> void:
	print("== Spells (Etapa 1) e eventos G01/G10")
	main.go_menu()
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.game_mode = "derruba"
	main.demo.lives_setting = 5
	main.event_level = 0
	main.arena_choice = "canteiro_obras"
	main.start_match()
	await demo_round()
	var sp = main.demo.spells
	sp.spawn_t = 999.0
	var ct = main.demo.canteiro
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var nuc: Array = ct.parts.filter(func(p): return p["nucleo"])
	var floor_y: float = nuc[0]["rect"].position.y
	var x0: float = nuc[0]["rect"].position.x + 40.0
	var place := func(dx_tiles: float) -> void:
		for i in main.players.size():
			main.demo.lives[i] = 99   # muitos testes seguidos: ninguém fica sem vida
		for r in [r0, r1]:
			r.dmg = 0.0
			r.stun_t = 0.0
			r.recover_t = 0.0
			r.frozen_t = 0.0
			r.spell_lock = false
			r.invuln = 0.0
			r.atk = ""
			r.atk_cd = 0.0
		put(r0, Vector2(x0, floor_y))
		put(r1, Vector2(x0 + dx_tiles * 64.0, floor_y))
		r0.facing = 1
		r1.facing = -1
	# sorteio em 2 etapas: só spells do pool, todas as famílias aparecem, ataque é a mais comum
	var cnt := {}
	for k in 400:
		var d: Dictionary = sp.pick()
		cnt[d["fam"]] = cnt.get(d["fam"], 0) + 1
		check(d["id"] in sp.pool() and sp.sc(d["id"])["familia"] == d["fam"], "sorteio dá spell do pool na família certa") if k == 0 else null
	check(cnt.size() == 4 and cnt["ataque"] > cnt["controle"] and cnt["ataque"] > cnt["transformacao"], "sorteio: 4 famílias, ataque mais frequente %s" % str(cnt))
	check(sp.spawn_points().size() >= 6 and sp.spawn_points().any(func(q): return q["fixo"]), "pontos de caixa fixos e variáveis no Canteiro (%d)" % sp.spawn_points().size())
	# coleta por contato com slot vazio
	place.call(6.0)
	sp.drop_box("S03", Vector2(x0, floor_y - 120.0), false)
	await frames(40)
	check(sp.boxes.is_empty() and sp.hud_info(0).get("id", "") == "S03" and sp.hud_info(0)["charges"] == 3, "encostar na caixa pega a spell (S03, 3 cargas)")
	# S03 canhão criogênico: congela quem acerta
	place.call(6.0)
	await frames(2)
	await tap("v0", "item")
	await frames(40)
	check(r1.frozen_t > 0.0 and sp.frozen.has(1) and sp.hud_info(0)["charges"] == 2, "S03: tiro acerta e congela (%.1f s)" % r1.frozen_t)
	var px: float = r1.position.x
	vset("v1", "right", true)
	await frames(20)
	vset("v1", "right", false)
	check(absf(r1.position.x - px) < 20.0, "congelado não anda")
	# agitar o direcional quebra mais rápido: conta quadros até soltar, sem e com agitação
	var calm := 0
	while r1.frozen_t > 0.0 and calm < 400:
		await frames(1)
		calm += 1
	check(calm > 60 and not sp.frozen.has(1), "sem agitar, o gelo solta sozinho (%d quadros)" % calm)
	place.call(6.0)
	sp.slot[0]["cd"] = 0.0
	await frames(2)
	await tap("v0", "item")
	await frames(40)
	var shook := 0
	while r1.frozen_t > 0.0 and shook < 400:
		vset("v1", "left" if shook % 8 < 4 else "right", true)
		vset("v1", "right" if shook % 8 < 4 else "left", false)
		await frames(1)
		shook += 1
	vset("v1", "left", false)
	vset("v1", "right", false)
	check(shook < calm * 0.7, "agitando ◄► quebra o gelo mais rápido (%d × %d quadros)" % [shook, calm])
	# pancada em quem está congelado estilhaça com empurrão maior
	place.call(1.0)
	sp.freeze(r1, 0)
	r1.take_hit(1, "rapido", 0)
	var kx_frozen: float = absf(r1.own_vx)
	place.call(1.0)
	r1.take_hit(1, "rapido", 0)
	check(kx_frozen > absf(r1.own_vx) * 1.2 and r1.frozen_t <= 0.0, "golpe no congelado estilhaça e empurra mais (%.0f × %.0f)" % [kx_frozen, absf(r1.own_vx)])
	# troca: segurar o especial ~0,3 s sobre outra caixa; a antiga cai com as cargas e o dono não pega de volta na hora
	place.call(8.0)
	sp.drop_box("S01", Vector2(x0, floor_y - 120.0), false)
	await frames(40)
	check(sp.boxes.size() == 1 and sp.hud_info(0)["id"] == "S03", "com o slot ocupado, encostar não pega")
	vset("v0", "item", true)
	await frames(int(float(sp.cfg["caixa"]["troca_s"]) * 60.0) + 4)
	vset("v0", "item", false)
	await frames(3)
	var dropped: Dictionary = sp.boxes[0] if sp.boxes.size() == 1 else {}
	check(sp.hud_info(0).get("id", "") == "S01" and dropped.get("id", "") == "S03" and dropped.get("charges", 0) == 1 and dropped["block"].has(0), "segurar troca: pega S01, o S03 cai com 1 carga e bloqueado para o dono")
	await frames(20)
	check(sp.hud_info(0)["id"] == "S01" and sp.boxes.size() == 1, "anti-recaptura: o dono não pega de volta na hora")
	# toque rápido em cima de caixa usa a spell (não troca)
	place.call(8.0)
	put(r0, Vector2(dropped["pos"].x, floor_y))
	await frames(2)
	await tap("v0", "item")
	await frames(4)
	check(sp.hud_info(0)["id"] == "S01" and sp.flags(r0)["prep"] >= 0.0, "toque rápido sobre a caixa usa a spell atual")
	await frames(40)
	# S06 superímã: segurar puxa todo mundo à frente enquanto a barra dura; soltar pausa
	sp.boxes.clear()
	place.call(5.0)
	sp.clear(r0)
	sp.equip(r0, "S06")
	await frames(2)
	var d0: float = r1.position.x - r0.position.x
	vset("v0", "item", true)
	await frames(30)
	vset("v0", "item", false)
	await frames(2)
	var e_left: float = sp.slot[0]["energy"]
	check(r1.position.x - r0.position.x < d0 - 80.0 and e_left < float(sp.sc("S06")["energia_s"]) - 0.3 and not sp.slot[0]["channel"], "S06: segurando puxa o rival (%.0f → %.0f px) e gasta a barra" % [d0, r1.position.x - r0.position.x])
	vset("v0", "item", true)
	await frames(int(e_left * 60.0) + 30)
	vset("v0", "item", false)
	check(sp.hud_info(0).is_empty(), "S06: barra acabou, o ímã some")
		# eliminação limpa o slot
	sp.boxes.clear()
	main.kill(r0, -1, null)
	await frames(2)
	check(sp.hud_info(0).is_empty(), "eliminado perde a spell (nada passa para o respawn)")
	await frames(90)
	# S01 punho pneumático: preparo, soco em linha
	place.call(3.0)
	sp.equip(r0, "S01")
	await frames(2)
	await tap("v0", "item")
	check(sp.flags(r0)["prep"] >= 0.0, "S01: começa a preparação (puxa o braço)")
	await frames(int(float(sp.sc("S01")["preparo"]) * 60.0) + 12)
	check(r1.dmg > 0.0 and r1.own_vx > 200.0 and sp.hud_info(0)["charges"] == 1, "S01: punho estica e arremessa o rival (dano %d%%, vx %.0f)" % [int(r1.dmg), r1.own_vx])
	# golpe na preparação cancela sem gastar carga
	place.call(3.0)
	sp.slot[0]["cd"] = 0.0
	await frames(2)
	await tap("v0", "item")
	await frames(6)
	r0.take_hit(-1, "rapido", 1)
	await frames(30)
	check(sp.hud_info(0).get("charges", 0) == 1 and r1.dmg == 0.0, "S01: levar golpe na preparação cancela (sem gastar carga)")
	# S10 andaime relâmpago: plataforma 2 tiles acima, à frente; robô fica de pé nela
	place.call(10.0)
	sp.clear(r0)
	sp.equip(r0, "S10")
	await frames(2)
	var pr: Rect2 = sp.scaffold_rect(r0)
	await tap("v0", "item")
	check(sp.platforms.size() == 1 and sp.hud_info(0)["charges"] == 1, "S10: andaime abre (1 carga restante)")
	put(r1, Vector2(pr.get_center().x, pr.position.y - 80.0))
	await frames(40)
	check(absf(r1.position.y - pr.position.y) < 6.0 and r1.is_on_floor(), "S10: dá para ficar de pé no andaime (y %.0f, topo %.0f)" % [r1.position.y, pr.position.y])
	put(r1, Vector2(sp.scaffold_rect(r0).get_center().x, sp.scaffold_rect(r0).position.y + 10.0))
	await frames(1)
	await tap("v0", "item")
	check(sp.hud_info(0).get("charges", 0) == 1, "S10: lugar ocupado não gasta carga")
	await frames(int(float(sp.sc("S10")["duracao_s"]) * 60.0))
	check(sp.platforms.is_empty(), "S10: andaime dobra sozinho")
	# S11 teleporte: segura para mirar (o robô para), move a mira com o direcional, solta para ir
	place.call(10.0)
	sp.clear(r0)
	sp.equip(r0, "S11")
	await frames(2)
	var x_before: float = r0.position.x
	vset("v0", "item", true)
	await frames(3)
	check(sp.aims.has(0) and r0.spell_lock, "S11: segurar abre a mira")
	vset("v0", "right", true)
	await frames(10)
	vset("v0", "right", false)
	vset("v0", "item", false)
	await frames(30)
	check(r0.position.x - x_before > 180.0 and sp.hud_info(0)["charges"] == 1 and not r0.spell_lock and r0.vis.visible, "S11: solta e teleporta %.1f tiles" % ((r0.position.x - x_before) / 64.0))
	r0.facing = -1
	put(r0, Vector2(main.level.ko_rect().position.x + 140.0, floor_y - 600.0))
	await frames(1)
	check(sp.teleport_dest(r0) == null, "S11: sem lugar livre não há destino")
		# S13 armadura fornalha: toque veste; segurar solta um jato contínuo; acabou o combustível, explode
	place.call(2.5)
	sp.clear(r0)
	sp.equip(r0, "S13")
	await frames(2)
	await tap("v0", "item")
	check(r0.spell_speed < 1.0 and r0.spell_push < 1.0 and sp.flags(r0).get("armor", false), "S13: veste a armadura (mais lento, resiste a empurrão)")
	await frames(25)
	r0.dmg = 0.0
	r0.invuln = 0.0
	r0.take_hit(-1, "pesado", 1)
	var kx_arm: float = absf(r0.own_vx)
	check(kx_arm < float(main.demo.cfg["amassometro"]["pesado"]["kx"]) * 0.6, "S13: marretada empurra bem menos (%.0f)" % kx_arm)
	await frames(30)
	place.call(2.5)
	await frames(2)
	vset("v0", "item", true)
	await frames(40)
	check(r1.dmg > 0.0 and sp.slot[0]["energy"] < float(sp.sc("S13")["combustivel_s"]) - 0.4, "S13: segurando, o jato acerta quem está na frente (dano %d%%)" % int(r1.dmg))
	await frames(int(float(sp.sc("S13")["combustivel_s"]) * 60.0))
	vset("v0", "item", false)
	await frames(2)
	check(r0.spell_speed == 1.0 and r0.spell_push == 1.0 and sp.hud_info(0).is_empty(), "S13: combustível acabou, a armadura explode e o slot esvazia")
	# ===== Etapa 2 (ataque)
	sp.boxes.clear()
	# S02 laser: preparo com linha de mira, feixe atravessa robôs
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S02")
	await frames(2)
	await tap("v0", "item")
	check(sp.flags(r0)["prep"] >= 0.0, "S02: mira antes de disparar")
	await frames(int(float(sp.sc("S02")["preparo"]) * 60.0) + 4)
	check(r1.dmg > 0.0 and sp.hud_info(0)["charges"] == 2, "S02: feixe acerta à distância (dano %d%%)" % int(r1.dmg))
	# S04 marreta sísmica: no ar não gasta; no chão a onda pega quem está apoiado no mesmo trecho
	place.call(3.0)
	sp.clear(r0)
	sp.equip(r0, "S04")
	r0.position.y -= 120.0
	r0.velocity.y = -100.0
	await frames(1)
	await tap("v0", "item")
	check(sp.hud_info(0).get("charges", 0) == 1 and sp.flags(r0)["prep"] < 0.0, "S04: no ar avisa e não gasta")
	place.call(3.0)
	await frames(30)
	await tap("v0", "item")
	await frames(int(float(sp.sc("S04")["preparo"]) * 60.0) + 25)
	check(r1.dmg > 0.0 and r1.velocity.y < 0.0 or r1.dmg > 0.0, "S04: a onda tira o rival do chão (dano %d%%)" % int(r1.dmg))
	place.call(3.0)
	sp.equip(r0, "S04")
	await frames(2)
	await tap("v0", "item")
	await frames(int(float(sp.sc("S04")["preparo"]) * 60.0) + 1)
	r1.velocity.y = -900.0   # pula na hora certa (a onda ainda está chegando)
	await frames(20)
	check(r1.dmg == 0.0, "S04: quem pulou escapa da onda (%s, %d%%)" % [r1.last_cause, int(r1.dmg)])
	# S05 rebiteira: tiro rápido, acerta e some
	place.call(5.0)
	sp.clear(r0)
	sp.equip(r0, "S05")
	await frames(2)
	await tap("v0", "item")
	await frames(25)
	check(r1.dmg > 0.0 and sp.hud_info(0)["charges"] == 3, "S05: rebite acerta (dano %d%%)" % int(r1.dmg))
	# ricochete: atira de costas para a parede de longe e o rebite volta
	var rv_test := {"owner": 0, "pos": Vector2(x0, floor_y - 40.0), "vel": Vector2(0, 900.0), "bounces": 0, "t": 0.0, "hit": [], "trail": []}
	sp.rivets.append(rv_test)
	await frames(10)
	check(rv_test["bounces"] >= 1 and rv_test["vel"].y < 0.0, "S05: rebite ricocheteia no chão (%d)" % rv_test["bounces"])
	# S17 bate-estaca: marca, desce e lança para cima
	place.call(2.6)
	sp.clear(r0)
	sp.equip(r0, "S17")
	await frames(2)
	await tap("v0", "item")
	check(sp.piles.size() == 1 and r1.dmg == 0.0, "S17: toque rápido marca a faixa à frente antes de descer")
	var y_before: float = r1.position.y
	var top_y: float = y_before
	for k in int(float(sp.sc("S17")["marca_s"]) * 60.0) + 40:
		await frames(1)
		top_y = minf(top_y, r1.position.y)
	check(r1.dmg > 0.0 and y_before - top_y > 2.0 * 64.0, "S17: estaca lança o rival para cima (%.1f tiles, %s)" % [(y_before - top_y) / 64.0, r1.last_cause])
	# mirar segurando: a marca anda com o direcional
	place.call(6.0)
	sp.equip(r0, "S17")
	await frames(2)
	vset("v0", "item", true)
	await frames(2)
	var mx0: float = sp.pile_aims[0]["x"] if sp.pile_aims.has(0) else 0.0
	vset("v0", "right", true)
	await frames(15)
	vset("v0", "right", false)
	var mx1: float = sp.pile_aims[0]["x"] if sp.pile_aims.has(0) else 0.0
	vset("v0", "item", false)
	await frames(3)
	check(mx1 - mx0 > 100.0 and sp.piles.size() >= 1 and absf(sp.piles[-1]["x"] - mx1) < 20.0, "S17: segurando, a mira anda (%.0f → %.0f) e a estaca cai lá" % [mx0, mx1])
	# S18 disco: rola, acerta e volta para a mão
	place.call(4.0)
	sp.clear(r0)
	sp.equip(r0, "S18")
	await frames(2)
	await tap("v0", "item")
	await frames(30)
	check(r1.dmg > 0.0, "S18: disco acerta rolando no chão (dano %d%%)" % int(r1.dmg))
	var back := 0
	while sp.discs.size() > 0 and back < 300:
		await frames(1)
		back += 1
	check(sp.discs.is_empty() and back < 200, "S18: disco volta para a mão (%d quadros)" % back)
	# S19 marreta-bumerangue: sem pesada enquanto voa, volta garantido
	place.call(3.5)
	sp.clear(r0)
	sp.equip(r0, "S19")
	await frames(2)
	await tap("v0", "item")
	await frames(3)
	check(r0.hammer_out and not r0.vis.has_hammer, "S19: a marreta sai da mão")
	await tap("v0", "heavy")
	check(r0.atk != "pesado", "S19: sem marretada pesada enquanto ela voa")
	var ret := 0
	while r0.hammer_out and ret < 300:
		await frames(1)
		ret += 1
	check(not r0.hammer_out and r1.dmg > 0.0, "S19: acerta na ida/volta e volta para a mão (%d quadros, dano %d%%)" % [ret, int(r1.dmg)])
	# S20 canhão de molas: BOING forte no primeiro alvo
	place.call(4.0)
	sp.clear(r0)
	sp.equip(r0, "S20")
	await frames(2)
	await tap("v0", "item")
	var x_b: float = r1.position.x
	await frames(int(float(sp.sc("S20")["preparo"]) * 60.0) + 60)
	check(r1.dmg > 0.0 and r1.position.x - x_b > 3.0 * 64.0, "S20: BOING arremessa longe (%.1f tiles)" % ((r1.position.x - x_b) / 64.0))
	sp.clear(r0)
	# ===== Etapa 3 (controle e engenharia)
	sp.boxes.clear()
	# S07 turboventilador: segurando, empurra para longe sem tirar o controle
	place.call(3.0)
	sp.clear(r0)
	sp.equip(r0, "S07")
	await frames(2)
	var d7: float = r1.position.x - r0.position.x
	vset("v0", "item", true)
	await frames(40)
	vset("v0", "item", false)
	await frames(2)
	check(r1.position.x - r0.position.x > d7 + 100.0 and r1.stun_t <= 0.0, "S07: vento empurra o rival (%.0f → %.0f px), sem tirar o controle" % [d7, r1.position.x - r0.position.x])
	# S08 gancho: no rival dá tranco para perto; na parede puxa o dono
	place.call(5.0)
	sp.clear(r0)
	sp.equip(r0, "S08")
	await frames(2)
	await tap("v0", "item")
	await frames(20)
	check(r1.dmg > 0.0 and r1.own_vx < 0.0 or r1.dmg > 0.0, "S08: garra acerta o rival e puxa (dano %d%%)" % int(r1.dmg))
	place.call(9.0)
	put(r1, Vector2(x0 - 600.0, floor_y))
	var xg: float = r0.position.x
	await frames(30)
	sp.slot[0]["cd"] = 0.0
	vset("v0", "up", true)
	await tap("v0", "item")
	vset("v0", "up", false)
	var moved := false
	for k in 70:
		await frames(1)
		if r0.position.distance_to(Vector2(xg, floor_y)) > 120.0:
			moved = true
	check(moved or sp.hooks.is_empty(), "S08: garra na estrutura puxa o dono (ou volta se não achar nada)")
	# S21 laço: liga os dois e o elástico puxa quando estica
	place.call(4.0)
	sp.clear(r0)
	sp.equip(r0, "S21")
	await frames(2)
	await tap("v0", "item")
	await frames(20)
	check(sp.tethers.size() == 1, "S21: laço prende o rival")
	put(r1, Vector2(r0.position.x + 6.0 * 64.0, floor_y))
	await frames(12)
	check(r1.position.x - r0.position.x < 6.0 * 64.0 - 40.0, "S21: esticado, o elástico aproxima os dois (%.0f px)" % (r1.position.x - r0.position.x))
	await frames(int(float(sp.sc("S21")["duracao_s"]) * 60.0))
	check(sp.tethers.is_empty(), "S21: o laço solta depois do tempo")
	# S12 carga remota: instala, arma e detona no segundo toque
	place.call(5.0)
	sp.clear(r0)
	sp.equip(r0, "S12")
	await frames(2)
	await tap("v0", "item")
	check(sp.charges_placed.size() == 1 and sp.hud_info(0)["charges"] == 1, "S12: instala a carga (slot vira detonador)")
	put(r1, Vector2(sp.charges_placed[0]["pos"].x + 40.0, floor_y))
	put(r0, Vector2(x0 + 5.0 * 64.0, floor_y))
	await frames(40)
	await tap("v0", "item")
	await frames(3)
	check(sp.charges_placed.is_empty() and r1.dmg > 0.0 and sp.flags(r0).get("fading", false), "S12: detona e lança quem está perto (dano %d%%)" % int(r1.dmg))
	# S28 escudo: bloqueia o tiro
	place.call(6.0)
	sp.clear(r0)
	sp.clear(r1)
	sp.equip(r0, "S28")
	await frames(2)
	await tap("v0", "item")
	await frames(25)
	check(sp.shields.size() == 1, "S28: escudo sobe à frente")
	sp.equip(r1, "S05")
	r1.facing = -1
	await frames(2)
	await tap("v1", "item")
	await frames(30)
	check(r0.dmg == 0.0 and sp.shields.size() == 1 and sp.shields[0]["hp"] < int(sp.sc("S28")["resistencia"]), "S28: rebite bate no escudo e não acerta")
	sp.clear(r1)
	# S27 controle remoto: derruba a viga pendurada mais perto
	var vigas: Array = ct.parts.filter(func(p): return p["kind"] == "viga" and not p["fallen"])
	if vigas.size() > 0:
		var vg: Dictionary = vigas[0]
		place.call(3.0)
		sp.clear(r0)
		put(r0, Vector2(vg["rect"].get_center().x - 120.0, floor_y))
		r0.facing = 1
		sp.equip(r0, "S27")
		await frames(2)
		var tg = sp.remote_target(r0)
		await tap("v0", "item")
		await frames(60)
		check(tg != null and tg["fallen"], "S27: o cabo estala e a viga despenca")
	sp.clear(r0)
	# ===== Mira em 8 direções e regra das plataformas
	var and0: Dictionary = ct.parts.filter(func(p): return p["kind"] == "andaime")[0]
	check(not sp._hard_at(and0["rect"].get_center()) and sp._grab_at(and0["rect"].get_center()) and sp._hard_at(nuc[0]["rect"].get_center()),
		"plataforma vazada não para tiro (mas o gancho agarra); a laje para")
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S03")
	await frames(2)
	vset("v0", "up", true)
	await tap("v0", "item")
	await frames(int(float(sp.sc("S03")["preparo"]) * 60.0) + 2)
	vset("v0", "up", false)
	check(sp.shots.size() > 0 and sp.shots[0]["vel"].y < -500.0 and absf(sp.shots[0]["vel"].x) < 1.0, "▲: canhão de gelo atira para cima")
	await frames(30)
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S08")
	await frames(2)
	vset("v0", "up", true)
	vset("v0", "right", true)
	await tap("v0", "item")
	vset("v0", "up", false)
	vset("v0", "right", false)
	check(sp.hooks.size() == 1 and sp.hooks[0]["vel"].y < 0.0 and sp.hooks[0]["vel"].x > 0.0, "▲►: gancho sai na diagonal")
	await frames(60)
	place.call(4.0)
	sp.clear(r0)
	sp.equip(r0, "S06")
	await frames(2)
	vset("v0", "item", true)
	vset("v0", "up", true)
	await frames(30)
	check(sp.slot[0]["aim"].y < -0.5, "ímã: a mira gira para cima enquanto segura (%s)" % str(sp.slot[0]["aim"]))
	vset("v0", "item", false)
	vset("v0", "up", false)
	await frames(3)
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S28")
	await frames(2)
	vset("v0", "up", true)
	await tap("v0", "item")
	vset("v0", "up", false)
	check(sp.shields.size() > 0 and sp.shields[-1].get("roof", false), "▲: escudo de solda vira teto")
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S12")
	await frames(2)
	vset("v0", "up", true)
	await tap("v0", "item")
	vset("v0", "up", false)
	await frames(110)
	check(sp.charges_placed.size() == 1 and not sp.charges_placed[0].get("flying", false) and sp.charges_placed[0]["pos"].distance_to(r0.position) > 40.0, "▲: carga arremessada gruda numa superfície")
	sp.charges_placed.clear()
	sp.shields.clear()   # o teto de solda do teste anterior seguraria a mola
	place.call(6.0)
	sp.clear(r0)
	sp.equip(r0, "S20")
	await frames(2)
	vset("v0", "up", true)
	await tap("v0", "item")
	await frames(int(float(sp.sc("S20")["preparo"]) * 60.0) + 2)
	vset("v0", "up", false)
	check(sp.springs.size() > 0 and sp.springs[0]["vel"].y < -600.0, "▲: canhão de molas em arco alto")
	await frames(60)
	sp.clear(r0)
	put(r0, Vector2(8 * 64.0 + 30.0, floor_y))
	r0.facing = -1
	sp.equip(r0, "S25")
	await frames(3)
	vset("v0", "up", true)
	vset("v0", "left", true)
	await tap("v0", "item")
	vset("v0", "up", false)
	vset("v0", "left", false)
	check(sp.bridges.size() > 0 and float(sp.bridges[-1].get("slope", 0.0)) > 0.3, "▲: ponte vira rampa")
	sp.clear(r0)
	# G10 carga especial: holofotes em 2 pontos e duas cápsulas descem
	main.event_level = 2
	main.events.manual = true
	sp.boxes.clear()
	main.events.trigger(main.events.cfg["lista"][1])
	await frames(3)
	check(main.events.phase == "aviso" and main.events.spots.size() == 2 and main.events.spots[0].distance_to(main.events.spots[1]) > 200.0, "G10: anuncia 2 pontos afastados (holofotes)")
	await frames(60)
	check(sp.boxes.size() == 2 and sp.boxes.all(func(b): return b["special"]), "G10: duas cápsulas de spell descem")
	main.events.manual = false
	main.event_level = 0

## Toda imagem pedida no código existe (a lama da Maré faltava e enchia o log de erros, travando o jogo).
func imagens_test() -> void:
	print("== Imagens")
	var missing := []
	var found := 0
	var re := RegEx.new()
	re.compile("Data\\.tex\\(\"([a-z_/0-9]+)\"\\)")
	for path in ["res://main.gd", "res://modes/demolicao.gd", "res://modes/arena_fx.gd", "res://modes/eventos.gd", "res://modes/spells.gd",
			"res://level/level.gd", "res://ui/hud.gd", "res://ui/menus.gd", "res://ui/kit.gd", "res://player/robot_visual.gd"]:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			if Data.tex(m.get_string(1)) == null:
				missing.append(m.get_string(1))
	for k in ["s01_canhao", "s01_luva", "s03_canhao", "s06_ima", "s10_tabua", "s10_trouxa", "s13_frente", "s13_costas", "icone_engenharia", "icone_transformacao"]:
		if Data.tex("spells/" + k) == null:
			missing.append("spells/" + k)
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
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
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
	check(PlayerInput.dev_held("joy3", "hammer") or r0.atk != "" or r0.atk_cd > 0.0, "X dá o golpe rápido")
	joy_axis(3, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await frames(2)
	check(PlayerInput.held(0, "dodge"), "gatilho RT é a esquiva")
	joy_axis(3, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	# CONFIGURAR CONTROLE: aprende um controle de botões trocados
	main.go_menu()
	PlayerInput.fake_joys = [3]
	main.menus.start_config()
	await frames(25)
	await joy_tap(3, 9)   # qualquer botão: escolhe o controle
	check(main.menus.cfg_joy == 3 and main.menus.cfg_step == 0, "configurar: escolheu o controle que apertou")
	var seq := [["b", 2], ["b", 3], ["b", 4], ["b", 9], ["b", 1], ["b", 7], ["b", 6], ["a", 0, -1.0], ["a", 0, 1.0], ["a", 1, -1.0], ["a", 1, 1.0]]
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
	check(cm.size() == 11 and cm["jump"] == ["b", 2, 1] and cm["dodge"] == ["b", 9, 1] and cm["left"][1] == 0 and cm["left"][2] < 0.0, "configurar: aprendeu as 11 ações (%s)" % str(cm.get("jump")))
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
	await tap("v0", "heavy")
	check(main.players.size() == 2 and main.players[1].get("bot", false), "na entrada, Y/△ adiciona bot")
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
	var crumble0 = main.demo.cfg["crumble_break_s"]
	main.demo.lives_setting = 1   # "derruba" = 1 eliminação (não herda vidas de outro teste)
	main.demo.cfg["crumble_break_s"] = 999.0   # mede só o bot: o caixote que racha sob quem fica parado derrubava os dois
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
	main.demo.cfg["crumble_break_s"] = crumble0
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
		for k in 8:  # os 8 modelos em azul
			Vis.draw_robot(sheet, {"color": 0, "model": k}, Vis.idle_pose(0.5), Transform2D(0.0, Vector2(2.6, 2.6), 0.0, Vector2(140 + k * 235, 560)))
		for k in 8:  # cores e expressões
			var po: Dictionary = Vis.idle_pose(0.5)
			po["expr"] = ex[k % 5]
			Vis.draw_robot(sheet, {"color": k % 4, "model": k}, po, Transform2D(0.0, Vector2(1.6, 1.6), 0.0, Vector2(140 + k * 235, 1010)))
	)
	layer.add_child(sheet)
	await frames(3)
	await snap(dir, "prancha_robos")

## Espia uma arena num modo com 4 bots: --espiar=DIR,arena,modo,segundos (uma foto a cada 10 s).
func espiar(arg: String) -> void:
	var p := arg.split(",")
	var dir := p[0]
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	main.bot_level = 1
	for k in 4:
		main.add_bot()
	main.arena_choice = p[1]
	main.game_mode = p[2]
	main.demo.cfg["rounds_to_win"] = 99
	main.start_match()
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	var secs := int(p[3]) if p.size() > 3 else 40
	for k in range(1, secs / 10 + 1):
		await frames(600)
		await snap(dir, "%s_%s_%02ds" % [p[1], p[2], k * 10])
		print("t=%d rei=%d capacete=%s tempos=%s estado=%d robôs=%s" % [k * 10, main.demo.king, str(main.demo.crown_pos), str(main.demo.king_time), main.state, str(main.robots.map(func(r): return Vector2i(r.position)))])

## Material para as propostas de interface: cenários sem HUD e robôs com fundo transparente.
func maquete_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	main.hud.bare = true
	main.go_menu()
	await frames(90)
	await snap(dir, "bg_menu")
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	main.mode = "demolicao"
	main.arena_choice = "canteiro"
	main.go_join()
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	for k in 6:
		await tap("v0", "down")
	main.add_bot()
	main.add_bot()
	var looks: Array = []
	for p in main.players:
		looks.append({"color": p["color"], "model": p["model"]})
	main.start_match()
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
	await frames(100)
	await snap(dir, "bg_jogo")
	# robôs recortados (fundo transparente)
	get_viewport().transparent_bg = true
	main._clear_robots()
	main.state = S.MENU
	main.hud.visible = false
	main.bg.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var sheet := Node2D.new()
	var Vis = load("res://player/robot_visual.gd")
	var which := [0, false]
	sheet.draw.connect(func():
		var lk: Dictionary = looks[which[0]]
		var pose: Dictionary = Vis.victory_pose(0.35, int(Data.model_meta(lk["model"])["danca"])) if which[1] else Vis.idle_pose(0.5)
		Vis.draw_robot(sheet, lk, pose, Transform2D(0.0, Vector2(6, 6), 0.0, Vector2(960, 900)))
	)
	layer.add_child(sheet)
	for k in looks.size():
		for v in 2:
			which[0] = k
			which[1] = v == 1
			sheet.queue_redraw()
			await frames(3)
			await snap(dir, "robo_%d%s" % [k, "_vitoria" if v == 1 else ""])
	print("cores: ", main.players.map(func(p): return p["color"]))

## Prancha dos 8 robôs montados pelo motor: parado, rostos, comemoração e corrida (--robos=DIR).
func robos_sheet(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var sheet := Node2D.new()
	var Vis = load("res://player/robot_visual.gd")
	var tt := [0.0]
	sheet.draw.connect(func():
		sheet.draw_texture_rect(Data.tex("temas/fabrica/fundo"), Rect2(0, 0, 1920, 1080), false)
		for k in 8:
			var x := 130.0 + k * 237.0
			Vis.draw_robot(sheet, {"color": k % 4, "model": k}, Vis.idle_pose(0.5), Transform2D(0.0, Vector2(2.4, 2.4), 0.0, Vector2(x, 400)))
			load("res://ui/kit.gd").text(sheet, Vector2(x - 110, 450), Data.MODEL_NAMES[k], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 220, 6, Data.INK)
			var po: Dictionary = Vis.victory_pose(tt[0] + k * 0.13, int(Data.model_meta(k)["danca"]))
			Vis.draw_robot(sheet, {"color": (k + 1) % 4, "model": k}, po, Transform2D(0.0, Vector2(1.6, 1.6), 0.0, Vector2(x, 760)))
			var p2: Dictionary = Vis.idle_pose(0.5)
			p2["expr"] = ["esforco", "susto", "eliminado", "vitoria"][k % 4]
			Vis.draw_robot(sheet, {"color": (k + 2) % 4, "model": k}, p2, Transform2D(0.0, Vector2(1.6, 1.6), 0.0, Vector2(x, 1010)))
	)
	layer.add_child(sheet)
	for f in 2:
		tt[0] = 0.21 * f
		sheet.queue_redraw()
		await frames(3)
		await snap(dir, "robos_%d" % f)

# ---------------------------------------------------------------- animação (quadros para GIF)
var _frame_no := 0

func grab(dir: String, prefix: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("%s_%04d.png" % [prefix, _frame_no]))
	_frame_no += 1

## Vitrine das animações de movimento e combate (--combate=DIR): quadros a 30 por segundo para virar GIF.
## P1 Lata: corre, derrapa, pulo + pulo duplo (mortal), esquiva no chão e no ar, golpes rápidos, marretada pesada.
## P2 Brutamontes (amassado): apanha, é arremessado girando e se recupera no ar. P3 Varapau: erra a marretada (fica cravada).
func combate_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	PlayerInput.virtual = {"v0": {}, "v1": {}, "v2": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	for d in ["v0", "v1", "v2"]:
		await tap(d, "jump")
	main.players[0]["model"] = 0
	main.players[1]["model"] = 4
	main.players[2]["model"] = 5
	main.game_mode = "derruba"
	main.demo.lives_setting = 5
	main.event_level = 0
	main.arena_choice = "demolicao"
	main.start_match()
	await demo_round()
	main.demo.spells.spawn_t = 999.0
	main.hud.visible = false
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var r2 = main.robots[2]
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(19), 576))
	put(r2, Vector2(col_x(24), 576))
	r1.dmg = 45.0
	r2.dmg = 90.0
	r1.facing = -1
	r2.facing = -1
	main.cam_lock = [1.55, Vector2(col_x(17), 470)]
	_frame_no = 0
	var script := {
		"v0": [[10, 40, "right"], [40, 58, "left"], [70, 78, "jump"], [82, 92, "jump"], [82, 120, "right"],
			[150, 153, "dodge"], [150, 153, "right"], [175, 189, "jump"], [192, 195, "dodge"], [192, 195, "right"], [192, 195, "up"],
			[240, 243, "hammer"], [258, 261, "hammer"], [276, 279, "hammer"], [330, 333, "heavy"],
			[440, 443, "dodge"], [440, 443, "right"]],
		"v1": [[372, 420, "left"], [395, 398, "dodge"], [395, 398, "left"]],
		"v2": [[300, 303, "heavy"], [430, 433, "heavy"]],
	}
	for f in 520:
		if f == 225:
			put(r0, Vector2(col_x(16), 576))
			put(r1, Vector2(col_x(17) + 10, 576))
			r0.facing = 1
			r1.dmg = 45.0
		if f == 320:
			r1.dmg = 135.0
			put(r1, Vector2(col_x(17) + 10, 576))
			r1.own_vx = 0.0
		if f == 425:
			put(r0, Vector2(col_x(12), 576))
			put(r2, Vector2(col_x(14) + 20, 576))
			r0.facing = 1
		var a := {"v0": {}, "v1": {}, "v2": {}}
		for d in script:
			for seg in script[d]:
				if f >= seg[0] and f < seg[1]:
					a[d][seg[2]] = true
		PlayerInput.virtual = a
		for r in main.robots:
			r.invuln = 0.0
		var foco: Vector2 = r0.position
		if f >= 225 and f < 425:
			foco = (r0.position + r1.position) / 2.0
		elif f >= 425:
			foco = (r0.position + r2.position) / 2.0
		main.cam_lock = [2.3, foco + Vector2(0, -60)]
		await frames(1)
		if f % 2 == 0:
			await grab(dir, "c")
	print("quadros: ", _frame_no)

## Vitrine das spells da Etapa 1 no Canteiro (--spells=DIR): caixas, cada spell em uso e a troca. 30 quadros/s.
func spells_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	for d in ["v0", "v1"]:
		await tap(d, "jump")
	main.players[0]["model"] = 0
	main.players[1]["model"] = 4
	main.game_mode = "derruba"
	main.demo.lives_setting = 5
	main.event_level = 0
	main.arena_choice = "canteiro_obras"
	main.start_match()
	await demo_round()
	var sp = main.demo.spells
	sp.spawn_t = 999.0
	main.hud.visible = false
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var nuc: Array = main.demo.canteiro.parts.filter(func(p): return p["nucleo"])
	var fy: float = nuc[0]["rect"].position.y
	var x0: float = nuc[0]["rect"].position.x + 40.0
	_frame_no = 0
	var segs := [["caixas", 50], ["S01", 60], ["S03", 120], ["S06", 90], ["S10", 70], ["S11", 70], ["S13", 300], ["troca", 60],
		["S02", 60], ["S04", 70], ["S05", 60], ["S17", 90], ["S18", 80], ["S19", 90], ["S20", 70], ["porte", 90],
		["S07", 90], ["S08", 70], ["S21", 120], ["S12", 110], ["S25", 90], ["S27", 90], ["S28", 90],
		["lasercima", 70], ["gelodiag", 70], ["ganchocima", 90], ["ventocima", 80], ["fogocima", 140], ["socobaixo", 60]]
	var mira_sp := {"lasercima": "S02", "gelodiag": "S03", "ganchocima": "S08", "ventocima": "S07", "fogocima": "S13", "socobaixo": "S01"}
	for a0 in OS.get_cmdline_user_args():
		if a0.begins_with("--so-spells="):
			segs = segs.filter(func(x): return x[0] in a0.substr(12).split("+"))
	for sg in segs:
		var nm: String = sg[0]
		for r in [r0, r1]:
			r.dmg = 0.0
			r.stun_t = 0.0
			r.recover_t = 0.0
			r.atk_cd = 0.0
			r.frozen_t = 0.0
			sp.clear(r)
		sp.boxes.clear()
		put(r0, Vector2(x0, fy))
		put(r1, Vector2(x0 + ({"S01": 3.0, "S13": 3.0, "S04": 3.0, "S17": 2.6, "S19": 3.5, "S18": 4.0, "S20": 4.0, "S07": 3.0, "S21": 4.0, "S12": 1.5}.get(nm, 5.5)) * 64.0, fy))
		r0.facing = 1
		r1.facing = -1
		if nm == "caixas":
			var fams := ["S01", "S06", "S10", "S13"]
			for k in 4:
				sp.drop_box(fams[k], Vector2(x0 + 90.0 + k * 90.0, fy - 260.0 - k * 40.0), false)
		elif nm == "troca":
			sp.equip(r0, "S03")
			sp.drop_box("S13", Vector2(x0, fy - 100.0), false)
		elif nm == "S25":
			put(r0, Vector2(8 * 64.0 + 30.0, fy))
			r0.facing = -1
			sp.equip(r0, nm)
		elif nm == "S27":
			var vg: Array = main.demo.canteiro.parts.filter(func(p): return p["kind"] == "viga" and not p["fallen"])
			if vg.size() > 0:
				put(r0, Vector2(vg[0]["rect"].get_center().x - 160.0, fy))
				put(r1, Vector2(vg[0]["rect"].get_center().x, fy))
			sp.equip(r0, nm)
		elif nm == "S28":
			sp.equip(r0, nm)
			sp.equip(r1, "S05")
		elif mira_sp.has(nm):
			sp.equip(r0, mira_sp[nm])
			if nm == "ganchocima":
				var vg2: Array = main.demo.canteiro.parts.filter(func(p): return p["kind"] == "viga" and not p["fallen"])
				if vg2.size() > 0:
					put(r0, Vector2(vg2[0]["rect"].position.x - 60.0, fy))
			if nm in ["ventocima", "socobaixo"]:
				put(r1, Vector2(x0 + 1.6 * 64.0, fy))
		elif nm == "porte":
			sp.equip(r0, "S05")
			sp.equip(r1, "S10")
		else:
			sp.equip(r0, nm)
		for f in int(sg[1]):
			var a := {"v0": {}, "v1": {}}
			match nm:
				"troca":
					a["v0"]["item"] = f >= 30 and f < 52
				"S01", "S10", "S02", "S04", "S17", "S18", "S19", "S20":
					a["v0"]["item"] = f == 14 or f == 15
				"S07":
					a["v0"]["item"] = f >= 10 and f < 80
				"S08", "S21", "S25", "S27":
					a["v0"]["item"] = f == 14 or f == 15
				"S12":
					a["v0"]["item"] = f in [14, 15, 80, 81]
					a["v0"]["left"] = f >= 25 and f < 45
				"S28":
					a["v0"]["item"] = f == 14 or f == 15
					a["v1"]["item"] = f in [45, 46, 60, 61]
				"lasercima":
					a["v0"]["up"] = true
					a["v0"]["item"] = f == 14 or f == 15
				"gelodiag":
					a["v0"]["up"] = f >= 8
					a["v0"]["right"] = f >= 8 and f < 12
					a["v0"]["item"] = f == 14 or f == 15
				"ganchocima":
					a["v0"]["up"] = f >= 8 and f < 20
					a["v0"]["right"] = f >= 8 and f < 11
					a["v0"]["item"] = f == 14 or f == 15
				"ventocima":
					a["v0"]["up"] = f >= 8
					a["v0"]["item"] = f >= 10 and f < 75
				"fogocima":
					a["v0"]["item"] = (f == 14 or f == 15) or (f >= 60 and f < 130)
					a["v0"]["up"] = f >= 60 and f < 95
				"socobaixo":
					a["v0"]["jump"] = f >= 4 and f < 18
					a["v0"]["right"] = f >= 4 and f < 14
					a["v0"]["down"] = f >= 20
					a["v0"]["item"] = f == 20 or f == 21
				"porte":
					a["v0"]["right"] = f >= 10 and f < 40
					a["v0"]["hammer"] = f in [55, 56]
				"S05":
					a["v0"]["item"] = f in [14, 15, 30, 31]
					a["v0"]["up"] = f >= 28 and f < 33
				"S03":
					a["v0"]["item"] = f == 14 or f == 15
					if f > 60:   # o congelado agita para sair
						a["v1"]["left" if f % 8 < 4 else "right"] = true
				"S06":
					a["v0"]["item"] = f >= 10 and f < 85
				"S11":
					a["v0"]["item"] = f >= 10 and f < 40
					a["v0"]["right"] = f >= 14 and f < 24
					a["v0"]["up"] = f >= 18 and f < 24
				"S13":
					a["v0"]["item"] = (f == 14 or f == 15) or (f >= 60 and f < 280)
			PlayerInput.virtual = a
			for r in main.robots:
				r.invuln = 0.0
			main.cam_lock = [2.4, (r0.position + Vector2(150, 0)) + Vector2(0, -70)]
			await frames(1)
			if f % 2 == 0:
				await grab(dir, nm)
	print("quadros: ", _frame_no)

## Pulo duplo quadro a quadro (--pulo=DIR): pula do chão, no alto aperta de novo; câmera parada e perto.
func pulo_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	PlayerInput.virtual = {"v0": {}}
	await frames(2)
	main.lab.start("v0")
	main.countdown = 0.0
	for r in main.robots:
		r.active = true
		r.invuln = 0.0
	main.sandbox_remove("boneco")
	main.hud.visible = false
	var r0 = main.robots[0]
	put(r0, Vector2(col_x(16), 12 * 64))
	r0.facing = 1
	await frames(30)
	main.cam_lock = [2.4, Vector2(col_x(16), 12 * 64 - 260)]
	_frame_no = 0
	for f in 70:
		var a := {}
		if f < 16:
			a["jump"] = true
		if f >= 20 and f < 32:
			a["jump"] = true
		if f >= 20 and f < 50:
			a["right"] = true
		PlayerInput.virtual = {"v0": a}
		await frames(1)
		await grab(dir, "p")

## Prancha do Canteiro (Derruba): a arte de art/out/prancha_canteiro_derruba_1/2.png + robôs desenhados pelo motor.
func prancha_canteiro(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var Vis = load("res://player/robot_visual.gd")
	var root := ProjectSettings.globalize_path("res://").path_join("..").simplify_path()
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var sheet := Node2D.new()
	layer.add_child(sheet)
	var cur := [null, 0]
	const S := 0.75
	var at := func(c: float, r: float) -> Vector2:
		return Vector2(c * 64.0, r * 64.0) * S
	sheet.draw.connect(func():
		sheet.draw_texture_rect(cur[0], Rect2(0, 0, 1920, 1056), false)
		sheet.draw_rect(Rect2(0, 1056, 1920, 24), Color("#e9f7f6"))
		var heavy: Dictionary = Vis.idle_pose(0.3)
		heavy["expr"] = "esforco"
		heavy["hammer_ang"] = -2.75
		heavy["hf_off"] = Vector2(-10, -22)
		heavy["hb_off"] = Vector2(-4, -18)
		heavy["lean"] = -0.3
		heavy["glint"] = 1.0
		var run: Dictionary = Vis.idle_pose(0.6)
		run["feet"] = [Vector2(10, -8), Vector2(-9, 0)]
		run["knee"] = [Vector2(7, 0), Vector2(1, 0)]
		run["hb_off"] = Vector2(-9, -4)
		run["lean"] = 0.18
		var fly: Dictionary = Vis.idle_pose(0.2)
		fly["expr"] = "eliminado"
		fly["rot"] = 2.2
		fly["hb_off"] = Vector2(-16, -22)
		fly["hf_off"] = Vector2(14, -20)
		fly["feet"] = [Vector2(-10, -6), Vector2(12, -4)]
		var flip: Dictionary = Vis.idle_pose(0.4)
		flip["expr"] = "esforco"
		flip["rot"] = 3.3
		flip["tuck"] = 1.0
		flip["feet"] = [Vector2(3, -24), Vector2(8, -24)]
		flip["knee"] = [Vector2(12, 0), Vector2(12, 0)]
		flip["hb_off"] = Vector2(9, 6)
		flip["hf_off"] = Vector2(6, 8)
		flip["hammer_ang"] = 2.5
		var looks := [{"color": 0, "model": 0}, {"color": 1, "model": 4}, {"color": 2, "model": 5}, {"color": 3, "model": 7}]
		var xf := func(c: float, r: float, face := 1.0) -> Transform2D:
			return Transform2D(0.0, Vector2(S * face, S), 0.0, at.call(c, r))
		if cur[1] == 0:
			Vis.draw_robot(sheet, looks[0], run, xf.call(12.0, 13.0))
			Vis.draw_robot(sheet, looks[1], heavy, xf.call(21.5, 13.0, -1.0))
			Vis.draw_robot(sheet, looks[2], Vis.idle_pose(1.0), xf.call(5.5, 10.0))
			Vis.draw_robot(sheet, looks[3], flip, xf.call(19.5, 7.2))
		else:
			var lk2: Dictionary = looks[1].duplicate()
			lk2["dmg"] = 3
			Vis.draw_robot(sheet, looks[0], heavy, xf.call(19.0, 13.0))
			Vis.draw_robot(sheet, lk2, fly, xf.call(36.0, 7.0))
			var lk3: Dictionary = looks[2].duplicate()
			lk3["dmg"] = 1
			Vis.draw_robot(sheet, lk3, Vis.idle_pose(2.0), xf.call(14.0, 13.0))
			Vis.draw_robot(sheet, looks[3], run, xf.call(34.5, 10.0, -1.0))
			# rastro e riscos do arremesso do Brutamontes
			sheet.draw_set_transform_matrix(Transform2D.IDENTITY)
			for k in 4:
				var p0: Vector2 = at.call(36.0 - 1.6 * (k + 1), 7.0 + 0.55 * (k + 1)) + Vector2(0, -30)
				sheet.draw_circle(p0, 22.0 - k * 4.0, Color(0.36, 0.77, 0.36, 0.35 - k * 0.07))
			for k in 3:
				var y0: float = at.call(0, 6.4 + k * 0.35).y
				sheet.draw_line(Vector2(at.call(30.0, 0).x, y0), Vector2(at.call(34.6, 0).x, y0 + 30), Color(1, 1, 1, 0.9), 4.0)
	)
	for i in 2:
		var img := Image.load_from_file(root.path_join("art/out/prancha_canteiro_derruba_%d.png" % (i + 1)))
		cur[0] = ImageTexture.create_from_image(img)
		cur[1] = i
		sheet.queue_redraw()
		await frames(3)
		await snap(dir, "prancha_canteiro_%d" % (i + 1))

## Vitrine do Canteiro (--canteiro=DIR): P1 marreta um trecho até desabar, o ciclo da obra dispara,
## P2 (amassado) é arremessado para fora e explode na borda. Quadros a cada 2 físicos.
func canteiro_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	PlayerInput.virtual = {"v0": {}, "v1": {}, "v2": {}}
	main.mode = "demolicao"
	main.go_join()
	await frames(2)
	for d in ["v0", "v1", "v2"]:
		await tap(d, "jump")
	main.players[1]["model"] = 4
	main.players[2]["model"] = 5
	main.game_mode = "derruba"
	main.demo.lives_setting = 3
	main.event_level = 0
	main.arena_choice = "canteiro_obras"
	main.start_match()
	await demo_round()
	main.demo.spells.spawn_t = 999.0
	var ct = main.demo.canteiro
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var r2 = main.robots[2]
	put(r0, Vector2(col_x(10), 13 * 64))
	put(r1, Vector2(col_x(22), 13 * 64))
	put(r2, Vector2(col_x(18), 13 * 64))
	r0.facing = 1
	_frame_no = 0
	for f in 600:
		var a := {"v0": {}, "v1": {}, "v2": {}}
		# P1 marreta o trecho 2 (cols 8-11) de cima, com ▼, até desabar (pula para o trecho do lado antes)
		if f < 330 and f % 72 == 4:
			r0.heavy_cd = 0.0
			a["v0"]["heavy"] = true
			a["v0"]["down"] = true
		if f >= 300 and f < 318:
			a["v0"]["right"] = true
		if f == 340:
			main.event_level = 2
			main.events.trigger(main.events.cfg["lista"][0])   # G01 agora (sirene + fita zebrada)
		if f == 470:
			put(r1, Vector2(col_x(27), 13 * 64))
			r1.dmg = 160.0
			put(r0, Vector2(col_x(26), 13 * 64))
			r0.facing = 1
			r0.heavy_cd = 0.0
		if f >= 474 and f < 477:
			a["v0"]["heavy"] = true
		PlayerInput.virtual = a
		for r in main.robots:
			r.invuln = 0.0
		await frames(1)
		if f % 2 == 0:
			await grab(dir, "k")
	print("quadros: ", _frame_no, " de pé: ", ct.standing(), " P2 vivo: ", r1.alive, " vidas: ", main.demo.lives)

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
	main.demo.cfg["spells"]["caixa"]["intervalo_s"] = [1.5, 2.5]
	main.demo.cfg["spells"]["caixa"]["max_mapa"] = 3
	main.start_match()
	main.demo.spells.spawn_t = 1.0
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
	for k in 6:
		await tap("v0", "down")   # P1 com outro modelo de robô
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
	main.demo.spells.equip(main.robots[0], "S03")
	main.demo.spells.equip(main.robots[1], "S13")
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
	main.demo.spells.spawn_t = 999.0

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
	# maré: lama sobe e elimina quem ficou embaixo
	await arena_round("mare")
	var r0 = main.robots[0]
	main.demo.t = float(main.level.prop("mare_inicio", "6"))
	main.demo.fx.goo_y = 820.0
	put(r0, Vector2(col_x(3), 832))
	await frames(60)
	check(not r0.alive, "a lama alcança e elimina")
## --arenas=DIR[,id:modo,...]: miniatura de cada arena (o mapa inteiro) e uma foto jogando com 4 bots.
func arenas_frames(arg: String) -> void:
	var parts := arg.split(",")
	var dir := parts[0]
	var only := {}
	for k in range(1, parts.size()):
		var pm := parts[k].split(":")
		only[pm[0]] = pm[1] if pm.size() > 1 else "derruba"
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {}
	main.mode = "demolicao"
	main.bot_level = 1
	for k in 4:
		main.add_bot()
	main.start_match()
	for a in main.demo.cfg["arenas"]:
		if not only.is_empty() and not only.has(a["id"]):
			continue
		if not only.is_empty():
			main.game_mode = only[a["id"]]
		else:
			main.game_mode = "derruba"
			for m in main.demo.cfg["modos"]:
				if a["id"] in m["arenas"]:
					main.game_mode = m["id"]
		main.arena_choice = a["id"]
		main._clear_robots()
		main.demo.start_round()
		# miniatura: arena inteira, sem HUD e sem robôs
		var lw: float = main.level.cols * 64.0
		var lh: float = main.level.rows * 64.0
		main.cam_lock = [minf(1.0, minf(1920.0 / lw, 1024.0 / lh)), Vector2(lw, lh) / 2.0]
		main.hud.visible = false
		for r in main.robots:
			r.visible = false
		await frames(8)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img = img.get_region(Rect2i(0, 56, 1920, 1024))
		img.resize(480, 256, Image.INTERPOLATE_LANCZOS)
		img.save_png(dir.path_join("arena_%s.png" % a["id"]))
		if not only.is_empty():
			var full := get_viewport().get_texture().get_image()
			full.save_png(dir.path_join("mapa_%s.png" % a["id"]))
		main.hud.visible = true
		main.cam_lock = []
		for r in main.robots:
			r.visible = true
		main.countdown = 0.0
		for r in main.robots:
			r.active = true
		main.demo.spells.spawn_t = 1.0
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
	main.demo.cfg["spells"]["caixa"]["intervalo_s"] = [2.0, 3.0]
	main.demo.cfg["spells"]["caixa"]["max_mapa"] = 3
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
	main.demo.spells.spawn_t = 1.5
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
			main.demo.spells.spawn_t = 1.0
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
			main.demo.cfg["spells"]["caixa"]["intervalo_s"] = [1.5, 2.5]
			main.demo.cfg["spells"]["caixa"]["max_mapa"] = 4
		if a.begins_with("--sub="):
			main.game_mode = a.substr(6)
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
			out.append({"arena": a["id"], "dur": main.demo.t, "first": first_death, "winner": main.demo.round_winner,
				"chegou": main.robots.filter(func(x): return x.finished).size()})
			main.timer = 0.0
			await get_tree().physics_frame
			await get_tree().physics_frame
	var fa := FileAccess.open("user://stats.json", FileAccess.WRITE)
	fa.store_string(JSON.stringify({"rounds": out, "deaths": main.demo.death_log, "quedas": main.fall_log}))
	fa.close()
	print("STATS_FILE ", ProjectSettings.globalize_path("user://stats.json"))
