extends SceneTree
const CINEMATIC := preload("res://scripts/garden_confrontation.gd")
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	evidence.record(message, value)
	if not value: failures += 1; push_error(message)
func frames() -> void:
	await process_frame
	await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 800)
	var demo := preload("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await frames()
	demo.player.position = Vector3(32.1, 1.05, -2)
	demo.player.set_physics_process(false)
	demo.hub.set_gate_open(true)
	demo.get_node("Mara").position = Vector3(28, 1.05, .6)
	demo.get_node("Ivo").position = Vector3(27, 1.05, -2)
	var before: String = demo.bridge.state_json()
	var poses := {}
	for id in ["Player", "Mara", "Ivo", "GardenWatch/corsair_raider"]:
		poses[id] = demo.get_node(id).transform
	var cinematic := CINEMATIC.new()
	cinematic.demo = demo
	demo.add_child(cinematic)
	check(demo.mode == "opening" and not demo.player.enabled, "Confrontation owns exploration controls")
	check(not demo.get_node("CanvasLayer").visible and root.get_camera_3d() == cinematic._camera, "Confrontation replaces exploration HUD and camera")
	var buttons := cinematic.find_children("*", "Button", true, false)
	check(buttons.size() == 1 and "Skip" in buttons[0].text, "Cutscene has only a skip control and no dialogue choices")
	check(cinematic._lines.size() == 3, "Confrontation uses all three existing story lines")
	for index in range(-1, 3):
		check(cinematic._index == index, "Shots advance in story order: %d" % index)
		if index >= 0:
			check(cinematic._audio.stream != null, "Exact voice clip exists for shot %d" % index)
			check(cinematic._remaining >= cinematic._audio.stream.get_length(), "Shot %d permits complete speech" % index)
			if index == 1: check(cinematic._speaker.text == "Tessa Ward", "Player's cinematic subtitle uses Tessa Ward")
		await create_timer(.15).timeout
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/oathshaper-confrontation-%d.png" % (index + 1))
		if OS.get_cmdline_user_args().has("--realtime"):
			await create_timer(cinematic._remaining + .02).timeout
		else:
			# Accelerate only the presentation clock; normal _process does the transition.
			cinematic._remaining = 0
		await frames()
	check(demo.mode == "explore" and demo.player.enabled, "Final voiced line automatically releases controls")
	check(demo.get_node("CanvasLayer").visible and root.get_camera_3d() == demo.camera_rig.camera, "Natural completion restores the HUD and exploration camera")
	check(demo.bridge.state_json() == before, "Watching the cutscene has no narrative side effects")
	for id in poses:
		check(demo.get_node(id).transform.is_equal_approx(poses[id]), "Staging restores actor transform: " + id)
	for controller in [false, true]:
		var skip_scene := CINEMATIC.new()
		skip_scene.demo = demo
		demo.add_child(skip_scene)
		var count := [0]
		skip_scene.finished.connect(func() -> void: count[0] += 1)
		var event: InputEvent
		if controller:
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_B
			pad.pressed = true
			event = pad
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.pressed = true
			event = key
		Input.parse_input_event(event)
		skip_scene.finish()
		await frames()
		check(count[0] == 1 and demo.mode == "explore", "Skip is idempotent and restores exploration: " + str(controller))
		check(demo.bridge.state_json() == before, "Skipping leaves story facts untouched: " + str(controller))
	demo.free()
	# Campaign entry owns the transition in every playable style.
	var main := preload("res://scripts/main.gd").new()
	main.save_path = "user://confrontation-no-save-%d.json" % Time.get_ticks_usec()
	root.add_child(main)
	main._start_new("command")
	await frames()
	main._demo.get_node("QuayOpening").finish()
	for profile in ["command", "flow", "vanguard"]:
		main._open_chapter(profile, true)
		check(main._confrontation != null and main._trial == null, profile + " stages the confrontation before creating combat")
		main._confrontation.finish()
		await frames()
		var trial: Control = main._trial
		check(trial != null and trial._modal == null, profile + " enters combat without a briefing modal")
		if profile == "command":
			check(trial.state.encounter.status == "active" and trial.state.clock.paused, "Command starts paused for initial orders")
			check(trial.hud.actor("player").name == "Tessa Ward", "Command combat uses the new player name")
		elif profile == "flow":
			check(trial.state.encounter.status == "encounter", "Flow starts its live encounter after the cutscene")
		else:
			check(trial.state.status == "engaged", "Vanguard starts its live encounter after the cutscene")
		main._close_command_trial()
		await frames()
	check(not FileAccess.file_exists(main.save_path), "Cinematic and combat entry never autosave the fixtures")
	main.free()
	main = preload("res://scripts/main.gd").new()
	root.add_child(main)
	for profile in ["command", "flow", "vanguard"]:
		main._frontend._selected = profile
		main._frontend.trial_requested.emit()
		await frames()
		var trial: Control = main._trial
		var intro: Node3D = trial._confrontation
		check(intro != null and trial._modal == null, profile + " menu entry opens the cinematic, not a text briefing")
		check(not trial.can_process() and intro.can_process(), profile + " cannot move or attack during the scene")
		check(not trial._layer.visible and trial.viewport.get_camera_3d() == intro._camera, profile + " hides combat HUD and owns the camera")
		check(intro._subtitle_layer.find_children("*", "Button", true, false).size() == 1, profile + " has Skip only, with no dialogue choices")
		for index in range(3):
			intro._next()
			await frames()
			check(intro._audio.stream != null, profile + " plays voice for story shot %d" % index)
			if OS.get_cmdline_user_args().has("--capture"):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/oathshaper-menu-confrontation-%s-%d.png" % [profile, index])
		# Command takes the automatic completion path; the live styles exercise
		# native root-viewport mouse/controller skip without input leakage.
		if profile == "command":
			intro._remaining = 0
		else:
			var skip: InputEvent
			if profile == "flow":
				var button: Button = intro._subtitle_layer.find_children("*", "Button", true, false)[0]
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = button.get_global_rect().get_center()
				click.pressed = true
				Input.parse_input_event(click)
				click = click.duplicate()
				click.pressed = false
				skip = click
			else:
				var pad := InputEventJoypadButton.new()
				pad.button_index = JOY_BUTTON_B
				pad.pressed = true
				skip = pad
			Input.parse_input_event(skip)
		await frames()
		check(trial._confrontation == null and trial.can_process(), profile + " hands off automatically to gameplay")
		check(trial._modal == null and trial._layer.visible, profile + " restores the HUD without a briefing or leaked Skip menu")
		check(trial.viewport.get_camera_3d() == trial.stage.camera, profile + " restores the combat camera")
		if profile == "command": check(trial.state.encounter.status == "active" and trial.state.clock.paused, "Menu Command starts paused for orders")
		elif profile == "flow": check(trial.state.encounter.status == "encounter", "Menu Flow starts live combat")
		else: check(trial.state.status == "engaged", "Menu Vanguard starts live combat")
		main._close_command_trial()
		await frames()
		check(main._frontend.visible and main._demo == null, profile + " returns to the menu without creating a campaign")
	main.free()
	evidence.finish("garden-confrontation", "Voiced shots, automatic handoff, native skip, restoration, and both campaign/menu startup for all three playable styles.", {"natural_playback": OS.get_cmdline_user_args().has("--realtime")})
	quit(1 if failures else 0)
