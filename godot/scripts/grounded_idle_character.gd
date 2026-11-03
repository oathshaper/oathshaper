extends Node3D
## Presentation-only grounding for an upright, unrigged imported character.
## Collision and conversation ownership stay on the scene's character root.

@export var model_slot: NodePath = ^"ModelSlot"
@export var collider_path: NodePath = ^"Collider/CollisionShape3D"
@export var breath_amount := 0.001
@export var idle_yaw_degrees := 0.0

var _model: Node3D
var _rest_position := Vector3.ZERO
var _rest_scale := Vector3.ONE
var _rest_rotation_y := 0.0
var _mesh_bottom_local := 0.0
var _elapsed := 0.0
var _use_procedural_idle := true


func _ready() -> void:
	# The floor body is created by the hub before this scene node. Wait for its
	# collision shapes to enter the physics world before finding the surface.
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var floor_y := _floor_height()
	if not is_finite(floor_y):
		push_warning("No floor below %s; keeping authored character placement." % name)
		return
	_align_collider(floor_y)
	var slot := get_node_or_null(model_slot) as Node3D
	if slot != null:
		_model = slot.get_node_or_null("ImportedModel") as Node3D
		_use_procedural_idle = slot.call("motion_mode") != "rigged"
	if _model != null:
		_mesh_bottom_local = _model_mesh_bottom()
		if is_finite(_mesh_bottom_local):
			_model.position.y += floor_y - _world_mesh_bottom()
			_rest_position = _model.position
			_rest_scale = _model.scale
			_rest_rotation_y = _model.rotation.y
		else:
			_model = null
	_add_contact_shadow(floor_y)


func _process(delta: float) -> void:
	if _model == null or not _use_procedural_idle:
		return
	_elapsed += delta
	# Stretch and counter-translate from the lowest mesh point. This gives a
	# faint breath while the feet remain at exactly the same floor height.
	var new_scale_y := _rest_scale.y * (1.0 + breath_amount * sin(_elapsed * TAU / 4.5))
	_model.scale.y = new_scale_y
	_model.position.y = _rest_position.y + (_rest_scale.y - new_scale_y) * _mesh_bottom_local
	_model.rotation.y = _rest_rotation_y + deg_to_rad(idle_yaw_degrees) * sin(_elapsed * 0.8)


func _floor_height() -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 2.0, global_position + Vector3.DOWN * 4.0)
	var collider := get_node_or_null(collider_path) as CollisionShape3D
	if collider != null and collider.get_parent() is CollisionObject3D:
		query.exclude = [(collider.get_parent() as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else NAN


func _align_collider(floor_y: float) -> void:
	var collider := get_node_or_null(collider_path) as CollisionShape3D
	if collider == null or not collider.shape is CapsuleShape3D:
		return
	var capsule := collider.shape as CapsuleShape3D
	var bottom_y := collider.global_position.y - capsule.height * 0.5
	global_position.y += floor_y - bottom_y


func _model_mesh_bottom() -> float:
	var bottom := INF
	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	if _model is MeshInstance3D:
		meshes.push_front(_model)
	for child in meshes:
		var visual := child as MeshInstance3D
		if visual.mesh == null:
			continue
		var bounds := visual.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					bottom = minf(bottom, _model.to_local(visual.to_global(Vector3(x, y, z))).y)
	return bottom


func _world_mesh_bottom() -> float:
	return _model.to_global(Vector3(0.0, _mesh_bottom_local, 0.0)).y


func _add_contact_shadow(floor_y: float) -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := Vector2((x + 0.5) / 32.0 - 1.0, (y + 0.5) / 32.0 - 1.0).length()
			var opacity := pow(maxf(0.0, 1.0 - radius), 1.6) * 0.45
			image.set_pixel(x, y, Color(0.05, 0.07, 0.08, opacity))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.3, 0.85)
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = plane
	shadow.material_override = material
	shadow.position = to_local(Vector3(global_position.x, floor_y + 0.008, global_position.z))
	add_child(shadow)
