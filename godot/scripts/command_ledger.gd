extends Control
## CommandView projection only. The controller owns pauses, confirmations, targeting and persistence.
signal requested(action: Dictionary)
const UI := preload("res://scripts/combat_theme.gd")
const TABS := ["Character", "Equipment", "Powers", "Party", "Inventory", "Journal", "Save"]
const PORTRAITS := {"player": "player", "mara": "mara", "clerk": "clerk", "ivo": "ivo"}
var interaction_enabled := true
var _view: Dictionary = {}
var _tab := 0
var _slot := ""
var _item := ""
var _preset := ""
var _filter := "all"
var _container := "all"
var _search := ""
var _stamp := ""
var _buttons: Dictionary = {}
var _heading: Label
var _context: Label
var _sidebar: VBoxContainer
var _page: VBoxContainer
var _scroll: ScrollContainer
var _tabs: Array[Button] = []
var _built := false
var _slot_icons: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()

func _build() -> void:
	if _built:
		return
	_built = true
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.03, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.style(Color("12272c"), UI.BRASS))
	margin.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_heading = _label(header, "Party ledger", 26, UI.BRASS, true)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hints := preload("res://scripts/input_hints.gd").attach(self)
	var close_button := _button(header, "close", "Close", {"kind": "ui.close_ledger"})
	close_button.custom_minimum_size.x = 180
	hints.bind(close_button, "Close · Esc", "Close · B")
	_context = _label(column, "", 16, UI.MUTED)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	column.add_child(tabs)
	for index in range(TABS.size()):
		var button := _button(tabs, "tab:" + TABS[index], TABS[index])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(index))
		_tabs.append(button)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 240
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.follow_focus = true
	body.add_child(side_scroll)
	_sidebar = VBoxContainer.new()
	_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar.add_theme_constant_override("separation", 8)
	side_scroll.add_child(_sidebar)
	var separator := VSeparator.new()
	body.add_child(separator)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	body.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 9)
	_scroll.add_child(_page)
	var hint := _label(column, "", 14, UI.MUTED)
	hints.bind(hint, "Q/E Tabs  ·  F1–F3 Inspect party  ·  Tab Focus  ·  Enter Choose  ·  Esc Back", "LB/RB Tabs  ·  L3/R3 Inspect party  ·  D-pad Focus  ·  A Choose  ·  B Back")

func open(view: Dictionary) -> void:
	_build()
	show()
	apply_view(view, true)
	_tabs[_tab].grab_focus()

func close() -> void:
	hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()

func apply_view(view: Dictionary, force := false) -> void:
	if _dict(_view.get("party")).get("inspected_id") != _dict(view.get("party")).get("inspected_id"):
		_slot = ""
		_item = ""
		_preset = ""
	_view = view.duplicate(true)
	if not _built:
		return
	var stamp := JSON.stringify([view.get("schema"), view.get("party"), view.get("actors"), view.get("equipment"), view.get("inventory"), view.get("progression"), view.get("actions"), view.get("world_actions"), view.get("capabilities"), view.get("logs"), view.get("encounter"), _dict(view.get("session")).get("phase")])
	if stamp == _stamp and not force:
		return
	_stamp = stamp
	_render()

## Called only by the controller when this is the top input context. Back belongs to the controller.
func handle_input(event: InputEvent) -> bool:
	if not visible or not interaction_enabled or not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_select_tab(posmod(_tab + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1), TABS.size()))
			return true
		if event.button_index == JOY_BUTTON_LEFT_STICK or event.button_index == JOY_BUTTON_RIGHT_STICK:
			_inspect_cycle(-1 if event.button_index == JOY_BUTTON_LEFT_STICK else 1)
			return true
	if event is InputEventKey:
		if event.ctrl_pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			_select_tab(posmod(_tab + (-1 if event.keycode == KEY_PAGEUP else 1), TABS.size()))
			return true
		var focus := get_viewport().gui_get_focus_owner()
		if not focus is LineEdit and event.keycode in [KEY_BRACKETLEFT, KEY_BRACKETRIGHT]:
			_inspect_cycle(-1 if event.keycode == KEY_BRACKETLEFT else 1)
			return true
	return false

func _inspect_cycle(delta: int) -> void:
	var party := _dict(_view.get("party"))
	var ids: Array = party.get("roster_ids", [])
	if ids.is_empty():
		return
	var index := ids.find(party.get("inspected_id"))
	_request({"kind": "party.inspect", "actor_id": ids[posmod(index + delta, ids.size())]})

func _request(action: Dictionary) -> void:
	if visible and interaction_enabled and not action.is_empty():
		requested.emit(action.duplicate(true))

func _preview(action: Dictionary) -> void:
	_request({"kind": "ui.preview", "action": action})

func _select_tab(index: int) -> void:
	if not interaction_enabled:
		return
	_tab = clampi(index, 0, TABS.size() - 1)
	_render()
	_scroll.scroll_vertical = 0
	_tabs[_tab].grab_focus()

