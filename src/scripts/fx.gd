extends Node2D
# 特效：彈道、爆炸、煙霧、光束、閃電

var game
var parts: Array = []
var glows: Array = []
var projs: Array = []
var beams: Array = []
var decals: Array = []
var anims: Array = []
var add_node: Node2D
var decal_node: Node2D
var shake := 0.0
var t_soft: Texture2D
var t_glow: Texture2D
var t_smoke: Texture2D
var t_scorch: Texture2D
var t_ring: Texture2D
var t_streak: Texture2D

func setup(g):
	game = g
	z_index = 40
	add_node = Node2D.new()
	add_node.z_index = 41
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_node.material = m
	add_node.draw.connect(_draw_add)
	game.world.add_child(add_node)
	decal_node = Node2D.new()
	decal_node.z_index = -15
	decal_node.draw.connect(_draw_decals)
	game.world.add_child(decal_node)
	t_soft = G.tex("fx_soft")
	t_glow = G.tex("fx_glow")
	t_smoke = G.tex("fx_smoke")
	t_scorch = G.tex("fx_scorch")
	t_ring = G.tex("fx_ring")
	t_streak = G.tex("fx_streak")

func S(world: Vector2, z := 0.0) -> Vector2:
	return game.iso(world) - Vector2(0, z)

func target_z(t) -> float:
	if t.kind == "building":
		return 18.0
	if t.is_air():
		return t.alt
	return 8.0 if t.ukind == "inf" else 10.0

