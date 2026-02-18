# === scripts/ui/IconRenderer.gd ===
extends Node
class_name IconRenderer
## Renders 3D GLB models (Kenney Space Kit) into thumbnail textures
## via SubViewport. Used for combat UI unit icons.

# Kenney GLTF base dirs (robust: both naming variants)
const KENNEY_GLTFS: Array[String] = [
	"res://kenney-space-kit/Models/GLTF format/",
	"res://kenney_space-kit/Models/GLTF format/",
]

const ICON_SIZE: int = 64
const ICON_BG: Color = Color(0.05, 0.06, 0.08, 1.0)

var _icon_cache: Dictionary = {}       # key:String -> Texture2D
var _icon_viewports: Dictionary = {}   # key:String -> SubViewport (kept alive)

# -----------------------------------------------
# Public API
# -----------------------------------------------

## Returns a cached or freshly rendered thumbnail for the given unit.
func get_unit_icon(unit_id: String, unit_name: String) -> Texture2D:
	var glb_path: String = _get_glb_for_unit_id(unit_id, unit_name)
	var cache_key: String = unit_id + "|" + unit_name
	return _render_glb_thumbnail(glb_path, cache_key)

# -----------------------------------------------
# GLB path resolution
# -----------------------------------------------

func _kenney_find(glb_name: String) -> String:
	for bv in KENNEY_GLTFS:
		var base: String = str(bv)
		var p: String = base + glb_name
		if ResourceLoader.exists(p):
			return p
	return ""

func _get_glb_for_unit_id(unit_id: String, unit_name: String) -> String:
	# Player units
	if unit_id == "mothership":
		return _kenney_find("craft_cargoB.glb")
	if unit_id == "miner_v1":
		return _kenney_find("craft_miner.glb")
	if unit_id == "defender_v1":
		return _kenney_find("craft_speederB.glb")
	if unit_id == "scout_v1":
		return _kenney_find("craft_racer.glb")

	# Enemies: map by name keywords (safe fallback)
	var n: String = unit_name.to_lower()
	if n.find("corsair") != -1:
		return _kenney_find("craft_speederA.glb")
	if n.find("swarm") != -1:
		return _kenney_find("craft_speederC.glb")
	if n.find("fortress") != -1:
		return _kenney_find("craft_cargoA.glb")
	if n.find("sentry") != -1:
		return _kenney_find("craft_speederD.glb")

	# generic enemy fallback
	return _kenney_find("craft_speederA.glb")

# -----------------------------------------------
# Thumbnail rendering
# -----------------------------------------------

func _make_fallback_texture(seed_str: String) -> Texture2D:
	var img: Image = Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(ICON_BG)

	var hval: int = int(abs(int(seed_str.hash()))) % 255
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			if ((x + y) % 16) < 4:
				img.set_pixel(x, y, Color(float(hval) / 255.0, 0.4, 0.8, 1.0))

	return ImageTexture.create_from_image(img)

func _collect_mesh_aabb(root: Node) -> AABB:
	var have: bool = false
	var out: AABB = AABB(Vector3.ZERO, Vector3.ONE)
	var stack: Array = [root]

	while stack.size() > 0:
		var n: Variant = stack.pop_back()
		if n is Node:
			for c in (n as Node).get_children():
				stack.append(c)

		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh:
				var local_aabb: AABB = mi.mesh.get_aabb()
				var corners: Array[Vector3] = [
					local_aabb.position,
					local_aabb.position + Vector3(local_aabb.size.x, 0, 0),
					local_aabb.position + Vector3(0, local_aabb.size.y, 0),
					local_aabb.position + Vector3(0, 0, local_aabb.size.z),
					local_aabb.position + Vector3(local_aabb.size.x, local_aabb.size.y, 0),
					local_aabb.position + Vector3(local_aabb.size.x, 0, local_aabb.size.z),
					local_aabb.position + Vector3(0, local_aabb.size.y, local_aabb.size.z),
					local_aabb.position + local_aabb.size
				]

				for cpos in corners:
					var world_p: Vector3 = mi.global_transform * cpos
					var root_space_p: Vector3 = root.global_transform.affine_inverse() * world_p
					if not have:
						out = AABB(root_space_p, Vector3(0.001, 0.001, 0.001))
						have = true
					else:
						out = out.expand(root_space_p)

	if not have:
		return AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	return out

func _render_glb_thumbnail(glb_path: String, cache_key: String) -> Texture2D:
	if _icon_cache.has(cache_key):
		return _icon_cache[cache_key] as Texture2D

	if glb_path == "" or not ResourceLoader.exists(glb_path):
		print("THUMBNAIL: GLB NOT FOUND -> ", glb_path, " key=", cache_key)
		var fb: Texture2D = _make_fallback_texture(cache_key)
		_icon_cache[cache_key] = fb
		return fb

	# SubViewport must live to keep texture valid
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(ICON_SIZE, ICON_SIZE)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	_icon_viewports[cache_key] = vp

	var vt: Texture2D = vp.get_texture()

	# World root
	var root: Node3D = Node3D.new()
	vp.add_child(root)

	# Environment
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65, 1.0)
	env.ambient_light_energy = 1.2

	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	# Lights
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.light_energy = 2.4
	key_light.rotation_degrees = Vector3(-45, 45, 0)
	root.add_child(key_light)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_energy = 1.2
	fill.rotation_degrees = Vector3(-15, -135, 0)
	root.add_child(fill)

	# Camera
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 38.0
	cam.current = true
	root.add_child(cam)

	# Instance model
	var ps: Variant = load(glb_path)
	if ps == null or not (ps is PackedScene):
		print("THUMBNAIL: LOAD FAILED -> ", glb_path)
		vp.queue_free()
		_icon_viewports.erase(cache_key)
		var fb2: Texture2D = _make_fallback_texture(cache_key + "_loadfail")
		_icon_cache[cache_key] = fb2
		return fb2

	var inst: Node3D = (ps as PackedScene).instantiate()
	root.add_child(inst)

	# Auto framing (AABB)
	var aabb: AABB = _collect_mesh_aabb(inst)
	var center: Vector3 = aabb.position + aabb.size * 0.5
	inst.position -= center

	var size_len: float = maxf(0.6, aabb.size.length())
	var radius: float = size_len * 0.55

	# 3/4 view
	cam.position = Vector3(radius * 0.55, radius * 0.35, radius * 1.35)
	cam.look_at(Vector3.ZERO, Vector3.UP)

	# Cache
	_icon_cache[cache_key] = vt
	return vt