func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _array(value: Variant) -> Array:
	return value if value is Array else []

func _name(value: Variant) -> String:
	return str(value).replace("_", " ").capitalize() if value != null else "Unknown"

func _number(value: Variant) -> String:
	return str(value) if value != null else "Unknown"

func _reasons(value: Variant) -> String:
	var lines := PackedStringArray()
	for reason in _array(value):
		var copy := str(_dict(reason).get("message", "Unavailable"))
		var display := {"instance already equipped by another actor": "Equipped by another party member. Unequip it first.", "Equipment training is missing": "Requires equipment training."}
		lines.append(str(display.get(copy, copy)))
	return "\n".join(lines)

func _actor(id: String) -> Dictionary:
	for entry in _array(_view.get("actors")):
		if str(entry.get("id", "")) == id:
			return entry
	return {}

func _inspected() -> Dictionary:
	return _actor(str(_dict(_view.get("party")).get("inspected_id", "")))

func _owned_item(id: String) -> Dictionary:
	for entry in _array(_dict(_view.get("inventory")).get("items")):
		if str(entry.get("id", "")) == id:
			return entry
	return {}

func _label(parent: Node, copy: String, size := 17, color := UI.INK, display := false) -> Label:
	var label := UI.label(copy, size, color, display)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, key: String, caption: String, action: Dictionary = {}) -> Button:
	var button := UI.button(caption, func() -> void: _request(action))
	button.custom_minimum_size.y = 40
	button.add_theme_font_size_override("font_size", 17)
	button.set_meta("ledger_key", key)
	button.clip_text = true
	button.tooltip_text = caption
	parent.add_child(button)
	_buttons[key] = button
	return button

func _section(copy: String) -> void:
	_label(_page, copy, 22, UI.BRASS, true)

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _render() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var key := str(focus.get_meta("ledger_key", "")) if focus != null and is_ancestor_of(focus) else ""
	var scroll := _scroll.scroll_vertical
	_clear(_sidebar)
	_clear(_page)
	for old_key in _buttons.keys():
		if not is_instance_valid(_buttons[old_key]) or not is_ancestor_of(_buttons[old_key]):
			_buttons.erase(old_key)
	for index in range(_tabs.size()):
		_tabs[index].add_theme_color_override("font_color", UI.BRASS if index == _tab else UI.MUTED)
	if _view.get("schema") != "command.view/v1":
		_context.text = "Waiting for the current Command session."
		_label(_page, "No character data has been received.")
		return
	var actor := _inspected()
	var recipient := _actor(str(_view.party.recipient_id))
	_heading.text = "Party ledger · " + str(actor.get("name", "Party"))
	_context.text = "Inspecting %s  ·  Orders remain with %s  ·  %s" % [actor.get("name", "Unknown"), recipient.get("name", "Unknown"), _name(_view.session.phase)]
	_render_sidebar(actor)
	match _tab:
		0: _character(actor)
		1: _equipment(actor)
		2: _powers(actor)
		3: _party(actor)
		4: _inventory(actor)
		5: _journal()
		6: _save()
	_scroll.set_deferred("scroll_vertical", scroll)
	_wire_focus()
	var restored := _focus_control(key)
	if restored != null:
		restored.grab_focus()

