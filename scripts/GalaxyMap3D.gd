# === scripts/GalaxyMap3D.gd ===
extends Node3D
class_name GalaxyMap3D

# Coordinator script that uses sub-modules for rendering
# Preserves public API for Main.gd and SelectionHandler

# ----------------------------
# Modules
# ----------------------------
var star_renderer: Node
var planet_renderer: Node
var connection_generator: Node

# ----------------------------
# Data
# ----------------------------

var systems: Array = []
var connections: Array = []

# Expose render cache for SelectionHandler
# Aliased to modules in _ready
var system_meshes: Array[Node3D] = []
var planet_meshes: Dictionary:
	get: return planet_renderer._planet_meshes if planet_renderer else {}

var mothership_mesh: Node3D = null

# key "s,p" -> Array[Node3D] (miner indicators)
var unit_indicators: Dictionary:
	get: return planet_renderer._unit_indicators if planet_renderer else {}

# Selection state
var mothership_node: Node = null
var selected_system_index: int = -1
var selected_planet_index: int = -1

var _rng_layout: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_encounters: RandomNumberGenerator = RandomNumberGenerator.new()

# Random start (read by Main.gd)
var start_system_index: int = 0

# ----------------------------
# Export tuning
# ----------------------------

@export var system_count: int = 28

# Galaxy shape (ellipse X/Z) + thickness Y
@export var spread_x: float = 85.0
@export var spread_z: float = 60.0
@export var spread_y: float = 18.0

# Enemies
@export var enemy_spawn_chance: float = 0.22
@export var enemy_min_count: int = 1
@export var enemy_max_count: int = 4

# Enemy scaling with distance from start
@export var enemy_scale_strength: float = 0.75

# Connections
@export var connect_max_dist: float = 55.0
@export var min_links_per_system: int = 1
@export var extra_link_chance: float = 0.10
@export var hard_max_links: int = 4
@export var heavy_degree_ratio: float = 0.15 

# Spiral galaxy look
@export var arm_count: int = 3
@export var arm_twist: float = 2.6
@export var arm_spread: float = 0.55
@export var core_radius: float = 12.0
@export var core_ratio: float = 0.18
@export var y_scale: float = 1.55

# Optional deterministic debug
@export var use_fixed_seed: bool = false
@export var fixed_seed: int = 42

const MODEL_PATH := "res://kenney_space-kit/Models/GLTF format/"

# ✅ Pick layer for raycast selection (must match Main.gd query mask)
const PICK_LAYER_BIT := 10
const PICK_LAYER_MASK := 1 << PICK_LAYER_BIT

# ----------------------------
# Lifecycle
# ----------------------------

func _ready() -> void:
	# Initialize modules
	star_renderer = StarRenderer.new(self)
	planet_renderer = PlanetRenderer.new(self)
	connection_generator = ConnectionGenerator.new(self)
	
	add_child(star_renderer)
	add_child(planet_renderer)
	add_child(connection_generator)

	if use_fixed_seed:
		_rng_layout.seed = fixed_seed
	else:
		_rng_layout.randomize()

	_rng_encounters.randomize()

	generate_map_3d()

	if get_parent() and get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")

func _process(delta: float) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001
	planet_renderer.process_orbits(time, systems)

# ----------------------------
# Map generation
# ----------------------------

func generate_map_3d() -> void:
	print("Generating 3D galaxy map (Modular)...")

	_clear_generated_nodes()
	systems.clear()

	# Generate Systems
	start_system_index = _rng_layout.randi_range(0, max(0, system_count - 1))

	for i in range(system_count):
		var pos: Vector3 = _random_galaxy_position()

		var system: Dictionary = {
			"index": i,
			"name": "System " + str(i),
			"position": pos,
			"planets": [],
			"scanned": false,
			"enemies": [],
			"star_type": _get_random_star_type(_rng_layout)
		}

		# Planets 2..5
		var planet_count: int = _rng_layout.randi_range(2, 5)
		for p in range(planet_count):
			var planet: Dictionary = {
				"index": p,
				"name": "Planet " + str(i) + "-" + str(p),
				"resources": {
					"iron": _rng_layout.randi_range(100, 500),
					"titanium": _rng_layout.randi_range(0, 100) if _rng_layout.randf() > 0.5 else 0,
					"uranium": _rng_layout.randi_range(0, 50) if _rng_layout.randf() > 0.8 else 0
				},
				"orbit_radius": _rng_layout.randf_range(4.0, 12.0),
				"orbit_speed": _rng_layout.randf_range(0.2, 1.0),
				"phase": _rng_layout.randf() * TAU
			}
			(system["planets"] as Array).append(planet)

		systems.append(system)

		# Visuals: Star
		var star_mesh: Node3D = star_renderer.create_star(system, pos, i)
		system_meshes.append(star_mesh)

	# Visuals: Connections
	connections = connection_generator.generate(systems, _rng_layout)
	connection_generator.draw_connections(connections, systems)

	# Content: Enemies
	_generate_enemies_random_scaled()

	# Visuals: Background & Mothership
	_create_mothership_mesh()
	star_renderer.create_starfield()

	update_selection_visuals()

