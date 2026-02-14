extends Node3D

@export var rotation_speed: float = 0.5        # mouse rotation multiplier
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 100.0
@export var move_speed: float = 20.0

# Keyboard rotation (degrees per second)
@export var yaw_speed_deg: float = 120.0        # Q/E
@export var pitch_speed_deg: float = 60.0       # Shift / Alt

# Pitch limits (degrees)
@export var min_pitch_deg: float = -80.0
@export var max_pitch_deg: float = 20.0

# --- Intro orbit + idle screensaver orbit ---
@export var orbit_enabled: bool = true
@export var intro_seconds_to_start: float = 2.0        # only once after boot
@export var idle_seconds_to_start: float = 90.0        # after user activity
@export var orbit_yaw_deg_per_sec: float = 8.0         # orbit speed
@export var orbit_pitch_deg: float = -25.0             # view angle while orbiting

var _is_rotating: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var pivot: Node3D = self

var _idle_time: float = 0.0
var _autopilot: bool = false

# ✅ ensures the 2s intro orbit happens only once
var _intro_done: bool = false

func _ready() -> void:
	_idle_time = 0.0
	_autopilot = false
	_intro_done = false

func _process(delta: float) -> void:
	_idle_time += delta

	if orbit_enabled:
		# ✅ Intro orbit: only once, only if user has not interacted yet
		if (not _intro_done) and (not _autopilot) and (_idle_time >= intro_seconds_to_start):
			_enable_autopilot(true)

		# ✅ Idle orbit: only after intro is done AND user was idle long enough
		if _intro_done and (not _autopilot) and (_idle_time >= idle_seconds_to_start):
			_enable_autopilot(true)

	if _autopilot:
		_run_orbit(delta)
		return

	_handle_keyboard_movement(delta)
	_handle_keyboard_yaw(delta)
	_handle_keyboard_pitch(delta)

func _run_orbit(delta: float) -> void:
	# Keep a pleasant pitch while orbiting
	var target_pitch: float = float(clamp(orbit_pitch_deg, min_pitch_deg, max_pitch_deg))
	var cur_pitch: float = float(rotation_degrees.x)
	rotation_degrees.x = lerp(cur_pitch, target_pitch, 5.0 * delta)

	# Orbit by slowly yawing around Y
	pivot.rotate_y(deg_to_rad(orbit_yaw_deg_per_sec * delta))

func _enable_autopilot(on: bool) -> void:
	_autopilot = on
	if on:
		_is_rotating = false

func _mark_user_activity() -> void:
	# ✅ first ever user input ends the intro phase permanently
	_intro_done = true

	_idle_time = 0.0
	if _autopilot:
		_enable_autopilot(false)

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
		_mark_user_activity()
		input_dir = input_dir.normalized()
		pivot.global_position += input_dir * move_speed * delta

func _handle_keyboard_yaw(delta: float) -> void:
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_Q):
		dir -= 1.0
	if Input.is_key_pressed(KEY_E):
		dir += 1.0

	if dir != 0.0:
		_mark_user_activity()
		pivot.rotate_y(deg_to_rad(dir * yaw_speed_deg * delta))

func _handle_keyboard_pitch(delta: float) -> void:
	var dir: float = 0.0
	if Input.is_key_pressed(KEY_SHIFT):
		dir -= 1.0
	if Input.is_key_pressed(KEY_ALT):
		dir += 1.0

	if dir != 0.0:
		_mark_user_activity()
		var new_pitch: float = float(rotation_degrees.x) + dir * pitch_speed_deg * delta
		rotation_degrees.x = float(clamp(new_pitch, min_pitch_deg, max_pitch_deg))

func _input(event: InputEvent) -> void:
	# Any meaningful input counts as activity.
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if k.pressed:
			_mark_user_activity()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if mb.pressed:
			_mark_user_activity()

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_rotating = mb.pressed
			_last_mouse_pos = mb.position

		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_mark_user_activity()
			_zoom(-zoom_speed)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_mark_user_activity()
			_zoom(zoom_speed)

	if event is InputEventMouseMotion and _is_rotating:
		_mark_user_activity()
		var mm: InputEventMouseMotion = event as InputEventMouseMotion

		var delta_pos: Vector2 = mm.position - _last_mouse_pos
		_last_mouse_pos = mm.position

		pivot.rotate_y(deg_to_rad(-delta_pos.x * rotation_speed))

		var current_rot_x: float = float(rotation_degrees.x)
		var new_rot_x: float = float(clamp(current_rot_x - delta_pos.y * rotation_speed, min_pitch_deg, max_pitch_deg))
		rotation_degrees.x = new_rot_x

func _zoom(amount: float) -> void:
	var pos: Vector3 = camera.position
	pos.z = float(clamp(pos.z + amount, min_zoom, max_zoom))
	camera.position = pos

func focus_on(target_pos: Vector3) -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(pivot, "global_position", target_pos, 0.5).set_trans(Tween.TRANS_SINE)

	var target_zoom: float = min(camera.position.z, 20.0)
	tween.tween_property(camera, "position:z", target_zoom, 0.5).set_trans(Tween.TRANS_SINE)
