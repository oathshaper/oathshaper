extends Node3D
## Presentation of the Command trial. Combat state, movement and damage come
## exclusively from the Rust view; animation never schedules an impact.
const SLOT := preload("res://scripts/character_model_slot.gd")
const WEAPON := preload("res://scripts/command_weapon.gd")
const ADVERSARY := preload("res://scripts/command_adversary.gd")
const GARDEN := preload("res://assets/meshes/garden_optimized.glb")
const SPACE := preload("res://scripts/command_space.gd")
const RIGS := {"player": "player", "corsair": "player", "mara": "mara", "ivo": "ivo", "clerk": "clerk", "civic_clerk": "clerk"}
const GOLD := Color("e2c37c")
const ALLY := Color("a9d6ca")
const HOSTILE := Color("e89782")
const TARGET := Color("ffd070")
var camera: Camera3D
var actors: Dictionary = {}
var _state: Dictionary = {}
var _targets: Dictionary = {}
var _sample_from: Dictionary = {}
var _sample_velocity: Dictionary = {}
var _facing_targets: Dictionary = {}
var _sample_tick := -1
var _sample_elapsed := 0.0
var _sample_interval := .1
# Command supplies its simulation accumulator. Other hosts use elapsed time.
var interpolation_fraction := -1.0
const CAMERA_SEARCH_BUDGET := 4
const CAMERA_YAWS := [0.0, -.35, .35, -.7, .7, -1.2, 1.2, -1.8, 1.8, PI]
const CAMERA_LIFTS := [0.0, .22, .5, .8]
var _camera_search_cursor := 0
var _camera_search_cooldown := 0.0
var _occluded_for := 0.0
var _search_best_score := -INF
var _search_best_yaw := 0.0
var _search_best_pitch := 0.0
var _framing_pair := ""
var _auto_heading := 0.0
const CAMERA_TRAVEL_SPEED := 5.0
const CAMERA_FOCUS_SPEED := 3.5
var _camera_sphere := SphereShape3D.new()
var _camera_sweep := PhysicsShapeQueryParameters3D.new()
var camera_candidates_last_frame := 0
var _previous_health: Dictionary = {}
var _active_ids: Dictionary = {}
var _clock_paused := true
var _follow := Vector3(1.5, 0, 0)
var _yaw := -PI * .5 + .08
var _distance := 7.2
var _pitch := .30
var _obstacle_yaw := 0.0
var _obstacle_pitch := 0.0
var _framed_distance := 7.2
var _effects: Node3D
var _generation := ""
var _space := SPACE.new()
var _follow_id := "player"
var _manual_camera_until := 0
var _manual_camera := false
var _manual_view_dirty := false
var _manual_anchor_id := ""
var _manual_anchor := Vector3.ZERO
var _camera_initialized := false
var markers: Control
var _selected_target := ""

func _ready() -> void:
	_camera_sphere.radius = .22
	_camera_sweep.shape = _camera_sphere
	_camera_sweep.collision_mask = 4
	_camera_sweep.margin = .05
	_build_garden()
	_build_collision()
	_build_lighting()
	_effects = Node3D.new()
	_effects.name = "PresentationEffects"
	add_child(_effects)
	camera = Camera3D.new()
	camera.name = "CommandCamera"
	camera.fov = 60
	camera.near = 0.1
	camera.far = 400
	add_child(camera)
	camera.current = true
	_position_camera()
	var marker_layer := CanvasLayer.new()
	marker_layer.layer = 0
	add_child(marker_layer)
	markers = preload("res://scripts/command_world_markers.gd").new()
	markers.stage = self
	marker_layer.add_child(markers)

func _build_garden() -> void:
	var garden := GARDEN.instantiate() as Node3D
	garden.name = "ImportedGarden"
	# Same measured mesh/scale as the quay; local origin is the central crossing.
	garden.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 15.64), Vector3(-0.9452, 1.4705, 0))
	add_child(garden)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	water.mesh = plane
	water.position.y = -1.8
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/harbor_water.gdshader")
	water.material_override = material
	add_child(water)

