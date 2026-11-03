extends Control
## Modal presentation only; the launcher owns journeys and saves.
signal new_game(profile_id: String)
signal load_game(profile_id: String)
signal profile_selected(profile_id: String)
signal cancelled
signal trial_requested
const PROFILES := preload("res://scripts/combat_profiles.gd")
const UI := preload("res://scripts/combat_theme.gd")
const INSPECTOR := preload("res://scripts/combat_style_inspector.gd")
var _mode := "title"
var _purpose := "new"
var _selected := PROFILES.DEFAULT_ID
var _load_available := false
var _in_game := false
var _message := ""
var _controller := false
var _axis_held := false
var _buttons: Array[Button] = []
var _detail: VBoxContainer
var _list: VBoxContainer
var _footer: Label
var _primary: Button
var _cards: Array[Button] = []
var _inspect: Button
var _inspector: Control
var _chapter_label: Label
var _body: HBoxContainer
var _art_border: Panel
var _scroll: ScrollContainer
const BACKDROP := "res://assets/ui/lantern-garden.png"
const BACKGROUND := Color("080f11")
const LINE := Color("344448")
const CARD_COPY := {
	"command": "Pause, queue, act", "flow": "Melee, magic, styles",
	"vanguard": "Aim, cover, command", "tactics": "Initiative & reactions",
	"momentum": "Action builds commands", "orders": "Plan, then resolve",
	"oathbound": "Steel, spells & tactics", "confluence": "Live time, linked arts",
	"cadence": "Ready, choose, resolve"
}
const GEAR_COPY := {
	"command": "Weapons, armor & powers", "flow": "Styles, amulets & charms",
	"vanguard": "Firearms, shields & tech", "tactics": "Gear & prepared spells",
	"momentum": "Weapons, sockets & commands", "orders": "Tactical kits & gadgets",
	"oathbound": "Arms, armor & spellcraft", "confluence": "Arms, charms & linked arts",
	"cadence": "Relics, roles & learned magic"
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func open_title(load_available: bool, message := "", saved_profile := "command") -> void:
	_load_available = load_available
	_selected = saved_profile if PROFILES.is_valid(saved_profile) else PROFILES.DEFAULT_ID
	_in_game = false
	_mode = "title"
	_message = message
	show()
	_render()

func open_picker(selected: String, load_available: bool, message := "", purpose := "new", in_game := false) -> void:
	_selected = selected if PROFILES.is_valid(selected) else PROFILES.DEFAULT_ID
	_load_available = load_available
	_purpose = purpose
	_in_game = in_game
	_message = message
	_mode = "picker"
	show()
	_render()

func open_style_picker(selected: String) -> void:
	open_picker(selected, false, "", "style", true)

func close_frontend() -> void:
	hide()

func show_error(message: String) -> void:
	_message = message
	_render()

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _add_button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := UI.button(caption, func() -> void: callback.call_deferred())
	parent.add_child(button)
	_buttons.append(button)
	return button

func _render() -> void:
	_clear(self)
	_inspector = null
	_buttons.clear()
	_cards.clear()
	_primary = null
	_inspect = null
	_art_border = null
	_scroll = null
	var shade := ColorRect.new()
	shade.color = BACKGROUND
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28 if side in ["top", "bottom"] else 32)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 18)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var brand := UI.wordmark()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	_chapter_label = UI.label("LANTERN QUAY\nThe Quay Robbery", 16, UI.MUTED)
	_chapter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_chapter_label)
	page.add_child(_rule())
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 32)
	page.add_child(_body)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	_body.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 10)
	_body.add_child(_detail)
	page.add_child(_rule())
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 20)
	page.add_child(footer_row)
	_footer = UI.label("", 17, UI.MUTED)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(_footer)
	var status := UI.label("", 16, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer_row.add_child(status)
	match _mode:
		"title": _render_title()
		"confirm": _render_confirmation()
		_: _render_picker()
	_update_hints()
	var selection := _selected
	for button in _buttons:
		if not button.disabled:
			button.grab_focus()
			break
	if _mode == "picker":
		_buttons[PROFILES.ids().find(selection)].grab_focus()

func _rule() -> ColorRect:
	var line := ColorRect.new()
	line.color = LINE
	line.custom_minimum_size.y = 1
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _space(parent: Node, height := 0, expand := false) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(space)

func _illustration(parent: Node, height: int, title := "The Quay Robbery", subtitle := "Recover the stolen payroll.") -> void:
	var art := Control.new()
	art.custom_minimum_size.y = height
	art.clip_contents = true
	parent.add_child(art)
	var picture := TextureRect.new()
	picture.texture = load(BACKDROP)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(picture)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.025, 0.045, 0.055, 0.0))
	ramp.set_color(1, Color(0.025, 0.045, 0.055, 0.96))
	var gradient := GradientTexture2D.new()
	gradient.gradient = ramp
	gradient.fill_from = Vector2(0, 0.25)
	gradient.fill_to = Vector2(0, 1)
	var veil := TextureRect.new()
	veil.texture = gradient
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(veil)
	_art_border = Panel.new()
	_art_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_border.add_theme_stylebox_override("panel", UI.style(Color.TRANSPARENT, LINE))
	_art_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(_art_border)
	var caption := VBoxContainer.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 22
	caption.offset_right = -22
	caption.offset_top = -83
	caption.offset_bottom = -18
	caption.add_theme_constant_override("separation", 4)
	caption.add_child(UI.label(title, 30, UI.INK, true))
	caption.add_child(UI.label(subtitle, 18, UI.MUTED))
	art.add_child(caption)

