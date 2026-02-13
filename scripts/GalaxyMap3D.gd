# === scripts/GalaxyMap3D.gd ===
extends Node3D
class_name GalaxyMap3D

# ----------------------------
# Data
# ----------------------------

var systems: Array = []
var connections: Array = []

var system_meshes: Array[MeshInstance3D] = []
var mothership_mesh: Node3D = null

# key "s,p" -> Array[Node3D]
var unit_indicators: Dictionary = {}

# Selection
var mothership_node: Node = null
var selected_system_index: int = -1
var selected_planet_index: int = -1

var planet_meshes: Dictionary = {} # int -> Array[MeshInstance3D]
var orbit_meshes: Dictionary = {}  # int -> Array[MeshInstance3D]

var _planet_noise_cache: Dictionary = {}
var _planet_material_cache: Dictionary = {}
var _planet_ring_nodes: Dictionary = {}

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
@export var enemy_scale_strength: float = 0.75 # 0.0 = off, 1.0 = strong scaling

# Connections
@export var connect_max_dist: float = 55.0
@export var min_links_per_system: int = 1

# extra links but controlled
@export var extra_link_chance: float = 0.10

# Degree policy:
# - HARD cap: 4 for everyone
# - SOFT cap: 3 for ~85% of nodes, 4 for ~15%
@export var hard_max_links: int = 4
@export var heavy_degree_ratio: float = 0.15 # 15% allowed to reach 4 (soft cap 3 otherwise)

# Spiral galaxy look
@export var arm_count: int = 3
@export var arm_twist: float = 2.6
@export var arm_spread: float = 0.55
@export var core_radius: float = 12.0
@export var core_ratio: float = 0.18
@export var y_scale: float = 1.55 # ✅ slightly higher disk

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
	if use_fixed_seed:
		_rng_layout.seed = fixed_seed
	else:
		_rng_layout.randomize()

	_rng_encounters.randomize()

	generate_map_3d()

	if get_parent() and get_parent().has_node("Managers/Mothership"):
		mothership_node = get_parent().get_node("Managers/Mothership")

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

	planet_meshes.clear()
	orbit_meshes.clear()
	unit_indicators.clear()

	_planet_ring_nodes.clear()
	_planet_noise_cache.clear()
	_planet_material_cache.clear()

# ----------------------------
# ✅ PICK HELPERS (Raycast selection)
# ----------------------------

func _get_combined_local_aabb(root: Node) -> AABB:
	var have: bool = false
	var combined: AABB = AABB()

	# Walk tree
	for n in root.get_children():
		if n is Node:
			var child_aabb: AABB = _get_combined_local_aabb(n)
			if child_aabb.size != Vector3.ZERO:
				if not have:
					combined = child_aabb
					have = true
				else:
					combined = combined.merge(child_aabb)

		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh == null:
				continue

			var aabb: AABB = mi.mesh.get_aabb()
			var xf: Transform3D = mi.transform

			var corners: Array = [
				aabb.position,
				aabb.position + Vector3(aabb.size.x, 0, 0),
				aabb.position + Vector3(0, aabb.size.y, 0),
				aabb.position + Vector3(0, 0, aabb.size.z),
				aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
				aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
				aabb.position + Vector3(0, aabb.size.y, aabb.size.z),
				aabb.position + aabb.size
			]

			var have2: bool = false
			var a2: AABB = AABB()
			for c in corners:
				# ✅ explicit typing -> fixes "Cannot infer type of 'p'"
				var p: Vector3 = xf * (c as Vector3)
				if not have2:
					a2 = AABB(p, Vector3(0.001, 0.001, 0.001))
					have2 = true
				else:
					a2 = a2.expand(p)

			if not have:
				combined = a2
				have = true
			else:
				combined = combined.merge(a2)

	return combined if have else AABB(Vector3.ZERO, Vector3.ZERO)