func _build_collision() -> void:
	var collision := StaticBody3D.new()
	collision.name = "AuthoredGardenCollision"
	collision.collision_layer = 4
	collision.collision_mask = 0
	add_child(collision)
	for obstacle in _space.geometry.obstacles:
		var shape := BoxShape3D.new()
		shape.size = Vector3(obstacle.size[0], obstacle.height, obstacle.size[1])
		var collider := CollisionShape3D.new()
		collider.name = str(obstacle.id)
		collider.shape = shape
		collider.position = Vector3(obstacle.center[0], obstacle.height * .5, obstacle.center[1])
		collision.add_child(collider)
	# Camera queries use the actual imported branches and leaves. Approximate
	# spheres around planter centres missed low branches over the fighting aisle.
	var scenery := StaticBody3D.new()
	scenery.name = "CameraScenery"
	scenery.collision_layer = 8
	scenery.collision_mask = 0
	add_child(scenery)
	for node in get_node("ImportedGarden").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null: continue
		var shape := mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var collider := CollisionShape3D.new()
		collider.shape = shape
		scenery.add_child(collider)
		collider.global_transform = mesh.global_transform

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/coastal_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("a2b7c3")
	environment.ambient_light_energy = 0.30
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("8ba8d3")
	sun.light_energy = 0.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add_child(sun)
	var beacon := OmniLight3D.new()
	beacon.name = "TowerSpill"
	# Same tower position expressed in the encounter garden coordinate frame.
	var layout := preload("res://scripts/garden_layout.gd")
	var local := layout.fit().affine_inverse() * Vector3(0, 7.85, -23)
	beacon.position = (local - Vector3(41.3, .54, -2)) * 1.7
	beacon.light_color = Color("ffcd83")
	beacon.light_energy = 2.0
	beacon.omni_range = 150.0
	beacon.omni_attenuation = .6
	beacon.shadow_enabled = true
	add_child(beacon)

func set_beacon_lit(lit: bool) -> void:
	get_node("TowerSpill").visible = lit

