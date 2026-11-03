extends SceneTree
var failures: Array[String] = []
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message);push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var script = load("res://scripts/flow_trial.gd")
	check(script != null,"Flow script loads")
	if script == null: quit(1);return
	var trial = script.new()
	root.add_child(trial)
	await process_frame
	trial.set_process(false)
	check(trial.bridge != null,"Real FlowBridge is available")
	if trial.bridge == null: quit(1);return
	check(trial.state.hero.diamond.size()==4,"Four assigned styles")
	check(trial.hud._diamond.size()==4,"Four visible style buttons")
	check(not trial.has_won(),"No campaign win before victory")
	var tab := InputEventKey.new()
	tab.keycode=KEY_TAB
	tab.pressed=true
	trial._input(tab)
	check(trial._modal.is_ancestor_of(trial.viewport.gui_get_focus_owner()),"Keyboard Tab stays inside modal")
	var controller_event := InputEventJoypadButton.new()
	controller_event.button_index=JOY_BUTTON_B
	controller_event.pressed=true
	trial._input(controller_event)
	check(trial._modal==null,"Controller B closes exactly one modal")
	check(trial.hud.actor("player").active_action==null,"Modal B does not start a combat action")
	trial._close()
	var receipt: Dictionary = trial.submit({"kind":"equip","item_id":"rain-1","socket":0})
	check(receipt.status=="rejected","Illegal gem rejected")
	trial.submit({"kind":"start"})
	var style := InputEventJoypadButton.new()
	style.button_index=JOY_BUTTON_DPAD_RIGHT
	style.pressed=true
	trial._input(style)
	check(trial.state.hero.style=="gale","Controller D-pad selects right style")
	trial.submit({"kind":"style","style":"gale"})
	receipt=trial.submit({"kind":"attack","verb":"power"})
	check(receipt.status=="rejected","Missing verb cannot cast another style")
	trial.submit({"kind":"attack","verb":"normal"})
	check(trial.hud.actor("player").chi.current==32,"Gale cost paid exactly once")
	trial.save_path="user://flow_native_test.json"
	trial._save()
	trial._load()
	check(trial.state.clock.paused,"Loaded menu owns pause")
	trial._close()
	trial.submit({"kind":"style","style":"stone"})
	trial.submit({"kind":"follower","mode":"attack"})
	var last_decision := -1
	for i in range(1600):
		if trial.state.session.phase=="victory": break
		if trial.state.session.phase=="surrender": trial.submit({"kind":"surrender","accept":true});break
		check(trial.state.session.phase!="defeat","Autonomous garden route survives")
		if trial.state.session.phase=="defeat": break
		var tick: int=trial.state.session.tick
		if tick%5==0 and tick!=last_decision:
			last_decision=tick
			var enemy: Dictionary=trial.hud.actor(str(trial.state.hero.target_id))
			if enemy.is_empty() or not enemy.conscious: trial._next_target();enemy=trial.hud.actor(str(trial.state.hero.target_id))
			var hero: Dictionary=trial.hud.actor("player")
			if not enemy.is_empty() and enemy.conscious:
				var offset:=Vector2(enemy.position[0]-hero.position[0],enemy.position[1]-hero.position[1])
				var dir:=offset.normalized() if offset.length()>1.45 else Vector2.ZERO
				trial.submit({"kind":"move","direction":[dir.x,dir.y]})
				if hero.active_action==null: trial.submit({"kind":"attack","verb":"power" if enemy.guard else "normal"})
		var result: Dictionary=trial.pump_tick()
		check(result.get("stop_reason")!="rejected","Host geometry and clock accepted")
		if trial.state.session.phase == "encounter":
			var selected: Dictionary = trial.hud.actor(str(trial.state.hero.target_id))
			check(not selected.is_empty() and selected.conscious, "Target handoff never leaves a fallen enemy selected during the actual fight")
		if i%20==0: await process_frame
		if i==40 and DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			trial.viewport.get_texture().get_image().save_png("/tmp/oathshaper-flow-combat.png")
	check(trial.has_won(),"Real core victory reaches host latch")
	check(str(trial.state.hero.target_id).is_empty(),"Victory clears the target, including a surrendered survivor")
	check(trial.state.progression.level==2,"Victory awards level and training")
	check(trial.state.inventory.copper==260,"Reward paid once")
	trial._outcome()
	await process_frame
	await process_frame
	for button in trial.hud._diamond:
		check(button.size.x>=100 and button.size.y>=40,"Style hit target remains usable")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		trial.viewport.get_texture().get_image().save_png("/tmp/oathshaper-flow-native.png")
	trial.queue_free()
	await process_frame
	print("FLOW_NATIVE_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
