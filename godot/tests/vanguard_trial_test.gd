extends SceneTree
var failures := 0
var checks := 0
var trial: Control
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await settle()
func aim_at(id: String) -> void:
	var target: Vector3 = trial.stage.actors[id].position + Vector3(0,1.2,0)
	for attempt in range(5):
		trial.stage._position_camera()
		var direction: Vector3 = (target - trial.stage.camera.global_position).normalized()
		trial.stage.yaw = atan2(-direction.x,-direction.z)
		trial.stage.pitch = asin(direction.y)
func _run() -> void:
	create_timer(50).timeout.connect(func() -> void: push_error("Vanguard test timeout"); quit(1))
	root.size = Vector2i(1280,800)
	trial = preload("res://scripts/vanguard_trial.gd").new()
	root.add_child(trial)
	await settle()
	if trial.state.is_empty():
		check(false,"Vanguard bridge loaded")
		quit(1)
		return
	trial.set_process(false)
	check(trial.state.status == "briefing", "Shared story briefing opens")
	trial._buttons["module:cooling"].pressed.emit()
	await settle()
	check(trial.state.actors.player.weapons[0].module == "cooling", "Staging module mutates actual weapon")
	await capture("briefing")
	trial._buttons.begin.pressed.emit()
	await settle()
	check(trial.state.status == "engaged" and not trial.state.paused, "Visible enter garden starts combat")
	# Aim the real camera at the hound center, then let the native host sample rays.
	var target: Vector3 = trial.stage.actors.hound.position + Vector3(0,1.2,0)
	var delta: Vector3 = target - trial.stage.actors.player.position - Vector3(0,1.55,0)
	trial.stage.yaw = atan2(-delta.x,-delta.z)
	trial.stage.pitch = -.035
	for attempt in range(5):
		trial.stage._position_camera()
		var direction: Vector3 = (target - trial.stage.camera.global_position).normalized()
		trial.stage.yaw = atan2(-direction.x,-direction.z)
		trial.stage.pitch = asin(direction.y)
	for i in range(3):
		trial._process(1.0/60.0)
		await settle()

	check(trial.state.aim == "hound", "Shoulder ray acquires observed hound")
	if trial.state.aim != "hound":
		quit(1)
		return
	await key(KEY_TAB)
	check(trial.state.paused and trial.state.pauses.has("wheel"), "Tab opens paused native squad selector")
	var tick: int = trial.state.tick
	trial._process(.1)
	check(int(trial.state.tick) == tick, "Wheel freezes simulation")
	await capture("wheel")
	trial._buttons["power:arc_overload"].pressed.emit()
	await settle()
	check(trial.state.actors.mara.pending != null and not trial.state.paused, "Mara power submits pending intent then resumes")
	check(trial.state.actors.player.id == "player", "Squad selection preserves protagonist")
	for i in range(20):
		trial._process(1.0/60.0)
		await settle()
	check(trial.state.actors.hound.shields == 0, "Observed overload strips hound shields")
	check(trial.state.actors.mara.cooldowns.has("arc_overload"), "Power has an individual cooldown")
	await key(KEY_TAB)
	trial._buttons["actor:ivo"].pressed.emit()
	await settle()
	trial._buttons["power:kinetic_throw"].pressed.emit()
	await settle()
	for i in range(24):
		trial._process(1.0/60.0)
		await settle()
	check(trial.state.actors.hound.position[0] > 6500, "Throw displacement uses host swept movement")
	await capture("combat")
	# Actual native firing path, with a cooling weapon; it can overheat on misses.
	var fire := InputEventMouseButton.new()
	fire.button_index = MOUSE_BUTTON_LEFT
	fire.pressed = true
	Input.parse_input_event(fire)
	await settle()
	for i in range(100):
		trial._process(1.0/60.0)
		if i % 12 == 0: await settle()
	fire.pressed = false
	Input.parse_input_event(fire)
	check(trial.state.actors.player.weapons[0].heat > 0, "Native trigger emits shots and creates heat")
	var heat: int = trial.state.actors.player.weapons[0].heat
	await key(KEY_Q)
	check(trial.state.actors.player.active == 1 and trial.state.actors.player.weapons[0].heat == heat, "Quick swap retains inactive weapon heat")
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(trial.state.pauses.has("wheel"), "Controller RB opens squad powers")
	await joy(JOY_BUTTON_B)
	check(not trial.state.paused, "Controller B closes only wheel pause")
	await key(KEY_ESCAPE)
	check(trial.state.pauses.has("menu"), "Escape opens menu pause")
	var ended := [false]
	trial.finished.connect(func() -> void: ended[0] = true)
	trial._buttons.leave.pressed.emit()
	check(ended[0], "Return emits finished lifecycle signal")
	check(not trial.has_won(), "Early leave cannot claim chapter victory")
	trial.queue_free()
	await settle()
	trial = preload("res://scripts/vanguard_trial.gd").new()
	root.add_child(trial)
	await settle()
	trial.set_process(false)
	trial._buttons.begin.pressed.emit()
	await settle()
	# Move through the actual input mapping to the west face of the east bed.
	trial.stage.yaw = -PI / 2
	var move := InputEventKey.new()
	move.physical_keycode = KEY_W
	move.pressed = true
	Input.parse_input_event(move.duplicate())
	await settle()
	for i in range(54): trial._process(1.0/60.0)
	trial.stage.yaw = 0
	for i in range(60): trial._process(1.0/60.0)
	move.pressed = false
	Input.parse_input_event(move.duplicate())
	await settle()
	await key(KEY_SPACE)
	check(trial.state.actors.player.cover, "Native movement reaches authored cover; Space tucks")
	trial._process(1.0/60.0)
	check(not trial.state.visible.has("hound:player"), "Planter physically blocks tucked player's incoming sight")
	await capture("cover")
	await joy(JOY_BUTTON_B)
	check(not trial.state.actors.player.cover and trial.state.draw, "Contextual B leaves cover without holstering")
	# Return down the clear lane before resolving the real encounter.
	trial.stage.yaw = PI
	move.pressed = true
	Input.parse_input_event(move.duplicate())
	await settle()
	for i in range(60): trial._process(1.0/60.0)
	move.pressed = false
	Input.parse_input_event(move)
	fire.pressed = true
	Input.parse_input_event(fire)
	for i in range(1800):
		if trial.state.status == "surrender":
			trial._confrontation.finish()
			trial._confrontation._choose_surrender(true)
			await settle()
		if trial.state.status in ["won", "lost"]: break
		var id := "hound" if trial.state.actors.hound.hp > 0 else "sentinel"
		if i % 8 == 0: aim_at(id)
		trial._process(1.0/60.0)
		if i % 60 == 0: await settle()
	check(trial.state.status == "won" and trial.has_won(), "Real firing and squad AI commit a victorious chapter")
	await capture("outcome")
	check(trial._closing and trial._modal == null, "Victory exits automatically without the old result modal")
	print("VANGUARD_TRIAL_TEST: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/oathshaper-vanguard-%s.png" % label)
