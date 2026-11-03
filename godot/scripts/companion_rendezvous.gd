extends RefCounted
## Travel owns positions. Story refreshes only change intent; they never teleport actors.
var _routes: Dictionary = {}
var _homes: Dictionary = {}
var _actors: Dictionary = {}
var _started := false
var _gate_open := false
var _following := false
var _portal: Dictionary = {}
var _last_trail := Vector2(INF, INF)
var _root: Node3D

func bind(root: Node3D) -> void:
	_root = root
	for id in ["Mara", "Ivo"]:
		var actor := root.get_node(id) as Node3D
		_actors[id] = actor
		_homes[id] = actor.transform

func reconcile(flags: Dictionary) -> void:
	var gathered := bool(flags.get("mara_recruited", false))
	if gathered and not _started:
		_started = true
		_routes["Mara"] = [Vector2(2, 0), Vector2(16, 0), Vector2(26, 0), Vector2(28, 0.6)]
	if gathered and flags.get("gate_open", false) and not _gate_open:
		_gate_open = true
		_routes["Ivo"] = [Vector2(27, -2)]

func follow_after_battle(player: Node3D, mara_at: Vector3, ivo_at: Vector3) -> void:
	# Explicit encounter scene transfer. The next steps occur in this same world.
	_actors.Mara.position = mara_at
	_actors.Ivo.position = ivo_at
	_routes = {"Mara": [], "Ivo": []}
	_started = true
	_gate_open = true
	_following = true
	_portal.clear()
	_last_trail = Vector2(player.position.x, player.position.z)
	_routes.Mara.append(_last_trail)
	_ground(_actors.Mara)
	_ground(_actors.Ivo)

func transfer_through_door(entrance: Vector3, exit: Vector3) -> void:
	if not _following: return
	if (_actors.Mara.position.x > 120) != (entrance.x > 120):
		# Player doubled back before Mara crossed: she stays in the current area.
		_portal.clear()
		_routes.Mara.append(Vector2(exit.x, exit.z))
		_last_trail = Vector2(exit.x, exit.z)
		return
	# Mara must reach the entrance before crossing the same portal as the player.
	_routes.Mara.append(Vector2(entrance.x, entrance.z))
	_portal = {"entrance": entrance, "exit": exit}

func finish_at_quay() -> void:
	# The ending explicitly cuts from the office to the quay after buying oil.
	_following = false
	_routes.Mara = []
	_portal.clear()
	_actors.Mara.transform = _homes.Mara
	_actors.Mara.get_node("ModelSlot").locomotion_speed = 0.0
	_ground(_actors.Mara)

func advance(delta: float, speaking: Node3D, player: Node3D) -> void:
	if _following and _portal.is_empty():
		var point := Vector2(player.position.x, player.position.z)
		if point.distance_to(_last_trail) >= .45:
			_routes.Mara.append(point)
			_last_trail = point
	for id in _actors:
		var actor: Node3D = _actors[id]
		var slot := actor.get_node("ModelSlot")
		slot.locomotion_speed = 0.0
		var route: Array = _routes.get(id, [])
		if route.is_empty() or actor == speaking: continue
		var at := Vector2(actor.position.x, actor.position.z)
		var player_at := Vector2(player.position.x, player.position.z)
		# Keep a short trail, including corners, rather than cutting through walls.
		if id == "Mara" and _following and _portal.is_empty() and route.size() <= 4 and at.distance_to(player_at) < 1.7:
			continue
		var direction: Vector2 = (route[0] - at).normalized()
		# These exploration meshes face +Z; combat's ModelSlot rotates them by PI.
		var heading := atan2(direction.x, direction.y)
		actor.rotation.y = rotate_toward(actor.rotation.y, heading, delta * 5.0)
		var facing := Vector2(sin(actor.rotation.y), cos(actor.rotation.y))
		var turn_weight := maxf(0.0, facing.dot(direction))
		var step := minf((4.6 if _following and id == "Mara" else 3.2) * delta * turn_weight, at.distance_to(route[0]))
		var next := at + direction * step
		if next.distance_to(player_at) < .85 and at.distance_to(player_at) > next.distance_to(player_at): continue
		actor.position.x = next.x
		actor.position.z = next.y
		_ground(actor)
		slot.locomotion_speed = step / maxf(delta, .001)
		if next.distance_to(route[0]) < .04:
			route.pop_front()
			if route.is_empty():
				slot.locomotion_speed = 0.0
				if id == "Mara" and not _portal.is_empty():
					actor.position = _portal.exit
					_ground(actor)
					_portal.clear()
					_last_trail = Vector2(player.position.x, player.position.z)
					route.append(_last_trail)
				elif not _following:
					actor.rotation.y = PI / 2.0

