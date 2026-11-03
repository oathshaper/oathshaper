extends SceneTree
## Graphical 1280 x 800 evidence for the quay material and garden pass.
## Godot --path godot --resolution 1280x800 --script res://tools/capture_material_pass.gd

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: PackedScene = load("res://scenes/demo.tscn")
	var demo: Node3D = scene.instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	await process_frame
	var player: CharacterBody3D = demo.get_node("Player") as CharacterBody3D
	var rig: Node3D = demo.get_node("CameraRig") as Node3D
	for shot in [
		["material-pass-quay-1280x800.png", Vector3(0.0, 1.05, 3.0), 0.0, 16.0],
		["material-pass-court-1280x800.png", Vector3(0.0, 1.05, -11.0), 0.0, 16.0],
		["material-pass-market-1280x800.png", Vector3(-21.0, 1.05, 1.0), 90.0, 16.0],
		["material-pass-garden-1280x800.png", Vector3(40.3, 1.05, 5.3), 0.0, 16.0],
	]:
		player.global_position = shot[1]
		player.rotation.y = deg_to_rad(shot[2])
		rig.call("focus_after_teleport", shot[2], false)
		rig.set("pitch", shot[3])
		for _step in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		if not _save(shot[0]):
			return
	# The exterior waterline is below the player camera. Inspect the modeled
	# seawall and its dark skirt from a fixed view just outside the south pier.
	rig.set_process(false)
	player.global_position = Vector3(0.0, 1.05, 6.0)
	var camera: Camera3D = rig.get_node("Camera3D") as Camera3D
	camera.global_position = Vector3(0.0, 1.9, 11.5)
	camera.look_at(Vector3(0.0, 0.1, 6.8))
	for _step in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	if not _save("material-pass-seawall-1280x800.png"):
		return
	quit(0)


func _save(filename: String) -> bool:
	var path := ProjectSettings.globalize_path("res://../docs/images/" + filename)
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Could not save material pass capture: " + path)
		quit(1)
		return false
	print("MATERIAL_CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])
	return true
