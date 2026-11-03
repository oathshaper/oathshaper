extends Control

signal quest_selected

## North-up plan of the quay floor rectangles and fitted imported garden.
## World +X is east, world -Z north. Tests compare the scene floor bounds
## and transformed planter positions with this drawing.

const GardenLayout = preload("res://scripts/garden_layout.gd")

const COMPACT_SIZE := Vector2(260.0, 190.0)
const EXPANDED_SIZE := Vector2(540.0, 380.0)

const QUAY_MIN := Vector2(-35.0, -32.0)
const QUAY_MAX := Vector2(65.0, 13.0)
const OFFICE_MIN := Vector2(153.5, -29.5)
const OFFICE_MAX := Vector2(166.5, -17.0)

# Each row mirrors _build_ground() in hub_environment.gd: name, x, z, width,
# depth, and surface kind. Rectangles are exact world metre footprints; unlike
# the previous illustrative map, every link is orthogonal and traversable.
const QUAY_SURFACES := [
	["CentralQuay", -8.0, -8.0, 16.0, 16.0, "quay"],
	["WestMarket", -28.0, -8.0, 16.0, 16.0, "market"],
	["CivicCourt", -10.0, -30.0, 20.0, 16.0, "court"],
	["EastBluff", 14.0, -12.0, 16.0, 20.0, "bluff"],
	["LanternGarden", 38.0, -14.0, 24.0, 20.0, "garden"],
	["MarketBridge", -12.0, -2.0, 4.0, 6.0, "bridge"],
	["CourtSteps", -2.0, -14.0, 4.0, 6.0, "bridge"],
	["BluffBridge", 8.0, -2.0, 6.0, 6.0, "bridge"],
	["MarketCourtAlley", -22.0, -22.0, 4.0, 14.0, "bridge"],
	["MarketCourtTurn", -18.0, -22.0, 8.0, 4.0, "bridge"],
	["CourtBluffWalk", 10.0, -20.0, 14.0, 4.0, "bridge"],
	["CourtBluffTurn", 20.0, -20.0, 4.0, 8.0, "bridge"],
	["GardenCauseway", 30.0, -4.0, 8.0, 4.0, "bridge"],
]

# Named collision footprints from _build_district_details(). The headless
# map test checks both their centers and widths against the generated scene.
const QUAY_FEATURES := [
	["MarketHouseWest", -31.1, 1.0, 5.0, 8.0, "roof"],
	["MarketHouseNorth", -25.2, -10.7, 5.5, 4.0, "roof"],
	["CourtArchiveWest", -12.3, -26.0, 4.1, 7.0, "roof"],
	["CourtArchiveEast", 12.4, -27.0, 4.3, 6.0, "roof"],
	["MarketStallA", -24.5, 4.8, 3.3, 2.0, "stall"],
	["MarketStallB", -16.1, 5.2, 2.8, 2.0, "stall"],
	["BluffRockNorth", 26.5, -14.2, 7.0, 3.8, "rock"],
	["BluffRockSouth", 26.5, 10.0, 6.0, 4.0, "rock"],
	["MooringCrateWest", -6.3, 5.5, 1.1, 1.1, "stall"],
	["MooringCrateEast", 6.2, -5.2, 1.2, 1.2, "stall"],
]

# Mesh fit shared with its collision, including the slight bridge alignment.
const GARDEN_BEDS := GardenLayout.BEDS

const CLERK_POINT := Vector2(0.0, -18.0)
const RECORDS_DOOR_POINT := Vector2(-10.1, -26.0)
const CABINET_POINT := Vector2(156.8, -27.5)
const DESK_POINT := Vector2(163.0, -26.5)
const TOWER_POINT := Vector2(0.0, -23.0)
const TOWER_FOOTPRINT_WIDTH := 5.2

const INK := Color("#101c28")
const FRAME := Color("#c9ae76")
const PARCHMENT := Color("#f3e9cc")
const MUTED := Color("#bdc9c3")
const WATER := Color("#204156")
const ROAD := Color("#b9a98b")
const STONE := Color("#687775")
const GARDEN := Color("#577762")
const MARKET := Color("#927964")
const COURT := Color("#aaa08b")
const BLUFF := Color("#b8b4a5")
const ROOF := Color("#354451")
const PLAYER := Color("#9ce8e2")
const OBJECTIVE := Color("#ffdb72")
const COMPLETE := Color("#a9dca8")

