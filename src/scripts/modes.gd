extends RefCounted
# 遭遇戰特殊模式
#   survival：生存模式 —— 敵軍沒有基地，從地圖邊緣一波波湧入，每 5 波一次首領波，撐過 25 波即勝利
#   koth    ：據點爭奪 —— 地圖中央有一座指揮所，獨佔據點累積控制點數，先到 KOTH_GOAL 者勝（也可殲滅取勝）

const SURV_GOAL := 25
const KOTH_GOAL := 300.0
const KOTH_OPEN := 150.0     # 開局 2:30 後指揮所才開放計分
const KOTH_R := 3.5

var game
var kind := ""

# ── 生存模式 ──
var wave := 0
var next_wave_t := 180.0
var wave_units: Array = []
var cleared := true
var order_t := 0.0
var src_i := 0

# ── 據點爭奪 ──
var hill := Vector2.ZERO
var score := {}            # team -> 控制點數
var owner_team := -99      # 目前控制的隊伍（-99 無人、-1 爭奪中）
var tick_t := 0.0
var warned := {}

func setup(g, k: String):
	game = g
	kind = k
	if kind == "survival":
		next_wave_t = 180.0
		game.objective = ""
		game.message("生存模式：敵軍將在 03:00 後開始進攻，撐過 %d 波即可獲勝！" % SURV_GOAL)
	elif kind == "koth":
		hill = find_hill_spot()
		for p in game.players:
			if not p.neutral:
				score[p.team] = 0.0
		game.reveal(hill, KOTH_R + 2.0)
		game.message("據點爭奪：中央指揮所 02:30 後開放，獨佔累積 %d 點即獲勝，控制方每秒額外 +$10" % int(KOTH_GOAL))

# 從地圖中央往外找一塊沒有礦石、可通行的空地放指揮所（避免採礦車被捲入）
func find_hill_spot() -> Vector2:
	var cx: int = game.W / 2
	var cy: int = game.H / 2
	var m = game.map
	for r in 25:
		for y in range(cy - r, cy + r + 1):
			for x in range(cx - r, cx + r + 1):
				if maxi(absi(x - cx), absi(y - cy)) != r:
					continue
				var ok := true
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var xx := x + dx
						var yy := y + dy
						if not m.inb(xx, yy) or m.has_ore(xx, yy) or (absi(dx) <= 1 and absi(dy) <= 1 and not m.passable(xx, yy)):
							ok = false
				if ok:
					return Vector2(x, y) + Vector2(0.5, 0.5)
	var c: Vector2i = game.nearest_free(Vector2i(cx, cy), 20)
	return Vector2(c) + Vector2(0.5, 0.5)

func is_survival() -> bool:
	return kind == "survival"

func is_koth() -> bool:
	return kind == "koth"

func update(dt: float):
	if kind == "survival":
		update_survival(dt)
	elif kind == "koth":
		update_koth(dt)

# 遊戲結束判定：回傳 "win" / "lose" / ""
func check() -> String:
	if kind == "survival":
		if not game.human.alive:
			return "lose"
		if wave >= SURV_GOAL and cleared:
			return "win"
	elif kind == "koth":
		for t in score:
			if float(score[t]) >= KOTH_GOAL:
				return "win" if t == game.human.team else "lose"
	return ""

# ───────────────────────── 生存模式 ─────────────────────────
func enemy_players() -> Array:
	var out := []
	for p in game.players:
		if not p.neutral and p != game.human and p.team != game.human.team:
			out.append(p)
	return out

func update_survival(dt: float):
	wave_units = wave_units.filter(func(u): return is_instance_valid(u) and not u.dead)
	if not cleared and wave_units.is_empty():
		cleared = true
		var bonus := 400 + 120 * wave
		game.human.money += bonus
		Sfx.play("cash", -4.0)
		game.message("第 %d 波已擊退！獲得獎勵 $%s" % [wave, G.fmt_money(bonus)])
		if OS.get_cmdline_user_args().has("--autotest"):
			print("  CLEARED wave %d t=%d" % [wave, int(game.time)])
		if wave < SURV_GOAL:
			next_wave_t = minf(next_wave_t, game.time + 25.0)
	if wave < SURV_GOAL and game.time >= next_wave_t:
		spawn_wave()
	order_t -= dt
	if order_t <= 0.0:
		order_t = 4.0
		drive_units()
	var rem := int(maxf(0.0, next_wave_t - game.time))
	if wave >= SURV_GOAL:
		game.objective = "生存模式：最終波！剩餘敵軍 %d" % wave_units.size()
	elif wave == 0:
		game.objective = "生存模式：第一波 %02d:%02d 後來襲" % [rem / 60, rem % 60]
	else:
		game.objective = "生存 第 %d/%d 波 ｜ 下一波 %02d:%02d ｜ 敵軍 %d" % [wave, SURV_GOAL, rem / 60, rem % 60, wave_units.size()]
	if wave > 0 and rem == 10 and not warned.has(wave):
		warned[wave] = true
		game.message("警告：第 %d 波敵軍 10 秒後抵達！" % (wave + 1))
		Sfx.play("alarm", -6.0)