func _style_primary(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", UI.style(accent, accent))
	button.add_theme_stylebox_override("hover", UI.style(accent.lightened(0.12), UI.INK))
	button.add_theme_stylebox_override("pressed", UI.style(accent.darkened(0.15), accent))
	button.add_theme_stylebox_override("focus", UI.style(Color.TRANSPARENT, UI.INK, 2))
	button.add_theme_color_override("font_color", BACKGROUND)
	button.add_theme_color_override("font_focus_color", BACKGROUND)
	button.add_theme_color_override("font_hover_color", BACKGROUND)
	button.add_theme_color_override("font_pressed_color", BACKGROUND)

func _render_title() -> void:
	_space(_list, 40)
	_list.add_child(UI.label("LANTERN QUAY", 17, UI.BRASS))
	_list.add_child(UI.label("Mara’s pay\nhas been stolen.", 50, UI.INK, true))
	_list.add_child(UI.label("Ivo has the thief cornered in Lantern Garden. Help Mara get her money back.", 22, UI.MUTED))
	_space(_list, 20)
	var start := _add_button(_list, "New game   →", func() -> void: open_picker(_selected, _load_available, "", "new"))
	start.custom_minimum_size = Vector2(360, 60)
	start.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_primary(start, UI.BRASS)
	var load_button := _add_button(_list, "Load game" if _load_available else "Load game  ·  No saved journey", func() -> void: open_picker(_selected, true, "", "load"))
	load_button.custom_minimum_size = Vector2(360, 60)
	load_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	load_button.disabled = not _load_available
	var trial := _add_button(_list, "The Quay Robbery   →", func() -> void: trial_requested.emit())
	trial.custom_minimum_size = Vector2(360, 54)
	trial.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_add_button(_list, "Audio", func() -> void: preload("res://scripts/game_audio.gd").ensure(self).open_settings())
	_space(_list, 8)
	_space(_detail, 12)
	_illustration(_detail, 400, "Beyond the harbor gate", "Lantern Garden")
	_detail.add_child(UI.label("THE QUAY ROBBERY", 16, UI.BRASS))
	_detail.add_child(UI.label("The thief brought two mechanical guards. Mara can mend wounds; Ivo will help you hold them off.", 23, UI.INK, true))
	if not _message.is_empty():
		_detail.add_child(UI.label(_message, 18, Color("f1b69a")))

func _render_picker() -> void:
	_list.add_theme_constant_override("separation", 8)
	_list.size_flags_stretch_ratio = 1.55
	_chapter_label.text = {"new": "NEW JOURNEY", "load": "LOAD JOURNEY", "style": "YOUR JOURNEY"}[_purpose] + "\nCombat & equipment styles"
	_list.add_child(UI.label("COMBAT STYLES", 16, UI.BRASS))
	_list.add_child(UI.label("Choose how you fight.", 40, UI.INK, true))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_list.add_child(_scroll)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(grid)
	for id in PROFILES.ids():
		var profile := PROFILES.get_profile(id)
		var button := _add_button(grid, "", _focus_preview.bind(id))
		_cards.append(button)
		button.custom_minimum_size = Vector2(0, 134)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = profile.name + " · " + profile.tagline
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 18
		content.offset_right = -18
		content.offset_top = 10
		content.offset_bottom = -10
		content.add_theme_constant_override("separation", 2)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(content)
		var number := "%02d" % _cards.size()
		for label in [UI.label(number, 14, UI.MUTED), UI.label(profile.name, 30, UI.INK, true), UI.label(CARD_COPY[id], 17, UI.MUTED)]:
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(label)
		if _cards.size() >= 4:
			var badge := PanelContainer.new()
			badge.name = "ComingSoon"
			badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			badge.offset_left = -112
			badge.offset_right = -10
			badge.offset_top = 8
			badge.offset_bottom = 31
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var badge_style := UI.style(Color("233237"), Color("526163"))
			badge_style.set_corner_radius_all(12)
			badge_style.content_margin_left = 8
			badge_style.content_margin_right = 8
			badge_style.content_margin_top = 2
			badge_style.content_margin_bottom = 2
			badge.add_theme_stylebox_override("panel", badge_style)
			var caption := UI.label("Coming soon", 12, UI.MUTED)
			caption.autowrap_mode = TextServer.AUTOWRAP_OFF
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(caption)
			button.add_child(badge)
		button.focus_entered.connect(_select_profile.bind(id))
	_list.add_child(UI.label("Choose controls, party commands and equipment rules.", 17, UI.MUTED))
	# Keep the illustration and actions stable while focus updates the details.
	var right := _detail
	_illustration(right, 176)
	_detail = VBoxContainer.new()
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	right.add_child(_detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	right.add_child(actions)
	var captions := {"new": "Start journey   →", "load": "Load journey   →", "style": "Apply style   →"}
	_primary = _add_button(actions, captions[_purpose], _accept)
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspect = _add_button(actions, "Preview menus   →", _open_inspector)
	_inspect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back := _add_button(_list, "← Back", _back)
	back.custom_minimum_size = Vector2(120, 36)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_stylebox_override("normal", UI.style(Color.TRANSPARENT, Color.TRANSPARENT))
	_render_detail()

func _select_profile(id: String) -> void:
	_selected = id
	_render_detail()
	_refresh_cards()
	if _scroll != null:
		_scroll.ensure_control_visible.call_deferred(_cards[PROFILES.ids().find(id)])

func _focus_preview(id: String) -> void:
	_select_profile(id)
	_inspect.grab_focus()

func _render_detail() -> void:
	_clear(_detail)
	var profile := PROFILES.get_profile(_selected)
	if _art_border != null:
		_art_border.add_theme_stylebox_override("panel", UI.style(Color.TRANSPARENT, LINE))
	if _inspect != null:
		_style_primary(_inspect, UI.BRASS)
	_detail.add_child(UI.label(str(profile.reference).to_upper(), 16, UI.BRASS))
	_detail.add_child(UI.label(profile.name, 36, UI.INK, true))
	_detail.add_child(UI.label(profile.description, 20, UI.MUTED))
	_space(_detail, 4)
	var summaries := HBoxContainer.new()
	summaries.add_theme_constant_override("separation", 20)
	_detail.add_child(summaries)
	for pair in [["PARTY", profile.party], ["EQUIPMENT", GEAR_COPY[_selected]]]:
		var summary := VBoxContainer.new()
		summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summaries.add_child(summary)
		summary.add_child(UI.label(pair[0], 16, UI.BRASS))
		summary.add_child(UI.label(pair[1], 20))
	_space(_detail, 0, true)
	_detail.add_child(UI.label("You can change styles in the Ledger.", 17, UI.MUTED))
	if not _message.is_empty():
		_detail.add_child(UI.label(_message, 18, Color("f1b69a")))

func _open_inspector() -> void:
	if is_instance_valid(_inspector):
		return
	_inspector = INSPECTOR.new()
	_inspector.profile_id = _selected
	_inspector._controller = _controller
	_inspector.closed.connect(_close_inspector)
	_inspector.trial_requested.connect(func() -> void: trial_requested.emit())
	_inspector.accepted.connect(func() -> void:
		_close_inspector()
		_accept())
	add_child(_inspector)

func _close_inspector() -> void:
	if is_instance_valid(_inspector):
		remove_child(_inspector)
		_inspector.queue_free()
	_inspector = null
	_inspect.grab_focus()

func _refresh_cards() -> void:
	# Selection moves the highlight; it never recolors the surrounding menu.
	var accent: Color = UI.BRASS
	for index in range(_cards.size()):
		var card := _cards[index]
		var selected := PROFILES.ids()[index] == _selected
		var fill := BACKGROUND.lerp(accent, 0.17) if selected else Color("0d1a1e")
		var normal := UI.style(fill, accent if selected else LINE)
		normal.border_width_left = 5 if selected else 1
		card.add_theme_stylebox_override("normal", normal)
		card.add_theme_stylebox_override("hover", UI.style(fill.lightened(0.04), accent))
		card.add_theme_stylebox_override("focus", UI.style(Color.TRANSPARENT, accent, 2))
		var content := card.get_child(0) as VBoxContainer
		(content.get_child(0) as Label).add_theme_color_override("font_color", accent)

func _accept() -> void:
	match _purpose:
		"style": profile_selected.emit(_selected)
		"load": load_game.emit(_selected)
		"new":
			if _in_game:
				_mode = "confirm"
				_render()
			else:
				new_game.emit(_selected)

func _render_confirmation() -> void:
	_list.add_child(UI.label("Leave this journey?", 34, UI.BRASS, true))
	_list.add_child(UI.label("Unsaved progress will be lost. Your existing save will remain until you choose to save again.", 22))
	_add_button(_list, "KEEP PLAYING", func() -> void: cancelled.emit())
	_add_button(_list, "START NEW JOURNEY", func() -> void: new_game.emit(_selected))
	_render_detail()

func _back() -> void:
	if _mode == "confirm":
		_mode = "picker"
		_render()
	elif _in_game:
		cancelled.emit()
	elif _mode != "title":
		open_title(_load_available, "", _selected)

func _update_hints() -> void:
	_footer.text = "D-pad  Browse     Ⓐ  Select     Ⓑ  Back" if _controller else "↑ ↓ ← →  Browse     Enter  Select     Esc  Back"

func _input(event: InputEvent) -> void:
	if not visible or is_instance_valid(_inspector):
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		_controller = Input.get_connected_joypads().has(event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		_controller = false
	_update_hints()
	if event.is_echo():
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
	if event.is_action_pressed("dialogue_back"):
		_back.call_deferred()
	elif event.is_action_pressed("dialogue_confirm"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused in _buttons and not focused.disabled:
			focused.pressed.emit()
	elif event.is_action_pressed("dialogue_up") or event.is_action_pressed("dialogue_down") or event.is_action_pressed("menu_left") or event.is_action_pressed("menu_right"):
		var direction := -1 if event.is_action_pressed("dialogue_up") or event.is_action_pressed("menu_left") else 1
		var current := _buttons.find(get_viewport().gui_get_focus_owner())
		if _mode == "picker" and current >= 0 and current < PROFILES.ids().size() and (event.is_action_pressed("dialogue_up") or event.is_action_pressed("dialogue_down")):
			# Follow the three-column card grid, then continue into its actions.
			var target := clampi(current + direction * 3, 0, PROFILES.ids().size())
			_buttons[target].grab_focus()
			get_viewport().set_input_as_handled()
			return
		for step in range(_buttons.size()):
			current = posmod(current + direction, _buttons.size())
			if not _buttons[current].disabled:
				_buttons[current].grab_focus()
				break
	elif event is InputEventMouse:
		return
	get_viewport().set_input_as_handled()
