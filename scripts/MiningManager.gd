extends Node

# Tracks assigned miners: system_index -> count
var deployments = {}

# Current active miners available in Mothership (will be synced with PrinterManager inventory)
var fleet_miners = 0

signal mining_occurred(resources_gained)

func _ready():
	print("Mining Manager initialized.")

func assign_miner_to_planet(system_index: int, planet_index: int):
	# We need to know if we have miners available
	var printer_manager = get_parent().get_node("PrinterManager")
	var miner_count = printer_manager.inventory.get("miner_v1", 0)
	
	if miner_count > 0:
		printer_manager.inventory["miner_v1"] -= 1
		var key = str(system_index) + "," + str(planet_index)
		if not deployments.has(key):
			deployments[key] = 0
		deployments[key] += 1
		print("Assigned miner to planet ", key)
		return true
	
	print("No miners in cargo to assign!")
	return false

func process_turn(systems: Array):
	var total_gained = {"iron": 0, "titanium": 0, "uranium": 0}
	
	for key in deployments:
		var parts = key.split(",")
		var s_idx = int(parts[0])
		var p_idx = int(parts[1])
		var count = deployments[key]
		
		var system = systems[s_idx]
		var planet = system.planets[p_idx]
		
		# Yield per miner for each resource
		var yields = {"iron": 15, "titanium": 5, "uranium": 2}
		
		for res in yields:
			var extraction = count * yields[res]
			if planet.resources[res] < extraction:
				extraction = planet.resources[res]
			
			planet.resources[res] -= extraction
			total_gained[res] += extraction
			Global.resources[res] += extraction
			
	if total_gained.iron > 0 or total_gained.titanium > 0 or total_gained.uranium > 0:
		emit_signal("mining_occurred", total_gained)
		print("Mining complete. Gained: ", total_gained)
