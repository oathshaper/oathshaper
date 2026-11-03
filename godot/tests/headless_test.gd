extends SceneTree

const TEST_SAVE := "user://oathshaper_hub_v4_headless_test.save.json"

func _initialize() -> void:
	call_deferred("_run")

func _json(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Invalid JSON response."}
	return parsed

func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Oathshaper headless test failed: " + message)
	quit(1)
	return false

func _joy(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func _axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func _mouse_drag(mask: int, motion: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = mask
	event.relative = motion
	Input.parse_input_event(event)

func _mouse_wheel(button: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)

func _key(physical_code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_code
	event.pressed = pressed
	Input.parse_input_event(event)

func _key_echo(physical_code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_code
	event.pressed = true
	event.echo = true
	Input.parse_input_event(event)

func _mouse_motion(motion: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = motion
	Input.parse_input_event(event)

func _input_hint_checks(scene: PackedScene) -> bool:
	# Synthetic events exercise controls, but cannot claim physical hardware is connected.
	var connected := not Input.get_connected_joypads().is_empty()
	var demo: Node3D = scene.instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	await process_frame
	var prompt := demo.get_node("CanvasLayer/Prompt") as Label
	var controls := demo.get_node("CanvasLayer/ControlsHint") as Label
	var status := demo.get_node("CanvasLayer/Status") as Label
	var location := demo.get_node("CanvasLayer/Location") as Label
	var map := demo.get_node("CanvasLayer/MapWidget") as Control
	var tracker := demo.get_node("CanvasLayer/ObjectiveTracker") as Control
	var panel := demo.get_node("CanvasLayer/DialoguePanel") as Control
	var back_hint := panel.get_node("Panel/Margin/VBox/BackHint") as Label
	if not _expect(prompt.text.is_empty() and not prompt.visible, "exploration starts without a persistent movement prompt"):
		return false
	if not _expect(controls.text.contains("Tab Ledger") and controls.text.contains("M Map") and controls.text.contains("J Quest") and controls.text.contains("F5") and controls.text.contains("F9") and not controls.text.contains("WASD") and not controls.text.contains("Menu"), "muted lower-right keyboard hints show ledger, map, objective, save and load keys"):
		return false
	if not _expect(not location.visible and str(map.get("_location_hint")).contains("CENTRAL QUAY") and map.position.y <= 40.0 and tracker.position.y > map.position.y + map.size.y, "district guidance lives in the top-right map above the objective"):
		return false
	if not _expect(is_equal_approx(tracker.position.x, map.position.x) and is_equal_approx(tracker.size.x, map.size.x), "quest tracker and minimap share both horizontal edges"):
		return false
	var active_title := tracker.get("_heading") as Label
	if not _expect(active_title.get_theme_color("font_color") == Color("#ffdb72") and (tracker.get("_panel_style") as StyleBoxFlat).border_color == Color("#ffdb72"), "active quest title and border are yellow"):
		return false
	if not _expect(not status.text.contains("F5") and not status.text.contains("Menu"), "status line contains feedback rather than duplicate control hints"):
		return false

	var player := demo.get_node("Player") as CharacterBody3D
	player.global_position = Vector3(0, 1, 1)
	await process_frame
	if not _expect(prompt.text.contains("Mara") and not prompt.text.contains("Ⓐ"), "nearby keyboard interaction identifies Mara without a controller badge"):
		return false
	_axis(2, 0.7)
	await process_frame
	if not _expect(prompt.text.contains("Ⓐ") == connected and prompt.text.contains("Mara"), "right stick hints require a connected controller"):
		return false
	if not _expect(controls.text.contains("Menu Ledger") == connected and controls.text.contains("F5") != connected, "exploration hints reflect connection state"):
		return false
	_axis(2, 0.0)
	_key_echo(KEY_SHIFT)
	await process_frame
	if not _expect(prompt.text.contains("Ⓐ") == connected, "neutral stick and key echo leave connection-aware hints unchanged"):
		return false

	_key(KEY_SHIFT, true)
	await process_frame
	_key(KEY_SHIFT, false)
	await process_frame
	if not _expect(prompt.text.contains("Mara") and not prompt.text.contains("Ⓐ") and controls.text.contains("F5"), "keyboard activity restores keyboard interaction and save hints"):
		return false
	_joy(0, true)
	await process_frame
	_joy(0, false)
	await process_frame
	if not _expect(demo.get("mode") == "dialogue" and panel.visible and not controls.visible, "circled A interaction enters dialogue without overlaying exploration controls"):
		return false
	if not _expect(back_hint.text.contains("Ⓐ") == connected and back_hint.text.contains("Esc") != connected, "dialogue only shows gamepad glyphs for connected hardware"):
		return false
	_mouse_motion(Vector2(12, 0))
	await process_frame
	if not _expect(back_hint.text.contains("Enter") and back_hint.text.contains("Esc") and not back_hint.text.contains("Ⓐ") and not back_hint.text.contains("Ⓑ"), "mouse movement swaps dialogue hints back to keyboard controls"):
		return false
	_axis(2, 0.7)
	await process_frame
	_axis(2, 0.0)
	await process_frame
	if not _expect(back_hint.text.contains("Ⓐ") == connected and back_hint.text.contains("Esc") != connected, "controller activity respects connection state during dialogue"):
		return false
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	await process_frame
	if not _expect(demo.get("mode") == "explore" and not panel.visible and prompt.visible and controls.visible and controls.text.contains("F5") and not prompt.text.contains("Ⓐ"), "keyboard Esc backs out and restores keyboard exploration hints"):
		return false
	_joy(3, true)
	await process_frame
	_joy(3, false)
	await process_frame
	if not _expect(not tracker.visible and bool(demo.get("_objective_dismissed")), "controller Y dismisses the objective"):
		return false
	_key(KEY_J, true)
	await process_frame
	_key(KEY_J, false)
	await process_frame
	if not _expect(tracker.visible and not bool(demo.get("_objective_dismissed")), "keyboard J restores the objective"):
		return false
	(tracker.get("dismiss_button") as Button).pressed.emit()
	await process_frame
	if not _expect(not tracker.visible, "objective close button dismisses the tracker"):
		return false
	var quest_click := InputEventMouseButton.new()
	quest_click.button_index = MOUSE_BUTTON_LEFT
	quest_click.pressed = true
	quest_click.position = (map.call("_footer_rect") as Rect2).get_center()
	map.call("_gui_input", quest_click)
	await process_frame
	if not _expect(tracker.visible and not bool(demo.get("_objective_dismissed")) and not tracker.call("is_collapsed"), "clicking the minimap quest restores the expanded tracker"):
		return false
	var expanded_tracker_height := tracker.size.y
	(tracker.get("collapse_button") as Button).pressed.emit()
	await process_frame
	if not _expect(tracker.visible and tracker.call("is_collapsed") and not active_title.visible and tracker.size.y < expanded_tracker_height * 0.5, "active quest collapses to a compact header: visible=%s collapsed=%s title=%s size=%s" % [tracker.visible, tracker.call("is_collapsed"), active_title.visible, tracker.size]):
		return false
	map.call("_gui_input", quest_click)
	await process_frame
	if not _expect(tracker.visible and not tracker.call("is_collapsed") and active_title.visible and tracker.size.y >= expanded_tracker_height, "minimap quest expands the collapsed tracker"):
		return false
	root.remove_child(demo)
	demo.queue_free()
	await process_frame
	return true

func _camera_checks(demo: Node3D) -> bool:
	var rig: Node3D = demo.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera3D")
	var player: CharacterBody3D = demo.get_node("Player")
	var start: Vector3 = player.global_position
	var starting_yaw: float = rig.get("yaw")
	var starting_pitch: float = rig.get("pitch")
	if not _expect(float(rig.get("distance")) <= 5.5 and starting_pitch <= 23.0, "exploration starts in a close third-person view"):
		return false
	_mouse_drag(MOUSE_BUTTON_MASK_RIGHT, Vector2(80, 40))
	await process_frame
	if not _expect(float(rig.get("yaw")) < starting_yaw - 15.0 and float(rig.get("pitch")) > starting_pitch + 8.0, "right drag orbits in both axes"):
		return false
	var orbit_yaw: float = rig.get("yaw")
	var pan_before_drag: Vector3 = rig.get("pan_offset")
	_mouse_drag(MOUSE_BUTTON_MASK_MIDDLE, Vector2(100, -50))
	await process_frame
	var pan: Vector3 = rig.get("pan_offset")
	var pan_motion := pan - pan_before_drag
	var pan_right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(orbit_yaw))
	var pan_forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(orbit_yaw))
	var expected_pan := (-pan_right * 100.0 - pan_forward * 50.0).normalized()
	if not _expect(pan_motion.length() > 0.7 and pan_motion.normalized().dot(expected_pan) > 0.99 and absf(pan_motion.y) < 0.001 and is_equal_approx(float(rig.get("yaw")), orbit_yaw), "middle drag pans in the dragged direction without orbiting (before=%s, delta=%s, yaw=%.2f, prior=%.2f)" % [pan_before_drag, pan_motion, float(rig.get("yaw")), orbit_yaw]):
		return false
	await process_frame
	var camera_before_follow: Vector3 = camera.global_position
	player.global_position += Vector3(1, 0, 0)
	await process_frame
	await process_frame
	if not _expect(camera.global_position.distance_to(camera_before_follow + Vector3(1, 0, 0)) < 0.02, "panned camera still follows player movement"):
		return false
	player.global_position = start
	var starting_distance: float = rig.get("distance")
	_mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	await process_frame
	if not _expect(float(rig.get("distance")) < starting_distance, "wheel up zooms in"):
		return false
	rig.set("distance", 3.55)
	_mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	await process_frame
	if not _expect(is_equal_approx(float(rig.get("distance")), 3.5), "wheel zoom clamps near distance"):
		return false
	rig.set("distance", 27.0)
	_mouse_wheel(MOUSE_BUTTON_WHEEL_DOWN)
	await process_frame
	if not _expect(is_equal_approx(float(rig.get("distance")), 28.0), "wheel zoom clamps far distance"):
		return false
	_key(KEY_F, true)
	await process_frame
	_key(KEY_F, false)
	if not _expect((rig.get("pan_offset") as Vector3).length() < 0.001, "F recenters the camera on the player"):
		return false
	rig.set("pan_offset", Vector3(1, 0, 0))
	_joy(8, true)
	await process_frame
	_joy(8, false)
	if not _expect((rig.get("pan_offset") as Vector3).length() < 0.001, "right stick click recenters the camera"):
		return false
	rig.set("pitch", 20.0)
	_axis(2, 1.0)
	_axis(3, 1.0)
	var yaw_before_stick: float = rig.get("yaw")
	var pitch_before_stick: float = rig.get("pitch")
	for _frame in range(6):
		await process_frame
	_axis(2, 0.0)
	_axis(3, 0.0)
	if not _expect(float(rig.get("yaw")) < yaw_before_stick and float(rig.get("pitch")) > pitch_before_stick, "right stick orbits and tilts the camera"):
		return false
	rig.set("yaw", 90.0)
	rig.set("pitch", 20.0)
	rig.set("distance", 5.0)
	await process_frame
	await process_frame
	_axis(1, -1.0)
	for _frame in range(8):
		await physics_frame
	_axis(1, 0.0)
	if not _expect(player.global_position.x < start.x - 0.1, "left stick movement remains camera relative after orbit"):
		return false
	player.global_position = start
	player.rotation.y = deg_to_rad(20.0)
	rig.set("yaw", 20.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	await process_frame
	return true

func _camera_auto_follow_checks(demo: Node3D) -> bool:
	var rig: Node3D = demo.get_node("CameraRig")
	var player: CharacterBody3D = demo.get_node("Player")
	var camera: Camera3D = rig.get_node("Camera3D")
	var saved_position := player.global_position
	var saved_rotation := player.rotation
	var saved_yaw: float = rig.get("yaw")
	var saved_pan: Vector3 = rig.get("pan_offset")
	rig.set("yaw", 0.0)
	rig.set("pan_offset", Vector3.ZERO)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	rig.set("_occlusion_ratio", 1.0)
	player.set("_move_basis_latched", false)
	player.rotation.y = 0.0
	await process_frame
	# D still turns the actor and close camera, but a brief keyboard tap should
	# cover much less ground and much less yaw than the former full-speed snap.
	_key(KEY_D, true)
	var d_start := player.global_position
	for _frame in range(12):
		await physics_frame
		await process_frame
	var d_first := player.global_position - d_start
	var d_yaw := float(rig.get("yaw"))
	print("Camera keyboard D first 12 frames: travel=%s, actor yaw=%.1f°, camera yaw=%.1f°" % [d_first, rad_to_deg(player.rotation.y), d_yaw])
	if not _expect(d_first.x > 0.3 and d_first.x < 0.6 and absf(d_first.z) < 0.1 and rad_to_deg(player.rotation.y) < -25.0 and rad_to_deg(player.rotation.y) > -45.0 and d_yaw < -15.0 and d_yaw > -50.0, "D tap turns and advances at a measured rate (travel=%s, yaw=%.1f)" % [d_first, d_yaw]):
		return false
	var d_mid := player.global_position
	for _frame in range(24):
		await physics_frame
		await process_frame
	var d_second := player.global_position - d_mid
	print("Camera keyboard D next 24 frames: travel=%s, actor yaw=%.1f°, camera yaw=%.1f°" % [d_second, rad_to_deg(player.rotation.y), float(rig.get("yaw"))])
	if not _expect(d_second.x > 1.0 and d_second.x < 1.4 and absf(d_second.z) < 0.1 and float(rig.get("yaw")) < -75.0, "held D completes the turn without full-speed travel or a camera-induced spiral (travel=%s)" % d_second):
		return false
	_key(KEY_D, false)
	await physics_frame
	# A new W press uses the *current* view. Releasing all input drops the latch.
	var w_forward := -camera.global_basis.z
	w_forward.y = 0.0
	w_forward = w_forward.normalized()
	var w_start := player.global_position
	_key(KEY_W, true)
	for _frame in range(12):
		await physics_frame
		await process_frame
	var w_travel := player.global_position - w_start
	if not _expect(w_travel.normalized().dot(w_forward) > 0.97 and w_travel.length() > 0.6 and camera.global_position.distance_to(player.global_position) < 6.0, "released D then pressed W advances into the current close view (travel=%s, intended=%s)" % [w_travel, w_forward]):
		return false
	# W to A in one input transition rebases the side-step against the view.
	var a_left := -camera.global_basis.x
	a_left.y = 0.0
	a_left = a_left.normalized()
	var a_start := player.global_position
	_key(KEY_W, false)
	_key(KEY_A, true)
	for _frame in range(12):
		await physics_frame
		await process_frame
	var a_travel := player.global_position - a_start
	if not _expect(a_travel.normalized().dot(a_left) > 0.97 and a_travel.length() > 0.3 and a_travel.length() < 0.6, "W to A turns and follows left of the view at a measured speed (travel=%s, intended=%s)" % [a_travel, a_left]):
		return false
	var a_mid := player.global_position
	for _frame in range(18):
		await physics_frame
		await process_frame
	var a_held := player.global_position - a_mid
	if not _expect(a_held.normalized().dot(a_left) > 0.97, "held A stays straight after the camera turns (travel=%s, intended=%s)" % [a_held, a_left]):
		return false
	# Add W while A is still held, then let go of A: each vector edge gets
	# the current camera basis instead of the old view from the first keypress.
	var diagonal := -camera.global_basis.x - camera.global_basis.z
	diagonal.y = 0.0
	diagonal = diagonal.normalized()
	var diagonal_start := player.global_position
	_key(KEY_W, true)
	for _frame in range(10):
		await physics_frame
		await process_frame
	var diagonal_travel := player.global_position - diagonal_start
	if not _expect(diagonal_travel.normalized().dot(diagonal) > 0.96, "W+A changes direction once without curving the held diagonal (travel=%s, intended=%s)" % [diagonal_travel, diagonal]):
		return false
	var forward_after_diagonal := -camera.global_basis.z
	forward_after_diagonal.y = 0.0
	forward_after_diagonal = forward_after_diagonal.normalized()
	var forward_start := player.global_position
	_key(KEY_A, false)
	for _frame in range(10):
		await physics_frame
		await process_frame
	var forward_travel := player.global_position - forward_start
	if not _expect(forward_travel.normalized().dot(forward_after_diagonal) > 0.96, "releasing A from W+A reorients W to the current camera forward"):
		return false
	_key(KEY_W, false)
	await physics_frame
	# Release and retap D; the new press samples the changed view.
	var retap_right := camera.global_basis.x
	retap_right.y = 0.0
	retap_right = retap_right.normalized()
	var retap_start := player.global_position
	_key(KEY_D, true)
	for _frame in range(9):
		await physics_frame
		await process_frame
	var retap_travel := player.global_position - retap_start
	if not _expect(retap_travel.normalized().dot(retap_right) > 0.96, "released and retapped D uses the new view instead of a stale movement basis"):
		return false
	_key(KEY_D, false)
	await physics_frame
	# The same latch and rebase must work with the left stick.
	player.global_position = saved_position
	player.rotation.y = 0.0
	rig.set("yaw", 0.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	await process_frame
	rig.call("_process", 0.0)
	var stick_initial_left := -camera.global_basis.x
	var stick_initial_forward := -camera.global_basis.z
	stick_initial_left.y = 0.0
	stick_initial_forward.y = 0.0
	_axis(0, -1.0)
	var stick_start := player.global_position
	for _frame in range(24):
		await physics_frame
		await process_frame
	var stick_left := player.global_position - stick_start
	if not _expect(stick_left.x < -1.4 and absf(stick_left.z) < 0.1 and float(rig.get("yaw")) > 80.0, "held left stick A tracks the actor without spiraling (travel=%s)" % stick_left):
		return false
	var stick_diagonal := stick_initial_left + stick_initial_forward
	stick_diagonal.y = 0.0
	stick_diagonal = stick_diagonal.normalized()
	var stick_mid := player.global_position
	_axis(1, -1.0)
	for _frame in range(10):
		await physics_frame
		await process_frame
	var stick_change := player.global_position - stick_mid
	if not _expect(stick_change.normalized().dot(stick_diagonal) > 0.96, "adding forward stick input smoothly uses the gesture's original world basis (travel=%s, expected=%s, dot=%.3f)" % [stick_change, stick_diagonal, stick_change.normalized().dot(stick_diagonal)]):
		return false
	_axis(0, 0.0)
	_axis(1, 0.0)
	await physics_frame
	var stick_retap := camera.global_basis.x
	stick_retap.y = 0.0
	stick_retap = stick_retap.normalized()
	var stick_retap_start := player.global_position
	_axis(0, 1.0)
	for _frame in range(8):
		await physics_frame
		await process_frame
	var stick_retap_travel := player.global_position - stick_retap_start
	if not _expect(stick_retap_travel.normalized().dot(stick_retap) > 0.96, "retapped right stick movement samples the new camera heading"):
		return false
	_axis(0, 0.0)
	await physics_frame
	# A constant-radius analog sweep must not jump when it crosses a rebase
	# threshold after the chase camera has already turned behind held A.
	player.global_position = saved_position
	player.rotation.y = 0.0
	rig.set("yaw", 0.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	await process_frame
	rig.call("_process", 0.0)
	_axis(0, -1.0)
	for _frame in range(24):
		await physics_frame
		await process_frame
	var previous_heading := player.velocity.normalized()
	var worst_sweep_turn := 0.0
	for step in range(1, 46):
		var angle := deg_to_rad(float(step) * 2.0)
		_axis(0, -cos(angle))
		_axis(1, -sin(angle))
		await physics_frame
		var heading := player.velocity.normalized()
		worst_sweep_turn = maxf(worst_sweep_turn, rad_to_deg(previous_heading.angle_to(heading)))
		previous_heading = heading
		await process_frame
	print("Camera analog sweep maximum frame turn: %.2f degrees" % worst_sweep_turn)
	if not _expect(worst_sweep_turn < 12.0, "gradual left-stick sweep changes world heading continuously after camera follow (worst frame=%.1f degrees)" % worst_sweep_turn):
		return false
	_axis(0, 0.0)
	_axis(1, 0.0)
	await physics_frame
	# If both devices are active, the last active device wins as a whole.
	# Keyboard D must not cancel the held left stick's horizontal action.
	player.global_position = saved_position
	player.rotation.y = 0.0
	rig.set("yaw", 0.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	rig.call("_process", 0.0)
	_axis(0, -1.0)
	for _frame in range(14):
		await physics_frame
		await process_frame
	var keyboard_right := camera.global_basis.x
	keyboard_right.y = 0.0
	keyboard_right = keyboard_right.normalized()
	_key(KEY_D, true)
	await physics_frame
	await process_frame
	if not _expect(str(player.get("_move_source")) == "keyboard" and player.velocity.normalized().dot(keyboard_right) > 0.95, "keyboard D takes explicit priority over held left stick A (source=%s, preferred=%s, key=%s, velocity=%s, intended=%s)" % [player.get("_move_source"), player.get("_preferred_source"), Input.is_physical_key_pressed(KEY_D), player.velocity, keyboard_right]):
		return false
	_key(KEY_D, false)
	await physics_frame
	await process_frame
	if not _expect(str(player.get("_move_source")) == "controller" and player.velocity.length() > 1.0, "held left stick resumes after keyboard D releases"):
		return false
	_axis(0, 0.0)
	await physics_frame
	# Orbit while holding the left stick: travel turns into the chosen view.
	# Release preserves that view; neutral/repress samples the same heading.
	player.global_position = saved_position
	player.rotation.y = 0.0
	rig.set("yaw", 0.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	rig.call("_process", 0.0)
	_axis(1, -1.0)
	for _frame in range(5):
		await physics_frame
		await process_frame
	_mouse_drag(MOUSE_BUTTON_MASK_RIGHT, Vector2(60, 0))
	await process_frame
	var stick_orbit_yaw := float(rig.get("yaw"))
	var stick_orbit_forward := -camera.global_basis.z
	stick_orbit_forward.y = 0
	var stick_orbit_start := player.global_position
	for _frame in range(12):
		await physics_frame
		await process_frame
	var stick_orbit_travel := player.global_position - stick_orbit_start
	if not _expect(stick_orbit_travel.normalized().dot(stick_orbit_forward.normalized()) > .97 and is_equal_approx(float(rig.get("yaw")), stick_orbit_yaw), "manual orbit redirects held stick travel into the chosen view"):
		return false
	_axis(1, 0.0)
	rig.call("_process", 0.7)
	rig.call("_process", 0.7)
	if not _expect(is_equal_approx(float(rig.get("yaw")), stick_orbit_yaw), "stick release preserves the chosen orbit beyond the old grace period"):
		return false
	var stick_new_right := camera.global_basis.x
	stick_new_right.y = 0.0
	stick_new_right = stick_new_right.normalized()
	_axis(0, 1.0)
	var stick_new_start := player.global_position
	for _frame in range(8):
		await physics_frame
		await process_frame
	var stick_new_travel := player.global_position - stick_new_start
	if not _expect(stick_new_travel.normalized().dot(stick_new_right) > 0.95, "stick neutral then repress reanchors movement to the current view"):
		return false
	_axis(0, 0.0)
	await physics_frame
	# Manual orbit remains available during travel and holds until recentered.
	player.global_position = saved_position
	player.rotation.y = 0.0
	rig.set("yaw", 0.0)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	await process_frame
	_key(KEY_W, true)
	for _frame in range(5):
		await physics_frame
		await process_frame
	_mouse_drag(MOUSE_BUTTON_MASK_RIGHT, Vector2(60, 0))
	await process_frame
	var manual_yaw: float = rig.get("yaw")
	var manual_forward := -camera.global_basis.z
	manual_forward.y = 0
	var travel_start := player.global_position
	for _frame in range(12):
		await physics_frame
		await process_frame
	var orbit_travel := player.global_position - travel_start
	if not _expect(orbit_travel.normalized().dot(manual_forward.normalized()) > .97 and is_equal_approx(float(rig.get("yaw")), manual_yaw), "manual orbit turns W travel into the chosen view and holds it"):
		return false
	_key(KEY_W, false)
	rig.call("_process", 0.7)
	if not _expect(is_equal_approx(float(rig.get("yaw")), manual_yaw), "manual orbit keeps its angle through the grace period"):
		return false
	rig.call("_process", 0.7)
	if not _expect(is_equal_approx(float(rig.get("yaw")), manual_yaw), "idle camera preserves manual orbit until explicit recenter"):
		return false
	_mouse_drag(MOUSE_BUTTON_MASK_MIDDLE, Vector2(75, -30))
	await process_frame
	var manual_pan: Vector3 = rig.get("pan_offset")
	rig.call("_process", 0.35)
	if not _expect((rig.get("pan_offset") as Vector3).distance_to(manual_pan) < 0.001, "manual pan stays in place during its grace period"):
		return false
	rig.call("_process", 1.0)
	if not _expect((rig.get("pan_offset") as Vector3).length() < manual_pan.length() * 0.6, "camera gently returns from a manual pan"):
		return false
	_key(KEY_F, true)
	await process_frame
	_key(KEY_F, false)
	if not _expect((rig.get("pan_offset") as Vector3).length() < 0.001 and absf(wrapf(float(rig.get("yaw")) - rad_to_deg(player.rotation.y), -180.0, 180.0)) < 0.1, "F recenters both the camera pivot and heading behind the player"):
		return false
	player.global_position = saved_position
	player.rotation = saved_rotation
	rig.set("yaw", saved_yaw)
	rig.set("pan_offset", saved_pan)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	player.set("_move_basis_latched", false)
	await process_frame
	return true


func _camera_reverse_checks(demo: Node3D) -> bool:
	var rig: Node3D = demo.get_node("CameraRig")
	var player: CharacterBody3D = demo.get_node("Player")
	var saved_position := player.global_position
	var saved_rotation := player.rotation
	var saved_yaw: float = rig.get("yaw")
	var saved_pitch: float = rig.get("pitch")
	var saved_distance: float = rig.get("distance")
	var saved_pan: Vector3 = rig.get("pan_offset")
	var saved_occlusion: float = rig.get("_occlusion_ratio")
	player.global_position = Vector3(0, 1.05, 5)
	player.rotation.y = 0.0
	rig.call("focus_after_teleport", 0.0, false)
	await process_frame

	var origin := player.global_position
	_key(KEY_W, true)
	for _frame in range(8):
		await physics_frame
		await process_frame
	var forward_travel := player.global_position - origin
	_key(KEY_W, false)
	await physics_frame
	if not _expect(forward_travel.z < -0.4 and absf(forward_travel.x) < 0.1, "W moves toward the camera aim (travel=%s)" % forward_travel):
		return false

	var reverse_start := player.global_position
	_key(KEY_S, true)
	for _frame in range(8):
		await physics_frame
		await process_frame
	var reverse_travel := player.global_position - reverse_start
	var reverse_yaw := float(rig.get("yaw"))
	print("Camera W/S trace: forward=%s, reverse=%s, reverse yaw=%.1f°, facing=%.1f°" % [forward_travel, reverse_travel, reverse_yaw, rad_to_deg(player.rotation.y)])
	if not _expect(reverse_travel.z > 0.4 and absf(reverse_travel.x) < 0.1 and absf(reverse_yaw) < 2.0 and absf(rad_to_deg(player.rotation.y)) < 2.0, "S backpedals opposite W without turning the actor or view (travel=%s, yaw=%.1f, facing=%.1f)" % [reverse_travel, reverse_yaw, rad_to_deg(player.rotation.y)]):
		return false
	_key(KEY_S, false)
	rig.call("_process", 1.5)
	if not _expect(absf(float(rig.get("yaw"))) < 2.0, "releasing S cannot trigger a delayed camera reversal"):
		return false
	var forward_again := player.global_position
	_key(KEY_W, true)
	for _frame in range(8):
		await physics_frame
		await process_frame
	var forward_again_travel := player.global_position - forward_again
	_key(KEY_W, false)
	await physics_frame
	if not _expect(forward_again_travel.z < -0.4 and absf(float(rig.get("yaw"))) < 2.0, "W after S still advances in the original forward direction (travel=%s, yaw=%.1f)" % [forward_again_travel, float(rig.get("yaw"))]):
		return false

	var stick_reverse_start := player.global_position
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	for _frame in range(8):
		await physics_frame
		await process_frame
	var stick_reverse_travel := player.global_position - stick_reverse_start
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await physics_frame
	if not _expect(stick_reverse_travel.z > 0.4 and absf(float(rig.get("yaw"))) < 2.0 and absf(rad_to_deg(player.rotation.y)) < 2.0, "left stick backward backpedals without an actor or camera flip (travel=%s, yaw=%.1f)" % [stick_reverse_travel, float(rig.get("yaw"))]):
		return false
	player.global_position = saved_position
	player.rotation = saved_rotation
	player.call("reset_movement_basis")
	rig.set("yaw", saved_yaw)
	rig.set("pitch", saved_pitch)
	rig.set("distance", saved_distance)
	rig.set("pan_offset", saved_pan)
	rig.set("_occlusion_ratio", saved_occlusion)
	rig.call("_process", 0.0)
	return true


func _camera_tower_occlusion_checks(demo: Node3D) -> bool:
	var rig: Node3D = demo.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera3D")
	var player: CharacterBody3D = demo.get_node("Player")
	var tower := demo.get_node("HubEnvironment/LandmarkTower") as Node3D
	var footprint := tower.get_node("TowerFootprint/CollisionShape3D") as CollisionShape3D
	var edge := (footprint.shape as BoxShape3D).size.x * 0.5
	var saved_position := player.global_position
	var saved_rotation := player.rotation
	var saved_yaw: float = rig.get("yaw")
	var saved_pan: Vector3 = rig.get("pan_offset")
	# Stand east of the tower and put the camera on its west side. The camera
	# ray crosses the upper tower above the low gameplay base footprint.
	player.global_position = tower.global_position + Vector3(edge + 2.2, 1.05, 0.0)
	player.rotation.y = deg_to_rad(-90.0)
	rig.set("yaw", -90.0)
	rig.set("pan_offset", Vector3.ZERO)
	rig.set("_orbit_grace_remaining", 0.0)
	rig.set("_manual_heading", false)
	rig.set("_occlusion_ratio", 1.0)
	for _frame in range(3):
		await physics_frame
		await process_frame
	var ratio := float(rig.get("_occlusion_ratio"))
	if not _expect(ratio < 0.55 and camera.global_position.x > tower.global_position.x + edge + 0.15, "tower occlusion pulls the close camera in front of visible stone instead of clipping through it (ratio=%.2f, eye=%s)" % [ratio, camera.global_position]):
		return false
	# Move onto the mapped CourtBluffWalk while clearing the tower. Its former
	# test point at this X and the tower's Z floated over an unwalkable gap.
	player.global_position = tower.global_position + Vector3(edge + 8.0, 1.05, 5.0)
	for _frame in range(24):
		await physics_frame
		await process_frame
	if not _expect(float(rig.get("_occlusion_ratio")) > 0.98, "camera eases back to normal chase distance after clearing tower (ratio=%.2f, player=%s, eye=%s)" % [float(rig.get("_occlusion_ratio")), player.global_position, camera.global_position]):
		return false
	player.global_position = saved_position
	player.rotation = saved_rotation
	rig.set("yaw", saved_yaw)
	rig.set("pan_offset", saved_pan)
	rig.set("_occlusion_ratio", 1.0)
	await process_frame
	return true


func _office_camera_transition_checks(scene: PackedScene) -> bool:
	var demo := scene.instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	var state: Dictionary = demo.get("_story_state")
	var flags: Dictionary = state.get("flags", {})
	flags["records_clue"] = true
	state["flags"] = flags
	demo.set("_story_state", state)
	var rig := demo.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	var player := demo.get_node("Player") as Node3D
	var office := demo.get_node("RecordsOffice") as Node3D
	rig.set("yaw", 128.0) # Arrive from a quay view facing away from the office.
	demo.call("_enter_records_office")
	for _frame in range(5):
		await physics_frame
		await process_frame
	var viewport_size := Vector2(1280.0, 800.0)
	var actor_screen := camera.unproject_position(player.global_position + Vector3.UP * 0.8) / viewport_size
	var cabinet_screen := camera.unproject_position((office.call("cabinet_position") as Vector3) + Vector3.UP * 0.8) / viewport_size
	if not _expect(bool(rig.get("_interior_view")) and absf(float(rig.get("yaw"))) < 0.1 and actor_screen.x > 0.35 and actor_screen.x < 0.65 and actor_screen.y > 0.35 and actor_screen.y < 0.7 and cabinet_screen.x > 0.2 and cabinet_screen.x < 0.6 and cabinet_screen.y > 0.1 and cabinet_screen.y < 0.5, "office transfer frames player and filing cabinet inside the cutaway room instead of facing sky (actor=%s, cabinet=%s)" % [actor_screen, cabinet_screen]):
		return false
	demo.call("_leave_records_office")
	await process_frame
	if not _expect(not bool(rig.get("_interior_view")) and absf(float(rig.get("pitch")) - 20.0) < 0.1 and player.global_position.x < 120.0, "return to quay restores the close outdoor chase camera"):
		return false
	var outward := player.global_position - (demo.get_node("HubEnvironment/RecordsDoor") as Node3D).global_position
	outward.y = 0.0
	outward = outward.normalized()
	var camera_forward := -camera.global_basis.z
	camera_forward.y = 0.0
	if not _expect((-player.global_basis.z).dot(outward) > 0.999 and camera_forward.normalized().dot(outward) > 0.999, "archive exit faces actor and camera outward through the doorway into Civic Court"):
		return false
	var guard := demo.get_node("HubEnvironment/RecordsDoor/CameraClearance") as StaticBody3D
	if not _expect((guard.collision_layer & (player as CharacterBody3D).collision_mask) == 0, "door camera clearance does not block the player approaching the interaction point"):
		return false
	var eye_probe := PhysicsShapeQueryParameters3D.new()
	var eye_shape := SphereShape3D.new()
	eye_shape.radius = 0.2
	eye_probe.shape = eye_shape
	eye_probe.transform.origin = camera.global_position
	eye_probe.exclude = [(player as CharacterBody3D).get_rid()]
	if not _expect(demo.get_world_3d().direct_space_state.intersect_shape(eye_probe).is_empty() and camera.global_position.distance_to(player.global_position + Vector3.UP * 0.7) > 3.5, "archive arrival gives the camera room behind the player and clearance from the protruding door surround"):
		return false
	# Check the near-plane corners against actual art, not only the collider.
	var door := demo.get_node("HubEnvironment/RecordsDoor") as Node3D
	var front_of_art := -INF
	for node in door.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := mesh.get_aabb()
		for point in range(8):
			front_of_art = maxf(front_of_art, mesh.to_global(bounds.get_endpoint(point)).x)
	for corner in [Vector2.ZERO, Vector2(1280, 0), Vector2(0, 800), Vector2(1280, 800)]:
		if not _expect(camera.project_position(corner, camera.near).x > front_of_art + 0.2, "archive arrival near plane stays entirely outside the door mesh"):
			return false
	var arrival := player.global_position
	_key(KEY_W, true)
	for _frame in range(8):
		await physics_frame
		await process_frame
	_key(KEY_W, false)
	var departure := player.global_position - arrival
	departure.y = 0.0
	if not _expect(departure.length() > 0.25 and departure.normalized().dot(outward) > 0.99, "W immediately walks away from the archive using the new arrival heading"):
		return false
	root.remove_child(demo)
	demo.queue_free()
	await process_frame
	return true

func _mesh_bottom_world(model: Node3D) -> float:
	var bottom := INF
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for child in meshes:
		var visual := child as MeshInstance3D
		if visual.mesh == null:
			continue
		var skeleton := visual.get_node_or_null(visual.skeleton) as Skeleton3D
		if visual.skin != null and skeleton != null:
			# Provider rigs have non-identity bind transforms. The static mesh
			# AABB is not the rendered boot position; evaluate the weighted pose.
			var matrices: Array[Transform3D] = []
			for bind in visual.skin.get_bind_count():
				var bone := skeleton.find_bone(visual.skin.get_bind_name(bind)) if not visual.skin.get_bind_name(bind).is_empty() else visual.skin.get_bind_bone(bind)
				matrices.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * visual.skin.get_bind_pose(bind))
			for surface in visual.mesh.get_surface_count():
				var arrays := visual.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var binds: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var stride := weights.size() / vertices.size()
				for vertex in vertices.size():
					var point := Vector3.ZERO
					for influence in stride:
						var index := vertex * stride + influence
						point += (matrices[binds[index]] * vertices[vertex]) * weights[index]
					bottom = minf(bottom, point.y)
			continue
		var bounds := visual.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					bottom = minf(bottom, visual.to_global(Vector3(x, y, z)).y)
	return bottom

func _ivo_grounding_checks(demo: Node3D) -> bool:
	var ivo: Node3D = demo.get_node("Ivo")
	var slot: Node3D = ivo.get_node("ModelSlot")
	var model: Node3D = demo.get_node("Ivo/ModelSlot/ImportedModel")
	var collider: StaticBody3D = demo.get_node("Ivo/Collider")
	var collision_shape: CollisionShape3D = collider.get_node("CollisionShape3D")
	var ray := PhysicsRayQueryParameters3D.create(ivo.global_position + Vector3.UP * 2.0, ivo.global_position + Vector3.DOWN * 4.0)
	ray.exclude = [collider.get_rid()]
	var floor_hit: Dictionary = demo.get_world_3d().direct_space_state.intersect_ray(ray)
	if not _expect(not floor_hit.is_empty() and floor_hit.get("collider") == demo.get_node("HubEnvironment/WalkableDistrict"), "Ivo stands over the walkable dock floor"):
		return false
	var floor_y: float = (floor_hit["position"] as Vector3).y
	var feet_y := _mesh_bottom_world(model)
	var collider_bottom := collision_shape.global_position.y - (collision_shape.shape as CapsuleShape3D).height * 0.5
	if not _expect(absf(feet_y - floor_y) < 0.015 and absf(collider_bottom - floor_y) < 0.015, "Ivo mesh feet and collider rest on the actual floor"):
		return false
	var shadow: MeshInstance3D = ivo.get_node_or_null("ContactShadow") as MeshInstance3D
	if not _expect(shadow != null and shadow.visible and absf(shadow.global_position.y - floor_y) < 0.02, "Ivo has a floor-bound contact shadow"):
		return false
	var rest_scale := model.scale
	for _step in range(4):
		ivo.call("_process", 0.4)
		if not _expect(absf(_mesh_bottom_world(model) - floor_y) < 0.015, "idle motion keeps Ivo's feet on the floor"):
			return false
	if not _expect(slot.call("motion_mode") == "rigged" and model.scale.is_equal_approx(rest_scale) and not bool(ivo.get("_use_procedural_idle")), "Ivo uses skeletal Idle without scaling his whole body"):
		return false
	return true

func _ivo_texture_check(demo: Node3D) -> bool:
	var model: Node3D = demo.get_node("Ivo/ModelSlot/ImportedModel")
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for child in meshes:
		var visual := child as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree():
			continue
		for surface in range(visual.mesh.get_surface_count()):
			var material := visual.get_active_material(surface) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				return _expect(true, "Ivo renders with the imported base-color texture")
	return _expect(false, "Ivo renders with the imported base-color texture")

func _mara_import_check(demo: Node3D) -> bool:
	var mara := demo.get_node("Mara") as Node3D
	var model := mara.get_node_or_null("ModelSlot/ImportedModel") as Node3D
	var body := mara.get_node("Body") as MeshInstance3D
	var shade := mara.get_node("LampShade") as MeshInstance3D
	var lamp := mara.get_node("Lamp") as OmniLight3D
	if not _expect(model != null and not body.visible and not shade.visible and lamp.light_energy == 0.0, "Mara's textured model replaces primitive art and does not emit a personal orange light"):
		return false
	var textured := false
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for child in meshes:
		var visual := child as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree():
			continue
		for surface in range(visual.mesh.get_surface_count()):
			var material := visual.get_active_material(surface) as BaseMaterial3D
			textured = textured or (material != null and material.albedo_texture != null)
	if not _expect(textured, "Mara renders with the imported base-color texture"):
		return false
	var collider := mara.get_node("Collider") as StaticBody3D
	var collision_shape := collider.get_node("CollisionShape3D") as CollisionShape3D
	var ray := PhysicsRayQueryParameters3D.create(mara.global_position + Vector3.UP * 2.0, mara.global_position + Vector3.DOWN * 4.0)
	ray.exclude = [collider.get_rid()]
	var floor_hit: Dictionary = demo.get_world_3d().direct_space_state.intersect_ray(ray)
	if not _expect(not floor_hit.is_empty() and floor_hit.get("collider") == demo.get_node("HubEnvironment/WalkableDistrict"), "Mara stands over the central quay floor"):
		return false
	var floor_y: float = (floor_hit["position"] as Vector3).y
	var collider_bottom := collision_shape.global_position.y - (collision_shape.shape as CapsuleShape3D).height * 0.5
	if not _expect(absf(_mesh_bottom_world(model) - floor_y) < 0.015 and absf(collider_bottom - floor_y) < 0.015, "Mara's feet and collider rest on the actual floor"):
		return false
	var shadow := mara.get_node_or_null("ContactShadow") as MeshInstance3D
	if not _expect(shadow != null and shadow.visible and absf(shadow.global_position.y - floor_y) < 0.02, "Mara keeps a floor-bound contact shadow"):
		return false
	for _step in range(4):
		mara.call("_process", 0.4)
		if not _expect(absf(_mesh_bottom_world(model) - floor_y) < 0.015, "Mara's idle keeps her feet on the floor"):
			return false
	return true

func _new_character_import_checks(demo: Node3D) -> bool:
	for actor_name in ["Player", "CivicClerk", "Vendor"]:
		var actor := demo.get_node(actor_name) as Node3D
		var model := actor.get_node_or_null("ModelSlot/ImportedModel") as Node3D
		if not _expect(model != null and not actor.get_node("Body").visible, "%s uses its supplied Meshy model instead of the primitive body" % actor_name):
			return false
		if actor_name == "CivicClerk" and not _expect(not actor.get_node("Ledger").visible, "clerk model replaces the primitive ledger"):
			return false
		if actor_name == "Vendor" and not _expect(not actor.get_node("Pack").visible, "merchant model replaces the primitive pack"):
			return false
		var textured := false
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			meshes.push_front(model)
		for child in meshes:
			var visual := child as MeshInstance3D
			if visual.mesh == null:
				continue
			for surface in range(visual.mesh.get_surface_count()):
				var material := visual.get_active_material(surface) as BaseMaterial3D
				textured = textured or (material != null and material.albedo_texture != null)
		if not _expect(textured, "%s keeps its imported color texture" % actor_name):
			return false
		var collider := actor as CollisionObject3D
		if collider == null:
			collider = actor.get_node("Collider") as CollisionObject3D
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 2.0, actor.global_position + Vector3.DOWN * 4.0)
		ray.exclude = [collider.get_rid()]
		var floor_hit: Dictionary = demo.get_world_3d().direct_space_state.intersect_ray(ray)
		if not _expect(not floor_hit.is_empty() and floor_hit.get("collider") == demo.get_node("RecordsOffice/Structure" if actor_name == "CivicClerk" else "HubEnvironment/WalkableDistrict"), "%s stands over its room or district floor" % actor_name):
			return false
		var floor_y: float = (floor_hit["position"] as Vector3).y
		if not _expect(absf(_mesh_bottom_world(model) - floor_y) < 0.08, "%s model feet are near the floor" % actor_name):
			return false
	return true

func _bone_track_count(clip: Animation, skeleton: Skeleton3D) -> int:
	var count := 0
	for index in range(clip.get_track_count()):
		var kind := clip.track_get_type(index)
		if kind != Animation.TYPE_POSITION_3D and kind != Animation.TYPE_ROTATION_3D and kind != Animation.TYPE_SCALE_3D:
			continue
		var path := clip.track_get_path(index)
		if path.get_subname_count() > 0 and skeleton.find_bone(String(path.get_subname(0))) >= 0:
			count += 1
	return count

func _walk_changes_bone_pose(player: AnimationPlayer, clip_name: StringName, skeleton: Skeleton3D) -> bool:
	var clip := player.get_animation(clip_name)
	player.play(clip_name)
	player.seek(0.0, true)
	player.advance(0.0)
	var start: Array[Transform3D] = []
	for bone in range(skeleton.get_bone_count()):
		start.append(skeleton.get_bone_pose(bone))
	for fraction in [0.23, 0.61]:
		player.seek(clip.length * fraction, true)
		player.advance(0.0)
		for bone in range(skeleton.get_bone_count()):
			if not skeleton.get_bone_pose(bone).is_equal_approx(start[bone]):
				return true
	return false

func _rigged_character_checks(demo: Node3D) -> bool:
	for entry in [
		{"actor": "Player", "file": "player", "second": "Walk"},
		{"actor": "Mara", "file": "mara", "second": "Talk"},
		{"actor": "Ivo", "file": "ivo", "second": "Talk"},
		{"actor": "CivicClerk", "file": "clerk", "second": "Talk"},
		{"actor": "Vendor", "file": "vendor", "second": "Talk"},
	]:
		var actor_name: String = entry["actor"]
		var slot: Node3D = demo.get_node("%s/ModelSlot" % actor_name)
		var expected_path := "res://assets/meshes/rigged/%s_rigged.glb" % entry["file"]
		if not _expect(slot.call("motion_mode") == "rigged" and slot.call("active_model_path") == expected_path, "%s selects its rigged GLB" % actor_name):
			return false
		var model: Node3D = slot.get_node("ImportedModel")
		var skinned_mesh: MeshInstance3D
		var skeleton: Skeleton3D
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var visual := child as MeshInstance3D
			if visual.mesh == null or visual.skin == null or visual.skin.get_bind_count() == 0:
				continue
			var bound := visual.get_node_or_null(visual.skeleton) as Skeleton3D
			if bound == null or bound.get_bone_count() < 2:
				continue
			for surface in range(visual.mesh.get_surface_count()):
				var arrays := visual.mesh.surface_get_arrays(surface)
				var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				if bones.size() != weights.size() or weights.size() < 4:
					continue
				var weighted_vertices := 0
				for vertex in range(weights.size() / 4):
					var total := 0.0
					for influence in range(4):
						var at := vertex * 4 + influence
						if bones[at] >= 0 and bones[at] < visual.skin.get_bind_count():
							total += weights[at]
					if total > 0.9:
						weighted_vertices += 1
				if weighted_vertices == arrays[Mesh.ARRAY_VERTEX].size():
					skinned_mesh = visual
					skeleton = bound
					break
			if skinned_mesh != null:
				break
		if not _expect(skinned_mesh != null and skeleton != null, "%s has a Godot Skin and weighted vertices bound to a Skeleton3D" % actor_name):
			return false
		var animator: AnimationPlayer = slot.get("_animation_player") as AnimationPlayer
		var idle_name: StringName = slot.get("_idle_clip")
		var second_name: StringName = slot.get("_walk_clip") if entry["second"] == "Walk" else slot.get("_talk_clip")
		if not _expect(animator != null and animator.has_animation(idle_name) and animator.has_animation(second_name), "%s imports Idle and %s clips" % [actor_name, entry["second"]]):
			return false
		var idle := animator.get_animation(idle_name)
		var second := animator.get_animation(second_name)
		if not _expect(_bone_track_count(idle, skeleton) > 0 and _bone_track_count(second, skeleton) > 0, "%s clips target real skeleton bones" % actor_name):
			return false
		if not _expect(idle.loop_mode == Animation.LOOP_LINEAR and second.loop_mode == Animation.LOOP_LINEAR, "%s scene loops Idle and %s" % [actor_name, entry["second"]]):
			return false
		if not _expect(_walk_changes_bone_pose(animator, second_name, skeleton), "%s %s clip changes an imported bone pose" % [actor_name, entry["second"]]):
			return false
		if actor_name == "Ivo" and not _expect(_walk_changes_bone_pose(animator, idle_name, skeleton), "Ivo Idle clip changes an imported bone pose"):
			return false
		if not _cadenced_idle_check(actor_name, animator, idle_name, skeleton):
			return false
		if entry["second"] == "Talk":
			if not _expect(is_equal_approx(idle.length, second.length), actor_name + " keeps the same body cadence while talking") or not _cadenced_idle_check(actor_name + " Talk", animator, second_name, skeleton):
				return false
		animator.play(idle_name)
		if actor_name != "Player":
			if not _expect(not bool(demo.get_node(actor_name).get("_use_procedural_idle")), "%s uses skeletal Idle without whole-body procedural breathing" % actor_name):
				return false
	return true

func _cadenced_idle_check(actor_name: String, animator: AnimationPlayer, idle_name: StringName, skeleton: Skeleton3D) -> bool:
	var duration := animator.get_animation(idle_name).length
	if not _expect(duration >= 7.0 and duration <= 8.5, actor_name + " sways once per eight slow beats"):
		return false
	var head := skeleton.find_bone("Head")
	var chest := skeleton.find_bone("Chest")
	var foot := skeleton.find_bone("LFoot")
	var other_foot := skeleton.find_bone("RFoot")
	if not _expect(head >= 0 and chest >= 0 and foot >= 0 and other_foot >= 0, actor_name + " has breathing and grounding joints"):
		return false
	animator.play(idle_name)
	animator.seek(0.0, true)
	var head_start := skeleton.to_global(skeleton.get_bone_global_pose(head).origin)
	var foot_start := skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
	var other_foot_start := skeleton.to_global(skeleton.get_bone_global_pose(other_foot).origin)
	var chest_start := skeleton.get_bone_pose_rotation(chest)
	var max_head_motion := 0.0
	var max_foot_motion := 0.0
	var max_breath := 0.0
	for sample_index in range(1, 33):
		animator.seek(duration * sample_index / 32.0, true)
		max_head_motion = maxf(max_head_motion, head_start.distance_to(skeleton.to_global(skeleton.get_bone_global_pose(head).origin)))
		max_foot_motion = maxf(max_foot_motion, foot_start.distance_to(skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)))
		max_foot_motion = maxf(max_foot_motion, other_foot_start.distance_to(skeleton.to_global(skeleton.get_bone_global_pose(other_foot).origin)))
		max_breath = maxf(max_breath, chest_start.angle_to(skeleton.get_bone_pose_rotation(chest)))
	print("SWAY %s period=%.3fs head=%.3fmm foot=%.3fmm chest=%.3fdeg" % [actor_name, duration, max_head_motion * 1000.0, max_foot_motion * 1000.0, rad_to_deg(max_breath)])
	if not _expect(head_start.distance_to(skeleton.to_global(skeleton.get_bone_global_pose(head).origin)) < 0.001, actor_name + " returns smoothly to the starting idle pose at the loop seam"):
		return false
	# Compare sway to this rig's standing span, rather than the former stand-in's
	# absolute head travel. Foot contact, cadence, chest rotation and seam checks
	# retain their separate limits after the provider rig/retargeting change.
	var standing_span := head_start.distance_to((foot_start + other_foot_start) * .5)
	var relative_sway := max_head_motion / standing_span
	return _expect(relative_sway > 0.004 and relative_sway < 0.03 and max_foot_motion < 0.002 and max_breath > deg_to_rad(0.5) and max_breath < deg_to_rad(1.5), actor_name + " has perceptible slow torso motion with both feet planted")

func _tower_import_check(demo: Node3D) -> bool:
	var tower := demo.get_node("HubEnvironment/LandmarkTower") as Node3D
	var art := tower.get_node("TowerArt") as Node3D
	var imported := tower.get_node_or_null("ImportedTowerArt") as Node3D
	var footprint := tower.get_node("TowerFootprint/CollisionShape3D") as CollisionShape3D
	var light := tower.get_node_or_null("BeaconLight") as OmniLight3D
	if not _expect(imported != null and not art.visible and light != null, "textured tower replaces primitive art while keeping its beacon light"):
		return false
	if not _expect(footprint.shape is BoxShape3D and (footprint.shape as BoxShape3D).size.is_equal_approx(Vector3(5.2, 10.7, 5.2)) and absf(footprint.position.y - 5.35) < 0.01, "imported tower has a full-height, 5.2 metre camera and gameplay collider"):
		return false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var has_color_texture := false
	var meshes: Array[Node] = imported.find_children("*", "MeshInstance3D", true, false)
	if imported is MeshInstance3D:
		meshes.push_front(imported)
	for child in meshes:
		var visual := child as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree():
			continue
		for surface in range(visual.mesh.get_surface_count()):
			var material := visual.get_active_material(surface)
			if material is BaseMaterial3D:
				has_color_texture = has_color_texture or material.albedo_texture != null
			elif material is ShaderMaterial:
				has_color_texture = has_color_texture or material.get_shader_parameter("albedo_map") is Texture2D
		var bounds := visual.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point := tower.to_local(visual.to_global(Vector3(x, y, z)))
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	if not _expect(has_color_texture, "tower renders with an imported base-color texture"):
		return false
	return _expect(absf(minimum.y) < 0.02 and maximum.y > 10.6 and maximum.y < 10.7 and maxf(absf(minimum.x), absf(maximum.x)) < 2.6 and maxf(absf(minimum.z), absf(maximum.z)) < 2.6, "imported tower rests at ground and reads as a broad, door-scale landmark")

func _garden_import_check(demo: Node3D) -> bool:
	var hub := demo.get_node("HubEnvironment") as Node3D
	var details := hub.get_node("DistrictDetails") as Node3D
	var imported := details.get_node_or_null("ImportedGardenArt") as Node3D
	var floor_visual := hub.get_node("WalkableDistrict/LanternGarden") as MeshInstance3D
	if not _expect(imported != null and imported.visible and not floor_visual.visible, "supplied Seaside Garden art replaces the garden blockout floor skin"):
		return false
	for old_name in ["GardenTree0", "GardenBedNorthWest", "GardenPathEntry"]:
		if not _expect(details.get_node_or_null(old_name) == null, "imported garden retires primitive %s" % old_name):
			return false
	var renderable_surfaces := 0
	var textured := false
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var meshes: Array[Node] = imported.find_children("*", "MeshInstance3D", true, false)
	if imported is MeshInstance3D:
		meshes.push_front(imported)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null or not visual.is_visible_in_tree():
			continue
		for surface in range(visual.mesh.get_surface_count()):
			if visual.mesh.surface_get_array_len(surface) == 0:
				continue
			renderable_surfaces += 1
			var material := visual.get_active_material(surface) as BaseMaterial3D
			textured = textured or (material != null and material.albedo_texture != null)
		var bounds := visual.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point := visual.to_global(Vector3(x, y, z))
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	if not _expect(renderable_surfaces > 0 and textured, "garden contains visible textured triangles from the supplied mesh"):
		return false
	if not _expect(minimum.x < 33.0 and maximum.x > 48.0 and minimum.z < -6.5 and maximum.z > 2.5 and maximum.y > 2.8, "imported garden spans the west bridge entrance and full east terrace"):
		return false
	var floor_shape := hub.get_node("DistrictDetails/GardenWalkCollision/Terrace") as CollisionShape3D
	return _expect(floor_shape != null and floor_shape.shape is BoxShape3D and not floor_shape.disabled, "garden keeps a simple, walkable collision floor")

func _choice(view: Dictionary, id: String) -> Dictionary:
	for item in view.get("choices", []):
		if item.get("id", "") == id:
			return item
	return {}

func _current_view(demo: Node3D) -> Dictionary:
	var native_bridge: Object = demo.get("bridge")
	return _json(str(native_bridge.call("view"))).get("data", {})

func _dialogue_camera_checks(demo: Node3D, actor: Node3D) -> bool:
	var rig: Node3D = demo.get_node("CameraRig")
	rig.call("_process", 0.5)
	var camera: Camera3D = rig.get_node("Camera3D")
	var face := actor.global_position + Vector3.UP * 0.85
	var viewport_size := root.get_visible_rect().size
	var screen := camera.unproject_position(face)
	var x := screen.x / viewport_size.x
	var y := screen.y / viewport_size.y
	var front := (camera.global_position - actor.global_position).normalized().dot(actor.global_basis.z)
	var label := actor.get_node_or_null("Name") as Label3D
	return _expect(not camera.is_position_behind(face) and camera.fov < 60.0 and x > 0.48 and x < 0.75 and y > 0.12 and y < 0.52 and front > 0.5, "%s dialogue shot frames the NPC face slightly off center (x=%.3f, y=%.3f, front=%.3f)" % [actor.name, x, y, front]) \
		and _expect(label == null or not label.visible, "%s nameplate hides during cinematic dialogue" % actor.name)

func _enter_npc(demo: Node3D, npc_path: String, expected_node: String, expected_speaker: String) -> bool:
	var actor: Node3D = demo.get_node(npc_path)
	var player: CharacterBody3D = demo.get_node("Player")
	player.global_position = actor.global_position + Vector3(2, 0, 0)
	_joy(0, false)
	await process_frame
	_joy(0, true)
	await process_frame
	var panel: Control = demo.get_node("CanvasLayer/DialoguePanel")
	var view: Dictionary = _current_view(demo)
	var slot: Node3D = actor.get_node("ModelSlot")
	if slot.call("motion_mode") == "rigged" and slot.get("_talk_clip") != &"":
		var animator: AnimationPlayer = slot.get("_animation_player") as AnimationPlayer
		if not _expect(animator.current_animation == slot.get("_talk_clip"), "%s plays its skeletal Talk gesture during dialogue" % npc_path):
			return false
	return _expect(demo.get("mode") == "dialogue" and panel.visible, "%s opens with controller A (mode=%s, player=%s, npc=%s, nearest=%s, status=%s, interact=%s)" % [npc_path, demo.get("mode"), player.global_position, actor.global_position, demo.call("_nearest_npc"), demo.get_node("CanvasLayer/Status").text, Input.is_action_pressed("interact")]) \
		and _expect(view.get("node_id", "") == expected_node and panel.get_node("Panel/Margin/VBox/Speaker").text == expected_speaker, "%s uses its own narrative entry" % npc_path) \
		and _dialogue_camera_checks(demo, actor)

func _leave_npc(demo: Node3D) -> bool:
	await _complete_player_reply(demo)
	if _current_view(demo).get("return_to") != null:
		_joy(0, false)
		_joy(1, true)
		await process_frame
		_joy(1, false)
		await process_frame
		if not _expect(demo.get("mode") == "dialogue" and _current_view(demo).get("return_to") == null, "B skips a response back to its menu before leaving"):
			return false
	_joy(0, false)
	await process_frame
	_joy(1, true)
	await process_frame
	var panel: Control = demo.get_node("CanvasLayer/DialoguePanel")
	var left: bool = _expect(demo.get("mode") == "explore" and not panel.visible, "controller B closes NPC dialogue")
	var rig: Node3D = demo.get_node("CameraRig")
	rig.call("_process", 0.5)
	var camera: Camera3D = rig.get_node("Camera3D")
	var exploration_pose: Transform3D = rig.call("_exploration_pose")
	left = _expect(camera.global_position.distance_to(exploration_pose.origin) < 0.02 and is_equal_approx(camera.fov, 75.0), "controller B restores exploration camera framing") and left
	var visible_badges := 0
	for npc in ["Mara", "Ivo", "CivicClerk", "Vendor"]:
		if demo.get_node("%s/Name" % npc).visible: visible_badges += 1
	left = _expect(visible_badges <= 1, "Only the reticled actor may show a nameplate after dialogue") and left
	for actor_name in ["Ivo", "CivicClerk", "Vendor"]:
		var slot: Node3D = demo.get_node("%s/ModelSlot" % actor_name)
		if slot.call("motion_mode") == "rigged":
			var animator: AnimationPlayer = slot.get("_animation_player") as AnimationPlayer
			var expected = slot.get("_walk_clip") if float(slot.get("locomotion_speed")) > .08 else slot.get("_idle_clip")
			left = _expect(animator.current_animation == expected, "%s resumes its travel or idle animation after dialogue" % actor_name) and left
	_joy(1, false)
	await process_frame
	return left

func _complete_player_reply(demo: Node3D) -> void:
	var panel := demo.get_node("CanvasLayer/DialoguePanel")
	if panel.get("_player_reply"):
		panel.call("_finish_line")
		await process_frame

func _barriers_match(demo: Node3D, gate_open: bool, shortcut_open: bool, context: String) -> bool:
	await _complete_player_reply(demo)
	# set_deferred("disabled") is committed by the next physics frame.
	await physics_frame
	var hub: Node3D = demo.get_node("HubEnvironment")
	var gate: StaticBody3D = hub.get_node("EastGardenGate/Barrier")
	var shortcut: StaticBody3D = hub.get_node("MarketCourtShortcut/Barrier")
	var gate_shape: CollisionShape3D = gate.get_node("CollisionShape3D")
	var shortcut_shape: CollisionShape3D = shortcut.get_node("CollisionShape3D")
	var physics: PhysicsDirectSpaceState3D = demo.get_world_3d().direct_space_state
	var gate_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30, 1, -2), Vector3(34, 1, -2)))
	var shortcut_hit: Dictionary = physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-20, 1, -15), Vector3(-20, 1, -9)))
	return _expect(bool(hub.call("is_gate_open")) == gate_open and bool(hub.call("is_shortcut_open")) == shortcut_open, "%s: hub access follows narrative flags" % context) \
		and _expect(gate.visible == not gate_open and shortcut.visible == not shortcut_open, "%s: route barriers change visually" % context) \
		and _expect(gate_shape.disabled == gate_open and shortcut_shape.disabled == shortcut_open, "%s: route collision shapes change after physics frame" % context) \
		and _expect((gate_hit.get("collider") == gate) == not gate_open and (shortcut_hit.get("collider") == shortcut) == not shortcut_open, "%s: physics rays can cross only opened routes" % context)

