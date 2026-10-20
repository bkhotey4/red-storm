extends Node2D
# 所有單位與建築的共同基底

var id := 0
var game
var player
var def: Dictionary = {}
var type_id := ""
var kind := ""
var hp := 100.0
var max_hp := 100.0
var pos := Vector2.ZERO
var dead := false
var selected := false
var armor := "heavy"
var sight := 5.0
var last_hit := -100.0
var last_attacker = null
var kills := 0
var rank := 0
var flash_t := 0.0

func tc() -> Color:
	return player.color

func is_air() -> bool:
	return false

func is_enemy(o) -> bool:
	return o != null and is_instance_valid(o) and not o.dead and player.is_enemy_of(o.player)

func dist_to(p: Vector2) -> float:
	return p.distance_to(pos)

func alive() -> bool:
	return not dead and is_instance_valid(self)

func armor_mult() -> float:
	return [1.0, 0.85, 0.7][rank] * player.up_armor(self) * ability_armor()

func dmg_mult() -> float:
	return [1.0, 1.2, 1.5][rank] * player.up_damage(self)

func ability_armor() -> float:
	return 1.0

func add_kill():
	kills += 1
	game.note_kill(self)
	var nr := 0
	if kills >= 6:
		nr = 2
	elif kills >= 3:
		nr = 1
	if nr > rank:
		rank = nr
		if player == game.human:
			game.message("%s 晉升為%s！" % [def.name, "老兵" if rank == 1 else "精英"])

func take_damage(amount: float, attacker = null, wh := "ap"):
	if dead:
		return
	var mult: float = float(Defs.WARHEADS.get(wh, Defs.WARHEADS.ap).get(armor, 1.0))
	var d := amount * mult * armor_mult() * (1.6 if game.mut("glass") else 1.0)
	if armor == "naval" and attacker != null and is_instance_valid(attacker) and attacker.get("player") != null and Defs.COUNTRIES.has(attacker.player.country):
		d *= float(Defs.COUNTRIES[attacker.player.country].get("dmg_vs_ship", 1.0))
	if d <= 0.0:
		return
	hp -= d
	last_hit = game.time
	flash_t = 0.08
	if attacker != null and is_instance_valid(attacker) and not attacker.dead:
		last_attacker = attacker
		on_attacked(attacker)
		if attacker.player != player and not player.neutral and not attacker.player.neutral:
			player.add_relation(attacker.player, -0.4)
	if hp <= 0.0:
		hp = 0.0
		if attacker != null and is_instance_valid(attacker) and attacker.player != player:
			attacker.add_kill()
			attacker.player.stats.killed += 1
		die()

func on_attacked(_attacker):
	pass

func heal(amount: float):
	hp = minf(max_hp, hp + amount)

func die():
	dead = true
	selected = false
	game.on_entity_died(self)
	queue_free()
