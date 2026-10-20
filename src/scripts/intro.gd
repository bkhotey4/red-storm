extends Node2D
# 片頭動畫：混合戰爭（支援 5 分鐘真實新聞結合開場影片 & 2.5 分鐘宣傳影片，可按 Esc / 點擊跳過，按 Tab 切換版本）
# 旁白：內嵌真實新聞主播與軍事指揮官英語語音 + 現代交響電子配樂

const DUR := 60.0
const W := 1920.0
const H := 1080.0

var video_mode := "5min" # "5min" (300s opening film) or "promo" (150s promotional trailer)
var vsp: VideoStreamPlayer = null
var use_video_stream := false
var video_dur := 300.0

# [開始秒, 英文, 中文]
const LINES := [
	[0.8, "This is RSN. We interrupt this broadcast.", "這裡是 RSN 新聞網。我們中斷節目插播。"],
	[4.2, "Across three continents, the lights are going out.", "橫跨三大洲，燈火正在熄滅。"],
	[9.0, "The first wave came from the sky.", "第一波攻擊來自天空。"],
	[12.0, "Cheap drones, by the thousand. No pilots. No warning.", "廉價無人機，成千上萬。沒有飛行員，沒有預警。"],
	[19.0, "The second wave came through the banks.", "第二波攻擊穿過銀行。"],
	[22.5, "Sanctions froze a nation in ninety seconds.", "制裁在九十秒內凍結了一個國家。"],
	[26.0, "Markets fell faster than cities.", "市場崩得比城市還快。"],
	[30.0, "Then the missiles.", "然後是飛彈。"],
	[32.5, "Power grids. Data centers. Refineries.", "電網、資料中心、煉油廠。"],
	[36.0, "The targets were not soldiers. They were systems.", "目標不是士兵，而是系統。"],
	[40.0, "Steel still matters. Carriers still sail.", "鋼鐵依然重要，航母依然出航。"],
	[44.0, "But wars are no longer won by steel alone.", "但戰爭已不再只靠鋼鐵取勝。"],
	[48.5, "Drones. Sanctions. Spies. Alliances.", "無人機、制裁、間諜、同盟。"],
	[52.0, "Every weapon is on the table.", "每一種武器都已擺上檯面。"],
	[55.0, "Commander, the storm is yours.", "指揮官，風暴由你掌控。"],
]
const NARR := "This is R S N. We interrupt this broadcast. Across three continents, the lights are going out. The first wave came from the sky. Cheap drones, by the thousand. No pilots. No warning. The second wave came through the banks. Sanctions froze a nation in ninety seconds. Markets fell faster than cities. Then the missiles. Power grids. Data centers. Refineries. The targets were not soldiers. They were systems. Steel still matters. Carriers still sail. But wars are no longer won by steel alone. Drones. Sanctions. Spies. Alliances. Every weapon is on the table. Commander, the storm is yours."

var t := 0.0
var done := false
var record_dir := ""
var frame_i := 0
var rng := RandomNumberGenerator.new()
var drones: Array = []
var booms: Array = []
var tickers: Array = []
var numbers: Array = []
var missiles: Array = []
var tanks: Array = []
var jets: Array = []
var sub_en: Label
var sub_zh: Label
var tts_started := false
var sfx_log: Array = []

signal finished