func _render_sidebar(actor: Dictionary) -> void:
	var id := str(actor.get("id", ""))
	if PORTRAITS.has(id):
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/ui/%s-portrait.png" % PORTRAITS[id])
		portrait.custom_minimum_size = Vector2(210, 170)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_sidebar.add_child(portrait)
	_label(_sidebar, str(actor.get("name", "Unknown")), 23, UI.BRASS, true)
	_label(_sidebar, _name(actor.get("roster_status")) + " · " + _name(actor.get("body")), 16, UI.MUTED)
	_label(_sidebar, "Mercy · Neutral", 18, UI.BRASS)
	var stats := _dict(actor.get("stats"))
	_label(_sidebar, "Level " + _number(stats.get("level")), 17)
	for pair in [["health", "Health"], ["focus", "Focus"], ["battery", "Tool charges"]]:
		var pool := _dict(actor.get(pair[0]))
		if not pool.is_empty() and int(pool.get("maximum", 0)) > 0:
			_label(_sidebar, "%s  %s / %s" % [pair[1], _number(pool.get("current")), _number(pool.get("maximum"))], 16)
			if int(pool.get("reserved", 0)) > 0:
				_label(_sidebar, "%s reserved · %s free" % [_number(pool.get("reserved")), _number(pool.get("free"))], 16, UI.MUTED)
	_label(_sidebar, "Inspect party", 18, UI.BRASS, true)
	var party_grid := GridContainer.new()
	party_grid.columns = 2
	party_grid.add_theme_constant_override("h_separation", 6)
	party_grid.add_theme_constant_override("v_separation", 6)
	_sidebar.add_child(party_grid)
	for member_id in _array(_dict(_view.get("party")).get("roster_ids")):
		var member := _actor(str(member_id))
		var button := _button(party_grid, "inspect:" + str(member_id), str(member.get("name", member_id)), {"kind": "party.inspect", "actor_id": member_id})
		button.custom_minimum_size = Vector2(112, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.tooltip_text = str(member.get("name", member_id)) + " · " + _name(member.get("roster_status"))
		if str(member_id) == id:
			button.add_theme_color_override("font_color", UI.BRASS)

func _character(actor: Dictionary) -> void:
	var p := _dict(_view.get("progression"))
	if p.get("actor_id") != actor.get("id"):
		_label(_page, "Waiting for this character's progression.")
		return
	_section("Character development")
	var classes := PackedStringArray()
	for entry in _array(p.get("classes")):
		classes.append("%s %s" % [_name(entry.id), entry.level])
	_label(_page, " / ".join(classes), 20)
	_label(_page, "%s XP · Level %s · %s pending levels" % [p.get("xp"), p.get("level"), p.get("pending_levels")])
	var stats := _dict(actor.get("stats"))
	_label(_page, "Defense %s  ·  Attack %s  ·  Power DC %s" % [_number(stats.get("defense")), _number(stats.get("attack")), _number(stats.get("power_dc"))])
	var saves := _dict(stats.get("saves"))
	_label(_page, "Fortitude %s  ·  Reflex %s  ·  Will %s" % [_number(saves.get("fortitude")), _number(saves.get("reflex")), _number(saves.get("will"))])
	_section("Attributes")
	for attr in _array(p.get("attributes")):
		_label(_page, "%s   %s   (base %s, equipment %s)" % [_name(attr.id), attr.total, attr.base, attr.gear])
	_section("Skills")
	for skill in _array(p.get("skills")):
		_label(_page, "%s   %s   ·   Rank %s / %s + ability %s + bonus %s" % [_name(skill.id), skill.total, skill.rank, skill.max_rank, skill.governing_modifier, skill.bonus])
	_section("Unspent choices")
	var budget := _dict(p.get("unspent"))
	_label(_page, "Skills %s · Feats %s · Powers %s · Attributes %s" % [budget.get("skill_points", 0), budget.get("feat_choices", 0), budget.get("power_choices", 0), budget.get("attribute_points", 0)])
	_section("Next choices")
	for choice in _array(p.get("next_choices")):
		_label(_page, "%s · %s · Cost %s%s" % [_name(choice.kind), _name(choice.id), choice.cost, "" if choice.available else "\n" + _reasons(choice.reasons)], 16, UI.INK if choice.available else UI.MUTED)
	_progression_presets(p)
	_capabilities(["skill", "dialogue"], "Skill opportunities")

func _progression_presets(p: Dictionary) -> void:
	_section("Review a complete build plan")
	var respec := _dict(p.get("respec"))
	if not respec.is_empty():
		_label(_page, "Respec: %s %s%s" % [respec.get("cost"), respec.get("currency"), "" if respec.get("available", false) else " · " + _reasons(respec.get("reasons"))], 16, UI.MUTED)
	var presets := _array(p.get("presets"))
	if presets.is_empty():
		_label(_page, "No complete build is available for this character. Choose individual skills above.", 16, UI.MUTED)
		return
	for preset in presets:
		var button := _button(_page, "preset:" + str(preset.id), str(preset.name))
		button.pressed.connect(func() -> void:
			_preset = str(preset.id)
			_render())
	var selected: Dictionary = {}
	for preset in presets:
		if str(preset.id) == _preset:
			selected = preset
	if selected.is_empty():
		_label(_page, "Select a plan to read every allocation before previewing it.", 16, UI.MUTED)
		return
	_label(_page, str(selected.get("description", "")), 17)
	var action := _dict(selected.get("action"))
	_show_plan(action)
	var confirm := _button(_page, "preset_preview", "Compare this complete plan")
	confirm.disabled = not selected.get("available", false) or action.is_empty()
	confirm.tooltip_text = _reasons(selected.get("reasons"))
	confirm.pressed.connect(_preview.bind(action))
	if confirm.disabled:
		_label(_page, confirm.tooltip_text, 16, UI.MUTED)

func _show_plan(action: Dictionary) -> void:
	_label(_page, _name(action.get("kind")) + " · " + str(action.get("actor_id", "")), 18, UI.BRASS)
	for attr in _array(action.get("initial_attributes")):
		_label(_page, "%s: %s" % [_name(attr.id), attr.value], 16)
	var levels: Array = _array(action.get("levels")) if action.has("levels") else [action]
	for index in range(levels.size()):
		var allocation: Dictionary = levels[index]
		_label(_page, "%s · %s" % ["Level " + str(index + 1) if action.has("levels") else "Next level", _name(allocation.get("class_id"))], 18, UI.BRASS)
		for skill in _array(allocation.get("skills")):
			_label(_page, "%s +%s ranks" % [_name(skill.id), skill.ranks], 16)
		for feat in _array(allocation.get("feats")):
			_label(_page, "Feat: " + _name(feat), 16)
		for power in _array(allocation.get("powers")):
			_label(_page, "Power: %s · Rank %s" % [_name(power.id), power.rank], 16)
		for attr in _array(allocation.get("attributes")):
			_label(_page, "Attribute: %s +%s" % [_name(attr.id), attr.amount], 16)
	_label(_page, "Unbind items: " + (", ".join(PackedStringArray(action.get("unbind_item_ids", []))) if not _array(action.get("unbind_item_ids")).is_empty() else "None"), 16)
	_label(_page, "Unallocated earned choices remain banked. Final costs and legality are checked in the comparison.", 15, UI.MUTED)

func _equipment(actor: Dictionary) -> void:
	var gear := _dict(_view.get("equipment"))
	if gear.get("actor_id") != actor.get("id"):
		_label(_page, "Waiting for this character's equipment.")
		return
	var entries := _array(gear.get("slots"))
	if _slot.is_empty() and not entries.is_empty():
		_slot = "main_hand" if entries.any(func(entry: Dictionary) -> bool: return entry.id == "main_hand") else str(entries[0].id)
	_section("Equipment")
	var split := HBoxContainer.new()
	split.name = "EquipmentColumns"
	split.add_theme_constant_override("separation", 18)
	_page.add_child(split)
	var body := VBoxContainer.new()
	body.name = "BodySlots"
	body.custom_minimum_size.x = 366
	body.add_theme_constant_override("separation", 8)
	split.add_child(body)
	_label(body, "Equipped", 18, UI.BRASS)
	var slots := GridContainer.new()
	slots.columns = 3
	slots.add_theme_constant_override("h_separation", 6)
	slots.add_theme_constant_override("v_separation", 6)
	body.add_child(slots)
	# Slot positions stay stable when a body has fewer slots. No rules live in the diagram.
	for id in ["focus_tool", "head", "accessory", "main_hand", "body", "offhand", "hands", "belt", ""]:
		var entry: Dictionary = {}
		for candidate in entries:
			if candidate.id == id:
				entry = candidate
		if entry.is_empty():
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(118, 116)
			slots.add_child(spacer)
			continue
		var equipped := _owned_item(str(entry.get("item_id", "")))
		var item_name := str(equipped.get("name", "Empty"))
		var slot_name := "Focus / tool" if id == "focus_tool" else _name(id)
		var button := _button(slots, "slot:" + str(id), "")
		button.custom_minimum_size = Vector2(118, 116)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = slot_name + " · " + item_name
		var contents := VBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_left = 5
		contents.offset_right = -5
		contents.offset_top = 6
		contents.offset_bottom = -6
		contents.add_theme_constant_override("separation", 3)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(contents)
		var icon := TextureRect.new()
		icon.texture = _equipment_icon(str(id))
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(icon)
		var title := _label(contents, slot_name, 16, UI.BRASS if _slot == id else UI.MUTED)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var item_label := _label(contents, item_name, 16, UI.INK if not equipped.is_empty() else UI.MUTED)
		item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_label.custom_minimum_size.y = 46
		item_label.max_lines_visible = 2
		item_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.pressed.connect(_select_equipment_slot.bind(str(id)))
		if _slot == id:
			button.add_theme_stylebox_override("normal", UI.style(Color("343126"), UI.BRASS, 2))
	var stats := _dict(actor.get("stats"))
	_label(body, "Defense %s  ·  Attack %s" % [_number(stats.get("defense")), _number(stats.get("attack"))], 17)
	_label(body, "Items used by queued orders are locked.", 16, UI.MUTED)
	var owned := VBoxContainer.new()
	owned.name = "OwnedEquipment"
	owned.custom_minimum_size.x = 300
	owned.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned.add_theme_constant_override("separation", 8)
	split.add_child(owned)
	_label(owned, _name(_slot) + " · Party inventory", 18, UI.BRASS)
	var current: Dictionary = {}
	for entry in entries:
		if entry.id == _slot:
			current = _owned_item(str(entry.get("item_id", "")))
	_label(owned, "Equipped: " + str(current.get("name", "Empty")), 17)
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "EquipmentList"
	list_scroll.custom_minimum_size.y = 328
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	owned.add_child(list_scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 7)
	list_scroll.add_child(options)
	var candidates: Array = []
	for option in _array(gear.get("options")):
		if _array(option.get("slot_ids")).has(_slot):
			candidates.append(option)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.get("available", false) != b.get("available", false):
			return bool(a.get("available", false))
		return str(a.get("label", "")) < str(b.get("label", "")))
	for option in candidates:
		_equipment_option(options, option)
	if candidates.is_empty():
		_label(options, "No compatible equipment in the party inventory.", 16, UI.MUTED)
	_label(owned, "Choose an item to compare changes before equipping it.", 16, UI.MUTED)
	var sets := _array(gear.get("sets"))
	if not sets.is_empty():
		_section("Weapon sets")
		var set_row := HBoxContainer.new()
		set_row.add_theme_constant_override("separation", 8)
		_page.add_child(set_row)
		for weapon_set in sets:
			var caption := str(weapon_set.name) + (" · Active" if weapon_set.id == gear.get("active_set_id") else "")
			var button := _button(set_row, "set:" + str(weapon_set.id), caption)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = weapon_set.id == gear.get("active_set_id")
			button.pressed.connect(_preview.bind({"kind": "weapon_set.activate", "actor_id": actor.id, "set_id": weapon_set.id, "expected_binding_version": gear.binding_version, "cancel_action_ids": []}))
	_capabilities(["upgrade"], "Equipment upgrades")

