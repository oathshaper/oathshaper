extends SceneTree
const MOUNT := preload("res://scripts/equipment_mount.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	var skeleton := Skeleton3D.new()
	skeleton.add_bone("Hand")
	skeleton.set_bone_pose_position(0, Vector3(1, 2, 3))
	root.add_child(skeleton)
	var hand := preload("res://scripts/hand_attachment.gd").new()
	hand.bone_name = "Hand"
	skeleton.add_child(hand)
	check(hand.position.is_equal_approx(Vector3(1, 2, 3)), "Equipment follows the initial hand pose")
	skeleton.set_bone_pose_position(0, Vector3(3, 2, 1))
	await process_frame
	await process_frame
	check(hand.position.is_equal_approx(Vector3(3, 2, 1)), "Equipment follows skeleton updates")
	skeleton.remove_child(hand)
	check(skeleton.get_signal_connection_list("skeleton_updated").is_empty(), "Detached equipment leaves no callback")
	skeleton.add_child(hand)
	check(skeleton.get_signal_connection_list("skeleton_updated").size() == 1, "Reattached equipment has exactly one callback")
	skeleton.free()
	# A source mesh whose handle is deliberately far from its origin catches
	# center-of-mesh attachment and double-scale regressions.
	var source := Node3D.new()
	source.name = "OffsetWeapon"
	for data in [["PrimaryGrip", Vector3(1, 0, 0)], ["SupportGrip", Vector3(1, 0, .4)]]:
		var socket := Marker3D.new()
		socket.name = data[0]
		socket.position = data[1]
		source.add_child(socket)
		socket.owner = source
	var packed := PackedScene.new()
	packed.pack(source)
	ResourceSaver.save(packed, "user://equipment-mount-fixture.tscn")
	source.free()
	var original := MOUNT.definition("staff").duplicate(true)
	MOUNT._data.weapons.staff.scene = "user://equipment-mount-fixture.tscn"
	for scale_value in [1.0, 2.0]:
		var rig := Node3D.new()
		rig.scale = Vector3.ONE * scale_value
		root.add_child(rig)
		var container := Node3D.new()
		rig.add_child(container)
		var result := MOUNT.mount(container, "staff", scale_value)
		check(result.imported, "Socket-equipped scene mounts")
		var grip := container.find_child("PrimaryGrip", true, false) as Node3D
		var support := container.find_child("SupportGrip", true, false) as Node3D
		check(grip.global_position.distance_to(Vector3(0, .035 * scale_value, 0)) < .0001, "Primary grip meets palm at both character scales")
		check(absf(grip.global_position.distance_to(support.global_position) - .4) < .0001, "Asset stays in meters across character scale")
		check((rig.global_transform * result.support).distance_to(support.global_position) < .0001, "Arm IK target is the actual support socket")
		rig.free()
	MOUNT._data.weapons.staff = original
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://equipment-mount-fixture.tscn"))
	print("EQUIPMENT_MOUNTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