# ----------------------------
# Selection visuals
# ----------------------------

func update_selection_visuals() -> void:
	# Update stars
	for i in range(system_meshes.size()):
		var is_sel: bool = (i == selected_system_index)
		var is_scanned: bool = bool(systems[i]["scanned"])
		star_renderer.update_selection(system_meshes[i], is_sel, is_scanned)

	# Update mothership position
	if mothership_node and mothership_mesh:
		var current_idx: int = int(mothership_node.get_current_system())
		if current_idx >= 0 and current_idx < systems.size():
			mothership_mesh.position = (systems[current_idx]["position"] as Vector3) + Vector3(0, 3, 0)

	_ensure_active_planets()
	
	# Update planet selection
	planet_renderer.refresh_selection(selected_system_index, selected_planet_index)
	
	# Update miners
	_update_unit_indicators()

func _ensure_active_planets() -> void:
	var active: Array[int] = []

	if mothership_node:
		var cur: int = int(mothership_node.get_current_system())
		if cur >= 0 and cur < systems.size():
			active.append(cur)

	if selected_system_index >= 0 and selected_system_index < systems.size() and !active.has(selected_system_index):
		active.append(selected_system_index)

	planet_renderer.update_planets(systems, active)

func _update_unit_indicators() -> void:
	if get_parent() == null or !get_parent().has_node("Managers"):
		return

	var managers: Node = get_parent().get_node("Managers")
	if !managers.has_node("MiningManager"):
		return

	var mining_manager: Node = managers.get_node("MiningManager")
	planet_renderer.update_unit_indicators(mining_manager.deployments)

# ----------------------------
# Cleanup
# ----------------------------

func _tag_generated(n: Node) -> void:
	if n != null:
		n.set_meta("_gen", true)

func _clear_generated_nodes() -> void:
	for c in get_children():
		if c != null and is_instance_valid(c) and c.has_meta("_gen") and bool(c.get_meta("_gen")):
			(c as Node).queue_free()

	system_meshes.clear()
	mothership_mesh = null
	connections.clear()
	
	planet_renderer.clear_all()
	connection_generator.clear_visuals()

# ----------------------------
# Enemies (Logic Only)
# ----------------------------

func _generate_enemies_random_scaled() -> void:
	var enemies_data = Global.get("enemies_data")
	if not (enemies_data is Array) or (enemies_data as Array).size() == 0:
		return

	var pool: Array = enemies_data as Array
	var start_pos: Vector3 = systems[start_system_index]["position"]

	var max_d: float = 0.01
	for s in systems:
		var d: float = (s as Dictionary)["position"].distance_to(start_pos)
		if d > max_d:
			max_d = d

	for i in range(systems.size()):
		var system: Dictionary = systems[i]
		system["enemies"] = []

		if i == start_system_index:
			continue

		if _rng_encounters.randf() >= enemy_spawn_chance:
			continue

		var enemy_type: Dictionary = pool[_rng_encounters.randi_range(0, pool.size() - 1)]
		var count: int = _rng_encounters.randi_range(enemy_min_count, enemy_max_count)

		var d01: float = system["position"].distance_to(start_pos) / max_d
		d01 = clamp(d01, 0.0, 1.0)
		var enemy_scale: float = 1.0 + (enemy_scale_strength * d01)

		if d01 > 0.66 and _rng_encounters.randf() < 0.45:
			count += 1

		for _c in range(count):
			var e: Dictionary = enemy_type.duplicate(true)
			_scale_enemy_dict(e, enemy_scale)
			system["enemies"].append(e)

