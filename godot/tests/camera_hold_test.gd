extends SceneTree
## Exercise the real camera against the imported garden, without advancing combat.
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	evidence.record(message, ok)
	if not ok:
		failures += 1
		push_error(message)

func exercise(stage, label: String) -> void:
	stage.set_process(false)
	stage.orbit(Vector2(90, 15))
	stage._position_camera()
	var chosen: Transform3D = stage.camera.global_transform
	var hero: Node3D = stage.actors.player
	hero.rotation.y += .7
	for frame in range(180):
		stage._position_camera()
	check(stage.camera.global_transform.is_equal_approx(chosen), label + ": stationary manual view does not drift after input")
	check(stage.camera_candidates_last_frame == 0, label + ": stationary manual view does not run obstruction searches")
	var enemy: Node3D
	for actor in stage._state.actors:
		if actor.faction == "hostile" and stage.actors.has(actor.id):
			enemy = stage.actors[actor.id]
			break
	check(enemy != null, label + ": fixture has a real adversary")
	if enemy == null: return
	var enemy_start := enemy.position
	enemy.position += Vector3(1, 0, .7)
	for frame in range(60): stage._position_camera()
	check(stage.camera.global_transform.is_equal_approx(chosen), label + ": enemy motion cannot pull a stationary manual camera")
	enemy.position = enemy_start
	hero.position += Vector3(.5, 0, 0)
	stage._position_camera()
	check(not stage.camera.global_transform.is_equal_approx(chosen), label + ": controlled-character travel allows the camera to follow")
	var arrived: Transform3D = stage.camera.global_transform
	for frame in range(60): stage._position_camera()
	check(stage.camera.global_transform.is_equal_approx(arrived), label + ": camera stops adjusting when character travel stops")
	stage.orbit(Vector2(-50, -10))
	stage._position_camera()
	check(not stage.camera.global_transform.is_equal_approx(arrived), label + ": another manual drag still changes the view")
	var orbited: Transform3D = stage.camera.global_transform
	stage.zoom(1.0)
	stage._position_camera()
	check(not stage.camera.global_transform.is_equal_approx(orbited), label + ": zoom works while the view is held")
	stage.recenter_camera()
	stage._position_camera()
	check(not stage._manual_camera, label + ": explicit recenter restores automatic framing")

func run() -> void:
	var command := preload("res://scripts/command_trial.gd").new()
	command.preview_mode = true
	root.add_child(command)
	command.set_process(false)
	await physics_frame
	await process_frame
	exercise(command.stage, "Command")
	command.stage.orbit(Vector2(30, 0))
	command.stage._position_camera()
	var before_switch: Transform3D = command.stage.camera.global_transform
	command.stage.follow_actor("mara")
	command.stage._position_camera()
	var switched: Transform3D = command.stage.camera.global_transform
	check(not switched.is_equal_approx(before_switch), "Command: explicit party switching reframes the new controlled actor")
	for frame in range(60): command.stage._position_camera()
	check(command.stage.camera.global_transform.is_equal_approx(switched), "Command: view holds again after a party switch")
	command.queue_free()
	await process_frame
	var flow := preload("res://scripts/flow_trial.gd").new()
	flow.preview_mode = true
	root.add_child(flow)
	flow.set_process(false)
	await physics_frame
	await process_frame
	exercise(flow.stage, "Flow")
	flow.queue_free()
	await process_frame
	print("CAMERA_HOLD: %d checks, %d failures" % [checks, failures])
	evidence.finish("camera-hold", "Manual camera hold, movement, orbit, zoom and recenter against actual Command/Flow garden stages.")
	quit(1 if failures else 0)
