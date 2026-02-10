extends Node

enum Phase { PLANNING, EXECUTION, RESOLVE, EVENT }

var current_phase = Phase.PLANNING
var turn_number = 1

signal phase_changed(new_phase)
signal turn_completed(turn_num)

func _ready():
	print("Turn Manager initialized. Current Turn: ", turn_number)

func next_phase():
	match current_phase:
		Phase.PLANNING:
			current_phase = Phase.EXECUTION
		Phase.EXECUTION:
			current_phase = Phase.RESOLVE
		Phase.RESOLVE:
			current_phase = Phase.EVENT
		Phase.EVENT:
			current_phase = Phase.PLANNING
			turn_number += 1
			emit_signal("turn_completed", turn_number)
	
	emit_signal("phase_changed", current_phase)
	print("Phase changed to: ", Phase.keys()[current_phase])

func end_planning():
	if current_phase == Phase.PLANNING:
		next_phase()
		# Trigger execution logic here
		_execute_actions()

func _execute_actions():
	print("Executing actions...")
	# Simulate execution time or logic
	await get_tree().create_timer(1.0).timeout
	next_phase() # To RESOLVE

func resolve_turn():
	if current_phase == Phase.RESOLVE:
		print("Resolving turn results...")
		# Update resources (passive regeneration)
		Global.resources.energy += 20
		
		# Process printer jobs
		if get_parent().has_node("PrinterManager"):
			get_parent().get_node("PrinterManager").process_turn()
		
		# Process mining
		if get_parent().has_node("MiningManager"):
			var main = get_parent().get_parent()
			var map = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
			get_parent().get_node("MiningManager").process_turn(map.systems)
		
		# Check for combat in current system
		_check_for_skirmish()
			
		next_phase() # To EVENT

func _check_for_skirmish():
	# Simple random chance for enemy presence in unscanned systems
	var managers = get_parent()
	var ms = managers.get_node("Mothership")
	var current_system_idx = ms.get_current_system()
	var main = managers.get_parent()
	var map = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
	var system = map.systems[current_system_idx]
	
	if not system.scanned and randf() < 0.3:
		print("Enemy encounter!")
		var enemy_units = [{"name": "Raider", "durability": 20, "firepower": 5}]
		managers.get_node("CombatManager").resolve_skirmish(managers.get_node("PrinterManager").inventory, enemy_units)

func process_event():
	if current_phase == Phase.EVENT:
		print("Processing events/anomalies...")
		# Trigger random events or triggers
		next_phase() # Back to PLANNING for next turn
