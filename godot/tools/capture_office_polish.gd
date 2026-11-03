extends SceneTree
## Actual-render checks for coping, archive arrival and cadenced skeletal idle.
## Godot --path godot --resolution 1280x800 --script res://tools/capture_office_polish.gd
## Add --write-movie /tmp/quiet-idle.avi --fixed-fps 30 before --script, and -- video after it.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var demo := (load("res://scenes/demo.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	await physics_frame
	await process_frame
	var player := demo.get_node("Player") as CharacterBody3D
	var rig := demo.get_node("CameraRig") as Node3D
	var camera := rig.get_node("Camera3D") as Camera3D
	if OS.get_cmdline_user_args().has("gameplay-video"):
		# Unmodified exploration camera, then the actual Mara dialogue framing.
		# Each shot lasts long enough to show a complete eight-beat sway.
		player.global_position = Vector3(0.0, 1.05, 1.5)
		player.rotation.y = 0.0
		rig.call("focus_after_teleport", 0.0)
		await _settle()
		if not _save("cadenced-idle-exploration-1280x800.png"):
			return
		for _frame in range(300):
			await process_frame
		demo.call("_begin_dialogue", "mara_greeting")
		for _frame in range(300):
			await process_frame
		quit(0)
		return
	var video := OS.get_cmdline_user_args().has("video")
	if not video:
		var state: Dictionary = demo.get("_story_state")
		state["flags"]["records_clue"] = true
		demo.set("_story_state", state)
		demo.call("_enter_records_office")
		player.global_position = Vector3(159.0, 1.05, -25.0)
		rig.set_process(false)
		rig.set_physics_process(false)
		camera.global_position = Vector3(166.2, 8.0, -19.0)
		camera.look_at(Vector3(160.0, 1.4, -25.3))
		await _settle()
		if not _save("office-coping-fixed-1280x800.png"):
			return
		camera.global_position += Vector3(-1.0, 0.0, -0.7)
		camera.look_at(Vector3(160.0, 1.4, -25.3))
		await _settle()
		if not _save("office-coping-fixed-orbit-1280x800.png"):
			return
		demo.call("_leave_records_office")
		await _settle()
		if not _save("archive-exit-facing-court-1280x800.png"):
			return
	# A shared floor and fixed camera let the five imported rigs be compared
	# while their own differently timed Idle clips continue running.
	player.set_physics_process(false)
	rig.set_process(false)
	rig.set_physics_process(false)
	for child in demo.get_children():
		if child is CanvasLayer:
			child.visible = false
	var actors := ["Player", "Mara", "Ivo", "CivicClerk", "Vendor"]
	for index in range(actors.size()):
		var actor := demo.get_node(actors[index]) as Node3D
		actor.global_position = Vector3(-3.2 + index * 1.6, 1.05, 0.0)
		actor.rotation.y = PI if index == 0 else 0.0
		var slot := actor.get_node("ModelSlot") as Node3D
		var animator: AnimationPlayer = slot.get("_animation_player")
		animator.play(slot.get("_idle_clip"))
		animator.seek(index * 0.41, true)
	player.velocity = Vector3.ZERO
	camera.fov = 42.0
	camera.global_position = Vector3(0.0, 2.0, 7.8)
	camera.look_at(Vector3(0.0, 1.1, 0.0))
	await _settle()
	if video:
		for _frame in range(450):
			await process_frame
	else:
		if not _save("quiet-character-breathing-1280x800.png"):
			return
	quit(0)


func _settle() -> void:
	for _frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw


func _save(filename: String) -> bool:
	var path := ProjectSettings.globalize_path("res://../docs/images/" + filename)
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not capture office polish: " + path)
		quit(1)
		return false
	print("POLISH_CAPTURE " + path)
	return true
