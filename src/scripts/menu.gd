extends Control
# 主選單

const MapS = preload("res://scripts/map.gd")
const FlagS = preload("res://scripts/flags.gd")

var t := 0.0
var opts := {}
var preview: TextureRect
var map_desc: Label
var seed_v := 0
var theme_res: Theme
var help: Control
var parade: Array = []
var camp: Control
var camp_sel := 0
var camp_brief: Label

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.music("menu")
	seed_v = randi()
	theme_res = make_theme()
	theme = theme_res
	build_ui()
	refresh_preview()
	bg_style = int(G.settings.get("menu_bg", -1))
	if bg_style < 0 or bg_style >= BG_NAMES.size():
		bg_style = randi() % BG_NAMES.size()
	setup_parade()

func make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = G.font
	th.default_font_size = 17
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.13, 0.92)
	sb.border_color = Color(0.55, 0.12, 0.08)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color(0.25, 0.1, 0.08, 0.95)
	sbh.border_color = Color(0.95, 0.3, 0.15)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.5, 0.1, 0.06)
	for cls in ["Button", "OptionButton"]:
		th.set_stylebox("normal", cls, sb)
		th.set_stylebox("hover", cls, sbh)
		th.set_stylebox("pressed", cls, sbp)
		th.set_stylebox("focus", cls, StyleBoxEmpty.new())
		th.set_color("font_color", cls, Color(0.93, 0.92, 0.88))
		th.set_color("font_hover_color", cls, Color(1, 1, 1))
	var pn := StyleBoxFlat.new()
	pn.bg_color = Color(0.05, 0.05, 0.06, 0.82)
	pn.border_color = Color(0.6, 0.12, 0.08)
	pn.set_border_width_all(2)
	pn.set_corner_radius_all(4)
	pn.content_margin_left = 26
	pn.content_margin_right = 26
	pn.content_margin_top = 20
	pn.content_margin_bottom = 20
	th.set_stylebox("panel", "PanelContainer", pn)
	var pm := StyleBoxFlat.new()
	pm.bg_color = Color(0.1, 0.1, 0.11, 0.98)
	pm.border_color = Color(0.6, 0.12, 0.08)
	pm.set_border_width_all(1)
	th.set_stylebox("panel", "PopupMenu", pm)
	th.set_stylebox("hover", "PopupMenu", sbh)
	th.set_font_size("font_size", "PopupMenu", 17)
	th.set_color("font_color", "Label", Color(0.9, 0.9, 0.86))
	return th

