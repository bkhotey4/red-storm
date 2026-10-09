extends Node2D
# 地圖：生成、地形繪製、礦石

const PRESETS := [
	{"name": "綠野平原", "theme": "temperate", "layout": "plains", "size": 100, "desc": "開闊草原，適合新手。"},
	{"name": "雙河谷地", "theme": "temperate", "layout": "river", "size": 112, "desc": "大河橫貫戰場，只有數個淺灘可以通過。"},
	{"name": "沙漠風暴", "theme": "desert", "layout": "canyon", "size": 112, "desc": "峽谷縱橫的沙漠，爭奪狹窄通道。"},
	{"name": "冰雪前線", "theme": "snow", "layout": "lake", "size": 112, "desc": "冰封湖泊位於中央，資源集中在湖岸。"},
	{"name": "焦土荒原", "theme": "desert", "layout": "plains", "size": 144, "desc": "巨大的荒漠平原，適合多人混戰。"},
	{"name": "寒冬峽谷", "theme": "snow", "layout": "canyon", "size": 100, "desc": "雪山之間的狹路相逢。"},
	{"name": "群島湖區", "theme": "temperate", "layout": "lake", "size": 128, "desc": "湖泊遍布的大地圖。"},
	{"name": "海岸決戰", "theme": "temperate", "layout": "coast", "size": 112, "desc": "雙方基地都靠海，可建造造船廠發展海軍。"},
	{"name": "熱帶海灣", "theme": "tropical", "layout": "coast", "size": 120, "desc": "棕櫚樹環繞的海灣與紅土峭壁，海陸空全面作戰。"},
	{"name": "棕櫚群島", "theme": "tropical", "layout": "lake", "size": 120, "desc": "熱帶潟湖散布，峭壁與叢林交錯。"},
	{"name": "紅岩叢林", "theme": "tropical", "layout": "canyon", "size": 112, "desc": "紅土峭壁切割的叢林戰場，搶占隘口。"},
	{"name": "台灣海峽", "theme": "tropical", "layout": "strait", "size": 160, "desc": "東側島嶼、西側大陸，中央海峽只有澎湖列島可落腳。島上東部是高山。需要海軍與空軍跨海作戰。"},
	{"name": "波斯灣", "theme": "desert", "layout": "gulf", "size": 160, "desc": "狹長海灣斜貫沙漠，油井密布，荷莫茲海峽是唯一的出海口。"},
	{"name": "歐亞大平原", "theme": "temperate", "layout": "plains", "size": 192, "desc": "超巨型平原，4 名玩家的長期消耗戰。"},
]
const THEMES := {
	"temperate": {"base": "grass", "dirt": "dirt", "alt": "sand", "rock": "rock", "water": "water",
		"mini": [Color(0.30, 0.42, 0.16), Color(0.42, 0.34, 0.22), Color(0.66, 0.58, 0.40), Color(0.10, 0.25, 0.38), Color(0.42, 0.40, 0.37), Color(0.3, 0.3, 0.3)],
		"trees": [["tree", 0], ["tree", 1], ["tree", 2], ["tree", 3], ["tree", 4], ["tree", 5], ["tree", 6], ["tree", 7]], "tree_density": 0.55,
		"deco": [0, 1, 2, 3, 0, 1, 4, 5, 6, 7, 8, 9, 10, 12, 14], "clear": Color(0.05, 0.06, 0.04)},
	"desert": {"base": "sand", "dirt": "dirt", "alt": "dune", "rock": "rock_trop", "water": "water", "rock_sprite": "cliff",
		"mini": [Color(0.70, 0.62, 0.44), Color(0.45, 0.36, 0.24), Color(0.78, 0.70, 0.52), Color(0.10, 0.25, 0.38), Color(0.44, 0.40, 0.35), Color(0.3, 0.3, 0.3)],
		"trees": [["palm", 0], ["palm", 1], ["palm", 2], ["palm", 3], ["palm", 4], ["palm", 5], ["tree", 2]], "tree_density": 0.2,
		"deco": [8, 9, 10, 11, 8, 9, 2, 13, 15], "clear": Color(0.08, 0.06, 0.04)},
	"tropical": {"base": "grass_trop", "dirt": "dirt_trop", "alt": "beach", "rock": "rock_trop", "water": "water", "rock_sprite": "cliff", "beach": 2,
		"mini": [Color(0.30, 0.48, 0.10), Color(0.52, 0.33, 0.18), Color(0.84, 0.75, 0.54), Color(0.06, 0.18, 0.42), Color(0.62, 0.40, 0.22), Color(0.3, 0.3, 0.3)],
		"trees": [["palm", 0], ["palm", 1], ["palm", 2], ["palm", 3], ["palm", 4], ["palm", 5], ["palm", 0], ["palm", 3], ["tree", 0], ["tree", 2]], "tree_density": 0.5, "water_tint": Color(0.62, 0.78, 1.12),
		"deco": [0, 1, 2, 3, 0, 1, 4, 5, 6, 7, 8, 9, 10, 12, 14], "clear": Color(0.04, 0.06, 0.03)},
	"snow": {"base": "snow", "dirt": "snowdirt", "alt": "ice", "rock": "rock", "water": "water",
		"mini": [Color(0.85, 0.88, 0.92), Color(0.55, 0.55, 0.55), Color(0.70, 0.82, 0.92), Color(0.12, 0.25, 0.38), Color(0.40, 0.40, 0.42), Color(0.35, 0.35, 0.36)],
		"trees": [["snowpine", 0], ["snowpine", 1], ["snowpine", 2], ["snowpine", 3], ["snowpine", 4], ["snowpine", 5]], "tree_density": 0.5,
		"deco": [8, 9, 10, 11, 12, 14], "clear": Color(0.05, 0.06, 0.08)},
}
const T_BASE := 0
const T_DIRT := 1
const T_ALT := 2
const T_WATER := 3
const T_ROCK := 4
const T_ROAD := 5
const CIVS := ["civ_house", "civ_house", "civ_shop", "civ_office", "civ_gas", "civ_tower", "civ_barn"]
const ORE_MAX := 500

var W := 72
var H := 72
var theme := "temperate"
var layout := "plains"
var terrain := PackedByteArray()
var ore := PackedInt32Array()
var gem := PackedByteArray()
var tree_at := PackedByteArray()
var bridge := PackedByteArray()
var elev := PackedByteArray()      # 0 = 低地, 1 = 高地
var cliff := PackedByteArray()     # 1 = 懸崖邊緣（不可通行 / 不可建造）
const CL := 18.0                   # 高地在畫面上抬高的像素
var trees := []
var rocks := []
var starts := []
var oils := []
var civs := []
var decos := []
var deco_layer: Node2D
var ore_cells := {}
var rng := RandomNumberGenerator.new()
var ore_layer: Node2D
var water_layer: Node2D
var ore_dirty := true
var regrow_t := 0.0
var game

func idx(x: int, y: int) -> int:
	return y * W + x

func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

