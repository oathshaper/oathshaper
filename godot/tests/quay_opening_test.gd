extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	root.size = Vector2i(1280, 800)
	var demo := load("res://scenes/demo.tscn").instantiate() as Node3D
	root.add_child(demo)
	await process_frame
	check(demo.get_node("GardenWatch").get_child_count() == 3, "The opening shows the actual three adversary meshes beyond the gate")
	var before: String = demo.bridge.state_json()
	demo.play_opening()
	var opening: Node3D = demo.get_node("QuayOpening")
	await process_frame
	check(not demo.player.enabled and demo.mode == "opening", "Opening owns movement")
	for index in range(3):
		check(opening._index == index, "Opening progresses in authored order")
		check(opening._audio.stream != null, "Every opening line has exact generated speech")
		await create_timer(.2).timeout
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/oathshaper-opening-%d.png" % index)
		opening._remaining = 0
		await process_frame
		await process_frame
	check(demo.mode == "explore" and demo.player.enabled, "Opening finishes automatically")
	check(demo.bridge.state_json() == before, "Opening never makes a dialogue choice")
	demo.play_opening()
	await process_frame
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_B
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	check(demo.mode == "explore" and demo.player.enabled, "B skips and releases movement")
	check(demo.bridge.state_json() == before, "Skip preserves story state")
	print("QUAY_OPENING: %d checks, %d failures" % [checks, failures])
	demo.free()
	quit(1 if failures else 0)
