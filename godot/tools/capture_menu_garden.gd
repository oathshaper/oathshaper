extends SceneTree
## Bake a HUD-free view of the actual garden for the launcher's illustration.
## Godot --path godot --resolution 1600x1000 --write-movie /tmp/menu-garden.avi --fixed-fps 30 --script res://tools/capture_menu_garden.gd

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(1))
	var demo := preload("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	demo.camera_rig.set_process(false)
	demo.camera_rig.set_physics_process(false)
	demo.player.hide()
	demo.get_node("CanvasLayer").hide()
	for label in _labels(demo):
		label.hide()
	var camera: Camera3D = demo.camera_rig.get_node("Camera3D")
	camera.fov = 48.0
	camera.global_position = Vector3(30.0, 22.0, 18.0)
	camera.look_at(Vector3(44.0, 0.5, -2.0))
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://assets/ui/lantern-garden.png")
	print("MENU_GARDEN_CAPTURE: ", error_string(result))
	quit(0 if result == OK else 1)

func _labels(node: Node) -> Array[Label3D]:
	var found: Array[Label3D] = []
	if node is Label3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_labels(child))
	return found
