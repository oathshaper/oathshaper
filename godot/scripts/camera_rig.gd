extends Node3D

@onready var target: Node3D = get_node("../Player")
@onready var camera: Camera3D = $Camera3D

const MIN_PITCH := 10.0
const MAX_PITCH := 65.0
const MIN_DISTANCE := 3.5
const MAX_DISTANCE := 28.0
const MOUSE_ORBIT_SPEED := 0.25
const MOUSE_PAN_SPEED := 0.002
const WHEEL_ZOOM_FACTOR := 1.15
const DIALOGUE_FOV := 48.0
const DIALOGUE_BLEND_SECONDS := 0.38

# Automatic follow tracks movement until the player chooses a manual orbit.
# The chosen heading stays put until explicit recenter or a scene transition.
@export_range(1.0, 40.0, 0.5) var active_follow_speed := 18.0
@export_range(0.1, 12.0, 0.1) var idle_follow_speed := 3.5
@export_range(0.0, 3.0, 0.05) var manual_orbit_grace := 1.25
@export_range(0.0, 3.0, 0.05) var manual_pan_grace := 1.0
@export_range(0.1, 8.0, 0.1) var pan_return_speed := 2.0
@export_range(0.1, 8.0, 0.1) var occlusion_return_speed := 3.0

var yaw := 20.0
var pitch := 20.0
var distance := 5.0
var pan_offset := Vector3.ZERO
var _exploration_fov := 75.0
var _dialogue_actor: Node3D
var _blend_from := Transform3D.IDENTITY
var _blend_from_fov := 75.0
var _blend_elapsed := 0.0
var _blending := false
var _orbit_grace_remaining := 0.0
var _pan_grace_remaining := 0.0
var _occlusion_ratio := 1.0
var _interior_view := false
var _manual_heading := false


func _ready() -> void:
	_exploration_fov = camera.fov


func enter_dialogue(npc: Node3D) -> void:
	if npc == null or not is_instance_valid(npc) or _dialogue_actor == npc:
		return
	_begin_blend()
	_dialogue_actor = npc


func exit_dialogue() -> void:
	if _dialogue_actor == null:
		return
	_begin_blend()
	_dialogue_actor = null


func focus_after_teleport(heading_degrees: float, interior := false) -> void:
	# Door transfers and save loads move the actor without a walking turn. Put
	# the close view behind the new arrival before it is drawn in that area.
	if target.has_method("reset_movement_basis"):
		target.call("reset_movement_basis")
	_interior_view = interior
	_manual_heading = false
	yaw = wrapf(heading_degrees, -180.0, 180.0)
	pitch = 55.0 if interior else 20.0
	distance = 4.2 if interior else 5.0
	pan_offset = Vector3.ZERO
	_orbit_grace_remaining = 0.0
	_pan_grace_remaining = 0.0
	_occlusion_ratio = 1.0
	_blending = false
	_update_occlusion(0.0)
	camera.global_transform = _exploration_pose()
	camera.fov = _exploration_fov


func _begin_blend() -> void:
	_blend_from = camera.global_transform
	_blend_from_fov = camera.fov
	_blend_elapsed = 0.0
	_blending = true


func _physics_process(delta: float) -> void:
	if not _can_move_camera():
		return
	_update_occlusion(delta)


func _update_occlusion(delta: float) -> void:
	var focus := _exploration_focus()
	var desired := focus + _exploration_offset()
	var query := PhysicsRayQueryParameters3D.create(focus, desired)
	var excluded: Array[RID] = [target.get_rid()]
	var hit: Dictionary
	for _attempt in range(8):
		query.exclude = excluded
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.get("collider") as CollisionObject3D
		# Dialogue actors should not make the camera jump onto the player's head.
		if collider != null and collider.name == "Collider":
			excluded.append(collider.get_rid())
			continue
		break
	var safe_ratio := 1.0
	if not hit.is_empty():
		safe_ratio = clampf((focus.distance_to(hit.position) - 0.3) / focus.distance_to(desired), 0.08, 1.0)
	if safe_ratio < _occlusion_ratio:
		_occlusion_ratio = safe_ratio
	else:
		_occlusion_ratio = move_toward(_occlusion_ratio, safe_ratio, occlusion_return_speed * delta)

func _process(delta: float) -> void:
	if _can_move_camera():
		_update_exploration_follow(delta)
	if _dialogue_actor != null and not is_instance_valid(_dialogue_actor):
		exit_dialogue()
	var destination := _exploration_pose()
	var destination_fov := _exploration_fov
	if _dialogue_actor != null:
		destination = _dialogue_pose(_dialogue_actor)
		destination_fov = DIALOGUE_FOV
	if _blending:
		_blend_elapsed += delta
		var amount := clampf(_blend_elapsed / DIALOGUE_BLEND_SECONDS, 0.0, 1.0)
		amount = amount * amount * (3.0 - 2.0 * amount)
		camera.global_transform = _blend_from.interpolate_with(destination, amount)
		camera.fov = lerpf(_blend_from_fov, destination_fov, amount)
		if _blend_elapsed >= DIALOGUE_BLEND_SECONDS:
			_blending = false
	else:
		camera.global_transform = destination
		camera.fov = destination_fov


