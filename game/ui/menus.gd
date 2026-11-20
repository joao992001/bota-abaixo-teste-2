extends Node
## Telas fora da partida: MENU principal, seleção de MODOS, COMO JOGAR, OPÇÕES e a PAUSA.
## Qualquer teclado ou controle navega (bots não). Desenho em draw(ci), chamado pelo HUD.

const Kit := preload("res://ui/kit.gd")
const RobotVis := preload("res://player/robot_visual.gd")

const MENU_ITEMS := ["JOGAR", "OFICINA", "COMO JOGAR", "OPÇÕES", "SAIR"]
const MODES := [
	{"id": "demolicao", "name": "DEMOLIÇÃO", "desc": "Quebre o chão dos outros.\nO último em pé leva ★", "ok": true},
	{"id": "rei", "name": "REI DA OBRA", "desc": "Segure o capacete de ouro\no máximo que puder", "ok": false},
	{"id": "corrida", "name": "CORRIDA SABOTADA", "desc": "Chegue ao elevador\nsoltando armadilhas", "ok": false},
	{"id": "torre", "name": "TORRE MALUCA", "desc": "Empilhe a torre\nmais alta", "ok": false},
	{"id": "construcao", "name": "CLÁSSICO", "desc": "Monte armadilhas com dono\ne corra até o elevador", "ok": true},
]
const PAUSE_ITEMS := ["CONTINUAR", "REINICIAR PARTIDA", "MENU PRINCIPAL"]
const STAR_GOALS := [3, 5, 7]

var main: Node
var sel := 0
var mode_sel := 0
var goal_sel := 1
var opt_sel := 0
var pause_sel := 0
var t := 0.0
var shake_card := 0.0
var arena_sel := 0
var sub_sel := 0
var adj_sel := 0
const EVENT_LEVELS := ["DESLIGADOS", "POUCOS", "NORMAL", "CAOS"]

func setup(m: Node) -> void:
	main = m

## Algum teclado/controle (não bot) apertou a ação?
func pressed(a: String) -> bool:
	for dev in PlayerInput.all_devices():
		if not dev.begins_with("bot") and PlayerInput.dev_pressed(dev, a):
			return true
	return false

func confirm() -> bool:
	return pressed("jump") or pressed("start")

func move_v() -> int:
	return int(pressed("down")) - int(pressed("up"))

func move_h() -> int:
	return int(pressed("right")) - int(pressed("left"))

