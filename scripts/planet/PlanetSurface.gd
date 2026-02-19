# res://scripts/planet/PlanetSurface.gd
extends Node3D
class_name PlanetSurface

@onready var sunlight: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

signal request_exit

var _planet_data: Dictionary = {}

# IMPORTANT: data-grid type
var planet_grid: TerrainGrid.TerrainGridData
var terrain_gen: TerrainGenerator

var _building_manager: BuildingManager
var _planet_ui: Node


func _ready() -> void:
	# prevent "glowing white" look
	_tune_environment()

	_building_manager = BuildingManager.new()
	_building_manager.name = "BuildingManager"
	add_child(_building_manager)

	_setup_ui()

	terrain_gen = TerrainGenerator.new()
	terrain_gen.name = "TerrainGenerator"
	add_child(terrain_gen)
	terrain_gen.generated.connect(_on_terrain_generated)


func setup(data: Dictionary) -> void:
	_planet_data = data
	print("Initializing Planet Surface: ", data.get("name", "Unknown"), " Type: ", data.get("visual_type", "unknown"))

	var type: String = data.get("visual_type", "terrestrial")
	var seed_val: int = int(abs(data.get("name", "planet").hash()))

	terrain_gen.map_seed = seed_val
	terrain_gen.size_x = 32
	terrain_gen.size_z = 24
	terrain_gen.cell_size = 2.0

	_apply_type_settings(type)

	terrain_gen.generate()


func _on_terrain_generated(g: TerrainGrid.TerrainGridData) -> void:
	planet_grid = g

	var cam: Camera3D = $CameraRig/Camera3D
	_building_manager.setup(planet_grid, cam)


func _tune_environment() -> void:
	# --- Sun ---
	if is_instance_valid(sunlight):
		sunlight.light_energy = 0.35
		sunlight.light_indirect_energy = 0.0
		sunlight.shadow_enabled = true

	# --- Environment ---
	if is_instance_valid(world_env) and world_env.environment != null:
		var env: Environment = world_env.environment

		# Kill "everything glows"
		env.glow_enabled = false

		# Tonemap: clamp brightness
		env.tonemap_exposure = -0.5
		env.tonemap_white = 4.0

		# Disable auto exposure / GI / screen effects using set() to avoid parse errors
		env.set("auto_exposure_enabled", false)
		env.set("auto_exposure_scale", 0.0)
		env.set("auto_exposure_min_luma", 0.0)
		env.set("auto_exposure_max_luma", 1.0)

		env.adjustment_enabled = false

		env.set("sdfgi_enabled", false)
		env.set("ssil_enabled", false)
		env.set("ssao_enabled", false)


func _apply_type_settings(type: String) -> void:
	match type:
		"barren":
			terrain_gen.blocked_threshold = 0.28
			terrain_gen.deco_density = 0.16
			terrain_gen.height_scale = 0.7
		"ice":
			terrain_gen.blocked_threshold = 0.22
			terrain_gen.deco_density = 0.10
			terrain_gen.height_scale = 0.6
		"lava":
			terrain_gen.blocked_threshold = 0.30
			terrain_gen.deco_density = 0.14
			terrain_gen.height_scale = 1.1
		"sand":
			terrain_gen.blocked_threshold = 0.24
			terrain_gen.deco_density = 0.12
			terrain_gen.height_scale = 0.8
		_:
			terrain_gen.blocked_threshold = 0.25
			terrain_gen.deco_density = 0.12
			terrain_gen.height_scale = 0.9


func _setup_ui() -> void:
	var ui_scene: PackedScene = load("res://scenes/planet/PlanetUI.tscn") as PackedScene
	if ui_scene == null:
		push_error("PlanetUI.tscn not found!")
		return

	_planet_ui = ui_scene.instantiate()
	add_child(_planet_ui)

	# If your UI exposes this signal, connect it
	if _planet_ui.has_signal("build_requested"):
		_planet_ui.build_requested.connect(_building_manager.start_placement)

	var btn := Button.new()
	btn.text = "RETURN TO GALAXY"
	btn.position = Vector2(20, 20)
	btn.pressed.connect(func(): request_exit.emit())
	_planet_ui.add_child(btn)


func get_mouse_world_position() -> Vector3:
	var camera: Camera3D = $CameraRig/Camera3D
	if camera == null:
		return Vector3.ZERO

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_end: Vector3 = ray_origin + camera.project_ray_normal(mouse_pos) * 2000.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position

	return Vector3.ZERO
