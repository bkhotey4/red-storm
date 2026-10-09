extends Node2D
# 隨機補給箱

var cell := Vector2i.ZERO
var kind := "money"
var sheet
var t := 0.0

func setup(c: Vector2i, k: String):
	cell = c
	kind = k
	sheet = G.sheet("crate")
	position = G.game.iso(Vector2(c) + Vector2(0.5, 0.5))

func _process(dt: float):
	t += dt
	queue_redraw()

func _draw():
	var a := 0.35 + 0.25 * sin(t * 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0.3, 0.9, 1.0, a * 0.4))
	draw_set_transform(Vector2.ZERO)
	if sheet != null:
		sheet.draw(self, 0 if kind in ["money", "unit"] else 1, Vector2(0, -2 + sin(t * 3.0) * 2.0), Color.WHITE)
