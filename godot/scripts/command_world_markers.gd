extends Control
## Screen-space names and a single selected-target marker. No depth fighting,
## perspective-scaled text, or overlapping nameplates.
var stage: Node3D
var placed_labels: Array[Rect2] = []
var reticle_target := ""
var reticle_center := Vector2.ZERO
var aim_text := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	placed_labels.clear()
	reticle_target = ""
	if stage == null or stage.camera == null:
		return
	var camera: Camera3D = stage.camera
	var area := get_viewport_rect()
	var selected := str(stage._state.get("party", {}).get("selected_target_id", stage._state.get("hero", {}).get("target_id", "")))
	var font := ThemeDB.fallback_font
	var rows: Array = stage._state.get("actors", []).duplicate()
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.id == selected: return b.id != selected
		if b.id == selected: return false
		return str(a.id) < str(b.id))
	# These are the HUD's occupied areas. Keep names out of controls as well as
	# each other; a far/offscreen actor remains identifiable in the party strip.
	var blocked: Array[Rect2] = [Rect2(0, 0, area.size.x, 80), Rect2(0, 80, 365, 145), Rect2(area.size.x - 295, 80, 295, 155), Rect2(0, area.size.y - 290, area.size.x, 290)]
	for actor in rows:
		if str(actor.id) != selected: continue
		if not actor.get("conscious", false) or not stage.actors.has(str(actor.id)):
			continue
		var body: Node3D = stage.actors[str(actor.id)]
		if not body.visible:
			continue
		var height := 1.9 if body.has_node("ModelSlot") else float(body.get_node("Art").model_height)
		var center := body.global_position + Vector3.UP * height * .55
		if camera.is_position_behind(center):
			continue
		var point := camera.unproject_position(center)
		if not area.has_point(point): continue
		if str(actor.id) == selected and area.has_point(point):
			reticle_target = selected
			reticle_center = point
			_draw_reticle(point, Color("ffb16d") if actor.faction == "hostile" else Color("b5e8ca"))
		var head := camera.unproject_position(body.global_position + Vector3.UP * (height + .22))
		var text := str(actor.name)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14
		var rect := Rect2(head - Vector2(width * .5, 22), Vector2(width, 24))
		var fits := false
		for step in range(3):
			var candidate := Rect2(rect.position - Vector2(0, step * 27), rect.size)
			if not area.encloses(candidate): continue
			var collision := false
			for other in blocked + placed_labels:
				if candidate.grow(3).intersects(other): collision = true; break
			if not collision:
				rect = candidate
				fits = true
				break
		if not fits: continue
		placed_labels.append(rect)
		if head.y - rect.end.y > 8:
			draw_line(Vector2(rect.get_center().x, rect.end.y), head, Color(.75, .81, .78, .65), 1, true)
		draw_style_box(_label_style(), rect)
		draw_string(font, rect.position + Vector2(7, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffcf9e") if actor.faction == "hostile" else Color("e8f1e9"))
	if not aim_text.is_empty():
		var width := font.get_string_size(aim_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 24
		var rect := Rect2(Vector2((area.size.x - width) * .5, area.size.y - 326), Vector2(width, 30))
		draw_style_box(_label_style(), rect)
		draw_string(font, rect.position + Vector2(12, 22), aim_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("fff1d8"))

func _label_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, .055, .06, .88)
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _draw_reticle(center: Vector2, color: Color) -> void:
	# Four inward arrowheads form the familiar broken X, leaving the body visible.
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var tip: Vector2 = center + direction * 9
		var outer: Vector2 = center + direction * 28
		var tangent: Vector2 = Vector2(-direction.y, direction.x) * 7
		var polygon := PackedVector2Array([tip, outer + tangent, outer - tangent])
		draw_colored_polygon(polygon, color)
		draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[0]]), Color("162027"), 2, true)
