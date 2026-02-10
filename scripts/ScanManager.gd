extends Node

# Handles scanning logic for star systems

var scan_cost_energy: int = 5
var scan_cost_data_reward: int = 10

func _ready():
	print("Scan Manager initialized.")

func scan_system(system: Dictionary) -> Dictionary:
	if system.scanned:
		return {"success": false, "message": "SYSTEM ALREADY SCANNED"}
	
	if Global.resources.energy < scan_cost_energy:
		return {"success": false, "message": "INSUFFICIENT ENERGY FOR SCAN!"}
	
	# Consume energy, reward data
	Global.resources.energy -= scan_cost_energy
	Global.resources.data += scan_cost_data_reward
	Global.gain_xp(10) # 10 XP per scan
	
	system.scanned = true
	print("Scanned system: ", system.name)
	return {"success": true, "message": "SCAN SUCCESSFUL: " + system.name.to_upper() + " (+10 XP)"}
