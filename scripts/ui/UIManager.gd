# === scripts/ui/UIManager.gd ===
extends Node
class_name UIManager
## Manages all HUD elements: resource bar, turn/phase info, printer slots,
## system panel, tooltips, and temporary messages.

# References (set via init)
var turn_manager: Node = null
var mothership: Node = null
var printer_manager: Node = null
var mining_manager: Node = null
var galaxy_map: Node = null
var scout_manager: Node = null
var combat_log_label: Label = null

# UI node references
var energy_label: Label = null
var iron_label: Label = null
var titanium_label: Label = null
var uranium_label: Label = null
var data_label: Label = null
var hp_label: Label = null
var level_label: Label = null
var turn_label: Label = null
var phase_label: Label = null
var end_turn_button: Button = null
var info_label: Label = null
var system_panel: PanelContainer = null
var system_title: Label = null
var system_content: RichTextLabel = null
var game_over_layer: CanvasLayer = null

var jump_button: Button = null
var scan_button: Button = null
var launch_scout_btn: Button = null
var deploy_miner_btn: Button = null
var print_scout_btn: Button = null
var print_miner_btn: Button = null
var print_defender_btn: Button = null
var printer_slots: Array = []

# -----------------------------------------------
# Initialization
# -----------------------------------------------

func init(refs: Dictionary) -> void:
	turn_manager = refs.get("turn_manager")
	mothership = refs.get("mothership")
	printer_manager = refs.get("printer_manager")
	mining_manager = refs.get("mining_manager")
	galaxy_map = refs.get("galaxy_map")
	scout_manager = refs.get("scout_manager")
	combat_log_label = refs.get("combat_log")

	energy_label = refs.get("energy_label")
	iron_label = refs.get("iron_label")
	titanium_label = refs.get("titanium_label")
	uranium_label = refs.get("uranium_label")
	data_label = refs.get("data_label")
	hp_label = refs.get("hp_label")
	level_label = refs.get("level_label")
	turn_label = refs.get("turn_label")
	phase_label = refs.get("phase_label")
	end_turn_button = refs.get("end_turn_button")
	info_label = refs.get("info_label")
	system_panel = refs.get("system_panel")
	system_title = refs.get("system_title")
	system_content = refs.get("system_content")
	game_over_layer = refs.get("game_over_layer")

	jump_button = refs.get("jump_button")
	scan_button = refs.get("scan_button")
	launch_scout_btn = refs.get("launch_scout_btn")
	deploy_miner_btn = refs.get("deploy_miner_btn")
	print_scout_btn = refs.get("print_scout_btn")
	print_miner_btn = refs.get("print_miner_btn")
	print_defender_btn = refs.get("print_defender_btn")
	printer_slots = refs.get("printer_slots", [])

# -----------------------------------------------
# Full UI update
# -----------------------------------------------

func update_ui() -> void:
	_update_resource_bar()
	_update_turn_info()
	_update_detailed_info()
	_update_scout_button()
	_update_printer_slots()

	if Global.mothership_hp <= 0 and game_over_layer:
		game_over_layer.visible = true

# -----------------------------------------------
# Resource bar
# -----------------------------------------------

func _update_resource_bar() -> void:
	if energy_label:
		energy_label.text = "Energy: " + str(Global.resources.energy)
	if iron_label:
		iron_label.text = "Iron: " + str(Global.resources.iron)
	if titanium_label:
		titanium_label.text = "Titanium: " + str(Global.resources.titanium)
	if uranium_label:
		uranium_label.text = "Uranium: " + str(Global.resources.uranium)
	if data_label:
		data_label.text = "Data: " + str(Global.resources.data)
	if hp_label:
		hp_label.text = "HP: " + str(Global.mothership_hp) + "/" + str(Global.max_mothership_hp)

# -----------------------------------------------
# Turn info
# -----------------------------------------------

func _update_turn_info() -> void:
	if turn_label and turn_manager:
		turn_label.text = "Turn: " + str(turn_manager.turn_number)
	if level_label:
		level_label.text = "LVL: " + str(Global.mothership_level) + " (XP: " + str(Global.xp) + "/" + str(Global.xp_to_next_level) + ")"
	if phase_label and turn_manager:
		phase_label.text = "Phase: " + turn_manager.Phase.keys()[turn_manager.current_phase].capitalize()