func build_ui():
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_top = 200
	root.offset_right = -60
	root.offset_bottom = -150
	root.add_theme_constant_override("separation", 40)
	add_child(root)
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(pc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 10)
	pc.add_child(grid)
	var cnames := []
	for c in Defs.COUNTRY_ORDER:
		cnames.append("%s（%s）" % [Defs.COUNTRIES[c].name, Defs.FACTIONS[Defs.COUNTRIES[c].faction].name])
	var csel := maxi(0, Defs.COUNTRY_ORDER.find(str(G.settings.get("country", "usa"))))
	add_opt(grid, "country", "我方國家", cnames, csel)
	add_opt(grid, "enemy_country", "敵方國家", ["隨機"] + cnames, 0)
	flag_ctl = Control.new()
	flag_ctl.custom_minimum_size = Vector2(72, 44)
	flag_ctl.draw.connect(func(): FlagS.draw(flag_ctl, Rect2(6, 4, 64, 40), Defs.COUNTRY_ORDER[opts.country.selected]))
	grid.add_child(flag_ctl)
	country_desc = Label.new()
	country_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	country_desc.custom_minimum_size = Vector2(260, 0)
	country_desc.add_theme_font_size_override("font_size", 13)
	country_desc.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	grid.add_child(country_desc)
	opts.country.item_selected.connect(func(_i): _update_country_desc())
	_update_country_desc()
	add_opt(grid, "enemies", "敵人數量", ["1 名對手", "2 名對手", "3 名對手"], 0)
	add_opt(grid, "ai_allied", "敵軍關係", ["敵軍互相結盟", "各自為戰(混戰)"], 0)
	add_opt(grid, "difficulty", "電腦難度", ["簡單（AI 收入 -25%，不騷擾）", "普通（會騷擾採礦車）", "困難（AI 收入 +35%，猛攻超武）"], 1)
	var names := []
	for p in MapS.PRESETS:
		names.append("%s (%dx%d)" % [p.name, p.size, p.size])
	add_opt(grid, "map", "戰場地圖", names, 0)
	add_opt(grid, "mapsize", "地圖尺寸", ["標準", "大 (×1.5)", "特大 (×2)", "超巨 (×2.5)"], int(G.settings.get("mapsize", 0)))
	opts.mapsize.item_selected.connect(func(i): G.settings["mapsize"] = i; G.save_settings(); refresh_preview())
	add_opt(grid, "money", "起始資金", ["$5,000", "$10,000", "$20,000", "$50,000"], 1)
	add_opt(grid, "speed", "遊戲速度", ["慢速", "正常", "快速"], 1)
	add_opt(grid, "crates", "隨機補給箱", ["開啟", "關閉"], 0)
	add_opt(grid, "events", "時事事件", ["開啟（制裁/駭客/軍援…）", "關閉"], 0)
	opts.map.item_selected.connect(func(_i): seed_v = randi(); refresh_preview())
	opts.enemies.item_selected.connect(func(_i): refresh_preview())
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	grid.add_child(sp)
	grid.add_child(Control.new())
	var start := Button.new()
	start.text = "開始作戰"
	start.custom_minimum_size = Vector2(0, 52)
	start.add_theme_font_override("font", G.font_bold)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start)
	grid.add_child(Control.new())
	grid.add_child(start)
	var cbtn := Button.new()
	cbtn.text = "戰役任務"
	cbtn.custom_minimum_size = Vector2(0, 46)
	cbtn.add_theme_font_override("font", G.font_bold)
	cbtn.add_theme_font_size_override("font_size", 19)
	cbtn.pressed.connect(func(): camp.visible = true)
	grid.add_child(Control.new())
	grid.add_child(cbtn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var hb := Button.new()
	hb.text = "操作說明"
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.pressed.connect(func(): help.visible = not help.visible)
	row.add_child(hb)
	var recb := Button.new()
	recb.text = "戰績"
	recb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recb.pressed.connect(func(): show_records())
	row.add_child(recb)
	var ldb := Button.new()
	ldb.text = "讀檔"
	ldb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ldb.pressed.connect(func(): show_loads())
	row.add_child(ldb)
	var ib := Button.new()
	ib.text = "片頭"
	ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.pressed.connect(func(): G.main.play_intro(true))
	row.add_child(ib)
	var bgb := Button.new()
	bgb.text = "背景"
	bgb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgb.tooltip_text = "切換選單背景"
	bgb.pressed.connect(func(): next_bg(); Sfx.play("click", -6.0))
	row.add_child(bgb)
	var qb := Button.new()
	qb.text = "離開"
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qb.pressed.connect(func(): get_tree().quit())
	row.add_child(qb)
	grid.add_child(Control.new())
	grid.add_child(row)
	# map preview
	var pv := PanelContainer.new()
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(pv)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	pv.add_child(vb)
	var lt := Label.new()
	lt.text = "戰場預覽"
	lt.add_theme_font_override("font", G.font_bold)
	lt.add_theme_font_size_override("font_size", 20)
	lt.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	vb.add_child(lt)
	# 預覽：方形小地圖旋轉 45° 再壓扁成等角菱形（用節點變換，不逐像素運算）
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(380, 200)
	holder.clip_contents = true
	vb.add_child(holder)
	var squash := Control.new()
	squash.size = Vector2(380, 400)
	squash.scale = Vector2(1, 0.5)
	holder.add_child(squash)
	preview = TextureRect.new()
	preview.size = Vector2(268, 268)
	preview.position = Vector2(190 - 134, 200 - 134)
	preview.pivot_offset = Vector2(134, 134)
	preview.rotation = PI / 4.0
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	squash.add_child(preview)
	map_desc = Label.new()
	map_desc.custom_minimum_size = Vector2(380, 0)
	map_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_desc.add_theme_font_size_override("font_size", 15)
	vb.add_child(map_desc)
	var rb := Button.new()
	rb.text = "重新產生地形"
	rb.pressed.connect(func(): seed_v = randi(); refresh_preview())
	vb.add_child(rb)
	# help panel
	help = PanelContainer.new()
	help.set_anchors_preset(Control.PRESET_CENTER)
	help.visible = false
	var hl := Label.new()
	hl.text = """《紅色風暴》玩法

1. 選取基地車，按 D（或雙擊）展開成建造廠。
2. 右側建造欄：發電廠 → 精煉廠（附採礦車）→ 兵營 → 戰車工廠。
3. 採礦車自動採集金礦（紫色寶石價值加倍）換取資金。
4. 雷達站開啟小地圖；科技中心解鎖高級單位與超級武器。
5. 用工程師佔領中立油井，可持續獲得資金；也能佔領敵方建築！
6. 摧毀所有敵方建築即可獲勝。

滑鼠：左鍵選取/框選，右鍵移動/攻擊
鍵盤：A 攻擊移動、S 停止、Ctrl+數字 編隊、Z 出售、X 修理
遊戲中按 F1 可隨時查看完整說明。

(點一下關閉)"""
	hl.add_theme_font_size_override("font_size", 17)
	help.add_child(hl)
	help.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: help.visible = false)
	add_child(help)
	help.position = Vector2(300, 180)
	build_campaign()

var flag_ctl: Control
var country_desc: Label

func _update_country_desc():
	var c: String = Defs.COUNTRY_ORDER[opts.country.selected]
	var d: Dictionary = Defs.COUNTRIES[c]
	var pw := ""
	if d.has("power"):
		pw = "\n特殊能力（需雷達/空軍指揮部）：%s" % Defs.SUPER[d.power].name
	country_desc.text = d.desc + pw
	if flag_ctl != null:
		flag_ctl.queue_redraw()

