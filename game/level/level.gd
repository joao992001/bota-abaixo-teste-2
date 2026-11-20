extends Node2D
## Monta o mapa a partir de levels/<id>.lvl: colisões, perigos fixos, spawns, elevador e células de construção.

const T := 64
var id := ""
var cols := 30
var rows := 16
var grid: Array = []
var spawns := {}            # número do spawn (1-4) -> posição dos pés
var elevator_cell := Vector2i(-1, -1)
var goal_rect := Rect2()
var hazard_rects: Array = []
var skin: Node = null       # arte do mapa (opcional); sem ela, formas simples

func load_level(level_id: String) -> void:
	id = level_id
	var in_map := false
	for raw in Data.read_text("levels/%s.lvl" % level_id).split("\n"):
		var line := raw.strip_edges(false, true)
		if in_map:
			if line.length() > 0:
				grid.append(line)
		elif line.begins_with("size:"):
			var p := line.substr(5).strip_edges().split("x")
			cols = int(p[0])
			rows = int(p[1])
		elif line.begins_with("=== map"):
			in_map = true
	if grid.size() != rows:
		push_error("Mapa %s: %d linhas, esperado %d" % [level_id, grid.size(), rows])
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var ch := ch_at(c)
			if ch in ["1", "2", "3", "4"]:
				spawns[int(ch)] = Vector2(x * T + T / 2.0, (y + 1) * T)
			elif ch == "E":
				elevator_cell = c
				goal_rect = Rect2(x * T + 8, (y - 1) * T, T - 16, 2 * T)
			elif ch == "^":
				hazard_rects.append(Rect2(x * T + 6, y * T + 26, T - 12, T - 26))
	_build_colliders()
	queue_redraw()

func ch_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= String(grid[c.y]).length():
		return "#"
	return String(grid[c.y])[c.x]

func can_build(c: Vector2i) -> bool:
	return ch_at(c) == "."

func _build_colliders() -> void:
	var solid := StaticBody2D.new()
	solid.collision_layer = 1
	solid.collision_mask = 0
	add_child(solid)
	var oneway := StaticBody2D.new()
	oneway.collision_layer = 2
	oneway.collision_mask = 0
	add_child(oneway)
	for y in rows:
		var x := 0
		while x < cols:
			var ch := ch_at(Vector2i(x, y))
			if ch != "#" and ch != "=":
				x += 1
				continue
			var x0 := x
			while x < cols and ch_at(Vector2i(x, y)) == ch:
				x += 1
			var cs := CollisionShape2D.new()
			var r := RectangleShape2D.new()
			if ch == "#":
				r.size = Vector2((x - x0) * T, T)
				cs.position = Vector2(x0 * T + r.size.x / 2.0, y * T + T / 2.0)
				cs.shape = r
				solid.add_child(cs)
			else:
				r.size = Vector2((x - x0) * T, 16)
				cs.position = Vector2(x0 * T + r.size.x / 2.0, y * T + 8)
				cs.shape = r
				cs.one_way_collision = true
				oneway.add_child(cs)

# ---------- formas simples (substituídas pela arte quando existir) ----------
func _draw() -> void:
	if skin != null:
		return
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var r := Rect2(x * T, y * T, T, T)
			match ch_at(c):
				"#":
					var base := Color("#e0894a") if (x / 2 + y / 2) % 2 == 0 else Color("#d9567f")
					draw_block(self, r, base)
				"=":
					draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(T, 16)), Data.INK)
					draw_rect(Rect2(r.position + Vector2(3, 5), Vector2(T - 6, 10)), Color("#c98b4e"))
				"^":
					for i in 3:
						var bx := r.position.x + 4 + i * 19
						var pts := PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx + 9.5, r.position.y + 22), Vector2(bx + 19, r.end.y)])
						draw_colored_polygon(pts, Color("#5a5560"))
						draw_polyline(pts, Data.INK, 3.0, true)
						draw_circle(Vector2(bx + 9.5, r.position.y + 26), 3.5, Data.DANGER)
	# elevador (objetivo)
	if elevator_cell.x >= 0:
		var e := Rect2(elevator_cell.x * T - 32, (elevator_cell.y - 2) * T, 128, 192)
		draw_rect(e.grow(5), Data.INK)
		draw_rect(e, Color("#f2c33a"))
		draw_rect(Rect2(e.position + Vector2(20, 30), Vector2(88, 162)), Color("#3b3f4a"))
		draw_rect(Rect2(e.position + Vector2(62, 30), Vector2(4, 162)), Data.INK)
		for i in 6:
			draw_rect(Rect2(e.position.x + i * 22, e.position.y, 11, 18), Data.INK)
		draw_string(ThemeDB.fallback_font, e.position + Vector2(0, -10), "ELEVADOR", HORIZONTAL_ALIGNMENT_CENTER, 128, 22, Color.WHITE)

static func draw_block(ci: CanvasItem, r: Rect2, base: Color) -> void:
	var inner := r.grow(-2)
	ci.draw_rect(inner, Data.INK)
	var f := inner.grow(-4)
	ci.draw_rect(f, base)
	ci.draw_rect(Rect2(f.position, Vector2(f.size.x, 10)), base.lightened(0.3))
	ci.draw_rect(Rect2(Vector2(f.end.x - 9, f.position.y + 10), Vector2(9, f.size.y - 10)), base.darkened(0.25))
	ci.draw_rect(Rect2(Vector2(f.position.x, f.end.y - 7), Vector2(f.size.x - 9, 7)), base.darkened(0.15))
