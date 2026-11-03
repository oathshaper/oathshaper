extends Control

## Pause journal. The scene owns the narrative state and save store; this control
## only presents that state and asks the scene to save or load.
signal closed
signal save_requested
signal load_requested
signal combat_style_requested
signal new_game_requested
signal input_observed(event: InputEvent)

const MAP_SCRIPT_PATH := "res://scripts/map_widget.gd"
const PROFILES := preload("res://scripts/combat_profiles.gd")
const CHAPTER := preload("res://scripts/garden_chapter.gd")
const UI := preload("res://scripts/combat_theme.gd")
const CATALOG := preload("res://scripts/party_catalog.gd")
const TAB_NAMES := ["Character", "Equipment", "Combat Style", "Inventory", "Map", "Load", "Save"]
const INK := Color("e8e1d0")
const MUTED := Color("b5bdbb")
const BRASS := Color("d7ad6b")
const FRAME := Color("17212a")
const PANEL := Color("23313a")

var _state: Dictionary = {}
var _moral_definition := {"label": "Mercy", "min": -5, "max": 5}
var _player_position := Vector3.ZERO
var _area := "quay"
var _waypoint_id := ""
var _using_controller := false
var _combat_profile_id := PROFILES.DEFAULT_ID
var _current_tab := 0
var _tab_buttons: Array[Button] = []
var _action_button: Button
var _actions: Array[Button] = []
var _axis_held := false
var _map_widget: Control
var _content: VBoxContainer
var _heading: Label
var _area_label: Label
var _feedback: Label
var _hint: Label
var _actor_index := 0
var _roster: Array[Button] = []
var _scroll: ScrollContainer
var _scroll_velocity := 0.0
var _scroll_remainder := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	visible = false
	set_input_mode(false)


func open_menu(state: Dictionary, player_position: Vector3, area: String, waypoint_id: String) -> void:
	_state = state.duplicate(true)
	_player_position = player_position
	_area = area
	_waypoint_id = waypoint_id
	_area_label.text = _area_name()
	_current_tab = 0
	set_feedback("")
	_render_tab()
	visible = true
	_tab_buttons[_current_tab].grab_focus()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	_scroll_velocity = 0.0
	closed.emit()


func set_input_mode(controller: bool) -> void:
	_using_controller = controller
	if _hint == null:
		return
	_hint.text = "Ⓑ Back   LB/RB Pages   Ⓧ/Ⓨ Actor   R-stick Scroll   D-pad Browse   Ⓐ Select" if controller else "Esc Back   ←/→ Pages   Q/E Actor   PgUp/PgDn Scroll   ↑/↓ Browse   Enter Select"

func _process(delta: float) -> void:
	if visible and absf(_scroll_velocity) > 0.2:
		_scroll_remainder += _scroll_velocity * 480.0 * delta
		var pixels := int(_scroll_remainder)
		_scroll.scroll_vertical += pixels
		_scroll_remainder -= pixels


func set_feedback(message: String) -> void:
	_feedback.text = message
	_feedback.visible = not message.is_empty()

func set_combat_profile(profile_id: String) -> void:
	_combat_profile_id = profile_id if PROFILES.is_valid(profile_id) else PROFILES.DEFAULT_ID
	var accent: Color = PROFILES.get_profile(_combat_profile_id).accent
	if _heading != null:
		_heading.add_theme_color_override("font_color", accent)
	if visible:
		_render_tab()

func set_moral_definition(definition: Dictionary) -> void:
	_moral_definition = definition.duplicate(true)


func update_state(state: Dictionary, player_position: Vector3, area: String, waypoint_id: String) -> void:
	_state = state.duplicate(true)
	_player_position = player_position
	_area = area
	_waypoint_id = waypoint_id
	if _area_label != null:
		_area_label.text = _area_name()
	if visible:
		_render_tab()