func _ready():
	rng.seed = 7
	for k in 40:
		drones.append({"p": Vector2(-200 - rng.randf() * 1400, 200 + rng.randf() * 500), "v": Vector2(380 + rng.randf() * 160, 10 + rng.randf() * 30), "k": "a_fpv" if k % 3 != 0 else "s_shahed", "s": 1.4 + rng.randf() * 0.8})
	for k in 60:
		tickers.append({"x": rng.randf() * W, "y": 120 + rng.randf() * 760, "v": 60 + rng.randf() * 240, "txt": ["RSX -%.1f%%" % (rng.randf() * 9), "ENERGY %+.1f%%" % (rng.randf() * 30), "CRD FROZEN", "SWIFT ▼", "GOLD +%.1f%%" % (rng.randf() * 6), "RESERVE -%d%%" % int(rng.randf() * 40), "DEFAULT RISK ▲"][k % 7], "c": Color(1, 0.3, 0.25) if k % 4 != 1 else Color(0.4, 1, 0.5)})
	for k in 90:
		numbers.append({"x": rng.randf() * W, "y": rng.randf() * H, "v": 120 + rng.randf() * 300, "n": "%08.2f" % (rng.randf() * 99999), "a": 0.15 + rng.randf() * 0.4})
	for k in 7:
		missiles.append({"t0": 30.4 + k * 0.9, "from": Vector2(1700 + k * 40, -100), "to": Vector2(300 + k * 190 + rng.randf() * 80, 760 + rng.randf() * 120), "dur": 1.6, "done": false})
	for k in 8:
		tanks.append({"x": -300 - k * 170, "y": 640 + (k % 2) * 60, "k": "s_tank" if k % 2 == 0 else "a_tank"})
	for k in 3:
		jets.append({"t0": 42.2 + k * 0.5, "p": Vector2(1180, 560)})
	sub_en = Label.new()
	sub_en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_en.add_theme_font_override("font", G.font_bold)
	sub_en.add_theme_font_size_override("font_size", 40)
	sub_en.add_theme_color_override("font_color", Color(1, 1, 1))
	sub_en.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub_en.add_theme_constant_override("outline_size", 8)
	sub_en.position = Vector2(0, H - 190)
	sub_en.size = Vector2(W, 50)
	add_child(sub_en)
	sub_zh = Label.new()
	sub_zh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_zh.add_theme_font_override("font", G.font_bold)
	sub_zh.add_theme_font_size_override("font_size", 26)
	sub_zh.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	sub_zh.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub_zh.add_theme_constant_override("outline_size", 6)
	sub_zh.position = Vector2(0, H - 135)
	sub_zh.size = Vector2(W, 40)
	add_child(sub_zh)
	if record_dir == "" and _setup_video_stream():
		use_video_stream = true
		sub_en.visible = false
		sub_zh.visible = false
		return
	Sfx.music("intro")
	start_tts()

func _setup_video_stream() -> bool:
	var vpath := "res://video/redstorm_intro_5min.ogv"
	video_dur = 300.0
	if video_mode == "promo":
		vpath = "res://video/redstorm_promo_trailer.ogv"
		video_dur = 150.0
	if not FileAccess.file_exists(vpath):
		if FileAccess.file_exists("res://video/redstorm_intro_cinematic.ogv"):
			vpath = "res://video/redstorm_intro_cinematic.ogv"
			video_dur = 60.0
		else:
			return false
	var vst := VideoStreamTheora.new()
	vst.file = vpath
	if vsp != null:
		vsp.queue_free()
	vsp = VideoStreamPlayer.new()
	vsp.stream = vst
	vsp.self_modulate = Color(1, 1, 1, 0)
	add_child(vsp)
	vsp.finished.connect(finish)
	vsp.play()
	return true

func start_tts():
	if record_dir != "" or tts_started or use_video_stream:
		return
	tts_started = true
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var voices: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	var v: String = voices[0]
	for vv in voices:
		if vv.to_lower().contains("david") or vv.to_lower().contains("mark") or vv.to_lower().contains("guy"):
			v = vv
			break
	DisplayServer.tts_speak(NARR, v, 60, 0.95, 1.0)

func _exit_tree():
	if tts_started:
		DisplayServer.tts_stop()
	if vsp != null and vsp.is_playing():
		vsp.stop()