func _attach_pick_box(target: Node3D, pick_type: String) -> void:
	if target == null:
		return

	# remove old
	if target.has_node("PickArea"):
		target.get_node("PickArea").queue_free()

	var aabb: AABB = _get_combined_local_aabb(target)
	if aabb.size == Vector3.ZERO:
		aabb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3(1, 1, 1))

	# slight padding
	var pad := 0.12
	aabb.position -= Vector3(pad, pad, pad)
	aabb.size += Vector3(pad * 2, pad * 2, pad * 2)

	var area := Area3D.new()
	area.name = "PickArea"
	area.set_meta("pick_type", pick_type)
	area.collision_layer = PICK_LAYER_MASK
	area.collision_mask = 0

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	cs.shape = box
	cs.position = aabb.position + aabb.size * 0.5

	area.add_child(cs)
	target.add_child(area)

func _attach_pick_sphere(target: Node3D, radius: float, pick_type: String, meta: Dictionary) -> void:
	if target == null:
		return

	if target.has_node("PickArea"):
		target.get_node("PickArea").queue_free()

	var area := Area3D.new()
	area.name = "PickArea"
	area.set_meta("pick_type", pick_type)

	for k in meta.keys():
		area.set_meta(k, meta[k])

	area.collision_layer = PICK_LAYER_MASK
	area.collision_mask = 0

	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = maxf(0.01, radius)
	cs.shape = sph

	area.add_child(cs)
	target.add_child(area)

# ----------------------------
# Map generation
# ----------------------------

func generate_map_3d() -> void:
	print("Generating 3D galaxy map...")

	_clear_generated_nodes()
	systems.clear()

	# choose start early (random per run)
	start_system_index = _rng_layout.randi_range(0, max(0, system_count - 1))

	var base_mat: StandardMaterial3D = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.5, 0.5, 0.5)
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.2, 0.4, 0.6)

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

		# Star mesh
		var star_mesh: MeshInstance3D = MeshInstance3D.new()
		_tag_generated(star_mesh)

		var sm: SphereMesh = SphereMesh.new()
		star_mesh.mesh = sm
		star_mesh.position = pos

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

		# ✅ Pick sphere for stars (raycast)
		_attach_pick_sphere(star_mesh, sm.radius * 1.15, "system", {"system_index": i})

	# connections first (so we have a good spread)
	_generate_connections()

	# enemies AFTER we know start and positions are set
	_generate_enemies_random_scaled()

	_create_mothership_mesh()
	_create_starfield()

	update_selection_visuals()

# ----------------------------
# Enemies: random + scaled by distance from random start
# ----------------------------

func _generate_enemies_random_scaled() -> void:
	var enemies_data = Global.get("enemies_data")
	if not (enemies_data is Array) or (enemies_data as Array).size() == 0:
		return

	var pool: Array = enemies_data as Array
	var start_pos: Vector3 = systems[start_system_index]["position"]

	# compute max distance for normalization
	var max_d: float = 0.01
	for s in systems:
		var d: float = (s as Dictionary)["position"].distance_to(start_pos)
		if d > max_d:
			max_d = d

	for i in range(systems.size()):
		var system: Dictionary = systems[i]
		system["enemies"] = []

		# keep start & very close area mostly safe
		if i == start_system_index:
			continue

		# spawn roll
		if _rng_encounters.randf() >= enemy_spawn_chance:
			continue

		var enemy_type: Dictionary = pool[_rng_encounters.randi_range(0, pool.size() - 1)]
		var count: int = _rng_encounters.randi_range(enemy_min_count, enemy_max_count)

		# scale factor 1.0 .. (1.0 + enemy_scale_strength)
		var d01: float = system["position"].distance_to(start_pos) / max_d
		d01 = clamp(d01, 0.0, 1.0)
		var scale: float = 1.0 + (enemy_scale_strength * d01)

		# further away: sometimes +1 extra enemy
		if d01 > 0.66 and _rng_encounters.randf() < 0.45:
			count += 1

		for _c in range(count):
			var e: Dictionary = enemy_type.duplicate(true)
			_scale_enemy_dict(e, scale)
			system["enemies"].append(e)

