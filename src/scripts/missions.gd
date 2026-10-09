extends RefCounted
# 戰役任務

const LIST := [
	{"id": "m1", "name": "任務一：前哨突擊", "faction": "allies", "enemy": "soviet", "headline": "COMMANDO TEAM DROPPED BEHIND ENEMY LINES",
		"map": {"name": "前哨", "theme": "temperate", "layout": "plains", "size": 64}, "seed": 1101, "money": 1500,
		"brief": "指揮官，蘇軍在北方建立了一座前哨基地。\n你沒有基地車，只有一支突擊小隊（含突擊隊員與工程師）。\n\n目標：摧毀敵方所有建築。\n提示：用工程師佔領蘇軍兵營，就能訓練蘇軍步兵當援軍！突擊隊員可用 C4 炸毀建築。"},
	{"id": "m2", "name": "任務二：堅守陣地", "faction": "soviet", "enemy": "allies", "headline": "FORWARD BASE UNDER SIEGE, REINFORCEMENTS 10 MINUTES OUT",
		"map": {"name": "堅守", "theme": "snow", "layout": "canyon", "size": 72}, "seed": 2202, "money": 6000,
		"brief": "同志，盟軍大軍壓境！我們的基地必須撐住。\n\n目標：堅守 10 分鐘，直到援軍抵達。\n提示：盡快建造特斯拉線圈與防空炮，保護好精煉廠。"},
	{"id": "m3", "name": "任務三：無人機戰爭", "faction": "allies", "enemy": "soviet", "headline": "LOITERING MUNITIONS REWRITE THE RULES OF THE DESERT",
		"map": {"name": "無人機", "theme": "desert", "layout": "plains", "size": 80}, "seed": 3303, "money": 10000,
		"brief": "敵軍大量使用柳葉刀巡飛彈與見證者自殺無人機。\n\n目標：摧毀敵方所有建築。\n提示：電子戰車與反無人機干擾塔能讓範圍內的敵方無人機墜毀；星鏈偵察可以找出敵方基地。"},
	{"id": "m4", "name": "任務四：核危機", "faction": "allies", "enemy": "soviet", "headline": "SILO DETECTED: NUCLEAR COUNTDOWN HAS BEGUN",
		"map": {"name": "核危機", "theme": "temperate", "layout": "coast", "size": 80}, "seed": 4404, "money": 12000,
		"brief": "情報顯示蘇軍的核彈發射井已經開始充能！\n\n目標：在核彈摧毀我們之前，炸掉敵方的核彈發射井。\n提示：海馬斯與光束坦克擅長拆除建築；也可以建造造船廠從海上進攻。"},
	# ───────── 混合戰爭戰役 ─────────
	{"id": "h1", "name": "混合戰爭 I：黑暗黎明", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "usa", "enemy_country": "russia",
		"map": {"name": "黑暗黎明", "theme": "temperate", "layout": "plains", "size": 80}, "seed": 5101, "money": 6000,
		"headline": "BLACKOUT: ENERGY ATTACK CRIPPLES FORWARD BASE",
		"brief": "【RSN 快訊】敵方切斷了我方前線基地的能源供應，電網一片漆黑。無人機已在黑暗中逼近。\n\n目標：撐過 8 分鐘，並在結束前讓電力恢復正常（發電量大於耗電量）。\n提示：敵方會重複使用「能源斷供」，多蓋幾座發電廠才有緩衝；反無人機干擾塔能擋住見證者。"},
	{"id": "h2", "name": "混合戰爭 II：蜂群", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "ukraine", "enemy_country": "russia",
		"map": {"name": "蜂群", "theme": "temperate", "layout": "river", "size": 96}, "seed": 5202, "money": 9000,
		"headline": "DRONE SWARMS CROSS THE RIVER AS ARMOR STALLS",
		"brief": "【RSN 快訊】裝甲部隊在河岸被電戰車與干擾塔釘死，唯一能越過防線的是無人機。\n\n目標：摧毀敵方所有建築。\n提示：你的 FPV 與 TB2 便宜 35%，無人機蜂群充能更快；先用海馬斯打掉干擾塔，無人機才飛得過去。"},
	{"id": "h3", "name": "混合戰爭 III：凍結", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "usa", "enemy_country": "iran",
		"map": {"name": "凍結", "theme": "desert", "layout": "canyon", "size": 96}, "seed": 5303, "money": 8000,
		"headline": "SANCTIONS BITE: RESERVES FROZEN, PRODUCTION HALTS",
		"brief": "【RSN 快訊】財政部宣布對敵方實施全面制裁。情報單位要求以間諜滲透摧毀其經濟。\n\n目標：用間諜成功滲透 3 座敵方建築，並發動一次「金融制裁」。\n提示：間諜不會被防禦塔攻擊，但靠近敵方步兵會被識破。精煉廠偷錢、發電廠停電、雷達揭露基地。"},
	{"id": "h4", "name": "混合戰爭 IV：紅海封鎖", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "usa", "enemy_country": "yemen",
		"map": {"name": "紅海", "theme": "desert", "layout": "gulf", "size": 128}, "seed": 5404, "money": 12000,
		"headline": "SHIPPING LANES CLOSED AS DRONE BOATS STRIKE TANKERS",
		"brief": "【RSN 快訊】敵方以見證者無人機與武裝快艇封鎖海峽，油輪不敢出港。航母戰鬥群奉命恢復航運。\n\n目標：摧毀敵方造船廠、無人機指揮站與所有艦艇。\n提示：航空母艦的艦載機可打擊 13 格內目標；驅逐艦的神盾系統能攔截無人機。"},
	{"id": "h5", "name": "混合戰爭 V：海峽", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "taiwan", "enemy_country": "china",
		"map": {"name": "海峽", "theme": "tropical", "layout": "strait", "size": 128}, "seed": 5505, "money": 14000,
		"headline": "AMPHIBIOUS LANDINGS REPORTED ON THE WESTERN SHORE",
		"brief": "【RSN 快訊】對岸的登陸部隊已在西側海灘上岸，東風飛彈隨時可能落下。島上的防線必須撐到增援抵達。\n\n目標：堅守 15 分鐘。\n提示：你的防禦建築便宜 25%、生命 +30%；雄風飛彈車對艦艇雙倍傷害。每隔一段時間西岸會有新一波登陸。"},
	{"id": "h6", "name": "混合戰爭 VI：同盟", "camp": "hybrid", "faction": "allies", "enemy": "random", "country": "japan", "enemy_country": "random", "enemies": 3, "ffa": true,
		"map": {"name": "同盟", "theme": "temperate", "layout": "lake", "size": 112}, "seed": 5606, "money": 10000,
		"headline": "THREE-WAY WAR: DIPLOMATS SCRAMBLE FOR ALLIES",
		"brief": "【RSN 快訊】三個勢力混戰，沒有人撐得過孤軍奮戰。外交官正在尋找願意結盟的夥伴。\n\n目標：與至少一名電腦締結同盟（按 T），然後消滅所有非盟友。\n提示：好感度隨時間上升，不要攻擊你想結盟的對象。結盟後可呼叫「盟友支援」。"},
	{"id": "h7", "name": "混合戰爭 VII：東風", "camp": "hybrid", "faction": "allies", "enemy": "soviet", "country": "usa", "enemy_country": "china", "enemies": 2,
		"map": {"name": "東風", "theme": "desert", "layout": "coast", "size": 128}, "seed": 5707, "money": 15000,
		"headline": "TWO SILOS ARMED: THE CLOCK IS RUNNING",
		"brief": "【RSN 快訊】兩個敵對勢力同時完成超級武器部署，倒數已經開始。這是混合戰爭的最後一役。\n\n目標：摧毀兩名敵人的所有超級武器建築（核彈發射井 / 氣象控制器）與建造廠。\n提示：注意畫面上方的倒數。用星鏈偵察找出發射井，間諜可以重置倒數。"},
]

