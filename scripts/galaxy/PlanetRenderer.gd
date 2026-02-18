extends Node
class_name PlanetRenderer

# Manages planets, orbits, mining indicators, and planet selection visuals
# Extracted from GalaxyMap3D

const PLANET_SCENE_BASE: String = "res://addons/naejimer_3d_planet_generator/scenes/"

# Weighted planet type distribution — seeded by planet name for consistency
const PLANET_TYPES: Array[String] = [
	"planet_terrestrial.tscn",   # Earth-like
	"planet_ice.tscn",           # Ice world
	"planet_lava.tscn",          # Volcanic
	"planet_sand.tscn",          # Desert
	"planet_gaseous.tscn",       # Gas giant
	"planet_no_atmosphere.tscn"  # Barren
]

var _map_root: Node3D

# Internal caches
var _planet_meshes: Dictionary = {}  # sys_idx -> Array[Node3D]
var _orbit_meshes: Dictionary = {}   # sys_idx -> Array[MeshInstance3D]
var _unit_indicators: Dictionary = {} # "s,p" -> Array[Node3D]
var _planet_ring_nodes: Dictionary = {} # "s,p" -> Node3D

func _init(map_root: Node3D) -> void:
	_map_root = map_root

# ----------------------------
# Core Update Logic
# ----------------------------

func update_planets(systems: Array, active_system_indices: Array) -> void:
	# Clear inactive systems
	for k in _planet_meshes.keys():
		var sys_idx: int = int(k)
		if !active_system_indices.has(sys_idx):
			_clear_planet_visuals(sys_idx)
	
	# Create/Update active systems
	for sys_idx in active_system_indices:
		var sys: Dictionary = systems[sys_idx]
		
		# Only show planets if scanned (or if it's the current system/selected system logic handled by caller)
		# The caller passes active_system_indices which should already filter for visibility
		# But we double check "scanned" if that's a requirement (caller usually handles logic)
		if !bool(sys["scanned"]):
			_clear_planet_visuals(sys_idx)
			continue

		if !_planet_meshes.has(sys_idx):
			_create_system_planets(sys, sys_idx)

func process_orbits(time: float, systems: Array) -> void:
	for sys_idx_key in _planet_meshes.keys():
		var s_idx: int = int(sys_idx_key)
		if s_idx < 0 or s_idx >= systems.size(): continue
		
		var sys_pos: Vector3 = systems[s_idx]["position"]
		var sys: Dictionary = systems[s_idx]
		var planets: Array = sys["planets"]

		var arr: Array = _planet_meshes[sys_idx_key]
		for p_idx in range(arr.size()):
			var p_mesh: Node3D = arr[p_idx] as Node3D
			if p_mesh == null or !is_instance_valid(p_mesh):
				continue

			var p_data: Dictionary = planets[p_idx]
			var angle_p: float = float(p_data["phase"]) + time * float(p_data["orbit_speed"])
			var offset_p: Vector3 = Vector3(cos(angle_p), 0, sin(angle_p)) * float(p_data["orbit_radius"])
			p_mesh.position = sys_pos + offset_p

	# Move miner indicators
	for key in _unit_indicators.keys():
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2: continue

		var s_idx2: int = int(parts[0])
		var p_idx2: int = int(parts[1])

		if _planet_meshes.has(s_idx2) and p_idx2 >= 0 and p_idx2 < (_planet_meshes[s_idx2] as Array).size():
			var p_mesh2: Node3D = (_planet_meshes[s_idx2] as Array)[p_idx2] as Node3D
			if p_mesh2 == null or !is_instance_valid(p_mesh2):
				continue

			var meshes: Array = _unit_indicators[key]
			var denom: float = maxf(1.0, float(meshes.size()))

			for k2 in range(meshes.size()):
				var miner_node: Node3D = meshes[k2]
				if miner_node == null or !is_instance_valid(miner_node):
					continue

				var angle_m: float = float(k2) * (TAU / denom) + time * 2.0
				var offset_m: Vector3 = Vector3(cos(angle_m), 0.5, sin(angle_m)) * 0.8
				miner_node.position = p_mesh2.position + offset_m

