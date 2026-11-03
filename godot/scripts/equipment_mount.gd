extends RefCounted
## One attachment contract for party and adversary rigs. Imported assets are in
## meters and carry named sockets; the existing procedural art uses rig units.
const DATA := "res://content/equipment_mounts.json"
static var _data: Dictionary = {}

static func definition(kind: String) -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return _data.weapons.get(kind, {})

static func vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

static func socket_transform(asset: Node3D, socket: Node3D) -> Transform3D:
	var result := socket.transform
	var parent := socket.get_parent()
	while parent != asset and parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

static func palm_frame(skeleton: Skeleton3D, side: String) -> Dictionary:
	# Provider finger landmarks define an actual palm frame. The old 19-bone
	# stand-ins have no fingers and retain their authored attachment transform.
	var prefix := "mixamorig_" + ("Right" if side == "R" else "Left") + "Hand"
	var hand := skeleton.find_bone(side + "Hand")
	var index := skeleton.find_bone(prefix + "Index1")
	var pinky := skeleton.find_bone(prefix + "Pinky1")
	if hand < 0 or index < 0 or pinky < 0: return {}
	var inverse := skeleton.get_bone_global_rest(hand).affine_inverse()
	var index_at: Vector3 = inverse * skeleton.get_bone_global_rest(index).origin
	var pinky_at: Vector3 = inverse * skeleton.get_bone_global_rest(pinky).origin
	var across := (index_at - pinky_at).normalized()
	var along := ((index_at + pinky_at) * .5).normalized()
	var normal := along.cross(across).normalized()
	var basis := Basis(normal, across.cross(normal).normalized(), across)
	return {"basis": basis, "position": (index_at + pinky_at) * .42}

static func mount(container: Node3D, kind: String, rig_scale: float, palm: Dictionary = {}) -> Dictionary:
	var spec := definition(kind)
	if spec.is_empty(): return {"imported": false, "support": Vector3.ZERO}
	var hand := Transform3D(Basis.from_euler(vector(spec.mount_rotation_degrees) * PI / 180.0), vector(spec.mount_position))
	if not palm.is_empty() and not str(spec.scene).is_empty():
		hand = Transform3D(palm.basis, palm.position)
		if kind == "buckler":
			# A shield faces along the knuckles; a shaft exits at the thumb.
			hand.basis = Basis(palm.basis.z, palm.basis.x, palm.basis.y)
	if kind == "sabre":
		# Blade edge and knuckle guard follow the fingers, not the palm normal.
		hand.basis *= Basis(Vector3.FORWARD, PI / 2)
	container.transform = hand
	var scene_path: String = spec.scene
	if not scene_path.is_empty():
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("Equipment scene cannot be loaded: " + scene_path)
			return {"imported": false, "support": Vector3.ZERO}
		var asset := packed.instantiate() as Node3D
		asset.transform = Transform3D.IDENTITY
		var grip := asset.find_child("PrimaryGrip", true, false) as Node3D
		var support := asset.find_child("SupportGrip", true, false) as Node3D
		if grip == null or (kind in ["staff", "crossbow"] and support == null):
			asset.free()
			push_error("Equipment requires PrimaryGrip and two-handed equipment requires SupportGrip: " + scene_path)
			return {"imported": false, "support": Vector3.ZERO}
		container.transform = hand * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE / maxf(rig_scale, .001)), Vector3.ZERO) * socket_transform(asset, grip).affine_inverse()
		container.add_child(asset)
		return {"imported": true, "support": container.transform * socket_transform(asset, support).origin if support != null else Vector3.ZERO}
	# Named fallback sockets make replacement and visual inspection possible now.
	# Those authored primitives use the legacy 2x rig-unit convention.
	container.transform = hand * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0 / maxf(rig_scale, .001)), Vector3.ZERO)
	for name in spec.sockets:
		var marker := Marker3D.new()
		marker.name = name
		marker.position = vector(spec.sockets[name])
		container.add_child(marker)
	return {"imported": false, "support": container.transform * vector(spec.sockets.get("SupportGrip", [0, 0, 0]))}
