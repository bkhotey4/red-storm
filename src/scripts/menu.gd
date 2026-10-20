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
var menu_vsp: VideoStreamPlayer = null

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Sfx.music("menu")
	seed_v = randi()
	theme_res = make_theme()
	theme = theme_res
	build_ui()
	refresh_preview()
	bg_style = int(G.settings.get("menu_bg", 0))
	if bg_style < 0 or bg_style >= BG_NAMES.size():
		bg_style = 0
	setup_parade()
	_setup_menu_video()

func _setup_menu_video():
	var vpath := "res://video/redstorm_menu_warfare.ogv"
	if not FileAccess.file_exists(vpath):
		vpath = "res://video/redstorm_promo_trailer.ogv"
	if not FileAccess.file_exists(vpath):
		return
	var vst := VideoStreamTheora.new()
	vst.file = vpath
	menu_vsp = VideoStreamPlayer.new()
	menu_vsp.stream = vst
	menu_vsp.volume_db = -80.0
	menu_vsp.self_modulate = Color(1, 1, 1, 0)
	add_child(menu_vsp)
	menu_vsp.finished.connect(func():
		if is_instance_valid(menu_vsp):
			menu_vsp.play())
	menu_vsp.play()

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
	root.offset_top = 175
	root.offset_right = -60
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 40)
	add_child(root)
	# 左側設定面板：視窗太矮時可捲動
	var lscroll := ScrollContainer.new()
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(lscroll)
	var pc := PanelContainer.new()
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	lscroll.add_child(pc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 7)
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
	add_opt(grid, "mode", "遊戲模式", ["殲滅戰（摧毀所有敵方建築）", "生存模式（抵擋 25 波敵軍）", "據點爭奪（佔領中央指揮所）"], 0)
	add_opt(grid, "enemies", "敵人數量", ["1 名對手", "2 名對手", "3 名對手"], 0)
	add_opt(grid, "ai_allied", "敵軍關係", ["敵軍互相結盟", "各自為戰(混戰)"], 0)
	add_opt(grid, "difficulty", "電腦難度", ["簡單（AI 收入 -25%，不騷擾）", "普通（會騷擾採礦車）", "困難（AI 收入 +35%，猛攻超武）", "殘酷（AI 收入 +75%，頻繁大軍壓境）"], 1)
	var names := []
	for p in MapS.PRESETS:
		names.append("%s (%dx%d)" % [p.name, p.size, p.size])
	add_opt(grid, "map", "戰場地圖", names, 0)
	add_opt(grid, "mapsize", "地圖尺寸", ["標準", "大 (×1.5)", "特大 (×2)", "超巨 (×2.5)"], int(G.settings.get("mapsize", 0)))
	opts.mapsize.item_selected.connect(func(i): G.settings["mapsize"] = i; G.save_settings(); refresh_preview())
	add_opt(grid, "money", "起始資金", ["$5,000", "$10,000", "$20,000", "$50,000"], 1)
	add_opt(grid, "speed", "遊戲速度", ["慢速", "正常", "快速"], 1)
	opts.map.item_selected.connect(func(_i): seed_v = randi(); refresh_preview())
	opts.enemies.item_selected.connect(func(_i): refresh_preview())
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	grid.add_child(sp)
	grid.add_child(Control.new())
	var start := Button.new()
	start.text = "開始作戰"
	start.custom_minimum_size = Vector2(0, 48)
	start.add_theme_font_override("font", G.font_bold)
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(_start)
	grid.add_child(Control.new())
	grid.add_child(start)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	var cbtn := Button.new()
	cbtn.text = "戰役任務"
	cbtn.custom_minimum_size = Vector2(0, 42)
	cbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cbtn.add_theme_font_override("font", G.font_bold)
	cbtn.add_theme_font_size_override("font_size", 19)
	cbtn.pressed.connect(func(): camp.visible = true)
	crow.add_child(cbtn)
	var dbtn := Button.new()
	dbtn.text = "每日挑戰"
	dbtn.custom_minimum_size = Vector2(0, 42)
	dbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dbtn.add_theme_font_override("font", G.font_bold)
	dbtn.add_theme_font_size_override("font_size", 19)
	dbtn.pressed.connect(func(): show_daily())
	crow.add_child(dbtn)
	grid.add_child(Control.new())
	grid.add_child(crow)
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
	ib.tooltip_text = "播放 5 分鐘真實新聞結合開場影片"
	ib.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ib.pressed.connect(func(): G.main.play_intro(true, "5min"))
	row.add_child(ib)
	var pb := Button.new()
	pb.text = "宣傳片"
	pb.tooltip_text = "播放 2.5 分鐘熱血宣傳影片"
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.pressed.connect(func(): G.main.play_promo())
	# 網頁版不含影片檔（檔案太大），不顯示宣傳片按鈕
	if not OS.has_feature("web"):
		row.add_child(pb)
	var bgb := Button.new()
	bgb.text = "背景"
	bgb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bgb.tooltip_text = "切換選單背景（目前：熱血現代戰爭）"
	bgb.pressed.connect(func(): next_bg(); Sfx.play("click", -6.0))
	row.add_child(bgb)
	var qb := Button.new()
	qb.text = "離開"
	qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qb.pressed.connect(func(): G.main.quit_game())
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
	# 戰場選項與規則修改器（勾選框）
	var op := PanelContainer.new()
	op.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ovb := VBoxContainer.new()
	ovb.add_theme_constant_override("separation", 4)
	op.add_child(ovb)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 14)
	root.remove_child(pv)
	rv.add_child(pv)
	rv.add_child(op)
	root.add_child(rv)
	var ot := Label.new()
	ot.text = "戰場選項"
	ot.add_theme_font_override("font", G.font_bold)
	ot.add_theme_font_size_override("font_size", 18)
	ot.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	ovb.add_child(ot)
	var og := GridContainer.new()
	og.columns = 2
	og.add_theme_constant_override("h_separation", 18)
	ovb.add_child(og)
	add_check(og, "crates", "隨機補給箱", true, "地圖上隨機出現補給箱")
	add_check(og, "events", "時事事件", true, "制裁、駭客、軍援等隨機事件")
	add_check(og, "weather", "動態天氣", true, "雨、霧、雪、沙塵暴影響射程與速度")
	add_check(og, "contracts", "戰場委託", true, "限時支線任務，完成領賞金")
	var mt := Label.new()
	mt.text = "規則修改器（所有玩家適用）"
	mt.add_theme_font_override("font", G.font_bold)
	mt.add_theme_font_size_override("font_size", 16)
	mt.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	ovb.add_child(mt)
	var mg := GridContainer.new()
	mg.columns = 2
	mg.add_theme_constant_override("h_separation", 18)
	ovb.add_child(mg)
	for k in MUTATORS:
		add_check(mg, "mut_" + k, MUTATORS[k].name, false, MUTATORS[k].desc)
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

