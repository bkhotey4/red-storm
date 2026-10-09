extends CanvasLayer
const FlagS = preload("res://scripts/flags.gd")
# 介面：右側建造欄、雷達、資金電力、訊息、選單

const SW := 300.0
const TABS := ["building", "defense", "infantry", "vehicle", "naval"]
const TAB_NAMES := ["建築", "防禦", "步兵", "載具", "海軍"]
const CW := 134.0
const CH := 98.0
const MMH := 160.0

var game
var side: Control
var top: Control
var tab := 0
var scroll := [0, 0, 0, 0, 0]
var msgs: Array = []
var pings: Array = []
var mm_img: Image
var mm_tex: ImageTexture
var mm_base: Image
var mm_mask: Image
var mm_t := 0.0
var hover_item := ""
var show_fps := false
var hover_btn := ""
var mm_drag := false
var pause_panel: Control
var end_panel: Control
var help_panel: Control
var accent := Color(0.75, 0.12, 0.08)
var theme_res: Theme
var noise_t := 0.0
var cameo_cache := {}

func setup(g):
	game = g
	layer = 10
	accent = Color(0.2, 0.45, 0.85) if g.human.faction == "allies" else Color(0.78, 0.13, 0.08)
	theme_res = make_theme()
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.draw.connect(_draw_top)
	add_child(top)
	side = Control.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_top = 0.0
	side.anchor_bottom = 1.0
	side.offset_left = -SW
	side.offset_right = 0
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	side.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	side.draw.connect(_draw_side)
	side.gui_input.connect(_side_input)
	side.mouse_exited.connect(func(): hover_item = ""; hover_btn = "")
	add_child(side)
	mm_base = game.map.make_preview(false)
	mm_img = mm_base.duplicate()
	mm_mask = Image.create(game.W, game.H, false, Image.FORMAT_RGBA8)
	mm_mask.fill(Color(0, 0, 0, 1))
	mm_tex = ImageTexture.create_from_image(mm_img)
	build_help()

func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = G.font
	t.default_font_size = 16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.15, 0.16, 0.95)
	sb.border_color = accent.darkened(0.2)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.22, 0.23, 0.25, 0.98)
	sbh.border_color = accent.lightened(0.2)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = accent.darkened(0.35)
	t.set_stylebox("normal", "Button", sb)
	t.set_stylebox("hover", "Button", sbh)
	t.set_stylebox("pressed", "Button", sbp)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.92, 0.92, 0.9))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(0.07, 0.08, 0.09, 0.94)
	pn.border_color = accent
	pn.set_border_width_all(2)
	pn.set_corner_radius_all(4)
	pn.content_margin_left = 28
	pn.content_margin_right = 28
	pn.content_margin_top = 22
	pn.content_margin_bottom = 22
	t.set_stylebox("panel", "PanelContainer", pn)
	return t

func over_ui(mp: Vector2) -> bool:
	var vs := side.get_viewport_rect().size
	if mp.x >= vs.x - SW:
		return true
	if pause_panel != null and pause_panel.visible:
		return true
	if end_panel != null and end_panel.visible:
		return true
	return false

func add_message(t: String):
	msgs.append({"text": t, "t": 0.0})
	if msgs.size() > 6:
		msgs.pop_front()

func ping(p: Vector2):
	pings.append({"p": p, "t": 0.0})

func _process(delta: float):
	for m in msgs:
		m.t += delta
	msgs = msgs.filter(func(m): return m.t < 7.0)
	for p in pings:
		p.t += delta
	pings = pings.filter(func(p): return p.t < 3.0)
	mm_t -= delta
	noise_t += delta
	if mm_t <= 0.0:
		mm_t = 0.4
		update_minimap()
	side.queue_redraw()
	top.queue_redraw()

# ───────────────────────── minimap ─────────────────────────
func radar_on() -> bool:
	return game.human.has_role("radar") and not game.human.low_power

func update_minimap():
	var W: int = game.W
	var H: int = game.H
	mm_img.copy_from(mm_base)
	var map = game.map
	for i in map.ore_cells.keys():
		mm_img.set_pixel(i % W, i / W, Color(0.9, 0.72, 0.15) if map.gem[i] == 0 else Color(0.75, 0.35, 0.95))
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var c: Color = b.player.color
		for y in range(b.cell.y, b.cell.y + b.size.y):
			for x in range(b.cell.x, b.cell.x + b.size.x):
				mm_img.set_pixel(x, y, c)
	for u in game.units:
		if u.dead or not u.visible:
			continue
		var x := clampi(int(u.pos.x), 0, W - 1)
		var y := clampi(int(u.pos.y), 0, H - 1)
		mm_img.set_pixel(x, y, u.player.color.lightened(0.35))
	mm_img.blend_rect(mm_mask, Rect2i(0, 0, W, H), Vector2i.ZERO)
	mm_tex.update(mm_img)

func mm_rect() -> Rect2:
	return Rect2(16, 46, SW - 32, MMH)

func mm_k() -> float:
	return minf((SW - 32.0) / float(game.W + game.H), (MMH - 8.0) / float(game.W + game.H) * 2.0)

func mm_origin() -> Vector2:
	var r := mm_rect()
	var k := mm_k()
	return Vector2(r.position.x + r.size.x * 0.5, r.position.y + (r.size.y - (game.W + game.H) * k * 0.5) * 0.5)

func world_to_mm(p: Vector2) -> Vector2:
	var k := mm_k()
	return mm_origin() + Vector2((p.x - p.y) * k, (p.x + p.y) * k * 0.5)

func mm_to_world(s: Vector2) -> Vector2:
	var k := mm_k()
	var d := s - mm_origin()
	var a := d.x / k
	var b := d.y / (k * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)