func unit_pool(p) -> Array:
	var out := []
	for id in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[id]
		if d.faction != p.faction or d.get("buildable", true) == false:
			continue
		if d.has("country") and d.country != p.country:
			continue
		if not d.cat in ["infantry", "vehicle", "air"]:
			continue
		if d.get("harvester", false) or d.has("mcv") or d.get("engineer", false) or d.get("spy", false) or d.get("jet", false):
			continue
		if d.has("limit") or d.has("carrier") or str(d.get("weapon", "")) == "":
			continue
		out.append(id)
	return out

func spawn_wave():
	wave += 1
	cleared = false
	next_wave_t = game.time + minf(70.0 + wave * 2.0, 110.0)
	var srcs := enemy_players()
	if srcs.is_empty():
		return
	var p = srcs[src_i % srcs.size()]
	src_i += 1
	var diff := int(game.settings.get("difficulty", 1))
	var budget: float = (1000.0 + 650.0 * wave + 45.0 * wave * wave) * [0.7, 1.0, 1.35, 1.7][clampi(diff, 0, 3)]
	var pool := unit_pool(p)
	var max_cost := 450.0 + 260.0 * wave
	var cands := pool.filter(func(id):
		var d: Dictionary = Defs.UNITS[id]
		if d.cat == "air" and wave < 4:
			return false
		return float(d.cost) <= max_cost)
	if cands.is_empty():
		cands = pool
	var boss := wave % 5 == 0
	var picks := []
	if boss:
		# 首領：該陣營最昂貴的地面/空中單位，精英、血量加倍
		var sorted := pool.duplicate()
		sorted.sort_custom(func(a, b): return float(Defs.UNITS[a].cost) > float(Defs.UNITS[b].cost))
		for k in 1 + wave / 10:
			picks.append({"id": sorted[k % mini(3, sorted.size())], "boss": true})
			budget -= float(Defs.UNITS[sorted[k % mini(3, sorted.size())]].cost)
	var guard := 0
	while budget > 0.0 and guard < 60:
		guard += 1
		var id: String = cands[randi() % cands.size()]
		picks.append({"id": id, "boss": false})
		budget -= float(Defs.UNITS[id].cost)
	var origin := Vector2(p.start_cell) + Vector2(0.5, 0.5)
	var free: Array = game.free_cells_near(Vector2i(origin), picks.size() + 4)
	var i := 0
	for pk in picks:
		var at := origin
		if Defs.UNITS[pk.id].kind != "air" and i < free.size():
			at = Vector2(free[i]) + Vector2(0.5, 0.5)
			i += 1
		elif Defs.UNITS[pk.id].kind == "air":
			at = origin + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var u = game.spawn_unit(p, pk.id, at)
		if wave >= 15:
			u.rank = 2 if randf() < 0.5 else 1
		elif wave >= 8 and randf() < 0.5:
			u.rank = 1
		if pk.boss:
			u.rank = 2
			u.max_hp *= 1.4 + 0.04 * wave
			u.hp = u.max_hp
			u.set_meta("boss", true)
		wave_units.append(u)
	order_t = 0.0
	if boss:
		Sfx.play("alarm", -2.0)
		game.message("⚠ 首領波次！第 %d 波：%d 個敵軍單位，含精英重裝首領！" % [wave, picks.size()])
	else:
		Sfx.play("radio", -4.0)
		game.message("第 %d 波敵軍來襲：%d 個單位" % [wave, picks.size()])
	game.ping(origin)
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  WAVE %d t=%d units=%d boss=%s src=%s" % [wave, int(game.time), picks.size(), boss, p.name])

func human_target(from: Vector2):
	var best = null
	var bd := 1e9
	for b in game.buildings:
		if b.dead or b.player != game.human or b.def.get("wall", false):
			continue
		var d: float = b.pos.distance_to(from)
		if d < bd:
			bd = d
			best = b
	if best == null:
		for u in game.units:
			if u.dead or u.player != game.human:
				continue
			var d: float = u.pos.distance_to(from)
			if d < bd:
				bd = d
				best = u
	return best

func drive_units():
	for u in wave_units:
		if u.order != "idle" and u.order != "return_home" and u.order != "return":
			continue
		var t = human_target(u.pos)
		if t == null:
			return
		if u.ukind == "air":
			u.cmd_attack(t)
		else:
			u.cmd_move(t.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), true)

