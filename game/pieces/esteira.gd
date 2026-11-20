extends "res://pieces/piece.gd"
## P04 Esteira: para o dono, sempre a favor do movimento (parado não move); rivais são empurrados na direção marcada.

func dir() -> int:
	return 1 if rot == 0 else -1

func rotate_piece() -> void:
	rot = 1 - rot
	queue_redraw()

func _make_bodies() -> void:
	add_body(Rect2(0, 0, 3 * T, T), all_bits())

func is_solid_for(_p: int) -> bool:
	return true

func belt_vx(robot, ix: float) -> float:
	var speed := param("speed_tiles_s") * T
	if robot.pid == owner_id:
		return signf(ix) * speed
	return dir() * speed

func _draw() -> void:
	var r := Rect2(4, 14, 184, 46)
	draw_rect(r, Data.INK)
	draw_rect(r.grow(-5), Color("#4a4f5c"))
	draw_rect(Rect2(9, 19, 174, 8), color)
	for i in 4:
		draw_circle(Vector2(26 + i * 47, 46), 9, Data.INK)
		draw_circle(Vector2(26 + i * 47, 46), 6, Color("#b9c0ca"))
	var off := fmod(t * param("speed_tiles_s") * T * 0.25, 32.0) * dir()
	for i in 6:
		var x := 8.0 + fposmod(i * 32.0 + off, 176.0)
		var d := float(dir())
		var pts := PackedVector2Array([Vector2(x, 30), Vector2(x + 8 * d, 36), Vector2(x, 42)])
		draw_polyline(pts, Color("#f2f2f2"), 4)
	draw_owner_mark(Vector2(96, 8), 10)
