extends SceneTree
## Render the actual timed response and B shortcut without touching user saves.
## Godot --path godot --resolution 1280x800 --write-movie /tmp/responses.avi --fixed-fps 30 --script res://tools/capture_response_flow.gd


func _initialize() -> void:
	call_deferred("_capture")


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame


func _tap(button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/images/" + filename))
	if result != OK:
		push_error("Response capture failed: " + filename)
		quit(1)


func _capture() -> void:
	var demo := (load("res://scenes/demo.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(demo)
	await _frames(3)
	var player := demo.get_node("Player") as CharacterBody3D
	var rig := demo.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	var panel := demo.get_node("CanvasLayer/DialoguePanel") as Control
	if OS.get_cmdline_user_args().has("sway"):
		player.hide()
		player.set_physics_process(false)
		rig.set_process(false)
		rig.set_physics_process(false)
		for child in demo.get_children():
			if child is CanvasLayer:
				child.visible = false
		var names := ["Mara", "Ivo", "CivicClerk", "Vendor"]
		for index in range(names.size()):
			var actor := demo.get_node(names[index]) as Node3D
			actor.global_position = Vector3(-2.4 + index * 1.6, 1.05, 0.0)
			actor.rotation.y = 0.0
			var slot := actor.get_node("ModelSlot")
			print("NPC_SWAY %s phase=%.3f rate=%.3f" % [actor.name, slot.get("_standing_phase"), slot.get("_standing_rate")])
		camera.fov = 42.0
		camera.global_position = Vector3(0.0, 2.0, 7.8)
		camera.look_at(Vector3(0.0, 1.1, 0.0))
		await _frames(600)
	else:
		player.global_position = Vector3(0.0, 1.05, 1.5)
		player.rotation.y = 0.0
		rig.call("focus_after_teleport", 0.0)
		await _frames(3)
		await _tap(JOY_BUTTON_A) # Enter Mara's menu.
		await _frames(45)
		await _tap(JOY_BUTTON_A) # Share oil.
		await _frames(30)
		await _save("timed-response-1280x800.png")
		await _frames(ceili(float(panel.get("_line_remaining")) * 30.0) + 20)
		if demo.call("_call_bridge", "view").get("data", {}).get("node_id") != "mara_greeting":
			push_error("Response did not return automatically")
			quit(1)
			return
		await _save("response-return-menu-1280x800.png")
		await _frames(45)
		await _tap(JOY_BUTTON_A) # Ask where Ivo is.
		await _frames(45)
		await _tap(JOY_BUTTON_B) # Skip this response.
		await _frames(45)
		await _save("response-skipped-1280x800.png")
	print("Response/sway render capture complete")
	quit(0)
