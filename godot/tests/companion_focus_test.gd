extends SceneTree
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	evidence.record(message, value)
	if not value: failures += 1; push_error(message)
func run() -> void:
	var demo := preload("res://scenes/demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	demo.set_process(false)
	demo.player.set_physics_process(false)
	demo.camera_rig.set_process(false)
	demo.player.position = Vector3(2, 1.05, 2)
	var mara: Node3D = demo.get_node("Mara")
	mara.position = Vector3(2, 1.05, .5)
	# Keep other targets outside talk range; this isolates the actual follower.
	demo._rendezvous.follow_after_battle(demo.player, mara.position, Vector3(27, 1.05, -2))
	var focus := preload("res://scripts/interaction_focus.gd").new()
	focus.demo = demo
	root.add_child(focus)
	demo.camera_rig.camera.global_position = Vector3(2, 3, 6)
	demo.camera_rig.camera.look_at(mara.global_position)
	demo.player.velocity = Vector3(0, 0, -2)
	check(not demo._npc_can_focus(mara), "Moving alongside Mara does not select her")
	check(demo._nearest_interactable().get("node") != mara, "Walking interaction key cannot accidentally talk to the follower")
	focus._process(0)
	check(not focus.visible, "Walking beside Mara leaves no follower reticle")
	check(not mara.get_node("Name").visible and not demo.get_node("Ivo/Name").visible, "Unreticled NPC name badges are hidden")
	demo._refresh_exploration_prompt()
	check(demo.prompt.text.is_empty(), "Walking beside Mara leaves no talk prompt")
	demo.player.velocity = Vector3.ZERO
	check(demo._npc_can_focus(mara) and demo._nearest_interactable().get("node") == mara, "Stopping and looking toward Mara permits conversation")
	focus._process(0)
	demo._refresh_exploration_prompt()
	check(focus.visible and "Mara" in demo.prompt.text, "Deliberate companion focus shows both bracket and prompt")
	check(mara.get_node("Name").visible and not demo.get_node("Ivo/Name").visible, "Only the reticled NPC displays a name badge")
	demo.camera_rig.camera.look_at(Vector3(2, 3, 10))
	check(not demo._npc_can_focus(mara), "Looking away dismisses the companion target")
	focus._process(0)
	check(not mara.get_node("Name").visible, "Looking away also removes the name badge")
	demo._rendezvous._following = false
	demo._rendezvous._routes.Mara = []
	demo.player.velocity = Vector3(0, 0, -2)
	check(demo._npc_can_focus(mara), "Ordinary stationary NPCs retain their approach interaction")
	# Before battle she also moves to the gate: the same selection rule applies.
	demo._rendezvous._routes.Mara = [Vector2(28, .6)]
	check(not demo._npc_can_focus(mara), "Mara travelling to the gate is not selected by proximity")
	mara.hide()
	check(not demo._npc_can_focus(mara), "Hidden companions are never selectable")
	focus.free()
	demo.free()
	evidence.finish("companion-focus", "Actual exploration target, prompt and bracket with moving, stopped, looking-away and stationary-NPC fixtures.")
	quit(1 if failures else 0)
