extends SceneTree
const SAVE := preload("res://scripts/save_store.gd")
var failures := 0
var checks := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
var path := "user://chapter-route-%s.json" % Time.get_ticks_usec()
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, description: String) -> void:
	evidence.record(description, value)
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func frames() -> void:
	await process_frame
	await process_frame
func choose(demo: Node, id: String) -> void:
	demo._choose(id)
	await frames()
	# Skip through the same presentation completion used by Back; the core
	# choice has already committed and must never be submitted a second time.
	if demo.panel._player_reply: demo.panel._finish_line()
	await frames()
func press_modal(trial: Node, caption: String) -> void:
	for button in trial._modal.find_children("*", "Button", true, false):
		if button.text == caption:
			button.pressed.emit()
			return
	check(false, "Missing visible chapter action: " + caption)
func run() -> void:
	var oil := "kept"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--oil="): oil = arg.trim_prefix("--oil=")
	if oil not in ["shared", "kept", "undecided"]:
		push_error("Unknown oil route: " + oil)
		quit(2)
		return
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 800)
	var main := preload("res://scripts/main.gd").new()
	main.save_path = path
	root.add_child(main)
	await frames()
	main._start_new("command")
	await frames()
	var demo = main._demo
	# Skip the opening through its native controller path before playing.
	var skip := InputEventJoypadButton.new()
	skip.button_index = JOY_BUTTON_B
	skip.pressed = true
	Input.parse_input_event(skip)
	await frames()
	skip.pressed = false
	Input.parse_input_event(skip)
	check(demo.mode == "explore" and not demo.has_node("QuayOpening"), "Opening releases the camera before gameplay")
	# Every optional oil branch must permit the robbery to be completed.
	demo._begin_dialogue("mara_greeting")
	if oil != "undecided": await choose(demo, "share_oil" if oil == "shared" else "keep_oil")
	demo._end_dialogue()
	check(demo.hub.is_beacon_lit() == (oil == "shared"), "Tower light agrees with the oil decision before the robbery")
	check(demo._objective_id() == "clerk", "Optional oil decision leaves the robbery objective intact")
	demo._enter_records_office()
	await frames()
	check(demo.records_office.visible and demo.get_node("CivicClerk").visible, "Clerk is inside the accessible office")
	check(demo._pay_chest.get_parent() == demo.records_office and not demo._pay_chest._coins.visible, "Ransacked chest starts empty in the office")
	demo._begin_dialogue("clerk_greeting")
	await choose(demo, "ask_robbery")
	demo._end_dialogue()
	check(demo._objective_id() == "mara", "Clerk establishes the robbery before recruitment")
	demo._leave_records_office()
	demo._begin_dialogue("mara_greeting")
	await choose(demo, "accept_help")
	demo._end_dialogue()
	check(demo._objective_id() == "garden_gate", "Agreeing to help directs the player to Ivo")
	check(not demo._story_state.flags.records_collected, "Optional history is not a combat gate")
	demo.player.global_position = demo._pay_loot.global_position
	check(demo._nearest_interactable().get("kind") != "pay_loot", "The guarded payroll cannot be collected before victory")
	demo._begin_dialogue("ivo_gate")
	await choose(demo, "open_gate")
	demo._end_dialogue()
	check(demo._story_state.flags.gate_open and demo._story_state.flags.oil_shared == (oil == "shared"), "Ivo opens the gate without changing the oil decision")
	check(demo._objective_id() == "garden", "Open gate directs party to garden entry")
	var clerk_home: Vector3 = demo.get_node("CivicClerk").position
	# Follow the actual routes in small steps. They must stay on authored floors,
	# and use their walk clips rather than sliding static NPCs to the gate.
	var saw_walk := false
	demo.player.position = Vector3(-5.5, 1.05, -26)
	for step in range(220):
		demo._rendezvous.advance(.1, null, demo.player)
		for id in ["Mara", "Ivo"]:
			var actor: Node3D = demo.get_node(id)
			var cell := Vector2i(floori(actor.position.x / 2.0) * 2, floori(actor.position.z / 2.0) * 2)
			check(demo.hub._walkable.has(cell), id + " stays on a quay floor or bridge")
			saw_walk = saw_walk or actor.get_node("ModelSlot").locomotion_speed > .1
		if demo._rendezvous.assembled(): break
	check(saw_walk and demo._rendezvous.assembled(), "Companions visibly walk to the gate")
	check(demo.get_node("Mara").position.distance_to(demo.GARDEN_ENTRY) < 6.0, "Mara arrives at the garden gate")
	check(demo.get_node("Ivo").position.distance_to(demo.GARDEN_ENTRY) < 6.0, "Ivo joins the gate assembly")
	check(demo.get_node("CivicClerk").position == clerk_home, "The optional clerk stays at the archive")
	if OS.get_cmdline_user_args().has("--capture"):
		demo.player.position = Vector3(24, 1.05, -2)
		demo.player.rotation.y = -PI / 2.0
		demo.camera_rig.focus_after_teleport(-90.0, false)
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-gate-rendezvous.png")
	demo.player.global_position = demo.GARDEN_ENTRY
	check(demo._nearest_interactable().get("kind") == "garden", "Garden entrance is a real nearby interaction")
	var input := InputEventKey.new()
	input.physical_keycode = KEY_E
	# Walk over the doorway plane without issuing an interaction command.
	demo.player.global_position = Vector3(32.1, 1.05, -2)
	await frames()
	check(main._confrontation != null and main._trial == null and demo.mode == "opening", "Crossing the doorway starts the in-world confrontation before combat")
	if main._confrontation != null:
		main._confrontation.finish()
		await frames()
	var trial = main._trial
	check(trial != null and trial.campaign_mode and not demo.visible, "Crossing the doorway opens the chapter without an interaction key")
	if trial == null:
		quit(1)
		return
	trial.set_process(false)
	check(trial.state.party.deployed_ids == ["player", "mara", "ivo"], "Mara and Ivo enter the garden with the player")
	check(trial.stage.actors.has("mara") and trial.stage.actors.has("ivo"), "Joined companions have actual 3D actors")
	check(trial._modal == null and trial.state.encounter.status == "active", "Confrontation hands off to combat without a briefing choice")
	await frames()
	trial._toggle_pause()
	for step in range(1000):
		# Play through the public attack path; this is not an AFK party test.
		var controlled: Dictionary = trial.hud.actor(str(trial.state.party.recipient_id))
		if controlled.get("conscious", false) and controlled.get("active_action") == null and controlled.queue.is_empty():
			trial._context_action("basic")
		if trial.state.clock.paused and trial.state.encounter.status == "active":
			trial._toggle_pause()
		trial._process(.1)
		if trial.state.encounter.status in ["won", "lost"]: break
		if step % 30 == 0: await frames()
	FileAccess.open("/tmp/oathshaper-chapter-route-outcome.json", FileAccess.WRITE).store_string(JSON.stringify(trial.state))
	check(trial.has_won(), "Earned combat victory reports chapter completion")
	await frames()
	check(main._trial == null and demo.visible and demo.process_mode == Node.PROCESS_MODE_INHERIT, "Victory automatically restores the cleared garden without a recovery dialog")
	check(demo.has_node("GardenResolution") and demo.mode == "opening" and not demo.player.enabled, "Victory starts a choiceless story scene before looting")
	if demo.has_node("GardenResolution"):
		var resolution = demo.get_node("GardenResolution")
		for line in range(3):
			resolution._process(resolution._remaining + .01)
			if line < 2:
				check(resolution._audio.stream != null, "Resolution line has an existing voiced performance")
				check(resolution._caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Resolution keeps the opening's left-aligned subtitles")
				if OS.get_cmdline_user_args().has("--capture"):
					await frames()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/tmp/oathshaper-resolution-%d.png" % line)
		await frames()
	check(demo.mode == "explore" and demo.player.enabled and not demo.has_node("GardenResolution"), "Resolution finishes on its timer and releases exploration")
	check(demo._objective_id() == "pay_loot", "Victory points to the chest without claiming it has been returned")
	var ivo_view: Dictionary = demo._call_bridge("begin_at", ["ivo_gate"]).data
	var obsolete := false
	for choice in ivo_view.choices:
		obsolete = obsolete or choice.id in ["ask_sentries", "ask_about_gate", "open_gate"]
	check(not obsolete and "guards are down" in ivo_view.text, "Earned victory retires Ivo preparation before payroll pickup")
	demo._call_bridge("end_dialogue")
	check(demo._pay_loot.visible and not demo._pay_chest._coins.visible, "Payroll is still on the defeated raider")
	check(demo._nearest_interactable().get("kind") == "pay_loot", "Victory returns within reach of the chest")
	check(demo._save() and demo._load() and demo._objective_id() == "pay_loot", "Uncollected victory survives save/load")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(demo.save_path)))
	var old_narrative: Dictionary = JSON.parse_string(old_save.narrative)
	old_narrative.state.flags.erase("raiders_defeated")
	old_save.narrative = JSON.stringify(old_narrative)
	var old_file := FileAccess.open(demo.save_path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old_save))
	old_file.close()
	check(demo._load() and demo._story_state.flags.raiders_defeated, "Existing revision-7 victory save derives the new fact from its chapter result")
	if OS.get_cmdline_user_args().has("--capture"):
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-stolen-chest.png")
	input.pressed = true
	Input.parse_input_event(input)
	await frames()
	input.pressed = false
	Input.parse_input_event(input)
	check(demo.mode == "dialogue", "Native interact opens the chest")
	await choose(demo, "take_pay")
	demo._end_dialogue()
	check(demo._objective_id() == "return_pay" and not demo._pay_loot.visible, "Picking up the chest changes its world and quest states")
	check(not demo._story_state.flags.pay_returned, "Collection is not a return")
	check(demo._save() and demo._load() and demo._objective_id() == "return_pay", "Carried chest survives save/load")
	demo._enter_records_office()
	await frames()
	demo._begin_dialogue("clerk_greeting")
	await choose(demo, "return_pay")
	demo._end_dialogue()
	await frames()
	check(demo.has_node("QuayEnding"), "Handing over payroll plays the lit tower ending")
	if demo.has_node("QuayEnding"): demo.get_node("QuayEnding").finish()
	check(demo.hub.is_beacon_lit() and demo.lamp.light_energy == 0, "Tower lights the quay, Mara emits no orange spill")
	check(demo._objective_id() == "robbery_done", "Handing payroll to the clerk completes the story")
	check(not demo._pay_loot.visible and demo._pay_chest._coins.visible, "Recovered coins appear in the office chest")
	check(demo._save(), "Completed chapter saves with journey")
	var saved = SAVE.load(path)
	check(saved.ok and saved.data.chapters.get("dockside_robbery", false), "Chapter result round-trips with narrative")
	demo._chapters.clear()
	check(demo._load() and demo._objective_id() == "robbery_done", "Reload restores the completed return")
	demo._begin_dialogue("clerk_greeting")
	var choices: Array = demo._call_bridge("view").get("data", {}).get("choices", [])
	check(choices.all(func(c): return c.id != "return_pay"), "Returned chest cannot be handed over twice")
	demo._end_dialogue()
	if OS.get_cmdline_user_args().has("--capture"):
		demo.camera_rig.focus_after_teleport(90.0, false)
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-pay-returned.png")
	var bad = saved.data.duplicate(true)
	bad.chapters.dockside_robbery = "true"
	var malformed_file := FileAccess.open(path, FileAccess.WRITE)
	malformed_file.store_string(JSON.stringify(bad))
	malformed_file.close()
	check(not SAVE.load(path).ok, "Reject malformed chapter progress")
	var old = saved.data.duplicate(true)
	old.schema = 2
	old.erase("chapters")
	malformed_file = FileAccess.open(path, FileAccess.WRITE)
	malformed_file.store_string(JSON.stringify(old))
	malformed_file.close()
	check(SAVE.load(path).ok and SAVE.load(path).data.chapters.is_empty(), "Existing schema2 journey remains loadable")
	malformed_file = FileAccess.open(path, FileAccess.WRITE)
	malformed_file.close()
	check(not SAVE.load(path).ok, "Empty save returns a load error without a parser diagnostic")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CHAPTER_ROUTE: %s checks, %s failures" % [checks, failures])
	evidence.finish("chapter-route", "Command chapter through native scene and gameplay methods; combat victory earned. Player approaches use fixture positioning, not a navigation bot.", {"oil": oil, "combat_style": "command", "final_objective": demo._objective_id()})
	quit(1 if failures else 0)
