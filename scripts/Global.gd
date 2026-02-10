extends Node

# Global game state and data loader

var drones_data = []
var modules_data = []
var enemies_data = []

signal xp_gained(amount)

var resources = {
	"energy": 100,
	"iron": 50,
	"titanium": 20,
	"uranium": 10,
	"data": 0
}

var mothership_level: int = 1
var xp: int = 0
var xp_to_next_level: int = 100

var mothership_hp: int = 100
var max_mothership_hp: int = 100

var max_energy: int = 100

func gain_xp(amount: int):
	xp += amount
	emit_signal("xp_gained", amount)
	if xp >= xp_to_next_level:
		level_up()

func level_up():
	mothership_level += 1
	xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * 1.5)
	max_energy += 20
	resources.energy = max_energy # Refill energy on level up
	print("LEVEL UP! Reached level ", mothership_level)

func reset_game():
	mothership_level = 1
	xp = 0
	xp_to_next_level = 100
	mothership_hp = 100
	max_mothership_hp = 100
	max_energy = 100
	resources = {
		"energy": 100,
		"iron": 50,
		"titanium": 20,
		"uranium": 10,
		"data": 0
	}
	print("Game resources reset.")

func _ready():
	load_game_data()

func load_game_data():
	drones_data = load_json("res://data/drones.json").get("drones", [])
	modules_data = load_json("res://data/modules.json").get("modules", [])
	enemies_data = load_json("res://data/enemies.json").get("enemies", [])
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
