extends Control
## Faixa de placar (56 px) + telas de cada fase. Desenho por código; fonte padrão da Godot.

const Piece := preload("res://pieces/piece.gd")
const RobotVis := preload("res://player/robot_visual.gd")
const PIECE_NAMES := {"P01": "Viga", "P02": "Mola", "P03": "Serra", "P04": "Esteira"}
const PIECE_HINT := {
	"P01": "dono atravessa por baixo",
	"P02": "dono 5 tiles, rival 3",
	"P03": "elimina rivais",
	"P04": "a favor do dono",
}

var main: Node
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func text(pos: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0) -> void:
	if outline > 0:
		draw_string_outline(font, pos, s, align, w, sz, outline, Data.INK)
	draw_string(font, pos, s, align, w, sz, col)

func panel(r: Rect2, col := Color("#2a1a2e")) -> void:
	draw_rect(r.grow(6), Data.INK)
	draw_rect(r, col)

func _draw() -> void:
	var S = main.S
	_draw_strip()
	match main.state:
		S.JOIN: _draw_join()
		S.PICK: _draw_pick()
		S.BUILD: _draw_build()
		S.RUN: _draw_run()
		S.SCORE: _draw_score()
		S.WIN: _draw_win()
	for fl in main.floaters:
		var k: float = fl["t"] / 1.2
		var c: Color = fl["color"]
		c.a = 1.0 - k * k
		text(fl["pos"] + Vector2(-60, -k * 60), fl["text"], 44, c, HORIZONTAL_ALIGNMENT_CENTER, 120, 12)
	if main.debug:
		var ids: Array = main.implemented_ids()
		text(Vector2(20, 1060), "DEBUG  F2 pula fase · F3 peça: %s · F4 dono: P%d · clique coloca/remove · F6 lento" % [PIECE_NAMES[ids[main.debug_piece]], main.debug_owner + 1], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)

func _draw_strip() -> void:
	draw_rect(Rect2(0, 0, 1920, 56), Color("#22152a"))
	draw_rect(Rect2(0, 52, 1920, 4), Data.INK)
	var S = main.S
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		var x = 30 + i * 260
		var col: Color = Data.COLORS[p["color"]]
		draw_circle(Vector2(x + 20, 27), 19, Data.INK)
		draw_circle(Vector2(x + 20, 27), 15, col)
		Piece.draw_symbol(self, p["color"], Vector2(x + 20, 27), 8, Data.INK)
		text(Vector2(x + 48, 40), "P%d  %d" % [i + 1, p["score"]], 30, col)
		if main.state == S.RUN and i < main.robots.size():
			var r = main.robots[i]
			if r.hammer_left > 0:
				draw_rect(Rect2(x + 170, 16, 26, 14), Color("#9aa3af"))
				draw_rect(Rect2(x + 181, 30, 5, 14), Color("#c98b4e"))
			if r.finished:
				text(Vector2(x + 205, 40), "✓", 30, Color.WHITE)
			elif not r.alive:
				text(Vector2(x + 205, 40), "✗", 30, Color("#9aa3af"))
	var names := {S.JOIN: "ENTRADA", S.PICK: "ESCOLHA", S.BUILD: "CONSTRUÇÃO", S.RUN: "CORRIDA", S.SCORE: "PLACAR", S.WIN: "VITÓRIA"}
	var label: String = names[main.state]
	if main.state in [S.PICK, S.BUILD, S.RUN, S.SCORE]:
		label = "RODADA %d · %s · %d" % [main.round_no, label, ceili(maxf(main.timer, 0.0))]
	text(Vector2(1200, 40), label, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 690)

