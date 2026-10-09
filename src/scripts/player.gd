extends RefCounted
# 玩家資料：資金、電力、生產佇列、超級武器

var index := 0
var name := ""
var faction := "allies"
var country := ""
var color := Color.WHITE
var team := 0
var is_ai := false
var neutral := false
var alive := true
var game
var money := 10000.0
var power_prod := 0.0
var power_use := 0.0
var low_power := false
var queues := {"building": [], "defense": [], "infantry": [], "vehicle": []}
var ready := {"building": "", "defense": ""}
var powers := {}
var sanctioned_until := -100.0
var energy_cut_until := -100.0
var sabotage_until := -100.0
var vet_bonus := false
var relations := {}       # 其他玩家 index -> 0..100 好感度
var allies := {}          # 結盟中的玩家 index -> true
var ceasefire := {}       # 停火中的玩家 index -> 到期時間
var proposal := {}        # 對方提議中的 index -> 種類 ("ally" / "ceasefire")
var base_team := 0
var start_cell := Vector2i.ZERO
var income_mult := 1.0
var build_mult := 1.0
var primary := {}
var stats := {"built": 0, "killed": 0, "lost": 0, "bld_lost": 0, "harvested": 0}
var funds_warned := 0.0
var last_under_attack := -100.0
var power_dirty := true
var was_low := false

func is_enemy_of(other) -> bool:
	if other == null or other == self:
		return false
	if neutral or other.neutral:
		return false
	if allies.has(other.index) or other.allies.has(index):
		return false
	if ceasefire.has(other.index) and game.time < float(ceasefire[other.index]):
		return false
	return other.team != team

func relation(other) -> float:
	return float(relations.get(other.index, 30.0))

func add_relation(other, d: float):
	relations[other.index] = clampf(relation(other) + d, 0.0, 100.0)

func buildings() -> Array:
	var out := []
	for b in game.buildings:
		if b.player == self and not b.dead:
			out.append(b)
	return out

func units() -> Array:
	var out := []
	for u in game.units:
		if u.player == self and not u.dead:
			out.append(u)
	return out

func has_role(role: String) -> bool:
	for b in game.buildings:
		if b.player == self and not b.dead and b.built():
			if b.def.role == role or (role == "airfield" and b.def.get("airfield", false)):
				return true
	return false

func count_role(role: String) -> int:
	var n := 0
	for b in game.buildings:
		if b.player == self and not b.dead:
			if b.def.role == role or (role == "airfield" and b.def.get("airfield", false)):
				n += 1
	return n

func count_type(id: String) -> int:
	var n := 0
	for b in game.buildings:
		if b.player == self and not b.dead and b.type_id == id:
			n += 1
	for u in game.units:
		if u.player == self and not u.dead and u.type_id == id:
			n += 1
	for c in queues:
		for it in queues[c]:
			if it.id == id:
				n += 1
	for c in ready:
		if ready[c] == id:
			n += 1
	return n

func producer_role(def: Dictionary) -> String:
	match def.get("cat", ""):
		"building", "defense":
			return "cy"
		"infantry":
			return "bar"
		"naval":
			return "yard"
		"air":
			if def.get("drone", false):
				return "dronehub"
			return "airfield" if def.get("jet", false) else "fac"
	return "fac"

func queue_cat(def: Dictionary) -> String:
	var c: String = def.get("cat", "")
	return "vehicle" if c == "air" or c == "naval" else c

# factions whose tech we own (captured enemy production buildings unlock their units)
func tech_factions(role: String) -> Array:
	var out := [faction]
	for b in game.buildings:
		if b.player == self and not b.dead and b.def.role == role and not out.has(b.def.faction):
			out.append(b.def.faction)
	return out

func missing_req(id: String) -> String:
	var def: Dictionary = Defs.get_def(id)
	var names := {"cy": "建造廠", "power": "發電廠", "ref": "精煉廠", "bar": "兵營", "fac": "戰車工廠",
		"radar": "雷達", "tech": "科技中心", "airfield": "空軍指揮部", "dronehub": "無人機站", "bank": "金融/能源設施", "yard": "造船廠"}
	for r in def.get("req", []):
		if not has_role(r):
			return names.get(r, r)
	return ""

func available(id: String) -> bool:
	var def: Dictionary = Defs.get_def(id)
	if def.is_empty() or def.get("buildable", true) == false:
		return false
	if def.has("country") and def.country != country:
		return false
	var role := producer_role(def)
	if not tech_factions(role).has(def.faction):
		return false
	return true

func can_build(id: String) -> bool:
	if not available(id):
		return false
	if missing_req(id) != "":
		return false
	var def: Dictionary = Defs.get_def(id)
	if def.has("limit") and count_type(id) >= int(def.limit):
		return false
	return has_role(producer_role(def))

func enqueue(id: String) -> bool:
	if not can_build(id):
		return false
	var def: Dictionary = Defs.get_def(id)
	var cat := queue_cat(def)
	var q: Array = queues[cat]
	if cat == "building" or cat == "defense":
		if q.size() > 0 or ready[cat] != "":
			return false
	elif q.size() >= 15:
		return false
	q.append({"id": id, "progress": 0.0, "spent": 0.0, "hold": false})
	return true