func add_opt(grid: GridContainer, key: String, label: String, items: Array, sel: int):
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	grid.add_child(l)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it)
	ob.select(sel)
	ob.custom_minimum_size = Vector2(260, 40)
	ob.get_popup().theme = theme_res
	ob.item_selected.connect(func(_i): Sfx.play("click", -6.0))
	grid.add_child(ob)
	opts[key] = ob

func sized_map() -> Dictionary:
	var p: Dictionary = MapS.PRESETS[opts.map.selected].duplicate()
	var mult: float = [1.0, 1.5, 2.0, 2.5][opts.mapsize.selected]
	if mult > 1.0:
		p["size"] = mini(400, int(round(int(p.size) * mult / 8.0)) * 8)
	return p

func refresh_preview():
	var preset: Dictionary = sized_map()
	var m = MapS.new()
	var p := preset.duplicate()
	p["players"] = 1 + opts.enemies.selected + 1
	p["seed"] = seed_v
	m.generate(p)
	var img: Image = m.make_preview(true)
	preview.texture = ImageTexture.create_from_image(img)
	var th := {"temperate": "溫帶", "desert": "沙漠", "snow": "雪地", "tropical": "熱帶"}
	map_desc.text = "%s\n%s ・ %dx%d ・ 最多 4 名玩家\n白色 = 你的出生點，紅色 = 敵人，黃/紫 = 礦區" % [preset.desc, th[preset.theme], preset.size, preset.size]
	m.free()

func _start():
	Sfx.play("click", -2.0)
	var cid: String = Defs.COUNTRY_ORDER[opts.country.selected]
	var fac: String = Defs.COUNTRIES[cid].faction
	G.settings.faction = fac
	G.settings.country = cid
	G.save_settings()
	var eci: int = opts.enemy_country.selected
	var s := {
		"faction": fac,
		"country": cid,
		"enemy_country": "random" if eci == 0 else Defs.COUNTRY_ORDER[eci - 1],
		"enemy_faction": "random" if eci == 0 else Defs.COUNTRIES[Defs.COUNTRY_ORDER[eci - 1]].faction,
		"enemies": opts.enemies.selected + 1,
		"ai_allied": opts.ai_allied.selected == 0,
		"difficulty": opts.difficulty.selected,
		"map": sized_map(),
		"seed": seed_v,
		"money": [5000, 10000, 20000, 50000][opts.money.selected],
		"speed": [0.75, 1.0, 1.35][opts.speed.selected],
		"crates": opts.crates.selected == 0,
		"events": opts.events.selected == 0,
	}
	G.main.start_game(s)

func _process(dt: float):
	t += dt
	queue_redraw()

const BG_NAMES := ["紅色指揮部", "海峽夜戰", "沙漠黎明", "數位戰場"]
var bg_style := 0

func next_bg():
	bg_style = (bg_style + 1) % BG_NAMES.size()
	G.settings["menu_bg"] = bg_style
	G.save_settings()
	parade.clear()
	setup_parade()

func setup_parade():
	var ids: Array = []
	match bg_style:
		0: ids = ["a_tank", "s_tank", "s_mammoth", "a_ifv", "s_arty", "a_beam", "s_flaktrk"]
		1: ids = ["a_destroyer", "s_sub", "a_cvn", "s_dread", "a_carrier", "s_fastboat", "a_seadrone"]
		2: ids = ["a_tank", "a_himars", "s_tos", "a_k9", "s_bmpt", "a_type10", "s_technical"]
		3: ids = ["a_ew", "s_ew", "a_harv", "s_iskander", "a_mcv", "s_hwasong", "a_hf"]
	for k in ids.size():
		parade.append({"id": ids[k], "x": k * 230.0, "col": Color(0.22, 0.52, 1.0) if ids[k].begins_with("a") else Color(0.92, 0.16, 0.12)})

func sheet_draw(key: String, frame: int, at: Vector2, col: Color, sc: float):
	var sh = G.sheet(key)
	if sh == null:
		return
	sh.draw(self, frame if sh.dirs == 0 else sh.dir_frame(TAU * frame / 32.0), at, col, Color(0.9, 0.9, 0.9), sc)

func _draw():
	var vs := get_viewport_rect().size
	match bg_style:
		1: draw_bg_strait(vs)
		2: draw_bg_desert(vs)
		3: draw_bg_cyber(vs)
		_: draw_bg_red(vs)
	draw_common(vs)

