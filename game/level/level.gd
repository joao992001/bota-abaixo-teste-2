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
var door_open := 0.0        # 0 fechado .. 1 aberto (main anima)
var blocks := {}            # caixotes destrutíveis 'd': Vector2i -> {hp, body, load, warn}
var block_hp := 2
signal block_broken(cell: Vector2i, kind: String)
var props := {}             # cabeçalho do .lvl ("chave: valor"): mecânicas da arena
var belts: Array = []       # esteiras do mapa: {body, dir, cells}
var belt_speed := 192.0
var belt_warn := false      # esteiras piscando antes de inverter
var extra_solid := Callable()   # sólidos que se movem (plataformas do guindaste), para bots e itens
var anim_t := 0.0

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
		elif ":" in line and not line.begins_with("#"):
			var kv := line.split(":", true, 1)
			props[kv[0].strip_edges()] = kv[1].strip_edges().trim_prefix("\"").trim_suffix("\"")
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
				goal_rect = Rect2(x * T + 4, (y - 2) * T + 20, T - 8, 3 * T - 20)  # elevador inteiro (3 tiles)
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
	if ch_at(c) in ["#", "o", "I", "d", "T", "<", ">"]:
		return true
	return extra_solid.is_valid() and extra_solid.call(c)

func prop(key: String, default = null):
	return props.get(key, default)

## Inverte todas as esteiras do mapa (a velocidade de plataforma da Godot carrega quem está em cima).
func flip_belts() -> void:
	for b in belts:
		b["dir"] = -b["dir"]
		b["body"].constant_linear_velocity = Vector2(b["dir"] * belt_speed, 0)
	queue_redraw()

## Caixote destrutível: perde vida; quebra em 0. Retorna true se quebrou.
func damage(c: Vector2i, amount := 1) -> bool:
	if not blocks.has(c):
		return false
	blocks[c]["hp"] -= amount
	queue_redraw()
	if blocks[c]["hp"] <= 0:
		break_block(c)
		return true
	return false

