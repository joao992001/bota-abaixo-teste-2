extends "res://pieces/piece.gd"
## P01 Viga: dono atravessa por baixo e pisa por cima; rivais: bloco sólido.

func size_tiles() -> Vector2i:
	return Vector2i(3, 1) if rot == 0 else Vector2i(1, 3)

func rotate_piece() -> void:
	rot = 1 - rot
	queue_redraw()

func _make_bodies() -> void:
	var s := Vector2(size_tiles() * T)
	add_body(Rect2(Vector2.ZERO, s), rival_bits())
	add_body(Rect2(0, 0, s.x, 16), bit(owner_id), true)

func is_solid_for(p: int) -> bool:
	return p != owner_id

func _draw() -> void:
	var s := Vector2(size_tiles() * T)
	var r := Rect2(Vector2.ZERO, s).grow(-3)
	draw_rect(r, Data.INK)
	var f := r.grow(-5)
	draw_rect(f, Color("#8d97a6"))
	draw_rect(Rect2(f.position, Vector2(f.size.x, 12)), color)
	draw_rect(Rect2(f.position.x, f.end.y - 8, f.size.x, 8), Color("#6b7280"))
	var n := maxi(size_tiles().x, size_tiles().y)
	for i in n:
		var c := Vector2(32 + i * 64, 38) if rot == 0 else Vector2(32, 38 + i * 64)
		draw_circle(c, 5, Data.INK)
	draw_owner_mark(Vector2(s.x - 22, 22) if rot == 0 else Vector2(22, s.y - 22), 12)
	if not ghost and owner_near(3 * T):
		for i in n:
			var b := Vector2(32 + i * 64, -14) if rot == 0 else Vector2(32, -14)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-10, 6), b + Vector2(0, -6), b + Vector2(10, 6)]), color)
			if rot == 1:
				break
