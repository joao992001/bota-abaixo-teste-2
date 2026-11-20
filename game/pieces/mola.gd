extends "res://pieces/piece.gd"
## P02 Mola: lança o dono a owner_launch_tiles e o rival a rival_launch_tiles.

var squeeze := 0.0

func _make_bodies() -> void:
	add_body(Rect2(0, 0, T, T), all_bits())

func is_solid_for(_p: int) -> bool:
	return true

func on_stand(robot) -> void:
	var h := param("owner_launch_tiles") if robot.pid == owner_id else param("rival_launch_tiles")
	robot.launch(h)
	squeeze = 0.12

func _process(dt: float) -> void:
	squeeze = maxf(squeeze - dt, 0.0)
	super(dt)

func _draw() -> void:
	if draw_art("mola_comprimida" if squeeze > 0 else "mola", Rect2(0, 0, 64, 64)):
		return
	var top := 30.0 if squeeze > 0 else 6.0
	draw_rect(Rect2(4, 46, 56, 16), Data.INK)
	draw_rect(Rect2(8, 49, 48, 10), Color("#8d97a6"))
	var coil_h := 46.0 - (top + 12)
	for i in 4:
		var y := top + 12 + coil_h * (i + 0.5) / 4.0
		draw_line(Vector2(14, y - 5), Vector2(50, y + 5), Data.INK, 8)
		draw_line(Vector2(14, y - 5), Vector2(50, y + 5), Color("#c9ced6"), 3)
	draw_rect(Rect2(2, top, 60, 16), Data.INK)
	draw_rect(Rect2(6, top + 3, 52, 10), color)
	draw_colored_polygon(PackedVector2Array([Vector2(32, top - 14), Vector2(22, top - 2), Vector2(42, top - 2)]), color)
	draw_polyline(PackedVector2Array([Vector2(32, top - 14), Vector2(22, top - 2), Vector2(42, top - 2), Vector2(32, top - 14)]), Data.INK, 2.5)
