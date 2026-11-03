extends Control
## Menu preview only. Catalog data is never applied to a journey here.
signal closed
signal accepted
signal trial_requested
const CHAPTER := preload("res://scripts/garden_chapter.gd")
const UI := preload("res://scripts/combat_theme.gd")
const PROFILES := preload("res://scripts/combat_profiles.gd")
const CATALOG := preload("res://scripts/party_catalog.gd")
const PAGES := ["Overview", "Character", "Equipment", "Abilities", "Party", "Inventory", "Map", "Journal", "Saves"]
var profile_id := "command"
var actor_index := 0
var page_index := 0
var _profile: Dictionary
var _study: Dictionary
var _tabs: Array[Button] = []
var _roster: Array[Button] = []
var _focusables: Array[Button] = []
var _portrait: TextureRect
var _identity: VBoxContainer
var _content: VBoxContainer
var _scroll: ScrollContainer
var _hint: Label
var _controller := false
var _axis_held := false
var _scroll_speed := 0.0
var _scroll_fraction := 0.0
var _closing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_profile = PROFILES.get_profile(profile_id)
	_study = CATALOG.profile(profile_id)
	_build_layout()
	_render_page()
	_tabs[0].grab_focus()

func _label(parent: Node, copy: String, size := 18, color := UI.INK, display := false) -> Label:
	var label := UI.label(copy, size, color, display)
	parent.add_child(label)
	return label

func _button(parent: Node, copy: String, callback: Callable) -> Button:
	var button := UI.button(copy, func() -> void: callback.call_deferred(), UI.BRASS)
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 17)
	parent.add_child(button)
	_focusables.append(button)
	return button

