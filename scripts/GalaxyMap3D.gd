extends Node3D
class_name GalaxyMap3D

# ----------------------------
# Data
# ----------------------------

var systems: Array = []
var connections: Array = []

# Typed arrays help Godot's type inference a LOT
var system_meshes: Array[MeshInstance3D] = []
var mothership_mesh: Node3D = null

# key (String "s,p") -> Array[Node3D] (miners orbiting that planet)
var unit_indicators: Dictionary = {}

# Selection
var mothership_node: Node = null
var selected_system_index: int = -1
var selected_planet_index: int = -1 # -1 means no planet selected within system

# Planets/orbits per system
var planet_meshes: Dictionary = {} # int -> Array[MeshInstance3D]
var orbit_meshes: Dictionary = {}  # int -> Array[MeshInstance3D]

# Caches to avoid stutter on planet clicks (no heavy texture/material rebuilds)
var _planet_noise_cache: Dictionary = {}     # key "s,p" -> NoiseTexture2D
var _planet_material_cache: Dictionary = {}  # key "s,p,sel" -> StandardMaterial3D
var _planet_ring_nodes: Dictionary = {}      # key "s,p" -> Node3D (selection ring container)

# RNG: keep layout stable if you want, but enemies random each run
var _rng_layout: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_encounters: RandomNumberGenerator = RandomNumberGenerator.new()

@export var system_count: int = 15
@export var spread_size: float = 50.0

# 1/4 - 1/5 ≈ 0.20 - 0.25
@export var enemy_spawn_chance: float = 0.22

# ✅ Connection tuning
@export var connect_max_distance: float = 45.0
@export var max_neighbors_per_system: int = 3
@export var extra_connection_chance: float = 0.18 # shortcuts
@export_range(0.0, 0.6, 0.05) var dead_end_ratio: float = 0.25 # want some degree-1 nodes

const MODEL_PATH := "res://kenney_space-kit/Models/GLTF format/"

func _ready() -> void:
	# Layout: deterministic (nice for debugging). Enemies: random each run.
	_rng_layout.seed = 42
	_rng_encounters.randomize()

	generate_map_3d()
	if get_parent() and get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")


# ----------------------------
# FIX: cleanup generated nodes
# ----------------------------

func _clear_generated_nodes() -> void:
	# We only delete nodes created at runtime by this script.
	# Those nodes are tagged with meta "_gen" = true.
	var children: Array = get_children()
	for c in children:
		if c != null and is_instance_valid(c) and c.has_meta("_gen") and bool(c.get_meta("_gen")):
			(c as Node).queue_free()

	# also clear our references (safe even if nodes are already queued)
	system_meshes.clear()
	mothership_mesh = null
	connections.clear()

	planet_meshes.clear()
	orbit_meshes.clear()
	unit_indicators.clear()

	_planet_ring_nodes.clear()
	_planet_noise_cache.clear()
	_planet_material_cache.clear()


func _tag_generated(n: Node) -> void:
	if n != null:
		n.set_meta("_gen", true)


# ----------------------------
# Map generation
# ----------------------------