var no_treaty_until := -100.0

func cost_of(id: String) -> float:
	var em: float = game.world_ev.cost_mult(self) if game != null and game.world_ev != null else 1.0
	return float(Defs.get_def(id).get("cost", 0)) * Defs.country_mult(country, "cost", id) * em

func country_name() -> String:
	return Defs.COUNTRIES[country].name if Defs.COUNTRIES.has(country) else ""

func cancel(id: String) -> bool:
	var def: Dictionary = Defs.get_def(id)
	var cat := queue_cat(def)
	if ready.has(cat) and ready[cat] == id:
		ready[cat] = ""
		money += cost_of(id)
		return true
	var q: Array = queues[cat]
	for i in range(q.size() - 1, -1, -1):
		if q[i].id == id:
			money += q[i].spent
			q.remove_at(i)
			return true
	return false

func progress_of(id: String) -> float:
	var def: Dictionary = Defs.get_def(id)
	var cat := queue_cat(def)
	var q: Array = queues[cat]
	if q.size() > 0 and q[0].id == id:
		return q[0].progress
	return -1.0

func queued_count(id: String) -> int:
	var def: Dictionary = Defs.get_def(id)
	var n := 0
	for it in queues[queue_cat(def)]:
		if it.id == id:
			n += 1
	return n

func recalc_power():
	power_prod = 0.0
	power_use = 0.0
	for b in game.buildings:
		if b.player == self and not b.dead and b.built():
			var pw: float = float(b.def.get("power", 0))
			if pw > 0:
				power_prod += pw * clampf(b.hp / b.max_hp * 1.2, 0.3, 1.0)
			else:
				power_use += -pw
	if game.time < energy_cut_until:
		power_prod = 0.0
	low_power = power_use > power_prod
	if low_power and not was_low and not is_ai and power_use > 0:
		Sfx.say("low_power", 20.0)
		Sfx.play("power_down", -4.0)
		game.message("電力不足！生產減慢、防禦停擺")
	was_low = low_power

func update(dt: float):
	if neutral or not alive:
		return
	recalc_power()
	for cat in queues:
		var q: Array = queues[cat]
		if q.is_empty():
			continue
		if ready.has(cat) and ready[cat] != "":
			continue
		var it: Dictionary = q[0]
		var def: Dictionary = Defs.get_def(it.id)
		var role := producer_role(def)
		var n := count_role(role)
		if n == 0 or not has_role(role):
			continue
		var t := Defs.build_time(it.id) / build_mult * Defs.country_mult(country, "time", it.id)
		var mult := 1.0 + 0.4 * (mini(n, 4) - 1)
		if low_power:
			mult *= 0.45
		if game.time < sabotage_until:
			mult *= 0.3
		if sanctioned():
			mult *= 0.5
		if game.world_ev != null:
			mult *= game.world_ev.speed_mult(self)
		var step := dt * mult / t
		var cost_full := cost_of(it.id)
		var cost_step := cost_full * step
		if money < cost_step:
			if not is_ai and game.time - funds_warned > 12.0:
				funds_warned = game.time
				Sfx.say("funds_low", 12.0)
				game.message("資金不足")
			continue
		money -= cost_step
		it.spent += cost_step
		it.progress += step
		if it.progress >= 1.0:
			money -= maxf(0.0, cost_full - it.spent)
			q.pop_front()
			if OS.get_cmdline_user_args().has("--autotest"):
				print("  DONE t=%d %s %s" % [int(game.time), name, it.id])
			if cat == "building" or cat == "defense":
				ready[cat] = it.id
				if not is_ai:
					Sfx.say("building_ready", 1.0)
					game.message("%s 建造完成，請選擇放置位置" % def.name)
			else:
				game.spawn_produced(self, it.id)
				stats.built += 1
	# special powers
	var have := {}
	for b in game.buildings:
		if b.player == self and not b.dead and b.built() and b.def.has("power_sw"):
			have[b.def.power_sw] = true
		# 國家特殊能力：需要雷達 / 空軍指揮部
		if b.player == self and not b.dead and b.built() and b.def.role == "radar" and Defs.COUNTRIES.has(country) and Defs.COUNTRIES[country].has("power"):
			have[Defs.COUNTRIES[country].power] = true
	if not allies.is_empty() and not is_ai:
		have["allyaid"] = true
	for k in powers.keys():
		if not have.has(k):
			powers.erase(k)
	for k in have:
		if not powers.has(k):
			powers[k] = 0.0
		var c: float = powers[k]
		if c < 1.0 and not low_power:
			var cm: float = float(Defs.COUNTRIES[country].get("charge", {}).get(k, 1.0)) if Defs.COUNTRIES.has(country) else 1.0
			var nc := minf(1.0, c + dt * cm / float(Defs.SUPER[k].charge))
			powers[k] = nc
			if nc >= 1.0:
				game.on_power_ready(self, k)

func sanctioned() -> bool:
	return game.time < sanctioned_until

func income_factor() -> float:
	return income_mult * (0.4 if sanctioned() else 1.0)

func power_list() -> Array:
	var out := []
	for k in Defs.POWER_ORDER:
		if powers.has(k):
			out.append(k)
	return out
