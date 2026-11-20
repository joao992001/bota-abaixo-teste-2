extends Node
## Telas fora da partida: MENU principal, seleção de MODOS, COMO JOGAR, OPÇÕES e a PAUSA.
## Qualquer teclado ou controle navega (bots não). Desenho em draw(ci), chamado pelo HUD.

const Kit := preload("res://ui/kit.gd")
const RobotVis := preload("res://player/robot_visual.gd")

const MENU_ITEMS := ["JOGAR", "COMO JOGAR", "OPÇÕES", "SAIR"]
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
	shake_card = maxf(shake_card - dt, 0.0)
	var S = main.S
	match main.state:
		S.MENU:
			sel = posmod(sel + move_v(), MENU_ITEMS.size())
			if confirm():
				match sel:
					0: main.state = S.MODES
					1: main.state = S.HOWTO
					2: main.state = S.OPTIONS
					3: main.get_tree().quit()
		S.MODES:
			mode_sel = posmod(mode_sel + move_h(), MODES.size())
			goal_sel = clampi(goal_sel - move_v(), 0, STAR_GOALS.size() - 1)
			if confirm():
				var m: Dictionary = MODES[mode_sel]
				if m["ok"]:
					main.mode = m["id"]
					main.demo.cfg["rounds_to_win"] = STAR_GOALS[goal_sel]
					if m["id"] == "demolicao":
						main.state = S.ARENAS
					else:
						main.go_join()
				else:
					shake_card = 0.35
			elif pressed("back"):
				main.state = S.MENU
		S.HOWTO:
			if confirm() or pressed("back"):
				main.state = S.MENU
		S.ARENAS:
			var n := arena_list().size()
			arena_sel = posmod(arena_sel + move_h(), n)
			var v := move_v()
			if v != 0:
				arena_sel = clampi(arena_sel + v * 4, 0, n - 1)
			if confirm():
				main.arena_choice = arena_list()[arena_sel]["id"]
				main.go_join()
			elif pressed("back"):
				main.state = S.MODES
		S.OPTIONS:
			opt_sel = posmod(opt_sel + move_v(), 4)
			var h := move_h()
			var c := confirm()
			if opt_sel == 0 and (h != 0 or c):
				main.toggle_fullscreen()
			elif opt_sel == 1 and (h != 0 or c):
				main.shake_on = not main.shake_on
			elif opt_sel == 2 and (h != 0 or c):
				main.bot_level = posmod(main.bot_level + (h if h != 0 else 1), 3)
			elif opt_sel == 3 and c:
				main.state = S.MENU
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
	if main.paused:
		_draw_pause(ci)

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
	# meta de estrelas (só para modos com rodadas)
	var goal: int = STAR_GOALS[goal_sel]
	Kit.wood(ci, Rect2(660, 860, 600, 90))
	Kit.text(ci, Vector2(660, 918), "▲▼  vence com", 30, Kit.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("#5a3a10"))
	for k in goal:
		Kit.star(ci, Vector2(900 + k * 46, 905), 44, true)
	Kit.text(ci, Vector2(0, 1056), "◄► modo  ·  PULAR confirmar  ·  BACKSPACE/ESC voltar", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

## SORTEIO + arenas de data/modos.json.
func arena_list() -> Array:
	var out: Array = [{"id": "sorteio", "nome": "SORTEIO", "dica": "Cada rodada numa arena diferente"}]
	out.append_array(main.demo.cfg["arenas"])
	return out

func _draw_arenas(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.3, 0.35, 0.35))
	Kit.ribbon(ci, Rect2(560, 30, 800, 128), "ESCOLHA A ARENA", 58)
	var list := arena_list()
	for i in list.size():
		var a: Dictionary = list[i]
		var on := i == arena_sel
		var col := i % 4
		var row := i / 4
		var c := Vector2(255 + col * 470, 370 + row * 400)
		var xf := Transform2D(sin(i * 1.9) * 0.025, Vector2(1.06, 1.06) if on else Vector2.ONE, 0.0, c)
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
		["itens", "Pegue as bolhas que caem: dinamite (botão de item arremessa),\nmartelão, capacete de aço e botas de mola."],
		["parado", "Caixote racha se você fica parado em cima. Aos 30 s, TERREMOTO!"],
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
		"VOLTAR",
	]
	for i in items.size():
		_button(ci, Rect2(560, 280 + i * 150, 800, 100), items[i], opt_sel == i)
	Kit.text(ci, Vector2(0, 1056), "▲▼ escolher  ·  ◄► ou PULAR muda", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 7)

func _draw_pause(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1920, 1080), Color(0.1, 0.25, 0.3, 0.55))
	Kit.ribbon(ci, Rect2(610, 180, 700, 128), "PAUSA", 64)
	for i in PAUSE_ITEMS.size():
		_button(ci, Rect2(610, 380 + i * 140, 700, 100), PAUSE_ITEMS[i], pause_sel == i)
