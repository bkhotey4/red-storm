extends RefCounted
# 存檔 / 讀檔：user://saves/slotN.json
# 做法：記錄開局設定（含地圖種子），讀檔時先用同樣設定重建地圖，再清掉所有單位/建築並從存檔還原。

const SLOTS := 3

static func slot_path(n: int) -> String:
	return "user://saves/slot%d.json" % n

static func slot_info(n: int) -> Dictionary:
	var p := slot_path(n)
	if not FileAccess.file_exists(p):
		return {}
	var txt := FileAccess.get_file_as_string(p)
	var d = JSON.parse_string(txt)
	if d is Dictionary:
		return {"title": d.get("title", "存檔"), "time": d.get("time", 0.0), "date": d.get("date", ""), "map": d.get("map_name", "")}
	return {}

static func save_game(game, n: int) -> bool:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var s: Dictionary = game.settings.duplicate(true)
	var mp = s.get("map", {})
	var d := {
		"version": 1,
		"title": ("%s — %02d:%02d" % [mp.get("name", "?"), int(game.time) / 60, int(game.time) % 60]),
		"date": Time.get_datetime_string_from_system(false, true),
		"map_name": str(mp.get("name", "")),
		"settings": s,
		"time": game.time,
		"next_id": game.next_id,
		"speed": game.speed,
		"cam": [game.cam.position.x, game.cam.position.y],
		"zoom": game.zoom,
		"explored": Marshalls.raw_to_base64(game.explored),
		"ore": Marshalls.raw_to_base64(game.map.ore.to_byte_array()),
		"gem": Marshalls.raw_to_base64(game.map.gem),
		"players": [],
		"buildings": [],
		"units": [],
		"mission": {},
	}
	for p in game.players:
		d.players.append({
			"money": p.money, "powers": p.powers, "alive": p.alive, "stats": p.stats,
			"relations": p.relations, "allies": p.allies, "ceasefire": p.ceasefire, "proposal": p.proposal,
			"sanctioned_until": p.sanctioned_until, "energy_cut_until": p.energy_cut_until, "sabotage_until": p.sabotage_until,
			"vet_bonus": p.vet_bonus, "queues": p.queues, "ready": p.ready, "country": p.country, "faction": p.faction, "team": p.team,
		})
	for b in game.buildings:
		if b.dead:
			continue
		var occ := []
		for o in b.occupants:
			occ.append({"id": o.id, "hp": o.hp, "rank": o.rank, "kills": o.kills})
		d.buildings.append({"id": b.id, "t": b.type_id, "p": b.player.index, "cx": b.cell.x, "cy": b.cell.y, "hp": b.hp, "bp": b.build_p,
			"rx": b.rally.x, "ry": b.rally.y, "vf": b.var_frame, "occ": occ, "tur": b.turret, "kills": b.kills, "rank": b.rank, "repairing": b.repairing})
	for u in game.units:
		if u.dead or u.has_meta("carrier") or u.has_meta("swarm"):
			continue
		d.units.append({"id": u.id, "t": u.type_id, "p": u.player.index, "x": u.pos.x, "y": u.pos.y, "hp": u.hp, "f": u.facing,
			"rank": u.rank, "kills": u.kills, "cargo": u.cargo, "ammo": u.ammo, "alt": u.alt, "landed": u.landed, "harv": u.def.get("harvester", false)})
	if game.mission != null:
		d.mission = {"id": game.mission.id, "spy_hits": game.mission.spy_hits, "sanction_fired": game.mission.sanction_fired, "waves": game.mission.waves, "wave_t": game.mission.wave_t}
	var f := FileAccess.open(slot_path(n), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	return true

static func load_settings(n: int):
	var p := slot_path(n)
	if not FileAccess.file_exists(p):
		return null
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (d is Dictionary):
		return null
	return d

static func player_by_index(game, idx: int):
	for p in game.players:
		if p.index == idx:
			return p
	return game.players[0]

# 在 game.start() 完成後呼叫，用存檔內容覆蓋目前狀態
static func apply(game, d: Dictionary):
	# 清掉開局自動產生的所有單位與建築
	for u in game.units.duplicate():
		game.remove_unit_silent(u)
	for b in game.buildings.duplicate():
		b.dead = true
		game.remove_building_cells(b)
		b.queue_free()
	game.buildings.clear()
	game.units.clear()
	game.selection.clear()
	for cr in game.crates.duplicate():
		if is_instance_valid(cr):
			cr.queue_free()
	game.crates.clear()
	game.time = float(d.get("time", 0.0))
	game.loading = true
	game.speed = float(d.get("speed", 1.0))
	game.zoom = float(d.get("zoom", 1.35))
	# 地圖資源
	var ore_b: PackedByteArray = Marshalls.base64_to_raw(str(d.get("ore", "")))
	if ore_b.size() == game.map.ore.size() * 4:
		game.map.ore = ore_b.to_int32_array()
	var gem_b: PackedByteArray = Marshalls.base64_to_raw(str(d.get("gem", "")))
	if gem_b.size() == game.map.gem.size():
		game.map.gem = gem_b
	game.map.ore_cells.clear()
	for i in game.map.ore.size():
		if game.map.ore[i] > 0:
			game.map.ore_cells[i] = true
	game.map.ore_dirty = true
	# 玩家
	var ps: Array = d.get("players", [])
	for i in mini(ps.size(), game.players.size()):
		var p = game.players[i]
		var q: Dictionary = ps[i]
		if p.neutral:
			continue
		p.money = float(q.get("money", p.money))
		p.alive = bool(q.get("alive", true))
		p.sanctioned_until = float(q.get("sanctioned_until", -100.0))
		p.energy_cut_until = float(q.get("energy_cut_until", -100.0))
		p.sabotage_until = float(q.get("sabotage_until", -100.0))
		p.vet_bonus = bool(q.get("vet_bonus", false))
		p.team = int(q.get("team", p.team))
		p.powers = {}
		for k in q.get("powers", {}).keys():
			p.powers[k] = float(q.powers[k])
		p.stats = {}
		for k in q.get("stats", {}).keys():
			p.stats[k] = int(q.stats[k])
		for nm in ["relations", "allies", "ceasefire", "proposal"]:
			var src: Dictionary = q.get(nm, {})
			var dst := {}
			for k in src.keys():
				dst[int(k)] = src[k]
			p.set(nm, dst)
		p.queues = {"building": [], "defense": [], "infantry": [], "vehicle": []}
		for cat in q.get("queues", {}).keys():
			for it in q.queues[cat]:
				p.queues[cat].append({"id": str(it.id), "progress": float(it.progress), "spent": float(it.spent), "hold": false})
		p.ready = {"building": str(q.get("ready", {}).get("building", "")), "defense": str(q.get("ready", {}).get("defense", ""))}
		p.power_dirty = true
	# 建築
	for bd in d.get("buildings", []):
		var p = player_by_index(game, int(bd.p))
		var b = game.place_building(p, str(bd.t), Vector2i(int(bd.cx), int(bd.cy)), true)
		b.id = int(bd.id)
		b.hp = minf(float(bd.hp), b.max_hp)
		b.build_p = float(bd.get("bp", 1.0))
		b.rally = Vector2(float(bd.get("rx", -1)), float(bd.get("ry", -1)))
		b.var_frame = int(bd.get("vf", 0))
		b.turret = float(bd.get("tur", 0.0))
		b.kills = int(bd.get("kills", 0))
		b.rank = int(bd.get("rank", 0))
		b.repairing = bool(bd.get("repairing", false))
		for o in bd.get("occ", []):
			b.occupants.append({"id": str(o.id), "hp": float(o.hp), "rank": int(o.rank), "kills": int(o.kills), "w": Defs.WEAPONS.get(Defs.UNITS[str(o.id)].weapon, {})})
			b.occ_cd.append(0.0)
	# 單位
	for ud in d.get("units", []):
		var p = player_by_index(game, int(ud.p))
		var u = game.spawn_unit(p, str(ud.t), Vector2(float(ud.x), float(ud.y)))
		u.id = int(ud.id)
		u.hp = minf(float(ud.hp), u.max_hp)
		u.facing = float(ud.f)
		u.turret = u.facing
		u.rank = int(ud.get("rank", 0))
		u.kills = int(ud.get("kills", 0))
		u.cargo = float(ud.get("cargo", 0.0))
		u.ammo = int(ud.get("ammo", u.ammo))
		if u.ukind == "air":
			u.alt = float(ud.get("alt", u.alt))
			u.landed = bool(ud.get("landed", false))
		if bool(ud.get("harv", false)):
			u.cmd_harvest()
	game.loading = false
	game.next_id = int(d.get("next_id", game.next_id))
	# 探索範圍
	var ex: PackedByteArray = Marshalls.base64_to_raw(str(d.get("explored", "")))
	if ex.size() == game.explored.size():
		game.explored = ex
		for y in game.H:
			for x in game.W:
				if ex[y * game.W + x] != 0:
					game.shroud.mark(x, y)
					game.hud.mm_mask.set_pixel(x, y, Color(0, 0, 0, 0))
		game.shroud_dirty = true
	# 任務
	if game.mission != null and d.has("mission") and not d.mission.is_empty():
		game.mission.spy_hits = int(d.mission.get("spy_hits", 0))
		game.mission.sanction_fired = bool(d.mission.get("sanction_fired", false))
		game.mission.waves = int(d.mission.get("waves", 0))
		game.mission.wave_t = float(d.mission.get("wave_t", 0.0))
	# AI 重新整理
	for ai in game.ais:
		ai.water_ok = -1
		ai.attack_group.clear()
		ai.next_attack = maxf(ai.next_attack, game.time + 90.0)
	var cam: Array = d.get("cam", [])
	if cam.size() == 2:
		game.cam.position = Vector2(float(cam[0]), float(cam[1]))
	game.hud.update_minimap()
	game.message("存檔已讀取")
