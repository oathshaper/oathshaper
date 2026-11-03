extends SceneTree
const JOURNAL := preload("res://scripts/journal_menu.gd")

## Runs the full records route through the real scene and action mappings.
## Run with: Godot --headless --path godot --script res://tests/route_integration_test.gd

var _save_path: String = "user://oathshaper_route_integration_%d.save.json" % Time.get_ticks_usec()
var _demo: Node3D
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _joy(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(button: int) -> void:
	_joy(button, true)
	await process_frame
	_joy(button, false)
	await process_frame


func _finish_player_reply() -> void:
	var panel := _demo.get_node("CanvasLayer/DialoguePanel")
	if panel.get("_player_reply"):
		panel.call("_finish_line")
		await process_frame


func _key_tap(code: int) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await process_frame


func _expect(condition: bool, description: String) -> bool:
	if condition:
		return true
	_failures.append(description)
	push_error("Records route integration failed: " + description)
	return false


func _flag(name: String) -> bool:
	var state: Dictionary = _demo.get("_story_state")
	var flags: Dictionary = state.get("flags", {})
	return bool(flags.get(name, false))


func _node_id() -> String:
	var view: Dictionary = _demo.call("_call_bridge", "view")
	return str(view.get("data", {}).get("node_id", ""))


func _content_has(journal: Control, fragment: String) -> bool:
	var content: Control = journal.get("_content") as Control
	if content == null:
		return false
	for child in content.find_children("*", "Label", true, false):
		if (child as Label).text.contains(fragment):
			return true
	return false

func _page_is(journal: Control, name: String) -> bool:
	return JOURNAL.TAB_NAMES[int(journal.get("_current_tab"))] == name

func _shoulder_to(journal: Control, name: String) -> void:
	for step in range(JOURNAL.TAB_NAMES.size()):
		if _page_is(journal, name):
			return
		await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	_expect(false, "controller cannot reach page " + name)


func _new_demo(scene: PackedScene) -> void:
	_demo = scene.instantiate() as Node3D
	_demo.set("save_path", _save_path)
	root.add_child(_demo)
	await process_frame
	await process_frame


func _remove_demo() -> void:
	if _demo != null and is_instance_valid(_demo):
		root.remove_child(_demo)
		_demo.queue_free()
		_demo = null
	await process_frame


func _finish() -> void:
	await _remove_demo()
	for suffix in ["", ".tmp"]:
		var path: String = _save_path + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if _failures.is_empty():
		print("Records route integration passed: open office, clerk conversation, controller map and journal, cabinet, records, and save/load")
	else:
		print("Records route integration failed (%d assertion(s))" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	if not _expect(ClassDB.class_exists("NarrativeBridge"), "native NarrativeBridge loads"):
		await _finish()
		return
	var scene: PackedScene = load("res://scenes/demo.tscn")
	if not _expect(scene != null, "demo scene loads"):
		await _finish()
		return
	await _new_demo(scene)
	var player := _demo.get_node("Player") as CharacterBody3D
	var panel := _demo.get_node("CanvasLayer/DialoguePanel") as Control
	var journal := _demo.get_node("CanvasLayer/JournalMenu") as Control
	var map := _demo.get_node("CanvasLayer/MapWidget") as Control
	var office := _demo.get_node("RecordsOffice") as Node3D
	var status := _demo.get_node("CanvasLayer/Status") as Label
	var records := office.get_node("FilingCabinet/Drawer/RecordsBundle") as Node3D
	if not _expect(_demo.get("bridge") != null and map.get("_waypoint_id") == "clerk", "new game points to the clerk in her office"):
		await _finish()
		return

	# The signed west archive door is reachable but locked until the clue is earned.
	player.global_position = Vector3(-8.3, 1.05, -26.0)
	await process_frame
	# The court parapet must open at the doorway. Move the real capsule toward
	# the facade, then check that its neighboring wing still blocks the edge.
	var door_approach := player.move_and_collide(Vector3(-2.0, 0.0, 0.0))
	_expect(door_approach != null and player.global_position.x < -9.65 and player.global_position.x > -10.05, "player physically reaches the archive threshold through the parapet opening")
	player.global_position = Vector3(-8.3, 1.05, -28.2)
	var parapet_wing := player.move_and_collide(Vector3(-2.0, 0.0, 0.0))
	_expect(parapet_wing != null and player.global_position.x > -9.55, "court parapet still blocks travel beside the archive doorway")
	player.global_position = Vector3(-8.3, 1.05, -26.0)
	if not _expect(_demo.call("_nearest_interactable").get("kind") == "door", "door has a scene-owned interaction point"):
		await _finish()
		return
	await _tap(0) # A / interact
	_expect(_demo.call("_area_id") == "records_office" and not _flag("records_clue"), "Office can be entered before any paperwork question")

	player.global_position = _demo.get_node("CivicClerk").global_position + Vector3(0, 0, 1.8)
	await process_frame
	await _tap(0)
	if not _expect(_demo.get("mode") == "dialogue" and panel.visible and (panel.get_node("Panel/Margin/VBox/Speaker") as Label).text == "Clerk", "A opens the clerk conversation"):
		await _finish()
		return
	var buttons: Array = panel.get("buttons")
	_expect(buttons.size() >= 2 and not buttons[0].disabled and buttons.any(func(b): return b.get_meta("choice_id") == "ask_about_records"), "Clerk offers optional directions and local history")

	# Menu is available during dialogue and returns to the same line on close.
	await _tap(6) # Start / Menu
	_expect(_demo.get("mode") == "menu" and journal.visible and panel.visible and journal.get("_current_tab") == 0, "Start opens the ledger during dialogue")
	await _tap(6)
	_expect(_demo.get("mode") == "dialogue" and not journal.visible and panel.visible, "Start closes the ledger back to dialogue")
	for button in panel.buttons:
		if button.get_meta("choice_id") == "ask_about_records": panel._select_index(panel.buttons.find(button))
	await _tap(0) # A / ask_about_records
	await _finish_player_reply()
	if not _expect(_flag("records_clue") and map.get("_waypoint_id") == "clerk" and (panel.get_node("Panel/Margin/VBox/Subtitle") as Label).text.contains("cabinet"), "Archive permission is optional and preserves the robbery objective"):
		await _finish()
		return
	var clerk_leaf_buttons: Array = panel.get("buttons")
	_expect(clerk_leaf_buttons.is_empty(), "clerk response shows no artificial return or leave choices")
	await _tap(1) # B skips response to clerk questions.
	_expect(_demo.get("mode") == "dialogue" and _node_id() == "clerk_greeting", "B returns to the clerk question menu")
	await _tap(1) # B leaves the menu.
	_expect(_demo.get("mode") == "explore" and not panel.visible, "B at the question menu returns to exploration")

	await _tap(4) # View / expand map
	_expect(map.get("_expanded") and map.desired_size() == Vector2(540, 380), "View opens the expanded records waypoint map")
	await _tap(1) # B / collapse map
	_expect(not map.get("_expanded") and map.desired_size() == Vector2(260, 190) and _demo.get("mode") == "explore", "B collapses the map without leaving exploration")
	if map.get("_expanded"):
		await _tap(4) # Restore compact state so later interactions remain readable.

	player.global_position = Vector3(-8.3, 1.05, -26.0)
	await process_frame
	await _tap(0)
	if not _expect(_demo.call("_area_id") == "records_office" and office.visible and player.global_position.distance_to(office.call("entry_position")) < 0.15 and map.get("_waypoint_id") == "clerk", "A enters the optional archive without replacing the main objective"):
		await _finish()
		return
	player.global_position = (office.call("cabinet_position") as Vector3) + Vector3(0.0, 0.0, 1.7)
	await process_frame
	if not _expect(_demo.call("_nearest_interactable").get("kind") == "cabinet", "cabinet can be reached inside the office"):
		await _finish()
		return
	await _tap(0)
	if not _expect(_demo.get("mode") == "dialogue" and panel.visible and (panel.get_node("Panel/Margin/VBox/Speaker") as Label).text == "Filing Cabinet" and office.get("_drawer_open"), "A opens the drawer and its authored conversation"):
		await _finish()
		return
	await create_timer(0.5).timeout
	_expect(records.visible and absf((office.get("_drawer") as Node3D).position.z - 0.68) < 0.01, "drawer visibly extends with the untaken bundle inside")
	await _tap(12) # D-pad down / leave records
	_expect(panel.get("selected_index") == 1, "D-pad moves to the second cabinet choice")
	await _tap(11) # D-pad up / take records
	_expect(panel.get("selected_index") == 0, "D-pad returns to the take-records choice")
	await _tap(0)
	await _finish_player_reply()
	if not _expect(_flag("records_collected") and not records.visible and map.get("_waypoint_id") == "clerk" and (panel.get_node("Panel/Margin/VBox/Subtitle") as Label).text.contains("Lantern Quay"), "Taking history hides the booklet and preserves the robbery objective: flag=%s mesh=%s goal=%s text=%s" % [_flag("records_collected"), records.visible, map.get("_waypoint_id"), panel.subtitle.text]):
		await _finish()
		return
	await _tap(1) # B returns from the narrator response to the cabinet
	await _tap(0) # A / close drawer
	await create_timer(0.5).timeout
	if not _expect(_node_id() == "cabinet_left" and _demo.get("mode") == "dialogue" and not office.get("_drawer_open") and absf((office.get("_drawer") as Node3D).position.z) < 0.01, "Close reaches cabinet_left while the drawer shuts"):
		await _finish()
		return

	# A save at the closed dialogue node must restore the closed drawer, then
	# Look Again must open it without duplicating the collected records.
	await _tap(6) # Start / ledger during cabinet_left
	await _tap(9) # LB -> Save
	await _tap(0) # A / SAVE JOURNEY
	if not _expect(FileAccess.file_exists(_save_path), "cabinet_left dialogue save writes a file"):
		await _finish()
		return
	await _remove_demo()
	await _new_demo(scene)
	player = _demo.get_node("Player") as CharacterBody3D
	panel = _demo.get_node("CanvasLayer/DialoguePanel") as Control
	journal = _demo.get_node("CanvasLayer/JournalMenu") as Control
	map = _demo.get_node("CanvasLayer/MapWidget") as Control
	office = _demo.get_node("RecordsOffice") as Node3D
	status = _demo.get_node("CanvasLayer/Status") as Label
	records = office.get_node("FilingCabinet/Drawer/RecordsBundle") as Node3D
	await _tap(6) # Start
	await _tap(9) # LB -> Save
	await _tap(9) # LB -> Load
	await _tap(0) # A / LOAD JOURNEY
	if not _expect(_demo.get("mode") == "menu" and _demo.get("_menu_return_mode") == "dialogue" and _node_id() == "cabinet_left" and not office.get("_drawer_open") and _flag("records_collected") and not records.visible, "loading cabinet_left restores the dialogue with the drawer shut and records collected"):
		await _finish()
		return
	await create_timer(0.5).timeout
	_expect(absf((office.get("_drawer") as Node3D).position.z) < 0.01, "loaded cabinet_left drawer stays visually closed")
	await _tap(6) # Resume cabinet_left
	await _tap(0) # A / look_again
	await create_timer(0.5).timeout
	_expect(_node_id() == "cabinet_greeting" and office.get("_drawer_open") and absf((office.get("_drawer") as Node3D).position.z - 0.68) < 0.01 and not records.visible, "Look Again reopens the empty collected-records drawer")
	buttons = panel.get("buttons")
	_expect(buttons.size() == 2 and (buttons[0] as Button).get_meta("choice_id") == "leave_records" and (buttons[1] as Button).get_meta("choice_id") == "leave", "taken records choice disappears while Leave cabinet remains available")
	await _tap(12) # D-pad down / Leave cabinet
	await _tap(0) # A / exit cabinet dialogue
	await create_timer(0.5).timeout
	_expect(_demo.get("mode") == "explore" and not office.get("_drawer_open") and absf((office.get("_drawer") as Node3D).position.z) < 0.01, "Leave exits cabinet dialogue and fully closes its drawer")

	await _tap(6)
	if not _expect(_demo.get("mode") == "menu" and journal.visible, "Start opens the ledger in the records office"):
		await _finish()
		return
	await _shoulder_to(journal, "Inventory")
	_expect(_page_is(journal, "Inventory") and _content_has(journal, "HARBOR HISTORY"), "shoulder navigation shows the collected records in Inventory")
	await _shoulder_to(journal, "Map")
	var journal_map: Control = journal.get("_map_widget") as Control
	_expect(_page_is(journal, "Map") and journal_map != null and journal_map.get("_area") == "records_office" and journal_map.get("_waypoint_id") == "clerk", "Journal Map shows the office without completing the main quest")
	await _shoulder_to(journal, "Save")
	if not _expect(_page_is(journal, "Save") and journal.get("_action_button") != null, "shoulder navigation reaches the Save page"):
		await _finish()
		return
	var saved_position := player.global_position
	_expect(not office.get("_drawer_open"), "exploration save captures a closed cabinet")
	await _tap(0) # A / SAVE JOURNEY
	if not _expect(FileAccess.file_exists(_save_path) and status.text.contains("Saved"), "controller A writes the journal save"):
		await _finish()
		return
	var saved_file: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	_expect(typeof(saved_file) == TYPE_DICTIONARY and saved_file.get("schema") == 3 and saved_file.get("combat_profile") == "command" and (saved_file.get("player", []) as Array).size() == 3, "save file contains the versioned narrative, combat profile and position envelope")
	await _tap(6)
	_expect(_demo.get("mode") == "explore", "Start closes the ledger after saving")

	# A fresh scene provides a real state reset before journal Load.
	await _remove_demo()
	await _new_demo(scene)
	player = _demo.get_node("Player") as CharacterBody3D
	journal = _demo.get_node("CanvasLayer/JournalMenu") as Control
	map = _demo.get_node("CanvasLayer/MapWidget") as Control
	office = _demo.get_node("RecordsOffice") as Node3D
	records = office.get_node("FilingCabinet/Drawer/RecordsBundle") as Node3D
	_expect(not _flag("records_collected") and records.visible and _demo.call("_area_id") == "quay" and not office.visible and not office.get("_drawer_open"), "fresh quay scene hides the offstage office with no collected records")
	await _tap(6) # Start
	await _tap(9) # LB -> Save
	await _tap(9) # LB -> Load
	if not _expect(_page_is(journal, "Load"), "shoulder navigation reaches the Load page"):
		await _finish()
		return
	await _tap(0) # A / LOAD JOURNEY
	if not _expect(_demo.get("mode") == "menu" and office.visible and player.global_position.distance_to(saved_position) < 0.15 and _flag("records_clue") and _flag("records_collected") and not records.visible and not office.get("_drawer_open"), "journal Load restores visible office, position and both narrative flags with the drawer closed"):
		await _finish()
		return
	await create_timer(0.5).timeout
	_expect(absf((office.get("_drawer") as Node3D).position.z) < 0.01, "exploration Load leaves the drawer visually closed")
	_expect(map.get("_waypoint_id") == "clerk" and journal.get("_area") == "records_office", "loaded map and journal present the saved office state")
	await _tap(6)
	_expect(_demo.get("mode") == "explore" and _demo.call("_area_id") == "records_office", "closing the loaded journal returns to office exploration")
	var completed_tracker := _demo.get_node("CanvasLayer/ObjectiveTracker") as Control
	var completed_title := completed_tracker.get("_heading") as Label
	_expect(completed_tracker.visible and completed_title.get_theme_color("font_color") == Color("#ffdb72") and (completed_tracker.get("_panel_style") as StyleBoxFlat).border_color == Color("#ffdb72"), "Optional archive visit leaves the unfinished robbery yellow after load")

	# Loading an active cabinet conversation should also restore the open drawer.
	await _tap(0) # A / cabinet, while still in interaction range
	if _expect(_demo.get("mode") == "dialogue" and office.get("_drawer_open"), "cabinet conversation can be reopened after load"):
		await _tap(6) # Start -> menu during cabinet dialogue
		await _tap(9) # LB -> Save
		await _tap(0) # Save active dialogue
		await _tap(6) # Close ledger to dialogue
		await _remove_demo()
		await _new_demo(scene)
		player = _demo.get_node("Player") as CharacterBody3D
		journal = _demo.get_node("CanvasLayer/JournalMenu") as Control
		office = _demo.get_node("RecordsOffice") as Node3D
		await _tap(6) # Start
		await _tap(9) # LB -> Save
		await _tap(9) # LB -> Load
		await _tap(0) # Load active dialogue
		_expect(_demo.get("mode") == "menu" and _demo.get("_menu_return_mode") == "dialogue" and office.get("_drawer_open"), "loading an active cabinet dialogue reopens its drawer")
		await create_timer(0.5).timeout
		_expect(absf((office.get("_drawer") as Node3D).position.z - 0.68) < 0.01, "active cabinet Load visibly extends the drawer")
		await _tap(6)
		_expect(_demo.get("mode") == "dialogue" and (_demo.get_node("CanvasLayer/DialoguePanel/Panel/Margin/VBox/Speaker") as Label).text == "Filing Cabinet", "closing the ledger resumes the loaded cabinet line")
		await _tap(1)
		await create_timer(0.5).timeout
		_expect(_demo.get("mode") == "explore" and not office.get("_drawer_open") and absf((office.get("_drawer") as Node3D).position.z) < 0.01, "B exits restored cabinet dialogue and closes the drawer")

	# The return door updates the map's district cue without leaving a travel
	# message pinned over exploration.
	player.global_position = office.call("exit_door_position")
	await process_frame
	await _tap(0)
	var return_status := _demo.get_node("CanvasLayer/Status") as Label
	var return_map := _demo.get_node("CanvasLayer/MapWidget") as Control
	_expect(_demo.call("_area_id") == "quay" and not office.visible and not return_status.visible and return_status.text.is_empty() and str(return_map.get("_location_hint")).contains("CIVIC COURT"), "returning to Civic Court hides the office and uses map location guidance without a persistent status message")

	await _finish()
