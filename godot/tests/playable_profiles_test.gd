extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func settle() -> void:
	await process_frame
	await process_frame
func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 800)
	var main := preload("res://scripts/main.gd").new()
	main.save_path = "user://profiles-untouched-%s.json" % Time.get_ticks_usec()
	root.add_child(main)
	await settle()
	for profile in ["command", "flow", "vanguard"]:
		main._frontend.open_picker(profile, false)
		main._frontend._open_inspector()
		await settle()
		var inspector = main._frontend._inspector
		var samples: Array[Node] = inspector.find_children("*", "SubViewport", true, false)
		check(samples.size() >= 1, profile + " has live 3D overview")
		var play: Button
		for button in inspector._focusables:
			if button.text == "Play The Quay Robbery  →": play = button
		check(play != null, profile + " has playable chapter entry")
		if play == null: continue
		play.pressed.emit()
		await settle()
		check(main._trial != null and main._trial.get_script().resource_path.ends_with(profile+"_trial.gd"), profile + " routes to its own runtime")
		check(not main._trial.state.is_empty() and not main._trial.has_won(), profile + " loads real uncompleted state")
		main._close_command_trial()
		await settle()
		check(main._frontend.visible and main._trial == null, profile + " returns to overview")
		main._frontend._close_inspector()
		await settle()
	check(not FileAccess.file_exists(main.save_path), "Standalone previews never create campaign save")
	print("PLAYABLE_PROFILES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
