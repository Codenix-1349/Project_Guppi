# === scripts/Main.gd ===
# Orchestrator: wires managers, UI modules, and handles high-level actions.
extends Node3D

# ---------------------------
# Manager references
# ---------------------------
@onready var turn_manager: Node = $Managers/TurnManager
@onready var mothership: Node = $Managers/Mothership
@onready var scan_manager: Node = $Managers/ScanManager
@onready var scout_manager: Node = $Managers/ScoutManager
@onready var printer_manager: Node = $Managers/PrinterManager
@onready var combat_manager: Node = $Managers/CombatManager
@onready var mining_manager: Node = $Managers/MiningManager
@onready var galaxy_map: Node = $GalaxyMap3D

# ---------------------------
# Scene UI references
# ---------------------------
@onready var energy_label: Label = $UI/Control/ResourceBar/EnergyLabel
@onready var iron_label: Label = $UI/Control/ResourceBar/IronLabel
@onready var titanium_label: Label = $UI/Control/ResourceBar/TitaniumLabel
@onready var uranium_label: Label = $UI/Control/ResourceBar/UraniumLabel
@onready var data_label: Label = $UI/Control/ResourceBar/DataLabel
@onready var hp_label: Label = $UI/Control/ResourceBar/HPLabel
@onready var level_label: Label = $UI/Control/TurnInfo/LevelLabel
@onready var turn_label: Label = $UI/Control/TurnInfo/TurnLabel
@onready var phase_label: Label = $UI/Control/TurnInfo/PhaseLabel
@onready var end_turn_button: Button = $UI/Control/TurnInfo/EndTurnButton

@onready var game_over_layer: CanvasLayer = $GameOverLayer

@onready var jump_button: Button = $UI/Control/ActionButtons/JumpButton
@onready var scan_button: Button = $UI/Control/ActionButtons/ScanButton
@onready var launch_scout_btn: Button = $UI/Control/ActionButtons/LaunchScoutButton
@onready var deploy_miner_btn: Button = $UI/Control/ActionButtons/AssignMinerButton
var land_button: Button = null

@onready var combat_log: Label = $UI/Control/CombatLog
@onready var info_label: Label = $UI/Control/InfoPanel/Label
@onready var system_panel: PanelContainer = $UI/Control/SystemPanel
@onready var system_title: Label = $UI/Control/SystemPanel/VBox/Title
@onready var system_content: RichTextLabel = $UI/Control/SystemPanel/VBox/Content

@onready var printer_slots: Array = [
	$UI/Control/PrinterStatus/Slot0,
	$UI/Control/PrinterStatus/Slot1,
	$UI/Control/PrinterStatus/Slot2
]

@onready var print_scout_btn: Button = $UI/Control/Fabricator/PrintScout
@onready var print_miner_btn: Button = $UI/Control/Fabricator/PrintMiner
@onready var print_defender_btn: Button = $UI/Control/Fabricator/PrintDefender

# UI containers hidden during combat
@onready var _ui_action_buttons: Control = $UI/Control/ActionButtons
@onready var _ui_printer_status: Control = $UI/Control/PrinterStatus
@onready var _ui_fabricator: Control = $UI/Control/Fabricator
@onready var _ui_info_panel: Control = $UI/Control/InfoPanel

# ---------------------------
# Module instances (created at runtime)
# ---------------------------
var _ui_manager: UIManager = null
var _combat_ui: CombatUI = null
var _selection_handler: SelectionHandler = null
var _icon_renderer: IconRenderer = null

# Combat mode tracking
var _saved_vis: Dictionary = {}

# External asset check (Kenney Space Kit)
const KENNEY_REQUIRED_DIR_1: String = "res://kenney-space-kit/Models"
const KENNEY_REQUIRED_DIR_2: String = "res://kenney_space-kit/Models"

# ---------------------------
# Lifecycle
# ---------------------------

func _ready() -> void:
	_check_required_assets()
	_create_modules()
	_connect_signals()
	_init_galaxy()

	_ui_manager.on_phase_changed(turn_manager.current_phase)
	_ui_manager.update_ui()

