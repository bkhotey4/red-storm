extends "res://scripts/entity.gd"
# 建築物

var cell := Vector2i.ZERO
var size := Vector2i(2, 2)
var build_p := 0.0
var selling := false
var sell_t := 0.0
var repairing := false
var anim_t := 0.0
var weapon: Dictionary = {}
var cd := 0.0
var turret := 0.0
var target = null
var scan_t := 0.0
var rally := Vector2(-1, -1)
var sheet
var tsheet
var fx_t := 0.0
var oil_t := 0.0
var unloading_t := 0.0
var capture_flash := 0.0
var var_frame := 0
var occupants: Array = []
var occ_cd: Array = []

func setup(g, p, id_: String, tl: Vector2i, instant := false):
	game = g
	player = p
	type_id = id_
	def = Defs.BUILDINGS[id_]
	kind = "building"
	cell = tl
	size = def.size
	pos = Vector2(tl) + Vector2(size) * 0.5
	max_hp = float(def.hp)
	hp = max_hp
	armor = "bld"
	sight = float(def.sight)
	if def.has("weapon"):
		weapon = Defs.WEAPONS[def.weapon]
	sheet = G.sheet(def.get("sprite", id_))
	tsheet = G.sheet(id_ + "_t")
	bsheet = G.sheet(id_ + "_build")
	build_p = 1.0 if instant else 0.0
	turret = PI * 0.75
	position = game.iso(pos)
	anim_t = randf() * 10.0

var bsheet = null
var dust_t := 0.0

func built() -> bool:
	return build_p >= 1.0 and not selling

func dist_to(p: Vector2) -> float:
	return p.distance_to(closest_point(p))

func closest_point(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, cell.x, cell.x + size.x), clampf(p.y, cell.y, cell.y + size.y))

func dock_pos() -> Vector2:
	return Vector2(cell.x + size.x * 0.5, cell.y + size.y + 0.55)

func exit_cell() -> Vector2i:
	return Vector2i(cell.x + size.x / 2, cell.y + size.y)

func powered() -> bool:
	return not player.low_power or not weapon.get("power", false)

func update(dt: float):
	if dead:
		return
	anim_t += dt
	flash_t -= dt
	capture_flash -= dt
	if build_p < 1.0:
		build_p = minf(1.0, build_p + dt / (2.8 if bsheet != null else 1.4))
		dust_t -= dt
		if dust_t <= 0.0 and game.fx != null:
			dust_t = 0.35
			var span := Vector2(size) * 0.45
			game.fx.ore_dust(pos + Vector2(randf_range(-span.x, span.x), randf_range(-span.y, span.y)))
		queue_redraw()
		if build_p >= 1.0:
			player.power_dirty = true
			game.on_building_complete(self)
	if selling:
		sell_t += dt
		if sell_t >= 1.0:
			game.finish_sell(self)
		queue_redraw()
		return
	if repairing:
		if hp >= max_hp:
			repairing = false
		else:
			var amt := max_hp * 0.06 * dt
			var cost := float(def.cost) * 0.5 * amt / max_hp
			if player.money >= cost:
				player.money -= cost
				heal(amt)
				if randf() < dt * 3.0:
					game.fx.spark(pos + Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)), 18.0)
	if not weapon.is_empty() and built():
		update_defense(dt)
	if not occupants.is_empty():
		update_garrison(dt)
	if def.role == "oil" and not player.neutral:
		oil_t += dt
		if oil_t >= 4.0:
			oil_t = 0.0
			player.money += 40.0 * (0.5 if player.sanctioned() else 1.0) * (game.world_ev.oil_bonus(player) if game.world_ev != null else 1.0)
	if def.has("income") and built():
		oil_t += dt
		if oil_t >= 3.0:
			oil_t = 0.0
			player.money += float(def.income) * (0.3 if player.sanctioned() else 1.0)
	# damage fx
	fx_t -= dt
	if fx_t <= 0.0 and built():
		fx_t = 0.35
		var r := hp / max_hp
		var span := Vector2(size) * 0.3
		if r < 0.5:
			game.fx.smoke(pos + Vector2(randf_range(-span.x, span.x), randf_range(-span.y, span.y)), 20.0 + size.x * 8.0, r < 0.25)
		# chimneys / power plant steam
		if def.role == "power" and not player.low_power and randf() < 0.5:
			game.fx.steam(pos + Vector2(-0.4, -0.7) if def.faction == "allies" else pos, 46.0)
		if def.role == "ref" and unloading_t < 1.0 and randf() < 0.3:
			game.fx.steam(pos + Vector2(0.1, -1.0), 55.0)
	unloading_t += dt
	queue_redraw()

