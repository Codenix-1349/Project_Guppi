extends Node
# CombatManager.gd (Godot 4.x strict-parse safe)
# Encounter combat with readable battle log: "who hits whom for how much".

signal encounter_started(payload: Dictionary)
signal encounter_updated(payload: Dictionary)
signal encounter_ended(payload: Dictionary)

# Legacy (optional)
signal combat_occurred(results)

const FLEE_CHANCE: float = 0.3333
const BAR_WIDTH: int = 22

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _active: bool = false
var _turn_in_encounter: int = 0

var _player_inventory_ref: Dictionary = {}
var _system_enemy_ref: Array = []

var _enemy_units: Array = []     # Array[Dictionary] each enemy has hp/max_hp
var _player_stacks: Array = []   # Array[Dictionary] stack has unit_hp array
var _log_buffer: Array = []      # Array[String] bbcode lines

func _ready() -> void:
	_rng.randomize()
	print("Combat Manager initialized.")

func is_encounter_active() -> bool:
	return _active

func get_log_bb() -> String:
	var max_lines: int = 250
	var start: int = max(0, _log_buffer.size() - max_lines)
	var lines: Array = _log_buffer.slice(start, _log_buffer.size())
	return "\n".join(lines)

func begin_encounter(system: Variant, player_inventory: Dictionary) -> void:
	if _active:
		return

	if typeof(system) != TYPE_DICTIONARY:
		push_warning("begin_encounter: system is not a Dictionary")
		return

	var sys: Dictionary = system as Dictionary
	if not sys.has("enemies") or typeof(sys["enemies"]) != TYPE_ARRAY:
		push_warning("begin_encounter: system has no enemies array")
		return

	_player_inventory_ref = player_inventory
	_system_enemy_ref = sys["enemies"] as Array

	_enemy_units.clear()
	_player_stacks.clear()
	_log_buffer.clear()

	for e in _system_enemy_ref:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var e_dict: Dictionary = e as Dictionary
		var max_hp: int = _safe_stat_from_dict(e_dict, "durability", 10)

		var inst: Dictionary = e_dict.duplicate(true)
		inst["max_hp"] = max_hp
		inst["hp"] = max_hp
		_enemy_units.append(inst)

	_player_stacks = _build_player_stacks_from_inventory(_player_inventory_ref)

	_active = true
	_turn_in_encounter = 0

	_log_line("[color=yellow][b]Feindkontakt![/b][/color] Entscheide: Kämpfen oder Fliehen.")
	_emit_update("ENCOUNTER STARTED")

func player_fight_round() -> void:
	if not _active:
		return

	_turn_in_encounter += 1
	_log_line("\n[b]Runde %d[/b]" % _turn_in_encounter)

	_player_attack_phase()

	if _enemy_units.size() == 0:
		_end_victory()
		return

	_enemy_attack_phase()

	if Global.mothership_hp <= 0:
		_end_defeat("HÜLLE ZERSTÖRT")
		return

	_emit_update("ROUND RESOLVED")

func player_try_flee() -> void:
	if not _active:
		return

	_turn_in_encounter += 1
	_log_line("\n[b]Runde %d[/b]" % _turn_in_encounter)
	_log_line("Fluchtversuch...")

	var roll: float = _rng.randf()
	if roll <= FLEE_CHANCE:
		_log_line("[color=green][b]Flucht gelungen![/b][/color] Du entkommst dem Kampf.")
		_end_flee()
		return

	_log_line("[color=red][b]Flucht gescheitert![/b][/color] Die Gegner erhalten einen freien Angriff.")
	_enemy_attack_phase(true)

	if Global.mothership_hp <= 0:
		_end_defeat("HÜLLE ZERSTÖRT")
		return

	_emit_update("FLEE FAILED")

# -------------------------
# Phases with detailed log
# -------------------------

func _player_attack_phase() -> void:
	var any_fire: bool = false

	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		var cnt: int = _count_alive_in_stack(stack)
		if cnt <= 0:
			continue

		var fp: int = int(stack.get("firepower", 0))
		if fp <= 0:
			continue

		any_fire = true

		var base: int = fp * cnt
		var dmg: int = int(float(base) * _rng.randf_range(0.85, 1.15))
		dmg = max(0, dmg)

		if _enemy_units.size() <= 0:
			break

		var target_idx: int = 0
		var target: Dictionary = _enemy_units[target_idx] as Dictionary
		var t_name: String = str(target.get("name", "Enemy"))

		_log_line("[color=cyan]%s x%d[/color] feuert auf [color=red]%s[/color] für [b]%d[/b] DMG"
			% [str(stack.get("name","Unit")), cnt, t_name, dmg])

		_apply_damage_to_enemy_index(target_idx, dmg)

	if not any_fire:
		_log_line("[color=gray]Deine Flotte hat keine Feuerkraft.[/color]")

