extends Node2D
const RecS = preload("res://scripts/records.gd")
# 遊戲主控：世界、輸入、指令、戰鬥規則

const UnitS = preload("res://scripts/unit.gd")
const BldS = preload("res://scripts/building.gd")
const MapS = preload("res://scripts/map.gd")
const PlayerS = preload("res://scripts/player.gd")
const AIS = preload("res://scripts/ai.gd")
const FxS = preload("res://scripts/fx.gd")
const HudS = preload("res://scripts/hud.gd")
const OverlayS = preload("res://scripts/overlay.gd")
const ShroudS = preload("res://scripts/shroud.gd")
const PropS = preload("res://scripts/prop.gd")
const MissionS = preload("res://scripts/missions.gd")
const EventsS = preload("res://scripts/events.gd")
const CrateS = preload("res://scripts/crate.gd")

const BUILD_GAP := 3

var W := 72
var H := 72
var world: Node2D
var map
var objects: Node2D
var air_layer: Node2D
var fx
var overlay
var shroud
var hud
var cam: Camera2D
var astar: AStarGrid2D
var astar_w: AStarGrid2D
var players: Array = []
var human
var neutral
var ais: Array = []
var units: Array = []
var buildings: Array = []
var bgrid: Array = []
var buckets := {}
var selection: Array = []
var groups := {}
var time := 0.0
var paused := false
var game_over := false
var result := ""
var speed := 1.0
var next_id := 1
var explored := PackedByteArray()
var shroud_dirty := true
var reveal_t := 0.0
var check_t := 0.0
var place_id := ""
var cmd_mode := ""
var dragging := false
var drag_start := Vector2.ZERO
var panning := false
var hover = null
var events: Array = []
var markers: Array = []
var last_group_key := -1
var last_group_time := 0.0
var cam_target := Vector2.ZERO
var zoom := 1.35
var settings := {}
var ack_t := 0.0
var mission = null
var world_ev = null
var loading := false
const SaveS = preload("res://scripts/saveload.gd")
var crates: Array = []
var crate_t := 30.0
var objective := ""

func start(s: Dictionary):
	settings = s
	G.game = self
	speed = float(s.get("speed", 1.0))
	world = Node2D.new()
	add_child(world)
	# map
	map = MapS.new()
	var preset: Dictionary = s.get("map", MapS.PRESETS[0])
	var mp := preset.duplicate()
	mp["players"] = 1 + int(s.get("enemies", 1))
	mp["seed"] = int(s.get("seed", randi()))
	map.generate(mp)
	W = map.W
	H = map.H
	world.add_child(map)
	map.build_visuals(self)
	RenderingServer.set_default_clear_color(MapS.THEMES[map.theme].clear)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	world.add_child(objects)
	air_layer = Node2D.new()
	air_layer.z_index = 30
	world.add_child(air_layer)
	fx = FxS.new()
	world.add_child(fx)
	fx.setup(self)
	overlay = OverlayS.new()
	overlay.game = self
	overlay.z_index = 60
	world.add_child(overlay)
	shroud = ShroudS.new()
	shroud.game = self
	shroud.z_index = 70
	world.add_child(shroud)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	# pathfinding
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar_w = AStarGrid2D.new()
	astar_w.region = Rect2i(0, 0, W, H)
	astar_w.cell_size = Vector2(1, 1)
	astar_w.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_w.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_w.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_w.update()
	for y in H:
		for x in W:
			if map.terrain[map.idx(x, y)] != map.T_WATER:
				astar_w.set_point_solid(Vector2i(x, y), true)
	bgrid.resize(W * H)
	bgrid.fill(null)
	for y in H:
		for x in W:
			if not map.passable(x, y):
				astar.set_point_solid(Vector2i(x, y), true)
	explored.resize(W * H)
	explored.fill(0)
	# props
	for t in map.trees:
		var pr = PropS.new()
		pr.setup(t[2], t[1], Vector2(t[0]) + Vector2(0.5, 0.5))
		objects.add_child(pr)
	for r in map.rocks:
		var pr = PropS.new()
		pr.setup(str(map.THEMES[map.theme].get("rock_sprite", "rock")), r[1], Vector2(r[0]) + Vector2(0.5, 0.5))
		objects.add_child(pr)
	setup_players(s)
	# neutral oil derricks
	for o in map.oils:
		place_building(neutral, "oil", o, true)
	for c in map.civs:
		var cb = place_building(neutral, c[0], c[1], true)
		cb.var_frame = c[2]
	# starting forces
	if s.has("mission"):
		mission = MissionS.new()
		mission.setup(self, s.mission)
	else:
		for p in players:
			if p.neutral:
				continue
			spawn_start(p)
	world_ev = EventsS.new()
	world_ev.setup(self)
	# HUD
	hud = HudS.new()
	add_child(hud)
	hud.setup(self)
	center_on(Vector2(human.start_cell) + Vector2(0.5, 0.5), true)
	reveal_all_now()
	Sfx.say("construction_options", 0.0)
	Sfx.music("battle")
	message("指揮官，展開基地車 (選取後按 D 或雙擊) 開始建設基地！")

func setup_players(s: Dictionary):
	var colors := [Color(0.92, 0.16, 0.12), Color(0.22, 0.52, 1.0), Color(0.95, 0.8, 0.12), Color(0.2, 0.8, 0.3), Color(1.0, 0.5, 0.1), Color(0.7, 0.3, 0.9)]
	var hf: String = s.get("faction", "allies")
	var hc: String = s.get("country", "")
	if hc == "random":
		var cands := []
		for c in Defs.COUNTRY_ORDER:
			if Defs.COUNTRIES[c].faction == hf:
				cands.append(c)
		hc = cands[randi() % cands.size()]
	if Defs.COUNTRIES.has(hc):
		hf = Defs.COUNTRIES[hc].faction
	human = PlayerS.new()
	human.country = hc
	human.index = 0
	human.game = self
	human.name = "指揮官"
	human.faction = hf
	human.color = Defs.FACTIONS[hf].color
	human.team = 0
	human.money = float(s.get("money", 10000))
	human.start_cell = map.starts[0]
	if OS.get_cmdline_user_args().has("--swap"):
		var t0 = map.starts[0]
		map.starts[0] = map.starts[1]
		map.starts[1] = t0
		human.start_cell = map.starts[0]
	players.append(human)
	colors.erase(human.color)
	var used := [human.color]
	var n := int(s.get("enemies", 1))
	var allied_ai: bool = s.get("ai_allied", true)
	var diff := int(s.get("difficulty", 1))
	for k in n:
		var p = PlayerS.new()
		p.index = k + 1
		p.game = self
		var ef: String = s.get("enemy_faction", "random")
		if ef == "random":
			ef = ["allies", "soviet"][randi() % 2]
		var ec: String = s.get("enemy_country", "")
		if ec == "random":
			var cands := []
			for c in Defs.COUNTRY_ORDER:
				if (s.get("enemy_faction", "random") == "random" or Defs.COUNTRIES[c].faction == ef) and c != hc:
					cands.append(c)
			for q in players:
				cands.erase(q.country)
			ec = cands[randi() % cands.size()] if not cands.is_empty() else ""
		if Defs.COUNTRIES.has(ec):
			ef = Defs.COUNTRIES[ec].faction
		p.country = ec
		p.faction = ef
		var c: Color = Defs.FACTIONS[ef].color
		if used.has(c):
			for cc in colors:
				if not used.has(cc):
					c = cc
					break
		used.append(c)
		p.color = c
		p.team = 1 if allied_ai else k + 1
		p.is_ai = true
		p.name = ("%s 電腦 %d" % [Defs.COUNTRIES[ec].name, k + 1]) if Defs.COUNTRIES.has(ec) else ("%s電腦 %d" % [Defs.FACTIONS[ef].name, k + 1])
		p.money = float(s.get("money", 10000))
		p.start_cell = map.starts[k + 1]
		match diff:
			0:
				p.income_mult = 0.75
				p.build_mult = 0.75
			1:
				p.income_mult = 1.0
				p.build_mult = 1.0
			2:
				p.income_mult = 1.35
				p.build_mult = 1.3
		players.append(p)
		var ai = AIS.new()
		ai.setup(self, p, diff)
		ais.append(ai)
	neutral = PlayerS.new()
	neutral.index = 99
	neutral.game = self
	neutral.neutral = true
	neutral.name = "中立"
	neutral.color = Color(0.6, 0.6, 0.6)
	neutral.team = -1
	neutral.faction = "neutral"
	players.append(neutral)

func spawn_start(p):
	var c := Vector2(p.start_cell) + Vector2(0.5, 0.5)
	var f: String = p.faction
	var mcv = spawn_unit(p, "a_mcv" if f == "allies" else "s_mcv", c)
	mcv.facing = PI * 1.25
	var inf := "a_gi" if f == "allies" else "s_con"
	var tank := "a_tank" if f == "allies" else "s_tank"
	var toc := (Vector2(W, H) * 0.5 - c).normalized()
	for k in 5:
		var off := toc.rotated(randf_range(-1.2, 1.2)) * randf_range(2.0, 3.5)
		spawn_unit(p, inf, c + off)
	for k in 2:
		var u = spawn_unit(p, tank, c + toc * 3.2 + toc.orthogonal() * (k * 1.4 - 0.7))
		u.facing = toc.angle()
		u.turret = u.facing

# ───────────────────────── spawning / buildings ─────────────────────────
func spawn_unit(p, id: String, at: Vector2):
	var u = UnitS.new()
	u.id = next_id
	next_id += 1
	u.setup(self, p, id, at)
	if p.country != "":
		var hm := Defs.country_mult(p.country, "hp", id)
		u.max_hp *= hm
		u.hp = u.max_hp
		u.speed *= Defs.country_mult(p.country, "speed", id)
	if u.ukind == "air":
		air_layer.add_child(u)
	else:
		objects.add_child(u)
	units.append(u)
	return u

func bld_at(x: int, y: int):
	if x < 0 or y < 0 or x >= W or y >= H:
		return null
	return bgrid[y * W + x]

