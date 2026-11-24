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
		if a.begins_with("--parede="):
			await parede_frames(a.substr(9))
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
		if a.begins_with("--itensgif="):
			await gifs_frames(a.substr(11))
			get_tree().quit(0)
			return
		if a.begins_with("--itens2="):
			await itens2_frames(a.substr(9))
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
	await itens_test()
	await bots_test()
	await arenas_test()
	await parede_test()
	await maquinas_test()
	await itens_novos_test()
	await submodos_test()
	await itens_modos_test()
	await eventos_test()
	await menus_test()
	await controles_test()
	await controle_real_test()
	await oficina_test()
	await robos_test()
	await combate_test()
	await lab_test()
	await canteiro_test()
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
	for k in 4:
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

## Itens próprios de cada modo (Batata, Rei, Fuga).
func itens_modos_test() -> void:
	print("== Itens dos modos")
	var lists := {}
	for m in main.demo.cfg["modos"]:
		lists[m["id"]] = m["itens_lista"]
	check("estilingue" in lists["batata"] and "choque" in lists["rei"] and "barreira" in lists["fuga"] and "dinamite" in lists["derruba"],
		"cada modo tem a sua lista de itens")
	# Batata: estilingue arremessa a dinamite; escudo impede receber
	main.game_mode = "batata"
	main.arena_choice = "demolicao"
	await demo_round()
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	for r in [r0, r1]:
		r.invuln = 0.0
	main.demo.bomb_holder = 0
	main.demo.bomb_fuse = 30.0
	main.demo.bomb_next = 99.0
	put(r0, Vector2(col_x(11), 576))
	put(r1, Vector2(col_x(16), 576))
	await frames(10)
	r0.facing = 1
	main.demo.give(r0, "estilingue")
	main.demo.use_item(r0)
	await frames(50)
	check(main.demo.bomb_holder == 1 and r0.item == "", "Batata: o estilingue arremessou a dinamite no rival (%d)" % main.demo.bomb_holder)
	main.demo.give(r1, "estilingue")
	r1.facing = 1
	main.demo.use_item(r1)
	await frames(90)
	check(main.demo.bomb_holder == 1, "Batata: estilingue que erra não passa a bomba (volta para quem jogou)")
	main.demo.give(r0, "escudo")
	main.demo.bomb_pass_cd = 0.0
	put(r1, r0.position + Vector2(20, 0))
	await frames(4)
	check(main.demo.bomb_holder == 1 and r0.fx_t["escudo"] > 0.0, "Batata: com o escudo, a bomba não passa para você")
	r0.fx_t["escudo"] = 0.0
	main.demo.give(r0, "patins")
	check(r0.fx_t["patins"] > 0.0, "patins ligam na hora")
	main.demo.bomb_fuse = 20.0
	main.demo.give(r0, "relogio")
	main.demo.use_item(r0)
	check(main.demo.bomb_holder == 1 and absf(main.demo.bomb_fuse - 17.0) < 0.1, "Batata: relógio de quem não tem a bomba encurta o pavio (%.1f)" % main.demo.bomb_fuse)
	main.demo.give(r1, "relogio")
	main.demo.use_item(r1)
	check(absf(main.demo.bomb_fuse - 21.0) < 0.1, "Batata: relógio de quem tem a bomba dá mais tempo (%.1f)" % main.demo.bomb_fuse)
	# Rei: laço tira o capacete do rei; onda de choque protege e depois empurra
	main.game_mode = "rei"
	main.arena_choice = "piramide"
	await demo_round()
	r0 = main.robots[0]
	r1 = main.robots[1]
	for r in [r0, r1]:
		r.invuln = 0.0
	put(r1, main.demo.crown_pos + Vector2(0, 2))
	await frames(4)
	check(main.demo.king == 1, "Rei: P2 é o rei")
	main.demo.king_grace = 0.0
	put(r0, r1.position + Vector2(-260, 0))
	await frames(4)
	r0.facing = 1
	main.demo.give(r0, "laco")
	main.demo.use_item(r0)
	await frames(2)
	check(main.demo.king == -1, "Rei: o laço puxou o rei e o capacete voou")
	await frames(30)
	check(absf(r1.position.x - r0.position.x) < 100.0, "Rei: o laço puxa o rival até colar em você (distância %.0f)" % absf(r1.position.x - r0.position.x))
	put(r0, r1.position + Vector2(-120, 0))
	await frames(4)
	main.demo.give(r0, "choque")
	main.demo.use_item(r0)
	await frames(3)
	var d1: float = r1.dmg
	check(r0.invuln > 1.0, "Rei: onda de choque deixa intocável enquanto carrega")
	r1.invuln = 0.0
	await frames(int(float(main.demo.item_cfg("choque")["espera_s"]) * 60.0) + 6)
	check(r1.dmg > d1, "Rei: e depois joga quem está perto longe")
	# Fuga: barreira larga caixotes atrás
	main.game_mode = "fuga"
	main.arena_choice = "torre"
	await demo_round()
	r0 = main.robots[0]
	var nb: int = main.level.blocks.size()
	main.demo.give(r0, "barreira")
	main.demo.use_item(r0)
	await frames(2)
	check(main.level.blocks.size() > nb, "Fuga: a barreira larga caixotes atrás (%d→%d)" % [nb, main.level.blocks.size()])
	await frames(30)
	r0.facing = 1
	main.demo.give(r0, "gancho")
	main.demo.use_item(r0)
	check(r0.item == "" and r0.velocity.y < -900.0, "Fuga: o gancho puxa para cima (vy %.0f item %s pos %s)" % [r0.velocity.y, r0.item, str(r0.position)])
	# itens aparecem em todas as fases da Batata (antes só nasciam em coluna com caixote)
	var sem := []
	for aid in main.demo.find_mode("batata")["arenas"]:
		main.arena_choice = aid
		await demo_round()
		main.demo.items.clear()
		main.demo.spawn_item("patins")
		if main.demo.items.is_empty():
			sem.append(aid)
	check(sem.is_empty(), "itens nascem em todas as fases da Batata (sem item: %s)" % str(sem))
	# Batata: a marreta quebra caixote (Obra de Concreto, pilha embaixo do buraco)
	main.game_mode = "batata"
	main.arena_choice = "obra_concreto"
	await demo_round()
	main.demo.bomb_next = 99.0
	var rr = main.robots[0]
	var nb0: int = main.level.blocks.size()
	put(rr, Vector2(5 * 64 + 22, 21 * 64 - 2))
	rr.facing = 1
	await frames(5)
	main.demo.attack(rr, "pesado")
	await frames(20)
	check(main.level.blocks.size() < nb0, "Batata: 1 marretada quebra o caixote (%d → %d)" % [nb0, main.level.blocks.size()])
	# lote 2a: itens novos da Batata
	main.game_mode = "batata"
	main.arena_choice = "demolicao"
	await demo_round()
	var a0 = main.robots[0]
	var a1 = main.robots[1]
	for rb in [a0, a1]:
		rb.invuln = 0.0
	main.demo.bomb_next = 99.0
	main.demo.bomb_holder = 0
	main.demo.bomb_fuse = 20.0
	put(a0, Vector2(col_x(11), 576))
	put(a1, Vector2(col_x(14), 576))
	await frames(5)
	main.demo.give(a0, "trocatroca")
	main.demo.use_item(a0)
	check(main.demo.bomb_holder == 1, "Troca-Troca: a bomba pulou para outro jogador")
	main.demo.give(a1, "apito")
	main.demo.use_item(a1)
	var f0: float = main.demo.bomb_fuse
	await frames(60)
	check(absf(main.demo.bomb_fuse - f0) < 0.01, "Apito do Juiz: o pavio fica parado")
	main.demo.apito_t = 0.0
	main.demo.give(a0, "corneta")
	main.demo.use_item(a0)
	check(a1.stun_t > 0.5, "Corneta: quem está perto fica tonto")
	await frames(70)
	main.demo.give(a0, "molabomba")
	main.demo.bomb_pass_cd = 0.0
	main.demo.pass_bomb(1, 0)
	check(main.demo.bomb_holder == 1, "Mola Anti-Bomba: a bomba quica de volta")
	a0.fx_t["molabomba"] = 0.0
	main.demo.give(a1, "banana")
	a1.facing = -1
	main.demo.use_item(a1)
	check(main.demo.traps.size() == 1, "Casca de Banana: fica no chão")
	main.demo.give(a0, "balao")
	put(a0, Vector2(col_x(11), 200))
	await frames(30)
	check(a0.velocity.y <= 141.0, "Balão: cai devagar (vy %.0f)" % a0.velocity.y)
	main.demo.give(a0, "fumaca")
	main.demo.use_item(a0)
	check(main.demo.clouds.size() == 1, "Bomba de Fumaça: nuvem no lugar")
	# lote 2b: itens novos do Rei
	main.game_mode = "rei"
	main.arena_choice = "demolicao"
	await demo_round()
	var k0 = main.robots[0]
	var k1 = main.robots[1]
	for rb in [k0, k1]:
		rb.invuln = 0.0
	put(k0, Vector2(col_x(11), 576))
	put(k1, Vector2(col_x(15), 576))
	await frames(5)
	main.demo.king = 1
	main.demo.king_grace = 0.0
	main.demo.king_hit[1] = k1.last_hit
	main.demo.give(k1, "armadura")
	k1.take_hit(-1, "marretada", 0)
	await frames(3)
	check(main.demo.king == 1, "Armadura: o rei aguenta 1 golpe sem perder o capacete")
	main.demo.king_grace = 0.0
	k1.invuln = 0.0
	put(k1, Vector2(col_x(15), 576))
	put(k0, Vector2(col_x(11), 576))
	k0.facing = 1
	await frames(10)
	main.demo.give(k0, "bumerangue")
	main.demo.use_item(k0)
	await frames(40)
	check(main.demo.king == -1, "Bumerangue: acertou o rei e o capacete caiu")
	await frames(60)
	put(k1, Vector2(col_x(15), 576))
	k1.invuln = 0.0
	await frames(5)
	main.demo.give(k0, "rede")
	main.demo.use_item(k0)
	await frames(25)
	check(main.demo.nets.size() == 1 and k1.stun_t > 0.5, "Lança-Rede: prende quem acertar")
	main.demo.give(k0, "capacetefalso")
	main.demo.use_item(k0)
	main.demo.give(k0, "cerca")
	main.demo.use_item(k0)
	check(main.demo.fakes.size() == 1 and main.demo.fences.size() == 1, "Capacete Falso e Cerca Elétrica aparecem")
	main.demo.king = -1
	main.demo.crown_pos = Vector2(col_x(20), 500)
	var d0: float = main.demo.crown_pos.distance_to(k0.position)
	main.demo.give(k0, "imacapacete")
	main.demo.use_item(k0)
	await frames(20)
	check(main.demo.king == 0 or main.demo.crown_pos.distance_to(k0.position) < d0 - 100.0, "Ímã de Capacete: o capacete vem até você")
	# lote 2c: itens novos da Fuga (mecânica testada no Canteiro)
	main.game_mode = "batata"
	main.arena_choice = "demolicao"
	await demo_round()
	main.demo.bomb_next = 99.0
	var f0r = main.robots[0]
	var f1r = main.robots[1]
	for rb in [f0r, f1r]:
		rb.invuln = 0.0
	put(f0r, Vector2(col_x(11), 576))
	put(f1r, Vector2(col_x(14), 576))
	f0r.facing = 1
	await frames(5)
	main.demo.give(f0r, "skate")
	main.demo.use_item(f0r)
	await frames(20)
	check(f1r.stun_t > 0.0 or absf(f1r.velocity.x) > 100.0 or f1r.position.x > col_x(14) + 40.0, "Skate: atropela quem está na frente")
	await frames(60)
	put(f0r, Vector2(col_x(11), 576))
	await frames(5)
	var x0: float = f0r.position.x
	main.demo.give(f0r, "chave_atalho")
	main.demo.use_item(f0r)
	check(f0r.position.x > x0 + 120.0, "Chave de Atalho: teletransporta para a frente (%.0f → %.0f)" % [x0, f0r.position.x])
	put(f0r, Vector2(col_x(11), 576))
	put(f1r, Vector2(col_x(9), 576))
	f0r.facing = 1
	await frames(5)
	main.demo.give(f0r, "ancora")
	main.demo.use_item(f0r)
	check(f1r.stun_t > 1.5, "Âncora: prende quem vem atrás")
	main.game_mode = "fuga"
	main.arena_choice = "torre"
	await demo_round()
	var fb = main.robots[0]
	main.demo.give(fb, "bolha")
	fb.invuln = 0.0
	fb.caught = true
	main.kill(fb, -1, null)
	await frames(2)
	check(fb.alive and fb.fx_t["bolha"] == 0.0, "Bolha Salva-Vidas: salva uma vez de ser pego pela tela")
	# mapa vivo: na Batata as alavancas se acionam sozinhas (portas trocam)
	main.game_mode = "batata"
	main.arena_choice = "obra_concreto"
	await demo_round()
	main.demo.bomb_next = 99.0
	var doors0: Array = main.level.doors.keys().map(func(c): return main.level.ch_at(c))
	main.demo.auto_lever_t = 0.05
	await frames(10)
	var doors1: Array = main.level.doors.keys().map(func(c): return main.level.ch_at(c))
	check(doors0 != doors1, "Batata: alavanca automática troca as portas sozinha")
	# ▼ em cima de tábua fina: desce por ela (Galerias da Mina, saída do alto da rocha)
	main.game_mode = "batata"
	main.arena_choice = "galerias_mina"
	await demo_round()
	r0 = main.robots[0]
	main.demo.bomb_next = 99.0
	put(r0, Vector2(9 * 64 + 32, 6 * 64 - 2))
	await frames(20)
	var y0: float = r0.position.y
	PlayerInput.virtual["v0"] = {"down": true}
	await frames(40)
	PlayerInput.virtual["v0"] = {}
	check(r0.position.y > y0 + 100.0, "▼ na tábua fina: o robô desce por ela (%.0f → %.0f)" % [y0, r0.position.y])
	main.arena_choice = "demolicao"
	main.game_mode = "derruba"

