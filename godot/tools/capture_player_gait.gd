extends SceneTree
## Render the imported player's actual Walk clip from the exploration camera.
## Godot --path godot --resolution 1280x800 --script res://tools/capture_player_gait.gd -- /tmp/gait


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "/tmp/oathshaper-player-gait"
	var demo: Node3D = load("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	var player: CharacterBody3D = demo.get_node("Player")
	var slot: Node3D = player.get_node("ModelSlot")
	var animator: AnimationPlayer = slot.get("_animation_player")
	var walk_clip: StringName = slot.get("_walk_clip")
	if animator == null or walk_clip.is_empty() or not animator.has_animation(walk_clip):
		push_error("Imported player Walk clip is missing: mode=%s path=%s clip=%s" % [slot.call("motion_mode"), slot.call("active_model_path"), walk_clip])
		quit(1)
		return
	player.set_physics_process(false)
	slot.set_process(false)
	player.global_position = Vector3(0.0, 1.05, 4.0)
	player.rotation.y = 0.0
	var rig: Node3D = demo.get_node("CameraRig")
	rig.set_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.current = true
	camera.fov = 46.0
	camera.global_position = Vector3(0.0, 2.1, 6.8)
	camera.look_at(Vector3(0.0, 1.05, 4.0))
	for child in demo.get_children():
		if child is CanvasLayer:
			child.visible = false
	animator.play(walk_clip)
	animator.pause()
	for frame in [1, 7, 19]:
		animator.seek(float(frame - 1) / 24.0, true)
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path := "%s-frame-%02d-1280x800.png" % [prefix, frame]
		var error := image.save_png(path)
		if error != OK:
			push_error("Could not save gait capture: %s" % path)
			quit(1)
			return
		print("GAIT_CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])
	quit()
