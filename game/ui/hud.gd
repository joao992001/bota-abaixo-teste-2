extends Control
## HUD e telas da partida no estilo cartoon (ui/kit.gd): cartões dos jogadores embaixo (retrato, estrelas, % de dano,
## item), título da rodada no topo, entrada de jogadores, placar da rodada e vitória. Menus em ui/menus.gd.

const Kit := preload("res://ui/kit.gd")
const Piece := preload("res://pieces/piece.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const Retrato := preload("res://ui/retrato.gd")
const PIECE_NAMES := {"P01": "Viga", "P02": "Mola", "P03": "Serra", "P04": "Esteira"}
const PIECE_HINT := {"P01": "dono atravessa por baixo", "P02": "dono 5 tiles, rival 3", "P03": "elimina rivais", "P04": "a favor do dono"}
const DIM := Color(0.16, 0.1, 0.18, 0.45)
const DARK := Color("#2a1a2e")
const CARD_W := 430.0
const CARD_GAP := 26.0
const CARD_Y := 938.0

var main: Node
var t := 0.0
var _banner := ""
var bare := false   # capturas para as propostas de interface: só o cenário, sem HUD
var _banner_age := 0.0
var _heads: Array = []          # retratos redondos (nós com recorte), reaproveitados a cada quadro
var _heads_used := 0
var _heads_root := Node2D.new()
var _over := Node2D.new()       # desenhos por cima dos retratos (selo do item, "FORA!")
var _over_cmds: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heads_root)
	add_child(_over)
	_over.draw.connect(func():
		for c in _over_cmds:
			c.call(_over))

func _process(dt: float) -> void:
	t += dt
	_banner_age += dt

func text(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0) -> void:
	Kit.text(self, pos, s, sz, col, align, w, outline)

func panel(r: Rect2, tint := Color.WHITE) -> void:
	Kit.paper(self, r, tint)

func _look(p: Dictionary) -> Dictionary:
	return {"color": p["color"], "model": p["model"], "acc": p["acc"], "skin": p.get("skin", {})}

## Nome do jogador: o nome do robô da Garagem, ou "P1".."P4" para os robôs de fábrica.
func pname(i: int) -> String:
	var sk: Dictionary = main.players[i].get("skin", {})
	return String(sk.get("nome", "")) if not sk.is_empty() and String(sk.get("nome", "")) != "" else "P%d" % (i + 1)

## Retrato redondo do jogador i centrado em c (desenhado por cima deste quadro).
func _head(i: int, c: Vector2, r: float, ring := Kit.INK, bg := Kit.CREAM, expr := "normal", alpha := 1.0) -> void:
	if _heads_used >= _heads.size():
		var n := Retrato.new()
		_heads_root.add_child(n)
		_heads.append(n)
	var h = _heads[_heads_used]
	_heads_used += 1
	h.look = _look(main.players[i])
	h.position = c
	h.radius = r
	h.ring = ring
	h.bg = bg
	h.expr = expr
	h.modulate = Color(1, 1, 1, alpha)
	h.visible = true

