# === scripts/TurnManager.gd ===
extends Node

enum Phase { PLANNING, EXECUTION, RESOLVE, EVENT }

var current_phase: int = Phase.PLANNING
var turn_number: int = 1

signal phase_changed(new_phase)
signal turn_completed(turn_num)

var _waiting_for_combat: bool = false

# Injected references (set by parent or via init)
var _printer_manager: Node = null
var _mining_manager: Node = null
var _mothership: Node = null
var _combat_manager: Node = null
var _galaxy_map: Node = null

func _ready() -> void:
	print("Turn Manager initialized. Current Turn: ", turn_number)
	_resolve_siblings()

func _resolve_siblings() -> void:
	var managers: Node = get_parent()
	if managers == null:
		return

	if managers.has_node("CombatManager"):
		_combat_manager = managers.get_node("CombatManager")
		if _combat_manager.has_signal("encounter_ended"):
			_combat_manager.encounter_ended.connect(_on_encounter_ended)

	if managers.has_node("PrinterManager"):
		_printer_manager = managers.get_node("PrinterManager")
	if managers.has_node("MiningManager"):
		_mining_manager = managers.get_node("MiningManager")
	if managers.has_node("Mothership"):
		_mothership = managers.get_node("Mothership")

	# Galaxy map is a sibling of Managers, not a child
	var main: Node = managers.get_parent()
	if main != null and main.has_node("GalaxyMap3D"):
		_galaxy_map = main.get_node("GalaxyMap3D")

func next_phase() -> void:
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

func end_planning() -> void:
	if current_phase == Phase.PLANNING:
		next_phase()
		_execute_actions()

func _execute_actions() -> void:
	print("Executing actions...")
	await get_tree().create_timer(1.0).timeout
	next_phase() # To RESOLVE

func resolve_turn() -> void:
	if current_phase != Phase.RESOLVE:
		return

	if _waiting_for_combat:
		print("Resolve paused: waiting for combat outcome...")
		return

	print("Resolving turn results...")

	# Energy regen per turn — uses Global's cap helpers (no duplicated formula)
	var regen: int = 20
	Global.resources.energy = mini(int(Global.resources.energy) + regen, int(Global.max_energy))

	# Printer production
	if _printer_manager != null:
		_printer_manager.process_turn()

	# Mining
	if _mining_manager != null and _galaxy_map != null and ("systems" in _galaxy_map):
		_mining_manager.process_turn(_galaxy_map.systems)

	# Combat check
	if _check_for_skirmish_and_pause():
		_waiting_for_combat = true
		return

	next_phase() # To EVENT

func _check_for_skirmish_and_pause() -> bool:
	if _mothership == null or _combat_manager == null or _galaxy_map == null:
		return false
	if not ("systems" in _galaxy_map):
		return false

	var current_system_idx: int = int(_mothership.get_current_system())
	var system: Variant = _galaxy_map.systems[current_system_idx]
	if system.enemies.size() <= 0:
		return false

	print("Enemy encounter in system ", system.name, "!")

	if _printer_manager == null:
		return false

	var inv: Dictionary = _printer_manager.inventory

	if _combat_manager.has_method("begin_encounter"):
		_combat_manager.begin_encounter(system, inv)
		return true

	return false

func _on_encounter_ended(_payload: Dictionary) -> void:
	_waiting_for_combat = false
	if current_phase == Phase.RESOLVE:
		next_phase() # To EVENT

func process_event() -> void:
	if current_phase == Phase.EVENT:
		print("Processing events/anomalies...")
		next_phase() # Back to PLANNING
