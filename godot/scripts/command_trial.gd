extends Control
## A complete isolated host for Command. The same scene is embedded in Overview.
signal finished
class WorldInput:
	extends Node
	signal unhandled(event: InputEvent)
	signal controls(event: InputEvent)
	func _input(event: InputEvent) -> void:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
			controls.emit(event)
	func _unhandled_input(event: InputEvent) -> void:
		unhandled.emit(event)
const CHAPTER := preload("res://scripts/garden_chapter.gd")
const STAGE := preload("res://scripts/command_stage.gd")
const HUD := preload("res://scripts/command_hud.gd")
const SPACE := preload("res://scripts/command_space.gd")
const UI := preload("res://scripts/combat_theme.gd")
const SAVE_PATH := "user://oathshaper_command_trial_v1.json"
var preview_mode := false
var campaign_mode := false
var play_intro := false
var _confrontation: Node3D
var _chapter_won := false
var seed_value := "20261022"
var save_path := SAVE_PATH
var bridge: RefCounted
var state: Dictionary = {}
var stage: Node3D
var hud: Control
var viewport: SubViewport
var ledger: Control
var _space := SPACE.new()
var _layer: CanvasLayer
var _modal: PanelContainer
var _tokens: Dictionary = {}
var _pending_ability: Dictionary = {}
var _pending_item := ""
var _serial := 0
var _prefix := ""
var _remainder := 0.0
var _preview_elapsed := 0.0
var _preview_resumed := false
var _preview_terminal := 0.0
var _last_direction := Vector2.ZERO
var _stick := Vector2.ZERO
var _orbit_stick := Vector2.ZERO
var _trigger_down := false
var _closing := false
var _controller := false
var _selecting := false
var _ground_cursor := Vector2.ZERO
var _audio := preload("res://scripts/combat_audio.gd").new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_audio.muted = preview_mode
	add_child(_audio)
	_prefix = "input-%s-%s-" % [Time.get_ticks_usec(), get_instance_id()]
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	# Mouse coordinates belong to this viewport. SubViewportContainer consumes
	# forwarded mouse events, so the root viewport cannot pick the garden.
	var world_input := WorldInput.new()
	viewport.add_child(world_input)
	world_input.unhandled.connect(_world_input)
	world_input.controls.connect(_handle_input)
	stage = STAGE.new()
	viewport.add_child(stage)
	_layer = CanvasLayer.new()
	viewport.add_child(_layer)
	hud = HUD.new()
	hud.preview_mode = preview_mode
	_layer.add_child(hud)
	hud.requested.connect(_request)
	if not ClassDB.class_exists("CommandBridge"):
		_error("Command extension is not available. Rebuild the host extension.")
		return
	bridge = ClassDB.instantiate("CommandBridge")
	var created := _call("create", [seed_value])
	if not created.get("ok", false):
		return
	_publish(created.data)
	if campaign_mode and not preview_mode:
		# Mara and Ivo accompany the player from the gate.
		submit({"kind":"party.deploy", "actor_ids":["player", "mara", "ivo"]})
	if preview_mode:
		_seed_preview()
	elif campaign_mode:
		submit({"kind": "encounter.start", "encounter_id": "garden_patrol"})
	elif play_intro:
		_confrontation = preload("res://scripts/garden_confrontation.gd").play_trial(self, func() -> void:
			_confrontation = null
			submit({"kind": "encounter.start", "encounter_id": "garden_patrol"}))
	else:
		_open_camp()

func _call(method: String, arguments: Array = []) -> Dictionary:
	if bridge == null:
		return {"ok": false}
	var parsed = JSON.parse_string(bridge.callv(method, arguments))
	if not parsed is Dictionary:
		_error("Command returned an invalid transport response.")
		return {"ok": false}
	if not parsed.get("ok", false):
		var error = parsed.get("error", "Command failed")
		_error(str(error.get("message", error)) if error is Dictionary else str(error))
	return parsed

func _error(message: String) -> void:
	if hud != null:
		hud.show_message(message)
	push_warning("Command: " + message)

func _publish(data: Dictionary) -> void:
	var view: Dictionary = data.get("view", data)
	if view.get("schema") != "command.view/v1":
		return
	state = view
	_audio.apply_view(view)
	_chapter_won = _chapter_won or state.encounter.outcome == "victory"
	stage.apply_view(state)
	hud.apply_view(state)
	if is_instance_valid(ledger):
		ledger.apply_view(state)

func _refresh() -> void:
	var result := _call("view")
	if result.get("ok", false):
		_publish(result.data)