var _player_position := Vector3.ZERO
var _area := "quay"
var _waypoint_id := ""
var _flags: Dictionary = {}
var _expanded := false
var _location_hint := ""
var _quay_edges: Array[Vector2] = []
var _footer_hovered := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_mouse_exited)
	custom_minimum_size = desired_size()
	size = desired_size()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _footer_rect().has_point(event.position)
		if hovered != _footer_hovered:
			_footer_hovered = hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _footer_rect().has_point(event.position):
		quest_selected.emit()
		accept_event()


func _on_mouse_exited() -> void:
	_footer_hovered = false
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()


func _footer_rect() -> Rect2:
	var height := 48.0 if _expanded else 30.0
	return Rect2(0.0, desired_size().y - height, desired_size().x, height)


func set_map_state(player_position: Vector3, area: String, waypoint_id: String, flags: Dictionary, location_hint: String = "") -> void:
	_player_position = player_position
	_area = area if area == "records_office" else "quay"
	_waypoint_id = waypoint_id
	_flags = flags.duplicate()
	_location_hint = location_hint
	queue_redraw()


func set_expanded(expanded: bool) -> void:
	_expanded = expanded
	custom_minimum_size = desired_size()
	size = desired_size()
	queue_redraw()


func desired_size() -> Vector2:
	return EXPANDED_SIZE if _expanded else COMPACT_SIZE


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, desired_size())
	draw_rect(outer, INK)
	draw_rect(outer.grow(-1.0), FRAME, false, 2.0)
	var font := get_theme_default_font()
	var large := _expanded
	var location_lines := _location_text().split("\n", false)
	var title := location_lines[0]
	var guidance := location_lines[1] if location_lines.size() > 1 else ""
	var inset := 20.0 if large else 12.0
	var title_size := 19 if large else 15
	var guidance_size := 15 if large else 12
	draw_string(font, Vector2(inset, 29.0 if large else 23.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, PARCHMENT)
	draw_string(font, Vector2(inset, 52.0 if large else 43.0), guidance,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, guidance_size, MUTED)
	var map_rect := Rect2(Vector2(20.0, 67.0), Vector2(500.0, 264.0)) if large \
		else Rect2(Vector2(12.0, 53.0), Vector2(236.0, 107.0))
	draw_rect(map_rect, WATER)
	if _area == "records_office":
		_draw_office(map_rect, large)
	else:
		_draw_quay(map_rect, large)
	draw_rect(map_rect, FRAME.darkened(0.15), false, 1.0)
	draw_rect(Rect2(map_rect.end - Vector2(37.0 if large else 30.0, map_rect.size.y), Vector2(37.0 if large else 30.0, 24.0 if large else 17.0)), INK)
	draw_string(font, map_rect.position + Vector2(map_rect.size.x - (29.0 if large else 24.0), 18.0 if large else 13.0), "N ↑",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14 if large else 11, OBJECTIVE)
	_draw_footer(font, large, outer.size.y)


func _location_text() -> String:
	if _location_hint.contains("\n"):
		return _location_hint
	if _area == "records_office":
		return "CIVIC RECORDS OFFICE\nRecords recovered · exit south" if bool(_flags.get("records_collected", false)) else "CIVIC RECORDS OFFICE\nCabinet northwest · exit south"
	var at := _player_position
	if at.x > 33.0:
		return "LANTERN GARDEN\nTower west · tide gate behind"
	if at.x > 12.0:
		return "EAST BLUFF\nIvo east · tower northwest"
	if at.x < -12.0:
		return "WEST MARKET\nQuay east · old way north"
	if at.z < -12.0:
		return "CIVIC COURT\nTower ahead · quay south"
	return "CENTRAL QUAY\nTower north · market west · gate east"


func _draw_quay(rect: Rect2, large: bool) -> void:
	var view := _fit_world_rect(rect, QUAY_MIN, QUAY_MAX)
	# Quay surfaces use the generated cells; the garden uses its fitted art outline.
	for surface in QUAY_SURFACES:
		if surface[0] in ["LanternGarden", "GardenCauseway"]:
			continue
		var area := _surface_area(surface)
		var color := _surface_color(surface[5])
		var a := _map_point(view, area.position, QUAY_MIN, QUAY_MAX)
		var b := _map_point(view, area.end, QUAY_MIN, QUAY_MAX)
		draw_rect(Rect2(a, b - a), color)
	_draw_garden_plan(view, large)
	_draw_quay_perimeter(view, large)
	# Roofs, stalls, crates and rocks occupy their actual collision footprints.
	for feature in QUAY_FEATURES:
		var color := ROOF
		match feature[5]:
			"stall": color = ROOF.lightened(0.12)
			"rock": color = STONE.darkened(0.28)
		_draw_footprint(view, Vector2(feature[1], feature[2]), Vector2(feature[3], feature[4]), color)
	_draw_tower(view, large)
	# The door is on the east face of the western archive. The two barriers
	# cross actual straight corridors; gold means open, dark means closed.
	var door := _quay_point(view, RECORDS_DOOR_POINT)
	draw_line(door + Vector2(0.0, -3.0 if large else -1.5),
		 door + Vector2(0.0, 3.0 if large else 1.5), OBJECTIVE, 2.0)
	_draw_gate(view, Vector2(-21.85, -12.0), Vector2(-18.15, -12.0), bool(_flags.get("shortcut_open", false)), large)
	_draw_gate(view, Vector2(32.0, -3.85), Vector2(32.0, -0.15), bool(_flags.get("gate_open", false)), large)
	if large:
		_district_label(view, Vector2(-20.0, 0.0), "MARKET")
		_district_label(view, Vector2(0.0, 4.0), "QUAY")
		_district_label(view, Vector2(0.0, -28.0), "CIVIC COURT")
		_district_label(view, Vector2(18.0, 4.5), "EAST BLUFF")
	var player_world := Vector2(_player_position.x, _player_position.z)
	match _waypoint_id:
		"mara":
			_draw_waypoint(_quay_point(view, Vector2(28, .6) if _flags.get("gate_open", false) else Vector2(0, -1)), large)
		"pay_loot":
			var chest := preload("res://scripts/payroll_pouch.gd").quay_position()
			_draw_waypoint(_quay_point(view, Vector2(chest.x, chest.z)), large)
		"clerk", "return_pay":
			_draw_waypoint(door, large)
		"records_door":
			_draw_waypoint(door, large)
		"garden_gate":
			_draw_waypoint(_quay_point(view, Vector2(25, -2)), large)
		"garden":
			_draw_waypoint(_quay_point(view, Vector2(31, -2)), large)
	_draw_player_on_map(view, player_world, QUAY_MIN, QUAY_MAX, large)


func _draw_garden_plan(view: Rect2, large: bool) -> void:
	# Draw the fitted stone footprint, not the hidden coarse fallback slab.
	var outline := PackedVector2Array([Vector2(30, -4), Vector2(39.7, -4), Vector2(39.7, 0), Vector2(30, 0)])
	_draw_garden_polygon(view, outline, ROAD, large)
	_draw_garden_polygon(view, GardenLayout.polygon(GardenLayout.TERRACE), STONE.lightened(0.25), large)
	for path in GardenLayout.PATHS:
		_draw_garden_polygon(view, GardenLayout.polygon(path), STONE.lightened(0.43), false, false)
	for bed in GARDEN_BEDS:
		var half := Vector2(bed[3], bed[4]) * 0.5
		_draw_garden_polygon(view, GardenLayout.polygon(Rect2(Vector2(bed[1], bed[2]) - half, half * 2.0)), GARDEN.darkened(0.20), large)


func _draw_garden_polygon(view: Rect2, world: PackedVector2Array, color: Color, large: bool, outline: bool = true) -> void:
	var pixels := PackedVector2Array()
	for point in world:
		pixels.append(_quay_point(view, point))
	draw_colored_polygon(pixels, color)
	if outline:
		pixels.append(pixels[0])
		draw_polyline(pixels, FRAME, 1.5 if large else 1.0, true)


func _draw_office(rect: Rect2, large: bool) -> void:
	# The roofless archive is 12 x 10 metres, with a south landing.
	var view := _fit_world_rect(rect.grow(-7.0), OFFICE_MIN, OFFICE_MAX)
	var northwest := _map_point(view, Vector2(154.0, -29.0), OFFICE_MIN, OFFICE_MAX)
	var southeast := _map_point(view, Vector2(166.0, -19.0), OFFICE_MIN, OFFICE_MAX)
	var room := Rect2(northwest, southeast - northwest)
	draw_rect(room, Color("#8f8b78"))
	var landing_a := _map_point(view, Vector2(158.4, -19.0), OFFICE_MIN, OFFICE_MAX)
	var landing_b := _map_point(view, Vector2(161.6, -17.5), OFFICE_MIN, OFFICE_MAX)
	draw_rect(Rect2(landing_a, landing_b - landing_a), ROAD)
	draw_rect(room, Color("#e0cc9b"), false, 3.0 if large else 1.5)
	var wall_width := 5.0 if large else 2.0
	var entrance := _map_point(view, Vector2(160.0, -19.0), OFFICE_MIN, OFFICE_MAX)
	draw_line(Vector2(entrance.x - (16.0 if large else 6.0), room.end.y),
		Vector2(entrance.x + (16.0 if large else 6.0), room.end.y), ROAD, wall_width)
	# Cabinet and desk silhouettes are readable at both sizes.
	var cabinet := _map_point(view, CABINET_POINT, OFFICE_MIN, OFFICE_MAX)
	var cabinet_size := Vector2(30.0, 15.0) if large else Vector2(12.0, 6.0)
	draw_rect(Rect2(cabinet - cabinet_size * 0.5, cabinet_size), Color("#293946"))
	draw_rect(Rect2(cabinet - cabinet_size * 0.5, cabinet_size), FRAME, false, 2.0 if large else 1.0)
	var desk := _map_point(view, DESK_POINT, OFFICE_MIN, OFFICE_MAX)
	var desk_size := Vector2(47.0, 22.0) if large else Vector2(19.0, 9.0)
	draw_rect(Rect2(desk - desk_size * 0.5, desk_size), Color("#554b3b"))
	if large:
		_draw_text(entrance + Vector2(20.0, 16.0), "ENTRY", 14, PARCHMENT)
		_draw_text(desk + Vector2(-18.0, 25.0), "DESK", 13, PARCHMENT)
	if _waypoint_id in ["done", "robbery_done"]:
		_draw_complete(cabinet, large)
	elif _waypoint_id in ["clerk", "return_pay"]:
		_draw_waypoint(_map_point(view, Vector2(162.1, -25.1), OFFICE_MIN, OFFICE_MAX), large)
	elif _waypoint_id == "cabinet":
		_draw_waypoint(cabinet, large)
	_draw_player_on_map(view, Vector2(_player_position.x, _player_position.z), OFFICE_MIN, OFFICE_MAX, large)


func _surface_area(surface: Array) -> Rect2:
	return Rect2(float(surface[1]), float(surface[2]), float(surface[3]), float(surface[4]))


func _surface_bounds() -> Dictionary:
	var result := {}
	for surface in QUAY_SURFACES:
		result[surface[0]] = _surface_area(surface)
	return result


func _surface_color(kind: String) -> Color:
	match kind:
		"market": return MARKET
		"court": return COURT
		"bluff": return BLUFF
		"garden": return GARDEN
		"bridge": return ROAD
	return STONE


func _fit_world_rect(canvas: Rect2, bounds_min: Vector2, bounds_max: Vector2) -> Rect2:
	# One world metre always has the same pixel scale on both axes.
	var world_size := bounds_max - bounds_min
	var pixels_per_metre := minf(canvas.size.x / world_size.x, canvas.size.y / world_size.y)
	var size := world_size * pixels_per_metre
	return Rect2(canvas.position + (canvas.size - size) * 0.5, size)


func _quay_point(view: Rect2, world: Vector2) -> Vector2:
	return _map_point(view, world, QUAY_MIN, QUAY_MAX)


func _draw_quay_perimeter(view: Rect2, large: bool) -> void:
	if _quay_edges.is_empty():
		_build_quay_edges()
	var edge_color := Color("#d9c8a2")
	for index in range(0, _quay_edges.size(), 2):
		if (_quay_edges[index].x + _quay_edges[index + 1].x) * 0.5 > 30.01:
			continue
		draw_line(_quay_point(view, _quay_edges[index]), _quay_point(view, _quay_edges[index + 1]),
			edge_color, 1.5 if large else 1.0)


func _build_quay_edges() -> void:
	var cells := {}
	for surface in QUAY_SURFACES:
		var area := _surface_area(surface)
		for x in range(int(area.position.x), int(area.end.x), 2):
			for z in range(int(area.position.y), int(area.end.y), 2):
				cells[Vector2i(x, z)] = true
	for cell in cells:
		var x: float = float(cell.x)
		var z: float = float(cell.y)
		if not cells.has(cell + Vector2i(0, -2)):
			_quay_edges.append_array([Vector2(x, z), Vector2(x + 2.0, z)])
		if not cells.has(cell + Vector2i(0, 2)):
			_quay_edges.append_array([Vector2(x, z + 2.0), Vector2(x + 2.0, z + 2.0)])
		if not cells.has(cell + Vector2i(-2, 0)):
			_quay_edges.append_array([Vector2(x, z), Vector2(x, z + 2.0)])
		if not cells.has(cell + Vector2i(2, 0)):
			_quay_edges.append_array([Vector2(x + 2.0, z), Vector2(x + 2.0, z + 2.0)])


func _draw_footprint(view: Rect2, center: Vector2, size: Vector2, color: Color) -> void:
	var a := _quay_point(view, center - size * 0.5)
	var b := _quay_point(view, center + size * 0.5)
	var outline := Rect2(a, b - a)
	draw_rect(outline, color)
	draw_rect(outline, FRAME, false, 1.0)


func _draw_tower(view: Rect2, large: bool) -> void:
	var center := _quay_point(view, TOWER_POINT)
	var radius := (_quay_point(view, TOWER_POINT + Vector2(TOWER_FOOTPRINT_WIDTH * 0.5, 0.0)).x - center.x)
	draw_circle(center, radius, ROOF)
	draw_arc(center, radius, 0.0, TAU, 24, FRAME, 1.5 if large else 1.0)
	if large:
		_draw_text(center + Vector2(8.0, -9.0), "TOWER", 11, PARCHMENT)


func _draw_gate(view: Rect2, a: Vector2, b: Vector2, open: bool, large: bool) -> void:
	var color := OBJECTIVE if open else INK
	var from := _quay_point(view, a)
	var to := _quay_point(view, b)
	draw_line(from, to, color, 4.0 if large else 2.5)
	if not open:
		draw_line(from, to, FRAME, 1.2 if large else 0.8)


func _map_point(rect: Rect2, world: Vector2, bounds_min: Vector2, bounds_max: Vector2) -> Vector2:
	var x := clampf(inverse_lerp(bounds_min.x, bounds_max.x, world.x), 0.0, 1.0)
	var y := clampf(inverse_lerp(bounds_min.y, bounds_max.y, world.y), 0.0, 1.0)
	return rect.position + Vector2(x * rect.size.x, y * rect.size.y)


func _draw_player_on_map(rect: Rect2, world: Vector2, bounds_min: Vector2, bounds_max: Vector2, large: bool) -> void:
	var point := _map_point(rect, world, bounds_min, bounds_max)
	if _is_in_bounds(world, bounds_min, bounds_max):
		_draw_player(point, large)
		return
	# Keep the marker inside the frame and use an arrow when the player is outside
	# the mapped room or district. A clamped dot would imply a false position.
	point.x = clampf(point.x, rect.position.x + 9.0, rect.end.x - 9.0)
	point.y = clampf(point.y, rect.position.y + 9.0, rect.end.y - 9.0)
	var direction := Vector2(0.0, 0.0)
	if world.x < bounds_min.x:
		direction.x = -1.0
	elif world.x > bounds_max.x:
		direction.x = 1.0
	if world.y < bounds_min.y:
		direction.y = -1.0
	elif world.y > bounds_max.y:
		direction.y = 1.0
	direction = direction.normalized()
	var side := Vector2(-direction.y, direction.x)
	var triangle := PackedVector2Array([
		point + direction * 6.0,
		point - direction * 5.0 + side * 4.0,
		point - direction * 5.0 - side * 4.0,
	])
	draw_colored_polygon(triangle, INK)
	draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), PLAYER, 2.0)