func _select_equipment_slot(id: String) -> void:
	_slot = id
	_render()

func _equipment_option(parent: VBoxContainer, option: Dictionary) -> void:
	var action := _dict(option.get("action"))
	var item := _owned_item(str(option.get("item_id", "")))
	var button := _button(parent, "gear:" + str(option.id), str(option.label))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 44
	button.disabled = not option.get("available", false) or action.is_empty()
	button.tooltip_text = _reasons(option.get("reasons"))
	button.pressed.connect(_preview.bind(action))
	var facts := PackedStringArray()
	if _array(option.get("slot_ids")).size() > 1:
		facts.append("Uses both hands" if _array(option.slot_ids).has("main_hand") and _array(option.slot_ids).has("offhand") else "Uses " + ", ".join(PackedStringArray(option.slot_ids)))
	if not item.is_empty():
		var holder := _actor(str(item.get("bound_actor_id", "")))
		if not holder.is_empty():
			facts.append("Equipped by " + str(holder.get("name", "companion")))
		for grant in _array(item.get("grants")):
			var grant_name := str(grant.get("label", grant.get("ability_id", ""))) if grant is Dictionary else ("Attack" if str(grant) == "basic" else _name(grant))
			facts.append("Grants " + grant_name)
	if not facts.is_empty():
		_label(parent, " · ".join(facts), 16, UI.MUTED)
	if button.disabled:
		_label(parent, button.tooltip_text if not button.tooltip_text.is_empty() else "Unavailable", 16, UI.MUTED)