func draw_bg_red(vs: Vector2):
	# background gradient
	for i in 24:
		var c := Color(0.16, 0.03, 0.02).lerp(Color(0.02, 0.02, 0.03), i / 24.0)
		draw_rect(Rect2(0, vs.y * i / 24.0, vs.x, vs.y / 24.0 + 1), c)
	# perspective tech grid
	var hz := vs.y * 0.55
	var gcol := Color(0.9, 0.2, 0.1, 0.18)
	for k in 24:
		var f := pow(fmod(k / 24.0 + t * 0.04, 1.0), 2.2)
		var y := hz + (vs.y - hz) * f
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(gcol.r, gcol.g, gcol.b, gcol.a * f * 1.5), 1.0)
	for k in range(-20, 21):
		var x0 := vs.x * 0.5 + k * 40.0
		var x1 := vs.x * 0.5 + k * 260.0
		draw_line(Vector2(x0, hz), Vector2(x1, vs.y), gcol, 1.0)
	scanlines(vs)
	# searchlights
	for k in 3:
		var ox := vs.x * (0.2 + 0.3 * k)
		var ang := -PI * 0.5 + sin(t * 0.4 + k * 2.0) * 0.5
		var tip := Vector2(ox, vs.y) + Vector2.from_angle(ang) * vs.y * 1.3
		var sidev := Vector2.from_angle(ang).orthogonal() * 110.0
		draw_polygon(PackedVector2Array([Vector2(ox, vs.y), tip + sidev, tip - sidev]),
			PackedColorArray([Color(1, 0.95, 0.8, 0.10), Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, 0.0)]))
	# showcase
	var red := Color(0.92, 0.18, 0.12)
	var blue := Color(0.25, 0.55, 1.0)
	var base_p := Vector2(vs.x * 0.74, vs.y * 0.52)
	var items := [["s_cy", 2, Vector2(0, 0), red, 1.5], ["s_tcoil", 0, Vector2(-190, 90), red, 1.5], ["s_power", 0, Vector2(210, -40), red, 1.5],
		["s_mammoth", 26, Vector2(-40, 190), red, 1.7], ["s_mammoth_t", 26, Vector2(-40, 190), red, 1.7],
		["s_tos", 18, Vector2(160, 170), red, 1.6], ["s_tos_t", 18, Vector2(160, 170), red, 1.6],
		["a_tb2", 5, Vector2(-260, -120), blue, 1.6]]
	for it in items:
		var off: Vector2 = it[2]
		if it[0] == "a_tb2":
			off += Vector2(sin(t * 0.6) * 40.0, cos(t * 0.8) * 10.0)
		sheet_draw(it[0], it[1], base_p + off, it[3], it[4])
	ground_parade(vs, Color(0.05, 0.04, 0.03, 0.9))

func scanlines(vs: Vector2):
	var sy := 0.0
	while sy < vs.y:
		draw_line(Vector2(0, sy), Vector2(vs.x, sy), Color(0, 0, 0, 0.12), 1.0)
		sy += 4.0

func ground_parade(vs: Vector2, ground_c: Color, water := false):
	draw_rect(Rect2(0, vs.y - 120, vs.x, 120), ground_c)
	for p in parade:
		var x: float = fmod(p.x + t * 40.0, 7 * 230.0) - 150.0
		var y := vs.y - 50.0
		if water:
			y += sin(t * 1.5 + x * 0.01) * 3.0
		var sh = G.sheet(p.id)
		if sh != null:
			sh.draw(self, sh.dir_frame(0.0), Vector2(x, y), p.col, Color(0.85, 0.85, 0.85), 2.2)
			var ts = G.sheet(p.id + "_t")
			if ts != null:
				ts.draw(self, ts.dir_frame(0.0), Vector2(x, y), p.col, Color(0.85, 0.85, 0.85), 2.2)