func passable(x: int, y: int) -> bool:
	if not inb(x, y):
		return false
	var i := idx(x, y)
	var t := terrain[i]
	return t != T_WATER and t != T_ROCK and tree_at[i] == 0 and cliff[i] == 0

func elev_at(p: Vector2) -> int:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if not inb(x, y):
		return 0
	return elev[idx(x, y)]

var vh := PackedFloat32Array()      # 頂點高度 0..1（坡道格子漸變）

func vtx_h(vx: int, vy: int) -> float:
	if vh.is_empty():
		return 0.0
	return vh[clampi(vy, 0, H) * (W + 1) + clampi(vx, 0, W)]

func height_at(p: Vector2) -> float:
	if vh.is_empty():
		return 0.0
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if not inb(x, y) or elev[idx(x, y)] == 0:
		return 0.0
	var fx := p.x - x
	var fy := p.y - y
	var h0 := vtx_h(x, y)
	var h1 := vtx_h(x + 1, y)
	var h2 := vtx_h(x + 1, y + 1)
	var h3 := vtx_h(x, y + 1)
	return lerpf(lerpf(h0, h1, fx), lerpf(h3, h2, fx), fy)

func elev_off(p: Vector2) -> Vector2:
	return Vector2(0, -CL * height_at(p))

func is_ramp(x: int, y: int) -> bool:
	var i := idx(x, y)
	if elev[i] == 0 or cliff[i] != 0:
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = Vector2i(x, y) + d
		if not inb(n.x, n.y) or elev[idx(n.x, n.y)] == 0:
			return true
	return false

func build_vh():
	vh.resize((W + 1) * (H + 1))
	vh.fill(0.0)
	# 格子分類：0 低地 1 高地 2 坡道
	var cls := PackedByteArray()
	cls.resize(W * H)
	for y in H:
		for x in W:
			var i := y * W + x
			if elev[i] == 0:
				cls[i] = 0
			else:
				cls[i] = 2 if is_ramp(x, y) else 1
	for vy in H + 1:
		for vx in W + 1:
			var high := false
			var low := false
			var ramp := false
			for yy in [vy - 1, vy]:
				for xx in [vx - 1, vx]:
					if xx < 0 or yy < 0 or xx >= W or yy >= H:
						low = true
					else:
						var c := cls[yy * W + xx]
						if c == 0:
							low = true
						elif c == 2:
							ramp = true
						else:
							high = true
			var h := 0.0
			if high:
				h = 1.0
			elif ramp and not low:
				h = 1.0
			vh[vy * (W + 1) + vx] = h

func buildable(x: int, y: int) -> bool:
	return passable(x, y)

