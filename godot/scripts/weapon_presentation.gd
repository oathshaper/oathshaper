extends Node3D
const POSE := preload("res://scripts/combat_pose.gd")
const HAND := preload("res://scripts/hand_attachment.gd")
const MOUNT := preload("res://scripts/equipment_mount.gd")
var pose: SkeletonModifier3D
var grip: Node3D
var visual: Node3D
var flash: MeshInstance3D
var kind := "sabre"

func _ready() -> void:
	var skeletons := get_parent().get_node("ModelSlot").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_warning("Practice weapons require a rigged player with RHand.")
		return
	var skeleton := skeletons[0] as Skeleton3D
	pose = POSE.new()
	skeleton.add_child(pose)
	grip = HAND.new()
	grip.bone_name = "RHand"
	skeleton.add_child(grip)
	visual = Node3D.new()
	grip.add_child(visual)
	configure(kind)

func _part(parent: Node3D, dimensions: Vector3, offset: Vector3, color: Color, metallic := false) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = offset
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.75 if metallic else 0.0
	material.roughness = 0.38 if metallic else 0.8
	part.material_override = material
	parent.add_child(part)
	return part

func configure(weapon_kind: String) -> void:
	kind = weapon_kind
	if visual == null:
		return
	pose.sheathe()
	pose.kind = kind
	for child in visual.get_children():
		visual.remove_child(child)
		child.queue_free()
	flash = null
	visual.hide()
	visual.transform = Transform3D.IDENTITY
	if kind == "sabre" and MOUNT.mount(visual, kind, grip.global_basis.get_scale().x, MOUNT.palm_frame(grip.get_parent(), "R")).imported:
		return
	visual.scale = Vector3.ONE * 2.0 / maxf(grip.global_basis.get_scale().x, .001)
	# This rig's hand Y runs along the fingers; its Z points through the palm.
	visual.rotation.x = -PI / 2.0 if kind == "carbine" else PI
	# Units here are local to the imported rig, which the model slot scales 2x.
	if kind == "sabre":
		_part(visual, Vector3(.035, .035, .09), Vector3(0, .035, 0), Color("43372e"))
		_part(visual, Vector3(.14, .025, .035), Vector3(0, .035, .065), Color("bfa467"), true)
		_part(visual, Vector3(.036, .012, .34), Vector3(0, .035, .25), Color("c3d2d4"), true)
	elif kind == "carbine":
		_part(visual, Vector3(.075, .075, .24), Vector3(0, .035, .10), Color("334a50"), true)
		_part(visual, Vector3(.04, .1, .05), Vector3(0, .08, .02), Color("473d31"))
		_part(visual, Vector3(.034, .034, .17), Vector3(0, .035, .30), Color("a4b6b8"), true)
		_part(visual, Vector3(.06, .065, .09), Vector3(0, .035, -.06), Color("544d3e"))
		flash = _part(visual, Vector3(.07, .07, .09), Vector3(0, .035, .42), Color("e8f9bf"))
		var material := flash.material_override as StandardMaterial3D
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash.hide()

func set_readied(value: bool) -> void:
	if pose == null:
		return
	pose.readied = value
	if not value:
		pose.sheathe()
	visual.visible = value and kind != "unarmed"

func strike() -> bool:
	if pose == null or not pose.strike():
		return false
	set_readied(true)
	return true

func _process(_delta: float) -> void:
	if flash != null:
		flash.visible = pose.readied and pose.strike_time >= 0.0 and pose.strike_time < .09
