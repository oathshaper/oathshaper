extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var map_script: Script = load("res://scripts/map_widget.gd")
	if map_script == null:
		_fail("Map widget script did not load")
		quit(1)
		return
	var map: Control = map_script.new()
	root.add_child(map)
	await process_frame
	_check(map.desired_size() == Vector2(260.0, 190.0), "compact size includes location guidance")
	map.set_map_state(Vector3(0.0, 1.0, 5.0), "quay", "clerk", {"shortcut_open": false, "gate_open": false})
	_check(map._waypoint_label() == "FIND THE CIVIC CLERK", "clerk waypoint")
	_check(map._location_text().begins_with("CENTRAL QUAY\n"), "compact map identifies current district")
	map.set_map_state(Vector3(23.0, 1.0, -4.0), "quay", "clerk", {}, "EAST BLUFF\nIvo east · tower northwest")
	_check(map._location_text() == "EAST BLUFF\nIvo east · tower northwest", "location guidance supplied by HUD")
	map.set_map_state(Vector3(-10.0, 1.0, -25.0), "quay", "records_door", {"shortcut_open": true})
	_check(map._waypoint_label() == "RECORDS DOOR", "records waypoint")
	_check(map._location_text().begins_with("CIVIC COURT\n"), "journal map derives location without supplied hint")
	map.set_expanded(true)
	_check(map.desired_size() == Vector2(540.0, 380.0), "expanded size")
	map.set_map_state(Vector3(157.0, 1.0, -27.0), "records_office", "cabinet", {})
	_check(map._area == "records_office", "indoor area")
	_check(map._location_text().begins_with("CIVIC RECORDS OFFICE\nCabinet"), "office location guidance")
	map.set_map_state(Vector3(157.0, 1.0, -27.0), "records_office", "done", {"records_collected": true})
	_check(map._location_text().contains("Records recovered"), "completed office guidance")
	var rect := Rect2(Vector2.ZERO, Vector2(100.0, 100.0))
	var north: Vector2 = map._map_point(rect, Vector2(0.0, -29.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0))
	var south: Vector2 = map._map_point(rect, Vector2(0.0, -19.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0))
	_check(north.y < south.y, "north is up")
	var east: Vector2 = map._map_point(rect, Vector2(166.0, -24.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0))
	var west: Vector2 = map._map_point(rect, Vector2(154.0, -24.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0))
	_check(east.x > west.x, "east is right")
	_check(not map._is_in_bounds(Vector2(150.0, -24.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0)), "out of bounds player uses edge indicator")
	_check(map._is_in_bounds(Vector2(157.0, -27.0), Vector2(154.0, -29.0), Vector2(166.0, -19.0)), "in bounds player uses dot")
	# The rendered plan and playable collision floor must share exact metre bounds.
	# This catches the original error where the map drew invented diagonal paths.
	var hub_script: Script = load("res://scripts/hub_environment.gd")
	var hub: Node3D = hub_script.new()
	root.add_child(hub)
	await process_frame
	var map_surfaces: Dictionary = map._surface_bounds()
	var floor_root := hub.get_node("WalkableDistrict")
	var actual_surfaces := {}
	for node in floor_root.get_children():
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			actual_surfaces[mesh.name] = Rect2(mesh.position.x - mesh.scale.x * 0.5,
				mesh.position.z - mesh.scale.z * 0.5, mesh.scale.x, mesh.scale.z)
	_check(map_surfaces.size() == actual_surfaces.size() and map_surfaces.size() == 13, "all 13 walkable footprints appear on map")
	for name in map_surfaces:
		_check(actual_surfaces.has(name) and (actual_surfaces.get(name, Rect2()) as Rect2).is_equal_approx(map_surfaces[name]), "map matches generated floor: " + name)
	for feature in map.QUAY_FEATURES:
		var body := hub.get_node_or_null("DistrictDetails/" + str(feature[0])) as StaticBody3D
		if not _expect_node(body, "mapped feature exists: " + str(feature[0])):
			continue
		var shape := (body.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		_check(Vector2(body.position.x, body.position.z).is_equal_approx(Vector2(feature[1], feature[2]))
			and Vector2(shape.size.x, shape.size.z).is_equal_approx(Vector2(feature[3], feature[4])),
			"map matches obstacle footprint: " + str(feature[0]))
	for bed in map.GARDEN_BEDS:
		var bed_collision := hub.get_node_or_null("DistrictDetails/GardenWalkCollision/" + str(bed[0])) as CollisionShape3D
		if not _expect_node(bed_collision, "mapped garden bed exists: " + str(bed[0])):
			continue
		var bed_shape := bed_collision.shape as BoxShape3D
		_check(bed_collision.position.is_equal_approx(map.GardenLayout.point(Vector3(bed[1], 0.99, bed[2])))
			and Vector2(bed_shape.size.x, bed_shape.size.z).is_equal_approx(Vector2(bed[3], bed[4]) * map.GardenLayout.ENLARGEMENT),
			"enlarged garden schematic matches planted-bed collision: " + str(bed[0]))
	var door := hub.get_node("RecordsDoor") as Node3D
	_check(map.RECORDS_DOOR_POINT.is_equal_approx(Vector2(door.position.x, door.position.z)), "records waypoint maps to the physical archive door")
	var tower := hub.get_node("LandmarkTower") as Node3D
	_check(map.TOWER_POINT.is_equal_approx(Vector2(tower.position.x, tower.position.z)), "tower icon maps to the physical landmark")
	var footprint := tower.get_node("TowerFootprint/CollisionShape3D") as CollisionShape3D
	if not (tower.get_node("TowerArt") as Node3D).visible:
		_check(is_equal_approx((footprint.shape as BoxShape3D).size.x, map.TOWER_FOOTPRINT_WIDTH) and is_equal_approx((footprint.shape as BoxShape3D).size.z, map.TOWER_FOOTPRINT_WIDTH), "imported tower icon uses actual collision footprint")
	else:
		_check((footprint.shape as BoxShape3D).size.x == 4.0 and (footprint.shape as BoxShape3D).size.z == 4.0, "primitive fallback retains its authored collision footprint")
	var compact_rect: Rect2 = map._fit_world_rect(Rect2(Vector2.ZERO, Vector2(236.0, 107.0)), map.QUAY_MIN, map.QUAY_MAX)
	_check(absf(compact_rect.size.x / (map.QUAY_MAX.x - map.QUAY_MIN.x) - compact_rect.size.y / (map.QUAY_MAX.y - map.QUAY_MIN.y)) < 0.0001, "compact map preserves metre scale across both axes")
	var office_script: Script = load("res://scripts/records_office.gd")
	var office: Node3D = office_script.new()
	office.position = Vector3(160.0, 0.0, -24.0)
	root.add_child(office)
	await process_frame
	var cabinet: Vector3 = office.cabinet_position()
	_check(map.CABINET_POINT.is_equal_approx(Vector2(cabinet.x, cabinet.z)), "cabinet marker matches the room")
	var desk: Node3D = office.get_node("RecordsDesk")
	_check(map.DESK_POINT.is_equal_approx(Vector2(desk.global_position.x, desk.global_position.z)), "desk silhouette matches the room")
	office.queue_free()
	hub.queue_free()
	await process_frame
	map.queue_free()
	if not _failed:
		print("map_widget_test passed")
	quit(1 if _failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_fail(label)


func _expect_node(node: Node, label: String) -> bool:
	_check(node != null, label)
	return node != null


func _fail(label: String) -> void:
	_failed = true
	push_error("map_widget_test failed: " + label)
