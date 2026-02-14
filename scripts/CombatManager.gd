extends Node
# CombatManager.gd (Godot 4.x strict-parse safe)
# Combat with aggregated stacks + segmented HP bars + working battle log.
# + Structured payload data for UI icons (fleet_units / enemy_units)

signal encounter_started(payload: Dictionary)
signal encounter_updated(payload: Dictionary)
signal encounter_ended(payload: Dictionary)

# Legacy (optional)
signal combat_occurred(results)

const FLEE_CHANCE: float = 0.3333
const BAR_WIDTH: int = 26  # visual width for large HP (mothership/enemies with big durability)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _active: bool = false
var _turn_in_encounter: int = 0

var _player_inventory_ref: Dictionary = {}
var _system_enemy_ref: Array = []

# Aggregated stacks
# stack: { id, name, count, max_hp, firepower, unit_hp:Array[int] }  unit_hp[0] is the "front" unit
var _player_stacks: Array = []
var _enemy_stacks: Array = []

# BBCode log lines
var _log_buffer: Array = []

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

# -------------------------
# Encounter lifecycle
# -------------------------

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

	_player_stacks.clear()
	_enemy_stacks.clear()
	_log_buffer.clear()

	_player_stacks = _build_player_stacks_from_inventory(_player_inventory_ref)
	_enemy_stacks = _build_enemy_stacks_from_system(_system_enemy_ref)

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

	if _count_total_enemy_units() <= 0:
		_end_victory()
		return

	_enemy_attack_phase(false)

	if int(Global.mothership_hp) <= 0:
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

	if int(Global.mothership_hp) <= 0:
		_end_defeat("HÜLLE ZERSTÖRT")
		return

	_emit_update("FLEE FAILED")

# -------------------------
# Phases
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

		# ✅ all living units of that type shoot
		var base: int = fp * cnt
		var dmg: int = int(float(base) * _rng.randf_range(0.85, 1.15))
		dmg = max(0, dmg)

		if _count_total_enemy_units() <= 0:
			break

		var target_idx: int = _pick_enemy_stack_target_index()
		if target_idx == -1:
			break

		var target: Dictionary = _enemy_stacks[target_idx] as Dictionary
		var t_name: String = str(target.get("name", "Enemy"))
		var attacker_name: String = str(stack.get("name","Unit"))

		_log_line("[color=cyan]%s x%d[/color] feuert auf [color=red]%s[/color] für [b]%d[/b] DMG"
			% [attacker_name, cnt, t_name, dmg])

		_apply_damage_to_stack(target, dmg, true)

	if not any_fire:
		_log_line("[color=gray]Deine Flotte hat keine Feuerkraft.[/color]")

	_sync_inventory_from_stacks()

func _enemy_attack_phase(free_attack: bool) -> void:
	if _count_total_enemy_units() <= 0:
		return

	var total_player_units: int = _count_total_player_units()

	for ev in _enemy_stacks:
		if typeof(ev) != TYPE_DICTIONARY:
			continue

		var enemy_stack: Dictionary = ev as Dictionary
		var cnt: int = _count_alive_in_stack(enemy_stack)
		if cnt <= 0:
			continue

		var e_name: String = str(enemy_stack.get("name", "Enemy"))
		var e_fp: int = int(enemy_stack.get("firepower", 1))

		# ✅ all living enemies in this stack shoot
		var base: int = e_fp * cnt
		var dmg: int = int(float(base) * _rng.randf_range(0.85, 1.15))
		dmg = max(1, dmg)

		if total_player_units <= 0:
			var hull_dmg: int = int(dmg * (3.0 if free_attack else 2.0))
			_log_line("[color=red]%s x%d[/color] trifft [color=orange]HÜLLE[/color] für [b]%d[/b] DMG" % [e_name, cnt, hull_dmg])
			_apply_damage_to_mothership(hull_dmg)
			if int(Global.mothership_hp) <= 0:
				return
			continue

		var t_stack_idx: int = _pick_player_stack_target_index()
		if t_stack_idx == -1:
			var hull_dmg2: int = int(dmg * 2.0)
			_log_line("[color=red]%s x%d[/color] trifft [color=orange]HÜLLE[/color] für [b]%d[/b] DMG" % [e_name, cnt, hull_dmg2])
			_apply_damage_to_mothership(hull_dmg2)
			if int(Global.mothership_hp) <= 0:
				return
			continue

		var t_stack: Dictionary = _player_stacks[t_stack_idx] as Dictionary
		var t_name: String = str(t_stack.get("name", "Unit"))

		_log_line("[color=red]%s x%d[/color] schießt auf [color=cyan]%s[/color] für [b]%d[/b] DMG" % [e_name, cnt, t_name, dmg])
		_apply_damage_to_stack(t_stack, dmg, false)

		_sync_inventory_from_stacks()
		total_player_units = _count_total_player_units()
		if total_player_units <= 0:
			_log_line("[color=orange]Alle Drohnen zerstört![/color] Ab jetzt geht Schaden auf die Hülle.")

