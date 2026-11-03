extends SceneTree
## Graphical-only 1280 x 800 comparison captures for the tower palette pass.
## Godot --path godot --resolution 1280x800 --script res://tools/capture_tower_match.gd

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
		["tower-paint-match-quay-1280x800.png", Vector3(0.0, 1.05, 3.0), 0.0],
		["tower-paint-match-court-1280x800.png", Vector3(0.0, 1.05, -11.0), 0.0],
		["tower-paint-match-archive-1280x800.png", Vector3(-6.2, 1.05, -26.0), 90.0],
		["tower-facade-market-1280x800.png", Vector3(-21.0, 1.05, 1.0), 90.0],
	]:
		player.global_position = shot[1]
		player.rotation.y = deg_to_rad(shot[2])
		rig.call("focus_after_teleport", shot[2], false)
		for _frame in range(8):
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path := "res://../docs/images/%s" % shot[0]
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("Could not save tower palette capture: %s" % path)
			quit(1)
			return
		print("TOWER_CAPTURE %s %dx%d" % [path, image.get_width(), image.get_height()])
	quit()
