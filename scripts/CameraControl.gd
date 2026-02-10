extends Node3D

@export var rotation_speed: float = 0.5
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 100.0

@export var move_speed: float = 20.0

var _is_rotating: bool = false
var _last_mouse_pos: Vector2

@onready var camera = $Camera3D
@onready var pivot = self

func _process(delta):
	_handle_keyboard_movement(delta)

func _handle_keyboard_movement(delta):
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir += transform.basis.x
	
	# Keep movement horizontal
	input_dir.y = 0
	input_dir = input_dir.normalized()
	
	pivot.global_position += input_dir * move_speed * delta

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = event.pressed
			_last_mouse_pos = event.position
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_speed)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_speed)

	if event is InputEventMouseMotion and _is_rotating:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		
		# Rotate horizontal (around Y axis)
		pivot.rotate_y(deg_to_rad(-delta.x * rotation_speed))
		# Rotate vertical (around X axis)
		var current_rot_x = rotation_degrees.x
		var new_rot_x = clamp(current_rot_x - delta.y * rotation_speed, -80, 0)
		rotation_degrees.x = new_rot_x

func _zoom(amount: float):
	var pos = camera.position
	pos.z = clamp(pos.z + amount, min_zoom, max_zoom)
	camera.position = pos
