extends SceneTree
## Actual imported skins/materials, host-driven presentation and close-camera safety.
const ADVERSARY := preload("res://scripts/command_adversary.gd")
const STAGE := preload("res://scripts/command_stage.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func capture(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(path) == OK, "Capture " + path)

func fixture(id: String, display_name: String, point: Array, faction := "hostile") -> Dictionary:
	return {"id":id,"name":display_name,"position":point,"faction":faction,"conscious":true,"appearance":{"main_hand":"sabre","offhand":"none"},"health":{"current":50,"maximum":50}}

func _run() -> void:
	root.size = Vector2i(1280,800)
	var stage := STAGE.new()
	root.add_child(stage)
	stage.set_process(false)
	stage.get_node("ImportedGarden").visible = false
	var ids := ["lantern_sentinel","iron_sentinel","crimson_corsair"]
	var display := Node3D.new()
	stage.add_child(display)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16,16)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("465052")
	ground.material_override = material
	display.add_child(ground)
	var rigs: Array[Node3D] = []
	for index in ids.size():
		var model := ADVERSARY.new()
		display.add_child(model)
		model.configure(ids[index])
		model.position.x = (index-1)*2.35
		rigs.append(model)
		var skeleton := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		check(skeleton.get_bone_count() >= 11, "Authored skin has real limb bones: " + ids[index])
		for clip in ["Idle","Walk","Strike","Hit"]:
			check(model.animation.has_animation(clip), "Imported clip " + ids[index] + ": " + clip)
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			check(mesh.skin != null, "Mesh bound to authored skin")
			var triangles := 0
			for surface in mesh.mesh.get_surface_count():
				triangles += mesh.mesh.surface_get_array_index_len(surface)/3
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var normalized := true
				for offset in range(0, weights.size(), 4):
					var total := weights[offset] + weights[offset+1] + weights[offset+2] + weights[offset+3]
					normalized = normalized and is_finite(total) and absf(total-1.0) < .001
				check(normalized and not weights.is_empty(), "Every vertex has normalized skin weights")
				var mat: StandardMaterial3D = mesh.mesh.surface_get_material(surface)
				check(mat.albedo_texture != null and mat.normal_texture != null and mat.metallic_texture != null, "Supplied base color, normal and metal maps retained")
			check(triangles <= 60000, "Game derivative meets triangle budget")
		model._sample("Walk", .25)
		var bone := skeleton.find_bone("LUpperLeg" if ids[index] == "crimson_corsair" else "LFrontUpper" if ids[index] == "iron_sentinel" else "LUpper")
		var walked := skeleton.get_bone_pose_rotation(bone)
		model.set_motion(Vector3.ZERO,10,true)
		check(skeleton.get_bone_pose_rotation(bone).is_equal_approx(walked), "Pause freezes posed limbs")
		check(not walked.is_equal_approx(Quaternion.IDENTITY), "Walk actually poses a limb")
		model._sample("Idle", 0)
		var label := Label3D.new()
		label.text = ids[index].replace("_"," ").capitalize()
		label.position = Vector3(model.position.x,2.35,0)
		label.font_size = 40
		label.pixel_size = .004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		display.add_child(label)
	stage.camera.position = Vector3(0,2.6,-7.7)
	stage.camera.fov = 43
	stage.camera.look_at(Vector3(0,1.05,0))
	await capture("/tmp/oathshaper-adversaries-rigged-idle.png")
	for model in rigs: model._sample("Walk", .25)
	await capture("/tmp/oathshaper-adversaries-rigged-walk.png")
	for model in rigs: model._sample("Strike", .375)
	await capture("/tmp/oathshaper-adversaries-rigged-strike.png")
	display.free()
	stage.get_node("ImportedGarden").visible = true
	stage.camera.fov = 60
	var view := {"session":{"generation":"mesh-test","tick":1},"clock":{"paused":true},"party":{"recipient_id":"player","camera_follow_id":"player","selected_target_id":"hound"},"actors":[fixture("player","Tessa Ward",[0.,0.],"party"),fixture("mara","Mara",[-1.5,1.5],"party"),fixture("ivo","Ivo",[-1.5,-1.5],"party"),fixture("hound","Iron Sentinel",[2.2,0.]),fixture("sentinel","Lantern Sentinel",[4.,2.]),fixture("corsair_raider","Crimson Corsair",[3.,-2.])]}
	view.actors[3].appearance.model = "iron_sentinel"
	view.actors[4].appearance.model = "lantern_sentinel"
	stage.apply_view(view)
	await physics_frame
	await process_frame
	stage._position_camera()
	check(stage.actors.hound.get_node("Art").kind == "iron_sentinel", "Appearance key resolves requested actual model")
	check(stage.actors.corsair_raider.has_node("Art") and not stage.actors.corsair_raider.has_node("ModelSlot"), "Enemy corsair does not reuse player model")
	check(stage.actors.corsair_raider.get_node("Weapon").grip != null, "Crimson sabre attaches to the supplied character derivative's hand rig")
	check(stage.actors.hound.get_node("SelectionRing").material_override.albedo_color == STAGE.TARGET, "Selected hostile gets the bright target ring")
	check(stage.actors.player.get_node("SelectionRing").material_override.albedo_color == STAGE.GOLD, "Selected party member retains their control ring")
	check(stage.camera.position.distance_to(stage.actors.player.position) < 8.5, "Command camera stays close to selected companion")
	var blocked := stage._safe_camera_position(Vector3(-3.91,1,-2.8),Vector3(-3.91,1,-6.0))
	check(blocked.z > -3.3, "Camera volume stops before planter wall")
	await capture("/tmp/oathshaper-adversaries-command-garden.png")
	view.actors[5].active_action = {"id":"strike-test","state":"windup","target":{"actor_id":"player"}}
	stage.apply_view(view)
	check(stage.actors.corsair_raider.get_node("Art")._reaction == "Strike", "Armed Crimson samples its authored Strike clip")
	check(stage.actors.corsair_raider.get_node("Weapon").pose.strike_count == 1, "Armed Crimson also animates its bone-attached weapon")
	stage.free()
	print("Adversary stage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