func generate_map_3d() -> void:
	print("Generating 3D galaxy map...")

	# ✅ IMPORTANT: delete ALL runtime-generated nodes (prevents ghost lines / old starfields)
	_clear_generated_nodes()

	# base material for stars
	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.5, 0.5)
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.2, 0.4, 0.6)

	systems.clear()

	for i in range(system_count):
		# System data
		var system: Dictionary = {
			"index": i,
			"name": "System " + str(i),
			"position": Vector3(
				_rng_layout.randf_range(-spread_size, spread_size),
				_rng_layout.randf_range(-spread_size / 5.0, spread_size / 5.0),
				_rng_layout.randf_range(-spread_size, spread_size)
			),
			"planets": [],
			"scanned": false,
			"enemies": [],
			"star_type": _get_random_star_type(_rng_layout)
		}

		# Spawn enemies (random every run)
		if i > 1 and _rng_encounters.randf() < enemy_spawn_chance:
			var enemies_data = Global.get("enemies_data")
			if enemies_data is Array and (enemies_data as Array).size() > 0:
				var pool: Array = enemies_data as Array
				var enemy_type: Dictionary = pool[_rng_encounters.randi_range(0, pool.size() - 1)]
				var count: int = _rng_encounters.randi_range(1, 4)
				for c in range(count):
					system["enemies"].append(enemy_type.duplicate(true))

		# Generate 2-5 planets
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

		# Star mesh
		var star_mesh: MeshInstance3D = MeshInstance3D.new()
		_tag_generated(star_mesh)

		var sm: SphereMesh = SphereMesh.new()
		star_mesh.mesh = sm
		star_mesh.position = system["position"]

		var star_visuals: Dictionary = _get_star_visuals(str(system["star_type"]))
		var mat: StandardMaterial3D = base_mat.duplicate()
		mat.emission = star_visuals["color"]
		mat.emission_energy_multiplier = 1.0
		star_mesh.material_override = mat

		sm.radius = float(star_visuals["size"])
		sm.height = float(star_visuals["size"]) * 2.0

		star_mesh.set_meta("system_index", i)
		add_child(star_mesh)
		system_meshes.append(star_mesh)

	# ✅ NEW: Connection graph generation (interesting paths)
	_build_connections_graph()

	_create_mothership_mesh()
	_create_starfield()

	# initial visual state
	update_selection_visuals()


# ----------------------------
# Connection graph (MST + extras + dead ends)
# ----------------------------

func _build_connections_graph() -> void:
	connections.clear()
	if systems.size() <= 1:
		return

	# Precompute all candidate edges under distance limit
	var edges: Array = []
	for i in range(systems.size()):
		for j in range(i + 1, systems.size()):
			var a: Vector3 = systems[i]["position"]
			var b: Vector3 = systems[j]["position"]
			var d := a.distance_to(b)
			if d <= connect_max_distance:
				edges.append({"i": i, "j": j, "d": d})

	# Fallback: if too sparse, loosen constraint once (prevents disconnected graphs)
	if edges.size() == 0:
		for i2 in range(systems.size()):
			for j2 in range(i2 + 1, systems.size()):
				var a2: Vector3 = systems[i2]["position"]
				var b2: Vector3 = systems[j2]["position"]
				var d2 := a2.distance_to(b2)
				edges.append({"i": i2, "j": j2, "d": d2})

	# Sort by distance (for MST / cheap edges)
	edges.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))

	# Degree tracking
	var degree: Array[int] = []
	degree.resize(systems.size())
	for k in range(degree.size()):
		degree[k] = 0

	# Union-Find parent array
	var parent: Array[int] = []
	parent.resize(systems.size())
	for p in range(parent.size()):
		parent[p] = p

	# --- Build MST ---
	var mst_edges: Array = []
	for e in edges:
		var i3 := int(e["i"])
		var j3 := int(e["j"])
		if _uf_unite(parent, i3, j3):
			mst_edges.append(e)
			degree[i3] += 1
			degree[j3] += 1
			if mst_edges.size() == systems.size() - 1:
				break

	# If still not connected (rare), force-connect with nearest edges
	if mst_edges.size() < systems.size() - 1:
		for e2 in edges:
			var a_idx := int(e2["i"])
			var b_idx := int(e2["j"])
			if _uf_unite(parent, a_idx, b_idx):
				mst_edges.append(e2)
				degree[a_idx] += 1
				degree[b_idx] += 1
				if mst_edges.size() == systems.size() - 1:
					break

	# Add MST edges (always)
	for e3 in mst_edges:
		_add_connection(int(e3["i"]), int(e3["j"]))

	# Dead-end preference
	var target_dead_ends := int(round(float(systems.size()) * dead_end_ratio))

	# --- Add extra edges (shortcuts) but limit per node ---
	for e4 in edges:
		if _rng_layout.randf() > extra_connection_chance:
			continue

		var a2_idx := int(e4["i"])
		var b2_idx := int(e4["j"])

		# already connected?
		if is_system_connected(a2_idx, b2_idx):
			continue

		# Respect max neighbors
		if degree[a2_idx] >= max_neighbors_per_system:
			continue
		if degree[b2_idx] >= max_neighbors_per_system:
			continue

		# Prefer leaving some degree-1 systems as dead ends
		var current_dead_ends := 0
		for dval in degree:
			if dval <= 1:
				current_dead_ends += 1

		if current_dead_ends < target_dead_ends:
			if degree[a2_idx] <= 1 or degree[b2_idx] <= 1:
				continue

		_add_connection(a2_idx, b2_idx)
		degree[a2_idx] += 1
		degree[b2_idx] += 1

	# Draw lines (based on `connections`)
	for c in connections:
		var ia: int = int(c[0])
		var ib: int = int(c[1])
		_draw_connection(systems[ia]["position"], systems[ib]["position"])


