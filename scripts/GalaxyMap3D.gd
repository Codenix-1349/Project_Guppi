extends Node3D

class_name GalaxyMap3D

var systems = []
var connections = []
var system_meshes = []
var mothership_mesh: Node3D = null
var unit_indicators = {} # key "sys,planet" -> [mesh1, mesh2...]

@export var system_count: int = 15
@export var spread_size: float = 50.0

# ✅ Enemy encounter chance per system (~1/4–1/5)
@export var enemy_spawn_chance: float = 0.22

var mothership_node: Node = null
var selected_system_index: int = -1
var selected_planet_index: int = -1 # -1 means no planet selected within system

var planet_meshes = {} # system_index -> [mesh1, mesh2...]
var orbit_meshes = {} # system_index -> [mesh1, mesh2...]

const MODEL_PATH = "res://kenney_space-kit/Models/GLTF format/"

var _generated := false

func _ready():
	if get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")
	generate_map_3d()

func generate_map_3d():
	if _generated:
		return
	_generated = true

	print("Generating 3D galaxy map...")
	seed(42)

	# Clear old data (in case)
	systems.clear()
	connections.clear()
	system_meshes.clear()

	# Clear old children (optional: leave starfield)
	for c in get_children():
		c.queue_free()

	# Create materials
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.5, 0.5)
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.2, 0.4, 0.6)
	base_mat.emission_energy_multiplier = 1.0

	for i in range(system_count):
		# Create data
		var system = {
			"index": i,
			"name": "System " + str(i),
			"position": Vector3(
				randf_range(-spread_size, spread_size),
				randf_range(-spread_size/5, spread_size/5),
				randf_range(-spread_size, spread_size)
			),
			"planets": [],
			"scanned": false,
			"enemies": [],
			"star_type": _get_random_star_type()
		}

		# ✅ Spawn enemies (adjustable chance)
		if i > 1 and randf() < enemy_spawn_chance and Global.enemies_data.size() > 0:
			var enemy_type = Global.enemies_data[randi() % Global.enemies_data.size()]
			var count = randi_range(1, 4)
			for c in range(count):
				var e = enemy_type.duplicate(true)

				# Ensure combat fields exist: hp/max_hp = durability
				if not e.has("max_hp"):
					var dur = 10
					if e.has("stats") and e.stats.has("durability"):
						dur = int(e.stats.durability)
					e["max_hp"] = max(1, dur)
				if not e.has("hp"):
					e["hp"] = int(e["max_hp"])

				system.enemies.append(e)

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

		# Create star mesh
		var sphere = MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		sphere.position = system.position

		var star_visuals = _get_star_visuals(system.star_type)
		var mat := base_mat.duplicate() as StandardMaterial3D
		mat.emission = star_visuals.color
		mat.emission_energy_multiplier = 0.5
		sphere.material_override = mat

		var sm := sphere.mesh as SphereMesh
		sm.radius = star_visuals.size
		sm.height = star_visuals.size * 2.0

		sphere.set_meta("system_index", i)
		add_child(sphere)
		system_meshes.append(sphere)

	# Connections
	for i in range(systems.size()):
		for j in range(i + 1, systems.size()):
			if systems[i].position.distance_to(systems[j].position) < 45:
				connections.append([i, j])
				_draw_connection(systems[i].position, systems[j].position)

	_create_mothership_mesh()
	_create_starfield()
	update_selection_visuals()

func _create_starfield():
	var star_count = 600
	var container = Node3D.new()
	container.name = "Starfield"
	add_child(container)

	var star_mesh = PointMesh.new()
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.use_point_size = true
	mat.point_size = 2.0
	mat.vertex_color_use_as_albedo = true

	var multi_mesh = MultiMesh.new()
	multi_mesh.mesh = star_mesh
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.instance_count = star_count

	for i in range(star_count):
		var pos = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * 500.0
		var xform = Transform3D(Basis(), pos)
		multi_mesh.set_instance_transform(i, xform)

		var c = Color(0.8, 0.9, 1.0)
		if randf() > 0.7: c = Color(1.0, 1.0, 0.8)
		elif randf() > 0.9: c = Color(1.0, 0.8, 0.8)
		multi_mesh.set_instance_color(i, c)

	var mm_instance = MultiMeshInstance3D.new()
	mm_instance.multimesh = multi_mesh
	mm_instance.material_override = mat
	container.add_child(mm_instance)

