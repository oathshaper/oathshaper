extends Control
## Native Command HUD. It projects the facade view and emits user intentions;
## costs, availability, queue state and outcomes are never calculated here.
signal requested(action: Dictionary)
const UI := preload("res://scripts/combat_theme.gd")
const ICONS := preload("res://scripts/command_action_icons.gd")
const CATEGORIES := ["weapon", "powers", "tech", "items", "movement"]
const TITLES := ["Weapons", "Powers", "Devices", "Items", "Movement"]
const PORTRAITS := {"player": "player", "mara": "mara", "clerk": "clerk", "ivo": "ivo"}
var preview_mode := false
var category_index := 0
var action_page := 0
var _view: Dictionary = {}
var _header: HBoxContainer
var _party: VBoxContainer
var _details: VBoxContainer
var _actions: HBoxContainer
var _queue: HBoxContainer
var _summary: Label
var _hint: Label
var _status: Label
var _log: RichTextLabel
var _categories: Array[Button] = []
var _visible_actions: Array = []
var _buttons: Dictionary = {}
var _fingerprint := ""
var _controller := false
var _recipient_id := ""
var _actor_memory: Dictionary = {}
var _selected_queue := ""
var _queue_editor: HBoxContainer
var _bottom_panel: PanelContainer
var _objective: Label
var _target_panel: VBoxContainer
var _target_name: Label
var _target_health: ProgressBar
var _context_actions: HBoxContainer
var _target_stamp := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _label(parent: Node, copy: String, size := 18, color := UI.INK, display := false) -> Label:
	var node := UI.label(copy, size, color, display)
	parent.add_child(node)
	return node

func _panel(parent: Node, preset: LayoutPreset, offsets: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = offsets.position.x
	panel.offset_top = offsets.position.y
	panel.offset_right = offsets.end.x
	panel.offset_bottom = offsets.end.y
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.025, .055, .065, .93), Color("58615b")))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)
	return column

func _button(parent: Node, key: String, caption: String, action: Dictionary, minimum := 42) -> Button:
	var node := UI.button(caption, func() -> void: _dispatch(key, action))
	node.set_meta("command_key", key)
	node.custom_minimum_size.y = minimum
	node.add_theme_font_size_override("font_size", 17)
	var box := UI.style(Color("122127"), Color("435359"))
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	node.add_theme_stylebox_override("normal", box)
	node.focus_mode = Control.FOCUS_NONE if preview_mode else Control.FOCUS_ALL
	parent.add_child(node)
	_buttons[key] = node
	node.focus_entered.connect(func() -> void: _remember_focus(key))
	return node