func _scale_enemy_dict(e: Dictionary, enemy_scale: float) -> void:
	if e.has("stats") and typeof(e["stats"]) == TYPE_DICTIONARY:
		var st: Dictionary = e["stats"] as Dictionary
		if st.has("durability"):
			st["durability"] = max(1, int(round(float(st["durability"]) * enemy_scale)))
		if st.has("firepower"):
			st["firepower"] = max(1, int(round(float(st["firepower"]) * lerp(1.0, 1.0 + (enemy_scale - 1.0) * 0.75, 1.0))))
		e["stats"] = st
	else:
		if e.has("durability"):
			e["durability"] = max(1, int(round(float(e["durability"]) * enemy_scale)))
		if e.has("firepower"):
			e["firepower"] = max(1, int(round(float(e["firepower"]) * lerp(1.0, 1.0 + (enemy_scale - 1.0) * 0.75, 1.0))))

# ----------------------------
# Galaxy Shape Logic
# ----------------------------

func _random_galaxy_position() -> Vector3:
	var in_core: bool = (_rng_layout.randf() < core_ratio)

	var u: float = _rng_layout.randf()
	var r01: float = pow(u, 0.55)
	if in_core:
		r01 = pow(_rng_layout.randf(), 1.6)

	var r_x: float = r01 * spread_x
	var r_z: float = r01 * spread_z

	var arm_index: int = _rng_layout.randi_range(0, max(0, arm_count - 1))
	var arm_base: float = (TAU / float(max(1, arm_count))) * float(arm_index)

	var twist: float = arm_twist * r01 * TAU * 0.25
	var jitter: float = _rng_layout.randfn(0.0, arm_spread) * lerp(0.35, 1.0, r01)

	var angle: float = arm_base + twist + jitter
	if in_core:
		angle = _rng_layout.randf() * TAU

	var x: float = cos(angle) * r_x
	var z: float = sin(angle) * r_z

	if in_core:
		x = clamp(x, -core_radius, core_radius) + _rng_layout.randfn(0.0, 2.0)
		z = clamp(z, -core_radius, core_radius) + _rng_layout.randfn(0.0, 2.0)

	var y: float = _rng_layout.randfn(0.0, 1.0) * (spread_y * 0.30) * y_scale
	y = clamp(y, -spread_y * y_scale, spread_y * y_scale)

	# Clamping
	x = clamp(x, -spread_x, spread_x)
	z = clamp(z, -spread_z, spread_z)

	return Vector3(x, y, z)

func _get_random_star_type(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.01: return "O"
	if roll < 0.05: return "B"
	if roll < 0.15: return "A"
	if roll < 0.30: return "F"
	if roll < 0.50: return "G"
	if roll < 0.75: return "K"
	return "M"

# ----------------------------
# Misc Helpers
# ----------------------------

func is_system_connected(a: int, b: int) -> bool:
	for conn in connections:
		if (conn[0] == a and conn[1] == b) or (conn[0] == b and conn[1] == a):
			return true
	return false

# ----------------------------
# Mothership (kept here for now, small enough)
# ----------------------------

func _create_mothership_mesh() -> void:
	if mothership_mesh and is_instance_valid(mothership_mesh):
		mothership_mesh.queue_free()
		mothership_mesh = null

	var ship_scene = load(MODEL_PATH + "craft_cargoA.glb")
	if ship_scene:
		mothership_mesh = (ship_scene as PackedScene).instantiate()
		_tag_generated(mothership_mesh)
		add_child(mothership_mesh)
		mothership_mesh.scale = Vector3(2, 2, 2)
	else:
		var fallback: MeshInstance3D = MeshInstance3D.new()
		_tag_generated(fallback)
		var pm: PrismMesh = PrismMesh.new()
		pm.size = Vector3(1.5, 2.0, 1.0)
		fallback.mesh = pm
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.9, 0.2)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.1)
		fallback.material_override = m
		add_child(fallback)
		mothership_mesh = fallback

	# Pick box for mothership
	_attach_pick_box(mothership_mesh, "mothership")

func _attach_pick_box(target: Node3D, pick_type: String) -> void:
	if target == null: return
	if target.has_node("PickArea"):
		target.get_node("PickArea").queue_free()

	# Simple AABB approximation approx
	var radius: float = 0.7
	
	var area: Area3D = Area3D.new()
	area.name = "PickArea"
	area.set_meta("pick_type", pick_type)

	# Fix: Set collision layer to match SelectionHandler raycast (Bit 10)
	area.collision_layer = 1 << 10
	area.collision_mask = 0

	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	cs.shape = sph
	
	area.add_child(cs)
	target.add_child(area)
