extends Node

@onready var turn_manager = $Managers/TurnManager
@onready var mothership = $Managers/Mothership
@onready var scan_manager = $Managers/ScanManager
@onready var printer_manager = $Managers/PrinterManager
@onready var combat_manager = $Managers/CombatManager
@onready var mining_manager = $Managers/MiningManager
@onready var galaxy_map = $GalaxyMap if has_node("GalaxyMap") else $GalaxyMap3D

@onready var energy_label = $UI/Control/ResourceBar/EnergyLabel
@onready var iron_label = $UI/Control/ResourceBar/IronLabel
@onready var titanium_label = $UI/Control/ResourceBar/TitaniumLabel
@onready var uranium_label = $UI/Control/ResourceBar/UraniumLabel
@onready var data_label = $UI/Control/ResourceBar/DataLabel
@onready var turn_label = $UI/Control/TurnInfo/TurnLabel
@onready var phase_label = $UI/Control/TurnInfo/PhaseLabel
@onready var end_turn_button = $UI/Control/TurnInfo/EndTurnButton

@onready var jump_button = $UI/Control/ActionButtons/JumpButton
@onready var scan_button = $UI/Control/ActionButtons/ScanButton
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

func _ready():
	# Connect signals
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.turn_completed.connect(_on_turn_completed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	jump_button.pressed.connect(_on_jump_pressed)
	scan_button.pressed.connect(_on_scan_pressed)
	deploy_miner_btn.pressed.connect(_on_deploy_miner_pressed)
	
	printer_manager.printer_updated.connect(_on_printer_updated)
	combat_manager.combat_occurred.connect(_on_combat_occurred)
	
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
	update_ui()

func _show_info(drone_id: String):
	var drone = Global.get_drone_by_id(drone_id)
	if drone:
		var cost_text = ""
		for res in drone.cost:
			cost_text += str(res).capitalize() + ": " + str(drone.cost[res]) + " "
		info_label.text = drone.name + " [" + cost_text + "]\n" + drone.description

func _hide_info():
	info_label.text = "Hover over a unit to see details..."

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
	if p_idx == -1: p_idx = 0 # Default to first planet if none selected
	
	if mining_manager.assign_miner_to_planet(current_idx, p_idx):
		update_ui()

func _update_detailed_info():
	if not galaxy_map: return
		
	var s_idx = galaxy_map.selected_system_index
	if s_idx == -1:
		system_panel.visible = false
		return
		
	system_panel.visible = true
	
	# MOTHERSHIP INFO (Fleet Overview)
	if s_idx == -2:
		system_title.text = "FLEET: MOTHERSHIP"
		var fleet_info = "[b]Unit Inventory:[/b]\n"
		var scouts = printer_manager.inventory.get("scout_v1", 0)
		var miners = printer_manager.inventory.get("miner_v1", 0)
		var defenders = printer_manager.inventory.get("defender_v1", 0)
		
		fleet_info += "- Scouts: [color=cyan]" + str(scouts) + "[/color]\n"
		fleet_info += "- Miners: [color=green]" + str(miners) + "[/color]\n"
		fleet_info += "- Defenders: [color=red]" + str(defenders) + "[/color]\n\n"
		fleet_info += "[center][color=gray]Select system/planet to deploy[/color][/center]"
		system_content.text = fleet_info
		return

	var system = galaxy_map.systems[s_idx]
	
	if not system.scanned:
		system_title.text = "UNBEKANNTES SYSTEM"
		system_content.text = "[center]Keine Sensordaten verfügbar.\nBitte [color=yellow]Scan System[/color] durchführen.[/center]"
		return
		
	var p_idx = galaxy_map.selected_planet_index
	
	if p_idx == -1:
		# SYSTEM OVERVIEW (Click on Star)
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
		summary += "[b]PLANETEN:[/b]\n" + planet_list
		
		system_content.text = summary
	else:
		# PLANET INFO (Click on Planet)
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
		printer_manager.add_job(drone)
		update_ui()

func _on_printer_updated():
	update_ui()

func _on_combat_occurred(report):
	print("Combat Report: ", report.status)
	combat_log.text = "COMBAT: " + report.status
	if report.player_losses.size() > 0:
		combat_log.text += "\nLosses: " + str(report.player_losses)
	combat_log.visible = true
	# Auto-hide after 5 seconds
	await get_tree().create_timer(5.0).timeout
	combat_log.visible = false
	update_ui()

func _on_jump_pressed():
	var target_index = galaxy_map.selected_system_index
	if target_index == -1: return
	
	if galaxy_map.is_system_connected(mothership.get_current_system(), target_index):
		if mothership.jump_to_system(target_index):
			if galaxy_map is Node2D:
				galaxy_map.queue_redraw()
			else:
				galaxy_map.selected_planet_index = -1
				galaxy_map.update_selection_visuals()
			update_ui()
	else:
		# Feedback for unconnected systems
		combat_log.text = "ERROR: SYSTEMS NOT CONNECTED"
		combat_log.visible = true
		await get_tree().create_timer(2.0).timeout
		combat_log.visible = false

func _on_scan_pressed():
	var current_index = mothership.get_current_system()
	var system = galaxy_map.systems[current_index]
	if scan_manager.scan_system(system):
		if galaxy_map is Node2D:
			galaxy_map.queue_redraw()
		else:
			galaxy_map.update_selection_visuals()
		update_ui()

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
	
	# Update button text based on phase
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
	turn_label.text = "Turn: " + str(turn_manager.turn_number)
	phase_label.text = "Phase: " + turn_manager.Phase.keys()[turn_manager.current_phase].capitalize()
	
	# System / Planet Info Logic
	_update_detailed_info()
	
	# Update printer slots
	for i in range(3):
		var job = printer_manager.slots[i]
		if job:
			printer_slots[i].value = printer_manager.get_job_progress(i) * 100
			printer_slots[i].visible = true
		else:
			printer_slots[i].visible = false
			
	if not galaxy_map is Node2D:
		galaxy_map.update_selection_visuals()

func _unhandled_input(event):
	if has_node("GalaxyMap3D") and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_process_3d_selection(event.position)

func _process_3d_selection(mouse_pos):
	var cam = get_node("CameraPivot/Camera3D")
	if not cam: return
	
	var s_idx = galaxy_map.selected_system_index
	
	# 1. Check Mothership
	if galaxy_map.mothership_mesh:
		var ms_pos = galaxy_map.mothership_mesh.global_position
		var ms_screen = cam.unproject_position(ms_pos)
		if not cam.is_position_behind(ms_pos):
			if mouse_pos.distance_to(ms_screen) < 30.0:
				galaxy_map.selected_system_index = -2 # Special index for Mothership
				galaxy_map.update_selection_visuals()
				update_ui()
				return

	# 2. Check Planets (in current system AND selected system)
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
				if not is_instance_valid(p_mesh): continue
				
				var screen_pos = cam.unproject_position(p_mesh.global_position)
				if cam.is_position_behind(p_mesh.global_position): continue
				
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
		return

	# 2. Check Systems
	var closest_idx = -1
	var min_pixel_dist = 40.0
	
	for i in range(galaxy_map.systems.size()):
		var sys_pos = galaxy_map.systems[i].position
		var screen_pos = cam.unproject_position(sys_pos)
		if cam.is_position_behind(sys_pos): continue
		
		var dist = mouse_pos.distance_to(screen_pos)
		if dist < min_pixel_dist:
			closest_idx = i
			min_pixel_dist = dist
			
	if closest_idx != -1:
		galaxy_map.selected_system_index = closest_idx
		galaxy_map.selected_planet_index = -1 # Clear planet selection when selecting new system
		galaxy_map.update_selection_visuals()
		update_ui()
	else:
		# Clicked empty space - Deselect
		galaxy_map.selected_system_index = -1
		galaxy_map.selected_planet_index = -1
		galaxy_map.update_selection_visuals()
		update_ui()
