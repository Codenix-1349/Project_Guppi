extends Node

@onready var turn_manager = $Managers/TurnManager
@onready var mothership = $Managers/Mothership
@onready var scan_manager = $Managers/ScanManager
@onready var scout_manager = $Managers/ScoutManager
@onready var printer_manager = $Managers/PrinterManager
@onready var combat_manager = $Managers/CombatManager
@onready var mining_manager = $Managers/MiningManager
@onready var galaxy_map = $GalaxyMap if has_node("GalaxyMap") else $GalaxyMap3D

@onready var energy_label = $UI/Control/ResourceBar/EnergyLabel
@onready var iron_label = $UI/Control/ResourceBar/IronLabel
@onready var titanium_label = $UI/Control/ResourceBar/TitaniumLabel
@onready var uranium_label = $UI/Control/ResourceBar/UraniumLabel
@onready var data_label = $UI/Control/ResourceBar/DataLabel
@onready var hp_label = $UI/Control/ResourceBar/HPLabel
@onready var level_label = $UI/Control/TurnInfo/LevelLabel
@onready var turn_label = $UI/Control/TurnInfo/TurnLabel
@onready var phase_label = $UI/Control/TurnInfo/PhaseLabel
@onready var end_turn_button = $UI/Control/TurnInfo/EndTurnButton

@onready var game_over_layer = $GameOverLayer

@onready var jump_button = $UI/Control/ActionButtons/JumpButton
@onready var scan_button = $UI/Control/ActionButtons/ScanButton
@onready var launch_scout_btn = $UI/Control/ActionButtons/LaunchScoutButton
@onready var deploy_miner_btn = $UI/Control/ActionButtons/AssignMinerButton
@onready var combat_log = $UI/Control/CombatLog
@onready var info_label = $UI/Control/InfoPanel/Label
@onready var system_panel = $UI/Control/SystemPanel
@onready var system_title = $UI/Control/SystemPanel/VBox/Title
@onready var system_content = $UI/Control/SystemPanel/VBox/Content

@onready var printer_slots = [
	$UI/Control/PrinterStatus/Slot0,
	$UI/Control/PrinterStatus/Slot1,
	$UI/Control/PrinterStatus/Slot2
]

@onready var print_scout_btn = $UI/Control/Fabricator/PrintScout
@onready var print_miner_btn = $UI/Control/Fabricator/PrintMiner
@onready var print_defender_btn = $UI/Control/Fabricator/PrintDefender

# --- UI containers we may hide during combat (best-effort: only if exist) ---
@onready var _ui_root: Control = $UI/Control
@onready var _ui_action_buttons: Control = $UI/Control/ActionButtons
@onready var _ui_printer_status: Control = $UI/Control/PrinterStatus
@onready var _ui_fabricator: Control = $UI/Control/Fabricator
@onready var _ui_info_panel: Control = $UI/Control/InfoPanel