func can_place(id: String, tl: Vector2i, p, ignore = null, need_near := true) -> bool:
	var def: Dictionary = Defs.BUILDINGS[id]
	var sz: Vector2i = def.size
	for y in range(tl.y, tl.y + sz.y):
		for x in range(tl.x, tl.x + sz.x):
			if not cell_buildable(id, x, y):
				return false
	for u in units:
		if u == ignore or u.dead or u.ukind == "air":
			continue
		if u.pos.x > tl.x - 0.1 and u.pos.x < tl.x + sz.x + 0.1 and u.pos.y > tl.y - 0.1 and u.pos.y < tl.y + sz.y + 0.1:
			if u.player != p or u.ukind == "veh" and u.moving:
				return false
	if need_near and not near_own(tl, sz, p, 5 if def.get("naval", false) else 0):
		return false
	return true

func cell_buildable(id: String, x: int, y: int) -> bool:
	if not map.inb(x, y) or bld_at(x, y) != null:
		return false
	if Defs.BUILDINGS[id].get("naval", false):
		return map.terrain[map.idx(x, y)] == map.T_WATER
	return map.buildable(x, y)

func near_own(tl: Vector2i, sz: Vector2i, p, extra := 0) -> bool:
	var r := Rect2i(tl, sz)
	for b in buildings:
		if b.player != p or b.dead or b.def.get("wall", false):
			continue
		var gap := BUILD_GAP + extra
		var br := Rect2i(b.cell - Vector2i(gap, gap), b.size + Vector2i(gap * 2, gap * 2))
		if br.intersects(r):
			return true
	return false

func place_building(p, id: String, tl: Vector2i, instant := false):
	var b = BldS.new()
	b.id = next_id
	next_id += 1
	b.setup(self, p, id, tl, instant)
	if p.country != "":
		b.max_hp *= Defs.country_mult(p.country, "hp", id)
		b.hp = b.max_hp
	objects.add_child(b)
	buildings.append(b)
	for y in range(tl.y, tl.y + b.size.y):
		for x in range(tl.x, tl.x + b.size.x):
			bgrid[y * W + x] = b
			astar.set_point_solid(Vector2i(x, y), true)
			astar_w.set_point_solid(Vector2i(x, y), true)
			map.clear_ore(x, y)
	# push own units out of the footprint
	for u in units:
		if u.dead or u.ukind == "air":
			continue
		if bld_at(int(u.pos.x), int(u.pos.y)) == b:
			var c := nearest_free(Vector2i(int(u.pos.x), int(u.pos.y)), 6)
			if c.x >= 0:
				u.pos = Vector2(c) + Vector2(0.5, 0.5)
				u.path.clear()
	p.power_dirty = true
	if instant:
		on_building_complete(b)
	if p == human:
		reveal_entity(b)
	return b

func on_building_complete(b):
	if loading:
		return
	if b.def.role == "ref":
		var hid := "a_harv" if b.def.faction == "allies" else "s_harv"
		var c := nearest_free(b.exit_cell(), 5)
		if c.x >= 0:
			var u = spawn_unit(b.player, hid, Vector2(c) + Vector2(0.5, 0.5))
			u.facing = PI * 0.5
			u.cmd_harvest()
	if b.player == human:
		Sfx.play("build", -4.0)
		if b.def.role == "yard":
			hud.tab = 4
			message("造船廠完工：右側「海軍」分頁可生產艦艇")
		if b.def.role in ["radar", "tech", "fac", "bar", "ref"]:
			Sfx.say("construction_options", 3.0)
	if b.def.has("super") and b.player != human and human.is_enemy_of(b.player):
		message("警告：%s 已建成超級武器「%s」，倒數開始！" % [b.player.name, Defs.SUPER[b.def.super].name])
		Sfx.play("alarm", -4.0)
		ping(b.pos)
		reveal(b.pos, 3.0)
	elif b.def.role == "radar" and b.player != human and human.is_enemy_of(b.player) and Defs.COUNTRIES.has(b.player.country) and Defs.COUNTRIES[b.player.country].has("power"):
		message("情報：%s 的特殊能力「%s」開始充能" % [b.player.name, Defs.SUPER[Defs.COUNTRIES[b.player.country].power].name])

func remove_building_cells(b):
	for y in range(b.cell.y, b.cell.y + b.size.y):
		for x in range(b.cell.x, b.cell.x + b.size.x):
			if bgrid[y * W + x] == b:
				bgrid[y * W + x] = null
				astar.set_point_solid(Vector2i(x, y), not map.passable(x, y))
				astar_w.set_point_solid(Vector2i(x, y), map.terrain[map.idx(x, y)] != map.T_WATER)

