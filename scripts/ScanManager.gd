extends Node

# Handles scanning logic for star systems

var scan_cost_energy: int = 5
var scan_cost_data_reward: int = 10

func _ready():
	print("Scan Manager initialized.")

func scan_system(system: Dictionary):
	if system.scanned:
		print("System already scanned.")
		return false
	
	if Global.resources.energy < scan_cost_energy:
		print("Insufficient energy for scan!")
		return false
	
	# Consume energy, reward data
	Global.resources.energy -= scan_cost_energy
	Global.resources.data += scan_cost_data_reward
	
	system.scanned = true
	print("Scanned system: ", system.name)
	return true