func _equipment_icon(slot: String) -> Texture2D:
	if _slot_icons.has(slot):
		return _slot_icons[slot]
	# Original line symbols, drawn for Oathshaper; they convey slot type, never item rarity.
	var paths := {
		"head": '<path d="M9 23V13a7 7 0 0 1 14 0v10h-5v-7h-4v7zM7 24h18"/>',
		"body": '<path d="m11 5-7 5 4 8 4-2v12h8V16l4 2 4-8-7-5-5 4z"/>',
		"hands": '<path d="M9 16V8a2 2 0 0 1 4 0v7-10a2 2 0 0 1 4 0v10-9a2 2 0 0 1 4 0v10-5a2 2 0 0 1 4 0v11l-4 6H11L5 18a2 2 0 0 1 3-2l3 3"/>',
		"belt": '<rect x="3" y="12" width="26" height="9" rx="1"/><rect x="12" y="10" width="9" height="13" rx="1"/><path d="M13 16h6"/>',
		"accessory": '<path d="M9 4v7l7 6 7-6V4M12 21l4-4 4 4-4 7z"/>',
		"focus_tool": '<circle cx="16" cy="16" r="9"/><circle cx="16" cy="16" r="3"/><path d="M16 3v4m0 18v4M3 16h4m18 0h4"/>',
		"main_hand": '<path d="m8 24 3-3M5 27l3-3m0-5 5 5m-2-5L24 5l3-1-1 4-13 14"/>',
		"offhand": '<path d="m16 4 10 4v8c0 6-10 12-10 12S6 22 6 16V8zM16 8v15"/>'
	}
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><g fill="none" stroke="#d8bd80" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">%s</g></svg>' % paths.get(slot, "")
	var image := Image.new()
	image.load_svg_from_string(svg, 2.0)
	var texture := ImageTexture.create_from_image(image)
	_slot_icons[slot] = texture
	return texture

func _powers(actor: Dictionary) -> void:
	var p := _dict(_view.get("progression"))
	if p.get("actor_id") != actor.get("id"):
		_label(_page, "Waiting for this character's powers.")
		return
	_section("Feats")
	for feat in _array(p.get("feats")):
		_label(_page, "%s · Rank %s" % [_name(feat.id), feat.rank])
	if _array(p.get("feats")).is_empty():
		_label(_page, "No feats learned.", 16, UI.MUTED)
	_section("Learned powers")
	for power in _array(p.get("powers")):
		_label(_page, "%s · Rank %s" % [_name(power.id), power.rank])
	if _array(p.get("powers")).is_empty():
		_label(_page, "No powers learned.", 16, UI.MUTED)
	_section("Current actions and sources")
	if actor.get("id") != _view.party.recipient_id:
		_label(_page, "Action availability belongs to the current order recipient. Inspecting this sheet does not switch orders.", 16, UI.MUTED)
		return
	for action in _array(_view.get("actions")):
		if not action.get("known", false):
			continue
		_label(_page, "%s · %s · Rank %s" % [action.name, _name(action.category), action.rank], 19, UI.BRASS)
		var costs := PackedStringArray()
		for cost in _array(action.get("costs")):
			costs.append("%s %s" % [cost.amount, cost.label])
		_label(_page, "%s\n%s\nTarget: %s · Range: %s m · Cooldown: %s ticks" % [action.source_label, " · ".join(costs) if not costs.is_empty() else "No resource cost", _name(action.target_kind), _number(action.range_m), action.cooldown_remaining_ticks], 16)
		if not action.available or action.get("ghost", false):
			_label(_page, _reasons(action.reasons), 16, UI.MUTED)