# -------------------------
# Damage + carry-over
# -------------------------

func _apply_damage_to_stack(stack: Dictionary, dmg: int, target_is_enemy: bool) -> void:
	var remaining: int = dmg
	var name_txt: String = str(stack.get("name", "Unit"))
	var max_hp: int = int(stack.get("max_hp", 1))

	if not stack.has("unit_hp") or typeof(stack["unit_hp"]) != TYPE_ARRAY:
		return

	var unit_hp: Array = stack["unit_hp"] as Array

	# ✅ carry over: always hits the "front" unit first
	while remaining > 0 and unit_hp.size() > 0:
		var current_hp: int = int(unit_hp[0])
		var take: int = min(remaining, current_hp)
		current_hp -= take
		remaining -= take

		if current_hp <= 0:
			unit_hp.remove_at(0)
			stack["count"] = unit_hp.size()
			_log_line("→ %s verliert 1 Einheit! (Rest: x%d)" % [
				("[color=red]%s[/color]" % name_txt) if target_is_enemy else ("[color=cyan]%s[/color]" % name_txt),
				int(stack["count"])
			])
		else:
			unit_hp[0] = current_hp
			_log_line("→ %s vorderste Einheit HP %d/%d" % [
				("[color=red]%s[/color]" % name_txt) if target_is_enemy else ("[color=cyan]%s[/color]" % name_txt),
				current_hp, max_hp
			])

	stack["unit_hp"] = unit_hp

func _apply_damage_to_mothership(dmg: int) -> void:
	Global.mothership_hp = int(Global.mothership_hp) - int(dmg)
	if int(Global.mothership_hp) < 0:
		Global.mothership_hp = 0

# -------------------------
# Build stacks
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

func _build_enemy_stacks_from_system(enemies: Array) -> Array:
	var stacks: Array = []
	var by_id: Dictionary = {} # id -> stack dict

	for ev in enemies:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = ev as Dictionary
		var id: String = str(e.get("id", e.get("name", "enemy")))
		var name_txt: String = str(e.get("name", id))
		var max_hp: int = _safe_stat_from_dict(e, "durability", 10)
		var fp: int = _safe_stat_from_dict(e, "firepower", 1)

		if not by_id.has(id):
			by_id[id] = {
				"id": id,
				"name": name_txt,
				"count": 0,
				"max_hp": max_hp,
				"firepower": fp,
				"unit_hp": []
			}

		var st: Dictionary = by_id[id] as Dictionary
		(st["unit_hp"] as Array).append(max_hp)
		st["count"] = int(st["count"]) + 1

	for k in by_id.keys():
		stacks.append(by_id[k])

	# stable order: tougher first (optional)
	stacks.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: int = int((a as Dictionary).get("max_hp", 0))
		var db: int = int((b as Dictionary).get("max_hp", 0))
		return da > db
	)

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

# -------------------------
# Target selection
# -------------------------

func _pick_player_stack_target_index() -> int:
	return _pick_stack_weighted(_player_stacks)

