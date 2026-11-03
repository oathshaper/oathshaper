extends SkeletonModifier3D
## Additive upper-body practice poses, applied after the authored locomotion clip.
## This modifies presentation only; it never resolves hits or spends resources.
var readied := false
var kind := "sabre"
var strike_time := -1.0
var strike_count := 0
var _blend := 0.0
var _guard_rotations: Dictionary = {}
var _guard_loaded := false
const DURATION := 0.65

func strike_duration() -> float:
	return DURATION

func strike() -> bool:
	if strike_time >= 0.0:
		return false
	readied = true
	strike_time = 0.0
	strike_count += 1
	return true

func sheathe() -> void:
	readied = false
	strike_time = -1.0

func _process(delta: float) -> void:
	_blend = move_toward(_blend, 1.0 if readied else 0.0, delta * 7.0)
	if strike_time >= 0.0:
		strike_time += delta
		if strike_time >= strike_duration():
			strike_time = -1.0

func _rotate(bone: String, angles: Vector3) -> void:
	var skeleton := get_skeleton()
	var index := skeleton.find_bone(bone)
	if index >= 0:
		# Imported bones have different rolls. Use skeleton-space axes so both
		# elbows bend forward instead of turning a local-X rotation into abduction.
		var rotation := Basis.from_euler(Vector3(-angles.x, angles.y, angles.z) * PI / 180.0 * _blend)
		var global_basis := rotation * skeleton.get_bone_global_pose(index).basis
		var parent := skeleton.get_bone_parent(index)
		var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * global_basis).get_rotation_quaternion())

func _prepare_guard() -> void:
	# Keep authored hip/leg locomotion, but hold the arms in their standing
	# pose before applying guard/strike. Adding a guard to a running arm swing
	# made the shield, sword and supporting hand flap on every step.
	var skeleton := get_skeleton()
	if not _guard_loaded:
		_guard_loaded = true
		var ancestor: Node = skeleton
		while ancestor != null:
			var players := ancestor.find_children("*", "AnimationPlayer", true, false)
			if not players.is_empty():
				var player := players[0] as AnimationPlayer
				if player.has_animation("Idle"):
					var idle := player.get_animation("Idle")
					for track in idle.get_track_count():
						if idle.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
						var path := idle.track_get_path(track)
						if path.get_subname_count() == 0: continue
						var bone := str(path.get_subname(path.get_subname_count() - 1))
						if bone in ["RClavicle", "LClavicle", "RUpperArm", "LUpperArm", "RForearm", "LForearm", "RHand", "LHand"]:
							_guard_rotations[bone] = idle.rotation_track_interpolate(track, 0.0)
				break
			ancestor = ancestor.get_parent()
	for bone in _guard_rotations:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(_guard_rotations[bone], _blend))

func _close_fingers(side: String) -> void:
	var skeleton := get_skeleton()
	var palm := preload("res://scripts/equipment_mount.gd").palm_frame(skeleton, side)
	if palm.is_empty(): return
	var hand := skeleton.find_bone(side + "Hand")
	var axis: Vector3 = (skeleton.get_bone_global_pose(hand).basis * palm.basis.z).normalized()
	var prefix := "mixamorig_" + ("Right" if side == "R" else "Left") + "Hand"
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in [1, 2, 3]:
			var index := skeleton.find_bone(prefix + finger + str(joint))
			if index < 0: continue
			var degrees: float = [55.0, 75.0, 40.0][joint - 1] * (1 if side == "R" else -1)
			var basis := Basis(Quaternion(axis, deg_to_rad(degrees) * _blend)) * skeleton.get_bone_global_pose(index).basis
			var parent := skeleton.get_bone_parent(index)
			skeleton.set_bone_pose_rotation(index, (skeleton.get_bone_global_pose(parent).basis.inverse() * basis).get_rotation_quaternion())

func _process_modification() -> void:
	if _blend <= 0.0:
		return
	_prepare_guard()
	var phase := clampf(strike_time / DURATION, 0.0, 1.0)
	var swing := sin(phase * PI) if strike_time >= 0.0 else 0.0
	match kind:
		"carbine":
			_rotate("RUpperArm", Vector3(48 - swing * 12, 0, 0))
			_rotate("RForearm", Vector3(35, 0, 0))
			_rotate("LUpperArm", Vector3(38, 0, 12))
			_rotate("LForearm", Vector3(50, 0, -12))
		"unarmed":
			_rotate("RUpperArm", Vector3(38 + swing * 50, 0, 0))
			_rotate("RForearm", Vector3(75 - swing * 65, 0, 0))
			_rotate("LUpperArm", Vector3(38, 0, 0))
			_rotate("LForearm", Vector3(80, 0, 0))
		_:
			_rotate("RUpperArm", Vector3(18 + swing * 55, -swing * 20, -swing * 18))
			_rotate("RForearm", Vector3(50 - swing * 30, 0, 0))
			_rotate("RHand", Vector3(-95 * swing, 0, 0))
			_rotate("LForearm", Vector3(18, 0, 0))
	_rotate("Chest", Vector3(0, swing * 12, 0))
	if kind != "unarmed": _close_fingers("R")
