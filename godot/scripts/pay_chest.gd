extends Node3D
## The forced-open payroll chest stays in the clerk's office.
var _coins: Node3D

func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/textures/materials/weathered_timber_albedo.png")
	wood.albedo_color = Color("b79a71")
	wood.roughness = .85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("353936")
	iron.metallic = .7
	iron.roughness = .5
	_box("Bottom", Vector3(0, .04, 0), Vector3(1.2, .08, .72), wood)
	for x in [-.56, .56]:
		_box("Side", Vector3(x, .28, 0), Vector3(.08, .48, .72), wood)
	for z in [-.32, .32]:
		_box("FrontBack", Vector3(0, .28, z), Vector3(1.2, .48, .08), wood)
	_box("Lid", Vector3(0, .86, -.48), Vector3(1.24, .76, .08), wood)
	get_node("Lid").rotation.x = deg_to_rad(-20)
	for x in [-.4, .4]:
		_box("Band", Vector3(x, .29, .365), Vector3(.07, .50, .02), iron)
	_box("BrokenHasp", Vector3(.02, .48, .38), Vector3(.1, .1, .04), iron)
	_box("BrokenLock", Vector3(.65, .015, .5), Vector3(.15, .03, .15), iron)
	_coins = Node3D.new()
	_coins.name = "ReturnedPayroll"
	add_child(_coins)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color("c7c0a6")
	silver.metallic = .8
	for i in range(18):
		var coin := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = .055
		shape.bottom_radius = .055
		shape.height = .015
		coin.mesh = shape
		coin.material_override = silver
		coin.position = Vector3(-.3 + (i % 6) * .12, .1 + (i % 3) * .015, -.18 + (i / 6) * .13)
		_coins.add_child(coin)
	_coins.hide()

func set_filled(filled: bool) -> void:
	_coins.visible = filled

func _box(title: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = title
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.material_override = material
	part.position = at
	add_child(part)
