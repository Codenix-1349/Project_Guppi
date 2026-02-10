extends Node

# Tracks the state of the player's Mothership

var current_system_index: int = 0
var jump_cost: int = 20

signal system_changed(new_index)
signal energy_depleted()

func _ready():
	print("Mothership initialized at system ", current_system_index)

func jump_to_system(system_index: int) -> Dictionary:
	# Check if enough energy
	if Global.resources.energy < jump_cost:
		emit_signal("energy_depleted")
		return {"success": false, "message": "INSUFFICIENT ENERGY FOR JUMP!"}
	
	# Consume energy
	Global.resources.energy -= jump_cost
	current_system_index = system_index
	emit_signal("system_changed", current_system_index)
	print("Mothership jumped to system ", system_index)
	return {"success": true, "message": "JUMP SUCCESSFUL: ARRIVED AT SYSTEM " + str(system_index)}

func get_current_system():
	return current_system_index