func _enemy_attack_phase(free_attack: bool = false) -> void:
	if _enemy_units.size() <= 0:
		return

	var total_player_units: int = _count_total_player_units()

	for ev in _enemy_units:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = ev as Dictionary
		var ehp: int = int(enemy.get("hp", 0))
		if ehp <= 0:
			continue

		var e_name: String = str(enemy.get("name", "Enemy"))
		var e_fp: int = _safe_stat_from_dict(enemy, "firepower", 1)

		var dmg: int = int(float(e_fp) * _rng.randf_range(0.85, 1.15))
		dmg = max(1, dmg)

		if total_player_units <= 0:
			var hull_dmg: int = int(dmg * (3.0 if free_attack else 2.0))
			_log_line("[color=red]%s[/color] trifft [color=orange]HÜLLE[/color] für [b]%d[/b] DMG" % [e_name, hull_dmg])
			Global.mothership_hp -= hull_dmg
			if Global.mothership_hp < 0:
				Global.mothership_hp = 0
			if Global.mothership_hp <= 0:
				return
			continue

		var t_stack_idx: int = _pick_player_stack_target_index()
		if t_stack_idx == -1:
			var hull_dmg2: int = int(dmg * 2.0)
			_log_line("[color=red]%s[/color] trifft [color=orange]HÜLLE[/color] für [b]%d[/b] DMG" % [e_name, hull_dmg2])
			Global.mothership_hp -= hull_dmg2
			if Global.mothership_hp < 0:
				Global.mothership_hp = 0
			if Global.mothership_hp <= 0:
				return
			continue

		var t_stack: Dictionary = _player_stacks[t_stack_idx] as Dictionary
		var t_name: String = str(t_stack.get("name", "Unit"))

		_log_line("[color=red]%s[/color] schießt auf [color=cyan]%s[/color] für [b]%d[/b] DMG" % [e_name, t_name, dmg])
		_apply_damage_to_stack(t_stack, dmg)

		_sync_inventory_from_stacks()
		total_player_units = _count_total_player_units()
		if total_player_units <= 0:
			_log_line("[color=orange]Alle Drohnen zerstört![/color] Ab jetzt geht Schaden auf die Hülle.")

# -------------------------
# Damage helpers
# -------------------------

func _apply_damage_to_enemy_index(idx: int, dmg: int) -> void:
	if idx < 0 or idx >= _enemy_units.size():
		return
	var enemy: Dictionary = _enemy_units[idx] as Dictionary
	var hp: int = int(enemy.get("hp", 0))
	var max_hp: int = int(enemy.get("max_hp", _safe_stat_from_dict(enemy, "durability", 10)))

	var take: int = min(dmg, hp)
	hp -= take
	enemy["hp"] = hp

	_log_line("→ [color=red]%s[/color] nimmt %d DMG (HP %d/%d)" % [str(enemy.get("name","Enemy")), take, hp, max_hp])

	if hp <= 0:
		var dead_name: String = str(enemy.get("name","Enemy"))
		_enemy_units.remove_at(idx)
		_log_line("[color=green]✖ %s zerstört[/color]" % dead_name)

func _apply_damage_to_stack(stack: Dictionary, dmg: int) -> void:
	var remaining: int = dmg
	var name_txt: String = str(stack.get("name", "Unit"))
	var max_hp: int = int(stack.get("max_hp", 1))

	if not stack.has("unit_hp") or typeof(stack["unit_hp"]) != TYPE_ARRAY:
		return

	var unit_hp: Array = stack["unit_hp"] as Array

	while remaining > 0 and unit_hp.size() > 0:
		var current_hp: int = int(unit_hp[0])
		var take: int = min(remaining, current_hp)
		current_hp -= take
		remaining -= take

		if current_hp <= 0:
			unit_hp.remove_at(0)
			stack["count"] = unit_hp.size()
			_log_line("→ [color=cyan]%s[/color] verliert 1 Einheit! (Rest: x%d)" % [name_txt, int(stack["count"])])
		else:
			unit_hp[0] = current_hp
			_log_line("→ [color=cyan]%s[/color] vorderste Einheit HP %d/%d" % [name_txt, current_hp, max_hp])

	stack["unit_hp"] = unit_hp

# -------------------------
# Build stacks / stats
# -------------------------

