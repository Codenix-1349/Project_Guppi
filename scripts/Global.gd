# === scripts/Global.gd ===
extends Node
# Global game state and data loader

var drones_data = []
var modules_data = []
var enemies_data = []

signal xp_gained(amount)

# ----------------------------
# Progression tuning
# ----------------------------
const BASE_MAX_ENERGY: int = 100   # ✅ Start: 100 Energy
const ENERGY_PER_LEVEL: int = 10   # ✅ +10 pro Level

const BASE_MAX_HP: int = 100       # ✅ Start: 100 HP
const HP_PER_LEVEL: int = 10       # ✅ +10 pro Level

# Refill to full on level-up (set false if you only want caps without healing)
const REFILL_ON_LEVEL_UP: bool = true

# ----------------------------
# Resources / stats
# ----------------------------
var resources = {
	"energy": BASE_MAX_ENERGY,
	"iron": 50,
	"titanium": 20,
	"uranium": 10,
	"data": 0
}

var mothership_level: int = 1
var xp: int = 0
var xp_to_next_level: int = 100

var mothership_hp: int = BASE_MAX_HP
var max_mothership_hp: int = BASE_MAX_HP
var max_energy: int = BASE_MAX_ENERGY


# ----------------------------
# Caps helpers
# ----------------------------
func _calc_max_energy_for_level(lvl: int) -> int:
	return BASE_MAX_ENERGY + ENERGY_PER_LEVEL * maxi(0, lvl - 1)

func _calc_max_hp_for_level(lvl: int) -> int:
	return BASE_MAX_HP + HP_PER_LEVEL * maxi(0, lvl - 1)

func recalc_caps_and_clamp() -> void:
	max_energy = _calc_max_energy_for_level(mothership_level)
	max_mothership_hp = _calc_max_hp_for_level(mothership_level)

	# Clamp current values to caps
	resources.energy = clampi(int(resources.energy), 0, max_energy)
	mothership_hp = clampi(int(mothership_hp), 0, max_mothership_hp)


# ----------------------------
# XP / Leveling
# ----------------------------
func gain_xp(amount: int) -> void:
	xp += int(amount)
	emit_signal("xp_gained", amount)

	# multi-level-up safe
	while xp >= xp_to_next_level:
		level_up()

func level_up() -> void:
	mothership_level += 1
	xp -= xp_to_next_level
	xp_to_next_level = int(float(xp_to_next_level) * 1.5)

	# apply new caps
	recalc_caps_and_clamp()

	if REFILL_ON_LEVEL_UP:
		resources.energy = max_energy
		mothership_hp = max_mothership_hp

	print("LEVEL UP! Reached level ", mothership_level, " | MaxEnergy=", max_energy, " | MaxHP=", max_mothership_hp)


# ----------------------------
# Reset
# ----------------------------
func reset_game() -> void:
	mothership_level = 1
	xp = 0
	xp_to_next_level = 100

	# compute caps for level 1
	max_energy = _calc_max_energy_for_level(mothership_level)
	max_mothership_hp = _calc_max_hp_for_level(mothership_level)

	mothership_hp = max_mothership_hp

	resources = {
		"energy": max_energy,
		"iron": 50,
		"titanium": 20,
		"uranium": 10,
		"data": 0
	}

	print("Game resources reset.")


# ----------------------------
# Data loading
# ----------------------------
func _ready() -> void:
	# Ensure caps are correct on boot
	recalc_caps_and_clamp()
	load_game_data()

func load_game_data() -> void:
	drones_data = load_json("res://data/drones.json").get("drones", [])
	modules_data = load_json("res://data/modules.json").get("modules", [])
	enemies_data = load_json("res://data/enemies.json").get("enemies", [])
	print("Game data loaded.")

func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		printerr("Error: File not found: ", path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return {}

	return json.data

func get_drone_by_id(id: String):
	for drone in drones_data:
		if drone.id == id:
			return drone
	return null

func get_module_by_id(id: String):
	for module in modules_data:
		if module.id == id:
			return module
	return null