# ───────────────────────── weapons ─────────────────────────
func fire_weapon(att, w: Dictionary, from: Vector2, z: float, t):
	var dmg: float = float(w.dmg) * att.dmg_mult()
	var tp: Vector2 = t.closest_point(from) if t.kind == "building" else t.pos
	var tz := target_z(t)
	var snd: String = w.get("snd", "")
	if snd != "":
		Sfx.play(snd, -6.0 if snd == "mg" else -3.0, from)
	var ms := S(from, z)
	match w.proj:
		"bullet":
			muzzle(ms, 0.5)
			beams.append({"a": ms, "b": S(tp, tz) + Vector2(randf_range(-3, 3), randf_range(-3, 3)), "t": 0.0, "d": 0.07, "kind": "tracer", "w": 1.5})
			hit_spark(S(tp, tz), t.kind == "building" or t.armor != "inf")
			t.take_damage(dmg, att, w.wh)
		"shell":
			muzzle(ms, 1.0)
			puff(ms, 0.6)
			var dist := from.distance_to(tp)
			projs.append({"kind": "shell", "from": from, "to": tp, "z0": z, "z1": tz, "t": 0.0, "dur": maxf(0.08, dist / 16.0),
				"target": t, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 0.0)), "arc": 4.0, "owner": att.player})
		"rocket":
			muzzle(ms, 0.7)
			var dist := from.distance_to(tp)
			projs.append({"kind": "rocket", "from": from, "to": tp, "z0": z, "z1": tz, "t": 0.0, "dur": maxf(0.15, dist / 9.0),
				"target": t, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 0.0)), "arc": 10.0, "trail": 0.0, "owner": att.player})
		"arty":
			var dist := from.distance_to(tp)
			var tp2 := tp + Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
			muzzle(ms, 1.2)
			puff(ms, 1.2)
			projs.append({"kind": "arty", "from": from, "to": tp2, "z0": z, "z1": 0.0, "t": 0.0, "dur": 1.1 + dist * 0.09,
				"target": null, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 1.2)), "arc": 70.0 + dist * 9.0, "trail": 0.0, "owner": att.player})
		"topattack":
			muzzle(ms, 0.8)
			puff(ms, 0.8)
			var dist := from.distance_to(tp)
			projs.append({"kind": "topattack", "from": from, "to": tp, "z0": z, "z1": tz, "t": 0.0, "dur": maxf(0.5, dist / 6.5),
				"target": t, "dmg": dmg, "wh": w.wh, "att": att, "splash": 0.0, "arc": 45.0 + dist * 6.0, "trail": 0.0, "owner": att.player})
		"mlrs":
			var dist := from.distance_to(tp)
			var tp2 := tp + Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7))
			muzzle(ms, 1.0)
			puff(ms, 1.0)
			projs.append({"kind": "mlrs", "from": from, "to": tp2, "z0": z, "z1": 0.0, "t": 0.0, "dur": 0.7 + dist * 0.07,
				"target": null, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 1.0)), "arc": 30.0 + dist * 5.0, "trail": 0.0, "owner": att.player})
		"ballistic":
			var dist := from.distance_to(tp)
			puff(ms, 2.0)
			glow(ms, 60.0, Color(1, 0.7, 0.3), 0.4)
			projs.append({"kind": "ballistic", "from": from, "to": tp, "z0": z, "z1": 0.0, "t": 0.0, "dur": 2.2 + dist * 0.05,
				"target": null, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 1.8)), "arc": 260.0 + dist * 8.0, "trail": 0.0, "owner": att.player})
		"torpedo":
			var dist := from.distance_to(tp)
			projs.append({"kind": "torpedo", "from": from, "to": tp, "z0": 0.0, "z1": 0.0, "t": 0.0, "dur": maxf(0.3, dist / 6.0),
				"target": t, "dmg": dmg, "wh": w.wh, "att": att, "splash": 0.0, "arc": 0.0, "trail": 0.0, "owner": att.player})
		"flak":
			var dist := from.distance_to(tp)
			muzzle(ms, 0.6)
			projs.append({"kind": "flak", "from": from, "to": tp, "z0": z, "z1": tz, "t": 0.0, "dur": maxf(0.08, dist / 20.0),
				"target": t, "dmg": dmg, "wh": w.wh, "att": att, "splash": 0.0, "arc": 0.0, "owner": att.player})
		"tesla":
			var b := S(tp, tz)
			beams.append({"a": ms, "b": b, "t": 0.0, "d": 0.28, "kind": "tesla", "w": 2.5, "seed": randi()})
			glow(ms, 34.0, Color(0.4, 0.6, 1.0), 0.25)
			glow(b, 40.0, Color(0.5, 0.7, 1.0), 0.3)
			t.take_damage(dmg, att, w.wh)
			if t.kind == "unit" and t.ukind == "inf":
				spark(tp, tz, Color(0.6, 0.8, 1.0))
		"beam":
			var b := S(tp, tz)
			beams.append({"a": ms, "b": b, "t": 0.0, "d": 0.32, "kind": "beam", "w": 5.0})
			glow(ms, 30.0, Color(0.5, 0.9, 1.0), 0.3)
			glow(b, 50.0, Color(0.5, 0.9, 1.0), 0.35)
			var sp := float(w.get("splash", 0.0))
			if sp > 0.0:
				game.damage_area(tp, sp, dmg, w.wh, att, t)
			else:
				t.take_damage(dmg, att, w.wh)
			scorch(tp, 0.5)
		"bomb":
			projs.append({"kind": "bomb", "from": from, "to": from + Vector2(0.1, 0.1), "z0": z - 8.0, "z1": 0.0, "t": 0.0, "dur": 0.7,
				"target": null, "dmg": dmg, "wh": w.wh, "att": att, "splash": float(w.get("splash", 1.5)), "arc": 0.0, "owner": att.player})

