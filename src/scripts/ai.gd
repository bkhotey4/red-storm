extends RefCounted
# 電腦 AI：建設基地、採礦、生產、進攻、防守、超級武器

var game
var p
var diff := 1
var pre := "a_"
var think_t := 0.0
var attack_group: Array = []
var next_attack := 240.0
var attack_size := 8
var wave := 0
var ready_powers := {}
var last_defend := -100.0
var eng_t := 120.0
var retarget_t := 0.0
var deploy_tries := 0
var garrison_t := 60.0
var no_build := false
var passive := false
var drone_focus := false
var wall_t := 150.0

const PLAN := [["power", 1], ["ref", 1], ["bar", 1], ["power", 2], ["fac", 1], ["ref", 2], ["radar", 1], ["def", 2],
	["power", 3], ["yard", 1], ["dronehub", 1], ["tech", 1], ["def", 4], ["power", 4], ["bank", 1], ["sw", 1], ["ref", 3], ["power", 5], ["def", 6], ["fac", 2], ["bar", 2], ["power", 6], ["def", 8]]

func setup(g, pl, d: int):
	game = g
	p = pl
	diff = d
	pre = "a_" if p.faction == "allies" else "s_"
	match diff:
		0:
			next_attack = 480.0
			attack_size = 5
		1:
			next_attack = 300.0
			attack_size = 8
		2:
			next_attack = 200.0
			attack_size = 10
	next_attack += randf_range(-20, 20)

var water_ok := -1
var raid_t := 240.0
var raid_group: Array = []

func naval_ok() -> bool:
	if water_ok < 0:
		var bp := base_pos()
		var n := 0
		for y in range(int(bp.y) - 20, int(bp.y) + 21):
			for x in range(int(bp.x) - 20, int(bp.x) + 21):
				if game.map.inb(x, y) and game.map.terrain[game.map.idx(x, y)] == game.map.T_WATER:
					n += 1
		water_ok = 1 if n > 40 else 0
	return water_ok == 1

func base_pos() -> Vector2:
	for b in game.buildings:
		if b.player == p and b.def.role == "cy" and not b.dead:
			return b.pos
	for b in game.buildings:
		if b.player == p and not b.dead:
			return b.pos
	return Vector2(p.start_cell) + Vector2(0.5, 0.5)

func enemy_players() -> Array:
	var out: Array = []
	for q in game.players:
		if q.alive and not q.neutral and p.is_enemy_of(q):
			out.append(q)
	return out

func enemy_dir() -> Vector2:
	var es := enemy_players()
	var bp := base_pos()
	if es.is_empty():
		return Vector2(1, 1).normalized()
	var best: Vector2 = Vector2(es[0].start_cell)
	var bd := 1e9
	for q in es:
		var d := bp.distance_to(Vector2(q.start_cell))
		if d < bd:
			bd = d
			best = Vector2(q.start_cell)
	return (best - bp).normalized()

func rally_pos() -> Vector2:
	return base_pos() + enemy_dir() * 6.0

func update(dt: float):
	if not p.alive:
		return
	think_t -= dt
	retarget_t -= dt
	if think_t > 0.0:
		return
	think_t = [1.3, 1.0, 0.7][diff]
	if not no_build:
		manage_mcv()
		place_ready()
		manage_buildings()
		manage_production()
		manage_walls()
	manage_army()
	manage_raid()
	manage_super()
	manage_repair()

func manage_mcv():
	var has_cy = p.has_role("cy") or p.count_role("cy") > 0
	for u in game.units:
		if u.player != p or u.dead or not u.def.has("mcv"):
			continue
		if not has_cy or deploy_tries > 0:
			if u.order == "idle" or u.order == "deploy":
				u.cmd_deploy()
				game.try_deploy(u)
				if not u.dead:
					deploy_tries += 1
					var c := Vector2(p.start_cell) + Vector2(randf_range(-4, 4), randf_range(-4, 4))
					u.cmd_move(c)
				else:
					deploy_tries = 0
			return

func role_id(role: String) -> String:
	if role == "bank":
		return "a_bank" if pre == "a_" else "s_gas"
	if role == "def":
		var has_radar: bool = p.has_role("radar")
		var enemy_drones := 0
		for u in game.units:
			if u.def.get("drone", false) and p.is_enemy_of(u.player):
				enemy_drones += 1
		if enemy_drones > 2 and has_radar and p.count_type(pre + "ewt") < 3 and randf() < 0.6:
			return pre + "ewt"
		var enemy_air := false
		for u in game.units:
			if u.is_air() and p.is_enemy_of(u.player):
				enemy_air = true
				break
		if enemy_air and has_radar and randf() < 0.5:
			return pre + ("aa" if pre == "a_" else "flak")
		if has_radar and randf() < 0.6:
			return pre + ("prism" if pre == "a_" else "tcoil")
		return pre + ("pill" if pre == "a_" else "sentry")
	return pre + role

