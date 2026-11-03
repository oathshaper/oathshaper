extends Node3D
## Optional imported character art. The parent keeps collision, interaction, and labels.

@export var model_path := ""
@export var rigged_model_path := ""
@export var require_rigged_walk := false
@export var placeholder_names: PackedStringArray = []
@export var model_offset := Vector3(0.0, -1.0, 0.0)
@export var model_scale := Vector3.ONE
@export var untextured_color := Color(0.55, 0.55, 0.52)
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var run_animation: StringName = &"Run"
@export var run_speed_threshold := 3.4
@export var run_cycle_distance := 2.8
@export var talk_animation: StringName = &"Talk"
@export_range(0.0, 5.0, 0.01) var walk_speed_threshold := 0.15
@export_range(0.2, 4.0, 0.05) var walk_cycle_distance := 1.8
@export var procedural_motion := true
@export var reverse_walk_on_backpedal := false
@export var randomize_standing_motion := true
## Zero uses a fresh seed per instance. Nonzero seeds support reproducible previews.
@export var standing_motion_seed := 0

var _animation_player: AnimationPlayer
var _idle_clip: StringName
var _walk_clip: StringName
var _run_clip: StringName
var _talk_clip: StringName
var _model: Node3D
var _motion_mode := "static"
var _active_model_path := ""
var _talking := false
## Used by scene-owned NPC routes; CharacterBody3D actors keep their real velocity.
var locomotion_speed := 0.0
var _rest_transform := Transform3D.IDENTITY
var _rest_rotation := Vector3.ZERO
var _rest_scale := Vector3.ONE
var _foot_anchor := Vector3.ZERO
var _elapsed := 0.0
var _stride_phase := 0.0
var _walk_mix := 0.0
var _standing_rng := RandomNumberGenerator.new()
var _standing_phase := 0.0
var _standing_rate := 1.0
var _standing_target_rate := 1.0
var _standing_retime_in := 0.0


func _ready() -> void:
	if randomize_standing_motion:
		if standing_motion_seed == 0:
			_standing_rng.randomize()
		else:
			_standing_rng.seed = standing_motion_seed
		_standing_phase = _standing_rng.randf()
		_standing_rate = _standing_rng.randf_range(0.9, 1.1)
		_standing_target_rate = _standing_rate
		_standing_retime_in = _standing_rng.randf_range(4.0, 9.0)
	var instance: Node3D
	for path in [rigged_model_path, model_path]:
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var resource: Resource = load(path)
		if not resource is PackedScene:
			push_warning("Character model must import as a PackedScene: " + path)
			continue
		var candidate := (resource as PackedScene).instantiate()
		if not candidate is Node3D:
			push_warning("Character model must have a Node3D root: " + path)
			candidate.queue_free()
			continue
		candidate.name = "ImportedModel"
		add_child(candidate)
		candidate.position = model_offset
		candidate.scale = model_scale
		if not _has_renderable_mesh(candidate):
			push_warning("Character model has no visible mesh; using primitive art: " + path)
			remove_child(candidate)
			candidate.queue_free()
			continue
		if path == rigged_model_path:
			_bind_rig_animations(candidate)
			if _animation_player == null or (require_rigged_walk and _walk_clip == &""):
				push_warning("Rigged character needs a weighted skin and required clips; using fallback: " + path)
				_animation_player = null
				_idle_clip = &""
				_walk_clip = &""
				_run_clip = &""
				_talk_clip = &""
				remove_child(candidate)
				candidate.queue_free()
				continue
		instance = candidate
		_active_model_path = path
		break
	if instance == null:
		return
	_rebuild_position_only_mesh_normals(instance)
	_tint_untextured_meshes(instance)
	if _animation_player == null:
		_bind_rig_animations(instance)
	if _animation_player != null:
		_motion_mode = "rigged"
		_load_locomotion_calibration()
	elif procedural_motion:
		# Unrigged exports get a modest presentation-only motion. Keep one foot
		# anchor fixed in the slot's local space while the mesh breathes or sways.
		_model = instance
		_rest_transform = instance.transform
		_rest_rotation = instance.rotation
		_rest_scale = instance.scale
		_foot_anchor.y = _mesh_bottom_local(instance)
		_motion_mode = "procedural"
	for placeholder_name in placeholder_names:
		var placeholder := get_parent().get_node_or_null(NodePath(placeholder_name))
		if placeholder is VisualInstance3D:
			placeholder.visible = false