func spawn_produced(p, id: String):
	var def: Dictionary = Defs.UNITS[id]
	if p == human:
		if def.get("drone", false):
			RecS.bump("drones")
		if def.has("carrier"):
			RecS.bump("carriers")
	var vet: bool = p.vet_bonus
	var role: String = p.producer_role(def)
	var prod = null
	var pb = p.primary.get(role)
	if pb != null and is_instance_valid(pb) and not pb.dead and pb.player == p:
		prod = pb
	if prod == null:
		for b in buildings:
			if b.player == p and not b.dead and b.built() and (b.def.role == role or (role == "airfield" and b.def.get("airfield", false))):
				if prod == null or b.def.faction == def.faction:
					prod = b
	if prod == null:
		p.money += def.cost
		return
	var u
	if def.kind == "ship":
		var wc := nearest_water(prod.exit_cell(), 6)
		if wc.x < 0:
			wc = nearest_water(Vector2i(int(prod.pos.x), int(prod.pos.y)), 8)
		if wc.x < 0:
			p.money += def.cost
			return
		u = spawn_unit(p, id, Vector2(wc) + Vector2(0.5, 0.5))
		if prod.rally.x >= 0:
			u.cmd_move(prod.rally)
	elif def.kind == "air":
		u = spawn_unit(p, id, prod.pos + Vector2(0.3, 0.3))
		if def.get("jet", false):
			u.landed = true
			u.alt = 16.0
		else:
			u.cmd_move(prod.pos + Vector2(1.5, 1.5))
	else:
		var c := nearest_free(prod.exit_cell(), 8)
		if c.x < 0:
			c = prod.exit_cell()
		u = spawn_unit(p, id, Vector2(c) + Vector2(0.5, 0.5) + Vector2(randf_range(-0.15, 0.15), randf_range(-0.15, 0.15)))
		u.facing = PI * 0.5
		u.turret = u.facing
		if def.get("harvester", false):
			u.cmd_harvest()
		elif prod.rally.x >= 0:
			u.cmd_move(prod.rally + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
		else:
			var out := nearest_free(c + Vector2i(randi_range(-1, 1), 2), 4)
			if out.x >= 0:
				u.cmd_move(Vector2(out) + Vector2(0.5, 0.5))
	if vet and u.rank < 1 and not def.get("harvester", false):
		u.rank = 1
	if p == human:
		Sfx.say("unit_ready", 2.5)
	if true:
		for ai in ais:
			if ai.p == p:
				ai.on_unit_built(u)

func nearest_free(c: Vector2i, maxr: int) -> Vector2i:
	for r in maxr + 1:
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				if map.inb(x, y) and map.passable(x, y) and bld_at(x, y) == null:
					var d := Vector2(x - c.x, y - c.y).length_squared()
					if d < bd:
						bd = d
						best = Vector2i(x, y)
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

func nearest_refinery(p, from: Vector2):
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.player == p and not b.dead and b.def.role == "ref" and b.built():
			var d: float = b.pos.distance_to(from)
			if d < bd:
				bd = d
				best = b
	return best

func nearest_airfield(p, from: Vector2):
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.player == p and not b.dead and b.def.get("airfield", false) and b.built():
			var d: float = b.pos.distance_to(from)
			if d < bd:
				bd = d
				best = b
	return best

# ───────────────────────── queries ─────────────────────────
func passable_pos(p: Vector2, water := false) -> bool:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	if water:
		return not astar_w.is_point_solid(Vector2i(x, y))
	return not astar.is_point_solid(Vector2i(x, y))

func los(a: Vector2, b: Vector2, water := false) -> bool:
	var d := a.distance_to(b)
	var n := int(d / 0.25) + 1
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		if not passable_pos(p, water):
			return false
		# check a little sideways for vehicle clearance
		var side := (b - a).normalized().orthogonal() * (0.4 if water else 0.3)
		if not passable_pos(p + side, water) or not passable_pos(p - side, water):
			return false
	return true

func nearest_water(c: Vector2i, maxr: int) -> Vector2i:
	for r in maxr + 1:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				if map.inb(x, y) and not astar_w.is_point_solid(Vector2i(x, y)):
					return Vector2i(x, y)
	return Vector2i(-1, -1)

func find_path(from: Vector2, to: Vector2, water := false) -> Array:
	var grid: AStarGrid2D = astar_w if water else astar
	var a := Vector2i(clampi(int(floor(from.x)), 0, W - 1), clampi(int(floor(from.y)), 0, H - 1))
	if grid.is_point_solid(a):
		a = nearest_water(a, 3) if water else nearest_free(a, 3)
		if a.x < 0:
			return []
	var b := Vector2i(clampi(int(floor(to.x)), 0, W - 1), clampi(int(floor(to.y)), 0, H - 1))
	var ids := grid.get_id_path(a, b, true)
	if ids.is_empty():
		return []
	var pts: Array = []
	for k in range(1, ids.size()):
		pts.append(Vector2(ids[k]) + Vector2(0.5, 0.5))
	var exact: bool = ids[ids.size() - 1] == b and not grid.is_point_solid(b)
	if exact:
		var tp := Vector2(clampf(to.x, b.x + 0.15, b.x + 0.85), clampf(to.y, b.y + 0.15, b.y + 0.85))
		if pts.is_empty():
			pts.append(tp)
		else:
			pts[pts.size() - 1] = tp
	if pts.is_empty():
		return []
	# string pulling
	var out: Array = []
	var cur := from
	var i := 0
	while i < pts.size():
		var j := mini(i + 10, pts.size() - 1)
		while j > i and not los(cur, pts[j], water):
			j -= 1
		out.append(pts[j])
		cur = pts[j]
		i = j + 1
	return out

func rebuild_buckets():
	buckets.clear()
	for u in units:
		if u.dead or u.ukind == "air":
			continue
		var k := int(u.pos.x) + int(u.pos.y) * 1000
		if buckets.has(k):
			buckets[k].append(u)
		else:
			buckets[k] = [u]

func neighbors(p: Vector2) -> Array:
	var out: Array = []
	var cx := int(p.x)
	var cy := int(p.y)
	for y in range(cy - 1, cy + 2):
		for x in range(cx - 1, cx + 2):
			var k := x + y * 1000
			if buckets.has(k):
				out.append_array(buckets[k])
	return out

func find_target(ent, w: Dictionary, rng: float, prefer_units := false, air_only := false):
	var best = null
	var best_s := 1e9
	var wh: Dictionary = Defs.WARHEADS[w.wh]
	var mp: Vector2 = ent.pos
	var minr := float(w.get("min_range", 0.0))
	for u in units:
		if u.dead or not ent.player.is_enemy_of(u.player):
			continue
		if u.def.get("spy", false):
			if ent.kind != "unit" or ent.ukind != "inf" or mp.distance_to(u.pos) > 2.2:
				continue
		if u.is_air():
			if not w.get("air", false):
				continue
		elif air_only or w.get("air_only", false):
			continue
		var eff: float = float(wh.get(u.armor, 1.0))
		if eff < 0.02:
			continue
		var d: float = mp.distance_to(u.pos)
		if d > rng or d < minr:
			continue
		if ent.player == human and not is_explored(int(u.pos.x), int(u.pos.y)):
			continue
		var s := d - eff * 2.0
		if not u.weapon.is_empty():
			s -= 1.0
		if s < best_s:
			best_s = s
			best = u
	if air_only or w.get("air_only", false):
		return best
	for b in buildings:
		if b.dead or not ent.player.is_enemy_of(b.player) or b.def.get("wall", false):
			continue
		var eff: float = float(wh.get("bld", 1.0))
		if eff < 0.02:
			continue
		var d: float = b.dist_to(mp)
		if d > rng or d < minr:
			continue
		var s := d + 1.5 - eff
		if b.def.has("weapon"):
			s -= 3.0
		if prefer_units:
			s += 6.0
		if s < best_s:
			best_s = s
			best = b
	return best

func damage_area(p: Vector2, r: float, dmg: float, wh: String, att, primary = null, owner = null, friendly := false):
	var own = owner
	if own == null and att != null and is_instance_valid(att):
		own = att.player
	for u in units.duplicate():
		if u.dead:
			continue
		if not friendly and own != null and u.player == own:
			continue
		if u.is_air() and wh != "flak":
			continue
		var d: float = u.pos.distance_to(p)
		if d <= r or u == primary:
			var f := 1.0 - 0.5 * clampf(d / r, 0.0, 1.0)
			u.take_damage(dmg * f, att if att != null and is_instance_valid(att) else null, wh)
	for b in buildings.duplicate():
		if b.dead:
			continue
		if not friendly and own != null and b.player == own:
			continue
		var d: float = b.dist_to(p)
		if d <= r or b == primary:
			var f := 1.0 - 0.5 * clampf(d / r, 0.0, 1.0)
			b.take_damage(dmg * f, att if att != null and is_instance_valid(att) else null, wh)

# ───────────────────────── events ─────────────────────────
func on_entity_died(e):
	selection.erase(e)
	for k in groups:
		groups[k].erase(e)
	if hover == e:
		hover = null
	if e.kind == "unit":
		units.erase(e)
		e.player.stats.lost += 1
		match e.ukind:
			"inf":
				fx.inf_death(e.pos, e.last_attacker != null and is_instance_valid(e.last_attacker) and e.last_attacker.get("weapon") != null and not e.last_attacker.weapon.is_empty() and e.last_attacker.weapon.get("proj", "") == "tesla")
			"veh":
				fx.explosion(e.pos, 1.8 if e.def.get("harvester", false) or e.def.has("mcv") else 1.3)
			"air":
				fx.explosion(e.pos, 1.6, e.alt * 0.5)
				fx.explosion(e.pos, 1.2)
	else:
		buildings.erase(e)
		remove_building_cells(e)
		e.player.stats.bld_lost += 1
		e.player.power_dirty = true
		var s: float = (e.size.x + e.size.y) * 0.5
		fx.explosion(e.pos, 1.2 + s * 0.5)
		for k in int(s * 2):
			var off := Vector2(randf_range(-0.5, 0.5) * e.size.x, randf_range(-0.5, 0.5) * e.size.y)
			var tp: Vector2 = e.pos + off
			events.append({"t": time + randf_range(0.1, 0.8), "fn": func(): fx.explosion(tp, 1.0 + randf() * 0.6)})
		if not e.occupants.is_empty():
			var occ: Array = e.occupants.duplicate()
			e.occupants.clear()
			for o in occ:
				var c := nearest_free(e.exit_cell(), 4)
				if c.x >= 0:
					var u = spawn_unit(e.player, o.id, Vector2(c) + Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)))
					u.hp = maxf(10.0, float(o.hp) * 0.5)
		if e.def.get("explode", false):
			fx.explosion(e.pos, 3.0)
			damage_area(e.pos, 2.5, 400.0, "he", null, null, null, true)
		if not e.def.get("wall", false) and not e.def.get("civ", false) and e.def.role != "def" and not e.player.neutral:
			var n := randi_range(0, 2)
			for k in n:
				var inf_id: String = Defs.FACTIONS.get(e.def.faction, {"infantry": "a_gi"}).get("infantry", "a_gi")
				var c := nearest_free(e.exit_cell(), 3)
				if c.x >= 0:
					spawn_unit(e.player, inf_id, Vector2(c) + Vector2(randf(), randf()) * 0.8 + Vector2(0.1, 0.1))
		if e.player == human:
			message("%s 被摧毀了" % e.def.name)

func quick_save():
	if game_over:
		return
	if SaveS.save_game(self, 0):
		message("已快速存檔（F9 讀取）")
		Sfx.play("click", -4.0)
	else:
		message("存檔失敗")

# ───────────────────────── 外交 ─────────────────────────
var diplo_t := 0.0

func others_of(p) -> Array:
	var out := []
	for q in players:
		if q != p and not q.neutral and q.alive:
			out.append(q)
	return out

func strength(p) -> float:
	var s := 0.0
	for u in units:
		if u.player == p and not u.dead:
			s += float(u.def.cost) * 0.5
	for b in buildings:
		if b.player == p and not b.dead:
			s += float(b.def.cost) * 0.3
	return s

func update_diplomacy(dt: float):
	diplo_t -= dt
	if diplo_t > 0.0:
		return
	diplo_t = 10.0
	# 好感度隨時間緩慢回升；停火到期
	for p in players:
		if p.neutral or not p.alive:
			continue
		for q in others_of(p):
			if not p.is_enemy_of(q):
				p.add_relation(q, 1.0)
			else:
				p.add_relation(q, 0.3)
		for k in p.ceasefire.keys():
			if time >= float(p.ceasefire[k]):
				p.ceasefire.erase(k)
				if p == human:
					message("與 %s 的停火協議到期" % players[k].name)
	# AI 主動提議
	for ai in ais:
		var p = ai.p
		if not p.alive or p.allies.has(human.index) or human.proposal.has(p.index):
			continue
		if randf() > 0.25:
			continue
		var enemies_n := 0
		for q in others_of(p):
			if p.is_enemy_of(q):
				enemies_n += 1
		if enemies_n >= 2 and p.relation(human) >= 45.0 and strength(human) > strength(p) * 0.8:
			human.proposal[p.index] = "ally"
			message("%s 提議與你結盟！按 T 開啟外交面板回應" % p.name)
			Sfx.play("radio", -4.0)
		elif p.relation(human) >= 30.0 and p.relation(human) < 45.0 and strength(human) > strength(p) * 1.5 and human.is_enemy_of(p):
			human.proposal[p.index] = "ceasefire"
			message("%s 提議停火 3 分鐘。按 T 開啟外交面板回應" % p.name)
			Sfx.play("radio", -4.0)

func propose(from, to, kind: String) -> bool:
	# 玩家向 AI 提議；回傳是否接受
	if time < from.no_treaty_until or time < to.no_treaty_until:
		message("輿論風向不利，目前無法締結條約")
		return false
	var rel: float = to.relation(from)
	var ok := false
	var enemies_n := 0
	for q in others_of(to):
		if to.is_enemy_of(q) and q != from:
			enemies_n += 1
	match kind:
		"ally":
			ok = rel >= 50.0 and (enemies_n >= 1 or strength(from) >= strength(to) * 1.3 or rel >= 70.0)
		"ceasefire":
			ok = rel >= 35.0
	if ok:
		apply_treaty(from, to, kind)
	else:
		to.add_relation(from, -3.0)
		if from == human:
			message("%s 拒絕了提議（好感度 %d%%，需要 %d%%）" % [to.name, int(rel), 50 if kind == "ally" else 35])
	return ok

func apply_treaty(a, b, kind: String):
	if a == human or b == human:
		RecS.bump("treaties")
	match kind:
		"ally":
			a.allies[b.index] = true
			b.allies[a.index] = true
			a.ceasefire.erase(b.index)
			b.ceasefire.erase(a.index)
			a.add_relation(b, 20.0)
			b.add_relation(a, 20.0)
			message("%s 與 %s 締結同盟！共享視野，可呼叫盟友支援" % [a.name, b.name])
			Sfx.say("building_ready", 1.0)
			if a == human or b == human:
				var other = b if a == human else a
				for u in units:
					if u.player == other and not u.dead:
						reveal_entity(u)
				for bb in buildings:
					if bb.player == other and not bb.dead:
						reveal_entity(bb)
				# 盟友支援能力
				human.powers["allyaid"] = human.powers.get("allyaid", 0.0)
			for u in units:
				if (u.player == a and u.target != null and is_instance_valid(u.target) and u.target.player == b) or (u.player == b and u.target != null and is_instance_valid(u.target) and u.target.player == a):
					u.cmd_stop()
		"ceasefire":
			a.ceasefire[b.index] = time + 180.0
			b.ceasefire[a.index] = time + 180.0
			message("%s 與 %s 停火 3 分鐘" % [a.name, b.name])
	a.proposal.erase(b.index)
	b.proposal.erase(a.index)

