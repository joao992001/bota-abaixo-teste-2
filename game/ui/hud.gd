extends Control
## HUD e telas da partida no estilo papel e giz: etiquetas de papel por jogador, placa de madeira da rodada,
## faixas de aviso, contagem em "adesivo", entrada de jogadores, placar e vitória. Menus em ui/menus.gd.

const Kit := preload("res://ui/kit.gd")
const Piece := preload("res://pieces/piece.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const PIECE_NAMES := {"P01": "Viga", "P02": "Mola", "P03": "Serra", "P04": "Esteira"}
const PIECE_HINT := {"P01": "dono atravessa por baixo", "P02": "dono 5 tiles, rival 3", "P03": "elimina rivais", "P04": "a favor do dono"}
const DIM := Color(0.1, 0.3, 0.35, 0.4)
const DARK := Color("#1f3a40")

var main: Node
var t := 0.0
var _banner := ""
var _banner_age := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(dt: float) -> void:
	t += dt
	_banner_age += dt

func text(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0) -> void:
	Kit.text(self, pos, s, sz, col, align, w, outline)

func panel(r: Rect2, tint := Color.WHITE) -> void:
	Kit.paper(self, r, tint)

func _look(p: Dictionary) -> Dictionary:
	return {"color": p["color"], "model": p["model"], "acc": p["acc"], "skin": p.get("skin", {})}

func _draw() -> void:
	var S = main.S
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
	if main.state in [S.PICK, S.BUILD, S.RUN, S.SCORE]:
		_draw_tags()
	for fl in main.floaters:
		var k: float = fl["t"] / 1.2
		var c: Color = fl["color"]
		c.a = 1.0 - k * k
		var p: Vector2 = main.to_screen(fl["pos"]) + Vector2(-260, -k * 60)
		Kit.text(self, p, fl["text"], 40, c, HORIZONTAL_ALIGNMENT_CENTER, 520, 10, Color(1, 0.98, 0.94, c.a))
	if main.sandbox and not main.paused:
		main.oficina.draw(self)
	if main.paused:
		main.menus.draw(self)
	_draw_toasts()
	if main.debug:
		var ids: Array = main.implemented_ids()
		text(Vector2(20, 1060), "DEBUG  F2 pula fase · F3 peça: %s · F4 dono: P%d · clique coloca/remove · F6 lento" % [PIECE_NAMES[ids[main.debug_piece]], main.debug_owner + 1], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)

# ---------------------------------------------------------------- etiquetas e placa (topo)
func _draw_tags() -> void:
	var S = main.S
	var goal := int(main.demo.cfg["rounds_to_win"])
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		var x: float = 14.0 + i * 262.0
		var r := Rect2(x, 6, 250, 78)
		var rot := (-0.015 if i % 2 == 0 else 0.015)
		draw_set_transform(r.get_center(), rot)
		var lr := Rect2(-r.size / 2.0, r.size)
		panel(lr)
		draw_rect(Rect2(lr.position + Vector2(8, 8), Vector2(8, lr.size.y - 16)), Data.COLORS[p["color"]])
		draw_set_transform(Vector2.ZERO)
		var out := false
		var robot = main.robots[i] if i < main.robots.size() else null
		if main.state == S.RUN and robot != null and (not robot.alive):
			out = true
		var pose: Dictionary = RobotVis.idle_pose(t + i)
		if out:
			pose["expr"] = "eliminado"
		RobotVis.draw_robot(self, _look(p), pose, Transform2D(0.0, Vector2(0.62, 0.62), 0.0, Vector2(x + 52, 82)))
		draw_set_transform(Vector2.ZERO)
		Kit.text(self, Vector2(x + 92, 40), "P%d" % (i + 1), 30, Data.TEXT_COLORS[p["color"]])
		if main.mode == "demolicao":
			var sz := minf(22.0, 96.0 / goal)
			for k in goal:
				Kit.star(self, Vector2(x + 102 + k * sz, 64), sz, k < int(p["score"]))
			if robot != null and robot.alive:
				var dc: Color = main.dmg_color(robot.dmg)
				Kit.text(self, Vector2(x + 140, 70), "%d%%" % int(robot.dmg), 34, dc, HORIZONTAL_ALIGNMENT_RIGHT, 104, 8, DARK)
			if robot != null and main.state == S.RUN and robot.alive:
				var fx: Dictionary = robot.fx_flags()
				var ix: float = x + 132.0
				for k in ["item", "martelao", "capacete", "mola", "ima", "foguete"]:
					var on = fx[k] != "" if k == "item" else fx[k]
					if on:
						draw_texture_rect(Data.tex("itens/" + (String(fx["item"]) if k == "item" else k)), Rect2(ix, 12, 34, 34), false)
						ix += 26
		else:
			Kit.text(self, Vector2(x + 150, 44), "%d" % p["score"], 34, DARK)
			Kit.text(self, Vector2(x + 92, 70), "pontos", 18, Color("#4a5a60"))
		if main.mode == "demolicao" and main.state in [S.RUN, S.SCORE]:
			_draw_sub_badge(i, x)
		if out:
			draw_rect(r, Color(0.95, 0.93, 0.88, 0.45))
			Kit.text(self, Vector2(x + 150, 66), "FORA", 26, Color("#8a5a5a"))
	# avisos de derrubada (à direita, embaixo da placa)
	if main.mode == "demolicao":
		var fy := 100.0
		for f in main.demo.feed:
			var a: float = clampf((4.5 - f["t"]) / 0.5, 0.0, 1.0)
			var fr := Rect2(1560, fy, 346, 40)
			panel(fr, Color(1, 1, 1, a))
			var p2: Dictionary = main.players[f["col"]] if f["col"] < main.players.size() else {"color": 0}
			Kit.text(self, Vector2(fr.position.x, fy + 29), f["text"], 24, Color(Data.TEXT_COLORS[p2["color"]], a), HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
			fy += 46.0
	# placa de madeira da rodada
	var sign := Rect2(1520, 6, 386, 78)
	Kit.wood(self, sign)
	var label := "RODADA %d" % main.round_no
	if main.mode == "demolicao" and main.demo.submode() == "placar" and main.state == S.RUN:
		var tl: float = maxf(main.demo.time_left, 0.0)
		label = "R%d  ·  %d:%02d" % [main.round_no, int(tl) / 60, int(tl) % 60]
	if main.mode == "demolicao" and main.state == S.RUN:
		_draw_event_note()
	if main.mode != "demolicao":
		var names := {S.PICK: "ESCOLHA", S.BUILD: "CONSTRUÇÃO", S.RUN: "CORRIDA", S.SCORE: "PLACAR"}
		label = "R%d · %s %d" % [main.round_no, names.get(main.state, ""), ceili(maxf(main.timer, 0.0))]
	Kit.text(self, Vector2(sign.position.x, 56), label, 34, Kit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 7, Color("#5a3a10"))

## Selo embaixo da etiqueta: vidas (corações) ou pontos da rodada, conforme o submodo.
func _draw_sub_badge(i: int, x: float) -> void:
	var d = main.demo
	match d.submode():
		"vidas":
			var n: int = int(d.lives.get(i, 0))
			var tot: int = int(d.sub.get("vidas", 3))
			panel(Rect2(x + 40, 84, 30 + tot * 34, 40))
			for k in tot:
				_heart(Vector2(x + 70 + k * 34, 104), 13.0, k < n)
		"placar":
			panel(Rect2(x + 40, 84, 170, 40))
			Kit.text(self, Vector2(x + 40, 115), "%d pts" % int(d.points.get(i, 0)), 28, DARK, HORIZONTAL_ALIGNMENT_CENTER, 170)
		"batata":
			if d.bomb_holder == i:
				panel(Rect2(x + 40, 84, 170, 40), Color(1, 0.85, 0.8))
				draw_texture_rect(Data.tex("itens/dinamite"), Rect2(x + 50, 86, 34, 34), false)
				Kit.text(self, Vector2(x + 86, 115), "%ds" % ceili(d.bomb_fuse), 28, Color("#d42035"))

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
	draw_polyline(pts, DARK, 3.0, true)

## Papel do evento ativo (nome + barra de tempo), entre as etiquetas e a placa.
func _draw_event_note() -> void:
	var ev = main.events
	if ev.phase == "":
		return
	var r := Rect2(1090, 10, 410, 70)
	var warn: bool = ev.phase == "aviso"
	panel(r, Color(1, 0.88, 0.8) if warn else Color.WHITE)
	var nm := String(ev.current.get("nome", "")).to_upper()
	Kit.text(self, Vector2(r.position.x, 46), ("EM BREVE: " if warn else "") + nm, 30 if not warn else 26, Color("#d42035") if warn else DARK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if not warn:
		var k: float = clampf(ev.phase_t / float(ev.current.get("dur", 1)), 0.0, 1.0)
		draw_rect(Rect2(r.position.x + 30, 60, (r.size.x - 60) * k, 8), Color("#f2c84b"))

## Avisos de controle conectado/desconectado (canto de baixo, à esquerda).
func _draw_toasts() -> void:
	var y := 140.0
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
		y += 76.0

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
	_ribbon_pop("QUEM VAI JOGAR?", 110, 860, 60)
	var mname := "DEMOLIÇÃO" if main.mode == "demolicao" else "CLÁSSICO"
	Kit.sticker(self, Vector2(0, 236), "modo %s" % mname, 40, DARK, HORIZONTAL_ALIGNMENT_CENTER, 1920)
	for i in 4:
		var r := Rect2(220 + i * 380, 290, 340, 470)
		var rot := sin(i * 2.3) * 0.025
		draw_set_transform(r.get_center(), rot)
		var lr := Rect2(-r.size / 2.0, r.size)
		if i < main.players.size():
			var p: Dictionary = main.players[i]
			panel(lr)
			draw_rect(Rect2(lr.position + Vector2(14, 14), Vector2(lr.size.x - 28, 10)), Data.COLORS[p["color"]])
			draw_set_transform(Vector2.ZERO)
			var tt := t + i * 0.77
			RobotVis.draw_robot(self, _look(p), RobotVis.idle_pose(tt), Transform2D(0.0, Vector2(2.4, 2.4), 0.0, r.get_center() + Vector2(-8, 130)))
			draw_set_transform(Vector2.ZERO)
			Kit.text(self, Vector2(r.position.x, r.position.y + 84), "P%d" % (i + 1), 52, Data.TEXT_COLORS[p["color"]], HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			var lab: String = PlayerInput.label(p["dev"])
			if p.get("bot", false):
				lab = "BOT · %s" % main.bots.LEVEL_NAMES[p.get("level", 1)]
			Kit.text(self, Vector2(r.position.x, r.position.y + 118), lab, 22, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			Kit.text(self, Vector2(r.position.x, r.end.y - 62), "◄ %s ►" % Data.COLOR_NAMES[p["color"]], 28, DARK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			Kit.text(self, Vector2(r.position.x, r.end.y - 28), "▲▼ %s  ·  %s" % [p["skin"]["nome"] if not p.get("skin", {}).is_empty() else Data.MODEL_NAMES[p["model"]], Data.ACC_NAMES[p["acc"]]], 22, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			panel(lr, Color(1, 1, 1, 0.55))
			draw_set_transform(Vector2.ZERO)
			var pst: String = PlayerInput.main_pad_type()
			Kit.text(self, Vector2(r.position.x, r.get_center().y - 30), "para entrar:", 30, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			Kit.pad_hint(self, r.get_center().x, r.get_center().y + 20, [["baixo"], " no controle"], 30, Color("#4a5a60"), pst)
			Kit.text(self, Vector2(r.position.x, r.get_center().y + 66), "Espaço / Ctrl dir. no teclado", 22, Color("#6a7a80"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var w := Rect2(160, 790, 1600, 250)
	panel(w)
	var st: String = PlayerInput.main_pad_type()
	var g := Color("#4a5a60")
	Kit.pad_hint(self, 960, 838, [["start"], " começa (2+)   ·   ", ["esquerda"], " troca o chapéu   ·   ◄► cor  ▲▼ robô   ·   ", ["cima"], " + bot   ·   ", ["direita"], " sai"], 30, DARK, st)
	Kit.pad_hint(self, 960, 892, ["No jogo:  ", ["baixo"], " pula   ", ["esquerda"], " ou ", ["rb"], " marreta   ", ["cima"], " ou ", ["lb"], " item   ", ["start"], " pausa"], 26, g, st)
	Kit.text(self, Vector2(w.position.x, 940), "Teclado A: WASD · Espaço pula · F marreta · G item (+bot)     Teclado B: setas · Ctrl dir. pula · ponto marreta · vírgula item", 22, g, HORIZONTAL_ALIGNMENT_CENTER, w.size.x)
	var pads: Array = Input.get_connected_joypads()
	var pl := "Nenhum controle detectado — conecte por USB ou Bluetooth (OPÇÕES ▸ TESTAR CONTROLES)" if pads.is_empty() \
		else "Controles: " + "  ·  ".join(pads.map(func(j): return "%d) %s" % [j + 1, PlayerInput.pad_name("joy%d" % j)]))
	Kit.text(self, Vector2(w.position.x + 20, 980), pl, 22, Color("#a01528") if pads.is_empty() else Color("#3c9a46"), HORIZONTAL_ALIGNMENT_CENTER, w.size.x - 40)
	Kit.text(self, Vector2(w.position.x, 1018), "teclado: B/N/M bots e dificuldade (%s)  ·  F11 tela cheia" % main.bots.LEVEL_NAMES[main.bot_level], 19, Color("#6a7a80"), HORIZONTAL_ALIGNMENT_CENTER, w.size.x)

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
			Kit.text(self, Vector2(card.position.x, card.end.y - 16), PIECE_HINT[id], 20, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, 220)
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
			var note := Rect2(360, 900, 1200, 110)
			panel(note)
			Kit.text(self, Vector2(note.position.x, 948), String(main.demo.arena.get("dica", "")), 34, DARK, HORIZONTAL_ALIGNMENT_CENTER, note.size.x)
			Kit.text(self, Vector2(note.position.x, 988), "MARRETA quebra e empurra  ·  PULE na cabeça  ·  item: G / vírgula / Y", 24, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, note.size.x)
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
	var board := Rect2(460, 250, 1000, 160 + main.players.size() * 140)
	panel(board)
	_ribbon_pop(main.demo.banner, 250, 1060, 54)
	var goal := int(main.demo.cfg["rounds_to_win"])
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		var y: float = board.position.y + 140 + i * 140
		var pose: Dictionary = RobotVis.victory_pose(t) if i == main.demo.round_winner else RobotVis.idle_pose(t + i)
		RobotVis.draw_robot(self, _look(p), pose, Transform2D(0.0, Vector2(1.4, 1.4), 0.0, Vector2(board.position.x + 110, y + 60)))
		draw_set_transform(Vector2.ZERO)
		Kit.text(self, Vector2(board.position.x + 180, y + 20), "P%d" % (i + 1), 50, Data.TEXT_COLORS[p["color"]])
		var sz := minf(70.0, 640.0 / goal)
		for k in goal:
			Kit.star(self, Vector2(board.position.x + 330 + k * sz, y), sz * 0.92, k < int(p["score"]))

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
		Kit.text(self, Vector2(380, y + 110), "  ".join(parts) if parts.size() > 0 else "+0", 26, Color("#4a5a60"))

# ---------------------------------------------------------------- vitória
func _draw_win() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), DIM)
	for k in 70:   # confete de papel
		var x := fposmod(k * 137.0 + t * (40 + k % 7 * 15), 1920.0)
		var y := fposmod(k * 71.0 + t * (120 + k % 5 * 30), 1080.0)
		draw_set_transform(Vector2(x, y), t * (2.0 + k % 3) + k)
		draw_rect(Rect2(-7, -10, 14, 20), Data.COLORS[k % 4])
		draw_rect(Rect2(-7, -10, 14, 5), Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO)
	var w: int = main.winner
	var pw: Dictionary = main.players[w]
	_ribbon_pop("P%d  VENCEU!" % (w + 1), 230, 1100, 90)
	RobotVis.draw_robot(self, _look(pw), RobotVis.victory_pose(t, pw.get("skin", {}).get("danca", 0)), Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(960, 830)))
	draw_set_transform(Vector2.ZERO)
	if main.mode == "demolicao":
		_draw_titles()
	var note := Rect2(560, 900, 800, 100)
	panel(note)
	Kit.text(self, Vector2(note.position.x, 962), "PULAR jogar de novo  ·  ESC menu", 36, DARK, HORIZONTAL_ALIGNMENT_CENTER, note.size.x)

## Títulos da partida (a partir das estatísticas) e números de cada jogador.
func _draw_titles() -> void:
	var titles := [["MARRETEIRO", "derrubadas", "mais derrubou rivais"], ["DEMOLIDOR", "caixotes", "mais quebrou caixotes"], ["DESASTRADO", "quedas", "mais caiu"]]
	var r := Rect2(60, 330, 560, 120 + titles.size() * 110)
	panel(r)
	Kit.text(self, Vector2(r.position.x, r.position.y + 62), "TÍTULOS", 44, DARK, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y: float = r.position.y + 110
	for tt in titles:
		var best := -1
		var bv := 0
		for i in main.players.size():
			var v: int = int(main.players[i]["stats"][tt[1]])
			if v > bv:
				bv = v
				best = i
		Kit.text(self, Vector2(r.position.x + 40, y + 40), tt[0], 36, Color("#8a5a10"))
		if best >= 0:
			Kit.text(self, Vector2(r.position.x + 330, y + 40), "P%d  (%d)" % [best + 1, bv], 36, Data.TEXT_COLORS[main.players[best]["color"]])
		else:
			Kit.text(self, Vector2(r.position.x + 330, y + 40), "—", 36, Color("#9aa4ae"))
		Kit.text(self, Vector2(r.position.x + 40, y + 76), tt[2], 22, Color("#4a5a60"))
		y += 110
	var r2 := Rect2(1300, 330, 560, 120 + main.players.size() * 80)
	panel(r2)
	Kit.text(self, Vector2(r2.position.x, r2.position.y + 62), "NÚMEROS", 44, DARK, HORIZONTAL_ALIGNMENT_CENTER, r2.size.x)
	for i in main.players.size():
		var st: Dictionary = main.players[i]["stats"]
		var yy: float = r2.position.y + 130 + i * 80
		Kit.text(self, Vector2(r2.position.x + 40, yy), "P%d" % (i + 1), 36, Data.TEXT_COLORS[main.players[i]["color"]])
		Kit.text(self, Vector2(r2.position.x + 120, yy), "%d derrub. · %d caixa%s · %d queda%s" % [st["derrubadas"], st["caixotes"], "" if st["caixotes"] == 1 else "s", st["quedas"], "" if st["quedas"] == 1 else "s"], 24, DARK)