func impact(pr: Dictionary):
	var to: Vector2 = pr.to
	var t = pr.target
	var att = pr.att if is_instance_valid(pr.att) else null
	match pr.kind:
		"shell":
			explosion(to, 0.7, pr.z1)
		"rocket":
			explosion(to, 0.8, pr.z1)
		"arty":
			explosion(to, 1.6)
		"flak":
			for k in 3:
				puff(S(to, pr.z1) + Vector2(randf_range(-10, 10), randf_range(-8, 8)), 0.5, Color(0.15, 0.15, 0.15))
			glow(S(to, pr.z1), 24.0, Color(1, 0.7, 0.3), 0.15)
		"bomb":
			explosion(to, 2.2)
		"topattack":
			explosion(to, 0.9, pr.z1)
		"torpedo":
			explosion(to, 1.2)
			for k in 4:
				parts.append({"p": S(to, 0.0), "v": Vector2(randf_range(-20, 20), randf_range(-80, -40)), "s0": 10.0, "s1": 30.0,
					"c0": Color(0.9, 0.95, 1.0, 0.8), "c1": Color(0.9, 0.95, 1.0, 0.0), "t": 0.0, "d": 1.0, "tex": t_soft, "g": 120.0})
		"mlrs":
			if pr.wh == "fire":
				fire_blast(to, 1.3)
			else:
				explosion(to, 1.2)
		"ballistic":
			explosion(to, 2.8)
			fire_blast(to, 1.6)
	if pr.splash > 0.0:
		game.damage_area(to, pr.splash, pr.dmg, pr.wh, att, null, pr.owner)
	elif t != null and is_instance_valid(t) and not t.dead:
		t.take_damage(pr.dmg, att, pr.wh)

# ───────────────────────── particles ─────────────────────────
func glow(sp: Vector2, size: float, col: Color, life: float, grow := 1.0, v := Vector2.ZERO):
	glows.append({"p": sp, "v": v, "s0": size, "s1": size * grow, "c0": col, "c1": Color(col.r, col.g, col.b, 0.0), "t": 0.0, "d": life, "tex": t_glow})

func muzzle(sp: Vector2, s: float):
	glow(sp, 26.0 * s, Color(1.0, 0.8, 0.4), 0.08)

func puff(sp: Vector2, s: float, col := Color(0.7, 0.68, 0.64)):
	parts.append({"p": sp, "v": Vector2(randf_range(-6, 6), -12.0), "s0": 10.0 * s, "s1": 28.0 * s, "c0": Color(col.r, col.g, col.b, 0.55),
		"c1": Color(col.r, col.g, col.b, 0.0), "t": 0.0, "d": 0.8, "tex": t_smoke, "g": 0.0})

func hit_spark(sp: Vector2, metal: bool):
	if metal:
		for k in 2:
			parts.append({"p": sp, "v": Vector2(randf_range(-60, 60), randf_range(-70, -10)), "s0": 3.0, "s1": 1.0, "c0": Color(1, 0.85, 0.4, 1),
				"c1": Color(1, 0.5, 0.1, 0), "t": 0.0, "d": 0.25, "tex": null, "g": 200.0})
	else:
		parts.append({"p": sp, "v": Vector2(0, -10), "s0": 5.0, "s1": 10.0, "c0": Color(0.6, 0.55, 0.45, 0.6), "c1": Color(0.6, 0.55, 0.45, 0),
			"t": 0.0, "d": 0.35, "tex": t_smoke, "g": 0.0})

func spark(world: Vector2, z := 10.0, col := Color(1, 0.85, 0.4)):
	var sp := S(world, z)
	for k in 5:
		parts.append({"p": sp, "v": Vector2(randf_range(-80, 80), randf_range(-90, -10)), "s0": 3.0, "s1": 1.0, "c0": col,
			"c1": Color(col.r, col.g, col.b, 0), "t": 0.0, "d": 0.35, "tex": null, "g": 220.0})
	glow(sp, 18.0, col, 0.12)

func smoke(world: Vector2, z: float, fire := false):
	var sp := S(world, z)
	var dark := 0.18 if fire else 0.35
	parts.append({"p": sp, "v": Vector2(randf_range(6, 14), randf_range(-28, -18)), "s0": 10.0, "s1": 42.0,
		"c0": Color(dark, dark, dark, 0.6), "c1": Color(dark, dark, dark, 0.0), "t": 0.0, "d": 2.4, "tex": t_smoke, "g": 0.0})
	if fire:
		glows.append({"p": sp + Vector2(0, 6), "v": Vector2(0, -20), "s0": 18.0, "s1": 6.0, "c0": Color(1.0, 0.5, 0.1, 0.9),
			"c1": Color(0.8, 0.2, 0.0, 0.0), "t": 0.0, "d": 0.6, "tex": t_glow})