# ───────────────────────── generation ─────────────────────────
func generate(p: Dictionary):
	W = int(p.get("size", 72))
	H = W
	theme = p.get("theme", "temperate")
	layout = p.get("layout", "plains")
	var nplayers: int = clampi(int(p.get("players", 2)), 2, 4)
	rng.seed = int(p.get("seed", 1))
	terrain.resize(W * H)
	terrain.fill(T_BASE)
	ore.resize(W * H)
	ore.fill(0)
	gem.resize(W * H)
	gem.fill(0)
	tree_at.resize(W * H)
	tree_at.fill(0)
	bridge.resize(W * H)
	bridge.fill(0)
	elev.resize(W * H)
	elev.fill(0)
	cliff.resize(W * H)
	cliff.fill(0)
	trees.clear()
	rocks.clear()
	starts.clear()
	oils.clear()
	civs.clear()
	decos.clear()
	ore_cells.clear()
	var hn := FastNoiseLite.new()
	hn.seed = rng.randi()
	hn.frequency = 0.045
	hn.fractal_octaves = 4
	var pn := FastNoiseLite.new()
	pn.seed = rng.randi()
	pn.frequency = 0.07
	var tn := FastNoiseLite.new()
	tn.seed = rng.randi()
	tn.frequency = 0.09
	var rn := FastNoiseLite.new()
	rn.seed = rng.randi()
	rn.frequency = 0.035
	var cx := W * 0.5
	var cy := H * 0.5
	for y in H:
		for x in W:
			var i := idx(x, y)
			var h := hn.get_noise_2d(x, y)
			var dc := Vector2(x - cx, y - cy).length() / (W * 0.5)
			match layout:
				"plains":
					if h < -0.5:
						terrain[i] = T_WATER
					elif h > 0.55:
						terrain[i] = T_ROCK
				"lake":
					var lim := 0.36 + h * 0.18
					if dc < lim:
						terrain[i] = T_WATER
					elif h < -0.52:
						terrain[i] = T_WATER
					elif h > 0.6:
						terrain[i] = T_ROCK
				"canyon":
					var r := absf(rn.get_noise_2d(x, y))
					if r < 0.075 and dc > 0.12:
						terrain[i] = T_ROCK
					elif h > 0.62:
						terrain[i] = T_ROCK
				"river":
					if h > 0.6:
						terrain[i] = T_ROCK
				"coast":
					var side := float(y - x) / W
					if side > 0.16 + h * 0.08 or side < -0.62 + h * 0.06:
						terrain[i] = T_WATER
					elif h > 0.62:
						terrain[i] = T_ROCK
				"strait":
					var u := float(x) / W
					var v := float(y) / H
					# 大陸海岸線（西側）
					var coast := 0.30 + h * 0.05 + sin(v * 9.0) * 0.02
					# 島嶼：葉形，中心 (0.70, 0.50)，南北長
					var iu := (u - 0.70) / 0.12
					var iv := (v - 0.50) / 0.34
					var lean := iu + iv * 0.35
					var island := lean * lean + iv * iv * (1.0 + 0.4 * absf(iv)) < 1.0 + h * 0.12
					# 澎湖群島
					var peng := Vector2(u - 0.50, v - 0.58).length() < 0.035 + h * 0.015 or Vector2(u - 0.47, v - 0.62).length() < 0.02
					if u > coast and not island and not peng:
						terrain[i] = T_WATER
					elif island and lean > 0.35 and absf(iv) < 0.8:
						terrain[i] = T_ROCK
					elif h > 0.66:
						terrain[i] = T_ROCK
				"gulf":
					var u := float(x) / W
					var v := float(y) / H
					# 海灣：從 (0.05,0.85) 到 (0.95,0.15) 的斜帶，寬度向東北收窄（荷莫茲海峽）
					var t := clampf(((u - 0.05) + (0.85 - v)) / 1.6, 0.0, 1.0)
					var dline := absf((u - 0.05) - (0.85 - v)) / sqrt(2.0)
					var wdt := 0.12 * (1.0 - t * 0.55) + h * 0.03
					if t > 0.82:
						wdt = 0.04 + h * 0.01
					if dline < wdt and t > 0.03:
						terrain[i] = T_WATER
					elif h > 0.6:
						terrain[i] = T_ROCK
			if terrain[i] == T_BASE:
				var pv := pn.get_noise_2d(x, y)
				if pv > 0.3:
					terrain[i] = T_DIRT
				elif pv < -0.45:
					terrain[i] = T_ALT
	if layout == "river":
		carve_river(hn)
	# shores
	if theme == "temperate" or theme == "tropical" or layout == "coast":
		var wm := dilate_mask(T_WATER, int(THEMES[theme].get("beach", 1)))
		for i in W * H:
			if wm[i] == 1 and terrain[i] != T_WATER and terrain[i] != T_ROCK and terrain[i] != T_ROAD:
				terrain[i] = T_ALT
	make_roads(hn)
	make_plateaus(hn)
	build_vh()
	# starts
	var m := 12
	var cand := [Vector2i(W - m, H - m), Vector2i(m - 1, m - 1), Vector2i(W - m, m - 1), Vector2i(m - 1, H - m)]
	if layout == "strait":
		cand = [Vector2i(int(W * 0.64), int(H * 0.52)), Vector2i(int(W * 0.14), int(H * 0.30)), Vector2i(int(W * 0.14), int(H * 0.72)), Vector2i(int(W * 0.70), int(H * 0.27))]
	elif layout == "gulf":
		cand = [Vector2i(int(W * 0.18), int(H * 0.22)), Vector2i(int(W * 0.80), int(H * 0.78)), Vector2i(int(W * 0.62), int(H * 0.15)), Vector2i(int(W * 0.30), int(H * 0.88))]
	for k in nplayers:
		starts.append(cand[k])
	for s in starts:
		clear_area(s, 9)
	# ore fields near each start
	var center := Vector2(cx, cy)
	for s in starts:
		var toc: Vector2 = (center - Vector2(s)).normalized()
		var angs := [-0.75, 0.75] if not (layout in ["strait", "gulf"]) else [-0.75, 0.75, 2.4, -2.4]
		for ang in angs:
			var fp := Vector2(s) + toc.rotated(ang) * rng.randf_range(7.5, 9.0)
			ore_blob(fp, rng.randf_range(2.6, 3.2), false)
	if layout in ["strait", "gulf"]:
		for k in 10:
			var q := Vector2(rng.randf_range(0.08, 0.92) * W, rng.randf_range(0.08, 0.92) * H)
			if inb(int(q.x), int(q.y)) and terrain[idx(int(q.x), int(q.y))] == T_BASE and not near_start(int(q.x), int(q.y), 14.0):
				ore_blob(q, rng.randf_range(2.4, 3.0), k % 3 == 0)
	# contested fields
	ore_blob(center, 2.8, true)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		ore_blob(center + Vector2(cos(a), sin(a)) * W * 0.24, 2.6, k % 2 == 0 and W >= 90)
	# 大地圖：依面積增加散布礦區與油井
	var extra := int(W * H / 12000.0) - 1
	if extra > 0 and not (layout in ["strait", "gulf"]):
		for k in extra * 3:
			var q := Vector2(rng.randf_range(0.08, 0.92) * W, rng.randf_range(0.08, 0.92) * H)
			if inb(int(q.x), int(q.y)) and terrain[idx(int(q.x), int(q.y))] != T_WATER and not near_start(int(q.x), int(q.y), 16.0):
				ore_blob(q, rng.randf_range(2.4, 3.1), k % 3 == 0)
	# oil derricks
	var oil_spots := [center + Vector2(-W * 0.14, W * 0.14), center + Vector2(W * 0.14, -W * 0.14)]
	if nplayers > 2 or W >= 90:
		oil_spots.append(center + Vector2(W * 0.14, W * 0.14))
		oil_spots.append(center + Vector2(-W * 0.14, -W * 0.14))
	if extra > 0 and not (layout in ["strait", "gulf"]):
		for k in extra * 4:
			var q := Vector2(rng.randf_range(0.1, 0.9) * W, rng.randf_range(0.1, 0.9) * H)
			var okq := inb(int(q.x), int(q.y)) and terrain[idx(int(q.x), int(q.y))] in [T_BASE, T_DIRT, T_ALT] and not near_start(int(q.x), int(q.y), 18.0)
			for sp in oil_spots:
				if sp.distance_to(q) < 20.0:
					okq = false
			if okq:
				oil_spots.append(q)
				if oil_spots.size() >= 4 + extra * 2:
					break
	if layout == "gulf":
		oil_spots = []
		for q in [Vector2(0.12, 0.62), Vector2(0.30, 0.40), Vector2(0.48, 0.30), Vector2(0.36, 0.72), Vector2(0.58, 0.60), Vector2(0.74, 0.46), Vector2(0.80, 0.22), Vector2(0.55, 0.85)]:
			oil_spots.append(Vector2(q.x * W, q.y * H))
	elif layout == "strait":
		oil_spots = []
		for q in [Vector2(0.20, 0.50), Vector2(0.10, 0.12), Vector2(0.10, 0.90), Vector2(0.66, 0.30), Vector2(0.66, 0.70), Vector2(0.50, 0.58)]:
			oil_spots.append(Vector2(q.x * W, q.y * H))
	for sp in oil_spots:
		var c := Vector2i(int(sp.x), int(sp.y))
		clear_area(c + Vector2i(1, 1), 2.2)
		for yy in range(c.y - 1, c.y + 3):
			for xx in range(c.x - 1, c.x + 3):
				if inb(xx, yy):
					ore[idx(xx, yy)] = 0
		oils.append(c)
	make_towns()
	# trees
	var th: Dictionary = THEMES[theme]
	var tlist: Array = th.trees
	var block := circle_mask(starts, 10.5)
	var oilm := circle_mask(oils, 3.0, Vector2(1, 1))
	for c in civs:
		var tl: Vector2i = c[1]
		var sz: Vector2i = Defs.BUILDINGS[c[0]].size
		for yy in range(maxi(0, tl.y - 1), mini(H - 1, tl.y + sz.y) + 1):
			for xx in range(maxi(0, tl.x - 1), mini(W - 1, tl.x + sz.x) + 1):
				block[yy * W + xx] = 1
	var tdens := float(th.tree_density)
	for y in H:
		for x in W:
			var i := idx(x, y)
			if terrain[i] == T_WATER or terrain[i] == T_ROCK or terrain[i] == T_ROAD or ore[i] > 0 or block[i] == 1 or oilm[i] == 1:
				continue
			var beach_palm: bool = theme == "tropical" and terrain[i] == T_ALT and rng.randf() < 0.14
			if beach_palm or (tn.get_noise_2d(x, y) > 0.28 and rng.randf() < tdens):
				tree_at[i] = 1
				var tt: Array = tlist[rng.randi() % tlist.size()]
				if beach_palm:
					tt = ["palm", rng.randi() % 6]
				trees.append([Vector2i(x, y), tt[1], tt[0]])
	# boulders on rock
	for y in H:
		for x in W:
			if terrain[idx(x, y)] == T_ROCK:
				var inner := near_type(x, y, T_ROCK, 1) and not (near_type(x, y, T_BASE, 1) or near_type(x, y, T_DIRT, 1))
				rocks.append([Vector2i(x, y), rng.randi() % 5 if inner or rng.randf() < 0.6 else 5 + rng.randi() % 3])
	ensure_connectivity()
	# ground decoration
	var dl: Array = th.deco
	for k in int(W * H * 0.07):
		var x := rng.randi() % W
		var y := rng.randi() % H
		var i := idx(x, y)
		if terrain[i] == T_WATER or terrain[i] == T_ROCK or terrain[i] == T_ROAD or tree_at[i] != 0 or ore[i] > 0 or civ_at(x, y):
			continue
		decos.append([Vector2(x + rng.randf_range(0.15, 0.85), y + rng.randf_range(0.15, 0.85)), dl[rng.randi() % dl.size()]])
	for i in W * H:
		if ore[i] > 0:
			ore_cells[i] = true

