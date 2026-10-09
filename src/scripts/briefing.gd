extends Node2D
const FlagS = preload("res://scripts/flags.gd")
# 任務簡報過場：RSN 新聞播報風格（標題逐字打出、情報地圖、跑馬燈），按任意鍵開始任務

const W := 1920.0
const H := 1080.0
var md: Dictionary = {}
var t := 0.0
var done := false
var rng := RandomNumberGenerator.new()
var brief_lb: Label
var pts: Array = []
var tts_started := false
signal finished

func _ready():
	rng.seed = int(md.get("seed", 1))
	for k in 7:
		pts.append(Vector2(300 + rng.randf() * 1300, 220 + rng.randf() * 420))
	brief_lb = Label.new()
	brief_lb.position = Vector2(120, 560)
	brief_lb.size = Vector2(1100, 260)
	brief_lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_lb.add_theme_font_override("font", G.font)
	brief_lb.add_theme_font_size_override("font_size", 24)
	brief_lb.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	brief_lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	brief_lb.add_theme_constant_override("outline_size", 6)
	add_child(brief_lb)
	Sfx.music("intro")
	Sfx.play("radio", -6.0)
	start_tts()

func start_tts():
	if tts_started or not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	tts_started = true
	var en: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if not en.is_empty() and md.has("headline"):
		DisplayServer.tts_speak("Breaking news. " + str(md.headline).capitalize() + ".", en[0], 60, 1.0, 1.0)
	var zh: PackedStringArray = DisplayServer.tts_get_voices_for_language("zh")
	if not zh.is_empty():
		var txt: String = str(md.get("brief", "")).replace("【RSN 快訊】", "").replace("\n", " ")
		DisplayServer.tts_speak(txt, zh[0], 60, 1.0, 1.0, 0, false)

func _exit_tree():
	if tts_started:
		DisplayServer.tts_stop()