func jammed() -> bool:
	return game.time < float(get_meta("jam_until", -1.0))

func update_defense(dt: float):
	if not powered() or jammed():
		return
	cd -= dt
	scan_t -= dt
	if target == null or not is_instance_valid(target) or target.dead or target.dist_to(pos) > float(weapon.range) + 0.5 or not is_enemy(target):
		target = null
		if scan_t <= 0.0:
			scan_t = 0.3
			target = game.find_target(self, weapon, float(weapon.range))
	if target != null:
		var ang = (target.pos - pos).angle()
		if tsheet != null:
			turret = G.angle_to_angle(turret, ang, 5.0 * dt)
		else:
			turret = ang
		if G.adiff(turret, ang) < 0.2 and cd <= 0.0:
			cd = float(weapon.rof)
			var z := 22.0
			match type_id:
				"s_tcoil":
					z = 62.0
				"a_prism":
					z = 60.0
				"a_aa", "s_flak":
					z = 22.0
			game.fx.fire_weapon(self, weapon, pos, z, target)

func update_garrison(dt: float):
	scan_t -= dt
	var bonus := 2.0 if type_id == "civ_office" else 1.0
	for i in occupants.size():
		occ_cd[i] -= dt
		var o: Dictionary = occupants[i]
		var w: Dictionary = o.w
		if w.is_empty() or occ_cd[i] > 0.0:
			continue
		var t = game.find_target(self, w, float(w.range) + bonus)
		if t != null:
			occ_cd[i] = float(w.rof) * randf_range(0.9, 1.2)
			var fake = self
			var from := pos + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4))
			game.fx.fire_weapon(fake, w, from, 26.0, t)

func can_hit(w: Dictionary, t) -> bool:
	if t.is_air():
		return w.get("air", false)
	if w.get("air_only", false):
		return false
	return float(Defs.WARHEADS[w.wh].get(t.armor, 1.0)) > 0.01

func on_attacked(attacker):
	game.notify_attack(self, attacker)
	if player == game.human and game.time - player.last_under_attack > 18.0:
		player.last_under_attack = game.time
		Sfx.say("base_under_attack", 18.0)
		game.message("警告：基地遭受攻擊！")
		game.ping(pos)

# 科技建築上方的圖示徽章（顏色＝擁有者，中立為白色）
func draw_tech_badge():
	var o := Vector2(0, -sheet.ay / sheet.res - 6.0 + sin(anim_t * 2.0) * 2.0)
	var c: Color = Color(0.92, 0.92, 0.92) if player.neutral else player.color
	draw_circle(o, 13.0, Color(0, 0, 0, 0.6))
	draw_circle(o, 11.0, c.darkened(0.35))
	draw_arc(o, 11.0, 0, TAU, 24, c.lightened(0.4), 2.0)
	match def.tech:
		"hosp":
			draw_rect(Rect2(o - Vector2(6, 2), Vector2(12, 4)), Color(1, 0.25, 0.2))
			draw_rect(Rect2(o - Vector2(2, 6), Vector2(4, 12)), Color(1, 0.25, 0.2))
		"shop":
			draw_arc(o, 5.0, 0, TAU, 16, Color(1, 0.85, 0.3), 3.0)
			for k in 6:
				var a := TAU * k / 6.0 + anim_t
				draw_line(o + Vector2.from_angle(a) * 5.0, o + Vector2.from_angle(a) * 8.0, Color(1, 0.85, 0.3), 2.5)
		"air":
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -8), o + Vector2(2, -2), o + Vector2(8, 1), o + Vector2(2, 1),
				o + Vector2(1, 6), o + Vector2(3, 8), o + Vector2(-3, 8), o + Vector2(-1, 6), o + Vector2(-2, 1), o + Vector2(-8, 1), o + Vector2(-2, -2)]), Color(0.6, 0.9, 1.0))