var id := ""
var data: Dictionary = {}
var game
var done := false
var timer := 0.0
var enemy

static func find(mid: String) -> Dictionary:
	for m in LIST:
		if m.id == mid:
			return m
	return {}

var spy_hits := 0
var sanction_fired := false
var wave_t := 0.0
var waves := 0

func setup(g, mid: String):
	game = g
	id = mid
	data = find(mid)
	enemy = game.players[1]
	var hs := Vector2(game.human.start_cell) + Vector2(0.5, 0.5)
	var es: Vector2i = enemy.start_cell
	match id:
		"h1":
			build_base(game.human, [["a_cy", Vector2i(-1, -1)], ["a_power", Vector2i(-4, -1)], ["a_ref", Vector2i(2, 2)], ["a_bar", Vector2i(-1, 3)], ["a_fac", Vector2i(-5, -5)], ["a_radar", Vector2i(3, -4)]])
			for k in 3:
				game.spawn_unit(game.human, "a_tank", hs + Vector2(-4 + k, -7))
			for k in 5:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(-6 + randf_range(-1, 1), -3 + randf_range(-1, 1)))
			spawn_mcv(enemy)
			enemy.money = 30000
			enemy.powers["energy"] = 0.85
			for ai in game.ais:
				ai.drone_focus = true
				ai.next_attack = 120.0
				ai.attack_size = 5
			game.human.energy_cut_until = game.time + 40.0
			game.human.power_dirty = true
			game.objective = "目標：堅守 08:00，結束時電力須充足"
		"h2":
			spawn_mcv(game.human)
			for k in 3:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_himars", hs + Vector2(-2.5, 2))
			game.spawn_unit(game.human, "a_ew", hs + Vector2(2.5, -1))
			build_base(enemy, [["s_cy", Vector2i(-1, -1)], ["s_power", Vector2i(3, -1)], ["s_power", Vector2i(3, 2)], ["s_ref", Vector2i(-1, 3)], ["s_bar", Vector2i(-4, -1)],
				["s_fac", Vector2i(6, 3)], ["s_radar", Vector2i(6, -1)], ["s_ewt", Vector2i(-6, 2)], ["s_ewt", Vector2i(2, -6)], ["s_ewt", Vector2i(8, 7)], ["s_flak", Vector2i(-5, -5)], ["s_flak", Vector2i(8, -4)], ["s_tcoil", Vector2i(-4, 6)]])
			enemy.money = 18000
			for k in 3:
				game.spawn_unit(enemy, "s_ew", Vector2(es) + Vector2(-8 + k * 2, 8))
			game.objective = "目標：摧毀敵方所有建築"
		"h3":
			spawn_mcv(game.human)
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_spy", hs + Vector2(1.5, 1.5))
			game.spawn_unit(game.human, "a_spy", hs + Vector2(2.0, 1.0))
			build_base(enemy, [["s_cy", Vector2i(-1, -1)], ["s_power", Vector2i(3, -1)], ["s_power", Vector2i(3, 2)], ["s_power", Vector2i(-4, 3)], ["s_ref", Vector2i(-1, 3)],
				["s_bar", Vector2i(-4, -1)], ["s_fac", Vector2i(6, 3)], ["s_radar", Vector2i(6, -1)], ["s_gas", Vector2i(-5, 6)], ["s_tech", Vector2i(2, 6)], ["s_sentry", Vector2i(8, 6)], ["s_sentry", Vector2i(-7, -3)]])
			enemy.money = 16000
			game.human.powers["sanction"] = 0.0
			game.objective = "目標：間諜滲透 0/3，金融制裁 0/1"
		"h4":
			spawn_mcv(game.human)
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 2))
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			var wc: Vector2i = game.nearest_water(game.human.start_cell, 30)
			if wc.x >= 0:
				game.spawn_unit(game.human, "a_cvn", Vector2(wc) + Vector2(0.5, 0.5))
				var w2: Vector2i = game.nearest_water(wc + Vector2i(3, 3), 10)
				if w2.x >= 0:
					game.spawn_unit(game.human, "a_destroyer", Vector2(w2) + Vector2(0.5, 0.5))
			build_base(enemy, [["s_cy", Vector2i(-1, -1)], ["s_power", Vector2i(3, -1)], ["s_power", Vector2i(3, 2)], ["s_ref", Vector2i(-1, 3)], ["s_bar", Vector2i(-4, -1)],
				["s_fac", Vector2i(6, 3)], ["s_radar", Vector2i(6, -1)], ["s_dronehub", Vector2i(-5, 3)], ["s_flak", Vector2i(-5, -5)], ["s_flak", Vector2i(8, -4)]])
			var ew: Vector2i = game.nearest_water(es, 40)
			if OS.get_cmdline_user_args().has("--autotest"):
				print("  H4 water=", ew, " es=", es)
			if ew.x >= 0:
				var placed := false
				for r in 8:
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if placed or maxi(absi(dx), absi(dy)) != r:
								continue
							var tl := ew + Vector2i(dx, dy)
							if game.can_place("s_yard", tl, enemy, null, false):
								game.place_building(enemy, "s_yard", tl, true)
								placed = true
				if OS.get_cmdline_user_args().has("--autotest"):
					print("  H4 yard placed=", placed)
				for k in 4:
					var w2: Vector2i = game.nearest_water(ew + Vector2i(randi_range(-6, 6), randi_range(-6, 6)), 8)
					if w2.x >= 0:
						game.spawn_unit(enemy, "s_fastboat" if k < 3 else "s_sub", Vector2(w2) + Vector2(0.5, 0.5))
			enemy.money = 30000
			for ai in game.ais:
				ai.drone_focus = true
			game.objective = "目標：摧毀敵方造船廠、無人機指揮站與所有艦艇"
		"h5":
			build_base(game.human, [["a_cy", Vector2i(-1, -1)], ["a_power", Vector2i(-4, -1)], ["a_power", Vector2i(-4, 2)], ["a_ref", Vector2i(2, 2)], ["a_bar", Vector2i(-1, 3)],
				["a_fac", Vector2i(-5, -5)], ["a_radar", Vector2i(3, -4)], ["a_pill", Vector2i(-7, 0)], ["a_pill", Vector2i(-7, 3)], ["a_aa", Vector2i(-6, -3)]])
			for k in 3:
				game.spawn_unit(game.human, "a_hf", hs + Vector2(-6 + k, -8))
			for k in 4:
				game.spawn_unit(game.human, "a_jav", hs + Vector2(-8 + randf_range(-1, 1), -2 + randf_range(-1, 1)))
			spawn_mcv(enemy)
			enemy.money = 40000
			for ai in game.ais:
				ai.next_attack = 200.0
			game.objective = "目標：堅守 15:00"
		"h6":
			spawn_mcv(game.human)
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_type10", hs + Vector2(-2.5, 2))
			for q in game.players:
				if q.is_ai:
					spawn_mcv(q)
					q.money = 12000
					q.relations[game.human.index] = 42.0
			game.objective = "目標：締結同盟，然後消滅所有非盟友"
		"h7":
			spawn_mcv(game.human)
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 2))
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 3))
			for q in game.players:
				if q.is_ai:
					var pre := "s_" if q.faction == "soviet" else "a_"
					build_base(q, [[pre + "cy", Vector2i(-1, -1)], [pre + "power", Vector2i(3, -1)], [pre + "power", Vector2i(3, 2)], [pre + "power", Vector2i(-4, 3)], [pre + "ref", Vector2i(-1, 3)],
						[pre + "bar", Vector2i(-4, -1)], [pre + "fac", Vector2i(6, 3)], [pre + "radar", Vector2i(6, -1)], [pre + "tech", Vector2i(-4, 6)], [pre + "sw", Vector2i(2, 6)],
						["s_tcoil" if pre == "s_" else "a_prism", Vector2i(6, 7)], ["s_sentry" if pre == "s_" else "a_pill", Vector2i(8, 6)]])
					q.money = 20000
					q.powers["nuke" if pre == "s_" else "storm"] = 0.0
			game.objective = "目標：摧毀所有敵方超級武器與建造廠"
		"m1":
			for k in 6:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			for k in 3:
				game.spawn_unit(game.human, "a_rocket", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			for k in 3:
				game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5 + k * 1.3, -3.0))
			game.spawn_unit(game.human, "a_eng", hs + Vector2(1, 1))
			game.spawn_unit(game.human, "a_eng", hs + Vector2(1.5, 0.5))
			game.spawn_unit(game.human, "a_cmdo", hs + Vector2(0, 1.5))
			build_base(enemy, [["s_bar", Vector2i(0, 0)], ["s_power", Vector2i(3, 0)], ["s_power", Vector2i(0, 3)], ["s_radar", Vector2i(3, 3)],
				["s_sentry", Vector2i(5, 5)], ["s_sentry", Vector2i(6, 1)], ["s_sentry", Vector2i(1, 6)], ["s_tcoil", Vector2i(5, 3)], ["s_wall", Vector2i(6, 3)], ["s_wall", Vector2i(6, 4)]])
			for k in 8:
				var u = game.spawn_unit(enemy, "s_con", Vector2(es) + Vector2(4 + randf_range(-2, 2), 4 + randf_range(-2, 2)))
			for k in 2:
				game.spawn_unit(enemy, "s_tank", Vector2(es) + Vector2(6.5 + k, 6.5))
			set_ai(true, true)
			game.objective = "目標：摧毀蘇軍前哨所有建築"
		"m2":
			build_base(game.human, [["s_cy", Vector2i(-1, -1)], ["s_power", Vector2i(-4, -1)], ["s_power", Vector2i(-4, 2)], ["s_power", Vector2i(3, -4)],
				["s_ref", Vector2i(2, 2)], ["s_bar", Vector2i(-1, 3)], ["s_fac", Vector2i(-5, -5)], ["s_radar", Vector2i(-1, -4)],
				["s_sentry", Vector2i(-3, -7)], ["s_sentry", Vector2i(-7, -3)], ["s_tcoil", Vector2i(-6, -6)]])
			for k in 4:
				game.spawn_unit(game.human, "s_tank", hs + Vector2(-5 + k, -7))
			for k in 6:
				game.spawn_unit(game.human, "s_con", hs + Vector2(-7 + randf_range(-1, 1), -3 + randf_range(-1, 1)))
			spawn_mcv(enemy)
			enemy.money = 30000
			set_ai(false, false)
			for ai in game.ais:
				ai.next_attack = 150.0
				ai.attack_size = 6
			game.objective = "目標：堅守 10:00"
		"m3":
			spawn_mcv(game.human)
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_ew", hs + Vector2(2.5, -1))
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 2))
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 3))
			spawn_mcv(enemy)
			enemy.money = 20000
			for ai in game.ais:
				ai.drone_focus = true
			game.objective = "目標：摧毀敵方所有建築"
		"m4":
			spawn_mcv(game.human)
			for k in 4:
				game.spawn_unit(game.human, "a_gi", hs + Vector2(randf_range(-2, 2), randf_range(-2, 2)))
			game.spawn_unit(game.human, "a_tank", hs + Vector2(-2.5, 2))
			build_base(enemy, [["s_cy", Vector2i(-1, -1)], ["s_power", Vector2i(3, -1)], ["s_power", Vector2i(3, 2)], ["s_power", Vector2i(-4, 3)],
				["s_ref", Vector2i(-1, 3)], ["s_bar", Vector2i(-4, -1)], ["s_fac", Vector2i(6, 3)], ["s_radar", Vector2i(6, -1)],
				["s_tech", Vector2i(-4, 6)], ["s_sw", Vector2i(2, 6)], ["s_tcoil", Vector2i(6, 7)], ["s_sentry", Vector2i(8, 6)]])
			enemy.money = 15000
			enemy.powers["nuke"] = 0.0
			game.objective = "目標：摧毀敵方核彈發射井"

