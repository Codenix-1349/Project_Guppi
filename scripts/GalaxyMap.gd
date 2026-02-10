extends Node2D

class_name GalaxyMap

var systems = []
var connections = []

var mothership_node: Node = null
var selected_system_index: int = -1

func _ready():
	generate_map(12)
	if get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")

func generate_map(num_systems: int):
	print("Generating galaxy map with ", num_systems, " systems...")
	seed(42)
	for i in range(num_systems):
		var system = {
			"index": i,
			"name": "System " + str(i),
			"position": Vector2(randf_range(100, 1100), randf_range(100, 600)),
			"resources": {
				"raw_ore": randi_range(50, 200),
				"rare_metals": randi_range(0, 20)
			},
			"scanned": false
		}
		systems.append(system)
	
	for i in range(systems.size()):
		for j in range(i + 1, systems.size()):
			if systems[i].position.distance_to(systems[j].position) < 350:
				connections.append([i, j])
	
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_local_mouse_position()
		_check_click(mouse_pos)

func _check_click(pos: Vector2):
	for i in range(systems.size()):
		if pos.distance_to(systems[i].position) < 20:
			selected_system_index = i
			_on_system_selected(i)
			queue_redraw()
			return

func _on_system_selected(_index: int):
	pass

func is_system_connected(a: int, b: int) -> bool:
	for conn in connections:
		if (conn[0] == a and conn[1] == b) or (conn[0] == b and conn[1] == a):
			return true
	return false

func _draw():
	# Draw connections with subtle glow
	for conn in connections:
		var color = Color(0.2, 0.4, 0.6, 0.3)
		var thickness = 1.0
		if selected_system_index != -1 and ((conn[0] == selected_system_index) or (conn[1] == selected_system_index)):
			color = Color(0.4, 0.8, 1.0, 0.8)
			thickness = 2.0
		
		draw_line(systems[conn[0]].position, systems[conn[1]].position, color, thickness)
	
	# Draw systems
	for i in range(systems.size()):
		var system = systems[i]
		
		# Base color
		var dot_color = Color(0.5, 0.5, 0.5)
		if system.scanned:
			dot_color = Color(0.8, 1.0, 0.8) # Scanned systems are soft green
		
		# Mothership highlight (Glow circle)
		if mothership_node and mothership_node.get_current_system() == i:
			draw_circle(system.position, 12, Color(1, 0.8, 0, 0.2)) # Outer glow
			draw_arc(system.position, 14, 0, TAU, 32, Color(1, 0.9, 0.2, 0.8), 2.0)
		
		# Selection highlight
		if selected_system_index == i:
			draw_circle(system.position, 10, Color(0, 0.8, 1, 0.15))
			draw_arc(system.position, 12, 0, TAU, 32, Color(0, 0.8, 1, 1.0), 1.5)
			
		# Drawing the actual system node
		draw_circle(system.position, 6, dot_color)
		
		# Tactical ring
		draw_arc(system.position, 8, 0, TAU, 32, dot_color.darkened(0.5), 1.0)
		
		# RESOURCE DISPLAY
		if system.scanned:
			var res_text = "Ore: " + str(system.resources.raw_ore)
			draw_string(ThemeDB.fallback_font, system.position + Vector2(12, 18), res_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.6, 0.2, 0.7))
			
			# SHOW ACTIVE MINERS
			var managers = get_parent().get_node("Managers")
			var mining_manager = managers.get_node("MiningManager")
			if mining_manager.deployments.has(i):
				var count = mining_manager.deployments[i]
				draw_string(ThemeDB.fallback_font, system.position + Vector2(12, -12), "Miners: " + str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.2, 1, 0.2))