# 載具煙霧彈：大片白色煙幕
func smoke_screen(world: Vector2):
	var sp := S(world, 4.0) + Vector2(randf_range(-26, 26), randf_range(-12, 12))
	var v := randf_range(0.82, 0.95)
	parts.append({"p": sp, "v": Vector2(randf_range(-8, 8), randf_range(-14, -6)), "s0": 22.0, "s1": 70.0,
		"c0": Color(v, v, v, 0.8), "c1": Color(v, v, v, 0.0), "t": 0.0, "d": 2.2, "tex": t_smoke, "g": 0.0})

func steam(world: Vector2, z: float):
	var sp := S(world, z)
	parts.append({"p": sp, "v": Vector2(randf_range(4, 10), randf_range(-26, -16)), "s0": 8.0, "s1": 34.0,
		"c0": Color(0.92, 0.94, 0.96, 0.45), "c1": Color(0.92, 0.94, 0.96, 0.0), "t": 0.0, "d": 2.0, "tex": t_smoke, "g": 0.0})

func ore_dust(world: Vector2):
	var sp := S(world, 4.0)
	parts.append({"p": sp + Vector2(randf_range(-8, 8), 0), "v": Vector2(randf_range(-6, 6), -14), "s0": 6.0, "s1": 20.0,
		"c0": Color(0.8, 0.65, 0.3, 0.5), "c1": Color(0.8, 0.65, 0.3, 0.0), "t": 0.0, "d": 1.0, "tex": t_smoke, "g": 0.0})

func scorch(world: Vector2, s: float):
	var cx := int(world.x)
	var cy := int(world.y)
	if game.map.inb(cx, cy) and game.map.terrain[game.map.idx(cx, cy)] == game.map.T_WATER and game.map.bridge[game.map.idx(cx, cy)] == 0:
		return
	decals.append({"p": game.iso(world), "s": 40.0 * s, "t": 0.0, "d": 25.0, "r": randf() * TAU})
	if decals.size() > 120:
		decals.pop_front()
	decal_node.queue_redraw()

func anim(key: String, sp: Vector2, scale: float, dur: float):
	var sh = G.sheet(key)
	if sh == null:
		return
	anims.append({"sh": sh, "p": sp, "sc": scale, "t": 0.0, "d": dur})

