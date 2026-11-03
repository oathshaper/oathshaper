extends SceneTree
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	evidence.record(message, ok)
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await physics_frame
	await process_frame
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Playtest continuity timed out"); quit(1))
	root.size = Vector2i(1280, 800)
	var demo := preload("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await settle()
	demo.set_process(false)
	demo.player.enabled = false
	var rig = demo.camera_rig
	rig.focus_after_teleport(30, false)
	var orbit := InputEventMouseMotion.new()
	orbit.button_mask = MOUSE_BUTTON_MASK_RIGHT
	orbit.relative = Vector2(160, 0)
	rig._input(orbit)
	var chosen: float = rig.yaw
	check(absf(angle_difference(deg_to_rad(chosen), demo.player.rotation.y)) < .001, "Exploration manual orbit turns the actor toward the view")
	demo.player.rotation.y += .8
	for i in range(200): rig._update_exploration_follow(.1)
	check(absf(chosen - rig.yaw) < .001, "Manual exploration heading persists beyond the old grace period")
	check(demo.hub.find_children("*", "Label3D", true, false).is_empty(), "No floating environment labels outside")
	check(demo.records_office.find_children("*", "Label3D", true, false).is_empty(), "No floating environment labels in the office")
	# Exercise NPC turning against actual visual +Z, including its initial turn.
	demo.player.position = Vector3(-5.5, 1.05, -26)
	demo._rendezvous.reconcile({"mara_recruited":true,"gate_open":true})
	var mara: Node3D = demo.get_node("Mara")
	check(mara.get_node("ModelSlot")._walk_clip != &"", "Mara has a real weighted walk clip")
	check(demo.get_node("Ivo/ModelSlot")._walk_clip != &"", "Ivo has a real weighted walk clip")
	var moved := false
	for i in range(240):
		var before := mara.position
		demo._rendezvous.advance(.1, null, demo.player)
		var delta := mara.position - before
		delta.y = 0
		if delta.length() > .01:
			moved = true
			check(mara.basis.z.dot(delta.normalized()) > .15, "Mara moves toward her visible front")
		if demo._rendezvous.assembled(): break
	check(moved and demo._rendezvous.assembled(), "Mara and Ivo complete the walking rendezvous")
	# Recovered party follows the player's travelled path across the court bridge.
	demo.player.position = Vector3(28, 1.05, 0)
	demo._rendezvous.follow_after_battle(demo.player, Vector3(29.8, 1.05, 0), Vector3(48, 1.6, -2))
	var last := mara.position
	for target in [Vector3(22, 1.05, 0), Vector3(22, 1.05, -18), Vector3(2, 1.05, -18), Vector3(2, 1.05, -26), Vector3(-5.5, 1.05, -26)]:
		while demo.player.position.distance_to(target) > .01:
			demo.player.position = demo.player.position.move_toward(target, .3)
			demo._rendezvous.advance(.1, null, demo.player)
			check(mara.position.distance_to(last) < .7, "Ordinary follower travel has no discontinuities")
			last = mara.position
	var saved: Dictionary = demo._rendezvous.snapshot()
	check(preload("res://scripts/companion_rendezvous.gd").valid_snapshot(saved), "Travel snapshot validates")
	mara.position = Vector3.ZERO
	demo._rendezvous.restore(saved, {}, demo.player)
	check(mara.position.distance_to(last) < .001, "Save/load preserves companion position and pending trail")
	demo._enter_records_office()
	check(mara.position.x < 120 and not mara.visible, "Mara does not teleport into the office when the player enters")
	for i in range(300):
		demo._rendezvous.advance(.1, null, demo.player)
		demo._refresh_area_visibility()
		if mara.position.x > 120: break
	check(mara.position.x > 120 and mara.visible, "Mara reaches the doorway then enters behind the player")
	check(mara.position.distance_to(demo.player.position) < 3.0, "Office entry lands behind the player at the shared doorway")
	# A legacy save has no travel state: it must discard the current escort.
	demo._rendezvous.restore({}, {}, demo.player)
	var reset_position := mara.position
	demo.player.position = Vector3(24, 1, -2)
	for i in range(20): demo._rendezvous.advance(.1, null, demo.player)
	check(mara.position.is_equal_approx(reset_position) and mara.position.x < 10, "Loading a pre-recruitment legacy save clears the later escort route")
	demo.queue_free()
	await settle()
	# Native hint helper never advertises a disconnected controller.
	var holder := Control.new()
	root.add_child(holder)
	var label := Label.new()
	holder.add_child(label)
	var hints = preload("res://scripts/input_hints.gd").attach(holder)
	hints.bind(label, "Enter Continue", "A Continue")
	if Input.get_connected_joypads().is_empty(): check(label.text == "Enter Continue", "No gamepad glyphs without a connected device")
	holder.queue_free()
	# Actual geometry, actual rig and native camera. No screenshot proxy scene.
	var trial := preload("res://scripts/command_trial.gd").new()
	root.add_child(trial)
	await settle()
	trial.set_process(false)
	for button in trial._modal.find_children("*", "Button", true, false):
		if button.text == "Enter the garden": button.pressed.emit(); break
	await settle()
	var stage = trial.stage
	stage.orbit(Vector2(80, -12))
	var yaw: float = stage._yaw
	stage._manual_camera_until = 0
	for i in range(8): stage._position_camera()
	check(absf(stage._yaw - yaw) < .001, "Combat manual yaw is not overwritten by target framing")
	check(stage.has_node("CameraScenery") and stage.get_node("CameraScenery").get_child_count() > 0, "Camera uses imported garden geometry")
	var hidden := 0
	for turn in range(8):
		# Manual views now remain where the player puts them. Check automatic
		# obstruction recovery after explicit recenter, with its bounded search.
		stage.recenter_camera()
		stage._yaw = yaw + turn * .78
		var subjects: Array[Vector3] = stage._camera_subjects()
		for frame in range(240):
			stage._position_camera(1.0 / 60.0)
			if stage._visible_subjects(stage.camera.position, subjects) == subjects.size(): break
		if stage._visible_subjects(stage.camera.position, subjects) < subjects.size(): hidden += 1
	check(hidden == 0, "Automatic camera samples find clear controlled-actor and target views")
	# Paused rig must not keep adding rotations to the same pose.
	var body: Node3D = stage.actors.mara
	var skeleton := body.get_node("ModelSlot").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hand := skeleton.find_bone("RHand")
	await settle()
	var start := skeleton.get_bone_global_pose(hand)
	for i in range(20): await process_frame
	check(start.is_equal_approx(skeleton.get_bone_global_pose(hand)), "Paused Mara hand pose remains stable")
	var equipment = body.get_node("Weapon")
	var grip_error: float = equipment.pose.support_error * skeleton.global_basis.get_scale().x
	check(equipment.pose._blend > .99 and grip_error < .06, "Readied staff support hand meets its grip within six centimetres (%.3f m)" % grip_error)
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-playtest-camera.png")
	trial.queue_free()
	await settle()
	print("PLAYTEST_CONTINUITY: %d checks, %d failures" % [checks, failures])
	evidence.finish("travel-camera-grip", "Authored route samples, real rigs and camera queries. Fixture story setup; no exhaustive navigation or visual-quality proof.")
	quit(1 if failures else 0)