func _input(ev: InputEvent):
	if record_dir != "":
		return
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_TAB and use_video_stream:
		video_mode = "promo" if video_mode == "5min" else "5min"
		t = 0.0
		_setup_video_stream()
		return
	if (ev is InputEventKey and ev.pressed and (ev.keycode == KEY_ESCAPE or ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER)) or (ev is InputEventMouseButton and ev.pressed):
		finish()

func finish():
	if done:
		return
	done = true
	if vsp != null and vsp.is_playing():
		vsp.stop()
	finished.emit()

func _process(delta: float):
	if use_video_stream:
		t += delta
		queue_redraw()
		if t >= video_dur + 1.5:
			finish()
		return
	var dt := delta if record_dir == "" else 1.0 / 24.0
	t += dt
	if t >= DUR + 1.5:
		finish()
		return
	# 字幕
	var en := ""
	var zh := ""
	for ln in LINES:
		if t >= float(ln[0]) and t < float(ln[0]) + 4.6:
			en = ln[1]
			zh = ln[2]
	sub_en.text = en
	sub_zh.text = zh
	sub_en.visible = t < 56.5 or t > 57.0
	sub_zh.visible = sub_en.visible
	# 無人機、飛彈等狀態
	if t >= 8.0 and t < 19.0:
		for d in drones:
			d.p += d.v * dt
			if d.p.x > W + 100:
				d.p.x = -100 - rng.randf() * 300
			if rng.randf() < dt * 0.35 and d.p.x > 500 and d.p.x < 1500:
				booms.append({"p": d.p + Vector2(0, 120 + rng.randf() * 150), "t": 0.0, "s": 0.9 + rng.randf() * 0.8})
				sfx("explode")
	for m in missiles:
		if t >= m.t0 + m.dur and not m.done:
			m.done = true
			booms.append({"p": m.to, "t": 0.0, "s": 2.2})
			sfx("big_explode")
	if t >= 38.0 and t < 48.5:
		for tk in tanks:
			tk.x += 150.0 * dt
	for b in booms:
		b.t += dt
	booms = booms.filter(func(b): return b.t < 1.3)
	for tk in tickers:
		tk.x -= tk.v * dt
		if tk.x < -300:
			tk.x = W + rng.randf() * 400
	for n in numbers:
		n.y += n.v * dt
		if n.y > H:
			n.y = -30
	queue_redraw()
	if record_dir != "":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg("%s/f%05d.jpg" % [record_dir, frame_i], 0.92)
		frame_i += 1

func sfx(name: String):
	if record_dir != "":
		sfx_log.append([t, name])
	else:
		Sfx.play(name, -6.0)

func fade(a: float, b: float, c: float, d: float) -> float:
	# 在 a..b 淡入，c..d 淡出
	if t < a or t > d:
		return 0.0
	if t < b:
		return (t - a) / (b - a)
	if t > c:
		return 1.0 - (t - c) / (d - c)
	return 1.0