# ───────────────────────── sidebar drawing ─────────────────────────
func bevel(ci: CanvasItem, r: Rect2, inset := true, base := Color(0.05, 0.07, 0.09)):
	var c := minf(6.0, minf(r.size.x, r.size.y) * 0.3)
	var pts := PackedVector2Array([r.position + Vector2(c, 0), Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.end.y - c),
		Vector2(r.end.x - c, r.end.y), Vector2(r.position.x, r.end.y), Vector2(r.position.x, r.position.y + c)])
	var fill := base.darkened(0.25) if inset else base
	ci.draw_colored_polygon(pts, Color(fill.r, fill.g, fill.b, 0.92))
	var la := 0.45 if inset else 0.75
	var lc := accent.lightened(0.35)
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(lc.r, lc.g, lc.b, la), 1.0)
	# glowing corner ticks
	ci.draw_line(r.position + Vector2(c, 0), r.position + Vector2(c + 14, 0), Color(lc.r, lc.g, lc.b, 1.0), 2.0)
	ci.draw_line(r.end - Vector2(c, 0), r.end - Vector2(c + 14, 0), Color(lc.r, lc.g, lc.b, 1.0), 2.0)

func _draw_side():
	var h := side.size.y
	var ci := side
	# tech background
	for i in 16:
		var y0 := h * i / 16.0
		var c := Color(0.06, 0.08, 0.1).lerp(Color(0.025, 0.03, 0.04), i / 16.0)
		ci.draw_rect(Rect2(0, y0, SW, h / 16.0 + 1), c)
	var gc := Color(accent.r, accent.g, accent.b, 0.06)
	var gy := 0.0
	while gy < h:
		ci.draw_line(Vector2(4, gy), Vector2(SW, gy), gc, 1.0)
		gy += 16.0
	var gx := 4.0
	while gx < SW:
		ci.draw_line(Vector2(gx, 0), Vector2(gx, h), gc, 1.0)
		gx += 16.0
	# glowing edge
	for k in 6:
		ci.draw_line(Vector2(k, 0), Vector2(k, h), Color(accent.r, accent.g, accent.b, 0.5 - k * 0.08), 1.0)
	ci.draw_line(Vector2(1, 0), Vector2(1, h), accent.lightened(0.5), 1.5)
	# moving scan pulse along the edge
	var py := fmod(noise_t * 180.0, h + 200.0) - 100.0
	ci.draw_line(Vector2(1, py), Vector2(1, py + 80), Color(1, 1, 1, 0.7), 2.0)
	var human = game.human
	# money
	bevel(ci, Rect2(16, 8, SW - 32, 32))
	var money_s := "$ " + G.fmt_money(human.money)
	ci.draw_string(G.font_bold, Vector2(16, 32), money_s, HORIZONTAL_ALIGNMENT_CENTER, SW - 32, 23, Color(1.0, 0.82, 0.25, 0.35))
	ci.draw_string(G.font_bold, Vector2(17, 33), money_s, HORIZONTAL_ALIGNMENT_CENTER, SW - 32, 23, Color(0, 0, 0, 0.5))
	ci.draw_string(G.font_bold, Vector2(16, 32), money_s, HORIZONTAL_ALIGNMENT_CENTER, SW - 32, 23, Color(1.0, 0.86, 0.35))
	if Defs.COUNTRIES.has(human.country):
		FlagS.draw(ci, Rect2(22, 12, 40, 24), human.country)
	# radar
	var mr := mm_rect()
	bevel(ci, mr.grow(3), true, Color(0.02, 0.03, 0.02))
	if radar_on():
		ci.draw_set_transform_matrix(Transform2D(Vector2(mm_k(), mm_k() * 0.5), Vector2(-mm_k(), mm_k() * 0.5), mm_origin()))
		ci.draw_texture_rect(mm_tex, Rect2(0, 0, game.W, game.H), false)
		ci.draw_set_transform_matrix(Transform2D.IDENTITY)
		# camera view
		var vs := side.get_viewport_rect().size
		var inv: Transform2D = game.get_viewport().get_canvas_transform().affine_inverse()
		var pts := PackedVector2Array()
		for c in [Vector2(0, 0), Vector2(vs.x - SW, 0), Vector2(vs.x - SW, vs.y), Vector2(0, vs.y), Vector2(0, 0)]:
			var wp := G.uniso(inv * c)
			var mp := world_to_mm(wp)
			pts.append(Vector2(clampf(mp.x, mr.position.x, mr.end.x), clampf(mp.y, mr.position.y, mr.end.y)))
		ci.draw_polyline(pts, Color(1, 1, 1, 0.8), 1.0)
		var cc := mr.get_center()
		var sa := noise_t * 1.6
		for k in 12:
			var a0 := sa - k * 0.05
			ci.draw_line(cc, cc + Vector2.from_angle(a0) * 100.0, Color(accent.r, accent.g, accent.b, 0.22 - k * 0.018), 2.0)
		var sy := mr.position.y
		while sy < mr.end.y:
			ci.draw_line(Vector2(mr.position.x, sy), Vector2(mr.end.x, sy), Color(0, 0, 0, 0.12), 1.0)
			sy += 3.0
		for pg in pings:
			var pp := world_to_mm(pg.p)
			var a: float = 1.0 - pg.t / 3.0
			ci.draw_arc(pp, 4.0 + fmod(pg.t * 20.0, 14.0), 0, TAU, 20, Color(1, 0.3, 0.2, a), 1.5)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(noise_t * 12.0)
		for k in 140:
			var p := mr.position + Vector2(rng.randf() * mr.size.x, rng.randf() * mr.size.y)
			var v := rng.randf() * 0.25
			ci.draw_rect(Rect2(p, Vector2(rng.randf_range(2, 8), 1)), Color(v, v * 1.1, v, 1))
		var txt := "雷達離線" if not human.has_role("radar") else "電力不足"
		ci.draw_string(G.font_bold, Vector2(mr.position.x, mr.position.y + mr.size.y * 0.5), txt, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 18, Color(0.6, 0.8, 0.6, 0.7))
		ci.draw_string(G.font, Vector2(mr.position.x, mr.position.y + mr.size.y * 0.5 + 22), "(建造雷達站以開啟小地圖)" if not human.has_role("radar") else "", HORIZONTAL_ALIGNMENT_CENTER, mr.size.x, 12, Color(0.6, 0.7, 0.6, 0.6))
	# power bar
	var pb := Rect2(6, grid_rect().position.y, 8, h - grid_rect().position.y - 100)
	bevel(ci, pb.grow(1))
	var cap := maxf(human.power_prod, human.power_use) * 1.15 + 1.0
	var prod_h: float = pb.size.y * human.power_prod / cap
	var use_h: float = pb.size.y * human.power_use / cap
	var pc := Color(0.2, 0.9, 0.3) if not human.low_power else Color(1, 0.2, 0.1)
	if human.power_prod - human.power_use < 50 and not human.low_power:
		pc = Color(1, 0.8, 0.2)
	ci.draw_rect(Rect2(pb.position.x, pb.end.y - prod_h, pb.size.x, prod_h), pc)
	ci.draw_line(Vector2(pb.position.x - 3, pb.end.y - use_h), Vector2(pb.end.x + 3, pb.end.y - use_h), Color(1, 1, 1), 2.0)
	# tabs
	for i in 5:
		var r := tab_rect(i)
		var active := i == tab
		var has_ready := false
		if i < 2:
			has_ready = human.ready[TABS[i]] != ""
		var bc := accent.darkened(0.2) if active else Color(0.18, 0.19, 0.2)
		if has_ready and int(noise_t * 3.0) % 2 == 0:
			bc = Color(0.8, 0.65, 0.1)
		bevel(ci, r, false, bc)
		var col := Color(1, 1, 1) if active else Color(0.75, 0.75, 0.75)
		if not tab_enabled(i):
			col = Color(0.4, 0.4, 0.4)
		ci.draw_string(G.font_bold, Vector2(r.position.x, r.position.y + 21), TAB_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, col)
	# cameos
	var items := tab_items(tab)
	var gr := grid_rect()
	var max_rows := int(gr.size.y / (CH + 4))
	var start: int = scroll[tab] * 2
	for k in range(start, mini(items.size(), start + max_rows * 2)):
		var idx := k - start
		var r := Rect2(gr.position.x + (idx % 2) * (CW + 4), gr.position.y + (idx / 2) * (CH + 4), CW, CH)
		draw_cameo(ci, r, items[k])
	if items.size() > max_rows * 2:
		var total_rows := int(ceil(items.size() / 2.0))
		ci.draw_string(G.font, Vector2(gr.position.x, gr.end.y + 12), "滾輪捲動 (%d/%d)" % [scroll[tab] + 1, total_rows - max_rows + 1], HORIZONTAL_ALIGNMENT_CENTER, gr.size.x, 11, Color(0.7, 0.7, 0.7))
	# bottom buttons
	for b in buttons():
		var r: Rect2 = b.r
		var on: bool = b.get("on", false)
		var bc := Color(0.2, 0.21, 0.22)
		if on:
			bc = accent.darkened(0.1)
		if hover_btn == b.id:
			bc = bc.lightened(0.15)
		if b.get("ready", false) and int(noise_t * 3.0) % 2 == 0:
			bc = Color(0.75, 0.2, 0.1)
		bevel(ci, r, false, bc)
		if b.has("charge") and not b.ready:
			ci.draw_rect(Rect2(r.position + Vector2(2, r.size.y - 5), Vector2((r.size.x - 4) * b.charge, 3)), accent.lightened(0.3))
		ci.draw_string(G.font_bold, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 6), b.label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(0.95, 0.95, 0.9))
	# tooltip
	if hover_item != "":
		draw_tooltip(hover_item)