func submit(action: Dictionary) -> Dictionary:
	if state.is_empty() or _closing:
		return {}
	_serial += 1
	var envelope := {"schema": "command.action/v1", "command_id": _prefix + str(_serial),
		"generation": state.session.generation, "expected_revision": state.session.revision, "action": action}
	var result := _call("submit", [JSON.stringify(envelope)])
	if result.get("ok", false):
		_publish(result.data)
		var receipt: Dictionary = result.data.get("receipt", {})
		if receipt.get("status") == "rejected": _audio.cue("reject")
		elif receipt.get("status") == "accepted":
			if action.get("kind") in ["queue.enqueue", "inventory.use"]: _audio.cue("queue")
			elif action.get("kind") in ["target.select", "party.possess"]: _audio.cue("select")
		if receipt.get("status") != "rejected" and str(action.get("kind")) in ["party.deploy", "encounter.start", "encounter.retry", "camp.enter"]:
			# Roster/scene changes invalidate LOS even while paused on contact.
			# Refresh knowledge now so the first orders can target visible enemies.
			if _satisfy_space():
				var refreshed := _call("advance", [0])
				if refreshed.get("ok", false):
					_publish(refreshed.data)
		if receipt.get("status") == "accepted" and action.get("kind") == "encounter.start":
			_cycle_target()
		if receipt.get("status") == "rejected":
			var reasons := PackedStringArray()
			for reason in receipt.get("reasons", []):
				reasons.append(str(reason.message))
			hud.show_message(" · ".join(reasons))
		return receipt
	return {}

func _satisfy_space() -> bool:
	var requests := _call("space_requests")
	if not requests.get("ok", false):
		return false
	if requests.data.is_empty():
		return true
	var cursor := _call("space_sequence")
	if not cursor.get("ok", false):
		return false
	var frame := _space.frame(requests.data, str(cursor.data))
	var result := _call("observe_space", [JSON.stringify(frame)])
	return result.get("ok", false)

func _process(delta: float) -> void:
	_advance_frame(delta)
	if is_instance_valid(stage):
		stage.interpolation_fraction = clampf(_remainder / .1, 0.0, 1.0)

func _advance_frame(delta: float) -> void:
	if bridge == null or state.is_empty() or _closing:
		return
	if preview_mode:
		_preview_elapsed += delta
		if not _preview_resumed and _preview_elapsed >= 5:
			_preview_resumed = true
			_toggle_pause()
		if state.encounter.status in ["won", "lost"]:
			_preview_terminal += delta
			if _preview_terminal > 5:
				_restart_preview()
				return
	if not preview_mode and _orbit_stick.length() > .18:
		stage.orbit(_orbit_stick * delta * 180)
	if not preview_mode and _modal == null and ledger == null and not state.clock.paused:
		_update_movement()
	# Defeat may itself own an automatic pause; show the outcome before stopping.
	if not preview_mode and state.encounter.status in ["won", "lost"] and _modal == null and ledger == null:
		_open_outcome()
	if state.clock.paused:
		_remainder = 0.0
		return
	_remainder += minf(delta, .25)
	var observation_pumps := 0
	while _remainder >= .1:
		if not _satisfy_space():
			_remainder = 0.0
			return
		var result := _call("advance", [1])
		if not result.get("ok", false):
			_remainder = 0.0
			return
		_publish(result.data)
		if int(result.data.get("consumed_ticks", 0)) == 0:
			# Admission of AI orders can require a new spatial observation without
			# consuming a tick. Service that request in this frame, boundedly.
			observation_pumps += 1
			if observation_pumps < 8 and not state.clock.paused and result.data.get("stop_reason") in ["complete", "waiting_for_space"]:
				continue
			# Keep owed simulation time when the geometry-pump budget is spent.
			# Admission is zero-time work, not a reason to lose a gameplay tick.
			if state.clock.paused:
				_remainder = 0.0
			return
		_remainder -= .1
		if state.clock.paused:
			_remainder = 0.0
			break
	if not preview_mode and state.encounter.status in ["won", "lost"] and _modal == null and ledger == null:
		_open_outcome()

func _acquire(owner: String) -> void:
	if _tokens.has(owner):
		return
	var receipt := submit({"kind": "pause.acquire", "owner": owner, "context_id": _prefix + owner})
	if receipt.get("pause_token") != null:
		_tokens[owner] = str(receipt.pause_token)

func _release(owner: String) -> void:
	if _tokens.has(owner):
		var token: String = _tokens[owner]
		_tokens.erase(owner)
		submit({"kind": "pause.release", "token": token})