func manage_buildings():
	if not p.has_role("cy"):
		return
	var q: Array = p.queues.building
	if q.is_empty() and p.ready.building == "":
		var need := ""
		if p.power_prod - p.power_use < 40 and p.count_role("power") > 0 and p.count_role("ref") > 0:
			need = pre + "power"
		else:
			for step in PLAN:
				var role: String = step[0]
				if role == "def":
					continue
				if role == "sw" and diff == 0:
					continue
				if role == "yard" and not naval_ok():
					continue
				if p.count_role(role) < int(step[1]):
					need = role_id(role)
					break
		if need != "" and p.can_build(need):
			p.enqueue(need)
	var dq: Array = p.queues.defense
	if dq.is_empty() and p.ready.defense == "":
		var ndef = p.count_role("def")
		var want := 0
		for step in PLAN:
			if step[0] == "def":
				if p.count_role("radar") > 0 or int(step[1]) <= 2:
					want = int(step[1])
		want = mini(want, 2 + diff * 3)
		if ndef < want and p.money > 800:
			var id := role_id("def")
			if p.can_build(id):
				p.enqueue(id)

func place_ready():
	for cat in ["building", "defense"]:
		var id: String = p.ready[cat]
		if id == "":
			continue
		var tl := find_spot(id)
		if tl.x >= 0:
			game.place_building(p, id, tl)
			p.ready[cat] = ""
		else:
			p.cancel(id)

func find_spot(id: String) -> Vector2i:
	var def: Dictionary = Defs.BUILDINGS[id]
	var sz: Vector2i = def.size
	var bp := base_pos()
	var ed := enemy_dir()
	var is_def: bool = def.cat == "defense"
	var anchor := bp
	if def.get("naval", false):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for y in range(int(bp.y) - 20, int(bp.y) + 21):
			for x in range(int(bp.x) - 20, int(bp.x) + 21):
				var tl := Vector2i(x, y)
				var d := Vector2(tl).distance_to(bp)
				if d < bd and game.can_place(id, tl, p):
					bd = d
					best = tl
		return best
	if def.role == "ref":
		var oc: Vector2i = game.map.find_ore_near(bp, 30.0)
		if oc.x >= 0:
			anchor = bp.lerp(Vector2(oc), 0.6)
	var nb := 0
	for b in game.buildings:
		if b.player == p:
			nb += 1
	for attempt in 80:
		var r: float
		var ang: float
		if is_def:
			r = randf_range(5.0, 9.0)
			ang = ed.angle() + randf_range(-1.1, 1.1)
		else:
			r = randf_range(2.5, 5.0 + nb * 0.45 + attempt * 0.05)
			ang = randf() * TAU
		var c := anchor + Vector2.from_angle(ang) * r
		var tl := Vector2i(int(c.x - sz.x * 0.5), int(c.y - sz.y * 0.5))
		if not game.can_place(id, tl, p):
			continue
		if not is_def and not margin_free(tl, sz):
			continue
		return tl
	return Vector2i(-1, -1)

# 在防禦塔前方築一小段圍牆（RA2 風格基地）
func manage_walls():
	wall_t -= think_t
	if wall_t > 0.0:
		return
	wall_t = 18.0
	var limit: int = [0, 14, 26][diff]
	var wid := pre + "wall"
	if limit == 0 or p.money < 700 or not p.can_build(wid):
		return
	var nw := 0
	var defs_: Array = []
	for b in game.buildings:
		if b.player != p or b.dead:
			continue
		if b.def.get("wall", false):
			nw += 1
		elif b.def.cat == "defense":
			defs_.append(b)
	if nw >= limit or defs_.is_empty():
		return
	var d = defs_[randi() % defs_.size()]
	var ed := enemy_dir()
	var perp := Vector2(-ed.y, ed.x)
	var c: Vector2 = d.pos + ed * 2.2
	var placed := 0
	for k in range(-2, 3):
		var q := c + perp * k
		var tl := Vector2i(int(floor(q.x)), int(floor(q.y)))
		if game.bld_at(tl.x, tl.y) != null or not game.can_place(wid, tl, p):
			continue
		var bad := false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var o = game.bld_at(tl.x + ox, tl.y + oy)
				if o != null and not o.def.get("wall", false) and o.def.cat != "defense":
					bad = true
		if bad:
			continue
		var cost := float(Defs.BUILDINGS[wid].cost)
		if p.money < cost:
			break
		p.money -= cost
		game.place_building(p, wid, tl, true)
		placed += 1

