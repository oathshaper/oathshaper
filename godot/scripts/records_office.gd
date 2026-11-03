extends Node3D
## Original, roofless civic records room. Positions and interaction points are metres.

const FLOOR_SIZE := Vector3(12.0, 0.4, 10.0)
const ENTRY_LOCAL := Vector3(0.0, 1.05, 3.0)
const EXIT_LOCAL := Vector3(0.0, 1.05, 4.2)
const CABINET_LOCAL := Vector3(-3.2, 1.05, -3.5)
const DRAWER_TRAVEL := 0.68
const WALL_TOP := 3.4
const COPING_HEIGHT := 0.18

var _materials: Dictionary = {}
var _box_mesh: BoxMesh
var _structure: StaticBody3D
var _drawer: Node3D
var _records: Node3D
var _drawer_open := false
var _records_collected := false
var _drawer_tween: Tween


func _ready() -> void:
	_make_materials()
	_structure = StaticBody3D.new()
	_structure.name = "Structure"
	add_child(_structure)
	_build_room()
	_build_furniture()
	_build_lighting()
	set_records_collected(_records_collected)


func entry_position() -> Vector3:
	return to_global(ENTRY_LOCAL)


func exit_door_position() -> Vector3:
	return to_global(EXIT_LOCAL)


func cabinet_position() -> Vector3:
	return to_global(CABINET_LOCAL)


func open_cabinet() -> void:
	if _drawer_open or _drawer == null:
		return
	_drawer_open = true
	_move_drawer(DRAWER_TRAVEL)


func close_cabinet() -> void:
	if not _drawer_open or _drawer == null:
		return
	_drawer_open = false
	_move_drawer(0.0)


func _move_drawer(destination: float) -> void:
	if _drawer_tween != null and _drawer_tween.is_running():
		_drawer_tween.kill()
	_drawer_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_drawer_tween.tween_property(_drawer, "position:z", destination, 0.42)


func set_records_collected(taken: bool) -> void:
	_records_collected = taken
	if _records != null:
		_records.visible = not taken


func _make_materials() -> void:
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE
	var pavers: Texture2D = load("res://assets/textures/materials/limestone_pavers_albedo.png")
	var masonry: Texture2D = load("res://assets/textures/materials/seawall_masonry_albedo.png")
	var timber: Texture2D = load("res://assets/textures/materials/weathered_timber_albedo.png")
	var canvas: Texture2D = load("res://assets/textures/materials/sailcloth_canvas_albedo.png")
	_materials = {
		"floor": _textured_material("#beb4a4", pavers),
		"tile_a": _textured_material("#e6dcca", pavers),
		"tile_b": _textured_material("#c8c2b7", pavers),
		# This evenly colored limestone map stays consistent on the three walls;
		# the tidal-band atlas is reserved for the low stonework and exterior.
		"wall": _textured_material("#d8d0c0", pavers),
		"stone": _textured_material("#c3c5c1", masonry),
		"trim": _textured_material("#858b85", masonry),
		"wood": _textured_material("#c6ad96", timber),
		"dark_wood": _textured_material("#81776d", timber),
		"brass": _material("#ae8553", true),
		"cabinet": _textured_material("#a2aea8", timber),
		"paper": _material("#d1bc8e"),
		"red_paper": _material("#8f5648"),
		"runner": _textured_material("#77665f", canvas),
		"window": _material("#364b54"),
		"lamp": _emissive("#ffcf85"),
	}


