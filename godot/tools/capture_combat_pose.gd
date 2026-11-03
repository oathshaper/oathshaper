extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(1))
	var demo := preload("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	demo.player.set_physics_process(false)
	demo.camera_rig.set_process(false)
	demo.camera_rig.set_physics_process(false)
	demo.player.global_position = Vector3(0, 1.05, 2)
	demo.get_node("CanvasLayer").hide()
	var camera: Camera3D = demo.camera_rig.get_node("Camera3D")
	camera.global_position = Vector3(3, 2.5, 5)
	camera.look_at(Vector3(0, 1.15, 2))
	for id in ["vanguard", "flow", "command"]:
		demo.set_combat_profile(id)
		demo._toggle_weapon()
		for frame in range(30):
			await process_frame
		await _save(id + "-ready")
		demo._strike()
		for frame in range(10):
			await process_frame
		await _save(id + "-strike")
	print("COMBAT_POSES_CAPTURED")
	root.remove_child(demo)
	demo.queue_free()
	quit(0)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../docs/images/combat-pose-" + name + ".png")