func frame_index() -> int:
	if sheet == null:
		return 0
	match def.role:
		"cy":
			return int(anim_t * 1.2) % sheet.n
		"radar":
			if player.low_power:
				return 0
			return int(anim_t * 5.0) % sheet.n
		"oil":
			return int(anim_t * 6.0) % sheet.n
		"sw":
			return 1 if float(player.powers.get(def.get("super", ""), 0.0)) >= 1.0 else 0
		"wall":
			if sheet.n >= 16:
				var m := 0
				var ofs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
				for k in 4:
					var o = game.bld_at(cell.x + ofs[k].x, cell.y + ofs[k].y)
					if o != null and not o.dead and o.def.get("role", "") == "wall":
						m |= 1 << k
				return m
	if def.get("role", "") == "techb" and def.get("tech", "") == "air":
		return 2 % sheet.n
	return mini(var_frame, sheet.n - 1)

func _draw():
	var col: Color = player.color
	var mod := Color.WHITE
	var r := hp / max_hp
	if r < 0.5:
		mod = Color(0.82, 0.78, 0.74)
	if r < 0.25:
		mod = Color(0.65, 0.58, 0.54)
	if flash_t > 0.0:
		mod = Color(1.4, 1.4, 1.4)
	if capture_flash > 0.0 and int(capture_flash * 8) % 2 == 0:
		mod = Color(1.6, 1.6, 1.6)
	var clip := build_p
	if selling:
		clip = 1.0 - sell_t
	if sheet == null:
		var pts := PackedVector2Array()
		for c in [Vector2(cell), Vector2(cell.x + size.x, cell.y), Vector2(cell + size), Vector2(cell.x, cell.y + size.y)]:
			pts.append(game.iso(c) - position)
		draw_colored_polygon(pts, col)
		return
	if clip < 1.0:
		# construction scaffold glow
		var pts := PackedVector2Array()
		for c in [Vector2(cell), Vector2(cell.x + size.x, cell.y), Vector2(cell + size), Vector2(cell.x, cell.y + size.y)]:
			pts.append(game.iso(c) - position)
		draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.25))
		pts.append(pts[0])
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.8), 1.5)
	if clip < 1.0 and bsheet != null:
		var bf := clampi(int(clip * bsheet.n), 0, bsheet.n - 1)
		bsheet.draw(self, bf, Vector2.ZERO, col, mod)
	else:
		sheet.draw(self, frame_index(), Vector2.ZERO, col, mod, 1.0, clampf(clip, 0.02, 1.0))
	if def.has("tech"):
		draw_tech_badge()
	if def.has("garrison") and (not occupants.is_empty() or selected):
		var n: int = def.garrison
		var y: float = -sheet.ay / sheet.res + 4.0
		for k in n:
			var x := (k - (n - 1) * 0.5) * 9.0
			var filled := k < occupants.size()
			draw_rect(Rect2(x - 3, y - 3, 7, 7), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(x - 2, y - 2, 5, 5), player.color.lightened(0.3) if filled else Color(0.3, 0.3, 0.3))
	if tsheet != null and clip >= 1.0:
		tsheet.draw(self, tsheet.dir_frame(turret), Vector2.ZERO, col, mod)
	if not weapon.is_empty() and weapon.get("power", false) and player.low_power and built():
		var a := 0.5 + 0.5 * sin(anim_t * 6.0)
		var o := Vector2(0, -sheet.ay / sheet.res + 10)
		draw_polyline(PackedVector2Array([o + Vector2(3, -10), o + Vector2(-3, 0), o + Vector2(2, 0), o + Vector2(-2, 10)]), Color(1, 0.9, 0.2, a), 3.0)
	if repairing:
		var a := 0.6 + 0.4 * sin(anim_t * 5.0)
		var o := Vector2(0, -sheet.ay / sheet.res + 8)
		draw_circle(o, 9.0, Color(0.1, 0.4, 0.1, 0.7 * a))
		draw_rect(Rect2(o - Vector2(6, 2), Vector2(12, 4)), Color(0.5, 1, 0.5, a))
		draw_rect(Rect2(o - Vector2(2, 6), Vector2(4, 12)), Color(0.5, 1, 0.5, a))