func draw_bg_strait(vs: Vector2):
	# 夜空 → 海面
	for i in 24:
		var c := Color(0.01, 0.02, 0.06).lerp(Color(0.03, 0.08, 0.16), i / 24.0)
		draw_rect(Rect2(0, vs.y * i / 24.0, vs.x, vs.y / 24.0 + 1), c)
	# 星星
	for k in 90:
		var sx := fmod(k * 173.7, vs.x)
		var sy := fmod(k * 97.3, vs.y * 0.5)
		var a := 0.4 + 0.6 * absf(sin(t * 1.3 + k))
		draw_circle(Vector2(sx, sy), 1.2, Color(0.9, 0.95, 1.0, a * 0.8))
	# 月亮
	var mc := Vector2(vs.x - 420, 150)
	draw_circle(mc, 46, Color(0.95, 0.95, 0.85, 0.95))
	draw_circle(mc + Vector2(-14, -6), 9, Color(0.8, 0.8, 0.72, 0.6))
	draw_circle(mc + Vector2(16, 14), 6, Color(0.8, 0.8, 0.72, 0.6))
	# 海面
	var hz := vs.y * 0.56
	draw_rect(Rect2(0, hz, vs.x, vs.y - hz), Color(0.03, 0.09, 0.18))
	for k in 60:
		var f := pow(k / 60.0, 1.6)
		var y := hz + (vs.y - hz) * f
		var ph := sin(t * 1.2 + k * 0.7)
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0.3, 0.6, 0.9, 0.05 + 0.08 * f * (0.5 + 0.5 * ph)), 1.0 + f * 2.0)
	# 月光倒影
	for k in 30:
		var y := hz + k * 12.0
		var w := 40.0 + k * 5.0 + sin(t * 2.0 + k) * 15.0
		draw_rect(Rect2(mc.x - w * 0.5, y, w, 3), Color(1, 1, 0.85, 0.08 + 0.04 * sin(t * 3.0 + k * 0.5)))
	# 遠處島嶼剪影
	var pts := PackedVector2Array([Vector2(vs.x * 0.55, hz)])
	for k in 20:
		var x := vs.x * 0.55 + k * (vs.x * 0.45 / 19.0)
		pts.append(Vector2(x, hz - 20 - 60 * absf(sin(k * 0.9)) - 30 * absf(sin(k * 2.3))))
	pts.append(Vector2(vs.x, hz))
	draw_colored_polygon(pts, Color(0.02, 0.04, 0.08))
	# 艦隊展示
	var blue := Color(0.25, 0.55, 1.0)
	var red := Color(0.92, 0.18, 0.12)
	var base_p := Vector2(vs.x * 0.74, vs.y * 0.62)
	sheet_draw("a_cvn", 4, base_p + Vector2(0, sin(t * 1.1) * 3.0), blue, 1.7)
	sheet_draw("a_destroyer", 6, base_p + Vector2(-230, 70 + sin(t * 1.4) * 3.0), blue, 1.6)
	sheet_draw("a_destroyer_t", 6, base_p + Vector2(-230, 70 + sin(t * 1.4) * 3.0), blue, 1.6)
	sheet_draw("s_dread", 20, base_p + Vector2(230, -90 + sin(t * 0.9) * 3.0), red, 1.6)
	sheet_draw("s_sub", 20, base_p + Vector2(120, 130 + sin(t * 1.7) * 3.0), red, 1.5)
	var jx := fmod(t * 120.0, vs.x + 400.0) - 200.0
	sheet_draw("a_hornet", 8, Vector2(jx, 240 + sin(t * 2.0) * 10.0), blue, 1.4)
	sheet_draw("a_hornet", 8, Vector2(jx - 90, 275 + sin(t * 2.0 + 1.0) * 10.0), blue, 1.4)
	# 雷達掃描
	var rc := Vector2(vs.x * 0.74, vs.y * 0.40)
	for k in 3:
		draw_arc(rc, 70 + k * 45, 0, TAU, 48, Color(0.3, 0.9, 0.6, 0.12), 1.0)
	var ra := t * 1.5
	draw_line(rc, rc + Vector2.from_angle(ra) * 160.0, Color(0.3, 1.0, 0.6, 0.5), 2.0)
	draw_polygon(PackedVector2Array([rc, rc + Vector2.from_angle(ra) * 160.0, rc + Vector2.from_angle(ra - 0.5) * 160.0]),
		PackedColorArray([Color(0.3, 1.0, 0.6, 0.25), Color(0.3, 1.0, 0.6, 0.0), Color(0.3, 1.0, 0.6, 0.0)]))
	ground_parade(vs, Color(0.02, 0.06, 0.12, 0.9), true)

func draw_bg_desert(vs: Vector2):
	for i in 24:
		var c := Color(0.55, 0.22, 0.08).lerp(Color(0.95, 0.65, 0.3), i / 24.0)
		draw_rect(Rect2(0, vs.y * i / 24.0, vs.x, vs.y / 24.0 + 1), c)
	# 太陽
	var sc := Vector2(vs.x * 0.62, vs.y * 0.40)
	for k in 6:
		draw_circle(sc, 60 + k * 30, Color(1, 0.85, 0.5, 0.06))
	draw_circle(sc, 58, Color(1, 0.93, 0.7, 0.95))
	# 沙丘層
	var dune_cols := [Color(0.82, 0.55, 0.25), Color(0.7, 0.42, 0.18), Color(0.55, 0.3, 0.12), Color(0.4, 0.22, 0.1)]
	for d in 4:
		var base_y := vs.y * (0.42 + d * 0.12)
		var pts := PackedVector2Array([Vector2(0, vs.y)])
		for k in 41:
			var x := vs.x * k / 40.0
			var y := base_y + sin(x * 0.004 + d * 1.7 + t * 0.05) * 40.0 + sin(x * 0.011 + d) * 18.0
			pts.append(Vector2(x, y))
		pts.append(Vector2(vs.x, vs.y))
		draw_colored_polygon(pts, dune_cols[d])
	# 熱浪 / 沙塵
	for k in 40:
		var x := fmod(k * 131.0 + t * (20.0 + k % 5 * 8.0), vs.x)
		var y := vs.y * 0.5 + fmod(k * 77.0, vs.y * 0.4)
		draw_circle(Vector2(x, y), 2.0 + k % 3, Color(1, 0.9, 0.7, 0.12))
	# 展示：盟軍裝甲與空中支援
	var blue := Color(0.25, 0.55, 1.0)
	var red := Color(0.92, 0.18, 0.12)
	var base_p := Vector2(vs.x * 0.74, vs.y * 0.58)
	sheet_draw("a_tank", 22, base_p + Vector2(-40, 120), blue, 1.8)
	sheet_draw("a_tank_t", 22, base_p + Vector2(-40, 120), blue, 1.8)
	sheet_draw("a_himars", 24, base_p + Vector2(160, 60), blue, 1.7)
	sheet_draw("a_himars_t", 24, base_p + Vector2(160, 60), blue, 1.7)
	sheet_draw("s_tos", 10, base_p + Vector2(-260, 10), red, 1.6)
	sheet_draw("s_tos_t", 10, base_p + Vector2(-260, 10), red, 1.6)
	sheet_draw("a_apache", 6, base_p + Vector2(60 + sin(t * 0.7) * 50.0, -170 + cos(t * 0.9) * 12.0), blue, 1.6)
	sheet_draw("oil", 0, base_p + Vector2(300, -60), Color.WHITE, 1.5)
	ground_parade(vs, Color(0.3, 0.18, 0.08, 0.92))