func break_treaty(a, b):
	a.allies.erase(b.index)
	b.allies.erase(a.index)
	a.ceasefire.erase(b.index)
	b.ceasefire.erase(a.index)
	a.add_relation(b, -40.0)
	b.add_relation(a, -40.0)
	message("%s 撕毀了與 %s 的同盟！" % [a.name, b.name])
	Sfx.play("alarm", -4.0)
	if a == human or b == human:
		var any := false
		for q in others_of(human):
			if human.allies.has(q.index):
				any = true
		if not any:
			human.powers.erase("allyaid")

func human_allies() -> Array:
	var out := []
	for q in others_of(human):
		if human.allies.has(q.index):
			out.append(q)
	return out

func notify_attack(victim, attacker):
	# 攻擊盟友會導致同盟破裂
	if attacker != null and is_instance_valid(attacker) and attacker.player != victim.player:
		var ap = attacker.player
		var vp = victim.player
		if vp.allies.has(ap.index) and ap == human:
			vp.set_meta("ally_hits", int(vp.get_meta("ally_hits", 0)) + 1)
			if int(vp.get_meta("ally_hits", 0)) > 6:
				vp.set_meta("ally_hits", 0)
				break_treaty(ap, vp)
	for ai in ais:
		if ai.p == victim.player:
			ai.on_attacked(victim, attacker)

func debug_battle():
	var c := Vector2(W, H) * 0.5
	reveal(c, 200.0)
	var e = players[1]
	var ids_h := ["a_tank", "a_tank", "a_himars", "a_beam", "a_jav", "a_jav", "a_ew", "a_tb2", "a_fpv", "a_fpv", "a_gi", "a_gi"] if human.faction == "allies" else ["s_tank", "s_tank", "s_mammoth", "s_arty", "s_con", "s_con", "s_tesla", "s_flak"]
	var ids_e := ["s_tank", "s_tank", "s_tos", "s_mammoth", "s_iskander", "s_con", "s_con", "s_tesla", "s_lancet", "s_lancet", "s_shahed", "s_ew"] if e.faction == "soviet" else ["a_tank", "a_tank", "a_beam", "a_ifv", "a_gi", "a_gi", "a_rocket", "a_cmdo"]
	if G.settings.has("debug_units"):
		ids_h = str(G.settings.debug_units).split(",")
	for k in ids_h.size():
		var sp := c + Vector2(3 + (k % 3), 3 + k / 3)
		if Defs.UNITS[ids_h[k]].kind == "ship":
			var wc: Vector2i = nearest_water(Vector2i(int(c.x), int(c.y)), 40)
			if wc.x >= 0:
				sp = Vector2(wc) + Vector2(0.5, 0.5)
				c = sp + Vector2(-6, -6)
				reveal(sp, 30.0)
		var u = spawn_unit(human, ids_h[k], sp)
		u.cmd_move(c + Vector2(-2, -2), true)
	for k in ids_e.size():
		var u = spawn_unit(e, ids_e[k], c + Vector2(-4 - (k % 3), -4 - k / 3))
		u.cmd_move(c + Vector2(3, 3), true)
	var b = place_building(e, "s_tcoil" if e.faction == "soviet" else "a_prism", Vector2i(int(c.x) - 1, int(c.y) + 2), true)
	center_on(c)

func enable_autopilot():
	var ai = AIS.new()
	ai.setup(self, human, 1)
	ais.append(ai)
	for p in players:
		pass

func spy_enter(u, b):
	var tp = b.player
	var me = u.player
	var msg := ""
	if me == human:
		RecS.bump("spies")
	match b.def.role:
		"power":
			tp.energy_cut_until = maxf(tp.energy_cut_until, time + 45.0)
			tp.power_dirty = true
			msg = "間諜破壞了 %s 的發電廠，敵方停電 45 秒" % tp.name
		"ref", "bank":
			var amt: float = maxf(500.0, tp.money * 0.2)
			amt = minf(amt, tp.money)
			tp.money -= amt
			me.money += amt
			msg = "間諜從 %s 竊取了 $%d" % [tp.name, int(amt)]
			fx.coins(b.pos)
		"radar":
			for o in buildings:
				if o.player == tp and not o.dead and me == human:
					reveal(o.pos, 5.0)
			msg = "間諜取得 %s 的雷達情報，敵方基地已揭露" % tp.name
		"sw":
			for k in tp.powers.keys():
				tp.powers[k] = 0.0
			msg = "間諜重置了 %s 的超級武器倒數！" % tp.name
		"tech":
			me.vet_bonus = true
			msg = "間諜竊取科技：我方新生產的單位將直接晉升老兵"
		"cy", "bar", "fac", "yard", "dronehub", "airfield":
			tp.sabotage_until = maxf(tp.sabotage_until, time + 60.0)
			msg = "間諜癱瘓了 %s 的生產線 60 秒" % tp.name
		_:
			msg = "間諜滲透了 %s，但沒有取得有用情報" % b.def.name
	if me == human:
		message(msg)
		Sfx.play("cash", -4.0)
		if mission != null:
			mission.on_spy(b)
	elif tp == human:
		message("警告：敵方間諜滲透了我方 %s！" % b.def.name)
		Sfx.play("alarm", -4.0)
	fx.scan_ring(b.pos, Color(1.0, 0.9, 0.3))
	remove_unit_silent(u)

func engineer_enter(u, b):
	if u.def.get("spy", false):
		if b.player != u.player and u.player.is_enemy_of(b.player):
			spy_enter(u, b)
		else:
			u.cmd_stop()
		return
	if b.player == u.player:
		if b.hp < b.max_hp:
			b.hp = b.max_hp
			if u.player == human:
				message("%s 已修復" % b.def.name)
	elif b.def.get("wall", false):
		u.cmd_stop()
		return
	else:
		var old = b.player
		b.player = u.player
		b.repairing = false
		b.capture_flash = 1.2
		b.target = null
		old.power_dirty = true
		u.player.power_dirty = true
		if b.def.role == "oil":
			u.player.money += 500
		if u.player == human:
			message("已佔領 %s！" % b.def.name)
			Sfx.say("building_ready", 1.0)
		elif old == human:
			message("警告：%s 被敵軍佔領！" % b.def.name)
			Sfx.play("alarm", -4.0)
	remove_unit_silent(u)

func plant_c4(u, t):
	Sfx.play("tick", -2.0, t.pos)
	var wt = weakref(t)
	var wu = weakref(u)
	events.append({"t": time + 1.2, "fn": func():
		var tt = wt.get_ref()
		var uu = wu.get_ref()
		if tt != null and not tt.dead:
			tt.hp = 1.0
			tt.take_damage(1e6, uu if uu != null and not uu.dead else null, "he")
	})

func try_deploy(u):
	var tl := Vector2i(int(floor(u.pos.x)) - 1, int(floor(u.pos.y)) - 1)
	var id: String = u.def.mcv
	for off in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
		if can_place(id, tl + off, u.player, u, false):
			var p = u.player
			remove_unit_silent(u)
			place_building(p, id, tl + off)
			Sfx.play("deploy", 0.0, u.pos)
			if p == human:
				message("基地車展開中……")
			return
	if u.player == human:
		message("這裡無法展開基地車，請移到較空曠的地方")
		Sfx.play("click", -2.0)

func remove_unit_silent(u):
	u.dead = true
	units.erase(u)
	selection.erase(u)
	for k in groups:
		groups[k].erase(u)
	u.queue_free()

func sell(b):
	if b.selling or b.dead or not b.built():
		return
	b.selling = true
	b.sell_t = 0.0
	b.repairing = false
	Sfx.play("sell", -2.0)

func finish_sell(b):
	var refund: float = float(b.def.cost) * 0.5 * b.hp / b.max_hp
	b.player.money += refund
	var f: String = b.def.faction
	b.dead = true
	buildings.erase(b)
	remove_building_cells(b)
	if not b.def.get("wall", false) and Defs.FACTIONS.has(f):
		var inf_id: String = Defs.FACTIONS[f].infantry
		for k in randi_range(1, 3):
			var c := nearest_free(b.exit_cell(), 4)
			if c.x >= 0:
				spawn_unit(b.player, inf_id, Vector2(c) + Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)))
	b.player.power_dirty = true
	selection.erase(b)
	if b.player == human:
		Sfx.play("cash", -2.0)
	b.queue_free()

func on_power_ready(p, kind: String):
	if p == human:
		message("特殊武器「%s」已就緒！" % Defs.SUPER[kind].name)
		Sfx.play("alarm", -8.0)
	for ai in ais:
		if ai.p == p:
			ai.power_ready(kind)

func player_at(target: Vector2, attacker):
	# the enemy player owning the building nearest the target point
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.dead or not attacker.is_enemy_of(b.player):
			continue
		var d: float = b.dist_to(target)
		if d < bd:
			bd = d
			best = b.player
	if best == null:
		for q in players:
			if attacker.is_enemy_of(q) and q.alive:
				return q
	return best

