extends Node
class_name StarRenderer

# Manages star meshes, visual properties, and selection highlighting
# Now separated from GalaxyMap3D logic

const PLANET_SCENE_BASE: String = "res://addons/naejimer_3d_planet_generator/scenes/"

# Reference to main map for adding children etc
var _map_root: Node3D

func _init(map_root: Node3D) -> void:
	_map_root = map_root

# ----------------------------
# Star Creation
# ----------------------------

func create_star(system_data: Dictionary, pos: Vector3, sys_idx: int) -> Node3D:
	var star_type: String = str(system_data.get("star_type", "G"))
	var star_visuals: Dictionary = _get_star_visuals(star_type)
	
	var star_scene: Variant = load(PLANET_SCENE_BASE + "star.tscn")
	var star_mesh: Node3D
	
	if star_scene != null and star_scene is PackedScene:
		star_mesh = (star_scene as PackedScene).instantiate()
		star_mesh.transform = Transform3D.IDENTITY
		var s_size: float = float(star_visuals["size"])
		star_mesh.scale = Vector3(s_size, s_size, s_size)
		star_mesh.position = pos

		_apply_star_shader_colors(star_mesh, star_type)
	else:
		# Fallback: basic sphere
		var fb: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = float(star_visuals["size"])
		sm.height = float(star_visuals["size"]) * 2.0
		fb.mesh = sm
		fb.position = pos
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.5, 0.5)
		mat.emission_enabled = true
		mat.emission = star_visuals["color"]
		mat.emission_energy_multiplier = 1.0
		fb.material_override = mat
		star_mesh = fb

	# Metadata for picking
	star_mesh.set_meta("_gen", true)
	star_mesh.set_meta("system_index", sys_idx)
	
	_map_root.add_child(star_mesh)
	
	# Add pick sphere
	# Note: Calling back to map helper or duplicating helper logic?
	# Better to duplicate simple helper logic here or expose it
	_attach_pick_sphere(star_mesh, 0.5, "system", {"system_index": sys_idx})
	
	return star_mesh

func create_starfield() -> void:
	var star_count: int = 450
	var container: Node3D = Node3D.new()
	container.name = "Starfield"
	container.set_meta("_gen", true)
	_map_root.add_child(container)

	var tiny: SphereMesh = SphereMesh.new()
	tiny.radius = 0.08
	tiny.height = 0.16
	tiny.radial_segments = 6
	tiny.rings = 3

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tiny
	mm.instance_count = star_count

	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	for i in range(star_count):
		var pos: Vector3 = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.4, 0.4), # flatter disk
			rng.randf_range(-1.0, 1.0)
		).normalized() * rng.randf_range(200.0, 450.0)

		var t: Transform3D = Transform3D(Basis(), pos)
		mm.set_instance_transform(i, t)

		var c: Color = Color(1.0, 1.0, 1.0)
		var roll: float = rng.randf()
		if roll < 0.15:
			c = Color(0.4, 0.6, 1.0) # blue
		elif roll > 0.85:
			c = Color(1.0, 0.5, 0.4) # red
		elif roll > 0.75:
			c = Color(1.0, 1.0, 0.85) # yellow-white
		
		# Alpha fade based on distance (fake)
		c.a = rng.randf_range(0.3, 0.8)
		mm.set_instance_color(i, c)

	var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
	inst.set_meta("_gen", true)
	inst.multimesh = mm
	inst.material_override = mat
	container.add_child(inst)

# ----------------------------
# Visual Updates
# ----------------------------

func update_selection(star_mesh: Node3D, is_selected: bool, is_scanned: bool) -> void:
	if star_mesh == null: return
	
	# Shader-based star: adjust atmosphere intensity
	var atmo: MeshInstance3D = star_mesh.get_node_or_null("Atmosphere") as MeshInstance3D
	if atmo and atmo.mesh:
		var mat: ShaderMaterial = atmo.mesh.material as ShaderMaterial
		if mat:
			if is_selected:
				mat.set_shader_parameter("intensity", 20.0)
			elif is_scanned:
				mat.set_shader_parameter("intensity", 14.0)
			else:
				mat.set_shader_parameter("intensity", 5.0) # Matches 'fix' value
		return

	# Fallback: StandardMaterial3D star
	if star_mesh is MeshInstance3D:
		var mat2 := (star_mesh as MeshInstance3D).material_override as StandardMaterial3D
		if mat2:
			if is_selected:
				mat2.emission_energy_multiplier = 4.0
			elif is_scanned:
				mat2.emission_energy_multiplier = 2.0
			else:
				mat2.emission_energy_multiplier = 0.5

