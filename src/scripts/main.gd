extends Node
# 主程式：主選單 / 遊戲切換

const MenuS = preload("res://scripts/menu.gd")
const GameS = preload("res://scripts/game.gd")

var menu = null
var game = null
var last_settings := {}
var auto_quit := -1.0
var shots: Array = []
var shot_dir := ""

func _ready():
	G.main = self
	DisplayServer.window_set_title("紅色風暴 Red Storm")
	get_tree().root.min_size = Vector2i(1024, 640)
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		var s := default_settings()
		s["auto"] = true
		s["enemies"] = 1
		for a in args:
			if a.begins_with("--map="):
				s["map"] = preload("res://scripts/map.gd").PRESETS[int(a.substr(6))]
			if a.begins_with("--time="):
				auto_quit = float(a.substr(7))
			if a.begins_with("--shots="):
				shot_dir = a.substr(8)
			if a.begins_with("--every="):
				G.settings["shot_every"] = float(a.substr(8))
			if a.begins_with("--speed="):
				s["speed"] = float(a.substr(8))
			if a.begins_with("--seed="):
				s["seed"] = int(a.substr(7))
			if a.begins_with("--zoom="):
				G.settings["debug_zoom"] = float(a.substr(7))
			if a.begins_with("--enemies="):
				s["enemies"] = int(a.substr(10))
			if a.begins_with("--mission="):
				var md: Dictionary = preload("res://scripts/missions.gd").find(a.substr(10))
				s["mission"] = md.id
				s["map"] = md.map
				s["seed"] = md.seed
				s["faction"] = md.faction
				s["enemy_faction"] = md.enemy
				s["money"] = md.money
				s["enemies"] = int(md.get("enemies", 1))
				s["ai_allied"] = not md.get("ffa", false)
				if md.has("country"):
					s["country"] = md.country
					s["enemy_country"] = md.get("enemy_country", "random")
			if a.begins_with("--faction="):
				s["faction"] = a.substr(10)
			if a.begins_with("--country="):
				s["country"] = a.substr(10)
			if a.begins_with("--size="):
				var mp: Dictionary = s["map"].duplicate()
				mp["size"] = int(a.substr(7))
				s["map"] = mp
			if a.begins_with("--diff="):
				s["difficulty"] = int(a.substr(7))
			if a.begins_with("--weather="):
				G.settings["debug_weather"] = a.substr(10)
			if a.begins_with("--muts="):
				s["muts"] = Array(a.substr(7).split(","))
			if a == "--daily":
				var dsd: Dictionary = MenuS.daily_settings(MenuS.today_code())
				for k in dsd:
					s[k] = dsd[k]
				print("  DAILY ", dsd.country, " vs ", dsd.enemy_country, " map=", dsd.map.name, " diff=", dsd.difficulty, " mode=", dsd["mode"], " muts=", dsd.muts)
			if a.begins_with("--persona="):
				G.settings["debug_persona"] = a.substr(10)
			if a.begins_with("--mode="):
				s["mode"] = a.substr(7)
			if a == "--ffa":
				s["ai_allied"] = false
			if a == "--rectest":
				s["rec_test"] = true
			if a.begins_with("--units="):
				G.settings["debug_units"] = a.substr(8)
		if s.has("mission") and not s.has("country"):
			s.erase("enemy_country")
		if auto_quit < 0:
			auto_quit = 120.0
		start_game(s)
		if args.has("--mapshot"):
			var img: Image = game.map.make_preview(true)
			img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
			img.save_png("/tmp/claude-0/pv/map_%d.png" % [MapS_index(s)])
			print("MAPSHOT starts=", game.map.starts, " oils=", game.map.oils.size())
			get_tree().quit()
			return
		if args.has("--battle"):
			game.debug_battle()
		if args.has("--airtest"):
			var sc: Vector2i = game.human.start_cell
			var af = game.place_building(game.human, "a_radar", sc + Vector2i(-3, 4), true)
			af.build_p = 1.0
			for k in 3:
				var j = game.spawn_unit(game.human, "a_jet", Vector2(sc) + Vector2(-12 - k * 2, -6))
				j.landed = false
				j.alt = j.def.get("alt", 3.0) if j.get("alt") != null else 3.0
				j.order = "return"
			game.events.append({"t": 1.0, "fn": func(): game.center_on(af.pos)})
			game.events.append({"t": 30.0, "fn": func():
				for u in game.units:
					if u.type_id == "a_jet":
						print("  JET landed=", u.landed, " pos=", u.pos, " af=", af.pos)})
		if args.has("--navaltab"):
			game.events.append({"t": 2.0, "fn": func():
				var ids: Array = game.hud.tab_items(4)
				print("  NAVAL tab items=", ids, " enabled=", game.hud.tab_enabled(4))})
		if args.has("--evtest"):
			var EV = preload("res://scripts/events.gd")
			var tt := 5.0
			for ev in EV.EVENTS:
				var evd: Dictionary = ev
				game.events.append({"t": tt, "fn": func():
					game.world_ev.fire(evd, game.human if randf() < 0.6 else game.players[1])
					print("  EVENT ", evd.id, " money=", int(game.human.money), " active=", game.world_ev.active.size())})
				tt += 12.0
		if args.has("--rectest"):
			game.events.append({"t": 130.0, "fn": func():
				game.human.stats.killed += 160
				game.end_game(true)
				print("  RECTEST ach=", preload("res://scripts/records.gd").get_rec().ach)})
		if args.has("--savetest"):
			game.events.append({"t": 150.0, "fn": func():
				var ok: bool = SaveS.save_game(game, 2)
				print("  SAVE ok=", ok, " units=", game.units.size(), " blds=", game.buildings.size(), " money=", int(game.human.money), " explored=", game.explored.count(1))
				load_game(2)
				print("  LOAD units=", game.units.size(), " blds=", game.buildings.size(), " money=", int(game.human.money), " time=", game.time, " explored=", game.explored.count(1), " mission=", game.mission != null)
				auto_quit = game.time + 120.0})
		if args.has("--startstest"):
			for b in game.buildings:
				if b.def.has("tech"):
					print("  TECH ", b.type_id, " at ", b.cell)
			print("  STARTS layout=", game.map.layout, " W=", game.W, " human=", game.human.start_cell, " enemy=", game.players[1].start_cell)
			get_tree().quit()
			return
		if G.settings.has("debug_weather") and game.weather != null:
			game.weather.cur = str(G.settings.debug_weather)
			game.weather.fade = 1.0
			game.weather.until = 99999.0
			game.events.append({"t": 3.0, "fn": func():
				var tk = game.units.filter(func(u): return u.player == game.human and u.ukind == "veh")[0]
				var arty := 0.0
				var w = game.weather
				print("  WEATHER ", w.cur, " ground=", w.speed_mult(tk), " range(5.5)=", w.range_mult(5.5), " range(12)=", w.range_mult(12.0), " status=", w.status_text())})
		for a in args:
			if a.begins_with("--perfoff="):
				var offs := a.substr(10).split(",")
				game.events.append({"t": 2.0, "fn": func():
					for c in game.objects.get_children():
						if "props" in offs and c.get_script() != null and c.get_script().resource_path.ends_with("prop.gd"):
							c.visible = false
					if "map" in offs:
						game.map.visible = false
						game.map.water_layer.visible = false
					if "deco" in offs:
						game.map.deco_layer.visible = false
						game.map.ore_layer.visible = false
					if "hud" in offs:
						game.hud.visible = false
						game.hud.side.visible = false
						game.hud.top.visible = false
					if "shroud" in offs:
						game.shroud.visible = false})
		if args.has("--perflog"):
			game.events.append({"t": 3.0, "fn": func():
				var cnt := {}
				var stack: Array = [game]
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					var k: String = n.get_script().resource_path.get_file() if n.get_script() != null else n.get_class()
					cnt[k] = int(cnt.get(k, 0)) + 1
					stack.append_array(n.get_children())
				print("  NODES ", cnt)
				print("  map chunks=", game.map.chunks.size(), " trees=", game.map.trees.size(), " rocks=", game.map.rocks.size())})

			for k in 6:
				game.events.append({"t": 5.0 + k * 5.0, "fn": func():
					print("  PERF t=%d fps=%d proc=%.1fms draws=%d objs=%d" % [int(game.time), Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
						Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
					var ks: Array = game.prof.keys()
					var parts := []
					for kk in ks:
						parts.append("%s=%.1f" % [kk, float(game.prof[kk]) / 1000.0])
					print("     ms: ", " ".join(parts), "  units=", game.units.size(), " zoom=", game.zoom)})
		if args.has("--techshot"):
			game.events.append({"t": 2.0, "fn": func():
				var techs: Array = game.buildings.filter(func(b): return b.def.has("tech"))
				techs.sort_custom(func(a, b): return a.def.tech < b.def.tech)
				var air = techs.filter(func(b): return b.def.tech == "air")[0]
				game.reveal(air.pos, 14.0)
				game.center_on(air.pos)
				for b in techs:
					if b.def.tech != "air" and b.pos.distance_to(air.pos) < 25.0:
						game.reveal(b.pos, 6.0)
				var eng = game.spawn_unit(game.human, "a_eng" if game.human.faction == "allies" else "s_eng", air.pos)
				game.engineer_enter(eng, air)
				game.contracts.offer("kills")
				game.events.append({"t": game.time + 1.0, "fn": func(): print("  AIRVIS visible=", air.visible, " owner=", air.player.name)})})
		if args.has("--contracttest"):
			var C = game.contracts
			game.ais = game.ais.filter(func(a): return a.p != game.human)
			game.events.append({"t": 5.0, "fn": func():
				var c := Vector2(game.human.start_cell) + Vector2(4, 4)
				C.offer("kills")
				C.cur.need = 3
				for k in 3:
					var e = game.spawn_unit(game.players[1], "s_con" if game.players[1].faction == "soviet" else "a_gi", c + Vector2(k * 0.5, 0))
					e.last_attacker = game.units.filter(func(u): return u.player == game.human)[0]
					e.take_damage(1e6, e.last_attacker, "he")})
			game.events.append({"t": 8.0, "fn": func():
				C.offer("tech")
				var tb = null
				for b in game.buildings.duplicate():
					if b.def.has("tech"):
						tb = b
						var eng = game.spawn_unit(game.human, "a_eng" if game.human.faction == "allies" else "s_eng", b.pos)
						game.engineer_enter(eng, b)
				var gi = game.spawn_unit(game.human, "a_gi" if game.human.faction == "allies" else "s_con", Vector2(game.human.start_cell) + Vector2(3, 3))
				gi.hp = 20.0
				game.events.append({"t": game.time + 5.0, "fn": func():
					print("  TECHTEST owner=", tb.player.name, " gi_hp=", int(gi.hp), "/", int(gi.max_hp), " powers=", game.human.powers.keys())})})
			game.events.append({"t": 15.0, "fn": func():
				C.offer("hold")
				C.cur.until = game.time + 3.0})
			game.events.append({"t": 20.0, "fn": func():
				C.offer("snipe")
				print("  SNIPE target=", C.cur.target.def.name)
				C.cur.target.take_damage(1e6, null, "he")})
			game.events.append({"t": 24.0, "fn": func():
				print("  CONTRACTS done=", C.done, " failed=", C.failed, " money=", int(game.human.money))})
		if args.has("--repeattest"):
			var inf: String = "a_gi" if game.human.faction == "allies" else "s_con"
			game.events.append({"t": 100.0, "fn": func():
				game.human.money += 5000
				game.human.repeat[inf] = true
				game.human.enqueue(inf)
				print("  REPEAT on, count=", game.human.count_type(inf))})
			game.events.append({"t": 160.0, "fn": func():
				print("  REPEAT after 60s count=", game.human.count_type(inf), " queued=", game.human.queued_count(inf))})
		if args.has("--abilitytest"):
			game.events.append({"t": 3.0, "fn": func():
				var c := Vector2(game.W, game.H) * 0.5
				var en = game.players[1]
				var dug_gi = game.spawn_unit(game.human, "a_gi", c)
				var open_gi = game.spawn_unit(game.human, "a_gi", c + Vector2(0, 1.0))
				var tk = game.spawn_unit(game.human, "a_tank", c + Vector2(-1.0, 0.5))
				dug_gi.use_ability()
				tk.use_ability()
				print("  ABIL dug=", dug_gi.dug, " range=", dug_gi.weapon_range(), " smoke=", tk.ability_status(), " again=", tk.use_ability())
				game.human.finish_upgrade("up_inf_armor")
				for k in 4:
					game.spawn_unit(en, "s_con", c + Vector2(4.0, -1.0 + k * 0.6))
				game.events.append({"t": game.time + 12.0, "fn": func():
					print("  ABIL after 12s dugHP=", int(dug_gi.hp) if is_instance_valid(dug_gi) else -1, " openHP=", int(open_gi.hp) if is_instance_valid(open_gi) else -1, " tankHP=", int(tk.hp) if is_instance_valid(tk) else -1, " status=", tk.ability_status() if is_instance_valid(tk) else "")})})
		if args.has("--upshot"):
			game.events.append({"t": 4.0, "fn": func():
				game.ais = game.ais.filter(func(a): return a.p != game.human)
				var sc := Vector2(game.human.start_cell) + Vector2(3.5, 6.5)
				game.human.finish_upgrade("up_inf_armor")
				game.human.finish_upgrade("up_mining")
				game.human.money += 3000
				game.human.enqueue("up_veh_weapon")
				game.hud.tab = 5
				for k in 4:
					var g = game.spawn_unit(game.human, "a_gi" if game.human.faction == "allies" else "s_con", sc + Vector2(k * 0.9, 0))
					g.use_ability()
					game.selection.append(g)
					g.selected = true
				var tk = game.spawn_unit(game.human, "a_tank" if game.human.faction == "allies" else "s_tank", sc + Vector2(1.5, 2.0))
				tk.use_ability()
				game.center_on(sc)})
		if args.has("--hillshot"):
			game.events.append({"t": 2.0, "fn": func():
				if game.gmode != null and game.gmode.is_koth():
					game.reveal(game.gmode.hill, 12.0)
					game.center_on(game.gmode.hill)
					print("  HILLSHOT hill=", game.gmode.hill, " map=", game.W, "x", game.H)})
			game.events.append({"t": 190.0, "fn": func():
				if game.gmode != null:
					game.center_on(game.gmode.hill)})
		if args.has("--endshot"):
			game.events.append({"t": 240.0, "fn": func():
				game.mvp = {"name": "灰狼坦克", "kills": 7, "rank": 2}
				auto_quit = -1.0
				game.end_game(true)
				await get_tree().create_timer(1.0).timeout
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(shot_dir + "/end.png")
				get_tree().quit()})
		if args.has("--diploshot"):
			game.events.append({"t": 3.0, "fn": func():
				game.human.proposal[1] = "ally"
				game.hud.toggle_diplomacy()
				game.paused = false})
		if args.has("--diplo"):
			game.events.append({"t": 30.0, "fn": func():
				game.players[1].relations[0] = 70.0
				print("  DIPLO propose -> ", game.propose(game.human, game.players[1], "ally"), " allies=", game.human.allies)})
			game.events.append({"t": 200.0, "fn": func():
				game.human.powers["allyaid"] = 1.0
				print("  DIPLO allyaid -> ", game.fire_power(game.human, "allyaid", Vector2(game.players[2].start_cell) if game.players.size() > 3 else Vector2(game.W * 0.5, game.H * 0.5)))})
			game.events.append({"t": 320.0, "fn": func():
				game.break_treaty(game.human, game.players[1])
				print("  DIPLO broke allies=", game.human.allies, " enemy=", game.human.is_enemy_of(game.players[1]))})
		for a in args:
			if a.begins_with("--look="):
				var xy := a.substr(7).split(",")
				var lc := Vector2(float(xy[0]), float(xy[1]))
				game.events.append({"t": 1.0, "fn": func():
					game.reveal(lc, 40.0)
					game.center_on(lc)
					if G.settings.has("debug_zoom"):
						game.set_zoom(float(G.settings.debug_zoom))
						game.center_on(lc)
					var n := 0
					for y in range(int(lc.y) - 6, int(lc.y) + 7):
						for x in range(int(lc.x) - 6, int(lc.x) + 7):
							if (x >= 0 and y >= 0 and x < game.W and y < game.H) and game.map.elev[game.map.idx(x, y)] > 0 and n < 6:
								var sp = game.spawn_unit(game.human, "a_gi" if game.human.faction == "allies" else "s_conscript", Vector2(x + 0.5, y + 0.5))
								n += 1
								if sp != null and n == 1:
									game.spawn_unit(game.human, "a_tank" if game.human.faction == "allies" else "s_tank", Vector2(x + 0.5, y + 1.5))
					print("  LOOK elev=", game.map.elev[game.map.idx(int(lc.x), int(lc.y))], " spawned=", n)})
			if a.begins_with("--firepower="):
				var k := a.substr(12)
				var c := Vector2(game.W, game.H) * 0.5
				game.reveal(c, 30.0)
				game.center_on(c)
				game.human.powers[k] = 1.0
				game.fire_power(game.human, k, c)
	elif args.has("--menustart"):
		to_menu()
		await get_tree().process_frame
		await get_tree().process_frame
		menu._start()
		await get_tree().process_frame
		print("MENUSTART money=", game.human.money, " enemies=", game.ais.size(), " diff=", game.settings.difficulty)
		get_tree().quit()
	elif args.has("--menushot"):
		to_menu()
		shot_dir = "/tmp/shots"
		for a in args:
			if a.begins_with("--shots="):
				shot_dir = a.substr(8)
		if args.has("--recshot"):
			var RecS = preload("res://scripts/records.gd")
			var r: Dictionary = RecS.get_rec()
			r.games = 12; r.wins = 7; r.losses = 5; r.killed = 640; r.built = 410; r.harvested = 180000.0; r.play_time = 5400.0; r.best_win = 480.0
			r.ach = "first_blood,veteran,hundred,blitz"; r.spies = 4; r.powers = 9; r.streak = 2; r.best_streak = 3; r.max_kills = 120
			menu.show_records()
		for a in args:
			if a.begins_with("--bg="):
				menu.bg_style = int(a.substr(5))
				menu.parade.clear()
				menu.setup_parade()
		if args.has("--dailyshot"):
			menu.show_daily()
		if args.has("--flagsel"):
			menu.opts.country.select(9)
			menu._update_country_desc()
		if args.has("--campshot"):
			menu.camp.visible = true
			menu.camp_sel = 8
			var md: Dictionary = preload("res://scripts/missions.gd").LIST[8]
			menu.camp_brief.text = "RSN BREAKING: " + md.headline + "\n\n" + md.brief
		await get_tree().create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot_dir + "/menu.png")
		get_tree().quit()
	elif args.has("--introshot") or args.has("--promoshot"):
		var sd := "/tmp/shots"
		for a in args:
			if a.begins_with("--shots="):
				sd = a.substr(8)
		play_intro(false, "promo" if args.has("--promoshot") else "5min")
		await get_tree().create_timer(9.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(sd + "/intro.png")
		print("INTROSHOT video=", intro.use_video_stream if intro != null else "none", " playing=", intro.vsp.is_playing() if intro != null and intro.vsp != null else false, " t=", intro.t if intro != null else -1.0)
		get_tree().quit()
	elif args.has("--briefshot"):
		var md: Dictionary = preload("res://scripts/missions.gd").find("h4")
		briefing = BriefS.new()
		briefing.md = md
		add_child(briefing)
		await get_tree().create_timer(4.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shots/brief.png")
		get_tree().quit()
	elif args.has("--introrec"):
		var dir := "/tmp/introframes"
		DirAccess.make_dir_recursive_absolute(dir)
		var it = IntroS.new()
		it.record_dir = dir
		add_child(it)
		it.finished.connect(func():
			var f := FileAccess.open(dir + "/sfx.json", FileAccess.WRITE)
			f.store_string(JSON.stringify(it.sfx_log))
			f.close()
			print("INTRO frames=", it.frame_i)
			get_tree().quit())
	else:
		if G.settings.get("intro_seen", false):
			to_menu()
		else:
			play_intro(false)

var intro = null
const IntroS = preload("res://scripts/intro.gd")

func play_intro(from_menu: bool, mode := "5min"):
	Sfx.stop_all()
	if menu != null:
		menu.queue_free()
		menu = null
	intro = IntroS.new()
	intro.video_mode = mode
	add_child(intro)
	intro.finished.connect(func():
		intro.queue_free()
		intro = null
		G.settings["intro_seen"] = true
		G.save_settings()
		to_menu())

func play_promo():
	play_intro(true, "promo")

const SaveS = preload("res://scripts/saveload.gd")

func load_game(n: int) -> bool:
	var d = SaveS.load_settings(n)
	if d == null:
		if game != null:
			game.message("沒有存檔")
		return false
	var s: Dictionary = d.settings
	if s.has("map") and s.map is Dictionary:
		var mp: Dictionary = s.map
		mp["size"] = int(mp.get("size", 72))
	s["seed"] = int(s.get("seed", 1))
	s["enemies"] = int(s.get("enemies", 1))
	s["money"] = float(s.get("money", 10000))
	s["difficulty"] = int(s.get("difficulty", 1))
	s.erase("brief_shown")
	s["from_save"] = true
	start_game(s)
	SaveS.apply(game, d)
	return true

func default_settings() -> Dictionary:
	return {
		"faction": G.settings.faction, "enemy_faction": "random", "enemies": 1, "ai_allied": true,
		"country": "random", "enemy_country": "random",
		"difficulty": 1, "money": 10000, "map": preload("res://scripts/map.gd").PRESETS[0], "seed": randi(), "speed": 1.0,
	}

func to_menu():
	Sfx.stop_all()
	if game != null:
		game.queue_free()
		game = null
		G.game = null
	if menu != null:
		menu.queue_free()
	menu = MenuS.new()
	add_child(menu)

const BriefS = preload("res://scripts/briefing.gd")
var briefing = null

func start_game(s: Dictionary):
	last_settings = s.duplicate()
	if menu != null:
		menu.queue_free()
		menu = null
	# 戰役任務：先播新聞式簡報
	if s.has("mission") and not s.get("auto", false) and not s.get("from_save", false) and not s.get("brief_shown", false):
		var md: Dictionary = preload("res://scripts/missions.gd").find(s.mission)
		if md.has("headline"):
			if game != null:
				game.queue_free()
				game = null
			Sfx.stop_all()
			briefing = BriefS.new()
			briefing.md = md
			add_child(briefing)
			var s2 := s.duplicate()
			s2["brief_shown"] = true
			briefing.finished.connect(func():
				briefing.queue_free()
				briefing = null
				start_game(s2))
			return
	if game != null:
		game.queue_free()
		game = null
	Sfx.stop_all()
	game = GameS.new()
	add_child(game)
	game.start(s)
	if s.get("auto", false):
		game.enable_autopilot()

func MapS_index(s: Dictionary) -> int:
	return preload("res://scripts/map.gd").PRESETS.find(s.get("map"))

# 離開遊戲：桌面版直接關閉；網頁版嘗試關閉分頁，被瀏覽器擋下時顯示提示畫面
func quit_game():
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	JavaScriptBridge.eval("window.close()", true)
	if game != null:
		game.queue_free()
		game = null
		G.game = null
	if menu != null:
		menu.queue_free()
		menu = null
	Sfx.stop_all()
	var bye := ColorRect.new()
	bye.color = Color(0.03, 0.03, 0.04)
	bye.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bye)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bye.add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)
	var lb := Label.new()
	lb.text = "已離開遊戲，可以直接關閉這個瀏覽器分頁。
感謝遊玩《紅色風暴》！"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_override("font", G.font_bold)
	lb.add_theme_font_size_override("font_size", 26)
	lb.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vb.add_child(lb)
	var back := Button.new()
	back.text = "回到主選單"
	back.custom_minimum_size = Vector2(240, 48)
	back.pressed.connect(func(): bye.queue_free(); to_menu())
	vb.add_child(back)

func restart_game():
	start_game(last_settings)

func _process(_dt: float):
	if auto_quit > 0.0 and game != null:
		if shot_dir != "":
			var next := int(game.time / float(G.settings.get("shot_every", 30.0)))
			if not shots.has(next):
				shots.append(next)
				_shot("%s/t%04d.png" % [shot_dir, int(game.time)])
		if int(game.time / 60.0) != int((game.time - 0.2) / 60.0):
			for p in game.players:
				if not p.neutral:
					var hs := {}
					for u in p.units():
						if u.def.get("harvester", false):
							hs[u.order] = hs.get(u.order, 0) + 1
					print("   harv states ", hs, " refs=", p.count_role("ref"))
					print("T%d %s units=%d blds=%d money=%d harv=%d killed=%d lost=%d q=%s" % [int(game.time), p.name, p.units().size(), p.buildings().size(), int(p.money), p.stats.harvested, p.stats.killed, p.stats.lost, str(p.queues.building.size())])
		if game.time >= auto_quit or game.game_over:
			var h = game.human
			print("AUTOTEST time=%.1f units=%d buildings=%d money_h=%d result=%s" % [game.time, game.units.size(), game.buildings.size(), int(h.money), game.result])
			for p in game.players:
				if not p.neutral:
					var kinds := {}
					for u in p.units():
						kinds[u.type_id] = kinds.get(u.type_id, 0) + 1
					print("  ", p.name, " alive=", p.alive, " money=", int(p.money), " stats=", p.stats, " units=", p.units().size(), " blds=", p.buildings().size(), " powers=", p.powers)
					print("     ", kinds)
					var bk := {}
					for b in p.buildings():
						bk[b.type_id] = bk.get(b.type_id, 0) + 1
					print("     B:", bk)
			get_tree().quit()
			auto_quit = -1.0

func _shot(path: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
