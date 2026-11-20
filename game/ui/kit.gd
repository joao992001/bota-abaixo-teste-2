extends RefCounted
## Kit visual da interface (estilo papel e giz): fonte Fredoka, papel, placa de madeira, faixa,
## texto com borda de "adesivo" e estrelas. Funções estáticas; texturas em res://assets/ui.

const INK := Color("#1f4f5a")
const CREAM := Color("#fffaf0")
static var _font: Font = null
static var _boxes := {}

static func font() -> Font:
	if _font == null:
		var f := FontFile.new()
		var path := "res://assets/fonts/fredoka-700.woff2"
		if FileAccess.file_exists(path):
			f.data = FileAccess.get_file_as_bytes(path)
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
