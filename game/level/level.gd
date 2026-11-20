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
				# espinhos altos (1,5 tile), em pé no fundo do poço
				hazard_rects.append(Rect2(x * T + 4, y * T + T - 100, T - 8, 100))
	_build_colliders()
	queue_redraw()

func ch_at(c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= String(grid[c.y]).length():
		return "#"
	return String(grid[c.y])[c.x]

func is_solid(c: Vector2i) -> bool:
	return ch_at(c) in ["#", "o", "I"]

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
			if ch == "o" or ch == "I":
				ch = "#"
			if ch != "#" and ch != "=":
				x += 1
				continue
			var x0 := x
			while x < cols and (ch_at(Vector2i(x, y)) == ch or (ch == "#" and is_solid(Vector2i(x, y)))):
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
	if Data.tex("cenario/tabua") != null:
		_draw_art()
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

func _draw_art() -> void:
	var tile := Vector2(T, T)
	_draw_ropes_and_planks()
	_draw_scaffolds()
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			var pos := Vector2(x * T, y * T)
			match ch_at(c):
				"#":
					draw_texture_rect(Data.tex("cenario/caixote_%d" % ((x * 7 + y * 3) % 3)), Rect2(pos, tile), false)
				"^":
					draw_texture_rect(Data.tex("cenario/espinho_%d" % ((x * 5 + y) % 3)), Rect2(pos + Vector2(0, T - 128), Vector2(T, 128)), false)
	if elevator_cell.x >= 0:
		draw_texture_rect(Data.tex("cenario/elevador"), Rect2(elevator_cell.x * T - 32, (elevator_cell.y - 2) * T, 128, 192), false)

## Tábuas one-way penduradas por cordas que sobem até fora da tela.
func _draw_ropes_and_planks() -> void:
	var rope := Color("#8a6a47")
	for y in rows:
		var x := 0
		while x < cols:
			if ch_at(Vector2i(x, y)) != "=":
				x += 1
				continue
			var x0 := x
			while x < cols and ch_at(Vector2i(x, y)) == "=":
				x += 1
			for rx in [x0 * T + 48.0, x * T - 48.0]:
				var pts := PackedVector2Array()
				for k in 25:
					var yy := lerpf(-200.0, y * T + 6.0, k / 24.0)
					pts.append(Vector2(rx + sin(k * 1.7 + rx) * 1.2, yy))
				draw_polyline(pts, rope, 3.5, true)
			for xx in range(x0, x):
				draw_texture_rect(Data.tex("cenario/tabua"), Rect2(xx * T, y * T, T, 16), false)

## Andaime de aço (células 'o'): postes, travessas e X, com tábua no topo.
func _draw_scaffolds() -> void:
	var seen := {}
	var steel := Color("#7f8f9a")
	var lite := Color("#9aa8b2")
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if ch_at(c) != "o" or seen.has(c):
				continue
			var x1 := x
			while ch_at(Vector2i(x1 + 1, y)) == "o":
				x1 += 1
			var y1 := y
			while ch_at(Vector2i(x, y1 + 1)) == "o":
				y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1):
					seen[Vector2i(xx, yy)] = true
			var r := Rect2(x * T + 6, y * T + 14, (x1 - x + 1) * T - 12, (y1 - y + 1) * T + 40)
			var step := 100.0
			var yy0 := r.position.y
			while yy0 < r.end.y:
				var yy1 := minf(yy0 + step, r.end.y)
				draw_line(Vector2(r.position.x, yy0), Vector2(r.end.x, yy1), steel, 5.0, true)
				draw_line(Vector2(r.end.x, yy0), Vector2(r.position.x, yy1), steel, 5.0, true)
				draw_line(Vector2(r.position.x - 4, yy1), Vector2(r.end.x + 4, yy1), steel, 5.0, true)
				draw_line(Vector2(r.position.x, yy0 + 2), Vector2(r.end.x, yy1 + 2), lite, 1.2, true)
				yy0 = yy1
			for px in [r.position.x, r.end.x]:
				draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), steel, 6.0, true)
				draw_line(Vector2(px - 1.5, r.position.y), Vector2(px - 1.5, r.end.y), lite, 1.2, true)
			for xx in range(x, x1 + 1):
				draw_texture_rect(Data.tex("cenario/tabua"), Rect2(xx * T, y * T, T, 22), false)

## Autotile: cada bloco escolhe a variante pelas faces expostas (topo, direita, esquerda, base, canto).
func block_tex(c: Vector2i) -> String:
	var t := not is_solid(c + Vector2i.UP)
	var r := not is_solid(c + Vector2i.RIGHT)
	var l := not is_solid(c + Vector2i.LEFT)
	var b := not is_solid(c + Vector2i.DOWN)
	var k := r and (b or is_solid(c + Vector2i(1, 1)))
	var cor := "dourado" if ch_at(c) == "o" else ("laranja" if (c.x / 3 + c.y / 2) % 2 == 0 else "magenta")
	return "cenario/blocos/%s_%d%d%d%d%d" % [cor, int(t), int(r), int(l), int(b), int(k)]

static func draw_block(ci: CanvasItem, r: Rect2, base: Color) -> void:
	var inner := r.grow(-2)
	ci.draw_rect(inner, Data.INK)
	var f := inner.grow(-4)
	ci.draw_rect(f, base)
	ci.draw_rect(Rect2(f.position, Vector2(f.size.x, 10)), base.lightened(0.3))
	ci.draw_rect(Rect2(Vector2(f.end.x - 9, f.position.y + 10), Vector2(9, f.size.y - 10)), base.darkened(0.25))
	ci.draw_rect(Rect2(Vector2(f.position.x, f.end.y - 7), Vector2(f.size.x - 9, 7)), base.darkened(0.15))
