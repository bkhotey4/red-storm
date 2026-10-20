extends Node
# 全域工具：字型、設定、等角座標轉換、圖片載入

const HW := 32.0   # half tile width in pixels
const HH := 16.0   # half tile height
const VERSION := "1.0"

var font: Font
var font_bold: Font
var game = null
var main = null
var settings := {
	"faction": "allies",
	"country": "usa",
	"campaign_done": "",
	"enemy_faction": "soviet",
	"difficulty": 1,
	"money": 10000,
	"seed": 0,
	"map_size": 72,
	"sfx_vol": 0.8,
	"voice_vol": 1.0,
	"music_vol": 0.5,
	"speed": 1.0,
	"edge_scroll": true,
}
var sheets := {}
var textures := {}

class Sheet:
	var tex: Texture2D
	var team: Texture2D
	var n := 1
	var cw := 1
	var ch := 1
	var cols := 1
	var ax := 0.0
	var ay := 0.0
	var dirs := 0
	var poses := 1
	var res := 1.0

	func w() -> float:
		return cw / res

	func h() -> float:
		return ch / res

	func rect(i: int) -> Rect2:
		i = clampi(i, 0, n - 1)
		return Rect2((i % cols) * cw, (i / cols) * ch, cw, ch)

	func dir_frame(angle: float) -> int:
		var d := dirs if dirs > 0 else 1
		var f := fposmod(angle, TAU) / TAU * d
		return int(round(f)) % d

	func draw(ci: CanvasItem, i: int, at: Vector2, tc: Color, mod := Color.WHITE, sc := 1.0, clip := 1.0):
		var r := rect(i)
		sc /= res
		var dst := Rect2(at - Vector2(ax, ay) * sc, Vector2(cw, ch) * sc)
		if clip < 1.0:
			# construction reveal from the bottom
			var hcut := ch * (1.0 - clip)
			r = Rect2(r.position.x, r.position.y + hcut, cw, ch - hcut)
			dst = Rect2(dst.position.x, dst.position.y + hcut * sc, dst.size.x, dst.size.y - hcut * sc)
		ci.draw_texture_rect_region(tex, dst, r, mod)
		if team != null:
			ci.draw_texture_rect_region(team, dst, r, Color(tc.r * mod.r, tc.g * mod.g, tc.b * mod.b, mod.a))

func _ready():
	load_settings()
	# 內嵌思源黑體（Noto Sans TC，OFL 授權）：網頁版、Mac、Steam Deck 都沒有微軟正黑體
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Microsoft JhengHei UI", "Microsoft JhengHei", "Microsoft YaHei UI", "Microsoft YaHei",
		"PingFang TC", "Noto Sans CJK TC", "Noto Sans CJK SC", "Noto Sans TC", "sans-serif"])
	sys.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sys.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var ff = load("res://fonts/NotoSansTC.ttf") if ResourceLoader.exists("res://fonts/NotoSansTC.ttf") else null
	if ff is FontFile:
		ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		var wght := TextServerManager.get_primary_interface().name_to_tag("wght")
		var reg := FontVariation.new()
		reg.base_font = ff
		reg.variation_opentype = {wght: 450}
		reg.fallbacks = [sys]
		var bold := FontVariation.new()
		bold.base_font = ff
		bold.variation_opentype = {wght: 700}
		bold.fallbacks = [sys]
		font = reg
		font_bold = bold
	else:
		font = sys
		var sb: SystemFont = sys.duplicate()
		sb.font_weight = 700
		font_bold = sb
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 15
	var icon := load_image("res://textures/icon.png")
	if icon and not OS.has_feature("web"):
		DisplayServer.set_icon(icon)

func iso(p: Vector2) -> Vector2:
	return Vector2((p.x - p.y) * HW, (p.x + p.y) * HH)

func uniso(s: Vector2) -> Vector2:
	var a := s.x / HW
	var b := s.y / HH
	return Vector2((a + b) * 0.5, (b - a) * 0.5)

