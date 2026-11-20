extends "res://pieces/piece.gd"
## P03 Serra circular: inofensiva e atravessável para o dono; elimina rivais ao toque.

func hazard_rect() -> Rect2:
	var h := param("hazard_hitbox_px")
	return Rect2(world_rect().get_center() - Vector2(h, h) / 2.0, Vector2(h, h))

func is_hazard_for(p: int) -> bool:
	return p != owner_id

func interact(robot) -> void:
	if robot.pid != owner_id and robot.rect().intersects(hazard_rect()):
		main.kill(robot, owner_id, self)

func _draw() -> void:
	var c := Vector2(32, 32)
	var safe := (not ghost) and owner_near(1.5 * T) and not rival_near(2 * T)
	var ang := 0.0 if safe else t * 9.0
	var teeth := 10
	if not safe:
		var pts := PackedVector2Array()
		for i in teeth * 2:
			var a := ang + TAU * i / (teeth * 2)
			pts.append(c + Vector2.from_angle(a) * (31.0 if i % 2 == 0 else 22.0))
		draw_colored_polygon(pts, Data.INK)
		var inner := PackedVector2Array()
		for i in teeth * 2:
			var a := ang + TAU * i / (teeth * 2)
			inner.append(c + Vector2.from_angle(a) * (26.0 if i % 2 == 0 else 19.0))
		draw_colored_polygon(inner, Data.DANGER)
	draw_circle(c, 21, Data.INK)
	draw_circle(c, 17, Color("#b9c0ca"))
	draw_arc(c, 11, ang, ang + PI * 1.2, 12, Color("#8d97a6"), 4)
	draw_owner_mark(c, 9)