func _toggle_pause() -> void:
	var acknowledged := _tokens.has("manual")
	if acknowledged:
		_release("manual")
	for reason in state.clock.pause_reasons.duplicate(true):
		if reason.acknowledgeable:
			submit({"kind": "pause.acknowledge", "token": reason.token})
			acknowledged = true
	if not acknowledged:
		_stop_movement()
		_acquire("manual")

func _request(action: Dictionary) -> void:
	if preview_mode or _closing or _modal != null:
		return
	match str(action.kind):
		"ui.controls": _open_controls()
		"ui.pause": _toggle_pause()
		"ui.camp": _open_camp()
		"ui.ledger": _open_ledger()
		"ui.close_ledger": _close_ledger()
		"ui.category": hud.set_category(int(action.index))
		"ui.action_page": hud.page_actions(int(action.delta))
		"ui.actor_cycle": _cycle_actor(int(action.delta))
		"ui.target_cycle": _cycle_target(int(action.get("delta", 1)))
		"ui.combat_log": hud._log.visible = not hud._log.visible
		"ui.context_action": _context_action(str(action.ability_id), str(action.get("source_id", "")))
		"ui.choose_action": _choose_action(str(action.ability_id), str(action.get("source_id", "")))
		"ui.inventory_use":
			_pending_item = str(action.item_id)
			_choose_item_target(str(action.actor_id))
		"ui.stop": _confirm({"kind": "queue.stop_clear", "actor_id": state.party.recipient_id, "confirm_paid_cost": true}, "Stop current action?", "Paid costs remain spent, and recovery still has to finish.")
		"ui.preview": _preview_change(action.action)
		"ui.save": _save()
		"ui.load": _load()
		"ui.exit": _exit_trial()
		"party.possess":
			_cancel_target()
			_stop_movement()
			submit(action)
			stage.follow_actor(str(action.actor_id))
		_: submit(action)

func _cycle_actor(direction: int) -> void:
	var ids: Array = state.party.deployed_ids
	var index := ids.find(state.party.recipient_id)
	_request({"kind": "party.possess", "actor_id": ids[posmod(index + direction, ids.size())], "select": true})

func _cycle_target(direction := 1) -> void:
	var candidates: Array = []
	var relation := "ally" if _pending_ability.get("target_kind") == "ally" else "enemy"
	for target in state.targets:
		if target.relation == relation:
			candidates.append(str(target.id))
	if candidates.is_empty():
		return
	var current := candidates.find(str(state.party.get("selected_target_id", "")))
	if current < 0:
		var owner: Dictionary = hud.actor(str(state.party.recipient_id))
		var origin := Vector2(owner.position[0], owner.position[1])
		candidates.sort_custom(func(a: String, b: String) -> bool:
			var left: Array = hud.actor(a).position
			var right: Array = hud.actor(b).position
			return origin.distance_squared_to(Vector2(left[0], left[1])) < origin.distance_squared_to(Vector2(right[0], right[1])))
	var index := posmod(current + direction, candidates.size()) if current >= 0 else (0 if direction > 0 else candidates.size() - 1)
	submit({"kind":"target.select", "target_id":candidates[index]})

func _context_action(id: String, source_id := "") -> void:
	_choose_action(id, source_id)
	if not _pending_ability.is_empty() and _pending_ability.get("target_kind") in ["enemy", "point"]:
		_confirm_aim()

func _valid_aim_target() -> Dictionary:
	var target: Dictionary = hud.actor(str(state.party.get("selected_target_id", "")))
	var ally: bool = _pending_ability.get("target_kind") == "ally"
	if target.is_empty() or not target.get("conscious", false) or (target.get("faction") == "party") != ally:
		return {}
	return target

func _begin_aim() -> void:
	_selecting = false
	_close_modal()
	_stop_movement()
	_acquire("targeting")
	if is_instance_valid(ledger):
		ledger.hide()
	if _valid_aim_target().is_empty():
		_cycle_target()
	stage.markers.aim_text = str(_pending_ability.get("name", "Use item")) + (" · LB/RB Target · A Confirm · B Cancel" if _controller else " · T Target · Enter Confirm · Esc Cancel")

func _confirm_aim() -> void:
	var target := _valid_aim_target()
	if target.is_empty():
		hud.show_message("Choose a conscious ally." if _pending_ability.get("target_kind") == "ally" else "Choose an enemy.")
		return
	if _pending_ability.get("target_kind") == "point":
		_queue_target({"kind":"point", "actor_id":null, "position":target.position})
	else:
		_queue_target({"kind":"actor", "actor_id":target.id, "position":null})