func _pick_enemy_stack_target_index() -> int:
	return _pick_stack_weighted(_enemy_stacks)

func _pick_stack_weighted(stacks: Array) -> int:
	var weights: Array = []
	var total: int = 0

	for i in range(stacks.size()):
		var sv: Variant = stacks[i]
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
# ✅ Structured payload for UI
# -------------------------

func _build_fleet_units_payload() -> Array:
	var out: Array = []

	# mothership always first
	out.append({
		"id": "mothership",
		"name": "Mutterschiff",
		"count": 1,
		"front_hp": int(Global.mothership_hp),
		"max_hp": int(Global.max_mothership_hp),
		"firepower_total": 0
	})

	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var st: Dictionary = sv as Dictionary
		var cnt: int = int(st.get("count", 0))
		if cnt <= 0:
			continue

		var unit_hp: Array = (st["unit_hp"] as Array) if st.has("unit_hp") and typeof(st["unit_hp"]) == TYPE_ARRAY else []
		var front_hp: int = int(unit_hp[0]) if unit_hp.size() > 0 else 0
		var fp: int = int(st.get("firepower", 0))
		var total_dmg: int = fp * cnt

		out.append({
			"id": str(st.get("id", "")),
			"name": str(st.get("name", "Unit")),
			"count": cnt,
			"front_hp": front_hp,
			"max_hp": int(st.get("max_hp", 1)),
			"firepower_total": total_dmg
		})

	return out

func _build_enemy_units_payload() -> Array:
	var out: Array = []

	for ev in _enemy_stacks:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var st: Dictionary = ev as Dictionary
		var cnt: int = int(st.get("count", 0))
		if cnt <= 0:
			continue

		var unit_hp: Array = (st["unit_hp"] as Array) if st.has("unit_hp") and typeof(st["unit_hp"]) == TYPE_ARRAY else []
		var front_hp: int = int(unit_hp[0]) if unit_hp.size() > 0 else 0
		var fp: int = int(st.get("firepower", 1))
		var total_dmg: int = fp * cnt

		out.append({
			"id": str(st.get("id", "")),
			"name": str(st.get("name", "Enemy")),
			"count": cnt,
			"front_hp": front_hp,
			"max_hp": int(st.get("max_hp", 1)),
			"firepower_total": total_dmg
		})

	return out

# -------------------------
# Rendering payload
# -------------------------

