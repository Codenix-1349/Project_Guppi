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
		"xp_gained": 0,
		"mothership_damage": 0,
		"status": "VICTORY"
	}
	
	# 1. Player Attack Phase
	var player_firepower = 0
	for drone_id in player_drones:
		var drone = Global.get_drone_by_id(drone_id)
		if drone and drone.stats.has("firepower"):
			# Apply individual drone counts
			player_firepower += drone.stats.firepower * player_drones[drone_id]
	
	# Randomize player damage (80% to 120%)
	player_firepower = int(player_firepower * randf_range(0.8, 1.2))
	
	var total_enemy_durability = 0
	for enemy in enemy_units:
		total_enemy_durability += enemy.stats.durability
		
	# Execute Player attack
	total_enemy_durability -= player_firepower
	
	# 2. Enemy Counter-Attack Phase (if any survive)
	if total_enemy_durability > 0:
		var enemy_firepower = 0
		for enemy in enemy_units:
			enemy_firepower += enemy.stats.firepower
			
		# Randomize enemy damage
		enemy_firepower = int(enemy_firepower * randf_range(0.8, 1.2))
		
		# Check if player has NO drones
		var total_drones = 0
		for drone_id in player_drones:
			total_drones += player_drones[drone_id]
			
		if total_drones <= 0:
			report.status = "CRITICAL_DAMAGE"
			var direct_damage = int(enemy_firepower * 5.0) # Highly lethal to hull
			report.mothership_damage = direct_damage
			Global.mothership_hp -= direct_damage
			if Global.mothership_hp < 0: Global.mothership_hp = 0
		else:
			report.status = "SKIRMISH_LOSS"
			_apply_player_losses(player_drones, enemy_firepower, report)
	else:
		report.enemies_destroyed = enemy_units.size()
		report.xp_gained = enemy_units.size() * 50 # Base XP per enemy
		report.status = "VICTORY"
		Global.gain_xp(report.xp_gained)
		
	emit_signal("combat_occurred", report)
	return report

func _apply_player_losses(player_drones: Dictionary, damage: int, report: Dictionary):
	var total_damage = damage
	var types = player_drones.keys()
	types.shuffle() # Randomize which drones take the hit
	
	for drone_id in types:
		while player_drones[drone_id] > 0 and total_damage > 0:
			var drone = Global.get_drone_by_id(drone_id)
			var absorption = drone.stats.durability
			
			total_damage -= absorption
			player_drones[drone_id] -= 1
			
			if not report.player_losses.has(drone_id):
				report.player_losses[drone_id] = 0
			report.player_losses[drone_id] += 1
			
			if total_damage < 0: total_damage = 0
