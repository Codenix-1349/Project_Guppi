# === scripts/ui/SelectionHandler.gd ===
extends Node
class_name SelectionHandler
## Handles 3D raycast picking for star systems, planets, and the mothership.

signal selection_changed()

# Must match GalaxyMap3D pick layer
const PICK_LAYER_BIT: int = 10
const PICK_LAYER_MASK: int = 1 << PICK_LAYER_BIT

var galaxy_map: Node = null
var camera_pivot: Node3D = null

# -----------------------------------------------
# Initialization
# -----------------------------------------------

func init(p_galaxy_map: Node, p_camera_pivot: Node3D) -> void:
	galaxy_map = p_galaxy_map
	camera_pivot = p_camera_pivot

# -----------------------------------------------
# Input
# -----------------------------------------------

func handle_click(mouse_pos: Vector2, is_double_click: bool) -> void:
	if galaxy_map == null or camera_pivot == null:
		return
	_process_3d_selection(mouse_pos, is_double_click)

# -----------------------------------------------
# Raycast selection
# -----------------------------------------------

func _process_3d_selection(mouse_pos: Vector2, is_double_click: bool = false) -> void:
	var cam: Camera3D = camera_pivot.get_node_or_null("Camera3D")
	if cam == null:
		return

	var origin: Vector3 = cam.project_ray_origin(mouse_pos)
	var dir: Vector3 = cam.project_ray_normal(mouse_pos).normalized()
	var to: Vector3 = origin + dir * 5000.0

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = PICK_LAYER_MASK

	var world: World3D = cam.get_world_3d()
	if world == null:
		return
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var hit: Dictionary = space.intersect_ray(query)

	if hit.is_empty():
		galaxy_map.selected_system_index = -1
		galaxy_map.selected_planet_index = -1
		galaxy_map.update_selection_visuals()
		emit_signal("selection_changed")
		return

	var col: Object = hit.get("collider", null)
	if col == null:
		return
	if not (col is Node):
		return

	var n: Node = col as Node
	var pick_type: String = str(n.get_meta("pick_type", ""))

	match pick_type:
		"mothership":
			galaxy_map.selected_system_index = -2
			galaxy_map.selected_planet_index = -1
			galaxy_map.update_selection_visuals()
			emit_signal("selection_changed")
			if is_double_click and galaxy_map.mothership_mesh:
				camera_pivot.focus_on(galaxy_map.mothership_mesh.global_position)
			return

		"system":
			var idx: int = int(n.get_meta("system_index", -1))
			if idx >= 0:
				galaxy_map.selected_system_index = idx
				galaxy_map.selected_planet_index = -1
				galaxy_map.update_selection_visuals()
				emit_signal("selection_changed")
				if is_double_click and idx < galaxy_map.systems.size():
					var sys_pos: Vector3 = galaxy_map.systems[idx]["position"]
					camera_pivot.focus_on(sys_pos)
			return

		"planet":
			var s_idx: int = int(n.get_meta("system_index", -1))
			var p_idx: int = int(n.get_meta("planet_index", -1))
			if s_idx >= 0 and p_idx >= 0:
				galaxy_map.selected_system_index = s_idx
				galaxy_map.selected_planet_index = p_idx
				galaxy_map.update_selection_visuals()
				emit_signal("selection_changed")
				if is_double_click and galaxy_map.planet_meshes.has(s_idx):
					var p_mesh: Variant = galaxy_map.planet_meshes[s_idx][p_idx]
					if p_mesh:
						camera_pivot.focus_on((p_mesh as Node3D).global_position)
			return

		_:
			galaxy_map.selected_system_index = -1
			galaxy_map.selected_planet_index = -1
			galaxy_map.update_selection_visuals()
			emit_signal("selection_changed")
			return