func _build_layout() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.055, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var frame := PanelContainer.new()
	frame.anchor_left = 0.045
	frame.anchor_top = 0.04
	frame.anchor_right = 0.955
	frame.anchor_bottom = 0.96
	frame.add_theme_stylebox_override("panel", _style(FRAME, BRASS, 2))
	add_child(frame)

	var frame_margin := MarginContainer.new()
	_margin(frame_margin, 16)
	frame.add_child(frame_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	frame_margin.add_child(page)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	page.add_child(header)
	var title := _label("THE WAYFARER'S LEDGER", 29, BRASS)
	title.add_theme_font_override("font", UI.serif())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_area_label = _label(_area_name(), 19, MUTED)
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_area_label)
	header.add_child(UI.button("Audio", func() -> void: preload("res://scripts/game_audio.gd").ensure(self).open_settings()))
	page.add_child(_rule())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	page.add_child(body)

	var tabs := VBoxContainer.new()
	tabs.custom_minimum_size = Vector2(222, 0)
	tabs.add_theme_constant_override("separation", 8)
	body.add_child(tabs)
	tabs.add_child(_label("PAGES", 17, MUTED))
	for index in range(TAB_NAMES.size()):
		var tab := Button.new()
		tab.custom_minimum_size = Vector2(0, 58)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.add_theme_font_size_override("font_size", 20)
		tab.pressed.connect(_select_tab.bind(index))
		_style_button(tab)
		tabs.add_child(tab)
		_tab_buttons.append(tab)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.add_theme_stylebox_override("panel", _style(PANEL, Color("6a7778"), 1))
	body.add_child(content_panel)
	var content_margin := MarginContainer.new()
	_margin(content_margin, 18)
	content_panel.add_child(content_margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	content_margin.add_child(inner)
	_heading = _label("", 28, BRASS)
	inner.add_child(_heading)
	inner.add_child(_rule())
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 6)
	inner.add_child(roster)
	for index in range(CATALOG.actors().size()):
		var button := Button.new()
		button.text = CATALOG.actors()[index].short
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		_style_button(button)
		button.pressed.connect(_select_actor.bind(index))
		roster.add_child(button)
		_roster.append(button)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	inner.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)

	_feedback = _label("", 17, BRASS)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.anchor_left = 0.30
	_feedback.anchor_top = 0.775
	_feedback.anchor_right = 0.88
	_feedback.anchor_bottom = 0.845
	_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback.visible = false
	add_child(_feedback)
	page.add_child(_rule())
	_hint = _label("", 17, MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_hint)


func _style(fill: Color, edge: Color, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(width)
	box.set_corner_radius_all(3)
	return box


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", BRASS)
	button.add_theme_stylebox_override("normal", _style(Color("27353d"), Color("4a5c61"), 1))
	button.add_theme_stylebox_override("hover", _style(Color("354950"), BRASS, 1))
	button.add_theme_stylebox_override("pressed", _style(Color("354950"), BRASS, 2))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, BRASS, 2))
	button.add_theme_constant_override("h_separation", 16)


func _margin(control: MarginContainer, amount: int) -> void:
	for side in ["left", "right", "top", "bottom"]:
		control.add_theme_constant_override("margin_" + side, amount)


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color("687a7a")
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _area_name() -> String:
	match _area:
		"records_office": return "CIVIC RECORDS OFFICE"
		"quay": return "LANTERN QUAY"
		_: return _area.replace("_", " ").to_upper()


func _select_tab(index: int) -> void:
	set_feedback("")
	_current_tab = posmod(index, TAB_NAMES.size())
	_render_tab()
	focus_current_page()

func focus_current_page() -> void:
	if _action_button != null:
		_action_button.grab_focus()
	else:
		_tab_buttons[_current_tab].grab_focus()


func _render_tab() -> void:
	for index in range(_roster.size()):
		_roster[index].add_theme_color_override("font_color", PROFILES.get_profile(_combat_profile_id).accent if index == _actor_index else INK)
	_scroll.scroll_vertical = 0
	for index in range(_tab_buttons.size()):
		_tab_buttons[index].text = ("▸  " if index == _current_tab else "    ") + "%02d   %s" % [index + 1, TAB_NAMES[index].to_upper()]
		_tab_buttons[index].add_theme_color_override("font_color", BRASS if index == _current_tab else INK)
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_action_button = null
	_actions.clear()
	_map_widget = null
	_heading.text = TAB_NAMES[_current_tab].to_upper()
	match _current_tab:
		0: _render_character()
		1: _render_equipment()
		2: _render_combat_style()
		3: _render_inventory()
		4: _render_map()
		5: _render_load()
		6: _render_save()


func _add_copy(text: String, color := MUTED, size := 19) -> Label:
	var copy := _label(text, size, color)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(copy)
	return copy