func _draw():
	if use_video_stream and vsp != null:
		var vs := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0))
		var vtex := vsp.get_video_texture()
		if vtex != null:
			draw_texture_rect(vtex, Rect2(Vector2.ZERO, vs), false)
		# 操作提示放右上角（避開影片底部的新聞跑馬燈），播放幾秒後淡出
		var mode_tag := "開場影片" if video_mode == "5min" else "宣傳片"
		var hint := "%s　Tab：切換開場影片／宣傳片　Esc／空白鍵：跳過" % mode_tag
		var ha := clampf(1.0 - (t - 6.0) / 1.5, 0.35, 1.0)
		var hw := G.font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0
		draw_rect(Rect2(vs.x - hw - 16, 14, hw, 28), Color(0, 0, 0, 0.55 * ha))
		draw_string(G.font, Vector2(vs.x - hw - 4, 34), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.92, 0.92, 0.9, ha))
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.02, 0.03))
	draw_news()
	draw_drones()
	draw_finance()
	draw_missiles()
	draw_steel()
	draw_title()
	# 暗角
	var vg := G.tex("fx_soft")
	draw_texture_rect(vg, Rect2(-W * 0.35, -H * 0.5, W * 1.7, H * 2.0), false, Color(0, 0, 0, 0.0))
	for k in 4:
		draw_rect(Rect2(0, 0, W, 60 + k * 30), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(0, H - 60 - k * 30, W, 60 + k * 30), Color(0, 0, 0, 0.12))
	# 片頭黑邊
	draw_rect(Rect2(0, 0, W, 70), Color(0, 0, 0))
	draw_rect(Rect2(0, H - 70, W, 70), Color(0, 0, 0))
	if record_dir == "":
		draw_string(G.font, Vector2(W - 260, H - 24), "按 Esc 跳過 / Press Esc to skip", HORIZONTAL_ALIGNMENT_RIGHT, 240, 14, Color(0.6, 0.6, 0.6, 0.7))
	# 開頭與結尾淡入淡出
	var black := 1.0 - clampf(t / 1.2, 0.0, 1.0)
	black = maxf(black, clampf((t - DUR - 0.2) / 1.2, 0.0, 1.0))
	if black > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, black))

func news_frame(alpha: float, headline: String, sub: String):
	# 新聞台框架
	var c := Color(1, 1, 1, alpha)
	draw_rect(Rect2(60, 90, 160, 44), Color(0.75, 0.08, 0.06, alpha))
	draw_string(G.font_bold, Vector2(60, 122), "RSN", HORIZONTAL_ALIGNMENT_CENTER, 160, 30, c)
	draw_string(G.font_bold, Vector2(236, 120), "WORLD NEWS  •  LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, alpha * 0.85))
	draw_circle(Vector2(560, 112), 7, Color(1, 0.15, 0.1, alpha * (0.5 + 0.5 * sin(t * 6.0))))
	# 下方標題帶
	draw_rect(Rect2(0, H - 330, W, 6), Color(0.75, 0.08, 0.06, alpha))
	draw_rect(Rect2(0, H - 324, W, 70), Color(0.05, 0.05, 0.08, alpha * 0.92))
	draw_rect(Rect2(60, H - 360, 260, 36), Color(0.75, 0.08, 0.06, alpha))
	draw_string(G.font_bold, Vector2(60, H - 334), "BREAKING NEWS", HORIZONTAL_ALIGNMENT_CENTER, 260, 22, c)
	draw_string(G.font_bold, Vector2(70, H - 280), headline, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)
	draw_string(G.font, Vector2(70, H - 262 + 2), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.85, 0.8, alpha))
	# 跑馬燈
	draw_rect(Rect2(0, H - 254, W, 34), Color(0.12, 0.12, 0.16, alpha * 0.95))
	var tick := "GRID FAILURES REPORTED IN 14 CITIES  •  DRONE SWARMS CROSS THE STRAIT  •  CENTRAL BANK FREEZES RESERVES  •  ENERGY EXPORTS HALTED  •  ALLIANCE TALKS COLLAPSE  •  CARRIER GROUP DEPARTS PORT  •  "
	var x := fmod(-t * 180.0, 2400.0)
	draw_string(G.font_bold, Vector2(x, H - 230), tick + tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.9, 0.7, alpha))

