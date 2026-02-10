extends Node3D

class_name GalaxyMap3D

var systems = []
var connections = []
var system_meshes = []
var mothership_mesh: MeshInstance3D = null
var unit_indicators = {} # system_index -> [mesh1, mesh2...]

@export var system_count: int = 15
@export var spread_size: float = 50.0

var mothership_node: Node = null
var selected_system_index: int = -1
var selected_planet_index: int = -1 # -1 means no planet selected within system

var planet_meshes = {} # system_index -> [mesh1, mesh2...]
var orbit_meshes = {} # system_index -> [mesh1, mesh2...]

func _ready():
	generate_map_3d()
	if get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")

func generate_map_3d():
	print("Generating 3D galaxy map...")
	seed(42)
	
	# Create materials
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.5, 0.5)
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.2, 0.4, 0.6)
	
	for i in range(system_count):
		# Create data
		var system = {
			"index": i,
			"name": "System " + str(i),
			"position": Vector3(randf_range(-spread_size, spread_size), randf_range(-spread_size/5, spread_size/5), randf_range(-spread_size, spread_size)),
			"planets": [],
			"scanned": false
		}
		
		# Generate 2-5 planets
		var planet_count = randi_range(2, 5)
		for p in range(planet_count):
			var planet = {
				"index": p,
				"name": "Planet " + str(i) + "-" + str(p),
				"resources": {
					"iron": randi_range(100, 500),
					"titanium": randi_range(0, 100) if randf() > 0.5 else 0,
					"uranium": randi_range(0, 50) if randf() > 0.8 else 0
				},
				"orbit_radius": randf_range(4.0, 12.0),
				"orbit_speed": randf_range(0.2, 1.0),
				"phase": randf() * TAU
			}
			system.planets.append(planet)
			
		systems.append(system)
		
		# Create Mesh
		var sphere = MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		sphere.mesh.radius = 0.8
		sphere.mesh.height = 1.6
		sphere.position = system.position
		sphere.material_override = base_mat.duplicate()
		
		# Metadata for picking
		sphere.set_meta("system_index", i)
		
		add_child(sphere)
		system_meshes.append(sphere)
	
	# Connections
	for i in range(systems.size()):
		for j in range(i + 1, systems.size()):
			if systems[i].position.distance_to(systems[j].position) < 45: # Raised from 30
				connections.append([i, j])
				_draw_connection(systems[i].position, systems[j].position)
				
	_create_mothership_mesh()

func _create_mothership_mesh():
	mothership_mesh = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(1.5, 2.0, 1.0)
	mothership_mesh.mesh = prism
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1)
	mat.emission_energy_multiplier = 2.0
	mothership_mesh.material_override = mat
	
	add_child(mothership_mesh)
	update_selection_visuals()

func update_selection_visuals():
	# Update star colors
	for i in range(system_meshes.size()):
		var mat = system_meshes[i].material_override
		if i == selected_system_index:
			mat.emission = Color(0, 0.8, 1.0)
			mat.emission_energy_multiplier = 2.0
		elif systems[i].scanned:
			mat.emission = Color(0.1, 0.6, 0.1)
			mat.emission_energy_multiplier = 1.0
		else:
			mat.emission = Color(0.2, 0.4, 0.6)
			mat.emission_energy_multiplier = 0.5
			
	# Move & Highlight Mothership
	if mothership_node and mothership_mesh:
		var current_idx = mothership_node.get_current_system()
		var target_pos = systems[current_idx].position + Vector3(0, 3, 0)
		mothership_mesh.position = target_pos
		
		var ms_mat = mothership_mesh.material_override
		if selected_system_index == -2:
			ms_mat.emission = Color(0, 0.8, 1.0) # Highlight cyan
			ms_mat.emission_energy_multiplier = 4.0
		else:
			ms_mat.emission = Color(1.0, 0.8, 0.1) # Default gold
			ms_mat.emission_energy_multiplier = 2.0
		
	# Update Miner indicators
	_update_unit_indicators()
	_update_planet_meshes()