func _input(ev: InputEvent):
	if (ev is InputEventKey and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
		if t < 1.0:
			return
		finish()

func finish():
	if done:
		return
	done = true
	finished.emit()

func _process(delta: float):
	t += delta
	var full: String = str(md.get("brief", ""))
	var n: int = mini(full.length(), int(maxf(0.0, t - 2.2) * 28.0))
	brief_lb.text = full.substr(0, n)
	queue_redraw()

func _draw():
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.03, 0.05))
	var a := clampf(t / 0.8, 0.0, 1.0)
	# 網格與情報地圖
	for gx in range(0, int(W), 60):
		draw_line(Vector2(gx, 0), Vector2(gx, H), Color(0.15, 0.35, 0.5, 0.15 * a), 1.0)
	for gy in range(0, int(H), 60):
		draw_line(Vector2(0, gy), Vector2(W, gy), Color(0.15, 0.35, 0.5, 0.15 * a), 1.0)
	for k in pts.size():
		var p: Vector2 = pts[k]
		var ph := fmod(t * 1.3 + k * 0.6, 1.0)
		draw_arc(p, 8 + ph * 44, 0, TAU, 32, Color(1, 0.25, 0.15, (1.0 - ph) * a * 0.8), 2.0)
		draw_circle(p, 5, Color(1, 0.3, 0.2, a))
		if k > 0 and t > 1.0 + k * 0.3:
			draw_line(pts[k - 1], p, Color(1, 0.4, 0.2, 0.4 * a), 2.0)
	# 掃描線
	var sy := fmod(t * 160.0, H)
	draw_rect(Rect2(0, sy, W, 3), Color(0.4, 0.8, 1.0, 0.25 * a))
	# 新聞框
	draw_rect(Rect2(60, 70, 160, 44), Color(0.75, 0.08, 0.06, a))
	draw_string(G.font_bold, Vector2(60, 102), "RSN", HORIZONTAL_ALIGNMENT_CENTER, 160, 30, Color(1, 1, 1, a))
	draw_string(G.font_bold, Vector2(236, 100), "WORLD NEWS  •  LIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, a * 0.85))
	draw_circle(Vector2(560, 92), 7, Color(1, 0.15, 0.1, a * (0.5 + 0.5 * sin(t * 6.0))))
	draw_string(G.font_bold, Vector2(0, 100), str(md.get("name", "")), HORIZONTAL_ALIGNMENT_RIGHT, W - 60, 26, Color(1, 0.85, 0.4, a))
	# 標題逐字
	var head: String = str(md.get("headline", ""))
	var n: int = mini(head.length(), int(maxf(0.0, t - 0.6) * 30.0))
	draw_rect(Rect2(60, 400, 260, 36), Color(0.75, 0.08, 0.06, a))
	draw_string(G.font_bold, Vector2(60, 426), "BREAKING NEWS", HORIZONTAL_ALIGNMENT_CENTER, 260, 22, Color(1, 1, 1, a))
	draw_rect(Rect2(0, 440, W, 80), Color(0.05, 0.05, 0.08, 0.92 * a))
	draw_rect(Rect2(0, 440, W, 5), Color(0.75, 0.08, 0.06, a))
	var shown := head.substr(0, n)
	if n < head.length() and int(t * 6.0) % 2 == 0:
		shown += "_"
	draw_string(G.font_bold, Vector2(70, 494), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, a))
	# 跑馬燈
	draw_rect(Rect2(0, 520, W, 30), Color(0.12, 0.12, 0.16, 0.95 * a))
	var tick := "GRID FAILURES REPORTED  •  DRONE SWARMS CROSS THE STRAIT  •  CENTRAL BANK FREEZES RESERVES  •  ENERGY EXPORTS HALTED  •  ALLIANCE TALKS COLLAPSE  •  CARRIER GROUP DEPARTS PORT  •  "
	var x := fmod(-t * 160.0, 2200.0)
	draw_string(G.font_bold, Vector2(x, 542), tick + tick, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.9, 0.7, a))
	# 簡報底板
	draw_rect(Rect2(100, 550, 1140, 290), Color(0, 0, 0, 0.45 * a))
	# 右側：陣營資訊
	var cn: String = str(md.get("country", ""))
	if Defs.COUNTRIES.has(cn):
		var c: Dictionary = Defs.COUNTRIES[cn]
		draw_rect(Rect2(1300, 560, 540, 270), Color(0.05, 0.06, 0.1, 0.8 * a))
		draw_rect(Rect2(1300, 560, 540, 270), Color(0.3, 0.5, 0.8, 0.5 * a), false, 1.0)
		var fc: Array = c.flag
		for k in 3:
			draw_rect(Rect2(1320, 580 + k * 20, 90, 20), Color(fc[k].r, fc[k].g, fc[k].b, a))
		draw_string(G.font_bold, Vector2(1430, 605), "我方：%s（%s）" % [c.name, Defs.FACTIONS[c.faction].name], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
		var ec: String = str(md.get("enemy_country", ""))
		var en: String = Defs.COUNTRIES[ec].name if Defs.COUNTRIES.has(ec) else "隨機"
		draw_string(G.font_bold, Vector2(1430, 640), "敵方：%s" % en, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.6, 0.5, a))
		draw_string(G.font, Vector2(1320, 690), str(c.desc), HORIZONTAL_ALIGNMENT_LEFT, 500, 16, Color(0.85, 0.85, 0.8, a))
	# 提示
	var blink := 0.5 + 0.5 * sin(t * 4.0)
	if t > 1.0:
		draw_string(G.font_bold, Vector2(0, H - 50), "按任意鍵開始任務  ·  Press any key to begin", HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 0.85, 0.4, blink))
	draw_rect(Rect2(0, 0, W, 50), Color(0, 0, 0))
	draw_rect(Rect2(0, H - 30, W, 30), Color(0, 0, 0))
