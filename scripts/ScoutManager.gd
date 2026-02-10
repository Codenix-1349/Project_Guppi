extends Node

# Handles remote scanning using Scout Drones

var scout_drone_id = "scout_v1"
var scan_energy_cost = 10

func _ready():
	print("Scout Manager initialized.")

func can_scout_system(mothership_pos, target_system_pos, scout_range: float) -> bool:
	return mothership_pos.distance_to(target_system_pos) <= scout_range

func launch_scout(system: Dictionary, scanner: Node) -> Dictionary:
	if system.scanned:
		return {"success": false, "message": "DIESES SYSTEM IST BEREITS GESCANNT!"}
		
	var managers = get_parent()
	var printer_manager = managers.get_node("PrinterManager")
	var scout_count = printer_manager.inventory.get(scout_drone_id, 0)
	
	if scout_count <= 0:
		return {"success": false, "message": "NO SCOUT DRONES IN INVENTORY!"}
		
	if Global.resources.energy < scan_energy_cost:
		return {"success": false, "message": "INSUFFICIENT ENERGY TO LAUNCH SCOUT!"}
		
	# Consume resources
	Global.resources.energy -= scan_energy_cost
	printer_manager.inventory[scout_drone_id] -= 1
	
	# Execute scan
	system.scanned = true
	Global.resources.data += scanner.scan_cost_data_reward
	Global.gain_xp(10) # 10 XP per scout scan
	
	print("Scout scanned system: ", system.name)
	return {"success": true, "message": "SCOUT SUCCESS: " + system.name.to_upper() + " SCANNED (+10 XP)"}