func _material(hex: String, metallic := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.roughness = 0.56 if metallic else 0.94
	material.metallic = 0.45 if metallic else 0.0
	return material


func _textured_material(hex: String, texture: Texture2D) -> StandardMaterial3D:
	var material := _material(hex)
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = true
	return material


func _repeat_material(base: StandardMaterial3D, horizontal: float, vertical: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = base.duplicate() as StandardMaterial3D
	material.uv1_scale = Vector3(horizontal, vertical, 1.0)
	return material


func _emissive(hex: String) -> StandardMaterial3D:
	var material := _material(hex)
	material.emission_enabled = true
	material.emission = Color(hex)
	material.emission_energy_multiplier = 1.8
	return material


func _box(parent: Node3D, title: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = title
	visual.mesh = _box_mesh
	visual.position = center
	visual.scale = size
	visual.material_override = material
	parent.add_child(visual)
	return visual


func _collision(title: String, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var node := CollisionShape3D.new()
	node.name = title + "Collision"
	node.position = center
	node.shape = shape
	_structure.add_child(node)


func _solid(title: String, center: Vector3, size: Vector3, material: Material) -> void:
	_box(self, title, center, size, material)
	_collision(title, center, size)


func _build_room() -> void:
	_solid("Floor", Vector3.ZERO, FLOOR_SIZE, _repeat_material(_materials["floor"], 6.0, 5.0))
	# Small contrasting stone squares give the room a readable retro scale.
	for x in range(6):
		for z in range(5):
			var center := Vector3(-5.0 + x * 2.0, 0.206, -4.0 + z * 2.0)
			var material: Material = _materials["tile_a"] if (x + z) % 2 == 0 else _materials["tile_b"]
			_box(self, "FloorTile_%d_%d" % [x, z], center, Vector3(1.94, 0.012, 1.94), material)
	_box(self, "CenterRunner", Vector3(0.0, 0.219, 0.25), Vector3(2.0, 0.016, 7.8), _repeat_material(_materials["runner"], 1.0, 4.0))
	_box(self, "RunnerBorderLeft", Vector3(-1.04, 0.23, 0.25), Vector3(0.05, 0.017, 7.8), _materials["brass"])
	_box(self, "RunnerBorderRight", Vector3(1.04, 0.23, 0.25), Vector3(0.05, 0.017, 7.8), _materials["brass"])

	_solid("NorthWall", Vector3(0.0, 1.8, -4.9), Vector3(12.0, 3.2, 0.2), _repeat_material(_materials["wall"], 3.0, 1.0))
	# Butt the side walls against the north wall instead of overlapping their
	# exterior faces at the corners. The joined collision volume is unchanged.
	_solid("WestWall", Vector3(-5.9, 1.8, 0.1), Vector3(0.2, 3.2, 9.8), _repeat_material(_materials["wall"], 2.5, 1.0))
	_solid("EastWall", Vector3(5.9, 1.8, 0.1), Vector3(0.2, 3.2, 9.8), _repeat_material(_materials["wall"], 2.5, 1.0))
	# Low south wall is the camera cutaway. The doorway gap stays physically open.
	_solid("SouthWallLeft", Vector3(-3.7, 0.775, 4.9), Vector3(4.6, 1.15, 0.2), _materials["stone"])
	_solid("SouthWallRight", Vector3(3.7, 0.775, 4.9), Vector3(4.6, 1.15, 0.2), _materials["stone"])
	# A short landing keeps the open doorway safe if the player walks past the
	# interaction point before choosing to return to the quay.
	_solid("ExitLanding", Vector3(0.0, 0.0, 5.75), Vector3(3.2, 0.4, 1.5), _materials["tile_b"])
	_solid("LandingEndRail", Vector3(0.0, 0.9, 6.45), Vector3(3.2, 1.4, 0.16), _materials["stone"])
	for side in [-1.0, 1.0]:
		_solid("LandingSideRail_%d" % int(side), Vector3(side * 1.56, 0.9, 5.75), Vector3(0.16, 1.4, 1.5), _materials["stone"])
	# Caps sit ON the wall, not inside it with coplanar top faces. At the
	# corners their footprints also meet edge-to-edge, avoiding depth flicker.
	var coping_y := WALL_TOP + COPING_HEIGHT * 0.5
	_box(self, "NorthCoping", Vector3(0.0, coping_y, -4.9), Vector3(12.12, COPING_HEIGHT, 0.32), _repeat_material(_materials["trim"], 6.0, 1.0))
	for side in [-1.0, 1.0]:
		_box(self, "SideCoping_%d" % int(side), Vector3(side * 5.9, coping_y, 0.13), Vector3(0.32, COPING_HEIGHT, 9.74), _repeat_material(_materials["trim"], 5.0, 1.0))
		_box(self, "SouthCoping_%d" % int(side), Vector3(side * 3.7, 1.42, 4.9), Vector3(4.6, 0.14, 0.31), _materials["trim"])
	_build_door()
	_build_windows()


func _build_door() -> void:
	var door := Node3D.new()
	door.name = "ExitDoor"
	add_child(door)
	# Match the West Archive's weathered timber and pale tower stone. The
	# existing posts and lintel keep exactly the same collision geometry.
	var stone := ShaderMaterial.new()
	stone.shader = load("res://shaders/tower_atlas_stone.gdshader")
	stone.set_shader_parameter("tower_base_color", load("res://assets/textures/tower/stonewatch_base_color.jpg"))
	stone.set_shader_parameter("atlas_region", Vector4(944.0 / 2048.0, 1068.0 / 2048.0, 62.0 / 2048.0, 300.0 / 2048.0))
	var iron := _material("#252a29", true)
	var rivet := _material("#77756d", true)
	var timber: StandardMaterial3D = _materials["wood"]
	for side in [-1.0, 1.0]:
		var center := Vector3(side * 1.48, 1.65, 4.9)
		_solid("ExitPost_%d" % int(side), center, Vector3(0.18, 2.9, 0.34), stone)
		_box(door, "StoneJambFace_%d" % int(side), center + Vector3(0.0, 0.0, -0.20), Vector3(0.29, 2.9, 0.09), stone)
	_solid("ExitLintel", Vector3(0.0, 3.06, 4.9), Vector3(3.08, 0.18, 0.34), stone)
	_box(door, "StoneLintelFace", Vector3(0.0, 3.06, 4.70), Vector3(3.30, 0.26, 0.09), stone)
	_box(door, "StoneKeystone", Vector3(0.0, 3.06, 4.63), Vector3(0.36, 0.33, 0.10), stone)
	_box(door, "Threshold", Vector3(0.0, 0.213, 4.55), Vector3(2.8, 0.025, 0.42), stone)
	# One leaf is folded against the right jamb; the center passage is unobstructed.
	var leaf := Node3D.new()
	leaf.name = "OpenLeaf"
	leaf.position = Vector3(1.38, 1.5, 4.75)
	leaf.rotation_degrees.y = -75.0
	door.add_child(leaf)
	_box(leaf, "DoorPanel", Vector3(-0.65, 0.0, 0.0), Vector3(1.3, 2.35, 0.1), _materials["dark_wood"])
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.05
	ring_mesh.outer_radius = 0.11
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 12
	# This folded leaf can be seen from the room and from the landing.
	for face in [-1.0, 1.0]:
		for board_index in range(7):
			var board: StandardMaterial3D = timber.duplicate() as StandardMaterial3D
			board.albedo_color = Color.from_hsv(0.087, 0.20, 0.88 + 0.04 * float(board_index % 3))
			# Each narrow plank takes one vertical strip from the source map.
			board.uv1_scale = Vector3(1.0 / 7.0, 1.0, 1.0)
			board.uv1_offset = Vector3(float(board_index) / 7.0, 0.0, 0.0)
			_box(leaf, "TimberBoard%d_%d" % [int(face), board_index], Vector3(-1.19 + board_index * 0.18, 0.0, face * 0.073), Vector3(0.172, 2.30, 0.052), board)
		for strap_index in range(2):
			var strap_y := -0.72 + strap_index * 1.44
			_box(leaf, "IronStrap%d_%d" % [int(face), strap_index], Vector3(-0.65, strap_y, face * 0.122), Vector3(1.20, 0.08, 0.045), iron)
			for pin_index in range(4):
				_box(leaf, "IronPin%d_%d_%d" % [int(face), strap_index, pin_index], Vector3(-1.12 + pin_index * 0.31, strap_y, face * 0.151), Vector3(0.038, 0.038, 0.025), rivet)
		_box(leaf, "RingPlate%d" % int(face), Vector3(-1.04, 0.0, face * 0.126), Vector3(0.25, 0.25, 0.025), iron)
		var ring := MeshInstance3D.new()
		ring.name = "IronRing%d" % int(face)
		ring.mesh = ring_mesh
		ring.position = Vector3(-1.04, -0.025, face * 0.17)
		ring.rotation.x = PI * 0.5
		ring.material_override = rivet
		leaf.add_child(ring)


func _build_windows() -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 3.8
		_box(self, "WindowFrame_%d" % int(side), Vector3(x, 2.08, -4.76), Vector3(1.65, 1.05, 0.12), _materials["dark_wood"])
		_box(self, "WindowGlass_%d" % int(side), Vector3(x, 2.08, -4.68), Vector3(1.38, 0.78, 0.035), _materials["window"])
		_box(self, "WindowBar_%d" % int(side), Vector3(x, 2.08, -4.65), Vector3(0.055, 0.78, 0.045), _materials["brass"])


func _build_furniture() -> void:
	_build_cabinet()
	var desk := Node3D.new()
	desk.name = "RecordsDesk"
	desk.position = Vector3(3.0, 0.0, -2.5)
	add_child(desk)
	_box(desk, "DeskTop", Vector3(0.0, 1.05, 0.0), Vector3(2.8, 0.16, 1.35), _materials["wood"])
	for x in [-1.18, 1.18]:
		for z in [-0.48, 0.48]:
			_box(desk, "Leg_%d_%d" % [int(x * 10), int(z * 10)], Vector3(x, 0.58, z), Vector3(0.17, 1.0, 0.17), _materials["dark_wood"])
	_collision("Desk", desk.position + Vector3(0.0, 0.7, 0.0), Vector3(2.8, 1.4, 1.35))
	for index in range(3):
		_box(desk, "Ledger_%d" % index, Vector3(-0.65 + index * 0.16, 1.17 + index * 0.035, -0.15), Vector3(0.8, 0.035, 0.55), _materials["paper"])
	_box(desk, "DeskInkpot", Vector3(0.95, 1.23, 0.3), Vector3(0.17, 0.22, 0.17), _materials["cabinet"])
	for shelf_index in range(3):
		var height := 0.68 + shelf_index * 0.72
		_box(self, "NorthShelf_%d" % shelf_index, Vector3(0.0, height, -4.47), Vector3(2.8, 0.12, 0.58), _materials["wood"])
		for file_index in range(5):
			_box(self, "ShelfFile_%d_%d" % [shelf_index, file_index], Vector3(-1.05 + file_index * 0.48, height + 0.16, -4.45), Vector3(0.34, 0.27, 0.38), _materials["paper"] if file_index % 2 == 0 else _materials["red_paper"])


func _build_cabinet() -> void:
	var cabinet := Node3D.new()
	cabinet.name = "FilingCabinet"
	cabinet.position = Vector3(-3.2, 0.0, -3.5)
	add_child(cabinet)
	_box(cabinet, "LeftSide", Vector3(-0.85, 1.13, 0.0), Vector3(0.14, 1.8, 0.82), _materials["cabinet"])
	_box(cabinet, "RightSide", Vector3(0.85, 1.13, 0.0), Vector3(0.14, 1.8, 0.82), _materials["cabinet"])
	_box(cabinet, "Back", Vector3(0.0, 1.13, -0.36), Vector3(1.7, 1.8, 0.1), _materials["cabinet"])
	_box(cabinet, "Top", Vector3(0.0, 2.07, 0.0), Vector3(1.84, 0.14, 0.9), _materials["dark_wood"])
	_box(cabinet, "Base", Vector3(0.0, 0.26, 0.0), Vector3(1.84, 0.12, 0.9), _materials["dark_wood"])
	_box(cabinet, "LowerDrawer", Vector3(0.0, 0.76, 0.43), Vector3(1.55, 0.57, 0.09), _materials["wood"])
	_box(cabinet, "LowerHandle", Vector3(0.0, 0.76, 0.5), Vector3(0.38, 0.055, 0.08), _materials["brass"])
	_collision("Cabinet", cabinet.position + Vector3(0.0, 1.12, 0.0), Vector3(1.84, 1.85, 0.9))
	_drawer = Node3D.new()
	_drawer.name = "Drawer"
	_drawer.position = Vector3(0.0, 1.48, 0.0)
	cabinet.add_child(_drawer)
	_box(_drawer, "Front", Vector3(0.0, 0.0, 0.43), Vector3(1.55, 0.55, 0.09), _materials["wood"])
	_box(_drawer, "Handle", Vector3(0.0, 0.0, 0.5), Vector3(0.42, 0.055, 0.08), _materials["brass"])
	_box(_drawer, "Tray", Vector3(0.0, -0.24, 0.05), Vector3(1.46, 0.055, 0.72), _materials["dark_wood"])
	for side in [-1.0, 1.0]:
		_box(_drawer, "TraySide_%d" % int(side), Vector3(side * 0.72, -0.08, 0.05), Vector3(0.05, 0.3, 0.72), _materials["dark_wood"])
	_records = Node3D.new()
	_records.name = "RecordsBundle"
	_records.position = Vector3(0.0, -0.16, 0.06)
	_drawer.add_child(_records)
	for index in range(4):
		_box(_records, "Folder_%d" % index, Vector3(0.0, index * 0.035, -0.04 + index * 0.015), Vector3(1.05, 0.025, 0.42), _materials["paper"] if index % 2 == 0 else _materials["red_paper"])
	_box(_records, "WaxSeal", Vector3(0.35, 0.16, 0.02), Vector3(0.12, 0.035, 0.12), _materials["brass"])
	# The upright cover remains visible above the drawer front in the dialogue shot.
	_box(_records, "LedgerCover", Vector3(0.0, 0.35, -0.12), Vector3(0.92, 0.66, 0.07), _materials["red_paper"])
	_box(_records, "LedgerTitle", Vector3(0.0, 0.44, -0.075), Vector3(0.48, 0.09, 0.015), _materials["brass"])


func _build_lighting() -> void:
	for side in [-1.0, 1.0]:
		var x: float = float(side) * 5.0
		_box(self, "SconceArm_%d" % int(side), Vector3(x, 2.48, -4.52), Vector3(0.12, 0.12, 0.58), _materials["brass"])
		_box(self, "SconceGlow_%d" % int(side), Vector3(x, 2.47, -4.14), Vector3(0.27, 0.34, 0.27), _materials["lamp"])
		var lamp := OmniLight3D.new()
		lamp.name = "WarmLamp_%d" % int(side)
		lamp.position = Vector3(x, 2.48, -3.95)
		lamp.light_color = Color("ffd6a3")
		lamp.light_energy = 1.1
		lamp.omni_range = 7.0
		add_child(lamp)