func make_plateaus(_hn: FastNoiseLite):
	if layout in ["strait", "gulf", "coast"]:
		return
	var en := FastNoiseLite.new()
	en.seed = rng.randi()
	en.frequency = 0.028
	en.fractal_octaves = 3
	var cx := W * 0.5
	var cy := H * 0.5
	var wm := dilate_mask(T_WATER, 2)
	for y in H:
		for x in W:
			var i := idx(x, y)
			var t := terrain[i]
			if t == T_WATER or t == T_ROCK or wm[i] == 1:
				continue
			if en.get_noise_2d(x, y) > 0.3 and Vector2(x, y).distance_to(Vector2(cx, cy)) >= 7.0:
				elev[i] = 1
	# 出生點附近保持低地
	var m := 12
	for s in [Vector2i(W - m, H - m), Vector2i(m - 1, m - 1), Vector2i(W - m, m - 1), Vector2i(m - 1, H - m)]:
		for yy in range(s.y - 11, s.y + 12):
			for xx in range(s.x - 11, s.x + 12):
				if inb(xx, yy) and Vector2(xx, yy).distance_to(Vector2(s)) < 11.0:
					elev[idx(xx, yy)] = 0
	# 移除太小的高地、填平高地內的小洞
	var seen := PackedByteArray()
	seen.resize(W * H)
	for y in H:
		for x in W:
			var i0 := idx(x, y)
			if elev[i0] == 0 or seen[i0] != 0:
				continue
			var q := [Vector2i(x, y)]
			seen[i0] = 1
			var head := 0
			while head < q.size():
				var c: Vector2i = q[head]
				head += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if inb(n.x, n.y):
						var j := idx(n.x, n.y)
						if elev[j] == 1 and seen[j] == 0:
							seen[j] = 1
							q.append(n)
			if q.size() < 40:
				for c in q:
					elev[idx(c.x, c.y)] = 0
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var i := idx(x, y)
			if elev[i] == 0 and elev[idx(x + 1, y)] == 1 and elev[idx(x - 1, y)] == 1 and elev[idx(x, y + 1)] == 1 and elev[idx(x, y - 1)] == 1:
				elev[i] = 1
	# 懸崖邊緣 = 高地上與低地相鄰的格子（道路經過處變成坡道）
	for y in H:
		for x in W:
			var i := idx(x, y)
			if elev[i] == 0:
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if not inb(n.x, n.y) or elev[idx(n.x, n.y)] == 0:
					edge = true
			if edge:
				cliff[i] = 1
				if terrain[i] == T_ROAD:
					cliff[i] = 0
				tree_at[i] = 0
				ore[i] = 0
	# 每塊高地至少 2 條坡道
	seen.fill(0)
	for y in H:
		for x in W:
			var i0 := idx(x, y)
			if elev[i0] == 0 or seen[i0] != 0:
				continue
			var q := [Vector2i(x, y)]
			var edges := []
			seen[i0] = 1
			var head := 0
			while head < q.size():
				var c: Vector2i = q[head]
				head += 1
				if cliff[idx(c.x, c.y)] == 1:
					edges.append(c)
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if inb(n.x, n.y):
						var j := idx(n.x, n.y)
						if elev[j] == 1 and seen[j] == 0:
							seen[j] = 1
							q.append(n)
			if edges.is_empty():
				continue
			var nramp := 2 + int(q.size() / 200)
			var picked := []
			for k in nramp * 6:
				var e: Vector2i = edges[rng.randi() % edges.size()]
				var ok := true
				for pk in picked:
					if Vector2(pk).distance_to(Vector2(e)) < 10.0:
						ok = false
				if ok:
					picked.append(e)
				if picked.size() >= nramp:
					break
			for e in picked:
				for yy in range(e.y - 1, e.y + 2):
					for xx in range(e.x - 1, e.x + 2):
						if inb(xx, yy):
							var j := idx(xx, yy)
							cliff[j] = 0
							if terrain[j] == T_WATER or terrain[j] == T_ROCK:
								terrain[j] = T_DIRT
							tree_at[j] = 0
	# 清掉懸崖上的樹
	var nt := []
	for t in trees:
		if cliff[idx(t[0].x, t[0].y)] == 0:
			nt.append(t)
	trees = nt

func make_roads(hn: FastNoiseLite):
	# two roads crossing the map
	for dir in 2:
		var off := rng.randf_range(-0.12, 0.12) * W
		for k in W * 4:
			var t := float(k) / (W * 4)
			var along := t * W
			var side := W * 0.5 + off + sin(t * TAU * 1.3 + dir) * W * 0.06
			var c := Vector2(along, side) if dir == 0 else Vector2(side, along)
			for yy in range(int(c.y) - 1, int(c.y) + 2):
				for xx in range(int(c.x) - 1, int(c.x) + 2):
					if not inb(xx, yy):
						continue
					if Vector2(xx + 0.5, yy + 0.5).distance_to(c) <= 1.15:
						if terrain[idx(xx, yy)] == T_WATER:
							if layout in ["strait", "gulf"]:
								continue
							bridge[idx(xx, yy)] = 1
						terrain[idx(xx, yy)] = T_ROAD

func civ_at(x: int, y: int) -> bool:
	for c in civs:
		var tl: Vector2i = c[1]
		var sz: Vector2i = Defs.BUILDINGS[c[0]].size
		if x >= tl.x - 1 and y >= tl.y - 1 and x <= tl.x + sz.x and y <= tl.y + sz.y:
			return true
	return false

