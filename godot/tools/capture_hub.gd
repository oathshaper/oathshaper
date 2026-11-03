extends SceneTree

## Graphical smoke capture. Run with Godot --path godot --script res://tools/capture_hub.gd.
## Images are written to user://captures so this tool does not change source files.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene: PackedScene = load("res://scenes/demo.tscn")
	var demo: Node3D = scene.instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	var rig: Node3D = demo.get_node("CameraRig")
	var player: CharacterBody3D = demo.get_node("Player")
	var output_dir := ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(output_dir)
	rig.set("distance", 24.0)
	player.global_position = Vector3(0, 1, -10)
	await _frame()
	_save(output_dir.path_join("hub-overview.png"))

	var bridge: Object = demo.get("bridge")
	bridge.call("begin_at", "mara_greeting")
	bridge.call("choose", "share_oil")
	bridge.call("end_dialogue")
	bridge.call("begin_at", "ivo_gate")
	bridge.call("choose", "open_gate")
	bridge.call("end_dialogue")
	demo.call("_refresh_world")
	rig.set("distance", 17.0)
	player.global_position = Vector3(23, 1, -2)
	await _frame()
	_save(output_dir.path_join("hub-east-gate-open.png"))

	rig.set_process(false)
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.fov = 50.0
	camera.global_position = Vector3(28.5, 2.2, 1.2)
	camera.look_at(Vector3(25.0, 1.0, -2.0))
	await _frame()
	_save(output_dir.path_join("hub-ivo-imported.png"))
	demo.call("_begin_dialogue", "ivo_gate")
	await _frame()
	_save(output_dir.path_join("hub-ivo-dialogue.png"))
	demo.call("_end_dialogue")

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 66.0
	camera.global_position = Vector3(9.0, 55.0, -11.0)
	camera.look_at(Vector3(9.0, 0.0, -11.0), Vector3(0.0, 0.0, -1.0))
	await _frame()
	_save(output_dir.path_join("hub-overhead.png"))
	quit(0)

func _frame() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _save(path: String) -> void:
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Could not save hub capture: " + error_string(error))
		quit(1)
		return
	print("Captured ", path)