func draw_bg_cyber(vs: Vector2):
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.01, 0.02, 0.03))
	# 數位雨
	for k in 60:
		var x := k * (vs.x / 60.0) + 8.0
		var sp := 60.0 + (k * 37) % 90
		var y := fmod(t * sp + k * 211.0, vs.y + 200.0) - 100.0
		for j in 12:
			var ch := char(0x30A0 + (k * 7 + j * 13 + int(t * 6.0)) % 90) if (k + j) % 3 != 0 else str((k * j + int(t * 4.0)) % 10)
			var a := (1.0 - j / 12.0) * 0.6
			draw_string(G.font_bold, Vector2(x, y - j * 18.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 1.0, 0.5, a) if j > 0 else Color(0.8, 1.0, 0.9, 0.9))
	# 六角網格地面
	var hz := vs.y * 0.52
	var gcol := Color(0.1, 0.8, 0.9, 0.16)
	for k in 20:
		var f := pow(fmod(k / 20.0 + t * 0.05, 1.0), 2.0)
		var y := hz + (vs.y - hz) * f
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(gcol.r, gcol.g, gcol.b, gcol.a * f * 1.6), 1.0)
	for k in range(-16, 17):
		draw_line(Vector2(vs.x * 0.5 + k * 50.0, hz), Vector2(vs.x * 0.5 + k * 300.0, vs.y), gcol, 1.0)
	# 金融曲線
	var pts := PackedVector2Array()
	for k in 80:
		var x := vs.x * 0.42 + k * (vs.x * 0.56 / 79.0)
		var v := sin(k * 0.3 + t * 0.8) * 30.0 + sin(k * 0.9 - t * 1.3) * 14.0 + k * 1.2
		pts.append(Vector2(x, vs.y * 0.36 - v))
	draw_polyline(pts, Color(1.0, 0.75, 0.2, 0.8), 2.0)
	draw_string(G.font_bold, Vector2(vs.x * 0.62, vs.y * 0.30), "GLOBAL MARKETS  ▲ %.2f%%   RESERVES FROZEN   SANCTIONS ACTIVE" % (3.0 + sin(t) * 2.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.75, 0.2, 0.7))
	# 無人機蜂群與電戰車
	var blue := Color(0.25, 0.55, 1.0)
	var red := Color(0.92, 0.18, 0.12)
	var base_p := Vector2(vs.x * 0.74, vs.y * 0.6)
	sheet_draw("a_dronehub", 0, base_p + Vector2(0, 40), blue, 1.5)
	sheet_draw("a_ew", 20, base_p + Vector2(-220, 110), blue, 1.7)
	sheet_draw("s_ew", 12, base_p + Vector2(230, 120), red, 1.7)
	for k in 6:
		var ang := t * 0.7 + k * TAU / 6.0
		var p := base_p + Vector2(cos(ang) * 230.0, -150.0 + sin(ang) * 60.0)
		sheet_draw("a_fpv" if k % 2 == 0 else "s_shahed", int(fmod(ang / TAU * 32.0 + 8.0, 32.0)), p, blue if k % 2 == 0 else red, 1.3)
	sheet_draw("a_tb2", 5, base_p + Vector2(sin(t * 0.5) * 80.0, -260), blue, 1.6)
	scanlines(vs)
	ground_parade(vs, Color(0.02, 0.05, 0.06, 0.92))