func make_towns():
	var road_cells := []
	for y in H:
		for x in W:
			if terrain[idx(x, y)] == T_ROAD:
				road_cells.append(Vector2i(x, y))
	if road_cells.is_empty():
		return
	var ntown := 3 + int(W / 32)
	for t in ntown:
		var rc: Vector2i = road_cells[rng.randi() % road_cells.size()]
		if near_start(rc.x, rc.y, 15.0) or near_oil(rc.x, rc.y):
			continue
		var placed := 0
		for attempt in 40:
			if placed >= rng.randi_range(3, 5):
				break
			var id: String = CIVS[rng.randi() % CIVS.size()]
			var sz: Vector2i = Defs.BUILDINGS[id].size
			var tl := rc + Vector2i(rng.randi_range(-5, 4), rng.randi_range(-5, 4))
			var ok := true
			for yy in range(tl.y - 1, tl.y + sz.y + 1):
				for xx in range(tl.x - 1, tl.x + sz.x + 1):
					if not inb(xx, yy):
						ok = false
						continue
					var inside := xx >= tl.x and yy >= tl.y and xx < tl.x + sz.x and yy < tl.y + sz.y
					var tt := terrain[idx(xx, yy)]
					if inside and (tt == T_WATER or tt == T_ROCK or tt == T_ROAD or ore[idx(xx, yy)] > 0):
						ok = false
			if not ok or civ_at(tl.x, tl.y) or civ_at(tl.x + sz.x - 1, tl.y + sz.y - 1) or near_start(tl.x, tl.y, 13.0) or near_oil(tl.x, tl.y):
				continue
			civs.append([id, tl, rng.randi() % 2])
			placed += 1

func carve_river(hn: FastNoiseLite):
	var L := int(W * 1.45)
	var fords := [0.3, 0.5, 0.7]
	for k in L:
		var t := float(k) / L
		var base := Vector2(t * W, H - t * H)
		var perp := Vector2(1, 1).normalized()
		var off := sin(t * TAU * 1.5 + 0.7) * W * 0.07 + hn.get_noise_1d(t * 60.0) * 3.0
		var c := base + perp * off
		var wdt := 2.2 + hn.get_noise_1d(t * 40.0 + 9.0) * 0.8
		var is_ford := false
		for f in fords:
			if absf(t - f) < 0.025:
				is_ford = true
		for yy in range(int(c.y - 5), int(c.y + 6)):
			for xx in range(int(c.x - 5), int(c.x + 6)):
				if not inb(xx, yy):
					continue
				var d := Vector2(xx + 0.5, yy + 0.5).distance_to(c)
				if d < wdt:
					terrain[idx(xx, yy)] = T_DIRT if is_ford else T_WATER
				elif d < wdt + 1.2 and terrain[idx(xx, yy)] != T_WATER:
					if is_ford:
						terrain[idx(xx, yy)] = T_DIRT