func draw_news():
	var a := fade(0.6, 1.6, 7.0, 8.6)
	if a <= 0.0:
		return
	# 背景：戰術地圖網格 + 脈衝紅點
	draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.05, 0.08, a))
	for gx in range(0, int(W), 60):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.15, 0.35, 0.5, 0.18 * a), 1.0)
	for gy in range(0, int(H), 60):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.15, 0.35, 0.5, 0.18 * a), 1.0)
	# 抽象大陸輪廓
	var conts := [
		PackedVector2Array([Vector2(180, 300), Vector2(420, 220), Vector2(640, 300), Vector2(600, 520), Vector2(480, 700), Vector2(300, 640), Vector2(200, 480)]),
		PackedVector2Array([Vector2(760, 260), Vector2(1100, 200), Vector2(1400, 300), Vector2(1500, 520), Vector2(1300, 640), Vector2(1000, 600), Vector2(820, 480)]),
		PackedVector2Array([Vector2(1500, 240), Vector2(1760, 280), Vector2(1800, 520), Vector2(1640, 640), Vector2(1540, 500)]),
	]
	for c in conts:
		draw_colored_polygon(c, Color(0.1, 0.2, 0.28, 0.7 * a))
		var cc: PackedVector2Array = c.duplicate()
		cc.append(c[0])
		draw_polyline(cc, Color(0.3, 0.6, 0.8, 0.6 * a), 2.0)
	var pts := [Vector2(520, 420), Vector2(1240, 380), Vector2(1660, 440), Vector2(380, 560), Vector2(1080, 540), Vector2(900, 330)]
	for k in pts.size():
		var p: Vector2 = pts[k]
		var ph := fmod(t * 1.5 + k * 0.7, 1.0)
		draw_arc(p, 10 + ph * 50, 0, TAU, 32, Color(1, 0.2, 0.15, (1.0 - ph) * a), 2.0)
		draw_circle(p, 6, Color(1, 0.25, 0.2, a))
		if k > 0 and t > 2.0 + k * 0.6:
			draw_line(pts[k - 1], p, Color(1, 0.4, 0.2, 0.5 * a), 2.0)
	news_frame(a, "BLACKOUTS SPREAD ACROSS THREE CONTINENTS", "Officials confirm coordinated attacks on power and finance")

func draw_drones():
	var a := fade(8.0, 9.0, 17.5, 19.0)
	if a <= 0.0:
		return
	# 沙漠地面 + 天空
	var sand := G.tex("sand")
	draw_texture_rect(sand, Rect2(0, 0, W, H), true, Color(0.55, 0.5, 0.42, a))
	for i in 10:
		draw_rect(Rect2(0, i * 40, W, 40), Color(0.15, 0.18, 0.22, a * (1.0 - i / 10.0) * 0.9))
	# 城鎮
	for k in 6:
		var sh = G.sheet(["civ_house", "civ_shop", "civ_office", "civ_gas", "civ_tower", "civ_barn"][k])
		if sh != null:
			sh.draw(self, 0, Vector2(300 + k * 240, 820 + (k % 2) * 60), Color.WHITE, Color(1, 1, 1, a), 2.2)
	for d in drones:
		var sh = G.sheet(d.k)
		if sh != null:
			draw_set_transform(d.p + Vector2(40, 60), 0.0, Vector2(1, 0.5))
			draw_circle(Vector2.ZERO, 14 * d.s, Color(0, 0, 0, 0.25 * a))
			draw_set_transform(Vector2.ZERO)
			sh.draw(self, sh.dir_frame(0.0), d.p, Color(0.9, 0.2, 0.15), Color(1, 1, 1, a), d.s)
	for k in 5:
		var ph := fmod(t * 2.0 + k * 0.37, 1.0)
		var src := Vector2(500 + k * 260, 900)
		var dst := src + Vector2(-200 + k * 90, -620)
		draw_line(src.lerp(dst, ph), src.lerp(dst, minf(1.0, ph + 0.08)), Color(1, 0.9, 0.5, a), 2.0)
	draw_booms(a)
	news_frame(a * 0.9, "THOUSANDS OF DRONES STRIKE WITHOUT WARNING", "Low-cost swarms overwhelm air defenses within minutes")

func draw_booms(a: float):
	var big = G.sheet("exp_big")
	if big == null:
		return
	for b in booms:
		var f: int = int(b.t / 1.3 * big.n)
		big.draw(self, mini(f, big.n - 1), b.p, Color.WHITE, Color(1, 1, 1, a), b.s)

