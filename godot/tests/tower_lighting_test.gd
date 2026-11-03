extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func capture(label: String) -> Image:
	if DisplayServer.get_name() == "headless": return null
	await process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png("/tmp/oathshaper-tower-%s.png" % label)
	return shot
func run() -> void:
	root.size = Vector2i(1280, 800)
	var demo := preload("res://scenes/demo.tscn").instantiate()
	demo.save_path = "user://tower-lighting-%s.json" % Time.get_ticks_usec()
	root.add_child(demo)
	await process_frame
	check(not demo.hub.is_beacon_lit(), "Quay starts with the tower out")
	check(demo.lamp.light_energy == 0, "Mara has no orange spill")
	demo.get_node("CanvasLayer").hide()
	demo.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	demo.add_child(camera)
	camera.position = Vector3(17, 11, 15)
	camera.look_at(Vector3(0, 4, -15))
	camera.make_current()
	var dark := await capture("dark")
	demo._call_bridge("begin_at", ["mara_greeting"])
	demo._call_bridge("choose", ["share_oil"])
	demo._call_bridge("end_dialogue")
	demo._refresh_world()
	check(demo.hub.is_beacon_lit(), "Donated oil lights the actual tower")
	var light := await capture("lit")
	if dark != null:
		var before := 0.0
		var after := 0.0
		# Lower half contains court, quay and building facades, not the sky.
		for y in range(400, 750, 8):
			for x in range(80, 1200, 8):
				before += dark.get_pixel(x,y).get_luminance()
				after += light.get_pixel(x,y).get_luminance()
		print("TOWER_RENDER brightness dark=%.2f lit=%.2f ratio=%.2f" % [before, after, after/maxf(before,.001)])
		check(after > before * 1.25, "Relighting visibly illuminates the scene at unchanged exposure")
	camera.position = Vector3(10, 12, -12)
	camera.look_at(Vector3(0, 10, -23))
	await capture("close")
	check(demo._save() and demo._load() and demo.hub.is_beacon_lit(), "Restored save keeps the tower illuminated")
	demo._enter_records_office()
	await process_frame
	camera.position = demo.records_office.position + Vector3(4.8, 6.4, 5.7)
	camera.look_at(demo.records_office.position + Vector3(0, .8, -1))
	camera.make_current()
	await capture("office")
	check(demo.get_node("CivicClerk").visible and demo._pay_chest.get_parent() == demo.records_office, "Clerk and chest remain together inside")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(demo.save_path))
	print("TOWER_LIGHTING: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