func _material(color: Color, metal := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72 if metal else 0.0
	material.roughness = 0.5 if metal else 0.85
	return material

func _part(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _ring(parent: Node3D, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.40
	mesh.outer_radius = 0.46
	mesh.rings = 32
	mesh.ring_segments = 8
	var material := _material(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _part(parent, mesh, Vector3(0, 0.05, 0), material)

func _create_actor(actor: Dictionary) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = str(actor.id)
	body.collision_layer = 0
	body.collision_mask = 0
	body.rotation.y = -PI / 2 if actor.get("faction", "party") == "party" else PI / 2
	add_child(body)
	var party_model: bool = actor.get("faction", "party") == "party" and RIGS.has(str(actor.id))
	if party_model:
		var slot := SLOT.new()
		slot.name = "ModelSlot"
		slot.rigged_model_path = "res://assets/meshes/rigged/%s_rigged.glb" % RIGS[str(actor.id)]
		slot.model_offset = Vector3.ZERO
		slot.model_scale = Vector3.ONE * 2
		slot.standing_motion_seed = str(actor.id).hash()
		slot.rotation.y = PI
		body.add_child(slot)
		var imported := slot.get_node("ImportedModel") as Node3D
		imported.position.y -= slot._mesh_bottom_local(imported) * slot.model_scale.y
		var weapon := WEAPON.new()
		weapon.name = "Weapon"
		body.add_child(weapon)
		weapon.configure(str(actor.appearance.main_hand), str(actor.appearance.offhand).replace("none", ""))
		weapon.set_readied(true)
	else:
		var model := ADVERSARY.new()
		model.name = "Art"
		body.add_child(model)
		model.configure(ADVERSARY.model_for(actor))
		if model.kind == "crimson_corsair":
			var weapon := WEAPON.new()
			weapon.name = "Weapon"
			body.add_child(weapon)
			weapon.configure(str(actor.get("appearance", {}).get("main_hand", "sabre")), "")
			weapon.set_readied(true)
	var ring := _ring(body, ALLY if actor.get("faction", "party") == "party" else HOSTILE)
	ring.name = "SelectionRing"
	actors[str(actor.id)] = body
	return body

func apply_view(view: Dictionary) -> void:
	var generation := str(view.get("session", {}).get("generation", ""))
	var tick := int(view.get("session", {}).get("tick", 0))
	var reset := generation != _generation or tick < _sample_tick
	var advanced := tick > _sample_tick
	if reset:
		_sample_from.clear()
		_sample_velocity.clear()
		_targets.clear()
		_camera_initialized = false
		_manual_anchor_id = ""
	if advanced or reset:
		_sample_from = _targets.duplicate()
		_sample_elapsed = 0.0
		_sample_interval = maxf(.001, float(view.get("session", {}).get("tick_ms", 100)) / 1000.0)
	if generation != _generation:
		_generation = generation
		_previous_health.clear()
		_active_ids.clear()
		for child in _effects.get_children():
			child.queue_free()
	_state = view
	_follow_id = str(view.get("party", {}).get("camera_follow_id", _follow_id))
	_clock_paused = bool(view.get("clock", {}).get("paused", true))
	_sample_tick = tick
	var selected := str(view.get("party", {}).get("recipient_id", ""))
	var selected_target := str(view.get("party", {}).get("selected_target_id", ""))
	if selected_target != _selected_target:
		_selected_target = selected_target
		_manual_camera_until = 0
	var present: Dictionary = {}
	for actor in view.get("actors", []):
		var point = actor.get("position", null)
		if point == null and actor.get("position_mm") != null:
			point = [actor.position_mm[0] / 1000.0, actor.position_mm[1] / 1000.0]
		if point == null or actor.get("roster_status", "") == "reserve":
			continue
		var id := str(actor.id)
		present[id] = true
		var newly_created := not actors.has(id)
		var body: CharacterBody3D = _create_actor(actor) if newly_created else actors[id]
		var target := Vector3(float(point[0]), _space.height_at(Vector2(float(point[0]), float(point[1]))), float(point[1]))
		var previous: Vector3 = _targets.get(id, target)
		_targets[id] = target
		if advanced:
			_sample_velocity[id] = (target - previous) / _sample_interval
		if newly_created or reset or _clock_paused or previous.distance_to(target) > 3.0:
			body.position = target
			_sample_from[id] = target
			_sample_velocity[id] = Vector3.ZERO
		if body.has_node("ModelSlot"):
			body.get_node("ModelSlot").process_mode = Node.PROCESS_MODE_DISABLED if _clock_paused else Node.PROCESS_MODE_INHERIT
		if body.has_node("Weapon") and body.get_node("Weapon").pose != null:
			body.get_node("Weapon").pose.process_mode = Node.PROCESS_MODE_DISABLED if _clock_paused else Node.PROCESS_MODE_INHERIT
		body.visible = true
		if body.has_node("Weapon"):
			var weapon := body.get_node("Weapon")
			var main_kind := str(actor.get("appearance", {}).get("main_hand", "unarmed"))
			var offhand_kind := str(actor.get("appearance", {}).get("offhand", "none")).replace("none", "")
			if weapon.kind != main_kind or weapon.offhand_kind != offhand_kind:
				weapon.configure(main_kind, offhand_kind)
		var conscious := bool(actor.get("conscious", true))
		var art: Node3D = body.get_node("ModelSlot") if body.has_node("ModelSlot") else body.get_node("Art")
		art.rotation.z = 0.0 if conscious else -PI * 0.43
		if body.has_node("Art"):
			body.get_node("Art").set_conscious(conscious)
		var ring := body.get_node("SelectionRing") as MeshInstance3D
		ring.visible = conscious
		var hostile_target: bool = selected_target == id and actor.get("faction") == "hostile"
		ring.material_override.albedo_color = TARGET if hostile_target else (GOLD if selected == id else (ALLY if actor.get("faction") == "party" else HOSTILE))
		ring.scale = Vector3.ONE * (1.22 if hostile_target else 1.0)
		var active: Dictionary = actor.get("active_action", {}) if actor.get("active_action") != null else {}
		var action_id := str(active.get("id", "")) if active.get("state") == "windup" else ""
		if action_id != "" and action_id != _active_ids.get(id, ""):
			if body.has_node("Weapon"):
				body.get_node("Weapon").set_readied(true)
				body.get_node("Weapon").pose.ability_id = str(active.get("ability_id", "basic"))
				body.get_node("Weapon").strike()
			if body.has_node("Art"):
				body.get_node("Art").show_attack()
		_active_ids[id] = action_id
		var resources: Dictionary = actor.get("resources", {})
		var health: Dictionary = actor.get("health", resources.get("health", {}))
		var current := int(health.get("current", 0))
		if _previous_health.has(id) and current != _previous_health[id]:
			_number(body.position + Vector3(0, 2, 0), current - int(_previous_health[id]))
			if current < int(_previous_health[id]) and body.has_node("Art") and conscious:
				body.get_node("Art").show_hit()
		_previous_health[id] = current
		var target_id := str(active.get("target", {}).get("actor_id", ""))
		_facing_targets[id] = target_id
	for id in actors:
		actors[id].visible = present.has(id)

func _number(at: Vector3, amount: int) -> void:
	var label := Label3D.new()
	label.text = "%+d" % amount
	label.font_size = 72
	label.pixel_size = .006
	label.outline_size = 10
	label.modulate = Color("b7e1a4") if amount > 0 else Color("ffe4ca")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_effects.add_child(label)
	label.position = at
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", at.y + 1.0, 1.3)
	tween.tween_property(label, "modulate:a", 0.0, 1.3)
	tween.chain().tween_callback(label.queue_free)

func _process(delta: float) -> void:
	_sample_elapsed += delta
	var fraction := interpolation_fraction if interpolation_fraction >= 0.0 else clampf(_sample_elapsed / _sample_interval, 0.0, 1.0)
	for id in actors:
		var body: CharacterBody3D = actors[id]
		if not body.visible:
			continue
		var target: Vector3 = _targets.get(id, body.position)
		var origin: Vector3 = _sample_from.get(id, target)
		body.position = target if _clock_paused else origin.lerp(target, fraction)
		# Use the authoritative interval velocity, not a burst followed by a stop.
		body.velocity = Vector3.ZERO if _clock_paused else _sample_velocity.get(id, Vector3.ZERO)
		if interpolation_fraction < 0.0 and _sample_elapsed > _sample_interval * 2.0:
			body.velocity = Vector3.ZERO
		var direction := body.velocity
		var facing_id := str(_facing_targets.get(id, ""))
		if direction.length_squared() <= .01 and actors.has(facing_id):
			direction = actors[facing_id].position - body.position
		if not _clock_paused and direction.length_squared() > .01:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-delta * 12.0))
		if body.has_node("Art"):
			body.get_node("Art").set_motion(body.velocity, int(_state.get("session", {}).get("tick", 0)), _clock_paused)
	_position_camera()

func _position_camera(delta := -1.0) -> void:
	if camera == null:
		return
	camera_candidates_last_frame = 0
	if delta < 0.0: delta = get_process_delta_time()
	delta = clampf(delta, 0.0, .05)
	if _hold_manual_view(_follow_id):
		return
	var manual_input := _manual_view_dirty
	# Perspective duel framing. Offset the combat axis so the controlled actor
	# and target have separate silhouettes; keep room above the bottom command bar.
	var focus := _follow
	var desired_distance := _distance
	if actors.has(_follow_id):
		focus = actors[_follow_id].position + Vector3.UP * .65
		var target_id := str(_state.get("party", {}).get("selected_target_id", ""))
		if actors.has(target_id) and actors[target_id].visible and target_id != _follow_id:
			var direction: Vector3 = actors[target_id].position - actors[_follow_id].position
			focus += direction.limit_length(10.0) * .43
			desired_distance = maxf(_distance, minf(12.0, 6.7 + direction.length() * .52))
			var pair := _follow_id + ":" + target_id
			if pair != _framing_pair and direction.length_squared() > .25:
				_framing_pair = pair
				_auto_heading = atan2(-direction.x, -direction.z) + .62
			if not _manual_camera:
				# Acquire a shoulder on deliberate selection. An enemy circling or
				# crossing the actor must not spin the camera around every frame.
				_yaw = rotate_toward(_yaw, _auto_heading, delta * .65)
	var blend := 1.0 - exp(-delta * 3.0)
	if _manual_camera:
		# A deliberate party switch must finish framing the new actor before
		# holding again; do not freeze halfway through the automatic easing.
		blend = 1.0
	if _manual_camera and _manual_anchor_id == _follow_id and actors.has(_follow_id):
		# Preserve the chosen composition. Only controlled-character travel
		# translates this focus; a target or companion moving cannot drag it.
		focus = _follow + actors[_follow_id].position - _manual_anchor
		desired_distance = _distance
	_follow = _follow.move_toward(_follow.lerp(focus, blend), CAMERA_FOCUS_SPEED * delta) if _camera_initialized and not _manual_camera else focus
	_framed_distance = lerpf(_framed_distance, desired_distance, blend) if _camera_initialized else desired_distance
	var first_frame := not _camera_initialized
	_camera_initialized = true
	# Hold a clear shoulder; search both directions and higher views if foliage
	# hides a fighter. A safe camera centre alone does not prove a clear shot.
	var desired := _camera_orbit(_obstacle_yaw, _obstacle_pitch)
	var safe := _safe_camera_position(_follow, desired)
	var subjects := _camera_subjects()
	_camera_search_cooldown = maxf(0.0, _camera_search_cooldown - delta)
	var visible_count := _visible_subjects(safe, subjects)
	var blocked := safe.distance_to(_follow) < desired.distance_to(_follow) * .88 or visible_count < subjects.size()
	_occluded_for = _occluded_for + delta if blocked else 0.0
	if not _manual_camera and _occluded_for >= .25 and _camera_search_cooldown <= 0.0:
		if _camera_search_cursor == 0:
			_search_best_score = visible_count * 30.0 + minf(safe.distance_to(_follow), _framed_distance)
			_search_best_yaw = _obstacle_yaw
			_search_best_pitch = _obstacle_pitch
		# Finish the bounded search before choosing a shoulder. Previously each
		# better candidate caused a jump, sometimes to the opposite side.
		for _candidate in range(CAMERA_SEARCH_BUDGET):
			var yaw_offset: float = CAMERA_YAWS[_camera_search_cursor % CAMERA_YAWS.size()]
			var lift: float = CAMERA_LIFTS[_camera_search_cursor / CAMERA_YAWS.size()]
			_camera_search_cursor += 1
			camera_candidates_last_frame += 1
			var clear := _safe_camera_position(_follow, _camera_orbit(yaw_offset, lift))
			var count := _visible_subjects(clear, subjects)
			var score: float = count * 30.0 + minf(clear.distance_to(_follow), _framed_distance) - absf(angle_difference(_obstacle_yaw, yaw_offset)) * 3.0 - lift * 2.0
			if score > _search_best_score + 2.0:
				_search_best_score = score
				_search_best_yaw = yaw_offset
				_search_best_pitch = lift
			if _camera_search_cursor >= CAMERA_YAWS.size() * CAMERA_LIFTS.size():
				_obstacle_yaw = _search_best_yaw
				_obstacle_pitch = _search_best_pitch
				safe = _safe_camera_position(_follow, _camera_orbit(_obstacle_yaw, _obstacle_pitch))
				_camera_search_cursor = 0
				_camera_search_cooldown = 1.2
				break
	elif not blocked:
		_camera_search_cursor = 0
	if first_frame: camera.position = safe
	var eased := camera.position.lerp(safe, blend)
	if not _manual_camera and _camera_initialized:
		eased = camera.position.move_toward(eased, CAMERA_TRAVEL_SPEED * delta)
	# Move the lens from its previous position, not from the subjects' feet.
	# A leaf crossing that sight line must not teleport the camera inward.
	if not manual_input and camera.position.length_squared() > .01:
		_camera_sweep.transform = Transform3D(Basis.IDENTITY, camera.position)
		_camera_sweep.motion = eased - camera.position
		var fractions := get_world_3d().direct_space_state.cast_motion(_camera_sweep)
		eased = camera.position.lerp(eased, fractions[0])
	camera.position = eased
	camera.look_at(_follow)
	_remember_manual_view(_follow_id)

func _hold_manual_view(id: String) -> bool:
	return _manual_camera and not _manual_view_dirty and _manual_anchor_id == id and actors.has(id) and actors[id].position.distance_squared_to(_manual_anchor) < .000001

func _remember_manual_view(id: String) -> void:
	if actors.has(id):
		_manual_anchor_id = id
		_manual_anchor = actors[id].position
	_manual_view_dirty = false

func _begin_manual_view() -> void:
	# Start from the visible shot, including any automatic obstruction offset,
	# so the first mouse/stick input does not snap back to an older orbit.
	if not _manual_view_dirty and _camera_initialized:
		var offset := camera.position - _follow
		if offset.length_squared() > .01:
			_yaw = atan2(offset.x, offset.z)
			_pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
			_distance = offset.length()
	_manual_camera = true
	_manual_view_dirty = true
	_obstacle_yaw = 0.0
	_obstacle_pitch = 0.0
	_camera_search_cursor = 0
	_camera_search_cooldown = 0.0

func _camera_subjects() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for id in [_follow_id, str(_state.get("party", {}).get("selected_target_id", ""))]:
		if actors.has(id) and actors[id].visible:
			points.append(actors[id].position + Vector3.UP * 1.65)
			points.append(actors[id].position + Vector3.UP * .95)
	return points

func _visible_subjects(from: Vector3, points: Array[Vector3]) -> int:
	var count := 0
	for point in points:
		var ray := PhysicsRayQueryParameters3D.create(from, point, 4 | 8)
		ray.hit_back_faces = true
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and not _actor_blocks_view(from, point): count += 1
	return count

func _camera_orbit(offset: float, lift: float) -> Vector3:
	var yaw := _yaw + offset
	var pitch := minf(_pitch + lift, 1.32)
	return _follow + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _framed_distance

func _safe_camera_position(focus: Vector3, desired: Vector3) -> Vector3:
	# Sweep against the authored solid boxes. Sweeping a sphere through the
	# garden's 900k-triangle foliage can stall a frame for seconds. Five lens
	# probes retain the imported mesh silhouette without triangle shape casts.
	var motion := desired - focus
	if motion.length_squared() < .0001: return desired
	_camera_sweep.transform = Transform3D(Basis.IDENTITY, focus)
	_camera_sweep.motion = motion
	var fractions := get_world_3d().direct_space_state.cast_motion(_camera_sweep)
	var fraction := fractions[0]
	var direction := motion.normalized()
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < .001: right = Vector3.RIGHT
	var up := right.cross(direction).normalized()
	for offset in [Vector3.ZERO, right * .22, right * -.22, up * .22, up * -.22]:
		var ray := PhysicsRayQueryParameters3D.create(focus + offset, desired + offset, 8)
		ray.hit_back_faces = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			fraction = minf(fraction, focus.distance_to(hit.position - offset) / motion.length())
	return focus + motion * maxf(0.0, fraction - .02) if fraction < 1.0 else desired

func orbit(relative: Vector2) -> void:
	_begin_manual_view()
	_yaw -= relative.x * .006
	_pitch = clampf(_pitch + relative.y * .004, .12, 1.15)

func zoom(amount: float) -> void:
	_begin_manual_view()
	_distance = clampf(_distance + amount, 3.5, 14.0)

func follow_actor(id: String) -> void:
	_follow_id = id

func pick(screen_point: Vector2) -> Dictionary:
	var closest := 42.0
	var selected := ""
	for id in actors:
		var body: Node3D = actors[id]
		if not body.visible or camera.is_position_behind(body.position):
			continue
		var distance := camera.unproject_position(body.position + Vector3.UP).distance_to(screen_point)
		if distance < closest:
			closest = distance
			selected = id
	if selected != "":
		return {"kind": "actor", "actor_id": selected, "position": null}
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen_point), camera.project_ray_normal(screen_point))
	return {"kind": "point", "actor_id": null, "position": [snappedf(hit.x, .001), snappedf(hit.z, .001)]} if hit != null else {}

func recenter_camera() -> void:
	_framing_pair = ""
	_occluded_for = 0.0
	_camera_search_cursor = 0
	_camera_search_cooldown = 0.0
	_manual_camera = false
	_manual_view_dirty = false
	_manual_anchor_id = ""
	_obstacle_yaw = 0.0
	_obstacle_pitch = 0.0

func _actor_blocks_view(from: Vector3, to: Vector3) -> bool:
	for body in actors.values():
		if not body.visible or body.position.distance_to(to - Vector3.UP * .95) < .8 or body.position.distance_to(to - Vector3.UP * 1.65) < .8: continue
		for height in [.6, 1.25, 1.8]:
			var center: Vector3 = body.position + Vector3.UP * height
			var closest := Geometry3D.get_closest_point_to_segment(center, from, to)
			if closest.distance_to(center) < .38: return true
	return false