滑鼠：左鍵選取/框選，右鍵移動/攻擊，按住右鍵拖曳＝移動畫面
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

const MUTATORS := {
	"fastbuild": {"name": "快速建造", "desc": "所有建造與生產速度 ×2"},
	"rich": {"name": "富礦", "desc": "採礦收入 ×1.5"},
	"superfast": {"name": "核戰時代", "desc": "超級武器與特殊能力充能 ×2"},
	"glass": {"name": "玻璃大砲", "desc": "所有傷害 ×1.6，戰鬥極快結束"},
	"veteran": {"name": "老兵部隊", "desc": "所有新單位直接是老兵"},
	"infantry": {"name": "步兵戰爭", "desc": "不能生產載具、飛機與艦艇（採礦車除外）"},
	"nosuper": {"name": "禁用超級武器", "desc": "不能建造核彈井與氣象控制器"},
	"turbo": {"name": "閃電戰", "desc": "所有單位移動速度 ×1.4"},
}
var checks := {}

func add_check(grid: GridContainer, key: String, label: String, on: bool, tip: String):
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = on
	cb.tooltip_text = tip
	cb.add_theme_font_size_override("font_size", 15)
	cb.toggled.connect(func(_v): Sfx.play("click", -6.0))
	grid.add_child(cb)
	checks[key] = cb

