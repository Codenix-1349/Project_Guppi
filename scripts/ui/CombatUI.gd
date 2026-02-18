# === scripts/ui/CombatUI.gd ===
extends Node
class_name CombatUI
## Runtime combat panel, battle log, encounter hooks, and unit row rendering.
## Extracted from Main.gd for separation of concerns.

signal combat_mode_changed(active: bool)

# Battle log placement + sizing (bottom-right corner)
const BATTLELOG_MARGIN_RIGHT: float = 16.0
const BATTLELOG_MARGIN_BOTTOM: float = 24.0
const BATTLELOG_W_EXPANDED: float = 420.0
const BATTLELOG_H_EXPANDED: float = 260.0
const BATTLELOG_W_COLLAPSED: float = 190.0
const BATTLELOG_H_HEADER: float = 44.0

# References (set via init)
var combat_manager: Node = null
var icon_renderer: Node = null   # IconRenderer instance

# Combat panel nodes
var _combat_panel: PanelContainer = null
var _combat_status: RichTextLabel = null
var _combat_fleet_rows: VBoxContainer = null
var _combat_enemy_rows: VBoxContainer = null
var _combat_fight_btn: Button = null
var _combat_flee_btn: Button = null
var _combat_close_btn: Button = null

# Battle log nodes
var _battle_panel: PanelContainer = null
var _battle_scroll: ScrollContainer = null
var _battle_rich: RichTextLabel = null
var _battle_toggle_btn: Button = null
var _battle_collapsed: bool = true

# Combat mode tracking
var _combat_mode_active: bool = false

# -----------------------------------------------
# Initialization
# -----------------------------------------------

func init(p_combat_manager: Node, p_icon_renderer: Node, ui_root: Control) -> void:
	combat_manager = p_combat_manager
	icon_renderer = p_icon_renderer
	_setup_combat_panel(ui_root)
	_setup_battle_log(ui_root)
	_connect_combat_signals()

# -----------------------------------------------
# Combat mode toggling
# -----------------------------------------------

func is_combat_active() -> bool:
	return _combat_mode_active

func set_combat_mode(active: bool) -> void:
	if _combat_mode_active == active:
		return
	_combat_mode_active = active
	emit_signal("combat_mode_changed", active)

# -----------------------------------------------
# Combat panel setup
# -----------------------------------------------

func _setup_combat_panel(ui_root: Control) -> void:
	_combat_panel = PanelContainer.new()
	_combat_panel.name = "CombatPanelRuntime"
	_combat_panel.visible = false
	_combat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_combat_panel.z_index = 2000

	_combat_panel.anchor_left = 0.0
	_combat_panel.anchor_top = 0.0
	_combat_panel.anchor_right = 1.0
	_combat_panel.anchor_bottom = 1.0
	_combat_panel.offset_left = 16
	_combat_panel.offset_top = 120
	_combat_panel.offset_right = -16
	_combat_panel.offset_bottom = -16

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.06, 0.08, 0.92)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	_combat_panel.add_theme_stylebox_override("panel", bg)

	ui_root.add_child(_combat_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_combat_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "KAMPF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_combat_status = RichTextLabel.new()
	_combat_status.bbcode_enabled = true
	_combat_status.scroll_active = false
	_combat_status.fit_content = true
	_combat_status.text = "[center][color=gray]Kein Kampf aktiv[/color][/center]"
	vbox.add_child(_combat_status)

	var lists: HBoxContainer = HBoxContainer.new()
	lists.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override("separation", 24)
	vbox.add_child(lists)

	# Fleet side
	var fleet_box: VBoxContainer = VBoxContainer.new()
	fleet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(fleet_box)

	var ft: Label = Label.new()
	ft.text = "DEINE FLOTTE"
	fleet_box.add_child(ft)

	var fleet_scroll: ScrollContainer = ScrollContainer.new()
	fleet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fleet_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_box.add_child(fleet_scroll)

	_combat_fleet_rows = VBoxContainer.new()
	_combat_fleet_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_fleet_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_fleet_rows.add_theme_constant_override("separation", 10)
	fleet_scroll.add_child(_combat_fleet_rows)

	# Enemy side
	var enemy_box: VBoxContainer = VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_child(enemy_box)

	var et: Label = Label.new()
	et.text = "GEGNER"
	enemy_box.add_child(et)

	var enemy_scroll: ScrollContainer = ScrollContainer.new()
	enemy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enemy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_box.add_child(enemy_scroll)

	_combat_enemy_rows = VBoxContainer.new()
	_combat_enemy_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_combat_enemy_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_combat_enemy_rows.add_theme_constant_override("separation", 10)
	enemy_scroll.add_child(_combat_enemy_rows)

	# Buttons
	var btns: HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 14)
	vbox.add_child(btns)

	_combat_fight_btn = Button.new()
	_combat_fight_btn.text = "KÄMPFEN (1 Runde)"
	btns.add_child(_combat_fight_btn)

	_combat_flee_btn = Button.new()
	_combat_flee_btn.text = "FLIEHEN (33%)"
	btns.add_child(_combat_flee_btn)

	_combat_close_btn = Button.new()
	_combat_close_btn.text = "SCHLIESSEN"
	_combat_close_btn.visible = false
	btns.add_child(_combat_close_btn)

	_combat_fight_btn.pressed.connect(func() -> void:
		if combat_manager and combat_manager.has_method("player_fight_round"):
			combat_manager.player_fight_round()
	)

	_combat_flee_btn.pressed.connect(func() -> void:
		if combat_manager and combat_manager.has_method("player_try_flee"):
			combat_manager.player_try_flee()
	)

	_combat_close_btn.pressed.connect(func() -> void:
		_combat_panel.visible = false
		set_combat_mode(false)
		_set_battle_log_active(false)
	)

