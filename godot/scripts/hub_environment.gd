extends Node3D
## Runtime-built, original blockout for the Lantern Quay district.
## All coordinates are metres; +X is east and -Z is north.

const CELL := 2
const WATER_SIZE := Vector3(1600.0, 0.12, 1000.0) # Collision-free visual sea only.
const TOWER_GLB := "res://assets/meshes/lantern_tower_civic.glb"
const GardenLayout = preload("res://scripts/garden_layout.gd")
const GARDEN_GLB := "res://assets/meshes/garden_optimized.glb"
const PLANK_TILE_METRES := 4.0
const MASONRY_TILE_METRES := 2.0
const SEAWALL_TILE_METRES := 5.0
const ROPE_TILE_METRES := 0.75
const TOWER_ATLAS_SIZE := 2048.0

# Adjust in the Inspector for replacement GLBs with different source units.
# These defaults fit the shorter civic derivative of the Stonewatch Beacon.
# Its door/plinth is raised 18%; the long shaft is compressed to keep height.
@export var tower_model_scale := Vector3(13.0, 15.0, 11.0)
@export var tower_model_offset := Vector3(0.0, 7.13745, 0.0)
# Mesh and collision share GardenLayout's measured entrance fit. Keep replacement
# asset adjustments there so art, walls and minimap cannot drift independently.

var _materials: Dictionary = {}
var _walkable: Dictionary = {}
var _unit_box: BoxMesh
var _tree_canopy: SphereMesh
var _garden_floor_visual: MeshInstance3D
var _garden_causeway_visual: MeshInstance3D
var _garden_imported := false
var _gate_barrier: StaticBody3D
var _shortcut_barrier: StaticBody3D
var _gate_open := false
var _shortcut_open := false


func _ready() -> void:
	_make_materials()
	_build_ground()
	_build_district_details()
	_build_perimeter()
	_build_records_door()
	_build_tower()
	_build_gateways()
	_build_horizon()
	_update_barriers()


func set_gate_open(open: bool) -> void:
	_gate_open = open
	_update_barriers()


func set_shortcut_open(open: bool) -> void:
	_shortcut_open = open
	_update_barriers()


func is_gate_open() -> bool:
	return _gate_open


func is_shortcut_open() -> bool:
	return _shortcut_open


func _make_materials() -> void:
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_tree_canopy = SphereMesh.new()
	_tree_canopy.radius = 1.2
	_tree_canopy.height = 2.0
	var planks: Texture2D = load("res://assets/textures/materials/dock_planks_albedo.png")
	var pavers: Texture2D = load("res://assets/textures/materials/limestone_pavers_albedo.png")
	var seawall: Texture2D = load("res://assets/textures/materials/seawall_masonry_albedo.png")
	var foliage: Texture2D = load("res://assets/textures/materials/coastal_foliage_albedo.png")
	var bark: Texture2D = load("res://assets/textures/materials/coastal_bark_albedo.png")
	var rope: Texture2D = load("res://assets/textures/materials/braided_rope_albedo.png")
	var timber: Texture2D = load("res://assets/textures/materials/weathered_timber_albedo.png")
	var rock: Texture2D = load("res://assets/textures/materials/coastal_rock_albedo.png")
	var roof: Texture2D = load("res://assets/textures/materials/slate_roof_albedo.png")
	var grass: Texture2D = load("res://assets/textures/materials/grass_soil_albedo.png")
	var lawn: Texture2D = load("res://assets/textures/materials/coastal_grass_albedo.png")
	var canvas: Texture2D = load("res://assets/textures/materials/sailcloth_canvas_albedo.png")
	_materials = {
		"water": _harbor_water_material(),
		"quay": _textured_material("#ffffff", planks),
		"market": _textured_material("#f5ede0", pavers),
		"court": _textured_material("#ffffff", pavers),
		"bluff": _textured_material("#f2f0e9", pavers),
		"garden": _textured_material("#ffffff", lawn),
		"garden_soil": _textured_material("#a69278", grass),
		"garden_path": _textured_material("#d4cbbb", pavers),
		"bridge": _textured_material("#ffffff", planks),
		"pier_wall": _textured_material("#ffffff", seawall),
		"pier_cap": _textured_material("#776a5d", timber),
		"rope": _textured_material("#ffffff", rope),
		"crate": _textured_material("#d4b89a", timber),
		"rock": _textured_material("#b9b9b2", rock),
		"roof": _textured_material("#ffffff", roof),
		"stone": _textured_material("#d8d5cb", pavers),
		"dark_stone": _textured_material("#565f5a", rock),
		"market_wall": _tower_facade_material(Color("#a9b5af")),
		"archive_wall": _tower_facade_material(Color("#f1f0e9")),
		"lantern_wall": _tower_facade_material(Color("#ceae8b")),
		"distant_wall": _tower_facade_material(Color("#8d9a94")),
		"wood": _textured_material("#9a806c", timber),
		"ochre": _textured_material("#b8835f", canvas),
		"indigo": _textured_material("#76778b", canvas),
		"flower_orange": _material("#ce7a4c"),
		"flower_blue": _material("#869ab5"),
		"leaf": _textured_material("#8ea385", foliage),
		"bark": _textured_material("#ffffff", bark),
		"light": _emissive_material("#ffc36a"),
		"distance": _material("#344850"),
		"window_frame": _material("#303638"),
		"window_dark": _material("#2b4348"),
		"window_lit": _emissive_material("#b18a4e"),
		"tower_dark_atlas": _tower_stone_material(Rect2(1089, 1090, 36, 240)),
		"tower_pale_atlas": _tower_stone_material(Rect2(944, 1068, 62, 300)),
	}


func _harbor_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/harbor_water.gdshader")
	return material


