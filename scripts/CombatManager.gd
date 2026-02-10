extends Node

# Simple automated combat resolution

signal combat_occurred(results)

func _ready():
	print("Combat Manager initialized.")

func resolve_skirmish(player_drones: Dictionary, enemy_units: Array):
	print("Resolving skirmish...")
	var report = {
		"player_losses": {},
		"enemies_destroyed": 0,
		"status": "VICTORY"
	}
	
	# Very simple logic: Total firepower vs Total durability
	var player_firepower = 0
	for drone_id in player_drones:
		var drone = Global.get_drone_by_id(drone_id)
		if drone and drone.stats.has("firepower"):
			player_firepower += drone.stats.firepower * player_drones[drone_id]
	
	var enemy_durability = 0
	var enemy_firepower = 0
	for enemy in enemy_units:
		enemy_durability += enemy.durability
		enemy_firepower += enemy.firepower
		
	# Damage exchange
	enemy_durability -= player_firepower
	
	if enemy_durability > 0:
		# Player takes losses if enemy survives
		report.status = "RETREAT"
		_apply_player_losses(player_drones, enemy_firepower, report)
	else:
		report.enemies_destroyed = enemy_units.size()
		report.status = "VICTORY"
		
	emit_signal("combat_occurred", report)
	return report

func _apply_player_losses(player_drones, damage, report):
	# Simple loss logic: remove drones based on damage
	# (In a real game, this would be more granular)
	for drone_id in player_drones.keys():
		if damage <= 0: break
		var count = player_drones[drone_id]
		if count > 0:
			player_drones[drone_id] -= 1
			damage -= 10 # Each drone absorbs 10 damage
			if not report.player_losses.has(drone_id):
				report.player_losses[drone_id] = 0
			report.player_losses[drone_id] += 1