func explosion(world: Vector2, size: float, z := 0.0):
	var sp := S(world, z)
	glow(sp, 50.0 * size, Color(1.0, 0.95, 0.75), 0.12, 1.3)
	if size < 0.9:
		anim("exp_small", sp, 0.5 + size * 0.6, 0.55)
	elif size < 1.7:
		anim("exp_med", sp + Vector2(0, 6), 0.55 + size * 0.35, 0.9)
	else:
		anim("exp_big", sp + Vector2(0, 10), 0.45 + size * 0.3, 1.3)
		if size >= 2.4:
			for k in 3:
				var off := Vector2(randf_range(-30, 30), randf_range(-14, 14)) * size * 0.4
				anims.append({"sh": G.sheet("exp_med"), "p": sp + off, "sc": 0.6 + size * 0.2, "t": -randf_range(0.05, 0.35), "d": 0.9})
	var n := int(1 + size * 2)
	for k in n:
		var off := Vector2(randf_range(-14, 14), randf_range(-8, 8)) * size
		var life := randf_range(0.35, 0.7) * (0.8 + size * 0.2)
		glows.append({"p": sp + off, "v": Vector2(randf_range(-15, 15), randf_range(-45, -15)) * size * 0.6, "s0": 14.0 * size, "s1": 36.0 * size,
			"c0": Color(1.0, randf_range(0.55, 0.75), 0.2, 1.0), "c1": Color(0.6, 0.12, 0.0, 0.0), "t": 0.0, "d": life, "tex": t_glow})
	for k in int(1 + size * 1.5):
		var off := Vector2(randf_range(-12, 12), randf_range(-8, 6)) * size
		var d := randf_range(0.2, 0.3)
		parts.append({"p": sp + off, "v": Vector2(randf_range(-10, 10), randf_range(-30, -12)) * (0.6 + size * 0.3), "s0": 14.0 * size, "s1": 50.0 * size,
			"c0": Color(d, d * 0.95, d * 0.9, 0.7), "c1": Color(d, d, d, 0.0), "t": 0.0, "d": randf_range(1.2, 2.4) * (0.7 + size * 0.2), "tex": t_smoke, "g": 0.0})
	for k in int(size * 6):
		parts.append({"p": sp, "v": Vector2(randf_range(-110, 110), randf_range(-160, -40)) * (0.5 + size * 0.25), "s0": 2.5, "s1": 1.5,
			"c0": Color(1.0, 0.8, 0.4, 1.0), "c1": Color(0.3, 0.2, 0.1, 0.0), "t": 0.0, "d": randf_range(0.4, 0.9), "tex": null, "g": 300.0})
	if size >= 1.5:
		glows.append({"p": sp, "v": Vector2.ZERO, "s0": 20.0 * size, "s1": 90.0 * size, "c0": Color(1, 0.8, 0.5, 0.6),
			"c1": Color(1, 0.6, 0.3, 0.0), "t": 0.0, "d": 0.4, "tex": t_ring, "flat": true})
	if z < 4.0:
		scorch(world, 0.35 + size * 0.35)
	if size >= 1.5:
		shake = maxf(shake, size * 2.5)
	if size >= 2.0:
		Sfx.play("big_explode", -2.0, world)
	elif size >= 0.9:
		Sfx.play("explode", -6.0, world)

func fire_blast(world: Vector2, size: float):
	var sp := S(world, 0.0)
	anim("exp_fire", sp + Vector2(0, 8), 0.5 + size * 0.35, 1.4)
	for k in int(6 + size * 6):
		var off := Vector2(randf_range(-22, 22), randf_range(-11, 11)) * size
		glows.append({"p": sp + off, "v": Vector2(randf_range(-8, 8), randf_range(-40, -15)), "s0": 18.0 * size, "s1": 44.0 * size,
			"c0": Color(1.0, randf_range(0.45, 0.65), 0.15, 1.0), "c1": Color(0.5, 0.08, 0.0, 0.0), "t": -randf() * 0.25, "d": randf_range(0.6, 1.1), "tex": t_glow})
	for k in int(3 + size * 3):
		var off := Vector2(randf_range(-20, 20), randf_range(-10, 10)) * size
		parts.append({"p": sp + off, "v": Vector2(randf_range(-6, 6), randf_range(-26, -12)), "s0": 20.0 * size, "s1": 60.0 * size,
			"c0": Color(0.15, 0.13, 0.12, 0.7), "c1": Color(0.2, 0.2, 0.2, 0.0), "t": 0.0, "d": randf_range(1.8, 3.0), "tex": t_smoke, "g": 0.0})
	scorch(world, size)

func wake(world: Vector2):
	var sp := S(world, 0.0)
	parts.append({"p": sp + Vector2(randf_range(-4, 4), randf_range(-2, 2)), "v": Vector2(randf_range(-4, 4), 0), "s0": 6.0, "s1": 22.0,
		"c0": Color(0.9, 0.95, 1.0, 0.5), "c1": Color(0.9, 0.95, 1.0, 0.0), "t": 0.0, "d": 1.4, "tex": t_soft, "g": 0.0})