func eventos_test() -> void:
	print("== Eventos")
	main.mode = "demolicao"
	main.arena_choice = "demolicao"
	main.game_mode = "derruba"
	main.demo.lives_setting = 1
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
	check(main.level.id != "oficina" and main.robots.size() == 3 and main.sandbox, "painel: trocar de arena mantém todos")
	await tap("v0", "start")
	ofi.sel = ofi.ROWS.find("sair")
	await tap("v0", "jump")
	check(main.state == S.MENU and not main.sandbox and not main.paused and Engine.time_scale == 1.0, "SAIR DA OFICINA volta ao menu")

## ROBÔS: 8 modelos só de aparência; ▲▼ na entrada passa por todos e volta; cada modelo tem arte completa e desmonta.
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
	main.demo.item_t = 999.0
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
	check(absf(r1.dmg - 50.0 - float(am["rapido"]["dano"])) < 0.1, "golpe rápido acerta e soma %d%% (%.0f%%)" % [int(am["rapido"]["dano"]), r1.dmg])
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
	for k in 2:
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
	lab.sel = lab.rows().find("sair")
	await tap("v0", "jump")
	check(main.state == S.MENU and not main.lab_mode and not main.sandbox, "SAIR volta ao menu")
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
	main.lab.sel = main.lab.rows().find("num12")
	main.lab.scroll = main.lab.sel - 4
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
	main.demo.item_t = 999.0
	var ct = main.demo.canteiro
	check(ct != null and main.level.id == "canteiro_obras" and ct.standing() == 9, "Canteiro monta laje (6), andaimes (2) e viga (%s)" % [ct.standing() if ct != null else -1])
	ct.cycle_t = 999.0
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
	# núcleo nunca cai
	var nuc = ct.parts[2]
	for k in 20:
		ct.damage(nuc, 99, nuc["rect"].get_center())
	await frames(90)
	check(not nuc["fallen"], "o núcleo (trechos do meio) nunca cai")
	# golpe rápido não danifica
	await demo_round()
	ct = main.demo.canteiro
	ct.cycle_t = 999.0
	r0 = main.robots[0]
	put(r0, Vector2(col_x(26), 13 * 64))
	r0.facing = 1
	await frames(2)
	await tap("v0", "hammer")
	await frames(20)
	check(ct.parts[4]["hp"] == ct.parts[4]["max"] and ct.parts[5]["hp"] == ct.parts[5]["max"], "golpe rápido não danifica a laje")
	# ciclo da obra: aviso e depois o alvo cede
	ct.cycle_t = 0.0
	await frames(3)
	var alvo = ct.target
	check(ct.cycle_state == "aviso" and alvo != null and not alvo["nucleo"] and alvo["warn_t"] > 0.0, "ciclo da obra marca um trecho com aviso (sirene + fita)")
	await frames(int((float(ct.cfg["aviso_ciclo_s"]) + float(ct.cfg["aviso_queda_s"])) * 60.0) + 20)
	check(alvo != null and alvo["fallen"] and ct.cycle_state == "calma", "depois do aviso, o alvo do ciclo cede e volta a calma")
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
	await heavy_hit("v0")
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
	var crumble0 = main.demo.cfg["crumble_break_s"]
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
	main.demo.item_t = 999.0
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
	main.demo.item_t = 999.0
	var ct = main.demo.canteiro
	var r0 = main.robots[0]
	var r1 = main.robots[1]
	var r2 = main.robots[2]
	put(r0, Vector2(col_x(10), 13 * 64))
	put(r1, Vector2(col_x(22), 13 * 64))
	put(r2, Vector2(col_x(18), 13 * 64))
	r0.facing = 1
	ct.cycle_t = 999.0
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
			ct.cycle_t = 0.0   # ciclo da obra agora (sirene + fita zebrada)
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
## Sequência de quadros de cada item novo (vira GIF): --gifs=DIR,item1,item2...
func gifs_frames(arg: String) -> void:
	var parts := arg.split(",")
	var dir := parts[0]
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.mode = "demolicao"
	main.event_level = 0
	main.arena_choice = "demolicao"
	main.game_mode = "batata"
	main.start_match()
	for k in range(1, parts.size()):
		var kind := parts[k]
		var rei: bool = kind in ["armadura", "capacetefalso", "cerca", "bumerangue", "rede", "imacapacete"]
		main.game_mode = "rei" if rei else "batata"
		await demo_round()
		main.demo.item_t = 999.0
		main.demo.bomb_next = 99.0
		var r0 = main.robots[0]
		var r1 = main.robots[1]
		for rb in [r0, r1]:
			rb.invuln = 0.0
		put(r0, Vector2(col_x(11), 576))
		put(r1, Vector2(col_x(15), 576))
		r0.facing = 1
		r1.facing = -1
		main.demo.bomb_holder = 0
		main.demo.bomb_fuse = 9.0
		await frames(10)
		if rei:
			main.demo.king = -1 if kind == "imacapacete" else 1
			main.demo.king_grace = 0.0
			main.demo.king_hit[1] = r1.last_hit
			if kind == "imacapacete":
				main.demo.crown_pos = Vector2(col_x(17), 500)
		match kind:
			"armadura":
				main.demo.give(r1, "armadura")
				put(r0, Vector2(col_x(14), 576))
				await frames(15)
				main.demo.attack(r0, "pesado")
			"molabomba":
				main.demo.give(r1, "molabomba")
				await frames(10)
				vset("v0", "right", true)
			"banana", "isca":
				r0.facing = -1
				put(r0, Vector2(col_x(13), 576))
				put(r1, Vector2(col_x(17), 576))
				await frames(4)
				main.demo.give(r0, kind)
				await frames(2)
				main.demo.use_item(r0)
				await frames(15)
				vset("v1", "left", true)
			"balao":
				main.demo.give(r0, "balao")
				put(r0, Vector2(col_x(12), 150))
			_:
				main.demo.give(r0, kind)
				await frames(8)
				main.demo.use_item(r0)
		for f in 30:
			await frames(3)
			await snap(dir, "%s_%03d" % [kind, f])
		vset("v0", "right", false)
		vset("v1", "left", false)