func _box(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UI.style(Color("0d1a1e"), Color("344448")))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = Color("080f11")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	layout.add_child(header)
	header.add_child(UI.wordmark())
	var title := _label(header, _profile.name + "  /  Menu preview", 26, UI.BRASS, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "← All styles", _close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	layout.add_child(tabs)
	for index in range(PAGES.size()):
		var tab := _button(tabs, PAGES[index], select_page.bind(index))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs.append(tab)
	var roster := HBoxContainer.new()
	roster.add_theme_constant_override("separation", 10)
	layout.add_child(roster)
	for index in range(CATALOG.actors().size()):
		var actor: Dictionary = CATALOG.actors()[index]
		var button := _button(roster, actor.short, select_actor.bind(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 64
		button.icon = load("res://assets/ui/" + actor.portrait + "-portrait.png")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.tooltip_text = CATALOG.build(profile_id, actor.id).role
		_roster.append(button)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	var sidebar := _box(body)
	(sidebar.get_parent() as Control).size_flags_horizontal = Control.SIZE_FILL
	(sidebar.get_parent() as Control).custom_minimum_size.x = 254
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(220, 174)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sidebar.add_child(_portrait)
	_identity = VBoxContainer.new()
	_identity.add_theme_constant_override("separation", 8)
	sidebar.add_child(_identity)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 14)
	_scroll.add_child(_content)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	layout.add_child(footer)
	_hint = _label(footer, "", 16, UI.MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var choose := _button(footer, "Choose this style  →", _accept)
	choose.add_theme_stylebox_override("normal", UI.style(UI.BRASS, UI.BRASS))
	choose.add_theme_stylebox_override("hover", UI.style(UI.BRASS.lightened(0.12), UI.INK))
	choose.add_theme_stylebox_override("pressed", UI.style(UI.BRASS.darkened(0.15), UI.BRASS))
	choose.add_theme_stylebox_override("focus", UI.style(Color.TRANSPARENT, UI.INK, 2))
	for color in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		choose.add_theme_color_override(color, Color("080f11"))
	_update_hints()

func select_page(index: int) -> void:
	page_index = posmod(index, PAGES.size())
	_scroll.scroll_vertical = 0
	_render_page()
	_tabs[page_index].grab_focus()

func select_actor(index: int) -> void:
	actor_index = posmod(index, CATALOG.actors().size())
	_scroll.scroll_vertical = 0
	_render_page()
	_roster[actor_index].grab_focus()

func _clear(parent: Node) -> void:
	for button in _focusables.duplicate():
		if is_instance_valid(button) and parent.is_ancestor_of(button):
			_focusables.erase(button)
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _render_page() -> void:
	_clear(_content)
	_clear(_identity)
	var actor: Dictionary = CATALOG.actors()[actor_index]
	var build := CATALOG.build(profile_id, actor.id)
	_portrait.texture = load("res://assets/ui/" + actor.portrait + "-portrait.png")
	_label(_identity, actor.short, 28, UI.INK, true)
	_label(_identity, build.role, 18, UI.BRASS)
	if actor.id == "player":
		_label(_identity, "Mercy · Neutral", 17, UI.INK)
		var meter := ProgressBar.new()
		meter.min_value = -5
		meter.max_value = 5
		meter.value = 0
		meter.show_percentage = false
		meter.custom_minimum_size.y = 10
		meter.add_theme_stylebox_override("fill", UI.style(UI.BRASS, UI.BRASS))
		_identity.add_child(meter)
		_label(_identity, "Ruthless                    Merciful", 14, UI.MUTED)
	else:
		_label(_identity, "Outlook · Unknown\nRelationship · Not established", 17, UI.MUTED)
	for index in range(_tabs.size()):
		_mark(_tabs[index], index == page_index)
	for index in range(_roster.size()):
		_mark(_roster[index], index == actor_index)
	var heading: String = _profile.page if page_index == 3 else PAGES[page_index]
	_label(_content, heading, 30, UI.INK, true)
	match page_index:
		0: _overview(build)
		1: _character(build)
		2: _equipment(build)
		3: _abilities(build)
		4: _party()
		5: _inventory(build)
		6: _map()
		7: _journal()
		8: _saves()

func _mark(button: Button, selected: bool) -> void:
	var fill := Color("0d1a1e").lerp(UI.BRASS, 0.15) if selected else Color("0d1a1e")
	button.add_theme_stylebox_override("normal", UI.style(fill, UI.BRASS if selected else Color("344448"), 2 if selected else 1))

func _card(parent: Node, title: String, copy: String) -> void:
	var box := _box(parent)
	_label(box, title, 19, UI.BRASS)
	_label(box, copy, 18, UI.MUTED)

func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_content.add_child(grid)
	return grid

func _overview(build: Dictionary) -> void:
	_label(_content, _profile.description, 21)
	if profile_id in ["command", "flow", "vanguard"]:
		_chapter_preview()
	var grid := _grid()
	_card(grid, "COMBAT & TIMING", _profile.reference + "\n" + _profile.tagline)
	_card(grid, "PARTY & CONTROL", _profile.party)
	_card(grid, "HUD & INPUT", _study.hud)
	_card(grid, "EQUIPMENT & INVENTORY", _study.inventory)
	_card(grid, "ROLES & ARCHETYPES", _study.coverage)
	_card(grid, "SKILLS & PROGRESSION", build.progression)
	if profile_id not in ["command", "flow", "vanguard"]:
		_label(_content, "Coming soon", 16, UI.MUTED)

func _chapter_preview() -> void:
	var play := _button(_content, "Play The Quay Robbery  →", func() -> void: trial_requested.emit())
	# Keep the footer's Choose action last in the established focus sequence.
	_focusables.erase(play)
	_focusables.insert(_focusables.size() - 1, play)
	var picture := TextureRect.new()
	picture.name = "CombatPreview"
	picture.custom_minimum_size.y = 300
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(picture)
	var sample := SubViewport.new()
	sample.size = Vector2i(1280, 800)
	sample.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sample.gui_disable_input = true
	picture.add_child(sample)
	picture.texture = sample.get_texture()
	var trial = load("res://scripts/%s_trial.gd" % profile_id).new()
	trial.preview_mode = true
	sample.add_child(trial)

	_label(_content, _profile.name + " · " + _profile.tagline, 16, UI.MUTED)

func _character(build: Dictionary) -> void:
	var grid := _grid()
	var resources := PackedStringArray()
	for key in build.resources:
		resources.append("%s  %s" % [key, build.resources[key]])
	_card(grid, "RESOURCES", "\n".join(resources))
	_card(grid, "TRAINING", "\n".join(build.skills))
	_card(grid, "PLAY PATTERN", build.loop)
	_card(grid, "TRADEOFF", build.weakness)
	_card(_content, "PROGRESSION", build.progression)

func _equipment(build: Dictionary) -> void:
	var grid := _grid()
	for gear in build.gear:
		var box := _box(grid)
		_label(box, str(gear.slot).to_upper(), 15, UI.BRASS)
		_label(box, gear.name, 24, UI.INK, true)
		_label(box, gear.detail, 17, UI.MUTED)

func _abilities(build: Dictionary) -> void:
	for ability in build.abilities + _study.get("common_actions", []):
		var box := _box(_content)
		_label(box, ability.name + "  ·  " + ability.cost, 20, UI.BRASS)
		_label(box, ability.effect, 18)
		_label(box, "Source: " + ability.source, 16, UI.MUTED)

func _party() -> void:
	_label(_content, _profile.party, 19, UI.BRASS)
	var grid := _grid()
	for actor in CATALOG.actors():
		var build := CATALOG.build(profile_id, actor.id)
		_card(grid, actor.short + " · " + build.role, build.loop + "\n" + build.weakness)

func _inventory(build: Dictionary) -> void:
	_card(_content, "CARRYING & ORGANIZATION", _study.inventory)
	_card(_content, "LOADOUT", "\n".join(build.gear.map(func(gear: Dictionary) -> String: return gear.name)))

func _map() -> void:
	var picture := TextureRect.new()
	picture.texture = preload("res://assets/ui/lantern-garden.png")
	picture.custom_minimum_size.y = 250
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_content.add_child(picture)
	_card(_content, "LANTERN GARDEN", CHAPTER.story().map_note)

func _journal() -> void:
	_card(_content, "THE QUAY ROBBERY", CHAPTER.story().premise)
	_card(_content, "OBJECTIVE", CHAPTER.story().objective)

func _saves() -> void:
	_card(_content, "YOUR JOURNEY", "Save or load from the title menu or journal.")

func _update_hints() -> void:
	_hint.text = "LB/RB Tabs · Ⓨ Member · R Scroll · Ⓐ Select · Ⓑ Back" if _controller else "Q/E Tabs · Tab Focus · PgUp/PgDn Scroll · Enter Select · Esc Back"

func _close() -> void:
	if not _closing:
		_closing = true
		closed.emit()

func _accept() -> void:
	if not _closing:
		_closing = true
		accepted.emit()

func _process(delta: float) -> void:
	_scroll_fraction += _scroll_speed * delta
	var pixels := int(_scroll_fraction)
	_scroll.scroll_vertical += pixels
	_scroll_fraction -= pixels

func _input(event: InputEvent) -> void:
	if _closing or not is_visible_in_tree():
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		_controller = Input.get_connected_joypads().has(event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		_controller = false
	_update_hints()
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
		_scroll_speed = event.axis_value * 600.0 if absf(event.axis_value) > 0.2 else 0.0
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		if absf(event.axis_value) < 0.25:
			_axis_held = false
		elif _axis_held:
			get_viewport().set_input_as_handled()
			return
		else:
			_axis_held = true
	if event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dialogue_back"):
		_close.call_deferred()
	elif (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]) or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_Q, KEY_E]):
		var previous: bool = (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_LEFT_SHOULDER) or (event is InputEventKey and event.physical_keycode == KEY_Q)
		select_page.call_deferred(page_index + (-1 if previous else 1))
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		select_actor.call_deferred(actor_index + 1)
	elif event is InputEventKey and event.pressed and event.physical_keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_scroll.scroll_vertical += -250 if event.physical_keycode == KEY_PAGEUP else 250
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_TAB:
		# Keep keyboard focus inside this modal; the picker is still underneath.
		var current := _focusables.find(get_viewport().gui_get_focus_owner())
		_focusables[posmod(current + (-1 if event.shift_pressed else 1), _focusables.size())].grab_focus()
	elif event.is_action_pressed("dialogue_confirm"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused in _focusables:
			focused.pressed.emit()
	elif event.is_action_pressed("dialogue_up") or event.is_action_pressed("dialogue_down") or event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		var step := -1 if event.is_action_pressed("dialogue_up") or event.is_action_pressed("menu_left") else 1
		var current := _focusables.find(get_viewport().gui_get_focus_owner())
		_focusables[posmod(current + step, _focusables.size())].grab_focus()
	elif event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