func coins(world: Vector2):
	var sp := S(world, 40.0)
	for k in 6:
		glows.append({"p": sp + Vector2(randf_range(-20, 20), randf_range(-10, 10)), "v": Vector2(randf_range(-10, 10), randf_range(20, 45)),
			"s0": 16.0, "s1": 6.0, "c0": Color(1.0, 0.85, 0.2, 1.0), "c1": Color(1.0, 0.6, 0.1, 0.0), "t": -randf() * 0.6, "d": 1.2, "tex": t_glow})

func scan_ring(world: Vector2, col := Color(0.4, 0.8, 1.0)):
	var sp := S(world, 0.0)
	for k in 3:
		glows.append({"p": sp, "v": Vector2.ZERO, "s0": 40.0, "s1": 1000.0, "c0": Color(col.r, col.g, col.b, 0.7), "c1": Color(col.r, col.g, col.b, 0.0),
			"t": -k * 0.3, "d": 1.4, "tex": t_ring, "flat": true})

func inf_death(world: Vector2, fried := false):
	var sp := S(world, 6.0)
	if fried:
		glow(sp, 30.0, Color(0.5, 0.7, 1.0), 0.3)
		parts.append({"p": sp, "v": Vector2(0, -20), "s0": 6.0, "s1": 18.0, "c0": Color(0.1, 0.1, 0.1, 0.7), "c1": Color(0, 0, 0, 0), "t": 0.0, "d": 1.0, "tex": t_smoke, "g": 0.0})
	else:
		parts.append({"p": sp, "v": Vector2(0, -6), "s0": 6.0, "s1": 12.0, "c0": Color(0.55, 0.5, 0.42, 0.6), "c1": Color(0.5, 0.45, 0.4, 0), "t": 0.0, "d": 0.6, "tex": t_smoke, "g": 0.0})
	Sfx.play("inf_die", -10.0, world, 0.15)

func lightning(world: Vector2):
	var b := S(world, 0.0)
	var a := b + Vector2(randf_range(-80, 80), -520)
	beams.append({"a": a, "b": b, "t": 0.0, "d": 0.35, "kind": "tesla", "w": 5.0, "seed": randi()})
	glow(b, 120.0, Color(0.7, 0.8, 1.0), 0.35)

func nuke_blast(world: Vector2):
	var sp := S(world, 0.0)
	glow(sp, 700.0, Color(1, 1, 0.9), 0.5, 1.2)
	for k in 40:
		var a := randf() * TAU
		var r := randf_range(0.0, 1.0)
		var off := Vector2(cos(a), sin(a) * 0.5) * r * 140.0
		glows.append({"p": sp + off, "v": Vector2(0, -randf_range(40, 160)), "s0": 60.0, "s1": 160.0,
			"c0": Color(1.0, randf_range(0.5, 0.8), 0.2, 1.0), "c1": Color(0.5, 0.1, 0.0, 0.0), "t": 0.0, "d": randf_range(1.0, 2.5), "tex": t_glow})
	for k in 40:
		var off := Vector2(randf_range(-160, 160), randf_range(-60, 40))
		parts.append({"p": sp + off, "v": Vector2(randf_range(-20, 20), randf_range(-90, -30)), "s0": 60.0, "s1": 200.0,
			"c0": Color(0.28, 0.24, 0.2, 0.8), "c1": Color(0.2, 0.2, 0.2, 0.0), "t": 0.0, "d": randf_range(3.0, 6.0), "tex": t_smoke, "g": 0.0})
	for k in 3:
		glows.append({"p": sp, "v": Vector2.ZERO, "s0": 50.0, "s1": 900.0 + k * 200.0, "c0": Color(1, 0.8, 0.5, 0.8), "c1": Color(1, 0.6, 0.3, 0.0),
			"t": -k * 0.15, "d": 1.2, "tex": t_ring, "flat": true})
	scorch(world, 6.0)
	shake = 22.0
	Sfx.play("big_explode", 4.0)

