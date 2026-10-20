extends RefCounted
# 戰場委託（遭遇戰）：每隔幾分鐘指揮部發佈一項限時任務，完成可領取賞金
#   harv  獵殺採礦車   摧毀 2 台敵方採礦車
#   snipe 斬首行動     摧毀指定的敵方建築（會在地圖上標示）
#   kills 殲滅部隊     擊殺 N 個敵方單位
#   tech  奪取據點     用工程師佔領任一油井或科技建築
#   hold  鐵壁防線     期限內不損失任何建築

var game
var next_t := 240.0
var cur := {}              # 目前任務；空字典＝沒有任務
var done := 0
var failed := 0
var hist: Array = []

const TYPES := ["harv", "snipe", "kills", "tech", "hold"]

func setup(g):
	game = g
	next_t = 240.0 + randf() * 60.0

func active() -> bool:
	return not cur.is_empty()

func update(_dt: float):
	if game.human == null or not game.human.alive:
		return
	if active():
		if cur.type == "snipe":
			var t = cur.target
			if cur.get("hit", false) or not is_instance_valid(t) or t.dead:
				if cur.get("hit", false):
					complete()
				else:
					cancel("目標已不存在")
				return
			if t.player == game.human:
				complete()   # 被我方工程師佔領也算
				return
			if not game.human.is_enemy_of(t.player):
				cancel("目標已非敵軍")
				return
		if cur.type == "hold" and game.time >= float(cur.until):
			complete()
			return
		if game.time >= float(cur.until):
			fail()
		return
	if game.time >= next_t:
		offer()

func offer(force := ""):
	if force != "" and not can_offer(force):
		return
	var opts := []
	for t in TYPES:
		if hist.size() > 0 and hist[-1] == t:
			continue
		if can_offer(t):
			opts.append(t)
	if opts.is_empty():
		next_t = game.time + 60.0
		return
	var t: String = force if force != "" else opts[randi() % opts.size()]
	hist.append(t)
	cur = {"type": t, "start": game.time, "n": 0}
	match t:
		"harv":
			cur.need = 2
			cur.until = game.time + 210.0
			cur.reward = 2500
			cur.name = "獵殺採礦車"
			cur.desc = "摧毀 2 台敵方採礦車"
		"snipe":
			var b = pick_snipe()
			if b == null:
				cur = {}
				return
			cur.target = b
			cur.until = game.time + 240.0
			cur.reward = 2000 + int(float(b.def.cost) * 0.6)
			cur.name = "斬首行動"
			cur.desc = "摧毀敵方「%s」" % b.def.name
			game.reveal(b.pos, 4.0)
			game.ping(b.pos)
		"kills":
			cur.need = 10 + int(game.time / 120.0)
			cur.until = game.time + 150.0
			cur.reward = 150 * int(cur.need)
			cur.name = "殲滅部隊"
			cur.desc = "擊殺 %d 個敵方單位" % int(cur.need)
		"tech":
			cur.until = game.time + 200.0
			cur.reward = 2000
			cur.name = "奪取據點"
			cur.desc = "用工程師佔領任一油井或科技建築"
		"hold":
			cur.until = game.time + 150.0
			cur.reward = 1500
			cur.name = "鐵壁防線"
			cur.desc = "150 秒內不損失任何建築"
			cur.bld_lost = int(game.human.stats.get("bld_lost", 0))
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  CONTRACT offer t=%d %s %s" % [int(game.time), cur.name, cur.desc])
	Sfx.play("radio", -4.0)
	game.message("【戰場委託】%s：%s，賞金 $%s" % [cur.name, cur.desc, G.fmt_money(cur.reward)])

func can_offer(t: String) -> bool:
	match t:
		"harv":
			for u in game.units:
				if not u.dead and u.def.get("harvester", false) and game.human.is_enemy_of(u.player):
					return true
			return false
		"snipe":
			return pick_snipe() != null
		"tech":
			for b in game.buildings:
				if not b.dead and b.def.role in ["oil", "techb"] and b.player != game.human:
					return true
			return false
	return true

func pick_snipe():
	var cands := []
	for b in game.buildings:
		if b.dead or not game.human.is_enemy_of(b.player) or b.player.neutral:
			continue
		if b.def.role in ["power", "radar", "ref", "dronehub", "bank", "tech", "bar"]:
			cands.append(b)
	if cands.is_empty():
		return null
	return cands[randi() % cands.size()]

func progress_text() -> String:
	if not active():
		return ""
	var rem := int(maxf(0.0, float(cur.until) - game.time))
	var p := ""
	match cur.type:
		"harv", "kills":
			p = " %d/%d" % [int(cur.n), int(cur.need)]
	return "委託：%s%s ｜ $%s ｜ %02d:%02d" % [cur.desc, p, G.fmt_money(cur.reward), rem / 60, rem % 60]

# ── 事件掛勾 ──
func on_death(e):
	if not active():
		return
	var killer = e.last_attacker
	var by_human: bool = killer != null and is_instance_valid(killer) and killer.player == game.human
	match cur.type:
		"harv":
			if by_human and e.kind == "unit" and e.def.get("harvester", false) and game.human.is_enemy_of(e.player):
				cur.n += 1
				if int(cur.n) >= int(cur.need):
					complete()
		"kills":
			if by_human and e.kind == "unit" and game.human.is_enemy_of(e.player):
				cur.n += 1
				if int(cur.n) >= int(cur.need):
					complete()
		"snipe":
			if e == cur.target:
				cur.hit = true
		"hold":
			if e.kind == "building" and e.player == game.human and not e.def.get("wall", false):
				fail()

func on_capture(p, b):
	if active() and cur.type == "tech" and p == game.human and b.def.role in ["oil", "techb"]:
		complete()

func complete():
	var r: int = int(cur.reward)
	game.human.money += r
	done += 1
	if not game.settings.get("auto", false):
		load("res://scripts/records.gd").bump("contracts")
	Sfx.play("cash", -2.0)
	game.message("【委託完成】%s！獲得賞金 $%s" % [cur.name, G.fmt_money(r)])
	finish()

func fail():
	failed += 1
	game.message("【委託失敗】%s" % cur.name)
	finish()

func cancel(why: String):
	game.message("【委託取消】%s（%s）" % [cur.name, why])
	finish()

func finish():
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  CONTRACT end t=%d done=%d failed=%d" % [int(game.time), done, failed])
	cur = {}
	next_t = game.time + 150.0 + randf() * 90.0