func selected_muts() -> Array:
	var out := []
	for k in MUTATORS:
		if checks.has("mut_" + k) and checks["mut_" + k].button_pressed:
			out.append(k)
	return out

func add_opt(grid: GridContainer, key: String, label: String, items: Array, sel: int):
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	grid.add_child(l)
	var ob := OptionButton.new()
	for it in items:
		ob.add_item(it)
	ob.select(sel)
	ob.custom_minimum_size = Vector2(260, 34)
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
	p["shuffle"] = true
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
		"crates": checks.crates.button_pressed,
		"events": checks.events.button_pressed,
		"mode": ["std", "survival", "koth"][opts.mode.selected],
		"contracts": checks.contracts.button_pressed,
		"weather": checks.weather.button_pressed,
		"muts": selected_muts(),
	}
	G.main.start_game(s)

func _process(dt: float):
	t += dt
	queue_redraw()

const BG_NAMES := ["熱血現代戰爭", "紅色指揮部", "海峽夜戰", "沙漠黎明", "數位戰場"]
const MODERN_BG_TEX := ["bg_modern_battle", "bg_carrier_battle", "bg_fpv_strike", "bg_night_airdef", "bg_coastal_salvo", "bg_finance_city"]
const MODERN_CAPTIONS := [
	"COMBINED ARMS ASSAULT  •  MBT ARMOR & HIMARS ROCKET ARTILLERY SALVO",
	"CARRIER STRIKE GROUP  •  AEGIS SM-6 INTERCEPT & F-35C LAUNCH",
	"EASTERN FRONT UAV SWARM  •  FPV LOITERING MUNITION STRIKE",
	"URBAN AIR DEFENSE  •  GEPARD FLAK & PATRIOT PAC-3 INTERCEPT",
	"STRAIT BLOCKADE  •  COASTAL ANTI-SHIP MISSILE SATURATION",
	"FINANCIAL WARFARE  •  SWIFT BLACKOUT & SOVEREIGN RESERVE FREEZE"
]
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
		0: ids = ["a_tank", "a_himars", "s_mammoth", "s_tos", "a_k9", "s_bmpt", "a_type10"]
		1: ids = ["a_tank", "s_tank", "s_mammoth", "a_ifv", "s_arty", "a_beam", "s_flaktrk"]
		2: ids = ["a_destroyer", "s_sub", "a_cvn", "s_dread", "a_carrier", "s_fastboat", "a_seadrone"]
		3: ids = ["a_tank", "a_himars", "s_tos", "a_k9", "s_bmpt", "a_type10", "s_technical"]
		4: ids = ["a_ew", "s_ew", "a_harv", "s_iskander", "a_mcv", "s_hwasong", "a_hf"]
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
		0: draw_bg_modern_warfare(vs)
		1: draw_bg_red(vs)
		2: draw_bg_strait(vs)
		3: draw_bg_desert(vs)
		4: draw_bg_cyber(vs)
		_: draw_bg_modern_warfare(vs)
	draw_common(vs)

func _draw_ken_burns_tex(tex: Texture2D, vs: Vector2, phase: float, alpha: float, dir_sign: float):
	if tex == null or alpha <= 0.001:
		return
	var zoom := 1.04 + 0.10 * phase
	var w := vs.x * zoom
	var h := vs.y * zoom
	var ox := (vs.x - w) * 0.5 + dir_sign * (phase - 0.5) * 42.0
	var oy := (vs.y - h) * 0.5 - phase * 18.0
	draw_texture_rect(tex, Rect2(ox, oy, w, h), false, Color(1, 1, 1, alpha))

