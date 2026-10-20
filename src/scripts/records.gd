extends RefCounted
# 戰績統計與成就：累積資料存在 user://records.cfg
# 用法：RecS.get_rec() 讀取字典；RecS.on_game_end(game, win) 累計並檢查成就

const PATH := "user://records.cfg"
const KEYS := ["games", "wins", "losses", "built", "killed", "lost", "bld_lost", "harvested", "spies", "powers",
	"treaties", "missions", "play_time", "best_win", "max_kills", "carriers", "drones", "walls_broken", "countries", "maps", "ach", "streak", "best_streak", "nukes_survived", "best_wave", "koth_wins", "contracts", "techs", "daily_date", "daily_best", "daily_wins"]

const ACH := [
	{"id": "first_blood", "name": "初次勝利", "desc": "贏得第一場遭遇戰或任務", "icon": "★"},
	{"id": "veteran", "name": "沙場老兵", "desc": "累計打完 10 場戰鬥", "icon": "⚔"},
	{"id": "commander", "name": "指揮官", "desc": "累計贏得 25 場戰鬥", "icon": "✪"},
	{"id": "hundred", "name": "百人斬", "desc": "累計消滅 100 個敵軍單位", "icon": "☠"},
	{"id": "thousand", "name": "鋼鐵風暴", "desc": "累計消滅 1,000 個敵軍單位", "icon": "☢"},
	{"id": "builder", "name": "軍工複合體", "desc": "累計生產 500 個單位", "icon": "⚙"},
	{"id": "tycoon", "name": "礦業大亨", "desc": "累計採礦收入達 $500,000", "icon": "$"},
	{"id": "blitz", "name": "閃電戰", "desc": "在 10 分鐘內贏得一場戰鬥", "icon": "⚡"},
	{"id": "spymaster", "name": "諜報大師", "desc": "成功滲透敵軍建築 10 次", "icon": "◉"},
	{"id": "super", "name": "超級武器", "desc": "發射特殊武器 20 次", "icon": "✦"},
	{"id": "diplomat", "name": "外交官", "desc": "締結 5 次條約", "icon": "✎"},
	{"id": "admiral", "name": "航母打擊群", "desc": "建造 5 艘航空母艦", "icon": "⚓"},
	{"id": "swarm", "name": "蜂群", "desc": "生產 100 架無人機", "icon": "✈"},
	{"id": "globetrotter", "name": "環球部署", "desc": "使用 6 個不同國家作戰", "icon": "✈"},
	{"id": "explorer", "name": "戰場探勘", "desc": "在 10 張不同地圖作戰", "icon": "⌖"},
	{"id": "campaign_basic", "name": "基礎戰役完成", "desc": "完成基礎戰役全部任務", "icon": "✔"},
	{"id": "campaign_hybrid", "name": "混合戰爭英雄", "desc": "完成混合戰爭戰役全部任務", "icon": "✔"},
	{"id": "streak5", "name": "連勝 5 場", "desc": "連續贏得 5 場戰鬥", "icon": "✪"},
	{"id": "ironwall", "name": "鐵壁", "desc": "贏得一場戰鬥且未損失任何建築", "icon": "▣"},
	{"id": "massacre", "name": "殲滅戰", "desc": "單場消滅 150 個敵軍單位", "icon": "☠"},
	{"id": "holdout", "name": "堅守陣線", "desc": "生存模式撐過 10 波", "icon": "▲"},
	{"id": "survivor", "name": "最後防線", "desc": "生存模式擊退全部 25 波敵軍", "icon": "♛"},
	{"id": "king", "name": "山丘之王", "desc": "贏得一場據點爭奪", "icon": "⚑"},
	{"id": "daily", "name": "日日精進", "desc": "贏得一次每日挑戰", "icon": "☀"},
	{"id": "merc", "name": "傭兵本色", "desc": "累計完成 10 項戰場委託", "icon": "✉"},
	{"id": "techlord", "name": "科技掠奪者", "desc": "累計佔領 10 座科技建築", "icon": "⚙"},
]

static var _rec: Dictionary = {}
static var _loaded := false

static func get_rec() -> Dictionary:
	if not _loaded:
		_loaded = true
		_rec = {}
		for k in KEYS:
			_rec[k] = ""
		for k in KEYS:
			if k in ["countries", "maps", "ach"]:
				_rec[k] = ""
			elif k in ["play_time", "harvested"]:
				_rec[k] = 0.0
			else:
				_rec[k] = 0
		_rec["best_win"] = 0.0
		var cf := ConfigFile.new()
		if cf.load(PATH) == OK:
			for k in KEYS:
				if cf.has_section_key("r", k):
					_rec[k] = cf.get_value("r", k)
	return _rec

static func save():
	var cf := ConfigFile.new()
	for k in KEYS:
		cf.set_value("r", k, _rec.get(k, 0))
	cf.save(PATH)