func tab_rect(i: int) -> Rect2:
	var tw := (SW - 36 - 8) / 5.0
	return Rect2(18 + i * (tw + 2), 44 + MMH + 12, tw, 30)

func power_rows() -> int:
	return game.human.power_list().size()

func grid_rect() -> Rect2:
	var h := side.size.y
	return Rect2(20, 44 + MMH + 50, CW * 2 + 4, h - (44 + MMH + 50) - 100 - power_rows() * 30)

func buttons() -> Array:
	var h := side.size.y
	var y := h - 88
	var human = game.human
	var out := [
		{"id": "repair", "label": "修理 (X)", "r": Rect2(20, y, CW, 30), "on": game.cmd_mode == "repair"},
		{"id": "sell", "label": "出售 (Z)", "r": Rect2(24 + CW, y, CW, 30), "on": game.cmd_mode == "sell"},
		{"id": "menu", "label": "選單 (Esc)", "r": Rect2(20, y + 34, CW * 2 + 4, 30)},
	]
	var pl: Array = human.power_list()
	for i in pl.size():
		var k: String = pl[i]
		var c: float = human.powers[k]
		var nm: String = Defs.SUPER[k].name
		var lbl := "%s  %d%%" % [nm, int(c * 100)]
		if c >= 1.0:
			lbl = "▶ " + nm + " 就緒"
		out.append({"id": "power:" + k, "label": lbl, "r": Rect2(20, y - 6 - (pl.size() - i) * 30, CW * 2 + 4, 27),
			"on": game.cmd_mode == "power:" + k, "ready": c >= 1.0, "charge": c})
	return out

func tab_enabled(i: int) -> bool:
	var human = game.human
	match i:
		0, 1:
			return human.has_role("cy")
		2:
			return human.has_role("bar")
		3:
			return human.has_role("fac") or human.has_role("airfield")
		4:
			return human.has_role("yard")
	return false

func tab_items(i: int) -> Array:
	var out: Array = []
	for id in Defs.BUILD_ORDER[TABS[i]]:
		if game.human.available(id):
			out.append(id)
	return out

func cameo_sheet_frame(id: String) -> Array:
	var sh = G.sheet(id)
	if sh == null:
		return [null, 0]
	var f := 0
	if Defs.UNITS.has(id):
		var d: Dictionary = Defs.UNITS[id]
		if d.kind == "inf":
			f = 1 * 4
		else:
			f = sh.dir_frame(PI * 0.62)
	elif id in ["a_cy", "s_cy", "a_radar", "s_radar", "oil"]:
		f = 2
	return [sh, f]