func set_ai(no_build: bool, passive: bool):
	for ai in game.ais:
		ai.no_build = no_build
		ai.passive = passive

func spawn_mcv(p):
	var c := Vector2(p.start_cell) + Vector2(0.5, 0.5)
	game.spawn_unit(p, "a_mcv" if p.faction == "allies" else "s_mcv", c)

func build_base(p, list: Array):
	var sc: Vector2i = p.start_cell
	for it in list:
		var id_: String = it[0]
		var tl: Vector2i = sc + it[1]
		var placed := false
		for r in 5:
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if placed or maxi(absi(dx), absi(dy)) != r:
						continue
					if game.can_place(id_, tl + Vector2i(dx, dy), p, null, false):
						game.place_building(p, id_, tl + Vector2i(dx, dy), true)
						placed = true
		if not placed:
			push_warning("mission: could not place " + id_)

func on_spy(_b):
	spy_hits += 1

func on_power(kind: String):
	if kind == "sanction":
		sanction_fired = true

func landing():
	# 海峽：在島嶼西岸找水邊的陸地格登陸
	var hs: Vector2i = game.human.start_cell
	var best := Vector2i(-1, -1)
	var tries := 0
	while tries < 200 and best.x < 0:
		tries += 1
		var x := hs.x - 4 - randi_range(0, 10)
		var y := hs.y + randi_range(-18, 18)
		if game.map.inb(x, y) and game.map.passable(x, y) and game.map.near_type(x, y, game.map.T_WATER, 2) and game.bld_at(x, y) == null:
			best = Vector2i(x, y)
	if best.x < 0:
		return
	waves += 1
	var ids: Array = ["s_tank", "s_tank", "s_bmpt", "s_con", "s_con", "s_con", "s_flak"]
	if waves >= 3:
		ids += ["s_mammoth", "s_tos"]
	for i in ids.size():
		var c: Vector2i = game.nearest_free(best + Vector2i(randi_range(-2, 2), randi_range(-2, 2)), 5)
		if c.x >= 0:
			var u = game.spawn_unit(enemy, ids[i], Vector2(c) + Vector2(0.5, 0.5))
			u.cmd_move(Vector2(hs) + Vector2(0.5, 0.5), true)
	game.message("警告：西岸偵測到第 %d 波登陸部隊！" % waves)
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  LANDING ", waves, " at ", best)
	game.ping(Vector2(best))
	Sfx.play("alarm", -4.0)

