extends Node

signal encounter_started(payload)
signal encounter_updated(payload)
signal encounter_ended(payload)

@export var flee_success_chance: float = 0.3333
@export var xp_per_enemy_destroyed: int = 50

var DRONE_DAMAGE_FALLBACK: Dictionary = {"scout_v1": 1, "miner_v1": 1, "defender_v1": 4}
var DRONE_DURABILITY_FALLBACK: Dictionary = {"scout_v1": 2, "miner_v1": 2, "defender_v1": 5}

var _active: bool = false
var _system_ref: Dictionary = {}
var _enemies_ref: Array = []
var _player_inv_ref: Dictionary = {}

func _ready():
	print("Combat Manager initialized.")

func is_encounter_active() -> bool:
	return _active

func begin_encounter(system_ref: Dictionary, player_inventory: Dictionary) -> void:
	if _active:
		return
	if not system_ref.has("enemies"):
		return

	_system_ref = system_ref
	_enemies_ref = system_ref["enemies"]       # reference
	_player_inv_ref = player_inventory         # reference

	if _enemies_ref.size() <= 0:
		return

	_ensure_enemy_hp(_enemies_ref)
	_active = true

	emit_signal("encounter_started", _make_payload("[color=yellow]Feindkontakt![/color] Entscheide: Kämpfen oder Fliehen."))

func player_fight_round() -> void:
	if not _active:
		return

	# Player attack
	var player_damage: int = _compute_player_damage(_player_inv_ref)
	player_damage = int(float(player_damage) * randf_range(0.9, 1.1))
	_apply_damage_to_enemies(_enemies_ref, player_damage)
	var destroyed: int = _remove_destroyed_enemies_in_place(_enemies_ref)

	# XP for kills
	var xp_gain: int = destroyed * xp_per_enemy_destroyed
	if xp_gain > 0:
		Global.gain_xp(xp_gain)

	# Enemy counter attack
	var enemy_damage: int = 0
	var mothership_damage: int = 0

	if _enemies_ref.size() > 0:
		enemy_damage = _compute_enemy_damage(_enemies_ref)
		enemy_damage = int(float(enemy_damage) * randf_range(0.9, 1.1))

		if _count_total_drones(_player_inv_ref) <= 0:
			mothership_damage = int(enemy_damage * 3.0)
			_apply_mothership_damage(mothership_damage)
		else:
			var spill: int = _apply_player_losses(_player_inv_ref, enemy_damage)
			if spill > 0:
				mothership_damage = spill
				_apply_mothership_damage(mothership_damage)

	var msg := "Runde abgeschlossen.\n"
	msg += "Du verursachst: [color=cyan]%d[/color] Schaden\n" % player_damage
	if destroyed > 0:
		msg += "[color=green]Zerstört: %d[/color] | XP +%d\n" % [destroyed, xp_gain]
	if _enemies_ref.size() > 0:
		msg += "Gegner verursachen: [color=red]%d[/color] Schaden\n" % enemy_damage
		if mothership_damage > 0:
			msg += "[color=red]Hüllenschaden: %d[/color]\n" % mothership_damage

	# End conditions
	if _enemies_ref.size() <= 0:
		_active = false
		emit_signal("encounter_updated", _make_payload(msg + "[color=green]SIEG! System gesichert.[/color]"))
		emit_signal("encounter_ended", _make_end_payload("VICTORY"))
		return

	if Global.mothership_hp <= 0:
		_active = false
		emit_signal("encounter_updated", _make_payload(msg + "[color=red]SCHIFF VERLOREN![/color]"))
		emit_signal("encounter_ended", _make_end_payload("DEFEAT"))
		return

	emit_signal("encounter_updated", _make_payload(msg))