## Fotos dos itens dos modos (Batata, Rei, Fuga) em ação.
func itens2_frames(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	get_window().size = Vector2i(1920, 1080)
	PlayerInput.virtual = {"v0": {}, "v1": {}}
	await frames(2)
	await tap("v0", "jump")
	await tap("v1", "jump")
	main.mode = "demolicao"
	main.event_level = 0
	main.arena_choice = "demolicao"
	main.game_mode = "batata"
	main.start_match()
	for pl in [["estilingue", 12], ["laco", 9], ["gancho", 10], ["choque", 50], ["choque_estouro", 104], ["relogio", 10], ["escudo", 30], ["patins", 24], ["barreira", 6]]:
		var kind: String = pl[0]
		await demo_round()
		main.demo.item_t = 999.0
		main.demo.bomb_next = 99.0
		main.demo.auto_lever_t = 999.0
		var r0 = main.robots[0]
		var r1 = main.robots[1]
		put(r0, Vector2(col_x(10), 576))
		put(r1, Vector2(col_x(15), 576))
		r0.facing = 1
		r1.facing = -1
		main.cam_lock = [1.5, Vector2(col_x(13), 450)]
		await frames(3)
		if kind in ["estilingue", "relogio"]:
			main.demo.bomb_holder = 0
			main.demo.bomb_fuse = 20.0
		var k2: String = "choque" if kind == "choque_estouro" else kind
		if kind == "patins":
			main.demo.give(r0, "patins")
			vset("v0", "right", true)
		else:
			main.demo.give(r0, k2)
			await frames(1)
			main.demo.use_item(r0)
		await frames(int(pl[1]))
		await snap(dir, "item2_" + kind)
		vset("v0", "right", false)

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
