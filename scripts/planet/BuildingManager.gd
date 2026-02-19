# res://scripts/planet/BuildingManager.gd
extends Node
class_name BuildingManager

signal placement_started
signal placement_cancelled
signal building_placed(building_id: String, cell: Vector2i, world_pos: Vector3)

# IMPORTANT: this is the DATA grid type now
var _grid: TerrainGrid.TerrainGridData
var _camera: Camera3D

var _occupied: Dictionary = {}

var _is_placing: bool = false
var _building_id: String = ""
var _hover_cell: Vector2i = Vector2i(-1, -1)

var _ghost: Node3D
var _ghost_mesh: MeshInstance3D

var _ray_length: float = 5000.0


func setup(grid_data: TerrainGrid.TerrainGridData, camera: Camera3D) -> void:
	_grid = grid_data
	_camera = camera


func start_placement(building_id: String = "default") -> void:
	if _grid == null or _camera == null:
		push_warning("BuildingManager.start_placement(): grid or camera not set yet.")
		return

	_building_id = building_id
	_is_placing = true
	_hover_cell = Vector2i(-1, -1)

	_create_ghost()
	placement_started.emit()


func cancel_placement() -> void:
	if not _is_placing:
		return

	_is_placing = false
	_building_id = ""
	_hover_cell = Vector2i(-1, -1)

	if is_instance_valid(_ghost):
		_ghost.queue_free()

	placement_cancelled.emit()


func is_cell_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


func occupy_cell(cell: Vector2i) -> void:
	_occupied[cell] = true


func _unhandled_input(event: InputEvent) -> void:
	if not _is_placing:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_placement()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _hover_cell.x == -1:
			return
		if _is_valid_cell(_hover_cell):
			_place_at(_hover_cell)
		return


func _process(_delta: float) -> void:
	if not _is_placing:
		return

	var hit: Dictionary = _raycast_mouse()
	if hit.is_empty():
		_set_ghost_visible(false)
		_hover_cell = Vector2i(-1, -1)
		return

	var world_pos: Vector3 = hit["position"] as Vector3
	var cell: Vector2i = _grid.world_to_grid(world_pos)

	if not _grid.in_bounds(cell.x, cell.y):
		_set_ghost_visible(false)
		_hover_cell = Vector2i(-1, -1)
		return

	_hover_cell = cell
	_set_ghost_visible(true)

	var snapped_pos: Vector3 = _grid.grid_to_world(cell.x, cell.y)
	_ghost.position = snapped_pos

	_apply_ghost_valid(_is_valid_cell(cell))


func _is_valid_cell(cell: Vector2i) -> bool:
	if not _grid.in_bounds(cell.x, cell.y):
		return false
	if not _grid.is_walkable(cell.x, cell.y):
		return false
	if is_cell_occupied(cell):
		return false
	return true


func _place_at(cell: Vector2i) -> void:
	occupy_cell(cell)

	var world_pos: Vector3 = _grid.grid_to_world(cell.x, cell.y)

	var building := Node3D.new()
	building.name = "Building_%s_%d_%d" % [_building_id, cell.x, cell.y]
	building.position = world_pos

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_grid.cell_size * 0.9, _grid.cell_size * 0.5, _grid.cell_size * 0.9)
	mesh.mesh = box
	mesh.position = Vector3(0.0, box.size.y * 0.5, 0.0)
	building.add_child(mesh)

	get_parent().add_child(building)

	building_placed.emit(_building_id, cell, world_pos)
	cancel_placement()


func _raycast_mouse() -> Dictionary:
	if _camera == null:
		return {}

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = _camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = _camera.project_ray_normal(mouse_pos)
	var ray_end: Vector3 = ray_origin + ray_dir * _ray_length

	var space_state: PhysicsDirectSpaceState3D = _camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	var result: Dictionary = space_state.intersect_ray(query)
	return result


func _create_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()

	_ghost = Node3D.new()
	_ghost.name = "GhostPreview"
	get_parent().add_child(_ghost)

	_ghost_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_grid.cell_size * 0.9, _grid.cell_size * 0.9)
	_ghost_mesh.mesh = plane
	_ghost_mesh.rotation_degrees.x = -90.0
	_ghost_mesh.position = Vector3(0.0, 0.05, 0.0)
	_ghost.add_child(_ghost_mesh)

	_set_ghost_visible(false)
	_apply_ghost_valid(false)


func _set_ghost_visible(v: bool) -> void:
	if is_instance_valid(_ghost):
		_ghost.visible = v


func _apply_ghost_valid(is_valid: bool) -> void:
	if not is_instance_valid(_ghost_mesh):
		return

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55 if is_valid else 0.20
	_ghost_mesh.material_override = mat