static func has_ach(id: String) -> bool:
	return id in str(get_rec().ach).split(",")

static func add_list(key: String, v: String):
	var r := get_rec()
	var cur := str(r[key])
	if v in cur.split(","):
		return
	r[key] = (cur + "," + v) if cur != "" else v

static func list_count(key: String) -> int:
	var cur := str(get_rec()[key])
	return 0 if cur == "" else cur.split(",").size()

static func bump(key: String, n: float = 1.0):
	var r := get_rec()
	if r[key] is float:
		r[key] = float(r[key]) + n
	else:
		r[key] = int(r[key]) + int(n)

# 回傳本次新解鎖的成就清單
static func on_game_end(game, win: bool) -> Array:
	var r := get_rec()
	var h = game.human
	var st: Dictionary = h.stats
	r.games = int(r.games) + 1
	if win:
		r.wins = int(r.wins) + 1
		r.streak = int(r.streak) + 1
		r.best_streak = maxi(int(r.best_streak), int(r.streak))
		if float(r.best_win) <= 0.0 or game.time < float(r.best_win):
			r.best_win = game.time
	else:
		r.losses = int(r.losses) + 1
		r.streak = 0
	r.built = int(r.built) + int(st.get("built", 0))
	r.killed = int(r.killed) + int(st.get("killed", 0))
	r.lost = int(r.lost) + int(st.get("lost", 0))
	r.bld_lost = int(r.bld_lost) + int(st.get("bld_lost", 0))
	r.harvested = float(r.harvested) + float(st.get("harvested", 0))
	r.play_time = float(r.play_time) + game.time
	r.max_kills = maxi(int(r.max_kills), int(st.get("killed", 0)))
	var daily := int(game.settings.get("daily", 0))
	if daily > 0 and win:
		r.daily_wins = int(r.daily_wins) + 1
		if int(r.daily_date) != daily or float(r.daily_best) <= 0.0 or game.time < float(r.daily_best):
			r.daily_date = daily
			r.daily_best = game.time
	var gm = game.get("gmode")
	var surv_waves := 0
	if gm != null and gm.is_survival():
		surv_waves = gm.wave - (0 if gm.cleared else 1)
		r.best_wave = maxi(int(r.best_wave), surv_waves)
	if gm != null and gm.is_koth() and win:
		r.koth_wins = int(r.koth_wins) + 1
	if game.mission != null and win:
		add_list("maps", "mission_" + str(game.mission.id))
	else:
		add_list("maps", str(game.settings.get("map", {}).get("name", "?")))
	add_list("countries", str(h.country))
	var fresh := []
	var MS = load("res://scripts/missions.gd")
	var basic_all := true
	var hybrid_all := true
	for m in MS.LIST:
		if not G.mission_done(m.id):
			if m.get("camp", "basic") == "hybrid":
				hybrid_all = false
			else:
				basic_all = false
	var cond := {
		"first_blood": int(r.wins) >= 1,
		"veteran": int(r.games) >= 10,
		"commander": int(r.wins) >= 25,
		"hundred": int(r.killed) >= 100,
		"thousand": int(r.killed) >= 1000,
		"builder": int(r.built) >= 500,
		"tycoon": float(r.harvested) >= 500000.0,
		"blitz": win and game.time <= 600.0,
		"spymaster": int(r.spies) >= 10,
		"super": int(r.powers) >= 20,
		"diplomat": int(r.treaties) >= 5,
		"admiral": int(r.carriers) >= 5,
		"swarm": int(r.drones) >= 100,
		"globetrotter": list_count("countries") >= 6,
		"explorer": list_count("maps") >= 10,
		"campaign_basic": basic_all,
		"campaign_hybrid": hybrid_all,
		"streak5": int(r.streak) >= 5,
		"ironwall": win and int(st.get("bld_lost", 0)) == 0 and game.time > 120.0,
		"massacre": int(st.get("killed", 0)) >= 150,
		"holdout": int(r.best_wave) >= 10,
		"survivor": gm != null and gm.is_survival() and win,
		"king": int(r.koth_wins) >= 1,
		"merc": int(r.contracts) >= 10,
		"daily": int(r.daily_wins) >= 1,
		"techlord": int(r.techs) >= 10,
	}
	for a in ACH:
		if not has_ach(a.id) and cond.get(a.id, false):
			add_list("ach", a.id)
			fresh.append(a)
	save()
	return fresh

static func find_ach(id: String) -> Dictionary:
	for a in ACH:
		if a.id == id:
			return a
	return {}

static func fmt_time(t: float) -> String:
	var s := int(t)
	if s >= 3600:
		return "%d 時 %02d 分" % [s / 3600, (s % 3600) / 60]
	return "%d 分 %02d 秒" % [s / 60, s % 60]

static func win_rate() -> String:
	var r := get_rec()
	if int(r.games) == 0:
		return "—"
	return "%d%%" % int(round(100.0 * int(r.wins) / int(r.games)))