func refresh_selection(selected_sys: int, selected_planet: int) -> void:
	for sys_key in _planet_meshes.keys():
		var idx: int = int(sys_key)
		var arr: Array = _planet_meshes[idx]
		
		for p_idx in range(arr.size()):
			var planet_node: Node3D = arr[p_idx] as Node3D
			if planet_node == null or !is_instance_valid(planet_node):
				continue

			var is_selected: bool = (idx == selected_sys and p_idx == selected_planet)

			# Selection ring
			var key: String = "%d,%d" % [idx, p_idx]
			if is_selected:
				if !_planet_ring_nodes.has(key) or !is_instance_valid(_planet_ring_nodes[key]):
					_planet_ring_nodes[key] = _add_selection_ring(planet_node)
					_planet_ring_nodes[key].set_meta("_gen", true)
			else:
				if _planet_ring_nodes.has(key) and is_instance_valid(_planet_ring_nodes[key]):
					(_planet_ring_nodes[key] as Node).queue_free()
				_planet_ring_nodes.erase(key)

			# Selection glow (Atmosphere shader emit)
			var atmo: MeshInstance3D = planet_node.get_node_or_null("Atmosphere") as MeshInstance3D
			if atmo and atmo.mesh:
				var mat: ShaderMaterial = atmo.mesh.material as ShaderMaterial
				if mat == null and atmo.material_override is ShaderMaterial:
					mat = atmo.material_override as ShaderMaterial
				
				if mat:
					if is_selected:
						mat.set_shader_parameter("emit", true)
						mat.set_shader_parameter("intensity", 8.0)
						mat.set_shader_parameter("color_2", Color(0.3, 0.7, 1.0))
					else:
						mat.set_shader_parameter("emit", false)
						mat.set_shader_parameter("intensity", 4.0)

func update_unit_indicators(mining_manager_deployments: Dictionary) -> void:
	# clear old
	for k in _unit_indicators.keys():
		for mesh in _unit_indicators[k]:
			if is_instance_valid(mesh):
				(mesh as Node).queue_free()
	_unit_indicators.clear()

	var miner_scene = load("res://kenney_space-kit/Models/GLTF format/craft_miner.glb")

	for key in mining_manager_deployments:
		var count: int = int(mining_manager_deployments[key])
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2: continue

		var s_idx: int = int(parts[0])
		# Only Create if planet mesh exists (system active)
		if !_planet_meshes.has(s_idx):
			continue
			
		if !_unit_indicators.has(key):
			_unit_indicators[key] = []

		for _c in range(count):
			var miner_node: Node3D
			if miner_scene:
				miner_node = (miner_scene as PackedScene).instantiate()
				miner_node.scale = Vector3(0.5, 0.5, 0.5)
			else:
				# fallback
				var fallback: MeshInstance3D = MeshInstance3D.new()
				var pm: PrismMesh = PrismMesh.new()
				pm.size = Vector3(0.3, 0.5, 0.3)
				fallback.mesh = pm
				var miner_mat: StandardMaterial3D = StandardMaterial3D.new()
				miner_mat.albedo_color = Color(0.2, 1.0, 0.2)
				miner_mat.emission_enabled = true
				miner_mat.emission = Color(0.2, 1.0, 0.2)
				fallback.material_override = miner_mat
				miner_node = fallback

			miner_node.set_meta("_gen", true)
			_map_root.add_child(miner_node)
			(_unit_indicators[key] as Array).append(miner_node)

func clear_all() -> void:
	for k in _planet_meshes.keys():
		_clear_planet_visuals(k)
	_planet_meshes.clear()
	_orbit_meshes.clear()
	_planet_ring_nodes.clear()
	_unit_indicators.clear()

# ----------------------------
# Internal Implementation
# ----------------------------