func fire_power(p, kind: String, target: Vector2) -> bool:
	if float(p.powers.get(kind, 0.0)) < 1.0:
		return false
	var tp = null
	if Defs.SUPER[kind].target == "enemy":
		tp = player_at(target, p)
		if tp == null:
			return false
	p.powers[kind] = 0.0
	if p == human:
		RecS.bump("powers")
	if p == human and mission != null:
		mission.on_power(kind)
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  POWER t=%d %s %s" % [int(time), p.name, kind])
	match kind:
		"nuke":
			fire_nuke(p, target)
		"storm":
			fire_storm(target)
		"sanction":
			var frozen: float = tp.money * 0.3
			tp.money -= frozen
			tp.sanctioned_until = time + 90.0
			message("金融制裁生效！%s 被凍結 $%d 資金，收入與生產大幅下降 90 秒" % [tp.name, int(frozen)] if p == human else "警告：我方遭受金融制裁！資金被凍結 $%d，收入與生產下降" % int(frozen))
			Sfx.play("cash" if p == human else "alarm", 0.0)
			for b in buildings:
				if b.player == tp and not b.dead:
					fx.coins(b.pos)
		"energy":
			tp.energy_cut_until = time + 60.0
			tp.power_dirty = true
			message("能源斷供！%s 全面停電 60 秒" % tp.name if p == human else "警告：敵方切斷能源供應！我方全面停電 60 秒")
			Sfx.play("power_down", 0.0)
			for b in buildings:
				if b.player == tp and not b.dead and b.def.role == "power":
					fx.smoke(b.pos, 30.0)
		"swarm":
			var hub = null
			for b in buildings:
				if b.player == p and not b.dead and b.def.get("power_sw", "") == "swarm":
					hub = b
			var src: Vector2 = hub.pos if hub != null else target
			var did: String = "a_fpv" if p.faction == "allies" else "s_lancet"
			var n := 8 if did == "a_fpv" else 6
			for k in n:
				var u = spawn_unit(p, did, src + Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)))
				u.cmd_move(target + Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
				u.set_meta("swarm", true)
			message("無人機蜂群已出擊！" if p == human else "警告：偵測到敵方無人機蜂群！")
			Sfx.play("jet", -2.0)
		"scan":
			if p == human:
				reveal(target, 11.0)
				fx.scan_ring(target)
				message("星鏈衛星掃描完成")
		"jam":
			for u in units.duplicate():
				if not u.dead and u.def.get("drone", false) and p.is_enemy_of(u.player) and u.pos.distance_to(target) <= 6.0:
					u.take_damage(1e5, null, "ap")
			for b in buildings:
				if not b.dead and p.is_enemy_of(b.player) and b.dist_to(target) <= 6.0:
					b.set_meta("jam_until", time + 25.0)
			fx.scan_ring(target, Color(0.3, 1.0, 0.5))
			message("GPS 干擾啟動：區域內敵方無人機墜毀、防禦失效" if p == human else "警告：敵方實施電子干擾！")
			Sfx.play("zap", 0.0)
		"paradrop":
			var ids := ["a_gi", "a_gi", "a_gi", "a_gi", "a_gi", "a_jav", "a_jav", "a_rocket", "a_rocket"]
			for k in ids.size():
				var at := target + Vector2(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6))
				var c := nearest_free(Vector2i(int(at.x), int(at.y)), 5)
				if c.x < 0:
					continue
				var u = spawn_unit(p, ids[k], Vector2(c) + Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)))
				u.set_meta("para_t", 2.2 + k * 0.18)
			if p == human:
				reveal(target, 5.0)
			message("空降部隊出發！" if p == human else "警告：敵方空降部隊！")
			Sfx.play("jet", -2.0)
		"barrage", "strait", "df":
			var src: Vector2 = Vector2(p.start_cell)
			var n := 10 if kind == "barrage" else (8 if kind == "strait" else 6)
			var r: float = Defs.SUPER[kind].radius
			for k in n:
				var mp := target + Vector2.from_angle(randf() * TAU) * randf() * r
				var dmg := 260.0 if kind == "barrage" else (200.0 if kind == "strait" else 420.0)
				fx.projs.append({"kind": "ballistic", "from": src + Vector2(randf_range(-1, 1), randf_range(-1, 1)), "to": mp, "z0": 20.0, "z1": 0.0,
					"t": -k * (0.22 if kind != "df" else 0.12), "dur": 2.4 if kind == "barrage" else (1.6 if kind == "strait" else 1.1), "target": null, "dmg": dmg,
					"wh": "he" if kind == "barrage" else ("topatk" if kind == "strait" else "antiship"), "att": null, "splash": 1.4 if kind == "barrage" else (1.0 if kind == "strait" else 1.6),
					"arc": 420.0 if kind == "barrage" else (160.0 if kind == "strait" else 300.0), "trail": 0.0, "owner": p})
			message(("%s 發射！" % Defs.SUPER[kind].name) if p == human else ("警告：偵測到敵方%s！" % Defs.SUPER[kind].name))
			Sfx.play("missile", 0.0)
		"militia", "armor":
			var home = null
			for b in buildings:
				if b.player == p and not b.dead and b.def.role == ("fac" if kind == "armor" else "cy"):
					home = b
			if home == null:
				for b in buildings:
					if b.player == p and not b.dead:
						home = b
			if home == null:
				return true
			var ids: Array = ["s_tank", "s_tank", "s_mammoth"] if kind == "armor" else ["s_con", "s_con", "s_con", "s_con", "s_con", "s_con", "s_flak", "s_flak", "s_con", "s_con"]
			for id in ids:
				var ex: Vector2 = home.exit_pos() if home.has_method("exit_pos") else home.pos + Vector2(0, float(home.size.y) * 0.5 + 1.0)
				var c := nearest_free(Vector2i(int(ex.x), int(ex.y)), 6)
				if c.x >= 0:
					var u = spawn_unit(p, id, Vector2(c) + Vector2(0.5, 0.5))
					u.cmd_move(Vector2(c) + Vector2(randf_range(-2, 2), randf_range(0, 3)))
			message("%s！部隊已在基地集結" % Defs.SUPER[kind].name if p == human else "警告：敵方大規模動員！")
			Sfx.play("deploy", 0.0)
		"allyaid":
			var fired := false
			for q in human_allies():
				for k in q.powers.keys():
					if k in ["nuke", "storm", "barrage", "df", "strait", "swarm"] and float(q.powers[k]) >= 1.0 and not fired:
						fire_power(q, k, target)
						fired = true
						message("盟友 %s 發動「%s」支援！" % [q.name, Defs.SUPER[k].name])
				if fired:
					break
			if not fired:
				var n := 0
				for q in human_allies():
					var ids: Array = ["a_tank", "a_tank", "a_ifv", "a_rocket", "a_gi"] if q.faction == "allies" else ["s_tank", "s_tank", "s_flaktrk", "s_tesla", "s_con"]
					for id in ids:
						var c := nearest_free(Vector2i(int(q.start_cell.x), int(q.start_cell.y)) + Vector2i(randi_range(-3, 3), randi_range(-3, 3)), 6)
						if c.x >= 0:
							var u = spawn_unit(q, id, Vector2(c) + Vector2(0.5, 0.5))
							u.cmd_move(target, true)
							n += 1
				message("盟友派出 %d 個單位支援！" % n)
			Sfx.play("radio", -2.0)
		"blockade":
			var r: float = Defs.SUPER[kind].radius
			for u in units.duplicate():
				if not u.dead and p.is_enemy_of(u.player) and u.pos.distance_to(target) <= r:
					u.take_damage(450.0 if u.ukind == "ship" else 120.0, null, "he")
					fx.explosion(u.pos, 1.2)
			for k in 6:
				var mp := target + Vector2.from_angle(randf() * TAU) * randf() * r
				events.append({"t": time + randf_range(0.1, 1.2), "fn": func(): fx.explosion(mp, 1.0)})
			var tp2 = player_at(target, p)
			if tp2 != null:
				tp2.sanctioned_until = maxf(tp2.sanctioned_until, time + 60.0)
			message("海峽封鎖！敵方航運中斷，收入下降 60 秒" if p == human else "警告：敵方實施海峽封鎖！收入下降")
			Sfx.play("big_explode", 0.0)
	ping(target)
	return true

func fire_nuke(p, target: Vector2):
	message("警告：偵測到核彈發射！")
	Sfx.play("alarm", 0.0)
	Sfx.play("missile", 0.0)
	var silo = null
	for b in buildings:
		if b.player == p and b.def.get("super", "") == "nuke" and not b.dead:
			silo = b
	if silo != null:
		fx.projs.append({"kind": "rocket", "from": silo.pos, "to": silo.pos, "z0": 20.0, "z1": 900.0, "t": 0.0, "dur": 1.5,
			"target": null, "dmg": 0.0, "wh": "he", "att": null, "splash": 0.0, "arc": 0.0, "trail": 0.0, "owner": p})
	fx.projs.append({"kind": "rocket", "from": target + Vector2(-2, -2), "to": target, "z0": 900.0, "z1": 0.0, "t": -3.0, "dur": 1.0,
		"target": null, "dmg": 0.0, "wh": "he", "att": null, "splash": 0.0, "arc": 0.0, "trail": 0.0, "owner": p})
	events.append({"t": time + 4.0, "fn": func():
		fx.nuke_blast(target)
		damage_area(target, 4.5, 1400.0, "he", null, null, null, true)
		for k in 10:
			var tp := target + Vector2(randf_range(-3, 3), randf_range(-3, 3))
			events.append({"t": time + randf_range(0.2, 1.5), "fn": func(): fx.explosion(tp, 1.5)})
	})

func fire_storm(target: Vector2):
	message("警告：閃電風暴即將降臨！")
	Sfx.play("alarm", 0.0)
	Sfx.play("thunder", 0.0)
	for k in 34:
		var dt := 1.5 + k * 0.25
		events.append({"t": time + dt, "fn": func():
			var tp := target + Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 3.8
			fx.lightning(tp)
			fx.explosion(tp, 0.8)
			damage_area(tp, 1.4, 260.0, "elec", null, null, null, true)
			if randf() < 0.35:
				Sfx.play("thunder", -4.0, tp)
		})

func can_garrison(u, b) -> bool:
	if b.kind != "building" or not b.def.has("garrison") or u.ukind != "inf" or u.weapon.is_empty():
		return false
	if b.occupants.size() >= int(b.def.garrison):
		return false
	return b.player.neutral or b.player == u.player