# ---------------------------
# Module creation
# ---------------------------

func _create_modules() -> void:
	# IconRenderer (must exist before CombatUI)
	_icon_renderer = IconRenderer.new()
	_icon_renderer.name = "IconRenderer"
	add_child(_icon_renderer)

	# UIManager
	_ui_manager = UIManager.new()
	_ui_manager.name = "UIManager"
	add_child(_ui_manager)
	_ui_manager.init({
		"turn_manager": turn_manager,
		"mothership": mothership,
		"printer_manager": printer_manager,
		"mining_manager": mining_manager,
		"galaxy_map": galaxy_map,
		"scout_manager": scout_manager,
		"combat_log": combat_log,
		"energy_label": energy_label,
		"iron_label": iron_label,
		"titanium_label": titanium_label,
		"uranium_label": uranium_label,
		"data_label": data_label,
		"hp_label": hp_label,
		"level_label": level_label,
		"turn_label": turn_label,
		"phase_label": phase_label,
		"end_turn_button": end_turn_button,
		"info_label": info_label,
		"system_panel": system_panel,
		"system_title": system_title,
		"system_content": system_content,
		"game_over_layer": game_over_layer,
		"jump_button": jump_button,
		"scan_button": scan_button,
		"launch_scout_btn": launch_scout_btn,
		"deploy_miner_btn": deploy_miner_btn,
		"print_scout_btn": print_scout_btn,
		"print_miner_btn": print_miner_btn,
		"print_defender_btn": print_defender_btn,
		"printer_slots": printer_slots,
	})

	# CombatUI
	_combat_ui = CombatUI.new()
	_combat_ui.name = "CombatUI"
	add_child(_combat_ui)
	if has_node("UI/Control"):
		_combat_ui.init(combat_manager, _icon_renderer, $UI/Control)
	_combat_ui.combat_mode_changed.connect(_on_combat_mode_changed)
	
	# Create Land Button
	land_button = Button.new()
	land_button.text = "LAND ON SURFACE"
	land_button.name = "LandButton"
	land_button.visible = false
	if _ui_action_buttons:
		_ui_action_buttons.add_child(land_button)
		# Move it to start or end? End is fine.
		land_button.pressed.connect(_on_land_button_pressed)


	# SelectionHandler
	_selection_handler = SelectionHandler.new()
	_selection_handler.name = "SelectionHandler"
	add_child(_selection_handler)
	_selection_handler.init(galaxy_map, $CameraPivot)
	_selection_handler.selection_changed.connect(_on_selection_changed)

	system_panel.visible = false

# ---------------------------
# Signal wiring
# ---------------------------