func _build() -> void:
	var top := _panel(self, Control.PRESET_TOP_WIDE, Rect2(16, 12, -32, 48))
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 10)
	top.add_child(_header)
	var name := _label(_header, "LANTERN GARDEN", 19, UI.BRASS, true)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = _label(_header, "", 16, UI.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_button(_header, "camp", "Camp", {"kind": "ui.camp"}, 34)
	_button(_header, "pause", "Resume · Space", {"kind": "ui.pause"}, 34)
	_button(_header, "ledger", "Party · I", {"kind": "ui.ledger"}, 34)
	_button(_header, "controls", "Controls · H", {"kind": "ui.controls"}, 34)
	_button(_header, "exit", "Menu", {"kind": "ui.exit"}, 34)
	_target_panel = _panel(self, Control.PRESET_TOP_LEFT, Rect2(16, 88, 340, 120))
	var target_row := HBoxContainer.new()
	_target_panel.add_child(target_row)
	_target_name = _label(target_row, "Choose a target", 19, UI.INK, true)
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(target_row, "previous_target", "‹", {"kind": "ui.target_cycle", "delta": -1}, 32).tooltip_text = "Previous target · Shift+T"
	_button(target_row, "next_target", "›", {"kind": "ui.target_cycle", "delta": 1}, 32).tooltip_text = "Next target · RB / T"
	_target_health = _meter(_target_panel, 1, 1, Color("ca796a"), 10)
	_context_actions = HBoxContainer.new()
	_target_panel.add_child(_context_actions)
	_details = _panel(self, Control.PRESET_TOP_RIGHT, Rect2(-282, 88, 266, 80))
	_label(_details, "THE QUAY ROBBERY", 15, UI.BRASS)
	_objective = _label(_details, "", 16)
	var log_button := _button(_details, "combat_log", "Combat log ▾", {"kind": "ui.combat_log"}, 28)
	log_button.add_theme_font_size_override("font_size", 14)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.custom_minimum_size.y = 180
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_color_override("default_color", UI.MUTED)
	_log.scroll_following = true
	_details.add_child(_log)
	_log.hide()
	_party = _panel(self, Control.PRESET_BOTTOM_LEFT, Rect2(16, -284, 236, 242))
	var bottom := _panel(self, Control.PRESET_BOTTOM_WIDE, Rect2(268, -252, -284, 210))
	_bottom_panel = bottom.get_parent() as PanelContainer
	_summary = _label(bottom, "", 16, UI.INK)
	var categories := HBoxContainer.new()
	categories.add_theme_constant_override("separation", 4)
	bottom.add_child(categories)
	for index in range(CATEGORIES.size()):
		var button := _button(categories, "category:" + CATEGORIES[index], TITLES[index], {"kind": "ui.category", "index": index}, 30)
		button.add_theme_font_size_override("font_size", 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_categories.append(button)
	_button(categories, "previous_page", "‹", {"kind": "ui.action_page", "delta": -1}, 30)
	_button(categories, "next_page", "›", {"kind": "ui.action_page", "delta": 1}, 30)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 6)
	bottom.add_child(_actions)
	_queue = HBoxContainer.new()
	_queue.add_theme_constant_override("separation", 6)
	bottom.add_child(_queue)
	_queue_editor = HBoxContainer.new()
	_queue_editor.add_theme_constant_override("separation", 8)
	bottom.add_child(_queue_editor)
	_queue_editor.hide()
	_hint = _label(self, "", 16, UI.INK)
	_hint.add_theme_color_override("font_outline_color", Color("071013"))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_left = 16
	_hint.offset_right = -16
	_hint.offset_top = -31
	_hint.offset_bottom = -8
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if preview_mode:
		for button in _buttons.values():
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_default_hint()

func _meter(parent: Node, value: float, maximum: float, color: Color, height := 6) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.max_value = maxf(maximum, 1)
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("28373c")
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _render_target() -> void:
	var target := actor(str(_view.party.get("selected_target_id", "")))
	var valid: bool = not target.is_empty() and target.get("conscious", false)
	_target_name.text = str(target.get("name", "Choose a target")) if valid else "Choose a target"
	_target_health.visible = valid
	if valid:
		_target_health.max_value = target.health.maximum
		_target_health.value = target.health.current
		_target_name.tooltip_text = "%d / %d HP" % [target.health.current, target.health.maximum]
	var stamp := JSON.stringify([_view.actions, valid])
	if stamp == _target_stamp:
		return
	_target_stamp = stamp
	_clear(_context_actions)
	# The quick attack next to a target stays the ordinary equipped strike.
	# Equipment grant ordering must not silently replace it with a special move.
	var context_actions: Array = _view.actions.duplicate()
	context_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.id == "basic" and b.id != "basic")
	for category in ["weapon", "powers", "tech"]:
		for action in context_actions:
			if action.category != category or not action.get("known", true) or action.target_kind not in ["enemy", "point"]:
				continue
			var button := _button(_context_actions, "context:" + str(action.id), str(action.name), {"kind":"ui.context_action", "ability_id":action.id, "source_id":action.source_id}, 40)
			button.add_theme_font_size_override("font_size", 14)
			button.icon = ICONS.icon(str(action.id))
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 24)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = not valid or not action.available
			button.tooltip_text = _action_tooltip(action)
			break