func draw_cameo(ci: CanvasItem, r: Rect2, id: String):
	var human = game.human
	var def: Dictionary = Defs.get_def(id)
	var ok: bool = human.can_build(id)
	var missing: String = human.missing_req(id)
	var cat: String = human.queue_cat(def)
	var is_ready: bool = human.ready.has(cat) and human.ready[cat] == id
	# background
	for i in 8:
		var c := Color(0.2, 0.25, 0.3).lerp(Color(0.06, 0.07, 0.09), i / 8.0)
		if def.faction == "soviet":
			c = Color(0.3, 0.2, 0.18).lerp(Color(0.08, 0.06, 0.06), i / 8.0)
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 8.0, r.size.x, r.size.y / 8.0 + 1), c)
	var cam = G.cameo(id)
	if cam != null:
		var dst := Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, (r.size.x - 4) * 200.0 / 272.0))
		ci.draw_texture_rect(cam[0], dst, false)
		if cam[1] != null:
			ci.draw_texture_rect(cam[1], dst, false, human.color)
	else:
		var sf := cameo_sheet_frame(id)
		var sh = sf[0]
		if sh != null:
			var sc := minf((r.size.x - 8) / sh.w(), (r.size.y - 18) / sh.h())
			var at = r.position + Vector2(r.size.x * 0.5, r.size.y * 0.5 - 2) + (Vector2(sh.ax, sh.ay) / sh.res - Vector2(sh.w(), sh.h()) * 0.5) * sc
			sh.draw(ci, sf[1], at, human.color, Color.WHITE, sc)
	ci.draw_rect(Rect2(r.position.x, r.end.y - 18, r.size.x, 18), Color(0, 0, 0, 0.62))
	ci.draw_string(G.font, Vector2(r.position.x + 4, r.end.y - 4), def.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, 13, Color(0.95, 0.95, 0.9))
	ci.draw_rect(Rect2(r.end.x - 52, r.position.y, 52, 16), Color(0, 0, 0, 0.45))
	ci.draw_string(G.font_bold, Vector2(r.position.x, r.position.y + 13), "$%d" % int(human.cost_of(id)), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 4, 12, Color(1, 0.85, 0.3))
	var prog: float = human.progress_of(id)
	if not ok and not is_ready and prog < 0.0:
		ci.draw_rect(r, Color(0, 0, 0, 0.62))
		if missing != "":
			ci.draw_string(G.font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), "需要" + missing, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1, 0.5, 0.4))
		elif def.has("limit") and human.count_type(id) >= int(def.limit):
			ci.draw_string(G.font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 4), "已達上限", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(1, 0.7, 0.4))
	if prog >= 0.0:
		# clock sweep over remaining part
		var c := r.get_center()
		var rad := r.size.length()
		var pts := PackedVector2Array([c])
		var a0 := -PI * 0.5 + TAU * prog
		var steps := 24
		for s in steps + 1:
			var a := lerpf(a0, PI * 1.5, float(s) / steps)
			pts.append(c + Vector2.from_angle(a) * rad)
		ci.draw_set_transform(Vector2.ZERO)
		clip_poly_draw(ci, pts, r, Color(0, 0, 0, 0.55))
		ci.draw_string(G.font_bold, Vector2(r.position.x, r.position.y + r.size.y * 0.5), "%d%%" % int(prog * 100), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 1, 1))
	if is_ready:
		var a := 0.6 + 0.4 * sin(noise_t * 8.0)
		ci.draw_rect(r, Color(1, 0.85, 0.2, 0.18 * a))
		ci.draw_string(G.font_bold, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 2), "就緒", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(1, 0.9, 0.3, a))
	var qn: int = human.queued_count(id)
	if qn > 1:
		ci.draw_string(G.font_bold, Vector2(r.position.x + 4, r.position.y + 14), "x%d" % qn, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1, 0.6))
	var border := Color(1, 1, 1, 0.1)
	if hover_item == id:
		border = Color(1, 1, 1, 0.7)
	ci.draw_rect(r, border, false, 1.0)

func clip_poly_draw(ci: CanvasItem, pts: PackedVector2Array, r: Rect2, col: Color):
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var res := Geometry2D.intersect_polygons(pts, rect_poly)
	for poly in res:
		if poly.size() >= 3:
			ci.draw_colored_polygon(poly, col)

func draw_tooltip(id: String):
	var def: Dictionary = Defs.get_def(id)
	var human = game.human
	var lines := [def.name, "造價 $%d" % def.cost]
	if def.has("power") and int(def.power) != 0:
		lines.append("電力 %+d" % int(def.power))
	if Defs.UNITS.has(id):
		lines.append("生命 %d   速度 %.1f" % [def.hp, def.speed])
	lines.append(def.get("desc", ""))
	var miss: String = human.missing_req(id)
	if miss != "":
		lines.append("需要：" + miss)
	lines.append("左鍵：建造　右鍵：取消")
	var w := 210.0
	var h := 20.0 * lines.size() + 10
	var mp := side.get_local_mouse_position()
	var p := Vector2(-w - 8, clampf(mp.y - h * 0.5, 4, side.size.y - h - 4))
	side.draw_rect(Rect2(p, Vector2(w, h)), Color(0.05, 0.06, 0.07, 0.95))
	side.draw_rect(Rect2(p, Vector2(w, h)), accent, false, 1.5)
	for i in lines.size():
		var col := Color(1, 0.85, 0.3) if i == 0 else Color(0.88, 0.88, 0.85)
		if lines[i].begins_with("需要"):
			col = Color(1, 0.45, 0.35)
		side.draw_string(G.font_bold if i == 0 else G.font, p + Vector2(8, 20 + i * 20), lines[i], HORIZONTAL_ALIGNMENT_LEFT, w - 14, 14 if i == 0 else 12, col)

# ───────────────────────── sidebar input ─────────────────────────
func item_at(lp: Vector2) -> String:
	var gr := grid_rect()
	if not gr.has_point(lp):
		return ""
	var items := tab_items(tab)
	var col := int((lp.x - gr.position.x) / (CW + 4))
	var row := int((lp.y - gr.position.y) / (CH + 4))
	if col > 1:
		return ""
	var local := Vector2(fmod(lp.x - gr.position.x, CW + 4), fmod(lp.y - gr.position.y, CH + 4))
	if local.x > CW or local.y > CH:
		return ""
	var k: int = scroll[tab] * 2 + row * 2 + col
	if k < items.size():
		return items[k]
	return ""

