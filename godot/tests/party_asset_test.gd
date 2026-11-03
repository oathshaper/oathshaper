extends SceneTree
const SLOT := preload("res://scripts/character_model_slot.gd")
const WEAPON := preload("res://scripts/command_weapon.gd")
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
var actors: Array[CharacterBody3D] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	evidence.record(message, value)
	if not value: failures += 1; push_error(message)
func frame(count := 3) -> void:
	for i in count: await process_frame
func capture(name: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/oath-party-assets-" + name + ".png")
func skin_grip_distance(weapon: Node3D, side: String) -> float:
	# Called inside skeleton_updated: modifiers' final transforms are restored
	# afterwards. Validate the rendered hand vertices, not our own socket math.
	var skeleton := weapon.grip.get_parent() as Skeleton3D
	var mesh: MeshInstance3D = skeleton.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := mesh.mesh.surface_get_arrays(0)
	var hand := skeleton.find_bone(side + "Hand")
	var matrices: Array[Transform3D] = []
	var bones: Array[int] = []
	for bind in mesh.skin.get_bind_count():
		var bone := skeleton.find_bone(mesh.skin.get_bind_name(bind)) if not mesh.skin.get_bind_name(bind).is_empty() else mesh.skin.get_bind_bone(bind)
		bones.append(bone)
		matrices.append(skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(bind))
	var asset: Node3D = weapon.visual if side == "R" else weapon.offhand_visual
	var primary: Node3D = asset.find_child("PrimaryGrip", true, false)
	var distance := INF
	for vertex in arrays[Mesh.ARRAY_VERTEX].size():
		var hand_weight := 0.0
		var point := Vector3.ZERO
		for influence in 4:
			var bind: int = arrays[Mesh.ARRAY_BONES][vertex * 4 + influence]
			var weight: float = arrays[Mesh.ARRAY_WEIGHTS][vertex * 4 + influence]
			if bones[bind] == hand: hand_weight += weight
			point += (matrices[bind] * arrays[Mesh.ARRAY_VERTEX][vertex]) * weight
		if hand_weight > .5: distance = minf(distance, point.distance_to(primary.global_position))
	return distance
func check_skin_grips(actor: Node3D) -> void:
	var weapon: Node3D = actor.get_node("Weapon")
	var skeleton := weapon.grip.get_parent() as Skeleton3D
	skeleton.skeleton_updated.connect(func() -> void:
		for side in ["R", "L"] if weapon.offhand_kind == "buckler" else ["R"]:
			var distance := skin_grip_distance(weapon, side)
			check(distance < .05, "%s %s grip touches the final skinned hand (%.3fm)" % [actor.name, side, distance])
	, CONNECT_ONE_SHOT)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("263138")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c9d3d4")
	env.environment.ambient_light_energy = .65
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -40, 0)
	sun.light_energy = 1.5
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = .5
	world.add_child(fill)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(18, 18)
	floor.mesh = plane
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color("596166"); mat.roughness = 1
	floor.material_override = mat
	world.add_child(floor)
	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	camera.position = Vector3(0, 2.3, -7.5)
	camera.look_at(Vector3(0, 1, 0))
	for data in [["player", "sabre", "buckler", -2.0], ["mara", "staff", "staff", 0.0], ["ivo", "mace", "buckler", 2.0]]:
		var actor := CharacterBody3D.new(); actor.name = data[0]
		actor.position.x = data[3]
		world.add_child(actor); actors.append(actor)
		var slot := SLOT.new(); slot.name = "ModelSlot"
		slot.model_scale = Vector3.ONE * 2
		slot.model_offset = Vector3.ZERO
		slot.rigged_model_path = "res://assets/meshes/rigged/%s_rigged.glb" % data[0]
		slot.rotation.y = PI
		slot.randomize_standing_motion = false
		actor.add_child(slot)
		var imported := slot.get_node("ImportedModel") as Node3D
		imported.position.y -= slot._mesh_bottom_local(imported) * slot.model_scale.y
		if data[0] == "player": check(absf(imported.position.y - .95) < .001, "Combat placement uses the rig ground anchor without doubling bind transforms")
		check(slot.motion_mode() == "rigged", "Actor uses a weighted rig: " + data[0])
		var weapon := WEAPON.new(); weapon.name = "Weapon"
		actor.add_child(weapon)
		weapon.configure(data[1], data[2]); weapon.set_readied(true)
		check(weapon.visual.find_child("PrimaryGrip", true, false) != null, "Imported weapon provides a primary grip: " + data[0])
		check(weapon.visual.find_children("*", "MeshInstance3D", true, false).size() == 1, "Actual supplied weapon mesh replaces primitive pieces: " + data[0])
		if data[0] == "mara": check(weapon.offhand_visual.get_child_count() == 0, "Mara's two equipment bindings draw one staff")
	await frame(20)
	for actor in actors: check_skin_grips(actor)
	await frame(3)
	var tessa := actors[0]; var slot: Node3D = tessa.get_node("ModelSlot")
	var skeleton: Skeleton3D = slot.find_children("*", "Skeleton3D", true, false)[0]
	check(skeleton.get_bone_count() == 72, "Tessa retains all provider joints")
	if "--inspect" in OS.get_cmdline_user_args():
		print("BONES ", range(skeleton.get_bone_count()).map(func(i): return skeleton.get_bone_name(i)))
		for actor in actors:
			var bones: Skeleton3D = actor.get_node("ModelSlot").find_children("*", "Skeleton3D", true, false)[0]
			var weapon: Node3D = actor.get_node("Weapon")
			print("GRIP ", actor.name, " hand=", bones.get_bone_global_pose(bones.find_bone("RHand")), " weapon=", weapon.visual.global_transform)
	for name in ["RHand", "LHand", "RUpperArm", "RForearm", "Chest", "mixamorig_RightHandIndex1"]:
		check(skeleton.find_bone(name) >= 0, "Required body/finger bone exists: " + name)
	var anim: AnimationPlayer = slot._animation_player
	for clip in ["Idle", "Walk", "Run"]: check(anim.has_animation(clip), "Tessa clip exists: " + clip)
	var mesh: MeshInstance3D = slot.find_children("*", "MeshInstance3D", true, false)[0]
	var material: StandardMaterial3D = mesh.mesh.surface_get_material(0)
	check(material.albedo_texture.get_width() == 8192, "Original 8K albedo is loaded")
	check(anim.current_animation == "Idle", "Stationary Tessa plays standing clip")
	for actor in actors:
		var weapon: Node3D = actor.get_node("Weapon")
		var primary: Node3D = weapon.visual.find_child("PrimaryGrip", true, false)
		var palm := preload("res://scripts/equipment_mount.gd").palm_frame(weapon.grip.get_parent(), "R")
		check(primary.global_position.distance_to(weapon.grip.to_global(palm.get("position", Vector3(0, .035, 0)))) < .002, "Weapon grip meets palm: " + actor.name)
	check(actors[1].get_node("Weapon").pose.support_error * 2 < .045, "Mara's support hand reaches the staff grip")
	await capture("party-ready")
	camera.position = Vector3(-3.7, 1.55, -2.2)
	camera.look_at(Vector3(-2, 1.15, 0))
	await frame(); await capture("tessa-grip")
	camera.position = Vector3(3.6, 1.6, -2.4)
	camera.look_at(Vector3(2, 1.15, 0))
	await frame(); await capture("ivo-grip")
	camera.position = Vector3(0, 2.3, -7.5)
	camera.look_at(Vector3(0, 1, 0))
	for ability in ["basic", "shield_bash"]:
		var weapon: Node3D = tessa.get_node("Weapon")
		weapon.pose.ability_id = ability; weapon.pose.strike_time = -1; weapon.strike()
		weapon.pose.strike_time = .6 if ability == "shield_bash" else .32
		weapon.pose.set_process(false)
		for actor in actors: check_skin_grips(actor)
		await frame(); await capture(ability)
		weapon.pose.sheathe(); weapon.pose.set_process(true); weapon.set_readied(true)
	for actor in actors: actor.velocity = Vector3(0, 0, -2.0)
	await frame(12)
	for actor in actors: check_skin_grips(actor)
	await frame(3); await capture("party-moving-armed")
	for actor in actors: actor.velocity = Vector3.ZERO
	for actor in actors: actor.get_node("Weapon").set_readied(false)
	await frame(5); await capture("party-sheathed")
	for actor in actors: actor.velocity = Vector3(0, 0, -2.0)
	await frame(12); await capture("party-walking")
	for actor in actors: actor.velocity = Vector3.ZERO
	for data in [[2.0, "Walk"], [4.5, "Run"], [0.0, "Idle"]]:
		tessa.velocity = Vector3(0, 0, -data[0])
		slot._process(0)
		check(anim.current_animation == data[1], "Movement selects " + data[1])
		await frame(10); await capture(str(data[1]).to_lower())
	check(is_equal_approx(slot.walk_cycle_distance, 1.138) and is_equal_approx(slot.run_cycle_distance, 3.537), "Library walk and jog supply their measured stride calibration")
	# All three travelling actors must share the gait policy. Checking only the
	# player's clip name missed the accelerated legacy walk on companions.
	for actor in actors:
		var actor_slot: Node3D = actor.get_node("ModelSlot")
		for sample in [[1.5, "Walk"], [4.5, "Run"], [0.0, "Idle"]]:
			actor.velocity = Vector3(0, 0, -sample[0])
			actor_slot._process(0)
			check(actor_slot._animation_player.current_animation == sample[1], str(actor.name) + " selects shared gait at " + str(sample[0]) + "m/s")
		check(is_equal_approx(actor_slot.run_speed_threshold, 2.8), str(actor.name) + " shares the travel gait threshold")
		check(actor_slot.run_cycle_distance > 3.0, str(actor.name) + " uses measured jog stride instead of sped-up walk")
	# Analog input near the gait boundary must not restart the cycle repeatedly.
	tessa.velocity = Vector3(0, 0, -3.0); slot._process(0)
	anim.seek(anim.get_animation("Run").length * .4, true)
	tessa.velocity = Vector3(0, 0, -2.7); slot._process(0)
	check(anim.current_animation == "Run", "Run has hysteresis around the input threshold")
	tessa.velocity = Vector3(0, 0, -2.4); slot._process(0)
	check(anim.current_animation == "Walk" and absf(anim.current_animation_position / anim.get_animation("Walk").length - .4) < .01, "Walk/run transition preserves foot phase")
	# Check the imported poses too: equal timeline phases must agree on which
	# leg leads. Otherwise a correct seek still makes the legs swap mid-blend.
	var gaps: Array = []
	for gait in ["Walk", "Run"]:
		var values: Array[float] = []
		for sample in 20:
			anim.play(gait, 0)
			anim.seek(anim.get_animation(gait).length * sample / 20.0, true)
			values.append(skeleton.get_bone_global_pose(skeleton.find_bone("LFoot")).origin.z - skeleton.get_bone_global_pose(skeleton.find_bone("RFoot")).origin.z)
		var amplitude: float = values.map(func(v): return absf(v)).max()
		gaps.append(values.map(func(v): return v / maxf(amplitude, .001)))
	var phase_error := 0.0
	for sample in 20: phase_error += pow(gaps[0][sample] - gaps[1][sample], 2) / 20.0
	check(phase_error < .08, "Retargeted walk and retained run keep the same leading leg through a gait change")
	if "--capture" in OS.get_cmdline_user_args():
		actors[1].hide(); actors[2].hide()
		slot.set_process(false)
		anim.speed_scale = 0
		for gait in ["Walk", "Run"]:
			var sheet := Image.create(2400, 900, false, Image.FORMAT_RGB8)
			for view in 2:
				camera.position = Vector3(-2, 1.5, -3.6) if view == 0 else Vector3(-5.6, 1.5, 0)
				camera.look_at(Vector3(-2, .95, 0))
				for phase in 4:
					anim.play(gait, 0); anim.seek(anim.get_animation(gait).length * phase / 4.0, true)
					await frame(); await RenderingServer.frame_post_draw
					var shot := root.get_texture().get_image()
					# Crop the central 4:3 view before laying out the sampled poses.
					var width := mini(shot.get_width(), roundi(shot.get_height() * 4.0 / 3.0))
					shot = shot.get_region(Rect2i((shot.get_width()-width)/2, 0, width, shot.get_height()))
					shot.resize(600, 450); shot.convert(Image.FORMAT_RGB8)
					sheet.blit_rect(shot, Rect2i(0, 0, 600, 450), Vector2i(phase*600, view*450))
			sheet.save_png("/tmp/oath-party-assets-" + gait.to_lower() + "-cycle.png")
	print("PARTY_ASSETS: %d checks, %d failures" % [checks, failures])
	evidence.finish("party-assets", "Imported party rigs, same-speed gait selection, original textures and equipment grip alignment. Visual acting quality still requires review.")
	world.free()
	quit(1 if failures else 0)