func _build_player_stacks_from_inventory(inv: Dictionary) -> Array:
	var stacks: Array = []
	var order: Array = ["defender_v1", "scout_v1", "miner_v1"]

	for idv in order:
		var id: String = str(idv)
		var cnt: int = int(inv.get(id, 0))
		if cnt <= 0:
			continue

		var d: Variant = Global.get_drone_by_id(id)
		if d == null or typeof(d) != TYPE_DICTIONARY:
			continue

		var d_dict: Dictionary = d as Dictionary
		var name_txt: String = str(d_dict.get("name", id))
		var max_hp: int = _safe_stat_from_dict(d_dict, "durability", 5)
		var fp: int = _safe_stat_from_dict(d_dict, "firepower", 1)

		var unit_hp: Array = []
		unit_hp.resize(cnt)
		for i in range(cnt):
			unit_hp[i] = max_hp

		var stack: Dictionary = {
			"id": id,
			"name": name_txt,
			"count": cnt,
			"max_hp": max_hp,
			"firepower": fp,
			"unit_hp": unit_hp
		}
		stacks.append(stack)

	return stacks

func _safe_stat_from_dict(obj: Dictionary, key: String, fallback: int) -> int:
	if obj.has("stats") and typeof(obj["stats"]) == TYPE_DICTIONARY:
		var stats: Dictionary = obj["stats"] as Dictionary
		if stats.has(key):
			return int(stats[key])
	if obj.has(key):
		return int(obj[key])
	return fallback

func _sync_inventory_from_stacks() -> void:
	var known: Array = ["defender_v1", "scout_v1", "miner_v1"]
	for idv in known:
		var id: String = str(idv)
		_player_inventory_ref[id] = 0

	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		var id2: String = str(stack.get("id", ""))
		var cnt: int = int(stack.get("count", 0))
		if id2 != "":
			_player_inventory_ref[id2] = cnt

func _pick_player_stack_target_index() -> int:
	var weights: Array = []
	var total: int = 0

	for i in range(_player_stacks.size()):
		var sv: Variant = _player_stacks[i]
		if typeof(sv) != TYPE_DICTIONARY:
			weights.append(0)
			continue
		var st: Dictionary = sv as Dictionary
		var alive: int = _count_alive_in_stack(st)
		weights.append(alive)
		total += alive

	if total <= 0:
		return -1

	var r: int = _rng.randi_range(1, total)
	var acc: int = 0
	for i in range(weights.size()):
		acc += int(weights[i])
		if r <= acc:
			return i

	return -1

# -------------------------
# Rendering
# -------------------------

func _emit_update(header: String) -> void:
	var payload: Dictionary = {
		"status": _build_status_bb(header),
		"fleet_bb": _build_fleet_bb(),
		"enemy_bb": _build_enemy_bb(),
		"log_bb": get_log_bb()
	}

	if _turn_in_encounter <= 0:
		emit_signal("encounter_started", payload)
	else:
		emit_signal("encounter_updated", payload)

func _build_status_bb(header: String) -> String:
	var s: String = ""
	s += "[b]%s[/b]\n" % header
	s += "Mutterschiff HP: [color=white]%d/%d[/color]\n" % [int(Global.mothership_hp), int(Global.max_mothership_hp)]
	s += "[color=gray]Aktion: Kämpfen (1 Runde) oder Fliehen (33%).[/color]\n"
	return s

func _build_fleet_bb() -> String:
	var bb: String = ""
	bb += "[b]DEINE FLOTTE[/b]\n\n"

	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		var cnt: int = int(stack.get("count", 0))
		if cnt <= 0:
			continue

		var max_hp: int = int(stack.get("max_hp", 1))
		var fp: int = int(stack.get("firepower", 0))
		var dmg_total: int = fp * cnt

		var unit_hp: Array = []
		if stack.has("unit_hp") and typeof(stack["unit_hp"]) == TYPE_ARRAY:
			unit_hp = stack["unit_hp"] as Array

		bb += "%s  [color=white]x%d[/color]  [color=cyan]DMG %d[/color]\n" % [str(stack.get("name", "Unit")), cnt, dmg_total]
		bb += _render_unit_bars(unit_hp, max_hp) + "\n\n"

	if _count_total_player_units() <= 0:
		bb += "[color=orange]Keine Drohnen aktiv.[/color]\n"

	return bb

