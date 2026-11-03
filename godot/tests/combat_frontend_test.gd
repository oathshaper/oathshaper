extends SceneTree
const SAVE := preload("res://scripts/save_store.gd")
const PROFILES := preload("res://scripts/combat_profiles.gd")
const TEST_PATH := "user://combat_frontend_test.save.json"
var failures := 0
var checks := 0
var capture := false
var capture_review := false

func _initialize() -> void:
	call_deferred("_run")

func _expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("Combat front-end test failed: " + message)

func _write(value: Variant) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _frames(count := 3) -> void:
	for frame in range(count):
		await process_frame

func _joy(button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames()

func _trigger(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = value
	Input.parse_input_event(event)
	await _frames()

func _key(code: int, shift := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await _frames(1)

func _shot(name: String, copy_root: Node = null) -> void:
	if not capture and not (capture_review and name in ["picker", "command-menu-overview", "command-menu-equipment", "vanguard-menu-equipment", "confluence-picker"]):
		return
	await _frames(8)
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://../docs/images/combat-" + name + "-1280x800.png")
	_expect(result == OK, "render capture " + name)
	if capture_review and copy_root != null:
		var copy_file := FileAccess.open("res://../docs/ui-copy-review/menu-" + name + ".txt", FileAccess.WRITE)
		copy_file.store_string(_visible_copy(copy_root))
		copy_file.close()

func _visible_copy(node: Node) -> String:
	var copy := ""
	if node is Control and not node.is_visible_in_tree():
		return copy
	if node is Label or node is Button:
		var rect: Rect2 = node.get_global_rect()
		var parent := node.get_parent()
		while parent != null:
			if parent is ScrollContainer:
				rect = rect.intersection(parent.get_global_rect())
			parent = parent.get_parent()
		if rect.has_area() and not node.text.is_empty():
			copy = node.text + "\n\n"
	for child in node.get_children():
		# A 3D combat sample has its own HUD and coordinate system.
		if not child is SubViewport:
			copy += _visible_copy(child)
	return copy

func _bounds(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Button or node is Label):
		var rect: Rect2 = node.get_global_rect()
		var parent: Node = node.get_parent()
		while parent != null:
			if parent is ScrollContainer:
				rect = rect.intersection(parent.get_global_rect())
			parent = parent.get_parent()
		if not rect.has_area():
			return
		_expect(rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= 1281 and rect.end.y <= 801, "visible UI fits 1280x800: " + str(node.get_path()))
	for child in node.get_children():
		_bounds(child)

func _copy(node: Node) -> String:
	var result: String = node.text if node is Label or node is Button else ""
	for child in node.get_children():
		result += "\n" + _copy(child)
	return result

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("capture")
	capture_review = OS.get_cmdline_user_args().has("review_capture")
	root.size = Vector2i(1280, 800)
	create_timer(90).timeout.connect(func() -> void: push_error("Combat test timed out"); quit(1))
	_expect(PROFILES.ids().size() == 9, "nine distinct presentation profiles including three ATB styles")
	_expect(PROFILES.get_profile("oathbound").family == "command" and PROFILES.get_profile("oathbound").party == "You + 3 companions", "Origins-inspired skin shares Command scheduling, four-person party")
	for id in PROFILES.ids():
		var profile := PROFILES.get_profile(id)
		_expect(profile.gear.size() >= 4 and profile.abilities.size() == 4, id + " authored player kit and actions present")
	_expect(SAVE.save("{}", Vector3(2, 1, -4), TEST_PATH, "vanguard") == OK, "schema 2 writes")
	var restored := SAVE.load(TEST_PATH)
	_expect(restored.get("ok", false) and restored.get("data", {}).get("combat_profile") == "vanguard", "schema 2 profile round trip")
	var legacy := {"schema": 1, "narrative": "{}", "player": [0, 1, 0]}
	_write(legacy)
	var migrated := SAVE.load(TEST_PATH)
	_expect(migrated.get("ok", false) and migrated.get("data", {}).get("combat_profile") == "command", "legacy defaults to Command")
	for invalid in ["2", true, 1.5, 3, null]:
		var data := legacy.duplicate(true)
		data.schema = invalid
		_write(data)
		_expect(not SAVE.load(TEST_PATH).ok, "reject malformed schema " + str(invalid))
	for invalid in [null, 5, "unknown", "", {}]:
		var data := legacy.duplicate(true)
		data.schema = 2
		data.combat_profile = invalid
		_write(data)
		_expect(not SAVE.load(TEST_PATH).ok, "reject malformed profile " + str(invalid))
	DirAccess.remove_absolute(TEST_PATH)
	var main := preload("res://scenes/main.tscn").instantiate()
	main.save_path = TEST_PATH
	root.add_child(main)
	await _frames()
	var front: Control = main._frontend
	_expect(front.visible and front._buttons[1].disabled, "title disables missing save")
	_bounds(front)
	await _shot("title")
	await _joy(JOY_BUTTON_A)
	_expect(front._mode == "picker", "controller reaches New Game picker")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(front._selected == "flow", "D-pad selects Flow and retains focus")
	await _shot("picker", front)
	_bounds(front)
	# All nine styles fit at Deck dimensions; no remaining profiles hide below the fold.
	for card in front._cards:
		_expect(front._scroll.get_global_rect().grow(1).encloses(card.get_global_rect()), "all nine style cards visible together")
		for label in card.get_child(0).get_children():
			_expect(card.get_global_rect().grow(1).encloses(label.get_global_rect()), "style card copy stays inside its card")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_expect(front._selected == "momentum", "three-column navigation reaches action ATB")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_expect(front._selected == "orders", "three-column navigation reaches Orders")
	await _joy(JOY_BUTTON_DPAD_RIGHT)
	_expect(front._selected == "oathbound", "controller reaches ninth style")
	for id in PROFILES.ids():
		front._cards[PROFILES.ids().find(id)].grab_focus()
		await _frames()
		_expect(front._inspect.text == "Preview menus   →", "chooser names the full menu preview")
		_expect(front._inspect.get_theme_stylebox("normal").bg_color == front.UI.BRASS, "preview accent stays brass: " + id)
		_expect(front._art_border.get_theme_stylebox("panel").border_color == front.LINE, "illustration border stays neutral: " + id)
		for index in range(front._cards.size()):
			var card: Button = front._cards[index]
			_expect(card.get_child(0).get_child(0).text == "%02d" % (index + 1), "uniform card numbers without category suffixes")
			_expect(card.get_child(0).get_child(0).get_theme_color("font_color") == front.UI.BRASS, "card numerals keep the same color")
			_expect(card.has_node("ComingSoon") == (index >= 3), "only styles 04-09 carry Coming soon pills")
		var picker_copy := _copy(front)
		for removed in ["ATB", "Command family", "Inspect kit", "The same garden", "A different approach", "One party. Your way"]:
			_expect(not picker_copy.contains(removed), "picker excludes removed copy: " + removed)
		var card_rect: Rect2 = front._cards[PROFILES.ids().find(id)].get_global_rect()
		_expect(front._scroll.get_global_rect().grow(1).encloses(card_rect), "focused card fully visible: " + id)
		await _joy(JOY_BUTTON_A)
		_expect(root.gui_get_focus_owner() == front._inspect, "card confirmation focuses full menu preview: " + id)
		await _joy(JOY_BUTTON_A)
		_expect(is_instance_valid(front._inspector) and front._selected == id, "style inspector keeps selected skin: " + id)
		var inspector: Control = front._inspector
		_expect(inspector.PAGES == ["Overview", "Character", "Equipment", "Abilities", "Party", "Inventory", "Map", "Journal", "Saves"], "complete menu preview, not a kit-only sheet")
		_expect(inspector.page_index == 0 and _copy(inspector._content).contains(PROFILES.CATALOG.profile(id).hud), "overview describes each style HUD: " + id)
		if id in ["command", "flow", "vanguard"]:
			var sample: Control = inspector._content.get_node("CombatPreview")
			_expect(inspector._scroll.get_global_rect().grow(1).encloses(sample.get_global_rect()), "entire combat view and HUD fit on initial overview: " + id)
		if id == "command":
			await _shot("command-menu-overview", inspector)
		for page in range(inspector.PAGES.size()):
			_expect(inspector.page_index == page, "bumper reaches preview tab " + str(page))
			_bounds(inspector)
			await _joy(JOY_BUTTON_RIGHT_SHOULDER)
		_expect(inspector.page_index == 0, "tabs wrap to Overview")
		for actor in range(4):
			var build: Dictionary = PROFILES.CATALOG.build(id, PROFILES.CATALOG.actors()[actor].id)
			for page in [2, 3]:
				inspector.select_page(page)
				await _frames()
				_expect(_copy(inspector._content).contains(build.gear[0].name if page == 2 else build.abilities[0].name), "inspector uses actor-specific kit and skills: " + id)
				_bounds(inspector)
				if page == 2 and actor == 1 and id in ["command", "vanguard"]:
					await _shot(id + "-menu-equipment", inspector)
			await _joy(JOY_BUTTON_Y)
			_expect(inspector.actor_index == (actor + 1) % 4 and inspector.page_index == 3, "member switch retains tab")
		_expect(not FileAccess.file_exists(TEST_PATH) and main._demo == null, "preview creates no save or journey")
		if id == "flow":
			for step in range(inspector._focusables.size() + 2):
				await _key(KEY_TAB)
				_expect(root.gui_get_focus_owner() in inspector._focusables and front._selected == id, "Tab cannot leak into picker")
			await _key(KEY_TAB, true)
			_expect(root.gui_get_focus_owner() in inspector._focusables, "Shift-Tab stays in inspector")
			for reverse in [false, true]:
				var boundary: Button = inspector._focusables[0 if reverse else -1]
				boundary.grab_focus()
				var repeated := InputEventKey.new()
				repeated.keycode = KEY_TAB
				repeated.physical_keycode = KEY_TAB
				repeated.shift_pressed = reverse
				repeated.pressed = true
				repeated.echo = true
				Input.parse_input_event(repeated)
				await _frames()
				_expect(root.gui_get_focus_owner() == boundary and front._selected == id, "held Tab cannot escape modal or change underlying style")
			await _key(KEY_E)
			_expect(inspector.page_index == 4, "keyboard changes preview tabs")
			await _key(KEY_Q)
			_expect(inspector.page_index == 3, "keyboard returns to abilities")
			var motion := InputEventJoypadMotion.new()
			motion.axis = JOY_AXIS_RIGHT_Y
			motion.axis_value = 1.0
			Input.parse_input_event(motion)
			await _frames(8)
			_expect(inspector._scroll.scroll_vertical > 0, "right stick reveals remaining abilities")
			motion = InputEventJoypadMotion.new()
			motion.axis = JOY_AXIS_RIGHT_Y
			Input.parse_input_event(motion)
			await _frames()
			_expect(inspector._scroll_speed == 0, "right-stick release stops scrolling")
		_bounds(front)
		if id == "confluence":
			await _shot("confluence-kit")
		await _joy(JOY_BUTTON_B)
		_expect(not is_instance_valid(front._inspector) and front._mode == "picker" and root.gui_get_focus_owner() == front._inspect, "B closes inspector and restores picker focus")
		if id in ["momentum", "confluence", "cadence"]:
			await _shot(id + "-picker", front)
	front._cards[1].grab_focus()
	await _frames()
	await _joy(JOY_BUTTON_A)
	_expect(root.gui_get_focus_owner() == front._inspect, "confirm focuses Preview menus")
	await _joy(JOY_BUTTON_A)
	front._inspector._focusables[-1].grab_focus()
	await _joy(JOY_BUTTON_A)
	var demo: Node3D = main._demo
	_expect(demo != null and not front.visible, "controller starts journey")
	if demo == null:
		quit(1)
		return
	_expect(demo.combat_profile() == "flow", "chosen style applied")
	_expect(demo.mode == "opening" and not demo.player.enabled, "New journey introduces the robbery before movement")
	var before_opening: String = demo.bridge.state_json()
	await _joy(JOY_BUTTON_B)
	_expect(demo.mode == "explore" and demo.player.enabled, "B skips opening and restores movement")
	_expect(demo.bridge.state_json() == before_opening, "Skipping cannot alter story choices")
	var before: String = demo.bridge.state_json()
	demo.player.global_position = Vector3(0, 1.05, 1.5)
	await _joy(JOY_BUTTON_START)
	_expect(demo.mode == "menu" and demo.journal.visible, "Menu opens Ledger")
	await _shot("party")
	for id in PROFILES.ids():
		main._choose_style()
		await _frames()
		front._buttons[PROFILES.ids().find(id)].grab_focus()
		await _joy(JOY_BUTTON_A)
		await _joy(JOY_BUTTON_DPAD_LEFT)
		await _joy(JOY_BUTTON_A)
		_expect(demo.combat_profile() == id and not front.visible and demo.journal.visible, "style applies and returns to Ledger: " + id)
		_expect(demo.bridge.state_json() == before, "style preserves narrative: " + id)
		# Regression: actor selection must change the rendered build, not only its portrait.
		var roles: Array[String] = []
		for actor_index in range(4):
			demo.journal._select_actor(actor_index)
			demo.journal._select_tab(0)
			await _frames()
			var build: Dictionary = demo.journal._build()
			_expect(not roles.has(build.role), id + " has distinct actor roles")
			roles.append(build.role)
			_expect(_copy(demo.journal._content).contains(build.role) and _copy(demo.journal._content).contains(build.weakness), id + " actor sheet has role and tradeoff")
			_bounds(demo.journal)
			if id == "vanguard" and actor_index == 1:
				await _shot("vanguard-mara-character")
			for page in [1, 2]:
				demo.journal._select_tab(page)
				await _frames()
				var expected: String = build.gear[0].name if page == 1 else build.abilities[0].name
				_expect(_copy(demo.journal._content).contains(expected), id + " renders selected actor's kit/actions")
				_bounds(demo.journal)
			if id == "flow" and actor_index == 2:
				await _shot("flow-ivo-abilities")
				demo.journal._scroll.scroll_vertical = 0
				var scroll_event := InputEventJoypadMotion.new()
				scroll_event.axis = JOY_AXIS_RIGHT_Y
				scroll_event.axis_value = 1.0
				Input.parse_input_event(scroll_event)
				await _frames(8)
				_expect(demo.journal._scroll.scroll_vertical > 0, "right stick exposes long style and common-action lists")
				scroll_event = InputEventJoypadMotion.new()
				scroll_event.axis = JOY_AXIS_RIGHT_Y
				Input.parse_input_event(scroll_event)
				await _frames()
				_expect(demo.journal._scroll_velocity == 0, "releasing right stick stops scrolling")
			if id == "cadence" and actor_index == 3:
				await _shot("cadence-clerk-abilities")
			await _joy(JOY_BUTTON_Y)
			_expect(demo.journal._actor_index == (actor_index + 1) % 4 and demo.journal._current_tab == 2, "controller cycles actor and keeps selected page")
		_expect(demo.bridge.state_json() == before, "build inspection never changes campaign: " + id)
		demo.journal._select_actor(0)
		demo.journal._select_tab(1)
		await _frames()
		_bounds(demo.journal)
		demo.journal._select_tab(2)
		await _frames()
		_bounds(demo.journal)
		if id == "oathbound":
			await _shot("oathbound-talents")
	demo.set_combat_profile("vanguard")
	demo.journal._select_tab(1)
	await _shot("equipment")
	demo.journal._select_tab(2)
	await _shot("powers")
	# New journey is reachable with controller and requires explicit discard.
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_A)
	_expect(front.visible and front._purpose == "new", "controller reaches New Journey")
	await _joy(JOY_BUTTON_A)
	await _joy(JOY_BUTTON_DPAD_LEFT)
	await _joy(JOY_BUTTON_A)
	_expect(front._mode == "confirm", "new journey asks before discarding")
	await _joy(JOY_BUTTON_B)
	await _joy(JOY_BUTTON_B)
	_expect(main._demo == demo and demo.journal.visible, "cancel preserves live journey")
	await _joy(JOY_BUTTON_B)
	_expect(demo.mode == "explore" and not demo.journal.visible, "B returns to exploration")
	var pose: Node = demo._weapon.pose
	await _trigger(.8)
	_expect(demo._weapon_ready and pose.strike_count == 1, "RT draws and fires once")
	await create_timer(.75).timeout
	await _trigger(.9)
	_expect(pose.strike_count == 1, "held analog trigger never repeats")
	await _trigger(0)
	await _joy(JOY_BUTTON_B)
	_expect(not demo._weapon_ready, "B sheathes")
	await _joy(JOY_BUTTON_X)
	_expect(demo._weapon_ready and pose.strike_count == 1, "X draws without firing")
	await _shot("weapon-ready")
	await _joy(JOY_BUTTON_BACK)
	await _trigger(.8)
	_expect(pose.strike_count == 1, "expanded map blocks attacks")
	await _joy(JOY_BUTTON_B)
	await _trigger(.9)
	_expect(pose.strike_count == 1, "closing map while trigger held cannot fire")
	await _trigger(0)
	demo._begin_dialogue("mara_greeting")
	await _trigger(.8)
	_expect(not demo._weapon_ready and pose.strike_count == 1, "dialogue sheathes and blocks attacks")
	demo._end_dialogue()
	await _trigger(0)
	demo.set_combat_profile("command")
	await _trigger(.8)
	_expect(pose.strike_count == 2, "fresh trigger starts sabre strike")
	await _shot("strike")
	await _trigger(0)
	await create_timer(.75).timeout
	_expect(pose.strike_time < 0 and demo._weapon_ready, "strike recovers but remains readied")
	_expect(demo._weapon.grip.bone_name == "RHand", "weapon follows real hand bone")
	# Invalid save load is transactional, including profile and position.
	demo._save()
	var good_save := FileAccess.get_file_as_string(TEST_PATH)
	var saved_position: Vector3 = demo.player.global_position
	before = demo.bridge.state_json()
	_write({"schema": 2, "combat_profile": "unknown", "player": [0, 1, 0], "narrative": "{}"})
	_expect(not demo.load_journey() and demo.bridge.state_json() == before and demo.player.global_position == saved_position and demo.combat_profile() == "command", "invalid profile load mutates nothing")
	main._choose_new_journey()
	main._start_load("flow")
	_expect(main._demo == demo and front.visible, "failed title load retains active journey")
	_write(JSON.parse_string(good_save))
	main._start_load("flow")
	await _frames()
	_expect(main._demo != demo and main._demo.combat_profile() == "flow", "load picker override applied after saved profile")
	_expect(main._demo.bridge.state_json() == before, "load restores exact narrative")
	demo = main._demo
	demo._save()
	_expect(SAVE.load(TEST_PATH).data.combat_profile == "flow", "loaded style persists on next save")
	root.remove_child(main)
	main.queue_free()
	await _frames()
	DirAccess.remove_absolute(TEST_PATH)
	if failures == 0:
		print("COMBAT_FRONTEND_OK: %d checks" % checks)
	else:
		push_error("COMBAT_FRONTEND_FAILED: %d / %d checks" % [failures, checks])
	quit(0 if failures == 0 else 1)
