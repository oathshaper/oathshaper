extends Node3D
## Recoverable payroll at the defeated raider, never a second office chest.
static func quay_position() -> Vector3:
	# Ivo holds the surrendered raider on the clear central path.
	return preload("res://scripts/garden_layout.gd").point(Vector3(41.3 + 4.0 / 1.7, .54, -2))

func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var pouch := SphereMesh.new()
	pouch.radius = .18
	pouch.height = .42
	mesh.mesh = pouch
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = preload("res://assets/textures/materials/sailcloth_canvas_albedo.png")
	cloth.albedo_color = Color("967249")
	mesh.material_override = cloth
	add_child(mesh)
	var tie := MeshInstance3D.new()
	var cord := TorusMesh.new()
	cord.inner_radius = .07
	cord.outer_radius = .09
	tie.mesh = cord
	tie.position.y = .16
	add_child(tie)