func _open_selector() -> void:
	_stop_movement()
	_selecting = true
	_acquire("selector")
	var buttons: Array = []
	var available: Array = []
	for action in state.actions:
		if action.category == hud.CATEGORIES[hud.category_index]:
			available.append(action)
	var pages := maxi(1, ceili(available.size() / 6.0))
	hud.action_page = posmod(hud.action_page, pages)
	for action in available.slice(hud.action_page * 6, hud.action_page * 6 + 6):
		var copy := str(action.name)
		if not action.available:
			copy += " · " + str(action.reasons[0].message) if not action.reasons.is_empty() else " · Unavailable"
		buttons.append([copy, func() -> void: _choose_action(str(action.id), str(action.source_id))])
	buttons.append(["‹ Category", func() -> void: hud.set_category(hud.category_index - 1); _open_selector()])
	buttons.append(["Category ›", func() -> void: hud.set_category(hud.category_index + 1); _open_selector()])
	buttons.append(["‹ Previous companion", func() -> void: _cycle_selection(-1)])
	buttons.append(["Next companion ›", func() -> void: _cycle_selection(1)])
	if pages > 1:
		buttons.append(["More actions", func() -> void: hud.page_actions(1); _open_selector()])
	buttons.append(["Back", _close_modal])
	_modal_menu(str(hud.actor(state.party.recipient_id).name) + " · " + str(hud.TITLES[hud.category_index]), "Choose an order. Time stays paused.
L3 / R3 or [ / ] switches companions.", buttons)

func _cycle_selection(direction: int) -> void:
	_selecting = false
	_cancel_target()
	_close_modal(false)
	_cycle_actor(direction)
	_open_selector()

func _choose_action(id: String, source_id := "") -> void:
	# World default attack prefers the real equipped weapon. Explicit action-bar
	# selections retain their exact source, including a blocked/lost binding.
	if source_id == "" and id == "basic":
		for candidate in state.actions:
			if candidate.id == id and candidate.available and str(candidate.source_id).begins_with("item:"):
				source_id = str(candidate.source_id)
				break
	for action in state.actions:
		if str(action.id) != id or (source_id != "" and str(action.source_id) != source_id):
			continue
		if not action.available:
			var reasons := PackedStringArray()
			for reason in action.reasons:
				reasons.append(str(reason.message))
			hud.show_message(" · ".join(reasons))
			return
		var selecting := _selecting
		_selecting = false
		_cancel_target()
		_selecting = selecting
		_pending_ability = action.duplicate(true)
		_pending_ability.actor_id = state.party.recipient_id
		if action.target_kind in ["self", "none"]:
			_queue_target({"kind": action.target_kind, "actor_id": null, "position": null})
		elif action.target_kind == "enemy":
			if _valid_aim_target().is_empty(): _cycle_target()
			if not _valid_aim_target().is_empty(): _confirm_aim()
			else: _begin_aim()
		else:
			_begin_aim()
		return

func _choose_item_target(actor_id: String) -> void:
	_pending_ability = {"actor_id": actor_id, "target_kind": "ally", "name": "Field dressing"}
	_begin_aim()

func _queue_target(target: Dictionary) -> void:
	if _pending_ability.is_empty():
		return
	var action: Dictionary
	if _pending_item != "":
		action = {"kind": "inventory.use", "actor_id": _pending_ability.actor_id, "item_id": _pending_item, "target": target}
	else:
		action = {"kind": "queue.enqueue", "actor_id": _pending_ability.actor_id, "ability_id": _pending_ability.id, "source_id": _pending_ability.source_id, "target": target}
	var receipt := submit(action)
	if receipt.get("status") == "accepted":
		_cancel_target()

func _cancel_target() -> void:
	if not _pending_ability.is_empty():
		_pending_ability.clear()
		_pending_item = ""
		stage.markers.aim_text = ""
		_close_modal(false)
		_release("targeting")
		if is_instance_valid(ledger):
			ledger.show()
		if _selecting:
			_selecting = false
			_close_modal()

func _modal_menu(title: String, copy: String, buttons: Array) -> void:
	_close_modal(false)
	if is_instance_valid(ledger):
		ledger.interaction_enabled = false
	_modal = PanelContainer.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal.offset_left = -260
	_modal.offset_right = 260
	var height := minf(660, 150 + buttons.size() * 48)
	_modal.offset_top = -height * .5
	_modal.offset_bottom = height * .5
	_modal.add_theme_stylebox_override("panel", UI.style(Color("0a171b"), UI.BRASS, 2))
	_layer.add_child(_modal)
	preload("res://scripts/chapter_voice.gd").attach(_modal, copy)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_modal.add_child(column)
	column.add_child(UI.label(title, 26, UI.INK, true))
	column.add_child(UI.label(copy, 18, UI.MUTED))
	var button_parent: Node = column
	if buttons.size() > 9:
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		column.add_child(scroll)
		var content := VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 8)
		scroll.add_child(content)
		button_parent = content
	var first: Button
	var controls: Array[Button] = []
	for entry in buttons:
		var callback: Callable = entry[1]
		var button := UI.button(str(entry[0]), func() -> void: callback.call_deferred())
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 18)
		button_parent.add_child(button)
		controls.append(button)
		if first == null:
			first = button
	if first != null:
		for index in range(controls.size()):
			var button := controls[index]
			button.focus_neighbor_top = button.get_path_to(controls[posmod(index - 1, controls.size())])
			button.focus_neighbor_bottom = button.get_path_to(controls[posmod(index + 1, controls.size())])
			button.focus_previous = button.focus_neighbor_top
			button.focus_next = button.focus_neighbor_bottom
			button.focus_neighbor_left = button.get_path_to(button)
			button.focus_neighbor_right = button.get_path_to(button)
		first.grab_focus()