func draw_bg_modern_warfare(vs: Vector2):
	draw_rect(Rect2(0, 0, vs.x, vs.y), Color(0.03, 0.02, 0.02))
	# 1. 高解析寫實場景基底 + 全動態現代戰爭實拍與實機混剪背景影片 (VideoStreamPlayer)
	var cycle_dur := 7.5
	var total_slides := MODERN_BG_TEX.size()
	var idx := int(t / cycle_dur) % total_slides
	var nxt := (idx + 1) % total_slides
	var p := fmod(t, cycle_dur) / cycle_dur
	var fade_w := 0.20
	var tex_cur := G.tex(MODERN_BG_TEX[idx])
	var tex_nxt := G.tex(MODERN_BG_TEX[nxt])
	_draw_ken_burns_tex(tex_cur, vs, p, 1.0, 1.0 if idx % 2 == 0 else -1.0)
	if p > (1.0 - fade_w):
		var fa := (p - (1.0 - fade_w)) / fade_w
		_draw_ken_burns_tex(tex_nxt, vs, fa * 0.2, fa, 1.0 if nxt % 2 == 0 else -1.0)
	if menu_vsp != null and menu_vsp.is_playing():
		var vtex := menu_vsp.get_video_texture()
		if vtex != null and vtex.get_width() > 16:
			draw_texture_rect(vtex, Rect2(0, 0, vs.x, vs.y), false, Color(1, 1, 1, 0.92))
	# 戰場熱血暗角與面板區對比度強化漸層
	for i in 12:
		var ratio := i / 12.0
		var c := Color(0.04, 0.015, 0.01, 0.36 * (1.0 - ratio) + 0.12)
		draw_rect(Rect2(0, vs.y * ratio, vs.x, vs.y / 12.0 + 2), c)
	var glow := G.tex("fx_glow")
	if glow != null:
		draw_texture_rect(glow, Rect2(vs.x * 0.55, vs.y * 0.15, vs.x * 0.45, vs.y * 0.55), false, Color(1.0, 0.38, 0.12, 0.14 + 0.06 * sin(t * 2.2)))
	# 戰場細緻火星粒子 (Subtle Battlefield Embers)
	for k in 32:
		var ex := fmod(k * 149.0 + t * (45.0 + (k % 5) * 14.0), vs.x)
		var ey := vs.y - fmod(k * 83.0 + t * (32.0 + (k % 4) * 12.0), vs.y * 0.75)
		var ea := (0.25 + 0.45 * absf(sin(t * 2.5 + k))) * 0.75
		draw_circle(Vector2(ex, ey), 1.2 + (k % 2) * 0.6, Color(1.0, 0.55 + (k % 3) * 0.15, 0.15, ea))
	# 右上角戰情 HUD 標籤
	var hud_x := vs.x - 620.0
	var hud_y := 22.0
	draw_rect(Rect2(hud_x, hud_y, 440, 30), Color(0.06, 0.02, 0.02, 0.82))
	draw_rect(Rect2(hud_x, hud_y, 5, 30), Color(0.95, 0.18, 0.12, 0.95))
	draw_circle(Vector2(hud_x + 19, hud_y + 15), 4.5, Color(1.0, 0.2, 0.15, 0.5 + 0.5 * sin(t * 6.0)))
	draw_string(G.font_bold, Vector2(hud_x + 32, hud_y + 21), MODERN_CAPTIONS[idx], HORIZONTAL_ALIGNMENT_LEFT, 396, 12, Color(1.0, 0.9, 0.75, 0.92))
	scanlines(vs)
	ground_parade(vs, Color(0.04, 0.025, 0.02, 0.94))

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
		["完成委託 / 佔領科技建築", "%d / %d" % [int(r.contracts), int(r.techs)]],
		["生存模式最佳波數 / 據點勝場", "%d / %d" % [int(r.best_wave), int(r.koth_wins)]],
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

# ───────────────────────── 每日挑戰 ─────────────────────────
# 以日期決定當天的國家、地圖、對手、難度與 2 個規則修改器；所有玩家同一天拿到相同戰場
static func today_code() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

