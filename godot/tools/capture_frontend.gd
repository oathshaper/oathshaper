extends SceneTree
## Capture the real launcher without starting or changing a saved journey.
## Godot --path godot --script res://tools/capture_frontend.gd

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	create_timer(30).timeout.connect(func() -> void: quit(1))
	root.title = "Oathshaper · Interface capture"
	var front := preload("res://scripts/combat_frontend.gd").new()
	root.add_child(front)
	for resolution in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		front.open_title(false)
		if not await _shot("title", resolution):
			quit(1)
			return
		front.open_picker("command", false)
		if not await _shot("profiles", resolution):
			quit(1)
			return
		if resolution == Vector2i(1280, 800):
			for sample in [["command", 0, 0, "overview"], ["vanguard", 2, 1, "equipment"], ["flow", 3, 2, "abilities"]]:
				front.open_picker(sample[0], false)
				front._open_inspector()
				front._inspector.select_actor(sample[2])
				front._inspector.select_page(sample[1])
				if sample[3] == "overview":
					front._inspector._focusables[-1].grab_focus()
				if not await _shot(sample[0] + "-" + sample[3], resolution):
					quit(1)
					return
				front._close_inspector()
	print("FRONTEND_CAPTURE_OK: seven rendered launcher images")
	quit()

func _shot(page: String, requested: Vector2i) -> bool:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	# Native windows can be constrained by the host desktop. Name the evidence
	# by its rendered dimensions, never the requested window size.
	var actual := capture.get_size()
	if actual != requested:
		print("Requested %s; host rendered %s" % [requested, actual])
	var path := "res://../docs/images/launcher-%s-%dx%d.png" % [page, actual.x, actual.y]
	var result := capture.save_png(path)
	if result != OK:
		push_error("Launcher capture failed: " + error_string(result))
	return result == OK