func apply_view(view: Dictionary, force := false) -> void:
	if view.is_empty():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	var had_focus := focus_owner != null and is_ancestor_of(focus_owner)
	var focused_key := str(focus_owner.get_meta("command_key", "")) if had_focus else ""
	var selected := str(view.party.recipient_id)
	var changed_actor := selected != _recipient_id
	if changed_actor:
		_store_memory()
		_recipient_id = selected
		var memory: Dictionary = _actor_memory.get(selected, {})
		category_index = int(memory.get("category", 0))
		action_page = int(memory.get("page", 0))
		_selected_queue = str(memory.get("queue", ""))
		focused_key = str(memory.get("focus", "category:" + CATEGORIES[category_index]))
	_view = view
	if _header == null:
		return
	var recipient := actor(selected)
	_status.text = "PAUSED" if view.clock.paused else ("IN COMBAT" if view.session.phase == "encounter" else "AT THE GATE")
	var reasons := PackedStringArray()
	for reason in view.clock.pause_reasons:
		reasons.append(str(reason.label))
	_buttons.pause.text = ("Resume" if view.clock.paused else "Pause") + (" · View" if _controller else " · Space")
	_buttons.pause.tooltip_text = "\n".join(reasons)
	for reason in view.clock.pause_reasons:
		if reason.owner == "orders_empty": _status.text = str(reason.label)
	_buttons.ledger.text = "Party · Menu" if _controller else "Party · I"
	_buttons.camp.visible = view.session.phase == "camp"
	_objective.text = "The guards are down. Search the raider." if view.get("encounter", {}).get("outcome") == "victory" else str(view.get("encounter", {}).get("objective", ""))
	var focus = recipient.get("focus")
	_summary.text = str(recipient.get("name", "Party"))
	if focus != null and int(focus.maximum) > 0:
		_summary.text += "   ·   Focus %d / %d   ·   %d committed" % [focus.current, focus.maximum, focus.reserved]
	elif recipient.get("battery") != null:
		_summary.text += "   ·   Tool charges %d   ·   %d committed" % [recipient.battery.current, recipient.battery.reserved]
	_render_target()
	var lines := PackedStringArray()
	for event in view.get("logs", []).slice(-6):
		lines.append("%.1f  %s" % [float(event.tick) / 10, event.text])
	_log.text = "\n".join(lines)
	# Only facts rendered by interactive controls participate. World poses do not.
	var party_rows: Array = []
	for id in view.party.deployed_ids:
		var member := actor(str(id))
		party_rows.append([id, member.get("name"), member.get("health"), member.get("focus"), member.get("battery"), member.get("ai"), member.get("active_action"), member.get("conscious"), member.get("queue", []).size()])
	var stamp := JSON.stringify([party_rows, view.actions, recipient.get("queue"), recipient.get("active_action"), selected, category_index, action_page, _selected_queue, _controller])
	if stamp == _fingerprint and not force:
		return
	_fingerprint = stamp
	_render_party()
	_render_actions()
	_render_queue(recipient)
	for index in range(_categories.size()):
		_categories[index].add_theme_color_override("font_color", UI.BRASS if index == category_index else UI.MUTED)
	_store_memory()
	_default_hint()
	if had_focus:
		_restore_focus(focused_key)

func _clear(parent: Node) -> void:
	# Erase before queue_free: a detached but still-valid control is already stale.
	for key in _buttons.keys():
		var node = _buttons[key]
		if not is_instance_valid(node) or node == parent or parent.is_ancestor_of(node):
			_buttons.erase(key)
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _dispatch(key: String, action: Dictionary) -> void:
	var button = _buttons.get(key)
	if preview_mode or not is_instance_valid(button) or button.disabled or action.is_empty():
		return
	requested.emit(action.duplicate(true))

func _remember_focus(key: String) -> void:
	if _recipient_id.is_empty():
		return
	if key.begins_with("action:") or key.begins_with("category:") or key.begins_with("queue"):
		var memory: Dictionary = _actor_memory.get(_recipient_id, {})
		memory["focus"] = key
		_actor_memory[_recipient_id] = memory

func _store_memory() -> void:
	if _recipient_id.is_empty():
		return
	var memory: Dictionary = _actor_memory.get(_recipient_id, {})
	memory.merge({"category": category_index, "page": action_page, "queue": _selected_queue}, true)
	_actor_memory[_recipient_id] = memory

func _restore_focus(key: String) -> void:
	if preview_mode:
		return
	for candidate in [key, "category:" + CATEGORIES[category_index], "actor:" + _recipient_id, "pause"]:
		var button = _buttons.get(candidate)
		if is_instance_valid(button) and is_ancestor_of(button) and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return

func set_input_device(controller: bool) -> void:
	controller = controller and not Input.get_connected_joypads().is_empty()
	if _controller == controller:
		return
	_controller = controller
	apply_view(_view, true)
	_default_hint()