func _add_connection(i: int, j: int) -> void:
	# normalize order to reduce duplicates
	var a := mini(i, j)
	var b := maxi(i, j)
	for conn in connections:
		if int(conn[0]) == a and int(conn[1]) == b:
			return
	connections.append([a, b])


# ----------------------------
# Union-Find helpers (Godot-safe, no local lambdas)
# ----------------------------

func _uf_find(parent: Array[int], x: int) -> int:
	var r := x
	while parent[r] != r:
		r = parent[r]

	# path compression
	var y := x
	while parent[y] != y:
		var nxt := parent[y]
		parent[y] = r
		y = nxt

	return r

func _uf_unite(parent: Array[int], a: int, b: int) -> bool:
	var ra := _uf_find(parent, a)
	var rb := _uf_find(parent, b)
	if ra == rb:
		return false
	parent[rb] = ra
	return true


# ----------------------------
# Starfield / Ship
# ----------------------------

func _create_starfield() -> void:
	var star_count: int = 600
	var container: Node3D = Node3D.new()
	container.name = "Starfield"
	_tag_generated(container)
	add_child(container)

	var star_mesh := PointMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.use_point_size = true
	mat.point_size = 2.0
	mat.vertex_color_use_as_albedo = true

	var multi_mesh: MultiMesh = MultiMesh.new()
	multi_mesh.mesh = star_mesh
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.instance_count = star_count

	for i in range(star_count):
		var pos: Vector3 = Vector3(
			_rng_layout.randf_range(-1, 1),
			_rng_layout.randf_range(-1, 1),
			_rng_layout.randf_range(-1, 1)
		).normalized() * 500.0

		var xform: Transform3D = Transform3D(Basis(), pos)
		multi_mesh.set_instance_transform(i, xform)

		var c: Color = Color(0.8, 0.9, 1.0)
		var roll: float = _rng_layout.randf()
		if roll > 0.9:
			c = Color(1.0, 0.8, 0.8)
		elif roll > 0.7:
			c = Color(1.0, 1.0, 0.8)
		multi_mesh.set_instance_color(i, c)

	var mm_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mm_instance.multimesh = multi_mesh
	mm_instance.material_override = mat
	_tag_generated(mm_instance)
	container.add_child(mm_instance)


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


# ----------------------------
# Visual updates (selection / planets / miners)
# ----------------------------

func update_selection_visuals() -> void:
	# Stars highlight
	for i in range(system_meshes.size()):
		var star_node: MeshInstance3D = system_meshes[i]
		if star_node == null:
			continue

		var mat := star_node.material_override as StandardMaterial3D
		if mat == null:
			continue

		if i == selected_system_index:
			mat.emission_energy_multiplier = 4.0
		elif bool(systems[i]["scanned"]):
			mat.emission_energy_multiplier = 2.0
		else:
			mat.emission_energy_multiplier = 0.5

	# Mothership position
	if mothership_node and mothership_mesh:
		var current_idx: int = int(mothership_node.get_current_system())
		if current_idx >= 0 and current_idx < systems.size():
			var target_pos: Vector3 = (systems[current_idx]["position"] as Vector3) + Vector3(0, 3, 0)
			mothership_mesh.position = target_pos

	# Planets/miners
	_ensure_active_planets()
	_refresh_planet_highlights()
	_update_unit_indicators()