func _party(actor: Dictionary) -> void:
	_section("Party roles")
	_label(_page, "Inspect or deploy a companion.", 17, UI.MUTED)
	for id in _array(_dict(_view.get("party")).get("roster_ids")):
		var member := _actor(str(id))
		_label(_page, "%s · %s · %s queued" % [member.get("name", id), _name(member.get("roster_status")), _array(member.get("queue")).size()], 19, UI.BRASS)
		for condition in _array(member.get("conditions")):
			_label(_page, str(condition.label), 16)
	_party_deployment(actor)
	_section("Companion behavior · " + str(actor.get("name", "")))
	var ai := _dict(actor.get("ai"))
	if ai.is_empty():
		_label(_page, "This character has no companion behavior settings.", 16, UI.MUTED)
		return
	var policy := _options(_page, "ai_policy", "Resource policy", ["conservative", "balanced", "spend"], str(ai.policy))
	var empty := _options(_page, "ai_empty", "When the queue is empty", ["role", "assist", "basic", "hold"], str(ai.empty_policy))
	var hold := CheckButton.new()
	hold.text = "Hold after explicit orders"
	hold.button_pressed = bool(ai.hold_after_orders)
	hold.set_meta("ledger_key", "ai_hold")
	_page.add_child(hold)
	var save := _button(_page, "ai_apply", "Apply companion behavior")
	save.pressed.connect(func() -> void:
		_request({"kind": "ai.configure", "actor_id": actor.id, "policy": policy.get_item_metadata(policy.selected), "empty_policy": empty.get_item_metadata(empty.selected), "hold_after_orders": hold.button_pressed}))
	if ai.get("last_reason") != null:
		_label(_page, "Last decision: " + str(ai.last_reason), 16, UI.MUTED)

func _party_deployment(actor: Dictionary) -> void:
	var party := _dict(_view.get("party"))
	var deployed := _array(party.get("deployed_ids"))
	var id := str(actor.get("id", ""))
	if id == "player":
		_label(_page, "Select a reserve companion to change who accompanies you.", 16, UI.MUTED)
		return
	if deployed.has(id):
		_label(_page, str(actor.get("name", "Companion")) + " is accompanying you.", 17)
		return
	_section("Invite " + str(actor.get("name", "companion")))
	var at_camp: bool = _dict(_view.get("session")).get("phase") == "camp"
	if not at_camp:
		_label(_page, "Return to camp to change companions.", 16, UI.MUTED)
	for member_id in deployed:
		if str(member_id) == "player":
			continue
		var member := _actor(str(member_id))
		var next_party: Array = deployed.duplicate()
		next_party[next_party.find(member_id)] = id
		var button := _button(_page, "deploy:" + id + ":replace:" + str(member_id), "Replace %s with %s" % [member.get("name", member_id), actor.get("name", id)])
		button.disabled = not at_camp or not actor.get("conscious", false)
		button.pressed.connect(_preview.bind({"kind": "party.deploy", "actor_ids": next_party}))
		if not actor.get("conscious", false):
			button.tooltip_text = "This companion must recover before joining."

func _options(parent: Node, key: String, caption: String, values: Array, selected: String) -> OptionButton:
	_label(parent, caption, 17)
	var control := OptionButton.new()
	control.custom_minimum_size.y = 40
	control.add_theme_font_size_override("font_size", 17)
	control.set_meta("ledger_key", key)
	for index in range(values.size()):
		control.add_item(_name(values[index]))
		control.set_item_metadata(index, values[index])
		if str(values[index]) == selected:
			control.select(index)
	parent.add_child(control)
	return control

