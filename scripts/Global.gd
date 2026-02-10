extends Node

# Global game state and data loader

var drones_data = []
var modules_data = []

var resources = {
	"energy": 100,
	"iron": 50,
	"titanium": 0,
	"uranium": 0,
	"data": 0
}

func _ready():
	load_game_data()

func load_game_data():
	drones_data = load_json("res://data/drones.json").get("drones", [])
	modules_data = load_json("res://data/modules.json").get("modules", [])
	print("Game data loaded.")

func load_json(path):
	if not FileAccess.file_exists(path):
		printerr("Error: File not found: ", path)
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return {}
	
	return json.data

func get_drone_by_id(id):
	for drone in drones_data:
		if drone.id == id:
			return drone
	return null

func get_module_by_id(id):
	for module in modules_data:
		if module.id == id:
			return module
	return null