func draw_common(vs: Vector2):
	# title
	var title := "紅色風暴"
	var tx := 60.0
	var ty := 118.0
	for k in 3:
		draw_string(G.font_bold, Vector2(tx + 4 - k, ty + 4 - k), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(0, 0, 0, 0.5))
	draw_string(G.font_bold, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color(0.95, 0.18, 0.1))
	draw_string(G.font_bold, Vector2(tx + 4, ty + 42), "R E D   S T O R M  ·  即時戰略", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.5, 0.85))
	# star emblem
	var c := Vector2(vs.x - 140, 110)
	var pts := PackedVector2Array()
	for i in 10:
		var r := 70.0 if i % 2 == 0 else 28.0
		pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 5.0 + sin(t * 0.3) * 0.05) * r)
	draw_colored_polygon(pts, Color(0.85, 0.12, 0.08, 0.85))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 0.8, 0.3, 0.8), 2.0)
	draw_string(G.font, Vector2(vs.x - 360, vs.y - 12), "v%s  ·  同人即時戰略遊戲（原創素材）" % G.VERSION, HORIZONTAL_ALIGNMENT_RIGHT, 340, 12, Color(0.6, 0.6, 0.6))

var load_panel: PanelContainer

var rec_panel: PanelContainer

func show_records():
	if rec_panel != null:
		rec_panel.queue_free()
		rec_panel = null
		return
	var RecS = preload("res://scripts/records.gd")
	var r: Dictionary = RecS.get_rec()
	rec_panel = PanelContainer.new()
	rec_panel.position = Vector2(380, 120)
	rec_panel.custom_minimum_size = Vector2(1160, 640)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.06, 0.98)
	sb.border_color = Color(0.75, 0.12, 0.08)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	rec_panel.add_theme_stylebox_override("panel", sb)
	add_child(rec_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	rec_panel.add_child(hb)
	# 左：統計
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(400, 0)
	hb.add_child(left)
	var title := Label.new()
	title.text = "戰績統計"
	title.add_theme_font_override("font", G.font_bold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	left.add_child(title)
	var MS = preload("res://scripts/missions.gd")
	var mdone := 0
	for m in MS.LIST:
		if G.mission_done(m.id):
			mdone += 1
	var rows := [
		["出戰場次", "%d（勝 %d / 敗 %d）" % [int(r.games), int(r.wins), int(r.losses)]],
		["勝率", RecS.win_rate()],
		["目前連勝 / 最佳連勝", "%d / %d" % [int(r.streak), int(r.best_streak)]],
		["最快勝利", RecS.fmt_time(float(r.best_win)) if float(r.best_win) > 0.0 else "—"],
		["總作戰時間", RecS.fmt_time(float(r.play_time))],
		["戰役任務完成", "%d / %d" % [mdone, MS.LIST.size()]],
		["生產單位", G.fmt_money(int(r.built))],
		["消滅敵軍", G.fmt_money(int(r.killed))],
		["單場最多擊殺", str(int(r.max_kills))],
		["損失單位 / 建築", "%s / %s" % [G.fmt_money(int(r.lost)), G.fmt_money(int(r.bld_lost))]],
		["採礦總收入", "$" + G.fmt_money(float(r.harvested))],
		["特殊武器發射", str(int(r.powers))],
		["間諜滲透成功", str(int(r.spies))],
		["締結條約", str(int(r.treaties))],
		["航母 / 無人機生產", "%d / %d" % [int(r.carriers), int(r.drones)]],
		["使用過的國家", str(RecS.list_count("countries"))],
		["作戰過的地圖", str(RecS.list_count("maps"))],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)
	for rw in rows:
		var a := Label.new()
		a.text = rw[0]
		a.add_theme_font_size_override("font_size", 16)
		a.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
		grid.add_child(a)
		var b := Label.new()
		b.text = rw[1]
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
		grid.add_child(b)
	var close := Button.new()
	close.text = "返回"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(func(): rec_panel.queue_free(); rec_panel = null)
	left.add_child(close)
	# 右：成就
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	hb.add_child(right)
	var n_un := 0
	for a in RecS.ACH:
		if RecS.has_ach(a.id):
			n_un += 1
	var t2 := Label.new()
	t2.text = "成就  %d / %d" % [n_un, RecS.ACH.size()]
	t2.add_theme_font_override("font", G.font_bold)
	t2.add_theme_font_size_override("font_size", 26)
	t2.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	right.add_child(t2)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(660, 520)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var ag := GridContainer.new()
	ag.columns = 2
	ag.add_theme_constant_override("h_separation", 12)
	ag.add_theme_constant_override("v_separation", 8)
	sc.add_child(ag)
	for a in RecS.ACH:
		var un: bool = RecS.has_ach(a.id)
		var pc := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.25, 0.18, 0.05, 0.9) if un else Color(0.1, 0.1, 0.12, 0.9)
		ps.border_color = Color(1, 0.75, 0.2) if un else Color(0.3, 0.3, 0.32)
		ps.set_border_width_all(1)
		ps.set_content_margin_all(8)
		pc.add_theme_stylebox_override("panel", ps)
		pc.custom_minimum_size = Vector2(318, 58)
		ag.add_child(pc)
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 10)
		pc.add_child(rh)
		var ic := Label.new()
		ic.text = a.icon if un else "🔒"
		ic.custom_minimum_size = Vector2(34, 0)
		ic.add_theme_font_size_override("font_size", 26)
		ic.add_theme_color_override("font_color", Color(1, 0.8, 0.25) if un else Color(0.5, 0.5, 0.5))
		rh.add_child(ic)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		rh.add_child(vb)
		var nl := Label.new()
		nl.text = a.name
		nl.add_theme_font_override("font", G.font_bold)
		nl.add_theme_font_size_override("font_size", 16)
		nl.add_theme_color_override("font_color", Color(1, 0.95, 0.8) if un else Color(0.6, 0.6, 0.6))
		vb.add_child(nl)
		var dl := Label.new()
		dl.text = a.desc
		dl.add_theme_font_size_override("font_size", 13)
		dl.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7) if un else Color(0.5, 0.5, 0.5))
		vb.add_child(dl)