# 回傳遮罩：與 terrain==t 的格子距離（切比雪夫）<= r 的格子為 1（分離式膨脹，O(W*H*r)）
func dilate_mask(t: int, r: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(W * H)
	a.fill(0)
	var b := PackedByteArray()
	b.resize(W * H)
	b.fill(0)
	for y in H:
		var row := y * W
		for x in W:
			if terrain[row + x] == t:
				for xx in range(maxi(0, x - r), mini(W - 1, x + r) + 1):
					a[row + xx] = 1
	for y in H:
		for x in W:
			if a[y * W + x] == 1:
				for yy in range(maxi(0, y - r), mini(H - 1, y + r) + 1):
					b[yy * W + x] = 1
	return b

func circle_mask(centers: Array, r: float, off := Vector2.ZERO) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(W * H)
	m.fill(0)
	var r2 := r * r
	for c in centers:
		var cv := Vector2(c) + off
		for yy in range(maxi(0, int(cv.y - r)), mini(H - 1, int(cv.y + r) + 1) + 1):
			for xx in range(maxi(0, int(cv.x - r)), mini(W - 1, int(cv.x + r) + 1) + 1):
				if Vector2(xx, yy).distance_squared_to(cv) < r2:
					m[yy * W + xx] = 1
	return m

func near_type(x: int, y: int, t: int, r: int) -> bool:
	for yy in range(y - r, y + r + 1):
		for xx in range(x - r, x + r + 1):
			if inb(xx, yy) and terrain[idx(xx, yy)] == t:
				return true
	return false

func near_start(x: int, y: int, r: float) -> bool:
	for s in starts:
		if Vector2(x, y).distance_to(Vector2(s)) < r:
			return true
	return false

func near_oil(x: int, y: int) -> bool:
	for o in oils:
		if Vector2(x, y).distance_to(Vector2(o) + Vector2(1, 1)) < 3.0:
			return true
	return false

func clear_area(c: Vector2i, r: float):
	for yy in range(int(c.y - r - 1), int(c.y + r + 2)):
		for xx in range(int(c.x - r - 1), int(c.x + r + 2)):
			if inb(xx, yy) and Vector2(xx, yy).distance_to(Vector2(c)) <= r:
				var i := idx(xx, yy)
				if terrain[i] == T_WATER or terrain[i] == T_ROCK:
					terrain[i] = T_BASE if theme != "temperate" else T_BASE
				tree_at[i] = 0
				cliff[i] = 0

func ore_blob(c: Vector2, r: float, is_gem: bool):
	for yy in range(int(c.y - r - 1), int(c.y + r + 2)):
		for xx in range(int(c.x - r - 1), int(c.x + r + 2)):
			if not inb(xx, yy):
				continue
			var d := Vector2(xx + 0.5, yy + 0.5).distance_to(c)
			var jitter := rng.randf_range(-0.6, 0.6)
			if d + jitter < r:
				var i := idx(xx, yy)
				if terrain[i] == T_WATER or terrain[i] == T_ROCK or terrain[i] == T_ROAD:
					continue
				if near_start(xx, yy, 4.5):
					continue
				tree_at[i] = 0
				ore[i] = int(clampf(ORE_MAX * (1.1 - d / r * 0.7) * rng.randf_range(0.7, 1.0), 120, ORE_MAX))
				gem[i] = 1 if is_gem else 0

func ensure_connectivity():
	if layout == "strait":
		# 海峽地圖：刻意不連通（需要海軍 / 空軍跨海）
		return
	var targets := []
	for k in range(1, starts.size()):
		targets.append(starts[k])
	for o in oils:
		targets.append(o + Vector2i(-1, 0))
	# 一次洪水填充檢查全部目標，只在有需要時重算
	var seen := flood(starts[0])
	for t in targets:
		if seen[idx(t.x, t.y)] == 0:
			carve_line(starts[0], t)
			seen = flood(starts[0])

func flood(a: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(W * H)
	var q := PackedInt32Array()
	q.append(idx(a.x, a.y))
	seen[idx(a.x, a.y)] = 1
	var head := 0
	var WW := W
	while head < q.size():
		var c := q[head]
		head += 1
		var x := c % WW
		var y := c / WW
		if x + 1 < WW and seen[c + 1] == 0 and passable(x + 1, y):
			seen[c + 1] = 1
			q.append(c + 1)
		if x > 0 and seen[c - 1] == 0 and passable(x - 1, y):
			seen[c - 1] = 1
			q.append(c - 1)
		if y + 1 < H and seen[c + WW] == 0 and passable(x, y + 1):
			seen[c + WW] = 1
			q.append(c + WW)
		if y > 0 and seen[c - WW] == 0 and passable(x, y - 1):
			seen[c - WW] = 1
			q.append(c - WW)
	return seen

func reachable(a: Vector2i, b: Vector2i) -> bool:
	var seen := flood(a)
	return seen[idx(b.x, b.y)] != 0

func carve_line(a: Vector2i, b: Vector2i):
	var steps := int(Vector2(a).distance_to(Vector2(b)) * 2) + 1
	for k in steps + 1:
		var p := Vector2(a).lerp(Vector2(b), float(k) / steps)
		for yy in range(int(p.y) - 1, int(p.y) + 2):
			for xx in range(int(p.x) - 1, int(p.x) + 2):
				if inb(xx, yy):
					var i := idx(xx, yy)
					if terrain[i] == T_WATER or terrain[i] == T_ROCK:
						terrain[i] = T_DIRT
					if tree_at[i] != 0:
						tree_at[i] = 0
					cliff[i] = 0
	var nt := []
	for t in trees:
		if tree_at[idx(t[0].x, t[0].y)] != 0:
			nt.append(t)
	trees = nt
	var nr := []
	for r in rocks:
		if terrain[idx(r[0].x, r[0].y)] == T_ROCK:
			nr.append(r)
	rocks = nr

# ───────────────────────── preview / minimap ─────────────────────────
func base_color(i: int) -> Color:
	var th: Dictionary = THEMES[theme]
	var c: Color = th.mini[terrain[i]]
	if elev[i] == 1:
		c = c.lightened(0.18)
	if cliff[i] == 1:
		c = Color(0.45, 0.38, 0.3)
	if tree_at[i] != 0:
		c = Color(0.12, 0.25, 0.1) if theme != "snow" else Color(0.2, 0.32, 0.25)
	if ore[i] > 0:
		c = Color(0.9, 0.7, 0.15) if gem[i] == 0 else Color(0.7, 0.35, 0.9)
	return c

func make_preview(show_starts := true) -> Image:
	var th: Dictionary = THEMES[theme]
	var mini_c: Array = th.mini
	var data := PackedByteArray()
	data.resize(W * H * 4)
	var ore_c := Color(0.9, 0.7, 0.15)
	var gem_c := Color(0.7, 0.35, 0.9)
	var tree_c := Color(0.12, 0.25, 0.1) if theme != "snow" else Color(0.2, 0.32, 0.25)
	var cliff_c := Color(0.45, 0.38, 0.3)
	var hi_c: Array = []
	for k in mini_c.size():
		hi_c.append((mini_c[k] as Color).lightened(0.18))
	for i in W * H:
		var c: Color
		if ore[i] > 0:
			c = ore_c if gem[i] == 0 else gem_c
		elif tree_at[i] != 0:
			c = tree_c
		elif cliff[i] == 1:
			c = cliff_c
		elif elev[i] == 1:
			c = hi_c[terrain[i]]
		else:
			c = mini_c[terrain[i]]
		var o := i * 4
		data[o] = int(c.r * 255.0)
		data[o + 1] = int(c.g * 255.0)
		data[o + 2] = int(c.b * 255.0)
		data[o + 3] = 255
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data)
	if show_starts:
		for k in starts.size():
			var s: Vector2i = starts[k]
			for yy in range(s.y - 2, s.y + 3):
				for xx in range(s.x - 2, s.x + 3):
					if inb(xx, yy):
						img.set_pixel(xx, yy, Color(1, 1, 1) if k == 0 else Color(1, 0.3, 0.2))
	for o in oils:
		img.set_pixel(o.x, o.y, Color(0.1, 0.1, 0.1))
	return img

# ───────────────────────── rendering ─────────────────────────
func build_visuals(g):
	game = g
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -20
	water_layer = Node2D.new()
	water_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	water_layer.z_index = -19
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec2 uv = UV + vec2(TIME * 0.012, TIME * 0.007) + 0.012 * vec2(sin(UV.y * 12.0 + TIME * 1.3), cos(UV.x * 10.0 + TIME));
	vec4 c = texture(TEXTURE, uv);
	float s = 0.5 + 0.5 * sin((UV.x + UV.y) * 18.0 + TIME * 2.0);
	c.rgb += vec3(0.03, 0.05, 0.06) * s;
	c.rgb *= tint;
	COLOR = vec4(c.rgb, COLOR.a);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var wt: Color = THEMES[theme].get("water_tint", Color(1, 1, 1))
	mat.set_shader_parameter("tint", Vector3(wt.r, wt.g, wt.b))
	water_layer.material = mat
	water_layer.draw.connect(_draw_water)
	get_parent().add_child.call_deferred(water_layer)
	deco_layer = Node2D.new()
	deco_layer.z_index = -18
	deco_layer.draw.connect(_draw_deco)
	get_parent().add_child.call_deferred(deco_layer)
	ore_layer = Node2D.new()
	ore_layer.z_index = -18
	ore_layer.draw.connect(_draw_ore)
	get_parent().add_child.call_deferred(ore_layer)
	build_chunks()
	queue_redraw()

func vtx_weight(layer: int, vx: int, vy: int, noise_amt := 0.0) -> float:
	var n := 0
	var tot := 0
	for yy in [vy - 1, vy]:
		for xx in [vx - 1, vx]:
			var x2 := clampi(xx, 0, W - 1)
			var y2 := clampi(yy, 0, H - 1)
			tot += 1
			var ii := idx(x2, y2)
			if bridge[ii] != 0:
				if layer == T_WATER:
					n += 1
			elif terrain[ii] == layer:
				n += 1
	var w := float(n) / tot
	if noise_amt > 0.0 and w > 0.0 and w < 1.0:
		var h := sin(vx * 12.9898 + vy * 78.233) * 43758.5453
		h = h - floor(h)
		w = clampf(w + (h - 0.5) * noise_amt, 0.0, 1.0)
	return w

func _uv(p: Vector2, scale := 0.25) -> Vector2:
	return p * scale

func _draw():
	var th: Dictionary = THEMES[theme]
	var base_t := G.tex(th.base)
	# base fills whole map (single quad)
	var corners := [Vector2(0, 0), Vector2(W, 0), Vector2(W, H), Vector2(0, H)]
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for c in corners:
		pts.append(G.iso(c))
		uvs.append(_uv(c))
	draw_polygon(pts, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, base_t)
	# darker rim for the map edge
	var rim := Color(0, 0, 0, 0.5)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), rim, 3.0)

