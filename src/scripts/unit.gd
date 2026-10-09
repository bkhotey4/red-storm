extends "res://scripts/entity.gd"
# 單位：步兵、載具、飛行器

var ukind := "veh"
var speed := 1.5
var radius := 0.35
var facing := 0.0
var turret := 0.0
var has_turret := false
var path: Array = []
var order := "idle"
var target = null
var home_pos := Vector2.ZERO
var amove_dest := Vector2.ZERO
var move_dest := Vector2.ZERO
var weapon: Dictionary = {}
var weapon2: Dictionary = {}
var cd := 0.0
var cd2 := 0.0
var burst := 0
var burst_t := 0.0
var scan_t := 0.0
var scan2_t := 0.0
var repath_t := 0.0
var stuck_t := 0.0
var stuck_ref := Vector2.ZERO
var repaths := 0
var moving := false
var anim_t := 0.0
var fire_t := 0.0
var turn_rate := 4.0
var sheet
var tsheet
var cargo := 0.0
const CARGO_MAX := 700.0
var ore_cell := Vector2i(-1, -1)
var mine_t := 0.0
var dock = null
var idle_t := 0.0
var alt := 0.0
var ammo := 0
var landed := false
var cell_key := -1
var jam_t := 0.0
var waypoints: Array = []

func setup(g, p, id_: String, at: Vector2):
	game = g
	player = p
	type_id = id_
	def = Defs.UNITS[id_]
	kind = "unit"
	pos = at
	ukind = def.kind
	speed = float(def.speed)
	max_hp = float(def.hp)
	hp = max_hp
	armor = def.armor
	sight = float(def.sight)
	has_turret = def.get("turret", false)
	if def.weapon != "":
		weapon = Defs.WEAPONS[def.weapon]
	if def.has("weapon2"):
		weapon2 = Defs.WEAPONS[def.weapon2]
	match ukind:
		"inf":
			radius = 0.17
			turn_rate = 10.0
		"ship":
			radius = 0.55
			turn_rate = 1.8
		"veh":
			radius = 0.36
			turn_rate = 3.6
			if id_.ends_with("mammoth") or id_.ends_with("mcv") or id_.ends_with("harv"):
				radius = 0.44
				turn_rate = 2.6
		"air":
			radius = 0.3
			turn_rate = 3.0 if def.get("jet", false) else 1.2
			alt = cruise_alt()
			ammo = int(weapon.get("ammo", 0))
	sheet = G.sheet(id_)
	if has_turret:
		tsheet = G.sheet(id_ + "_t")
	home_pos = pos
	scan_t = randf() * 0.5
	position = game.iso(pos)
	if ukind == "air":
		z_index = 30

func is_air() -> bool:
	return ukind == "air"

func weapon_range() -> float:
	return float(weapon.get("range", 0.0))

func update(dt: float):
	if dead:
		return
	if has_meta("para_t"):
		var pt: float = float(get_meta("para_t")) - dt
		if pt <= 0.0:
			remove_meta("para_t")
			game.fx.ore_dust(pos)
		else:
			set_meta("para_t", pt)
			queue_redraw()
			return
	anim_t += dt
	cd -= dt
	cd2 -= dt
	fire_t -= dt
	flash_t -= dt
	scan_t -= dt
	scan2_t -= dt
	repath_t -= dt
	if hp < max_hp:
		if def.get("heal", false):
			heal(max_hp * 0.012 * dt)
		elif rank == 2:
			heal(max_hp * 0.02 * dt)
	if burst > 0:
		burst_t -= dt
		if burst_t <= 0.0:
			burst -= 1
			burst_t = 0.2
			if target != null and is_instance_valid(target) and not target.dead:
				fire_weapon(weapon, target)
	if ukind == "air":
		update_air(dt)
	else:
		update_ground(dt)
		if not weapon2.is_empty():
			update_aa(dt)
	position = game.iso(pos)
	if ukind == "ship" and moving and randf() < dt * 8.0:
		game.fx.wake(pos - Vector2.from_angle(facing) * 0.45)
	queue_redraw()

# ───────────────────────── orders ─────────────────────────
func queue_move(dest: Vector2, attack_move := false):
	if order in ["move", "amove", "engage_am"] and ukind != "air":
		waypoints.append([dest, attack_move])
	else:
		cmd_move(dest, attack_move)