# -----------------------------------------------
# Battle log setup
# -----------------------------------------------

func _setup_battle_log(ui_root: Control) -> void:
	_battle_panel = PanelContainer.new()
	_battle_panel.name = "BattleLogRuntime"
	_battle_panel.visible = false
	_battle_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_panel.top_level = true
	_battle_panel.z_index = 3000

	_battle_panel.anchor_left = 1.0
	_battle_panel.anchor_top = 1.0
	_battle_panel.anchor_right = 1.0
	_battle_panel.anchor_bottom = 1.0
	_battle_panel.offset_right = -BATTLELOG_MARGIN_RIGHT

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.02, 0.03, 0.78)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8
	_battle_panel.add_theme_stylebox_override("panel", bg)

	ui_root.add_child(_battle_panel)

	var root_v: VBoxContainer = VBoxContainer.new()
	root_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_panel.add_child(root_v)

	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_v.add_child(header)

	var title: Label = Label.new()
	title.text = "BATTLE LOG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_battle_toggle_btn = Button.new()
	_battle_toggle_btn.text = "Show"
	header.add_child(_battle_toggle_btn)

	_battle_toggle_btn.pressed.connect(func() -> void:
		_battle_collapsed = !_battle_collapsed
		_apply_battle_log_layout()
		if not _battle_collapsed:
			call_deferred("_scroll_battle_log_to_bottom")
	)

	_battle_scroll = ScrollContainer.new()
	_battle_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(_battle_scroll)

	_battle_rich = RichTextLabel.new()
	_battle_rich.bbcode_enabled = true
	_battle_rich.scroll_active = false
	_battle_rich.fit_content = true
	_battle_rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_rich.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_battle_rich.text = ""
	_battle_scroll.add_child(_battle_rich)

	_battle_collapsed = true
	_apply_battle_log_layout()

# -----------------------------------------------
# Signal connections
# -----------------------------------------------

func _connect_combat_signals() -> void:
	if combat_manager == null:
		return
	if combat_manager.has_signal("encounter_started"):
		combat_manager.encounter_started.connect(_on_encounter_ui)
	if combat_manager.has_signal("encounter_updated"):
		combat_manager.encounter_updated.connect(_on_encounter_ui)
	if combat_manager.has_signal("encounter_ended"):
		combat_manager.encounter_ended.connect(_on_encounter_end)

# -----------------------------------------------
# Battle log helpers
# -----------------------------------------------

func _set_battle_log_active(active: bool) -> void:
	if _battle_panel == null:
		return
	_battle_panel.visible = active
	if not active:
		_battle_rich.text = ""
		_battle_collapsed = true
		_apply_battle_log_layout()

func _apply_battle_log_layout() -> void:
	if _battle_panel == null:
		return

	var right: float = -BATTLELOG_MARGIN_RIGHT
	var bottom: float = -BATTLELOG_MARGIN_BOTTOM

	if _battle_collapsed:
		_battle_toggle_btn.text = "Show"
		_battle_scroll.visible = false
		_battle_panel.custom_minimum_size = Vector2(BATTLELOG_W_COLLAPSED, 0)
		_battle_panel.offset_right = right
		_battle_panel.offset_left = -(BATTLELOG_W_COLLAPSED + BATTLELOG_MARGIN_RIGHT)
		_battle_panel.offset_bottom = bottom
		_battle_panel.offset_top = bottom - BATTLELOG_H_HEADER
	else:
		_battle_toggle_btn.text = "Hide"
		_battle_scroll.visible = true
		_battle_panel.custom_minimum_size = Vector2(BATTLELOG_W_EXPANDED, BATTLELOG_H_EXPANDED)
		_battle_panel.offset_right = right
		_battle_panel.offset_left = -(BATTLELOG_W_EXPANDED + BATTLELOG_MARGIN_RIGHT)
		_battle_panel.offset_bottom = bottom
		_battle_panel.offset_top = bottom - BATTLELOG_H_EXPANDED