# ----------------------------
# Internal Helpers
# ----------------------------

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

func _get_star_shader_colors(t: String) -> Dictionary:
	# c1 = dark base, c2 = mid tone, c3 = bright highlight
	# emit = per-type emission
	match t:
		"O": return {"c1": Color(0.02, 0.04, 0.18), "c2": Color(0.15, 0.4, 0.9),  "c3": Color(0.5, 0.7, 1.0),  "emit": 0.8}
		"B": return {"c1": Color(0.04, 0.08, 0.25), "c2": Color(0.35, 0.55, 0.9), "c3": Color(0.7, 0.85, 1.0), "emit": 0.7}
		"A": return {"c1": Color(0.15, 0.15, 0.2),  "c2": Color(0.6, 0.6, 0.75),  "c3": Color(0.9, 0.9, 1.0),  "emit": 0.5}
		"F": return {"c1": Color(0.2, 0.18, 0.05),  "c2": Color(0.7, 0.65, 0.3),  "c3": Color(1.0, 0.95, 0.6), "emit": 0.6}
		"G": return {"c1": Color(0.25, 0.15, 0.0),  "c2": Color(0.8, 0.6, 0.1),   "c3": Color(1.0, 0.85, 0.3), "emit": 0.8}
		"K": return {"c1": Color(0.2, 0.06, 0.0),   "c2": Color(0.8, 0.35, 0.05), "c3": Color(1.0, 0.6, 0.2),  "emit": 1.0}
		"M": return {"c1": Color(0.18, 0.03, 0.0),  "c2": Color(0.7, 0.2, 0.02),  "c3": Color(1.0, 0.4, 0.1),  "emit": 1.5}
	return {"c1": Color(0.25, 0.15, 0.0), "c2": Color(0.8, 0.6, 0.1), "c3": Color(1.0, 0.85, 0.3), "emit": 0.8}

func _apply_star_shader_colors(star_mesh: Node3D, type: String) -> void:
	# Recolor body shader
	var body_mi: MeshInstance3D = star_mesh as MeshInstance3D
	if body_mi and body_mi.mesh:
		var body_mat: ShaderMaterial = body_mi.mesh.material as ShaderMaterial
		if body_mat:
			var sc: Dictionary = _get_star_shader_colors(type)
			body_mat = body_mat.duplicate() as ShaderMaterial
			body_mat.set_shader_parameter("color_1", sc["c1"])
			body_mat.set_shader_parameter("color_2", sc["c2"])
			body_mat.set_shader_parameter("color_3", sc["c3"])
			body_mat.set_shader_parameter("color_4", sc["c2"])
			body_mat.set_shader_parameter("color_5", sc["c3"])
			body_mat.set_shader_parameter("emit", sc.get("emit", 1.0))
			body_mi.mesh = body_mi.mesh.duplicate()
			(body_mi.mesh as SphereMesh).material = body_mat

	# Recolor atmosphere
	var atmo: MeshInstance3D = star_mesh.get_node_or_null("Atmosphere") as MeshInstance3D
	if atmo and atmo.mesh:
		var atmo_mat: ShaderMaterial = atmo.mesh.material as ShaderMaterial
		if atmo_mat:
			var sc2: Dictionary = _get_star_shader_colors(type)
			atmo_mat = atmo_mat.duplicate() as ShaderMaterial
			atmo_mat.set_shader_parameter("color_1", sc2["c1"])
			atmo_mat.set_shader_parameter("color_2", sc2["c3"])
			atmo_mat.set_shader_parameter("intensity", 5.0)
			atmo.mesh = atmo.mesh.duplicate()
			(atmo.mesh as SphereMesh).material = atmo_mat

func _get_combined_local_aabb(root: Node) -> AABB:
	var have: bool = false
	var combined: AABB = AABB()
	for n in root.get_children():
		if n is Node:
			var child_aabb: AABB = _get_combined_local_aabb(n)
			if child_aabb.size != Vector3.ZERO:
				if !have:
					combined = child_aabb
					have = true
				else:
					combined = combined.merge(child_aabb)
	
	if root is VisualInstance3D:
		var aabb: AABB = (root as VisualInstance3D).get_aabb()
		if !have:
			combined = aabb
			have = true
		else:
			combined = combined.merge(aabb)
			
	return combined if have else AABB(Vector3.ZERO, Vector3.ZERO)

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