func garrison_enter(u, b):
	if not can_garrison(u, b):
		u.cmd_stop()
		return
	b.occupants.append({"id": u.type_id, "hp": u.hp, "rank": u.rank, "kills": u.kills, "w": u.weapon})
	b.occ_cd.append(0.0)
	if b.player != u.player:
		b.player = u.player
		b.capture_flash = 0.6
	if u.player == human:
		Sfx.play("click", -4.0)
	remove_unit_silent(u)

func garrison_exit(b):
	var p = b.player
	for o in b.occupants:
		var c := nearest_free(b.exit_cell(), 4)
		if c.x < 0:
			continue
		var u = spawn_unit(p, o.id, Vector2(c) + Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)))
		u.hp = minf(u.max_hp, float(o.hp))
		u.rank = int(o.rank)
		u.kills = int(o.kills)
	b.occupants.clear()
	b.occ_cd.clear()
	b.player = neutral

func update_crates(dt: float):
	if mission != null or not settings.get("crates", true):
		return
	crate_t -= dt
	if crate_t <= 0.0 and crates.size() < 6:
		crate_t = randf_range(35.0, 60.0)
		for attempt in 30:
			var c := Vector2i(randi_range(4, W - 5), randi_range(4, H - 5))
			if map.passable(c.x, c.y) and bld_at(c.x, c.y) == null and not map.has_ore(c.x, c.y):
				var kinds := ["money", "money", "money", "heal", "veteran", "reveal", "unit"]
				var cr = CrateS.new()
				cr.setup(c, kinds[randi() % kinds.size()])
				objects.add_child(cr)
				crates.append(cr)
				break
	for cr in crates.duplicate():
		for u in units:
			if u.dead or u.ukind == "air" or u.ukind == "ship" or u.player.neutral:
				continue
			if int(u.pos.x) == cr.cell.x and int(u.pos.y) == cr.cell.y:
				pick_crate(u, cr)
				break

func pick_crate(u, cr):
	crates.erase(cr)
	var p = u.player
	var txt := ""
	match cr.kind:
		"money":
			var amt := randi_range(8, 20) * 100
			p.money += amt
			txt = "補給箱：獲得 $%d" % amt
			Sfx.play("cash", -2.0, u.pos)
		"heal":
			for o in units:
				if o.player == p and o.pos.distance_to(u.pos) < 5.0:
					o.hp = o.max_hp
			txt = "補給箱：附近單位完全修復"
			fx.scan_ring(u.pos, Color(0.4, 1.0, 0.5))
		"veteran":
			for o in units:
				if o.player == p and o.pos.distance_to(u.pos) < 4.0 and o.rank < 2:
					o.rank += 1
					o.kills = maxi(o.kills, 3 * o.rank)
			txt = "補給箱：附近單位晉升！"
			fx.scan_ring(u.pos, Color(1.0, 0.85, 0.3))
		"reveal":
			if p == human:
				reveal(u.pos, 30.0)
			txt = "補給箱：揭露地圖"
		"unit":
			var id: String = "a_tank" if p.faction == "allies" else "s_tank"
			spawn_unit(p, id, u.pos + Vector2(0.8, 0.8))
			txt = "補給箱：獲得一輛坦克！"
	if p == human:
		message(txt)
	cr.queue_free()

func drone_detonate(u, t):
	var tp: Vector2 = t.closest_point(u.pos) if t.kind == "building" else t.pos
	var w: Dictionary = u.weapon
	fx.explosion(tp, 1.3 if u.type_id != "a_fpv" else 0.9, 4.0)
	damage_area(tp, float(w.get("splash", 0.6)), float(w.dmg) * u.dmg_mult(), w.wh, u, t)
	remove_unit_silent(u)

# EW: enemy drones inside jamming range crash
var ew_t := 0.0
func update_ew(dt: float):
	ew_t -= dt
	if ew_t > 0.0:
		return
	ew_t = 0.25
	var srcs: Array = []
	for u in units:
		if not u.dead and u.def.has("ew"):
			srcs.append([u.player, u.pos, float(u.def.ew)])
	for b in buildings:
		if not b.dead and b.def.has("ew") and b.built() and not b.player.low_power:
			srcs.append([b.player, b.pos, float(b.def.ew)])
	if srcs.is_empty():
		return
	for u in units.duplicate():
		if u.dead or not u.def.get("drone", false):
			continue
		for s in srcs:
			if s[0].is_enemy_of(u.player) and u.pos.distance_to(s[1]) <= s[2]:
				u.jam_t = 0.3
				u.hp -= 45.0 * 0.25
				if randf() < 0.3:
					fx.spark(u.pos, u.alt, Color(0.5, 1.0, 0.6))
				if u.hp <= 0.0:
					u.hp = 0.0
					u.die()
				break

func message(t: String):
	if hud != null:
		hud.add_message(t)

func ping(p: Vector2):
	if hud != null:
		hud.ping(p)