func _side_input(ev: InputEvent):
	if game.game_over:
		return
	if ev is InputEventMouseMotion:
		var lp: Vector2 = ev.position
		hover_item = item_at(lp)
		hover_btn = ""
		for b in buttons():
			if b.r.has_point(lp):
				hover_btn = b.id
		if mm_drag and radar_on():
			game.center_on(mm_to_world(lp))
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		var lp: Vector2 = mb.position
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			scroll[tab] = maxi(0, scroll[tab] - 1)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			var items := tab_items(tab)
			var max_rows := int(grid_rect().size.y / (CH + 4))
			var total_rows := int(ceil(items.size() / 2.0))
			scroll[tab] = mini(scroll[tab] + 1, maxi(0, total_rows - max_rows))
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			mm_drag = false
			return
		if not mb.pressed:
			return
		if mm_rect().has_point(lp) and radar_on():
			if mb.button_index == MOUSE_BUTTON_LEFT:
				mm_drag = true
				game.center_on(mm_to_world(lp))
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				var list: Array = game.own_selected_units()
				if not list.is_empty():
					game.command_move(list, mm_to_world(lp))
					Sfx.play("radio", -10.0)
			return
		for i in 5:
			if tab_rect(i).has_point(lp):
				tab = i
				Sfx.play("click", -8.0)
				return
		for b in buttons():
			if b.r.has_point(lp) and mb.button_index == MOUSE_BUTTON_LEFT:
				press_button(b.id)
				return
		var id := item_at(lp)
		if id != "":
			if mb.button_index == MOUSE_BUTTON_LEFT:
				click_item(id)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				if game.human.cancel(id):
					Sfx.play("click", -6.0)
					if game.place_id == id:
						game.place_id = ""

func click_item(id: String):
	var human = game.human
	var def: Dictionary = Defs.get_def(id)
	var cat: String = human.queue_cat(def)
	if human.ready.has(cat) and human.ready[cat] == id:
		game.begin_place(id)
		Sfx.play("click", -6.0)
		return
	if human.can_build(id):
		if human.enqueue(id):
			Sfx.play("click", -6.0)
			if cat == "building" or cat == "defense":
				pass
		else:
			game.message("該生產線正忙碌中")
	else:
		var miss: String = human.missing_req(id)
		if miss != "":
			game.message("需要先建造：" + miss)
		Sfx.play("click", 0.0)

func press_button(id: String):
	Sfx.play("click", -6.0)
	if id.begins_with("power:"):
		var k := id.substr(6)
		if float(game.human.powers.get(k, 0.0)) >= 1.0 and Defs.SUPER[k].target == "self":
			game.fire_power(game.human, k, Vector2(game.human.start_cell))
			return
		if float(game.human.powers.get(k, 0.0)) >= 1.0:
			game.cmd_mode = "" if game.cmd_mode == id else id
			game.place_id = ""
			if Defs.SUPER[k].target == "enemy":
				game.message("選擇要制裁的敵方建築")
			else:
				game.message("選擇「%s」的目標位置" % Defs.SUPER[k].name)
		else:
			game.message("%s 充能中…… %s" % [Defs.SUPER[k].name, Defs.SUPER[k].desc])
		return
	match id:
		"repair":
			game.cmd_mode = "" if game.cmd_mode == "repair" else "repair"
			game.place_id = ""
		"sell":
			game.cmd_mode = "" if game.cmd_mode == "sell" else "sell"
			game.place_id = ""
		"menu":
			toggle_pause_menu()