func _emit_update(header: String) -> void:
	var payload: Dictionary = {
		"status": _build_status_bb(header),
		"fleet_bb": _build_fleet_bb(),
		"enemy_bb": _build_enemy_bb(),
		"log_bb": get_log_bb(),

		# ✅ structured (for UI icons)
		"fleet_units": _build_fleet_units_payload(),
		"enemy_units": _build_enemy_units_payload()
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
	bb += "[b]FLOTTE[/b]\n\n"

	# ✅ Mothership bar in combat
	bb += "[color=orange]Mutterschiff[/color]\n"
	bb += _render_segment_bar(int(Global.mothership_hp), int(Global.max_mothership_hp)) + "\n\n"

	var any_units: bool = false

	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		var cnt: int = int(stack.get("count", 0))
		if cnt <= 0:
			continue

		any_units = true

		var max_hp: int = int(stack.get("max_hp", 1))
		var fp: int = int(stack.get("firepower", 0))
		var dmg_total: int = fp * cnt

		# front unit HP
		var unit_hp: Array = (stack["unit_hp"] as Array) if stack.has("unit_hp") and typeof(stack["unit_hp"]) == TYPE_ARRAY else []
		var front_hp: int = int(unit_hp[0]) if unit_hp.size() > 0 else 0

		bb += "%s  [color=white]%dx[/color]  [color=cyan]DMG %d[/color]\n" % [str(stack.get("name", "Unit")), cnt, dmg_total]
		bb += _render_segment_bar(front_hp, max_hp) + "\n\n"

	if not any_units:
		bb += "[color=gray]Keine Drohnen aktiv.[/color]\n"

	return bb

func _build_enemy_bb() -> String:
	var bb: String = ""
	bb += "[b]GEGNER[/b]\n\n"

	if _count_total_enemy_units() <= 0:
		bb += "[color=green]Keine Gegner mehr.[/color]\n"
		return bb

	for ev in _enemy_stacks:
		if typeof(ev) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = ev as Dictionary
		var cnt: int = int(stack.get("count", 0))
		if cnt <= 0:
			continue

		var max_hp: int = int(stack.get("max_hp", 1))
		var fp: int = int(stack.get("firepower", 1))
		var dmg_total: int = fp * cnt

		var unit_hp: Array = (stack["unit_hp"] as Array) if stack.has("unit_hp") and typeof(stack["unit_hp"]) == TYPE_ARRAY else []
		var front_hp: int = int(unit_hp[0]) if unit_hp.size() > 0 else 0

		bb += "%s  [color=white]%dx[/color]  [color=red]DMG %d[/color]\n" % [str(stack.get("name","Enemy")), cnt, dmg_total]
		bb += _render_segment_bar(front_hp, max_hp) + "\n\n"

	return bb

# -------------------------
# HP bar rendering (segments)
# -------------------------

func _render_segment_bar(hp: int, max_hp: int) -> String:
	var mh: int = max(1, max_hp)
	var h: int = clamp(hp, 0, mh)

	# For small HP pools (drones etc): 1 segment == 1 HP
	if mh <= BAR_WIDTH:
		var filled: int = h
		var empty: int = mh - h

		var bar := ""
		bar += "[color=gray][[/color]"
		bar += "[color=lime]" + "█".repeat(filled) + "[/color]"
		bar += "[color=gray]" + "·".repeat(empty) + "[/color]"
		bar += "[color=gray]][/color] "
		bar += "[color=white]%d/%d[/color]" % [h, mh]
		return bar

	# For huge pools (mothership, fortress): compress
	var cells: int = BAR_WIDTH
	var hp_per_cell: int = int(ceil(float(mh) / float(cells)))
	hp_per_cell = max(1, hp_per_cell)

	var filled_cells: int = int(ceil(float(h) / float(hp_per_cell)))
	filled_cells = clamp(filled_cells, 0, cells)
	var empty_cells: int = cells - filled_cells

	var bar2 := ""
	bar2 += "[color=gray][[/color]"
	bar2 += "[color=lime]" + "█".repeat(filled_cells) + "[/color]"
	bar2 += "[color=gray]" + "·".repeat(empty_cells) + "[/color]"
	bar2 += "[color=gray]][/color] "
	bar2 += "[color=white]%d/%d[/color]" % [h, mh]
	return bar2

# -------------------------
# Endings + log
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
		"log_bb": get_log_bb(),
		"fleet_units": _build_fleet_units_payload(),
		"enemy_units": _build_enemy_units_payload()
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
		"log_bb": get_log_bb(),
		"fleet_units": _build_fleet_units_payload(),
		"enemy_units": _build_enemy_units_payload()
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
		"log_bb": get_log_bb(),
		"fleet_units": _build_fleet_units_payload(),
		"enemy_units": _build_enemy_units_payload()
	}
	emit_signal("encounter_ended", payload)

	var report: Dictionary = {
		"status": "DEFEAT",
		"xp_gained": 0,
		"mothership_damage": 0,
		"player_losses": {}
	}
	emit_signal("combat_occurred", report)

# -------------------------
# Counters
# -------------------------

func _count_alive_in_stack(stack: Dictionary) -> int:
	if not stack.has("unit_hp") or typeof(stack["unit_hp"]) != TYPE_ARRAY:
		return 0
	return (stack["unit_hp"] as Array).size()

func _count_total_player_units() -> int:
	var total: int = 0
	for sv in _player_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		total += int(stack.get("count", 0))
	return total

func _count_total_enemy_units() -> int:
	var total: int = 0
	for sv in _enemy_stacks:
		if typeof(sv) != TYPE_DICTIONARY:
			continue
		var stack: Dictionary = sv as Dictionary
		total += int(stack.get("count", 0))
	return total
