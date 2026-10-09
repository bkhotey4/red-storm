extends RefCounted
# 混合戰爭隨機時事事件（遭遇戰）：制裁、駭客、輿論、油價、軍援、罷工……
# 每 2~4 分鐘一則，RSN 快訊橫幅顯示，影響 45~90 秒；也可能發生在 AI 身上。

var game
var next_t := 150.0
var active: Array = []     # {id, name, until, target}
var banner := ""
var banner_t := 0.0
var cost_mod := {}         # player index -> 造價倍率
var speed_mod := {}        # player index -> 生產速度倍率
var hist: Array = []

const EVENTS := [
	{"id": "sanction", "name": "國際制裁", "dur": 60.0, "news": "安理會通過對 %s 的新一輪制裁，礦石出口收入銳減。", "bad": true},
	{"id": "hack", "name": "電網遭駭", "dur": 40.0, "news": "%s 電網遭到大規模網路攻擊，多座電廠離線。", "bad": true},
	{"id": "strike", "name": "軍工罷工", "dur": 70.0, "news": "%s 軍工廠工人罷工，裝備交付延宕。", "bad": true},
	{"id": "inflate", "name": "貨幣貶值", "dur": 75.0, "news": "%s 貨幣對美元重挫，進口裝備成本飆升 30%%。", "bad": true},
	{"id": "aid", "name": "軍事援助", "dur": 0.0, "news": "盟國軍援抵達 %s：一批現金與裝備已到位。", "bad": false},
	{"id": "oil", "name": "油價飆漲", "dur": 80.0, "news": "中東局勢緊張，油價飆漲，%s 的油井收入倍增。", "bad": false},
	{"id": "boom", "name": "軍工訂單", "dur": 70.0, "news": "%s 獲得大筆軍工訂單，生產線全速運轉。", "bad": false},
	{"id": "opinion", "name": "輿論風向", "dur": 90.0, "news": "國際輿論轉向，%s 短期內難以締結新條約。", "bad": true},
	{"id": "leak", "name": "情報外洩", "dur": 0.0, "news": "駭客公開了 %s 的衛星影像，敵方部署一覽無遺。", "bad": true},
	{"id": "ceasefire", "name": "人道停火", "dur": 45.0, "news": "聯合國斡旋達成 45 秒人道停火，各方暫停炮火。", "bad": false, "global": true},
]

func setup(g):
	game = g
	next_t = 120.0 + randf() * 90.0

func enabled() -> bool:
	return game.mission == null and game.settings.get("events", true)

func update(dt: float):
	banner_t = maxf(0.0, banner_t - dt)
	# 事件到期
	for e in active.duplicate():
		if game.time >= float(e.until):
			end_event(e)
			active.erase(e)
	if not enabled():
		return
	if game.time >= next_t:
		next_t = game.time + 120.0 + randf() * 120.0
		fire_random()

func cost_mult(p) -> float:
	return float(cost_mod.get(p.index, 1.0))

func speed_mult(p) -> float:
	return float(speed_mod.get(p.index, 1.0))

func show(txt: String):
	banner = txt
	banner_t = 14.0
	game.message("RSN 快訊：" + txt)
	Sfx.play("radio", -8.0)

func fire_random():
	var alive: Array = []
	for p in game.players:
		if not p.neutral and p.alive:
			alive.append(p)
	if alive.is_empty():
		return
	var ev: Dictionary = EVENTS[randi() % EVENTS.size()]
	# 避免連續同一事件
	if hist.size() > 0 and hist[-1] == ev.id:
		ev = EVENTS[randi() % EVENTS.size()]
	var target = alive[randi() % alive.size()]
	# 讓玩家稍微多一點好事、少一點壞事（簡單難度）
	var diff: int = int(game.settings.get("difficulty", 1))
	if target == game.human and ev.get("bad", false) and diff == 0 and randf() < 0.5:
		target = alive[randi() % alive.size()]
	fire(ev, target)

func fire(ev: Dictionary, target):
	hist.append(ev.id)
	var nm: String = target.country_name() if target.country_name() != "" else target.name
	var e := {"id": ev.id, "name": ev.name, "until": game.time + float(ev.dur), "target": target}
	match ev.id:
		"sanction":
			target.sanctioned_until = maxf(target.sanctioned_until, game.time + float(ev.dur))
		"hack":
			target.energy_cut_until = maxf(target.energy_cut_until, game.time + float(ev.dur))
			target.power_dirty = true
		"strike":
			speed_mod[target.index] = 0.55
		"inflate":
			cost_mod[target.index] = 1.3
		"aid":
			target.money += 1500.0 + 500.0 * randi_range(0, 3)
			var pre: String = "a_" if target.faction == "allies" else "s_"
			var ids := [pre + "tank", pre + "tank", pre + ("ifv" if target.faction == "allies" else "flaktrk")]
			var cy = null
			for b in game.buildings:
				if b.player == target and not b.dead and b.def.role == "cy":
					cy = b
			if cy != null:
				for id in ids:
					if Defs.UNITS.has(id):
						game.spawn_unit(target, id, cy.pos + Vector2(randf_range(-2.0, 2.0), 3.5))
		"oil":
			e["oil_bonus"] = true
		"boom":
			speed_mod[target.index] = 1.5
		"opinion":
			target.no_treaty_until = game.time + float(ev.dur)
		"leak":
			# 揭露目標所有建築給人類玩家（若目標是人類，則敵人 AI 得到位置 → 以提前攻擊表示）
			if target != game.human:
				for b in game.buildings:
					if b.player == target and not b.dead:
						game.reveal(b.pos, 5.0)
			else:
				for ai in game.ais:
					ai.next_attack = minf(ai.next_attack, game.time + 30.0)
		"ceasefire":
			for p in game.players:
				if not p.neutral:
					for q in game.players:
						if q != p and not q.neutral and p.is_enemy_of(q):
							p.ceasefire[q.index] = game.time + float(ev.dur)
	if float(ev.dur) > 0.0:
		active.append(e)
	var txt: String = ev.news % nm if ev.news.contains("%s") else ev.news
	show(txt)

func end_event(e: Dictionary):
	var target = e.target
	match e.id:
		"strike", "boom":
			speed_mod.erase(target.index)
		"inflate":
			cost_mod.erase(target.index)
	if target == game.human or e.get("global", false):
		game.message("RSN：「%s」事件結束" % e.name)

func oil_bonus(p) -> float:
	for e in active:
		if e.id == "oil" and e.target == p:
			return 2.0
	return 1.0

func status_lines() -> Array:
	var out := []
	for e in active:
		var rem := int(float(e.until) - game.time)
		var who: String = e.target.country_name() if e.target.country_name() != "" else e.target.name
		out.append("%s（%s）%02d:%02d" % [e.name, who, rem / 60, rem % 60])
	return out