func _draw_join() -> void:
	draw_rect(Rect2(0, 56, 1920, 1024), Color(0.1, 0.05, 0.12, 0.55))
	text(Vector2(0, 250), "BOTA-ABAIXO", 120, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 28)
	text(Vector2(0, 320), "Aperte PULAR para entrar  ·  ◄ ► cor  ·  ▲ ▼ chapéu  ·  ENTER / START começa (2+)", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
	for i in 4:
		var r := Rect2(240 + i * 370, 400, 330, 420)
		panel(r, Color("#3b2a46"))
		if i < main.players.size():
			var p: Dictionary = main.players[i]
			var col: Color = Data.COLORS[p["color"]]
			RobotVis.draw_robot(self, p["color"], "normal", 0.0, Time.get_ticks_msec() / 400.0, false, p["acc"], false, Transform2D(0.0, Vector2(2.3, 2.3), 0.0, r.get_center() + Vector2(-14, 140)))
			draw_set_transform(Vector2.ZERO)
			text(r.position + Vector2(0, 52), "P%d" % (i + 1), 46, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 10)
			text(r.position + Vector2(0, 390), "◄ %s ►  ▲▼ %s" % [Data.COLOR_NAMES[p["color"]], Data.ACC_NAMES[p["acc"]]], 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		else:
			text(r.position + Vector2(0, 220), "livre", 40, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	text(Vector2(0, 900), "Teclado A: WASD + Espaço + Shift   ·   Teclado B: setas + Ctrl + Enter num.   ·   Controle: A pula, X marreta", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 6)

func _dev_name(dev: String) -> String:
	match dev:
		"kb_a": return "teclado A"
		"kb_b": return "teclado B"
	return "controle" if dev.begins_with("joy") else dev

func _draw_pick() -> void:
	draw_rect(Rect2(0, 56, 1920, 1024), Color(0.1, 0.05, 0.12, 0.45))
	text(Vector2(0, 300), "ESCOLHA SUA PEÇA", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 16)
	text(Vector2(0, 360), "quem tem menos pontos escolhe primeiro  ·  ◄ ► e PULAR", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
	var n: int = main.conveyor.size()
	var belt := Rect2(960 - n * 125 - 20, 440, n * 250 + 40, 240)
	panel(belt, Color("#4a4f5c"))
	var elapsed: float = main.timers("pick_seconds") - main.timer
	for i in n:
		var c: Vector2 = main.conveyor_slot(i)
		var card := Rect2(c - Vector2(110, 110), Vector2(220, 220))
		draw_rect(card, Color("#5d6372") if main.conveyor[i] != "" else Color("#3a3e48"))
		for k in main.pick_order.size():
			var pi: int = main.pick_order[k]
			var p: Dictionary = main.players[pi]
			if p["piece"] == "" and p["sel"] == i:
				var col = main.player_color(pi)
				var rr := card.grow(-4 - k * 9)
				draw_rect(rr, col, false, 7)
				var waiting: bool = elapsed < p["unlock"]
				text(Vector2(card.position.x + 8 + k * 50, card.end.y + 44), "P%d%s" % [pi + 1, "…" if waiting else ""], 30, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)
		var id: String = main.conveyor[i]
		if id != "":
			text(Vector2(card.position.x, card.position.y + 34), PIECE_NAMES[id], 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 220, 6)
			text(Vector2(card.position.x, card.end.y - 12), PIECE_HINT[id], 20, Color("#dfe3ea"), HORIZONTAL_ALIGNMENT_CENTER, 220)
	var y := 800
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		if p["piece"] != "":
			text(Vector2(0, y), "P%d pegou %s" % [i + 1, PIECE_NAMES[p["piece"]]], 30, main.player_color(i), HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
			y += 40

func _draw_build() -> void:
	text(Vector2(0, 110), "CONSTRUA!  setas/analógico movem · MARRETA gira · PULAR coloca", 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)

func _draw_run() -> void:
	if main.countdown > 0.0:
		var s := "PRONTOS..." if main.countdown > 0.6 else "VAI!"
		text(Vector2(0, 520), s, 130, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 28)

func _draw_score() -> void:
	draw_rect(Rect2(0, 56, 1920, 1024), Color(0.1, 0.05, 0.12, 0.55))
	var target := int(Data.scoring["target_points"])
	text(Vector2(0, 230), "PLACAR · meta %d" % target, 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 16)
	if main.round_points.size() > 0 and main.round_points[0]["all_finished"]:
		text(Vector2(0, 290), "Fácil demais! Todo mundo chegou: ninguém leva os +10.", 30, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
	if main.embargo_msg != "":
		text(Vector2(0, 330), main.embargo_msg, 30, Color("#ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
	for i in main.players.size():
		var p: Dictionary = main.players[i]
		var b: Dictionary = main.round_points[i] if i < main.round_points.size() else {}
		var y = 400 + i * 140
		var col = main.player_color(i)
		text(Vector2(260, y + 60), "P%d" % (i + 1), 56, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		var bar := Rect2(380, y + 10, 1000, 60)
		draw_rect(bar.grow(5), Data.INK)
		draw_rect(bar, Color("#3b2a46"))
		var prev: int = p["score"] - int(b.get("total", 0))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(p["score"]) / target, 0, 1), bar.size.y)), col.darkened(0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(prev) / target, 0, 1), bar.size.y)), col)
		text(Vector2(1400, y + 55), "%d" % p["score"], 48, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
		var parts := []
		if b.get("finish", 0) > 0: parts.append("+%d chegou" % b["finish"])
		if b.get("first", 0) > 0: parts.append("+%d primeiro" % b["first"])
		if b.get("kills", 0) > 0: parts.append("+%d eliminações" % b["kills"])
		if b.get("hammer", 0) > 0: parts.append("+%d marreta" % b["hammer"])
		text(Vector2(380, y + 110), "  ".join(parts) if parts.size() > 0 else "+0", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 6)

func _draw_win() -> void:
	draw_rect(Rect2(0, 56, 1920, 1024), Color(0.1, 0.05, 0.12, 0.6))
	var w: int = main.winner
	var col = main.player_color(w)
	RobotVis.draw_robot(self, main.players[w]["color"], "vitoria", 0.0, Time.get_ticks_msec() / 300.0, true, main.players[w]["acc"], false, Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(960, 800)))
	draw_set_transform(Vector2.ZERO)
	text(Vector2(0, 330), "P%d VENCEU!" % (w + 1), 140, col, HORIZONTAL_ALIGNMENT_CENTER, 1920, 30)
	text(Vector2(0, 900), "PULAR ou START para jogar de novo", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 1920, 8)
	var t := Time.get_ticks_msec() / 1000.0
	for k in 60:
		var x := fposmod(k * 137.0 + t * (40 + k % 7 * 15), 1920.0)
		var y := fposmod(k * 71.0 + t * (120 + k % 5 * 30), 1024.0) + 56
		draw_rect(Rect2(x, y, 12, 18), Data.COLORS[k % 4])