func _close_modal(release := true) -> void:
	if is_instance_valid(_modal):
		_layer.remove_child(_modal)
		_modal.queue_free()
	_modal = null
	if is_instance_valid(ledger):
		ledger.interaction_enabled = true
	if release:
		_selecting = false
		_release("selector")

func _confirm(action: Dictionary, title: String, copy: String) -> void:
	_stop_movement()
	_acquire("selector")
	_modal_menu(title, copy, [["Confirm", func() -> void:
		submit(action)
		_close_modal()], ["Cancel", _close_modal]])

func _preview_change(action: Dictionary) -> void:
	_acquire("selector")
	var envelope := {"schema": "command.preview/v1", "generation": state.session.generation, "expected_revision": state.session.revision, "action": action}
	var result := _call("preview", [JSON.stringify(envelope)])
	if not result.get("ok", false):
		_release("selector")
		return
	var reasons := PackedStringArray()
	for reason in result.data.get("reasons", []):
		reasons.append(str(reason.message))
	if not result.data.get("available", false):
		_modal_menu("Cannot make this change", "\n".join(reasons), [["Back", _close_modal]])
		return
	var projected: Dictionary = result.data.view
	var before: Dictionary = hud.actor(str(state.party.inspected_id))
	var after: Dictionary = {}
	for actor in projected.actors:
		if actor.id == before.get("id"):
			after = actor
	var changes := PackedStringArray([str(action.kind).replace(".", " · ").capitalize()])
	if action.kind == "party.deploy":
		var names := PackedStringArray()
		for id in action.actor_ids:
			names.append(str(hud.actor(str(id)).get("name", id)))
		changes = PackedStringArray(["Enter the garden with " + ", ".join(names) + "."])
	if not before.is_empty() and not after.is_empty():
		for key in ["defense", "attack", "power_dc"]:
			if before.stats.get(key) != after.stats.get(key):
				changes.append("%s: %s → %s" % [key.capitalize(), before.stats.get(key), after.stats.get(key)])
		for key in ["health", "focus"]:
			if before.get(key) != after.get(key) and after.get(key) != null:
				changes.append("%s: %d / %d → %d / %d" % [key.capitalize(), before[key].current, before[key].maximum, after[key].current, after[key].maximum])
	changes.append("Confirm this change?")
	_confirm(action, "Apply this change?", "\n".join(changes))

func _open_ledger() -> void:
	if is_instance_valid(ledger):
		_close_ledger()
		return
	_cancel_target()
	_stop_movement()
	_acquire("ledger")
	ledger = load("res://scripts/command_ledger.gd").new()
	_layer.add_child(ledger)
	ledger.requested.connect(_request)
	submit({"kind": "party.inspect", "actor_id": state.party.recipient_id})
	ledger.open(state)

func _close_ledger() -> void:
	_close_modal()
	if is_instance_valid(ledger):
		_layer.remove_child(ledger)
		ledger.queue_free()
	ledger = null
	_release("ledger")