func _create_system_planets(sys: Dictionary, sys_idx: int) -> void:
	_planet_meshes[sys_idx] = []
	_orbit_meshes[sys_idx] = []
	
	var planets: Array = sys["planets"]
	for p_idx in range(planets.size()):
		var p_data: Dictionary = planets[p_idx]

		# Instantiate procedural planet scene from addon
		var scene_path: String = _get_planet_scene_path(p_data)
		var scene_res: Variant = load(scene_path)
		var planet_node: Node3D
		
		if scene_res != null and scene_res is PackedScene:
			planet_node = (scene_res as PackedScene).instantiate()
			# Reset baked transform → identity, then uniform scale
			planet_node.transform = Transform3D.IDENTITY
			planet_node.scale = Vector3(0.8, 0.8, 0.8) # SphereMesh default r=0.5 → 0.4
		else:
			# Fallback: basic sphere
			var fb: MeshInstance3D = MeshInstance3D.new()
			var sm: SphereMesh = SphereMesh.new()
			sm.radius = 0.4
			sm.height = 0.8
			fb.mesh = sm
			planet_node = fb

		planet_node.set_meta("_gen", true)
		planet_node.set_meta("system_index", sys_idx)
		planet_node.set_meta("planet_index", p_idx)
		planet_node.set_meta("pick_type", "planet")

		# Vary rotation speed
		var anim_tree: AnimationTree = planet_node.get_node_or_null("AnimationTree") as AnimationTree
		if anim_tree:
			var seed_val: int = int(abs(str(p_data["name"]).hash())) % 100
			var speed: float = 0.04 + float(seed_val) * 0.001 
			anim_tree.set("parameters/TimeScale/scale", speed)

		_map_root.add_child(planet_node)
		(_planet_meshes[sys_idx] as Array).append(planet_node)

		# Flattened pick sphere attach
		_attach_pick_sphere(planet_node, 0.5, "planet", {"system_index": sys_idx, "planet_index": p_idx})

		_draw_orbit_path(sys_idx, float(p_data["orbit_radius"]), sys["position"])

func _clear_planet_visuals(sys_idx: int) -> void:
	if _planet_meshes.has(sys_idx):
		for n in _planet_meshes[sys_idx]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		_planet_meshes.erase(sys_idx)
	
	if _orbit_meshes.has(sys_idx):
		for n in _orbit_meshes[sys_idx]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		_orbit_meshes.erase(sys_idx)
		
	# Clear rings for this system
	var keys := _planet_ring_nodes.keys()
	for k in keys:
		var parts := str(k).split(",")
		if parts.size() == 2 and int(parts[0]) == sys_idx:
			if is_instance_valid(_planet_ring_nodes[k]):
				(_planet_ring_nodes[k] as Node).queue_free()
			_planet_ring_nodes.erase(k)

func _get_planet_scene_path(p_data: Dictionary) -> String:
	# Equal distribution — purely visual, decoupled from resources
	var seed_hash: int = int(abs(str(p_data.get("name", "planet")).hash()))
	var type_idx: int = seed_hash % PLANET_TYPES.size()
	return PLANET_SCENE_BASE + PLANET_TYPES[type_idx]

func _draw_orbit_path(sys_idx: int, radius: float, center_pos: Vector3) -> void:
	if !_orbit_meshes.has(sys_idx):
		_orbit_meshes[sys_idx] = []

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.set_meta("_gen", true)

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.4, 0.5, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = center_pos

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	var steps: int = 64
	for i in range(steps + 1):
		var ang: float = float(i) * (TAU / float(steps))
		immediate_mesh.surface_add_vertex(Vector3(cos(ang) * radius, 0, sin(ang) * radius))
	immediate_mesh.surface_end()

	_map_root.add_child(mesh_instance)
	(_orbit_meshes[sys_idx] as Array).append(mesh_instance)

func _add_selection_ring(parent_node: Node3D) -> Node3D:
	var bracket_scene: Node3D = Node3D.new()
	bracket_scene.name = "SelectionBrackets"
	parent_node.add_child(bracket_scene)

	for i in range(4):
		var line: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.05, 0.2, 0.05)
		line.mesh = box

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.0, 0.8, 1.0)
		line.material_override = mat

		bracket_scene.add_child(line)

		var angle: float = deg_to_rad(45.0 + float(i) * 90.0)
		line.position = Vector3(cos(angle) * 0.7, 0, sin(angle) * 0.7)
		line.rotation_degrees = Vector3(0, -rad_to_deg(angle), 0)

	return bracket_scene

func _attach_pick_sphere(target: Node3D, radius: float, pick_type: String, meta: Dictionary = {}) -> void:
	if target == null: return
	
	if target.has_node("PickArea"):
		target.get_node("PickArea").queue_free()

	var area: Area3D = Area3D.new()
	area.name = "PickArea"
	area.set_meta("pick_type", pick_type)
	for k in meta.keys():
		area.set_meta(k, meta[k])
	
	# Fix: Set collision layer to match SelectionHandler raycast (Bit 10)
	area.collision_layer = 1 << 10
	area.collision_mask = 0

	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = maxf(0.01, radius)
	cs.shape = sph
	
	area.add_child(cs)
	target.add_child(area)