func break_block(c: Vector2i) -> void:
	if not blocks.has(c):
		return
	blocks[c]["body"].queue_free()
	blocks.erase(c)
	var kind: String = "tnt" if ch_at(c) == "T" else "caixote"
	var row := String(grid[c.y])
	grid[c.y] = row.substr(0, c.x) + "." + row.substr(c.x + 1)
	queue_redraw()
	block_broken.emit(c, kind)

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
			if ch == "<" or ch == ">":
				# esteira do mapa: um corpo por trecho contínuo, com velocidade de plataforma
				var x0b := x
				while x < cols and ch_at(Vector2i(x, y)) == ch:
					x += 1
				var bb := StaticBody2D.new()
				bb.collision_layer = 1
				bb.collision_mask = 0
				var bcs := CollisionShape2D.new()
				var brs := RectangleShape2D.new()
				brs.size = Vector2((x - x0b) * T, T)
				bcs.shape = brs
				bcs.position = Vector2(x0b * T + brs.size.x / 2.0, y * T + T / 2.0)
				bb.add_child(bcs)
				add_child(bb)
				belt_speed = float(prop("esteira_vel", "3")) * T
				var dir := 1 if ch == ">" else -1
				bb.constant_linear_velocity = Vector2(dir * belt_speed, 0)
				belts.append({"body": bb, "dir": dir, "x0": x0b, "x1": x, "y": y})
				continue
			if ch == "d" or ch == "T":
				# caixote destrutível: corpo próprio para poder sumir sozinho
				var body := StaticBody2D.new()
				body.collision_layer = 1
				body.collision_mask = 0
				var bs := CollisionShape2D.new()
				var br := RectangleShape2D.new()
				br.size = Vector2(T, T)
				bs.shape = br
				bs.position = Vector2(x * T + T / 2.0, y * T + T / 2.0)
				body.add_child(bs)
				add_child(body)
				blocks[Vector2i(x, y)] = {"hp": block_hp, "body": body, "load": 0.0, "warn": 0.0}
				x += 1
				continue
			if ch != "#" and ch != "=":
				x += 1
				continue
			var x0 := x
			while x < cols and (ch_at(Vector2i(x, y)) == ch or (ch == "#" and ch_at(Vector2i(x, y)) in ["#", "o", "I"])):
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
				"d", "T":
					_draw_block_d(c, pos)
				"<", ">":
					draw_texture_rect(Data.tex("cenario/esteira_piso"), Rect2(pos, tile), false)
				"^":
					draw_texture_rect(Data.tex("cenario/espinho_%d" % ((x * 5 + y) % 3)), Rect2(pos + Vector2(0, T - 128), Vector2(T, 128)), false)
	for b in belts:
		if belt_warn and fmod(anim_t, 0.25) < 0.12:
			continue
		var off := fposmod(anim_t * belt_speed * 0.5 * b["dir"], 32.0)
		var x := float(b["x0"] * T) + off
		while x < b["x1"] * T - 8:
			var p := Vector2(x + 8, b["y"] * T + 9)
			var d := float(b["dir"])
			draw_polyline(PackedVector2Array([p + Vector2(-4 * d, -5), p + Vector2(3 * d, 0), p + Vector2(-4 * d, 5)]), Color("#fff4c8") if not belt_warn else Color("#f2c84b"), 2.6, true)
			x += 32.0
	if elevator_cell.x >= 0:
		var e := Vector2(elevator_cell.x * T - 32, (elevator_cell.y - 2) * T)
		var tx := Data.tex("cenario/elevador")
		draw_texture_rect(tx, Rect2(e, Vector2(128, 192)), false)
		if door_open > 0.01:
			# porta pantográfica recolhe para os lados e mostra o interior iluminado
			var o := door_open * 36.0
			draw_rect(Rect2(e + Vector2(63 - o, 47), Vector2(2 + 2 * o, 145)), Color("#f3dd92"))
			draw_rect(Rect2(e + Vector2(63 - o, 47), Vector2(2 + 2 * o, 10)), Color("#fff4c8"))
			var sc := 3.0
			draw_texture_rect_region(tx, Rect2(e + Vector2(25, 47), Vector2(38 - o, 145)), Rect2(Vector2(25 + o, 47) * sc, Vector2(38 - o, 145) * sc))
			draw_texture_rect_region(tx, Rect2(e + Vector2(65 + o, 47), Vector2(38 - o, 145)), Rect2(Vector2(65, 47) * sc, Vector2(38 - o, 145) * sc))

func _process(dt: float) -> void:
	anim_t += dt
	if belts.size() > 0:
		queue_redraw()
	if door_open > 0.0 or _was_open:
		queue_redraw()
	for b in blocks.values():
		if b["warn"] > 0.0:
			queue_redraw()
			break
	_was_open = door_open > 0.0

var _was_open := false

## Caixote destrutível: rachaduras conforme o dano e tremor antes de cair.
func _draw_block_d(c: Vector2i, pos: Vector2) -> void:
	var b: Dictionary = blocks.get(c, {})
	var off := Vector2.ZERO
	if b.get("warn", 0.0) > 0.0:
		off = Vector2(randf_range(-3, 3), randf_range(-2, 2))
	var tx := Data.tex("cenario/tnt") if ch_at(c) == "T" else Data.tex("cenario/caixote_%d" % ((c.x * 7 + c.y * 3) % 3))
	draw_texture_rect(tx, Rect2(pos + off, Vector2(T, T)), false)
	var dmg := block_hp - int(b.get("hp", block_hp))
	var crack := Color("#5a3a1c")
	if dmg >= 1 or b.get("load", 0.0) > 0.0:
		var p := pos + off
		var k := 1.0 if dmg >= 1 else 0.6
		draw_polyline(PackedVector2Array([p + Vector2(12, 4), p + Vector2(24, 20), p + Vector2(19, 30), p + Vector2(34, 44)]), crack, 2.5 * k, true)
		draw_polyline(PackedVector2Array([p + Vector2(24, 20), p + Vector2(40, 16), p + Vector2(52, 6)]), crack, 2.0 * k, true)
	if dmg >= 1 and b.get("load", 0.0) > 0.0:
		draw_polyline(PackedVector2Array([pos + off + Vector2(8, 56), pos + off + Vector2(26, 46), pos + off + Vector2(44, 58)]), crack, 2.5, true)

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