func next_waypoint() -> bool:
	if waypoints.is_empty():
		return false
	var w: Array = waypoints.pop_front()
	var wl := waypoints.duplicate()
	cmd_move(w[0], w[1])
	waypoints = wl
	return true

func cmd_move(dest: Vector2, attack_move := false):
	waypoints.clear()
	target = null
	move_dest = dest
	if ukind == "air":
		order = "move"
		landed = false
		return
	if def.get("harvester", false) and not attack_move:
		order = "move"
	order = "amove" if attack_move and not weapon.is_empty() else "move"
	amove_dest = dest
	set_path(dest)

func cmd_attack(t):
	if t == null or weapon.is_empty() and not def.get("c4", false):
		return
	target = t
	if def.get("c4", false) and (t.kind == "building" or t.ukind == "veh"):
		order = "c4"
		set_path(t.pos)
		return
	if not can_hit(weapon, t):
		return
	order = "attack"
	landed = false
	if ukind != "air":
		set_path(t.pos)

func cmd_stop():
	waypoints.clear()
	target = null
	path.clear()
	order = "idle"
	home_pos = pos
	moving = false

func cmd_capture(b):
	target = b
	order = "capture"
	set_path(b.pos)

func cmd_garrison(b):
	target = b
	order = "garrison"
	set_path(b.pos)

func cmd_harvest(cell := Vector2i(-1, -1)):
	ore_cell = cell
	order = "harvest"
	target = null
	path.clear()

func cmd_dock(ref):
	dock = ref
	order = "toref"
	path.clear()

func cmd_deploy():
	if not def.has("mcv"):
		return
	order = "deploy"
	path.clear()

func can_hit(w: Dictionary, t) -> bool:
	if w.is_empty() or t == null:
		return false
	if t.is_air():
		return w.get("air", false)
	if w.get("air_only", false):
		return false
	var wh: Dictionary = Defs.WARHEADS[w.wh]
	return float(wh.get(t.armor, 1.0)) > 0.01

# ───────────────────────── ground ─────────────────────────
func update_ground(dt: float):
	if def.get("harvester", false):
		update_harvester(dt)
		separate(dt)
		return
	match order:
		"idle":
			moving = false
			if has_turret:
				turret = G.angle_to_angle(turret, facing, 2.0 * dt)
			if not weapon.is_empty() and scan_t <= 0.0:
				scan_t = 0.35 + randf() * 0.25
				var t = game.find_target(self, weapon, weapon_range() + (1.0 if ukind == "inf" else 1.5))
				if t != null:
					target = t
					order = "engage"
					home_pos = pos
		"move":
			if follow(dt):
				if not next_waypoint():
					order = "idle"
					home_pos = pos
			elif has_turret and not weapon.is_empty():
				fire_on_move(dt)
		"amove":
			if scan_t <= 0.0:
				scan_t = 0.35 + randf() * 0.2
				var t = game.find_target(self, weapon, weapon_range() + 2.0)
				if t != null:
					target = t
					order = "engage_am"
			if order == "amove" and follow(dt):
				if not next_waypoint():
					order = "idle"
					home_pos = pos
		"attack", "engage", "engage_am":
			if target == null or not is_instance_valid(target) or target.dead or (target.player == player):
				lost_target()
			else:
				if order == "engage" and pos.distance_to(home_pos) > 7.0:
					target = null
					order = "return_home"
					set_path(home_pos)
				else:
					attack_step(dt, target)
					if order == "engage_am" and scan_t <= 0.0:
						scan_t = 0.8
						if target.kind == "building" and not target.def.has("weapon"):
							var t2 = game.find_target(self, weapon, weapon_range() + 1.0, true)
							if t2 != null and t2.kind == "unit":
								target = t2
		"return_home":
			if follow(dt):
				order = "idle"
			if scan_t <= 0.0:
				scan_t = 0.5
				var t = game.find_target(self, weapon, weapon_range() + 0.5)
				if t != null:
					target = t
					order = "engage"
		"capture":
			if target == null or not is_instance_valid(target) or target.dead:
				cmd_stop()
			elif target.dist_to(pos) < 0.55:
				game.engineer_enter(self, target)
				return
			else:
				chase(dt, target)
		"garrison":
			if target == null or not is_instance_valid(target) or target.dead:
				cmd_stop()
			elif target.dist_to(pos) < 0.6:
				game.garrison_enter(self, target)
				return
			else:
				chase(dt, target)
		"c4":
			if target == null or not is_instance_valid(target) or target.dead:
				cmd_stop()
			elif target.dist_to(pos) < 0.6:
				game.plant_c4(self, target)
				cmd_stop()
			else:
				chase(dt, target)
		"deploy":
			game.try_deploy(self)
			if not dead:
				order = "idle"
	separate(dt)