# ───────────────────────── update/draw ─────────────────────────
func update(dt: float):
	for i in range(projs.size() - 1, -1, -1):
		var pr: Dictionary = projs[i]
		pr.t += dt
		if pr.target != null and is_instance_valid(pr.target) and not pr.target.dead and pr.kind != "arty":
			var t = pr.target
			pr.to = t.closest_point(pr.from) if t.kind == "building" else t.pos
		if pr.kind == "torpedo":
			pr.trail -= dt
			if pr.trail <= 0.0:
				pr.trail = 0.05
				wake(pr.from.lerp(pr.to, clampf(pr.t / pr.dur, 0.0, 1.0)))
		if pr.kind in ["rocket", "arty", "topattack", "mlrs", "ballistic"]:
			pr.trail -= dt
			if pr.trail <= 0.0:
				pr.trail = 0.03
				var p := proj_screen(pr)
				parts.append({"p": p, "v": Vector2(randf_range(-4, 4), -6), "s0": 4.0, "s1": 14.0, "c0": Color(0.75, 0.72, 0.68, 0.55),
					"c1": Color(0.7, 0.7, 0.7, 0.0), "t": 0.0, "d": 0.7, "tex": t_smoke, "g": 0.0})
		if pr.t >= pr.dur:
			projs.remove_at(i)
			impact(pr)
	_upd_list(parts, dt)
	_upd_list(glows, dt)
	for i in range(anims.size() - 1, -1, -1):
		anims[i].t += dt
		if anims[i].t >= anims[i].d:
			anims.remove_at(i)
	for i in range(beams.size() - 1, -1, -1):
		beams[i].t += dt
		if beams[i].t >= beams[i].d:
			beams.remove_at(i)
	var dchg := false
	for i in range(decals.size() - 1, -1, -1):
		decals[i].t += dt
		if decals[i].t >= decals[i].d:
			decals.remove_at(i)
			dchg = true
	if dchg or int(game.time * 2.0) != int((game.time - dt) * 2.0):
		decal_node.queue_redraw()
	shake = maxf(0.0, shake - dt * 18.0)
	queue_redraw()
	add_node.queue_redraw()

func _upd_list(arr: Array, dt: float):
	for i in range(arr.size() - 1, -1, -1):
		var p: Dictionary = arr[i]
		p.t += dt
		if p.t >= p.d:
			arr.remove_at(i)
			continue
		if p.t < 0.0:
			continue
		p.p += p.v * dt
		var g: float = p.get("g", 0.0)
		if g != 0.0:
			p.v.y += g * dt

func proj_screen(pr: Dictionary) -> Vector2:
	var f: float = clampf(pr.t / pr.dur, 0.0, 1.0)
	var w: Vector2 = pr.from.lerp(pr.to, f)
	var z: float = lerpf(pr.z0, pr.z1, f) + pr.arc * 4.0 * f * (1.0 - f)
	if pr.kind == "bomb":
		z = lerpf(pr.z0, 0.0, f * f)
	return S(w, z)

func _draw():
	var _t := Time.get_ticks_usec()
	_draw_impl()
	G.game._pf("fx_draw", _t)

