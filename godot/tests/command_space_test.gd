extends SceneTree
## Actual imported-garden footprint: route clearance and scene collider parity.
var failures := 0
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _run() -> void:
	var space := preload("res://scripts/command_space.gd").new()
	for id in space.geometry.spawns:
		var point: Array = space.geometry.spawns[id]
		check(space.walkable(Vector2(point[0], point[1])), "Spawn must fit actual terrace: " + id)
	check(not space.walkable(Vector2(5.78, 5.44)), "Raised bed is not walkable")
	check(not space.walkable(Vector2(30, 0)), "Sea is not walkable")
	check(space.route(Vector2.ZERO, Vector2(6, 2)).size() == 2, "Worked example has clear direct corridor")
	var around: Array = space.route(Vector2(2, 5.44), Vector2(10, 5.44))
	check(around.size() > 2, "Path must route around east bed")
	for index in range(1, around.size()):
		check(space.line_clear(around[index - 1], around[index], .35, true), "Every routed segment clears bed and rail")
	check(space.route(Vector2.ZERO, Vector2(5.78, 5.44)).is_empty(), "No direct-line fallback into obstacle")
	check(space.route(Vector2.ZERO, Vector2(-6.5, 0)).size() >= 2, "Exit route crosses the terrace/ramp seam")
	var stage := preload("res://scripts/command_stage.gd").new()
	root.add_child(stage)
	await physics_frame
	await physics_frame
	for pair in [[Vector2(2, 5.44), Vector2(10, 5.44)], [Vector2.ZERO, Vector2(6, 2)]]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(pair[0].x, 1.0, pair[0].y), Vector3(pair[1].x, 1.0, pair[1].y), 4)
		var clear := stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
		check(clear == space.line_clear(pair[0], pair[1]), "Analytic LOS matches actual scene collision")
	print("COMMAND_SPACE_TEST: %d failures" % failures)
	quit(1 if failures else 0)
