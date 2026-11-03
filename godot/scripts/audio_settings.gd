extends CanvasLayer
const UI := preload("res://scripts/combat_theme.gd")
var mixer: Node
var _was_paused := false
var _focus: Control

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	var shade := ColorRect.new()
	shade.color = Color(0.02, .03, .04, .94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 70)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 30)
	shade.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(UI.label("Audio", 32, UI.INK, true))
	var first: HSlider
	for bus in mixer.BUSES:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 54
		row.add_theme_constant_override("separation", 20)
		page.add_child(row)
		var label := UI.label(bus, 22)
		label.custom_minimum_size.x = 140
		row.add_child(label)
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.custom_minimum_size.y = 36
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.value = mixer.levels[bus] * 100.0
		row.add_child(slider)
		var amount := UI.label("%d%%" % slider.value, 22)
		amount.custom_minimum_size.x = 65
		row.add_child(amount)
		slider.value_changed.connect(func(value: float) -> void:
			mixer.set_level(bus, value / 100.0)
			amount.text = "%d%%" % value
		)
		if first == null: first = slider
	var actions := HBoxContainer.new()
	page.add_child(actions)
	actions.add_child(UI.button("Test interface", func() -> void: mixer.cue("queue")))
	actions.add_child(UI.button("Test effects", func() -> void: mixer.cue("strike")))
	page.add_child(UI.button("Back", _close))
	var hints := UI.label("", 18, UI.MUTED)
	page.add_child(hints)
	preload("res://scripts/input_hints.gd").attach(self).bind(hints, "← / → Adjust   Tab Browse   Esc Back", "D-pad Adjust / Browse   B Back")
	first.grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	get_tree().paused = _was_paused
	if is_instance_valid(_focus) and _focus.is_visible_in_tree(): _focus.grab_focus()
	queue_free()
