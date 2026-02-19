extends Node
class_name UnitManager

var _camera: Camera3D
var _selected_units: Array[Unit] = []
var _is_active: bool = true # Can be disabled if Building Mode is active

func setup(camera: Camera3D) -> void:
	_camera = camera

func _unhandled_input(event: InputEvent) -> void:
	if !_is_active: return
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_selection(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_move_command(event.position)

func _handle_selection(mouse_pos: Vector2, add_to_selection: bool) -> void:
	var result = _raycast(mouse_pos)
	if result and result.collider is Unit:
		var unit = result.collider
		if add_to_selection:
			if unit in _selected_units:
				_deselect(unit)
			else:
				_select(unit)
		else:
			_clear_selection()
			_select(unit)
	else:
		if !add_to_selection:
			_clear_selection()

func _handle_move_command(mouse_pos: Vector2) -> void:
	if _selected_units.is_empty(): return
	
	var result = _raycast(mouse_pos)
	if result:
		var target_pos = result.position
		for unit in _selected_units:
			unit.move_to(target_pos)
			
		# Visual indicator?
		# spawn_move_marker(target_pos)

func _raycast(mouse_pos: Vector2) -> Dictionary:
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * 2000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	# query.collision_mask = ... # Terrain + Units
	return _camera.get_world_3d().direct_space_state.intersect_ray(query)

func _select(unit: Unit) -> void:
	_selected_units.append(unit)
	unit.set_selected(true)

func _deselect(unit: Unit) -> void:
	_selected_units.erase(unit)
	unit.set_selected(false)

func _clear_selection() -> void:
	for u in _selected_units:
		u.set_selected(false)
	_selected_units.clear()

func set_active(active: bool) -> void:
	_is_active = active
	if !active:
		_clear_selection()