func _create_mothership_mesh():
	var ship_scene = load(MODEL_PATH + "craft_cargoA.glb")
	if ship_scene:
		mothership_mesh = ship_scene.instantiate()
		add_child(mothership_mesh)
		mothership_mesh.scale = Vector3(2, 2, 2)
	else:
		mothership_mesh = MeshInstance3D.new()
		mothership_mesh.mesh = PrismMesh.new()
		(mothership_mesh.mesh as PrismMesh).size = Vector3(1.5, 2.0, 1.0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.1)
		mothership_mesh.material_override = mat
		add_child(mothership_mesh)

	update_selection_visuals()

func update_selection_visuals():
	# Update star colors
	for i in range(system_meshes.size()):
		var mat = system_meshes[i].material_override
		if i == selected_system_index:
			mat.emission_energy_multiplier = 4.0
		elif systems[i].scanned:
			mat.emission_energy_multiplier = 2.0
		else:
			mat.emission_energy_multiplier = 0.5

	# Move & highlight mothership
	if mothership_node and mothership_mesh:
		var current_idx = mothership_node.get_current_system()
		var target_pos = systems[current_idx].position + Vector3(0, 3, 0)
		mothership_mesh.position = target_pos

		if mothership_mesh is MeshInstance3D:
			var ms_mat = (mothership_mesh as MeshInstance3D).material_override
			if selected_system_index == -2:
				ms_mat.emission = Color(0, 0.8, 1.0)
				ms_mat.emission_energy_multiplier = 4.0
			else:
				ms_mat.emission = Color(1.0, 0.8, 0.1)
				ms_mat.emission_energy_multiplier = 2.0

	_update_unit_indicators()
	_update_planet_meshes()

func _update_planet_meshes():
	var active_systems = []
	if mothership_node: active_systems.append(mothership_node.get_current_system())
	if selected_system_index != -1: active_systems.append(selected_system_index)

	# Clear old
	for sys_idx in planet_meshes:
		for mesh in planet_meshes[sys_idx]:
			if is_instance_valid(mesh):
				mesh.queue_free()
	planet_meshes.clear()

	for sys_idx in orbit_meshes:
		for mesh in orbit_meshes[sys_idx]:
			if is_instance_valid(mesh):
				mesh.queue_free()
	orbit_meshes.clear()

	for sys_idx in active_systems:
		if sys_idx < 0 or sys_idx >= systems.size():
			continue
		var system = systems[sys_idx]
		if not system.scanned:
			continue

		planet_meshes[sys_idx] = []
		for p_idx in range(system.planets.size()):
			var p_data = system.planets[p_idx]
			var planet_node = MeshInstance3D.new()
			planet_node.mesh = SphereMesh.new()
			(planet_node.mesh as SphereMesh).radius = 0.4
			(planet_node.mesh as SphereMesh).height = 0.8

			var is_selected = (p_idx == selected_planet_index and sys_idx == selected_system_index)
			planet_node.material_override = _get_planet_material(p_data, is_selected)

			planet_node.set_meta("system_index", sys_idx)
			planet_node.set_meta("planet_index", p_idx)

			add_child(planet_node)
			planet_meshes[sys_idx].append(planet_node)

			if is_selected:
				_add_selection_ring(planet_node)

			_draw_orbit_path(sys_idx, p_data.orbit_radius)

func _get_planet_material(p_data, is_selected):
	var mat = StandardMaterial3D.new()

	var noise = FastNoiseLite.new()
	noise.seed = p_data.name.hash()
	noise.frequency = 0.05

	var noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise

	mat.albedo_texture = noise_tex

	if p_data.resources.uranium > 0:
		mat.albedo_color = Color(0.2, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.3, 0.1)
	elif p_data.resources.titanium > 0:
		mat.albedo_color = Color(0.6, 0.6, 0.7)
		mat.metallic = 0.8
		mat.roughness = 0.2
	else:
		mat.albedo_color = Color(0.7, 0.4, 0.2)
		mat.roughness = 0.9

	if is_selected:
		mat.emission_enabled = true
		mat.emission = Color(0, 0.6, 1.0)
		mat.emission_energy_multiplier = 1.5

	return mat

