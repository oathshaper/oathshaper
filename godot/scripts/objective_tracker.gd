extends PanelContainer

signal dismissed

const QUEST_TITLE := "THE QUAY ROBBERY"
const ACTIVE_COLOR := Color("#ffdb72")
const COMPLETE_COLOR := Color("#a9dca8")

var _quest_title := QUEST_TITLE
var _panel_style: StyleBoxFlat
var _eyebrow: Label
var _heading: Label
var _step: Label
var _distance: Label
var collapse_button: Button
var dismiss_button: Button
var _last_stage := ""
var _last_metres := -1
var _collapsed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.035, 0.055, 0.075, 0.88)
	_panel_style.border_width_left = 4
	_panel_style.corner_radius_top_left = 5
	_panel_style.corner_radius_bottom_left = 5
	add_theme_stylebox_override("panel", _panel_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_eyebrow = Label.new()
	_eyebrow.text = "TRACKED OBJECTIVE"
	_eyebrow.add_theme_font_size_override("font_size", 13)
	_eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_eyebrow)
	collapse_button = Button.new()
	collapse_button.text = "−"
	collapse_button.tooltip_text = "Collapse or expand quest"
	collapse_button.focus_mode = Control.FOCUS_NONE
	collapse_button.flat = true
	collapse_button.custom_minimum_size = Vector2(28.0, 26.0)
	collapse_button.add_theme_font_size_override("font_size", 14)
	_make_compact_button(collapse_button)
	collapse_button.pressed.connect(_on_collapse_pressed)
	header.add_child(collapse_button)
	dismiss_button = Button.new()
	dismiss_button.text = "×"
	preload("res://scripts/input_hints.gd").attach(self).bind(dismiss_button, "Dismiss objective (J)", "Dismiss objective (Y)", "tooltip_text")
	dismiss_button.focus_mode = Control.FOCUS_NONE
	dismiss_button.flat = true
	dismiss_button.custom_minimum_size = Vector2(28.0, 26.0)
	dismiss_button.add_theme_font_size_override("font_size", 14)
	_make_compact_button(dismiss_button)
	dismiss_button.add_theme_color_override("font_color", Color("bdc9c3"))
	dismiss_button.pressed.connect(_on_dismiss_pressed)
	header.add_child(dismiss_button)
	_heading = Label.new()
	_heading.text = QUEST_TITLE
	_heading.add_theme_font_size_override("font_size", 18)
	column.add_child(_heading)
	_step = Label.new()
	_step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_step.add_theme_font_size_override("font_size", 16)
	column.add_child(_step)
	_distance = Label.new()
	_distance.add_theme_font_size_override("font_size", 14)
	column.add_child(_distance)
	set_objective("mara", INF)


func _on_dismiss_pressed() -> void:
	dismissed.emit()


func _make_compact_button(button: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, empty)


func _on_collapse_pressed() -> void:
	set_collapsed(not _collapsed)


func set_collapsed(collapsed: bool) -> void:
	_collapsed = collapsed
	_eyebrow.text = _quest_title if collapsed else "TRACKED OBJECTIVE"
	_heading.visible = not collapsed
	_step.visible = not collapsed
	_distance.visible = not collapsed
	collapse_button.text = "+" if collapsed else "−"
	collapse_button.tooltip_text = "Expand quest" if collapsed else "Collapse quest"
	offset_bottom = offset_top + desired_height()


func is_collapsed() -> bool:
	return _collapsed


func desired_height() -> float:
	# Explicit HUD bounds prevent an early word-wrap minimum from leaving a
	# tall empty panel before the first viewport layout pass.
	return 52.0 if _collapsed else 156.0


func set_objective(stage: String, distance_metres: float) -> void:
	var metres := roundi(distance_metres) if is_finite(distance_metres) else -1
	if stage == _last_stage and metres == _last_metres:
		return
	_quest_title = QUEST_TITLE
	_heading.text = _quest_title
	if stage != _last_stage:
		set_collapsed(false)
	_last_stage = stage
	_last_metres = metres
	var color := COMPLETE_COLOR if stage in ["done", "robbery_done"] else ACTIVE_COLOR
	_panel_style.border_color = color
	for label in [_eyebrow, _heading, _step, _distance]:
		label.add_theme_color_override("font_color", color)
	collapse_button.add_theme_color_override("font_color", color)
	match stage:
		"mara":
			_step.text = "Tell Mara the payroll was stolen. Ask her to join you."
		"clerk":
			_step.text = "Check on the clerk in her office beside the tower."
		"records_door":
			_step.text = "Enter the west archive's records door."
		"cabinet":
			_step.text = "Open the iron filing cabinet inside."
		"garden_gate":
			_step.text = "Talk to Ivo at the garden gate. He has the thief cornered."
		"garden":
			_step.text = "Join Mara and Ivo at the gate. Defeat the raider and his guards."
		"pay_loot":
			_step.text = "Search the defeated raider for the payroll pouch."
		"return_pay":
			_step.text = "Return the stolen payroll to the clerk in her office."
		"robbery_done":
			_step.text = "The wages are returned and the tower is lit."
			_distance.text = "COMPLETE"
			return
		"done":
			_step.text = "Records recovered. Read them in Inventory."
			_distance.text = "COMPLETE"
			return
		_:
			_step.text = "Explore Lantern Quay."
	_distance.text = "%d m to waypoint" % metres if metres >= 0 else "Follow the map waypoint"
