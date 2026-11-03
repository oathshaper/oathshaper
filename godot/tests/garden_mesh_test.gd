extends SceneTree

## Exercises the real Player script over the imported bridge and terrace.
## Run after import with: Godot --headless --path godot --script res://tests/garden_mesh_test.gd

const GardenLayout = preload("res://scripts/garden_layout.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("Garden mesh test failed: " + message)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var hub := (load("res://scripts/hub_environment.gd") as Script).new() as Node3D
	hub.name = "HubEnvironment"
	world.add_child(hub)
	var imported := hub.get_node_or_null("DistrictDetails/ImportedGardenArt") as Node3D
	_expect(imported != null and imported.visible, "optimized supplied garden instantiates visibly")
	if imported == null:
		quit(1)
		return
	hub.call("set_gate_open", true)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	world.add_child(rig)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.rotation.y = -PI * 0.5 # W travels east along the garden bridge.
	rig.add_child(camera)
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(29.0, 1.05, -2.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.7
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	player.add_child(shape)
	world.add_child(player)
	await physics_frame
	await physics_frame
	# Check the actual art at the mouth: the original mismatch had a 2.3 m
	# bridge inside a 4 m plank deck. A bigger abstract floor cannot pass this.
	var mouth_min := INF
	var mouth_max := -INF
	for mesh in imported.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = mesh.to_global(vertex)
				if point.x > 31.7 and point.x < 32.4 and point.y < 0.6:
					mouth_min = minf(mouth_min, point.z)
					mouth_max = maxf(mouth_max, point.z)
	_expect(mouth_min < -3.7 and mouth_max > -0.3, "actual stone mouth spans the plank deck: %.2f..%.2f" % [mouth_min, mouth_max])
	_expect(mouth_min > -4.5 and mouth_max < 0.5, "mesh is centered on the four metre opening")
	var approach := hub.get_node("DistrictDetails/GardenApproach")
	var deck := approach.get_node("Deck") as MeshInstance3D
	var sill := approach.get_node("StoneSill") as MeshInstance3D
	_expect(is_equal_approx(deck.position.x - deck.scale.x * 0.5, 30.0), "planks meet the bluff paving edge exactly")
	_expect(is_equal_approx(deck.position.x + deck.scale.x * 0.5, sill.position.x - sill.scale.x * 0.5), "planks meet stone sill without overlapping coplanar faces")
	_expect(is_equal_approx(deck.scale.z, sill.scale.z), "paving, plank and stone mouth share their width")
	_check_approach_faces(approach, hub.get_node("SeawallsAndParapets"))
	# Start on the bluff, not halfway across the bridge. Exercise both edges
	# as well as the center, including the sill and the rise inside the gate.
	for lane in [-2.9, -2.0, -1.1]:
		player.global_position = Vector3(29.0, 1.05, lane)
		player.velocity = Vector3.ZERO
		player.call("reset_movement_basis")
		for _frame in range(6):
			await physics_frame
		var entry_y := player.global_position.y
		_key(KEY_W, true)
		for _frame in range(200):
			await physics_frame
		_key(KEY_W, false)
		await physics_frame
		var arrival := player.global_position
		_expect(arrival.x > 43.2 and arrival.x < 45.0, "W reaches the terrace from the bluff in lane %.1f: %s" % [lane, arrival])
		_expect(absf(arrival.y - 1.628) < 0.08, "feet rest on enlarged terrace: %s" % arrival)
		_key(KEY_S, true)
		for _frame in range(200):
			await physics_frame
		_key(KEY_S, false)
		for _frame in range(6):
			await physics_frame
		_expect(player.global_position.x > 28.0 and player.global_position.x < 30.0, "S crosses back to the bluff in lane %.1f: %s" % [lane, player.global_position])
		_expect(absf(player.global_position.y - entry_y) < 0.06, "return reaches original bluff height")
	# The mesh's walking deck is flat until the gate, then rises. These
	# measured heights catch both floating actors and an early invisible step.
	var physics := world.get_world_3d().direct_space_state
	for sample in [[33.0, 0.20], [37.0, 0.21], [40.0, 0.406], [42.0, 0.707], [44.0, 0.770]]:
		var hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(sample[0], 3.0, -2.0), Vector3(sample[0], -1.0, -2.0)))
		_expect(not hit.is_empty() and absf(hit.get("position", Vector3.ZERO).y - sample[1]) < 0.10, "floor proxy follows measured visible paving at x=%.1f: %s" % [sample[0], hit.get("position")])
	var bed_center := GardenLayout.point(Vector3(39.0, 0.99, -5.3))
	player.global_position = Vector3(bed_center.x, 1.63, -3.0)
	camera.rotation.y = 0.0
	player.call("reset_movement_basis")
	await physics_frame
	_key(KEY_W, true)
	for _frame in range(85):
		await physics_frame
	_key(KEY_W, false)
	_expect(player.global_position.z < -4.0 and player.global_position.z > -6.2, "enlarged north planter stops player at its rim: %s" % player.global_position)
	var side_hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(34.0, 0.9, -2.0), Vector3(34.0, 0.9, -4.2)))
	_expect(not side_hit.is_empty() and side_hit.get("collider") == hub.get_node("DistrictDetails/GardenWalkCollision"), "bridge rail prevents stepping into water")
	# The story gate must still block the full usable width before unlocking.
	hub.call("set_gate_open", false)
	await physics_frame
	await physics_frame
	for lane in [-3.2, -2.0, -0.8]:
		var hit := physics.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(30.5, 1.0, lane), Vector3(33.0, 1.0, lane)))
		_expect(not hit.is_empty() and hit.get("collider") == hub.get_node("EastGardenGate/Barrier"), "closed gate spans entrance lane %.1f" % lane)

	world.queue_free()
	await process_frame
	if not _failed:
		print("garden_mesh_test passed: actual mesh fit, three lanes both ways, floor heights, planter, rails and closed gate")
	quit(1 if _failed else 0)


func _check_approach_faces(approach: Node3D, perimeter: Node3D) -> void:
	# Coincident outward faces shimmer with camera motion even though all
	# walking tests pass. Ignore internal contacts with opposite normals.
	var pieces: Array[MeshInstance3D] = []
	for node in approach.get_children() + perimeter.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and node.rotation.is_zero_approx():
			pieces.append(node)
	var inspected := 0
	for i in range(pieces.size()):
		var a := pieces[i]
		for j in range(i + 1, pieces.size()):
			var b := pieces[j]
			if a.get_parent() != approach and b.get_parent() != approach:
				continue
			var box_a := AABB(a.global_position - a.scale * 0.5, a.scale)
			var box_b := AABB(b.global_position - b.scale * 0.5, b.scale)
			for axis in range(3):
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var overlap_u := minf(box_a.end[u], box_b.end[u]) - maxf(box_a.position[u], box_b.position[u])
				var overlap_v := minf(box_a.end[v], box_b.end[v]) - maxf(box_a.position[v], box_b.position[v])
				if overlap_u < 0.001 or overlap_v < 0.001:
					continue
				inspected += 1
				for face in [0, 1]:
					var plane_a: float = box_a.position[axis] if face == 0 else box_a.end[axis]
					var plane_b: float = box_b.position[axis] if face == 0 else box_b.end[axis]
					_expect(absf(plane_a - plane_b) > 0.001, "no coincident outward faces between %s and %s (axis %d)" % [a.name, b.name, axis])
	_expect(inspected > 0, "seam geometry was inspected for coplanar faces")
