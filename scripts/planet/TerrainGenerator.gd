# res://scripts/planet/TerrainGenerator.gd
extends Node3D
class_name TerrainGenerator

@export var size_x: int = 32
@export var size_z: int = 24
@export var cell_size: float = 2.0

@export var map_seed: int = 0
@export var attempts: int = 8

@export var noise_frequency: float = 0.08
@export var height_scale: float = 0.9
@export var blocked_threshold: float = 0.25

@export_range(0.0, 1.0, 0.01) var deco_density: float = 0.12
@export var min_deco_distance_cells: int = 2

signal generated(grid: TerrainGrid.TerrainGridData)

const MODEL_DIR: String = "res://Kenney_space-kit/Models/GLTF format/"

const DECO_ROCKS: Array[String] = ["rock_largeA.glb","rock_largeB.glb","rocks_smallA.glb","rocks_smallB.glb","rock.glb"]
const DECO_CRATERS: Array[String] = ["crater.glb","craterLarge.glb","meteor_half.glb"]
const DECO_CRYSTALS: Array[String] = ["rock_crystals.glb","rock_crystalsLargeA.glb","rock_crystalsLargeB.glb"]
const DECO_ALIEN: Array[String] = ["alien.glb","satelliteDish_detailed.glb","meteor_detailed.glb"]
const DECO_STRUCTURES: Array[String] = ["structure.glb","structure_closed.glb","structure_detailed.glb","hangar_roundA.glb","hangar_smallB.glb"]

var grid: TerrainGrid.TerrainGridData

var _noise: FastNoiseLite = FastNoiseLite.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _terrain_root: Node3D = Node3D.new()
@onready var _deco_root: Node3D = Node3D.new()

# Materials (avoid blown out whites)
var _floor_mat: StandardMaterial3D
var _blocked_mat: StandardMaterial3D


func _ready() -> void:
	add_child(_terrain_root)
	_terrain_root.name = "GeneratedTerrain"
	add_child(_deco_root)
	_deco_root.name = "GeneratedDecorations"

	_build_materials()


func _build_materials() -> void:
	_floor_mat = StandardMaterial3D.new()
	_floor_mat.albedo_color = Color(0.45, 0.45, 0.45) # mid gray
	_floor_mat.roughness = 1.0
	_floor_mat.metallic = 0.0

	_blocked_mat = StandardMaterial3D.new()
	_blocked_mat.albedo_color = Color(0.25, 0.25, 0.25) # darker
	_blocked_mat.roughness = 1.0
	_blocked_mat.metallic = 0.0


func generate() -> void:
	_clear_generated()

	var ok: bool = false
	for i in range(attempts):
		_apply_seed(i)

		grid = _build_grid()
		_build_visual_tiles(grid)
		_place_decorations(grid)

		ok = _validate_connectivity(grid)
		if ok:
			generated.emit(grid)
			return

		_clear_generated()

	generated.emit(grid)


func _apply_seed(offset: int) -> void:
	var s: int = map_seed
	if s == 0:
		s = int(Time.get_unix_time_from_system())
	s += offset * 1337
	_rng.seed = s
	_noise.seed = s
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


func _build_grid() -> TerrainGrid.TerrainGridData:
	var g: TerrainGrid.TerrainGridData = TerrainGrid.TerrainGridData.new(size_x, size_z, cell_size)

	for x in range(size_x):
		for z in range(size_z):
			var n: float = _noise.get_noise_2d(float(x), float(z))
			var n01: float = (n + 1.0) * 0.5
			var is_blocked: bool = n01 < blocked_threshold

			var raw_h: float = _noise.get_noise_2d(float(x) + 1000.0, float(z) - 500.0)
			var h01: float = (raw_h + 1.0) * 0.5
			var tier: int = int(floor(h01 * 3.0))
			var height: float = float(tier) * height_scale

			g.set_cell(
				x, z,
				TerrainGrid.TerrainGridData.CellType.BLOCKED if is_blocked else TerrainGrid.TerrainGridData.CellType.FLOOR,
				height
			)
	return g


