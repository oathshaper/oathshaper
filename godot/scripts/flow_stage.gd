extends "res://scripts/command_stage.gd"
## Close action camera with a stable target-facing orbit. Backpedaling does not
## turn the camera around; movement remains relative to the displayed view.
var _manual_orbit_until := 0
var _tracked_target := ""
func _ready() -> void:
	_distance = 7.0
	_pitch = .32
	super._ready()
	camera.fov = 62
func orbit(relative: Vector2) -> void:
	_manual_orbit_until = Time.get_ticks_msec() + 2200
	super.orbit(relative)
func recenter_camera() -> void:
	_tracked_target = ""
	super.recenter_camera()
func _position_camera(delta := -1.0) -> void:
	if camera == null or not actors.has("player"): return
	if _hold_manual_view("player"): return
	if delta < 0.0: delta = get_process_delta_time()
	delta = clampf(delta, 0.0, .05)
	var hero: Node3D = actors.player
	var target_id := str(_state.get("hero", {}).get("target_id", ""))
	var focus := hero.position + Vector3.UP * .9
	if actors.has(target_id) and actors[target_id].visible:
		var target: Node3D = actors[target_id]
		var direction := target.position - hero.position
		if direction.length() > .3:
			if not _manual_camera:
				if target_id != _tracked_target: _auto_heading = atan2(-direction.x, -direction.z)
				_yaw = rotate_toward(_yaw, _auto_heading, delta * .65)
			focus += direction.limit_length(6.0) * .22
		_tracked_target = target_id
	if _manual_camera and _manual_anchor_id == "player":
		focus = _follow + hero.position - _manual_anchor
	_follow = _follow.move_toward(_follow.lerp(focus, 1.0-exp(-delta*3)), CAMERA_FOCUS_SPEED * delta) if _camera_initialized and not _manual_camera else focus
	focus = _follow
	var desired := focus + Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	var ray := PhysicsRayQueryParameters3D.create(focus, desired, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var safe: Vector3 = hit.position.lerp(focus,.12) if not hit.is_empty() else desired
	camera.position = camera.position.move_toward(camera.position.lerp(safe,1.0-exp(-delta*3)), CAMERA_TRAVEL_SPEED*delta) if _camera_initialized and not _manual_camera else safe
	camera.look_at(focus)
	_camera_initialized = true
	_remember_manual_view("player")