func _connect_signals() -> void:
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.turn_completed.connect(_on_turn_completed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	jump_button.pressed.connect(_on_jump_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	launch_scout_btn.pressed.connect(_on_launch_scout_pressed)
	deploy_miner_btn.pressed.connect(_on_deploy_miner_pressed)

	jump_button.mouse_entered.connect(func() -> void: _ui_manager.show_jump_info())
	jump_button.mouse_exited.connect(func() -> void: _ui_manager.hide_info())

	printer_manager.printer_updated.connect(func() -> void: _ui_manager.update_ui())
	printer_manager.drone_fabricated.connect(_on_drone_fabricated)
	mining_manager.mining_occurred.connect(_on_mining_occurred)
	mothership.energy_depleted.connect(func() -> void: _ui_manager.show_temporary_message("WARNING: CRITICAL ENERGY DEPLETED!"))

	if combat_manager.has_signal("combat_occurred"):
		combat_manager.combat_occurred.connect(_on_combat_occurred)

	Global.xp_gained.connect(func(_amt: Variant) -> void: _ui_manager.update_ui())

	print_scout_btn.pressed.connect(func() -> void: _on_print_requested("scout_v1"))
	print_miner_btn.pressed.connect(func() -> void: _on_print_requested("miner_v1"))
	print_defender_btn.pressed.connect(func() -> void: _on_print_requested("defender_v1"))

	print_scout_btn.mouse_entered.connect(func() -> void: _ui_manager.show_drone_info("scout_v1"))
	print_miner_btn.mouse_entered.connect(func() -> void: _ui_manager.show_drone_info("miner_v1"))
	print_defender_btn.mouse_entered.connect(func() -> void: _ui_manager.show_drone_info("defender_v1"))

	print_scout_btn.mouse_exited.connect(func() -> void: _ui_manager.hide_info())
	print_miner_btn.mouse_exited.connect(func() -> void: _ui_manager.hide_info())
	print_defender_btn.mouse_exited.connect(func() -> void: _ui_manager.hide_info())

# ---------------------------
# Galaxy initialization
# ---------------------------

func _init_galaxy() -> void:
	if galaxy_map.has_method("generate_map_3d"):
		galaxy_map.mothership_node = mothership
		galaxy_map.generate_map_3d()
		_apply_random_start_system_if_available()
		call_deferred("_focus_camera_on_start")

func _apply_random_start_system_if_available() -> void:
	if galaxy_map == null:
		return

	var start_idx: int = 0
	if "start_system_index" in galaxy_map:
		start_idx = int(galaxy_map.start_system_index)

	if mothership != null:
		if mothership.has_method("set_current_system"):
			mothership.set_current_system(start_idx)
		else:
			mothership.current_system_index = start_idx
			if mothership.has_signal("system_changed"):
				mothership.emit_signal("system_changed", start_idx)

	if galaxy_map.has_method("update_selection_visuals"):
		galaxy_map.selected_system_index = -1
		galaxy_map.selected_planet_index = -1
		galaxy_map.update_selection_visuals()

func _focus_camera_on_start() -> void:
	if not has_node("CameraPivot"):
		return

	var pivot: Node = get_node("CameraPivot")
	if pivot == null or not pivot.has_method("focus_on"):
		return

	if galaxy_map and ("mothership_mesh" in galaxy_map) and galaxy_map.mothership_mesh:
		pivot.focus_on(galaxy_map.mothership_mesh.global_position)
		return

	if galaxy_map and ("systems" in galaxy_map):
		var cur: int = int(mothership.get_current_system())
		if cur >= 0 and cur < galaxy_map.systems.size():
			var sys: Variant = galaxy_map.systems[cur]
			if sys and ("position" in sys):
				pivot.focus_on(sys.position)

# ---------------------------
# View Management (Galaxy <-> Planet Surface)
# ---------------------------

var _planet_view_instance: Node = null
const PLANET_SURFACE_SCENE = preload("res://scenes/planet/PlanetSurface.tscn")

func enter_planet_view(planet_data: Dictionary) -> void:
	if _planet_view_instance:
		return

	# Hide Galaxy View
	galaxy_map.visible = false
	# mothership is a logic node, visuals are in galaxy_map
	
	# Hide Galaxy UI panels (SystemPanel, etc.)
	_set_galaxy_ui_visible(false)

	# Instantiate Planet Surface
	_planet_view_instance = PLANET_SURFACE_SCENE.instantiate()
	add_child(_planet_view_instance)
	
	if _planet_view_instance.has_signal("request_exit"):
		_planet_view_instance.request_exit.connect(exit_planet_view)
	
	if _planet_view_instance.has_method("setup"):
		_planet_view_instance.setup(planet_data)

	# TODO: Show Planet HUD

func exit_planet_view() -> void:
	if _planet_view_instance:
		_planet_view_instance.queue_free()
		_planet_view_instance = null

	# Show Galaxy View
	galaxy_map.visible = true
	
	_set_galaxy_ui_visible(true)
	
	# Reset camera?
	call_deferred("_focus_camera_on_start") # or keep last pos

func _set_galaxy_ui_visible(vis: bool) -> void:
	$UI/Control.visible = vis
	# If we have specific panels for planet view, toggle them here
	# For now, hiding the main control hides everything (resource bar, buttons)
	# We might want to keep resource bar visible? User requirement: "RTS style ... build menu"
	# Probably needs its own UI layer. For Phase 1, basic toggle is fine.

# ---------------------------
# External assets check
# ---------------------------

func _check_required_assets() -> void:
	var ok: bool = DirAccess.dir_exists_absolute(KENNEY_REQUIRED_DIR_1) or DirAccess.dir_exists_absolute(KENNEY_REQUIRED_DIR_2)
	if not ok:
		push_warning("⚠ Grafik-Assets fehlen! Siehe README.md.")
		if combat_log:
			combat_log.text = "⚠ Grafik-Assets fehlen! Bitte Kenney Space Kit entpacken."
			combat_log.visible = true

# ---------------------------
# Input
# ---------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selection_handler.handle_click((event as InputEventMouseButton).position, (event as InputEventMouseButton).double_click)

# ---------------------------
# Signal handlers
# ---------------------------

func _on_selection_changed() -> void:
	_ui_manager.update_ui()
	_update_land_button_visibility()

func _update_land_button_visibility() -> void:
	if not land_button: return
	
	# Only show if a planet is selected and we are in galaxy view
	var p_idx: int = galaxy_map.selected_planet_index if "selected_planet_index" in galaxy_map else -1
	var s_idx: int = galaxy_map.selected_system_index if "selected_system_index" in galaxy_map else -1 # Also need system?
	
	# Check if planet selected
	if p_idx != -1 and galaxy_map.visible: # Only show in galaxy view
		land_button.visible = true
	else:
		land_button.visible = false


func _on_phase_changed(new_phase: int) -> void:
	_ui_manager.on_phase_changed(new_phase)

func _on_turn_completed(_turn_num: Variant) -> void:
	_ui_manager.update_ui()

func _on_end_turn_pressed() -> void:
	if turn_manager.current_phase == turn_manager.Phase.PLANNING:
		turn_manager.end_planning()
	elif turn_manager.current_phase == turn_manager.Phase.RESOLVE:
		turn_manager.resolve_turn()
	elif turn_manager.current_phase == turn_manager.Phase.EVENT:
		turn_manager.process_event()

# ---------------------------
# Actions
# ---------------------------

func _on_jump_pressed() -> void:
	if turn_manager.current_phase != turn_manager.Phase.PLANNING:
		_ui_manager.show_temporary_message("SPRUNG NUR IN DER PLANUNGSPHASE MÖGLICH!")
		return

	var target_index: int = galaxy_map.selected_system_index
	if target_index == -1:
		return

	if galaxy_map.is_system_connected(mothership.get_current_system(), target_index):
		var result: Dictionary = mothership.jump_to_system(target_index)
		_ui_manager.show_temporary_message(result.message)
		if result.success:
			galaxy_map.selected_planet_index = -1
			galaxy_map.update_selection_visuals()
			_ui_manager.update_ui()
	else:
		_ui_manager.show_temporary_message("ERROR: SYSTEMS NOT CONNECTED")

func _on_scan_pressed() -> void:
	var current_index: int = mothership.get_current_system()
	var system: Dictionary = galaxy_map.systems[current_index]
	var result: Dictionary = scan_manager.scan_system(system)
	_ui_manager.show_temporary_message(result.message)
	if result.success:
		galaxy_map.update_selection_visuals()
		_ui_manager.update_ui()

func _on_launch_scout_pressed() -> void:
	var s_idx: int = galaxy_map.selected_system_index
	if s_idx < 0:
		return

	var system: Dictionary = galaxy_map.systems[s_idx]
	var result: Dictionary = scout_manager.launch_scout(system, scan_manager)
	_ui_manager.show_temporary_message(result.message)
	if result.success:
		galaxy_map.update_selection_visuals()
		_ui_manager.update_ui()

func _on_deploy_miner_pressed() -> void:
	var current_idx: int = mothership.get_current_system()
	var system: Dictionary = galaxy_map.systems[current_idx]
	if not system.scanned:
		_ui_manager.show_temporary_message("ERROR: SYSTEM NOT SCANNED")
		return

	var p_idx: int = galaxy_map.selected_planet_index if "selected_planet_index" in galaxy_map else -1
	if p_idx == -1:
		p_idx = 0

	var result: Dictionary = mining_manager.assign_miner_to_planet(current_idx, p_idx)
	_ui_manager.show_temporary_message(result.message)
	if result.success:
		galaxy_map.update_selection_visuals()
		_ui_manager.update_ui()
		
func _on_land_button_pressed() -> void:
	var s_idx: int = galaxy_map.selected_system_index
	var p_idx: int = galaxy_map.selected_planet_index
	
	if s_idx == -1 or p_idx == -1: 
		return

	# We need the planet data dictionary.
	# GalaxyMap3D stores systems -> planets array
	if galaxy_map and "systems" in galaxy_map:
		var system: Dictionary = galaxy_map.systems[s_idx]
		var planets: Array = system.get("planets", [])
		if p_idx >= 0 and p_idx < planets.size():
			var p_data: Dictionary = planets[p_idx]
			enter_planet_view(p_data)


func _on_print_requested(drone_id: String) -> void:
	var drone: Variant = Global.get_drone_by_id(drone_id)
	if drone:
		var result: Dictionary = printer_manager.add_job(drone)
		_ui_manager.show_temporary_message(result.message)
		if result.success:
			_ui_manager.update_ui()

func _on_drone_fabricated(drone_id: Variant) -> void:
	var drone: Variant = Global.get_drone_by_id(str(drone_id))
	if drone:
		_ui_manager.show_temporary_message("FABRICATION COMPLETE: " + str(drone.name).to_upper())
	_ui_manager.update_ui()

func _on_mining_occurred(gained: Dictionary) -> void:
	var msg: String = "MINING COMPLETE: "
	var parts: Array = []
	for res in gained:
		if int(gained[res]) > 0:
			parts.append(str(gained[res]) + " " + str(res).capitalize())
	if parts.size() > 0:
		_ui_manager.show_temporary_message(msg + ", ".join(parts))
	_ui_manager.update_ui()

func _on_combat_occurred(report: Dictionary) -> void:
	var status_text: String = "GEFECHT: "
	match str(report.get("status", "")):
		"VICTORY":
			status_text += "SIEG!"
		"SKIRMISH_LOSS":
			status_text += "RÜCKZUG / VERLUSTE"
		"CRITICAL_DAMAGE":
			status_text += "KRITISCHER TREFFER (HÜLLE!)"
		_:
			status_text += str(report.get("status", ""))

	var full_msg: String = status_text
	if int(report.get("xp_gained", 0)) > 0:
		full_msg += "\nXP erhalten: +" + str(report.xp_gained)
	if int(report.get("mothership_damage", 0)) > 0:
		full_msg += "\nSCHIFFSSCHADEN: " + str(report.mothership_damage)

	_ui_manager.show_temporary_message(full_msg)
	_ui_manager.update_ui()

func _on_restart_pressed() -> void:
	Global.reset_game()
	get_tree().reload_current_scene()

# ---------------------------
# Combat mode toggling (hide/show HUD panels)
# ---------------------------

func _on_combat_mode_changed(active: bool) -> void:
	var nodes_to_toggle: Array = []

	if system_panel:
		nodes_to_toggle.append(system_panel)
	if _ui_action_buttons:
		nodes_to_toggle.append(_ui_action_buttons)
	if _ui_printer_status:
		nodes_to_toggle.append(_ui_printer_status)
	if _ui_fabricator:
		nodes_to_toggle.append(_ui_fabricator)
	if _ui_info_panel:
		nodes_to_toggle.append(_ui_info_panel)
	if combat_log:
		nodes_to_toggle.append(combat_log)

	if active:
		_saved_vis.clear()
		for n in nodes_to_toggle:
			if n == null:
				continue
			_saved_vis[n.get_path()] = n.visible
			n.visible = false
	else:
		for path in _saved_vis.keys():
			var p: NodePath = path
			if has_node(p):
				var n2: Node = get_node(p)
				n2.visible = bool(_saved_vis[path])
		_saved_vis.clear()