func _ground(actor: Node3D) -> void:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 2, actor.global_position + Vector3.DOWN * 4)
	var exclusions: Array[RID] = [_root.player.get_rid()]
	for a in _actors.values(): exclusions.append(a.get_node("Collider").get_rid())
	query.exclude = exclusions
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Roots use a one-metre capsule centre, with the imported soles at its base.
		actor.position.y = hit.position.y + 1.0

func assembled() -> bool:
	return _started and _gate_open and _routes.get("Mara", []).is_empty() and _routes.get("Ivo", []).is_empty()

func is_travelling_companion(actor: Node3D) -> bool:
	if actor == _actors.get("Mara"):
		return _following or not _routes.get("Mara", []).is_empty()
	return actor == _actors.get("Ivo") and not _routes.get("Ivo", []).is_empty()

func snapshot() -> Dictionary:
	var actors := {}
	var routes := {}
	for id in _actors:
		var a: Node3D = _actors[id]
		actors[id] = [a.position.x, a.position.y, a.position.z, a.rotation.y]
		routes[id] = []
		for p in _routes.get(id, []): routes[id].append([p.x, p.y])
	var portal := {}
	for key in _portal:
		var p: Vector3 = _portal[key]
		portal[key] = [p.x, p.y, p.z]
	return {"actors": actors, "routes": routes, "started": _started, "gate_open": _gate_open, "following": _following, "portal": portal}

static func valid_snapshot(data: Dictionary) -> bool:
	if data.is_empty(): return true # Older saves derive a safe scene entry.
	for key in ["actors", "routes", "portal"]:
		if not data.get(key) is Dictionary: return false
	for key in ["started", "gate_open", "following"]:
		if not data.get(key) is bool: return false
	if data.actors.size() != 2 or data.routes.size() != 2: return false
	for id in ["Mara", "Ivo"]:
		if not _numbers(data.actors.get(id), 4): return false
		if not data.routes.get(id) is Array or data.routes[id].size() > 4096: return false
		for point in data.routes[id]:
			if not _numbers(point, 2): return false
	if not data.portal.is_empty():
		if data.portal.size() != 2: return false
		for key in ["entrance", "exit"]:
			if not _numbers(data.portal.get(key), 3): return false
	return true

static func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for n in value:
		if typeof(n) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(n)) or absf(float(n)) > 1000: return false
	return true

func restore(data: Dictionary, flags: Dictionary, player: Node3D) -> void:
	if not valid_snapshot(data): return
	if data.is_empty():
		# Loading an older save must also discard travel from the current game.
		_started = false
		_gate_open = false
		_following = false
		_portal.clear()
		_routes.clear()
		for id in _actors:
			_actors[id].transform = _homes[id]
			_actors[id].get_node("ModelSlot").locomotion_speed = 0.0
		reconcile(flags)
		if flags.get("pay_recovered", false) and not flags.get("pay_returned", false):
			follow_after_battle(player, player.position + Vector3(0, 0, 1.6), Vector3(48, 1.6, -2))
		elif flags.get("pay_returned", false):
			finish_at_quay()
			_routes.Ivo = []
			_actors.Ivo.position = Vector3(27, 1, -2)
			_ground(_actors.Ivo)
		return
	_started = data.started
	_gate_open = data.gate_open
	_following = data.following
	_portal.clear()
	for key in data.portal:
		var p: Array = data.portal[key]
		_portal[key] = Vector3(p[0], p[1], p[2])
	for id in _actors:
		var p: Array = data.actors[id]
		_actors[id].position = Vector3(p[0], p[1], p[2])
		_actors[id].rotation.y = p[3]
		_routes[id] = []
		for point in data.routes[id]: _routes[id].append(Vector2(point[0], point[1]))
	_last_trail = Vector2(player.position.x, player.position.z)