# -----------------------------------------------
# Printer slots
# -----------------------------------------------

func _update_printer_slots() -> void:
	if printer_manager == null:
		return
	for i in range(mini(3, printer_slots.size())):
		var job: Variant = printer_manager.slots[i]
		if job:
			printer_slots[i].value = printer_manager.get_job_progress(i) * 100
			printer_slots[i].get_node("Label").text = job.name
			printer_slots[i].visible = true
		else:
			printer_slots[i].visible = false

# -----------------------------------------------
# Phase changed handler
# -----------------------------------------------

func on_phase_changed(new_phase: int) -> void:
	update_ui()
	var is_planning: bool = (new_phase == turn_manager.Phase.PLANNING)
	if jump_button:
		jump_button.disabled = not is_planning
	if scan_button:
		scan_button.disabled = not is_planning
	if print_scout_btn:
		print_scout_btn.disabled = not is_planning
	if print_miner_btn:
		print_miner_btn.disabled = not is_planning
	if print_defender_btn:
		print_defender_btn.disabled = not is_planning

	if end_turn_button:
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

# -----------------------------------------------
# System panel / detailed info
# -----------------------------------------------

func _update_detailed_info() -> void:
	if not galaxy_map:
		return

	var s_idx: int = galaxy_map.selected_system_index
	if s_idx == -1:
		if system_panel:
			system_panel.visible = false
		return

	if system_panel:
		system_panel.visible = true

	# Mothership info (Fleet Overview)
	if s_idx == -2:
		system_title.text = "FLOTTE: MUTTERSCHIFF"
		var fleet_info: String = "[b]Einheiteninventar:[/b]\n"
		var scouts: int = printer_manager.inventory.get("scout_v1", 0)
		var miners: int = printer_manager.inventory.get("miner_v1", 0)
		var defenders: int = printer_manager.inventory.get("defender_v1", 0)

		fleet_info += "- Scouts: [color=cyan]" + str(scouts) + "[/color]\n"
		fleet_info += "- Miners: [color=green]" + str(miners) + "[/color]\n"
		fleet_info += "- Defenders: [color=red]" + str(defenders) + "[/color]\n\n"
		fleet_info += "[center][color=gray]System/Planet zum Einsatz auswählen[/color][/center]"
		system_content.text = fleet_info
		return

	var system: Dictionary = galaxy_map.systems[s_idx]

	if not system.scanned:
		system_title.text = "UNBEKANNTES SYSTEM"
		system_content.text = "[center]Keine Sensordaten verfügbar.\nBitte [color=yellow]Scan System[/color] durchführen.[/center]"
		return

	var p_idx: int = galaxy_map.selected_planet_index

	if p_idx == -1:
		_show_system_overview(s_idx, system)
	else:
		_show_planet_detail(s_idx, p_idx, system)

func _show_system_overview(s_idx: int, system: Dictionary) -> void:
	system_title.text = "SYSTEM: " + system.name.to_upper()
	var total_res: Dictionary = {"iron": 0, "titanium": 0, "uranium": 0}
	var total_miners: int = 0
	var planet_list: String = "[indent]"

	for i in range(system.planets.size()):
		var p: Dictionary = system.planets[i]
		var key: String = str(s_idx) + "," + str(i)
		var m_count: int = mining_manager.deployments.get(key, 0)
		total_miners += m_count

		planet_list += "[color=cyan]" + p.name + "[/color]: FE " + str(p.resources.iron)
		if p.resources.titanium > 0:
			planet_list += " | TI " + str(p.resources.titanium)
		if p.resources.uranium > 0:
			planet_list += " | U " + str(p.resources.uranium)
		if m_count > 0:
			planet_list += " ([color=green]Miners: " + str(m_count) + "[/color])"
		planet_list += "\n"

		for res in total_res:
			total_res[res] += p.resources[res]

	planet_list += "[/indent]"

	var summary: String = "[b]GESAMT RESSOURCEN:[/b]\n"
	summary += "FE: " + str(total_res.iron) + " | TI: " + str(total_res.titanium) + " | U: " + str(total_res.uranium) + "\n"
	summary += "TOTAL MINER: [color=green]" + str(total_miners) + "[/color]\n\n"

	if system.enemies.size() > 0:
		summary += "[b][color=red]BEDROHUNGEN ERKANNT:[/color][/b]\n"
		var enemy_counts: Dictionary = {}
		for e in system.enemies:
			enemy_counts[e.name] = enemy_counts.get(e.name, 0) + 1
		for e_name in enemy_counts:
			summary += "- " + e_name + " (x" + str(enemy_counts[e_name]) + ")\n"
		summary += "\n"

	summary += "[b]PLANETEN:[/b]\n" + planet_list
	system_content.text = summary