func _add_selection_ring(parent_node):
	var bracket_scene = Node3D.new()
	parent_node.add_child(bracket_scene)

	for i in range(4):
		var line = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.05, 0.2, 0.05)
		line.mesh = box

		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0, 0.8, 1.0)
		line.material_override = mat

		bracket_scene.add_child(line)

		var angle = deg_to_rad(45 + i * 90)
		line.position = Vector3(cos(angle) * 0.7, 0, sin(angle) * 0.7)
		line.rotation_degrees = Vector3(0, -rad_to_deg(angle), 0)

func _get_random_star_type():
	var roll = randf()
	if roll < 0.01: return "O"
	if roll < 0.05: return "B"
	if roll < 0.15: return "A"
	if roll < 0.30: return "F"
	if roll < 0.50: return "G"
	if roll < 0.75: return "K"
	return "M"

func _get_star_visuals(type):
	match type:
		"O": return {"color": Color(0.2, 0.5, 1.0), "size": 2.5}
		"B": return {"color": Color(0.5, 0.7, 1.0), "size": 1.8}
		"A": return {"color": Color(1.0, 1.0, 1.0), "size": 1.4}
		"F": return {"color": Color(1.0, 1.0, 0.8), "size": 1.2}
		"G": return {"color": Color(1.0, 0.9, 0.3), "size": 1.0}
		"K": return {"color": Color(1.0, 0.6, 0.2), "size": 0.8}
		"M": return {"color": Color(1.0, 0.3, 0.1), "size": 0.6}
	return {"color": Color(1, 1, 1), "size": 1.0}

func _draw_orbit_path(sys_idx: int, radius: float):
	if not orbit_meshes.has(sys_idx):
		orbit_meshes[sys_idx] = []

	var mesh_instance = MeshInstance3D.new()
	var immediate_mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.4, 0.5, 0.15)
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
	for key in unit_indicators:
		for mesh in unit_indicators[key]:
			if is_instance_valid(mesh):
				mesh.queue_free()
	unit_indicators.clear()

	if not get_parent().has_node("Managers"):
		return

	var managers = get_parent().get_node("Managers")
	if not managers.has_node("MiningManager"):
		return

	var mining_manager = managers.get_node("MiningManager")
	var miner_scene = load(MODEL_PATH + "craft_miner.glb")

	for key in mining_manager.deployments:
		var count = mining_manager.deployments[key]
		var parts = key.split(",")
		var s_idx = int(parts[0])

		var is_active = (s_idx == selected_system_index)
		if mothership_node:
			is_active = is_active or (s_idx == mothership_node.get_current_system())
		if not is_active:
			continue

		unit_indicators[key] = []

		for k in range(count):
			var miner_node
			if miner_scene:
				miner_node = miner_scene.instantiate()
				miner_node.scale = Vector3(0.5, 0.5, 0.5)
			else:
				miner_node = MeshInstance3D.new()
				miner_node.mesh = BoxMesh.new()
				(miner_node.mesh as BoxMesh).size = Vector3(0.3, 0.3, 0.3)
			add_child(miner_node)
			unit_indicators[key].append(miner_node)

func _process(_delta):
	var time = Time.get_ticks_msec() * 0.001

	for sys_idx in planet_meshes:
		var sys_pos = systems[sys_idx].position
		for p_idx in range(planet_meshes[sys_idx].size()):
			var p_mesh = planet_meshes[sys_idx][p_idx]
			var p_data = systems[sys_idx].planets[p_idx]
			var angle = p_data.phase + time * p_data.orbit_speed
			var offset = Vector3(cos(angle), 0, sin(angle)) * p_data.orbit_radius
			p_mesh.position = sys_pos + offset

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
	material.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	add_child(mesh_instance)
