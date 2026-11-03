extends SceneTree

const OFFICE_SCRIPT := preload("res://scripts/records_office.gd")


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("Records office test failed: " + message)
	quit(1)
	return false


func _ray(office: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	return office.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(office.to_global(from), office.to_global(to)))


func _run() -> void:
	var office := Node3D.new()
	office.name = "RecordsOffice"
	office.position = Vector3(160.0, 0.0, -24.0)
	office.set_script(OFFICE_SCRIPT)
	root.add_child(office)
	await physics_frame
	var structure := office.get_node("Structure") as StaticBody3D
	# Coplanar wall/cap tops shimmer under a moving camera. Check the actual
	# generated surfaces, including cap joins at both corners.
	var north_cap := office.get_node("NorthCoping") as MeshInstance3D
	var north_cap_bounds := north_cap.transform * north_cap.mesh.get_aabb()
	for wall_name in ["NorthWall", "WestWall", "EastWall"]:
		var wall := office.get_node(wall_name) as MeshInstance3D
		var wall_bounds := wall.transform * wall.mesh.get_aabb()
		if not _expect(north_cap_bounds.position.y >= wall_bounds.end.y - 0.0001 and north_cap_bounds.end.y > wall_bounds.end.y + 0.1, "coping covers rather than shares the wall top: " + wall_name):
			return
	for side in [-1, 1]:
		var side_cap := office.get_node("SideCoping_%d" % side) as MeshInstance3D
		var side_bounds := side_cap.transform * side_cap.mesh.get_aabb()
		if not _expect(absf(side_bounds.position.z - north_cap_bounds.end.z) < 0.0001, "side cap butts against north cap without overlapping top faces"):
			return
		if not _expect((side_cap.material_override as StandardMaterial3D).albedo_texture != null, "wall top retains its stone texture"):
			return
	if not _expect(office.call("entry_position") == Vector3(160.0, 1.05, -21.0) and office.call("exit_door_position") == Vector3(160.0, 1.05, -19.8) and office.call("cabinet_position") == Vector3(156.8, 1.05, -27.5), "world-space entry, exit, and cabinet points match the 12x10 office"):
		return
	var floor_hit := _ray(office, Vector3(0.0, 2.0, 3.0), Vector3(0.0, -1.0, 3.0))
	if not _expect(floor_hit.get("collider") == structure and absf((floor_hit["position"] as Vector3).y - 0.2) < 0.001, "entry stands over the colliding floor at y=0.2"):
		return
	if not _expect(_ray(office, Vector3(0.0, 1.0, -3.0), Vector3(0.0, 1.0, -6.0)).get("collider") == structure and _ray(office, Vector3(4.0, 1.0, 0.0), Vector3(7.0, 1.0, 0.0)).get("collider") == structure, "north and side walls block walking out"):
		return
	if not _expect(_ray(office, Vector3(0.0, 1.0, 4.0), Vector3(0.0, 1.0, 6.0)).is_empty() and _ray(office, Vector3(3.0, 1.0, 4.0), Vector3(3.0, 1.0, 6.0)).get("collider") == structure, "south doorway is open while the cutaway wall collides"):
		return
	if not _expect(_ray(office, Vector3(0.0, 1.0, 5.6), Vector3(0.0, 1.0, 7.0)).get("collider") == structure, "short exit landing ends in a safe rail instead of open void"):
		return
	if not _expect(_ray(office, Vector3(0.0, 1.5, 0.0), Vector3(0.0, 6.0, 0.0)).is_empty(), "roofless room leaves the camera's overhead view clear"):
		return
	var drawer := office.get_node("FilingCabinet/Drawer") as Node3D
	var records := office.get_node("FilingCabinet/Drawer/RecordsBundle") as Node3D
	if not _expect(drawer.position.z == 0.0 and records.visible, "closed cabinet contains the records bundle"):
		return
	office.call("open_cabinet")
	await create_timer(0.5).timeout
	if not _expect(absf(drawer.position.z - 0.68) < 0.005, "drawer visibly extends into the room"):
		return
	office.call("open_cabinet")
	if not _expect(absf(drawer.position.z - 0.68) < 0.005, "opening the drawer twice is idempotent"):
		return
	office.call("close_cabinet")
	await create_timer(0.5).timeout
	if not _expect(not office.get("_drawer_open") and absf(drawer.position.z) < 0.005 and records.visible, "closing the cabinet retracts the drawer and leaves uncollected records inside"):
		return
	office.call("close_cabinet")
	if not _expect(absf(drawer.position.z) < 0.005, "closing the drawer twice is idempotent"):
		return
	office.call("open_cabinet")
	await create_timer(0.18).timeout
	office.call("close_cabinet")
	await create_timer(0.5).timeout
	if not _expect(not office.get("_drawer_open") and absf(drawer.position.z) < 0.005, "closing during the opening tween returns the drawer fully home"):
		return
	office.call("open_cabinet")
	await create_timer(0.5).timeout
	office.call("set_records_collected", true)
	if not _expect(not records.visible, "collected records disappear from the open drawer"):
		return
	office.call("set_records_collected", false)
	if not _expect(records.visible, "restoring uncollected state shows the records"):
		return
	print("Records office collision, cutaway, entry/exit, drawer open/close and collection checks passed")
	quit(0)