func _inventory(actor: Dictionary) -> void:
	var inventory := _dict(_view.get("inventory"))
	_section("Inventory · %s credits" % _dict(inventory.get("currency")).get("credits", "Unknown"))
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	_page.add_child(filters)
	var filter := _options(filters, "inventory_filter", "Filter", ["all", "usable", "equipment", "reserved", "favorites", "quest"], _filter)
	filter.item_selected.connect(func(index: int) -> void:
		_filter = str(filter.get_item_metadata(index))
		_render())
	var containers: Array = ["all"]
	for container in _array(inventory.get("containers")):
		containers.append(str(container.id))
	var container_select := _options(filters, "inventory_container", "Container", containers, _container)
	container_select.item_selected.connect(func(index: int) -> void:
		_container = str(container_select.get_item_metadata(index))
		_render())
	var search := LineEdit.new()
	search.placeholder_text = "Find an item by name"
	search.text = _search
	search.custom_minimum_size.y = 40
	search.set_meta("ledger_key", "inventory_search")
	_page.add_child(search)
	# Submit keeps the editor/caret stable while typing; filtering never changes core state.
	search.text_submitted.connect(func(copy: String) -> void:
		_search = copy
		_render())
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	_page.add_child(split)
	var item_scroll := ScrollContainer.new()
	item_scroll.custom_minimum_size = Vector2(330, 330)
	item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.follow_focus = true
	split.add_child(item_scroll)
	var item_list := VBoxContainer.new()
	item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(item_list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.custom_minimum_size.x = 310
	split.add_child(detail)
	var items := _array(inventory.get("items"))
	var shown := 0
	for item in items:
		if not _item_matches(item):
			continue
		shown += 1
		var button := _button(item_list, "item:" + str(item.id), "%s ×%s\n%s free / %s reserved" % [item.name, item.quantity, item.free, item.reserved])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 64
		button.pressed.connect(func() -> void:
			_item = str(item.id)
			_render())
	if shown == 0:
		_label(item_list, "No items match these filters.", 16, UI.MUTED)
	var selected := _owned_item(_item)
	if not selected.is_empty():
		_item_details(selected, actor, detail)
	else:
		_label(detail, "Select an item to see who carries it and how it can be used.", 17, UI.MUTED)
	_capabilities(["shop", "craft", "dismantle", "inventory", "loot"], "Workbench and trade")

func _item_matches(item: Dictionary) -> bool:
	if _container != "all" and str(item.container_id) != _container:
		return false
	if _search != "" and not str(item.name).to_lower().contains(_search.to_lower()):
		return false
	match _filter:
		"usable": return _operation(item, "inventory.use").size() > 0
		"equipment": return not _array(item.get("compatible_slots")).is_empty() or not _array(item.get("bound_slots")).is_empty() or not _operation(item, "equipment.apply").is_empty()
		"reserved": return int(item.get("reserved", 0)) > 0
		"favorites": return bool(item.get("favorite", false))
		"quest": return bool(item.get("quest_protected", false))
	return true

func _operation(item: Dictionary, kind: String) -> Dictionary:
	for operation in _array(item.get("operations")):
		if operation.get("kind") == kind:
			return operation
	return {}

func _item_details(item: Dictionary, actor: Dictionary, parent: VBoxContainer) -> void:
	_label(parent, str(item.name), 22, UI.BRASS, true)
	var description := str(item.get("description", ""))
	if not description.is_empty() and description != "%s; %s" % [item.name, item.get("category", "")]:
		_label(parent, description, 17)
	if item.has("category"):
		_label(parent, _name(item.category), 16, UI.MUTED)
	_label(parent, "%s\nQuantity %s · Available %s · Committed %s" % [_name(item.container_id), item.quantity, item.free, item.reserved], 16)
	var bound := _actor(str(item.get("bound_actor_id", "")))
	if not bound.is_empty():
		_label(parent, "Equipped by " + str(bound.name), 16)
	for grant in _array(item.get("grants")):
		_label(parent, "Grants: " + (str(grant.get("label", grant.get("ability_id", ""))) if grant is Dictionary else _name(grant)), 16, UI.BRASS)
	if not _array(item.get("occupies_slots")).is_empty():
		_label(parent, "Occupies: " + ", ".join(PackedStringArray(item.occupies_slots)), 16)
	if item.get("quest_protected", false):
		_label(parent, "Quest protected", 16, UI.BRASS)
	if not item.get("accessible", false):
		_label(parent, _reasons(item.get("reasons")), 16, UI.MUTED)
	var use := _operation(item, "inventory.use")
	if not use.is_empty():
		var button := _button(parent, "inventory_use", "Use with " + str(actor.get("name", "character")), {"kind": "ui.inventory_use", "actor_id": actor.get("id"), "item_id": item.id})
		button.disabled = not use.get("available", false) or not item.get("accessible", false) or not _array(_dict(_view.get("party")).get("deployed_ids")).has(actor.get("id"))
		button.tooltip_text = _reasons(use.get("reasons"))
		if not _array(_dict(_view.get("party")).get("deployed_ids")).has(actor.get("id")):
			button.tooltip_text = "Reserve characters cannot issue item orders."
		if button.disabled:
			_label(parent, button.tooltip_text, 16, UI.MUTED)
		_label(parent, "Choose a target. The item is used when this order begins.", 16, UI.MUTED)
	for operation in _array(item.get("operations")):
		if operation.kind == "inventory.use":
			continue
		_label(parent, "%s%s" % [_name(operation.kind), "" if operation.available else " · " + _reasons(operation.reasons)], 16, UI.MUTED)

func _capabilities(prefixes: Array, title: String) -> void:
	var entries: Array = []
	for entry in _array(_view.get("capabilities")):
		var action := _dict(entry.get("action"))
		var family := str(action.get("kind", "")).split(".")[0]
		if prefixes.has(family):
			entries.append(entry)
	if entries.is_empty():
		return
	_section(title)
	for entry in entries:
		var button := _button(_page, "capability:" + str(entry.id), str(entry.label))
		button.disabled = not entry.get("available", false)
		button.tooltip_text = _reasons(entry.get("reasons"))
		button.pressed.connect(_preview.bind(_dict(entry.action)))
		_label(_page, str(entry.get("description", "")), 16)
		if button.disabled:
			_label(_page, button.tooltip_text, 16, UI.MUTED)

func _journal() -> void:
	var encounter := _dict(_view.get("encounter"))
	_section("The Quay Robbery")
	_label(_page, str(encounter.get("objective", "No active objective")), 20)
	_label(_page, "Status: %s · Outcome: %s" % [_name(encounter.get("status")), _name(encounter.get("outcome"))], 16)
	_section("Revealed skill opportunities")
	for action in _array(_view.get("world_actions")):
		var checker := _actor(str(action.get("checker_id", "")))
		_label(_page, "%s · Checker: %s · DC %s" % [action.name, checker.get("name", action.checker_id), _number(action.get("dc"))], 18)
		if action.get("helper_id") != null:
			_label(_page, "Helper: " + str(_actor(str(action.helper_id)).get("name", action.helper_id)), 16)
		if not action.available:
			_label(_page, _reasons(action.reasons), 16, UI.MUTED)
	_capabilities(["skill", "dialogue"], "Available interactions")
	_capabilities(["camp", "encounter"], "Camp")
	_section("Recent events")
	for entry in _array(_view.get("logs")):
		_label(_page, "%.1f s · %s" % [float(entry.tick) / 10.0, entry.text], 17)
	if _array(_view.get("logs")).is_empty():
		_label(_page, "No events recorded.", 16, UI.MUTED)

func _save() -> void:
	_section("The Quay Robbery")
	_label(_page, "This chapter has its own save slot. Your Lantern Quay journey is saved separately.", 19)
	_button(_page, "save_trial", "Save chapter", {"kind": "ui.save"})
	_button(_page, "load_trial", "Load chapter…", {"kind": "ui.load"})
	_label(_page, "Loading pauses the encounter until you resume.", 16, UI.MUTED)

func _wire_focus() -> void:
	var controls: Array[Control] = []
	_collect_focus(self, controls)
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[posmod(index - 1, controls.size())])
		controls[index].focus_neighbor_top = controls[index].focus_previous
		controls[index].focus_neighbor_left = controls[index].focus_previous
		controls[index].focus_neighbor_bottom = controls[index].focus_next
		controls[index].focus_neighbor_right = controls[index].focus_next

	if _tab == 1:
		_wire_equipment_focus()