func _scale_enemy_dict(e: Dictionary, scale: float) -> void:
	# supports both formats: stats:{durability, firepower} or flat keys
	if e.has("stats") and typeof(e["stats"]) == TYPE_DICTIONARY:
		var st: Dictionary = e["stats"] as Dictionary
		if st.has("durability"):
			st["durability"] = max(1, int(round(float(st["durability"]) * scale)))
		if st.has("firepower"):
			st["firepower"] = max(1, int(round(float(st["firepower"]) * lerp(1.0, 1.0 + (scale - 1.0) * 0.75, 1.0))))
		e["stats"] = st
	else:
		if e.has("durability"):
			e["durability"] = max(1, int(round(float(e["durability"]) * scale)))
		if e.has("firepower"):
			e["firepower"] = max(1, int(round(float(e["firepower"]) * lerp(1.0, 1.0 + (scale - 1.0) * 0.75, 1.0))))

# ----------------------------
# Spiral galaxy position
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

	x = clamp(x, -spread_x, spread_x)
	z = clamp(z, -spread_z, spread_z)

	return Vector3(x, y, z)

# ----------------------------
# Union-Find helpers (NO nested funcs)
# ----------------------------

func _uf_find(parent: Array, x: int) -> int:
	var y: int = x
	while int(parent[y]) != y:
		parent[y] = parent[int(parent[y])]
		y = int(parent[y])
	return y

func _uf_unite(parent: Array, rank: Array, a: int, b: int) -> bool:
	var ra: int = _uf_find(parent, a)
	var rb: int = _uf_find(parent, b)
	if ra == rb:
		return false

	if int(rank[ra]) < int(rank[rb]):
		var tmp: int = ra
		ra = rb
		rb = tmp

	parent[rb] = ra
	if int(rank[ra]) == int(rank[rb]):
		rank[ra] = int(rank[ra]) + 1
	return true

# ----------------------------
# Connections generation
# ----------------------------

func _generate_connections() -> void:
	connections.clear()
	if systems.size() <= 1:
		return

	# soft caps: most nodes max 3, few max 4
	var cap: Array = _build_degree_caps(systems.size())

	var edges: Array = []
	for i in range(systems.size()):
		var a: Vector3 = systems[i]["position"]
		for j in range(i + 1, systems.size()):
			var b: Vector3 = systems[j]["position"]
			var d: float = a.distance_to(b)
			if d <= connect_max_dist:
				edges.append({"a": i, "b": j, "d": d})

	# fallback if too sparse
	if edges.size() < systems.size() - 1:
		for i2 in range(systems.size()):
			var a2: Vector3 = systems[i2]["position"]
			for j2 in range(i2 + 1, systems.size()):
				var b2: Vector3 = systems[j2]["position"]
				var d2: float = a2.distance_to(b2)
				if d2 <= connect_max_dist * 1.25:
					edges.append({"a": i2, "b": j2, "d": d2})

	edges.sort_custom(func(e1, e2): return float(e1["d"]) < float(e2["d"]))

	var parent: Array = []
	var rank: Array = []
	parent.resize(systems.size())
	rank.resize(systems.size())
	for k in range(systems.size()):
		parent[k] = k
		rank[k] = 0

	# degree map
	var deg: Array = []
	deg.resize(systems.size())
	for i4 in range(deg.size()):
		deg[i4] = 0

	# MST first (guarantees reachability)
	for e in edges:
		var ai: int = int(e["a"])
		var bi: int = int(e["b"])

		# hard cap: never exceed hard_max_links
		if int(deg[ai]) >= hard_max_links or int(deg[bi]) >= hard_max_links:
			continue

		if _uf_unite(parent, rank, ai, bi):
			connections.append([ai, bi])
			deg[ai] = int(deg[ai]) + 1
			deg[bi] = int(deg[bi]) + 1

	# ensure each node has at least min_links_per_system (but never exceed hard cap)
	for i5 in range(systems.size()):
		while int(deg[i5]) < min_links_per_system and int(deg[i5]) < hard_max_links:
			var best_j: int = -1
			var best_d: float = 999999.0
			var pos_i: Vector3 = systems[i5]["position"]

			for j5 in range(systems.size()):
				if j5 == i5:
					continue
				if _has_connection(i5, j5):
					continue
				if int(deg[j5]) >= hard_max_links:
					continue

				var d5: float = pos_i.distance_to(systems[j5]["position"])
				if d5 < best_d:
					best_d = d5
					best_j = j5

			if best_j == -1:
				break

			connections.append([i5, best_j])
			deg[i5] = int(deg[i5]) + 1
			deg[best_j] = int(deg[best_j]) + 1

	# occasional cross-links (controlled) honoring SOFT caps (3 for most, 4 for few)
	for e2 in edges:
		if _rng_layout.randf() > extra_link_chance:
			continue

		var a6: int = int(e2["a"])
		var b6: int = int(e2["b"])

		if _has_connection(a6, b6):
			continue

		# hard cap always
		if int(deg[a6]) >= hard_max_links or int(deg[b6]) >= hard_max_links:
			continue

		# soft cap: most nodes max 3
		if int(deg[a6]) >= int(cap[a6]):
			continue
		if int(deg[b6]) >= int(cap[b6]):
			continue

		connections.append([a6, b6])
		deg[a6] = int(deg[a6]) + 1
		deg[b6] = int(deg[b6]) + 1

	# draw lines
	for conn in connections:
		var a_pos: Vector3 = systems[conn[0]]["position"]
		var b_pos: Vector3 = systems[conn[1]]["position"]
		_draw_connection(a_pos, b_pos)