# ───────────────────────── shroud ─────────────────────────
func is_explored(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	return explored[y * W + x] == 1

func reveal(c: Vector2, r: float):
	var r2 := r * r
	var changed := false
	for y in range(int(c.y - r), int(c.y + r) + 1):
		if y < 0 or y >= H:
			continue
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if x < 0 or x >= W:
				continue
			var i := y * W + x
			if explored[i] == 0 and Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length_squared() <= r2:
				explored[i] = 1
				changed = true
				if hud != null and hud.mm_mask != null:
					hud.mm_mask.set_pixel(x, y, Color(0, 0, 0, 0))
	if changed:
		shroud_dirty = true
		shroud.reveal_circle(c, r + 0.8)

func reveal_entity(e):
	var r: float = e.sight + (1.5 if e.kind == "building" else 0.0)
	if e.kind == "building":
		reveal(e.pos, r + e.size.x * 0.5)
	else:
		reveal(e.pos, r)

func reveal_all_now():
	for u in units:
		if u.player == human:
			reveal_entity(u)
	for b in buildings:
		if b.player == human:
			reveal_entity(b)
	shroud.queue_redraw()
	map.ore_dirty = true

func update_visibility():
	for u in units:
		if u.player == human or human.allies.has(u.player.index):
			var k := int(u.pos.x) * 1000 + int(u.pos.y)
			if u.get_meta("rk", -1) != k:
				u.set_meta("rk", k)
				reveal_entity(u)
		else:
			u.visible = is_explored(int(u.pos.x), int(u.pos.y))
	for b in buildings:
		if b.player == human or human.allies.has(b.player.index):
			if not b.has_meta("rv"):
				b.set_meta("rv", true)
				reveal_entity(b)
		else:
			b.visible = is_explored(b.cell.x, b.cell.y) or is_explored(b.cell.x + b.size.x - 1, b.cell.y + b.size.y - 1)
	if shroud_dirty:
		shroud_dirty = false
		map.ore_dirty = true

# ───────────────────────── main loop ─────────────────────────
func _process(delta: float):
	update_camera(delta)
	map.activate_chunks()
	if paused or game_over:
		overlay.queue_redraw()
		return
	var dt := minf(delta, 0.05) * speed
	time += dt
	rebuild_buckets()
	for p in players:
		p.update(dt)
	for u in units.duplicate():
		if not u.dead:
			u.update(dt)
	for b in buildings.duplicate():
		if not b.dead:
			b.update(dt)
	fx.update(dt)
	update_ew(dt)
	update_diplomacy(dt)
	if world_ev != null:
		world_ev.update(dt)
	map.update(dt)
	for ai in ais:
		ai.update(dt)
	for i in range(events.size() - 1, -1, -1):
		if events[i].t <= time:
			var ev = events[i]
			events.remove_at(i)
			ev.fn.call()
	for i in range(markers.size() - 1, -1, -1):
		markers[i].t += dt
		if markers[i].t > 0.8:
			markers.remove_at(i)
	reveal_t -= dt
	if reveal_t <= 0.0:
		reveal_t = 0.25
		update_visibility()
	check_t -= dt
	if check_t <= 0.0:
		check_t = 1.0
		check_victory()
		update_crates(1.0)
	ack_t -= dt
	update_hover()
	overlay.queue_redraw()

func check_victory():
	for p in players:
		if p.neutral or not p.alive:
			continue
		if mission != null and mission.id == "m1" and p == human:
			continue
		var has := false
		for b in buildings:
			if b.player == p and not b.dead and not b.def.get("wall", false) and not b.def.get("civ", false):
				has = true
				break
		if not has:
			for u in units:
				if u.player == p and not u.dead and u.def.has("mcv"):
					has = true
					break
		if not has:
			p.alive = false
			if p != human:
				message("%s 已被消滅！" % p.name)
			for u in units.duplicate():
				if u.player == p and not u.dead:
					u.take_damage(1e6, null, "he")
			for b in buildings.duplicate():
				if b.player == p and not b.dead:
					b.take_damage(1e6, null, "he")
	if mission != null:
		var r: String = mission.check()
		if r != "":
			end_game(r == "win")
		return
	if not human.alive:
		end_game(false)
		return
	var any_enemy := false
	for p in players:
		if p.alive and not p.neutral and p.team != human.team:
			any_enemy = true
	if not any_enemy:
		end_game(true)

func end_game(win: bool):
	if game_over:
		return
	game_over = true
	result = "win" if win else "lose"
	cmd_mode = ""
	place_id = ""
	if win and mission != null:
		G.mark_mission_done(mission.id)
	var fresh: Array = [] if settings.get("auto", false) and not settings.get("rec_test", false) else RecS.on_game_end(self, win)
	hud.show_end(win, fresh)

# ───────────────────────── camera ─────────────────────────
func center_on(p: Vector2, instant := false):
	var vs := get_viewport_rect().size
	cam.position = iso(p) + Vector2(hud_width() * 0.5 / zoom if hud != null else 110.0, 0)
	clamp_cam()

func hud_width() -> float:
	return 232.0

func clamp_cam():
	var vs := get_viewport_rect().size / zoom
	var minx := -H * G.HW - 100
	var maxx := W * G.HW + 100 + hud_width() / zoom
	var miny := -80.0
	var maxy := (W + H) * G.HH + 80
	cam.position.x = clampf(cam.position.x, minx + vs.x * 0.5, maxx - vs.x * 0.5) if maxx - minx > vs.x else (minx + maxx) * 0.5
	cam.position.y = clampf(cam.position.y, miny + vs.y * 0.5, maxy - vs.y * 0.5) if maxy - miny > vs.y else (miny + maxy) * 0.5

func update_camera(delta: float):
	var v := Vector2.ZERO
	var spd := 1100.0 / zoom
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if Input.is_key_pressed(KEY_UP):
		v.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		v.y += 1
	var mp := get_viewport().get_mouse_position()
	var vs := get_viewport_rect().size
	if G.settings.get("edge_scroll", true) and DisplayServer.window_is_focused() and not panning:
		var m := 6.0
		if mp.x <= m:
			v.x -= 1
		elif mp.x >= vs.x - m:
			v.x += 1
		if mp.y <= m:
			v.y -= 1
		elif mp.y >= vs.y - m:
			v.y += 1
	if v != Vector2.ZERO:
		cam.position += v.normalized() * spd * delta
	clamp_cam()
	cam.zoom = Vector2(zoom, zoom)
	cam.offset = fx.shake_off() if fx != null else Vector2.ZERO

func iso(p: Vector2) -> Vector2:
	return G.iso(p) + map.elev_off(p)

func mouse_world() -> Vector2:
	var s := get_global_mouse_position()
	var w := G.uniso(s + Vector2(0, map.CL))
	if map.elev_at(w) == 1:
		var w2 := G.uniso(s + Vector2(0, map.CL * map.height_at(w)))
		if map.elev_at(w2) == 1:
			return w2
		return w
	return G.uniso(s)

func high_ground(ent, t) -> bool:
	if ent == null or t == null or ent.kind != "unit":
		return false
	return map.elev_at(ent.pos) == 1 and map.elev_at(t.pos) == 0

func sound_attenuation(wp: Vector2) -> float:
	var s := G.iso(wp) - cam.position
	var vs := get_viewport_rect().size / zoom
	var nx := absf(s.x) / (vs.x * 0.5)
	var ny := absf(s.y) / (vs.y * 0.5)
	var n := maxf(nx, ny)
	if n <= 1.0:
		return 0.0
	if n > 2.5:
		return -60.0
	return -(n - 1.0) * 14.0

# ───────────────────────── selection & input ─────────────────────────
func entity_at_screen(cp: Vector2):
	var best = null
	var bd := 1e9
	for u in units:
		if u.dead or not u.visible:
			continue
		var sp: Vector2 = u.position
		var off := 10.0 if u.ukind == "inf" else 12.0
		if u.ukind == "air":
			off = u.alt
		var d := cp.distance_to(sp - Vector2(0, off))
		var rad := 11.0 if u.ukind == "inf" else 20.0
		if u.ukind == "air":
			rad = 26.0 if u.def.get("airship", false) else 20.0
		if d < rad and d < bd:
			bd = d
			best = u
	if best != null:
		return best
	var w := G.uniso(cp)
	var b = bld_at(int(floor(w.x)), int(floor(w.y)))
	if b != null and b.visible:
		return b
	var by := -1e9
	for bb in buildings:
		if bb.dead or not bb.visible or bb.sheet == null:
			continue
		var r := Rect2(bb.position - Vector2(bb.sheet.ax, bb.sheet.ay) / bb.sheet.res * 0.8, Vector2(bb.sheet.w(), bb.sheet.h()) * 0.8)
		if r.has_point(cp) and cp.y < bb.position.y and bb.position.y > by:
			by = bb.position.y
			best = bb
	return best

func update_hover():
	var cp := get_global_mouse_position()
	var mp := get_viewport().get_mouse_position()
	if hud != null and hud.over_ui(mp):
		hover = null
		return
	hover = entity_at_screen(cp)

func select_list(list: Array, add := false):
	if not add:
		for e in selection:
			if is_instance_valid(e):
				e.selected = false
		selection.clear()
	for e in list:
		if not selection.has(e):
			selection.append(e)
			e.selected = true

func own_selected_units() -> Array:
	var out: Array = []
	for e in selection:
		if is_instance_valid(e) and not e.dead and e.kind == "unit" and e.player == human:
			out.append(e)
	return out

func _unhandled_input(ev: InputEvent):
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_zoom(zoom * 1.1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_zoom(zoom / 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed
		if game_over:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				left_press(mb)
			elif dragging:
				dragging = false
				var cp := get_global_mouse_position()
				if cp.distance_to(drag_start) > 8.0 / zoom:
					box_select(drag_start, cp, mb.shift_pressed)
				else:
					click_select(mb.shift_pressed, false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if place_id != "" or cmd_mode != "":
				place_id = ""
				cmd_mode = ""
				return
			context_order(mb.ctrl_pressed)
	elif ev is InputEventMouseMotion:
		if panning:
			cam.position -= (ev as InputEventMouseMotion).relative / zoom
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		key_press(ev as InputEventKey)

func set_zoom(z: float):
	var before := get_global_mouse_position()
	zoom = clampf(z, 0.55, 2.0)
	cam.zoom = Vector2(zoom, zoom)
	cam.force_update_scroll()
	var after := get_global_mouse_position()
	cam.position += before - after
	clamp_cam()

func left_press(mb: InputEventMouseButton):
	if place_id != "":
		try_place()
		return
	if cmd_mode.begins_with("power:"):
		var kind := cmd_mode.substr(6)
		if fire_power(human, kind, mouse_world()):
			cmd_mode = ""
		else:
			message("無效的目標")
		return
	match cmd_mode:
		"sell":
			var e = hover
			if e != null and e.kind == "building" and e.player == human:
				sell(e)
			if not mb.shift_pressed:
				cmd_mode = ""
			return
		"repair":
			var e = hover
			if e != null and e.kind == "building" and e.player == human:
				e.repairing = not e.repairing
				Sfx.play("click", -4.0)
			if not mb.shift_pressed:
				cmd_mode = ""
			return
		"amove":
			if mb.shift_pressed:
				for u in own_selected_units():
					u.queue_move(mouse_world(), true)
			else:
				command_move(own_selected_units(), mouse_world(), true)
				cmd_mode = ""
			return
	if mb.double_click:
		click_select(false, true)
		return
	dragging = true
	drag_start = get_global_mouse_position()

func click_select(shift: bool, dbl: bool):
	var e = hover
	if e == null:
		if not shift:
			select_list([])
		return
	if e.player == human:
		if dbl and e.kind == "unit":
			if e.def.has("mcv"):
				e.cmd_deploy()
				return
			var vs := get_viewport_rect().size / zoom
			var r := Rect2(cam.position - vs * 0.5, vs)
			var list: Array = []
			for u in units:
				if u.player == human and u.type_id == e.type_id and r.has_point(u.position):
					list.append(u)
			select_list(list, shift)
		elif shift:
			if selection.has(e):
				selection.erase(e)
				e.selected = false
			else:
				select_list([e], true)
		else:
			select_list([e])
			if e.kind == "building" and e.def.role in ["bar", "fac"] or e.kind == "building" and e.def.get("airfield", false):
				human.primary[e.def.role if not e.def.get("airfield", false) or e.def.role == "fac" else "airfield"] = e
		if e.kind == "unit":
			ack_select(e)
		else:
			Sfx.play("click", -8.0)
	else:
		select_list([e])

func ack_select(u):
	if ack_t > 0.0:
		return
	ack_t = 0.4
	Sfx.play("select", -6.0)

func box_select(a: Vector2, b: Vector2, add: bool):
	var r := Rect2(a, Vector2.ZERO).expand(b)
	var list: Array = []
	var combat := false
	for u in units:
		if u.player == human and not u.dead:
			var sp: Vector2 = u.position - Vector2(0, u.alt if u.ukind == "air" else 8.0)
			if r.has_point(sp):
				list.append(u)
				if not u.def.get("harvester", false):
					combat = true
	if combat:
		list = list.filter(func(u): return not u.def.get("harvester", false))
	select_list(list, add)
	if list.size() > 0:
		ack_select(list[0])

func context_order(force_fire := false):
	var list := own_selected_units()
	var wp := mouse_world()
	var t = hover
	if list.is_empty():
		for e in selection:
			if is_instance_valid(e) and e.kind == "building" and e.player == human and (e.def.role in ["bar", "fac", "yard", "dronehub"] or e.def.get("airfield", false)):
				e.rally = wp
				markers.append({"p": wp, "t": 0.0, "c": Color(0.3, 1, 0.3)})
				Sfx.play("click", -6.0)
		return
	Sfx.play("radio", -10.0)
	if t != null and t.kind == "building" and t.def.has("garrison") and (t.player.neutral or t.player == human):
		var rest: Array = []
		for u in list:
			if can_garrison(u, t):
				u.cmd_garrison(t)
			elif u.def.get("engineer", false):
				rest.append(u)
			else:
				rest.append(u)
		if rest.size() < list.size():
			markers.append({"p": t.pos, "t": 0.0, "c": Color(0.3, 0.8, 1.0)})
			if not rest.is_empty():
				command_move(rest, wp)
			return
	if t != null and t.player != human and t.visible:
		var enemy: bool = human.is_enemy_of(t.player)
		var any := false
		for u in list:
			if u.def.get("spy", false) and t.kind == "building" and enemy and not t.def.get("wall", false) and not t.def.get("civ", false):
				u.cmd_capture(t)
				any = true
			elif u.def.get("engineer", false) and t.kind == "building" and not t.def.get("wall", false) and not t.def.get("civ", false):
				u.cmd_capture(t)
				any = true
			elif enemy or force_fire:
				if u.def.get("c4", false) and t.kind == "building":
					u.cmd_attack(t)
				elif u.can_hit(u.weapon, t):
					u.cmd_attack(t)
				elif not u.weapon.is_empty() or u.def.get("c4", false):
					u.cmd_attack(t)
			else:
				u.cmd_move(t.pos)
			any = true
		markers.append({"p": t.pos, "t": 0.0, "c": Color(1, 0.25, 0.2)})
		unit_ack(list, human.is_enemy_of(t.player))
		return
	if t != null and t.player == human and t.kind == "building":
		var rest: Array = []
		for u in list:
			if u.def.get("harvester", false) and t.def.role == "ref":
				u.cmd_dock(t)
			elif u.def.get("engineer", false) and t.hp < t.max_hp:
				u.cmd_capture(t)
			elif force_fire:
				u.cmd_attack(t)
			else:
				rest.append(u)
		if not rest.is_empty():
			command_move(rest, wp)
		return
	var cell := Vector2i(int(floor(wp.x)), int(floor(wp.y)))
	if map.has_ore(cell.x, cell.y) and is_explored(cell.x, cell.y):
		var rest: Array = []
		for u in list:
			if u.def.get("harvester", false):
				u.cmd_harvest(cell)
			else:
				rest.append(u)
		if rest.is_empty():
			markers.append({"p": wp, "t": 0.0, "c": Color(1, 0.85, 0.2)})
			return
		list = rest
	if Input.is_key_pressed(KEY_SHIFT):
		for u in list:
			u.queue_move(wp + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
		markers.append({"p": wp, "t": 0.0, "c": Color(0.3, 1, 0.8)})
		return
	command_move(list, wp)

func unit_ack(list: Array, attack: bool):
	if list.is_empty() or list[0].player != human:
		return
	var u = list[0]
	if u.type_id == "s_arty":
		Sfx.ack("ack_arty_attack" if attack else "ack_arty_move")
	elif u.ukind == "inf":
		if not attack:
			Sfx.ack("ack_inf_move")
	elif u.type_id == "s_mammoth" and attack:
		Sfx.ack("ack_heavy_attack")
	elif u.ukind == "veh" and not u.def.get("harvester", false):
		Sfx.ack("ack_veh_attack" if attack else "ack_veh_move")

func command_move(list: Array, dest: Vector2, amove := false):
	if list.is_empty():
		return
	unit_ack(list, amove)
	markers.append({"p": dest, "t": 0.0, "c": Color(1, 0.3, 0.2) if amove else Color(0.3, 1, 0.3)})
	var ground: Array = []
	for u in list:
		if u.ukind == "air":
			if amove:
				u.cmd_move(dest)
			else:
				u.cmd_move(dest + Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
		else:
			ground.append(u)
	if ground.is_empty():
		return
	var dc := Vector2i(clampi(int(floor(dest.x)), 0, W - 1), clampi(int(floor(dest.y)), 0, H - 1))
	var need := 0
	for u in ground:
		need += 1 if u.ukind != "inf" else 0
	var ninf := ground.size() - need
	need += int(ceil(ninf / 3.0))
	var cells := free_cells_near(dc, need)
	ground.sort_custom(func(a, b): return a.pos.distance_squared_to(dest) < b.pos.distance_squared_to(dest))
	var inf_slot := 0
	var inf_cell := Vector2i(-1, -1)
	var offs := [Vector2(0.3, 0.3), Vector2(0.7, 0.35), Vector2(0.5, 0.72)]
	for u in ground:
		if cells.is_empty():
			u.cmd_move(dest, amove)
			continue
		if u.ukind == "inf":
			if inf_slot == 0 or inf_cell.x < 0:
				inf_cell = pop_nearest(cells, u.pos)
			u.cmd_move(Vector2(inf_cell) + offs[inf_slot], amove)
			inf_slot = (inf_slot + 1) % 3
		else:
			var c := pop_nearest(cells, dest)
			u.cmd_move(Vector2(c) + Vector2(0.5, 0.5), amove)

func pop_nearest(cells: Array, p: Vector2) -> Vector2i:
	var bi := 0
	var bd := 1e9
	for i in cells.size():
		var d: float = (Vector2(cells[i]) + Vector2(0.5, 0.5)).distance_squared_to(p)
		if d < bd:
			bd = d
			bi = i
	var c: Vector2i = cells[bi]
	cells.remove_at(bi)
	return c

func free_cells_near(c: Vector2i, n: int) -> Array:
	var out: Array = []
	var r := 0
	while out.size() < n and r < 12:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if maxi(absi(x - c.x), absi(y - c.y)) != r:
					continue
				if map.inb(x, y) and map.passable(x, y) and bld_at(x, y) == null:
					out.append(Vector2i(x, y))
		r += 1
	return out

func key_press(k: InputEventKey):
	var code := k.keycode
	if code == KEY_ESCAPE:
		if place_id != "" or cmd_mode != "":
			place_id = ""
			cmd_mode = ""
		else:
			hud.toggle_pause_menu()
		return
	if game_over:
		return
	if code >= KEY_0 and code <= KEY_9:
		var n := code - KEY_0
		if k.ctrl_pressed:
			groups[n] = own_selected_units()
			message("編隊 %d 已設定 (%d 個單位)" % [n, groups[n].size()])
		elif groups.has(n):
			var list: Array = groups[n].filter(func(u): return is_instance_valid(u) and not u.dead)
			groups[n] = list
			if list.is_empty():
				return
			select_list(list, k.shift_pressed)
			var now := Time.get_ticks_msec() / 1000.0
			if last_group_key == n and now - last_group_time < 0.4:
				center_on(list[0].pos)
			last_group_key = n
			last_group_time = now
		return
	match code:
		KEY_A:
			if not own_selected_units().is_empty():
				cmd_mode = "amove"
		KEY_S:
			for u in own_selected_units():
				u.cmd_stop()
		KEY_D:
			for u in own_selected_units():
				if u.def.has("mcv"):
					u.cmd_deploy()
			for e in selection.duplicate():
				if is_instance_valid(e) and e.kind == "building" and e.player == human and not e.occupants.is_empty():
					garrison_exit(e)
		KEY_H, KEY_SPACE:
			var cy = null
			for b in buildings:
				if b.player == human and b.def.role == "cy":
					cy = b
			if cy != null:
				center_on(cy.pos)
			elif not own_selected_units().is_empty():
				center_on(own_selected_units()[0].pos)
			else:
				for u in units:
					if u.player == human:
						center_on(u.pos)
						break
		KEY_E:
			var list: Array = []
			for u in units:
				if u.player == human and not u.def.get("harvester", false) and not u.def.has("mcv") and not u.def.get("engineer", false):
					list.append(u)
			select_list(list)
		KEY_N:
			cycle_select(units.filter(func(u): return u.player == human and not u.dead and u.def.get("harvester", false) and u.order == "idle"), "idle_harv", "沒有閒置的採礦車")
		KEY_I:
			cycle_select(units.filter(func(u): return u.player == human and not u.dead and u.order == "idle" and not u.def.get("harvester", false) and not u.def.has("mcv") and not u.def.get("engineer", false) and not u.def.get("spy", false)), "idle_unit", "沒有閒置的戰鬥單位")
		KEY_TAB:
			cycle_select(buildings.filter(func(b): return b.player == human and not b.dead and b.built() and b.def.role in ["cy", "bar", "fac", "yard", "dronehub", "airfield"]), "fac", "還沒有生產建築")
		KEY_B:
			cycle_select(buildings.filter(func(b): return b.player == human and not b.dead and b.built()), "bld", "沒有建築")
		KEY_Q:
			if not selection.is_empty() and is_instance_valid(selection[0]):
				var tid: String = selection[0].type_id
				select_list(units.filter(func(u): return u.player == human and u.type_id == tid))
		KEY_Z:
			cmd_mode = "sell"
		KEY_X:
			cmd_mode = "repair"
		KEY_P, KEY_PAUSE:
			paused = not paused
			message("遊戲暫停" if paused else "遊戲繼續")
		KEY_EQUAL, KEY_KP_ADD:
			speed = minf(3.0, speed + 0.25)
			message("遊戲速度 x%.2f" % speed)
		KEY_MINUS, KEY_KP_SUBTRACT:
			speed = maxf(0.5, speed - 0.25)
			message("遊戲速度 x%.2f" % speed)
		KEY_F1:
			hud.toggle_help()
		KEY_F3:
			hud.show_fps = not hud.show_fps
		KEY_T:
			hud.toggle_diplomacy()
		KEY_F5:
			quick_save()
		KEY_F9:
			G.main.load_game(0)
		KEY_DELETE:
			for e in selection:
				if is_instance_valid(e) and e.kind == "building" and e.player == human:
					sell(e)

var cycle_idx := {}

# 循環選取同一類的物件並把鏡頭帶過去（閒置採礦車 / 閒置戰鬥單位 / 生產建築）
func cycle_select(list: Array, key: String, empty_msg: String):
	if list.is_empty():
		message(empty_msg)
		return
	var i: int = (int(cycle_idx.get(key, -1)) + 1) % list.size()
	cycle_idx[key] = i
	var e = list[i]
	select_list([e])
	center_on(e.pos)
	Sfx.play("select", -8.0)
	message("%s（%d / %d）" % [e.def.name, i + 1, list.size()])

func begin_place(id: String):
	place_id = id
	cmd_mode = ""

func place_tl() -> Vector2i:
	var w := mouse_world()
	var sz: Vector2i = Defs.BUILDINGS[place_id].size
	return Vector2i(int(floor(w.x - sz.x * 0.5 + 0.5)), int(floor(w.y - sz.y * 0.5 + 0.5)))

func try_place():
	var tl := place_tl()
	if can_place(place_id, tl, human):
		var def: Dictionary = Defs.BUILDINGS[place_id]
		var cat: String = def.cat
		place_building(human, place_id, tl)
		human.ready[cat] = ""
		human.stats.built += 1
		Sfx.play("place", -2.0)
		place_id = ""
	else:
		Sfx.play("click", 0.0)
		message("無法在此處放置")