func _ensure_active_planets() -> void:
	# Show planets only for: current system + selected system
	var active: Array[int] = []

	if mothership_node:
		var cur: int = int(mothership_node.get_current_system())
		if cur >= 0 and cur < systems.size():
			active.append(cur)

	if selected_system_index >= 0 and selected_system_index < systems.size() and !active.has(selected_system_index):
		active.append(selected_system_index)

	# Remove planets for systems that are no longer active
	var existing_keys := planet_meshes.keys()
	for k in existing_keys:
		var sys_idx: int = int(k)
		if !active.has(sys_idx):
			_clear_planet_visuals(sys_idx)

	# Create planets for active scanned systems if missing
	for sys_idx in active:
		var sys: Dictionary = systems[sys_idx]
		if !bool(sys["scanned"]):
			# ensure nothing is shown if unscanned
			_clear_planet_visuals(sys_idx)
			continue

		if !planet_meshes.has(sys_idx):
			planet_meshes[sys_idx] = []
			orbit_meshes[sys_idx] = []

			var planets: Array = sys["planets"]
			for p_idx in range(planets.size()):
				var p_data: Dictionary = planets[p_idx]

				var planet_node: MeshInstance3D = MeshInstance3D.new()
				_tag_generated(planet_node)
				var sm: SphereMesh = SphereMesh.new()
				sm.radius = 0.4
				sm.height = 0.8
				planet_node.mesh = sm

				planet_node.set_meta("system_index", sys_idx)
				planet_node.set_meta("planet_index", p_idx)

				# initial material (not selected by default)
				planet_node.material_override = _get_planet_material_cached(sys_idx, p_idx, p_data, false)

				add_child(planet_node)
				(planet_meshes[sys_idx] as Array).append(planet_node)

				# orbit path once per planet
				_draw_orbit_path(sys_idx, float(p_data["orbit_radius"]))


func _refresh_planet_highlights() -> void:
	for sys_key in planet_meshes.keys():
		var idx: int = int(sys_key)
		var sys: Dictionary = systems[idx]
		var planets: Array = sys["planets"]

		var arr: Array = planet_meshes[idx]
		for p_idx in range(arr.size()):
			var planet_node: MeshInstance3D = arr[p_idx]
			if planet_node == null or !is_instance_valid(planet_node):
				continue

			var is_selected: bool = (idx == selected_system_index and p_idx == selected_planet_index)
			var p_data: Dictionary = planets[p_idx]

			planet_node.material_override = _get_planet_material_cached(idx, p_idx, p_data, is_selected)

			# Selection ring
			var key: String = "%d,%d" % [idx, p_idx]
			if is_selected:
				if !_planet_ring_nodes.has(key) or !is_instance_valid(_planet_ring_nodes[key]):
					_planet_ring_nodes[key] = _add_selection_ring(planet_node)
					_tag_generated(_planet_ring_nodes[key])
			else:
				if _planet_ring_nodes.has(key) and is_instance_valid(_planet_ring_nodes[key]):
					(_planet_ring_nodes[key] as Node).queue_free()
				_planet_ring_nodes.erase(key)


func _get_planet_material_cached(sys_idx: int, p_idx: int, p_data: Dictionary, is_selected: bool) -> StandardMaterial3D:
	var key_mat: String = "%d,%d,%d" % [sys_idx, p_idx, (1 if is_selected else 0)]
	if _planet_material_cache.has(key_mat):
		return _planet_material_cache[key_mat] as StandardMaterial3D

	var mat: StandardMaterial3D = StandardMaterial3D.new()

	# Noise texture per planet (cached)
	var key_noise: String = "%d,%d" % [sys_idx, p_idx]
	var noise_tex: NoiseTexture2D

	if _planet_noise_cache.has(key_noise):
		noise_tex = _planet_noise_cache[key_noise] as NoiseTexture2D
	else:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = int(str(p_data["name"]).hash())
		noise.frequency = 0.05

		noise_tex = NoiseTexture2D.new()
		noise_tex.width = 512
		noise_tex.height = 256
		noise_tex.seamless = true
		noise_tex.noise = noise

		_planet_noise_cache[key_noise] = noise_tex

	mat.albedo_texture = noise_tex

	# Base look by resources
	var res: Dictionary = p_data["resources"]

	if int(res.get("uranium", 0)) > 0:
		mat.albedo_color = Color(0.2, 0.8, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.3, 0.1)
	elif int(res.get("titanium", 0)) > 0:
		mat.albedo_color = Color(0.6, 0.6, 0.7)
		mat.metallic = 0.8
		mat.roughness = 0.2
	else:
		mat.albedo_color = Color(0.7, 0.4, 0.2)
		mat.roughness = 0.9

	# Selection glow
	if is_selected:
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.6, 1.0)
		mat.emission_energy_multiplier = 1.5

	_planet_material_cache[key_mat] = mat
	return mat