func _update_battle_log_text(payload: Dictionary) -> void:
	if _battle_panel == null:
		return
	if not _battle_panel.visible:
		return

	var log_bb: String = ""
	if payload.has("log_bb"):
		log_bb = str(payload["log_bb"])
	elif combat_manager and combat_manager.has_method("get_log_bb"):
		log_bb = str(combat_manager.get_log_bb())

	_battle_rich.text = log_bb

	if not _battle_collapsed:
		call_deferred("_scroll_battle_log_to_bottom")

func _scroll_battle_log_to_bottom() -> void:
	if _battle_scroll == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var sb: ScrollBar = _battle_scroll.get_v_scroll_bar()
	if sb:
		_battle_scroll.scroll_vertical = int(sb.max_value)

# -----------------------------------------------
# Unit row rendering
# -----------------------------------------------

const ICON_SIZE: int = 64

func _clear_rows(box: VBoxContainer) -> void:
	if box == null:
		return
	for c in box.get_children():
		(c as Node).queue_free()

func _make_unit_row(unit: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var unit_id: String = str(unit.get("id", ""))
	var unit_name: String = str(unit.get("name", "Unit"))
	var cnt: int = int(unit.get("count", 0))
	var front_hp: int = int(unit.get("front_hp", 0))
	var max_hp: int = int(unit.get("max_hp", 1))
	var dmg_total: int = int(unit.get("firepower_total", 0))

	# Icon
	var icon: TextureRect = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if icon_renderer and icon_renderer.has_method("get_unit_icon"):
		icon.texture = icon_renderer.get_unit_icon(unit_id, unit_name)
	row.add_child(icon)

	# Text + bar
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)

	var name_lbl: Label = Label.new()
	if unit_id == "mothership":
		name_lbl.text = "%s" % unit_name
	else:
		name_lbl.text = "%s  x%d" % [unit_name, cnt]
	col.add_child(name_lbl)

	var info: Label = Label.new()
	if unit_id == "mothership":
		info.text = "HP %d/%d" % [front_hp, max_hp]
	else:
		info.text = "DMG %d   |   Front HP %d/%d" % [dmg_total, front_hp, max_hp]
	info.modulate = Color(0.85, 0.88, 0.95, 1.0)
	col.add_child(info)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max(1, max_hp)
	bar.value = clamp(front_hp, 0, int(bar.max_value))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 18)
	col.add_child(bar)

	return row

func _render_combat_lists(payload: Dictionary) -> void:
	if _combat_fleet_rows == null or _combat_enemy_rows == null:
		return

	_clear_rows(_combat_fleet_rows)
	_clear_rows(_combat_enemy_rows)

	var fleet_units: Array = payload.get("fleet_units", [])
	var enemy_units: Array = payload.get("enemy_units", [])

	for u in fleet_units:
		if typeof(u) != TYPE_DICTIONARY:
			continue
		_combat_fleet_rows.add_child(_make_unit_row(u as Dictionary))

	for u2 in enemy_units:
		if typeof(u2) != TYPE_DICTIONARY:
			continue
		_combat_enemy_rows.add_child(_make_unit_row(u2 as Dictionary))

# -----------------------------------------------
# Encounter hooks
# -----------------------------------------------

func _on_encounter_ui(payload: Dictionary) -> void:
	if _combat_panel == null:
		return

	set_combat_mode(true)
	_combat_panel.visible = true
	_combat_close_btn.visible = false
	_combat_fight_btn.disabled = false
	_combat_flee_btn.disabled = false

	_combat_status.text = str(payload.get("status", ""))

	_render_combat_lists(payload)

	_set_battle_log_active(true)
	_battle_collapsed = false
	_apply_battle_log_layout()
	_update_battle_log_text(payload)

func _on_encounter_end(payload: Dictionary) -> void:
	if _combat_panel == null:
		return

	var result: String = str(payload.get("result", ""))
	if result != "":
		_combat_status.text = "[b]Result:[/b] " + result + "\n\n" + _combat_status.text

	_combat_fight_btn.disabled = true
	_combat_flee_btn.disabled = true
	_combat_close_btn.visible = true

	_render_combat_lists(payload)

	_set_battle_log_active(true)
	_update_battle_log_text(payload)