func draw_plateaus(base_t: Texture2D, rock_t: Texture2D, node: CanvasItem = null, r: Rect2i = Rect2i(0, 0, 0, 0)):
	if node == null:
		node = self
	if r.size.x == 0:
		r = Rect2i(0, 0, W, H)
	var face_c := Color(0.62, 0.55, 0.47)
	var face_d := Color(0.42, 0.37, 0.32)
	# 由北到南畫，讓南側的崖面蓋住後面的格子
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := idx(x, y)
			if elev[i] == 0:
				continue
			var c := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var hv := [vtx_h(x, y), vtx_h(x + 1, y), vtx_h(x + 1, y + 1), vtx_h(x, y + 1)]
			var top := []
			for k in 4:
				top.append(G.iso(c[k]) + Vector2(0, -CL * hv[k]))
			# 崖面：東側 (x+1) 與南側 (y+1) 若是低地
			var east_low := not inb(x + 1, y) or elev[idx(x + 1, y)] == 0
			var south_low := not inb(x, y + 1) or elev[idx(x, y + 1)] == 0
			if east_low and hv[1] + hv[2] > 0.01:
				var fp := PackedVector2Array([top[1], top[2], G.iso(c[2]), G.iso(c[1])])
				var fu := PackedVector2Array([Vector2(x * 0.3, 0), Vector2(x * 0.3 + 0.3, 0), Vector2(x * 0.3 + 0.3, 0.25), Vector2(x * 0.3, 0.25)])
				node.draw_polygon(fp, PackedColorArray([face_d, face_d, face_d, face_d]), fu, rock_t)
			if south_low and hv[2] + hv[3] > 0.01:
				var fp := PackedVector2Array([top[2], top[3], G.iso(c[3]), G.iso(c[2])])
				var fu := PackedVector2Array([Vector2(y * 0.3, 0.3), Vector2(y * 0.3 + 0.3, 0.3), Vector2(y * 0.3 + 0.3, 0.55), Vector2(y * 0.3, 0.55)])
				node.draw_polygon(fp, PackedColorArray([face_c, face_c, face_c, face_c]), fu, rock_t)
			# 高地頂面
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for k in 4:
				pts.append(top[k])
				uvs.append(_uv(c[k]))
			var ramp := is_ramp(x, y)
			var tint := Color(1.06, 1.05, 1.0) if cliff[i] == 0 else Color(0.9, 0.86, 0.8)
			if ramp:
				tint = Color(0.98, 0.95, 0.88)
			node.draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs, base_t)
			# 崖頂邊緣線
			if east_low and hv[1] + hv[2] > 0.01:
				node.draw_line(top[1], top[2], Color(0.25, 0.2, 0.15, 0.6), 1.5)
			if south_low and hv[2] + hv[3] > 0.01:
				node.draw_line(top[2], top[3], Color(0.25, 0.2, 0.15, 0.6), 1.5)
			var north_low := not inb(x, y - 1) or elev[idx(x, y - 1)] == 0
			var west_low := not inb(x - 1, y) or elev[idx(x - 1, y)] == 0
			if north_low and hv[0] + hv[1] > 0.01:
				node.draw_line(top[0], top[1], Color(1, 1, 0.9, 0.35), 1.0)
			if west_low and hv[0] + hv[3] > 0.01:
				node.draw_line(top[0], top[3], Color(1, 1, 0.9, 0.35), 1.0)

const CH := 24                      # 地形分塊大小（格），分塊可被鏡頭剔除
var wts_cache := {}
var chunks: Array = []
var water_chunks: Array = []

func layer_weights(layer: int, noise_amt: float) -> PackedFloat32Array:
	if wts_cache.has(layer):
		return wts_cache[layer]
	var wts := PackedFloat32Array()
	wts.resize((W + 1) * (H + 1))
	for vy in H + 1:
		for vx in W + 1:
			wts[vy * (W + 1) + vx] = vtx_weight(layer, vx, vy, noise_amt)
	wts_cache[layer] = wts
	return wts

func draw_layer(layer: int, t: Texture2D, noise_amt: float, node: CanvasItem = null, r: Rect2i = Rect2i(0, 0, 0, 0), raised := true):
	if node == null:
		node = self
	if r.size.x == 0:
		r = Rect2i(0, 0, W, H)
	var wts := layer_weights(layer, noise_amt)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var w0 := wts[y * (W + 1) + x]
			var w1 := wts[y * (W + 1) + x + 1]
			var w2 := wts[(y + 1) * (W + 1) + x + 1]
			var w3 := wts[(y + 1) * (W + 1) + x]
			if w0 + w1 + w2 + w3 <= 0.001:
				continue
			var c := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var hi: bool = raised and elev[y * W + x] == 1
			for v in c:
				var off := Vector2(0, -CL * vtx_h(int(v.x), int(v.y))) if hi else Vector2.ZERO
				pts.append(G.iso(v) + off)
				uvs.append(_uv(v))
			var cols := PackedColorArray([Color(1, 1, 1, sm(w0)), Color(1, 1, 1, sm(w1)), Color(1, 1, 1, sm(w2)), Color(1, 1, 1, sm(w3))])
			node.draw_polygon(pts, cols, uvs, t)

func chunk_rect(k: int) -> Rect2i:
	var nx := int(ceil(W / float(CH)))
	var cx := (k % nx) * CH
	var cy := (k / nx) * CH
	return Rect2i(cx, cy, mini(CH, W - cx), mini(CH, H - cy))

var chunk_ready := PackedByteArray()

