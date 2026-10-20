extends RefCounted
# 動態天氣（遭遇戰）：依地圖主題輪替晴天與惡劣天氣，影響移動速度、武器射程與空中單位
#   rain 大雨   ：遠程武器射程 -10%
#   fog  濃霧   ：遠程武器射程 -25%
#   storm 雷雨  ：遠程武器射程 -15%，空中單位速度 -25%，偶爾落雷
#   snow 大雪   ：地面單位速度 -12%
#   blizzard 暴風雪：地面單位速度 -25%，遠程射程 -20%，空中單位速度 -30%
#   sand 沙塵暴 ：遠程射程 -25%，地面速度 -10%，空中單位速度 -30%

const KINDS := {
	"clear": {"name": "晴朗", "range": 1.0, "ground": 1.0, "air": 1.0},
	"rain": {"name": "大雨", "range": 0.9, "ground": 1.0, "air": 1.0, "desc": "遠程武器射程 -10%"},
	"fog": {"name": "濃霧", "range": 0.75, "ground": 1.0, "air": 1.0, "desc": "遠程武器射程 -25%"},
	"storm": {"name": "雷雨", "range": 0.85, "ground": 1.0, "air": 0.75, "desc": "遠程射程 -15%、飛機與無人機速度 -25%，小心落雷"},
	"snow": {"name": "大雪", "range": 1.0, "ground": 0.88, "air": 1.0, "desc": "地面部隊速度 -12%"},
	"blizzard": {"name": "暴風雪", "range": 0.8, "ground": 0.75, "air": 0.7, "desc": "地面速度 -25%、遠程射程 -20%、空中速度 -30%"},
	"sand": {"name": "沙塵暴", "range": 0.75, "ground": 0.9, "air": 0.7, "desc": "遠程射程 -25%、地面速度 -10%、空中速度 -30%"},
}
const BY_THEME := {
	"temperate": ["rain", "rain", "fog", "storm"],
	"tropical": ["rain", "storm", "storm", "fog"],
	"snow": ["snow", "snow", "blizzard", "fog"],
	"desert": ["sand", "sand", "storm"],
}
const LONG_RANGE := 6.5     # 射程超過此值的武器才受天氣影響

var game
var cur := "clear"
var until := 0.0
var fade := 0.0            # 0..1 畫面效果強度（漸入漸出）
var bolt_t := 0.0
var flash := 0.0
var drops: Array = []

func setup(g):
	game = g
	cur = "clear"
	until = 200.0 + randf() * 160.0
	for k in 160:
		drops.append(Vector2(randf(), randf()))

func update(dt: float):
	var target_fade := 0.0 if cur == "clear" else 1.0
	fade = move_toward(fade, target_fade, dt / 6.0)
	flash = maxf(0.0, flash - dt)
	if game.time >= until:
		if cur == "clear":
			var opts: Array = BY_THEME.get(game.map.theme, ["rain"])
			cur = opts[randi() % opts.size()]
			until = game.time + 90.0 + randf() * 90.0
			Sfx.play("radio", -8.0)
			game.message("氣象警報：%s 來襲（%s）" % [KINDS[cur].name, KINDS[cur].desc])
		else:
			game.message("氣象：%s 已經過去，天氣轉晴" % KINDS[cur].name)
			cur = "clear"
			until = game.time + 220.0 + randf() * 200.0
	if cur == "storm":
		bolt_t -= dt
		if bolt_t <= 0.0:
			bolt_t = randf_range(6.0, 14.0)
			strike()

# 雷雨隨機落雷：打在地圖某處，對附近單位造成少量傷害
func strike():
	var p := Vector2(randf_range(4, game.W - 4), randf_range(4, game.H - 4))
	if randf() < 0.5 and not game.units.is_empty():
		var u = game.units[randi() % game.units.size()]
		if is_instance_valid(u) and not u.dead and u.ukind != "ship":
			p = u.pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
	game.fx.lightning(p)
	flash = 0.3
	Sfx.play("zap", -6.0)
	game.damage_area(p, 1.0, 120.0, "elec", null, null, null, true)

func range_mult(rng: float) -> float:
	if rng < LONG_RANGE:
		return 1.0
	return lerpf(1.0, float(KINDS[cur].range), fade)

func speed_mult(u) -> float:
	var k: String = "air" if u.ukind == "air" else ("ground" if u.ukind != "ship" else "")
	if k == "":
		return 1.0
	return lerpf(1.0, float(KINDS[cur][k]), fade)

func status_text() -> String:
	if cur == "clear":
		return ""
	var rem := int(maxf(0.0, until - game.time))
	return "天氣：%s %02d:%02d" % [KINDS[cur].name, rem / 60, rem % 60]

# 螢幕空間的天氣效果（由 HUD 在最底層呼叫）
func draw_screen(ci: CanvasItem, vs: Vector2, w: float, t: float):
	if fade <= 0.01:
		return
	var a := fade
	match cur:
		"rain", "storm":
			ci.draw_rect(Rect2(0, 0, w, vs.y), Color(0.05, 0.08, 0.14, 0.22 * a))
			for d in drops:
				var x: float = fposmod(d.x * w + t * 120.0, w)
				var y: float = fposmod(d.y * vs.y + t * 900.0, vs.y)
				ci.draw_line(Vector2(x, y), Vector2(x - 5, y + 22), Color(0.7, 0.8, 0.95, 0.35 * a), 1.2)
			if flash > 0.0:
				ci.draw_rect(Rect2(0, 0, w, vs.y), Color(0.9, 0.95, 1.0, flash * a))
		"snow", "blizzard":
			var wind := 220.0 if cur == "blizzard" else 40.0
			ci.draw_rect(Rect2(0, 0, w, vs.y), Color(0.85, 0.9, 1.0, (0.18 if cur == "blizzard" else 0.08) * a))
			for i in drops.size():
				var d: Vector2 = drops[i]
				var x: float = fposmod(d.x * w + t * wind + sin(t * 1.5 + i) * 12.0, w)
				var y: float = fposmod(d.y * vs.y + t * (90.0 + (i % 5) * 18.0), vs.y)
				ci.draw_circle(Vector2(x, y), 1.4 + (i % 3) * 0.7, Color(1, 1, 1, 0.75 * a))
		"sand":
			ci.draw_rect(Rect2(0, 0, w, vs.y), Color(0.75, 0.55, 0.3, 0.24 * a))
			for i in drops.size():
				var d: Vector2 = drops[i]
				var x: float = fposmod(d.x * w + t * 520.0, w)
				var y: float = fposmod(d.y * vs.y + sin(t + i) * 20.0, vs.y)
				ci.draw_line(Vector2(x, y), Vector2(x - 26, y + 3), Color(0.9, 0.75, 0.5, 0.3 * a), 1.5)
		"fog":
			ci.draw_rect(Rect2(0, 0, w, vs.y), Color(0.78, 0.8, 0.82, 0.3 * a))
			for i in 6:
				var cx: float = fposmod(i * w / 6.0 + t * 14.0, w + 400.0) - 200.0
				var cy: float = vs.y * (0.2 + 0.13 * i)
				ci.draw_circle(Vector2(cx, cy), 220.0, Color(0.85, 0.87, 0.9, 0.08 * a))

func save_state() -> Dictionary:
	return {"cur": cur, "until": until, "fade": fade}

func load_state(d: Dictionary):
	cur = str(d.get("cur", "clear"))
	if not KINDS.has(cur):
		cur = "clear"
	until = float(d.get("until", until))
	fade = float(d.get("fade", 0.0))
