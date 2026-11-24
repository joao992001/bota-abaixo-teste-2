extends Node2D
## Partida: MENU → MODO → ARENA → AJUSTES → ENTRADA → RODADA → PLACAR → (próxima rodada | VITÓRIA).
## Regras de cada modo em modes/demolicao.gd + data/modos.json (modos: derruba, batata, rei, fuga).
## Debug: F1 hitboxes/info · F2 pula fase · F5 jogador parado · F6 câmera lenta.

const Level := preload("res://level/level.gd")
const Background := preload("res://level/background.gd")
const Robot := preload("res://player/robot.gd")
const Hud := preload("res://ui/hud.gd")
const Debris := preload("res://fx/debris.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const Demolicao := preload("res://modes/demolicao.gd")
const Bots := preload("res://modes/bots.gd")
const Menus := preload("res://ui/menus.gd")
const Eventos := preload("res://modes/eventos.gd")
const Oficina := preload("res://ui/oficina.gd")
const Laboratorio := preload("res://ui/laboratorio.gd")
const T := 64

enum S { JOIN, RUN, SCORE, WIN, MENU, MODES, HOWTO, OPTIONS, ARENAS, AJUSTES, EVENTOS, CONTROLES, INTRO, CONFIGPAD }
var state := S.INTRO   # abre com a intro animada (os testes pulam direto para a entrada)
var paused := false
const MENU_STATES := [S.MENU, S.MODES, S.HOWTO, S.OPTIONS, S.ARENAS, S.AJUSTES, S.EVENTOS, S.CONTROLES, S.INTRO, S.CONFIGPAD]
var sandbox := false          # OFICINA: ambiente de testes (respawn infinito, rodada sem fim)
var oficina: Node = null
var lab: Node = null
var lab_mode := false        # LABORATÓRIO (uma Oficina de medição/calibragem)
var perf_acc := {}             # tempo gasto por parte (medição --perf)
var lost_pads: Array = []      # jogadores cujo controle desconectou no meio da partida (índices)
var timer := 0.0
var round_no := 0
var players: Array = []      # {dev, color, score, piece, sel, unlock, cursor, ghost, placed, rep}
var robots: Array = []
var finish_order: Array = []
var countdown := 0.0
var end_delay := -1.0
var winner := -1
var debug := false
var floaters: Array = []     # textos flutuantes {pos, text, color, t}
var puffs: Array = []        # poeira {pos, t, r}
var impacts: Array = []      # estouro de impacto dos golpes {pos, dir, s, t, rot}
var sparks: Array = []       # estrelinhas {pos, vel, t, rot}
var shake_amt := 0.0
var shake_on := true          # OPÇÕES > tremor da tela
var door_open := 0.0
var mode := "demolicao"      # motor das partidas (o modo de jogo escolhido fica em game_mode)
var demo: Node
var events: Node2D = null   # eventos dinâmicos (modes/eventos.gd)
var bots: Node
var menus: Node
var fall_log: Array = []
var self_falls := 0          # quedas sem ter levado golpe nos últimos 2 s (bots: deve ficar perto de 0)
var arena_choice := "sorteio"
var game_mode := "derruba"       # modo escolhido no menu: derruba, batata, rei, fuga (data/modos.json → modos)
var event_level := 2             # AJUSTES: 0 desligados, 1 poucos, 2 normal, 3 caos   # arena da Demolição: "sorteio" ou o id do .lvl
var bot_level := 1            # 0 fácil, 1 médio, 2 difícil (M na entrada)
var match_over := false
var cam_lock: Array = []      # [zoom, centro] fixa a câmera (capturas de animação)

var world: Node2D
var level: Level
var bg: Background
var bg_layer: CanvasLayer
var camera: Camera2D
var robots_root: Node2D
var overlay: Node2D
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
	events = Eventos.new()
	events.setup(self)
	world.add_child(events)
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
	demo = Demolicao.new()
	demo.setup(self)
	add_child(demo)
	bots = Bots.new()
	bots.setup(self)
	add_child(bots)
	menus = Menus.new()
	menus.setup(self)
	add_child(menus)
	oficina = Oficina.new()
	oficina.setup(self)
	add_child(oficina)
	lab = Laboratorio.new()
	lab.setup(self)
	add_child(lab)
	lab.load_saved()   # ajustes salvos no Laboratório valem no jogo todo
	PlayerInput.pad_changed.connect(_on_pad_changed)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--autotest" or a.begins_with("--shot") or a.begins_with("--anim") or a.begins_with("--demo") or a.begins_with("--menus") or a.begins_with("--arenas") or a.begins_with("--video") or a.begins_with("--stats") or a.begins_with("--perf") or a.begins_with("--itens") or a.begins_with("--oficina") or a.begins_with("--parede") or a.begins_with("--intro") or a.begins_with("--maquete") or a.begins_with("--robos") or a.begins_with("--combate") or a.begins_with("--lab") or a.begins_with("--espiar"):
			state = S.JOIN   # testes e capturas começam direto na entrada de jogadores
			var scr: GDScript = load("res://tests/driver.gd")
			if scr == null or not scr.can_instantiate():
				push_error("driver de testes não compilou")
				get_tree().quit(3)   # não fica parado esperando
				return
			var drv: Node = scr.new()
			drv.main = self
			add_child(drv)
			break
	if state == S.MENU:
		load_arena("demolicao")
		load_options()

## Opções salvas no computador (user://opcoes.cfg).
## Controle conectou/desconectou. Na entrada, quem perdeu o controle sai; na partida, o jogo pausa
## até o controle voltar (o mesmo, ou qualquer outro livre apertando START/PULAR).
func _on_pad_changed(dev: String, connected: bool) -> void:
	var i: int = PlayerInput.slots.find(dev)
	if connected:
		if i >= 0:
			lost_pads.erase(i)
		return
	if i < 0:
		return
	if state == S.JOIN:
		players.remove_at(i)
		PlayerInput.slots.remove_at(i)
	elif state in [S.RUN, S.SCORE, S.WIN]:
		if not (i in lost_pads):
			lost_pads.append(i)
		if state != S.WIN:
			paused = true
			menus.pause_sel = 0

# ---------------------------------------------------------------- oficina / laboratório (testes)
## Quem cuida do modo de testes atual: o Laboratório ou a Oficina (mesmo jeito de usar: painel, tick, desenho).
func tester() -> Node:
	return lab if lab_mode else oficina

## Outro dispositivo apertou PULAR na Oficina: entra na hora.
func _sandbox_join() -> void:
	if players.size() >= 4:
		return
	for dev in PlayerInput.all_devices():
		if dev in PlayerInput.slots or dev.begins_with("bot") or dev.begins_with("boneco") or PlayerInput.aliases.has(dev):
			continue
		if PlayerInput.dev_pressed(dev, "jump") and PlayerInput.twin_of(dev) == "":
			add_player(dev)
			_spawn_robot_for(players.size() - 1)
			return

## Robô novo no meio da rodada (Oficina): aparece pelo guindaste.
func _spawn_robot_for(i: int) -> void:
	var r: CharacterBody2D = Robot.new()
	r.setup(i, players[i]["color"], self, players[i]["model"])
	r.position = level.spawns.get(1, Vector2(960, 300))
	robots_root.add_child(r)
	robots.append(r)
	r.active = true
	r.hammer_left = 999
	demo.respawn(r)

## Oficina: adiciona boneco de treino (fica parado, apanha) ou bot.
func sandbox_add(kind: String) -> void:
	if players.size() >= 4:
		Audio.play("menu_negado")
		return
	if kind == "bot":
		add_bot()
	else:
		var n := 0
		while PlayerInput.virtual.has("boneco%d" % n):
			n += 1
		var dev := "boneco%d" % n
		PlayerInput.virtual[dev] = {}
		add_player(dev)
		players[-1]["boneco"] = true
	_spawn_robot_for(players.size() - 1)
	Audio.play("menu_ok")

## Tira o último boneco/bot (só se for o último da lista, para não embaralhar os jogadores).
func sandbox_remove(kind: String) -> void:
	if players.size() <= 1 or not players[-1].get(kind, false):
		Audio.play("menu_negado")
		return
	var i := players.size() - 1
	PlayerInput.virtual.erase(players[i]["dev"])
	players.remove_at(i)
	PlayerInput.slots.remove_at(i)
	if i < robots.size():
		robots[i].queue_free()
		robots.remove_at(i)
	Audio.play("menu_voltar")

## Enquanto falta controle: um controle livre que apertar START ou PULAR assume o jogador.
func _reassign_lost_pads() -> bool:
	if lost_pads.is_empty():
		return false
	for dev in PlayerInput.all_devices():
		if dev in PlayerInput.slots or PlayerInput.is_keyboard(dev) or dev.begins_with("bot") or PlayerInput.aliases.has(dev):
			continue
		if PlayerInput.dev_pressed(dev, "start") or PlayerInput.dev_pressed(dev, "jump"):
			var i: int = lost_pads.pop_front()
			PlayerInput.slots[i] = dev
			players[i]["dev"] = dev
			PlayerInput.toasts.append({"text": "P%d agora joga com %s" % [i + 1, PlayerInput.pad_name(dev)], "t": 0.0, "ok": true, "dev": dev})
			Audio.play("menu_ok")
			return true
	return false

func save_options() -> void:
	var cf := ConfigFile.new()
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	cf.set_value("opcoes", "tela_cheia", full)
	cf.set_value("opcoes", "tremor", shake_on)
	cf.set_value("opcoes", "bots", bot_level)
	cf.set_value("opcoes", "musica", Audio.music_vol)
	cf.set_value("opcoes", "efeitos", Audio.sfx_vol)
	cf.set_value("opcoes", "vibracao", PlayerInput.vibration)
	cf.save("user://opcoes.cfg")

func load_options() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://opcoes.cfg") != OK:
		return
	shake_on = cf.get_value("opcoes", "tremor", true)
	bot_level = cf.get_value("opcoes", "bots", 1)
	PlayerInput.vibration = cf.get_value("opcoes", "vibracao", true)
	Audio.set_volumes(cf.get_value("opcoes", "musica", 6), cf.get_value("opcoes", "efeitos", 8))
	if not cf.get_value("opcoes", "tela_cheia", true):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## Volta ao menu principal: sem jogadores, arena da Demolição ao fundo.
func go_menu() -> void:
	if sandbox:
		tester().stop()
		sandbox = false
	paused = false
	lost_pads.clear()
	events.reset_round()
	_clear_robots()
	players.clear()
	PlayerInput.slots.clear()
	for k in PlayerInput.virtual.keys():
		if String(k).begins_with("bot"):
			PlayerInput.virtual.erase(k)
	if level.id != "demolicao":
		load_arena("demolicao")
	state = S.MENU

func go_join() -> void:
	state = S.JOIN

func player_color(p: int) -> Color:
	if p >= 0 and p < players.size():
		return Data.COLORS[players[p]["color"]]
	return Data.COLORS[clampi(p, 0, 3)]

# ---------------------------------------------------------------- loop
## Música de cada tela.
func _update_music() -> void:
	var tense := false
	match state:
		S.WIN: Audio.music("vitoria", false)
		S.RUN, S.SCORE:
			var nm := "partida"
			if mode == "demolicao" and demo.arena.has("musica"):
				nm = String(demo.arena["musica"])   # cada família de arena tem sua música
				tense = state == S.RUN and (demo.quaking
					or (demo.rule() == "batata" and demo.bomb_holder >= 0 and demo.bomb_fuse < 3.0)
					or (demo.fx != null and is_instance_valid(demo.fx) and demo.fx.scroll_on and demo.t > 20.0))
			Audio.music(nm)
		_: Audio.music("menu")
	Audio.music_tempo(1.03 if tense else 1.0, 1.0 / 60.0)   # tensão: a música acelera um pouquinho

func _physics_process(dt: float) -> void:
	_update_music()
	if _reassign_lost_pads():
		return   # o START que assumiu o controle não conta como "continuar"
	if paused:
		if sandbox and tester().open:
			tester().update()
		else:
			menus.update_pause()
		hud.queue_redraw()
		overlay.queue_redraw()
		return
	if state in [S.RUN, S.SCORE]:
		for i in players.size():
			if sandbox and not players[i].get("bot", false) and PlayerInput.pressed(i, "start"):
				tester().toggle()   # na Oficina/Laboratório, START abre o painel de testes
				return
			if not players[i].get("bot", false) and PlayerInput.pressed(i, "start"):
				paused = true
				menus.pause_sel = 0
				Audio.play("menu_ok")
				return
	if state in MENU_STATES:
		menus.update(dt)
	world.visible = not (state in MENU_STATES)   # nos menus aparece o cenário próprio do menu, não o mapa
	match state:
		S.JOIN: _join_update()
		S.RUN:
			if sandbox:
				tester().tick()
				_sandbox_join()
			var t0 := Time.get_ticks_usec()
			bots.update(dt)
			var t1 := Time.get_ticks_usec()
			demo.update(dt)
			perf_acc["bots"] = perf_acc.get("bots", 0.0) + (t1 - t0) / 1000.0
			perf_acc["demo"] = perf_acc.get("demo", 0.0) + (Time.get_ticks_usec() - t1) / 1000.0
			_run_update(dt)
		S.SCORE:
			timer -= dt
			if timer <= 0.0:
				_after_score()
		S.WIN:
			if menus.pressed("back"):
				go_menu()
			else:
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
	for im in impacts:
		im["t"] += dt
	impacts = impacts.filter(func(x): return x["t"] < 0.2)
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
	var lw: float = level.cols * 64.0
	var lh: float = level.rows * 64.0
	var zmin := minf(1.0, minf(1920.0 / lw, 1024.0 / lh))   # mapa maior que a tela: pode afastar um pouco
	var zfloor := maxf(zmin, 0.72)                          # ...mas não muito (a câmera rola)
	var tz := zmin
	var tc := Vector2(lw, lh) / 2.0
	if state in MENU_STATES:
		tz = 1.25
		tc = Vector2(1000, 470)
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
			tz = clampf(minf(1920.0 / box.size.x, 1024.0 / box.size.y), zfloor, CAM_MAX)
			tc = box.get_center()
		else:
			tz = cam_zoom
			tc = cam_center
		tz = zmin   # arena inteira na tela, sempre (pedido: ver tudo, mesmo com poucos jogadores)
		tc = Vector2(lw, lh) / 2.0
		if demo != null and demo.fx != null and is_instance_valid(demo.fx) and demo.fx.scroll_on:
			# câmera que rola: a arena manda (Torre sobe, Ponte avança); quem sai da tela está fora
			tz = demo.fx.scroll_zoom
			tc = demo.fx.scroll_center
	var k := 1.0 - exp(-dt * 3.0)
	if cam_lock.size() == 2:
		tz = cam_lock[0]
		tc = cam_lock[1]
		k = 1.0
	cam_zoom = lerpf(cam_zoom, tz, k)
	cam_center = cam_center.lerp(tc, k)
	var hw := 960.0 / cam_zoom
	var hh := 512.0 / cam_zoom
	cam_center.x = clampf(cam_center.x, hw, lw - hw) if lw > hw * 2.0 else lw / 2.0
	cam_center.y = clampf(cam_center.y, hh, lh - hh) if lh > hh * 2.0 else lh / 2.0
	camera.zoom = Vector2(cam_zoom, cam_zoom)
	camera.position = cam_center + Vector2(0, Data.ARENA_Y) - Vector2(0, 28) / cam_zoom
	shake_amt = move_toward(shake_amt, 0.0, dt * 40.0)
	camera.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amt
	# fundo em paralaxe (camada própria, move menos que o mundo)
	var zb := 1.0 + (cam_zoom - 1.0) * 0.4
	var bc := Vector2(960, 540) + (cam_center - Vector2(960, 512)) * 0.5
	if lw > 1920.0 or lh > 1024.0:
		# mapa grande: o fundo fica um pouco ampliado e rola uma fração do caminho
		zb = maxf(zb, 1.15)
		var rel := Vector2((cam_center.x - hw) / maxf(lw - hw * 2.0, 1.0), (cam_center.y - hh) / maxf(lh - hh * 2.0, 1.0))
		rel = rel.clamp(Vector2.ZERO, Vector2.ONE)
		bc = Vector2(960, 540) + (rel - Vector2(0.5, 0.5)) * Vector2(1920, 1080) * (1.0 - 1.0 / zb)
	zb = maxf(zb, 1.0)
	bc.x = clampf(bc.x, 960.0 / zb, 1920.0 - 960.0 / zb)
	bc.y = clampf(bc.y, 540.0 / zb, 1080.0 - 540.0 / zb)
	bg_layer.scale = Vector2(zb, zb)
	bg_layer.offset = Vector2(960, 540) - bc * zb

## Retângulo do mundo que a câmera mostra agora.
func view_rect() -> Rect2:
	var hw := 960.0 / cam_zoom
	var hh := 512.0 / cam_zoom
	return Rect2(cam_center - Vector2(hw, hh), Vector2(hw, hh) * 2.0)

func to_screen(p: Vector2) -> Vector2:
	return (p + world.position - camera.position) * cam_zoom + Vector2(960, 540)

# ---------------------------------------------------------------- entrada
func _join_update() -> void:
	var devs: Array = PlayerInput.all_devices()
	devs.sort_custom(func(a, b): return PlayerInput.is_known(a) and not PlayerInput.is_known(b))   # reconhecidos primeiro
	for dev in devs:
		if dev in PlayerInput.slots or not PlayerInput.dev_pressed(dev, "jump"):
			continue
		if PlayerInput.aliases.has(dev):
			# gêmeo apertou sozinho: era um controle de verdade, libera para entrar no próximo aperto
			if PlayerInput.twin_of(dev) == "":
				PlayerInput.aliases.erase(dev)
			continue
		var twin := PlayerInput.twin_of(dev)
		if twin != "":
			PlayerInput.aliases[dev] = twin
			continue
		if players.size() < 4:
			add_player(dev)
	for i in range(players.size() - 1, -1, -1):
		if PlayerInput.pressed(i, "back"):
			players.remove_at(i)
			PlayerInput.slots.remove_at(i)
	if players.is_empty() and menus.pressed("back"):
		state = S.MODES
	for i in players.size():
		if PlayerInput.pressed(i, "left"):
			_cycle_color(i, -1)
		if PlayerInput.pressed(i, "right"):
			_cycle_color(i, 1)
		if PlayerInput.pressed(i, "up"):
			cycle_robot(i, -1)
		if PlayerInput.pressed(i, "down"):
			cycle_robot(i, 1)
		if PlayerInput.pressed(i, "heavy") and not PlayerInput.held(i, "back") and not players[i].get("bot", false):
			# Y/△ (marretada pesada): adiciona bot; com a mesa cheia, tira os bots
			if players.size() < 4:
				add_bot()
			else:
				while players.size() > 0 and players[-1].get("bot", false):
					remove_last_bot()
			break
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
	players.append({"dev": dev, "color": col, "model": players.size() % Data.MODELS.size(), "score": 0,
		"stats": {"derrubadas": 0, "caixotes": 0, "quedas": 0}})
	Audio.voice("voz_oi", players[-1]["model"])
	PlayerInput.slots.append(dev)

## ▲▼ na entrada: passa pelos 8 modelos de robô (sempre na cor do jogador).
func cycle_robot(i: int, d: int) -> void:
	players[i]["model"] = posmod(int(players[i]["model"]) + d, Data.MODELS.size())
	Audio.voice("voz_oi", players[i]["model"])

func _cycle_color(i: int, d: int) -> void:
	var used := players.map(func(p): return p["color"])
	var col: int = players[i]["color"]
	for _k in 4:
		col = posmod(col + d, 4)
		if not (col in used):
			players[i]["color"] = col
			return

## Troca a fase em jogo (arena nova, caixotes inteiros).
func load_arena(id: String) -> void:
	level.queue_free()
	level = Level.new()
	world.add_child(level)
	world.move_child(level, 0)
	level.load_level(id)
	bg.set_theme(level.theme)
	bg.modulate = bg_tint()

## Tom do fundo: o Canteiro aceita o tom do mapa ("fundo:" no .lvl); os temas usam a própria imagem.
func bg_tint() -> Color:
	var tint: String = level.prop("fundo", "")
	return Color(tint) if tint != "" and level.theme == "canteiro" else Color.WHITE

## Cor do Amassômetro: branco → amarelo → laranja → vermelho.
func dmg_color(d: float) -> Color:
	if d < 50.0:
		return Color("#ffffff").lerp(Color("#f2c84b"), d / 50.0)
	if d < 100.0:
		return Color("#f2c84b").lerp(Color("#f08a3d"), (d - 50.0) / 50.0)
	return Color("#f08a3d").lerp(Color("#d42035"), clampf((d - 100.0) / 60.0, 0.0, 1.0))

func start_match() -> void:
	lost_pads.clear()
	for p in players:
		p["score"] = 0
		p["stats"] = {"derrubadas": 0, "caixotes": 0, "quedas": 0}
	match_over = false
	round_no = 0
	winner = -1
	_demo_next_round()

# ---------------------------------------------------------------- escolha
# ---------------------------------------------------------------- construção
# ---------------------------------------------------------------- corrida
## Caixote quebrado: tábuas e lascas voando.
func break_crate(center: Vector2) -> void:
	var parts := []
	var plank := Data.tex("cenario/tabua")
	var crate := Data.tex("cenario/caixote_0")
	for k in 4:
		parts.append({"tex": [plank], "rect": Rect2(Vector2(-16 + (k % 2) * 16, -16 + (k / 2) * 20), Vector2(28, 8)), "mod": Color.WHITE})
	for k in 2:
		parts.append({"tex": [crate], "rect": Rect2(Vector2(-12 + k * 14, -6), Vector2(18, 18)), "mod": Color.WHITE})
	var d: Node2D = Debris.new()
	d.setup(parts, center, 1, Vector2.ZERO)
	world.add_child(d)

func _clear_robots() -> void:
	for r in robots:
		r.queue_free()
	robots.clear()

func _demo_next_round() -> void:
	round_no += 1
	bots.reset()
	_clear_robots()
	demo.start_round()

func start_run() -> void:
	start_run_at([1, 2, 3, 4])

## Corrida/rodada com os robôs nos spawns indicados (um por jogador, na ordem).
func start_run_at(spots: Array) -> void:
	_clear_robots()
	state = S.RUN
	timer = 0.0
	countdown = 1.5
	end_delay = -1.0
	finish_order = []
	for i in players.size():
		var r: CharacterBody2D = Robot.new()
		r.setup(i, players[i]["color"], self, players[i]["model"])
		r.position = level.spawns.get(int(spots[i]) if i < spots.size() else i + 1, level.spawns[1])
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
			state = S.SCORE
			timer = float(demo.cfg["score_seconds"])
			match_over = demo.end_round()

func check_contacts(r: CharacterBody2D) -> void:
	if state != S.RUN or not r.alive or r.finished:
		return
	var rr: Rect2 = r.rect()
	for h in level.hazard_rects:
		if rr.intersects(h):
			kill(r, -1, null)
			return
	if level.elevator_cell != Vector2i(-1, -1) and demo.rule() == "fuga" and rr.intersects(level.goal_rect):
		finish(r)   # Fuga: chegou ao elevador primeiro
	elif r.position.y > level.rows * T + 100:
		kill(r, -1, null)

func kill(r: CharacterBody2D, owner: int, pc: Node2D) -> void:
	if not r.alive or r.finished:
		return
	if r.last_hit > 2.0 and r.fall_reason == "":
		self_falls += 1
	if r.last_hit > 2.0:
		fall_log.append("P%d %s %s" % [r.pid + 1, str(Vector2i(r.position / 64.0)), r.fall_reason if r.fall_reason != "" else "andou"])
		if r.has_meta("takeoff"):
			print("    QUEDA P%d — saiu do chão: %s" % [r.pid + 1, r.get_meta("takeoff")])
	if true:
		var cause: String = r.last_cause if r.last_hit <= 2.5 or r.last_cause == "ficou parado" or r.last_cause == "lama" else "caiu sozinho"
		if cause == "":
			cause = "caiu sozinho"
		var by: int = r.last_attacker if r.last_hit <= 2.5 else -1
		demo.death_log.append({"arena": demo.arena.get("id", ""), "t": demo.t, "victim": r.pid, "cause": cause,
			"by": by, "round": round_no})
		if by >= 0 and by != r.pid and by < players.size():
			players[by]["stats"]["derrubadas"] += 1
			demo.feed.append({"text": "P%d derrubou P%d" % [by + 1, r.pid + 1], "col": by, "t": 0.0})
			demo.on_knockout(by, r.pid)
		else:
			players[r.pid]["stats"]["quedas"] += 1
			demo.feed.append({"text": "P%d %s" % [r.pid + 1, "caiu sozinho" if cause == "caiu sozinho" else "caiu (%s)" % cause], "col": r.pid, "t": 0.0})
			demo.on_knockout(-1, r.pid)
		if demo.intercept_kill(r):
			return
	r.eliminate()

func finish(r: CharacterBody2D) -> void:
	r.finish()
	finish_order.append(r.pid)
	float_text(r.position + Vector2(0, -100), "1º!" if finish_order.size() == 1 else "%dº" % finish_order.size(), player_color(r.pid))

func use_item(r: CharacterBody2D) -> void:
	demo.use_item(r)

## Bot entra como jogador com dispositivo virtual (o cérebro em modes/bots.gd aperta os botões).
func add_bot() -> void:
	if players.size() >= 4:
		return
	var n := 1
	while ("bot%d" % n) in PlayerInput.slots:
		n += 1
	var dev := "bot%d" % n
	PlayerInput.virtual[dev] = {}
	add_player(dev)
	players[-1]["bot"] = true
	players[-1]["level"] = bot_level
	players[-1]["model"] = rng.randi() % Data.MODELS.size()

func remove_last_bot() -> void:
	for i in range(players.size() - 1, -1, -1):
		if players[i].get("bot", false):
			PlayerInput.virtual.erase(players[i]["dev"])
			players.remove_at(i)
			PlayerInput.slots.remove_at(i)
			return

## Bloco de números de data/controller.json (testes e ferramentas).
func c_ctrl(key: String) -> Dictionary:
	return Data.ctrl[key]

## Impacto de um golpe ("rapido" ou "pesado"). true = acertou um robô.
func try_attack(r: CharacterBody2D, kind: String) -> bool:
	return demo.attack(r, kind)

func danger_near(r: CharacterBody2D) -> bool:
	var c: Vector2 = r.rect().get_center()
	for h in level.hazard_rects:
		if h.get_center().distance_to(c) < 1.3 * T:
			return true
	return false

# ---------------------------------------------------------------- placar
func _after_score() -> void:
	if match_over:
		winner = demo.round_winner
		state = S.WIN
		_clear_robots()
	else:
		_demo_next_round()

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

## Estouro de impacto do golpe (estrela serrilhada branca/amarela + anel). s = força (0,5 rápido, 1 pesado).
func impact_fx(pos: Vector2, dir: int, s: float) -> void:
	impacts.append({"pos": pos, "dir": dir, "s": s, "t": 0.0, "rot": rng.randf_range(0, TAU)})

## Anel de ar (pulo duplo, recuperou o equilíbrio no ar).
func ring_fx(pos: Vector2, s: float) -> void:
	impacts.append({"pos": pos, "dir": 0, "s": s, "t": 0.0, "rot": 0.0, "ring": true})

## Parafuso que pula do robô quando ele passa de um estágio de amassado.
func pop_bolt(pos: Vector2, dir: int) -> void:
	var d: Node2D = Debris.new()
	d.setup([{"tex": [Data.tex("robo/parafuso")], "rect": Rect2(-6, -6, 12, 12), "mod": Color.WHITE}], pos, dir, Vector2(dir * 140.0, -260.0))
	world.add_child(d)

## Tremor leve de câmera (desligável nas OPÇÕES).
func shake(amount: float) -> void:
	if shake_on:
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
	for im in impacts:
		var k: float = im["t"] / 0.2
		var e := 1.0 - pow(1.0 - k, 3.0)
		if im.get("ring", false):
			var rr2: float = (20.0 + 40.0 * e) * float(im["s"])
			overlay.draw_set_transform(im["pos"], 0.0, Vector2(1.0, 0.38))
			overlay.draw_arc(Vector2.ZERO, rr2, 0, TAU, 28, Color(1, 1, 1, 0.9 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0, true)
			overlay.draw_set_transform(Vector2.ZERO)
			continue
		var R: float = (34.0 + 46.0 * float(im["s"])) * (0.55 + 0.45 * e)
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 16:
			var a: float = float(im["rot"]) + i * TAU / 16.0
			var rr := R * (1.0 if i % 2 == 0 else 0.5)
			pts.append(im["pos"] + Vector2.from_angle(a) * rr * Vector2(1.25, 1.0))
			inner.append(im["pos"] + Vector2.from_angle(a) * rr * 0.55 * Vector2(1.25, 1.0))
		if k < 0.55:
			overlay.draw_colored_polygon(pts, Color(1.0, 0.86, 0.35, 1.0 - k))
			overlay.draw_colored_polygon(inner, Color(1, 1, 1, 1.0 - k))
		overlay.draw_arc(im["pos"], R * 1.15, 0, TAU, 28, Color(1, 1, 1, (1.0 - k) * 0.9), 4.0 * (1.0 - k) + 1.0, true)
		# riscos de velocidade na direção do golpe
		for j in 3:
			var y0 := (j - 1) * 14.0
			var x0: float = -float(im["dir"]) * (20.0 + 40.0 * e)
			overlay.draw_line(im["pos"] + Vector2(x0, y0), im["pos"] + Vector2(x0 - float(im["dir"]) * 30.0 * (1.0 - k), y0), Color(1, 1, 1, 1.0 - k), 3.0, true)
	var star := Data.tex("cenario/brilho")
	for sp in sparks:
		var k: float = sp["t"] / 0.4
		var sz := 22.0 * (1.0 - k * 0.6)
		overlay.draw_set_transform(sp["pos"], sp["rot"] + k * 3.0)
		overlay.draw_texture_rect(star, Rect2(-sz / 2, -sz / 2, sz, sz), false, Color(1, 1, 1, 1.0 - k))
	overlay.draw_set_transform(Vector2.ZERO)
	for r in robots:
		if r.alive and r.visible and r.drop_t > 0.0:
			# voltando pendurado no guindaste
			var hk: Vector2 = r.position + Vector2(0, -96)
			overlay.draw_line(Vector2(hk.x, -400), hk, Color("#5a6370"), 3.0, true)
			overlay.draw_arc(hk + Vector2(0, 8), 9, 0, PI, 10, Color("#5a6370"), 4.0, true)
	for r in robots:
		if r.alive and r.visible and r.stun_t > 0.12:
			var hc: Vector2 = r.rect().position + Vector2(24, -10)
			for k in 3:
				var ang := Time.get_ticks_msec() / 160.0 + k * TAU / 3.0
				overlay.draw_texture_rect(star, Rect2(hc + Vector2(cos(ang) * 22, sin(ang) * 7) - Vector2(7, 7), Vector2(14, 14)), false)
	if lab_mode and state == S.RUN:
		lab.draw_world(overlay)
	if debug:
		for r in robots:
			overlay.draw_rect(r.rect(), Color(0, 1, 0, 0.8), false, 2)
		for h in level.hazard_rects:
			overlay.draw_rect(h, Color(1, 0, 0, 0.9), false, 2)
		overlay.draw_rect(level.goal_rect, Color(0, 1, 1, 0.9), false, 2)

# ---------------------------------------------------------------- debug
func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F1: debug = not debug
			KEY_F2: skip_phase()
			KEY_F5:
				if state == S.JOIN and players.size() < 4:
					PlayerInput.virtual["parado%d" % players.size()] = {}
					add_player("parado%d" % players.size())
			KEY_F6: Engine.time_scale = 0.3 if Engine.time_scale == 1.0 else 1.0
			KEY_F11: toggle_fullscreen()
			KEY_TAB:
				if sandbox and state == S.RUN:
					tester().toggle()
			KEY_B:
				if state == S.JOIN:
					add_bot()
			KEY_N:
				if state == S.JOIN:
					remove_last_bot()
			KEY_M:
				if state == S.JOIN:
					bot_level = (bot_level + 1) % 3
					for p in players:
						if p.get("bot", false):
							p["level"] = bot_level

## F11: tela cheia <-> janela (o jogo abre em tela cheia: display/window/size/mode=3).
func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func skip_phase() -> void:
	match state:
		S.JOIN:
			while players.size() < 2:
				PlayerInput.virtual["parado%d" % players.size()] = {}
				add_player("parado%d" % players.size())
			start_match()
		S.SCORE: timer = 0.0
		S.RUN:
			demo.round_winner = -1
			end_delay = 0.01
			countdown = 0.0
			timer = 0.0
			for r in robots:
				r.active = true
		S.WIN: start_match()
