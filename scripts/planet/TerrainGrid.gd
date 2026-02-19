# res://scripts/planet/TerrainGrid.gd
extends Node3D
class_name TerrainGrid

# === DATA CLASS (RefCounted) ===
class TerrainGridData extends RefCounted:
	enum CellType { FLOOR, BLOCKED }

	var size_x: int
	var size_z: int
	var cell_size: float

	var heights: PackedFloat32Array
	var types: PackedInt32Array

	func _init(_size_x: int, _size_z: int, _cell_size: float) -> void:
		size_x = _size_x
		size_z = _size_z
		cell_size = _cell_size

		heights = PackedFloat32Array()
		heights.resize(size_x * size_z)

		types = PackedInt32Array()
		types.resize(size_x * size_z)

	func idx(x: int, z: int) -> int:
		return z * size_x + x

	func in_bounds(x: int, z: int) -> bool:
		return x >= 0 and x < size_x and z >= 0 and z < size_z

	func set_cell(x: int, z: int, cell_type: int, height: float) -> void:
		var i: int = idx(x, z)
		types[i] = cell_type
		heights[i] = height

	func get_type(x: int, z: int) -> int:
		return int(types[idx(x, z)])

	func get_height(x: int, z: int) -> float:
		return float(heights[idx(x, z)])

	func is_walkable(x: int, z: int) -> bool:
		return get_type(x, z) == CellType.FLOOR

	func grid_to_world(x: int, z: int) -> Vector3:
		var ox: float = (float(size_x) - 1.0) * 0.5
		var oz: float = (float(size_z) - 1.0) * 0.5
		var y: float = get_height(x, z)
		return Vector3((float(x) - ox) * cell_size, y, (float(z) - oz) * cell_size)

	func world_to_grid(pos: Vector3) -> Vector2i:
		var ox: float = (float(size_x) - 1.0) * 0.5
		var oz: float = (float(size_z) - 1.0) * 0.5
		var x: int = int(round(pos.x / cell_size + ox))
		var z: int = int(round(pos.z / cell_size + oz))
		return Vector2i(x, z)

	func get_neighbors4(x: int, z: int) -> Array[Vector2i]:
		var res: Array[Vector2i] = []
		var dirs: Array[Vector2i] = [
			Vector2i(1, 0),
			Vector2i(-1, 0),
			Vector2i(0, 1),
			Vector2i(0, -1),
		]
		for d: Vector2i in dirs:
			var nx: int = x + d.x
			var nz: int = z + d.y
			if in_bounds(nx, nz):
				res.append(Vector2i(nx, nz))
		return res


# === NODE WRAPPER ===
# If a Node in the scene has this script, it will NOT crash.
var data: TerrainGridData