func player_try_flee() -> void:
	if not _active:
		return

	if randf() < flee_success_chance:
		_active = false
		emit_signal("encounter_updated", _make_payload("[color=gray]Flucht erfolgreich.[/color] Gegner bleiben im System (Rest-HP)."))
		emit_signal("encounter_ended", _make_end_payload("FLED"))
		return

	# failed flee -> enemy free shot
	var enemy_damage: int = _compute_enemy_damage(_enemies_ref)
	enemy_damage = int(float(enemy_damage) * randf_range(0.9, 1.1))

	var mothership_damage: int = 0
	if _count_total_drones(_player_inv_ref) <= 0:
		mothership_damage = int(enemy_damage * 3.0)
		_apply_mothership_damage(mothership_damage)
	else:
		var spill: int = _apply_player_losses(_player_inv_ref, enemy_damage)
		if spill > 0:
			mothership_damage = spill
			_apply_mothership_damage(mothership_damage)

	var msg := "[color=orange]Flucht fehlgeschlagen![/color]\n"
	msg += "Gegner-Feuerschlag: [color=red]%d[/color]\n" % enemy_damage
	if mothership_damage > 0:
		msg += "[color=red]Hüllenschaden: %d[/color]\n" % mothership_damage

	if Global.mothership_hp <= 0:
		_active = false
		emit_signal("encounter_updated", _make_payload(msg + "[color=red]SCHIFF VERLOREN![/color]"))
		emit_signal("encounter_ended", _make_end_payload("DEFEAT"))
		return

	emit_signal("encounter_updated", _make_payload(msg))

# ---------------------------
# Payload/UI builders
# ---------------------------

func _make_payload(status_bbcode: String) -> Dictionary:
	return {
		"status": status_bbcode,
		"fleet_bb": _build_fleet_bbcode(_player_inv_ref),
		"enemy_bb": _build_enemy_bbcode(_enemies_ref),
		"hp": "%d/%d" % [Global.mothership_hp, Global.max_mothership_hp]
	}

func _make_end_payload(result: String) -> Dictionary:
	return {
		"result": result,
		"fleet_bb": _build_fleet_bbcode(_player_inv_ref),
		"enemy_bb": _build_enemy_bbcode(_enemies_ref),
		"hp": "%d/%d" % [Global.mothership_hp, Global.max_mothership_hp]
	}

