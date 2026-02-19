extends Node3D

# RTS Camera Controller
# Attach to a Node3D "Rig" that contains a Camera3D child.

# Settings
@export_group("Movement")
@export var move_speed: float = 20.0
@export var boost_multiplier: float = 2.5
@export var pan_smooth: float = 10.0

@export_group("Zoom")
@export var min_zoom: float = 5.0
@export var max_zoom: float = 50.0
@export var zoom_speed: float = 5.0
@export var zoom_smooth: float = 10.0

@export_group("Rotation")
@export var rotation_speed: float = 0.3

# State
var _target_zoom: float = 20.0
var _current_zoom: float = 20.0
var _is_rotating: bool = false
var _camera: Camera3D

func _ready() -> void:
	_camera = $Camera3D
	if not _camera:
		push_warning("RTSCamera: No Camera3D child found!")
		return
	
	# Initial zoom
	_target_zoom = _camera.position.z
	if _target_zoom == 0: _target_zoom = 20.0
	_current_zoom = _target_zoom

func _process(delta: float) -> void:
	if not _camera: return
	
	_handle_movement(delta)
	_handle_zoom(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clamp(_target_zoom - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clamp(_target_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_rotating = event.pressed
			if _is_rotating:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseMotion and _is_rotating:
		rotation.y -= event.relative.x * rotation_speed * 0.01
		# Optional: Pitch rotation
		# rotation.x -= event.relative.y * rotation_speed * 0.01
		# rotation.x = clamp(rotation.x, -1.0, -0.1)

func _handle_movement(delta: float) -> void:
	var dir := Vector3.ZERO
	var speed = move_speed
	
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= boost_multiplier

	# WASD
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
		
	# Mouse Edge Pan (Optional, usually annoying while debugging, enable later?)
	# var viewport_size = get_viewport().get_visible_rect().size
	# var mouse_pos = get_viewport().get_mouse_position()
	# if mouse_pos.x < 10: dir.x -= 1
	# if mouse_pos.x > viewport_size.x - 10: dir.x += 1
	
	if dir.length_squared() > 0:
		dir = dir.normalized()
		# Move relative to camera rotation
		var forward = transform.basis.z
		var right = transform.basis.x
		# Flatten movement to XZ plane
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		
		var move_vec = (forward * dir.z + right * dir.x) * speed * delta
		global_position += move_vec

	# Clamp position to map bounds? (TODO)

func _handle_zoom(delta: float) -> void:
	_current_zoom = lerp(_current_zoom, _target_zoom, zoom_smooth * delta)
	# Assuming camera is offset on Z or Y. 
	# In PlanetSurface.tscn: Transform3D(…, 0, 20, 20) -> Y=20, Z=20.
	# We'll adjust local Z translation of camera for zoom distance
	# But wait, CameraRig has Camera3D child.
	# If Camera3D is at (0,0,distance), we change distance.
	# In our scene, CameraRig is at (0, 20, 20) relative to root? No.
	# Tscn: [node name="CameraRig" type="Node3D" parent="."] transform ...
	# [node name="Camera3D" type="Camera3D" parent="CameraRig"] (default transform?)
	
	# Let's assume CameraRig handles Position (X,Z) over terrain.
	# And Rotation/Pitch.
	# Camera3D child handles distance (Zoom).
	
	_camera.position.z = _current_zoom