func show_loads():
	if load_panel != null:
		load_panel.queue_free()
	var SaveS = preload("res://scripts/saveload.gd")
	load_panel = PanelContainer.new()
	load_panel.position = Vector2(520, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.06, 0.98)
	sb.border_color = Color(0.75, 0.12, 0.08)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	load_panel.add_theme_stylebox_override("panel", sb)
	add_child(load_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	load_panel.add_child(vb)
	var t := Label.new()
	t.text = "讀取存檔"
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	vb.add_child(t)
	for n in SaveS.SLOTS:
		var info: Dictionary = SaveS.slot_info(n)
		var b := Button.new()
		b.text = ("槽位 %d：%s（%s）" % [n + 1, info.get("title", ""), info.get("date", "")]) if not info.is_empty() else ("槽位 %d：（空）" % [n + 1])
		b.disabled = info.is_empty()
		b.custom_minimum_size = Vector2(520, 44)
		var slot: int = n
		b.pressed.connect(func(): G.main.load_game(slot))
		vb.add_child(b)
	var cl := Button.new()
	cl.text = "返回"
	cl.pressed.connect(func(): load_panel.queue_free(); load_panel = null)
	vb.add_child(cl)

func build_campaign():
	var MS = preload("res://scripts/missions.gd")
	camp = PanelContainer.new()
	camp.visible = false
	camp.position = Vector2(420, 150)
	camp.custom_minimum_size = Vector2(900, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.06, 0.98)
	sb.border_color = Color(0.75, 0.12, 0.08)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	camp.add_theme_stylebox_override("panel", sb)
	add_child(camp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	camp.add_child(hb)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	hb.add_child(left)
	var title := Label.new()
	title.text = "戰役任務"
	title.add_theme_font_override("font", G.font_bold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	left.add_child(title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 430)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	sc.add_child(lv)
	var last_camp := ""
	for i in MS.LIST.size():
		var cp: String = MS.LIST[i].get("camp", "basic")
		if cp != last_camp:
			last_camp = cp
			var hl := Label.new()
			hl.text = "— 混合戰爭戰役 —" if cp == "hybrid" else "— 基礎戰役 —"
			hl.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
			lv.add_child(hl)
		var b := Button.new()
		var mid: String = MS.LIST[i].id
		var unlocked: bool = G.mission_unlocked(mid)
		b.text = ("✓ " if G.mission_done(mid) else ("🔒 " if not unlocked else "")) + MS.LIST[i].name
		b.disabled = not unlocked
		b.custom_minimum_size = Vector2(300, 38)
		var idx: int = i
		b.pressed.connect(func():
			camp_sel = idx
			Sfx.play("click", -6.0)
			var md: Dictionary = MS.LIST[idx]
			camp_brief.text = (("RSN BREAKING: " + md.headline + "\n\n") if md.has("headline") else "") + md.brief)
		lv.add_child(b)
	var close := Button.new()
	close.text = "返回"
	close.pressed.connect(func(): camp.visible = false)
	left.add_child(close)
	var unl := CheckBox.new()
	unl.text = "解鎖全部關卡"
	unl.button_pressed = G.settings.get("unlock_all", false)
	unl.toggled.connect(func(v): G.settings["unlock_all"] = v; G.save_settings(); camp.queue_free(); build_campaign(); camp.visible = true)
	left.add_child(unl)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	hb.add_child(right)
	camp_brief = Label.new()
	camp_brief.text = MS.LIST[0].brief
	camp_brief.custom_minimum_size = Vector2(520, 360)
	camp_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	camp_brief.add_theme_font_size_override("font_size", 18)
	right.add_child(camp_brief)
	var go := Button.new()
	go.text = "開始任務"
	go.custom_minimum_size = Vector2(0, 52)
	go.add_theme_font_override("font", G.font_bold)
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(func():
		var md: Dictionary = MS.LIST[camp_sel]
		var s := {"faction": md.faction, "enemy_faction": md.enemy, "enemies": int(md.get("enemies", 1)), "ai_allied": not md.get("ffa", false),
			"difficulty": opts.difficulty.selected, "map": md.map, "seed": md.seed, "money": md.money, "speed": 1.0, "mission": md.id}
		if md.has("country"):
			s["country"] = md.country
			s["enemy_country"] = md.get("enemy_country", "random")
		G.main.start_game(s))
	right.add_child(go)
