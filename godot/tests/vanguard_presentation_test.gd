extends SceneTree
## Native menu-entry regression: rendered pixels, cinematic gait, observed cover.
var failures := 0
var checks := 0
var trial: Control
var output := "/tmp/oathshaper-vanguard-presentation"

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1; push_error(message)

func frames() -> void:
	await process_frame
	await process_frame

func snapshot(label: String) -> Image:
	await frames()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(output + "-" + label + ".png")
	return image

func key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames()

func tap(code: Key) -> void:
	await key(code)
	await key(code, false)

func aim_at(id: String) -> void:
	var target: Vector3 = trial.stage.actors[id].position + Vector3(0, 1.2, 0)
	for attempt in 5:
		trial.stage._position_camera()
		var direction: Vector3 = (target - trial.stage.camera.global_position).normalized()
		trial.stage.yaw = atan2(-direction.x, -direction.z)
		trial.stage.pitch = asin(direction.y)

func rendered_overlay(label: String) -> void:
	trial._layer.hide()
	var world := await snapshot(label + "-world")
	trial._layer.show()
	var image := await snapshot(label)
	var center := image.get_size() / 2
	var ink := image.get_pixelv(center + Vector2i(0, -12))
	var under := world.get_pixelv(center + Vector2i(0, -12))
	check(ink.r > .75 and ink.g > .7 and ink.v - under.v > .2, label + " crosshair is drawn at the actual screen center above the world")
	var darkened := 0
	for x in range(24, image.get_width() - 24, 16):
		for y in range(image.get_height() - 145, image.get_height() - 24, 16):
			if world.get_pixel(x, y).v - image.get_pixel(x, y).v > .15: darkened += 1
	check(darkened > 50, label + " HUD panel pixels cover the 3D view")

func run() -> void:
	create_timer(75).timeout.connect(func() -> void: push_error("Vanguard presentation timeout"); quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	root.size = Vector2i(1280, 800)
	var main := preload("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._frontend._selected = "vanguard"
	main._frontend.trial_requested.emit()
	trial = main._trial
	trial.set_process(false)
	var scene: Node3D = trial._confrontation
	check(scene != null and not trial.can_process(), "Real menu launch enters the cinematic with gameplay frozen")
	for shot in 3:
		scene._remaining = 0
		await frames()
		await create_timer(.2).timeout
		for id in ["player", "mara", "ivo"]:
			var body: CharacterBody3D = trial.stage.actors[id]
			var slot = body.get_node("ModelSlot")
			check(body.velocity == Vector3.ZERO and slot._animation_player.current_animation in [slot._idle_clip, slot._talk_clip], "%s stands or talks during intro shot %d" % [id, shot])
		if shot == 1: await snapshot("intro")
	scene._remaining = 0
	await frames()
	check(trial._confrontation == null and trial.state.status == "engaged", "Natural intro completion enters combat")
	check(trial._layer.layer > trial.get_canvas_layer_node().layer, "Menu-hosted world cannot cover its HUD")
	await rendered_overlay("combat")
	root.size = Vector2i(1600, 900)
	await frames()
	await rendered_overlay("wide")
	root.size = Vector2i(1280, 800)
	await tap(KEY_TAB)
	check(trial._modal != null and trial.state.pauses.has("wheel"), "Squad menu opens through native keyboard input")
	await snapshot("squad")
	await tap(KEY_TAB)
	check(trial._modal == null and not trial.state.paused, "Squad menu returns control to combat")
	# Use the real movement proposal and core acceptance path to the west face
	# of the east planter. No actor coordinates or combat resources are patched.
	trial.stage.yaw = -PI / 2
	await key(KEY_W)
	for tick in 54: trial._process(1.0 / 60)
	trial.stage.yaw = 0
	for tick in 60: trial._process(1.0 / 60)
	await key(KEY_W, false)
	trial._process(1.0 / 60)
	check("Take cover" in trial._cover_hint.text and trial.stage._cover_marker.visible, "Approaching the planter offers cover and draws its floor marker")
	await aim_at("hound")
	await snapshot("cover-ready")
	await tap(KEY_SPACE)
	trial._process(1.0 / 60)
	check(trial.state.actors.player.cover and "Leave cover" in trial._cover_hint.text, "Space enters cover and changes the contextual control")
	check(not trial.state.visible.has("hound:player"), "Planter blocks enemy sight to the tucked player")
	check(trial.stage.actors.player.get_node("ModelSlot").position.y < 0, "Covered actor lowers behind the planter")
	await snapshot("cover")
	var aim := InputEventMouseButton.new()
	aim.button_index = MOUSE_BUTTON_RIGHT
	aim.pressed = true
	Input.parse_input_event(aim)
	await frames()
	trial._process(1.0 / 60)
	check(trial.state.aimed and trial.stage.actors.player.get_node("ModelSlot").position.y == 0, "RMB raises the player to peek over cover")
	check(trial.state.visible.has("player:hound") and trial.state.visible.has("hound:player"), "Peeking restores outgoing sight and exposes the player to return fire")
	check(trial.state.aim == "hound" and "Lantern Sentinel" in trial._target.text, "Reticle acquires the observed hostile and shows target vitals")
	await snapshot("peek")
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	fire.pressed = true
	Input.parse_input_event(fire)
	await frames()
	for tick in 15: trial._process(1.0 / 60)
	check(trial.state.actors.player.weapons[0].heat > 0, "Native trigger fires while peeking")
	fire.pressed = false
	Input.parse_input_event(fire.duplicate())
	aim.pressed = false
	Input.parse_input_event(aim.duplicate())
	await frames()
	trial._process(1.0 / 60)
	check(not trial.state.visible.has("hound:player"), "Releasing aim restores cover protection")
	await tap(KEY_SPACE)
	check(not trial.state.actors.player.cover, "Space leaves cover")
	# The shared cinematic also needs to stop a moving actor mid-encounter,
	# independently of the initial-spawn fix.
	var body: CharacterBody3D = trial.stage.actors.player
	body.velocity = Vector3(4, 0, 0)
	scene = preload("res://scripts/garden_confrontation.gd").play_trial(trial, func() -> void: pass)
	await create_timer(.3).timeout
	check(body.velocity == Vector3.ZERO and body.get_node("ModelSlot")._animation_player.current_animation == body.get_node("ModelSlot")._idle_clip, "Cinematic ownership stops an actor that was already moving")
	scene.finish()
	await frames()
	check(body.velocity == Vector3(4, 0, 0), "Cinematic releases the saved locomotion state")
	main.free()
	print("VANGUARD_PRESENTATION_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