static func daily_settings(code: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("daily:%d" % code)
	var cid: String = Defs.COUNTRY_ORDER[r.randi() % Defs.COUNTRY_ORDER.size()]
	var foes := []
	for c in Defs.COUNTRY_ORDER:
		if Defs.COUNTRIES[c].faction != Defs.COUNTRIES[cid].faction:
			foes.append(c)
	var ec: String = foes[r.randi() % foes.size()]
	var MapP: Array = preload("res://scripts/map.gd").PRESETS
	var mi := r.randi() % mini(11, MapP.size())
	var mk: Array = MUTATORS.keys()
	var muts := []
	while muts.size() < 2:
		var k: String = mk[r.randi() % mk.size()]
		if not k in muts and not (k == "infantry" and "nosuper" in muts):
			muts.append(k)
	var mode: String = ["std", "std", "std", "koth"][r.randi() % 4]
	return {
		"faction": Defs.COUNTRIES[cid].faction, "country": cid,
		"enemy_country": ec, "enemy_faction": Defs.COUNTRIES[ec].faction,
		"enemies": 1 + int(r.randi() % 3 == 0), "ai_allied": true,
		"difficulty": 1 + int(r.randi() % 2), "map": MapP[mi], "seed": int(r.randi() % 1000000),
		"money": 10000, "speed": 1.0, "crates": true, "events": true, "weather": true, "contracts": true,
		"mode": mode, "muts": muts, "daily": code,
	}

var daily_panel: Control

func show_daily():
	if daily_panel != null:
		daily_panel.queue_free()
		daily_panel = null
		return
	var code := today_code()
	var ds := daily_settings(code)
	var RecS = preload("res://scripts/records.gd")
	var r: Dictionary = RecS.get_rec()
	daily_panel = PanelContainer.new()
	daily_panel.position = Vector2(660, 200)
	daily_panel.custom_minimum_size = Vector2(600, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.06, 0.98)
	sb.border_color = Color(1, 0.7, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(24)
	daily_panel.add_theme_stylebox_override("panel", sb)
	add_child(daily_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	daily_panel.add_child(vb)
	var title := Label.new()
	title.text = "每日挑戰　%d/%02d/%02d" % [code / 10000, (code / 100) % 100, code % 100]
	title.add_theme_font_override("font", G.font_bold)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	vb.add_child(title)
	var mnames := []
	for k in ds.muts:
		mnames.append("%s（%s）" % [MUTATORS[k].name, MUTATORS[k].desc])
	var lines := [
		"我方：%s　　敵方：%s%s" % [Defs.COUNTRIES[ds.country].name, Defs.COUNTRIES[ds.enemy_country].name, "（＋1 名盟友）" if ds.enemies > 1 else ""],
		"地圖：%s　　難度：%s　　模式：%s" % [ds.map.name, ["簡單", "普通", "困難", "殘酷"][ds.difficulty], "據點爭奪" if ds.mode == "koth" else "殲滅戰"],
		"今日規則：",
	]
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.add_theme_font_size_override("font_size", 17)
		vb.add_child(lb)
	for m in mnames:
		var lb := Label.new()
		lb.text = "　◆ " + m
		lb.add_theme_font_size_override("font_size", 16)
		lb.add_theme_color_override("font_color", Color(1, 0.65, 0.45))
		vb.add_child(lb)
	var best := Label.new()
	if int(r.get("daily_date", 0)) == code and float(r.get("daily_best", 0.0)) > 0.0:
		var bt := float(r.daily_best)
		best.text = "今日最佳：%02d:%02d 獲勝" % [int(bt) / 60, int(bt) % 60]
	else:
		best.text = "今日尚未完成。目標：盡快取得勝利！"
	best.add_theme_font_override("font", G.font_bold)
	best.add_theme_font_size_override("font_size", 18)
	best.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	vb.add_child(best)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var go := Button.new()
	go.text = "開始挑戰"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size = Vector2(0, 48)
	go.add_theme_font_override("font", G.font_bold)
	go.add_theme_font_size_override("font_size", 20)
	go.pressed.connect(func(): Sfx.play("click", -2.0); G.main.start_game(daily_settings(code)))
	hb.add_child(go)
	var cl := Button.new()
	cl.text = "關閉"
	cl.custom_minimum_size = Vector2(120, 48)
	cl.pressed.connect(func(): show_daily())
	hb.add_child(cl)

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
