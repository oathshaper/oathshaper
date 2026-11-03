extends SceneTree
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	evidence.record(message, ok)
	if not ok: failures += 1; push_error(message)
func frames(count := 3) -> void:
	for i in count: await process_frame
func run() -> void:
	root.size = Vector2i(1280,800)
	var trial := preload("res://scripts/flow_trial.gd").new()
	trial.play_intro = true
	root.add_child(trial)
	await frames()
	check(trial._confrontation != null, "Direct Flow entry uses the story cutscene")
	check(trial._confrontation._temporary_actors.is_empty(), "Cutscene and encounter use the same six story actors")
	check(trial.state.session.tick == 0, "Combat cannot advance during the cutscene")
	trial._confrontation.finish()
	await frames(5)
	trial.set_process(false)
	check(trial._layer.visible and trial.hud.is_visible_in_tree(), "HUD returns after the cinematic")
	check(trial.state.clock.pause_reasons.has("ready"), "Encounter waits for the player to begin")
	for index in 4:
		trial.hud._diamond[index].pressed.emit()
		check(trial.state.hero.style == trial.state.hero.diamond[index], "Visible style button selects its style while ready")
		var weapon = trial.stage.actors.player.get_node("Weapon")
		check(weapon.kind == ("sabre" if index == 2 else "unarmed"), "Actual Tessa weapon agrees with selected style")
		if index == 2:
			await frames(5)
			check(weapon.visual != null and weapon.visual.is_visible_in_tree(), "Harbor blade has a visible sabre mesh")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				trial.viewport.get_texture().get_image().save_png("/tmp/oathshaper-flow-sabre.png")
	trial.hud._diamond[0].pressed.emit()
	var initial_target: String = trial.state.hero.target_id
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed = true
	trial._world_input(wheel)
	check(trial.state.hero.target_id != initial_target, "Mouse wheel selects a different living opponent")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	trial._world_input(wheel)
	check(trial.state.hero.target_id == initial_target, "Reverse mouse wheel returns to previous spatial target")
	check(trial.stage.actors.ivo.visible and trial.stage.actors.ivo.has_node("ModelSlot"), "Ivo remains a visible rigged party member")
	for pair in [["hound","lantern_sentinel"],["sentinel","iron_sentinel"],["corsair_raider","crimson_corsair"]]:
		check(trial.stage.actors[pair[0]].get_node("Art").kind == pair[1], "Actual enemy mesh matches story identity: " + pair[0])
	for size in [Vector2i(1280,800),Vector2i(1280,720)]:
		root.size = size
		await frames(5)
		var bounds := Rect2(Vector2.ZERO,Vector2(trial.viewport.size))
		for i in 4:
			var rect: Rect2 = trial.hud._diamond[i].get_global_rect()
			check(bounds.encloses(rect), "Style button fits viewport " + str(size))
			for j in range(i+1,4): check(not rect.intersects(trial.hud._diamond[j].get_global_rect()), "Style hit rectangles never overlap")
		for control in trial.hud.find_children("*","Control",true,false):
			if control.is_visible_in_tree() and (control is Button or control is Label):
				check(bounds.encloses(control.get_global_rect()), "Visible HUD text/control fits " + str(size) + ": " + str(control.text))
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			trial.viewport.get_texture().get_image().save_png("/tmp/oathshaper-flow-ready-%d.png" % size.y)
	check("LMB" in trial.hud._verbs[0].text and not "RT" in trial.hud._verbs[0].text, "Keyboard mode shows mouse attack binding")
	var begin := InputEventKey.new()
	begin.keycode = KEY_ENTER; begin.pressed = true
	trial._input(begin)
	check(not trial.state.clock.paused, "Enter starts from the ready state")
	trial._request({"kind":"ui.pause"})
	check(trial.state.clock.paused, "Visible Pause control stops combat")
	var frozen: int = trial.state.session.tick
	trial.pump_tick()
	check(trial.state.session.tick == frozen, "Paused host cannot consume a combat tick")
	trial._menu()
	check(trial._modal != null and trial._modal.is_visible_in_tree(), "Ledger opens while paused")
	trial._close()
	check(trial.state.clock.paused, "Closing Ledger preserves the prior manual pause")
	trial._toggle_pause()
	check(not trial.state.clock.paused, "Resume releases the manual pause")
	trial.free()
	await frames()
	print("FLOW_PRESENTATION: %d checks, %d failures" % [checks,failures])
	evidence.finish("flow-presentation","Native cutscene-to-combat, real model identities, HUD bounds, nonoverlapping style buttons, keyboard hints and pause ownership.")
	quit(1 if failures else 0)