# ───────────────────────── 據點爭奪 ─────────────────────────
func update_koth(dt: float):
	tick_t -= dt
	if tick_t > 0.0:
		return
	tick_t = 1.0
	if game.time < KOTH_OPEN:
		var rem := int(KOTH_OPEN - game.time)
		game.objective = "據點爭奪：中央指揮所 %02d:%02d 後開放" % [rem / 60, rem % 60]
		if rem == 30:
			game.message("中央指揮所 30 秒後開放，派部隊前往佔領！")
			game.ping(hill)
		return
	var present := {}
	for u in game.units:
		if u.dead or u.player.neutral or u.ukind == "air" or u.def.get("harvester", false):
			continue
		if u.pos.distance_to(hill) <= KOTH_R:
			present[u.player.team] = true
	var prev := owner_team
	if present.size() == 1:
		owner_team = present.keys()[0]
	elif present.size() > 1:
		owner_team = -1
	else:
		owner_team = -99
	if owner_team >= 0:
		score[owner_team] = float(score.get(owner_team, 0.0)) + 1.0
		for p in game.players:
			if not p.neutral and p.alive and p.team == owner_team:
				p.money += 10.0
	if owner_team != prev and OS.get_cmdline_user_args().has("--autotest"):
		print("  HILL t=%d owner=%d score=%s" % [int(game.time), owner_team, str(score)])
	if owner_team != prev:
		if owner_team == game.human.team:
			game.message("我軍已佔領中央指揮所！")
			Sfx.play("radio", -4.0)
		elif owner_team >= 0:
			game.message("敵軍佔領了中央指揮所！")
			Sfx.play("alarm", -8.0)
			game.ping(hill)
		elif owner_team == -1 and prev >= 0:
			game.message("中央指揮所爭奪中！")
	var mine := float(score.get(game.human.team, 0.0))
	var best_e := 0.0
	for t in score:
		if t != game.human.team:
			best_e = maxf(best_e, float(score[t]))
	var st := "無人控制"
	if owner_team == game.human.team:
		st = "我方控制"
	elif owner_team == -1:
		st = "爭奪中"
	elif owner_team >= 0:
		st = "敵方控制"
	game.objective = "據點爭奪：我方 %d / 敵方 %d（目標 %d）・%s" % [int(mine), int(best_e), int(KOTH_GOAL), st]
	for t in score:
		var s := float(score[t])
		if int(s) == int(KOTH_GOAL) - 30 and not warned.has(t):
			warned[t] = true
			game.message(("我軍再控制 30 秒即可獲勝！" if t == game.human.team else "警告：敵軍再控制 30 秒就會獲勝！"))

# 世界座標下的據點圖示（由 overlay 呼叫）
func draw_world(ci: CanvasItem):
	if kind != "koth":
		return
	var col := Color(0.9, 0.9, 0.9)
	if owner_team == game.human.team:
		col = game.human.color
	elif owner_team == -1:
		col = Color(1.0, 0.85, 0.2)
	elif owner_team >= 0:
		for p in game.players:
			if not p.neutral and p.team == owner_team:
				col = p.color
				break
	var c: Vector2 = game.iso(hill)
	var pulse := 0.55 + 0.25 * sin(game.time * 3.0)
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48.0
		pts.append(c + Vector2(cos(a) * KOTH_R * G.HW * 1.414, sin(a) * KOTH_R * G.HH * 1.414))
	ci.draw_polyline(pts, Color(0, 0, 0, 0.5), 7.0)
	ci.draw_polyline(pts, Color(col.r, col.g, col.b, pulse + 0.2), 4.0)
	var inner := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		inner.append(c + Vector2(cos(a) * KOTH_R * G.HW * 1.414, sin(a) * KOTH_R * G.HH * 1.414))
	ci.draw_colored_polygon(inner, Color(col.r, col.g, col.b, 0.14))
	# 旗桿
	ci.draw_line(c, c + Vector2(0, -46), Color(0.2, 0.2, 0.2), 3.0)
	var wave_o := sin(game.time * 5.0) * 3.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -46), c + Vector2(26, -40 + wave_o), c + Vector2(0, -32)]), col)
	ci.draw_string(G.font_bold, c + Vector2(-40, 26), "中央指揮所", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color(1, 1, 1, 0.85))

func save_state() -> Dictionary:
	return {"kind": kind, "wave": wave, "next_wave_t": next_wave_t, "score": score, "owner": owner_team}

func load_state(d: Dictionary):
	wave = int(d.get("wave", 0))
	next_wave_t = float(d.get("next_wave_t", next_wave_t))
	owner_team = int(d.get("owner", -99))
	var sc: Dictionary = d.get("score", {})
	for k in sc:
		score[int(k)] = float(sc[k])
	if kind == "survival":
		# 存檔不會分辨波次單位；讀檔後把所有敵軍單位視為目前波次
		wave_units.clear()
		for u in game.units:
			if not u.dead and u.player != game.human and not u.player.neutral and u.player.team != game.human.team:
				wave_units.append(u)
		cleared = wave_units.is_empty()
