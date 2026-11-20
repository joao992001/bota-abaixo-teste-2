extends Node2D
## Peça com dono. Toda consulta recebe o jogador: o dono e os rivais têm regras diferentes.
## Camadas de colisão: 1 = mapa sólido, 2 = mapa one-way, 3..6 = "sólido para o jogador 0..3".

const T := 64
var piece_id := ""
var def := {}
var owner_id := -1
var color := Color.WHITE
var color_idx := 4          # índice da cor do dono (4 = neutro)
var cell := Vector2i.ZERO
var rot := 0
var ghost := true
var kills := 0
var placed_round := 0
var main: Node = null
var t := 0.0

func setup(id: String, owner: int, col_idx: int, c: Vector2i, r: int = 0) -> void:
	piece_id = id
	def = Data.pieces[id]
	owner_id = owner
	color_idx = col_idx
	color = Data.COLORS[col_idx] if col_idx < 4 else Color("#dfe3ea")
	rot = r
	move_to(c)

func move_to(c: Vector2i) -> void:
	cell = c
	position = Vector2(cell * T)
	queue_redraw()

func param(key: String) -> float:
	return float(def["params"][key])

func size_tiles() -> Vector2i:
	var s: Array = def["tamanho_tiles"]
	return Vector2i(int(s[0]), int(s[1]))

func cells() -> Array:
	var out := []
	var s := size_tiles()
	for y in s.y:
		for x in s.x:
			out.append(cell + Vector2i(x, y))
	return out

func world_rect() -> Rect2:
	return Rect2(Vector2(cell * T), Vector2(size_tiles() * T))

func activate(round_no: int) -> void:
	ghost = false
	placed_round = round_no
	modulate = Color.WHITE
	_make_bodies()
	queue_redraw()

static func bit(p: int) -> int:
	return 1 << (2 + p)

func rival_bits() -> int:
	var b := 0
	for p in 4:
		if p != owner_id:
			b |= bit(p)
	return b

func all_bits() -> int:
	return bit(0) | bit(1) | bit(2) | bit(3)

func add_body(rect: Rect2, layers: int, one_way := false) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = layers
	b.collision_mask = 0
	b.set_meta("piece", self)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	cs.position = rect.get_center()
	cs.one_way_collision = one_way
	b.add_child(cs)
	add_child(b)
	return b

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

func owner_near(dist: float) -> bool:
	return main != null and main.robot_near(owner_id, world_rect().get_center(), dist, true)

func rival_near(dist: float) -> bool:
	return main != null and main.robot_near(owner_id, world_rect().get_center(), dist, false)

# ---- comportamento (sobrescrito por peça) ----
func _make_bodies() -> void: pass
func rotate_piece() -> void: pass
func is_solid_for(_p: int) -> bool: return false
func is_hazard_for(_p: int) -> bool: return false
func interact(_robot) -> void: pass          # chamado a cada frame da corrida, para cada robô
func on_stand(_robot) -> void: pass          # robô pisou em cima
func belt_vx(_robot, _ix: float) -> float: return 0.0

# ---- desenho comum ----
func draw_owner_mark(center: Vector2, r: float) -> void:
	draw_circle(center, r + 4, Data.INK)
	draw_circle(center, r, color)
	draw_symbol(self, color_idx, center, r * 0.55, Data.INK)

## Desenha a textura da peça na cor do dono (PNG 2x). Retorna false se não houver arte.
func draw_art(name: String, rect: Rect2, per_color := true) -> bool:
	var tx := Data.tex("pecas/%s_c%d" % [name, color_idx] if per_color else "pecas/" + name)
	if tx == null:
		return false
	draw_texture_rect(tx, rect, false)
	return true

static func draw_symbol(ci: CanvasItem, idx: int, c: Vector2, r: float, col: Color) -> void:
	match idx:
		4: pass
		0: ci.draw_circle(c, r, col)
		1: ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), col)
		2: ci.draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), col)
		3: ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.15), c + Vector2(r, 0), c + Vector2(0, r * 1.15), c + Vector2(-r, 0)]), col)
