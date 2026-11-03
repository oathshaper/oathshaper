extends SceneTree
## Four consistent, 2048 px reference views of the real MarketBridge pier.
## Run graphically: Godot --path godot --script res://tools/capture_meshy_dock.gd

const IMAGE_SIZE := Vector2i(2048, 2048)
const FOCUS := Vector3(-10.0, 0.48, 1.0)
const FLOOR_NAME := "MarketBridge"
const EDGE_CENTERS := [Vector3(-10.0, 0.52, -2.0), Vector3(-10.0, 0.52, 4.0)]


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var viewport := SubViewport.new()
	viewport.name = "MeshyDockCapture"
	viewport.size = IMAGE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)

	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#53646a")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#bec5bf")
	settings.ambient_light_energy = 0.85
	environment.environment = settings
	viewport.add_child(environment)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	key.light_energy = 1.4
	key.shadow_enabled = false
	viewport.add_child(key)

	# Instantiate the production environment script and isolate only the
	# existing 4 x 6 m market connector. Nothing is re-modelled or moved.
	var hub := Node3D.new()
	hub.name = "HubEnvironment"
	hub.set_script(load("res://scripts/hub_environment.gd"))
	viewport.add_child(hub)
	await process_frame
	if not _isolate_market_bridge(hub):
		quit(1)
		return

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.0
	camera.near = 0.05
	camera.far = 100.0
	viewport.add_child(camera)
	camera.current = true

	var output_dir := ProjectSettings.globalize_path("res://").path_join("../art/meshy/dock").simplify_path()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if mkdir_error != OK:
		push_error("Cannot create dock reference directory: " + error_string(mkdir_error))
		quit(1)
		return

	var views := [
		["01-south-face.png", Vector3(-10.0, 2.4, 10.2), Vector3.UP, 6.5],
		["02-west-end.png", Vector3(-18.5, 3.6, 1.0), Vector3.UP, 7.0],
		["03-northeast-quarter.png", Vector3(-4.0, 5.4, -6.0), Vector3.UP, 8.0],
		["04-overhead.png", Vector3(-10.0, 12.0, 1.0), Vector3(0.0, 0.0, -1.0), 7.4],
	]
	for view in views:
		camera.size = view[3]
		camera.global_position = view[1]
		camera.look_at(FOCUS, view[2])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = output_dir.path_join(view[0])
		var error := viewport.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Cannot save dock reference: " + path + " (" + error_string(error) + ")")
			quit(1)
			return
		print("Captured ", path)
	quit(0)


func _isolate_market_bridge(hub: Node3D) -> bool:
	for child in hub.get_children():
		if child.name != "WalkableDistrict" and child.name != "SeawallsAndParapets":
			(child as Node3D).visible = false

	var floors: StaticBody3D = hub.get_node("WalkableDistrict")
	var floor_count := 0
	for child in floors.get_children():
		if child is MeshInstance3D:
			child.visible = child.name == FLOOR_NAME
			if child.visible:
				floor_count += 1

	var edges: StaticBody3D = hub.get_node("SeawallsAndParapets")
	var stems: Array[String] = []
	for child in edges.get_children():
		if not child is MeshInstance3D:
			continue
		if "Rope" in child.name or "TimberCap" in child.name:
			continue
		for center in EDGE_CENTERS:
			if (child as MeshInstance3D).position.distance_to(center) < 0.01:
				stems.append(child.name)
	if floor_count != 1 or stems.size() != 2:
		push_error("MarketBridge geometry changed; expected one deck and two timber edges.")
		return false
	for child in edges.get_children():
		if child is MeshInstance3D:
			child.visible = false
			for stem in stems:
				if child.name == stem or child.name.begins_with(stem + "TimberCap") or child.name.begins_with(stem + "Rope"):
					child.visible = true
	return true