func _add_selection_ring(parent_node: Node3D) -> Node3D:
	var bracket_scene: Node3D = Node3D.new()
	bracket_scene.name = "SelectionBrackets"
	parent_node.add_child(bracket_scene)

	for i in range(4):
		var line: MeshInstance3D = MeshInstance3D.new()
		_tag_generated(line)
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


func _draw_orbit_path(sys_idx: int, radius: float) -> void:
	if !orbit_meshes.has(sys_idx):
		orbit_meshes[sys_idx] = []

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	_tag_generated(mesh_instance)

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.4, 0.5, 0.15)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = systems[sys_idx]["position"]

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	var steps: int = 64
	for i in range(steps + 1):
		var ang: float = float(i) * (TAU / float(steps))
		immediate_mesh.surface_add_vertex(Vector3(cos(ang) * radius, 0, sin(ang) * radius))
	immediate_mesh.surface_end()

	add_child(mesh_instance)
	(orbit_meshes[sys_idx] as Array).append(mesh_instance)


func _clear_planet_visuals(sys_idx: int) -> void:
	if planet_meshes.has(sys_idx):
		for n in planet_meshes[sys_idx]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		planet_meshes.erase(sys_idx)

	if orbit_meshes.has(sys_idx):
		for n in orbit_meshes[sys_idx]:
			if is_instance_valid(n):
				(n as Node).queue_free()
		orbit_meshes.erase(sys_idx)

	# remove rings for this system
	var keys := _planet_ring_nodes.keys()
	for k in keys:
		var parts := str(k).split(",")
		if parts.size() == 2 and int(parts[0]) == sys_idx:
			if is_instance_valid(_planet_ring_nodes[k]):
				(_planet_ring_nodes[k] as Node).queue_free()
			_planet_ring_nodes.erase(k)


# ----------------------------
# Miners (indicators)
# ----------------------------

func _update_unit_indicators() -> void:
	# Clear old
	for k in unit_indicators.keys():
		var arr_old: Array = unit_indicators[k]
		for mesh in arr_old:
			if is_instance_valid(mesh):
				(mesh as Node).queue_free()
	unit_indicators.clear()

	if get_parent() == null or !get_parent().has_node("Managers"):
		return

	var managers: Node = get_parent().get_node("Managers")
	if !managers.has_node("MiningManager"):
		return

	var mining_manager: Node = managers.get_node("MiningManager")

	var miner_scene = load(MODEL_PATH + "craft_miner.glb")

	for key in mining_manager.deployments:
		var count: int = int(mining_manager.deployments[key])
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2:
			continue

		var s_idx: int = int(parts[0])

		# Only show if system is active (selected or current)
		var is_active: bool = (s_idx == selected_system_index)
		if mothership_node:
			is_active = is_active or (s_idx == int(mothership_node.get_current_system()))
		if !is_active:
			continue

		unit_indicators[key] = []

		for k2 in range(count):
			var miner_node: Node3D

			if miner_scene:
				miner_node = (miner_scene as PackedScene).instantiate()
				_tag_generated(miner_node)
				miner_node.scale = Vector3(0.5, 0.5, 0.5)
			else:
				var fallback: MeshInstance3D = MeshInstance3D.new()
				_tag_generated(fallback)
				var bm: BoxMesh = BoxMesh.new()
				bm.size = Vector3(0.3, 0.3, 0.3)
				fallback.mesh = bm
				var miner_mat: StandardMaterial3D = StandardMaterial3D.new()
				miner_mat.albedo_color = Color(0.2, 1.0, 0.2)
				miner_mat.emission_enabled = true
				miner_mat.emission = Color(0.2, 1.0, 0.2)
				miner_mat.emission_energy_multiplier = 3.0
				fallback.material_override = miner_mat
				miner_node = fallback

			add_child(miner_node)
			(unit_indicators[key] as Array).append(miner_node)