func _default_hint() -> void:
	if _hint == null:
		return
	if preview_mode:
		_hint.text = "Command · Combat preview"
	elif _controller:
		_hint.text = "LB / RB Target · L3 / R3 Party · RT Attack · X Actions · Menu Ledger · View Pause"
	else:
		_hint.text = "Tab Party · I Ledger · Space Pause · 1–6 Actions · T Target · E Attack · H Controls"

func actor(id: String) -> Dictionary:
	for entry in _view.get("actors", []):
		if str(entry.id) == id:
			return entry
	return {}

func _render_party() -> void:
	_clear(_party)
	var portrait_index := 0
	for id in _view.party.deployed_ids:
		var member := actor(str(id))
		if member.is_empty():
			continue
		portrait_index += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_party.add_child(row)
		var button := _button(row, "actor:" + str(id), "", {"kind": "party.possess", "actor_id": id, "select": true}, 54)
		button.custom_minimum_size.x = 52
		button.tooltip_text = str(member.name) + " · Take control"
		button.disabled = not member.get("conscious", true)
		if PORTRAITS.has(str(id)):
			var texture: Texture2D = load("res://assets/ui/%s-portrait.png" % PORTRAITS[str(id)])
			var portrait := AtlasTexture.new()
			portrait.atlas = texture
			portrait.region = Rect2(texture.get_width() * .34, 0, texture.get_width() * .32, texture.get_height() * .21)
			var face := TextureRect.new()
			face.texture = portrait
			face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(face)
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.offset_left = 4
			face.offset_top = 4
			face.offset_right = -4
			face.offset_bottom = -4
		if id == _view.party.recipient_id:
			button.add_theme_stylebox_override("normal", UI.style(Color("393326"), UI.BRASS, 2))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 3)
		row.add_child(info)
		var title := _label(info, "%s%s" % [member.name, "" if _controller else " · F%d" % portrait_index], 16, UI.BRASS if id == _view.party.recipient_id else UI.INK)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		var status := "%d / %d HP" % [member.health.current, member.health.maximum]
		if id != _view.party.possessed_id:
			status += " · AI" if not member.get("ai", {}).get("hold_after_orders", false) else " · Hold"
		var health_text := _label(info, status, 14, UI.MUTED)
		health_text.tooltip_text = str(member.get("ai", {}).get("last_reason", ""))
		_meter(info, member.health.current, member.health.maximum, Color("97bc91"))
		var pool = member.get("focus")
		if pool != null and int(pool.maximum) > 0:
			_meter(info, pool.current, pool.maximum, Color("89acc4"), 4)
		elif member.get("battery") != null and int(member.battery.maximum) > 0:
			_meter(info, member.battery.current, member.battery.maximum, UI.BRASS, 4)
	var buttons := HBoxContainer.new()
	_party.add_child(buttons)
	for entry in [["previous_actor", "‹ Party", -1], ["next_actor", "Party ›", 1]]:
		var button := _button(buttons, entry[0], ("‹ L3" if entry[2] == -1 else "R3 ›") if _controller else entry[1], {"kind": "ui.actor_cycle", "delta": entry[2]}, 28)
		button.add_theme_font_size_override("font_size", 14)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _render_actions() -> void:
	_clear(_actions)
	_visible_actions.clear()
	var available: Array = []
	var has_weapon_attack: bool = _view.actions.any(func(a: Dictionary) -> bool:
		return a.id == "basic" and str(a.source_id).begins_with("item:") and not a.get("ghost", false))
	for action in _view.actions:
		if action.category == CATEGORIES[category_index] and action.get("known", true):
			# Keep unarmed fallback in the rules, but show the equipped attack once.
			if action.id == "basic" and str(action.source_id).begins_with("learned:") and has_weapon_attack: continue
			available.append(action)
	if CATEGORIES[category_index] == "weapon":
		var order := {"brace": 0, "basic": 1, "lunge": 2, "shield_bash": 3}
		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(order.get(a.id, 4)) < int(order.get(b.id, 4)))
	var pages := maxi(1, ceili(available.size() / 6.0))
	action_page = posmod(action_page, pages)
	for index in range(action_page * 6, mini(available.size(), action_page * 6 + 6)):
		var action: Dictionary = available[index]
		_visible_actions.append(action)
		var costs := PackedStringArray()
		for cost in action.costs:
			costs.append("%d %s" % [cost.amount, cost.label])
		var blocked := not bool(action.available) or bool(action.get("ghost", false))
		var caption := "%s%s\n%s" % ["" if _controller else "%d  " % _visible_actions.size(), action.name, " · ".join(costs) if not costs.is_empty() else "Ready"]
		if blocked:
			caption += "\n" + _short_reason(action)
		var scoped_key := "action:" + str(action.id) + ":" + str(action.source_id)
		var button := _button(_actions, scoped_key, caption, {"kind": "ui.choose_action", "ability_id": action.id, "source_id": action.source_id}, 58)
		# Compatibility alias identifies only the first visible source for this ability.
		# Every real row/focus identity and its emitted request remains source-specific.
		var alias := "action:" + str(action.id)
		if not _buttons.has(alias):
			_buttons[alias] = button
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.icon = ICONS.icon(str(action.id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		button.clip_text = true
		button.disabled = blocked
		button.tooltip_text = _action_tooltip(action)
		if blocked:
			button.add_theme_color_override("font_disabled_color", Color("a5aaa6"))

	if available.is_empty():
		var empty := _label(_actions, "No known " + TITLES[category_index].to_lower() + " for this character.", 17, UI.MUTED)
		empty.custom_minimum_size.y = 58

func _render_queue(recipient: Dictionary) -> void:
	_clear(_queue)
	_clear(_queue_editor)
	var active = recipient.get("active_action")
	var label := _label(_queue, ("AI ORDER\n" if active != null and active.get("origin") == "ai" else "CURRENT\n") + (_ability_name(str(active.ability_id)) + " · " + str(active.state) if active != null else "Ready"), 15, UI.BRASS)
	label.custom_minimum_size.x = 110
	var queue: Array = recipient.get("queue", [])
	var selected_index := -1
	for index in range(queue.size()):
		var entry: Dictionary = queue[index]
		var id := str(entry.id)
		var button := _button(_queue, "queue:" + id, "%d · %s%s" % [index + 1, "AI · " if entry.get("origin") == "ai" else "", _ability_name(str(entry.ability_id))], {}, 42)
		button.clip_text = true
		button.tooltip_text = _queue_tooltip(entry)
		button.icon = ICONS.icon(str(entry.ability_id))
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_queue.bind(id))
		if id == _selected_queue:
			selected_index = index
			button.add_theme_stylebox_override("normal", UI.style(Color("393326"), UI.BRASS))
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_queue.add_child(space)
	var clear_intent := {"kind": "queue.clear_future", "actor_id": recipient.get("id", "")}
	if active != null and active.get("origin") == "ai":
		clear_intent = {"kind": "queue.stop_clear", "actor_id": recipient.id, "confirm_paid_cost": true}
	var clear := _button(_queue, "clear", "Clear", clear_intent, 42)
	clear.disabled = queue.is_empty() and active == null
	clear.tooltip_text = "Clear orders, including the current AI order. Paid costs remain spent."
	if active != null and active.get("origin") != "ai" and queue.is_empty():
		clear.disabled = true
	_button(_queue, "stop", "Disengage", {"kind": "ui.stop"}, 42).tooltip_text = "Confirm interruption. Paid costs and recovery remain."
	if selected_index < 0:
		_selected_queue = ""
	_queue_editor.visible = selected_index >= 0
	_bottom_panel.offset_top = -292 if selected_index >= 0 else -252
	if selected_index >= 0:
		var selected: Dictionary = queue[selected_index]
		var title := _label(_queue_editor, "Selected: " + _ability_name(str(selected.ability_id)), 16, UI.BRASS)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var earlier := _button(_queue_editor, "queue_earlier", "← Earlier", {}, 36)
		earlier.disabled = selected_index == 0
		earlier.pressed.connect(_move_queue.bind(-1))
		var later := _button(_queue_editor, "queue_later", "Later →", {}, 36)
		later.disabled = selected_index == queue.size() - 1
		later.pressed.connect(_move_queue.bind(1))
		_button(_queue_editor, "queue_remove", "Remove order", {"kind": "queue.remove", "actor_id": recipient.id, "action_id": selected.id}, 36)

func _select_queue(id: String) -> void:
	if preview_mode:
		return
	_selected_queue = id
	apply_view(_view, true)
	_restore_focus("queue:" + id)

func _move_queue(delta: int) -> void:
	if preview_mode:
		return
	var ids: Array = []
	for entry in actor(_recipient_id).get("queue", []):
		ids.append(str(entry.id))
	var index := ids.find(_selected_queue)
	var destination := index + delta
	if index < 0 or destination < 0 or destination >= ids.size():
		return
	var swap: String = ids[destination]
	ids[destination] = ids[index]
	ids[index] = swap
	requested.emit({"kind": "queue.reorder", "actor_id": _recipient_id, "action_ids": ids})

func _ability_name(id: String) -> String:
	for action in _view.get("actions", []):
		if str(action.id) == id:
			return str(action.name)
	return id.replace("_", " ").capitalize()

func _short_reason(action: Dictionary) -> String:
	var reasons: Array = action.get("reasons", [])
	if reasons.is_empty():
		return "Unavailable"
	var concise := {"queue_full": "Queue full", "source_lost": "Source unavailable", "cooldown": "Still recovering", "armor": "Armor restriction"}
	return str(concise.get(str(reasons[0].get("code", "")), reasons[0].message))

func _source_label(action: Dictionary) -> String:
	var label := str(action.get("source_label", ""))
	if label.is_empty() or label == str(action.get("source_id", "")):
		# Human-readable fallback only; the full binding identity remains in the tooltip.
		return label.replace(":", " · ").replace("_", " ").capitalize() if not label.is_empty() else "Bound source"
	return label

func _action_tooltip(action: Dictionary) -> String:
	var lines := PackedStringArray([str(action.name), "Source: " + _source_label(action)])
	if not str(action.get("description", "")).is_empty(): lines.append(str(action.description))
	for cost in action.get("costs", []):
		lines.append("%s %s" % [cost.amount, cost.label])
	lines.append("Target: " + str(action.get("target_kind", "")))
	if action.get("range_m") != null:
		lines.append("Range: %s m" % action.range_m)
	if action.get("radius_m") != null:
		lines.append("Radius: %s m" % action.radius_m)
	if int(action.get("cooldown_remaining_ticks", 0)) > 0:
		lines.append("Recovery: %.1f s" % (float(action.cooldown_remaining_ticks) / 10.0))
	for reason in action.get("reasons", []):
		lines.append(str(reason.message))
	return "\n".join(lines)

func _queue_tooltip(entry: Dictionary) -> String:
	var target: Dictionary = entry.get("target", {})
	var label := _ability_name(str(entry.ability_id)) + " · " + str(entry.get("state", "waiting"))
	if target.get("actor_id") != null:
		label += "\nTarget: " + str(actor(str(target.actor_id)).get("name", target.actor_id))
	elif target.get("kind") == "point":
		label += "\nTarget: selected ground point"
	for action in _view.get("actions", []):
		if action.id == entry.ability_id and action.source_id == entry.source_id:
			label += "\nSource: " + _source_label(action)
			break
	for cost in entry.get("reserved_costs", []):
		label += "\nReserved: %s %s" % [cost.amount, cost.label]
	for reason in entry.get("reasons", []):
		label += "\n" + str(reason.message)
	return label + "\nSelect to move earlier, move later or remove."

func set_category(index: int) -> void:
	category_index = posmod(index, CATEGORIES.size())
	action_page = 0
	apply_view(_view, true)

func page_actions(direction: int) -> void:
	action_page += direction
	apply_view(_view, true)

func choose_number(index: int) -> void:
	if preview_mode or index < 0 or index >= _visible_actions.size():
		return
	var action: Dictionary = _visible_actions[index]
	if not action.get("available", false) or action.get("ghost", false):
		show_message(str(action.name) + " · " + _short_reason(action))
		return
	requested.emit({"kind": "ui.choose_action", "ability_id": action.id, "source_id": action.source_id})

func show_message(message: String) -> void:
	_hint.text = message

func _process(_delta: float) -> void:
	if _controller and Input.get_connected_joypads().is_empty(): set_input_device(false)