func margin_free(tl: Vector2i, sz: Vector2i) -> bool:
	for y in range(tl.y - 1, tl.y + sz.y + 1):
		for x in range(tl.x - 1, tl.x + sz.x + 1):
			if x >= tl.x and x < tl.x + sz.x and y >= tl.y and y < tl.y + sz.y:
				continue
			if not game.map.inb(x, y):
				return false
			if game.bld_at(x, y) != null:
				return false
	# keep refinery docks / factory exits open
	for y in range(tl.y + sz.y, tl.y + sz.y + 2):
		for x in range(tl.x, tl.x + sz.x):
			if game.map.inb(x, y) and not game.map.passable(x, y):
				return false
	return true

func count_units(pred: Callable) -> int:
	var n := 0
	for u in game.units:
		if u.player == p and not u.dead and pred.call(u):
			n += 1
	return n

func manage_production():
	var nref = p.count_role("ref")
	var nharv := count_units(func(u): return u.def.get("harvester", false))
	var want_h = nref + (1 if diff == 2 and nref > 1 else 0)
	var vq: Array = p.queues.vehicle
	var harv_id := pre + "harv"
	var queued_h: int = p.queued_count(harv_id)
	if nharv + queued_h < want_h and p.can_build(harv_id) and vq.size() < 2:
		vq.push_front({"id": harv_id, "progress": 0.0, "spent": 0.0, "hold": false})
		return
	var reserve := 600.0 if p.queues.building.size() > 0 else 200.0
	if p.money < reserve:
		return
	# engineers for oil derricks
	eng_t -= 1.0
	if eng_t <= 0.0:
		eng_t = 150.0
		var oil = nearest_oil()
		if oil != null and p.can_build(pre + "eng"):
			p.enqueue(pre + "eng")
	var iq: Array = p.queues.infantry
	if iq.size() < 2 and p.has_role("bar"):
		var opts := []
		if pre == "a_":
			opts = [["a_gi", 5], ["a_rocket", 3], ["a_jav", 3], ["a_cmdo", 1 if diff >= 1 else 0], ["a_spy", 1 if diff >= 1 else 0]]
		else:
			opts = [["s_con", 6], ["s_flak", 2], ["s_tesla", 3], ["s_guerrilla", 5], ["s_agent", 1 if diff >= 1 else 0]]
		var id := pick(opts)
		if id != "" and p.can_build(id):
			p.enqueue(id)
	if vq.size() < 2 and (p.has_role("fac") or p.has_role("yard")):
		var opts := []
		if pre == "a_":
			opts = [["a_tank", 6], ["a_ifv", 3], ["a_beam", 2], ["a_himars", 2], ["a_ew", 1 if enemy_has_drones() else 0], ["a_fpv", 3], ["a_tb2", 2], ["a_jet", 1],
				["a_destroyer", 2 if naval_count() < 4 else 0], ["a_carrier", 1 if naval_count() < 4 else 0],
				["a_apache", 2], ["a_type10", 5], ["a_k9", 2], ["a_hf", 2], ["a_seadrone", 2 if naval_count() < 6 else 0], ["a_tuojiang", 2 if naval_count() < 6 else 0], ["a_cvn", 1 if naval_count() < 5 else 0]]
		else:
			opts = [["s_tank", 6], ["s_flaktrk", 2], ["s_arty", 2], ["s_mammoth", 2], ["s_tos", 2], ["s_iskander", 1], ["s_ew", 1 if enemy_has_drones() else 0], ["s_lancet", 2], ["s_shahed", 2], ["s_airship", 1],
				["s_sub", 2 if naval_count() < 4 else 0], ["s_dread", 1 if naval_count() < 4 else 0],
				["s_bmpt", 3], ["s_hwasong", 1], ["s_fastboat", 3 if naval_count() < 6 else 0], ["s_technical", 3], ["s_cvn", 1 if naval_count() < 5 else 0]]
		var id := pick(opts)
		if id != "" and p.can_build(id):
			p.enqueue(id)

func naval_count() -> int:
	return count_units(func(u): return u.ukind == "ship")