func _draw_impl():
	for a in anims:
		if a.t < 0.0:
			continue
		var sh = a.sh
		var f := int(a.t / a.d * sh.n)
		sh.draw(self, f, a.p, Color.WHITE, Color.WHITE, a.sc)
	for p in parts:
		if p.t < 0.0:
			continue
		var f: float = p.t / p.d
		var s: float = lerpf(p.s0, p.s1, f)
		var c: Color = p.c0.lerp(p.c1, f)
		if p.tex == null:
			draw_line(p.p, p.p - p.v * 0.03, c, s)
		else:
			draw_texture_rect(p.tex, Rect2(p.p - Vector2(s, s) * 0.5, Vector2(s, s)), false, c)
	for pr in projs:
		var sp := proj_screen(pr)
		match pr.kind:
			"shell":
				draw_circle(sp, 2.0, Color(1, 0.9, 0.6))
			"rocket", "topattack", "mlrs", "ballistic":
				var f: float = clampf(pr.t / pr.dur, 0.0, 1.0)
				var f2 := minf(1.0, f + 0.03)
				var nxt: Vector2 = S(pr.from.lerp(pr.to, f2), lerpf(pr.z0, pr.z1, f2) + pr.arc * 4.0 * f2 * (1.0 - f2))
				var dir := (nxt - sp).normalized()
				draw_line(sp - dir * 5.0, sp + dir * 3.0, Color(0.85, 0.85, 0.8), 2.5)
			"arty":
				draw_circle(sp, 3.5, Color(0.9, 0.9, 0.85))
				var ground := S(pr.from.lerp(pr.to, clampf(pr.t / pr.dur, 0.0, 1.0)), 0.0)
				draw_set_transform(ground, 0.0, Vector2(1, 0.5))
				draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.3))
				draw_set_transform(Vector2.ZERO)
			"flak":
				draw_circle(sp, 1.5, Color(1, 0.8, 0.5))
			"bomb":
				draw_circle(sp, 4.0, Color(0.15, 0.15, 0.15))
	var sh := shake_off()
	if sh != Vector2.ZERO:
		pass

func shake_off() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-shake, shake), randf_range(-shake, shake) * 0.6)

func _draw_add():
	for p in glows:
		if p.t < 0.0:
			continue
		var f: float = p.t / p.d
		var s: float = lerpf(p.s0, p.s1, f)
		var c: Color = p.c0.lerp(p.c1, f)
		if p.get("flat", false):
			add_node.draw_texture_rect(p.tex, Rect2(p.p - Vector2(s, s * 0.5) * 0.5, Vector2(s, s * 0.5)), false, c)
		else:
			add_node.draw_texture_rect(p.tex, Rect2(p.p - Vector2(s, s) * 0.5, Vector2(s, s)), false, c)
	for pr in projs:
		if pr.kind in ["rocket", "shell", "topattack", "mlrs", "ballistic"]:
			var sp := proj_screen(pr)
			add_node.draw_texture_rect(t_glow, Rect2(sp - Vector2(10, 10), Vector2(20, 20)), false, Color(1, 0.7, 0.3, 0.8))
	for b in beams:
		var f: float = b.t / b.d
		var a := 1.0 - f
		match b.kind:
			"tracer":
				add_node.draw_line(b.a, b.b, Color(1, 0.9, 0.5, a), b.w)
			"beam":
				add_node.draw_line(b.a, b.b, Color(0.3, 0.8, 1.0, a * 0.6), b.w * 3.0)
				add_node.draw_line(b.a, b.b, Color(0.8, 1.0, 1.0, a), b.w)
			"tesla":
				var rng := RandomNumberGenerator.new()
				rng.seed = b.seed + int(b.t * 30.0)
				for strand in 2:
					var pts := PackedVector2Array()
					var n := 9
					for k in n + 1:
						var q: Vector2 = b.a.lerp(b.b, float(k) / n)
						if k > 0 and k < n:
							q += Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12))
						pts.append(q)
					add_node.draw_polyline(pts, Color(0.4, 0.55, 1.0, a * 0.7), b.w * 2.5)
					add_node.draw_polyline(pts, Color(0.85, 0.92, 1.0, a), b.w * 0.8)

func _draw_decals():
	for d in decals:
		var a := 1.0 - maxf(0.0, (d.t - d.d * 0.6) / (d.d * 0.4))
		decal_node.draw_set_transform(d.p, 0.0, Vector2(1.0, 0.5))
		decal_node.draw_texture_rect(t_scorch, Rect2(-Vector2(d.s, d.s) * 0.5, Vector2(d.s, d.s)), false, Color(1, 1, 1, a))
	decal_node.draw_set_transform(Vector2.ZERO)