func _add_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	_content.add_child(row)
	var key := _label(label_text, 21, INK)
	key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(key)
	row.add_child(_label(value_text, 21, BRASS))
	_content.add_child(_rule())


func _signed(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)

func _select_actor(index: int) -> void:
	_actor_index = posmod(index, CATALOG.actors().size())
	_render_tab()
	_roster[_actor_index].grab_focus()

func _build() -> Dictionary:
	return CATALOG.build(_combat_profile_id, CATALOG.actors()[_actor_index].id)

func _preview_heading() -> void:
	_add_copy(CATALOG.actors()[_actor_index].name + " · " + _build().role, INK, 23)
	_add_copy("Build preview", MUTED, 16)


func _render_character() -> void:
	var profile := PROFILES.get_profile(_combat_profile_id)
	var actor: Dictionary = CATALOG.actors()[_actor_index]
	var build := _build()
	_heading.text = "PARTY · " + str(profile.name).to_upper()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_content.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = load("res://assets/ui/" + actor.portrait + "-portrait.png")
	portrait.custom_minimum_size = Vector2(170, 225)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)
	details.add_child(UI.label(actor.name, 26, INK, true))
	details.add_child(UI.label(build.role, 20, profile.accent))
	details.add_child(UI.label("Build preview", 16, MUTED))
	if actor.id == "player":
		var moral := int(_state.get("moral", 0))
		details.add_child(UI.label(str(_moral_definition.label).to_upper() + " " + _signed(moral), 19, profile.accent))
		var meter := ProgressBar.new()
		meter.min_value = _moral_definition.min
		meter.max_value = _moral_definition.max
		meter.value = moral
		meter.show_percentage = false
		meter.custom_minimum_size.y = 14
		meter.add_theme_stylebox_override("background", UI.style(Color("101b20"), MUTED))
		meter.add_theme_stylebox_override("fill", UI.style(profile.accent, profile.accent))
		details.add_child(meter)
		details.add_child(UI.label("Ivo affinity " + _signed(int(_state.get("affinity", {}).get("ivo", 0))), 17, MUTED))
	else:
		details.add_child(UI.label("Guest" if actor.id == "clerk" else "Companion", 17, MUTED))
		details.add_child(UI.label("Outlook · not established", 17, MUTED))
		if actor.id == "ivo":
			details.add_child(UI.label("Affinity " + _signed(int(_state.get("affinity", {}).get("ivo", 0))), 17, MUTED))
	var resources: Array[String] = []
	for key in build.resources:
		resources.append("%s %s" % [key, str(build.resources[key])])
	details.add_child(UI.label(" · ".join(resources), 17, INK))
	_add_copy("TRAINING  ·  " + " · ".join(build.skills), profile.accent, 18)
	_add_copy(build.loop, INK, 19)
	_add_copy("Tradeoff: " + build.weakness, MUTED, 18)
	_add_copy("Progression: " + build.progression, MUTED, 18)


func _render_equipment() -> void:
	var profile := PROFILES.get_profile(_combat_profile_id)
	_preview_heading()
	for gear in _build().gear:
		_add_kit_row(gear.slot, gear.name, gear.detail, profile.accent)
	_add_copy("Equipment preview · Read only", MUTED, 16)


func _add_kit_row(slot: String, item: String, detail: String, accent: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 54
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)
	var key := UI.label(slot, 18, MUTED)
	key.custom_minimum_size.x = 170
	row.add_child(key)
	var value := VBoxContainer.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	value.add_child(UI.label(item, 21, accent))
	value.add_child(UI.label(detail, 17, MUTED))

func _render_combat_style() -> void:
	var profile := PROFILES.get_profile(_combat_profile_id)
	_heading.text = str(profile.page).to_upper()
	_preview_heading()
	for ability in _build().abilities + CATALOG.profile(_combat_profile_id).get("common_actions", []):
		_add_copy(ability.name + " · " + ability.cost, profile.accent, 20)
		_add_copy(ability.source + " — " + ability.effect, MUTED, 17)
	_add_action("CHANGE COMBAT STYLE", false, true)
	_add_secondary_action("START NEW JOURNEY", func() -> void: new_game_requested.emit())
	_add_copy("Controls: " + CATALOG.profile(_combat_profile_id).hud, MUTED, 17)