func pick(opts: Array) -> String:
	var valid := []
	var tot := 0
	for o in opts:
		if int(o[1]) > 0 and p.can_build(o[0]):
			valid.append(o)
			tot += int(o[1])
	if tot == 0:
		return ""
	var r := randi() % tot
	for o in valid:
		r -= int(o[1])
		if r < 0:
			return o[0]
	return valid[0][0]

func nearest_oil():
	var bp := base_pos()
	var best = null
	var bd := 1e9
	for b in game.buildings:
		if b.def.role == "oil" and b.player != p and not b.dead and (b.player.neutral or p.is_enemy_of(b.player)):
			var d: float = b.pos.distance_to(bp)
			if d < bd:
				bd = d
				best = b
	return best

func on_unit_built(u):
	if u.def.get("spy", false):
		var best = null
		var bd := 1e9
		for b in game.buildings:
			if b.dead or not p.is_enemy_of(b.player) or not (b.def.role in ["power", "ref", "sw", "radar"]):
				continue
			var d: float = b.pos.distance_to(base_pos())
			if d < bd:
				bd = d
				best = b
		if best != null:
			u.cmd_capture(best)
		return
	if u.def.get("engineer", false):
		var oil = nearest_oil()
		if oil != null:
			u.cmd_capture(oil)
		return
	if u.def.get("harvester", false):
		return
	if u.ukind != "air":
		var rp := rally_pos() + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		u.cmd_move(rp)

func is_combat(u) -> bool:
	return not u.def.get("harvester", false) and not u.def.has("mcv") and not u.def.get("engineer", false) and not u.weapon.is_empty()

func manage_army():
	attack_group = attack_group.filter(func(u): return is_instance_valid(u) and not u.dead)
	var home: Array = []
	for u in game.units:
		if u.player == p and not u.dead and is_combat(u) and not attack_group.has(u):
			home.append(u)
	if not passive and game.time > next_attack and home.size() >= attack_size:
		launch_attack(home)
		return
	# keep attack group moving to targets
	if retarget_t <= 0.0:
		retarget_t = 4.0
		for u in attack_group:
			if u.ukind == "air":
				if u.order == "idle" or u.order == "return":
					if u.def.get("jet", false) and (u.ammo < int(u.weapon.get("ammo", 0)) or not u.landed):
						continue
					var t = pick_target(u.pos, true)
					if t != null:
						u.cmd_attack(t)
				continue
			if u.order == "idle" or u.order == "return_home":
				var t = pick_target(u.pos, false)
				if t != null:
					u.cmd_move(t.pos, true)
	garrison_t -= 1.0
	if garrison_t <= 0.0:
		garrison_t = 40.0
		try_garrison(home)
	# idle home units gather at rally
	var rp := rally_pos()
	if passive:
		return
	for u in home:
		if u.ukind == "air":
			continue
		if u.order == "idle" and u.pos.distance_to(rp) > 6.0 and u.pos.distance_to(base_pos()) > 3.0:
			u.cmd_move(rp + Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))
	# defeated group -> merge back
	if attack_group.size() > 0 and attack_group.size() < 3 and game.time > next_attack - 60.0:
		for u in attack_group:
			if u.ukind != "air":
				u.cmd_move(rp, false)
		attack_group.clear()

# 困難 / 普通 AI：定期派快速小隊騷擾敵方採礦車（困難更頻繁、規模更大）
func manage_raid():
	if diff == 0 or passive:
		return
	raid_group = raid_group.filter(func(u): return is_instance_valid(u) and not u.dead)
	if game.time < raid_t:
		return
	var want: int = 3 if diff == 1 else 4
	var cands: Array = []
	for u in game.units:
		if u.player == p or u.dead or not is_combat(u) or attack_group.has(u) or raid_group.has(u):
			continue
		if u.ukind == "veh" and float(u.def.get("speed", 1.0)) >= 1.8 and u.order == "idle":
			cands.append(u)
	if cands.size() < want:
		return
	var target = null
	var bd := 1e9
	var bp := base_pos()
	for u in game.units:
		if u.dead or not p.is_enemy_of(u.player) or not u.def.get("harvester", false):
			continue
		var d: float = u.pos.distance_to(bp)
		if d < bd:
			bd = d
			target = u
	if target == null:
		raid_t = game.time + 60.0
		return
	raid_group = cands.slice(0, want)
	for u in raid_group:
		u.cmd_attack(target)
	raid_t = game.time + (150.0 if diff == 1 else 90.0)

