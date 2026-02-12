extends Node

enum Phase { PLANNING, EXECUTION, RESOLVE, EVENT }

var current_phase = Phase.PLANNING
var turn_number = 1

signal phase_changed(new_phase)
signal turn_completed(turn_num)

var _waiting_for_combat: bool = false

func _ready():
	print("Turn Manager initialized. Current Turn: ", turn_number)

	if get_parent().has_node("CombatManager"):
		get_parent().get_node("CombatManager").encounter_ended.connect(_on_encounter_ended)

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
		_execute_actions()

func _execute_actions():
	print("Executing actions...")
	await get_tree().create_timer(1.0).timeout
	next_phase() # To RESOLVE

func resolve_turn():
	if current_phase != Phase.RESOLVE:
		return

	if _waiting_for_combat:
		print("Resolve paused: waiting for combat outcome...")
		return

	print("Resolving turn results...")

	Global.resources.energy += 20

	if get_parent().has_node("PrinterManager"):
		get_parent().get_node("PrinterManager").process_turn()

	if get_parent().has_node("MiningManager"):
		var main = get_parent().get_parent()
		var map = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
		get_parent().get_node("MiningManager").process_turn(map.systems)

	# Combat check
	if _check_for_skirmish_and_pause():
		_waiting_for_combat = true
		return

	next_phase() # To EVENT

func _check_for_skirmish_and_pause() -> bool:
	var managers = get_parent()
	if not managers.has_node("Mothership"):
		return false
	var ms = managers.get_node("Mothership")
	var current_system_idx = ms.get_current_system()

	var main = managers.get_parent()
	if main == null:
		return false

	var map = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
	if map == null:
		return false

	var system = map.systems[current_system_idx]
	if system.enemies.size() <= 0:
		return false

	print("Enemy encounter in system ", system.name, "!")
	var combat = managers.get_node("CombatManager")
	var inv = managers.get_node("PrinterManager").inventory
	combat.begin_encounter(system, inv)
	return true

func _on_encounter_ended(_payload: Dictionary) -> void:
	_waiting_for_combat = false
	if current_phase == Phase.RESOLVE:
		next_phase() # To EVENT

func process_event():
	if current_phase == Phase.EVENT:
		print("Processing events/anomalies...")
		next_phase() # Back to PLANNING