func _update_planet_meshes():
	# Clear planets of non-selected systems to save performance
	# but for now let's just show planets for the current and selected system
	var active_systems = []
	if mothership_node: active_systems.append(mothership_node.get_current_system())
	if selected_system_index != -1: active_systems.append(selected_system_index)
	
	# Clear all planet and orbit meshes first
	for sys_idx in planet_meshes:
		for mesh in planet_meshes[sys_idx]:
			mesh.queue_free()
	planet_meshes.clear()
	
	for sys_idx in orbit_meshes:
		for mesh in orbit_meshes[sys_idx]:
			mesh.queue_free()
	orbit_meshes.clear()
	
	for sys_idx in active_systems:
		var system = systems[sys_idx]
		if not system.scanned: continue # DO NOT SHOW PLANETS IF NOT SCANNED
		
		planet_meshes[sys_idx] = []
		for p_idx in range(system.planets.size()):
			var p_data = system.planets[p_idx]
			var planet_node = MeshInstance3D.new()
			planet_node.mesh = SphereMesh.new()
			planet_node.mesh.radius = 0.4
			planet_node.mesh.height = 0.8
			
			var mat = StandardMaterial3D.new()
			# Determine color based on resources
			if p_idx == selected_planet_index:
				mat.albedo_color = Color(0, 0.8, 1.0)
				mat.emission_enabled = true
				mat.emission = Color(0, 0.4, 0.8)
			elif p_data.resources.uranium > 0: 
				mat.albedo_color = Color(0.1, 0.8, 0.1)
			elif p_data.resources.titanium > 0: 
				mat.albedo_color = Color(0.8, 0.8, 0.9)
			else: 
				mat.albedo_color = Color(0.7, 0.4, 0.2)
			
			planet_node.material_override = mat
			planet_node.set_meta("system_index", sys_idx)
			planet_node.set_meta("planet_index", p_idx)
			
			add_child(planet_node)
			planet_meshes[sys_idx].append(planet_node)
			
			# Add orbit line
			_draw_orbit_path(sys_idx, p_data.orbit_radius)

func _draw_orbit_path(sys_idx: int, radius: float):
	if not orbit_meshes.has(sys_idx): orbit_meshes[sys_idx] = []
	
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.4, 0.5, 0.15) # Very faint blue/grey
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = systems[sys_idx].position
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	var steps = 64
	for i in range(steps + 1):
		var angle = i * (TAU / steps)
		immediate_mesh.surface_add_vertex(Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	immediate_mesh.surface_end()
	
	add_child(mesh_instance)
	orbit_meshes[sys_idx].append(mesh_instance)

func _update_unit_indicators():
	# Clear old
	for sys_idx in unit_indicators:
		for mesh in unit_indicators[sys_idx]:
			mesh.queue_free()
	unit_indicators.clear()
	
	var managers = get_parent().get_node("Managers")
	var mining_manager = managers.get_node("MiningManager")
	
	var miner_mat = StandardMaterial3D.new()
	miner_mat.albedo_color = Color(0.2, 1.0, 0.2)
	miner_mat.emission_enabled = true
	miner_mat.emission = Color(0.2, 1.0, 0.2)
	miner_mat.emission_energy_multiplier = 3.0
	
	for key in mining_manager.deployments:
		var count = mining_manager.deployments[key]
		var parts = key.split(",")
		var s_idx = int(parts[0])
		
		# Only show if system is active (selected or current)
		var is_active = (s_idx == selected_system_index)
		if mothership_node: is_active = is_active or (s_idx == mothership_node.get_current_system())
		if not is_active: continue
		
		unit_indicators[key] = []
		
		for k in range(count):
			var box = MeshInstance3D.new()
			var cube = BoxMesh.new()
			cube.size = Vector3(0.3, 0.3, 0.3)
			box.mesh = cube
			box.material_override = miner_mat
			
			add_child(box)
			unit_indicators[key].append(box)

func _process(_delta):
	# Update planet positions (orbits)
	var time = Time.get_ticks_msec() * 0.001
	for sys_idx in planet_meshes:
		var sys_pos = systems[sys_idx].position
		for p_idx in range(planet_meshes[sys_idx].size()):
			var p_mesh = planet_meshes[sys_idx][p_idx]
			var p_data = systems[sys_idx].planets[p_idx]
			
			var angle = p_data.phase + time * p_data.orbit_speed
			var offset = Vector3(cos(angle), 0, sin(angle)) * p_data.orbit_radius
			p_mesh.position = sys_pos + offset
			
	# Update miner positions (orbiting their planets)
	for key in unit_indicators:
		var parts = key.split(",")
		var s_idx = int(parts[0])
		var p_idx = int(parts[1])
		
		if planet_meshes.has(s_idx) and p_idx < planet_meshes[s_idx].size():
			var p_mesh = planet_meshes[s_idx][p_idx]
			var meshes = unit_indicators[key]
			for k in range(meshes.size()):
				var angle = k * (TAU / max(1, meshes.size())) + time * 2.0
				var offset = Vector3(cos(angle), 0.5, sin(angle)) * 0.8
				meshes[k].position = p_mesh.position + offset

func is_system_connected(a: int, b: int) -> bool:
	for conn in connections:
		if (conn[0] == a and conn[1] == b) or (conn[0] == b and conn[1] == a):
			return true
	return false

func _draw_connection(start: Vector3, end: Vector3):
	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	
	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()
	
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.6, 1.0, 0.5) # Brighter blue
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	add_child(mesh_instance)
