extends Node2D
# 選取框、血條、放置預覽、指令標記

var game

func hp_color(r: float) -> Color:
	if r > 0.6:
		return Color(0.25, 0.95, 0.25)
	if r > 0.3:
		return Color(1.0, 0.85, 0.15)
	return Color(1.0, 0.2, 0.15)

func bar(center: Vector2, w: float, r: float, segs: int, col := Color(-1, 0, 0)):
	var x0 := center.x - w * 0.5
	draw_rect(Rect2(x0 - 1, center.y - 1, w + 2, 6), Color(0, 0, 0, 0.8))
	var c := hp_color(r) if col.r < 0 else col
	var sw := w / segs
	var filled := int(ceil(r * segs))
	for i in segs:
		var cc := c if i < filled else Color(0.15, 0.15, 0.15)
		draw_rect(Rect2(x0 + i * sw + 0.5, center.y, sw - 1.0, 4), cc)

func unit_box(u, col: Color, show_hp := true):
	var sp: Vector2 = u.position
	var h := 24.0 if u.ukind == "inf" else 34.0
	var w := 20.0 if u.ukind == "inf" else 40.0
	if u.def.get("airship", false):
		w = 90.0
		h = 50.0
	var top := sp - Vector2(0, h + (u.alt if u.ukind == "air" else 0.0))
	var r := Rect2(top.x - w * 0.5, top.y, w, h + 6)
	var L := 6.0
	for c in [[r.position, Vector2(1, 0), Vector2(0, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)], [r.end, Vector2(-1, 0), Vector2(0, -1)]]:
		draw_line(c[0], c[0] + c[1] * L, col, 1.5)
		draw_line(c[0], c[0] + c[2] * L, col, 1.5)
	if show_hp:
		bar(Vector2(sp.x, r.position.y - 7), w, u.hp / u.max_hp, 8 if u.ukind == "inf" else 12)
		if u.def.get("harvester", false):
			bar(Vector2(sp.x, r.position.y - 13), w, u.cargo / u.CARGO_MAX, 10, Color(1, 0.8, 0.2))

func bld_box(b, col: Color):
	var pts := PackedVector2Array()
	for c in [Vector2(b.cell), Vector2(b.cell.x + b.size.x, b.cell.y), Vector2(b.cell + b.size), Vector2(b.cell.x, b.cell.y + b.size.y), Vector2(b.cell)]:
		pts.append(game.iso(c))
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.8), 1.5)
	var top = b.position.y - (b.sheet.ay / b.sheet.res if b.sheet != null else 40.0) + 6.0
	bar(Vector2(b.position.x, top - 8), 22.0 * (b.size.x + b.size.y), b.hp / b.max_hp, 5 * (b.size.x + b.size.y))

