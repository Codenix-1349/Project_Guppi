# === scripts/TurnManager.gd ===
extends Node

enum Phase { PLANNING, EXECUTION, RESOLVE, EVENT }

var current_phase: int = Phase.PLANNING
var turn_number: int = 1

signal phase_changed(new_phase)
signal turn_completed(turn_num)

var _waiting_for_combat: bool = false

func _ready() -> void:
	print("Turn Manager initialized. Current Turn: ", turn_number)

	# Pause RESOLVE until combat finished (if CombatManager exists)
	if get_parent().has_node("CombatManager"):
		var combat: Node = get_parent().get_node("CombatManager")
		if combat != null and combat.has_signal("encounter_ended"):
			combat.encounter_ended.connect(_on_encounter_ended)

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

	# -----------------------------
	# Energy regen per turn (capped)
	# Desired rule:
	#   Lvl 1: max 80 energy
	#   Each further lvl: +20 max energy
	# -----------------------------
	var lvl: int = int(Global.mothership_level)
	var max_energy: int = 100 + 10 * maxi(0, lvl - 1)
	Global.resources.energy = mini(int(Global.resources.energy) + 20, max_energy)

	# Printer production
	if get_parent().has_node("PrinterManager"):
		get_parent().get_node("PrinterManager").process_turn()

	# Mining
	if get_parent().has_node("MiningManager"):
		var main: Node = get_parent().get_parent()
		if main != null:
			var map: Node = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
			if map != null and ("systems" in map):
				get_parent().get_node("MiningManager").process_turn(map.systems)

	# Combat check
	if _check_for_skirmish_and_pause():
		_waiting_for_combat = true
		return

	next_phase() # To EVENT

func _check_for_skirmish_and_pause() -> bool:
	var managers: Node = get_parent()
	if managers == null:
		return false
	if not managers.has_node("Mothership"):
		return false
	if not managers.has_node("PrinterManager"):
		return false
	if not managers.has_node("CombatManager"):
		return false

	var ms: Node = managers.get_node("Mothership")
	var current_system_idx: int = int(ms.get_current_system())

	var main: Node = managers.get_parent()
	if main == null:
		return false

	var map: Node = main.get_node("GalaxyMap") if main.has_node("GalaxyMap") else main.get_node("GalaxyMap3D")
	if map == null:
		return false
	if not ("systems" in map):
		return false

	var system = map.systems[current_system_idx]
	if system.enemies.size() <= 0:
		return false

	print("Enemy encounter in system ", system.name, "!")

	var combat: Node = managers.get_node("CombatManager")
	var inv: Dictionary = managers.get_node("PrinterManager").inventory

	# ✅ New combat entrypoint (parse-safe, per-unit HP stacks)
	if combat != null and combat.has_method("begin_encounter"):
		combat.begin_encounter(system, inv)
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