# returns "win", "lose" or ""
func check() -> String:
	timer = game.time
	match id:
		"h1":
			var left: float = 480.0 - game.time
			game.objective = "目標：堅守 %02d:%02d（結束時電力須充足）" % [int(maxf(0, left)) / 60, int(maxf(0, left)) % 60]
			if not game.human.alive:
				return "lose"
			if left <= 0.0:
				return "win" if game.human.power_prod >= game.human.power_use and game.human.power_prod > 0 else "lose"
			if game.time > 200.0 and float(enemy.powers.get("energy", 0.0)) >= 1.0:
				game.fire_power(enemy, "energy", Vector2(game.human.start_cell))
		"h2", "h4", "h6", "h7":
			if not game.human.alive:
				return "lose"
			if id == "h2" and count_bld(enemy) == 0:
				return "win"
			if id == "h4":
				var left_b := 0
				for b in game.buildings:
					if b.player == enemy and not b.dead and b.def.role in ["yard", "dronehub"]:
						left_b += 1
				var ships := 0
				for u in game.units:
					if u.player == enemy and not u.dead and u.ukind == "ship":
						ships += 1
				game.objective = "目標：敵方造船廠/無人機站剩 %d，艦艇剩 %d" % [left_b, ships]
				if left_b == 0 and ships == 0 and game.time > 120.0:
					return "win"
			if id == "h6":
				var allied: bool = game.human_allies().size() > 0
				var foes := 0
				for q in game.players:
					if q.is_ai and q.alive and game.human.is_enemy_of(q):
						foes += 1
				game.objective = ("目標：消滅所有非盟友（剩 %d）" % foes) if allied else "目標：先與一名電腦締結同盟（按 T）"
				if allied and foes == 0:
					return "win"
			if id == "h7":
				var left_b := 0
				for b in game.buildings:
					if b.player != game.human and not b.player.neutral and not b.dead and b.def.role in ["sw", "cy"]:
						left_b += 1
				game.objective = "目標：敵方超級武器/建造廠剩 %d" % left_b
				if left_b == 0:
					return "win"
		"h3":
			if not game.human.alive:
				return "lose"
			game.objective = "目標：間諜滲透 %d/3，金融制裁 %d/1" % [mini(spy_hits, 3), 1 if sanction_fired else 0]
			if spy_hits >= 3 and sanction_fired:
				return "win"
		"h5":
			var left: float = 900.0 - game.time
			game.objective = "目標：堅守 %02d:%02d（第 %d 波登陸）" % [int(maxf(0, left)) / 60, int(maxf(0, left)) % 60, waves]
			if not game.human.alive:
				return "lose"
			if left <= 0.0:
				return "win"
			wave_t -= 1.0
			if wave_t <= 0.0:
				wave_t = 150.0 if waves > 0 else 90.0
				landing()
		"m1":
			var alive := false
			for u in game.units:
				if u.player == game.human and not u.dead:
					alive = true
					break
			if not alive:
				for b in game.buildings:
					if b.player == game.human and not b.dead and not b.def.get("civ", false):
						alive = true
			if not alive:
				return "lose"
			if count_bld(enemy) == 0:
				return "win"
		"m2":
			var left: float = 600.0 - game.time
			game.objective = "目標：堅守 %02d:%02d" % [int(maxf(0, left)) / 60, int(maxf(0, left)) % 60]
			if not game.human.alive:
				return "lose"
			if left <= 0.0:
				return "win"
		"m3":
			if not game.human.alive:
				return "lose"
			if count_bld(enemy) == 0:
				return "win"
		"m4":
			if not game.human.alive:
				return "lose"
			var silo := false
			for b in game.buildings:
				if b.player == enemy and not b.dead and b.type_id == "s_sw":
					silo = true
			if not silo:
				return "win"
	return ""

func count_bld(p) -> int:
	var n := 0
	for b in game.buildings:
		if b.player == p and not b.dead and not b.def.get("civ", false) and not b.def.get("wall", false):
			n += 1
	return n