func _material(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 1.0
	return material


func _textured_material(hex: String, texture: Texture2D) -> StandardMaterial3D:
	var material := _material(hex)
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


func _tower_stone_material(region_pixels: Rect2) -> ShaderMaterial:
	# These two tall, coherent stone islands come from the supplied tower atlas.
	# Each narrow support uses its island once at approximately source aspect.
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/tower_atlas_stone.gdshader")
	material.set_shader_parameter("tower_base_color", load("res://assets/textures/tower/stonewatch_base_color.jpg"))
	material.set_shader_parameter("atlas_region", Vector4(
		region_pixels.position.x / TOWER_ATLAS_SIZE,
		region_pixels.position.y / TOWER_ATLAS_SIZE,
		region_pixels.size.x / TOWER_ATLAS_SIZE,
		region_pixels.size.y / TOWER_ATLAS_SIZE
	))
	return material


func _tower_facade_material(tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/tower_facade_bricks.gdshader")
	material.set_shader_parameter("tower_base_color", load("res://assets/textures/tower/stonewatch_base_color.jpg"))
	material.set_shader_parameter("stone_tint", tint)
	return material


func _surface_tile(base: StandardMaterial3D, width: float, height: float, metres_per_tile: float) -> StandardMaterial3D:
	return _surface_repeat(base, width / metres_per_tile, height / metres_per_tile)


func _surface_repeat(base: StandardMaterial3D, horizontal_tiles: float, vertical_tiles: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	material.uv1_scale = Vector3(horizontal_tiles, vertical_tiles, 1.0)
	return material


func _emissive_material(hex: String) -> StandardMaterial3D:
	var material := _material(hex)
	material.emission_enabled = true
	material.emission = Color(hex)
	material.emission_energy_multiplier = 2.0
	return material


func _build_ground() -> void:
	var water := MeshInstance3D.new()
	water.name = "HarborWater"
	water.position = Vector3(4.0, -0.43, -12.0)
	water.mesh = _unit_box
	water.scale = WATER_SIZE
	water.material_override = _materials["water"]
	add_child(water)

	var floors := StaticBody3D.new()
	floors.name = "WalkableDistrict"
	add_child(floors)
	# Whole-number, two-metre cells let the generated seawall close every
	# exposed edge while leaving all corridor junctions genuinely open.
	var regions := [
		["CentralQuay", Rect2i(-8, -8, 16, 16), "quay"],
		["WestMarket", Rect2i(-28, -8, 16, 16), "market"],
		["CivicCourt", Rect2i(-10, -30, 20, 16), "court"],
		["EastBluff", Rect2i(14, -12, 16, 20), "bluff"],
		["LanternGarden", GardenLayout.REGION, "garden"],
		["MarketBridge", Rect2i(-12, -2, 4, 6), "bridge"],
		["CourtSteps", Rect2i(-2, -14, 4, 6), "bridge"],
		["BluffBridge", Rect2i(8, -2, 6, 6), "bridge"],
		["MarketCourtAlley", Rect2i(-22, -22, 4, 14), "bridge"],
		["MarketCourtTurn", Rect2i(-18, -22, 8, 4), "bridge"],
		["CourtBluffWalk", Rect2i(10, -20, 14, 4), "bridge"],
		["CourtBluffTurn", Rect2i(20, -20, 4, 8), "bridge"],
		["GardenCauseway", GardenLayout.CAUSEWAY, "bridge"],
	]
	for region in regions:
		_add_floor(floors, region[0], region[1], _materials[region[2]])
		_mark_walkable(region[1])


func _add_floor(parent: StaticBody3D, title: String, area: Rect2i, material: Material) -> void:
	var center := Vector3(area.position.x + area.size.x / 2.0, 0.0, area.position.y + area.size.y / 2.0)
	var size := Vector3(area.size.x, 0.4, area.size.y)
	var floor_visual := MeshInstance3D.new()
	floor_visual.name = title
	floor_visual.position = center
	floor_visual.mesh = _unit_box
	floor_visual.scale = size
	if material == _materials["quay"] or material == _materials["bridge"] or material == _materials["bluff"] or material == _materials["market"] or material == _materials["court"] or material == _materials["garden"]:
		floor_visual.material_override = _surface_tile(material as StandardMaterial3D, size.x, size.z, PLANK_TILE_METRES)
	else:
		floor_visual.material_override = material
	parent.add_child(floor_visual)
	if title == "LanternGarden":
		_garden_floor_visual = floor_visual
	elif title == "GardenCauseway":
		_garden_causeway_visual = floor_visual
	var floor_shape := BoxShape3D.new()
	floor_shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % title
	collision.position = center
	collision.shape = floor_shape
	parent.add_child(collision)


func _mark_walkable(area: Rect2i) -> void:
	for x in range(area.position.x, area.end.x, CELL):
		for z in range(area.position.y, area.end.y, CELL):
			_walkable[Vector2i(x, z)] = true


func _build_perimeter() -> void:
	var horizontal: Dictionary = {}
	var vertical: Dictionary = {}
	for key in _walkable.keys():
		var cell: Vector2i = key
		if not _walkable.has(cell + Vector2i(0, -CELL)):
			_record_edge(horizontal, cell.y, cell.x)
		if not _walkable.has(cell + Vector2i(0, CELL)):
			_record_edge(horizontal, cell.y + CELL, cell.x)
		if not _walkable.has(cell + Vector2i(-CELL, 0)):
			_record_edge(vertical, cell.x, cell.y)
		if not _walkable.has(cell + Vector2i(CELL, 0)):
			_record_edge(vertical, cell.x + CELL, cell.y)

	var edge_body := StaticBody3D.new()
	edge_body.name = "SeawallsAndParapets"
	add_child(edge_body)
	var edge_index := 0
	var horizontal_rows: Array = horizontal.keys()
	horizontal_rows.sort()
	for z in horizontal_rows:
		var starts: Array = horizontal[z]
		starts.sort()
		var run_start: int = starts[0]
		var run_end: int = run_start + CELL
		for i in range(1, starts.size()):
			if starts[i] == run_end:
				run_end += CELL
			else:
				_add_edge(edge_body, "Horizontal%03d" % edge_index, Vector3((run_start + run_end) / 2.0, 0.52, z), Vector3(run_end - run_start, 0.85, 0.34))
				edge_index += 1
				run_start = starts[i]
				run_end = run_start + CELL
		_add_edge(edge_body, "Horizontal%03d" % edge_index, Vector3((run_start + run_end) / 2.0, 0.52, z), Vector3(run_end - run_start, 0.85, 0.34))
		edge_index += 1
	var vertical_rows: Array = vertical.keys()
	vertical_rows.sort()
	for x in vertical_rows:
		var starts: Array = vertical[x]
		starts.sort()
		var run_start: int = starts[0]
		var run_end: int = run_start + CELL
		for i in range(1, starts.size()):
			if starts[i] == run_end:
				run_end += CELL
			else:
				_add_vertical_perimeter_run(edge_body, "Vertical%03d" % edge_index, x, run_start, run_end)
				edge_index += 1
				run_start = starts[i]
				run_end = run_start + CELL
		_add_vertical_perimeter_run(edge_body, "Vertical%03d" % edge_index, x, run_start, run_end)
		edge_index += 1


func _add_vertical_perimeter_run(parent: StaticBody3D, title: String, x: int, run_start: int, run_end: int) -> void:
	# The archive facade meets the court's west perimeter at x=-10. Leave a
	# real opening for its signed door while retaining collision on both wings.
	if x == -10 and run_start < -27.2 and run_end > -24.8:
		_add_edge(parent, title + "North", Vector3(x, 0.52, (run_start - 27.2) * 0.5), Vector3(0.34, 0.85, -27.2 - run_start))
		_add_edge(parent, title + "South", Vector3(x, 0.52, (run_end - 24.8) * 0.5), Vector3(0.34, 0.85, run_end + 24.8))
	else:
		_add_edge(parent, title, Vector3(x, 0.52, (run_start + run_end) * 0.5), Vector3(0.34, 0.85, run_end - run_start))


func _record_edge(rows: Dictionary, fixed_coordinate: int, start: int) -> void:
	if not rows.has(fixed_coordinate):
		rows[fixed_coordinate] = []
	rows[fixed_coordinate].append(start)


func _add_edge(parent: StaticBody3D, title: String, center: Vector3, size: Vector3) -> void:
	if _garden_imported and _is_imported_garden_edge(center):
		# The imported garden owns its rails and fitted collision. Never add
		# grid walls through the enlarged bridge or duplicate its stonework.
		return
	var along_x := size.x > size.z
	var length: float = maxf(size.x, size.z)
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.position = center
	visual.mesh = _unit_box
	visual.scale = size
	visual.material_override = _surface_repeat(_materials["pier_wall"], length / SEAWALL_TILE_METRES, 1.0)
	parent.add_child(visual)
	# Continue the dark, wet course below the walkable slab to the waterline.
	# This skirt has no collision; the original parapet remains the boundary.
	_box(parent, title + "WetStoneSkirt", Vector3(center.x, -0.18, center.z), Vector3(size.x, 0.55, size.z), _surface_repeat(_materials["rock"], length / 2.5, 1.0))
	# The dark cap and two narrow twisted-cord strips are presentation only.
	# Both long faces are detailed because the player can walk around the hub.
	var cap_size := Vector3(size.x + 0.06, 0.08, size.z + 0.06)
	_box(parent, title + "TimberCap", center + Vector3.UP * (size.y * 0.5 + 0.025), cap_size, _materials["pier_cap"])
	var rope_material := _surface_repeat(_materials["rope"], length / ROPE_TILE_METRES, 1.0)
	for side in [-1.0, 1.0]:
		var rope_center := center + Vector3.UP * 0.23
		var rope_size := Vector3(size.x, 0.13, size.z)
		if along_x:
			rope_center.z += side * (size.z * 0.5 + 0.033)
			rope_size.z = 0.065
		else:
			rope_center.x += side * (size.x * 0.5 + 0.033)
			rope_size.x = 0.065
		_box(parent, title + "Rope" + ("A" if side < 0 else "B"), rope_center, rope_size, rope_material)
	# Dark timber stringers and a lower beam give the low seawall the layered
	# construction of a pier without adding another walking obstruction.
	var lower_size := Vector3(size.x + 0.04, 0.14, size.z + 0.12)
	if not along_x:
		lower_size = Vector3(size.x + 0.12, 0.14, size.z + 0.04)
	_box(parent, title + "LowerBeam", center + Vector3.DOWN * 0.47, lower_size, _materials["pier_cap"])
	for side in [-1.0, 1.0]:
		var stringer_at := center + Vector3.DOWN * 0.01
		var stringer_size := Vector3(size.x, 0.11, size.z)
		if along_x:
			stringer_at.z += side * (size.z * 0.5 + 0.055)
			stringer_size.z = 0.075
		else:
			stringer_at.x += side * (size.x * 0.5 + 0.055)
			stringer_size.x = 0.075
		_box(parent, title + "Stringer" + ("A" if side < 0 else "B"), stringer_at, stringer_size, _materials["pier_cap"])
	_add_edge_posts(parent, title, center, length, along_x)
	_add_edge_collision(parent, title, center, size)


func _is_imported_garden_edge(center: Vector3) -> bool:
	var point := Vector2(center.x, center.z)
	return Rect2(GardenLayout.REGION).grow(0.1).has_point(point) or Rect2(GardenLayout.CAUSEWAY).grow(0.1).has_point(point)


func _add_edge_collision(parent: StaticBody3D, title: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision" % title
	collision.position = center
	collision.shape = shape
	parent.add_child(collision)


func _add_edge_posts(parent: Node3D, title: String, center: Vector3, length: float, along_x: bool) -> void:
	# Posts sit on existing wall runs, never in the archive's separately cut
	# threshold. Keep a margin at each run end so corners and short gaps stay clear.
	if length < 3.8:
		return
	var count := maxi(1, int((length - 1.5) / 5.0))
	var spacing := length / float(count + 1)
	var rope_ring := TorusMesh.new()
	rope_ring.inner_radius = 0.27
	rope_ring.outer_radius = 0.34
	rope_ring.rings = 8
	rope_ring.ring_segments = 16
	for index in range(count):
		var distance := -length * 0.5 + spacing * float(index + 1)
		var at := Vector3(center.x + (distance if along_x else 0.0), 0.40, center.z + (0.0 if along_x else distance))
		# The shaft continues below deck level into the water as a visible pile.
		_box(parent, "%sPost%02d" % [title, index], at, Vector3(0.44, 2.10, 0.44), _materials["pier_cap"])
		_box(parent, "%sPostCap%02d" % [title, index], at + Vector3.UP * 1.10, Vector3(0.52, 0.12, 0.52), _materials["dark_stone"])
		for wrap in range(2):
			_mesh(parent, "%sPostRope%02d_%d" % [title, index, wrap], rope_ring, at + Vector3.UP * (0.64 + float(wrap) * 0.12), _materials["rope"])


func _build_district_details() -> void:
	var details := Node3D.new()
	details.name = "DistrictDetails"
	add_child(details)
	# Quay furniture is kept off the direct north, west and east approaches.
	_solid_box(details, "MooringCrateWest", Vector3(-6.3, 0.65, 5.5), Vector3(1.1, 1.1, 1.1), _materials["crate"])
	_solid_box(details, "MooringCrateEast", Vector3(6.2, 0.7, -5.2), Vector3(1.2, 1.2, 1.2), _materials["crate"])
	_solid_box(details, "QuayMarker", Vector3(5.9, 1.2, 5.7), Vector3(0.55, 2.0, 0.55), _surface_repeat(_materials["rock"], 1.0, 1.0))

	# Market stalls and the old roofline make this arm of the hub feel enclosed.
	var market_west_at := Vector3(-31.1, 2.5, 1.0)
	var market_west_size := Vector3(5.0, 5.0, 8.0)
	_solid_box(details, "MarketHouseWest", market_west_at, market_west_size, _materials["dark_stone"])
	_skin_building(details, "MarketHouseWest", market_west_at, market_west_size, _materials["market_wall"], 1)
	var market_north_at := Vector3(-25.2, 2.2, -10.7)
	var market_north_size := Vector3(5.5, 4.4, 4.0)
	_solid_box(details, "MarketHouseNorth", market_north_at, market_north_size, _materials["dark_stone"])
	_skin_building(details, "MarketHouseNorth", market_north_at, market_north_size, _materials["market_wall"], 1)
	_solid_box(details, "MarketStallA", Vector3(-24.5, 0.95, 4.8), Vector3(3.3, 1.5, 2.0), _surface_repeat(_materials["crate"], 2.0, 1.0))
	_box(details, "MarketCanopyA", Vector3(-24.5, 2.1, 4.8), Vector3(3.8, 0.18, 2.5), _materials["ochre"])
	_solid_box(details, "MarketStallB", Vector3(-16.1, 0.95, 5.2), Vector3(2.8, 1.5, 2.0), _surface_repeat(_materials["crate"], 2.0, 1.0))
	_box(details, "MarketCanopyB", Vector3(-16.1, 2.1, 5.2), Vector3(3.2, 0.18, 2.5), _materials["indigo"])

	# The court has a clear tower silhouette and aligned, low boundary markers.
	var archive_west_at := Vector3(-12.3, 2.9, -26.0)
	var archive_west_size := Vector3(4.1, 5.8, 7.0)
	_solid_box(details, "CourtArchiveWest", archive_west_at, archive_west_size, _materials["stone"])
	_skin_building(details, "CourtArchiveWest", archive_west_at, archive_west_size, _materials["archive_wall"], 2)
	var archive_east_at := Vector3(12.4, 2.4, -27.0)
	var archive_east_size := Vector3(4.3, 4.8, 6.0)
	_solid_box(details, "CourtArchiveEast", archive_east_at, archive_east_size, _materials["stone"])
	_skin_building(details, "CourtArchiveEast", archive_east_at, archive_east_size, _materials["archive_wall"], 1)
	_solid_box(details, "CourtBenchWest", Vector3(-7.0, 0.55, -17.3), Vector3(2.5, 0.55, 0.7), _surface_repeat(_materials["crate"], 2.0, 1.0))
	_solid_box(details, "CourtBenchEast", Vector3(7.0, 0.55, -17.3), Vector3(2.5, 0.55, 0.7), _surface_repeat(_materials["crate"], 2.0, 1.0))

	# A broad terrace opens to sea on the east, with a higher rocky backdrop.
	var rock_north_at := Vector3(26.5, 2.3, -14.2)
	var rock_north_size := Vector3(7.0, 4.4, 3.8)
	_solid_box(details, "BluffRockNorth", rock_north_at, rock_north_size, _materials["dark_stone"])
	_skin_box(details, "BluffRockNorth", rock_north_at, rock_north_size, _materials["rock"], _materials["rock"], false)
	var rock_south_at := Vector3(26.5, 1.7, 10.0)
	var rock_south_size := Vector3(6.0, 3.2, 4.0)
	_solid_box(details, "BluffRockSouth", rock_south_at, rock_south_size, _materials["dark_stone"])
	_skin_box(details, "BluffRockSouth", rock_south_at, rock_south_size, _materials["rock"], _materials["rock"], false)
	var lookout_at := Vector3(23.7, 0.55, 3.6)
	var lookout_size := Vector3(3.5, 0.7, 1.1)
	_solid_box(details, "BluffLookout", lookout_at, lookout_size, _materials["stone"])
	_skin_box(details, "BluffLookout", lookout_at, lookout_size, _materials["rock"], _materials["rock"], false)
	if not _try_garden_glb(details):
		_build_garden_fallback(details)


func _try_garden_glb(parent: Node3D) -> bool:
	if not ResourceLoader.exists(GARDEN_GLB):
		push_warning("Seaside Garden GLB is missing; using blockout garden.")
		return false
	var resource: Resource = ResourceLoader.load(GARDEN_GLB)
	if not resource is PackedScene:
		push_warning("Seaside Garden GLB did not import as a scene; using blockout garden.")
		return false
	var imported: Node = (resource as PackedScene).instantiate()
	if not imported is Node3D:
		imported.free()
		push_warning("Seaside Garden GLB root is not Node3D; using blockout garden.")
		return false
	imported.name = "ImportedGardenArt"
	parent.add_child(imported)
	var model := imported as Node3D
	model.transform = GardenLayout.fit() * Transform3D(
		Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE * 9.2), Vector3(40.744, 1.405, -2.0))
	if not _has_renderable_mesh(model):
		model.queue_free()
		push_warning("Seaside Garden GLB has no visible mesh; using blockout garden.")
		return false
	# The source terrace supplies the garden's actual deck, foliage, planters,
	# stonework and railings. Hide the old lawn skin and replace its coarse
	# collision with fitted surfaces while retaining the narrative gate.
	_garden_imported = true
	_garden_floor_visual.visible = false
	_garden_causeway_visual.visible = false
	# These coarse cells only generate the district outline/fallback now.
	# Fitted shapes below own the walkable imported surface.
	get_node("WalkableDistrict/LanternGardenCollision").disabled = true
	get_node("WalkableDistrict/GardenCausewayCollision").disabled = true
	_build_garden_approach(parent)
	_build_garden_walk_collision(parent)
	return true


func _build_garden_approach(parent: Node3D) -> void:
	# One owner for each exposed face: the deck/sill fit BETWEEN the masonry,
	# and the foundation sits BELOW them. Full-width overlapping boxes here
	# previously put wood and stone on the same side plane, causing shimmer.
	var body := StaticBody3D.new()
	body.name = "GardenApproach"
	parent.add_child(body)
	var clear_width := 3.36
	_box(body, "Deck", Vector3(30.7, 0.0, -2.0), Vector3(1.4, 0.4, clear_width), _surface_tile(_materials["bridge"], 1.4, clear_width, PLANK_TILE_METRES))
	_garden_box_collision(body, "DeckCollision", Vector3(31.2, 0.0, -2.0), Vector3(2.4, 0.4, clear_width))
	_garden_box_collision(body, "SillCollision", Vector3(31.9, 0.02, -2.0), Vector3(1.0, 0.44, clear_width))
	_box(body, "StoneSill", Vector3(31.9, 0.02, -2.0), Vector3(1.0, 0.44, clear_width), _surface_tile(_materials["garden_path"], 1.0, clear_width, 2.0))
	_box(body, "StoneFoundation", Vector3(31.2, -0.4, -2.0), Vector3(2.4, 0.4, clear_width), _surface_repeat(_materials["rock"], 1.0, 1.0))
	for side in [-1.0, 1.0]:
		var z: float = -2.0 + side * 1.84
		var suffix := "North" if side < 0.0 else "South"
		# Begin outside the quay's 34 cm wall. Its end cap must not share
		# an exposed plane with the new wall's outer face at the elbow.
		_box(body, suffix + "StoneBase", Vector3(31.185, -0.09, z), Vector3(2.03, 1.02, 0.32), _surface_tile(_materials["pier_wall"], 2.03, 1.02, 2.5))
		var post_z: float = -2.0 + side * 1.94
		_box(body, suffix + "QuayPost", Vector3(30.14, 0.38, post_z), Vector3(0.40, 1.24, 0.40), _materials["pier_cap"])
		_box(body, suffix + "QuayPostCap", Vector3(30.14, 1.055, post_z), Vector3(0.46, 0.11, 0.46), _materials["dark_stone"])
		# The supplied first posts are asymmetric. Measured attachment points
		# let each beam stop inside its post instead of crossing its cap/rope.
		var north: bool = side < 0.0
		var upper_end := Vector3(32.18, 0.94, -3.75) if north else Vector3(32.34, 0.94, -0.29)
		var lower_end := Vector3(32.12, 0.48, -3.80) if north else Vector3(31.65, 0.65, -0.30)
		_garden_beam(body, suffix + "UpperBeam", Vector3(30.34, 0.94, z), upper_end, 0.16, 0.25, _materials["pier_cap"])
		_garden_beam(body, suffix + "LowerBeam", Vector3(30.34, lower_end.y, z), lower_end, 0.16, 0.22, _materials["pier_cap"])
		var rope_end := Vector3(32.13, 0.80, -3.80) if north else Vector3(31.80, 0.80, -0.30)
		_garden_beam(body, suffix + "Rope", Vector3(30.34, 0.80, z), rope_end, 0.09, 0.10, _surface_repeat(_materials["rope"], 3.0, 1.0))
		_garden_box_collision(body, suffix + "Rail", Vector3(31.1, 0.65, z), Vector3(2.2, 1.0, 0.32))


func _garden_beam(parent: Node3D, title: String, start: Vector3, end: Vector3, height: float, width: float, material: Material) -> void:
	var direction := end - start
	var beam := _box(parent, title, (start + end) * 0.5, Vector3(direction.length(), height, width), material)
	beam.rotation.y = -atan2(direction.z, direction.x)


func _garden_box_collision(parent: Node3D, title: String, at: Vector3, size: Vector3, fitted: bool = false) -> void:
	var collision := CollisionShape3D.new()
	collision.name = title
	var shape := BoxShape3D.new()
	shape.size = size * (GardenLayout.ENLARGEMENT if fitted else 1.0)
	collision.shape = shape
	collision.position = GardenLayout.point(at) if fitted else at
	if fitted:
		collision.rotation_degrees.y = GardenLayout.ALIGNMENT_DEGREES
	parent.add_child(collision)


func _build_garden_walk_collision(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "GardenWalkCollision"
	parent.add_child(body)
	# Measured against the actual triangles: bridge stays level; the rise is
	# inside the gate pillars. Keep the front side walks at terrace height.
	_garden_box_collision(body, "Terrace", Vector3(44.0, 0.34, -2.0), Vector3(10.8, 0.4, 10.4), true)
	_garden_box_collision(body, "NorthLanding", Vector3(37.5, 0.34, -5.1), Vector3(2.2, 0.4, 4.2), true)
	_garden_box_collision(body, "SouthLanding", Vector3(37.5, 0.34, 1.4), Vector3(2.2, 0.4, 3.6), true)
	_garden_box_collision(body, "BridgeDeck", Vector3(35.7, 0.0, -2.0), Vector3(7.4, 0.4, 3.36))
	var ramp_shape := ConvexPolygonShape3D.new()
	var ramp_points := PackedVector3Array()
	for point in [
		Vector3(36.4, -0.2, -3.0), Vector3(36.4, -0.2, -0.4),
		Vector3(38.6, -0.2, -3.0), Vector3(38.6, -0.2, -0.4),
		Vector3(36.4, 0.20, -3.0), Vector3(36.4, 0.20, -0.4),
		Vector3(38.6, 0.54, -3.0), Vector3(38.6, 0.54, -0.4),
	]:
		ramp_points.append(GardenLayout.point(point))
	ramp_shape.points = ramp_points
	var ramp := CollisionShape3D.new()
	ramp.name = "BridgeRamp"
	ramp.shape = ramp_shape
	body.add_child(ramp)
	for bed in GardenLayout.BEDS:
		_garden_box_collision(body, bed[0], Vector3(bed[1], 0.99, bed[2]), Vector3(bed[3], 0.90, bed[4]), true)
	for side in [-1.0, 1.0]:
		_garden_box_collision(body, "BridgeNorthRail" if side < 0 else "BridgeSouthRail",
			Vector3(35.9, 1.0, -2.0 + side * 1.84), Vector3(7.8, 1.4, 0.32))
	for edge in [
		["NorthRail", Vector3(42.8, 1.02, -7.2), Vector3(13.2, 0.96, 0.22)],
		["SouthRail", Vector3(42.8, 1.02, 3.2), Vector3(13.2, 0.96, 0.22)],
		["EastRail", Vector3(49.3, 1.02, -2.0), Vector3(0.22, 0.96, 10.4)],
		["WestNorthRail", Vector3(36.6, 1.02, -5.1), Vector3(0.22, 0.96, 4.2)],
		["WestSouthRail", Vector3(36.6, 1.02, 1.4), Vector3(0.22, 0.96, 3.6)],
	]:
		_garden_box_collision(body, edge[0], edge[1], edge[2], true)


func _build_garden_fallback(parent: Node3D) -> void:
	var fitted := Node3D.new()
	fitted.name = "GardenFallback"
	parent.add_child(fitted)
	fitted.transform = GardenLayout.fit()
	parent = fitted
	for i in range(4):
		_add_tree(parent, "GardenTree%d" % i, Vector3(39.0 if i < 2 else 44.7, 0.0, -5.3 if i % 2 == 0 else 1.2))
	_build_garden_details(parent)


func _build_garden_details(parent: Node3D) -> void:
	# The missing-asset blockout follows the same east-west 14 x 12 m garden
	# and expanded causeway used by the imported stone terrace and minimap.
	for section in [
		["Entry", Vector3(34.0, 0.219, -2.0), Vector3(5.8, 0.025, 1.8)],
		["Spine", Vector3(42.5, 0.219, -2.0), Vector3(13.5, 0.025, 2.0)],
		["CrossWalk", Vector3(42.0, 0.219, -2.0), Vector3(2.0, 0.025, 9.5)],
		["SeaLookout", Vector3(48.5, 0.220, -2.0), Vector3(2.0, 0.025, 2.7)],
	]:
		_box(parent, "GardenPath%s" % section[0], section[1], section[2], _surface_tile(_materials["garden_path"], section[2].x, section[2].z, 2.0))
	_add_garden_bed(parent, "GardenBedNorthWest", Vector3(39.0, 0.0, -5.3), Vector2(2.5, 2.4), _materials["flower_orange"])
	_add_garden_bed(parent, "GardenBedSouthWest", Vector3(39.0, 0.0, 1.2), Vector2(2.5, 2.4), _materials["flower_blue"])
	_add_garden_bed(parent, "GardenBedNorthEast", Vector3(44.7, 0.0, -5.3), Vector2(2.5, 2.4), _materials["flower_blue"])
	_add_garden_bed(parent, "GardenBedSouthEast", Vector3(44.7, 0.0, 1.2), Vector2(2.5, 2.4), _materials["flower_orange"])


func _add_garden_bed(parent: Node3D, title: String, at: Vector3, footprint: Vector2, bloom: Material) -> void:
	var bed := Node3D.new()
	bed.name = title
	bed.position = at
	parent.add_child(bed)
	var bed_size := Vector3(footprint.x, 0.43, footprint.y)
	_solid_box(bed, "TimberPlanter", Vector3(0.0, 0.43, 0.0), bed_size, _materials["pier_cap"])
	_box(bed, "Soil", Vector3(0.0, 0.66, 0.0), Vector3(footprint.x - 0.18, 0.035, footprint.y - 0.18), _surface_tile(_materials["garden_soil"], footprint.x, footprint.y, 1.0))
	for side in [-1.0, 1.0]:
		_box(bed, "LongRim%d" % int(side), Vector3(side * (footprint.x * 0.5 - 0.045), 0.68, 0.0), Vector3(0.09, 0.10, footprint.y + 0.07), _materials["wood"])
		_box(bed, "EndRim%d" % int(side), Vector3(0.0, 0.68, side * (footprint.y * 0.5 - 0.045)), Vector3(footprint.x + 0.07, 0.10, 0.09), _materials["wood"])
	var foliage := SphereMesh.new()
	foliage.radius = 0.28
	foliage.height = 0.45
	var flower := SphereMesh.new()
	flower.radius = 0.11
	flower.height = 0.21
	for plant in range(3):
		var offset := Vector3(-0.18 if plant % 2 == 0 else 0.18, 0.82, -0.62 + plant * 0.62)
		_mesh(bed, "Foliage%d" % plant, foliage, offset, _materials["leaf"])
		_mesh(bed, "Bloom%d" % plant, flower, offset + Vector3.UP * 0.28, bloom)


func _build_records_door() -> void:
	# The west archive is a solid facade in this hub. This readable door is the
	# interaction point; entering transfers the player to the cutaway interior.
	var door := Node3D.new()
	door.name = "RecordsDoor"
	door.position = Vector3(-10.10, 0.0, -26.0)
	add_child(door)
	# Camera rays include layer 8; the player's layer-1 mask does not. The
	# surround/sign project past the solid building and need their own clearance.
	var camera_guard := StaticBody3D.new()
	camera_guard.name = "CameraClearance"
	camera_guard.collision_layer = 128
	camera_guard.collision_mask = 0
	var guard_shape := BoxShape3D.new()
	guard_shape.size = Vector3(0.9, 3.3, 2.7)
	var guard_collision := CollisionShape3D.new()
	guard_collision.shape = guard_shape
	guard_collision.position = Vector3(0.2, 1.65, 0.0)
	camera_guard.add_child(guard_collision)
	door.add_child(camera_guard)
	# The lighthouse's timber, iron bands, and pale voussoirs inform this
	# original procedural doorway. The wall's existing collision stays put.
	var wood := _records_door_wood_material()
	var iron := _material("#282c2b")
	var rivet := _material("#6b6456")
	_box(door, "DarkReveal", Vector3(0.04, 1.20, 0.0), Vector3(0.12, 2.38, 1.76), _materials["dark_stone"])
	for board_index in range(9):
		var z := (float(board_index) - 4.0) * 0.18
		var crown := 1.0 - pow(absf(z) / 0.81, 1.8)
		var top := 2.13 + 0.44 * crown
		var plank: StandardMaterial3D = wood.duplicate() as StandardMaterial3D
		plank.albedo_color = Color.from_hsv(0.087, 0.22, 0.86 + 0.06 * float(board_index % 3))
		_box(door, "TimberBoard%d" % board_index, Vector3(0.14, top * 0.5, z), Vector3(0.14, top - 0.035, 0.175), plank)
	for side in [-1.0, 1.0]:
		_box(door, "IronEdge%d" % int(side), Vector3(0.23, 1.09, side * 0.80), Vector3(0.035, 2.16, 0.045), iron)
		_box(door, "StoneJamb%d" % int(side), Vector3(0.23, 1.09, side * 1.03), Vector3(0.31, 2.18, 0.31), _materials["tower_pale_atlas"])
		_box(door, "DarkSpring%d" % int(side), Vector3(0.25, 2.07, side * 0.82), Vector3(0.27, 0.28, 0.17), _materials["tower_dark_atlas"])
	for stone_index in range(9):
		var angle := PI - (float(stone_index) + 0.5) * PI / 9.0
		var z := 0.98 * cos(angle)
		var y := 2.11 + 0.54 * sin(angle)
		var tangent_y := 0.54 * cos(angle)
		var tangent_z := -0.98 * sin(angle)
		var arch_stone := _box(door, "StoneArch%d" % stone_index, Vector3(0.24, y, z), Vector3(0.31, 0.30, 0.34), _materials["tower_pale_atlas"])
		arch_stone.rotation.x = atan2(-tangent_y, tangent_z)
	for strap_index in range(2):
		var y := 0.48 + strap_index * 1.05
		_box(door, "IronStrap%d" % strap_index, Vector3(0.23, y, 0.0), Vector3(0.04, 0.072, 1.60), iron)
		for stud_index in range(5):
			var stud := SphereMesh.new()
			stud.radius = 0.023
			stud.height = 0.046
			_mesh(door, "IronStud%d_%d" % [strap_index, stud_index], stud, Vector3(0.26, y, (float(stud_index) - 2.0) * 0.35), rivet)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.105
	plate.bottom_radius = 0.105
	plate.height = 0.025
	var handle_plate := _mesh(door, "RingPlate", plate, Vector3(0.24, 1.06, 0.37), iron)
	handle_plate.rotation.z = PI * 0.5
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.105
	ring.rings = 8
	ring.ring_segments = 12
	var handle_ring := _mesh(door, "IronRing", ring, Vector3(0.275, 1.02, 0.37), rivet)
	handle_ring.rotation.z = PI * 0.5
	_box(door, "RecordsSignBoard", Vector3(0.44, 3.00, 0.0), Vector3(0.09, 0.36, 2.22), wood)


func _records_door_wood_material() -> StandardMaterial3D:
	# One coherent vertical board from the weathered timber map is sampled for
	# each modeled door plank. The tower atlas still supplies the stone surround.
	var board := AtlasTexture.new()
	board.atlas = load("res://assets/textures/materials/weathered_timber_albedo.png")
	board.region = Rect2(334.0, 0.0, 150.0, 1254.0)
	return _textured_material("#ffffff", board)


func _wall_surface(base: Material, width: float, height: float) -> Material:
	if base is ShaderMaterial:
		var surface: ShaderMaterial = base.duplicate() as ShaderMaterial
		surface.set_shader_parameter("facade_metres", Vector2(width, height))
		return surface
	return _surface_tile(base as StandardMaterial3D, width, height, MASONRY_TILE_METRES)


func _skin_box(parent: Node3D, title: String, at: Vector3, size: Vector3, wall: Material, top: StandardMaterial3D, eaves: bool) -> void:
	# Each side has its own UV density. A single scaled BoxMesh stretches one of
	# the perpendicular faces, especially on long market and archive buildings.
	var east_west := _wall_surface(wall, size.z, size.y)
	var north_south := _wall_surface(wall, size.x, size.y)
	for side in [-1.0, 1.0]:
		_box(parent, title + ("West" if side < 0 else "East") + "Skin", Vector3(at.x + side * (size.x * 0.5 + 0.045), at.y, at.z), Vector3(0.08, size.y - 0.10, size.z - 0.10), east_west)
		_box(parent, title + ("North" if side < 0 else "South") + "Skin", Vector3(at.x, at.y, at.z + side * (size.z * 0.5 + 0.045)), Vector3(size.x - 0.10, size.y - 0.10, 0.08), north_south)
	var overhang := 0.24 if eaves else 0.02
	var roof := _box(parent, title + "RoofSkin", at + Vector3.UP * (size.y * 0.5 + 0.045), Vector3(size.x + overhang, 0.10, size.z + overhang), top)
	roof.material_override = _surface_repeat(top, size.x / 1.5, size.z / 1.5)


func _skin_building(parent: Node3D, title: String, at: Vector3, size: Vector3, wall: Material, rows: int) -> void:
	_skin_box(parent, title, at, size, wall, _materials["roof"], true)
	_add_building_stonework(parent, title, at, size)
	var base_y := at.y - size.y * 0.5
	for row in range(rows):
		var window_y := base_y + 2.20 + row * 2.0
		for side in [-1.0, 1.0]:
			var x_face: float = at.x + side * size.x * 0.5
			var z_face: float = at.z + side * size.z * 0.5
			var z_count := clampi(int(size.z / 2.2), 2, 3)
			var x_count := clampi(int(size.x / 2.2), 2, 3)
			for column in range(z_count):
				if title == "CourtArchiveWest" and row == 0 and side > 0 and column == 1:
					continue # Keep the east facade clear for the records door.
				var z_at: float = at.z - size.z * 0.5 + size.z * (column + 1.0) / (z_count + 1.0)
				var lit := (column + row * 2 + (0 if side < 0 else 1) + title.length()) % 5 == 0
				_add_window_x(parent, "%sX%d%d%d" % [title, row, int(side), column], x_face, side, window_y, z_at, lit)
			for column in range(x_count):
				var x_at: float = at.x - size.x * 0.5 + size.x * (column + 1.0) / (x_count + 1.0)
				var lit := (column + row * 2 + (2 if side < 0 else 3) + title.length()) % 5 == 0
				_add_window_z(parent, "%sZ%d%d%d" % [title, row, int(side), column], z_face, side, window_y, x_at, lit)


func _add_building_stonework(parent: Node3D, title: String, at: Vector3, size: Vector3) -> void:
	# The dark course ties the flat facades to the tower's stone plinth. It is
	# split around the west archive's playable door. Repeats use world metres.
	var base_y := at.y - size.y * 0.5
	var stone: StandardMaterial3D = _materials["rock"]
	for side in [-1.0, 1.0]:
		var x_face: float = at.x + side * (size.x * 0.5 + 0.055)
		if title == "CourtArchiveWest" and side > 0:
			var wing_length: float = size.z * 0.5 - 1.05
			for wing in [-1.0, 1.0]:
				var wing_center: float = at.z + wing * (1.05 + wing_length * 0.5)
				_box(parent, "%sDoorWing%d" % [title, int(wing)], Vector3(x_face, base_y + 0.44, wing_center), Vector3(0.12, 0.88, wing_length), _surface_tile(stone, wing_length, 0.88, MASONRY_TILE_METRES))
		else:
			_box(parent, "%sPlinthX%d" % [title, int(side)], Vector3(x_face, base_y + 0.44, at.z), Vector3(0.12, 0.88, size.z - 0.08), _surface_tile(stone, size.z, 0.88, MASONRY_TILE_METRES))
		var z_face: float = at.z + side * (size.z * 0.5 + 0.055)
		_box(parent, "%sPlinthZ%d" % [title, int(side)], Vector3(at.x, base_y + 0.44, z_face), Vector3(size.x - 0.08, 0.88, 0.12), _surface_tile(stone, size.x, 0.88, MASONRY_TILE_METRES))
	if title.begins_with("CourtArchive"):
		# The tower's tall dark-stone UV island has nearly the same aspect as
		# these lower-corner supports; one island is mapped to each face once.
		for x_side in [-1.0, 1.0]:
			for z_side in [-1.0, 1.0]:
				_box(parent, "%sButtress%d%d" % [title, int(x_side), int(z_side)], Vector3(at.x + x_side * (size.x * 0.5 + 0.11), base_y + 1.16, at.z + z_side * (size.z * 0.5 + 0.11)), Vector3(0.36, 2.32, 0.36), _materials["tower_dark_atlas"])
		var court_side := 1.0 if title == "CourtArchiveWest" else -1.0
		for z_side in [-1.0, 1.0]:
			_box(parent, "%sUpperPier%d" % [title, int(z_side)], Vector3(at.x + court_side * (size.x * 0.5 + 0.12), base_y + 3.32, at.z + z_side * (size.z * 0.5 + 0.12)), Vector3(0.44, 2.20, 0.44), _materials["tower_pale_atlas"])
	elif title.begins_with("MarketHouse"):
		# A pair of quay-facing pale supports carries the tower's lighter stone
		# into the market without repeating its full atlas on the block facades.
		for z_side in [-1.0, 1.0]:
			_box(parent, "%sQuayPier%d" % [title, int(z_side)], Vector3(at.x + size.x * 0.5 + 0.12, base_y + 1.10, at.z + z_side * (size.z * 0.5 + 0.12)), Vector3(0.44, 2.20, 0.44), _materials["tower_pale_atlas"])


func _add_window_x(parent: Node3D, title: String, surface_x: float, facing: float, height: float, z: float, lit: bool) -> void:
	var root := Node3D.new()
	root.name = title
	root.position = Vector3(surface_x, height, z)
	root.rotation.y = PI * 0.5 * facing
	parent.add_child(root)
	_add_recessed_window(root, lit)


func _add_window_z(parent: Node3D, title: String, surface_z: float, facing: float, height: float, x: float, lit: bool) -> void:
	var root := Node3D.new()
	root.name = title
	root.position = Vector3(x, height, surface_z)
	root.rotation.y = 0.0 if facing > 0.0 else PI
	parent.add_child(root)
	_add_recessed_window(root, lit)


func _add_recessed_window(root: Node3D, lit: bool) -> void:
	# Local +Z faces outdoors on every building face. The wall itself stays solid
	# for collision: a dark reveal sits just beyond its skin, the glazing sits
	# back, and deep tower-stone jambs/sill/lintel project around it. This gives
	# the window depth without cutting a hole through the playable building.
	var tower_stone: Material = _materials["tower_pale_atlas"]
	var frame: Material = _materials["window_frame"]
	_box(root, "Recess", Vector3(0.0, 0.0, 0.105), Vector3(0.75, 0.96, 0.04), _materials["tower_dark_atlas"])
	_box(root, "Pane", Vector3(0.0, 0.0, 0.145), Vector3(0.66, 0.84, 0.03), _materials["window_lit"] if lit else _materials["window_dark"])
	for side in [-1.0, 1.0]:
		_box(root, "StoneJamb%d" % int(side), Vector3(side * 0.43, 0.0, 0.21), Vector3(0.19, 1.18, 0.30), tower_stone)
	_box(root, "StoneLintel", Vector3(0.0, 0.56, 0.21), Vector3(1.05, 0.20, 0.30), tower_stone)
	_box(root, "StoneSill", Vector3(0.0, -0.56, 0.25), Vector3(1.17, 0.16, 0.42), tower_stone)
	_box(root, "MullionVertical", Vector3(0.0, 0.0, 0.19), Vector3(0.055, 0.84, 0.06), frame)
	_box(root, "MullionHorizontal", Vector3(0.0, 0.0, 0.19), Vector3(0.66, 0.055, 0.06), frame)


func _add_tree(parent: Node3D, title: String, at: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = title
	tree.position = at
	parent.add_child(tree)
	_solid_box(tree, "Trunk", Vector3(0.0, 1.0, 0.0), Vector3(0.45, 2.0, 0.45), _materials["bark"])
	_mesh(tree, "Canopy", _tree_canopy, Vector3(0.0, 2.65, 0.0), _materials["leaf"])


func _build_tower() -> void:
	# Replace TowerArt with an imported GLB. Keep this root and TowerFootprint
	# in place so dialogue, collision and save coordinates stay stable.
	var tower := Node3D.new()
	tower.name = "LandmarkTower"
	tower.position = Vector3(0.0, 0.0, -23.0)
	add_child(tower)
	var footprint := StaticBody3D.new()
	footprint.name = "TowerFootprint"
	tower.add_child(footprint)
	var base_shape := BoxShape3D.new()
	base_shape.size = Vector3(4.0, 2.5, 4.0)
	var base_collision := CollisionShape3D.new()
	base_collision.name = "CollisionShape3D"
	base_collision.position.y = 1.25
	base_collision.shape = base_shape
	footprint.add_child(base_collision)
	var art := Node3D.new()
	art.name = "TowerArt"
	tower.add_child(art)
	_box(art, "Plinth", Vector3(0, 0.75, 0), Vector3(4, 1.5, 4), _materials["dark_stone"])
	_skin_box(art, "Plinth", Vector3(0, 0.75, 0), Vector3(4, 1.5, 4), _materials["rock"], _materials["rock"], false)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 1.05
	shaft.bottom_radius = 1.6
	shaft.height = 9.0
	_mesh(art, "TaperedShaft", shaft, Vector3(0, 5.7, 0), _surface_repeat(_materials["rock"], 4.0, 4.5))
	_box(art, "LanternRoom", Vector3(0, 11.1, 0), Vector3(3.0, 1.8, 3.0), _materials["ochre"])
	_skin_box(art, "LanternRoom", Vector3(0, 11.1, 0), Vector3(3.0, 1.8, 3.0), _materials["lantern_wall"], _materials["roof"], true)
	var beacon := SphereMesh.new()
	beacon.radius = 1.0
	beacon.height = 1.8
	_mesh(art, "Beacon", beacon, Vector3(0, 11.1, 0), _materials["light"])
	var roof := CylinderMesh.new()
	roof.top_radius = 0.15
	roof.bottom_radius = 2.0
	roof.height = 1.7
	_mesh(art, "CopperCap", roof, Vector3(0, 12.9, 0), _surface_repeat(_materials["roof"], 4.0, 2.0))
	_box(art, "Spire", Vector3(0, 14.1, 0), Vector3(0.25, 1.1, 0.25), _materials["light"])
	var light := OmniLight3D.new()
	light.name = "BeaconLight"
	light.position = Vector3(0, 11.2, 0)
	light.light_color = Color("#ffbd61")
	light.light_energy = 1.4
	light.omni_range = 72.0
	light.omni_attenuation = .6
	tower.add_child(light)
	if _try_tower_glb(tower, art):
		# The supplied civic model is wider than the primitive fallback.  Keep
		# its collider in step while leaving the fallback's original footprint.
		base_shape.size = Vector3(5.2, 10.7, 5.2)
		base_collision.position.y = 5.35
		light.position.y = 7.85
		for mesh in tower.get_node("ImportedTowerArt").find_children("*", "MeshInstance3D", true, false):
			for surface in range(mesh.mesh.get_surface_count()):
				var original := mesh.get_active_material(surface) as StandardMaterial3D
				if original == null: continue
				var illuminated := ShaderMaterial.new()
				illuminated.shader = preload("res://shaders/tower_lantern.gdshader")
				illuminated.set_shader_parameter("albedo_map", original.albedo_texture)
				illuminated.set_shader_parameter("normal_map", original.normal_texture)
				illuminated.set_shader_parameter("surface_map", original.roughness_texture)
				mesh.set_surface_override_material(surface, illuminated)
	# Shadowed emitters sit outside the opaque imported lantern shell.
	for i in range(4):
		var direction := Vector3(sin(i * PI * .5), 0, cos(i * PI * .5))
		var beam := SpotLight3D.new()
		beam.name = "LanternWindow%d" % i
		beam.position = light.position + direction * 1.45
		beam.light_color = Color("ffcd83")
		beam.light_energy = 1.8
		beam.spot_range = 72.0
		beam.spot_angle = 65
		beam.spot_attenuation = .6
		beam.shadow_enabled = true
		tower.add_child(beam)
		beam.look_at(beam.global_position + direction * 10 + Vector3.DOWN * 5)
	set_beacon_lit(false)

func set_beacon_lit(lit: bool) -> void:
	var tower := get_node_or_null("LandmarkTower")
	if tower == null: return
	for child in tower.get_children():
		if child is Light3D: child.visible = lit
	for mesh in tower.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_surface_override_material(surface) as ShaderMaterial
			if material != null and material.shader == preload("res://shaders/tower_lantern.gdshader"):
				material.set_shader_parameter("lamp_power", 2.8 if lit else 0.0)
	var fallback := tower.get_node("TowerArt/Beacon") as MeshInstance3D
	fallback.visible = lit

func is_beacon_lit() -> bool:
	return get_node("LandmarkTower/BeaconLight").visible


func _try_tower_glb(tower: Node3D, fallback_art: Node3D) -> bool:
	if not ResourceLoader.exists(TOWER_GLB):
		return false
	var resource: Resource = ResourceLoader.load(TOWER_GLB)
	if not resource is PackedScene:
		push_warning("Lantern tower GLB did not import as a scene; using primitive tower.")
		return false
	var imported: Node = (resource as PackedScene).instantiate()
	if not imported is Node3D:
		imported.free()
		push_warning("Lantern tower GLB root is not Node3D; using primitive tower.")
		return false
	imported.name = "ImportedTowerArt"
	tower.add_child(imported)
	(imported as Node3D).position = tower_model_offset
	(imported as Node3D).scale = tower_model_scale
	if not _has_renderable_mesh(imported as Node3D):
		imported.queue_free()
		push_warning("Lantern tower GLB has no visible mesh; using primitive tower.")
		return false
	fallback_art.visible = false
	return true


func _has_renderable_mesh(model: Node3D) -> bool:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.push_front(model)
	for node in meshes:
		var visual := node as MeshInstance3D
		if not visual.is_visible_in_tree() or visual.mesh == null:
			continue
		for surface in range(visual.mesh.get_surface_count()):
			if visual.mesh.surface_get_array_len(surface) > 0:
				return true
	return false


func _build_gateways() -> void:
	var east_gate := Node3D.new()
	east_gate.name = "EastGardenGate"
	east_gate.position = Vector3(32.0, 0.0, -2.0)
	add_child(east_gate)
	if not _garden_imported:
		_solid_box(east_gate, "NorthPost", Vector3(0, 1.5, -2.45), Vector3(0.9, 3.0, 0.9), _surface_repeat(_materials["rock"], 1.0, 1.5))
		_solid_box(east_gate, "SouthPost", Vector3(0, 1.5, 2.45), Vector3(0.9, 3.0, 0.9), _surface_repeat(_materials["rock"], 1.0, 1.5))
		_box(east_gate, "Lintel", Vector3(0, 3.1, 0), Vector3(1.0, 0.45, 5.8), _surface_repeat(_materials["rock"], 3.0, 1.0))
	_gate_barrier = _barrier(east_gate, Vector3(0, 0.95, 0), Vector3(0.45, 1.8, 3.7))
	_gate_barrier.name = "Barrier"

	var shortcut := Node3D.new()
	shortcut.name = "MarketCourtShortcut"
	shortcut.position = Vector3(-20.0, 0.0, -12.0)
	add_child(shortcut)
	_solid_box(shortcut, "WestPost", Vector3(-2.45, 1.3, 0), Vector3(0.9, 2.6, 0.9), _surface_repeat(_materials["rock"], 1.0, 1.5))
	_solid_box(shortcut, "EastPost", Vector3(2.45, 1.3, 0), Vector3(0.9, 2.6, 0.9), _surface_repeat(_materials["rock"], 1.0, 1.5))
	_shortcut_barrier = _barrier(shortcut, Vector3(0, 0.95, 0), Vector3(3.7, 1.8, 0.45))
	_shortcut_barrier.name = "Barrier"


func _barrier(parent: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = center
	parent.add_child(body)
	var leaves := _box(body, "GateLeaves", Vector3.ZERO, size, _materials["wood"])
	leaves.material_override = _surface_repeat(_materials["wood"], maxf(size.x, size.z) / PLANK_TILE_METRES, 1.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	return body


func _update_barriers() -> void:
	_toggle_barrier(_gate_barrier, _gate_open)
	_toggle_barrier(_shortcut_barrier, _shortcut_open)


func _toggle_barrier(body: StaticBody3D, open: bool) -> void:
	if body == null:
		return
	body.visible = not open
	var collision: CollisionShape3D = body.get_node("CollisionShape3D")
	collision.set_deferred("disabled", open)


func _build_horizon() -> void:
	var horizon := Node3D.new()
	horizon.name = "DistantDistrictSilhouette"
	add_child(horizon)
	var shapes := [
		["NorthRoofA", Vector3(-32, 3.0, -39), Vector3(9, 6, 5)],
		["NorthRoofB", Vector3(-20, 4.5, -41), Vector3(5, 9, 4)],
		["NorthRoofC", Vector3(24, 3.0, -40), Vector3(11, 6, 5)],
		["SouthWarehouse", Vector3(-27, 2.5, 18), Vector3(12, 5, 5)],
	]
	for item in shapes:
		_box(horizon, item[0], item[1], item[2], _materials["distance"])
		_skin_box(horizon, item[0], item[1], item[2], _materials["distant_wall"], _materials["roof"], true)


func _solid_box(parent: Node3D, title: String, at: Vector3, size: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = title
	body.position = at
	parent.add_child(body)
	_box(body, "Visual", Vector3.ZERO, size, material)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	return body


func _box(parent: Node3D, title: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := _mesh(parent, title, _unit_box, at, material)
	visual.scale = size
	return visual


func _mesh(parent: Node3D, title: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.position = at
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	return visual