func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	if not _expect(ClassDB.class_exists("NarrativeBridge"), "native extension must load"):
		return
	var source: String = FileAccess.get_file_as_string("res://content/lantern_quay.json")
	var bridge: Object = ClassDB.instantiate("NarrativeBridge") as Object
	if not _expect(_json(str(bridge.call("load_story", source))).get("ok", false), "story loads"):
		return
	if not _expect(str(_json(str(bridge.call("begin"))).get("data", {}).get("text", "")).contains("tower"), "initial line"):
		return
	var choice: Dictionary = _json(str(bridge.call("choose", "share_oil")))
	if not _expect(choice.get("ok", false) and choice.get("data", {}).get("node_id") == "mara_thanks", "choice reaches thanks"):
		return
	var greeting: Dictionary = _json(str(bridge.call("finish_response")))
	if not _expect(str(greeting.get("data", {}).get("text", "")).contains("tower"), "later line reflects the choice"):
		return
	var saved: Dictionary = _json(str(bridge.call("save_json")))
	var restored: Object = ClassDB.instantiate("NarrativeBridge") as Object
	if not _expect(_json(str(restored.call("load_story", source))).get("ok", false), "second bridge loads story"):
		return
	if not _expect(_json(str(restored.call("load_save", saved.get("data", {}).get("save", "")))).get("ok", false), "native save reloads"):
		return
	if not _expect(str(_json(str(restored.call("view"))).get("data", {}).get("text", "")).contains("tower"), "reloaded line persists"):
		return
	var event_result: Dictionary = _json(str(restored.call("choose_with_events", "ask_for_favor")))
	var event_data: Dictionary = event_result.get("data", {})
	if not _expect(event_result.get("ok", false) and event_data.get("view", {}).get("node_id") == "tide_gate", "committed choice reaches tide gate"):
		return
	if not _expect(event_data.get("events", []).size() == 1 and event_data.get("events", [])[0].get("kind") == "choice_committed", "native adapter exposes committed choice event"):
		return

	var scene: PackedScene = load("res://scenes/demo.tscn")
	if not _expect(scene != null, "demo scene loads"):
		return
	var demo: Node3D = scene.instantiate() as Node3D
	demo.set("save_path", TEST_SAVE)
	root.add_child(demo)
	await process_frame
	if not await _camera_checks(demo):
		return
	if not await _camera_auto_follow_checks(demo):
		return
	if not await _camera_reverse_checks(demo):
		return
	if not await _camera_tower_occlusion_checks(demo):
		return
	if not _mara_import_check(demo):
		return
	if not _new_character_import_checks(demo):
		return
	if not _rigged_character_checks(demo):
		return
	if not _expect(demo.has_node("Ivo/ModelSlot/ImportedModel") and not demo.get_node("Ivo/Body").visible and not demo.get_node("Ivo/Mantle").visible, "Ivo GLB imports and replaces primitive visuals"):
		return
	if not _tower_import_check(demo):
		return
	if not _garden_import_check(demo):
		return
	if not _ivo_texture_check(demo):
		return
	if not await _ivo_grounding_checks(demo):
		return
	if not await _barriers_match(demo, false, false, "new game"):
		return
	var player: CharacterBody3D = demo.get_node("Player")
	var initial_position: Vector3 = player.global_position
	var rig: Node3D = demo.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("Camera3D")
	var initial_camera_position: Vector3 = camera.global_position
	_axis(1, -1.0)
	for _frame in range(15):
		await physics_frame
	await process_frame
	var traveled := player.global_position - initial_position
	var player_forward := -player.global_transform.basis.z
	var model: Node3D = demo.get_node("Player/ModelSlot/ImportedModel")
	var animation_player: AnimationPlayer = demo.get_node("Player/ModelSlot").get("_animation_player") as AnimationPlayer
	if not _expect(player_forward.normalized().dot(traveled.normalized()) > 0.9 and model.global_transform.basis.z.normalized().dot(traveled.normalized()) > 0.9, "forward walking turns both actor and imported visual face away from the camera"):
		return
	rig.call("_process", 0.0)
	var chase_pose := rig.call("_exploration_pose") as Transform3D
	if not _expect(camera.global_position.distance_to(chase_pose.origin) < 0.02 and camera.global_position.distance_to(initial_camera_position) > 0.3, "close chase camera tracks the moving player without position lag (pose gap=%.3f, camera shift=%.3f, travel=%s, eye=%s, desired=%s)" % [camera.global_position.distance_to(chase_pose.origin), camera.global_position.distance_to(initial_camera_position), traveled, camera.global_position, chase_pose.origin]):
		return
	var player_slot := demo.get_node("Player/ModelSlot")
	var expected_gait: StringName = player_slot.get("_run_clip") if player.velocity.length() >= player_slot.run_speed_threshold else player_slot.get("_walk_clip")
	var expected_cycle: float = player_slot.run_cycle_distance if expected_gait == player_slot.get("_run_clip") else player_slot.walk_cycle_distance
	var cycle_travel := player.velocity.length() * animation_player.current_animation_length / animation_player.speed_scale
	print("LOCOMOTION clip=%s rate=%.3f speed=%.3f span=%.3f expected=%.3f" % [animation_player.current_animation, animation_player.speed_scale, player.velocity.length(), cycle_travel, expected_cycle])
	if not _expect(animation_player.current_animation == expected_gait and absf(cycle_travel - expected_cycle) < .03, "player's skeletal gait matches its measured travel distance"):
		return
	_axis(1, 0.0)
	await physics_frame
	if not _expect(player.global_position.z < initial_position.z - 0.1, "left stick moves player toward Mara (start=%s, end=%s)" % [initial_position, player.global_position]):
		return
	await process_frame
	await process_frame
	if not _expect(animation_player.current_animation == demo.get_node("Player/ModelSlot").get("_idle_clip") and is_equal_approx(animation_player.speed_scale, 1.0), "releasing the stick returns the player to normal-speed Idle (clip=%s, speed=%s, velocity=%s, axis=%s)" % [animation_player.current_animation, animation_player.speed_scale, player.velocity, Input.get_axis("move_forward", "move_back")]):
		return
	_axis(1, 1.0)
	for _frame in range(3):
		await physics_frame
		await process_frame
	if not _expect(bool(player.get("backpedaling")) and animation_player.current_animation == demo.get_node("Player/ModelSlot").get("_walk_clip") and animation_player.speed_scale < -0.6, "reverse stick travel runs the skinned Walk clip backward"):
		return
	_axis(1, 0.0)
	await physics_frame
	await process_frame
	if not await _enter_npc(demo, "Ivo", "ivo_gate", "Ivo"):
		return
	if not _expect(not _choice(_current_view(demo), "open_gate").get("enabled", false), "Ivo needs Mara to join before opening the gate"):
		return
	var yaw_in_dialogue: float = rig.get("yaw")
	var distance_in_dialogue: float = rig.get("distance")
	_mouse_drag(MOUSE_BUTTON_MASK_RIGHT, Vector2(80, 40))
	_mouse_wheel(MOUSE_BUTTON_WHEEL_UP)
	await process_frame
	if not _expect(is_equal_approx(float(rig.get("yaw")), yaw_in_dialogue) and is_equal_approx(float(rig.get("distance")), distance_in_dialogue), "camera input pauses during conversation"):
		return
	if not await _leave_npc(demo):
		return
	if not await _enter_npc(demo, "CivicClerk", "clerk_greeting", "Clerk"):
		return
	if not _expect(_choice(_current_view(demo), "open_shortcut").get("enabled", false), "Optional shortcut has no morality requirement"):
		return
	if not await _leave_npc(demo):
		return
	player.global_position = Vector3(0, 1, 1)
	_joy(0, true)
	await process_frame
	if not _expect(demo.get("mode") == "dialogue", "controller A enters nearby dialogue"):
		return
	var panel: Control = demo.get_node("CanvasLayer/DialoguePanel")
	if not _expect(panel.visible and panel.get("selected_index") == 0, "first enabled choice is focused"):
		return
	if not _expect(str(panel.get_node("Panel/Margin/VBox/Subtitle").text).contains("tower"), "opening press does not also confirm a choice"):
		return
	if not _expect(panel.get_node("VoicePlayer").stream == preload("res://scripts/voice_library.gd").clip("Mara", panel.get_node("Panel/Margin/VBox/Subtitle").text), "exact greeting selects its recorded audio"):
		return
	_joy(12, true)
	await process_frame
	if not _expect(panel.get("selected_index") == 1, "D-pad down moves to next choice"):
		return
	_joy(12, false)
	_joy(12, true)
	await process_frame
	if not _expect(panel.get("selected_index") == 2, "D-pad reaches the next optional question"):
		return
	for _step in range(_current_view(demo).choices.size() - 1 - 2):
		_joy(12, false)
		_joy(12, true)
		await process_frame
	_joy(12, false)
	_joy(12, true)
	await process_frame
	if not _expect(panel.get("selected_index") == 0, "D-pad wraps from Leave to the first choice"):
		return
	for button in panel.buttons:
		if button.get_meta("choice_id") == "share_oil": panel._select_index(panel.buttons.find(button))
	_joy(12, false)
	_joy(0, false)
	_joy(0, true)
	await process_frame
	await _complete_player_reply(demo)
	if not _expect(panel.get_node("Panel/Margin/VBox/Speaker").text == "Mara", "controller A selects a choice"):
		return
	if not _expect(demo.hub.is_beacon_lit() and demo.lamp.light_energy == 0.0, "choice changes encounter light"):
		return
	if not await _barriers_match(demo, false, false, "after sharing oil"):
		return
	_joy(0, false)
	await process_frame
	_joy(1, true)
	await process_frame
	if not _expect(str(panel.get_node("Panel/Margin/VBox/Subtitle").text).contains("tower"), "B skips the response to the changed question menu"):
		return
	_joy(1, false)
	await process_frame
	_joy(6, true)
	await process_frame
	await process_frame
	if not _expect(demo.get("mode") == "menu" and demo.get_node("CanvasLayer/JournalMenu").visible and panel.visible, "controller Start opens the journal during dialogue"):
		return
	_joy(6, false)
	await process_frame
	_joy(1, true)
	await process_frame
	_joy(1, false)
	await process_frame
	if not _expect(demo.get("mode") == "dialogue" and panel.visible, "controller B closes the journal and resumes dialogue"):
		return
	_key(KEY_F5, true)
	await process_frame
	_key(KEY_F5, false)
	if not _expect(FileAccess.file_exists(TEST_SAVE), "F5 saves active dialogue"):
		return
	player.global_position = Vector3(1, 1, 1)
	_key(KEY_F9, true)
	await process_frame
	if not _expect(demo.get("mode") == "dialogue" and panel.visible, "F9 resumes saved active dialogue"):
		return
	if not _expect(demo.hub.is_beacon_lit() and demo.lamp.light_energy == 0.0 and player.global_position.distance_to(Vector3(0, 1, 1)) < 0.2, "active dialogue reload restores saved state and position"):
		return
	if not _expect(str(panel.get_node("Panel/Margin/VBox/Subtitle").text).contains("tower"), "active dialogue reload restores current line"):
		return
	_key(KEY_F9, false)
	await process_frame
	_joy(1, true)
	await process_frame
	if not _expect(demo.get("mode") == "explore", "controller B returns to exploration"):
		return
	_joy(1, false)
	_key(KEY_F5, true)
	await process_frame
	if not _expect(FileAccess.file_exists(TEST_SAVE), "F5 saves exploration"):
		return
	_key(KEY_F5, false)
	root.remove_child(demo)
	demo.queue_free()
	await process_frame

	var reloaded: Node3D = scene.instantiate() as Node3D
	reloaded.set("save_path", TEST_SAVE)
	root.add_child(reloaded)
	await process_frame
	_key(KEY_F9, true)
	await process_frame
	if not _expect(reloaded.hub.is_beacon_lit() and reloaded.lamp.light_energy == 0.0, "F9 reloads world consequence"):
		return
	if not _expect(reloaded.get_node("Player").global_position.distance_to(Vector3(0, 1, 1)) < 0.2, "reload restores position"):
		return
	_key(KEY_F9, false)
	if not await _barriers_match(reloaded, false, false, "reloaded oil choice"):
		return
	if not await _enter_npc(reloaded, "Mara", "mara_greeting", "Mara"):
		return
	if not _expect(str(_current_view(reloaded).get("text", "")).contains("tower"), "Mara's changed greeting persists in the hub"):
		return
	if not _expect(_choice(_current_view(reloaded), "ask_for_favor").get("enabled", false), "Ivo location question is available after sharing oil"):
		return
	var reloaded_panel = reloaded.panel
	for button in reloaded_panel.buttons:
		if button.get_meta("choice_id") == "ask_for_favor": reloaded_panel._select_index(reloaded_panel.buttons.find(button))
	_joy(0, false)
	await process_frame
	_joy(0, true)
	await process_frame
	await _complete_player_reply(reloaded)
	if not _expect(_current_view(reloaded).get("node_id", "") == "tide_gate", "controller A asks where Ivo stands watch"):
		return
	_joy(0, false)
	await process_frame
	_joy(1, true)
	await process_frame
	_joy(1, false)
	await process_frame
	var repeated_ivo: Dictionary = _choice(_current_view(reloaded), "ask_for_favor")
	var repeat_buttons: Array = reloaded.get_node("CanvasLayer/DialoguePanel").get("buttons").filter(func(b): return b.get_meta("choice_id") == "ask_for_favor")
	if not _expect(not repeated_ivo.get("enabled", true) and repeated_ivo.get("completed", false) and str(repeated_ivo.get("locked_reason", "")) == "Already asked" and repeat_buttons.size() == 1 and (repeat_buttons[0] as Button).disabled and (repeat_buttons[0] as Button).text.begins_with("✓") and (repeat_buttons[0] as Button).text.contains("Already asked"), "asked Ivo question remains visible and greyed as completed"):
		return
	if not await _leave_npc(reloaded):
		return
	if not await _enter_npc(reloaded, "Vendor", "vendor_greeting", "Vendor"):
		return
	if not await _leave_npc(reloaded):
		return
	reloaded._call_bridge("begin_at", ["clerk_greeting"])
	reloaded._call_bridge("choose", ["ask_robbery"])
	reloaded._call_bridge("begin_at", ["mara_greeting"])
	reloaded._call_bridge("choose", ["accept_help"])
	reloaded._call_bridge("end_dialogue")
	reloaded._refresh_world()
	if not await _enter_npc(reloaded, "Ivo", "ivo_gate", "Ivo"):
		return
	if not _expect(_choice(_current_view(reloaded), "open_gate").get("enabled", false), "Ivo's gate request remains available"):
		return
	_joy(0, false)
	await process_frame
	_joy(0, true)
	await process_frame
	if not _expect(_current_view(reloaded).get("node_id", "") == "ivo_gate_opened", "controller A commits Ivo's gate choice"):
		return
	if not await _barriers_match(reloaded, true, false, "after Ivo's choice"):
		return
	if not await _leave_npc(reloaded):
		return
	if not await _enter_npc(reloaded, "CivicClerk", "clerk_greeting", "Clerk"):
		return
	for button in reloaded.panel.buttons:
		if button.get_meta("choice_id") == "open_shortcut": reloaded.panel._select_index(reloaded.panel.buttons.find(button))
	if not _expect(_choice(_current_view(reloaded), "open_shortcut").get("enabled", false), "The optional market shortcut remains available"):
		return
	_joy(0, false)
	await process_frame
	_joy(0, true)
	await process_frame
	if not _expect(_current_view(reloaded).get("node_id", "") == "clerk_shortcut_opened", "controller A commits the clerk's shortcut choice"):
		return
	if not await _barriers_match(reloaded, true, true, "after clerk's choice"):
		return
	if not await _leave_npc(reloaded):
		return
	var garden_position := Vector3(44, 1.63, -3)
	reloaded.get_node("Player").global_position = garden_position
	_key(KEY_F5, true)
	await process_frame
	if not _expect(FileAccess.file_exists(TEST_SAVE), "F5 saves unlocked hub access"):
		return
	_key(KEY_F5, false)
	root.remove_child(reloaded)
	reloaded.queue_free()
	await process_frame
	var hub_reloaded: Node3D = scene.instantiate() as Node3D
	hub_reloaded.set("save_path", TEST_SAVE)
	root.add_child(hub_reloaded)
	await process_frame
	_key(KEY_F9, true)
	await process_frame
	if not _expect(hub_reloaded.get("mode") == "explore" and hub_reloaded.get_node("Player").global_position.distance_to(garden_position) < 0.2, "F9 restores garden position and exploration (position=%s, expected=%s, mode=%s)" % [hub_reloaded.get_node("Player").global_position, garden_position, hub_reloaded.get("mode")]):
		return
	if not await _barriers_match(hub_reloaded, true, true, "reloaded hub access"):
		return
	if not _expect(hub_reloaded.get_node("CanvasLayer/Location").text.contains("LANTERN GARDEN"), "reloaded position updates district signpost"):
		return
	_key(KEY_F9, false)
	root.remove_child(hub_reloaded)
	hub_reloaded.queue_free()
	await process_frame
	if not await _input_hint_checks(scene):
		return
	if not await _office_camera_transition_checks(scene):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("Oathshaper native bridge, four controller NPC entries, adaptive input hints, guarded hub routes, collision, recorded greeting and save/load checks passed")
	quit(0)
