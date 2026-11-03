extends "res://scripts/command_stage.gd"
## Uses the shared garden/rig builders only. Vanguard owns camera, pose projection,
## observed rays and movement proposals; this script never applies damage.
var yaw := -PI / 2
var pitch := -.05
var aimed := false
var _last_shots := 0
var _vstate: Dictionary = {}
var move_axis := Vector2.ZERO
var _flash_time := 0.0
var _tracer: MeshInstance3D
var _cover_marker: Node3D
var _cover_material: StandardMaterial3D

func _ready() -> void:
	_build_garden()
	_build_collision()
	_build_lighting()
	_effects = Node3D.new()
	add_child(_effects)
	_build_cover_marker()
	camera = Camera3D.new()
	camera.fov = 66
	camera.near = .08
	camera.far = 400
	add_child(camera)
	camera.current = true
	_tracer = MeshInstance3D.new()
	_tracer.name = "ShotTracer"
	add_child(_tracer)

func look(amount: Vector2) -> void:
	yaw -= amount.x * .003
	pitch = clampf(pitch - amount.y * .003, -.6, .55)

func forward() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))

func _position_camera(_delta := -1.0) -> void:
	if camera == null or not actors.has("player"):
		return
	var body: Node3D = actors.player
	var direction := forward()
	var right := direction.cross(Vector3.UP).normalized()
	var eye := body.position + Vector3(0, 1.55, 0)
	var distance_back := 2.0 if aimed else 3.25
	var desired := eye - direction * distance_back + right * .65
	# Planter collision protects the camera; the body cannot cross these boxes.
	var query := PhysicsRayQueryParameters3D.create(eye, desired, 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	camera.position = hit.position.lerp(eye, .12) if not hit.is_empty() else desired
	camera.look_at(eye + direction * 24 + right * .65, Vector3.UP)
	body.rotation.y = yaw

func apply_view(view: Dictionary) -> void:
	var previous := _vstate
	_vstate = view
	aimed = bool(view.aimed)
	for id in view.actors:
		var actor: Dictionary = view.actors[id]
		var body: CharacterBody3D
		if not actors.has(id):
			body = _create_actor({"id": id, "name": actor.name, "faction": "party" if actor.party else "hostile", "appearance":{"model":{"hound":"lantern_sentinel","sentinel":"iron_sentinel","corsair_raider":"crimson_corsair"}.get(id,""),"main_hand":"unarmed","offhand":"none"}})
			if body.has_node("Weapon"):
				body.get_node("Weapon").free()
				_build_firearm(body, id)
		else:
			body = actors[id]
		var point := Vector2(actor.position[0], actor.position[1]) / 1000.0
		body.position = Vector3(point.x, _space.height_at(point), point.y)
		# Spawning and cinematic staging are not travel. Sample authoritative
		# positions across advancing ticks; commands at the same tick keep gait.
		var elapsed := int(view.tick) - int(previous.get("tick", view.tick))
		if previous.is_empty() or bool(view.paused) or elapsed < 0 or actor.hp <= 0:
			body.velocity = Vector3.ZERO
		elif elapsed > 0:
			var before: Array = previous.actors[id].position
			body.velocity = Vector3(actor.position[0] - before[0], 0, actor.position[1] - before[1]) * (60.0 / (1000.0 * elapsed))
		if actor.party and body.has_node("ModelSlot"):
			var slot := body.get_node("ModelSlot")
			slot.rotation.z = 0.0 if actor.hp > 0 else -1.2
			slot.position.y = -.55 if actor.cover and not (id == "player" and view.aimed) else 0.0
			body.get_node("Firearm").set_readied(actor.hp > 0 and (id != "player" or view.draw))
		else:
			body.get_node("Art").rotation.z = 0.0 if actor.hp > 0 else -1.2
			body.get_node("Art").set_conscious(actor.hp > 0)
		body.visible = id == "player" or not actor.party or camera.position.distance_to(body.position + Vector3(0,1,0)) > 2.5
		body.get_node("SelectionRing").visible = actor.hp > 0
		# The HUD owns the aimed target's name/vitals. A second world-space
		# label duplicates it and was unreadable in the native GL capture.
		if id != "player" and actor.hp > 0:
			var target := actors.get("player") as Node3D
			if target != null:
				body.rotation.y = atan2(body.position.x - target.position.x, body.position.z - target.position.z)
	if int(view.shots) > _last_shots:
		_shot_flash(str(view.last_shooter), view.last_target)
	_last_shots = int(view.shots)
	_update_cover_marker()
	_position_camera()

func cover_candidate(point: Vector2) -> Dictionary:
	# The affordance and the frame observation share the same eligibility rule.
	var best := {}
	var nearest := INF
	for obstacle in _space.geometry.obstacles:
		var bounds: Rect2 = _space._rect(obstacle)
		if bounds.has_point(point): continue
		var at := point.clamp(bounds.position, bounds.end)
		var distance := point.distance_to(at)
		if distance >= nearest: continue
		nearest = distance
		best = {"point": at, "normal": at.direction_to(point), "distance": distance,
			"available": bounds.grow(.8).has_point(point)}
	return best

func _build_cover_marker() -> void:
	_cover_marker = Node3D.new()
	_cover_marker.name = "CoverMarker"
	_effects.add_child(_cover_marker)
	_cover_material = _material(Color("d8bd80"))
	_cover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# A floor bracket sits outside the planter, on its nearest accessible edge.
	for index in 3:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.85, .035, .06) if index == 0 else Vector3(.06, .035, .35)
		_part(_cover_marker, mesh, Vector3(0, 0, 0) if index == 0 else Vector3(-.4 if index == 1 else .4, 0, .15), _cover_material)

