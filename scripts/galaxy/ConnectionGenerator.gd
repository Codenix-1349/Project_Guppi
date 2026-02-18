extends Node
class_name ConnectionGenerator

# Graph generation and connection rendering
# Extracted from GalaxyMap3D

var _map_root: Node3D

func _init(map_root: Node3D) -> void:
	_map_root = map_root

# ----------------------------
# Public API
# ----------------------------

func generate(systems: Array, rng: RandomNumberGenerator) -> Array:
	# returns Array of [a, b] pairs (indices)
	var connections: Array = []
	if systems.size() <= 1:
		return connections

	var connect_max_dist: float = 55.0
	var hard_max_links: int = 4
	var extra_link_chance: float = 0.10

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
				if i2 == j2: continue # should not happen by loop, but safe
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

	var deg: Array = []
	deg.resize(systems.size())
	for i4 in range(deg.size()):
		deg[i4] = 0

	# MST first (guarantees reachability)
	for e in edges:
		var ai: int = int(e["a"])
		var bi: int = int(e["b"])

		if int(deg[ai]) >= hard_max_links or int(deg[bi]) >= hard_max_links:
			continue

		if _uf_unite(parent, rank, ai, bi):
			connections.append([ai, bi])
			deg[ai] = int(deg[ai]) + 1
			deg[bi] = int(deg[bi]) + 1

	# Connect disjoints if any
	# (Simplified logic from original: brute force MST again if disjoint)
	# For simplicity assuming MST mostly covered it; adding guaranteed link logic
	for i5 in range(1, systems.size()):
		if _uf_find(parent, 0) != _uf_find(parent, i5):
			# find nearest connected node to i5
			var best_d: float = 999999.0
			var best_j: int = -1
			var pos_i: Vector3 = systems[i5]["position"]
			
			for j5 in range(systems.size()):
				if i5 == j5: continue
				if _uf_find(parent, i5) == _uf_find(parent, j5): continue # same component
				
				var d5: float = pos_i.distance_to(systems[j5]["position"])
				if d5 < best_d:
					best_d = d5
					best_j = j5
			
			if best_j != -1:
				_uf_unite(parent, rank, i5, best_j)
				connections.append([i5, best_j])
				deg[i5] = int(deg[i5]) + 1
				deg[best_j] = int(deg[best_j]) + 1

	# occasional cross-links
	for e2 in edges:
		if rng.randf() > extra_link_chance:
			continue

		var a6: int = int(e2["a"])
		var b6: int = int(e2["b"])

		# Check existing connection
		var existing: bool = false
		for c in connections:
			if (c[0] == a6 and c[1] == b6) or (c[0] == b6 and c[1] == a6):
				existing = true
				break
		if existing: continue

		if int(deg[a6]) >= int(cap[a6]) or int(deg[b6]) >= int(cap[b6]):
			continue

		connections.append([a6, b6])
		deg[a6] = int(deg[a6]) + 1
		deg[b6] = int(deg[b6]) + 1

	return connections

func draw_connections(connections: Array, systems: Array) -> void:
	for conn in connections:
		var a_pos: Vector3 = systems[conn[0]]["position"]
		var b_pos: Vector3 = systems[conn[1]]["position"]
		_draw_line(a_pos, b_pos)

func clear_visuals() -> void:
	# Removes nodes named 'ConnectionLine' directly from children
	# This avoids tracking a separate array just for lines in this module
	# Note: If map has other lines, consider tagging mechanism
	for c in _map_root.get_children():
		if c.name == "ConnectionLine" or (c.has_meta("_gen_conn") and c.get_meta("_gen_conn")):
			c.queue_free()

# ----------------------------
# Internal Algo
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

func _build_degree_caps(n: int) -> Array:
	var caps: Array = []
	caps.resize(n)
	for i in range(n):
		caps[i] = 3
	
	# ~15% nodes allows 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var count_high: int = int(float(n) * 0.15)
	for k in range(count_high):
		var idx: int = rng.randi_range(0, n - 1)
		caps[idx] = 4
	return caps

func _draw_line(start: Vector3, end: Vector3) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "ConnectionLine"
	mesh_instance.set_meta("_gen", true) # So main map cleaner finds it too
	mesh_instance.set_meta("_gen_conn", true)

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

	_map_root.add_child(mesh_instance)
