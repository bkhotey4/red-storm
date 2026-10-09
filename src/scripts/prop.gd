extends Node2D
# 樹木與岩石等靜態物件

var sheet
var frame := 0
var pos := Vector2.ZERO

func setup(key: String, f: int, p: Vector2):
	sheet = G.sheet(key)
	frame = f
	pos = p + Vector2(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12))
	position = G.game.iso(pos) if G.game != null else G.iso(pos)

func _draw():
	if sheet != null:
		sheet.draw(self, frame, Vector2.ZERO, Color.WHITE)