func _build_visual_tiles(g: TerrainGrid.TerrainGridData) -> void:
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(cell_size, cell_size)

	var blocked_mesh: BoxMesh = BoxMesh.new()
	blocked_mesh.size = Vector3(cell_size * 0.95, height_scale * 1.2, cell_size * 0.95)

	for x in range(g.size_x):
		for z in range(g.size_z):
			var t: int = g.get_type(x, z)
			var p: Vector3 = g.grid_to_world(x, z)

			if t == TerrainGrid.TerrainGridData.CellType.FLOOR:
				var mi: MeshInstance3D = MeshInstance3D.new()
				mi.mesh = floor_mesh
				mi.position = p
				mi.material_override = _floor_mat
				_terrain_root.add_child(mi)

				# collider for raycasts / interaction
				var body: StaticBody3D = StaticBody3D.new()
				var shape: CollisionShape3D = CollisionShape3D.new()
				var box: BoxShape3D = BoxShape3D.new()
				box.size = Vector3(cell_size, 0.1, cell_size)
				shape.shape = box
				body.add_child(shape)
				body.position = p + Vector3(0.0, 0.05, 0.0)
				body.set_meta("grid", Vector2i(x, z))
				_terrain_root.add_child(body)
			else:
				var bi: MeshInstance3D = MeshInstance3D.new()
				bi.mesh = blocked_mesh
				bi.position = p + Vector3(0.0, height_scale * 0.6, 0.0)
				bi.material_override = _blocked_mat
				_terrain_root.add_child(bi)

				var bbody: StaticBody3D = StaticBody3D.new()
				var bshape: CollisionShape3D = CollisionShape3D.new()
				var bbox: BoxShape3D = BoxShape3D.new()
				bbox.size = Vector3(cell_size * 0.95, height_scale * 1.2, cell_size * 0.95)
				bshape.shape = bbox
				bbody.add_child(bshape)
				bbody.position = bi.position
				bbody.set_meta("grid", Vector2i(x, z))
				_terrain_root.add_child(bbody)


func _place_decorations(g: TerrainGrid.TerrainGridData) -> void:
	var occupied: Dictionary = {}
	var all_lists: Array = [DECO_ROCKS, DECO_CRATERS, DECO_CRYSTALS, DECO_ALIEN, DECO_STRUCTURES]

	for x in range(g.size_x):
		for z in range(g.size_z):
			if not g.is_walkable(x, z):
				continue
			if _rng.randf() > deco_density:
				continue
			if _has_nearby_deco(occupied, x, z, min_deco_distance_cells):
				continue

			var list_any: Variant = all_lists[_rng.randi_range(0, all_lists.size() - 1)]
			if typeof(list_any) != TYPE_ARRAY:
				continue
			var list: Array = list_any
			if list.is_empty():
				continue

			var file: String = str(list[_rng.randi_range(0, list.size() - 1)])
			if file == "":
				continue

			var res: Resource = load(MODEL_DIR + file)
			if res == null or not (res is PackedScene):
				continue

			var inst: Node3D = (res as PackedScene).instantiate() as Node3D
			if inst == null:
				continue

			var p: Vector3 = g.grid_to_world(x, z)
			var jitter: Vector3 = Vector3(
				(_rng.randf() - 0.5) * cell_size * 0.4,
				0.0,
				(_rng.randf() - 0.5) * cell_size * 0.4
			)

			inst.position = p + jitter
			inst.rotation.y = _rng.randf_range(0.0, TAU)

			_deco_root.add_child(inst)
			occupied[Vector2i(x, z)] = true


func _has_nearby_deco(occupied: Dictionary, x: int, z: int, dist: int) -> bool:
	for dx in range(-dist, dist + 1):
		for dz in range(-dist, dist + 1):
			if dx == 0 and dz == 0:
				continue
			if occupied.has(Vector2i(x + dx, z + dz)):
				return true
	return false


func _validate_connectivity(g: TerrainGrid.TerrainGridData) -> bool:
	var total_walkable: int = 0
	var start: Vector2i = Vector2i(-1, -1)

	for x in range(g.size_x):
		for z in range(g.size_z):
			if g.is_walkable(x, z):
				total_walkable += 1
				if start.x == -1:
					start = Vector2i(x, z)

	if total_walkable == 0:
		return false

	var visited: Dictionary = {}
	var q: Array[Vector2i] = [start]
	visited[start] = true

	while q.size() > 0:
		var cur: Vector2i = q.pop_front()
		for n: Vector2i in g.get_neighbors4(cur.x, cur.y):
			if visited.has(n):
				continue
			if not g.is_walkable(n.x, n.y):
				continue
			visited[n] = true
			q.append(n)

	return float(visited.size()) / float(total_walkable) >= 0.55


func _clear_generated() -> void:
	for c in _terrain_root.get_children():
		c.queue_free()
	for c in _deco_root.get_children():
		c.queue_free()
