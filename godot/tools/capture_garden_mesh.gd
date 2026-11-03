extends SceneTree
## Graphical QA for the supplied Seaside Garden terrace.
## Godot --path godot --resolution 1280x800 --script res://tools/capture_garden_mesh.gd
## Add -- live for an interactive preview with a separate save slot; -- walk for movie capture.
## Use -- seams with Movie Maker for close orbit views and compact HUD evidence.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var demo := (load("res://scenes/demo.tscn") as PackedScene).instantiate() as Node3D
	demo.set("save_path", "user://garden-fit-preview.json")
	root.add_child(demo)
	await process_frame
	await process_frame
	var player := demo.get_node("Player") as CharacterBody3D
	var rig := demo.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	var hub := demo.get_node("HubEnvironment") as Node3D
	if hub.get_node_or_null("DistrictDetails/ImportedGardenArt") == null:
		push_error("Garden capture requires the imported Seaside Garden mesh")
		quit(1)
		return
	# Open through the actual rules so the minimap and physical gate agree.
	for step in [["begin_at", ["mara_greeting"]], ["choose", ["share_oil"]], ["end_dialogue", []],
		["begin_at", ["ivo_gate"]], ["choose", ["open_gate"]], ["end_dialogue", []]]:
		var result: Dictionary = demo.call("_call_bridge", step[0], step[1])
		if not result.get("ok", false):
			push_error("Garden preview story setup failed: " + str(result))
			quit(1)
			return
	demo.call("_refresh_world")
	await physics_frame
	if OS.get_cmdline_user_args().has("seams"):
		await _capture_seams(demo, player, rig, camera)
		quit(0)
		return
	if OS.get_cmdline_user_args().has("live"):
		player.global_position = Vector3(28.8, 1.05, -2.0)
		player.rotation.y = -PI * 0.5
		rig.call("focus_after_teleport", -90.0, false)
		DisplayServer.window_set_title("Oathshaper — Garden seam and HUD preview")
		print("GARDEN_LIVE ready; separate preview save slot")
		return
	if OS.get_cmdline_user_args().has("walk"):
		player.global_position = Vector3(29.0, 1.05, -2.0)
		player.rotation.y = -PI * 0.5
		rig.call("focus_after_teleport", -90.0, false)
		for _frame in range(15):
			await process_frame
		for key in [KEY_W, KEY_S]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.pressed = true
			Input.parse_input_event(event)
			for _frame in range(200):
				await physics_frame
			event = InputEventKey.new()
			event.physical_keycode = key
			event.pressed = false
			Input.parse_input_event(event)
			for _frame in range(20):
				await process_frame
			print("GARDEN_WALK ", key, " ", player.global_position)
		quit(0)
		return
	for shot in [
		["/tmp/oathshaper-garden-approach.png", Vector3(28.8, 1.05, -2.0), -90.0],
		["/tmp/oathshaper-garden-return.png", Vector3(34.8, 1.05, -2.0), 90.0],
		["/tmp/oathshaper-garden-interior.png", Vector3(46.0, 1.63, -3.0), -90.0],
	]:
		player.global_position = shot[1]
		player.rotation.y = deg_to_rad(shot[2])
		rig.call("focus_after_teleport", shot[2], false)
		for _frame in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		if not _save(shot[0]):
			return
	demo.call("_set_map_expanded", true)
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("/tmp/oathshaper-garden-expanded-map.png"):
		return
	demo.call("_set_map_expanded", false)
	rig.set_process(false)
	player.global_position = Vector3(43.5, 1.63, -3.0)
	camera.global_position = Vector3(29.0, 18.0, 10.0)
	camera.look_at(Vector3(44.0, 0.5, -3.0))
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("/tmp/oathshaper-garden-overview.png"):
		return
	player.global_position = Vector3(29.0, 1.05, -2.0)
	player.rotation.y = -PI * 0.5
	camera.global_position = Vector3(25.0, 7.5, 5.5)
	camera.look_at(Vector3(35.0, 0.4, -2.0))
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("/tmp/oathshaper-garden-join.png"):
		return
	quit(0)


func _save(path: String) -> bool:
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not save garden capture: " + path)
		quit(1)
		return false
	print("GARDEN_CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])
	return true


func _capture_seams(demo: Node3D, player: CharacterBody3D, rig: Node3D, camera: Camera3D) -> void:
	# Use --write-movie with this mode: close moving views expose depth fighting
	# that a distant still and walk-through collision test cannot catch.
	player.global_position = Vector3(32.9, 1.05, -2.0)
	player.rotation.y = -PI * 0.5
	rig.set_process(false)
	rig.set_physics_process(false)
	camera.global_position = Vector3(27.6, 2.3, -2.0)
	camera.look_at(Vector3(31.4, 0.4, -2.0))
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	_save("/tmp/oathshaper-compact-quest.png")
	var tracker := demo.get_node("CanvasLayer/ObjectiveTracker") as Control
	var map := demo.get_node("CanvasLayer/MapWidget") as Control
	print("HUD_FIT map=", map.get_global_rect(), " tracker=", tracker.get_global_rect())
	for collapsed in [true, false]:
		tracker.call("set_collapsed", collapsed)
		for frame in range(3):
			await process_frame
		print("HUD_FIT collapsed=", collapsed, " tracker=", tracker.get_global_rect())
	for node in demo.get_children():
		if node is CanvasLayer:
			node.hide()
	for side in [1.0, -1.0]:
		for frame in range(151):
			var angle := lerpf(-PI / 3.0, PI / 3.0, float(frame) / 150.0)
			camera.global_position = Vector3(31.1 + sin(angle) * 4.0, 1.5, -2.0 + side * cos(angle) * 4.0)
			camera.look_at(Vector3(31.1, 0.30, -2.0 + side * 1.7))
			await process_frame
			if frame == 75:
				await RenderingServer.frame_post_draw
				_save("/tmp/oathshaper-seam-%s.png" % ("south" if side > 0 else "north"))
	print("GARDEN_SEAMS close moving views complete")