func update(dt: float) -> void:
	t += dt
	if move_v() != 0 or move_h() != 0:
		Audio.play("menu_mover")
	if pressed("back"):
		Audio.play("menu_voltar")
	elif confirm():
		Audio.play("menu_ok")
	shake_card = maxf(shake_card - dt, 0.0)
	var S = main.S
	match main.state:
		S.MENU:
			sel = posmod(sel + move_v(), MENU_ITEMS.size())
			if confirm():
				match sel:
					0: main.state = S.MODES
					1: main.oficina.start(_who_confirmed())
					2: main.state = S.HOWTO
					3: main.state = S.OPTIONS
					4: main.get_tree().quit()
		S.MODES:
			mode_sel = posmod(mode_sel + move_h(), MODES.size())
			if confirm():
				var m: Dictionary = MODES[mode_sel]
				if m["ok"]:
					main.mode = m["id"]
					if m["id"] == "demolicao":
						main.state = S.SUBMODOS
					else:
						main.go_join()
				else:
					shake_card = 0.35
					Audio.play("menu_negado")
			elif pressed("back"):
				main.state = S.MENU
		S.HOWTO:
			if confirm() or pressed("back"):
				main.state = S.MENU
		S.SUBMODOS:
			var subs: Array = main.demo.cfg["submodos"]
			sub_sel = posmod(sub_sel + move_h(), subs.size())
			if confirm():
				main.submode_choice = subs[sub_sel]["id"]
				main.state = S.ARENAS
			elif pressed("back"):
				main.state = S.MODES
		S.AJUSTES:
			adj_sel = posmod(adj_sel + move_v(), 6)
			var h2 := move_h()
			var c2 := confirm()
			match adj_sel:
				0:
					if h2 != 0:
						goal_sel = clampi(goal_sel + h2, 0, STAR_GOALS.size() - 1)
				1:
					if h2 != 0 or c2:
						main.event_level = posmod(main.event_level + (h2 if h2 != 0 else 1), 4)
				2:
					if c2:
						main.state = S.EVENTOS
				3:
					if h2 != 0 or c2:
						main.demo.items_on = not main.demo.items_on
				4:
					if h2 != 0 or c2:
						main.demo.help_losers = not main.demo.help_losers
				5:
					if c2:
						main.demo.cfg["rounds_to_win"] = STAR_GOALS[goal_sel]
						main.go_join()
			if pressed("back"):
				main.state = S.ARENAS
		S.EVENTOS:
			main.events.menu_update(self)
		S.CONTROLES:
			_update_pads()
		S.ARENAS:
			var n := arena_list().size()
			arena_sel = posmod(arena_sel + move_h(), n)
			var v := move_v()
			if v != 0:
				arena_sel = clampi(arena_sel + v * 4, 0, n - 1)
			if confirm():
				main.arena_choice = arena_list()[arena_sel]["id"]
				main.state = S.AJUSTES
			elif pressed("back"):
				main.state = S.SUBMODOS
		S.OPTIONS:
			opt_sel = posmod(opt_sel + move_v(), 8)
			var h := move_h()
			var c := confirm()
			if opt_sel == 0 and (h != 0 or c):
				main.toggle_fullscreen()
			elif opt_sel == 1 and (h != 0 or c):
				main.shake_on = not main.shake_on
			elif opt_sel == 2 and (h != 0 or c):
				main.bot_level = posmod(main.bot_level + (h if h != 0 else 1), 3)
			elif opt_sel == 3 and h != 0:
				Audio.set_volumes(Audio.music_vol + h, Audio.sfx_vol)
			elif opt_sel == 4 and h != 0:
				Audio.set_volumes(Audio.music_vol, Audio.sfx_vol + h)
				Audio.play("caixote_pancada")
			elif opt_sel == 5 and (h != 0 or c):
				PlayerInput.vibration = not PlayerInput.vibration
				if PlayerInput.vibration:
					for j in Input.get_connected_joypads():
						Input.start_joy_vibration(j, 0.5, 0.5, 0.25)
			elif opt_sel == 6 and c:
				main.state = S.CONTROLES
				pad_prev.clear()
			elif opt_sel == 7 and c:
				main.state = S.MENU
			if h != 0 or c:
				main.save_options()
			if pressed("back"):
				main.state = S.MENU

## Pausa (dentro da partida): Start/Enter abre; navega com ▲▼.
func update_pause() -> void:
	pause_sel = posmod(pause_sel + move_v(), PAUSE_ITEMS.size())
	if pressed("back"):
		main.paused = false
	elif confirm():
		match pause_sel:
			0: main.paused = false
			1:
				main.paused = false
				main.start_match()
			2:
				main.paused = false
				main.go_menu()

# ---------------------------------------------------------------- desenho
func draw(ci: CanvasItem) -> void:
	var S = main.S
	match main.state:
		S.MENU: _draw_menu(ci)
		S.MODES: _draw_modes(ci)
		S.HOWTO: _draw_howto(ci)
		S.OPTIONS: _draw_options(ci)
		S.ARENAS: _draw_arenas(ci)
		S.SUBMODOS: _draw_submodes(ci)
		S.AJUSTES: _draw_adjust(ci)
		S.EVENTOS: main.events.menu_draw(ci, self)
		S.CONTROLES: _draw_pads(ci)
	if main.paused:
		if main.sandbox and main.oficina.open:
			main.oficina.draw(ci)
		else:
			_draw_pause(ci)

## Qual dispositivo confirmou agora (vira o P1 da Oficina).
func _who_confirmed() -> String:
	for dev in PlayerInput.all_devices():
		if PlayerInput.dev_pressed(dev, "jump") or PlayerInput.dev_pressed(dev, "start"):
			return dev
	return "kb_a"