func _ready():
	# Connect signals
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.turn_completed.connect(_on_turn_completed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

	jump_button.pressed.connect(_on_jump_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	launch_scout_btn.pressed.connect(_on_launch_scout_pressed)
	deploy_miner_btn.pressed.connect(_on_deploy_miner_pressed)

	jump_button.mouse_entered.connect(_show_jump_info)
	jump_button.mouse_exited.connect(_hide_info)

	printer_manager.printer_updated.connect(_on_printer_updated)
	printer_manager.drone_fabricated.connect(_on_drone_fabricated)
	mining_manager.mining_occurred.connect(_on_mining_occurred)
	mothership.energy_depleted.connect(_on_energy_depleted)

	# legacy combat log signal (kept; optional)
	if combat_manager.has_signal("combat_occurred"):
		combat_manager.combat_occurred.connect(_on_combat_occurred)

	Global.xp_gained.connect(_on_xp_gained)

	print_scout_btn.pressed.connect(_on_print_scout)
	print_miner_btn.pressed.connect(_on_print_miner)
	print_defender_btn.pressed.connect(_on_print_defender)

	# Hover signals for tooltips
	print_scout_btn.mouse_entered.connect(func(): _show_info("scout_v1"))
	print_miner_btn.mouse_entered.connect(func(): _show_info("miner_v1"))
	print_defender_btn.mouse_entered.connect(func(): _show_info("defender_v1"))

	print_scout_btn.mouse_exited.connect(_hide_info)
	print_miner_btn.mouse_exited.connect(_hide_info)
	print_defender_btn.mouse_exited.connect(_hide_info)

	system_panel.visible = false

	# Initialize 3D Map if active
	if galaxy_map.has_method("generate_map_3d"):
		galaxy_map.mothership_node = mothership
		galaxy_map.generate_map_3d()

		# ✅ Auto-focus at game start (after nodes are ready)
		call_deferred("_focus_camera_on_start")

	# ✅ Runtime combat UI + runtime battle log (no new files)
	_setup_combat_ui()
	_setup_battle_log_ui()

	_on_phase_changed(turn_manager.current_phase)
	update_ui()


# ✅ NEW: start camera focus on mothership / current system
func _focus_camera_on_start() -> void:
	if not has_node("CameraPivot"):
		return

	var pivot = get_node("CameraPivot")
	if pivot == null or not pivot.has_method("focus_on"):
		return

	# Prefer mothership mesh position (3D model in GalaxyMap3D)
	if galaxy_map and ("mothership_mesh" in galaxy_map) and galaxy_map.mothership_mesh:
		pivot.focus_on(galaxy_map.mothership_mesh.global_position)
		return

	# Fallback: focus current system
	if galaxy_map and ("systems" in galaxy_map):
		var cur: int = int(mothership.get_current_system())
		if cur >= 0 and cur < galaxy_map.systems.size():
			var sys = galaxy_map.systems[cur]
			if sys and ("position" in sys):
				pivot.focus_on(sys.position)


func _show_info(drone_id: String):
	var drone = Global.get_drone_by_id(drone_id)
	if drone:
		var cost_text = ""
		for res in drone.cost:
			cost_text += str(res).capitalize() + ": " + str(drone.cost[res]) + " "
		var build_time = drone.get("build_time", 2)
		info_label.text = drone.name + " (" + str(build_time) + " Runden) [" + cost_text + "]\n" + drone.description

func _hide_info():
	info_label.text = "Hover over a unit to see details..."

func _show_jump_info():
	var cost = mothership.jump_cost
	info_label.text = "JUMP DRIVE [Energie: " + str(cost) + "]\nBereite einen Sprung in ein benachbartes System vor."

func _on_deploy_miner_pressed():
	var current_idx = mothership.get_current_system()
	var system = galaxy_map.systems[current_idx]
	if not system.scanned:
		combat_log.text = "ERROR: SYSTEM NOT SCANNED"
		combat_log.visible = true
		await get_tree().create_timer(2.0).timeout
		combat_log.visible = false
		return

	var p_idx = galaxy_map.selected_planet_index if "selected_planet_index" in galaxy_map else -1
	if p_idx == -1:
		p_idx = 0

	var result = mining_manager.assign_miner_to_planet(current_idx, p_idx)
	_show_temporary_message(result.message)
	if result.success:
		if galaxy_map and galaxy_map.has_method("update_selection_visuals"):
			galaxy_map.update_selection_visuals()
		update_ui()

func _update_detailed_info():
	if not galaxy_map:
		return

	var s_idx = galaxy_map.selected_system_index
	if s_idx == -1:
		system_panel.visible = false
		return

	system_panel.visible = true

	# MOTHERSHIP INFO (Fleet Overview)
	if s_idx == -2:
		system_title.text = "FLOTTE: MUTTERSCHIFF"
		var fleet_info = "[b]Einheiteninventar:[/b]\n"
		var scouts = printer_manager.inventory.get("scout_v1", 0)
		var miners = printer_manager.inventory.get("miner_v1", 0)
		var defenders = printer_manager.inventory.get("defender_v1", 0)

		fleet_info += "- Scouts: [color=cyan]" + str(scouts) + "[/color]\n"
		fleet_info += "- Miners: [color=green]" + str(miners) + "[/color]\n"
		fleet_info += "- Defenders: [color=red]" + str(defenders) + "[/color]\n\n"
		fleet_info += "[center][color=gray]System/Planet zum Einsatz auswählen[/color][/center]"
		system_content.text = fleet_info
		return

	var system = galaxy_map.systems[s_idx]

	if not system.scanned:
		system_title.text = "UNBEKANNTES SYSTEM"
		system_content.text = "[center]Keine Sensordaten verfügbar.\nBitte [color=yellow]Scan System[/color] durchführen.[/center]"
		return

	var p_idx = galaxy_map.selected_planet_index

	if p_idx == -1:
		# SYSTEM OVERVIEW
		system_title.text = "SYSTEM: " + system.name.to_upper()
		var total_res = {"iron": 0, "titanium": 0, "uranium": 0}
		var total_miners = 0
		var planet_list = "[indent]"

		for i in range(system.planets.size()):
			var p = system.planets[i]
			var key = str(s_idx) + "," + str(i)
			var m_count = mining_manager.deployments.get(key, 0)
			total_miners += m_count

			planet_list += "[color=cyan]" + p.name + "[/color]: FE " + str(p.resources.iron)
			if p.resources.titanium > 0: planet_list += " | TI " + str(p.resources.titanium)
			if p.resources.uranium > 0: planet_list += " | U " + str(p.resources.uranium)
			if m_count > 0: planet_list += " ([color=green]Miners: " + str(m_count) + "[/color])"
			planet_list += "\n"

			for res in total_res:
				total_res[res] += p.resources[res]

		planet_list += "[/indent]"

		var summary = "[b]GESAMT RESSOURCEN:[/b]\n"
		summary += "FE: " + str(total_res.iron) + " | TI: " + str(total_res.titanium) + " | U: " + str(total_res.uranium) + "\n"
		summary += "TOTAL MINER: [color=green]" + str(total_miners) + "[/color]\n\n"

		if system.enemies.size() > 0:
			summary += "[b][color=red]BEDROHUNGEN ERKANNT:[/color][/b]\n"
			var enemy_counts = {}
			for e in system.enemies:
				enemy_counts[e.name] = enemy_counts.get(e.name, 0) + 1
			for e_name in enemy_counts:
				summary += "- " + e_name + " (x" + str(enemy_counts[e_name]) + ")\n"
			summary += "\n"

		summary += "[b]PLANETEN:[/b]\n" + planet_list
		system_content.text = summary
	else:
		# PLANET INFO
		var planet = system.planets[p_idx]
		var key = str(s_idx) + "," + str(p_idx)
		var m_count = mining_manager.deployments.get(key, 0)

		system_title.text = "PLANET: " + planet.name.to_upper()
		var p_info = "[b]Detaillierte Analyse:[/b]\n"
		p_info += "- Eisen: " + str(planet.resources.iron) + "\n"
		p_info += "- Titan: " + str(planet.resources.titanium) + "\n"
		p_info += "- Uran: " + str(planet.resources.uranium) + "\n\n"
		p_info += "[b]Bergbau-Status:[/b]\n"
		p_info += "Aktive Drohnen: [color=green]" + str(m_count) + "[/color]\n\n"
		p_info += "[center][color=gray]Klick den Stern für systemweite Übersicht[/color][/center]"

		system_content.text = p_info

func _on_print_scout(): _on_print_requested("scout_v1")
func _on_print_miner(): _on_print_requested("miner_v1")
func _on_print_defender(): _on_print_requested("defender_v1")

func _on_print_requested(drone_id: String):
	var drone = Global.get_drone_by_id(drone_id)
	if drone:
		var result = printer_manager.add_job(drone)
		_show_temporary_message(result.message)
		if result.success:
			update_ui()

func _on_printer_updated():
	update_ui()

# Legacy combat log handler (kept)
func _on_combat_occurred(report):
	var status_text = "GEFECHT: "
	match report.status:
		"VICTORY": status_text += "SIEG!"
		"SKIRMISH_LOSS": status_text += "RÜCKZUG / VERLUSTE"
		"CRITICAL_DAMAGE": status_text += "KRITISCHER TREFFER (HÜLLE!)"
		_: status_text += str(report.status)

	combat_log.text = status_text
	if report.xp_gained > 0:
		combat_log.text += "\nXP erhalten: +" + str(report.xp_gained)

	if report.mothership_damage > 0:
		combat_log.text += "\nSCHIFFSSCHADEN: " + str(report.mothership_damage)

	if report.player_losses.size() > 0:
		var loss_parts = []
		for drone_id in report.player_losses:
			var drone = Global.get_drone_by_id(drone_id)
			var drone_name = drone.name if drone else drone_id
			loss_parts.append(str(report.player_losses[drone_id]) + "x " + drone_name)
		combat_log.text += "\nVerluste: " + ", ".join(loss_parts)

	combat_log.visible = true
	await get_tree().create_timer(5.0).timeout
	combat_log.visible = false
	update_ui()

func _on_xp_gained(_amount):
	update_ui()

func _on_drone_fabricated(drone_id):
	var drone = Global.get_drone_by_id(drone_id)
	_show_temporary_message("FABRICATION COMPLETE: " + drone.name.to_upper())
	update_ui()

func _on_mining_occurred(gained):
	var msg = "MINING COMPLETE: "
	var parts = []
	for res in gained:
		if gained[res] > 0:
			parts.append(str(gained[res]) + " " + res.capitalize())
	if parts.size() > 0:
		_show_temporary_message(msg + ", ".join(parts))
	update_ui()

func _on_restart_pressed():
	Global.reset_game()
	get_tree().reload_current_scene()

func _on_energy_depleted():
	_show_temporary_message("WARNING: CRITICAL ENERGY DEPLETED!")

func _on_jump_pressed():
	if turn_manager.current_phase != turn_manager.Phase.PLANNING:
		_show_temporary_message("SPRUNG NUR IN DER PLANUNGSPHASE MÖGLICH!")
		return

	var target_index = galaxy_map.selected_system_index
	if target_index == -1:
		return

	if galaxy_map.is_system_connected(mothership.get_current_system(), target_index):
		var result = mothership.jump_to_system(target_index)
		_show_temporary_message(result.message)
		if result.success:
			if galaxy_map is Node2D:
				galaxy_map.queue_redraw()
			else:
				galaxy_map.selected_planet_index = -1
				galaxy_map.update_selection_visuals()
			update_ui()
	else:
		combat_log.text = "ERROR: SYSTEMS NOT CONNECTED"
		combat_log.visible = true
		await get_tree().create_timer(2.0).timeout
		combat_log.visible = false

func _on_scan_pressed():
	var current_index = mothership.get_current_system()
	var system = galaxy_map.systems[current_index]
	var result = scan_manager.scan_system(system)
	_show_temporary_message(result.message)
	if result.success:
		if galaxy_map is Node2D:
			galaxy_map.queue_redraw()
		else:
			galaxy_map.update_selection_visuals()
		update_ui()

func update_scout_button():
	var s_idx = galaxy_map.selected_system_index
	if s_idx < 0:
		launch_scout_btn.disabled = true
		return

	var system = galaxy_map.systems[s_idx]
	if system.scanned:
		launch_scout_btn.disabled = true
		return

	var m_pos = galaxy_map.systems[mothership.get_current_system()].position
	var t_pos = system.position
	var scout_data = Global.get_drone_by_id("scout_v1")
	var s_range = scout_data.stats.get("scan_range", 700)

	var in_range = scout_manager.can_scout_system(m_pos, t_pos, s_range)
	var has_scout = printer_manager.inventory.get("scout_v1", 0) > 0

	launch_scout_btn.disabled = !in_range or !has_scout or turn_manager.current_phase != turn_manager.Phase.PLANNING

	if !has_scout:
		launch_scout_btn.tooltip_text = "Keine Scouts im Inventar"
	elif !in_range:
		launch_scout_btn.tooltip_text = "Ziel außer Reichweite (> 800)"
	elif turn_manager.current_phase != turn_manager.Phase.PLANNING:
		launch_scout_btn.tooltip_text = "Nur in der Planungsphase möglich"
	else:
		launch_scout_btn.tooltip_text = "Scout starten"

func _on_launch_scout_pressed():
	var s_idx = galaxy_map.selected_system_index
	if s_idx < 0:
		return

	var system = galaxy_map.systems[s_idx]
	var result = scout_manager.launch_scout(system, scan_manager)
	_show_temporary_message(result.message)
	if result.success:
		if galaxy_map is Node2D:
			galaxy_map.queue_redraw()
		else:
			galaxy_map.update_selection_visuals()
		update_ui()

func _show_temporary_message(msg: String):
	combat_log.text = msg
	combat_log.visible = true
	await get_tree().create_timer(3.0).timeout
	combat_log.visible = false

func _on_end_turn_pressed():
	if turn_manager.current_phase == turn_manager.Phase.PLANNING:
		turn_manager.end_planning()
	elif turn_manager.current_phase == turn_manager.Phase.RESOLVE:
		turn_manager.resolve_turn()
	elif turn_manager.current_phase == turn_manager.Phase.EVENT:
		turn_manager.process_event()

func _on_phase_changed(new_phase):
	update_ui()
	var is_planning = (new_phase == turn_manager.Phase.PLANNING)
	jump_button.disabled = !is_planning
	scan_button.disabled = !is_planning
	print_scout_btn.disabled = !is_planning
	print_miner_btn.disabled = !is_planning
	print_defender_btn.disabled = !is_planning

	match new_phase:
		turn_manager.Phase.PLANNING:
			end_turn_button.text = "End Planning"
			end_turn_button.disabled = false
		turn_manager.Phase.EXECUTION:
			end_turn_button.text = "Executing..."
			end_turn_button.disabled = true
		turn_manager.Phase.RESOLVE:
			end_turn_button.text = "Resolve Turn"
			end_turn_button.disabled = false
		turn_manager.Phase.EVENT:
			end_turn_button.text = "Process Event"
			end_turn_button.disabled = false

func _on_turn_completed(_turn_num):
	update_ui()

func update_ui():
	energy_label.text = "Energy: " + str(Global.resources.energy)
	iron_label.text = "Iron: " + str(Global.resources.iron)
	titanium_label.text = "Titanium: " + str(Global.resources.titanium)
	uranium_label.text = "Uranium: " + str(Global.resources.uranium)
	data_label.text = "Data: " + str(Global.resources.data)
	hp_label.text = "HP: " + str(Global.mothership_hp) + "/" + str(Global.max_mothership_hp)
	turn_label.text = "Turn: " + str(turn_manager.turn_number)
	level_label.text = "LVL: " + str(Global.mothership_level) + " (XP: " + str(Global.xp) + "/" + str(Global.xp_to_next_level) + ")"
	phase_label.text = "Phase: " + turn_manager.Phase.keys()[turn_manager.current_phase].capitalize()

	_update_detailed_info()
	update_scout_button()

	for i in range(3):
		var job = printer_manager.slots[i]
		if job:
			printer_slots[i].value = printer_manager.get_job_progress(i) * 100
			printer_slots[i].get_node("Label").text = job.name
			printer_slots[i].visible = true
		else:
			printer_slots[i].visible = false

	if Global.mothership_hp <= 0:
		game_over_layer.visible = true

func _unhandled_input(event):
	if has_node("GalaxyMap3D") and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_process_3d_selection(event.position, event.double_click)

func _process_3d_selection(mouse_pos, is_double_click = false):
	var cam = get_node("CameraPivot/Camera3D")
	if not cam:
		return

	var s_idx = galaxy_map.selected_system_index

	# 1) Mothership
	if galaxy_map.mothership_mesh:
		var ms_pos = galaxy_map.mothership_mesh.global_position
		var ms_screen = cam.unproject_position(ms_pos)
		if not cam.is_position_behind(ms_pos):
			if mouse_pos.distance_to(ms_screen) < 50.0:
				galaxy_map.selected_system_index = -2
				galaxy_map.update_selection_visuals()
				update_ui()
				if is_double_click:
					get_node("CameraPivot").focus_on(ms_pos)
				return

	# 2) Systems
	for i in range(galaxy_map.system_meshes.size()):
		var sys_mesh = galaxy_map.system_meshes[i]
		var sys_pos = sys_mesh.global_position
		var sys_screen = cam.unproject_position(sys_pos)

		if not cam.is_position_behind(sys_pos):
			if mouse_pos.distance_to(sys_screen) < 40.0:
				galaxy_map.selected_system_index = i
				galaxy_map.selected_planet_index = -1
				galaxy_map.update_selection_visuals()
				update_ui()
				if is_double_click:
					get_node("CameraPivot").focus_on(sys_pos)
				return

	# 3) Planets
	var active_sys_indices = []
	active_sys_indices.append(mothership.get_current_system())
	if s_idx != -1 and s_idx != active_sys_indices[0]:
		active_sys_indices.append(s_idx)

	var closest_planet_idx = -1
	var target_s_idx = -1
	var min_p_dist = 25.0

	for check_s_idx in active_sys_indices:
		if galaxy_map.systems[check_s_idx].scanned and galaxy_map.planet_meshes.has(check_s_idx):
			for p_idx in range(galaxy_map.planet_meshes[check_s_idx].size()):
				var p_mesh = galaxy_map.planet_meshes[check_s_idx][p_idx]
				if not is_instance_valid(p_mesh):
					continue

				var screen_pos = cam.unproject_position(p_mesh.global_position)
				if cam.is_position_behind(p_mesh.global_position):
					continue

				var dist = mouse_pos.distance_to(screen_pos)
				if dist < min_p_dist:
					closest_planet_idx = p_idx
					target_s_idx = check_s_idx
					min_p_dist = dist

	if closest_planet_idx != -1:
		galaxy_map.selected_system_index = target_s_idx
		galaxy_map.selected_planet_index = closest_planet_idx
		galaxy_map.update_selection_visuals()
		update_ui()
		if is_double_click:
			var p_mesh2 = galaxy_map.planet_meshes[target_s_idx][closest_planet_idx]
			get_node("CameraPivot").focus_on(p_mesh2.global_position)
		return

	# Clicked empty space - Deselect
	galaxy_map.selected_system_index = -1
	galaxy_map.selected_planet_index = -1
	galaxy_map.update_selection_visuals()
	update_ui()

# ---------------------------
# RUNTIME COMBAT UI (no new files)
# ---------------------------

var _combat_panel: PanelContainer
var _combat_status: RichTextLabel
var _combat_fleet: RichTextLabel
var _combat_enemy: RichTextLabel
var _combat_fight_btn: Button
var _combat_flee_btn: Button
var _combat_close_btn: Button

# ---------------------------
# RUNTIME BATTLE LOG UI (combat-only, collapsible, never blocks buttons)
# ---------------------------

var _battle_panel: PanelContainer
var _battle_scroll: ScrollContainer
var _battle_rich: RichTextLabel
var _battle_toggle_btn: Button
var _battle_collapsed: bool = true

# track original UI visibility
var _combat_mode_active: bool = false
var _saved_vis: Dictionary = {}

func _set_combat_mode(active: bool) -> void:
	if _combat_mode_active == active:
		return
	_combat_mode_active = active

	var nodes_to_toggle: Array = []

	if system_panel: nodes_to_toggle.append(system_panel)
	if _ui_action_buttons: nodes_to_toggle.append(_ui_action_buttons)
	if _ui_printer_status: nodes_to_toggle.append(_ui_printer_status)
	if _ui_fabricator: nodes_to_toggle.append(_ui_fabricator)
	if _ui_info_panel: nodes_to_toggle.append(_ui_info_panel)
	if combat_log: nodes_to_toggle.append(combat_log) # avoid double messages behind panel

	if active:
		_saved_vis.clear()
		for n in nodes_to_toggle:
			if n == null: continue
			_saved_vis[n.get_path()] = n.visible
			n.visible = false
	else:
		for path in _saved_vis.keys():
			var p: NodePath = path
			if has_node(p):
				var n2 = get_node(p)
				n2.visible = bool(_saved_vis[path])
		_saved_vis.clear()

func _setup_combat_ui():
	if not has_node("UI/Control"):
		print("WARN: UI/Control not found -> combat UI disabled")
		return

	var ui_root: Control = $UI/Control

	_combat_panel = PanelContainer.new()
	_combat_panel.name = "CombatPanelRuntime"
	_combat_panel.visible = false
	_combat_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_combat_panel.anchor_left = 0.0
	_combat_panel.anchor_top = 0.0
	_combat_panel.anchor_right = 1.0
	_combat_panel.anchor_bottom = 1.0
	_combat_panel.offset_left = 16
	_combat_panel.offset_top = 120
	_combat_panel.offset_right = -16
	_combat_panel.offset_bottom = -16

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	_combat_panel.add_theme_stylebox_override("panel", bg)

	ui_root.add_child(_combat_panel)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_combat_panel.add_child(vbox)

	var title := Label.new()
	title.text = "KAMPF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_combat_status = RichTextLabel.new()
	_combat_status.bbcode_enabled = true
	_combat_status.fit_content = true
	_combat_status.scroll_active = false
	_combat_status.text = "[center][color=gray]Kein Kampf aktiv[/color][/center]"
	vbox.add_child(_combat_status)

	var lists := HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(lists)

	var fleet_box := VBoxContainer.new()
	fleet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(fleet_box)

	var ft := Label.new()
	ft.text = "DEINE FLOTTE"
	fleet_box.add_child(ft)

	_combat_fleet = RichTextLabel.new()
	_combat_fleet.bbcode_enabled = true
	_combat_fleet.fit_content = true
	_combat_fleet.scroll_active = true
	_combat_fleet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fleet_box.add_child(_combat_fleet)

	var enemy_box := VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(enemy_box)

	var et := Label.new()
	et.text = "GEGNER"
	enemy_box.add_child(et)

	_combat_enemy = RichTextLabel.new()
	_combat_enemy.bbcode_enabled = true
	_combat_enemy.fit_content = true
	_combat_enemy.scroll_active = true
	_combat_enemy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_box.add_child(_combat_enemy)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btns)

	_combat_fight_btn = Button.new()
	_combat_fight_btn.text = "KÄMPFEN (1 Runde)"
	btns.add_child(_combat_fight_btn)

	_combat_flee_btn = Button.new()
	_combat_flee_btn.text = "FLIEHEN (33%)"
	btns.add_child(_combat_flee_btn)

	_combat_close_btn = Button.new()
	_combat_close_btn.text = "SCHLIESSEN"
	_combat_close_btn.visible = false
	btns.add_child(_combat_close_btn)

	_combat_fight_btn.pressed.connect(func():
		if combat_manager and combat_manager.has_method("player_fight_round"):
			combat_manager.player_fight_round()
	)

	_combat_flee_btn.pressed.connect(func():
		if combat_manager and combat_manager.has_method("player_try_flee"):
			combat_manager.player_try_flee()
	)

	_combat_close_btn.pressed.connect(func():
		_combat_panel.visible = false
		_set_combat_mode(false)
		_set_battle_log_active(false) # ✅ hide log completely when combat closed
	)

	if combat_manager:
		if combat_manager.has_signal("encounter_started"):
			combat_manager.encounter_started.connect(_on_encounter_ui)
		if combat_manager.has_signal("encounter_updated"):
			combat_manager.encounter_updated.connect(_on_encounter_ui)
		if combat_manager.has_signal("encounter_ended"):
			combat_manager.encounter_ended.connect(_on_encounter_end)

func _setup_battle_log_ui():
	if not has_node("UI/Control"):
		return
	var ui_root: Control = $UI/Control

	_battle_panel = PanelContainer.new()
	_battle_panel.name = "BattleLogRuntime"
	_battle_panel.visible = false
	_battle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # will be set when expanded
	_battle_panel.z_index = 2000

	# ✅ anchor bottom-right to never block action buttons (left)
	_battle_panel.anchor_left = 1.0
	_battle_panel.anchor_top = 1.0
	_battle_panel.anchor_right = 1.0
	_battle_panel.anchor_bottom = 1.0
	_battle_panel.offset_right = -16
	_battle_panel.offset_bottom = -16
	# width/height will be handled by collapsed/expanded toggle

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.03, 0.78)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	_battle_panel.add_theme_stylebox_override("panel", bg)

	ui_root.add_child(_battle_panel)

	var root_v := VBoxContainer.new()
	_battle_panel.add_child(root_v)

	# Header row
	var header := HBoxContainer.new()
	root_v.add_child(header)

	var title := Label.new()
	title.text = "BATTLE LOG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_battle_toggle_btn = Button.new()
	_battle_toggle_btn.text = "Show"
	header.add_child(_battle_toggle_btn)

	_battle_toggle_btn.pressed.connect(func():
		_battle_collapsed = !_battle_collapsed
		_apply_battle_log_layout()
	)

	_battle_scroll = ScrollContainer.new()
	_battle_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(_battle_scroll)

	_battle_rich = RichTextLabel.new()
	_battle_rich.bbcode_enabled = true
	_battle_rich.scroll_active = false
	_battle_rich.fit_content = true
	_battle_rich.text = ""
	_battle_scroll.add_child(_battle_rich)

	_battle_collapsed = true
	_apply_battle_log_layout()