func draw_finance():
	var a := fade(18.5, 19.5, 28.5, 30.0)
	if a <= 0.0:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.05, a))
	for n in numbers:
		draw_string(G.font, Vector2(n.x, n.y), n.n, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.9, 0.5, n.a * a * 0.5))
	# 崩跌折線
	var pts := PackedVector2Array()
	var seg := 40
	for k in seg + 1:
		var u := float(k) / seg
		var yv := 320.0 + 380.0 * pow(u, 1.6) + sin(u * 40.0 + t) * 14.0
		if u * 1900.0 < (t - 19.5) * 320.0:
			pts.append(Vector2(60 + u * 1800.0, yv))
	if pts.size() > 1:
		draw_polyline(pts, Color(1, 0.25, 0.2, a), 4.0)
		var last := pts[pts.size() - 1]
		draw_circle(last, 8, Color(1, 0.4, 0.3, a))
	# 跑馬燈
	for tk in tickers:
		draw_string(G.font_bold, Vector2(tk.x, tk.y), tk.txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(tk.c.r, tk.c.g, tk.c.b, 0.7 * a))
	# 制裁印章
	if t > 22.0:
		var s := clampf((t - 22.0) / 0.25, 0.0, 1.0)
		var sc := 2.2 - 1.2 * s
		draw_set_transform(Vector2(W * 0.5, 400), -0.12, Vector2(sc, sc))
		draw_rect(Rect2(-330, -70, 660, 140), Color(0.8, 0.1, 0.08, 0.0), false, 10.0)
		draw_rect(Rect2(-330, -70, 660, 140), Color(0.9, 0.12, 0.1, s * a), false, 10.0)
		draw_string(G.font_bold, Vector2(-330, 30), "SANCTIONED", HORIZONTAL_ALIGNMENT_CENTER, 660, 84, Color(0.9, 0.12, 0.1, s * a))
		draw_set_transform(Vector2.ZERO)
		draw_string(G.font_bold, Vector2(0, 540), "ASSETS FROZEN  •  $%s" % G.fmt_money(4.2e9 * minf(1.0, (t - 22.0) / 4.0)), HORIZONTAL_ALIGNMENT_CENTER, W, 42, Color(1, 0.85, 0.3, a))
	var bank = G.sheet("a_bank")
	if bank != null:
		bank.draw(self, 0, Vector2(1560, 860), Color(0.25, 0.5, 1.0), Color(1, 1, 1, a), 2.4)
	news_frame(a * 0.9, "SANCTIONS FREEZE NATIONAL RESERVES IN 90 SECONDS", "Payment networks severed; currency loses 40% overnight")

