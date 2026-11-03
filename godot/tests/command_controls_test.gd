extends SceneTree
## Real core + rendered controls. No synthetic combat view or direct health mutation.
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
var trial: Control

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	evidence.record(message, value)
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func frames() -> void:
	await process_frame
	await process_frame

func press_modal(caption: String) -> void:
	if trial._modal == null:
		check(false, "Expected modal: " + caption)
		return
	for button in trial._modal.find_children("*", "Button", true, false):
		if button.text == caption:
			button.pressed.emit()
			return
	check(false, "Missing modal button: " + caption)

func visible_copy(node: Node) -> String:
	if node is CanvasItem and not node.is_visible_in_tree():
		return ""
	var copy := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	for child in node.get_children():
		copy += visible_copy(child)
	return copy

func run() -> void:
	create_timer(60).timeout.connect(func() -> void: push_error("Command controls timed out"); quit(1))
	root.size = Vector2i(1280, 800)
	trial = preload("res://scripts/command_trial.gd").new()
	root.add_child(trial)
	await frames()
	trial.set_process(false)
	press_modal("Choose companions")
	await frames()
	check(trial.ledger != null and trial.ledger._tab == 3, "Gate offers real Party tab")
	trial.ledger._buttons["inspect:ivo"].pressed.emit()
	await frames()
	trial.ledger._buttons["deploy:ivo:replace:clerk"].pressed.emit()
	await frames()
	check(trial.state.party.deployed_ids == ["player", "mara", "clerk"], "Preview does not replace companion")
	press_modal("Confirm")
	await frames()
	check(trial.state.party.deployed_ids == ["player", "mara", "ivo"], "Confirm actually deploys Ivo")
	check(trial.stage.actors.has("ivo") and trial.stage.actors.ivo.visible and not trial.stage.actors.clerk.visible, "Scene shows selected companion and hides reserve")
	trial._close_ledger()
	trial._open_camp()
	press_modal("Enter the garden")
	await frames()
	check(trial.state.clock.paused, "Encounter pauses before the first orders")
	var enemies: Array = []
	for actor in trial.state.actors:
		if actor.faction == "hostile": enemies.append(actor.id)
	check(enemies.size() == 3, "All three adversaries are observable while paused after deployment")
	trial.hud._buttons.next_target.pressed.emit()
	await frames()
	var target: Dictionary = trial.hud.actor(str(trial.state.party.selected_target_id))
	check(not target.is_empty() and target.faction == "hostile", "Target control selects an actual visible enemy")
	check(trial.hud._target_name.text == target.name and trial.hud._target_health.max_value == target.health.maximum, "Enemy name and health come from the selected actor")
	trial.hud._buttons["context:basic"].pressed.emit()
	await frames()
	var player: Dictionary = trial.hud.actor("player")
	check(player.queue.size() == 1 and player.queue[0].target.actor_id == target.id, "Context action queues against selected enemy")
	check(trial._modal == null and trial.state.clock.paused, "Context order needs no second modal and preserves pause")
	trial.hud._buttons["actor:mara"].pressed.emit()
	await frames()
	check(trial.state.party.possessed_id == "mara", "Portrait takes control of Mara")
	trial.hud._buttons["context:binding_current"].pressed.emit()
	await frames()
	var mara: Dictionary = trial.hud.actor("mara")
	check(mara.queue.size() == 1 and mara.focus.reserved == 18, "Mara's contextual power reserves her own focus")
	check(mara.queue[0].target.kind == "point", "Area power uses selected enemy position")
	trial.hud.set_category(1)
	await frames()
	var bounds := Rect2(Vector2.ZERO, Vector2(1280, 800))
	for key in ["actor:player", "actor:mara", "actor:ivo", "pause", "ledger", "next_target", "context:basic", "action:binding_current", "clear", "stop"]:
		var button: Button = trial.hud._buttons[key]
		check(bounds.encloses(button.get_global_rect()), "Visible combat control fits Steam Deck: " + key)
	var copy := visible_copy(trial.hud)
	FileAccess.open("/tmp/oathshaper-command-hud.txt", FileAccess.WRITE).store_string(copy)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-hud-final.png")
	trial._open_ledger()
	trial._request({"kind":"party.inspect", "actor_id":"mara"})
	trial.ledger._select_tab(4)
	var dressing_id := ""
	for item in trial.state.inventory.items:
		if item.get("definition_id") == "dressing":
			dressing_id = str(item.id)
	check(not dressing_id.is_empty(), "Live party inventory contains field dressings")
	if not dressing_id.is_empty():
		trial.ledger._buttons["item:" + dressing_id].pressed.emit()
		await frames()
		check(trial.ledger._buttons.has("inventory_use") and not trial.ledger._buttons.inventory_use.disabled, "Real dressing has an enabled Use control")
		FileAccess.open("/tmp/oathshaper-command-inventory.txt", FileAccess.WRITE).store_string(visible_copy(trial.ledger))
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/oathshaper-command-inventory-final.png")
		trial.ledger._buttons.inventory_use.pressed.emit()
		await frames()
		trial.submit({"kind":"target.select", "target_id":"player"})
		check(trial._modal == null and not trial.ledger.visible, "Item targeting exposes the world instead of a dialog")
		trial._confirm_aim()
		await frames()
		mara = trial.hud.actor("mara")
		check(mara.queue.size() == 2 and mara.queue[1].ability_id == "dressing", "Inventory Use queues an actual dressing order")
		for item in trial.state.inventory.items:
			if item.id == dressing_id:
				check(item.reserved == 1 and item.free == item.quantity - 1, "Dressing reservation appears in real shared inventory")
	trial._close_ledger()
	trial._toggle_pause()
	for _i in range(30):
		trial._process(.1)
		if trial.hud.actor("ivo").get("active_action") != null: break
	var ivo: Dictionary = trial.hud.actor("ivo")
	check(ivo.get("active_action") != null and ivo.active_action.get("origin") == "ai", "Uncontrolled Ivo chooses an actual AI order")
	trial._request({"kind":"party.possess", "actor_id":"ivo", "select":true})
	await frames()
	check(not trial.hud._buttons.clear.disabled, "Current AI order can be cleared from HUD")
	trial._acquire("manual")
	trial.hud._buttons.clear.pressed.emit()
	await frames()
	ivo = trial.hud.actor("ivo")
	check(ivo.active_action == null and ivo.queue.is_empty(), "Clear cancels the AI order after taking control")
	var needs_orders := false
	for reason in trial.state.clock.pause_reasons:
		if reason.owner == "orders_empty": needs_orders = true
	check(needs_orders and trial.state.clock.paused, "Cleared controlled queue pauses for orders")
	check(trial.hud._status.text == "Ivo needs orders", "HUD explains the automatic pause")
	trial._choose_action("basic")
	ivo = trial.hud.actor("ivo")
	check(ivo.queue.size() == 1 and ivo.queue[0].origin == "player", "Player supplies an override through the action bar")
	trial._toggle_pause()
	check(not trial.state.clock.paused, "One Resume releases manual and empty-order pauses together")
	# Real viewport input with a focused Resume button: one press is one toggle.
	trial.hud._buttons.pause.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	check(trial.state.clock.paused, "Focused pause button plus native Space pauses exactly once")
	var serial: int = trial._serial
	event.echo = true
	Input.parse_input_event(event)
	await frames()
	check(trial._serial == serial and trial.state.clock.paused, "Held Space repeat does not toggle or submit again")
	event.echo = false
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()
	check(not trial.state.clock.paused, "One fresh Space press resumes without a second GUI toggle")
	print("COMMAND_CONTROLS: %d checks, %d failures" % [checks, failures])
	evidence.finish("command-controls", "Actual Command HUD and viewport events; scripted keyboard input, no physical controller verification.")
	quit(1 if failures else 0)