func _render_inventory() -> void:
	_add_copy("CARRIED QUEST ITEMS", BRASS, 21)
	var flags: Dictionary = _state.get("flags", {})
	var carrying_pay := bool(flags.get("pay_recovered", false)) and not bool(flags.get("pay_returned", false))
	if carrying_pay:
		_add_copy("STOLEN PAYROLL", INK, 23)
		_add_copy("A pouch of coins and wage slips. Return it to the clerk in her office.", INK)
	if bool(flags.get("records_collected", false)):
		_add_copy("HARBOR HISTORY", INK, 23)
		_add_copy(CHAPTER.story().records, INK)
	elif not carrying_pay:
		_add_copy("No quest items carried.")
	_content.add_child(_rule())
	_add_copy("INVENTORY PREVIEW · " + CATALOG.profile(_combat_profile_id).name, BRASS, 20)
	_add_copy(CATALOG.profile(_combat_profile_id).inventory, INK, 19)
	_add_copy("Equipment changes are unavailable on this page.", MUTED, 17)


func _render_map() -> void:
	var map_script: Resource = load(MAP_SCRIPT_PATH)
	if not map_script is GDScript:
		_add_copy("The area map is unavailable.", BRASS)
		return
	_map_widget = map_script.new() as Control
	if _map_widget == null:
		_add_copy("The area map is unavailable.", BRASS)
		return
	var map_center := CenterContainer.new()
	map_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(map_center)
	map_center.add_child(_map_widget)
	_map_widget.call("set_map_state", _player_position, _area, _waypoint_id, _state.get("flags", {}))
	_map_widget.call("set_expanded", true)


func _render_load() -> void:
	_add_copy("Return to your last saved position and story state.")
	_add_action("LOAD JOURNEY", true)
	_add_copy("Loading replaces your current unsaved progress.", MUTED, 17)


func _render_save() -> void:
	_add_copy("Save your position, choices, and quest progress.")
	_add_action("SAVE JOURNEY", false)
	_add_copy("You can also save directly from exploration.", MUTED, 17)


func _add_action(caption: String, loading: bool, style := false) -> void:
	_action_button = Button.new()
	_action_button.text = caption
	_action_button.custom_minimum_size = Vector2(300, 64)
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_action_button.add_theme_font_size_override("font_size", 21)
	_style_button(_action_button)
	if style:
		_action_button.pressed.connect(func() -> void: combat_style_requested.emit())
	elif loading:
		_action_button.pressed.connect(func() -> void: load_requested.emit())
	else:
		_action_button.pressed.connect(func() -> void: save_requested.emit())
	_content.add_child(_action_button)
	_actions.append(_action_button)

func _add_secondary_action(caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(300, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_font_size_override("font_size", 18)
	_style_button(button)
	button.pressed.connect(callback)
	_content.add_child(button)
	_actions.append(button)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	input_observed.emit(event)
	if event.is_echo():
		return
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_scroll_velocity = event.axis_value
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		if absf(event.axis_value) < 0.25:
			_axis_held = false
		elif _axis_held:
			get_viewport().set_input_as_handled()
			return
		else:
			_axis_held = true
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_scroll.scroll_vertical += -260 if event.keycode == KEY_PAGEUP else 260
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_Q, KEY_E]:
		_select_actor(_actor_index + (-1 if event.keycode == KEY_Q else 1))
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y]:
		_select_actor(_actor_index + (-1 if event.button_index == JOY_BUTTON_X else 1))
	elif event.is_action_pressed("menu_toggle") or event.is_action_pressed("dialogue_back"):
		close_menu()
	elif event.is_action_pressed("menu_left"):
		_select_tab(_current_tab - 1)
	elif event.is_action_pressed("menu_right"):
		_select_tab(_current_tab + 1)
	elif event.is_action_pressed("dialogue_up") or event.is_action_pressed("dialogue_down"):
		var direction := -1 if event.is_action_pressed("dialogue_up") else 1
		if _actions.size() > 1:
			var index := _actions.find(get_viewport().gui_get_focus_owner())
			_actions[posmod(index + direction, _actions.size())].grab_focus()
		else:
			_scroll.scroll_vertical += direction * 90
	elif event.is_action_pressed("dialogue_confirm"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused in _actions:
			focused.pressed.emit()
		elif _action_button != null:
			_action_button.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
