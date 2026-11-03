extends RefCounted
## Deterministic host geometry adapter. Both collision shapes and route queries
## use this authored footprint of the imported garden. It owns no combat rules.
const PATH := "res://content/command_garden.json"
var geometry: Dictionary
var sequence := 0

func _init() -> void:
	geometry = JSON.parse_string(FileAccess.get_file_as_string(PATH))

func _v(point: Array) -> Vector2:
	return Vector2(float(point[0]), float(point[1]))

func _rect(obstacle: Dictionary, radius := 0.0) -> Rect2:
	var size := _v(obstacle.size)
	return Rect2(_v(obstacle.center) - size * .5, size).grow(radius)

func _over_floor(point: Vector2) -> bool:
	for floor in geometry.walkable:
		if point.x >= floor.min[0] and point.x <= floor.max[0] and point.y >= floor.min[1] and point.y <= floor.max[1]:
			return true
	return false

func walkable(point: Vector2, radius := 0.35) -> bool:
	for offset in [Vector2.ZERO, Vector2(radius, radius), Vector2(-radius, radius), Vector2(radius, -radius), Vector2(-radius, -radius)]:
		if not _over_floor(point + offset):
			return false
	for obstacle in geometry.obstacles:
		if _rect(obstacle, radius).has_point(point):
			return false
	return true

func _crosses_rect(from: Vector2, to: Vector2, rectangle: Rect2) -> bool:
	# Slab intersection includes edges so routes never skim through a planter.
	var direction := to - from
	var near := 0.0
	var far := 1.0
	for axis in range(2):
		if absf(direction[axis]) < .00001:
			if from[axis] < rectangle.position[axis] or from[axis] > rectangle.end[axis]:
				return false
		else:
			var first := (rectangle.position[axis] - from[axis]) / direction[axis]
			var last := (rectangle.end[axis] - from[axis]) / direction[axis]
			near = maxf(near, minf(first, last))
			far = minf(far, maxf(first, last))
			if near > far:
				return false
	return true

func line_clear(from: Vector2, to: Vector2, radius := 0.0, require_floor := false) -> bool:
	for obstacle in geometry.obstacles:
		if _crosses_rect(from, to, _rect(obstacle, radius)):
			return false
	if require_floor:
		var samples := maxi(1, ceili(from.distance_to(to) / .20))
		for index in range(samples + 1):
			if not walkable(from.lerp(to, float(index) / samples), radius):
				return false
	return true

func route(from: Vector2, to: Vector2, radius := 0.35) -> Array:
	if not walkable(from, radius) or not walkable(to, radius):
		return []
	if line_clear(from, to, radius, true):
		return [from, to]
	var points: Array[Vector2] = [from, to]
	for obstacle in geometry.obstacles:
		var bounds := _rect(obstacle, radius + .015)
		for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
			if walkable(point, radius):
				points.append(point)
	for portal in geometry.portals:
		if walkable(_v(portal), radius):
			points.append(_v(portal))
	var graph := AStar2D.new()
	for index in range(points.size()):
		graph.add_point(index, points[index])
	for first in range(points.size()):
		for last in range(first + 1, points.size()):
			if line_clear(points[first], points[last], radius, true):
				graph.connect_points(first, last)
	var result: Array = []
	for point in graph.get_point_path(0, 1):
		result.append(point)
	return result

func height_at(point: Vector2) -> float:
	if point.x < -4.59:
		return lerpf(-.578, 0.0, clampf((point.x + 8.33) / 3.74, 0, 1))
	return 0.0

func frame(requests: Array, next_sequence := "") -> Dictionary:
	if requests.is_empty():
		return {}
	sequence = int(next_sequence) if next_sequence != "" else sequence + 1
	var first: Dictionary = requests[0]
	var result := {"generation": first.generation, "geometry_revision": geometry.revision,
		"tick": first.tick, "state_revision": first.state_revision,
		"producer_id": "godot-garden", "sequence": str(sequence), "results": []}
	for request in requests:
		var from := _v(request.from_mm) / 1000.0
		var to := _v(request.to_mm) / 1000.0
		var radius := float(request.radius_mm) / 1000.0
		var answer := {"request_id": request.id, "valid": true, "reason_code": null,
			"position_mm": null, "visible": null, "clear": null, "path_mm": [], "ground_height_mm": null}
		if request.geometry_revision != geometry.revision or request.tick != first.tick or request.state_revision != first.state_revision or request.generation != first.generation:
			answer.valid = false
			answer.reason_code = "stale_geometry_request"
		else:
			match str(request.kind):
				"path":
					for point in route(from, to, radius):
						answer.path_mm.append([roundi(point.x * 1000), roundi(point.y * 1000)])
					answer.clear = not answer.path_mm.is_empty()
				"los", "visibility":
					answer.clear = line_clear(from, to)
					answer.visible = answer.clear and from.distance_to(to) <= float(request.maximum_distance_mm) / 1000.0
				"swept_path": answer.clear = line_clear(from, to, radius, true)
				"pose": answer.position_mm = request.to_mm if walkable(to, radius) else null
				"ground": answer.ground_height_mm = roundi(height_at(to) * 1000) if walkable(to, radius) else null
				_:
					answer.valid = false
					answer.reason_code = "unknown_geometry_query"
		result.results.append(answer)
	return result
