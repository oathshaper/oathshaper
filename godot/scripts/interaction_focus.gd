extends Control
## A screen-space focus bracket for the current interaction; names stay in the HUD.
var demo: Node3D
var _point := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	visible = demo.mode == "explore" and not demo._map_expanded
	var nearby: Dictionary = demo._nearest_interactable() if visible else {}
	# World labels share the reticle's exact target and disappear with its HUD.
	for npc in demo.npcs:
		var label: Label3D = npc.node.get_node_or_null("Name")
		if label != null: label.visible = false
	if nearby.is_empty():
		visible = false
		return
	var at: Vector3 = nearby.get("at", Vector3.ZERO)
	if nearby.has("node"): at = nearby.node.global_position + Vector3.UP * .65
	elif nearby.kind == "door": at = demo.hub.get_node("RecordsDoor").global_position + Vector3.UP * 1.1
	elif nearby.kind == "pay_loot": at = demo._pay_loot.global_position + Vector3.UP * .3
	elif nearby.kind == "garden": at = demo.GARDEN_ENTRY + Vector3.UP
	else: at += Vector3.UP * .45
	var camera: Camera3D = demo.camera_rig.camera
	visible = not camera.is_position_behind(at)
	if visible:
		_point = camera.unproject_position(at)
		if nearby.has("node"):
			var label: Label3D = nearby.node.get_node_or_null("Name")
			if label != null: label.visible = true
	queue_redraw()

func _draw() -> void:
	var color := Color("dfc888")
	for sign_x in [-1, 1]:
		for sign_y in [-1, 1]:
			var corner := _point + Vector2(sign_x, sign_y) * 13
			draw_line(corner, corner - Vector2(sign_x * 7, 0), color, 2, true)
			draw_line(corner, corner - Vector2(0, sign_y * 7), color, 2, true)