func _logo(ci: CanvasItem, y: float, w: float) -> void:
	var h := w * 340.0 / 1700.0
	var bob := sin(t * 1.6) * 6.0
	ci.draw_texture_rect(Data.tex("ui/logo"), Rect2(960 - w / 2, y + bob, w, h), false)

func _button(ci: CanvasItem, r: Rect2, label: String, on: bool, rot := 0.0) -> void:
	var c := r.get_center()
	ci.draw_set_transform(c, rot + (sin(t * 6.0) * 0.015 if on else 0.0), Vector2.ONE * (1.06 if on else 1.0))
	var rr := Rect2(-r.size / 2.0, r.size)
	if on:
		Kit.paper(ci, rr.grow(10), Color("#f2c84b"))
	Kit.paper(ci, rr)
	Kit.text(ci, Vector2(rr.position.x, 14), label, 44, Color("#2c4a52") if not on else Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
	if on:
		ci.draw_texture_rect(Data.tex("robo/marreta"), Rect2(rr.position.x - 70, -34, 64, 64), false)
	ci.draw_set_transform(Vector2.ZERO)

func _draw_menu(ci: CanvasItem) -> void:
	_logo(ci, 40, 1180)
	for i in MENU_ITEMS.size():
		_button(ci, Rect2(250, 440 + i * 120, 440, 90), MENU_ITEMS[i], sel == i, (-0.02 if i % 2 == 0 else 0.02))
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  PULAR / ENTER confirmar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

## Ilustração do cartão; xf = transformação do cartão (girado), para não perdê-la ao desenhar peças giradas.
func _mode_art(ci: CanvasItem, id: String, c: Vector2, xf: Transform2D) -> void:
	match id:
		"demolicao":
			for k in 3:
				ci.draw_texture_rect(Data.tex("cenario/caixote_%d" % k), Rect2(c + Vector2(-96 + k * 64, 0), Vector2(64, 64)), false)
			ci.draw_texture_rect(Data.tex("cenario/caixote_1"), Rect2(c + Vector2(-32, -64), Vector2(64, 64)), false)
			ci.draw_set_transform_matrix(xf * Transform2D(0.9 + sin(t * 4.0) * 0.3, Vector2(0.4, 0.4), 0.0, c + Vector2(60, -40)))
			ci.draw_texture(Data.tex("robo/marreta"), Vector2(-128, -224))
			ci.draw_set_transform_matrix(xf)
		"rei":
			ci.draw_texture_rect(Data.tex("cenario/caixote_0"), Rect2(c + Vector2(-48, 0), Vector2(96, 64)), false)
			ci.draw_texture_rect(Data.tex("itens/capacete"), Rect2(c + Vector2(-56, -100), Vector2(112, 112)), false, Color(1.0, 0.85, 0.3))
		"corrida":
			ci.draw_texture_rect(Data.tex("cenario/elevador"), Rect2(c + Vector2(-50, -80), Vector2(100, 150)), false)
		"torre":
			for k in 4:
				ci.draw_set_transform_matrix(xf * Transform2D(sin(k * 2.1) * 0.12, c + Vector2(sin(k * 1.3) * 10.0, 40 - k * 46)))
				ci.draw_texture_rect(Data.tex("cenario/caixote_%d" % (k % 3)), Rect2(-30, -24, 60, 48), false)
			ci.draw_set_transform_matrix(xf)
		"construcao":
			ci.draw_texture_rect(Data.tex("pecas/esteira_c0"), Rect2(c + Vector2(-96, 10), Vector2(192, 64)), false)
			ci.draw_texture_rect(Data.tex("pecas/serra_rival"), Rect2(c + Vector2(-70, -66), Vector2(64, 64)), false)
			ci.draw_texture_rect(Data.tex("pecas/mola_c2"), Rect2(c + Vector2(10, -60), Vector2(64, 64)), false)

func _draw_modes(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 40, 800, 128), "ESCOLHA O MODO", 60)
	var n := MODES.size()
	for i in n:
		var m: Dictionary = MODES[i]
		var on := i == mode_sel
		var cx := 960 + (i - mode_sel) * 380.0
		var sz := Vector2(340, 470) * (1.08 if on else 0.92)
		var cy := 560.0 + (0.0 if on else 20.0)
		var rot := sin(i * 1.7) * 0.03
		if on and shake_card > 0.0:
			rot += sin(shake_card * 60.0) * 0.05
		var xf := Transform2D(rot, Vector2(cx, cy))
		ci.draw_set_transform_matrix(xf)
		var r := Rect2(-sz / 2.0, sz)
		if on:
			Kit.paper(ci, r.grow(12), Color("#f2c84b"))
		Kit.paper(ci, r, Color.WHITE if m["ok"] else Color(0.85, 0.85, 0.85))
		_mode_art(ci, m["id"], Vector2(0, -90), xf)
		Kit.text(ci, Vector2(r.position.x, 60), m["name"], 38 if m["name"].length() < 12 else 30, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var lines: PackedStringArray = m["desc"].split("\n")
		for k in lines.size():
			Kit.text(ci, Vector2(r.position.x, 110 + k * 32), lines[k], 24, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if not m["ok"]:
			ci.draw_texture_rect(Data.tex("ui/em_breve"), Rect2(-130, -150, 260, 95), false)
		ci.draw_set_transform(Vector2.ZERO)
	Kit.text(ci, Vector2(0, 1056), "◄► modo  ·  PULAR confirmar  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _sub_art(ci: CanvasItem, id: String, c: Vector2, xf: Transform2D) -> void:
	match id:
		"ultimo":
			RobotVis.draw_robot(ci, {"color": 0, "model": 0, "acc": 0}, RobotVis.victory_pose(t), xf * Transform2D(0.0, Vector2(1.5, 1.5), 0.0, c + Vector2(0, 70)))
		"vidas":
			for k in 3:
				RobotVis.draw_robot(ci, {"color": 1, "model": 2, "acc": 0}, RobotVis.idle_pose(t + k), xf * Transform2D(0.0, Vector2(0.9, 0.9), 0.0, c + Vector2(-80 + k * 80, 60)))
		"placar":
			ci.draw_set_transform_matrix(xf)
			Kit.wood(ci, Rect2(c + Vector2(-130, -60), Vector2(260, 110)))
			Kit.text(ci, c + Vector2(-130, 20), "+3  +1  −1", 44, Kit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, 260, 8, Color("#5a3a10"))
		"batata":
			ci.draw_set_transform_matrix(xf * Transform2D(sin(t * 8.0) * 0.15, c))
			ci.draw_texture_rect(Data.tex("itens/dinamite"), Rect2(-70, -80, 140, 140), false)
	ci.draw_set_transform_matrix(xf)

func _draw_submodes(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "DEMOLIÇÃO: SUBMODO", 52)
	var subs: Array = main.demo.cfg["submodos"]
	for i in subs.size():
		var m: Dictionary = subs[i]
		var on := i == sub_sel
		var c := Vector2(270 + i * 460, 560)
		var xf := Transform2D(sin(i * 1.7) * 0.03, Vector2.ONE * (1.06 if on else 0.96), 0.0, c)
		ci.draw_set_transform_matrix(xf)
		var r := Rect2(-200, -280, 400, 560)
		if on:
			Kit.paper(ci, r.grow(12), Color("#f2c84b"))
		Kit.paper(ci, r)
		_sub_art(ci, m["id"], Vector2(0, -110), xf)
		Kit.text(ci, Vector2(r.position.x, 80), String(m["nome"]).to_upper(), 36 if String(m["nome"]).length() < 14 else 30, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var lines: PackedStringArray = String(m["dica"]).split("\n")
		for k in lines.size():
			Kit.text(ci, Vector2(r.position.x, 140 + k * 34), lines[k], 25, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	ci.draw_set_transform(Vector2.ZERO)
	Kit.text(ci, Vector2(0, 1056), "◄► escolher  ·  PULAR confirmar  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _draw_adjust(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "AJUSTES DA PARTIDA", 54)
	var sname: String = main.demo.find_submode(main.submode_choice)["nome"]
	var aname := "Sorteio"
	for a in main.demo.cfg["arenas"]:
		if a["id"] == main.arena_choice:
			aname = a["nome"]
	Kit.sticker(ci, Vector2(0, 205), "%s  ·  %s" % [sname, aname], 34, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, 1920)
	var items := [
		"★ PARA VENCER:  ◄ %d ►" % STAR_GOALS[goal_sel],
		"EVENTOS:  ◄ %s ►" % EVENT_LEVELS[main.event_level],
		"ESCOLHER EVENTOS  ▸",
		"ITENS:  ◄ %s ►" % ("SIM" if main.demo.items_on else "NÃO"),
		"AJUDA PARA QUEM PERDE:  ◄ %s ►" % ("SIM" if main.demo.help_losers else "NÃO"),
		"COMEÇAR  ▸",
	]
	for i in items.size():
		_button(ci, Rect2(510, 250 + i * 128, 900, 96), items[i], adj_sel == i)
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  ◄► muda  ·  PULAR confirmar  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

## SORTEIO + arenas de data/modos.json.
func arena_list() -> Array:
	var out: Array = [{"id": "sorteio", "nome": "SORTEIO", "dica": "Cada rodada numa arena diferente"}]
	out.append_array(main.demo.cfg["arenas"])
	return out

func _draw_arenas(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "ESCOLHA A ARENA", 58)
	var list := arena_list()
	var nrows: int = int(ceil(list.size() / 4.0))
	var sc := minf(1.0, 860.0 / (nrows * 400.0 - 70.0))   # mais arenas: cartões menores
	for i in list.size():
		var a: Dictionary = list[i]
		var on := i == arena_sel
		var col := i % 4
		var row := i / 4
		var c := Vector2(255 + col * 470, 175 + 165 * sc + row * 400 * sc)
		var xf := Transform2D(sin(i * 1.9) * 0.025, Vector2(sc, sc) * (1.06 if on else 1.0), 0.0, c)
		ci.draw_set_transform_matrix(xf)
		var r := Rect2(-205, -165, 410, 330)
		if on:
			Kit.paper(ci, r.grow(12), Color("#f2c84b"))
		Kit.paper(ci, r)
		var thumb := Data.tex("ui/arena_" + a["id"])
		var tr := Rect2(-180, -142, 360, 192)
		if a["id"] == "sorteio":
			ci.draw_rect(tr, Color("#9fe3ee"))
			Kit.sticker(ci, Vector2(-180, 0), "?", 150, Color("#f2c84b"), HORIZONTAL_ALIGNMENT_CENTER, 360)
		elif thumb != null:
			ci.draw_texture_rect(thumb, tr, false)
		else:
			ci.draw_rect(tr, Color("#9fe3ee"))
		Kit.text(ci, Vector2(r.position.x, 100), String(a["nome"]).to_upper(), 34 if String(a["nome"]).length() < 15 else 28, Color("#1f3a40"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Kit.text(ci, Vector2(r.position.x, 138), a["dica"], 21, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	ci.draw_set_transform(Vector2.ZERO)
	Kit.text(ci, Vector2(0, 1056), "◄►▲▼ escolher  ·  PULAR confirmar  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _draw_howto(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "COMO JOGAR", 60)
	var r := Rect2(160, 180, 1600, 780)
	Kit.paper(ci, r)
	var tips := [
		["robo", "Derrube os outros no poço de espinhos. O último em pé ganha uma ★."],
		["marreta", "MARRETA: quebra o caixote à frente (3 golpes) e empurra quem estiver ali."],
		["pisao", "PULE NA CABEÇA de alguém para deixá-lo tonto.\n▼ + MARRETA quebra o chão embaixo de você."],
		["itens", "Pegue as bolhas que caem (12 itens): dinamite, gancho, cola, chave-bumerangue,\nfuradeira, tábua, mola portátil (botão de ITEM usa) · martelão, ímã, botas, capacete."],
		["parado", "Caixote racha se você fica parado em cima. No fim da rodada, TERREMOTO!"],
	]
	for i in tips.size():
		var y := r.position.y + 80 + i * 140
		var ic: String = tips[i][0]
		var c := Vector2(r.position.x + 120, y + 30)
		match ic:
			"robo": RobotVis.draw_robot(ci, {"color": 0, "model": 0, "acc": 0}, RobotVis.victory_pose(t), Transform2D(0.0, Vector2(1.1, 1.1), 0.0, c + Vector2(0, 50)))
			"marreta":
				ci.draw_set_transform(c, 0.6 + sin(t * 5.0) * 0.5, Vector2(0.45, 0.45))
				ci.draw_texture(Data.tex("robo/marreta"), Vector2(-128, -224))
			"pisao":
				var po: Dictionary = RobotVis.idle_pose(t)
				po["expr"] = "susto"
				RobotVis.draw_robot(ci, {"color": 2, "model": 2, "acc": 0}, po, Transform2D(0.0, Vector2(0.9, 0.9), 0.0, c + Vector2(0, 60)))
			"itens":
				var names := ["dinamite", "martelao", "capacete", "mola"]
				for k in 4:
					ci.draw_texture_rect(Data.tex("itens/" + names[k]), Rect2(c + Vector2(-70 + (k % 2) * 60, -40 + (k / 2) * 52), Vector2(54, 54)), false)
			"parado":
				ci.draw_texture_rect(Data.tex("cenario/caixote_0"), Rect2(c - Vector2(40, 30), Vector2(80, 80)), false)
		ci.draw_set_transform(Vector2.ZERO)
		var lines: PackedStringArray = String(tips[i][1]).split("\n")
		for k in lines.size():
			Kit.text(ci, Vector2(r.position.x + 260, y + 44 - (lines.size() - 1) * 18 + k * 40), lines[k], 32, Color("#1f3a40"))
	Kit.text(ci, Vector2(0, 1050), "Teclado A: WASD · Espaço pula · F marreta · G item     Teclado B: setas · Ctrl dir. pula · ponto marreta · vírgula item     Controle: A · X · Y", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 6)

func _draw_options(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 60, 800, 128), "OPÇÕES", 60)
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	var items := [
		"TELA CHEIA:  %s" % ("SIM" if full else "NÃO"),
		"TREMOR DA TELA:  %s" % ("SIM" if main.shake_on else "NÃO"),
		"BOTS:  %s" % main.bots.LEVEL_NAMES[main.bot_level].to_upper(),
		"MÚSICA:  ◄ %s ►" % _bar(Audio.music_vol),
		"EFEITOS:  ◄ %s ►" % _bar(Audio.sfx_vol),
		"VIBRAÇÃO:  %s" % ("SIM" if PlayerInput.vibration else "NÃO"),
		"TESTAR CONTROLES  ▸",
		"VOLTAR",
	]
	for i in items.size():
		_button(ci, Rect2(560, 205 + i * 104, 800, 84), items[i], opt_sel == i)
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  ◄► ou PULAR muda", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _bar(v: int) -> String:
	return "■".repeat(v) + "□".repeat(10 - v)

func _draw_pause(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.25, 0.3, 0.55))
	Kit.ribbon(ci, Rect2(610, 180, 700, 128), "PAUSA", 64)
	if not main.lost_pads.is_empty():
		var r := Rect2(460, 40, 1000, 120)
		Kit.paper(ci, r, Color(1, 0.86, 0.82))
		var who := ", ".join(main.lost_pads.map(func(i): return "P%d" % (i + 1)))
		Kit.text(ci, Vector2(r.position.x, r.position.y + 52), "CONTROLE DESCONECTADO: %s" % who, 38, Color("#a01528"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Kit.text(ci, Vector2(r.position.x, r.position.y + 94), "Reconecte (USB ou Bluetooth) ou aperte START em outro controle", 24, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	for i in PAUSE_ITEMS.size():
		_button(ci, Rect2(610, 380 + i * 140, 700, 100), PAUSE_ITEMS[i], pause_sel == i)

# ---------------------------------------------------------------- testar controles
var pad_prev := {}   # joy -> {botão: bool} (bordas para vibrar e sair)

func _pad_edge(j: int, b: int) -> bool:
	var now := Input.is_joy_button_pressed(j, b)
	var key := "%d:%d" % [j, b]
	var was: bool = pad_prev.get(key, false)
	pad_prev[key] = now
	return now and not was

func _update_pads() -> void:
	# sai com Esc/Backspace ou SELECT (B não sai: aqui ele é testado)
	if PlayerInput.dev_pressed("kb_a", "back") or PlayerInput.dev_pressed("kb_b", "back"):
		main.state = main.S.OPTIONS
		Audio.play("menu_voltar")
		return
	for j in Input.get_connected_joypads():
		if _pad_edge(j, JOY_BUTTON_BACK):
			main.state = main.S.OPTIONS
			Audio.play("menu_voltar")
			return
		if _pad_edge(j, JOY_BUTTON_A):
			Input.start_joy_vibration(j, 0.6, 0.6, 0.2)   # PULAR vibra: testa o motor
			Audio.play("pulo")
		if _pad_edge(j, JOY_BUTTON_X):
			Audio.play("marreta_vento")
		if _pad_edge(j, JOY_BUTTON_Y) or _pad_edge(j, JOY_BUTTON_B):
			Audio.play("item")

func _draw_pads(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.45))
	Kit.ribbon(ci, Rect2(560, 20, 800, 128), "TESTAR CONTROLES", 54)
	var pads: Array = Input.get_connected_joypads()
	if pads.is_empty():
		var r := Rect2(260, 190, 1400, 760)
		Kit.paper(ci, r)
		Kit.text(ci, Vector2(r.position.x, r.position.y + 90), "NENHUM CONTROLE DETECTADO", 50, Color("#a01528"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		var tips := [
			"USB: ligue o cabo — aparece aqui na hora.",
			"Xbox (Bluetooth): Windows ▸ Bluetooth ▸ Adicionar dispositivo; segure o botão de parear do controle.",
			"PlayStation (DualSense/DualShock 4): segure CREATE/SHARE + PS até a luz piscar e pareie no Bluetooth.",
			"Switch Pro / 8BitDo: modo X-input (Xbox) funciona melhor; pareie pelo Bluetooth do Windows.",
			"Steam aberta pode esconder ou duplicar o controle (Steam Input): feche a Steam se algo estranho acontecer.",
			"Rodando dentro do editor: clique na janela do jogo para ela ter o foco.",
		]
		for i in tips.size():
			Kit.text(ci, Vector2(r.position.x + 70, r.position.y + 190 + i * 88), "•  " + tips[i], 27, Color("#2c4a52"))
	else:
		var n: int = mini(pads.size(), 4)
		var cw := 430.0
		var x0 := 960.0 - (n * cw + (n - 1) * 20.0) / 2.0
		for k in n:
			_draw_pad_card(ci, pads[k], Rect2(x0 + k * (cw + 20.0), 180, cw, 780), k)
	Kit.text(ci, Vector2(0, 1056), "Aperte os botões para ver acender  ·  PULAR vibra  ·  SELECT ou ESC volta", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _draw_pad_card(ci: CanvasItem, j: int, r: Rect2, k: int) -> void:
	Kit.paper(ci, r)
	var dev := "joy%d" % j
	var st: String = PlayerInput.pad_type(dev)
	var dark := Color("#1f3a40")
	Kit.text(ci, Vector2(r.position.x, r.position.y + 60), "CONTROLE %d" % (j + 1), 40, dark, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var nm := Input.get_joy_name(j)
	Kit.text(ci, Vector2(r.position.x + 20, r.position.y + 96), nm.substr(0, 30), 22, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 40)
	var tname := {"xbox": "tipo Xbox", "ps": "tipo PlayStation", "nintendo": "tipo Nintendo", "generico": "genérico (botões como Xbox)"}
	Kit.text(ci, Vector2(r.position.x, r.position.y + 128), tname.get(st, ""), 22, Color("#3c9a46"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var used: int = PlayerInput.slots.find(dev)
	if used >= 0:
		Kit.text(ci, Vector2(r.position.x, r.position.y + 158), "jogando como P%d" % (used + 1), 22, Data.TEXT_COLORS[main.players[used]["color"]] if used < main.players.size() else dark, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	# corpo do controle
	var c := Vector2(r.get_center().x, r.position.y + 360)
	var body := Rect2(c - Vector2(180, 95), Vector2(360, 190))
	ci.draw_rect(body, Color("#d5dbe1"))
	ci.draw_circle(body.position + Vector2(40, 150), 70, Color("#d5dbe1"))
	ci.draw_circle(body.end - Vector2(40, 40), 70, Color("#d5dbe1"))
	# gatilhos e ombros
	var lt := Input.get_joy_axis(j, JOY_AXIS_TRIGGER_LEFT)
	var rt := Input.get_joy_axis(j, JOY_AXIS_TRIGGER_RIGHT)
	for side in [-1, 1]:
		var tr := Rect2(c + Vector2(side * 125 - 40, -165), Vector2(80, 26))
		ci.draw_rect(tr, Color("#9aa4ae"))
		var v: float = rt if side > 0 else lt
		ci.draw_rect(Rect2(tr.position, Vector2(tr.size.x * clampf(v, 0.0, 1.0), tr.size.y)), Color("#f2c84b"))
		Kit.text(ci, Vector2(tr.position.x, tr.position.y - 6), ("RT" if side > 0 else "LT") if st != "ps" else ("R2" if side > 0 else "L2"), 18, dark, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
		Kit.pad_btn(ci, c + Vector2(side * 125, -112), 18, "rb" if side > 0 else "lb", st, Input.is_joy_button_pressed(j, JOY_BUTTON_RIGHT_SHOULDER if side > 0 else JOY_BUTTON_LEFT_SHOULDER))
	# analógicos
	for stick in [[JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, Vector2(-120, -20), JOY_BUTTON_LEFT_STICK], [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, Vector2(60, 50), JOY_BUTTON_RIGHT_STICK]]:
		var sc: Vector2 = c + stick[2]
		ci.draw_circle(sc, 36, Color("#5a6370"))
		var ax := Vector2(Input.get_joy_axis(j, stick[0]), Input.get_joy_axis(j, stick[1]))
		ci.draw_circle(sc + ax * 22.0, 22, Color("#f2c84b") if Input.is_joy_button_pressed(j, stick[3]) else Color("#2f3640"))
	# direcional
	var dc := c + Vector2(-60, 50)
	for d in [[JOY_BUTTON_DPAD_UP, Vector2(0, -22)], [JOY_BUTTON_DPAD_DOWN, Vector2(0, 22)], [JOY_BUTTON_DPAD_LEFT, Vector2(-22, 0)], [JOY_BUTTON_DPAD_RIGHT, Vector2(22, 0)]]:
		ci.draw_rect(Rect2(dc + d[1] - Vector2(12, 12), Vector2(24, 24)), Color("#f2c84b") if Input.is_joy_button_pressed(j, d[0]) else Color("#2f3640"))
	ci.draw_rect(Rect2(dc - Vector2(12, 12), Vector2(24, 24)), Color("#2f3640"))
	# botões de ação
	var fc := c + Vector2(120, -20)
	for b in [["baixo", Vector2(0, 30), JOY_BUTTON_A], ["direita", Vector2(30, 0), JOY_BUTTON_B], ["esquerda", Vector2(-30, 0), JOY_BUTTON_X], ["cima", Vector2(0, -30), JOY_BUTTON_Y]]:
		Kit.pad_btn(ci, fc + b[1], 16, b[0], st, Input.is_joy_button_pressed(j, b[2]))
	Kit.pad_btn(ci, c + Vector2(-34, -40), 12, "select", st, Input.is_joy_button_pressed(j, JOY_BUTTON_BACK))
	Kit.pad_btn(ci, c + Vector2(34, -40), 12, "start", st, Input.is_joy_button_pressed(j, JOY_BUTTON_START))
	# o que faz cada botão no jogo
	var y := r.position.y + 520
	for line in [[["baixo"], " pula"], [["esquerda"], " ", ["rb"], " marreta"], [["cima"], " ", ["lb"], " item"], [["start"], " pausa / começa"], [["direita"], " volta nos menus"]]:
		var parts: Array = []
		for e in line:
			parts.append(e)
		Kit.pad_hint(ci, r.get_center().x, y, parts, 26, dark, st)
		y += 48
