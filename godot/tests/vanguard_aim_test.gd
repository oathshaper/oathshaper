extends SceneTree
## The third-person muzzle must converge on the screen-center aim ray.
var failures := 0
var checks := 0
var trial: Control

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func run() -> void:
	trial = preload("res://scripts/vanguard_trial.gd").new()
	root.add_child(trial)
	trial.set_process(false)
	trial.submit({"kind":"begin"})
	for size in [Vector2i(1280, 800), Vector2i(1600, 900)]:
		root.size = size
		await process_frame
		await process_frame
		for aimed in [false, true]:
			trial.submit({"kind":"aim", "pressed":aimed})
			# Deliberately leave the enemy off-center: a body-volume contact
			# must not pull the tracer away from the player's chosen aim point.
			trial.stage.yaw = -1.3
			trial.stage.pitch = -.05
			trial.stage._position_camera()
			var camera: Camera3D = trial.stage.camera
			var center := Vector2(trial.viewport.size) * .5
			var muzzle: Vector3 = trial.stage.actors.player.get_node("Firearm").flash.global_position
			for target in [null, "hound"]:
				var end: Vector3 = trial.stage._shot_endpoint("player", target, muzzle)
				check(not camera.is_position_behind(end) and camera.unproject_position(end).distance_to(center) < .01,
					"%s aimed=%s target=%s: player shot converges on center" % [size, aimed, target])
			var npc_end: Vector3 = trial.stage._shot_endpoint("mara", "hound", muzzle)
			check(npc_end.is_equal_approx(trial.stage.actors.hound.position + Vector3(0, 1.2, 0)),
				"Squad firing retains its own target")
	# Acquire a live hostile through the actual camera observation and core.
	var point: Vector3 = trial.stage.actors.hound.position + Vector3(0, 1.2, 0)
	for attempt in 12:
		trial.stage._position_camera()
		var desired: Vector3 = (point - trial.stage.camera.global_position).normalized()
		var ray: Vector3 = trial.stage._aim_ray()
		trial.stage.yaw += wrapf(atan2(-desired.x, -desired.z) - atan2(-ray.x, -ray.z), -PI, PI)
		trial.stage.pitch += asin(desired.y) - asin(ray.y)
	trial.stage._position_camera()
	trial._process(1.0 / 60)
	check(trial.state.aim == "hound", "Centered live enemy is acquired by core observation")
	trial.submit({"kind":"trigger", "pressed":true})
	trial._process(1.0 / 60)
	trial.submit({"kind":"trigger", "pressed":false})
	check(trial.state.actors.player.weapons[0].heat > 0, "Centered trigger emits a real player shot")
	check(str(trial.state.log).contains("Tessa Ward hit Lantern Sentinel"), "Player shot resolves against the centered hostile")
	trial.free()
	print("VANGUARD_AIM_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
