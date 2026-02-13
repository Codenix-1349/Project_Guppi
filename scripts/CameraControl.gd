extends Node3D

@export var rotation_speed: float = 0.5        # mouse rotation multiplier
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 100.0
@export var move_speed: float = 20.0

# Keyboard rotation (degrees per second)
@export var yaw_speed_deg: float = 120.0        # Q/E
@export var pitch_speed_deg: float = 60.0       # LShift / LAlt

# Pitch limits (degrees)
@export var min_pitch_deg: float = -80.0
@export var max_pitch_deg: float = 20.0

var _is_rotating: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var pivot: Node3D = self

func _process(delta: float) -> void:
	_handle_keyboard_movement(delta)
	_handle_keyboard_yaw(delta)
	_handle_keyboard_pitch(delta)

func _handle_keyboard_movement(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir += transform.basis.x

	# Keep movement horizontal
	input_dir.y = 0.0

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		pivot.global_position += input_dir * move_speed * delta

func _handle_keyboard_yaw(delta: float) -> void:
	# Q = left, E = right (rotate around Y axis)
	var dir := 0.0
	if Input.is_key_pressed(KEY_Q):
		dir -= 1.0
	if Input.is_key_pressed(KEY_E):
		dir += 1.0

	if dir != 0.0:
		# Using rotate_y keeps it relative to current orientation
		pivot.rotate_y(deg_to_rad(dir * yaw_speed_deg * delta))

func _handle_keyboard_pitch(delta: float) -> void:
	# LShift = tilt down, LAlt = tilt up (rotate around X axis / pitch)
	var dir := 0.0
	if Input.is_key_pressed(KEY_SHIFT):      # left+right shift, see note below
		dir -= 1.0                            # tilt down
	if Input.is_key_pressed(KEY_ALT):        # left+right alt, see note below
		dir += 1.0                            # tilt up

	if dir != 0.0:
		var new_pitch: float = rotation_degrees.x + dir * pitch_speed_deg * delta
		rotation_degrees.x = clamp(new_pitch, min_pitch_deg, max_pitch_deg)

func _input(event: InputEvent) -> void:
	# Mouse Buttons (casted)
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = mb.pressed
			_last_mouse_pos = mb.position

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-zoom_speed)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(zoom_speed)

	# Mouse Motion (casted)
	if event is InputEventMouseMotion and _is_rotating:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion

		var delta_pos: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position

		# Rotate horizontal (around Y axis)
		pivot.rotate_y(deg_to_rad(-delta_pos.x * rotation_speed))

		# Rotate vertical (around X axis)
		var current_rot_x: float = rotation_degrees.x
		var new_rot_x: float = clamp(current_rot_x - delta_pos.y * rotation_speed, min_pitch_deg, max_pitch_deg)
		rotation_degrees.x = new_rot_x

func _zoom(amount: float) -> void:
	var pos: Vector3 = camera.position
	pos.z = clamp(pos.z + amount, min_zoom, max_zoom)
	camera.position = pos

func focus_on(target_pos: Vector3) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(pivot, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_SINE)

	var target_zoom: float = min(camera.position.z, 20.0)
	tween.tween_property(camera, "position:z", target_zoom, 0.5).set_trans(Tween.TRANS_SINE)