func _update_cover_marker() -> void:
	var p: Dictionary = _vstate.actors.player
	var point := Vector2(p.position[0], p.position[1]) / 1000.0
	var candidate := cover_candidate(point)
	_cover_marker.visible = not candidate.is_empty() and candidate.distance < 5.0 and p.hp > 0
	if not _cover_marker.visible: return
	var normal: Vector2 = candidate.normal
	var at: Vector2 = candidate.point + normal * .18
	_cover_marker.position = Vector3(at.x, _space.height_at(at) + .08, at.y)
	_cover_marker.rotation.y = atan2(normal.x, normal.y)
	_cover_material.albedo_color = Color("9ad6dd") if p.cover or candidate.available else Color("d8bd80")

func _build_firearm(body: Node3D, id: String) -> void:
	var gun := preload("res://scripts/vanguard_weapon.gd").new()
	gun.name = "Firearm"
	body.add_child(gun)
	gun.configure("carbine")
	gun.set_readied(id != "player")

func _aim_ray() -> Vector3:
	return camera.project_ray_normal(camera.get_viewport().get_visible_rect().size * .5)

func _shot_endpoint(id: String, target, start: Vector3) -> Vector3:
	var has_target := target != null and actors.has(target)
	var at: Vector3 = actors[target].position + Vector3(0, 1.2, 0) if has_target else start + forward() * 18
	if id != "player":
		return at
	# The shoulder camera and muzzle have different origins. Converge at the
	# center ray's hit depth, including misses; never snap sideways to a body's
	# center just because the aim ray intersects its target volume.
	var ray := _aim_ray()
	var depth := maxf((at - camera.global_position).dot(ray), .1) if has_target else 40.0
	return camera.global_position + ray * depth

