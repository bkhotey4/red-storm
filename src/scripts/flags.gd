extends RefCounted
# 各國國旗繪製（簡化但可辨識的設計），供 HUD / 選單 / 簡報使用
# FlagS.draw(ci, Rect2, country_id)

static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot := -PI / 2):
	var pts := PackedVector2Array()
	for k in 10:
		var rr := r if k % 2 == 0 else r * 0.42
		var a := rot + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)

static func draw(ci: CanvasItem, r: Rect2, id: String):
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	var red := Color(0.8, 0.1, 0.12)
	var blue := Color(0.1, 0.2, 0.55)
	var white := Color(0.97, 0.97, 0.97)
	match id:
		"usa":
			for k in 13:
				ci.draw_rect(Rect2(o.x, o.y + h * k / 13.0, w, h / 13.0 + 0.5), red if k % 2 == 0 else white)
			ci.draw_rect(Rect2(o.x, o.y, w * 0.42, h * 7.0 / 13.0), blue)
			for yy in 4:
				for xx in 5:
					ci.draw_circle(o + Vector2(w * 0.42 * (xx + 0.5) / 5.0, h * 7.0 / 13.0 * (yy + 0.5) / 4.0), h * 0.035, white)
		"japan":
			ci.draw_rect(r, white)
			ci.draw_circle(o + Vector2(w * 0.5, h * 0.5), h * 0.3, Color(0.75, 0.05, 0.1))
		"korea":
			ci.draw_rect(r, white)
			var c := o + Vector2(w * 0.5, h * 0.5)
			var rr := h * 0.26
			ci.draw_circle(c, rr, Color(0.8, 0.1, 0.2))
			# 下半藍（以多邊形近似太極）
			var pts := PackedVector2Array()
			for k in 17:
				var a := PI * 0.15 + PI * k / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, Color(0.1, 0.25, 0.6))
			ci.draw_circle(c + Vector2(-rr * 0.5, rr * 0.1).rotated(-0.15), rr * 0.5, Color(0.8, 0.1, 0.2))
			ci.draw_circle(c + Vector2(rr * 0.5, -rr * 0.1).rotated(-0.15), rr * 0.5, Color(0.1, 0.25, 0.6))
			var black := Color(0.08, 0.08, 0.08)
			for q in [[-1, -1], [1, 1], [1, -1], [-1, 1]]:
				var base := c + Vector2(q[0] * w * 0.3, q[1] * h * 0.28)
				for k in 3:
					var p := base + Vector2(0, (k - 1) * h * 0.075)
					ci.draw_line(p - Vector2(w * 0.07, 0), p + Vector2(w * 0.07, 0), black, h * 0.045)
		"taiwan":
			ci.draw_rect(r, Color(0.85, 0.08, 0.12))
			ci.draw_rect(Rect2(o.x, o.y, w * 0.5, h * 0.5), Color(0.0, 0.15, 0.6))
			var c := o + Vector2(w * 0.25, h * 0.25)
			for k in 12:
				var a := k * TAU / 12.0
				ci.draw_line(c, c + Vector2(cos(a), sin(a)) * h * 0.17, white, h * 0.04)
			ci.draw_circle(c, h * 0.09, white)
		"ukraine":
			ci.draw_rect(Rect2(o.x, o.y, w, h * 0.5), Color(0.0, 0.35, 0.73))
			ci.draw_rect(Rect2(o.x, o.y + h * 0.5, w, h * 0.5), Color(1.0, 0.84, 0.0))
		"russia":
			ci.draw_rect(Rect2(o.x, o.y, w, h / 3.0), white)
			ci.draw_rect(Rect2(o.x, o.y + h / 3.0, w, h / 3.0), Color(0.0, 0.2, 0.6))
			ci.draw_rect(Rect2(o.x, o.y + h * 2.0 / 3.0, w, h / 3.0), Color(0.85, 0.1, 0.12))
		"nkorea":
			ci.draw_rect(r, Color(0.0, 0.2, 0.6))
			ci.draw_rect(Rect2(o.x, o.y + h * 0.16, w, h * 0.04), white)
			ci.draw_rect(Rect2(o.x, o.y + h * 0.2, w, h * 0.6), Color(0.85, 0.1, 0.12))
			ci.draw_rect(Rect2(o.x, o.y + h * 0.8, w, h * 0.04), white)
			var c := o + Vector2(w * 0.33, h * 0.5)
			ci.draw_circle(c, h * 0.2, white)
			star(ci, c, h * 0.17, Color(0.85, 0.1, 0.12))
		"iran":
			ci.draw_rect(Rect2(o.x, o.y, w, h / 3.0), Color(0.15, 0.6, 0.25))
			ci.draw_rect(Rect2(o.x, o.y + h / 3.0, w, h / 3.0), white)
			ci.draw_rect(Rect2(o.x, o.y + h * 2.0 / 3.0, w, h / 3.0), Color(0.85, 0.1, 0.12))
			var c := o + Vector2(w * 0.5, h * 0.5)
			ci.draw_arc(c, h * 0.11, PI * 0.2, PI * 1.3, 12, Color(0.85, 0.1, 0.12), h * 0.035)
			ci.draw_arc(c, h * 0.11, PI * 1.7, PI * 2.8, 12, Color(0.85, 0.1, 0.12), h * 0.035)
			ci.draw_line(c + Vector2(0, -h * 0.14), c + Vector2(0, h * 0.1), Color(0.85, 0.1, 0.12), h * 0.035)
		"cuba":
			for k in 5:
				ci.draw_rect(Rect2(o.x, o.y + h * k / 5.0, w, h / 5.0 + 0.5), Color(0.0, 0.25, 0.6) if k % 2 == 0 else white)
			var tri := PackedVector2Array([o, o + Vector2(w * 0.45, h * 0.5), o + Vector2(0, h)])
			ci.draw_colored_polygon(tri, Color(0.8, 0.1, 0.12))
			star(ci, o + Vector2(w * 0.15, h * 0.5), h * 0.14, white)
		"china":
			ci.draw_rect(r, Color(0.87, 0.1, 0.1))
			var y := Color(1.0, 0.87, 0.0)
			star(ci, o + Vector2(w * 0.17, h * 0.32), h * 0.19, y)
			for p in [Vector2(0.34, 0.12), Vector2(0.42, 0.27), Vector2(0.42, 0.45), Vector2(0.34, 0.58)]:
				star(ci, o + Vector2(w * p.x, h * p.y), h * 0.07, y)
		"yemen":
			ci.draw_rect(Rect2(o.x, o.y, w, h / 3.0), Color(0.85, 0.1, 0.12))
			ci.draw_rect(Rect2(o.x, o.y + h / 3.0, w, h / 3.0), white)
			ci.draw_rect(Rect2(o.x, o.y + h * 2.0 / 3.0, w, h / 3.0), Color(0.08, 0.08, 0.08))
		_:
			if Defs.COUNTRIES.has(id):
				var fc: Array = Defs.COUNTRIES[id].flag
				for k in 3:
					ci.draw_rect(Rect2(o.x, o.y + h * k / 3.0, w, h / 3.0 + 0.5), fc[k])
			else:
				ci.draw_rect(r, Color(0.3, 0.3, 0.3))
	ci.draw_rect(r, Color(0, 0, 0, 0.7), false, 1.0)
