extends SceneTree
## Real core-owned gear projected at the Steam Deck viewport; no mutations from preview.
var checks := 0
var failures := 0
var requests: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func copy_of(node: Node) -> String:
	var copy := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	for child in node.get_children():
		copy += copy_of(child)
	return copy

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var bridge: RefCounted = ClassDB.instantiate("CommandBridge")
	var response: Dictionary = JSON.parse_string(bridge.call("create", "20261022"))
	check(response.get("ok", false), "Command bridge creates a real equipment view")
	var view: Dictionary = response.data.get("view", response.data)
	var ledger := preload("res://scripts/command_ledger.gd").new()
	root.add_child(ledger)
	ledger.requested.connect(func(action: Dictionary) -> void: requests.append(action))
	ledger.open(view)
	ledger._select_tab(1)
	var layouts: Array[String] = []
	var serial := 0
	for actor_id in ["player", "mara", "clerk", "ivo"]:
		serial += 1
		var envelope := {"schema": "command.action/v1", "command_id": "equipment-test-" + str(serial), "generation": view.session.generation, "expected_revision": view.session.revision, "action": {"kind": "party.inspect", "actor_id": actor_id}}
		response = JSON.parse_string(bridge.call("submit", JSON.stringify(envelope)))
		check(response.get("ok", false), "Inspect " + actor_id)
		view = response.data.view
		ledger.apply_view(view, true)
		await process_frame
		await process_frame
		var original := JSON.stringify(view)
		check(ledger._slot == "main_hand", actor_id + " starts with the main-hand inventory")
		check(ledger._buttons.has("slot:head") and ledger._buttons.has("slot:belt"), actor_id + " has all eight body slots")
		var columns: Control = ledger.find_child("EquipmentColumns", true, false)
		var body: Control = ledger.find_child("BodySlots", true, false)
		var owned: Control = ledger.find_child("OwnedEquipment", true, false)
		check(columns.get_global_rect().end.x <= 1262, actor_id + " equipment fits viewport width")
		check(body.get_global_rect().end.x < owned.global_position.x, actor_id + " slots and candidates stay side by side")
		check(body.get_global_rect().end.y <= 730, actor_id + " all body slots fit without page scrolling")
		check(owned.get_global_rect().end.y <= 730, actor_id + " candidate list fits above footer")
		var slots: Array = view.equipment.slots
		layouts.append(JSON.stringify(slots))
		for entry in slots:
			var slot: Button = ledger._buttons["slot:" + str(entry.id)]
			slot.pressed.emit()
			await process_frame
			var expected := 0
			for option in view.equipment.options:
				if not option.slot_ids.has(entry.id):
					continue
				expected += 1
				var button: Button = ledger._buttons.get("gear:" + str(option.id))
				check(button != null, actor_id + " compatible owned option is visible: " + str(option.id))
				check(button.disabled == (not option.available), "Core availability is preserved")
				if not button.disabled:
					button.pressed.emit()
					check(requests.back() == {"kind": "ui.preview", "action": option.action}, "Comparison carries exact binding version and changes")
			var rendered := 0
			for key in ledger._buttons:
				if str(key).begins_with("gear:"):
					rendered += 1
			check(rendered == expected, "Selected slot excludes incompatible items")
		check(JSON.stringify(view) == original, "Equipment browsing does not mutate combat state")
		ledger._buttons["slot:main_hand"].pressed.emit()
		await process_frame
		await process_frame
		for node in ledger._buttons["slot:main_hand"].find_children("*", "Label", true, false):
			check(node.size.y >= 23, "Slot labels have visible rendered height")
		var text := copy_of(ledger)
		check(not text.contains("exposed") and not text.contains("Plans for"), "Equipment copy contains no implementation placeholders")
		var file := FileAccess.open("/tmp/oathshaper-command-equipment-" + actor_id + ".txt", FileAccess.WRITE)
		file.store_string(text)
		if OS.get_cmdline_user_args().has("--capture"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/oathshaper-command-equipment-" + actor_id + ".png")
	ledger._select_tab(3)
	await process_frame
	await process_frame
	check(ledger._buttons.has("deploy:ivo:replace:mara") and ledger._buttons.has("deploy:ivo:replace:clerk"), "Reserve Ivo has explicit choices of whom to replace")
	ledger._buttons["deploy:ivo:replace:clerk"].pressed.emit()
	check(requests.back() == {"kind": "ui.preview", "action": {"kind": "party.deploy", "actor_ids": ["player", "mara", "ivo"]}}, "Companion replacement requests exact full-roster core comparison")
	var party_copy := FileAccess.open("/tmp/oathshaper-command-party-ivo.txt", FileAccess.WRITE)
	party_copy.store_string(copy_of(ledger))
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-party-ivo.png")
	var encounter_view := view.duplicate(true)
	encounter_view.session.phase = "encounter"
	ledger.apply_view(encounter_view, true)
	check(ledger._buttons["deploy:ivo:replace:clerk"].disabled, "Companions cannot be replaced in combat")
	check(layouts[0] != layouts[1] and layouts[1] != layouts[2] and layouts[2] != layouts[3], "Every party member has different real gear")
	print("COMMAND_EQUIPMENT_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
