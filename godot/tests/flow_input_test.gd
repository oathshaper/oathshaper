extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)
func axis(trial: Control, which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = which
	event.axis_value = value
	trial._input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var trial = load("res://scripts/flow_trial.gd").new()
	root.add_child(trial)
	await process_frame
	trial.set_process(false)
	check(trial.bridge != null,"Actual Flow bridge loads")
	trial._close()
	axis(trial,JOY_AXIS_RIGHT_X,.7)
	axis(trial,JOY_AXIS_LEFT_Y,-.7)
	trial._trigger = true
	trial._guard = true
	trial._menu()
	check(trial._orbit == Vector2.ZERO and trial._stick == Vector2.ZERO,"Opening modal neutralizes camera and movement")
	check(not trial._trigger and not trial._guard,"Opening modal retires trigger and guard latches")
	axis(trial,JOY_AXIS_RIGHT_X,0)
	axis(trial,JOY_AXIS_LEFT_Y,0)
	axis(trial,JOY_AXIS_TRIGGER_RIGHT,0)
	axis(trial,JOY_AXIS_TRIGGER_LEFT,0)
	axis(trial,JOY_AXIS_RIGHT_Y,.8)
	check(trial._orbit == Vector2.ZERO,"Modal motion cannot arm a future orbit")
	trial._close()
	check(trial._orbit == Vector2.ZERO and trial._stick == Vector2.ZERO,"Release during modal remains neutral after dismissal")
	axis(trial,JOY_AXIS_RIGHT_X,.4)
	check(is_equal_approx(trial._orbit.x,.4),"Fresh world stick event resumes camera control")
	axis(trial,JOY_AXIS_RIGHT_X,0)
	check(trial._orbit == Vector2.ZERO,"Fresh release stops camera control")
	trial._begin_encounter()
	axis(trial,JOY_AXIS_LEFT_Y,1.0)
	check(trial._stick == Vector2.ZERO,"Paused stick input cannot latch walking")
	for code in [KEY_3,KEY_ENTER]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		await process_frame
	check(trial.state.hero.style == "harbor" and not trial.state.clock.paused,"Native 3 then Enter selects sword and begins")
	var before: Array = trial.hud.actor("player").position.duplicate()
	for i in range(30): trial.pump_tick()
	check(trial.hud.actor("player").position == before,"3 then Enter does not move Tessa")
	trial.submit({"kind":"dodge"})
	for i in range(12): trial.pump_tick()
	var landed: Array = trial.hud.actor("player").position.duplicate()
	check(landed != before,"Idle dodge travels backwards")
	for i in range(10): trial.pump_tick()
	check(trial.hud.actor("player").position == landed,"Idle dodge stops without a key release")
	trial._toggle_pause()
	axis(trial,JOY_AXIS_LEFT_Y,1.0)
	trial._toggle_pause()
	check(trial._stick == Vector2.ZERO,"Resume clears movement from pause")
	axis(trial,JOY_AXIS_LEFT_Y,1.0)
	check(trial._stick.y == 1.0,"Fresh post-resume stick input works")
	trial.queue_free()
	await process_frame
	print("FLOW_INPUT_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