func _is_in_bounds(world: Vector2, bounds_min: Vector2, bounds_max: Vector2) -> bool:
	return world.x >= bounds_min.x and world.x <= bounds_max.x and world.y >= bounds_min.y and world.y <= bounds_max.y


func _draw_player(point: Vector2, large: bool) -> void:
	var r := 7.0 if large else 5.0
	draw_circle(point, r + 2.0, INK)
	draw_circle(point, r, PLAYER)
	draw_circle(point, 1.5, INK)


func _draw_waypoint(point: Vector2, large: bool) -> void:
	var r := 9.0 if large else 7.0
	draw_circle(point, r + 2.0, INK)
	draw_circle(point, r, OBJECTIVE)
	draw_circle(point, r - (3.0 if large else 2.0), INK)
	draw_circle(point, 2.0, OBJECTIVE)


func _draw_complete(point: Vector2, large: bool) -> void:
	var radius := 9.0 if large else 7.0
	draw_circle(point, radius + 2.0, INK)
	draw_circle(point, radius, COMPLETE)
	var scale_factor := 1.0 if large else 0.75
	draw_line(point + Vector2(-5.0, 0.0) * scale_factor, point + Vector2(-1.0, 4.0) * scale_factor, INK, 2.5)
	draw_line(point + Vector2(-1.0, 4.0) * scale_factor, point + Vector2(6.0, -4.0) * scale_factor, INK, 2.5)