func _update_exploration_follow(delta: float) -> void:
	var orbit_x := Input.get_axis("camera_left", "camera_right")
	var orbit_y := Input.get_axis("camera_up", "camera_down")
	var manual_orbit := absf(orbit_x) > 0.02 or absf(orbit_y) > 0.02
	if manual_orbit:
		yaw = wrapf(yaw - orbit_x * 85.0 * delta, -180.0, 180.0)
		pitch = clampf(pitch + orbit_y * 65.0 * delta, MIN_PITCH, MAX_PITCH)
		_note_manual_orbit()
	else:
		_orbit_grace_remaining = maxf(0.0, _orbit_grace_remaining - delta)

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if not _manual_heading and not manual_orbit and _orbit_grace_remaining <= 0.0:
		var heading := wrapf(rad_to_deg(target.rotation.y), -180.0, 180.0)
		if move_input.length_squared() > 0.04:
			if not bool(target.get("backpedaling")):
				var follow_weight := 1.0 - exp(-active_follow_speed * delta)
				yaw = wrapf(rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(heading), follow_weight)), -180.0, 180.0)
		else:
			var weight := 1.0 - exp(-idle_follow_speed * delta)
			yaw = wrapf(rad_to_deg(lerp_angle(deg_to_rad(yaw), deg_to_rad(heading), weight)), -180.0, 180.0)

	_pan_grace_remaining = maxf(0.0, _pan_grace_remaining - delta)
	if _pan_grace_remaining <= 0.0 and pan_offset.length_squared() > 0.000001:
		pan_offset = pan_offset.lerp(Vector3.ZERO, 1.0 - exp(-pan_return_speed * delta))
		if pan_offset.length_squared() < 0.0001:
			pan_offset = Vector3.ZERO


func _note_manual_orbit() -> void:
	_manual_heading = true
	_orbit_grace_remaining = manual_orbit_grace
	target.rotation.y = deg_to_rad(yaw)
	# Input can be delivered before the next camera process tick. Publish the
	# chosen basis now so held movement cannot latch the previous heading.
	camera.global_transform = _exploration_pose()
	if target.has_method("reset_movement_basis"):
		target.reset_movement_basis()


func _exploration_pose() -> Transform3D:
	var focus := _exploration_focus()
	var position := focus + _exploration_offset() * _occlusion_ratio
	return Transform3D(Basis.looking_at(focus - position), position)


func _exploration_focus() -> Vector3:
	return target.global_position + Vector3.UP * 0.7 + pan_offset


func _exploration_offset() -> Vector3:
	if _interior_view:
		# The office is roofless, with a low south cutaway wall and open doorway.
		# A steeper view reveals the cabinet over the doorway lintel at entry.
		var room_distance := clampf(distance, MIN_DISTANCE, 6.5)
		return Vector3(0.0, room_distance * tan(deg_to_rad(pitch)), room_distance).rotated(Vector3.UP, deg_to_rad(yaw))
	var height := distance * tan(deg_to_rad(pitch))
	return Vector3(0.0, height, distance).rotated(Vector3.UP, deg_to_rad(yaw))


func _dialogue_pose(npc: Node3D) -> Transform3D:
	# Blend the player's approach with the NPC's front. Side approaches become
	# three-quarter portraits; approaching from behind still shows the NPC face.
	var toward_npc := npc.global_position - target.global_position
	toward_npc.y = 0.0
	var separation := toward_npc.length()
	if separation >= 0.01:
		toward_npc /= separation
	var front := npc.global_transform.basis.z
	front.y = 0.0
	front = front.normalized() if front.length_squared() > 0.01 else Vector3.BACK
	var view_side := (front - toward_npc * 0.45).normalized()
	var right := (-view_side).cross(Vector3.UP).normalized()
	var shot_distance := maxf(2.7, separation + 0.7)
	var position := npc.global_position + view_side * shot_distance + right * 0.45 + Vector3.UP * 1.15
	# Aim to the NPC's left, placing their face a little right of center.
	var focus := npc.global_position + Vector3.UP * 0.38 - right * 0.30
	return Transform3D(Basis.looking_at(focus - position), position)


func _input(event: InputEvent) -> void:
	if not _can_move_camera():
		return
	if event.is_action_pressed("camera_recenter"):
		_manual_heading = false
		pan_offset = Vector3.ZERO
		_pan_grace_remaining = 0.0
		yaw = wrapf(rad_to_deg(target.rotation.y), -180.0, 180.0)
		_orbit_grace_remaining = 0.0
		_occlusion_ratio = 1.0
		_update_occlusion(0.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance / WHEEL_ZOOM_FACTOR, MIN_DISTANCE, MAX_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance * WHEEL_ZOOM_FACTOR, MIN_DISTANCE, MAX_DISTANCE)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			yaw = wrapf(yaw - event.relative.x * MOUSE_ORBIT_SPEED, -180.0, 180.0)
			pitch = clampf(pitch + event.relative.y * MOUSE_ORBIT_SPEED, MIN_PITCH, MAX_PITCH)
			_note_manual_orbit()
		elif (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
			var right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(yaw))
			var forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(yaw))
			pan_offset += (-right * event.relative.x + forward * event.relative.y) * distance * MOUSE_PAN_SPEED
			_pan_grace_remaining = manual_pan_grace
		else:
			return
		get_viewport().set_input_as_handled()


func _can_move_camera() -> bool:
	return _dialogue_actor == null and get_parent().get("mode") == "explore"