# ───────────────────────── top overlay ─────────────────────────
func _draw_top():
	var ci := top
	var vs := top.size
	# time
	var t: float = game.time
	var ts := "%02d:%02d" % [int(t) / 60, int(t) % 60]
	var info := ts
	if game.human.country_name() != "":
		info += "  " + game.human.country_name()
	if game.speed != 1.0:
		info += "  x%.2f" % game.speed
	if game.paused:
		info += "  [暫停]"
	ci.draw_rect(Rect2(8, 6, 250, 24), Color(0, 0, 0, 0.45))
	ci.draw_string(G.font_bold, Vector2(16, 24), info, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.9, 0.85))
	ci.draw_string(G.font, Vector2(170, 24), "F1 操作說明   T 外交", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.7, 0.7))
	if show_fps:
		ci.draw_string(G.font_bold, Vector2(vs.x - SW - 150, 24), "FPS %d  單位 %d  地圖 %dx%d" % [Engine.get_frames_per_second(), game.units.size(), game.W, game.H], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 1, 0.6))
	var np: int = game.human.proposal.size()
	if np > 0 and int(noise_t * 2.0) % 2 == 0:
		ci.draw_string(G.font_bold, Vector2(262, 24), "✉ 外交提議", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.3))
	# 敵方超級武器倒數（情報面板）
	var ex := 0.0
	var px := (vs.x - SW) * 0.5 - 170.0
	var py := 8.0
	for pl in game.players:
		if pl == game.human or pl.neutral or not pl.alive or not game.human.is_enemy_of(pl):
			continue
		for k in pl.power_list():
			if not (k in ["nuke", "storm", "barrage", "strait", "blockade", "armor", "paradrop", "militia", "df"]):
				continue
			var c: float = pl.powers[k]
			var cm: float = float(Defs.COUNTRIES[pl.country].get("charge", {}).get(k, 1.0)) if Defs.COUNTRIES.has(pl.country) else 1.0
			var rem := int((1.0 - c) * float(Defs.SUPER[k].charge) / cm)
			var big: bool = k in ["nuke", "storm", "barrage"]
			var r := Rect2(px, py, 340, 22)
			ci.draw_rect(r, Color(0.25, 0.02, 0.02, 0.72) if big else Color(0.05, 0.05, 0.08, 0.7))
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x * c, r.size.y)), Color(pl.color.r, pl.color.g, pl.color.b, 0.35))
			ci.draw_rect(r, Color(pl.color.r, pl.color.g, pl.color.b, 0.8), false, 1.0)
			var txt := "%s  %s  %02d:%02d" % [pl.name, Defs.SUPER[k].name, rem / 60, rem % 60]
			if c >= 1.0:
				txt = "%s  %s  ‼ 就緒" % [pl.name, Defs.SUPER[k].name]
				if int(noise_t * 4.0) % 2 == 0:
					ci.draw_rect(r, Color(1, 0.2, 0.1, 0.35))
			ci.draw_string(G.font_bold, Vector2(r.position.x + 8, r.position.y + 16), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 16, 14, Color(1, 0.9, 0.85) if big else Color(0.9, 0.9, 0.9))
			py += 25.0
			ex += 1.0
	if ex > 0.0:
		ci.draw_string(G.font, Vector2(px, 6.0 + py), "敵方超級武器 / 特殊能力倒數", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.6, 0.5, 0.8))
	# RSN 時事快訊橫幅
	if game.world_ev != null and game.world_ev.banner_t > 0.0:
		var bw := 760.0
		var bx := (vs.x - SW) * 0.5 - bw * 0.5
		var by := vs.y - 150.0
		var fade := clampf(game.world_ev.banner_t / 1.5, 0.0, 1.0)
		ci.draw_rect(Rect2(bx, by, bw, 34), Color(0.04, 0.04, 0.07, 0.9 * fade))
		ci.draw_rect(Rect2(bx, by, 64, 34), Color(0.75, 0.08, 0.06, fade))
		ci.draw_string(G.font_bold, Vector2(bx, by + 24), "RSN", HORIZONTAL_ALIGNMENT_CENTER, 64, 17, Color(1, 1, 1, fade))
		ci.draw_rect(Rect2(bx, by, bw, 2), Color(0.75, 0.08, 0.06, fade))
		ci.draw_string(G.font_bold, Vector2(bx + 76, by + 23), game.world_ev.banner, HORIZONTAL_ALIGNMENT_LEFT, bw - 88, 15, Color(1, 0.95, 0.85, fade))
	if game.world_ev != null and not game.world_ev.active.is_empty():
		var ly := 36.0
		for l in game.world_ev.status_lines():
			ci.draw_string(G.font, Vector2(vs.x - SW - 260, ly + 14), "◆ " + l, HORIZONTAL_ALIGNMENT_LEFT, 250, 12, Color(1, 0.8, 0.5, 0.9))
			ly += 16.0
	var y := 52.0
	if game.objective != "":
		ci.draw_rect(Rect2(8, 34, 330, 24), Color(0.3, 0.05, 0.02, 0.6))
		ci.draw_string(G.font_bold, Vector2(16, 52), game.objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 0.85, 0.4))
		y = 80.0
	# messages
	for m in msgs:
		var a := clampf(7.0 - m.t, 0.0, 1.0)
		ci.draw_string(G.font_bold, Vector2(17, y + 1), m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, a * 0.8))
		ci.draw_string(G.font_bold, Vector2(16, y), m.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.55, 1.0, 0.55, a))
		y += 22.0
	# selection info panel
	var sel: Array = game.selection.filter(func(e): return is_instance_valid(e) and not e.dead)
	if not sel.is_empty():
		var e = sel[0]
		var pw := 330.0
		var ph := 64.0
		var r := Rect2(8, vs.y - ph - 30, pw, ph)
		ci.draw_rect(r, Color(0.05, 0.06, 0.07, 0.8))
		ci.draw_rect(r, accent.darkened(0.2), false, 1.5)
		var title: String = e.def.name
		if sel.size() > 1:
			title = "已選取 %d 個單位" % sel.size()
		elif e.player != game.human:
			title += "  (%s)" % e.player.name
		ci.draw_string(G.font_bold, r.position + Vector2(10, 22), title, HORIZONTAL_ALIGNMENT_LEFT, pw - 20, 16, Color(1, 0.9, 0.5))
		if sel.size() == 1:
			var hr: float = e.hp / e.max_hp
			ci.draw_rect(Rect2(r.position + Vector2(10, 32), Vector2(200, 8)), Color(0.15, 0.15, 0.15))
			ci.draw_rect(Rect2(r.position + Vector2(10, 32), Vector2(200 * hr, 8)), game.overlay.hp_color(hr))
			var extra := "%d / %d" % [int(e.hp), int(e.max_hp)]
			if e.kind == "unit":
				if e.rank > 0:
					extra += "   " + ["", "老兵 ★", "精英 ★★"][e.rank]
				if e.def.get("harvester", false):
					extra += "   載礦 %d%%" % int(e.cargo / e.CARGO_MAX * 100)
			else:
				if e.def.has("power") and int(e.def.power) != 0:
					extra += "   電力 %+d" % int(e.def.power)
			ci.draw_string(G.font, r.position + Vector2(10, 56), extra, HORIZONTAL_ALIGNMENT_LEFT, pw - 20, 13, Color(0.85, 0.85, 0.85))
		else:
			var counts := {}
			for s in sel:
				counts[s.def.name] = counts.get(s.def.name, 0) + 1
			var parts := []
			for k in counts:
				parts.append("%s x%d" % [k, counts[k]])
			ci.draw_string(G.font, r.position + Vector2(10, 46), "、".join(parts), HORIZONTAL_ALIGNMENT_LEFT, pw - 20, 13, Color(0.85, 0.85, 0.85))
	# hint bar
	var hint := "左鍵:選取/框選　右鍵:移動/攻擊　A:攻擊移動　S:停止　D:展開基地車　Ctrl+數字:編隊　H:回基地　N:閒置礦車　I:閒置單位　Tab:生產建築　滾輪:縮放"
	ci.draw_rect(Rect2(0, vs.y - 22, vs.x - SW, 22), Color(0, 0, 0, 0.55))
	ci.draw_string(G.font, Vector2(10, vs.y - 6), hint, HORIZONTAL_ALIGNMENT_LEFT, vs.x - SW - 20, 12, Color(0.75, 0.75, 0.72))
	# placement tip
	if game.place_id != "":
		var txt := "放置 %s：左鍵確定，右鍵取消" % Defs.BUILDINGS[game.place_id].name
		ci.draw_string(G.font_bold, Vector2(0, 90), txt, HORIZONTAL_ALIGNMENT_CENTER, vs.x - SW, 18, Color(1, 0.9, 0.4))