func _district_label(rect: Rect2, world: Vector2, label: String) -> void:
	var point := _map_point(rect, world, QUAY_MIN, QUAY_MAX)
	var font := get_theme_default_font()
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	var box := Rect2(Vector2(point.x - width * 0.5 - 4.0, point.y - 13.0), Vector2(width + 8.0, 17.0))
	draw_rect(box, INK.darkened(0.06))
	draw_string(font, Vector2(point.x - width * 0.5, point.y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, PARCHMENT)


func _draw_text(point: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), point + Vector2(1.0, 1.0), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, INK)
	draw_string(get_theme_default_font(), point, value,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)


func _draw_footer(font: Font, large: bool, height: float) -> void:
	var label := _waypoint_label()
	var baseline := height - (20.0 if large else 10.0)
	var font_size := 16 if large else 12
	var icon_at := Vector2(26.0 if large else 18.0, baseline - 4.0)
	var color := COMPLETE if _waypoint_id in ["done", "robbery_done"] else OBJECTIVE
	draw_rect(_footer_rect(), Color("#203039") if _footer_hovered else Color("#17232d"))
	draw_line(Vector2(1.0, _footer_rect().position.y), Vector2(desired_size().x - 1.0, _footer_rect().position.y), color.darkened(0.3), 1.0)
	if _waypoint_id in ["done", "robbery_done"]:
		_draw_complete(icon_at, false)
	else:
		draw_circle(icon_at, 4.0 if large else 3.0, OBJECTIVE)
	draw_string(font, Vector2(36.0 if large else 31.0, baseline), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
	if large:
		var legend := "YOU · GOAL" if _waypoint_id != "done" else "YOU · DONE"
		draw_string(font, Vector2(434.0, baseline), legend,
			HORIZONTAL_ALIGNMENT_RIGHT, 85.0, 12, MUTED)
	else:
		draw_string(font, Vector2(236.0, baseline), "›", HORIZONTAL_ALIGNMENT_RIGHT, 12.0, font_size, color)


func _waypoint_label() -> String:
	match _waypoint_id:
		"mara": return "SPEAK TO MARA"
		"pay_loot": return "SEARCH THE RAIDER"
		"return_pay": return "RETURN TO THE CLERK"
		"garden_gate":
			return "SPEAK TO IVO"
		"garden":
			return "ENTER LANTERN GARDEN"
		"robbery_done":
			return "PAY RETURNED"
		"clerk":
			return "FIND THE CIVIC CLERK"
		"records_door":
			return "RECORDS DOOR"
		"cabinet":
			return "OLD RECORDS"
		"done":
			return "RECORDS FOUND"
	return "EXPLORE THE QUAY"
