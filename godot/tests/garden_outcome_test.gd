extends SceneTree
var failures: Array[String] = []
var checks := 0
var main: Node
var trial: Control
var style := "flow"
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func aim_at(id: String) -> void:
	var target: Vector3 = trial.stage.actors[id].position + Vector3(0,1.2,0)
	for attempt in range(5):
		trial.stage._position_camera()
		var direction: Vector3 = (target - trial.stage.camera.global_position).normalized()
		trial.stage.yaw = atan2(-direction.x,-direction.z)
		trial.stage.pitch = asin(direction.y)
func capture(label: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"): return
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/oathshaper-outcome-%s-%s.png" % [style,label])
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--style="): style = arg.trim_prefix("--style=")
	create_timer(100).timeout.connect(func() -> void: push_error("Outcome route timeout"); quit(1))
	root.size = Vector2i(1280,800)
	main = preload("res://scripts/main.gd").new()
	main.save_path = "user://outcome-test-%d.json" % Time.get_ticks_usec()
	root.add_child(main)
	main._frontend._selected = style
	main._open_chapter(style,false)
	await frames()
	trial = main._trial
	trial._confrontation.finish()
	await frames()
	trial.set_process(false)
	if style == "flow":
		trial._toggle_pause()
		trial.submit({"kind":"follower","mode":"attack"})
		if OS.get_cmdline_user_args().has("--surrender-fixture"):
			# Isolate the rare low-health offer without depending on damage-roll luck.
			# The ordinary route above is separately exercised with earned combat.
			var saved: Dictionary = JSON.parse_string(trial._call("save_json").data.save)
			# Keep the runtime's u64 counters as exact JSON tokens, not Godot floats.
			var session: String = saved.session
			session = session.replace('"phase":"encounter"','"phase":"surrender"')
			session = session.replace('"pauses":{}','"pauses":{"surrender":"Surrender offered"}')
			for id in ["hound","sentinel","corsair_raider"]:
				var resource := RegEx.new()
				resource.compile('("'+id+':health":\\{[^}]*"current":)[0-9]+')
				session = resource.sub(session,'${1}'+("12" if id == "corsair_raider" else "0"))
			saved.session = session
			var restored: Dictionary = trial._call("restore_json",[JSON.stringify(saved)])
			check(restored.get("ok",false),"Bounded surrender fixture restores through the real bridge: " + str(restored.get("error","")))
			if not restored.get("ok",false): quit(1); return
			trial._publish(restored.data)
			trial.submit({"kind":"resume","token":trial.state.clock.restore_token})
		for i in range(1800):
			if trial.state.session.phase != "encounter": break
			if i % 5 == 0:
				var enemy: Dictionary = trial.hud.actor(str(trial.state.hero.target_id))
				var hero: Dictionary = trial.hud.actor("player")
				if not enemy.is_empty() and enemy.conscious:
					var offset := Vector2(enemy.position[0]-hero.position[0],enemy.position[1]-hero.position[1])
					var dir := offset.normalized() if offset.length()>1.45 else Vector2.ZERO
					trial.submit({"kind":"move","direction":[dir.x,dir.y]})
					if hero.active_action == null: trial.submit({"kind":"attack","verb":"power" if enemy.guard else "normal"})
			trial.pump_tick()
			if i % 30 == 0: await frames()
		trial._outcome()
	else:
		trial.submit({"kind":"trigger","pressed":true})
		for i in range(3600):
			if trial.state.status != "engaged": break
			var id := "hound" if trial.state.actors.hound.hp > 0 else "sentinel"
			if i % 8 == 0: aim_at(id)
			trial._process(1.0/60.0)
			if i % 60 == 0: await frames()
	var phase: String = trial.state.session.phase if style == "flow" else trial.state.status
	print("OUTCOME_PHASE ",style," ",phase)
	check(phase in ["surrender","victory","won"],"Earned encounter reaches surrender or victory")
	if is_instance_valid(trial._confrontation):
		var scene: Node3D = trial._confrontation
		check(scene.surrender and not trial.can_process(),"Surrender freezes gameplay and owns the shot")
		check(trial._modal == null and not trial._layer.visible,"Surrender replaces the result panel and combat HUD")
		scene._next()
		check(scene._audio.stream != null,"Surrender has the exact new voiced line")
		check("pouch" in scene._caption.text and not "chest" in scene._caption.text,"Raider offers the pouch, not the office chest")
		scene._process(scene._remaining + .01)
		check(scene._awaiting_choice and scene._choice_row.get_child_count() == 2,"Speech ends in accept/decline choices")
		var tick = trial.state.session.tick if style == "flow" else trial.state.tick
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE
		skip.pressed = true
		Input.parse_input_event(skip)
		await frames()
		check(is_instance_valid(scene) and not scene._done,"Escape never accepts or declines surrender")
		check(tick == (trial.state.session.tick if style == "flow" else trial.state.tick),"Combat clock stays still during the decision")
		await capture("surrender")
		if OS.get_cmdline_user_args().has("--decline"):
			(scene._choice_row.get_child(1) as Button).grab_focus()
		# Real root UI accept dispatch: the same Enter press must not attack.
		var accept := InputEventKey.new()
		accept.keycode = KEY_ENTER
		accept.physical_keycode = KEY_ENTER
		accept.pressed = true
		Input.parse_input_event(accept)
		accept = accept.duplicate()
		accept.pressed = false
		Input.parse_input_event(accept)
		await frames()
		if OS.get_cmdline_user_args().has("--decline"):
			var resumed: String = trial.state.session.phase if style == "flow" else trial.state.status
			check(resumed in ["encounter","engaged"] and not trial.has_won(),"Decline resumes combat without granting victory")
			check(trial._confrontation == null and trial._layer.visible,"Decline restores the HUD and releases the cinematic")
			check(trial.viewport.get_camera_3d() == trial.stage.camera,"Decline restores the player's combat camera")
			check(trial._stick == Vector2.ZERO if style == "flow" else trial._left_stick == Vector2.ZERO,"Choice input never latches movement")
			main.free()
			print("GARDEN_DECLINE ",style," CHECKS ",checks," FAILURES ",failures)
			quit(0 if failures.is_empty() else 1)
			return
		# Flow notices phase changes in its normal processing loop, disabled above.
		if is_instance_valid(trial) and not trial._closing: trial._outcome()
	await frames()
	await frames()
	check(main._trial == null and is_instance_valid(main._demo),"Menu victory automatically returns to a real garden")
	if not is_instance_valid(main._demo): quit(1); return
	var demo: Node3D = main._demo
	check(demo.combat_profile() == style,"Garden retains the selected combat style")
	check(demo.has_node("GardenResolution"),"Garden plays the voiced post-battle cutscene")
	if demo.has_node("GardenResolution"):
		var resolution: Node3D = demo.get_node("GardenResolution")
		resolution._next()
		check(resolution._caption.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,"Resolution uses matching left-aligned subtitles")
		check(resolution._audio.stream != null,"Ivo's resolution line is voiced")
		await capture("resolution")
		resolution.finish()
		await frames()
	check(demo.mode == "explore" and demo.player.enabled,"Resolution gives control back in the cleared garden")
	check(demo._objective_id() == "pay_loot" and demo._pay_loot.visible,"Payroll still needs to be looted")
	check(demo._nearest_interactable().get("kind") == "pay_loot","Player returns within reach of the raider's pouch")
	check(not demo._story_state.flags.pay_recovered and not demo._story_state.flags.pay_returned,"Victory does not collect or return the payroll")
	check(demo._story_state.flags.gate_open and demo._story_state.flags.mara_recruited,"Chapter entry establishes the returning party and open gate")
	check(not FileAccess.file_exists(main.save_path),"Demo route never overwrites a save")
	await capture("garden")
	main.free()
	print("GARDEN_OUTCOME ",style," CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