func draw_missiles():
	var a := fade(29.5, 30.5, 38.0, 39.5)
	if a <= 0.0:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.05, 0.08, a))
	for i in 10:
		draw_rect(Rect2(0, i * 42, W, 42), Color(0.25, 0.12, 0.1, a * (1.0 - i / 10.0) * 0.8))
	var grass := G.tex("dirt_trop")
	draw_texture_rect(grass, Rect2(0, 420, W, 700), true, Color(0.75, 0.68, 0.6, a))
	# 城市天際線（平民建築）
	for k in 9:
		var sh = G.sheet(["civ_office", "civ_tower", "civ_house", "civ_shop", "civ_office", "civ_gas", "civ_tower", "civ_house", "civ_barn"][k])
		if sh != null:
			sh.draw(self, 0, Vector2(120 + k * 210, 600 + (k % 3) * 30), Color.WHITE, Color(0.8, 0.8, 0.8, a), 1.7)
	# 目標：發電廠、精煉廠、銀行
	var targets := ["a_power", "s_ref", "a_bank", "s_power", "a_ref", "s_gas", "a_radar"]
	for k in targets.size():
		var sh = G.sheet(targets[k])
		if sh != null:
			sh.draw(self, 0, Vector2(320 + k * 200, 820 + (k % 2) * 40), Color(0.3, 0.5, 0.9) if k % 2 == 0 else Color(0.9, 0.2, 0.15), Color(1, 1, 1, a), 1.6)
	var fire = G.sheet("exp_fire")
	for m in missiles:
		if m.done and fire != null:
			var f: int = int(t * 12.0) % fire.n
			fire.draw(self, f, m.to + Vector2(0, -10), Color.WHITE, Color(1, 1, 1, a), 1.6)
	var streak := G.tex("fx_streak")
	for m in missiles:
		if t < m.t0 or m.done:
			continue
		var u: float = clampf((t - m.t0) / m.dur, 0.0, 1.0)
		var p: Vector2 = m.from.lerp(m.to, u)
		var tail: Vector2 = m.from.lerp(m.to, maxf(0.0, u - 0.18))
		draw_line(tail, p, Color(1, 0.8, 0.5, 0.8 * a), 4.0)
		draw_line(tail, p, Color(1, 1, 1, 0.9 * a), 1.5)
		draw_circle(p, 6, Color(1, 1, 0.9, a))
	draw_booms(a)
	if t > 34.0:
		draw_string(G.font_bold, Vector2(0, 200), "TARGET: INFRASTRUCTURE", HORIZONTAL_ALIGNMENT_CENTER, W, 48, Color(1, 0.3, 0.2, a * (0.6 + 0.4 * sin(t * 5.0))))
	news_frame(a * 0.9, "MISSILE STRIKES HIT GRIDS, DATA CENTERS, REFINERIES", "No military targets reported — analysts call it 'systems warfare'")

func draw_steel():
	var a := fade(39.0, 40.0, 47.5, 49.0)
	if a <= 0.0:
		return
	var grass := G.tex("grass_trop")
	draw_texture_rect(grass, Rect2(0, 0, W, H), true, Color(0.75, 0.75, 0.7, a))
	var water := G.tex("water")
	var coast := PackedVector2Array([Vector2(1100, 0), Vector2(W, 0), Vector2(W, 760), Vector2(1500, 720), Vector2(1250, 520), Vector2(1180, 260)])
	var beach := PackedVector2Array()
	for q in coast:
		beach.append(q + Vector2(-22, 10))
	draw_colored_polygon(beach, Color(0.85, 0.78, 0.58, a))
	var uvs := PackedVector2Array()
	for q in coast:
		uvs.append(q / 512.0)
	draw_polygon(coast, PackedColorArray([Color(0.7, 0.8, 1.0, a), Color(0.7, 0.8, 1.0, a), Color(0.7, 0.8, 1.0, a), Color(0.7, 0.8, 1.0, a), Color(0.7, 0.8, 1.0, a), Color(0.7, 0.8, 1.0, a)]), uvs, water)
	var dd = G.sheet("a_destroyer")
	if dd != null:
		for k in 2:
			dd.draw(self, dd.dir_frame(PI * 0.1), Vector2(1500 + k * 180, 250 + k * 160 + sin(t * 1.3 + k) * 3.0), Color(0.25, 0.5, 1.0), Color(1, 1, 1, a), 1.8)
	# 砲口火光
	var fl := G.tex("fx_glow")
	for tk in tanks:
		if fmod(t * 1.7 + tk.x * 0.01, 1.0) < 0.12:
			draw_texture_rect(fl, Rect2(tk.x + 40, tk.y - 40, 60, 60), false, Color(1, 0.8, 0.4, a))
	# 戰車縱隊
	for tk in tanks:
		var sh = G.sheet(tk.k)
		var tt = G.sheet(tk.k + "_t")
		if sh != null:
			var col := Color(0.9, 0.2, 0.15) if tk.k.begins_with("s_") else Color(0.25, 0.5, 1.0)
			sh.draw(self, sh.dir_frame(0.0), Vector2(tk.x, tk.y), col, Color(1, 1, 1, a), 2.2)
			if tt != null:
				tt.draw(self, tt.dir_frame(0.0), Vector2(tk.x, tk.y), col, Color(1, 1, 1, a), 2.2)
	# 航母 + 艦載機
	var cv = G.sheet("a_cvn")
	if cv != null:
		cv.draw(self, cv.dir_frame(PI * 0.1), Vector2(1380, 420 + sin(t * 1.5) * 3.0), Color(0.25, 0.5, 1.0), Color(1, 1, 1, a), 2.0)
	var jet = G.sheet("a_hornet")
	for j in jets:
		if t >= j.t0 and jet != null:
			var u: float = t - j.t0
			var p: Vector2 = Vector2(1380, 400) + Vector2(-u * 420.0, -u * 160.0)
			jet.draw(self, jet.dir_frame(PI * 0.85), p, Color(0.25, 0.5, 1.0), Color(1, 1, 1, a), 1.8)
	var ap = G.sheet("a_apache")
	if ap != null:
		ap.draw(self, ap.dir_frame(0.0), Vector2(300 + fmod(t * 120.0, 1500.0), 250 + sin(t * 2.0) * 10.0), Color(0.25, 0.5, 1.0), Color(1, 1, 1, a), 2.0)
	news_frame(a * 0.9, "CARRIER GROUPS DEPLOY AS ARMORED COLUMNS ADVANCE", "Conventional forces mobilize across the strait")

