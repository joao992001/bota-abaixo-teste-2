extends Node2D
## Fundo do Canteiro em formas simples (céu turquesa, formas brancas suaves, plateia em silhueta).

var texture: Texture2D = null

func _draw() -> void:
	if texture != null:
		draw_texture(texture, Vector2.ZERO)
		return
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#3aa7a3"))
	for p in [Vector2(300, 260), Vector2(900, 180), Vector2(1500, 300), Vector2(1200, 600), Vector2(500, 650)]:
		draw_circle(p, 90, Color(1, 1, 1, 0.18))
		draw_circle(p + Vector2(80, 20), 60, Color(1, 1, 1, 0.18))
