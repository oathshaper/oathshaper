extends SceneTree
var checks := 0
var failures := 0
var trial: Control

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	create_timer(45).timeout.connect(func() -> void: push_error("Targeting test timed out"); quit(1))
	root.size = Vector2i(1280, 800)
	trial = preload("res://scripts/command_trial.gd").new()
	root.add_child(trial)
	await process_frame
	trial.set_process(false)
	trial._close_modal()
	trial.submit({"kind":"encounter.start", "encounter_id":"garden_patrol"})
	await process_frame
	check(trial.state.party.selected_target_id == "hound", "Contact selects the nearest enemy")
	await create_timer(1.2).timeout
	var close_camera: Camera3D = trial.stage.camera
	var hero: Vector3 = trial.stage.actors.player.position
	var foe: Vector3 = trial.stage.actors.hound.position
	var hero_screen := close_camera.unproject_position(hero + Vector3.UP)
	var foe_screen := close_camera.unproject_position(foe + Vector3.UP)
	check(absf(hero_screen.x - foe_screen.x) >= 35, "Melee opponents have separate screen silhouettes")
	for position in [hero, foe]:
		var foot := close_camera.unproject_position(position)
		var head := close_camera.unproject_position(position + Vector3.UP * 1.8)
		check(foot.y < 550 and head.y > 80, "Both whole fighters fit above the action bar and below the header")
	check(close_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Combat keeps perspective depth")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-melee.png")
	trial.stage.orbit(Vector2(180, 0))
	var manual_yaw: float = trial.stage._yaw
	var previous: String = trial.state.party.selected_target_id
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	check(trial.state.party.selected_target_id != previous, "RB selects another enemy")
	check(trial.state.party.possessed_id == "player" and trial._modal == null, "Bumper targeting changes neither possession nor modal state")
	check(trial.stage._manual_camera and is_equal_approx(trial.stage._yaw, manual_yaw), "Target selection preserves manual camera heading")
	await joy(JOY_BUTTON_LEFT_SHOULDER)
	check(trial.state.party.selected_target_id == previous, "LB reverses target selection")
	trial._choose_action("basic")
	check(trial.hud.actor("player").queue.size() == 1 and trial._modal == null, "Action bar attacks selected enemy without a dialog")
	await joy(JOY_BUTTON_RIGHT_STICK)
	check(trial.state.party.possessed_id == "mara" and trial.state.party.camera_follow_id == "mara", "R3 possesses and follows Mara")
	trial._choose_action("mend")
	check(not trial._pending_ability.is_empty() and trial._modal == null, "Healing aims in the world")
	FileAccess.open("/tmp/oathshaper-command-targeting.txt", FileAccess.WRITE).store_string(trial.stage.markers.aim_text)
	check(trial.hud.actor(str(trial.state.party.selected_target_id)).faction == "party", "Healing selects an ally")
	var before: int = trial.hud.actor("mara").focus.reserved
	await joy(JOY_BUTTON_RIGHT_SHOULDER)
	var ally: String = trial.state.party.selected_target_id
	check(trial.hud.actor(ally).faction == "party", "Healing bumpers stay within allies")
	check(trial.hud.actor("mara").focus.reserved == before, "Cycling does not spend or reserve focus")
	await joy(JOY_BUTTON_A)
	check(trial.hud.actor("mara").queue[0].target.actor_id == ally and trial.hud.actor("mara").focus.reserved == before + 16, "A confirms the highlighted ally exactly once")
	check(trial._pending_ability.is_empty() and trial._modal == null, "Healing returns directly to combat HUD")
	trial._choose_action("binding_current")
	await joy(JOY_BUTTON_B)
	check(trial._pending_ability.is_empty() and trial.hud.actor("mara").focus.reserved == before + 16, "B cancels area aim without spending")
	trial.submit({"kind":"target.select", "target_id":"hound"})
	await create_timer(1.0).timeout
	check(trial.stage._follow_id == "mara", "Camera ownership survives later view updates")
	for body in trial.stage.actors.values():
		check(not body.has_node("Nameplate"), "Command has no competing 3D nameplate: " + str(body.name))
	var target_center: Vector3 = trial.stage.actors.hound.position + Vector3.UP
	var camera: Camera3D = trial.stage.camera
	check((-camera.global_basis.z).dot(camera.global_position.direction_to(target_center)) > .85, "Camera frames the selected target after cycling")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		var markers: Control = trial.stage.markers
		check(markers.reticle_target == "hound", "Broken X is drawn on the selected target")
		check(markers.placed_labels.size() == 1, "Only the reticled actor has a world name badge")
		for i in range(markers.placed_labels.size()):
			for j in range(i):
				check(not markers.placed_labels[i].intersects(markers.placed_labels[j]), "Names never overlap")
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-targeting.png")
	var sounds: int = trial._audio.played
	trial._publish(trial.state)
	trial._publish(trial.state)
	check(trial._audio.played == sounds, "Repeated state projection does not replay combat audio")
	trial._request({"kind":"ui.controls"})
	await process_frame
	check(trial._modal != null and trial._modal.get_global_rect().end.y < 800, "Controls are reachable and fit Steam Deck height")
	trial._close_modal()
	print("COMMAND_TARGETING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