# 只有鏡頭附近的分塊才真正產生繪圖指令（大地圖開局不用一次畫完全圖）
func activate_chunks():
	if game == null or game.cam == null:
		return
	var vs: Vector2 = game.get_viewport_rect().size / game.zoom
	var c: Vector2 = game.cam.position
	var corners := [c - vs * 0.5, c + Vector2(vs.x, -vs.y) * 0.5, c + vs * 0.5, c + Vector2(-vs.x, vs.y) * 0.5]
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for sc in corners:
		var w := G.uniso(sc)
		lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
		hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	var nx := int(ceil(W / float(CH)))
	var x0 := clampi(int(lo.x - 4) / CH, 0, nx - 1)
	var x1 := clampi(int(hi.x + 4) / CH, 0, nx - 1)
	var ny := int(ceil(H / float(CH)))
	var y0 := clampi(int(lo.y - 4) / CH, 0, ny - 1)
	var y1 := clampi(int(hi.y + 4) / CH, 0, ny - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var k := cy * nx + cx
			if chunk_ready[k] == 0:
				chunk_ready[k] = 1
				chunks[k].queue_redraw()
				water_chunks[k].queue_redraw()

func _draw_chunk(node: CanvasItem, k: int):
	if chunk_ready[k] == 0:
		return
	var th: Dictionary = THEMES[theme]
	var r := chunk_rect(k)
	draw_plateaus(G.tex(th.base), G.tex(th.rock), node, r)
	draw_layer(T_ALT, G.tex(th.alt), 0.5, node, r)
	draw_layer(T_DIRT, G.tex(th.dirt), 0.5, node, r)
	draw_layer(T_ROAD, G.tex("road"), 0.15, node, r)
	draw_layer(T_ROCK, G.tex(th.rock), 0.35, node, r)

func _draw_water_chunk(node: CanvasItem, k: int):
	if chunk_ready[k] == 0:
		return
	var th: Dictionary = THEMES[theme]
	var r := chunk_rect(k)
	draw_layer(T_WATER, G.tex(th.water), 0.3, node, r, false)
	# foam along shores
	var foam := G.tex("foam")
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if terrain[idx(x, y)] != T_WATER:
				continue
			if not (near_type(x, y, T_BASE, 1) or near_type(x, y, T_DIRT, 1) or near_type(x, y, T_ALT, 1)):
				continue
			var c := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for v in c:
				pts.append(G.iso(v))
				uvs.append(v * 0.5)
			var a := 0.22
			node.draw_polygon(pts, PackedColorArray([Color(1, 1, 1, a), Color(1, 1, 1, a), Color(1, 1, 1, a), Color(1, 1, 1, a)]), uvs, foam)

func build_chunks():
	for c in chunks:
		c.queue_free()
	for c in water_chunks:
		c.queue_free()
	chunks.clear()
	water_chunks.clear()
	wts_cache.clear()
	var nx := int(ceil(W / float(CH)))
	var ny := int(ceil(H / float(CH)))
	chunk_ready.resize(nx * ny)
	chunk_ready.fill(0)
	for k in nx * ny:
		var n := Node2D.new()
		n.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var kk: int = k
		n.draw.connect(func(): _draw_chunk(n, kk))
		add_child(n)
		chunks.append(n)
		var wn := Node2D.new()
		wn.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		wn.use_parent_material = true
		wn.draw.connect(func(): _draw_water_chunk(wn, kk))
		water_layer.add_child(wn)
		water_chunks.append(wn)

func sm(w: float) -> float:
	return clampf(w * w * (3.0 - 2.0 * w) * 1.15, 0.0, 1.0)

func _draw_water():
	pass

func _draw_bridges():
	var deck := G.tex("pave")
	var dcol := Color(1.05, 1.02, 0.96)
	for y in H:
		for x in W:
			if bridge[idx(x, y)] == 0:
				continue
			var c := [Vector2(x, y), Vector2(x + 1, y), Vector2(x + 1, y + 1), Vector2(x, y + 1)]
			var pts := PackedVector2Array()
			var sh_pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			for v in c:
				pts.append(G.iso(v) + Vector2(0, -6))
				sh_pts.append(G.iso(v) + Vector2(10, 12))
				uvs.append(v * 0.5)
			deco_layer.draw_colored_polygon(sh_pts, Color(0, 0.02, 0.06, 0.35))
			# 橋面側邊厚度（朝鏡頭的兩側）
			var sides := [[1, 2, Vector2i(1, 0)], [2, 3, Vector2i(0, 1)]]
			for sd in sides:
				var n: Vector2i = Vector2i(x, y) + sd[2]
				if inb(n.x, n.y) and bridge[idx(n.x, n.y)] != 0:
					continue
				var a: Vector2 = pts[sd[0]]
				var b: Vector2 = pts[sd[1]]
				deco_layer.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 9), a + Vector2(0, 9)]), Color(0.36, 0.34, 0.31))
			deco_layer.draw_polygon(pts, PackedColorArray([dcol, dcol, dcol, dcol]), uvs, deck)
			deco_layer.draw_line(pts[0], pts[1], Color(0, 0, 0, 0.12), 1.0)
			deco_layer.draw_line(pts[3], pts[0], Color(0, 0, 0, 0.12), 1.0)
			# 欄杆
			var edges := [[0, 1, Vector2i(0, -1)], [1, 2, Vector2i(1, 0)], [2, 3, Vector2i(0, 1)], [3, 0, Vector2i(-1, 0)]]
			for e in edges:
				var n: Vector2i = Vector2i(x, y) + e[2]
				if not inb(n.x, n.y) or bridge[idx(n.x, n.y)] != 0 or terrain[idx(n.x, n.y)] != T_WATER:
					continue
				var a: Vector2 = pts[e[0]]
				var b: Vector2 = pts[e[1]]
				deco_layer.draw_line(a + Vector2(0, -4), b + Vector2(0, -4), Color(0.25, 0.24, 0.22), 2.5)
				deco_layer.draw_line(a + Vector2(0, -5), b + Vector2(0, -5), Color(0.85, 0.82, 0.74), 1.0)
				for k in 5:
					var q := a.lerp(b, (k + 0.5) / 5.0)
					deco_layer.draw_line(q, q + Vector2(0, -4), Color(0.3, 0.29, 0.27), 1.5)

func _draw_deco():
	_draw_bridges()
	var sh = G.sheet("deco")
	if sh == null:
		return
	for d in decos:
		sh.draw(deco_layer, d[1], G.iso(d[0]), Color.WHITE)

func _draw_ore():
	var og = G.sheet("ore")
	var gg = G.sheet("gem")
	var vis_check: bool = game != null and game.human != null
	for i in ore_cells.keys():
		var amt := ore[i]
		if amt <= 0:
			continue
		var x = i % W
		var y = i / W
		if vis_check and not game.is_explored(x, y):
			continue
		var lvl := 0
		if amt > ORE_MAX * 0.66:
			lvl = 2
		elif amt > ORE_MAX * 0.33:
			lvl = 1
		var v = (x * 7 + y * 13) % 3
		var sh = gg if gem[i] == 1 else og
		if sh:
			sh.draw(ore_layer, lvl * 3 + v, G.iso(Vector2(x + 0.5, y + 0.5)), Color.WHITE)

func update(dt: float):
	regrow_t += dt
	if regrow_t > 6.0:
		regrow_t = 0.0
		var add := []
		for i in ore_cells.keys():
			if ore[i] > 0 and ore[i] < ORE_MAX:
				ore[i] = mini(ORE_MAX, ore[i] + 12)
				ore_dirty = true
			if ore[i] > ORE_MAX * 0.8 and rng.randf() < 0.02:
				var x = i % W + rng.randi_range(-1, 1)
				var y = i / W + rng.randi_range(-1, 1)
				if inb(x, y):
					var j := idx(x, y)
					if ore[j] == 0 and passable(x, y) and game.bld_at(x, y) == null:
						ore[j] = 60
						gem[j] = gem[i]
						add.append(j)
		for j in add:
			ore_cells[j] = true
	if ore_dirty:
		ore_dirty = false
		ore_layer.queue_redraw()

func take_ore(x: int, y: int, amt: int) -> int:
	var i := idx(x, y)
	var got := mini(ore[i], amt)
	ore[i] -= got
	if ore[i] <= 0:
		ore[i] = 0
		ore_cells.erase(i)
	ore_dirty = true
	return got * (2 if gem[i] == 1 else 1)

func has_ore(x: int, y: int) -> bool:
	return inb(x, y) and ore[idx(x, y)] > 0

func find_ore_near(from: Vector2, max_d := 40.0) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := max_d
	for i in ore_cells.keys():
		if ore[i] <= 0:
			continue
		var x = i % W
		var y = i / W
		if game.bld_at(x, y) != null:
			continue
		var d := from.distance_to(Vector2(x + 0.5, y + 0.5))
		if gem[i] == 1:
			d -= 2.0
		if d < bd:
			bd = d
			best = Vector2i(x, y)
	return best

func clear_ore(x: int, y: int):
	var i := idx(x, y)
	if ore[i] > 0:
		ore[i] = 0
		ore_cells.erase(i)
		ore_dirty = true
