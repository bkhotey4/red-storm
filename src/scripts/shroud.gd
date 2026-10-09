extends Node2D
# 戰爭迷霧（未探索區域）— 以低解析度貼圖 + 線性濾波呈現柔和邊緣

var game
var img: Image
var tex: ImageTexture
var dirty := false
const SUB := 3

func _ready():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func init_tex():
	var W: int = game.W
	var H: int = game.H
	img = Image.create(W * SUB, H * SUB, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	tex = ImageTexture.create_from_image(img)

func mark(x: int, y: int):
	if img == null:
		init_tex()
	for dy in SUB:
		for dx in SUB:
			img.set_pixel(x * SUB + dx, y * SUB + dy, Color(0, 0, 0, 0))
	dirty = true

func reveal_circle(c: Vector2, r: float):
	if img == null:
		init_tex()
	var W: int = game.W * SUB
	var H: int = game.H * SUB
	var cx := c.x * SUB
	var cy := c.y * SUB
	var rs := r * SUB
	var soft := 1.4 * SUB
	for y in range(maxi(0, int(cy - rs)), mini(H, int(cy + rs) + 1)):
		for x in range(maxi(0, int(cx - rs)), mini(W, int(cx + rs) + 1)):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > rs:
				continue
			var a := clampf((d - (rs - soft)) / soft, 0.0, 1.0)
			var cur := img.get_pixel(x, y).a
			if a < cur:
				img.set_pixel(x, y, Color(0, 0, 0, a))
				dirty = true

func _process(_dt: float):
	if dirty and tex != null:
		dirty = false
		tex.update(img)
		queue_redraw()

func _draw():
	if img == null:
		init_tex()
	var W: int = game.W
	var H: int = game.H
	var k := 1.0 / SUB
	draw_set_transform_matrix(Transform2D(Vector2(G.HW, G.HH) * k, Vector2(-G.HW, G.HH) * k, Vector2.ZERO))
	draw_texture_rect(tex, Rect2(0, 0, W * SUB, H * SUB), false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# black out beyond the map edge
	var big := 4000.0
	var c0 := G.iso(Vector2(0, 0))
	var c1 := G.iso(Vector2(W, 0))
	var c2 := G.iso(Vector2(W, H))
	var c3 := G.iso(Vector2(0, H))
	var col := Color(0, 0, 0, 1)
	draw_colored_polygon(PackedVector2Array([c0, c1, Vector2(c1.x + big, c1.y - big), Vector2(c0.x - big, c0.y - big)]), col)
	draw_colored_polygon(PackedVector2Array([c1, c2, Vector2(c2.x + big, c2.y + big), Vector2(c1.x + big, c1.y - big)]), col)
	draw_colored_polygon(PackedVector2Array([c2, c3, Vector2(c3.x - big, c3.y + big), Vector2(c2.x + big, c2.y + big)]), col)
	draw_colored_polygon(PackedVector2Array([c3, c0, Vector2(c0.x - big, c0.y - big), Vector2(c3.x - big, c3.y + big)]), col)