func _build_fleet_bbcode(inv: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("[b]Mutterschiff HP:[/b] [color=orange]%d/%d[/color]" % [Global.mothership_hp, Global.max_mothership_hp])
	lines.append("")

	var order: Array[String] = ["scout_v1", "miner_v1", "defender_v1"]
	var any: bool = false

	for drone_id_str: String in order:
		var cnt: int = int(inv.get(drone_id_str, 0))
		if cnt <= 0:
			continue

		any = true

		var name: String = drone_id_str

		var drone_data = Global.get_drone_by_id(drone_id_str)
		if drone_data != null and typeof(drone_data) == TYPE_DICTIONARY:
			var d: Dictionary = drone_data
			if d.has("name"):
				name = str(d["name"])

		var hp_per_unit: int = _get_drone_durability(drone_id_str)
		lines.append("- %s x%d  [color=gray](HP je Einheit: %d)[/color]" % [name, cnt, hp_per_unit])

	if not any:
		lines.append("[color=gray]Keine Drohnen im Hangar.[/color]")

	return "\n".join(lines)

func _build_enemy_bbcode(enemies: Array) -> String:
	if enemies.size() == 0:
		return "[color=gray]Keine Gegner.[/color]"

	var hp_lines: Array[String] = []
	for e in enemies:
		var name: String = str(_enemy_get(e, "name", "Enemy"))
		var hp: int = int(_enemy_get(e, "hp", 0))
		var mx: int = int(_enemy_get(e, "max_hp", hp))
		hp_lines.append("- %s  [color=red]%d/%d[/color]" % [name, hp, mx])

	return "\n".join(hp_lines)

# ---------------------------
# Damage calculations
# ---------------------------

func _compute_player_damage(inv: Dictionary) -> int:
	var total: int = 0
	for drone_id in inv.keys():
		var drone_id_str: String = str(drone_id)
		var count: int = int(inv.get(drone_id, 0))
		if count <= 0:
			continue

		var per_unit: int = 0
		var drone = Global.get_drone_by_id(drone_id_str)
		if drone != null and typeof(drone) == TYPE_DICTIONARY:
			var d: Dictionary = drone
			if d.has("stats") and typeof(d["stats"]) == TYPE_DICTIONARY:
				var st: Dictionary = d["stats"]
				if st.has("firepower"):
					per_unit = int(st["firepower"])

		if per_unit <= 0:
			per_unit = int(DRONE_DAMAGE_FALLBACK.get(drone_id_str, 1))

		total += per_unit * count

	return total

func _compute_enemy_damage(enemies: Array) -> int:
	var total: int = 0
	for e in enemies:
		var stats: Dictionary = _get_enemy_stats(e)
		total += int(stats.get("firepower", 2))
	return total

func _apply_damage_to_enemies(enemies: Array, damage: int) -> void:
	if damage <= 0 or enemies.size() == 0:
		return

	var indices: Array[int] = []
	for i in range(enemies.size()):
		indices.append(i)
	indices.shuffle()

	var remaining: int = damage
	for idx in indices:
		if remaining <= 0:
			break

		var enemy = enemies[idx]
		var hp: int = int(_enemy_get(enemy, "hp", 0))
		if hp <= 0:
			continue

		var chunk: int = min(remaining, hp)
		_enemy_set(enemy, "hp", hp - chunk)
		remaining -= chunk

func _remove_destroyed_enemies_in_place(enemies: Array) -> int:
	var destroyed: int = 0
	for i in range(enemies.size() - 1, -1, -1):
		var hp: int = int(_enemy_get(enemies[i], "hp", 0))
		if hp <= 0:
			enemies.remove_at(i)
			destroyed += 1
	return destroyed

func _apply_player_losses(inv: Dictionary, damage: int) -> int:
	var remaining: int = damage
	if remaining <= 0:
		return 0

	var types: Array = inv.keys()
	types.shuffle()

	for drone_id in types:
		var drone_id_str: String = str(drone_id)
		while int(inv.get(drone_id, 0)) > 0 and remaining > 0:
			var dur: int = _get_drone_durability(drone_id_str)
			remaining -= dur
			inv[drone_id] = int(inv[drone_id]) - 1

		if remaining <= 0:
			break

	if remaining > 0:
		return int(float(remaining) * 0.25)
	return 0

func _get_drone_durability(drone_id: String) -> int:
	var drone = Global.get_drone_by_id(drone_id)
	if drone != null and typeof(drone) == TYPE_DICTIONARY:
		var d: Dictionary = drone
		if d.has("stats") and typeof(d["stats"]) == TYPE_DICTIONARY:
			var st: Dictionary = d["stats"]
			if st.has("durability"):
				return max(1, int(st["durability"]))
	return max(1, int(DRONE_DURABILITY_FALLBACK.get(drone_id, 2)))

func _apply_mothership_damage(amount: int) -> void:
	if amount <= 0:
		return
	Global.mothership_hp -= amount
	if Global.mothership_hp < 0:
		Global.mothership_hp = 0

func _count_total_drones(inv: Dictionary) -> int:
	var total: int = 0
	for k in inv.keys():
		total += int(inv.get(k, 0))
	return total

# ---------------------------
# Enemy HP init/helpers
# ---------------------------

func _ensure_enemy_hp(enemies: Array) -> void:
	for e in enemies:
		var stats: Dictionary = _get_enemy_stats(e)
		var mx: int = int(stats.get("durability", 10))
		if mx <= 0:
			mx = 10

		if not _enemy_has(e, "max_hp"):
			_enemy_set(e, "max_hp", mx)
		if not _enemy_has(e, "hp"):
			_enemy_set(e, "hp", mx)

		var hp: int = int(_enemy_get(e, "hp", mx))
		if hp > mx:
			_enemy_set(e, "hp", mx)
		if hp < 0:
			_enemy_set(e, "hp", 0)

func _get_enemy_stats(enemy) -> Dictionary:
	if typeof(enemy) == TYPE_DICTIONARY:
		return (enemy as Dictionary).get("stats", {})
	if enemy != null and enemy.has_method("get"):
		var s = enemy.get("stats")
		return s if typeof(s) == TYPE_DICTIONARY else {}
	return {}

func _enemy_has(enemy, key: String) -> bool:
	if typeof(enemy) == TYPE_DICTIONARY:
		return (enemy as Dictionary).has(key)
	if enemy != null and enemy.has_method("get"):
		return enemy.get(key) != null
	return false

func _enemy_get(enemy, key: String, default_value):
	if typeof(enemy) == TYPE_DICTIONARY:
		return (enemy as Dictionary).get(key, default_value)
	if enemy != null and enemy.has_method("get"):
		var v = enemy.get(key)
		return default_value if v == null else v
	return default_value

func _enemy_set(enemy, key: String, value) -> void:
	if typeof(enemy) == TYPE_DICTIONARY:
		(enemy as Dictionary)[key] = value
		return
	if enemy != null and enemy.has_method("set"):
		enemy.set(key, value)