func lost_target():
	target = null
	match order:
		"engage_am":
			order = "amove"
			set_path(amove_dest)
		"engage":
			order = "return_home"
			if pos.distance_to(home_pos) > 1.0:
				set_path(home_pos)
		_:
			order = "idle"
			home_pos = pos

func chase(dt: float, t):
	if repath_t <= 0.0 or path.is_empty():
		repath_t = 0.9 + randf() * 0.4
		set_path(t.pos)
	follow(dt)

func attack_step(dt: float, t):
	var d: float = t.dist_to(pos)
	var rng := weapon_range() * (1.0 + 0.1 * rank)
	if game.high_ground(self, t):
		rng += 1.0
	var minr := float(weapon.get("min_range", 0.0))
	if d > rng:
		if ukind == "air":
			return
		chase(dt, t)
		if has_turret:
			turret = G.angle_to_angle(turret, (t.pos - pos).angle(), 5.0 * dt)
		return
	if d < minr:
		lost_target()
		return
	path.clear()
	moving = false
	aim_and_fire(dt, t, weapon)

func aim_point(t) -> Vector2:
	if t.kind == "building":
		return t.closest_point(pos)
	return t.pos

func aim_and_fire(dt: float, t, w: Dictionary) -> bool:
	var ang := (aim_point(t) - pos).angle()
	var aimed := false
	if def.has("carrier"):
		aimed = true
	elif has_turret:
		turret = G.angle_to_angle(turret, ang, 6.0 * dt)
		aimed = G.adiff(turret, ang) < 0.18
	elif ukind == "inf":
		facing = ang
		aimed = true
	else:
		facing = G.angle_to_angle(facing, ang, turn_rate * dt)
		aimed = G.adiff(facing, ang) < 0.2
	if aimed and cd <= 0.0:
		fire_weapon(w, t)
		cd = float(w.rof) * (1.0 - 0.1 * rank)
		if w.has("burst"):
			burst = int(w.burst) - 1
			burst_t = 0.2
		return true
	return false

func fire_on_move(dt: float):
	if scan_t <= 0.0:
		scan_t = 0.4
		var t = game.find_target(self, weapon, weapon_range())
		target = t
	if target != null and is_instance_valid(target) and not target.dead and target.dist_to(pos) <= weapon_range():
		var ang := (aim_point(target) - pos).angle()
		turret = G.angle_to_angle(turret, ang, 6.0 * dt)
		if G.adiff(turret, ang) < 0.18 and cd <= 0.0:
			fire_weapon(weapon, target)
			cd = float(weapon.rof)
	else:
		target = null
		turret = G.angle_to_angle(turret, facing, 3.0 * dt)

func update_aa(dt: float):
	if scan2_t <= 0.0:
		scan2_t = 0.5
		var t = game.find_target(self, weapon2, float(weapon2.range), false, true)
		if t != null and cd2 <= 0.0:
			fire_weapon(weapon2, t)
			cd2 = float(weapon2.rof)

func fire_weapon(w: Dictionary, t):
	if def.has("carrier") and w == weapon:
		launch_jet(t)
		return
	if w.get("proj", "") == "kamikaze" and ukind != "air":
		if t != null and is_instance_valid(t) and not t.dead:
			game.drone_detonate(self, t)
		return
	var ang := turret if has_turret else facing
	var z := 14.0
	match ukind:
		"inf":
			z = 13.0
		"veh":
			z = 20.0 if has_turret else 16.0
		"air":
			z = alt
	var from := pos + Vector2.from_angle(ang) * radius * 0.9
	game.fx.fire_weapon(self, w, from, z, t)
	fire_t = 0.22

func launch_jet(t):
	var n := 0
	for o in game.units:
		if not o.dead and o.has_meta("carrier") and o.get_meta("carrier") == self:
			n += 1
	if n >= int(def.get("hangar", 3)):
		return
	var j = game.spawn_unit(player, def.carrier, pos + Vector2.from_angle(facing) * 0.6)
	j.set_meta("carrier", self)
	j.facing = facing
	j.alt = 18.0
	j.landed = false
	j.target = t
	j.order = "attack"
	fire_t = 0.22
	Sfx.play("jet", -6.0)
	if OS.get_cmdline_user_args().has("--autotest"):
		print("  LAUNCH ", type_id, " -> ", t.type_id)