func _show_planet_detail(s_idx: int, p_idx: int, system: Dictionary) -> void:
	var planet: Dictionary = system.planets[p_idx]
	var key: String = str(s_idx) + "," + str(p_idx)
	var m_count: int = mining_manager.deployments.get(key, 0)

	system_title.text = "PLANET: " + planet.name.to_upper()
	var p_info: String = "[b]Detaillierte Analyse:[/b]\n"
	p_info += "- Eisen: " + str(planet.resources.iron) + "\n"
	p_info += "- Titan: " + str(planet.resources.titanium) + "\n"
	p_info += "- Uran: " + str(planet.resources.uranium) + "\n\n"
	p_info += "[b]Bergbau-Status:[/b]\n"
	p_info += "Aktive Drohnen: [color=green]" + str(m_count) + "[/color]\n\n"
	p_info += "[center][color=gray]Klick den Stern für systemweite Übersicht[/color][/center]"
	system_content.text = p_info

# -----------------------------------------------
# Scout button
# -----------------------------------------------

func _update_scout_button() -> void:
	if launch_scout_btn == null or galaxy_map == null:
		return

	var s_idx: int = galaxy_map.selected_system_index
	if s_idx < 0:
		launch_scout_btn.disabled = true
		return

	var system: Dictionary = galaxy_map.systems[s_idx]
	if system.scanned:
		launch_scout_btn.disabled = true
		return

	var m_pos: Vector3 = galaxy_map.systems[mothership.get_current_system()].position
	var t_pos: Vector3 = system.position
	var scout_data: Variant = Global.get_drone_by_id("scout_v1")
	var s_range: float = scout_data.stats.get("scan_range", 700)

	var in_range: bool = false
	if scout_manager and scout_manager.has_method("can_scout_system"):
		in_range = scout_manager.can_scout_system(m_pos, t_pos, s_range)
	var has_scout: bool = printer_manager.inventory.get("scout_v1", 0) > 0

	launch_scout_btn.disabled = not in_range or not has_scout or turn_manager.current_phase != turn_manager.Phase.PLANNING

	if not has_scout:
		launch_scout_btn.tooltip_text = "Keine Scouts im Inventar"
	elif not in_range:
		launch_scout_btn.tooltip_text = "Ziel außer Reichweite (> 800)"
	elif turn_manager.current_phase != turn_manager.Phase.PLANNING:
		launch_scout_btn.tooltip_text = "Nur in der Planungsphase möglich"
	else:
		launch_scout_btn.tooltip_text = "Scout starten"

# -----------------------------------------------
# Tooltips
# -----------------------------------------------

func show_drone_info(drone_id: String) -> void:
	var drone: Variant = Global.get_drone_by_id(drone_id)
	if drone and info_label:
		var cost_text: String = ""
		for res in drone.cost:
			cost_text += str(res).capitalize() + ": " + str(drone.cost[res]) + " "
		var build_time: int = drone.get("build_time", 2)
		info_label.text = drone.name + " (" + str(build_time) + " Runden) [" + cost_text + "]\n" + drone.description

func hide_info() -> void:
	if info_label:
		info_label.text = "Hover over a unit to see details..."

func show_jump_info() -> void:
	if info_label and mothership:
		var cost: int = mothership.jump_cost
		info_label.text = "JUMP DRIVE [Energie: " + str(cost) + "]\nBereite einen Sprung in ein benachbartes System vor."

# -----------------------------------------------
# Temporary message
# -----------------------------------------------

func show_temporary_message(msg: String) -> void:
	if combat_log_label == null:
		return
	combat_log_label.text = msg
	combat_log_label.visible = true
	await get_tree().create_timer(3.0).timeout
	combat_log_label.visible = false
