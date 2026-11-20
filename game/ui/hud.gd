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
	return {"color": p["color"], "model": p["model"], "acc": p["acc"]}

func _draw() -> void:
	var S = main.S
	if main.state in main.MENU_STATES:
		main.menus.draw(self)
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
		var p: Vector2 = main.to_screen(fl["pos"]) + Vector2(-100, -k * 60)
		Kit.text(self, p, fl["text"], 40, c, HORIZONTAL_ALIGNMENT_CENTER, 200, 10, Color(1, 0.98, 0.94, c.a))
	if main.paused:
		main.menus.draw(self)
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
			var sz := minf(26.0, 150.0 / goal)
			for k in goal:
				Kit.star(self, Vector2(x + 106 + k * sz, 62), sz, k < int(p["score"]))
			if robot != null and main.state == S.RUN and robot.alive:
				var fx: Dictionary = robot.fx_flags()
				var ix: float = x + 150.0
				for k in ["item", "martelao", "capacete", "mola"]:
					var on = fx[k] != "" if k == "item" else fx[k]
					if on:
						draw_texture_rect(Data.tex("itens/" + ("dinamite" if k == "item" else k)), Rect2(ix, 12, 34, 34), false)
						ix += 30
		else:
			Kit.text(self, Vector2(x + 150, 44), "%d" % p["score"], 34, DARK)
			Kit.text(self, Vector2(x + 92, 70), "pontos", 18, Color("#4a5a60"))
		if out:
			draw_rect(r, Color(0.95, 0.93, 0.88, 0.45))
			Kit.text(self, Vector2(x + 150, 66), "FORA", 26, Color("#8a5a5a"))
	# placa de madeira da rodada
	var sign := Rect2(1520, 6, 386, 78)
	Kit.wood(self, sign)
	var label := "RODADA %d" % main.round_no
	if main.mode != "demolicao":
		var names := {S.PICK: "ESCOLHA", S.BUILD: "CONSTRUÇÃO", S.RUN: "CORRIDA", S.SCORE: "PLACAR"}
		label = "R%d · %s %d" % [main.round_no, names.get(main.state, ""), ceili(maxf(main.timer, 0.0))]
	Kit.text(self, Vector2(sign.position.x, 56), label, 34, Kit.CREAM, HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 7, Color("#5a3a10"))

## Faixa de aviso que "salta" quando o texto muda.
func _ribbon_pop(txt: String, y: float, w: float, size: int, alpha := 1.0) -> void:
	if txt != _banner:
		_banner = txt
		_banner_age = 0.0
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
			Kit.text(self, Vector2(r.position.x, r.end.y - 28), "▲▼ %s  ·  %s" % [Data.MODEL_NAMES[p["model"]], Data.ACC_NAMES[p["acc"]]], 22, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			panel(lr, Color(1, 1, 1, 0.55))
			draw_set_transform(Vector2.ZERO)
			Kit.text(self, Vector2(r.position.x, r.get_center().y), "aperte PULAR", 36, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			Kit.text(self, Vector2(r.position.x, r.get_center().y + 40), "ou B para bot", 26, Color("#6a7a80"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var w := Rect2(160, 800, 1600, 230)
	panel(w)
	Kit.text(self, Vector2(w.position.x, 850), "ENTER / START começa (2+)  ·  MARRETA troca o chapéu  ·  BACKSPACE / ESC sai", 32, DARK, HORIZONTAL_ALIGNMENT_CENTER, w.size.x)
	Kit.text(self, Vector2(w.position.x, 900), "Teclado A: WASD · Espaço pula · F marreta · G item      Teclado B: setas · Ctrl dir. pula · ponto marreta · vírgula item", 24, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, w.size.x)
	Kit.text(self, Vector2(w.position.x, 940), "Controle: A pula · X marreta · Y item · Select sai      BOTS: B adiciona · N remove · M dificuldade (%s)" % main.bots.LEVEL_NAMES[main.bot_level], 24, Color("#4a5a60"), HORIZONTAL_ALIGNMENT_CENTER, w.size.x)
	Kit.text(self, Vector2(w.position.x, 990), "F11 tela cheia", 20, Color("#6a7a80"), HORIZONTAL_ALIGNMENT_CENTER, w.size.x)

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
	RobotVis.draw_robot(self, _look(pw), RobotVis.victory_pose(t), Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(960, 830)))
	draw_set_transform(Vector2.ZERO)
	var note := Rect2(560, 900, 800, 100)
	panel(note)
	Kit.text(self, Vector2(note.position.x, 962), "PULAR jogar de novo  ·  ESC menu", 36, DARK, HORIZONTAL_ALIGNMENT_CENTER, note.size.x)