func on_attacked(attacker):
	if player == game.human:
		if def.get("harvester", false) and game.time - player.last_under_attack > 15.0:
			player.last_under_attack = game.time
			game.message("採礦車遭受攻擊！")
			Sfx.say("base_under_attack", 15.0)
	if ukind == "air":
		return
	if (order == "idle" or order == "return_home") and can_hit(weapon, attacker):
		if attacker.dist_to(pos) < weapon_range() + 5.0:
			target = attacker
			order = "engage"
			home_pos = pos
	game.notify_attack(self, attacker)

# ───────────────────────── movement ─────────────────────────
func set_path(to: Vector2) -> bool:
	path = game.find_path(pos, to, ukind == "ship")
	repaths = 0
	stuck_t = 0.0
	stuck_ref = pos
	return not path.is_empty()

func follow(dt: float) -> bool:
	if path.is_empty():
		moving = false
		return true
	var wp: Vector2 = path[0]
	var to := wp - pos
	var d := to.length()
	var spd := speed
	if ukind == "veh" or ukind == "ship":
		var ang := to.angle()
		if d > 0.05:
			facing = G.angle_to_angle(facing, ang, turn_rate * dt)
		var df := G.adiff(facing, ang)
		if df > 1.0 and d > 0.15:
			moving = true
			return false
		spd *= 1.0 - 0.6 * minf(1.0, df / 1.0)
	elif d > 0.01:
		facing = to.angle()
	var step := spd * dt
	moving = true
	if d <= step:
		pos = wp
		path.pop_front()
		if path.is_empty():
			moving = false
			return true
		# waypoint blocked by new building -> repath
		var nwp: Vector2 = path[0]
		if not game.passable_pos(nwp, ukind == "ship") and path.size() > 1:
			set_path(path.back())
	else:
		pos += to / d * step
	stuck_t += dt
	if stuck_t > 1.2:
		if pos.distance_to(stuck_ref) < 0.2:
			repaths += 1
			if repaths > 3 or pos.distance_to(path.back()) < 1.6:
				path.clear()
				moving = false
				return true
			var dest: Vector2 = path.back()
			path = game.find_path(pos, dest, ukind == "ship")
		stuck_ref = pos
		stuck_t = 0.0
	return false

func separate(dt: float):
	var push := Vector2.ZERO
	for o in game.neighbors(pos):
		if o == self or o.dead or o.ukind == "air":
			continue
		var dv: Vector2 = pos - o.pos
		var dd := dv.length()
		var minr: float = radius + o.radius
		if dd < minr:
			if dd < 0.0001:
				push += Vector2.from_angle(randf() * TAU) * 0.05
			else:
				var w := 1.0
				if moving and not o.moving:
					w = 0.6
				push += dv / dd * (minr - dd) * w
	if push != Vector2.ZERO:
		push = push.limit_length(2.0 * dt)
		var np := pos + push
		if game.passable_pos(np, ukind == "ship"):
			pos = np

