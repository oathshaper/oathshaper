extends SceneTree
## Run against the exported story scene: editor-only checks miss export data loss.
const ACTORS := {
	"Player": {"rig": "player", "placeholders": ["Body"]},
	"Mara": {"rig": "mara", "placeholders": ["Body"]},
	"Ivo": {"rig": "ivo", "placeholders": ["Body", "Mantle"]},
	"CivicClerk": {"rig": "clerk", "placeholders": ["Body", "Ledger"]},
	"Vendor": {"rig": "vendor", "placeholders": ["Body", "Pack"]},
}
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)

func frames() -> void:
	await process_frame
	await process_frame

func inspect_characters(demo: Node, phase: String) -> void:
	for id in ACTORS:
		var actor: Node3D = demo.get_node(id)
		var slot = actor.get_node("ModelSlot")
		var expected: Dictionary = ACTORS[id]
		var label: String = phase + ": " + id
		check(slot.placeholder_names == PackedStringArray(expected.placeholders), label + " retains authored placeholder list after export")
		var model := slot.get_node_or_null("ImportedModel") as Node3D
		check(model != null and slot.active_model_path() == "res://assets/meshes/rigged/%s_rigged.glb" % expected.rig, label + " loads the intended model")
		check(slot.motion_mode() == "rigged", label + " keeps skeletal animation")
		# Check known scene geometry independently of the exported list, so an
		# empty list cannot make a missing-placeholder check pass vacuously.
		for name in expected.placeholders:
			var placeholder := actor.get_node_or_null(NodePath(name)) as VisualInstance3D
			check(placeholder != null and not placeholder.visible, label + " hides primitive " + name)
		if model != null and actor.is_visible_in_tree():
			var textured_surfaces := 0
			for mesh in model.find_children("*", "MeshInstance3D", true, false):
				if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
				for surface in mesh.mesh.get_surface_count():
					var material = mesh.get_active_material(surface)
					if material is BaseMaterial3D and material.albedo_texture != null: textured_surfaces += 1
			check(textured_surfaces > 0, label + " renders textured character surfaces")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/oathshaper-character-" + name + ".png")

func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(1))
	root.size = Vector2i(1280, 800)
	var main = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	main.save_path = "user://character-presentation-%s.json" % Time.get_ticks_usec()
	root.add_child(main)
	await frames()
	main._start_new("command")
	await frames()
	inspect_characters(main._demo, "opening")
	await capture("opening")
	if main._demo.has_node("QuayOpening"): main._demo.get_node("QuayOpening").finish()
	await frames()
	inspect_characters(main._demo, "quay")
	await capture("quay")
	main._demo._enter_records_office()
	await frames()
	inspect_characters(main._demo, "office")
	await capture("office")
	main._demo._leave_records_office()
	await frames()
	check(main._demo._save(), "Fixture journey saves without touching player saves")
	main._start_load("command")
	await frames()
	inspect_characters(main._demo, "loaded journey")
	print("CHARACTER_PRESENTATION: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