func _build_enemy_bb() -> String:
	var bb: String = ""
	bb += "[b]GEGNER[/b]\n\n"

	for ev in _enemy_units:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = ev as Dictionary
		var name_txt: String = str(enemy.get("name", "Enemy"))
		var hp: int = int(enemy.get("hp", 0))
		var max_hp: int = int(enemy.get("max_hp", _safe_stat_from_dict(enemy, "durability", 10)))
		var fp: int = _safe_stat_from_dict(enemy, "firepower", 1)

		bb += "%s  [color=red]DMG %d[/color]\n" % [name_txt, fp]
		bb += _render_bar_inline(hp, max_hp) + "\n\n"

	if _enemy_units.size() == 0:
		bb += "[color=green]Keine Gegner mehr.[/color]\n"

	return bb

func _render_unit_bars(unit_hp: Array, max_hp: int) -> String:
	var out: String = ""
	var line: String = ""
	var per_line: int = 3

	for i in range(unit_hp.size()):
		var hp: int = int(unit_hp[i])
		var one: String = _render_bar_inline(hp, max_hp)
		line += one + "  "
		if ((i + 1) % per_line) == 0:
			out += line.strip_edges() + "\n"
			line = ""

	if line != "":
		out += line.strip_edges()

	return out

func _render_bar_inline(hp: int, max_hp: int) -> String:
	var mh: int = max(1, max_hp)
	var cells: int = BAR_WIDTH

	var hp_per_cell: int = int(ceil(float(mh) / float(cells)))
	hp_per_cell = max(1, hp_per_cell)

	var filled_cells: int = int(ceil(float(max(0, hp)) / float(hp_per_cell)))
	filled_cells = clamp(filled_cells, 0, cells)

	var bar: String = ""
	bar += "[color=gray]["
	for i in range(cells):
		if i < filled_cells:
			bar += "[/color][color=lime]█[/color][color=gray]"
		else:
			bar += "·"
	bar += "][/color] "
	bar += "[color=white]%d/%d[/color]" % [hp, max_hp]
	return bar

# -------------------------
# Logging / endings
# -------------------------

func _log_line(text_bb: String) -> void:
	_log_buffer.append(text_bb)

func _end_victory() -> void:
	var xp: int = 50 * max(1, _system_enemy_ref.size())
	Global.gain_xp(xp)

	_log_line("\n[color=green][b]SIEG![/b][/color] Gegner eliminiert. XP: [b]+%d[/b]" % xp)
	_system_enemy_ref.clear()
	_active = false

	var payload: Dictionary = {
		"result": "SIEG (+%d XP)" % xp,
		"status": _build_status_bb("ENCOUNTER ENDED"),
		"fleet_bb": _build_fleet_bb(),
		"enemy_bb": _build_enemy_bb(),
		"log_bb": get_log_bb()
	}
	emit_signal("encounter_ended", payload)

	var report: Dictionary = {
		"status": "VICTORY",
		"xp_gained": xp,
		"mothership_damage": 0,
		"player_losses": {}
	}
	emit_signal("combat_occurred", report)

func _end_flee() -> void:
	_active = false
	_log_line("\n[color=yellow]Du ziehst dich zurück.[/color]")

	var payload: Dictionary = {
		"result": "FLUCHT",
		"status": _build_status_bb("ENCOUNTER ENDED"),
		"fleet_bb": _build_fleet_bb(),
		"enemy_bb": _build_enemy_bb(),
		"log_bb": get_log_bb()
	}
	emit_signal("encounter_ended", payload)

	var report: Dictionary = {
		"status": "FLED",
		"xp_gained": 0,
		"mothership_damage": 0,
		"player_losses": {}
	}
	emit_signal("combat_occurred", report)

func _end_defeat(reason: String) -> void:
	_log_line("\n[color=red][b]NIEDERLAGE![/b][/color] %s" % reason)
	_active = false

	var payload: Dictionary = {
		"result": "NIEDERLAGE: %s" % reason,
		"status": _build_status_bb("ENCOUNTER ENDED"),
		"fleet_bb": _build_fleet_bb(),
		"enemy_bb": _build_enemy_bb(),
		"log_bb": get_log_bb()
	}
	emit_signal("encounter_ended", payload)

	var report: Dictionary = {
		"status": "DEFEAT",
		"xp_gained": 0,
		"mothership_damage": 0,
		"player_losses": {}
	}
	emit_signal("combat_occurred", report)

func _count_alive_in_stack(stack: Dictionary) -> int:
	if not stack.has("unit_hp") or typeof(stack["unit_hp"]) != TYPE_ARRAY:
		return 0
	var unit_hp: Array = stack["unit_hp"] as Array
	return unit_hp.size()

func _count_total_player_units() -> int:
	var total: int = 0
	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		total += int(stack.get("count", 0))
	return total