func _open_camp() -> void:
	_stop_movement()
	_acquire("selector")
	var completed: bool = state.encounter.outcome == "victory"
	_modal_menu("The guards are down" if completed else "Garden camp", CHAPTER.story().discovery if completed else "Prepare the party before entering the garden.", [
		["Replay chapter" if completed else "Enter the garden", func() -> void:
			_close_modal()
			submit({"kind": "encounter.start", "encounter_id": "garden_patrol"})],
		["Equipment & powers", func() -> void: _close_modal(); _open_ledger()],
		["Choose companions", func() -> void: _close_modal(); _open_ledger(); ledger._select_tab(3)],
		["Combat controls", _open_controls],
		["Audio", func() -> void: preload("res://scripts/game_audio.gd").ensure(self).open_settings()],
		["Load chapter", func() -> void: _close_modal(); _load()],
		["Return", _exit_trial]])

func _open_outcome() -> void:
	if _closing: return
	var won: bool = state.encounter.status == "won"
	if won and campaign_mode:
		_closing = true
		_finish.call_deferred()
		return
	var buttons: Array = []
	if won:
		buttons.append(["Return to camp", func() -> void:
			_close_modal()
			submit({"kind": "camp.enter", "camp_id": "garden_camp"})
			_open_camp()])
	else:
		buttons.append(["Retry from encounter checkpoint", func() -> void:
			_close_modal()
			submit({"kind": "encounter.retry", "checkpoint_id": state.encounter.checkpoint_id})
			_tokens.clear()
			_remainder = 0.0])
	buttons.append(["Party sheet", func() -> void: _close_modal(); _open_ledger()])
	buttons.append(["Return to quay" if campaign_mode else "Return to menu", _exit_trial])
	_modal_menu("The guards are down" if won else "Party defeated", CHAPTER.story().discovery + "\n\n" + CHAPTER.story().resolution if won else "Return to the gate and try again, or load a save.", buttons)

func _save() -> void:
	var result := _call("save_json")
	if not result.get("ok", false):
		return
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		_error("Could not save this chapter.")
		return
	file.store_string(result.data.save)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path))
	hud.show_message("Chapter saved." if error == OK else "Save failed: " + error_string(error))

func _load() -> void:
	if not FileAccess.file_exists(save_path):
		_error("No save exists for this chapter.")
		return
	var result := _call("restore_json", [FileAccess.get_file_as_string(save_path)])
	if not result.get("ok", false):
		return
	_tokens.clear()
	_pending_ability.clear()
	_pending_item = ""
	_selecting = false
	_last_direction = Vector2.ZERO
	_stick = Vector2.ZERO
	_trigger_down = false
	_remainder = 0.0
	_close_modal(false)
	if is_instance_valid(ledger):
		_layer.remove_child(ledger)
		ledger.queue_free()
		ledger = null
	_publish(result.data)
	_refresh()
	_modal_menu("Chapter loaded", "Time is paused. Review the party before resuming.", [["Continue", _close_modal], ["Party sheet", func() -> void: _close_modal(); _open_ledger()]])

func _exit_trial() -> void:
	if campaign_mode and has_won():
		_finish()
		return
	if state.session.phase == "camp":
		var receipt := submit({"kind": "profile.prepare_exit"})
		if receipt.get("status") == "accepted":
			_finish()
			return
	_acquire("selector")
	var destination := "Return to quay" if campaign_mode else "Return to menu"
	_modal_menu(destination + "?", "Unsaved chapter progress will be lost.", [[destination, _finish], ["Stay", _close_modal]])

func _finish() -> void:
	_closing = true
	bridge = null
	finished.emit()

func _stop_movement() -> void:
	_stick = Vector2.ZERO
	if _last_direction != Vector2.ZERO and not state.is_empty() and state.party.possessed_id != null:
		submit({"kind": "movement.intent", "actor_id": state.party.possessed_id, "direction": [0, 0]})
	_last_direction = Vector2.ZERO

func _update_movement() -> void:
	if state.party.possessed_id == null:
		return
	var actor: Dictionary = hud.actor(str(state.party.possessed_id))
	if actor.get("active_action") != null:
		return
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if _stick.length() > .2:
		input = _stick
	var world: Vector3 = stage.camera.global_basis.x * input.x + stage.camera.global_basis.z * input.y
	var direction := Vector2(world.x, world.z).normalized() if input.length() > .2 else Vector2.ZERO
	if direction.distance_to(_last_direction) < .08:
		return
	_last_direction = direction
	submit({"kind": "movement.intent", "actor_id": state.party.possessed_id, "direction": [direction.x, direction.y]})

