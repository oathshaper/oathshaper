extends Node3D
## Visual-only hand follower. The pinned Linux release reproduced a native
## BoneAttachment3D unbind error; use an explicit script callable here.
var bone_name := ""
var _skeleton: Skeleton3D
var _bone := -1

func _enter_tree() -> void:
	_skeleton = get_parent() as Skeleton3D
	if _skeleton == null:
		push_error("Hand attachment requires a Skeleton3D parent.")
		return
	_bone = _skeleton.find_bone(bone_name)
	if _bone < 0:
		push_error("Hand attachment bone is missing: " + bone_name)
		return
	_skeleton.skeleton_updated.connect(_follow_hand)
	_follow_hand()

func _follow_hand() -> void:
	transform = _skeleton.get_bone_global_pose(_bone)

func _exit_tree() -> void:
	if is_instance_valid(_skeleton) and _skeleton.skeleton_updated.is_connected(_follow_hand):
		_skeleton.skeleton_updated.disconnect(_follow_hand)
	_skeleton = null
	_bone = -1