func _set_battle_log_active(active: bool) -> void:
	if _battle_panel == null:
		return
	_battle_panel.visible = active
	if not active:
		_battle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle_rich.text = ""
		_battle_collapsed = true
		_apply_battle_log_layout()

func _apply_battle_log_layout() -> void:
	if _battle_panel == null:
		return

	if _battle_collapsed:
		_battle_toggle_btn.text = "Show"
		_battle_scroll.visible = false

		# ✅ Only show header row (no empty body)
		_battle_panel.custom_minimum_size = Vector2(170, 0)

		# Keep it tight at bottom-right
		_battle_panel.offset_left = -170
		_battle_panel.offset_top = -44

		# ✅ Do not block clicks except the tiny header/button area
		_battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_battle_toggle_btn.text = "Hide"
		_battle_scroll.visible = true

		# Expanded box
		var w: float = 520
		var h: float = 260
		_battle_panel.custom_minimum_size = Vector2(w, h)
		_battle_panel.offset_left = -w
		_battle_panel.offset_top = -h

		# ✅ When expanded we intentionally capture clicks inside panel only
		_battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _update_battle_log_text(payload: Dictionary) -> void:
	if _battle_panel == null:
		return
	if not _battle_panel.visible:
		return

	# Prefer payload log_bb if present; else ask manager (if method exists)
	var log_bb: String = ""
	if payload.has("log_bb"):
		log_bb = str(payload["log_bb"])
	elif combat_manager and combat_manager.has_method("get_log_bb"):
		log_bb = str(combat_manager.get_log_bb())

	_battle_rich.text = log_bb

	# auto scroll to bottom when expanded
	if not _battle_collapsed:
		await get_tree().process_frame
		_battle_scroll.scroll_vertical = int(_battle_scroll.get_v_scroll_bar().max_value)

func _on_encounter_ui(payload: Dictionary):
	if _combat_panel == null:
		return

	_set_combat_mode(true)
	_combat_panel.visible = true
	_combat_close_btn.visible = false
	_combat_fight_btn.disabled = false
	_combat_flee_btn.disabled = false

	_combat_status.text = str(payload.get("status", ""))
	_combat_fleet.text = str(payload.get("fleet_bb", ""))
	_combat_enemy.text = str(payload.get("enemy_bb", ""))

	# ✅ Battle log only during combat UI
	_set_battle_log_active(true)
	_update_battle_log_text(payload)

func _on_encounter_end(payload: Dictionary):
	if _combat_panel == null:
		return

	var result = str(payload.get("result", ""))
	if result != "":
		_combat_status.text = "[b]Result:[/b] " + result + "\n\n" + _combat_status.text

	_combat_fight_btn.disabled = true
	_combat_flee_btn.disabled = true
	_combat_close_btn.visible = true

	# keep log visible while combat panel still open (combat-only requirement)
	_set_battle_log_active(true)
	_update_battle_log_text(payload)

func _on_encounter_end_close_cleanup():
	_set_battle_log_active(false)

# ---------------------------
# END RUNTIME COMBAT UI
# ---------------------------