func _seed_preview() -> void:
	submit({"kind": "encounter.start", "encounter_id": "garden_patrol"})
	for order in [["player", "lunge", "hound"], ["player", "basic", "hound"], ["mara", "binding_current", "hound"], ["mara", "gale_arc", "hound"], ["clerk", "disrupt_device", "sentinel"], ["clerk", "pinning_bolt", "sentinel"]]:
		submit({"kind": "party.select", "actor_id": order[0]})
		for action in state.actions:
			if action.id == order[1]:
				var point := [2.0, 0.0] if order[2] == "hound" else [6.0, 2.0]
				var target := {"kind": "point", "actor_id": null, "position": point} if action.target_kind == "point" else {"kind": "actor", "actor_id": order[2], "position": null}
				submit({"kind": "queue.enqueue", "actor_id": order[0], "ability_id": action.id, "source_id": action.source_id, "target": target})
				break
	submit({"kind": "party.select", "actor_id": "mara"})
	hud.set_category(1)

func _restart_preview() -> void:
	var result := _call("create", [seed_value])
	if result.get("ok", false):
		_tokens.clear()
		_publish(result.data)
		_preview_elapsed = 0.0
		_preview_terminal = 0.0
		_preview_resumed = false
		_seed_preview()

func _consume_input() -> void:
	# Consume inside the rendered viewport before its focused buttons see A or
	# Enter; consuming only the parent allowed a second unrelated activation.
	viewport.set_input_as_handled()
	get_viewport().set_input_as_handled()

func _handle_input(event: InputEvent) -> void:
	if preview_mode or _closing or bridge == null or not is_visible_in_tree():
		return
	if event is InputEventKey and event.is_action_pressed("camera_recenter") and _modal == null and ledger == null:
		stage.recenter_camera()
		_consume_input()
		return
	if event is InputEventKey and event.echo:
		_consume_input()
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_controller = Input.get_connected_joypads().has(event.device)
	elif event is InputEventKey or event is InputEventMouseButton:
		_controller = false
	if hud.has_method("set_input_device"):
		hud.set_input_device(_controller)
	var back: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		if not _pending_ability.is_empty(): _cancel_target()
		elif _modal != null: _close_modal()
		elif ledger != null: _close_ledger()
		else:
			for body in stage.actors.values():
				if body.has_node("Weapon"): body.get_node("Weapon").set_readied(false)
		_consume_input()
		return
	if not _pending_ability.is_empty():
		var aim_handled := false
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_T: _cycle_target(-1 if event.shift_pressed else 1); aim_handled = true
				KEY_ENTER, KEY_KP_ENTER, KEY_E: _confirm_aim(); aim_handled = true
		elif event is InputEventJoypadButton and event.pressed:
			match event.button_index:
				JOY_BUTTON_LEFT_SHOULDER: _cycle_target(-1); aim_handled = true
				JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_Y: _cycle_target(1); aim_handled = true
				JOY_BUTTON_A: _confirm_aim(); aim_handled = true
		elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var pressed: bool = event.axis_value > .5
			if pressed and not _trigger_down: _confirm_aim()
			_trigger_down = pressed
			aim_handled = true
		if aim_handled: _consume_input()
		return
	if _modal != null:
		# Target selection is reversible; confirmation dialogs keep the chosen actor.
		if not _pending_ability.is_empty() or _selecting:
			var cycle := 0
			if event is InputEventJoypadButton and event.pressed:
				if event.button_index == JOY_BUTTON_LEFT_STICK: cycle = -1
				if event.button_index == JOY_BUTTON_RIGHT_STICK: cycle = 1
				if _selecting and _pending_ability.is_empty() and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
					hud.set_category(hud.category_index + (-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1))
					_open_selector()
					_consume_input()
					return
			elif event is InputEventKey and event.pressed:
				if event.keycode == KEY_BRACKETLEFT: cycle = -1
				if event.keycode in [KEY_TAB, KEY_BRACKETRIGHT]: cycle = 1
				if _selecting and _pending_ability.is_empty() and event.keycode in [KEY_Q, KEY_E]:
					hud.set_category(hud.category_index + (-1 if event.keycode == KEY_Q else 1))
					_open_selector()
					_consume_input()
					return
			if cycle != 0:
				_cycle_selection(cycle)
				_consume_input()
		return
	if ledger != null:
		if ledger.handle_input(event): _consume_input()
		return
	var handled := false
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_H: _open_controls(); handled = true
			KEY_SPACE: _toggle_pause(); handled = true
			KEY_TAB: _cycle_actor(1); handled = true
			KEY_I, KEY_C: _open_ledger(); handled = true
			KEY_F1, KEY_F2, KEY_F3:
				var index: int = event.keycode - KEY_F1
				if index < state.party.deployed_ids.size(): _request({"kind": "party.possess", "actor_id": state.party.deployed_ids[index], "select": true})
				handled = true
			KEY_BRACKETLEFT: _cycle_actor(-1); handled = true
			KEY_BRACKETRIGHT: _cycle_actor(1); handled = true
			KEY_Q: _open_selector(); handled = true
			KEY_E: _context_action("basic"); handled = true
			KEY_T: _cycle_target(-1 if event.shift_pressed else 1); handled = true
			KEY_X: _request({"kind":"ui.stop"}); handled = true
			KEY_BACKSPACE: _confirm({"kind":"queue.clear_future", "actor_id":state.party.recipient_id}, "Clear future orders?", "Release all waiting reservations. The current action continues."); handled = true
			KEY_F5: _save(); handled = true
			KEY_F9: _load(); handled = true
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_6:
					hud.choose_number(event.keycode - KEY_1)
					handled = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_START: _open_ledger(); handled = true
			JOY_BUTTON_BACK: _toggle_pause(); handled = true
			JOY_BUTTON_LEFT_SHOULDER: _cycle_target(-1); handled = true
			JOY_BUTTON_RIGHT_SHOULDER: _cycle_target(1); handled = true
			JOY_BUTTON_X: _open_selector(); handled = true
			JOY_BUTTON_Y: _cycle_target(); handled = true
			JOY_BUTTON_LEFT_STICK: _cycle_actor(-1); handled = true
			JOY_BUTTON_RIGHT_STICK: _cycle_actor(1); handled = true
	elif event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_LEFT_X: _stick.x = event.axis_value
			JOY_AXIS_LEFT_Y: _stick.y = event.axis_value
			JOY_AXIS_RIGHT_X: _orbit_stick.x = event.axis_value
			JOY_AXIS_RIGHT_Y: _orbit_stick.y = event.axis_value
			JOY_AXIS_TRIGGER_RIGHT:
				var pressed: bool = event.axis_value > .5
				if pressed and not _trigger_down: _context_action("basic")
				_trigger_down = pressed
				handled = true
	if handled:
		_consume_input()