func _wire_equipment_focus() -> void:
	var layout := ["focus_tool", "head", "accessory", "main_hand", "body", "offhand", "hands", "belt", ""]
	var first_item: Control
	for key in _buttons:
		if str(key).begins_with("gear:") and not _buttons[key].disabled:
			first_item = _buttons[key]
			break
	for index in range(layout.size()):
		var button: Button = _buttons.get("slot:" + str(layout[index]))
		if button == null:
			continue
		for direction in [[-1, "focus_neighbor_left"], [1, "focus_neighbor_right"], [-3, "focus_neighbor_top"], [3, "focus_neighbor_bottom"]]:
			var neighbor := index + int(direction[0])
			if neighbor < 0 or neighbor >= layout.size():
				continue
			if abs(int(direction[0])) == 1 and neighbor / 3 != index / 3:
				continue
			var other: Button = _buttons.get("slot:" + str(layout[neighbor]))
			if other != null:
				button.set(str(direction[1]), button.get_path_to(other))
		if index % 3 == 2 and first_item != null:
			button.focus_neighbor_right = button.get_path_to(first_item)
	var selected: Button = _buttons.get("slot:" + _slot)
	if selected != null:
		for key in _buttons:
			if str(key).begins_with("gear:"):
				_buttons[key].focus_neighbor_left = _buttons[key].get_path_to(selected)

func _collect_focus(node: Node, controls: Array[Control]) -> void:
	if node is Control and node.focus_mode == Control.FOCUS_ALL and node.is_visible_in_tree():
		if not node is BaseButton or not node.disabled:
			controls.append(node)
	for child in node.get_children():
		_collect_focus(child, controls)

func _focus_control(key: String) -> Control:
	if key.is_empty():
		return null
	var controls: Array[Control] = []
	_collect_focus(self, controls)
	for control in controls:
		if str(control.get_meta("ledger_key", "")) == key:
			return control
	return null
