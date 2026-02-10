extends Node

# Handles remote scanning using Scout Drones

var scout_drone_id = "scout_v1"
var scan_energy_cost = 10

func _ready():
	print("Scout Manager initialized.")

func can_scout_system(mothership_pos, target_system_pos, scout_range: float) -> bool:
	return mothership_pos.distance_to(target_system_pos) <= scout_range

func launch_scout(system: Dictionary, scanner: Node):
	var printer_manager = get_parent().get_node("PrinterManager")
	var scout_count = printer_manager.inventory.get(scout_drone_id, 0)
	
	if scout_count <= 0:
		print("No Scout Drones in inventory!")
		return false
		
	if Global.resources.energy < scan_energy_cost:
		print("Insufficient energy to launch scout!")
		return false
		
	# Consume resources
	Global.resources.energy -= scan_energy_cost
	printer_manager.inventory[scout_drone_id] -= 1
	
	# Execute scan (using existing ScanManager logic but without its local energy cost)
	system.scanned = true
	Global.resources.data += scanner.scan_cost_data_reward
	
	print("Scout scanned system: ", system.name)
	return true