# ───────────────────────── menus ─────────────────────────
func make_panel(title: String) -> Array:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.theme = theme_res
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	root.add_child(cc)
	var pc := PanelContainer.new()
	cc.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	var lb := Label.new()
	lb.text = title
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", G.font_bold)
	lb.add_theme_font_size_override("font_size", 30)
	lb.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	vb.add_child(lb)
	add_child(root)
	return [root, vb]

func add_btn(vb: VBoxContainer, text: String, cb: Callable):
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.pressed.connect(func(): Sfx.play("click", -4.0); cb.call())
	vb.add_child(b)

var diplo_panel: Control
var diplo_vb: VBoxContainer

func toggle_diplomacy():
	if end_panel != null and end_panel.visible:
		return
	if diplo_panel != null and diplo_panel.visible:
		diplo_panel.visible = false
		game.paused = false
		return
	if diplo_panel == null:
		var pr := make_panel("外交（T）")
		diplo_panel = pr[0]
		diplo_vb = pr[1]
	rebuild_diplomacy()
	diplo_panel.visible = true
	game.paused = true

func rebuild_diplomacy():
	for c in diplo_vb.get_children():
		if c is Label and c == diplo_vb.get_child(0):
			continue
		c.queue_free()
	var human = game.human
	var tip := Label.new()
	tip.text = "好感度會隨時間回升，攻擊對方會下降。結盟需 50%，停火需 35%。\n結盟後共享視野，並獲得「盟友支援」能力；攻擊盟友會導致同盟破裂。"
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	diplo_vb.add_child(tip)
	for q in game.others_of(human):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var fl := Control.new()
		fl.custom_minimum_size = Vector2(40, 26)
		var qc: String = q.country
		fl.draw.connect(func(): FlagS.draw(fl, Rect2(0, 1, 38, 24), qc))
		row.add_child(fl)
		var nm := Label.new()
		var st := "盟友" if human.allies.has(q.index) else ("停火中" if (human.ceasefire.has(q.index) and game.time < float(human.ceasefire[q.index])) else ("敵對" if human.is_enemy_of(q) else "中立"))
		nm.text = "%s（%s）  好感 %d%%  [%s]" % [q.name, q.country_name(), int(q.relation(human)), st]
		nm.custom_minimum_size = Vector2(330, 0)
		nm.add_theme_color_override("font_color", q.color.lightened(0.3))
		row.add_child(nm)
		if human.proposal.has(q.index):
			var kind: String = human.proposal[q.index]
			var acc := Button.new()
			acc.text = "接受%s" % ("結盟" if kind == "ally" else "停火")
			acc.pressed.connect(func(): game.apply_treaty(human, q, kind); rebuild_diplomacy())
			row.add_child(acc)
			var rej := Button.new()
			rej.text = "拒絕"
			rej.pressed.connect(func(): human.proposal.erase(q.index); q.add_relation(human, -5.0); rebuild_diplomacy())
			row.add_child(rej)
		elif human.allies.has(q.index):
			var br := Button.new()
			br.text = "解除同盟"
			br.pressed.connect(func(): game.break_treaty(human, q); rebuild_diplomacy())
			row.add_child(br)
		else:
			var al := Button.new()
			al.text = "提議結盟"
			al.pressed.connect(func(): game.propose(human, q, "ally"); rebuild_diplomacy())
			row.add_child(al)
			var cf := Button.new()
			cf.text = "提議停火"
			cf.pressed.connect(func(): game.propose(human, q, "ceasefire"); rebuild_diplomacy())
			row.add_child(cf)
		diplo_vb.add_child(row)
	add_btn(diplo_vb, "關閉", func(): toggle_diplomacy())

var save_panel: Control
var save_vb: VBoxContainer

func toggle_saves():
	if save_panel != null and save_panel.visible:
		save_panel.visible = false
		return
	if save_panel == null:
		var pr := make_panel("存檔 / 讀檔")
		save_panel = pr[0]
		save_vb = pr[1]
	rebuild_saves()
	save_panel.visible = true

func rebuild_saves():
	for c in save_vb.get_children():
		if c == save_vb.get_child(0):
			continue
		c.queue_free()
	var SaveS = preload("res://scripts/saveload.gd")
	for n in SaveS.SLOTS:
		var info: Dictionary = SaveS.slot_info(n)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var lb := Label.new()
		lb.text = ("槽位 %d：%s\n%s" % [n + 1, info.get("title", ""), info.get("date", "")]) if not info.is_empty() else ("槽位 %d：（空）" % [n + 1])
		lb.custom_minimum_size = Vector2(300, 0)
		row.add_child(lb)
		var sb := Button.new()
		sb.text = "存檔"
		var slot: int = n
		sb.pressed.connect(func():
			if SaveS.save_game(game, slot):
				game.message("已存檔到槽位 %d" % [slot + 1])
			rebuild_saves())
		row.add_child(sb)
		var lbn := Button.new()
		lbn.text = "讀檔"
		lbn.disabled = info.is_empty()
		lbn.pressed.connect(func(): G.main.load_game(slot))
		row.add_child(lbn)
		save_vb.add_child(row)
	var tip := Label.new()
	tip.text = "F5 快速存檔（槽位 1）　F9 快速讀檔"
	tip.add_theme_font_size_override("font_size", 13)
	save_vb.add_child(tip)
	add_btn(save_vb, "關閉", func(): toggle_saves())