func _world_input(event: InputEvent) -> void:
	if preview_mode or _closing or bridge == null or (ledger != null and _pending_ability.is_empty()) or _modal != null:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		stage.orbit(event.relative)
		viewport.set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			stage.zoom(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var target: Dictionary = stage.pick(event.position)
			if not _pending_ability.is_empty():
				if _pending_ability.get("target_kind") == "point" and target.get("kind") == "actor":
					target = {"kind": "point", "actor_id": null, "position": hud.actor(str(target.actor_id)).position}
				if target.get("kind") == "actor":
					submit({"kind":"target.select", "target_id":target.actor_id})
					if event.double_click: _confirm_aim()
				elif _pending_ability.get("target_kind") == "point":
					_queue_target(target)
			elif target.get("kind") == "actor":
				var actor: Dictionary = hud.actor(str(target.actor_id))
				if actor.get("faction") == "party":
					_request({"kind": "party.possess", "actor_id": actor.id, "select": true})
				else:
					submit({"kind":"target.select", "target_id":actor.id})
					if event.double_click:
						_context_action("basic")
		viewport.set_input_as_handled()

func has_won() -> bool:
	return _chapter_won

func _open_controls() -> void:
	_stop_movement()
	_acquire("selector")
	var text := "LB / RB · Previous / next enemy\nRT · Queue attack   X · Choose actions\nL3 / R3 · Switch companion\nView · Pause / resume   Menu · Party sheet\nLeft stick · Move   Right stick · Orbit camera\nA · Confirm aimed action   B · Cancel aim" if _controller else "T / Shift+T · Next / previous enemy\nE · Queue attack   1–6 · Action bar   Q · All actions\nTab / F1–F3 · Switch companion\nSpace · Pause / resume   I · Party sheet\nWASD · Move   Right mouse drag · Orbit camera\nEnter · Confirm aimed action   Esc · Cancel aim\nBackspace · Clear queued orders   X · Disengage"
	text += "\n\nChoose an enemy, queue actions, then resume.\nCompanions act on their own until you take control.\nCombat pauses when your character needs new orders."
	_modal_menu("Command controls", text, [["Back", _close_modal]])
	_modal.offset_top = -310
	_modal.offset_bottom = 310
