extends RefCounted
class_name BuildingData

# Definitions for all buildable structures
# ID -> Properties
const BUILDINGS = {
	"hq": {
		"name": "Headquarters",
		"cost": {"iron": 0, "energy": 0}, # Free to start?
		"scene_path": "res://kenney_space-kit/Models/GLTF format/hangar_roundA.glb",
		"size": Vector2i(2, 2), # 2x2 Tiles
		"description": "Main base of operations."
	},
	"factory": {
		"name": "Factory",
		"cost": {"iron": 100, "energy": 50},
		"scene_path": "res://kenney_space-kit/Models/GLTF format/machine_generatorLarge.glb",
		"size": Vector2i(2, 2),
		"description": "Produces units."
	},
	"solar": {
		"name": "Solar Panel",
		"cost": {"iron": 20, "energy": 0},
		"scene_path": "res://kenney_space-kit/Models/GLTF format/satelliteDish.glb", # Use dish as solar for now? Or pipe_ring?
		"size": Vector2i(1, 1),
		"description": "Generates energy."
	},
	"turret": {
		"name": "Defense Turret",
		"cost": {"iron": 50, "energy": 10},
		"scene_path": "res://kenney_space-kit/Models/GLTF format/turret_single.glb",
		"size": Vector2i(1, 1),
		"description": "Defends against enemies."
	},
	"house": {
		"name": "Habitation",
		"cost": {"iron": 30, "energy": 5},
		"scene_path": "res://kenney_space-kit/Models/GLTF format/corridor_cornerRoundWindow.glb", 
		"size": Vector2i(1, 1),
		"description": "Increases population capacity."
	}
}

static func get_building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})

static func get_all_ids() -> Array:
	return BUILDINGS.keys()