func _build_degree_caps(n: int) -> Array:
	var caps: Array = []
	caps.resize(n)

	# default soft cap: 3
	for i in range(n):
		caps[i] = 3

	# pick ~15% nodes that are allowed to reach 4
	var heavy_count: int = int(round(float(n) * clamp(heavy_degree_ratio, 0.0, 1.0)))
	heavy_count = clamp(heavy_count, 0, n)

	var picked: Dictionary = {}
	var tries: int = 0
	while picked.size() < heavy_count and tries < 9999:
		tries += 1
		var idx: int = _rng_layout.randi_range(0, n - 1)
		if picked.has(idx):
			continue
		picked[idx] = true
		caps[idx] = 4

	# enforce hard cap anyway
	for j in range(n):
		caps[j] = min(int(caps[j]), hard_max_links)

	return caps

func _has_connection(a: int, b: int) -> bool:
	for conn in connections:
		if (conn[0] == a and conn[1] == b) or (conn[0] == b and conn[1] == a):
			return true
	return false

func is_system_connected(a: int, b: int) -> bool:
	return _has_connection(a, b)

# ----------------------------
# Starfield + mothership
# ----------------------------

func _create_starfield() -> void:
	var star_count: int = 450
	var container: Node3D = Node3D.new()
	container.name = "Starfield"
	_tag_generated(container)
	add_child(container)

	var tiny: SphereMesh = SphereMesh.new()
	tiny.radius = 0.08
	tiny.height = 0.16

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.8, 1.0)
	mat.emission_energy_multiplier = 1.0

	var mm: MultiMesh = MultiMesh.new()
	mm.mesh = tiny
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = star_count

	for i in range(star_count):
		var dir := Vector3(
			_rng_layout.randf_range(-1, 1),
			_rng_layout.randf_range(-1, 1),
			_rng_layout.randf_range(-1, 1)
		)
		if dir.length() < 0.01:
			dir = Vector3(1, 0, 0)
		dir = dir.normalized()

		var pos: Vector3 = dir * _rng_layout.randf_range(320.0, 520.0)
		mm.set_instance_transform(i, Transform3D(Basis(), pos))

		var roll: float = _rng_layout.randf()
		var c: Color = Color(0.8, 0.9, 1.0)
		if roll > 0.92:
			c = Color(1.0, 0.8, 0.8)
		elif roll > 0.75:
			c = Color(1.0, 1.0, 0.85)
		mm.set_instance_color(i, c)

	var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	_tag_generated(inst)
	inst.multimesh = mm
	inst.material_override = mat
	container.add_child(inst)

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

	# ✅ Pick box for mothership (fits model AABB)
	_attach_pick_box(mothership_mesh, "mothership")