func toggle_pause_menu():
	if end_panel != null and end_panel.visible:
		return
	if pause_panel == null:
		var pr := make_panel("遊戲暫停")
		pause_panel = pr[0]
		var vb: VBoxContainer = pr[1]
		add_btn(vb, "繼續作戰", func(): toggle_pause_menu())
		add_btn(vb, "存檔 / 讀檔", func(): toggle_saves())
		add_btn(vb, "重新開始本局", func(): G.main.restart_game())
		add_btn(vb, "操作說明", func(): toggle_help())
		for kv in [["音樂音量", "music_vol"], ["音效音量", "sfx_vol"], ["語音音量", "voice_vol"]]:
			var row := HBoxContainer.new()
			var lb := Label.new()
			lb.text = kv[0]
			lb.custom_minimum_size = Vector2(90, 0)
			row.add_child(lb)
			var sl := HSlider.new()
			sl.min_value = 0.0
			sl.max_value = 1.0
			sl.step = 0.05
			sl.value = float(G.settings.get(kv[1], 0.8))
			sl.custom_minimum_size = Vector2(180, 24)
			var key: String = kv[1]
			sl.value_changed.connect(func(v):
				G.settings[key] = v
				Sfx.update_music_volume()
				G.save_settings())
			row.add_child(sl)
			vb.add_child(row)
		var cb := CheckBox.new()
		cb.text = "滑鼠移到邊緣捲動畫面"
		cb.button_pressed = G.settings.get("edge_scroll", true)
		cb.toggled.connect(func(v): G.settings["edge_scroll"] = v; G.save_settings())
		vb.add_child(cb)
		add_btn(vb, "返回主選單", func(): G.main.to_menu())
		add_btn(vb, "離開遊戲", func(): get_tree().quit())
		pause_panel.visible = false
	pause_panel.visible = not pause_panel.visible
	game.paused = pause_panel.visible

func show_end(win: bool, fresh: Array = []):
	if pause_panel != null:
		pause_panel.visible = false
	var pr := make_panel("任務完成！勝利！" if win else "任務失敗……")
	end_panel = pr[0]
	var vb: VBoxContainer = pr[1]
	var h = game.human
	var t: float = game.time
	var lines := [
		"作戰時間：%02d:%02d" % [int(t) / 60, int(t) % 60],
		"生產單位：%d" % h.stats.built,
		"消滅敵軍：%d" % h.stats.killed,
		"損失單位：%d   損失建築：%d" % [h.stats.lost, h.stats.bld_lost],
		"採礦收入：$%s" % G.fmt_money(h.stats.harvested),
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", 17)
		vb.add_child(lb)
	for a in fresh:
		var al := Label.new()
		al.text = "🏆 成就解鎖：%s — %s" % [a.name, a.desc]
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.add_theme_font_size_override("font_size", 17)
		al.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		vb.add_child(al)
	if not fresh.is_empty():
		Sfx.play("cash", -4.0)
	if win and game.mission != null:
		var nxt: String = G.next_mission(game.mission.id)
		if nxt != "":
			var MS = load("res://scripts/missions.gd")
			var md: Dictionary = MS.find(nxt)
			add_btn(vb, "下一關：" + md.name, func():
				var s := {"faction": md.faction, "enemy_faction": md.enemy, "enemies": int(md.get("enemies", 1)), "ai_allied": not md.get("ffa", false),
					"difficulty": game.settings.get("difficulty", 1), "map": md.map, "seed": md.seed, "money": md.money, "speed": 1.0, "mission": md.id}
				if md.has("country"):
					s["country"] = md.country
					s["enemy_country"] = md.get("enemy_country", "random")
				G.main.start_game(s))
		else:
			var lb := Label.new()
			lb.text = "★ 戰役全部完成！ ★"
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			lb.add_theme_font_size_override("font_size", 22)
			vb.add_child(lb)
	add_btn(vb, "再玩一局", func(): G.main.restart_game())
	add_btn(vb, "返回主選單", func(): G.main.to_menu())
	add_btn(vb, "離開遊戲", func(): get_tree().quit())
	Sfx.play("alarm" if not win else "cash", -2.0)

func build_help():
	var pr := make_panel("操作說明")
	help_panel = pr[0]
	var vb: VBoxContainer = pr[1]
	var txt := """【基本】
左鍵點選 / 拖曳框選單位；雙擊選取畫面上同類單位
右鍵：移動、攻擊敵人、採礦、進入建築（工程師）
選取基地車後按 D 或雙擊 → 展開成建造廠

【建造】
右側建造欄：左鍵生產，右鍵取消；建築完成後點選再放到地圖上
兵營 / 戰車工廠 / 造船廠選取後，右鍵地面可設定集結點
特殊武器按鈕在建造欄下方，充能完成後點擊再選目標
電力不足會讓生產變慢、防禦塔停擺

【快捷鍵】
A 攻擊移動　S 停止　E 選取全部戰鬥單位　Q 選取同類
N 下一台閒置採礦車　I 下一個閒置戰鬥單位　Tab 循環生產建築　B 循環全部建築（都會把鏡頭帶過去）
點小地圖跳視角，右鍵小地圖直接下達移動命令
Shift+右鍵 設定路徑點　步兵右鍵平民建築＝進駐，選取該建築按 D 撤出
Ctrl+1~9 設定編隊，1~9 選取編隊（連按兩下跳過去）
Z 出售模式　X 修理模式　Delete 出售選取建築
H / 空白鍵 回到基地　方向鍵 / 滑鼠移到邊緣 捲動畫面
滾輪縮放　中鍵拖曳 平移　+ / - 調整遊戲速度　P 暫停　F3 顯示 FPS　Esc 選單

【外交 / 情報】
T 開啟外交面板：向電腦提議結盟或停火，結盟後共享視野並獲得「盟友支援」
F5 快速存檔　F9 快速讀檔　Esc 選單內有 3 個存檔槽位
間諜右鍵敵方建築＝滲透（發電廠停電、精煉廠偷錢、雷達揭露、超武重置、科技晉升、生產癱瘓）
畫面上方會顯示敵方超級武器與特殊能力的倒數；航母會自動派出艦載機攻擊 13 格內目標"""
	var lb := Label.new()
	lb.text = txt
	lb.add_theme_font_size_override("font_size", 15)
	vb.add_child(lb)
	add_btn(vb, "關閉", func(): toggle_help())
	help_panel.visible = false

func toggle_help():
	help_panel.visible = not help_panel.visible
	move_child(help_panel, get_child_count() - 1)