func load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		# 匯出版（.pck）裡 PNG 會被轉成匯入資源，改用 ResourceLoader 讀取
		if ResourceLoader.exists(path):
			var t = load(path)
			if t is Texture2D:
				var im: Image = t.get_image()
				if im != null and im.is_compressed():
					im.decompress()
				return im
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(bytes) != OK:
		return null
	return img

func tex(name: String) -> Texture2D:
	if textures.has(name):
		return textures[name]
	var img := load_image("res://textures/%s.png" % name)
	var t: Texture2D = null
	if img:
		t = ImageTexture.create_from_image(img)
	textures[name] = t
	return t

var cameos := {}

func cameo(key: String):
	if cameos.has(key):
		return cameos[key]
	var out = null
	var img := load_image("res://cameos/%s.png" % key)
	if img != null:
		var t := ImageTexture.create_from_image(img)
		var ti := load_image("res://cameos/%s_team.png" % key)
		out = [t, ImageTexture.create_from_image(ti) if ti != null else null]
	cameos[key] = out
	return out

func sheet(key: String) -> Sheet:
	if sheets.has(key):
		return sheets[key]
	var s: Sheet = null
	var jpath := "res://sprites/%s.json" % key
	if FileAccess.file_exists(jpath):
		var info = JSON.parse_string(FileAccess.get_file_as_string(jpath))
		var img := load_image("res://sprites/%s.png" % key)
		if info is Dictionary and img:
			s = Sheet.new()
			s.tex = ImageTexture.create_from_image(img)
			if info.get("team", false):
				var ti := load_image("res://sprites/%s_team.png" % key)
				if ti:
					s.team = ImageTexture.create_from_image(ti)
			s.n = int(info.n)
			s.cw = int(info.cw)
			s.ch = int(info.ch)
			s.cols = int(info.cols)
			s.ax = float(info.ax)
			s.ay = float(info.ay)
			s.dirs = int(info.get("dirs", 0))
			s.poses = int(info.get("poses", 1))
			s.res = float(info.get("res", 1.0))
	sheets[key] = s
	return s

func mission_done(mid: String) -> bool:
	return mid in str(settings.get("campaign_done", "")).split(",")

func mark_mission_done(mid: String):
	if mission_done(mid):
		return
	var cur := str(settings.get("campaign_done", ""))
	settings["campaign_done"] = (cur + "," + mid) if cur != "" else mid
	save_settings()

func mission_unlocked(mid: String) -> bool:
	var MS = load("res://scripts/missions.gd")
	var prev := ""
	for m in MS.LIST:
		if m.id == mid:
			return prev == "" or mission_done(prev) or settings.get("unlock_all", false)
		if m.get("camp", "basic") == MS.find(mid).get("camp", "basic"):
			prev = m.id
	return true

func next_mission(mid: String) -> String:
	var MS = load("res://scripts/missions.gd")
	var camp = MS.find(mid).get("camp", "basic")
	var found := false
	for m in MS.LIST:
		if found and m.get("camp", "basic") == camp:
			return m.id
		if m.id == mid:
			found = true
	return ""

func fmt_money(v: float) -> String:
	var s := str(int(v))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0 and s[i - 1] != "-":
			out = "," + out
	return out

func angle_to_angle(from: float, to: float, max_step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	if absf(d) <= max_step:
		return to
	return from + signf(d) * max_step

func adiff(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))

func load_settings():
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		for k in ["sfx_vol", "voice_vol", "music_vol", "edge_scroll", "faction", "country", "scroll_speed", "intro_seen", "campaign_done", "unlock_all", "mapsize", "menu_bg", "tips_count", "left_pan"]:
			if cf.has_section_key("s", k):
				settings[k] = cf.get_value("s", k)

func save_settings():
	var cf := ConfigFile.new()
	for k in ["sfx_vol", "voice_vol", "music_vol", "edge_scroll", "faction", "country", "scroll_speed", "intro_seen", "campaign_done", "unlock_all", "mapsize", "menu_bg", "tips_count", "left_pan"]:
		if settings.has(k):
			cf.set_value("s", k, settings[k])
	cf.save("user://settings.cfg")