func _load_locomotion_calibration() -> void:
	# A replacement rig carries its own measured stride; legacy NPC rigs keep
	# their Inspector values. Only presentation timing is read from this file.
	var path := _active_model_path.get_basename() + ".motion.json"
	if not FileAccess.file_exists(path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	walk_cycle_distance = maxf(.2, float(data.get("walk_cycle_distance", walk_cycle_distance)))
	run_cycle_distance = maxf(.2, float(data.get("run_cycle_distance", run_cycle_distance)))
	run_speed_threshold = maxf(walk_speed_threshold, float(data.get("run_speed_threshold", run_speed_threshold)))


func _process(delta: float) -> void:
	var character := get_parent() as CharacterBody3D
	var speed := Vector2(character.velocity.x, character.velocity.z).length() if character != null else locomotion_speed
	var moving := speed > walk_speed_threshold
	if _animation_player != null:
		# Backpedaling keeps a walk gait, even when reverse input is fast.
		var reverse := reverse_walk_on_backpedal and character != null and bool(character.get("backpedaling"))
		var run_threshold := run_speed_threshold - .25 if _animation_player.current_animation == _run_clip else run_speed_threshold
		var gait := _run_clip if speed >= run_threshold and _run_clip != &"" and not reverse else _walk_clip
		var wanted := _talk_clip if _talking and _talk_clip != &"" else (gait if moving and gait != &"" else _idle_clip)
		var standing := wanted == _idle_clip or wanted == _talk_clip
		if standing and randomize_standing_motion:
			_standing_retime_in -= delta
			if _standing_retime_in <= 0.0:
				_standing_target_rate = _standing_rng.randf_range(0.9, 1.1)
				_standing_retime_in = _standing_rng.randf_range(4.0, 9.0)
			_standing_rate = move_toward(_standing_rate, _standing_target_rate, delta * 0.02)
		var cycle_distance := run_cycle_distance if wanted == _run_clip else walk_cycle_distance
		var playback_rate := _standing_rate if standing else clampf(speed * _animation_player.get_animation(wanted).length / cycle_distance, 0.05, 4.0)
		# The actor keeps facing forward when S or the left stick pulls back.
		# Reversing the in-place gait makes that travel read as a backpedal.
		var backpedaling := not standing and reverse
		_animation_player.speed_scale = -playback_rate if backpedaling else playback_rate
		if wanted != &"" and (not _animation_player.is_playing() or _animation_player.current_animation != wanted):
			# Preserve the body phase across Idle/Talk; entering conversation must
			# not restart everyone's sway at the same neutral pose.
			var previous := _animation_player.current_animation
			var gait_change := previous != &"" and previous in [_walk_clip, _run_clip] and wanted in [_walk_clip, _run_clip]
			var gait_phase := _animation_player.current_animation_position / _animation_player.get_animation(previous).length if gait_change else 0.0
			if previous != &"" and (previous == _idle_clip or previous == _talk_clip):
				_standing_phase = fposmod(_animation_player.current_animation_position / _animation_player.get_animation(previous).length, 1.0)
			_animation_player.play(wanted, .16)
			if gait_change:
				_animation_player.seek(gait_phase * _animation_player.get_animation(wanted).length, true)
			if standing and randomize_standing_motion:
				_animation_player.seek(_standing_phase * _animation_player.get_animation(wanted).length, true)
	elif _motion_mode == "procedural":
		_advance_procedural(delta, speed, moving)


func motion_mode() -> String:
	return _motion_mode


func active_model_path() -> String:
	return _active_model_path


func set_talking(active: bool) -> void:
	_talking = active
	_process(0.0)


func _advance_procedural(delta: float, speed: float, moving: bool) -> void:
	if _model == null:
		return
	_elapsed += delta
	_walk_mix = move_toward(_walk_mix, 1.0 if moving else 0.0, delta * 5.0)
	if moving:
		_stride_phase += delta * clampf(speed * 2.1, 4.0, 12.0)
	var stride := sin(_stride_phase)
	var breath := 0.001 * sin(_elapsed * TAU / 4.5) * (1.0 - _walk_mix)
	var step_squash := 0.012 * cos(_stride_phase * 2.0) * _walk_mix
	_model.scale = _rest_scale
	_model.scale.y *= 1.0 + breath + step_squash
	_model.rotation = _rest_rotation + Vector3(
		deg_to_rad(2.0 + 1.2 * cos(_stride_phase * 2.0)) * _walk_mix,
		0.0,
		deg_to_rad(3.2) * stride * _walk_mix
	)
	# The lowest central point stays at its authored position: breathing and
	# walking sway do not lift the entire character away from the floor.
	_model.position = _rest_transform * _foot_anchor - _model.transform.basis * _foot_anchor


func _mesh_bottom_local(model: Node3D) -> float:
	# Imported skin bounds may already include the bind-space scale/offset.
	# An authored anchor avoids applying those transforms twice when grounding.
	var contact := model.find_child("GroundContact", true, false) as Node3D
	if contact != null: return model.to_local(contact.global_position).y
	var bottom := INF
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		var bounds := visual.mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					bottom = minf(bottom, model.to_local(visual.to_global(Vector3(x, y, z))).y)
	return bottom if is_finite(bottom) else 0.0


func _bind_rig_animations(model: Node3D) -> void:
	# A skeleton node alone is insufficient: the mesh needs usable bone weights.
	if not _has_weighted_skin(model):
		return
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	for node in players:
		var candidate := node as AnimationPlayer
		var idle := _find_clip(candidate, idle_animation)
		if idle == &"":
			continue
		var walk := _find_clip(candidate, walk_animation)
		var talk := _find_clip(candidate, talk_animation)
		if _animation_player == null or (walk != &"" and _walk_clip == &""):
			_animation_player = candidate
			_idle_clip = idle
			_walk_clip = walk
			_run_clip = _find_clip(candidate, run_animation)
			_talk_clip = talk
		if walk != &"":
			break
	if _animation_player != null:
		_animation_player.get_animation(_idle_clip).loop_mode = Animation.LOOP_LINEAR
		if _walk_clip != &"":
			_animation_player.get_animation(_walk_clip).loop_mode = Animation.LOOP_LINEAR
		if _run_clip != &"":
			_animation_player.get_animation(_run_clip).loop_mode = Animation.LOOP_LINEAR
		if _talk_clip != &"":
			_animation_player.get_animation(_talk_clip).loop_mode = Animation.LOOP_LINEAR
		_process(0.0)


func _has_weighted_skin(model: Node3D) -> bool:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		var skeleton := visual.get_node_or_null(visual.skeleton) as Skeleton3D
		if skeleton == null or skeleton.get_bone_count() == 0 or visual.skin == null or visual.skin.get_bind_count() == 0:
			continue
		for surface in range(visual.mesh.get_surface_count()):
			var arrays := visual.mesh.surface_get_arrays(surface)
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if bones != null and weights != null and bones.size() > 0 and weights.size() == bones.size():
				for weight in weights:
					if weight > 0.0:
						return true
	return false


func _find_clip(player: AnimationPlayer, requested: StringName) -> StringName:
	if player.has_animation(requested):
		return requested
	# Imported animation libraries may prefix the clip as "Library/Idle".
	for name in player.get_animation_list():
		if String(name).get_file().to_lower() == String(requested).to_lower():
			return StringName(name)
	return &""


func _has_renderable_mesh(model: Node3D) -> bool:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		if not visual.is_visible_in_tree() or visual.mesh == null:
			continue
		if visual.mesh.get_surface_count() > 0 and visual.mesh.get_aabb().size.length_squared() > 0.0:
			return true
	return false


func _rebuild_position_only_mesh_normals(model: Node3D) -> void:
	# Mesh-only concept exports can omit normals entirely. Rebuild just that
	# narrow case; leave UVs, colors, blend shapes, and skinned art untouched.
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		var source: Mesh = visual.mesh
		if not source is ArrayMesh:
			continue
		var source_array := source as ArrayMesh
		if source_array.get_surface_count() != 1 or source_array.get_blend_shape_count() != 0:
			continue
		if source_array.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = source_array.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_NORMAL] != null or arrays[Mesh.ARRAY_TEX_UV] != null or arrays[Mesh.ARRAY_COLOR] != null or arrays[Mesh.ARRAY_BONES] != null or arrays[Mesh.ARRAY_WEIGHTS] != null:
			continue
		var original_material: Material = source_array.surface_get_material(0)
		var surface_tool := SurfaceTool.new()
		surface_tool.create_from(source_array, 0)
		surface_tool.generate_normals()
		var rebuilt: ArrayMesh = surface_tool.commit()
		if original_material != null:
			rebuilt.surface_set_material(0, original_material)
		visual.mesh = rebuilt


func _tint_untextured_meshes(model: Node3D) -> void:
	var fallback := StandardMaterial3D.new()
	fallback.albedo_color = untextured_color
	fallback.roughness = 1.0
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		if visual.mesh == null:
			continue
		for surface in range(visual.mesh.get_surface_count()):
			var imported: Material = visual.mesh.surface_get_material(surface)
			var plain := imported as BaseMaterial3D
			var lacks_color := imported == null or (plain != null and plain.albedo_texture == null and plain.albedo_color == Color.WHITE)
			if visual.material_override == null and visual.get_surface_override_material(surface) == null and lacks_color:
				visual.set_surface_override_material(surface, fallback)