func _draw():
	var human = game.human
	var t: float = game.time
	# markers
	for m in game.markers:
		var f: float = m.t / 0.8
		var s := 14.0 * (1.0 - f) + 4.0
		var c: Color = m.c
		c.a = 1.0 - f
		var p: Vector2 = game.iso(m.p)
		draw_polyline(PackedVector2Array([p + Vector2(-s * 2, 0), p + Vector2(0, -s), p + Vector2(s * 2, 0), p + Vector2(0, s), p + Vector2(-s * 2, 0)]), c, 2.0)
	# selection
	for e in game.selection:
		if not is_instance_valid(e) or e.dead:
			continue
		var col := Color(1, 1, 1) if e.player == human else Color(1, 0.35, 0.3)
		if e.kind == "unit":
			unit_box(e, col)
			if e.player == human and not e.waypoints.is_empty():
				var prev: Vector2 = game.iso(e.move_dest)
				for w in e.waypoints:
					var np: Vector2 = game.iso(w[0])
					draw_dashed_line(prev, np, Color(0.3, 1, 0.8, 0.6), 1.5, 5.0)
					draw_circle(np, 3.0, Color(0.3, 1, 0.8, 0.8))
					prev = np
		else:
			bld_box(e, col)
			if e.player == human and e.rally.x >= 0 and (e.def.role in ["bar", "fac"] or e.def.get("airfield", false)):
				var a: Vector2 = e.position
				var b: Vector2 = game.iso(e.rally)
				draw_dashed_line(a, b, Color(0.4, 1, 0.4, 0.7), 1.5, 6.0)
				draw_circle(b, 4.0, Color(0.4, 1, 0.4, 0.8))
	# hover
	var h = game.hover
	if h != null and is_instance_valid(h) and not h.dead and not game.selection.has(h):
		var col := Color(1, 1, 1, 0.5) if h.player == human else Color(1, 0.4, 0.3, 0.6)
		if h.player.neutral:
			col = Color(0.8, 0.8, 0.8, 0.6)
		if h.kind == "unit":
			unit_box(h, col, true)
		else:
			bld_box(h, col)
		var name: String = h.def.name
		if h.player != human and not h.player.neutral:
			name = "%s (%s)" % [name, h.player.name]
		var tp: Vector2 = h.position + Vector2(-60, 14)
		draw_string(G.font, tp + Vector2(1, 1), name, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0, 0, 0, 0.8))
		draw_string(G.font, tp, name, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.95))
	# drag box
	if game.dragging:
		var a: Vector2 = game.drag_start
		var b := get_global_mouse_position()
		if a.distance_to(b) > 8.0 / game.zoom:
			var r := Rect2(a, Vector2.ZERO).expand(b)
			draw_rect(r, Color(0.3, 1, 0.3, 0.12), true)
			draw_rect(r, Color(0.4, 1, 0.4, 0.9), false, 1.5)
	# placement ghost
	if game.place_id != "":
		var id: String = game.place_id
		var tl: Vector2i = game.place_tl()
		var def: Dictionary = Defs.BUILDINGS[id]
		var ok: bool = game.can_place(id, tl, human)
		var sz: Vector2i = def.size
		# build radius hint
		for b in game.buildings:
			if b.player == human and not b.def.get("wall", false):
				var g: int = game.BUILD_GAP
				var c0 := Vector2(b.cell - Vector2i(g, g))
				var c1 := Vector2(b.cell + b.size + Vector2i(g, g))
				draw_polyline(PackedVector2Array([game.iso(c0), game.iso(Vector2(c1.x, c0.y)), game.iso(c1), game.iso(Vector2(c0.x, c1.y)), game.iso(c0)]), Color(1, 1, 1, 0.08), 1.0)
		for y in range(tl.y, tl.y + sz.y):
			for x in range(tl.x, tl.x + sz.x):
				var cell_ok: bool = game.cell_buildable(id, x, y)
				var c := Color(0.2, 1, 0.3, 0.35) if (cell_ok and ok) else Color(1, 0.2, 0.15, 0.4)
				var pts := PackedVector2Array([game.iso(Vector2(x, y)), game.iso(Vector2(x + 1, y)), game.iso(Vector2(x + 1, y + 1)), game.iso(Vector2(x, y + 1))])
				draw_colored_polygon(pts, c)
		var sh = G.sheet(id)
		if sh != null:
			var center := Vector2(tl) + Vector2(sz) * 0.5
			sh.draw(self, 0, game.iso(center), human.color, Color(1, 1, 1, 0.55))
	# super weapon targeting
	if game.cmd_mode.begins_with("power:"):
		var kind: String = game.cmd_mode.substr(6)
		var p: Vector2 = game.iso(game.mouse_world())
		var r: float = maxf(0.8, float(Defs.SUPER[kind].radius)) * 45.25
		draw_set_transform(p, 0.0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1, 0.2, 0.1, 0.8), 2.0)
		draw_arc(Vector2.ZERO, r * (0.5 + 0.5 * fmod(t, 1.0)), 0, TAU, 48, Color(1, 0.4, 0.2, 0.5), 1.5)
		draw_set_transform(Vector2.ZERO)
		draw_line(p + Vector2(-14, 0), p + Vector2(14, 0), Color(1, 0.3, 0.2), 2.0)
		draw_line(p + Vector2(0, -10), p + Vector2(0, 10), Color(1, 0.3, 0.2), 2.0)
	# cursor hints
	var mp := get_global_mouse_position()
	var hint := ""
	var hc := Color(1, 1, 1)
	match game.cmd_mode:
		"amove":
			hint = "攻擊移動"
			hc = Color(1, 0.4, 0.3)
		"sell":
			hint = "$ 出售"
			hc = Color(0.4, 1, 0.4)
		"repair":
			hint = "修理"
			hc = Color(0.5, 0.8, 1)
		_:
			if game.cmd_mode.begins_with("power:"):
				hint = Defs.SUPER[game.cmd_mode.substr(6)].name
				hc = Color(1, 0.4, 0.2)
	if hint == "" and game.place_id == "" and h != null and is_instance_valid(h) and not game.own_selected_units().is_empty():
		if h.player != human and not h.player.neutral:
			hint = "攻擊"
			hc = Color(1, 0.3, 0.25)
			for u in game.own_selected_units():
				if u.def.get("engineer", false) and h.kind == "building":
					hint = "佔領"
					hc = Color(1, 0.85, 0.3)
				elif u.def.get("spy", false) and h.kind == "building":
					hint = "滲透"
					hc = Color(1, 0.95, 0.4)
		elif h.kind == "building" and h.def.has("garrison") and (h.player.neutral or h.player == human):
			for u in game.own_selected_units():
				if game.can_garrison(u, h):
					hint = "進駐"
					hc = Color(0.4, 0.85, 1.0)
		elif h.player.neutral and h.kind == "building":
			for u in game.own_selected_units():
				if u.def.get("engineer", false):
					hint = "佔領"
					hc = Color(1, 0.85, 0.3)
	if hint != "":
		var fs = 14.0 / game.zoom
		draw_string(G.font_bold, mp + Vector2(16, 26) / game.zoom + Vector2(1, 1), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), Color(0, 0, 0, 0.8))
		draw_string(G.font_bold, mp + Vector2(16, 26) / game.zoom, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), hc)