# ----------------------------
# Selection visuals
# ----------------------------

func update_selection_visuals() -> void:
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

	if mothership_node and mothership_mesh:
		var current_idx: int = int(mothership_node.get_current_system())
		if current_idx >= 0 and current_idx < systems.size():
			mothership_mesh.position = (systems[current_idx]["position"] as Vector3) + Vector3(0, 3, 0)

	_ensure_active_planets()
	_refresh_planet_highlights()
	_update_unit_indicators()

# ----------------------------
# Planets (unchanged from your current logic)
# ----------------------------

func _ensure_active_planets() -> void:
	var active: Array[int] = []

	if mothership_node:
		var cur: int = int(mothership_node.get_current_system())
		if cur >= 0 and cur < systems.size():
			active.append(cur)

	if selected_system_index >= 0 and selected_system_index < systems.size() and !active.has(selected_system_index):
		active.append(selected_system_index)

	for k in planet_meshes.keys():
		var sys_idx: int = int(k)
		if !active.has(sys_idx):
			_clear_planet_visuals(sys_idx)

	for sys_idx2 in active:
		var sys: Dictionary = systems[sys_idx2]
		if !bool(sys["scanned"]):
			_clear_planet_visuals(sys_idx2)
			continue

		if !planet_meshes.has(sys_idx2):
			planet_meshes[sys_idx2] = []
			orbit_meshes[sys_idx2] = []

			var planets: Array = sys["planets"]
			for p_idx in range(planets.size()):
				var p_data: Dictionary = planets[p_idx]

				var planet_node: MeshInstance3D = MeshInstance3D.new()
				_tag_generated(planet_node)
				var sm: SphereMesh = SphereMesh.new()
				sm.radius = 0.4
				sm.height = 0.8
				planet_node.mesh = sm

				planet_node.set_meta("system_index", sys_idx2)
				planet_node.set_meta("planet_index", p_idx)

				planet_node.material_override = _get_planet_material_cached(sys_idx2, p_idx, p_data, false)

				add_child(planet_node)
				(planet_meshes[sys_idx2] as Array).append(planet_node)

				# ✅ Pick sphere for planets
				_attach_pick_sphere(planet_node, 0.4 * 1.25, "planet", {"system_index": sys_idx2, "planet_index": p_idx})

				_draw_orbit_path(sys_idx2, float(p_data["orbit_radius"]))

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

	var keys := _planet_ring_nodes.keys()
	for k in keys:
		var parts := str(k).split(",")
		if parts.size() == 2 and int(parts[0]) == sys_idx:
			if is_instance_valid(_planet_ring_nodes[k]):
				(_planet_ring_nodes[k] as Node).queue_free()
			_planet_ring_nodes.erase(k)

# ----------------------------
# Miners indicators
# ----------------------------

func _update_unit_indicators() -> void:
	for k in unit_indicators.keys():
		for mesh in unit_indicators[k]:
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

		var is_active: bool = (s_idx == selected_system_index)
		if mothership_node:
			is_active = is_active or (s_idx == int(mothership_node.get_current_system()))
		if !is_active:
			continue

		unit_indicators[key] = []

		for _k2 in range(count):
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
# Process
# ----------------------------

func _process(_delta: float) -> void:
	var time: float = float(Time.get_ticks_msec()) * 0.001

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
# Drawing connections
# ----------------------------

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

# ----------------------------
# Star type
# ----------------------------

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