# ───────────────────────── harvester ─────────────────────────
func update_harvester(dt: float):
	match order:
		"idle", "move":
			if order == "move":
				if follow(dt):
					order = "idle"
					idle_t = 0.0
				return
			idle_t += dt
			moving = false
			if idle_t > 3.0:
				idle_t = 0.0
				if game.map.find_ore_near(pos, 60.0).x >= 0:
					order = "harvest" if cargo < CARGO_MAX else "toref"
		"harvest":
			if cargo >= CARGO_MAX:
				order = "toref"
				dock = null
				path.clear()
				return
			if ore_cell.x < 0 or not game.map.has_ore(ore_cell.x, ore_cell.y) or game.bld_at(ore_cell.x, ore_cell.y) != null:
				ore_cell = game.map.find_ore_near(pos, 60.0)
				path.clear()
				if ore_cell.x < 0:
					order = "toref" if cargo > 0 else "idle"
					return
				set_path(Vector2(ore_cell) + Vector2(0.5, 0.5))
			var cc := Vector2(ore_cell) + Vector2(0.5, 0.5)
			var dd := pos.distance_to(cc)
			if dd < 0.4 or (path.is_empty() and dd < 1.0):
				moving = false
				path.clear()
				mine_t += dt
				facing += sin(anim_t * 2.0) * dt * 0.3
				if mine_t >= 0.45:
					mine_t = 0.0
					var got: int = game.map.take_ore(ore_cell.x, ore_cell.y, 45)
					cargo += got
					if got > 0 and randf() < 0.5:
						game.fx.ore_dust(pos)
					if got == 0:
						ore_cell = Vector2i(-1, -1)
			else:
				if path.is_empty():
					if repath_t <= 0.0:
						repath_t = 1.0
						if not set_path(cc):
							ore_cell = Vector2i(-1, -1)
				elif follow(dt) and pos.distance_to(cc) > 1.0:
					ore_cell = game.map.find_ore_near(pos + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 60.0)
		"toref":
			if dock == null or not is_instance_valid(dock) or dock.dead or dock.player != player:
				dock = game.nearest_refinery(player, pos)
				path.clear()
				if dock == null:
					order = "idle"
					return
			var dp: Vector2 = dock.closest_point(pos)
			if dock.dist_to(pos) < 0.95:
				order = "unload"
				mine_t = 0.0
				path.clear()
				moving = false
			else:
				if path.is_empty() and repath_t <= 0.0:
					repath_t = 1.2
					set_path(dp)
				follow(dt)
		"unload":
			moving = false
			if dock == null or not is_instance_valid(dock) or dock.dead:
				order = "toref"
				return
			facing = G.angle_to_angle(facing, PI * 0.5, 2.0 * dt)
			mine_t += dt
			if mine_t >= 0.15:
				mine_t = 0.0
				var amt := minf(cargo, 50.0)
				cargo -= amt
				var gain = amt * player.income_factor()
				player.money += gain
				player.stats.harvested += int(gain)
				if player == game.human and randf() < 0.3:
					Sfx.play("tick", -14.0)
				if cargo <= 0.0:
					cargo = 0.0
					order = "harvest"
					dock.unloading_t = 0.0

# ───────────────────────── air ─────────────────────────
func cruise_alt() -> float:
	if def.get("jet", false):
		return 70.0
	match type_id:
		"a_apache":
			return 48.0
		"a_tb2":
			return 85.0
		"a_fpv":
			return 30.0
		"s_lancet":
			return 42.0
		"s_shahed":
			return 55.0
	return 50.0

func drone_target():
	if def.get("prefer_bld", false):
		var best = null
		var bd := sight
		for b in game.buildings:
			if b.dead or not player.is_enemy_of(b.player) or b.def.get("wall", false):
				continue
			var d: float = b.dist_to(pos)
			if d < bd:
				bd = d
				best = b
		if best != null:
			return best
	var w := weapon
	if def.get("kamikaze", false):
		w = weapon.duplicate()
		w["range"] = sight
	return game.find_target(self, w, sight, false)

