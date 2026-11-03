extends SceneTree

const SLOT_SCRIPT := preload("res://scripts/character_model_slot.gd")
const RIG_FIXTURE := "user://oathshaper_rig_slot_fixture.tscn"
const STATIC_FIXTURE := "user://oathshaper_static_slot_fixture.tscn"
const IDLE_ONLY_FIXTURE := "user://oathshaper_idle_only_slot_fixture.tscn"
const UNWEIGHTED_FIXTURE := "user://oathshaper_unweighted_slot_fixture.tscn"
const EMPTY_FIXTURE := "user://oathshaper_empty_slot_fixture.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Rig slot test failed: " + message)
	quit(1)
	return false


func _weighted_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.3, -0.5, 0.0), Vector3(0.3, -0.5, 0.0),
		Vector3(-0.3, 0.5, 0.0), Vector3(0.3, 0.5, 0.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result


func _fixture(path: String, mesh: bool, skeleton: bool, clips: PackedStringArray, weighted: bool) -> bool:
	var fixture := Node3D.new()
	fixture.name = "Fixture"
	if mesh:
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		visual.mesh = _weighted_mesh() if weighted else BoxMesh.new()
		if weighted:
			visual.skeleton = NodePath("../Bones")
			var skin := Skin.new()
			skin.add_bind(0, Transform3D.IDENTITY)
			visual.skin = skin
		fixture.add_child(visual)
		visual.owner = fixture
	if skeleton:
		var bones := Skeleton3D.new()
		bones.name = "Bones"
		bones.add_bone("Root")
		fixture.add_child(bones)
		bones.owner = fixture
	if not clips.is_empty():
		var animator := AnimationPlayer.new()
		animator.name = "Animator"
		fixture.add_child(animator)
		animator.owner = fixture
		var library := AnimationLibrary.new()
		for clip_name in clips:
			var clip := Animation.new()
			clip.length = 1.0
			clip.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(clip_name, clip)
		animator.add_animation_library("Locomotion", library)
	var scene := PackedScene.new()
	var packed: Error = scene.pack(fixture)
	fixture.free()
	if packed != OK:
		return false
	return ResourceSaver.save(scene, path) == OK


func _actor(path: String, preferred_path: String = "") -> CharacterBody3D:
	var actor := CharacterBody3D.new()
	actor.name = "Actor"
	_populate_actor(actor, path, preferred_path)
	root.add_child(actor)
	return actor


func _stationary_actor(path: String, motion_seed := 0) -> Node3D:
	var actor := Node3D.new()
	actor.name = "StationaryActor"
	_populate_actor(actor, path)
	actor.get_node("ModelSlot").set("standing_motion_seed", motion_seed)
	root.add_child(actor)
	return actor


func _populate_actor(actor: Node3D, path: String, preferred_path: String = "") -> void:
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	actor.add_child(body)
	var slot := Node3D.new()
	slot.name = "ModelSlot"
	slot.set_script(SLOT_SCRIPT)
	slot.set("model_path", path)
	slot.set("rigged_model_path", preferred_path)
	slot.set("placeholder_names", PackedStringArray(["Body"]))
	actor.add_child(slot)


func _remove_actor(actor: Node3D) -> void:
	root.remove_child(actor)
	actor.queue_free()
	await process_frame


func _run() -> void:
	if not _expect(_fixture(RIG_FIXTURE, true, true, PackedStringArray(["Idle", "Walk", "Talk"]), true), "write synthetic rig fixture"):
		return
	if not _expect(_fixture(STATIC_FIXTURE, true, false, PackedStringArray(), false), "write static mesh fixture"):
		return
	if not _expect(_fixture(IDLE_ONLY_FIXTURE, true, true, PackedStringArray(["Idle"]), true), "write idle-only fixture"):
		return
	if not _expect(_fixture(UNWEIGHTED_FIXTURE, true, true, PackedStringArray(["Idle", "Walk"]), false), "write unweighted skeleton fixture"):
		return
	if not _expect(_fixture(EMPTY_FIXTURE, false, true, PackedStringArray(["Idle", "Walk"]), false), "write empty rig fixture"):
		return

	var actor := _actor(RIG_FIXTURE)
	await process_frame
	var slot: Node3D = actor.get_node("ModelSlot")
	var animator: AnimationPlayer = actor.get_node("ModelSlot/ImportedModel/Animator")
	if not _expect(not actor.get_node("Body").visible and animator.current_animation == "Locomotion/Idle" and slot.call("motion_mode") == "rigged", "rigged import hides primitive and starts namespaced Idle"):
		return
	actor.velocity = Vector3(1.0, 0.0, 0.0)
	slot.call("_process", 0.0)
	if not _expect(animator.current_animation == "Locomotion/Walk", "horizontal velocity selects Walk"):
		return
	actor.velocity = Vector3.ZERO
	slot.call("_process", 0.0)
	if not _expect(animator.current_animation == "Locomotion/Idle", "stopping returns to Idle"):
		return
	await _remove_actor(actor)

	actor = _actor(STATIC_FIXTURE, RIG_FIXTURE)
	await process_frame
	slot = actor.get_node("ModelSlot")
	if not _expect(slot.call("motion_mode") == "rigged" and slot.call("active_model_path") == RIG_FIXTURE, "preferred weighted rig replaces the static model"):
		return
	await _remove_actor(actor)

	actor = _actor(STATIC_FIXTURE, UNWEIGHTED_FIXTURE)
	await process_frame
	slot = actor.get_node("ModelSlot")
	if not _expect(slot.call("motion_mode") == "procedural" and slot.call("active_model_path") == STATIC_FIXTURE, "unweighted preferred model falls back to the static art"):
		return
	await _remove_actor(actor)

	actor = _actor(UNWEIGHTED_FIXTURE)
	await process_frame
	slot = actor.get_node("ModelSlot")
	if not _expect(slot.call("motion_mode") == "procedural" and slot.get("_animation_player") == null, "unweighted skeleton and clips do not count as a rig"):
		return
	await _remove_actor(actor)

	var stationary := _stationary_actor(RIG_FIXTURE, 202)
	var neighbor := _stationary_actor(RIG_FIXTURE, 907)
	await process_frame
	var stationary_animator: AnimationPlayer = stationary.get_node("ModelSlot/ImportedModel/Animator")
	if not _expect(stationary_animator.current_animation == "Locomotion/Idle", "stationary civic actor selects Idle"):
		return
	var standing_slot := stationary.get_node("ModelSlot")
	var neighbor_slot := neighbor.get_node("ModelSlot")
	if not _expect(absf(float(standing_slot.get("_standing_phase")) - float(neighbor_slot.get("_standing_phase"))) > 0.05 and not is_equal_approx(float(standing_slot.get("_standing_rate")), float(neighbor_slot.get("_standing_rate"))), "independent seeded NPCs begin at different sway phases and tempos"):
		return
	stationary_animator.advance(0.25)
	var phase_before := stationary_animator.current_animation_position
	standing_slot.call("set_talking", true)
	if not _expect(stationary_animator.current_animation == "Locomotion/Talk" and absf(stationary_animator.current_animation_position - phase_before) < 0.001, "Idle to Talk preserves the sway phase"):
		return
	standing_slot.call("set_talking", false)
	if not _expect(absf(stationary_animator.current_animation_position - phase_before) < 0.001, "returning to Idle does not reset sway"):
		return
	var original_rate := float(standing_slot.get("_standing_rate"))
	var varied := false
	for step in range(200):
		var before := float(standing_slot.get("_standing_rate"))
		standing_slot.call("_process", 0.1)
		var after := float(standing_slot.get("_standing_rate"))
		if not _expect(after >= 0.9 and after <= 1.1 and absf(after - before) <= 0.0021, "sway tempo drifts gradually inside its bounded range"):
			return
		varied = varied or absf(after - original_rate) > 0.005
	if not _expect(varied, "NPC tempo changes over time rather than repeating a fixed harmonic"):
		return
	await _remove_actor(neighbor)
	await _remove_actor(stationary)

	actor = _actor(IDLE_ONLY_FIXTURE)
	await process_frame
	slot = actor.get_node("ModelSlot")
	animator = actor.get_node("ModelSlot/ImportedModel/Animator")
	actor.velocity = Vector3(1.0, 0.0, 0.0)
	slot.call("_process", 0.0)
	if not _expect(animator.current_animation == "Locomotion/Idle", "missing Walk keeps Idle instead of disappearing"):
		return
	await _remove_actor(actor)

	actor = _actor(STATIC_FIXTURE)
	await process_frame
	slot = actor.get_node("ModelSlot")
	var model: Node3D = actor.get_node("ModelSlot/ImportedModel")
	var foot: Vector3 = slot.get("_foot_anchor")
	var anchored_at: Vector3 = model.transform * foot
	if not _expect(actor.has_node("ModelSlot/ImportedModel") and not actor.get_node("Body").visible and slot.get("_animation_player") == null and slot.call("motion_mode") == "procedural", "static visible mesh imports with procedural motion and without a rig"):
		return
	actor.velocity = Vector3(3.0, 0.0, 0.0)
	slot.call("_process", 0.2)
	if not _expect(absf(model.rotation.z) > 0.01 and (model.transform * foot).distance_to(anchored_at) < 0.0001, "unrigged walk sways visibly while its foot anchor stays fixed"):
		return
	actor.velocity = Vector3.ZERO
	slot.call("_process", 0.2)
	if not _expect((model.transform * foot).distance_to(anchored_at) < 0.0001, "unrigged idle also keeps its foot anchor fixed"):
		return
	await _remove_actor(actor)

	var still := Node3D.new()
	_populate_actor(still, STATIC_FIXTURE)
	var still_slot: Node3D = still.get_node("ModelSlot")
	still_slot.set("procedural_motion", false)
	root.add_child(still)
	await process_frame
	if not _expect(still_slot.call("motion_mode") == "static" and (still_slot.get_node("ImportedModel") as Node3D).rotation == Vector3.ZERO, "grounded actor can opt out of slot motion"):
		return
	await _remove_actor(still)

	actor = _actor(EMPTY_FIXTURE)
	await process_frame
	if not _expect(actor.get_node("Body").visible and not actor.has_node("ModelSlot/ImportedModel"), "rig without visible geometry keeps primitive fallback"):
		return
	await _remove_actor(actor)

	for path in [RIG_FIXTURE, STATIC_FIXTURE, IDLE_ONLY_FIXTURE, UNWEIGHTED_FIXTURE, EMPTY_FIXTURE]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Oathshaper rig slot Idle/Walk, procedural foot-anchored motion, opt-out and empty fallback checks passed")
	quit(0)