func _shot_flash(id: String, target) -> void:
	if not actors.has(id):
		return
	var start: Vector3 = actors[id].position + Vector3(0, 1.2, 0)
	if actors[id].has_node("Firearm"):
		var weapon = actors[id].get_node("Firearm")
		weapon.strike()
		if is_instance_valid(weapon.flash): start = weapon.flash.global_position
	elif actors[id].has_node("Art"):
		actors[id].get_node("Art").show_attack()
	var end := _shot_endpoint(id, target, start)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(start)
	mesh.surface_add_vertex(end)
	mesh.surface_end()
	_tracer.mesh = mesh
	var material := _material(Color("ffe1a0"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer.material_override = material
	_tracer.visible = true
	_flash_time = .045

func _process(delta: float) -> void:
	_flash_time -= delta
	if _tracer != null:
		_tracer.visible = _flash_time > 0
	for body in actors.values():
		if body.has_node("Art"):
			body.get_node("Art").set_motion(body.velocity, int(_vstate.get("tick", 0)), bool(_vstate.get("paused", true)))
	_position_camera()

func _clear_segment(from: Vector2, to: Vector2) -> bool:
	return _space.line_clear(from, to, .35, true)

func frame(state: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	var sight: Array[String] = []
	var cover: Array[String] = []
	var aim = null
	var nearest := 1000.0
	var origin := camera.global_position
	var ray := _aim_ray()
	for id in state.actors:
		var a: Dictionary = state.actors[id]
		var point := Vector2(a.position[0], a.position[1]) / 1000.0
		var desired := point
		if a.hp > 0:
			if int(a.knockback_until) > int(state.tick):
				desired += Vector2(a.knockback[0], a.knockback[1]) / 1000.0
			elif id == "player" and not a.cover and int(a.stunned) <= int(state.tick):
				var dir := Vector2(-sin(yaw), -cos(yaw))
				desired += (Vector2(-dir.y, dir.x) * move_axis.x + dir * -move_axis.y).limit_length() * (4.0 / 60)
			elif a.party and a.stance == "follow" and id != "player" and int(a.stunned) <= int(state.tick):
				var player: Dictionary = state.actors.player
				var goal := Vector2(player.position[0], player.position[1]) / 1000.0 + Vector2(-1.4, -1.5 if id == "mara" else 1.5)
				if point.distance_to(goal) > .5:
					var path: Array = _space.route(point, goal)
					if path.size() > 1:
						desired += point.direction_to(path[1]) * minf(4.0 / 60, point.distance_to(path[1]))
		if not _clear_segment(point, desired):
			desired = point
		positions[id] = [roundi(desired.x * 1000), roundi(desired.y * 1000)]
		var candidate := cover_candidate(point)
		if not candidate.is_empty() and candidate.available:
			cover.append(str(id))
	for id in state.actors:
		var a: Dictionary = state.actors[id]
		var point := Vector2(positions[id][0], positions[id][1]) / 1000.0
		# Camera ray intersects a body-sized target volume; nearest ally also
		# blocks firing. Rays cannot click-select a hostile behind a planter.
		if id != "player" and a.hp > 0:
			var center := Vector3(point.x, 1.15 + _space.height_at(point), point.y)
			var along := (center - origin).dot(ray)
			var miss := center.distance_to(origin + ray * along)
			var muzzle: Vector3 = actors.player.position + Vector3(0,1.2,0)
			if along > (muzzle - origin).dot(ray) + .3 and along < nearest and miss < .62:
				nearest = along
				aim = null if a.party else id
	for id in state.actors:
		for target in state.actors:
			if id == target:
				continue
			var a: Dictionary = state.actors[id]
			var b: Dictionary = state.actors[target]
			if a.hp <= 0 or b.hp <= 0:
				continue
			var from := Vector2(positions[id][0], positions[id][1]) / 1000.0
			var to := Vector2(positions[target][0], positions[target][1]) / 1000.0
			var source_height := .8 if a.cover and not (id == "player" and state.aimed) else 1.75
			var target_height := 1.65 if b.cover and target == "player" and state.aimed else (.8 if b.cover else 1.25)
			var ray_query := PhysicsRayQueryParameters3D.create(Vector3(from.x, source_height, from.y), Vector3(to.x, target_height, to.y), 4)
			var clear: bool = get_world_3d().direct_space_state.intersect_ray(ray_query).is_empty()
			if clear:
				var segment := to - from
				for blocker in state.actors:
					if blocker in [id, target] or state.actors[blocker].hp <= 0:
						continue
					var body_point := Vector2(positions[blocker][0], positions[blocker][1]) / 1000.0
					var along := (body_point - from).dot(segment) / maxf(segment.length_squared(), .001)
					if along > .03 and along < .97 and body_point.distance_to(from + segment * along) < .32:
						clear = false
						break
			if clear:
				sight.append("%s:%s" % [id, target])
	return {"tick":int(state.tick),"sequence":int(state.sequence)+1,"positions":positions,"sight":sight,"aim":aim,"cover":cover}