func update_air(dt: float):
	var jet: bool = def.get("jet", false)
	var kamikaze: bool = def.get("kamikaze", false)
	var loiter: bool = def.get("loiter", false)
	var tgt_alt := cruise_alt()
	if landed:
		tgt_alt = 16.0
		var af = game.nearest_airfield(player, pos) if jet else null
		if af != null and af.def.get("runway", false) and af.pos.distance_to(pos) < 3.0:
			tgt_alt = 3.0
	if kamikaze and order == "attack" and target != null and is_instance_valid(target) and not target.dead:
		var dd: float = target.dist_to(pos)
		if dd < 2.5:
			tgt_alt = lerpf(6.0, cruise_alt(), dd / 2.5)
	alt = move_toward(alt, tgt_alt, (90.0 if kamikaze else 40.0) * dt)
	jam_t -= dt
	match order:
		"idle":
			moving = false
			if jet and not landed:
				order = "return"
				if has_meta("appr"):
					remove_meta("appr")
			elif not jet and scan_t <= 0.0:
				scan_t = 0.6 if def.get("drone", false) else 1.0
				var t = drone_target() if def.get("drone", false) else game.find_target(self, weapon, sight, true)
				if t != null:
					target = t
					order = "attack"
			if jet and landed and ammo < int(weapon.get("ammo", 0)):
				idle_t += dt
				if idle_t > 2.0:
					idle_t = 0.0
					ammo += 1
			if def.get("drone", false) and not landed:
				pos += Vector2.from_angle(anim_t * 1.3 + id) * 0.35 * dt
				facing = anim_t * 1.3 + id + PI * 0.5
		"move":
			landed = false
			if def.get("drone", false) and scan_t <= 0.0 and pos.distance_to(move_dest) < 4.0:
				scan_t = 0.5
				var t = drone_target()
				if t != null and t.dist_to(pos) < 5.0:
					target = t
					order = "attack"
					return
			if fly_to(dt, move_dest, 0.3):
				order = "idle"
				if jet:
					order = "return"
					if has_meta("appr"):
						remove_meta("appr")
		"attack":
			landed = false
			if target == null or not is_instance_valid(target) or target.dead:
				target = null
				order = "return" if jet else "idle"
				if has_meta("appr"):
					remove_meta("appr")
				return
			if jet and ammo <= 0:
				order = "return"
				if has_meta("appr"):
					remove_meta("appr")
				return
			var d: float = target.dist_to(pos)
			if kamikaze:
				var tp: Vector2 = target.closest_point(pos) if target.kind == "building" else target.pos
				fly_to(dt, tp, 0.0)
				if d < 0.45:
					game.drone_detonate(self, target)
				return
			if jet:
				var ang = (target.pos - pos).angle()
				facing = G.angle_to_angle(facing, ang, turn_rate * dt)
				pos += Vector2.from_angle(facing) * speed * dt
				moving = true
				if d < weapon_range() and G.adiff(facing, ang) < 0.35 and cd <= 0.0:
					fire_weapon(weapon, target)
					cd = float(weapon.rof)
					ammo -= 1
			elif loiter:
				if d > weapon_range() * 0.8:
					fly_to(dt, target.pos, 0.2)
				else:
					moving = false
					pos += Vector2.from_angle(anim_t * 0.8 + id) * 0.4 * dt
					facing = G.angle_to_angle(facing, (target.pos - pos).angle(), 2.0 * dt)
					if cd <= 0.0 and d <= weapon_range():
						fire_weapon(weapon, target)
						cd = float(weapon.rof)
			else:
				if d > 0.4:
					fly_to(dt, target.pos, 0.2)
				if d <= weapon_range() and cd <= 0.0:
					fire_weapon(weapon, target)
					cd = float(weapon.rof)
		"return":
			if has_meta("carrier"):
				var cv = get_meta("carrier")
				if cv == null or not is_instance_valid(cv) or cv.dead:
					game.fx.explosion(pos, 0.8)
					game.remove_unit_silent(self)
					return
				if fly_to(dt, cv.pos, 0.6):
					game.remove_unit_silent(self)
				return
			var af = game.nearest_airfield(player, pos)
			if af == null:
				order = "move"
				move_dest = pos
				return
			if af.def.get("runway", false):
				# 沿跑道降落：先飛到跑道頭外的進場點，再沿跑道中心線滑行到停機位置
				var ry: float = af.pos.y + 0.5
				var slot := 0
				for o in game.units:
					if o != self and not o.dead and o.landed and o.player == player and o.pos.distance_to(af.pos) < 3.0:
						slot += 1
				var park := Vector2(af.pos.x + 1.2 - (slot % 4) * 0.75, ry)
				if not has_meta("appr"):
					if fly_to(dt, Vector2(af.pos.x - 3.5, ry), 0.6):
						set_meta("appr", true)
				elif fly_to(dt, park, 0.2):
					remove_meta("appr")
					facing = 0.0
					landed = true
					order = "idle"
					idle_t = 0.0
			elif fly_to(dt, af.pos + Vector2(0.3, 0.3), 0.25):
				landed = true
				order = "idle"
				idle_t = 0.0
	if jam_t > 0.0:
		pos += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 0.6 * dt
	pos.x = clampf(pos.x, 0.5, game.W - 0.5)
	pos.y = clampf(pos.y, 0.5, game.H - 0.5)

func fly_to(dt: float, p: Vector2, tol: float) -> bool:
	var to := p - pos
	var d := to.length()
	if d <= tol:
		moving = false
		return true
	var ang := to.angle()
	facing = G.angle_to_angle(facing, ang, turn_rate * dt)
	var spd := speed
	if G.adiff(facing, ang) > 0.8 and def.get("jet", false):
		spd *= 0.7
	if not def.get("jet", false):
		pos += to / d * minf(spd * dt, d)
	else:
		pos += Vector2.from_angle(facing) * minf(spd * dt, d + 0.1)
	moving = true
	return false