# ----------------------------
# Runtime updates
# ----------------------------

func _process(_delta: float) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001

	# Planet orbits
	for sys_idx_key in planet_meshes.keys():
		var s_idx: int = int(sys_idx_key)
		var sys_pos: Vector3 = systems[s_idx]["position"]
		var sys: Dictionary = systems[s_idx]
		var planets: Array = sys["planets"]

		var arr: Array = planet_meshes[s_idx]
		for p_idx in range(arr.size()):
			var p_mesh: MeshInstance3D = arr[p_idx]
			if p_mesh == null or !is_instance_valid(p_mesh):
				continue

			var p_data: Dictionary = planets[p_idx]
			var angle_p: float = float(p_data["phase"]) + time * float(p_data["orbit_speed"])
			var offset_p: Vector3 = Vector3(cos(angle_p), 0, sin(angle_p)) * float(p_data["orbit_radius"])
			p_mesh.position = sys_pos + offset_p

	# Miner positions (orbit planet)
	for key in unit_indicators.keys():
		var parts: PackedStringArray = str(key).split(",")
		if parts.size() < 2:
			continue

		var s_idx2: int = int(parts[0])
		var p_idx2: int = int(parts[1])

		if planet_meshes.has(s_idx2) and p_idx2 >= 0 and p_idx2 < (planet_meshes[s_idx2] as Array).size():
			var p_mesh2: MeshInstance3D = (planet_meshes[s_idx2] as Array)[p_idx2]
			if p_mesh2 == null or !is_instance_valid(p_mesh2):
				continue

			var meshes: Array = unit_indicators[key]
			var denom: float = maxf(1.0, float(meshes.size()))

			for k2 in range(meshes.size()):
				var miner_node: Node3D = meshes[k2]
				if miner_node == null or !is_instance_valid(miner_node):
					continue

				var angle_m: float = float(k2) * (TAU / denom) + time * 2.0
				var offset_m: Vector3 = Vector3(cos(angle_m), 0.5, sin(angle_m)) * 0.8
				miner_node.position = p_mesh2.position + offset_m


# ----------------------------
# Helpers
# ----------------------------

func is_system_connected(a: int, b: int) -> bool:
	for conn in connections:
		if (conn[0] == a and conn[1] == b) or (conn[0] == b and conn[1] == a):
			return true
	return false


func _draw_connection(start: Vector3, end: Vector3) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "ConnectionLine"
	_tag_generated(mesh_instance)

	var immediate_mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.3, 0.6, 1.0, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(start)
	immediate_mesh.surface_add_vertex(end)
	immediate_mesh.surface_end()

	add_child(mesh_instance)


func _get_random_star_type(rng: RandomNumberGenerator) -> String:
	var roll: float = rng.randf()
	if roll < 0.01: return "O"
	if roll < 0.05: return "B"
	if roll < 0.15: return "A"
	if roll < 0.30: return "F"
	if roll < 0.50: return "G"
	if roll < 0.75: return "K"
	return "M"


func _get_star_visuals(t: String) -> Dictionary:
	match t:
		"O": return {"color": Color(0.2, 0.5, 1.0), "size": 2.5}
		"B": return {"color": Color(0.5, 0.7, 1.0), "size": 1.8}
		"A": return {"color": Color(1.0, 1.0, 1.0), "size": 1.4}
		"F": return {"color": Color(1.0, 1.0, 0.8), "size": 1.2}
		"G": return {"color": Color(1.0, 0.9, 0.3), "size": 1.0}
		"K": return {"color": Color(1.0, 0.6, 0.2), "size": 0.8}
		"M": return {"color": Color(1.0, 0.3, 0.1), "size": 0.6}
	return {"color": Color(1, 1, 1), "size": 1.0}