func try_garrison(home: Array):
	var bp := base_pos()
	var best = null
	var bd := 20.0
	for b in game.buildings:
		if b.dead or not b.def.has("garrison") or not (b.player.neutral or b.player == p):
			continue
		if b.occupants.size() >= int(b.def.garrison):
			continue
		var d: float = b.pos.distance_to(bp)
		if d < bd:
			bd = d
			best = b
	if best == null:
		return
	var n := 0
	for u in home:
		if n >= 3:
			break
		if u.ukind == "inf" and u.order == "idle" and game.can_garrison(u, best):
			u.cmd_garrison(best)
			n += 1

func launch_attack(home: Array):
	var t = pick_target(base_pos(), false)
	if t == null:
		return
	wave += 1
	attack_group = home.duplicate()
	for u in attack_group:
		if u.ukind == "air":
			u.cmd_attack(t)
		else:
			u.cmd_move(t.pos + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)), true)
	next_attack = game.time + [260.0, 170.0, 120.0][diff]
	attack_size = mini(attack_size + [1, 2, 3][diff], 30)

func pick_target(from: Vector2, prefer_def: bool):
	var best = null
	var bd := 1e9
	for b in game.buildings:
		if b.dead or not p.is_enemy_of(b.player) or b.def.get("wall", false):
			continue
		var d: float = b.pos.distance_to(from)
		if prefer_def and b.def.has("weapon"):
			d -= 8.0
		if b.def.role in ["ref", "fac", "cy"]:
			d -= 3.0
		if diff == 2 and b.def.role in ["sw", "ewt"]:
			d -= 10.0
		if d < bd:
			bd = d
			best = b
	if best == null:
		for u in game.units:
			if u.dead or not p.is_enemy_of(u.player):
				continue
			var d: float = u.pos.distance_to(from)
			if d < bd:
				bd = d
				best = u
	return best

func on_attacked(victim, attacker):
	if attacker == null or not is_instance_valid(attacker) or attacker.dead:
		return
	if game.time - last_defend < 3.0:
		return
	var bp := base_pos()
	if victim.pos.distance_to(bp) > 16.0 and not victim.def.get("harvester", false):
		return
	last_defend = game.time
	for u in game.units:
		if u.player != p or u.dead or not is_combat(u) or attack_group.has(u):
			continue
		if u.order in ["idle", "move", "return_home"] and u.pos.distance_to(victim.pos) < [12.0, 22.0, 32.0][diff]:
			if u.can_hit(u.weapon, attacker):
				u.cmd_attack(attacker)

func enemy_has_drones() -> bool:
	for u in game.units:
		if u.def.get("drone", false) and p.is_enemy_of(u.player):
			return true
	return false

func power_ready(kind: String):
	ready_powers[kind] = true

func manage_super():
	for kind in ready_powers.keys():
		if float(p.powers.get(kind, 0.0)) < 1.0:
			ready_powers.erase(kind)
			continue
		var tgt := Vector2(-1, -1)
		match kind:
			"sanction", "energy":
				var t = pick_target(base_pos(), false)
				if t != null:
					tgt = t.pos
			"militia", "armor":
				tgt = base_pos()
			"scan":
				var es := enemy_players()
				if not es.is_empty():
					tgt = Vector2(es[0].start_cell)
			"jam":
				var t = pick_target(base_pos(), true)
				if t != null and attack_group.size() > 0:
					tgt = t.pos
			_:
				var best = null
				var bs := -1.0
				for b in game.buildings:
					if b.dead or not p.is_enemy_of(b.player):
						continue
					var sc := 0.0
					for o in game.buildings:
						if o.player == b.player and not o.dead and o.pos.distance_to(b.pos) < 4.0:
							sc += 1.0
					if b.def.role in ["cy", "fac", "sw"]:
						sc += 2.0
					if kind == "swarm":
						sc = 0.0
						for u in game.units:
							if not u.dead and p.is_enemy_of(u.player) and u.ukind == "veh" and u.pos.distance_to(b.pos) < 5.0:
								sc += 1.0
					if sc > bs:
						bs = sc
						best = b
				if best != null:
					tgt = best.pos
		if tgt.x >= 0:
			if game.fire_power(p, kind, tgt):
				ready_powers.erase(kind)

func manage_repair():
	if p.money < 600:
		return
	for b in game.buildings:
		if b.player == p and not b.dead and b.built() and b.hp < b.max_hp * 0.6 and not b.repairing:
			b.repairing = true
