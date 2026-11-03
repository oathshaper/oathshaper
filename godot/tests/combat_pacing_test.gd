extends SceneTree
## Real host tick budget plus presentation-only samples; no timing thresholds.
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	evidence.record(label, value)
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var trial := preload("res://scripts/command_trial.gd").new()
	trial.preview_mode = true
	root.add_child(trial)
	trial.set_process(false)
	trial.stage.set_process(false)
	await physics_frame
	trial._preview_resumed = true
	trial._toggle_pause()
	var start_tick: int = trial.state.session.tick
	for _frame in range(6): trial._process(.1)
	check(int(trial.state.session.tick) - start_tick == 6, "Zero-time admission does not discard simulation ticks")
	check(trial._remainder < .00001, "Six admitted ticks spend exactly six 100ms intervals")
	# Preserve a real view's shape while supplying known presentation snapshots.
	# This does not submit positions to the rules or claim a gameplay outcome.
	var view: Dictionary = trial.state.duplicate(true)
	view.clock.paused = false
	view.session.generation = "motion-fixture"
	view.session.tick = 0
	for actor in view.actors:
		if actor.id == "player": actor.position = [0.0, 0.0]; actor.active_action = null
	var stage = trial.stage
	stage.apply_view(view)
	var body: CharacterBody3D = stage.actors.player
	var slot = body.get_node("ModelSlot")
	for tick in range(1, 5):
		view.session.tick = tick
		for actor in view.actors:
			if actor.id == "player": actor.position = [.17 * tick, 0.0]
		stage.apply_view(view)
		var previous := body.position
		for frame in range(1, 7):
			stage.interpolation_fraction = float(frame) / 6.0
			stage._process(1.0 / 60.0)
			slot._process(1.0 / 60.0)
			check(absf(body.position.x - (.17 * (tick - 1) + .17 * frame / 6.0)) < .00001, "Samples interpolate evenly across the tick")
			check(body.position.distance_to(previous) < .029, "No rush-and-stop movement burst")
			check(absf(body.velocity.x - 1.7) < .00001 and slot._animation_player.current_animation == slot._walk_clip, "Walk stays active at authoritative speed between updates")
			check(stage.camera_candidates_last_frame <= stage.CAMERA_SEARCH_BUDGET, "Camera search has a per-frame work limit")
			previous = body.position
	# An extra UI/geometry publication at the same tick must not restart the blend.
	stage.interpolation_fraction = .5
	stage._process(0.0)
	var midway := body.position
	stage.apply_view(view)
	stage._process(0.0)
	check(body.position.is_equal_approx(midway), "Same-tick UI publications do not rewind interpolation")
	view.clock.paused = true
	stage.apply_view(view)
	var paused := body.position
	stage._process(.2)
	check(body.position == paused and body.velocity == Vector3.ZERO, "Pause freezes movement at its committed position")
	view.session.generation = "restored-fixture"
	view.session.tick = 0
	for actor in view.actors:
		if actor.id == "player": actor.position = [-2.0, 0.0]
	stage.apply_view(view)
	check(body.position.is_equal_approx(Vector3(-2, 0, 0)), "Restore snaps to its new snapshot without a travel streak")
	print("COMBAT_PACING: %d checks, %d failures" % [checks, failures])
	evidence.finish("combat-pacing", "Deterministic host tick accounting and staged motion samples; no GPU or frame-rate assertion.")
	trial.queue_free()
	await process_frame
	quit(1 if failures else 0)
