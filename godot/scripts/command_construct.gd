extends Node3D
## Original articulated bronze/stone wards. All motion is cosmetic and follows host ticks.
var kind := "hound"
var _body: Node3D
var _head: Node3D
var _jaw: Node3D
var _emitter: Node3D
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _feet: Array[Node3D] = []
var _last_tick := 0
var _attack_at := -100
var _paused := true
var _bronze: StandardMaterial3D
var _dark: StandardMaterial3D
var _stone: StandardMaterial3D
var _glow: StandardMaterial3D

func _ready() -> void:
	configure(kind)

func _material(color: String, metal := 0.0, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metal
	material.roughness = roughness
	return material

func _materials() -> void:
	_bronze = _material("a28b60", .75, .38)
	_dark = _material("2c4042", .65, .54)
	_stone = _material("c2c2ac", .04, .86)
	_stone.albedo_texture = load("res://assets/textures/materials/coastal_rock_albedo.png")
	_stone.uv1_scale = Vector3(1.5, 1.5, 1.0)
	_glow = _material("e7b969", .2, .25)
	_glow.emission_enabled = true
	_glow.emission = Color("ffb668")
	_glow.emission_energy_multiplier = 1.2

func _part(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _oval(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var part := _part(parent, mesh, at, material)
	part.scale = dimensions
	return part

func _rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material, end_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if end_radius < 0 else end_radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 16
	var part := _part(parent, mesh, (from + to) * .5, material)
	part.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	return part

func _ring(parent: Node3D, at: Vector3, inner: float, outer: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	return _part(parent, mesh, at, material)

func _pivot(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = label
	pivot.position = at
	parent.add_child(pivot)
	return pivot

func configure(construct_kind: String) -> void:
	kind = construct_kind.to_lower()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_legs.clear()
	_knees.clear()
	_feet.clear()
	_materials()
	_body = _pivot(self, "ArmoredBody", Vector3.ZERO)
	_head = null
	_jaw = null
	_emitter = null
	_attack_at = -100
	if kind == "hound":
		_hound()
	elif kind == "sentinel":
		_sentinel()
	else:
		push_warning("Unknown ward construct: " + kind)

func _hound() -> void:
	_oval(_body, Vector3(0, .81, .04), Vector3(.52, .38, .93), _dark)
	# Overlapping mapped stone carapace plates expose bronze ribs and articulated joints.
	for z in [-.24, .03, .29]:
		_oval(_body, Vector3(0, .94, z), Vector3(.57, .20, .35), _stone)
		var rib := _ring(_body, Vector3(0, .81, z), .22, .25, _bronze)
		rib.rotation.x = PI * .5
		rib.scale.y = .78
	_rod(_body, Vector3(0, 1.04, -.31), Vector3(0, 1.04, .43), .025, _bronze)
	_head = _pivot(_body, "ArticulatedHead", Vector3(0, .94, -.51))
	_oval(_head, Vector3.ZERO, Vector3(.35, .32, .40), _bronze)
	_oval(_head, Vector3(0, .06, -.04), Vector3(.29, .19, .35), _stone)
	_oval(_head, Vector3(0, -.045, -.26), Vector3(.23, .14, .33), _dark)
	_oval(_head, Vector3(0, -.025, -.40), Vector3(.19, .10, .07), _bronze)
	_jaw = _pivot(_head, "Jaw", Vector3(0, -.11, -.10))
	_oval(_jaw, Vector3(0, 0, -.18), Vector3(.20, .065, .34), _bronze)
	for side in [-1, 1]:
		_oval(_head, Vector3(side * .157, .04, -.12), Vector3(.045, .058, .095), _glow)
		_rod(_head, Vector3(side * .12, .12, .06), Vector3(side * .15, .30, .035), .057, _bronze, .010)
		_rod(_jaw, Vector3(side * .065, .015, -.25), Vector3(side * .065, .065, -.25), .015, _stone, .003)
		for front in [-1, 1]:
			var leg := _pivot(_body, "Hip_%d_%d" % [side, front], Vector3(side * .29, .77, front * .32))
			_legs.append(leg)
			_oval(leg, Vector3.ZERO, Vector3.ONE * .22, _bronze)
			var knee_at := Vector3(side * .025, -.29, .10 if front == 1 else -.06)
			_rod(leg, Vector3.ZERO, knee_at, .07, _dark, .05)
			_oval(leg, knee_at * .45, Vector3(.16, .26, .18), _stone)
			var knee := _pivot(leg, "Knee", knee_at)
			_knees.append(knee)
			_oval(knee, Vector3.ZERO, Vector3.ONE * .14, _bronze)
			_rod(knee, Vector3.ZERO, Vector3(0, -.31, -.065), .042, _dark)
			_rod(knee, Vector3(side * .055, -.03, 0), Vector3(side * .055, -.25, -.05), .018, _bronze)
			var foot := _pivot(knee, "Paw", Vector3(0, -.35, -.08))
			_feet.append(foot)
			_oval(foot, Vector3(0, .005, -.04), Vector3(.20, .10, .29), _bronze)
			for toe in [-1, 0, 1]:
				_oval(foot, Vector3(toe * .055, 0, -.17), Vector3(.04, .055, .08), _dark)
	var tail := _pivot(_body, "CounterweightTail", Vector3(0, .87, .49))
	_rod(tail, Vector3.ZERO, Vector3(0, .15, .32), .04, _bronze, .022)
	_oval(tail, Vector3(0, .15, .32), Vector3(.07, .08, .15), _dark)

func _sentinel() -> void:
	# Three splayed hydraulic legs, not a wooden column; upper turret can swivel independently.
	for index in range(3):
		var angle := TAU * index / 3.0
		var leg := _pivot(_body, "Support_%d" % index, Vector3(sin(angle) * .18, .53, cos(angle) * .18))
		leg.rotation.y = angle
		_legs.append(leg)
		_oval(leg, Vector3.ZERO, Vector3.ONE * .19, _bronze)
		_rod(leg, Vector3.ZERO, Vector3(0, -.21, .22), .075, _dark, .055)
		var knee := _pivot(leg, "Knee", Vector3(0, -.21, .22))
		_knees.append(knee)
		_oval(knee, Vector3.ZERO, Vector3.ONE * .16, _bronze)
		_rod(knee, Vector3.ZERO, Vector3(0, -.23, .09), .05, _dark)
		_oval(leg, Vector3(0, -.07, .10), Vector3(.18, .17, .29), _stone)
		var foot := _pivot(knee, "Foot", Vector3(0, -.25, .12))
		_feet.append(foot)
		_oval(foot, Vector3.ZERO, Vector3(.27, .09, .32), _bronze)
	_oval(_body, Vector3(0, .78, 0), Vector3(.62, .65, .56), _dark)
	for angle in [0.0, PI * .5, PI, PI * 1.5]:
		var plate := _oval(_body, Vector3(sin(angle) * .24, .83, cos(angle) * .22), Vector3(.23, .50, .17), _stone)
		plate.rotation.y = angle
	_ring(_body, Vector3(0, .57, 0), .24, .29, _bronze)
	_ring(_body, Vector3(0, 1.04, 0), .24, .29, _bronze)
	_rod(_body, Vector3(0, 1.02, 0), Vector3(0, 1.20, 0), .11, _bronze)
	_head = _pivot(_body, "SwivelTurret", Vector3(0, 1.25, 0))
	_oval(_head, Vector3.ZERO, Vector3(.54, .42, .46), _bronze)
	_oval(_head, Vector3(0, .12, .01), Vector3(.48, .18, .44), _stone)
	for side in [-1, 1]:
		_oval(_head, Vector3(side * .24, .01, .01), Vector3(.09, .25, .30), _dark)
		_oval(_head, Vector3(side * .14, .06, -.205), Vector3(.045, .055, .045), _glow)
	_emitter = _pivot(_head, "WardEmitter", Vector3(0, -.03, -.20))
	_rod(_emitter, Vector3.ZERO, Vector3(0, 0, -.26), .10, _dark, .065)
	for z in [-.04, -.16, -.25]:
		var ring := _ring(_emitter, Vector3(0, 0, z), .07, .095, _bronze)
		ring.rotation.x = PI * .5
	_oval(_emitter, Vector3(0, 0, -.265), Vector3(.105, .105, .025), _glow)
	for side in [-1, 1]:
		_rod(_head, Vector3(side * .20, -.06, -.10), Vector3(side * .11, -.06, -.40), .022, _bronze)
	_rod(_head, Vector3(0, .18, .10), Vector3(0, .38, .10), .025, _bronze, .006)

func set_motion(velocity: Vector3, tick: int, paused: bool) -> void:
	_paused = paused
	if paused or _body == null:
		return
	if tick < _last_tick:
		_attack_at = -100
	_last_tick = tick
	var speed := clampf(Vector2(velocity.x, velocity.z).length() / 2.5, 0.0, 1.0)
	var phase := float(tick) * .66
	var attack := clampf(1.0 - float(tick - _attack_at) / 5.0, 0.0, 1.0)
	_body.position.y = absf(sin(phase)) * .025 * speed
	if kind == "hound":
		for index in range(_legs.size()):
			var offset := PI if index in [1, 2] else 0.0
			var step := sin(phase + offset)
			_legs[index].rotation.x = step * .36 * speed
			_knees[index].rotation.x = maxf(0.0, -step) * .48 * speed
			_feet[index].rotation.x = -step * .15 * speed
		_head.rotation.x = -.16 * attack
		_head.position.z = -.51 - .10 * attack
		_jaw.rotation.x = .36 * attack
	elif kind == "sentinel":
		_head.rotation.y = sin(float(tick) * .035) * .12 if speed < .05 else 0.0
		_emitter.position.z = -.20 + .075 * attack
		for index in range(_legs.size()):
			_legs[index].rotation.x = sin(phase + index * TAU / 3.0) * .12 * speed
	_glow.emission_energy_multiplier = 1.2 + attack * 1.8

func show_attack() -> void:
	_attack_at = _last_tick
	# A host-triggered flash is presentation only; motion remains frozen on paused ticks.
	if not _paused:
		_glow.emission_energy_multiplier = 3.0
