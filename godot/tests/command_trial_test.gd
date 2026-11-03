extends SceneTree
## Real launcher -> CommandBridge -> isolated garden -> native HUD/ledger.
var failures := 0
var checks := 0
var trial: Control
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
func joy(code: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)

func click_at(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()

func press_modal(caption: String) -> void:
	if trial._modal == null:
		check(false, "Expected visible Command dialog: " + caption)
		return
	for button in trial._modal.find_children("*", "Button", true, false):
		if button.text == caption:
			button.pressed.emit()
			return
	check(false, "Missing visible Command action: " + caption)
func modal_has_title(caption: String) -> bool:
	for label in trial._modal.find_children("*", "Label", true, false):
		if label.text == caption: return true
	return false
func _run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("Command test timed out"); quit(1))
	root.size = Vector2i(1280, 800)
	var main := preload("res://scripts/main.gd").new()
	main.save_path = "user://command-test-no-campaign.json"
	root.add_child(main)
	await settle()
	main._frontend._buttons[2].pressed.emit()
	await settle()
	trial = main._trial
	check(trial != null and not main._frontend.visible, "Title's visible trial button opens actual Command host")
	if trial == null or trial.state.is_empty():
		quit(1)
		return
	trial.save_path = "user://command-test-trial.json"
	trial.set_process(false)
	check(trial.state.session.phase == "camp", "Trial starts at camp")
	check(trial.hud.actor("player").health.maximum == 80, "Live Tessa Ward fixture")
	var weapon_actions: Array = trial.hud._visible_actions.map(func(a: Dictionary) -> String: return a.id)
	check(weapon_actions == ["brace", "basic", "lunge", "shield_bash"], "Tessa has four distinct weapon actions with Shield bash in slot four")
	check("interrupt" in trial.hud._buttons["action:shield_bash"].tooltip_text, "Shield bash explains its actual combat effect")
	check(trial.hud.actor("mara").health.maximum == 50 and trial.hud.actor("mara").focus.maximum == 56, "Distinct live Mara fixture")
	check(trial.hud.actor("clerk").health.maximum == 62, "Distinct live clerk fixture")
	await _capture("briefing")
	# The menu entry now starts with the voiced confrontation. Exercise its
	# Skip control; camp controls are tested separately by command_controls_test.
	check(is_instance_valid(trial._confrontation) and trial._modal == null, "Menu entry presents the confrontation without a briefing dialog")
	if not is_instance_valid(trial._confrontation):
		quit(1)
		return
	var skip_buttons: Array[Node] = trial._confrontation._subtitle_layer.find_children("*", "Button", true, false)
	check(skip_buttons.size() == 1 and "Skip" in skip_buttons[0].text, "Confrontation has a visible Skip control")
	if skip_buttons.is_empty():
		quit(1)
		return
	skip_buttons[0].pressed.emit()
	await settle()
	trial.set_process(false)
	check(trial.state.session.phase == "encounter" and trial.state.clock.paused, "Begin encounter pauses on contact")
	await _capture("tessa-actions")
	trial.hud._buttons["actor:mara"].pressed.emit()
	await settle()
	check(trial.state.party.recipient_id == "mara" and trial.state.party.possessed_id == "mara", "Portrait switches order recipient and possession")
	for entry in [["binding_current", {"kind":"point","actor_id":null,"position":[2.0,0.0]}], ["gale_arc", {"kind":"actor","actor_id":"hound","position":null}], ["mend", {"kind":"actor","actor_id":"player","position":null}]]:
		trial._request({"kind":"ui.choose_action","ability_id":entry[0]})
		check(trial._modal == null, "Ability keeps world visible: " + entry[0])
		if not trial._pending_ability.is_empty(): trial._queue_target(entry[1])
		await settle()
	var mara: Dictionary = trial.hud.actor("mara")
	check(mara.queue.size() == 3 and mara.focus.reserved == 44 and mara.focus.free == 12, "HUD reflects exact three-order reservations")
	trial._choose_action("veil")
	check(trial._pending_ability.is_empty() and trial.hud.actor("mara").focus.reserved == 44, "Unavailable Veil does not target or spend")
	var last: String = str(mara.queue[-1].id)
	trial.hud._buttons["queue:" + last].pressed.emit()
	await settle()
	trial.hud._buttons["queue_remove"].pressed.emit()
	await settle()
	check(trial.hud.actor("mara").focus.reserved == 28, "Cancel future order releases only its reservation")
	# Bumpers target actors without a dialog or changing possession.
	trial._choose_action("binding_current")
	var previous_target: String = trial.state.party.selected_target_id
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(trial.state.party.recipient_id == "mara" and not trial._pending_ability.is_empty(), "Bumper keeps order recipient while aiming")
	check(trial.state.party.selected_target_id != previous_target and trial._modal == null and trial.state.clock.paused, "Bumper cycles in-world target under owned pause")
	check(trial.hud.actor("mara").focus.reserved == 28, "Target cycling preserves prior reservations")
	await joy(JOY_BUTTON_B)
	check(trial._modal == null and trial._pending_ability.is_empty() and trial.state.clock.paused, "B cancels aim, preserving contact")
	await key(KEY_F2)
	check(trial.state.party.recipient_id == "mara", "F2 returns to Mara")
	trial._choose_action("binding_current")
	await settle()
	check(trial._modal == null and not trial._pending_ability.is_empty(), "Ground targeting needs no target list")
	var point: Vector2 = trial.stage.camera.unproject_position(Vector3(3.5, 0, 1.0))
	await click_at(point)
	check(trial._pending_ability.is_empty() and trial.hud.actor("mara").queue.size() == 3, "Actual garden pixel click commits ground target")
	if trial.hud.actor("mara").queue.size() == 3:
		trial.submit({"kind":"queue.remove", "actor_id":"mara", "action_id":trial.hud.actor("mara").queue[-1].id})
	else:
		trial._cancel_target()
	await key(KEY_I)
	check(is_instance_valid(trial.ledger), "Native I opens party ledger")
	check(trial.state.clock.pause_reasons.size() >= 2, "Ledger owns a separate pause from contact")
	trial._request({"kind":"party.inspect","actor_id":"ivo"})
	await settle()
	check(trial.state.party.inspected_id == "ivo" and trial.state.party.recipient_id == "mara", "Reserve inspection preserves recipient")
	await key(KEY_ESCAPE)
	check(trial.ledger == null and trial.state.clock.paused, "Back closes ledger but leaves contact pause")
	trial.hud.set_category(1)
	await _capture("contact")
	await key(KEY_SPACE)
	check(not trial.state.clock.paused, "Native Space acknowledges contact")
	for index in range(10):
		trial._process(.1)
		if int(trial.state.session.tick) >= 5:
			break
	check(int(trial.state.session.tick) >= 5, "Godot geometry drives actual fixed ticks")
	check(trial.hud.actor("mara").focus.current == 38, "Windup pays Bind once through shared resource ledger")
	await key(KEY_SPACE)
	check(trial.state.clock.paused, "Manual pause stops clock")
	trial._save()
	var generation: String = str(trial.state.session.generation)
	trial._load()
	check(str(trial.state.session.generation) != generation, "Load rotates live generation")
	check(trial.state.clock.paused and trial.hud.actor("mara").focus.current == 38, "Loaded paid windup stays paused without double charge")
	await key(KEY_ESCAPE)
	await key(KEY_SPACE)
	for index in range(40):
		trial._process(.1)
		if int(trial.state.session.tick) >= 15:
			break
	check(int(trial.state.session.tick) >= 15, "Restored observation cursor accepts fresh geometry")
	await _capture("combat")
	# Continue the actual seeded encounter using the same geometry, not a result fixture.
	for index in range(500):
		if trial.state.clock.paused and trial._modal == null: trial._toggle_pause()
		trial._process(.1)
		if index % 20 == 0: await settle()
		if trial.state.encounter.status in ["won", "lost"]: break
	FileAccess.open("/tmp/oathshaper-command-outcome-view.json", FileAccess.WRITE).store_string(JSON.stringify(trial.state))
	check(trial.state.encounter.status == "won", "Live party AI and queued orders win the seeded encounter")
	check(trial._modal != null, "Committed outcome opens recovery choices")
	if trial.state.encounter.status == "won":
		await _capture("outcome")
		var credits: int = trial.state.inventory.currency.credits
		var reward = trial.state.encounter.reward_receipt_id
		check(reward != null, "Victory commits a reward receipt")
		press_modal("Return to camp")
		await settle()
		check(trial.state.session.phase == "camp", "Outcome returns to camp")
		check(modal_has_title("The guards are down"), "Camp preserves the resolved story")
		check(trial.state.inventory.currency.credits == credits, "Camp does not award the encounter twice")
		# Inspect party, select clerk, then use the native shop/craft comparison.
		press_modal("Equipment & powers")
		await settle()
		trial._request({"kind":"party.inspect", "actor_id":"clerk"})
		trial.ledger._buttons["tab:Inventory"].pressed.emit()
		await settle()
		var craft_button: Button = trial.ledger._buttons.get("capability:craft_arc_edge")
		check(craft_button != null and not craft_button.disabled, "Clerk's inventory exposes legal workbench recipe")
		if craft_button != null and not craft_button.disabled:
			craft_button.pressed.emit()
			await settle()
			check(trial._modal != null and not trial.ledger.interaction_enabled, "Craft comparison owns nested modal and disables sheet input")
			var selected: String = trial.state.party.recipient_id
			await joy(JOY_BUTTON_RIGHT_STICK)
			check(trial.state.party.recipient_id == selected, "Confirmation cannot switch the paying actor")
			press_modal("Confirm")
			await settle()
			check(trial.state.inventory.currency.credits == credits - 20, "Confirmed workbench craft pays exact credits")
			var found := false
			for item in trial.state.inventory.items:
				if item.definition_id == "arc_edge": found = true
			check(found, "Crafted upgrade is an owned inventory instance")
		await _capture("inventory")
		await key(KEY_ESCAPE)
	# A malformed candidate must preserve current state and authority.
	var before := JSON.stringify(trial.state)
	var broken = JSON.parse_string(trial.bridge.restore_json("{}"))
	check(not broken.ok and JSON.stringify(trial.state) == before, "Corrupt save leaves live host unchanged")
	var trial_path: String = trial.save_path
	trial.hud._buttons["exit"].pressed.emit()
	await settle()
	check(main._trial == null and is_instance_valid(main._demo) and main._demo.visible, "Completed menu chapter returns to the garden")
	if is_instance_valid(main._demo):
		check(main._demo.has_node("GardenResolution"), "Garden return plays the post-battle resolution")
	check(not FileAccess.file_exists(main.save_path), "Trial never creates a campaign save")
	if FileAccess.file_exists(trial_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(trial_path))
	print("COMMAND_TRIAL_TEST: %d checks, %d failures" % [checks, failures])
	main.free()
	quit(1 if failures else 0)
func _capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/oathshaper-command-%s.png" % name)
	FileAccess.open("/tmp/oathshaper-command-%s.txt" % name, FileAccess.WRITE).store_string(_visible_copy(trial.hud))

func _visible_copy(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree():
		return ""
	var text := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	for child in node.get_children():
		text += _visible_copy(child)
	return text
