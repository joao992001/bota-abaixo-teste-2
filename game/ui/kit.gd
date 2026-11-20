extends RefCounted
## Kit visual da interface (estilo papel e giz): fonte Fredoka, papel, placa de madeira, faixa,
## texto com borda de "adesivo" e estrelas. Funções estáticas; texturas em res://assets/ui.

const INK := Color("#1f4f5a")
const CREAM := Color("#fffaf0")
static var _font: Font = null
static var _boxes := {}

static func font() -> Font:
	if _font == null:
		# carrega como recurso importado (é o que vai junto no jogo exportado; o arquivo .woff2 cru não vai)
		var path := "res://assets/fonts/fredoka-700.woff2"
		var f: FontFile = load(path) if ResourceLoader.exists(path) else null
		if f != null:
			f = f.duplicate()
			f.fallbacks = [ThemeDB.fallback_font]   # setas ◄►▲▼ e outros símbolos
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font

static func box(name: String, margin_x: float, margin_y: float) -> StyleBoxTexture:
	if not _boxes.has(name):
		var sb := StyleBoxTexture.new()
		sb.texture = Data.tex("ui/" + name)
		sb.texture_margin_left = margin_x
		sb.texture_margin_right = margin_x
		sb.texture_margin_top = margin_y
		sb.texture_margin_bottom = margin_y
		_boxes[name] = sb
	return _boxes[name]

static func paper(ci: CanvasItem, r: Rect2, tint := Color.WHITE) -> void:
	var sb := box("papel", 40, 40)
	sb.modulate_color = tint
	ci.draw_style_box(sb, r)

static func wood(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(box("madeira", 48, 30), r)

static func ribbon(ci: CanvasItem, r: Rect2, txt: String, size := 56) -> void:
	ci.draw_style_box(box("faixa", 96, 40), r)
	text(ci, Vector2(r.position.x, r.get_center().y + size * 0.36 - r.size.y * 0.06), txt, size, Color("#5a3a10"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

## Texto com borda (adesivo creme por padrão, ou contorno escuro).
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 0, ocol := INK) -> void:
	var f := font()
	if outline > 0:
		ci.draw_string_outline(f, pos, s, align, w, size, outline, ocol)
	ci.draw_string(f, pos, s, align, w, size, col)

static func sticker(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w := -1.0) -> void:
	text(ci, pos + Vector2(4, 6), s, size, Color(0.12, 0.23, 0.25, 0.25), align, w, int(size * 0.22), Color(0.12, 0.23, 0.25, 0.25))
	text(ci, pos, s, size, col, align, w, int(size * 0.22), CREAM)

static func star(ci: CanvasItem, c: Vector2, size: float, filled: bool) -> void:
	ci.draw_texture_rect(Data.tex("ui/estrela" if filled else "ui/estrela_vazia"), Rect2(c - Vector2(size, size) / 2.0, Vector2(size, size)), false)

# ---------------------------------------------------------------- botões de controle
## Botão do controle desenhado (sem depender de fonte): pos = "baixo" | "direita" | "esquerda" | "cima"
## (posição física, igual em todos os controles) ou "start" / "lb" / "rb"; estilo = xbox | ps | nintendo | generico.
const PAD_LETTER := {"xbox": {"baixo": "A", "direita": "B", "esquerda": "X", "cima": "Y"},
	"generico": {"baixo": "A", "direita": "B", "esquerda": "X", "cima": "Y"},
	"nintendo": {"baixo": "B", "direita": "A", "esquerda": "Y", "cima": "X"}}
const PAD_COLOR := {"baixo": Color("#5cc45c"), "direita": Color("#e5484d"), "esquerda": Color("#4f86d9"), "cima": Color("#f2c84b")}
const PS_COLOR := {"baixo": Color("#8fb4f0"), "direita": Color("#ff7a8a"), "esquerda": Color("#f39ad9"), "cima": Color("#5fd6b0")}

static func pad_btn(ci: CanvasItem, c: Vector2, r: float, pos: String, style: String, lit := false) -> void:
	var dark := Color("#2f3640")
	ci.draw_circle(c + Vector2(0, r * 0.12), r, Color(0.1, 0.15, 0.18, 0.35))
	if pos in ["start", "lb", "rb", "select"]:
		var w := r * 2.4
		var rr := Rect2(c - Vector2(w / 2.0, r * 0.75), Vector2(w, r * 1.5))
		ci.draw_rect(rr, Color("#f2c84b") if lit else dark)
		var lab: String = {"start": "START", "select": "SELECT", "lb": "LB", "rb": "RB"}[pos]
		if style == "ps":
			lab = {"start": "OPTIONS", "select": "SHARE", "lb": "L1", "rb": "R1"}[pos]
		elif style == "nintendo":
			lab = {"start": "+", "select": "−", "lb": "L", "rb": "R"}[pos]
		text(ci, Vector2(rr.position.x, c.y + r * 0.32), lab, int(r * (0.62 if lab.length() > 3 else 0.9)), dark if lit else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x)
		return
	if style == "ps":
		ci.draw_circle(c, r, Color("#f2c84b") if lit else dark)
		var col: Color = dark if lit else PS_COLOR[pos]
		var k := r * 0.48
		var wd := maxf(2.0, r * 0.2)
		match pos:
			"baixo":
				ci.draw_line(c + Vector2(-k, -k), c + Vector2(k, k), col, wd, true)
				ci.draw_line(c + Vector2(-k, k), c + Vector2(k, -k), col, wd, true)
			"direita":
				ci.draw_arc(c, k, 0, TAU, 24, col, wd, true)
			"esquerda":
				ci.draw_rect(Rect2(c - Vector2(k, k) * 0.9, Vector2(k, k) * 1.8), col, false, wd)
			"cima":
				ci.draw_polyline(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, k * 0.75), c + Vector2(-k, k * 0.75), c + Vector2(0, -k)]), col, wd, true)
		return
	var st: String = style if PAD_LETTER.has(style) else "xbox"
	var fill: Color = Color("#f2c84b") if lit else (dark if st == "nintendo" else PAD_COLOR[pos])
	ci.draw_circle(c, r, fill)
	ci.draw_arc(c, r, 0, TAU, 28, Color(1, 1, 1, 0.35), maxf(1.5, r * 0.1), true)
	text(ci, Vector2(c.x - r, c.y + r * 0.36), PAD_LETTER[st][pos], int(r * 1.05), dark if lit else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)

## Linha de dica com botões: partes = ["texto", ["baixo"], "pula", ...]; centralizada em cx.
static func pad_hint(ci: CanvasItem, cx: float, y: float, parts: Array, size: int, col: Color, style: String) -> void:
	var f := font()
	var r := size * 0.62
	var w := 0.0
	for p in parts:
		w += (r * 2.0 + 8.0) if p is Array else f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := cx - w / 2.0
	for p in parts:
		if p is Array:
			var big: bool = p[0] in ["start", "lb", "rb", "select"]
			var bw := r * (2.4 if big else 2.0)
			pad_btn(ci, Vector2(x + bw / 2.0 + 4.0, y - size * 0.34), r, p[0], style)
			x += bw + 8.0
		else:
			text(ci, Vector2(x, y), p, size, col)
			x += f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