## Texto ajustado: diminui a fonte até caber na largura.
func fit_text(pos: Vector2, s: String, size: int, col: Color, w: float, outline := 0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var sz := size
	while sz > 14 and Kit.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x > w:
		sz -= 2
	Kit.text(self, pos, s, sz, col, align, w, outline)

func _draw() -> void:
	_heads_used = 0
	_over_cmds.clear()
	_draw_all()
	for n in range(_heads_used, _heads.size()):
		_heads[n].visible = false
	_over.queue_redraw()

func _draw_all() -> void:
	var S = main.S
	if bare:
		if main.state in main.MENU_STATES:
			main.menus._draw_scene(self, [1.0, 1.0, 1.0, 1.0])
		return
	if main.state in main.MENU_STATES:
		main.menus.draw(self)
		_draw_toasts()
		return
	match main.state:
		S.JOIN: _draw_join()
		S.PICK: _draw_pick()
		S.BUILD: _draw_build()
		S.RUN: _draw_run()
		S.SCORE: _draw_score()
		S.WIN: _draw_win()
	if not main.paused and (main.state in [S.PICK, S.BUILD, S.RUN] or (main.state == S.SCORE and main.mode != "demolicao")):
		_draw_tags()
	for fl in main.floaters:
		var k: float = fl["t"] / 1.2
		var c: Color = fl["color"]
		c.a = 1.0 - k * k
		var p: Vector2 = main.to_screen(fl["pos"]) + Vector2(-260, -k * 60)
		Kit.text(self, p, fl["text"], 40, c, HORIZONTAL_ALIGNMENT_CENTER, 520, 10, Color(Kit.INK, c.a))
	if main.sandbox and not main.paused:
		main.oficina.draw(self)
	if main.paused:
		main.menus.draw(self)
	_draw_toasts()
	if main.debug:
		var ids: Array = main.implemented_ids()
		text(Vector2(20, 1060), "DEBUG  F2 pula fase · F3 peça: %s · F4 dono: P%d · clique coloca/remove · F6 lento" % [PIECE_NAMES[ids[main.debug_piece]], main.debug_owner + 1], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)

# ---------------------------------------------------------------- cartões dos jogadores (embaixo) e topo
func _draw_tags() -> void:
	var S = main.S
	var n: int = main.players.size()
	var x0 := (1920.0 - (n * CARD_W + (n - 1) * CARD_GAP)) / 2.0
	for i in n:
		_card(i, Rect2(x0 + i * (CARD_W + CARD_GAP), CARD_Y, CARD_W, 130))
	# título da rodada (topo, na faixa do placar)
	var label := "RODADA %d" % main.round_no
	if main.mode == "demolicao" and main.demo.submode() == "placar" and main.state == S.RUN:
		var tl: float = maxf(main.demo.time_left, 0.0)
		label = "RODADA %d  ·  %d:%02d" % [main.round_no, int(tl) / 60, int(tl) % 60]
	if main.mode != "demolicao":
		var names := {S.PICK: "ESCOLHA", S.BUILD: "CONSTRUÇÃO", S.RUN: "CORRIDA", S.SCORE: "PLACAR"}
		label = "R%d · %s %d" % [main.round_no, names.get(main.state, ""), ceili(maxf(main.timer, 0.0))]
	Kit.title(self, Vector2(0, 52), label, 46)
	if main.mode == "demolicao" and main.state == S.RUN:
		_draw_event_note()
	# avisos de derrubada (canto de cima, à direita)
	if main.mode == "demolicao":
		var fy := 10.0
		for f in main.demo.feed:
			var a: float = clampf((4.5 - f["t"]) / 0.5, 0.0, 1.0)
			var fr := Rect2(1530, fy, 370, 46)
			Kit.chunk(self, fr, Color(Kit.CREAM, a), 23, 5, 5.0)
			var p2: Dictionary = main.players[f["col"]] if f["col"] < main.players.size() else {"color": 0}
			fit_text(Vector2(fr.position.x + 16, fy + 32), f["text"], 24, Color(Data.TEXT_COLORS[p2["color"]], a), fr.size.x - 32, 0, HORIZONTAL_ALIGNMENT_CENTER)
			fy += 56.0

## Cartão de um jogador: retrato, P# e nome, estrelas, % de dano grande, item no selo e efeitos ativos.
## Fica translúcido quando um robô passa por trás dele.
func _card(i: int, r: Rect2) -> void:
	var S = main.S
	var p: Dictionary = main.players[i]
	var col: Color = Data.COLORS[p["color"]]
	var robot = main.robots[i] if i < main.robots.size() else null
	var out: bool = main.state == S.RUN and robot != null and not robot.alive
	var a := 1.0
	for rb in main.robots:
		if rb.alive and r.grow(30).has_point(main.to_screen(rb.position)):
			a = 0.35
	var body := Rect2(r.position + Vector2(0, 18), Vector2(r.size.x, 112))
	Kit.chunk(self, body, Color(Color("#b8aeb4") if out else col, a))
	_head(i, r.position + Vector2(71, 59), 58, Kit.INK, Kit.CREAM, "eliminado" if out else "normal", a)
	var tc := Color(1, 1, 1, a)
	var oc := Color(Kit.INK, a)
	fit_text(Vector2(r.position.x + 142, r.position.y + 58), ("P%d  %s" % [i + 1, pname(i)]) if pname(i) != "P%d" % (i + 1) else "P%d" % (i + 1), 26, tc, 255, 7)
	if main.mode == "demolicao":
		var goal := int(main.demo.cfg["rounds_to_win"])
		var sz := minf(28.0, 150.0 / goal)
		for k in goal:
			var sc := Vector2(r.position.x + 156 + k * sz, r.position.y + 96)
			if k < int(p["score"]):
				Kit.star(self, sc, sz * 1.05, true)
			else:
				draw_colored_polygon(_star_pts(sc, sz * 1.05), Color(Kit.INK, 0.3 * a))
		if robot != null and robot.alive and not out:
			var dc: Color = main.dmg_color(robot.dmg)
			Kit.text(self, Vector2(r.position.x, r.position.y + 104), "%d%%" % int(robot.dmg), 62, Color(dc, a), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20, 13, oc)
		if robot != null and main.state == S.RUN and robot.alive:
			var fx: Dictionary = robot.fx_flags()
			var held: String = String(fx["item"])
			if held != "":
				var hc := r.position + Vector2(118, 104)
				_over_cmds.append(func(ci: CanvasItem):
					ci.draw_circle(hc, 25, Color(Kit.INK, a))
					ci.draw_circle(hc, 21, Color(1, 1, 1, a))
					ci.draw_texture_rect(Data.tex("itens/" + held), Rect2(hc - Vector2(17, 17), Vector2(34, 34)), false, Color(1, 1, 1, a)))
			var ix: float = r.position.x + 160.0
			for k in ["martelao", "capacete", "mola", "ima", "foguete"]:
				if fx[k]:
					var ic := Vector2(ix, r.position.y + 14)
					draw_circle(ic, 19, Color(Kit.INK, a))
					draw_circle(ic, 16, Color(Kit.CREAM, a))
					draw_texture_rect(Data.tex("itens/" + k), Rect2(ic - Vector2(14, 14), Vector2(28, 28)), false, Color(1, 1, 1, a))
					ix += 40.0
		if main.state in [S.RUN, S.SCORE]:
			_draw_sub_badge(i, r)
	else:
		Kit.text(self, Vector2(r.position.x, r.position.y + 104), "%d pts" % int(p["score"]), 50, tc, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20, 11, oc)
	if out:
		var cc := body.get_center()
		_over_cmds.append(func(ci: CanvasItem):
			ci.draw_set_transform(cc + Vector2(40, 0), -0.14)
			Kit.sticker(ci, Vector2(-200, 24), "FORA!", 64, Color("#ff5a5a"), HORIZONTAL_ALIGNMENT_CENTER, 400)
			ci.draw_set_transform(Vector2.ZERO))

func _star_pts(c: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(c + Vector2.from_angle(-PI / 2.0 + k * PI / 5.0) * size * (0.5 if k % 2 == 0 else 0.22))
	return pts

## Selo em cima do cartão (à direita): vidas (corações) ou pontos da rodada, conforme o submodo.
func _draw_sub_badge(i: int, r: Rect2) -> void:
	var d = main.demo
	match d.submode():
		"vidas":
			var n: int = int(d.lives.get(i, 0))
			var tot: int = int(d.sub.get("vidas", 3))
			var w := 24.0 + tot * 34.0
			var b := Rect2(r.end.x - w - 14, r.position.y - 30, w, 44)
			Kit.chunk(self, b, Kit.CREAM, 22, 5, 0.0)
			for k in tot:
				_heart(Vector2(b.position.x + 29 + k * 34, b.get_center().y + 1), 13.0, k < n)
		"placar":
			Kit.pill(self, Rect2(r.end.x - 184, r.position.y - 30, 170, 44), Kit.CREAM, "%d pts" % int(d.points.get(i, 0)), 26)
		"batata":
			if d.bomb_holder == i:
				var b2 := Rect2(r.end.x - 184, r.position.y - 30, 170, 44)
				Kit.chunk(self, b2, Color("#ffd0c8"), 22, 5, 0.0)
				draw_texture_rect(Data.tex("itens/dinamite"), Rect2(b2.position.x + 14, b2.position.y + 5, 34, 34), false)
				Kit.text(self, Vector2(b2.position.x + 56, b2.position.y + 32), "%ds" % ceili(d.bomb_fuse), 28, Color("#d42035"))

func _heart(c: Vector2, s: float, full: bool) -> void:
	var pts := PackedVector2Array()
	for k in 33:
		var a := k * TAU / 32.0
		var hx := 16.0 * pow(sin(a), 3)
		var hy := -(13.0 * cos(a) - 5.0 * cos(2 * a) - 2.0 * cos(3 * a) - cos(4 * a))
		pts.append(c + Vector2(hx, hy) * s / 16.0)
	if full:
		draw_colored_polygon(pts, Color("#e5484d"))
	else:
		draw_colored_polygon(pts, Color(0.75, 0.72, 0.68, 0.6))
	draw_polyline(pts, Kit.INK, 3.0, true)

## Evento ativo (nome + barra de tempo), no canto de cima à esquerda.
func _draw_event_note() -> void:
	var ev = main.events
	if ev.phase == "":
		return
	var r := Rect2(20, 10, 420, 62)
	var warn: bool = ev.phase == "aviso"
	Kit.chunk(self, r, Color("#ffd0c8") if warn else Kit.CREAM, 22, 5, 6.0)
	var nm := String(ev.current.get("nome", "")).to_upper()
	fit_text(Vector2(r.position.x + 16, r.position.y + (40 if warn else 36)), ("EM BREVE: " if warn else "") + nm, 28, Color("#d42035") if warn else DARK, r.size.x - 32, 0, HORIZONTAL_ALIGNMENT_CENTER)
	if not warn:
		var k: float = clampf(ev.phase_t / float(ev.current.get("dur", 1)), 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 24, r.position.y + 44, (r.size.x - 48) * k, 8), Color("#f2c84b"))

## Avisos de controle conectado/desconectado (canto de baixo, à esquerda).
func _draw_toasts() -> void:
	var y := 850.0   # canto de baixo à esquerda, subindo (não cobre títulos nem cartões)
	for i in range(PlayerInput.toasts.size() - 1, -1, -1):
		var tt: Dictionary = PlayerInput.toasts[i]
		var a := clampf((4.0 - float(tt["t"])) / 0.4, 0.0, 1.0)
		var slide := (1.0 - clampf(float(tt["t"]) / 0.18, 0.0, 1.0)) * -720.0
		var tw: float = Kit.font().get_string_size(String(tt["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var r := Rect2(24 + slide, y, tw + 110.0, 64)
		panel(r, Color(1, 1, 1, a) if tt["ok"] else Color(1, 0.86, 0.82, a))
		var dev: String = tt.get("dev", "")
		Kit.pad_btn(self, r.position + Vector2(44, 32), 18, "baixo", PlayerInput.pad_type(dev) if tt["ok"] else "generico")
		Kit.text(self, Vector2(r.position.x + 76, r.position.y + 42), String(tt["text"]), 26, Color(0.17, 0.29, 0.32, a) if tt["ok"] else Color(0.63, 0.08, 0.16, a))
		y -= 76.0

## Faixa de aviso que "salta" quando o texto muda.
func _ribbon_pop(txt: String, y: float, w: float, size: int, alpha := 1.0) -> void:
	if txt != _banner:
		_banner = txt
		_banner_age = 0.0
		if txt != "":
			Audio.play("locutor", 1.0, -6.0)   # "locutor" de bipes robóticos
	var k := clampf(_banner_age / 0.22, 0.0, 1.0)
	var s := lerpf(1.45, 1.0, 1.0 - pow(1.0 - k, 3.0))
	draw_set_transform(Vector2(960, y), sin(_banner_age * 3.0) * 0.01, Vector2(s, s))
	Kit.ribbon(self, Rect2(-w / 2.0, -64, w, 128), txt, size)
	draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- entrada
func _draw_join() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	_ribbon_pop("QUEM VAI JOGAR?", 100, 1200, 64)
	var W := 400.0
	var H := 600.0
	var gap := 36.0
	var x0 := (1920.0 - (4 * W + 3 * gap)) / 2.0
	var st: String = PlayerInput.main_pad_type()
	for i in 4:
		var r := Rect2(x0 + i * (W + gap), 196, W, H)
		var rot: float = [-0.026, 0.021, -0.017, 0.026][i]
		draw_set_transform(r.get_center(), rot)
		var lr := Rect2(-r.size / 2.0, r.size)
		if i < main.players.size():
			var p: Dictionary = main.players[i]
			var col: Color = Data.COLORS[p["color"]]
			Kit.chunk(self, lr, Kit.CREAM, 28)
			draw_circle(Vector2(0, -40), 150, Color("#ffe48a"))
			Kit.text(self, Vector2(lr.position.x, lr.position.y + 84), "P%d" % (i + 1), 76, col, HORIZONTAL_ALIGNMENT_CENTER, W, 15)
			var lab: String = PlayerInput.label(p["dev"])
			if p.get("bot", false):
				lab = "BOT · %s" % main.bots.LEVEL_NAMES[p.get("level", 1)]
			fit_text(Vector2(lr.position.x + 20, lr.position.y + 120), lab, 22, Kit.SOFT, W - 40, 0, HORIZONTAL_ALIGNMENT_CENTER)
			var nm: String = p["skin"]["nome"] if not p.get("skin", {}).is_empty() else Data.MODEL_NAMES[p["model"]]
			Kit.text(self, Vector2(lr.position.x, lr.end.y - 104), nm, 42, DARK, HORIZONTAL_ALIGNMENT_CENTER, W)
			var pr := Rect2(lr.position.x + 30, lr.end.y - 82, W - 60, 58)
			Kit.chunk(self, pr, col, 20, 5, 0.0)
			Kit.text(self, Vector2(pr.position.x, pr.get_center().y + 10), "◄ cor ►   ▲▼ robô", 27, DARK, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
			draw_set_transform(Vector2.ZERO)
			RobotVis.draw_robot(self, _look(p), RobotVis.idle_pose(t + i * 0.77), Transform2D(rot, Vector2(2.6, 2.6), 0.0, r.get_center() + Vector2(0, 150)))
			draw_set_transform(Vector2.ZERO)
		else:
			Kit.chunk(self, lr, Color(Kit.CREAM, 0.55), 28)
			Kit.text(self, Vector2(lr.position.x, -40), "P%d" % (i + 1), 84, Color("#f2c84b"), HORIZONTAL_ALIGNMENT_CENTER, W, 16)
			draw_set_transform(Vector2.ZERO)
			Kit.pad_hint(self, r.get_center().x, r.get_center().y + 40, [["baixo"], " entrar"], 36, DARK, st)
			Kit.pad_hint(self, r.get_center().x, r.get_center().y + 104, [["cima"], " + bot"], 30, DARK, st)
			Kit.text(self, Vector2(r.position.x, r.get_center().y + 170), "teclado: Espaço / Ctrl dir.", 22, Kit.SOFT, HORIZONTAL_ALIGNMENT_CENTER, W)
	draw_set_transform(Vector2.ZERO)
	if Input.get_connected_joypads().is_empty():
		Kit.sticker(self, Vector2(0, 950), "nenhum controle detectado  ·  OPÇÕES ▸ TESTAR CONTROLES", 26, Color("#ff8a8a"), HORIZONTAL_ALIGNMENT_CENTER, 1920)
	Kit.pad_hint(self, 960, 1030, [["baixo"], " entrar   ", "◄► cor   ▲▼ robô   ", ["esquerda"], " chapéu   ", ["cima"], " + bot   ", ["direita"], " sair   ", ["start"], " começar"], 30, Color.WHITE, st, 7)

# ---------------------------------------------------------------- clássico: escolha e construção
func _draw_pick() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	_ribbon_pop("ESCOLHA SUA PEÇA", 260, 860, 56)
	Kit.sticker(self, Vector2(0, 380), "quem tem menos pontos escolhe primeiro  ·  ◄ ► e PULAR", 30, DARK, HORIZONTAL_ALIGNMENT_CENTER, 1920)
	var n: int = main.conveyor.size()
	var elapsed: float = main.timers("pick_seconds") - main.timer
	for i in n:
		var c: Vector2 = main.conveyor_slot(i)
		var card := Rect2(c - Vector2(110, 110), Vector2(220, 220))
		panel(card, Color.WHITE if main.conveyor[i] != "" else Color(0.7, 0.7, 0.7, 0.6))
		for k in main.pick_order.size():
			var pi: int = main.pick_order[k]
			var p: Dictionary = main.players[pi]
			if p["piece"] == "" and p["sel"] == i:
				var col = main.player_color(pi)
				draw_rect(card.grow(4 + k * 9), col, false, 7)
				var waiting: bool = elapsed < p["unlock"]
				Kit.text(self, Vector2(card.position.x + 8 + k * 54, card.end.y + 44), "P%d%s" % [pi + 1, "…" if waiting else ""], 30, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Kit.CREAM)
		var id: String = main.conveyor[i]
		if id != "":
			Kit.text(self, Vector2(card.position.x, card.position.y + 40), PIECE_NAMES[id], 30, DARK, HORIZONTAL_ALIGNMENT_CENTER, 220)
			Kit.text(self, Vector2(card.position.x, card.end.y - 16), PIECE_HINT[id], 20, Color("#6b5a70"), HORIZONTAL_ALIGNMENT_CENTER, 220)
	var y := 820
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		if p["piece"] != "":
			Kit.sticker(self, Vector2(0, y), "P%d pegou %s" % [i + 1, PIECE_NAMES[p["piece"]]], 30, main.player_color(i), HORIZONTAL_ALIGNMENT_CENTER, 1920)
			y += 44

func _draw_build() -> void:
	Kit.sticker(self, Vector2(0, 140), "CONSTRUA!  setas movem · MARRETA gira · PULAR coloca", 34, DARK, HORIZONTAL_ALIGNMENT_CENTER, 1920)

# ---------------------------------------------------------------- corrida / rodada
func _draw_run() -> void:
	if main.mode == "demolicao" and main.demo.banner_t > 0.0:
		_ribbon_pop(main.demo.banner, 330, 1000, 62)
		if main.countdown > 0.0:
			var note := Rect2(360, 740, 1200, 116)
			panel(note)
			Kit.text(self, Vector2(note.position.x, note.position.y + 50), String(main.demo.arena.get("dica", "")), 34, DARK, HORIZONTAL_ALIGNMENT_CENTER, note.size.x)
			Kit.text(self, Vector2(note.position.x, note.position.y + 90), "MARRETA quebra e empurra  ·  PULE na cabeça  ·  ITEM usa o que você pegou", 24, Kit.SOFT, HORIZONTAL_ALIGNMENT_CENTER, note.size.x)
	if main.countdown > 0.0:
		var go: bool = main.countdown <= 0.6
		var s := "VAI!" if go else "PRONTOS?"
		var k := clampf((0.6 - main.countdown) / 0.15, 0.0, 1.0) if go else 1.0
		var sc := lerpf(1.6, 1.0, k)
		draw_set_transform(Vector2(960, 600), 0.0, Vector2(sc, sc))
		Kit.sticker(self, Vector2(-600, 40), s, 140, Color("#f2c84b") if go else Color("#4f86d9"), HORIZONTAL_ALIGNMENT_CENTER, 1200)
		draw_set_transform(Vector2.ZERO)

# ---------------------------------------------------------------- placar
func _draw_demo_score() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	_ribbon_pop(main.demo.banner, 96, 1400, 64)
	var goal := int(main.demo.cfg["rounds_to_win"])
	var order: Array = range(main.players.size())
	order.sort_custom(func(x, y): return int(main.players[x]["score"]) > int(main.players[y]["score"]) or (int(main.players[x]["score"]) == int(main.players[y]["score"]) and x < y))
	var n: int = order.size()
	var rowh := 140.0
	var y0 := 540.0 - (n * (rowh + 30.0)) / 2.0 + 40.0
	for k in n:
		var i: int = order[k]
		var p: Dictionary = main.players[i]
		var win: bool = i == main.demo.round_winner
		var r := Rect2(420, y0 + k * (rowh + 30.0), 1080, rowh)
		var rot: float = [-0.017, 0.017, -0.01, 0.014][k % 4]
		draw_set_transform(r.get_center(), rot)
		var lr := Rect2(-r.size / 2.0, r.size)
		Kit.chunk(self, lr, Color("#ffe48a") if win else Kit.CREAM, 28)
		Kit.text(self, Vector2(lr.position.x + 150, lr.position.y + 60), "P%d" % (i + 1), 38, Data.COLORS[p["color"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		if pname(i) != "P%d" % (i + 1):
			fit_text(Vector2(lr.position.x + 150, lr.position.y + 106), pname(i), 34, DARK, 290)
		var sz := minf(66.0, 560.0 / goal)
		for s2 in goal:
			Kit.star(self, Vector2(lr.position.x + 490 + s2 * sz, 0), sz * 0.95, s2 < int(p["score"]))
		draw_set_transform(Vector2.ZERO)
		_head(i, r.position + Vector2(76, rowh / 2.0), 54, Kit.INK, Color.WHITE, "vitoria" if win else "normal")
		if win:
			var bc := r.position + Vector2(r.size.x + 10, 8)
			_over_cmds.append(func(ci: CanvasItem):
				Kit.burst(ci, bc, 64, t * 0.6, 6.0)
				Kit.text(ci, bc + Vector2(-80, 18), "+1", 52, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 160, 12))

func _draw_score() -> void:
	if main.mode == "demolicao":
		_draw_demo_score()
		return
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	var target := int(Data.scoring["target_points"])
	var board := Rect2(200, 200, 1520, 200 + main.players.size() * 140)
	panel(board)
	_ribbon_pop("PLACAR · meta %d" % target, 200, 900, 54)
	if main.round_points.size() > 0 and main.round_points[0]["all_finished"]:
		Kit.text(self, Vector2(board.position.x, 320), "Fácil demais! Todo mundo chegou: ninguém leva os +10.", 30, Color("#8a5a10"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x)
	if main.embargo_msg != "":
		Kit.text(self, Vector2(board.position.x, 356), main.embargo_msg, 30, Color("#8a5a10"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x)
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		var b: Dictionary = main.round_points[i] if i < main.round_points.size() else {}
		var y: float = 390 + i * 140
		var col = main.player_color(i)
		Kit.text(self, Vector2(260, y + 60), "P%d" % (i + 1), 52, Data.TEXT_COLORS[p["color"]])
		var bar := Rect2(380, y + 10, 1000, 60)
		draw_rect(bar, Color(0.85, 0.8, 0.7))
		var prev: int = p["score"] - int(b.get("total", 0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(p["score"]) / target, 0, 1), bar.size.y)), col.darkened(0.25))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(prev) / target, 0, 1), bar.size.y)), col)
		Kit.text(self, Vector2(1400, y + 55), "%d" % p["score"], 48, DARK)
		var parts := []
		if b.get("finish", 0) > 0: parts.append("+%d chegou" % b["finish"])
		if b.get("first", 0) > 0: parts.append("+%d primeiro" % b["first"])
		if b.get("kills", 0) > 0: parts.append("+%d eliminações" % b["kills"])
		if b.get("hammer", 0) > 0: parts.append("+%d marreta" % b["hammer"])
		Kit.text(self, Vector2(380, y + 110), "  ".join(parts) if parts.size() > 0 else "+0", 26, Color("#6b5a70"))

# ---------------------------------------------------------------- vitória
func _draw_win() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	for k in 70:   # confete
		var x := fposmod(k * 137.0 + t * (40 + k % 7 * 15), 1920.0)
		var y := fposmod(k * 71.0 + t * (120 + k % 5 * 30), 1080.0)
		draw_set_transform(Vector2(x, y), t * (2.0 + k % 3) + k)
		draw_rect(Rect2(-9, -12, 18, 24), Kit.INK)
		draw_rect(Rect2(-7, -10, 14, 20), Data.COLORS[k % 4])
	draw_set_transform(Vector2.ZERO)
	var w: int = main.winner
	var pw: Dictionary = main.players[w]
	Kit.burst(self, Vector2(960, 640), 330, t * 0.15, 8.0)
	_ribbon_pop("%s VENCEU!" % pname(w).to_upper(), 100, 1600, 86)
	var goal := int(main.demo.cfg["rounds_to_win"]) if main.mode == "demolicao" else 0
	var sw := 46.0 * goal
	var px := 960.0 - (90.0 + sw) / 2.0
	Kit.text(self, Vector2(px, 222), "P%d" % (w + 1), 44, Data.COLORS[pw["color"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	for k in goal:
		Kit.star(self, Vector2(px + 110 + k * 46, 206), 42, k < int(pw["score"]))
	RobotVis.draw_robot(self, _look(pw), RobotVis.victory_pose(t, pw.get("skin", {}).get("danca", 0)), Transform2D(0.0, Vector2(5.2, 5.2), 0.0, Vector2(960, 930)))
	draw_set_transform(Vector2.ZERO)
	if main.mode == "demolicao":
		_draw_titles()
	Kit.pad_hint(self, 960, 1040, [["baixo"], " jogar de novo      ", ["direita"], " menu"], 32, Color.WHITE, PlayerInput.main_pad_type(), 8)

## Títulos da partida (a partir das estatísticas), em cartões dos lados do vencedor.
func _draw_titles() -> void:
	var titles := [["MARRETEIRO", "derrubadas", "mais derrubou rivais", "derrubada"], ["DEMOLIDOR", "caixotes", "mais quebrou caixotes", "caixote"],
		["DESASTRADO", "quedas", "mais caiu sozinho", "queda"]]
	var spots := [Rect2(70, 330, 390, 236), Rect2(1460, 330, 390, 236), Rect2(1460, 610, 390, 236)]
	for k in titles.size():
		var tt: Array = titles[k]
		var best := -1
		var bv := 0
		for i in main.players.size():
			var v: int = int(main.players[i]["stats"][tt[1]])
			if v > bv:
				bv = v
				best = i
		var r: Rect2 = spots[k]
		var rot: float = [-0.035, 0.035, -0.026][k]
		draw_set_transform(r.get_center(), rot)
		var lr := Rect2(-r.size / 2.0, r.size)
		Kit.chunk(self, lr, Kit.CREAM, 26)
		Kit.text(self, Vector2(lr.position.x + 24, lr.position.y + 54), tt[0], 38, Kit.YEL, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
		Kit.text(self, Vector2(lr.position.x + 24, lr.position.y + 86), tt[2], 22, Kit.SOFT)
		if best >= 0:
			fit_text(Vector2(lr.position.x + 124, lr.position.y + 156), pname(best), 32, DARK, 240)
			Kit.text(self, Vector2(lr.position.x + 124, lr.position.y + 188), "%d %s%s" % [bv, tt[3], "" if bv == 1 else "s"], 22, Kit.SOFT)
		else:
			Kit.text(self, Vector2(lr.position.x + 24, lr.position.y + 170), "ninguém", 30, Kit.SOFT)
		draw_set_transform(Vector2.ZERO)
		if best >= 0:
			_head(best, r.get_center() + Vector2(-r.size.x / 2.0 + 64, 44).rotated(rot), 40, Kit.INK, Color.WHITE)