# ───────────────────────── drawing ─────────────────────────
func _draw():
	if sheet == null:
		draw_circle(Vector2(0, -8), 8, player.color)
		return
	if has_meta("para_t"):
		var pt: float = float(get_meta("para_t"))
		var hgt := minf(pt, 2.0) * 70.0
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 6.0 * (1.0 - hgt / 180.0), Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2(0, -hgt), 0.0, Vector2.ONE)
		var sw := sin(anim_t * 2.0 + id) * 2.0
		draw_line(Vector2(-9 + sw, -34), Vector2(-2, -12), Color(0.2, 0.2, 0.2), 1.0)
		draw_line(Vector2(9 + sw, -34), Vector2(2, -12), Color(0.2, 0.2, 0.2), 1.0)
		var canopy := PackedVector2Array()
		for k in 11:
			var a := PI + PI * k / 10.0
			canopy.append(Vector2(cos(a) * 12.0 + sw, -34 + sin(a) * 8.0))
		draw_colored_polygon(canopy, Color(0.9, 0.9, 0.85))
		draw_polyline(canopy, Color(0.45, 0.45, 0.4), 1.0)
		sheet.draw(self, 16, Vector2.ZERO, player.color, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var col: Color = player.color
	var mod := Color.WHITE
	if flash_t > 0.0:
		mod = Color(1.5, 1.5, 1.5)
	match ukind:
		"inf":
			var d8 := int(round(fposmod(facing, TAU) / TAU * 8.0)) % 8
			var pose := 0
			if fire_t > 0.0:
				pose = 3
			elif moving:
				pose = 1 + int(anim_t * 7.0) % 2
			sheet.draw(self, d8 * 4 + pose, Vector2.ZERO, col, mod)
		"veh", "ship":
			var bob := Vector2(0, sin(anim_t * 1.7 + id) * 1.2) if ukind == "ship" else Vector2.ZERO
			sheet.draw(self, sheet.dir_frame(facing), bob, col, mod)
			if tsheet != null:
				tsheet.draw(self, tsheet.dir_frame(turret), bob, col, mod)
		"air":
			var shadow_a := 0.35 if alt > 20.0 else 0.5
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
			var shr := 34.0
			match type_id:
				"a_jet":
					shr = 16.0
				"a_fpv":
					shr = 6.0
				"s_lancet":
					shr = 9.0
				"s_shahed":
					shr = 13.0
				"a_tb2":
					shr = 18.0
				"a_apache":
					shr = 22.0
			var sil: bool = def.get("jet", false) or type_id in ["a_hornet", "s_j15"]
			if not sil:
				draw_circle(Vector2.ZERO, shr, Color(0, 0, 0, shadow_a))
			draw_set_transform(Vector2.ZERO)
			if sil:
				# 機形陰影：同一張圖塗黑，依高度往右下偏移
				var so := Vector2(alt * 0.35, alt * 0.12)
				sheet.draw(self, sheet.dir_frame(facing), so, Color(0, 0, 0, 0), Color(0, 0, 0, 0.32 if alt > 6.0 else 0.45))
			var bob := 0.0 if landed else sin(anim_t * 2.0) * 2.0
			sheet.draw(self, sheet.dir_frame(facing), Vector2(0, -alt + bob), col, mod)
			if def.get("heli", false):
				var hub := Vector2(0, -alt + bob - 13.0)
				draw_set_transform(hub, 0.0, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, 30.0, Color(0.15, 0.15, 0.15, 0.18))
				var ra := anim_t * 38.0
				for k in 2:
					var d := Vector2.from_angle(ra + k * PI * 0.5) * 30.0
					draw_line(-d, d, Color(0.12, 0.12, 0.12, 0.55), 2.0)
				draw_set_transform(Vector2.ZERO)
	if rank > 0:
		var y := -30.0 if ukind != "inf" else -26.0
		if ukind == "air":
			y -= alt
		for k in rank:
			var cx := 12.0 + k * 6.0
			draw_polyline(PackedVector2Array([Vector2(cx - 3, y), Vector2(cx, y + 3), Vector2(cx + 3, y)]), Color(1, 0.85, 0.2), 2.0)