func draw_title():
	var a := fade(48.0, 49.5, 59.5, 61.0)
	if a <= 0.0:
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.02, 0.02, a))
	# 透視網格
	for k in 20:
		var y := 560 + pow(float(k) / 20.0, 2.2) * 520.0
		draw_line(Vector2(0, y), Vector2(W, y), Color(0.6, 0.1, 0.08, 0.35 * a), 1.0)
	for k in 25:
		var x := -800 + k * 150.0
		draw_line(Vector2(W * 0.5 + (x - W * 0.5) * 0.15, 560), Vector2(x, H), Color(0.6, 0.1, 0.08, 0.3 * a), 1.0)
	# 四個關鍵字依序亮起
	var words := [["DRONES", "無人機"], ["SANCTIONS", "制裁"], ["SPIES", "間諜"], ["ALLIANCES", "同盟"]]
	for k in words.size():
		var wa := clampf((t - 48.6 - k * 0.8) / 0.4, 0.0, 1.0) * a
		if t > 54.5:
			wa *= clampf(1.0 - (t - 54.5) / 0.8, 0.0, 1.0)
		draw_string(G.font_bold, Vector2(0, 300 + k * 70), words[k][0] + "   " + words[k][1], HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color(1, 0.9, 0.8, wa))
	if t > 55.0:
		var s := clampf((t - 55.0) / 0.6, 0.0, 1.0)
		var sc := 1.6 - 0.6 * s
		draw_set_transform(Vector2(W * 0.5, 420), 0.0, Vector2(sc, sc))
		draw_string(G.font_bold, Vector2(-800, 0), "紅色風暴", HORIZONTAL_ALIGNMENT_CENTER, 1600, 150, Color(0.9, 0.12, 0.08, s * a))
		draw_string(G.font_bold, Vector2(-800, 90), "RED STORM", HORIZONTAL_ALIGNMENT_CENTER, 1600, 70, Color(1, 0.85, 0.5, s * a))
		draw_set_transform(Vector2.ZERO)
		var s2 := clampf((t - 56.0) / 0.6, 0.0, 1.0)
		draw_string(G.font_bold, Vector2(0, 600), "HYBRID WARFARE  •  混合戰爭", HORIZONTAL_ALIGNMENT_CENTER, W, 42, Color(1, 1, 1, s2 * a))
		draw_string(G.font, Vector2(0, 650), "Steel. Drones. Money. Information.", HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.8, 0.8, 0.75, s2 * a))
