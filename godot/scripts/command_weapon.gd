extends Node3D
const MOUNT := preload("res://scripts/equipment_mount.gd")
const HAND := preload("res://scripts/hand_attachment.gd")
## Original equipment presentation. Bone poses/flash never resolve attacks or change inventory.
class CommandPose:
	extends "res://scripts/combat_pose.gd"
	var offhand_kind := ""
	var support_target := Vector3.ZERO
	var support_error := 0.0
	var ability_id := "basic"
	func strike_duration() -> float:
		return 1.2 if ability_id == "shield_bash" else DURATION
	func _process_modification() -> void:
		if _blend <= 0.0:
			return
		var phase := clampf(strike_time / strike_duration(), 0.0, 1.0)
		var swing := sin(phase * PI) if strike_time >= 0.0 else 0.0
		if kind in ["staff", "crossbow"] or (ability_id == "shield_bash" and strike_time >= 0):
			_prepare_guard()
		if ability_id == "shield_bash" and offhand_kind == "buckler" and strike_time >= 0:
			_rotate("RUpperArm", Vector3(18, 0, 0))
			_rotate("RForearm", Vector3(50, 0, 0))
			_shield_guard(swing)
			_rotate("Chest", Vector3(0, -swing * 12, 0))
			_close_fingers("R")
			_close_fingers("L")
			return
		if kind == "crossbow":
			_rotate("RUpperArm", Vector3(49 - swing * 8, -3, 0))
			_rotate("RForearm", Vector3(38, 0, 0))
			_rotate("LUpperArm", Vector3(44, -8, 15))
			_rotate("LForearm", Vector3(56, 0, -15))
			_rotate("Chest", Vector3(0, -4, 0))
		elif kind == "staff":
			_rotate("RUpperArm", Vector3(23 + swing * 28, -12 + swing * 18, -14))
			_rotate("RForearm", Vector3(48 - swing * 17, 0, 0))
			_rotate("RHand", Vector3(-swing * 30, 0, 0))
			_rotate("LUpperArm", Vector3(27 + swing * 18, 9, 19))
			_rotate("LForearm", Vector3(49 - swing * 12, -8, -14))
			_rotate("Chest", Vector3(0, swing * 15, 0))
		else:
			super._process_modification()
		if kind in ["staff", "crossbow"]:
			_support_hand()
			_close_fingers("R")
			_close_fingers("L")
		if offhand_kind == "buckler" and kind not in ["staff", "crossbow"]:
			_shield_guard()
			_close_fingers("L")

	func _shield_guard(push := 0.0) -> void:
		# The wrist sits in front of a bent elbow. Align the buckler's outward
		# normal to the forearm, rather than correcting an arbitrary hand roll.
		var skeleton := get_skeleton()
		var shoulder := skeleton.find_bone("LUpperArm")
		var wrist := skeleton.find_bone("LHand")
		var elbow := skeleton.find_bone("LForearm")
		var palm := MOUNT.palm_frame(skeleton, "L")
		var grip: Vector3 = palm.get("position", Vector3(0, .035, 0))
		var mount_basis: Basis = Basis(palm.basis.z, palm.basis.x, palm.basis.y) if not palm.is_empty() else Basis.from_euler(Vector3(PI, 0, 0))
		var reach := skeleton.get_bone_global_rest(shoulder).origin.distance_to(skeleton.get_bone_global_rest(elbow).origin) + skeleton.get_bone_global_rest(elbow).origin.distance_to(skeleton.get_bone_global_rest(wrist).origin)
		var target := skeleton.get_bone_global_pose(shoulder).origin + Vector3(-.015, -.12 + .03 * push, .14 + .08 * push) * (reach / .22)
		for iteration in 2:
			var basis := skeleton.get_bone_global_pose(wrist).basis
			_reach_hand("L", target - basis * grip, Vector3(.15, -1, 0))
			var direction := (skeleton.get_bone_global_pose(wrist).origin - skeleton.get_bone_global_pose(elbow).origin).normalized()
			basis = skeleton.get_bone_global_pose(wrist).basis
			_set_global_basis(wrist, Basis(Quaternion((basis * mount_basis.z).normalized(), direction)) * basis)

	func _support_hand() -> void:
		var skeleton := get_skeleton()
		var right := skeleton.find_bone("RHand")
		var left := skeleton.find_bone("LHand")
		var shoulder := skeleton.find_bone("LUpperArm")
		if right < 0 or left < 0 or shoulder < 0: return
		var original := skeleton.get_bone_global_pose(right)
		var right_palm := MOUNT.palm_frame(skeleton, "R")
		var grip: Vector3 = right_palm.get("position", Vector3(0, .035, 0))
		if kind == "staff":
			# Diagonal two-handed guard: lower hand at the waist, upper hand
			# across the chest. Keep the shaft outside the coat and face.
			var mounted: Basis = right_palm.get("basis", Basis.from_euler(Vector3(PI, 0, 0)))
			var swing := sin(clampf(strike_time / DURATION, 0.0, 1.0) * PI) if strike_time >= 0.0 else 0.0
			var direction := Vector3(.72 - .5 * swing, .68 - .5 * swing, .10 + .8 * swing).normalized()
			var basis := Basis(Quaternion((original.basis * mounted.z).normalized(), direction)) * original.basis
			var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
			var palm_target := hips + Vector3(-.10, .10 + .03 * swing, .18 + .10 * swing)
			_reach_hand("R", palm_target - basis * grip)
			_set_global_basis(right, basis)
		else:
			var centered := original.origin.lerp(skeleton.get_bone_global_pose(shoulder).origin, .45)
			_reach_hand("R", centered)
			_set_global_basis(right, original.basis)
		var target: Vector3 = skeleton.get_bone_global_pose(right) * support_target
		var palm: Vector3 = MOUNT.palm_frame(skeleton, "L").get("position", Vector3(0, .035, 0))
		var basis := skeleton.get_bone_global_pose(left).basis
		_reach_hand("L", target - basis * palm)
		_set_global_basis(left, basis)
		support_error = (skeleton.get_bone_global_pose(left) * palm).distance_to(target)

	func _set_global_basis(bone: int, basis: Basis) -> void:
		var skeleton := get_skeleton()
		var parent := skeleton.get_bone_parent(bone)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(bone, (parent_basis.inverse() * basis).get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()

	func _reach_hand(side: String, target: Vector3, pole_hint := Vector3.ZERO) -> void:
		# Analytic two-bone reach with an outward/downward elbow pole. The old
		# unconstrained CCD could flip the elbow when the staff crossed the body.
		var skeleton := get_skeleton()
		var upper := skeleton.find_bone(side + "UpperArm")
		var forearm := skeleton.find_bone(side + "Forearm")
		var hand := skeleton.find_bone(side + "Hand")
		if upper < 0 or forearm < 0 or hand < 0: return
		var shoulder := skeleton.get_bone_global_pose(upper).origin
		var elbow := skeleton.get_bone_global_pose(forearm).origin
		var wrist := skeleton.get_bone_global_pose(hand).origin
		var a := shoulder.distance_to(elbow)
		var b := elbow.distance_to(wrist)
		var distance := clampf(shoulder.distance_to(target), absf(a - b) + .001, (a + b) * .995)
		var direction := (target - shoulder).normalized()
		var pole := pole_hint if pole_hint != Vector3.ZERO else Vector3(signf(shoulder.x), -.8, .15)
		var bend := (pole - direction * pole.dot(direction)).normalized()
		if bend.length_squared() < .01: bend = Vector3.UP.cross(direction).normalized()
		var along := (a * a + distance * distance - b * b) / (2.0 * distance)
		var elbow_target := shoulder + direction * along + bend * sqrt(maxf(0, a * a - along * along))
		var upper_turn := Quaternion((elbow - shoulder).normalized(), (elbow_target - shoulder).normalized())
		_set_global_basis(upper, Basis(upper_turn) * skeleton.get_bone_global_pose(upper).basis)
		elbow = skeleton.get_bone_global_pose(forearm).origin
		wrist = skeleton.get_bone_global_pose(hand).origin
		var reachable := shoulder + direction * distance
		var lower_turn := Quaternion((wrist - elbow).normalized(), (reachable - elbow).normalized())
		_set_global_basis(forearm, Basis(lower_turn) * skeleton.get_bone_global_pose(forearm).basis)

var pose: SkeletonModifier3D
var grip: Node3D
var visual: Node3D
var offhand_grip: Node3D
var offhand_visual: Node3D
var flash: MeshInstance3D
var kind := "sabre"
var offhand_kind := ""
var _readied := false
var _owned_skeleton: Skeleton3D
var _bronze: StandardMaterial3D
var _steel: StandardMaterial3D
var _dark: StandardMaterial3D
var _wood: StandardMaterial3D
var _glow: StandardMaterial3D

func _ready() -> void:
	_materials()
	var slot := get_parent().get_node_or_null("ModelSlot")
	if slot == null:
		slot = get_parent().get_node_or_null("Art")
	if slot == null:
		push_warning("CommandWeapon requires a sibling ModelSlot with a rigged skeleton.")
		return
	var skeletons := slot.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_owned_skeleton = skeletons[0] as Skeleton3D
	if _owned_skeleton.find_bone("RHand") < 0 or _owned_skeleton.find_bone("LHand") < 0:
		push_warning("CommandWeapon requires RHand and LHand bones.")
		return
	pose = CommandPose.new()
	pose.name = "CommandEquipmentPose"
	_owned_skeleton.add_child(pose)
	grip = HAND.new()
	grip.name = "CommandRightGrip"
	grip.bone_name = "RHand"
	_owned_skeleton.add_child(grip)
	visual = Node3D.new()
	grip.add_child(visual)
	offhand_grip = HAND.new()
	offhand_grip.name = "CommandLeftGrip"
	offhand_grip.bone_name = "LHand"
	_owned_skeleton.add_child(offhand_grip)
	offhand_visual = Node3D.new()
	offhand_grip.add_child(offhand_visual)
	configure(kind, offhand_kind)

func _exit_tree() -> void:
	# Attachments are children of the imported skeleton, not of this component.
	for node in [grip, offhand_grip, pose]:
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.queue_free()

func _material(color: String, metal := 0.0, roughness := 0.65) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metal
	material.roughness = roughness
	return material

func _materials() -> void:
	_bronze = _material("b49a61", 0.76, 0.33)
	_steel = _material("b9d0d1", 0.85, 0.24)
	_dark = _material("293c3f", 0.65, 0.5)
	_wood = _material("b4a18b", 0.0, 0.78)
	_wood.albedo_texture = load("res://assets/textures/materials/weathered_timber_albedo.png")
	_glow = _material("80c7bc", 0.25, 0.24)
	_glow.emission_enabled = true
	_glow.emission = Color("77c5b6")
	_glow.emission_energy_multiplier = 0.8

func _part(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _ellipsoid(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 20
	sphere.rings = 12
	var part := _part(parent, sphere, at, material)
	part.scale = dimensions
	return part

func _rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material, tip_radius := -1.0) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius if tip_radius < 0 else tip_radius
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 16
	var part := _part(parent, cylinder, (from + to) * 0.5, material)
	part.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return part

func _ring(parent: Node3D, at: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 24
	torus.ring_segments = 8
	var part := _part(parent, torus, at, material)
	part.rotation.x = PI * 0.5
	return part

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func configure(main_kind: String, secondary_kind: String = "") -> void:
	kind = main_kind.to_lower()
	offhand_kind = secondary_kind.to_lower()
	if visual == null:
		return
	_clear(visual)
	_clear(offhand_visual)
	flash = null
	pose.kind = kind
	pose.offhand_kind = offhand_kind
	var mounted := MOUNT.mount(visual, kind, _owned_skeleton.global_basis.get_scale().x, MOUNT.palm_frame(_owned_skeleton, "R"))
	# Two-handed bindings occupy both slots, but refer to one physical weapon.
	var secondary_mesh := "" if kind in ["staff", "crossbow"] and offhand_kind == kind else offhand_kind
	var offhand := MOUNT.mount(offhand_visual, secondary_mesh, _owned_skeleton.global_basis.get_scale().x, MOUNT.palm_frame(_owned_skeleton, "L"))
	pose.support_target = mounted.support
	if mounted.imported:
		if offhand_kind == "buckler" and not offhand.imported: _buckler(offhand_visual)
		set_readied(_readied)
		return
	match kind:
		"sabre": _sabre(visual)
		"staff": _staff(visual)
		"mace": _mace(visual)
		"crossbow": _crossbow(visual)
		"buckler": _buckler(visual)
		"unarmed", "": pass
		_: push_warning("Unknown Command weapon presentation: " + kind)
	if offhand_kind == "buckler" and not offhand.imported:
		_buckler(offhand_visual)
	set_readied(_readied)

func set_readied(value: bool) -> void:
	_readied = value
	if pose == null:
		return
	pose.readied = value
	pose._blend = 1.0 if value else 0.0
	if not value:
		pose.sheathe()
	visual.visible = value and visual.get_child_count() > 0
	offhand_visual.visible = value and offhand_visual.get_child_count() > 0

func strike() -> bool:
	if pose == null or not pose.strike():
		return false
	set_readied(true)
	return true

func _process(_delta: float) -> void:
	if is_instance_valid(flash) and pose != null:
		flash.visible = pose.readied and pose.strike_time >= 0.0 and pose.strike_time < 0.10

func _sabre(parent: Node3D) -> void:
	_rod(parent, Vector3(0, 0, -0.055), Vector3(0, 0, 0.055), 0.018, _dark)
	_ellipsoid(parent, Vector3(0, 0, -0.065), Vector3(.045, .035, .035), _bronze)
	_rod(parent, Vector3(-.075, 0, .065), Vector3(.075, 0, .065), .012, _bronze)
	# Curved diamond-section blade: original vertices with planar UVs, not a box blade.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers := [Vector3(0, 0, .075), Vector3(.005, 0, .26), Vector3(.026, 0, .43), Vector3(.043, 0, .49)]
	var widths := [.019, .017, .011, .001]
	for index in range(centers.size() - 1):
		var a: Vector3 = centers[index]
		var b: Vector3 = centers[index + 1]
		var ring_a := [a + Vector3(-widths[index], 0, 0), a + Vector3(0, .006, 0), a + Vector3(widths[index], 0, 0), a + Vector3(0, -.006, 0)]
		var ring_b := [b + Vector3(-widths[index + 1], 0, 0), b + Vector3(0, .004, 0), b + Vector3(widths[index + 1], 0, 0), b + Vector3(0, -.004, 0)]
		for face in range(4):
			var next := (face + 1) % 4
			for point in [ring_a[face], ring_b[face], ring_b[next], ring_a[face], ring_b[next], ring_a[next]]:
				tool.set_uv(Vector2(point.x * 10.0, point.z * 2.0))
				tool.add_vertex(point)
	tool.generate_normals()
	_part(parent, tool.commit(), Vector3.ZERO, _steel)
	_rod(parent, Vector3(-.062, 0, .065), Vector3(-.044, -.025, -.055), .007, _bronze)

func _buckler(parent: Node3D) -> void:
	_ellipsoid(parent, Vector3(0, 0, .045), Vector3(.31, .31, .055), _dark)
	_ring(parent, Vector3(0, 0, .065), .14, .157, _bronze)
	_ellipsoid(parent, Vector3(0, 0, .080), Vector3(.10, .10, .065), _bronze)
	for index in range(8):
		var angle := TAU * index / 8.0
		_ellipsoid(parent, Vector3(cos(angle) * .125, sin(angle) * .125, .075), Vector3.ONE * .014, _steel)
	_rod(parent, Vector3(-.10, 0, .07), Vector3(.10, 0, .07), .007, _bronze)
	_rod(parent, Vector3(0, -.10, .07), Vector3(0, .10, .07), .007, _bronze)

func _staff(parent: Node3D) -> void:
	_rod(parent, Vector3(0, 0, -.39), Vector3(0, 0, .48), .016, _wood)
	for z in [-.37, -.09, .09, .43]:
		_rod(parent, Vector3(0, 0, z - .018), Vector3(0, 0, z + .018), .022, _bronze)
	_rod(parent, Vector3(0, 0, -.43), Vector3(0, 0, -.38), .022, _dark, .013)
	_ring(parent, Vector3(0, 0, .49), .040, .052, _bronze)
	_ellipsoid(parent, Vector3(0, 0, .50), Vector3(.045, .045, .10), _glow)
	for side in [-1, 1]:
		_rod(parent, Vector3(side * .025, 0, .43), Vector3(side * .035, 0, .54), .009, _bronze, .004)

func _mace(parent: Node3D) -> void:
	_rod(parent, Vector3(0, 0, -.04), Vector3(0, 0, .27), .018, _wood)
	_rod(parent, Vector3(0, 0, -.04), Vector3(0, 0, .07), .024, _dark)
	_ellipsoid(parent, Vector3(0, 0, -.045), Vector3(.05, .05, .04), _bronze)
	_ellipsoid(parent, Vector3(0, 0, .31), Vector3(.11, .11, .16), _bronze)
	for index in range(6):
		var angle := index * TAU / 6.0
		var at := Vector3(cos(angle) * .045, sin(angle) * .045, .31)
		var flange := _ellipsoid(parent, at, Vector3(.045, .022, .17), _steel)
		flange.rotation.z = angle
	_ellipsoid(parent, Vector3(0, 0, .40), Vector3(.045, .045, .04), _bronze)

func _crossbow(parent: Node3D) -> void:
	_ellipsoid(parent, Vector3(0, .01, -.04), Vector3(.065, .075, .28), _wood)
	_rod(parent, Vector3(0, .025, -.04), Vector3(0, .025, .32), .023, _dark)
	_rod(parent, Vector3(0, .053, .04), Vector3(0, .053, .36), .006, _steel)
	_ellipsoid(parent, Vector3(0, -.035, .04), Vector3(.055, .11, .065), _wood)
	for side in [-1, 1]:
		var inner := Vector3(side * .04, 0, .26)
		var middle := Vector3(side * .14, 0, .23)
		var outer := Vector3(side * .24, .015, .18)
		_rod(parent, inner, middle, .015, _bronze)
		_rod(parent, middle, outer, .012, _dark, .007)
		_rod(parent, outer, Vector3(0, .035, .04), .0025, _steel)
		_ring(parent, Vector3(side * .04, 0, .26), .010, .018, _steel)
	flash = _ellipsoid(parent, Vector3(0, .053, .37), Vector3(.025, .025, .08), _glow)
	flash.hide()
