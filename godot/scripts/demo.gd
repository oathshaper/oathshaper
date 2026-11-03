extends Node3D

signal combat_style_requested
signal new_game_requested
signal chapter_requested(profile_id: String)

const VOICES := preload("res://scripts/voice_library.gd")
const SAVE := preload("res://scripts/save_store.gd")
const TALK_RANGE := 3.0
const DOOR_RANGE := 2.7
const CABINET_RANGE := 2.9
const EXIT_RANGE := 2.2
const PROFILES := preload("res://scripts/combat_profiles.gd")
# A few steps beyond the arch leave room for the close camera on arrival.
const PAY_CHEST := preload("res://scripts/pay_chest.gd")
const GARDEN_ENTRY := Vector3(31.0, 1.05, -2.0)
const QUAY_RETURN := Vector3(-5.5, 1.05, -26.0)
@export var save_path := SAVE.HUB_PATH

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var hub: Node3D = $HubEnvironment
@onready var records_office: Node3D = $RecordsOffice
@onready var panel: Control = $CanvasLayer/DialoguePanel
@onready var map_widget: Control = $CanvasLayer/MapWidget
@onready var objective_tracker: Control = $CanvasLayer/ObjectiveTracker
@onready var journal: Control = $CanvasLayer/JournalMenu
@onready var prompt: Label = $CanvasLayer/Prompt
@onready var controls_hint: Label = $CanvasLayer/ControlsHint
@onready var status: Label = $CanvasLayer/Status
@onready var location: Label = $CanvasLayer/Location
@onready var lamp: OmniLight3D = $Mara/Lamp
@onready var npcs: Array[Dictionary] = [
	{"node": $Mara, "name": "Mara", "entry": "mara_greeting"},
	{"node": $Ivo, "name": "Ivo", "entry": "ivo_gate"},
	{"node": $CivicClerk, "name": "Civic Clerk", "entry": "clerk_greeting"},
	{"node": $Vendor, "name": "Vendor", "entry": "vendor_greeting"},
]

var bridge: Object
var mode := "explore"
var _talking_actor: Node3D
var _using_controller := false
var _map_expanded := false
var _objective_dismissed := false
var _last_objective_stage := ""
var _status_until_ms := 0
var _menu_return_mode := "explore"
var _story_state: Dictionary = {}
var _chapters: Dictionary = {}
var combat_profile_id := PROFILES.DEFAULT_ID
var _weapon_ready := false
var _weapon: Node3D
var _trigger_held := false
var _attack_edge := false
var _garden_watch: Node3D
var _pay_chest: Node3D
var _pay_loot: Node3D
var _ending_pending := false
var _mara_office := false
var _garden_threshold_armed := true
var _rendezvous := preload("res://scripts/companion_rendezvous.gd").new()

func _ready() -> void:
	$CivicClerk.position = $RecordsOffice.position + Vector3(2.1, 1.0, -1.1)
	$CivicClerk.rotation.y = PI
	_rendezvous.bind(self)
	_build_garden_watch()
	_build_pay_chest()
	_build_weapon_visual()
	_refresh_area_visibility()
	panel.selected.connect(_choose)
	panel.cancelled.connect(_end_dialogue)
	panel.response_finished.connect(_return_to_questions)
	panel.speaking_changed.connect(_set_speaking)
	panel.input_observed.connect(_observe_input_event)
	journal.input_observed.connect(_observe_input_event)
	journal.closed.connect(_close_menu)
	journal.save_requested.connect(_save_from_menu)
	journal.load_requested.connect(_load_from_menu)
	journal.combat_style_requested.connect(func() -> void: combat_style_requested.emit())
	journal.new_game_requested.connect(func() -> void: new_game_requested.emit())
	objective_tracker.connect("dismissed", _dismiss_objective)
	map_widget.connect("quest_selected", _show_objective_from_map)
	panel.hide_panel()
	_render_input_hints()
	var focus := preload("res://scripts/interaction_focus.gd").new()
	focus.demo = self
	$CanvasLayer.add_child(focus)
	_set_map_expanded(false)
	var mara_imported: bool = $Mara/ModelSlot.has_node("ImportedModel")
	if mara_imported:
		# Hide the primitive globe over the imported buckle. The tower now
		# supplies the exterior light; the legacy personal light stays off.
		lamp.position = Vector3(0.0, 0.4, 0.16)
		$Mara/LampShade.hide()
	if not ClassDB.class_exists("NarrativeBridge"):
		_show_status("Narrative extension is unavailable.", 0.0)
		return
	bridge = ClassDB.instantiate("NarrativeBridge") as Object
	var source: String = FileAccess.get_file_as_string("res://content/lantern_quay.json")
	var result: Dictionary = _call_bridge("load_story", [source])
	if not result.get("ok", false):
		_show_status("Story error: %s" % str(result.get("error", "unknown")), 0.0)
		bridge = null
		return
	var authored: Dictionary = JSON.parse_string(source)
	journal.set_moral_definition(authored.moral)
	_refresh_world()

func set_combat_profile(profile_id: String) -> void:
	combat_profile_id = profile_id if PROFILES.is_valid(profile_id) else PROFILES.DEFAULT_ID
	_weapon_ready = false
	if _weapon != null:
		_configure_weapon()
	if journal != null:
		journal.call("set_combat_profile", combat_profile_id)
	_render_input_hints()

func combat_profile() -> String:
	return combat_profile_id

func sync_combat_input() -> void:
	# Do not turn a trigger already held in a modal into a fresh attack.
	_trigger_held = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.25
	for device in Input.get_connected_joypads():
		_trigger_held = _trigger_held or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > 0.25
	_attack_edge = false

func _build_weapon_visual() -> void:
	_weapon = preload("res://scripts/weapon_presentation.gd").new()
	_weapon.name = "PracticeWeapon"
	player.add_child(_weapon)
	_configure_weapon()

func _configure_weapon() -> void:
	if _weapon == null:
		return
	var profile := PROFILES.get_profile(combat_profile_id)
	_weapon.configure(str(profile.weapon))

func _process(delta: float) -> void:
	preload("res://scripts/game_audio.gd").ensure(self).context = "office" if _area_id() == "records_office" else "quay"
	if _using_controller and Input.get_connected_joypads().is_empty(): _set_input_mode(false)
	if mode in ["explore", "dialogue"]:
		_rendezvous.advance(delta, _talking_actor, player)
	if is_instance_valid(_garden_watch) and _garden_watch.visible:
		for actor in _garden_watch.get_children():
			actor.get_node("Art").set_motion(Vector3.ZERO, Time.get_ticks_msec() / 100, false)
	_refresh_area_visibility()
	_refresh_location_label()
	_refresh_navigation()
	if mode == "explore":
		_check_garden_threshold()
		_refresh_exploration_prompt()
	prompt.visible = bridge != null and mode == "explore" and not prompt.text.is_empty()
	controls_hint.visible = mode == "explore"
	status.visible = mode == "explore" and not status.text.is_empty() and (_status_until_ms < 0 or Time.get_ticks_msec() < _status_until_ms)
	location.visible = false
	map_widget.visible = mode == "explore"
	objective_tracker.visible = mode == "explore" and not _map_expanded and not _objective_dismissed

func _input(event: InputEvent) -> void:
	if mode == "opening": return
	_observe_input_event(event)
	_attack_edge = false
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_RIGHT:
		_attack_edge = event.axis_value > 0.55 and not _trigger_held
		if event.axis_value < 0.25:
			_trigger_held = false
		elif event.axis_value > 0.55:
			_trigger_held = true
	if bridge == null or event.is_echo():
		return
	if mode != "menu" and event.is_action_pressed("menu_toggle"):
		get_viewport().set_input_as_handled()
		call_deferred("_open_menu")
	elif mode == "explore" and event.is_action_pressed("map_toggle"):
		get_viewport().set_input_as_handled()
		_set_map_expanded(not _map_expanded)
	elif mode == "explore" and event.is_action_pressed("objective_toggle"):
		get_viewport().set_input_as_handled()
		_objective_dismissed = not _objective_dismissed
		if not _objective_dismissed:
			objective_tracker.call("set_collapsed", false)
		objective_tracker.visible = not _objective_dismissed and not _map_expanded
	elif mode == "explore" and _map_expanded and event.is_action_pressed("dialogue_back"):
		get_viewport().set_input_as_handled()
		_set_map_expanded(false)

func _observe_input_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if event.pressed:
			_set_input_mode(true)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.35:
			_set_input_mode(true)
	elif event is InputEventKey:
		if event.pressed and not event.is_echo():
			_set_input_mode(false)
	elif event is InputEventMouseButton:
		if event.pressed:
			_set_input_mode(false)
	elif event is InputEventMouseMotion:
		if event.relative.length_squared() >= 64.0:
			_set_input_mode(false)

func _set_input_mode(controller: bool) -> void:
	controller = controller and not Input.get_connected_joypads().is_empty()
	if _using_controller == controller:
		return
	_using_controller = controller
	_render_input_hints()

func _render_input_hints() -> void:
	var weapon_hint := "RT Strike · Ⓧ Draw · Ⓑ Sheathe" if _using_controller else "LMB Strike · Q Draw · Esc Sheathe"
	controls_hint.text = ("Menu Ledger · View Map · Ⓨ Quest\n" + weapon_hint) if _using_controller else ("Tab Ledger · M Map · J Quest · F5 Save · F9 Load\n" + weapon_hint)
	panel.set_input_mode(_using_controller)
	journal.set_input_mode(_using_controller)
	_refresh_exploration_prompt()

func _refresh_exploration_prompt() -> void:
	var nearby: Dictionary = _nearest_interactable()
	if nearby.is_empty():
		prompt.text = ""
	else:
		var verb := ""
		match str(nearby["kind"]):
			"npc": verb = "Speak with"
			"cabinet": verb = "Open"
			"door": verb = "Enter"
			"pay_loot": verb = "Search"
			"office_chest": verb = "Examine"
			"exit": verb = "Return to"
			"garden": verb = "Enter"
		prompt.text = "Ⓐ %s %s" % [verb, nearby["name"]] if _using_controller else "E: %s %s" % [verb, nearby["name"]]

func _nearest_interactable() -> Dictionary:
	if _area_id() == "records_office":
		var options: Array[Dictionary] = [
			{"kind": "office_chest", "name": "ransacked payroll chest", "at": _pay_chest.global_position, "range": 2.0},
			{"kind": "cabinet", "name": "filing cabinet", "at": records_office.cabinet_position(), "range": CABINET_RANGE},
			{"kind": "exit", "name": "Civic Court", "at": records_office.exit_door_position(), "range": EXIT_RANGE},
		]
		for npc in npcs:
			if not _npc_can_focus(npc.node): continue
			var entry := npc.duplicate()
			entry.merge({"kind": "npc", "at": npc.node.global_position, "range": TALK_RANGE})
			options.append(entry)
		var nearest: Dictionary = {}
		var distance := INF
		for option in options:
			var metres := player.global_position.distance_to(option.at)
			if metres < float(option.range) and metres < distance:
				distance = metres
				nearest = option
		return nearest
	if player.global_position.distance_to(hub.get_node("RecordsDoor").global_position) < DOOR_RANGE:
		return {"kind": "door", "name": "clerk’s office"}
	if bool(_story_state.get("flags", {}).get("gate_open", false)) and not bool(_chapters.get("dockside_robbery", false)) and player.global_position.distance_to(GARDEN_ENTRY) < 3.0:
		return {"kind": "garden", "name": "Lantern Garden"}
	if bool(_chapters.get("dockside_robbery", false)) and _pay_loot.visible and player.global_position.distance_to(_pay_loot.global_position) < 2.5:
		return {"kind": "pay_loot", "name": "Crimson Raider"}
	var npc := _nearest_npc()
	if not npc.is_empty():
		var entry := npc.duplicate()
		entry["kind"] = "npc"
		return entry
	return {}

func _nearest_npc() -> Dictionary:
	var nearest: Dictionary = {}
	var distance := TALK_RANGE
	for npc in npcs:
		var subject: Node3D = npc["node"]
		if not _npc_can_focus(subject): continue
		var candidate: float = player.global_position.distance_to(subject.global_position)
		if candidate < distance:
			distance = candidate
			nearest = npc
	return nearest

func _npc_can_focus(subject: Node3D) -> bool:
	if not subject.visible: return false
	if not _rendezvous.is_travelling_companion(subject): return true
	# Following is not an invitation to talk. Stop and look at a companion to
	# select them; the prompt, reticle and interaction key all use this decision.
	if Vector2(player.velocity.x, player.velocity.z).length() > .15: return false
	var toward := subject.global_position - player.global_position
	toward.y = 0
	var forward: Vector3 = -camera_rig.camera.global_basis.z
	forward.y = 0
	return toward.normalized().dot(forward.normalized()) >= .75

func _refresh_location_label() -> void:
	var at: Vector3 = player.global_position
	if _area_id() == "records_office":
		location.text = "CIVIC RECORDS OFFICE\nHarbor history collected · exit south" if bool(_story_state.get("flags", {}).get("records_collected", false)) else "CIVIC RECORDS OFFICE\nCabinet northwest · exit south"
	elif at.x > 33.0:
		location.text = "LANTERN GARDEN\nTower west · quay gate behind"
	elif at.x > 12.0:
		location.text = "EAST BLUFF\nIvo east · tower northwest"
	elif at.x < -12.0:
		location.text = "WEST MARKET\nQuay east · old way north"
	elif at.z < -12.0:
		location.text = "CIVIC COURT\nTower ahead · quay south"
	else:
		location.text = "CENTRAL QUAY\nTower north · market west · gate east"

func _unhandled_input(event: InputEvent) -> void:
	if bridge == null or event.is_echo():
		return
	if mode == "menu" or _map_expanded:
		return
	if event.is_action_pressed("quick_save"):
		_save()
	elif event.is_action_pressed("quick_load"):
		_load()
	elif mode == "explore" and event.is_action_pressed("interact"):
		var nearby: Dictionary = _nearest_interactable()
		if nearby.is_empty():
			return
		match str(nearby["kind"]):
			"npc": _begin_dialogue(str(nearby["entry"]))
			"door": _enter_records_office()
			"cabinet":
				records_office.call("open_cabinet")
				_begin_dialogue("cabinet_greeting")
			"exit": _leave_records_office()
			"pay_loot": _begin_dialogue("pay_loot")
			"office_chest": _begin_dialogue("office_chest")
			"garden":
				if _rendezvous.assembled():
					chapter_requested.emit(combat_profile_id)
				else:
					_show_status("Mara is on her way. Wait here with Ivo.", 4.0)
	elif mode == "explore" and event.is_action_pressed("combat_draw"):
		_toggle_weapon()
	elif mode == "explore" and event.is_action_pressed("combat_attack"):
		if event is InputEventJoypadMotion and not _attack_edge:
			return
		_strike()
	elif mode == "explore" and event.is_action_pressed("dialogue_back") and _weapon_ready:
		_sheathe_weapon()
	else:
		return
	get_viewport().set_input_as_handled()

func _toggle_weapon() -> void:
	if _weapon_ready:
		_sheathe_weapon()
		return
	_weapon_ready = true
	_weapon.set_readied(true)
	preload("res://scripts/game_audio.gd").ensure(self).cue("draw")
	_show_status("%s ready." % str(PROFILES.get_profile(combat_profile_id).get("name", "Command")))

func _sheathe_weapon() -> void:
	_weapon_ready = false
	_weapon.set_readied(false)
	_show_status("Weapon sheathed.")

func _strike() -> void:
	if not _weapon.strike():
		return
	_weapon_ready = true
	var ranged := str(PROFILES.get_profile(combat_profile_id).get("weapon", "sabre")) == "carbine"
	preload("res://scripts/game_audio.gd").ensure(self).cue("shot" if ranged else "miss")

func _set_map_expanded(expanded: bool) -> void:
	_map_expanded = expanded
	map_widget.call("set_expanded", expanded)
	var map_size: Vector2 = map_widget.call("desired_size")
	map_widget.offset_left = -32.0 - map_size.x
	map_widget.offset_right = -32.0
	map_widget.offset_top = 32.0
	map_widget.offset_bottom = 32.0 + map_size.y
	var tracker_top := 32.0 + float(map_widget.call("desired_size").y) + 16.0
	objective_tracker.offset_left = map_widget.offset_left
	objective_tracker.offset_right = map_widget.offset_right
	objective_tracker.offset_top = tracker_top
	objective_tracker.offset_bottom = tracker_top + float(objective_tracker.call("desired_height"))
	objective_tracker.visible = mode == "explore" and not expanded and not _objective_dismissed

func _show_objective_from_map() -> void:
	if mode != "explore":
		return
	_objective_dismissed = false
	objective_tracker.call("set_collapsed", false)
	_set_map_expanded(false)
	objective_tracker.visible = true

func _dismiss_objective() -> void:
	_objective_dismissed = true
	objective_tracker.visible = false

func _show_status(message: String, seconds := 3.5) -> void:
	status.text = message
	_status_until_ms = -1 if seconds <= 0.0 else Time.get_ticks_msec() + roundi(seconds * 1000.0)

func _clear_status() -> void:
	status.text = ""
	_status_until_ms = 0

func _enter_records_office() -> void:
	preload("res://scripts/game_audio.gd").ensure(self).cue("door_open")
	_rendezvous.transfer_through_door(hub.get_node("RecordsDoor").global_position + Vector3(.8, 0, 0), records_office.entry_position() + Vector3(0, 0, 1.0))
	player.global_position = records_office.call("entry_position")
	player.velocity = Vector3.ZERO
	_refresh_area_visibility()
	player.rotation.y = 0.0
	camera_rig.call("focus_after_teleport", 0.0, true)
	_clear_status()
	_refresh_location_label()
	_refresh_navigation()

func _leave_records_office() -> void:
	preload("res://scripts/game_audio.gd").ensure(self).cue("door_close")
	_rendezvous.transfer_through_door(records_office.exit_door_position(), QUAY_RETURN + Vector3(-1.0, 0, 0))
	player.global_position = QUAY_RETURN
	player.velocity = Vector3.ZERO
	_refresh_area_visibility()
	# The archive opens east into the court; world north is parallel to its
	# facade. Derive arrival heading from the actual door-to-landing direction.
	var outward := QUAY_RETURN - (hub.get_node("RecordsDoor") as Node3D).global_position
	outward.y = 0.0
	player.rotation.y = atan2(-outward.x, -outward.z)
	camera_rig.call("focus_after_teleport", rad_to_deg(player.rotation.y), false)
	_clear_status()
	_refresh_location_label()
	_refresh_navigation()

func _open_menu() -> void:
	_menu_return_mode = mode
	mode = "menu"
	player.enabled = false
	panel.set_process_input(false)
	journal.call("set_combat_profile", combat_profile_id)
	journal.open_menu(_story_state, player.global_position, _area_id(), _objective_id())
	panel.set_presentation_paused(true)
	journal.set_input_mode(_using_controller)

func _close_menu() -> void:
	journal.hide()
	mode = _menu_return_mode
	player.enabled = mode == "explore"
	panel.set_process_input(true)
	panel.set_presentation_paused(false)
	if mode == "dialogue" and panel.selected_index >= 0:
		panel.buttons[panel.selected_index].grab_focus()

func _save_from_menu() -> void:
	_save()
	journal.set_feedback(status.text)

func _load_from_menu() -> void:
	if _load():
		_menu_return_mode = mode
		mode = "menu"
		player.enabled = false
		panel.set_process_input(false)
		panel.set_presentation_paused(true)
		journal.update_state(_story_state, player.global_position, _area_id(), _objective_id())
	journal.set_feedback(status.text)

func _area_id() -> String:
	return "records_office" if player.global_position.x > 120.0 else "quay"

func _objective_id() -> String:
	var flags: Dictionary = _story_state.get("flags", {})
	if bool(flags.get("pay_returned", false)):
		return "robbery_done"
	if bool(flags.get("pay_recovered", false)):
		return "return_pay"
	if bool(_chapters.get("dockside_robbery", false)):
		return "pay_loot"
	if bool(flags.get("gate_open", false)):
		return "garden"
	if bool(flags.get("mara_recruited", false)): return "garden_gate"
	if bool(flags.get("robbery_known", false)): return "mara"
	return "clerk"

func _refresh_navigation() -> void:
	if bridge == null:
		return
	var stage := _objective_id()
	if not _last_objective_stage.is_empty() and stage != _last_objective_stage:
		_objective_dismissed = false
	_last_objective_stage = stage
	var target := Vector3.ZERO
	match stage:
		"mara": target = $Mara.global_position
		"pay_loot": target = _pay_loot.global_position
		"clerk", "return_pay": target = $CivicClerk.global_position if _area_id() == "records_office" else hub.get_node("RecordsDoor").global_position
		"garden_gate": target = $Ivo.global_position
		"garden": target = GARDEN_ENTRY
		"records_door": target = hub.get_node("RecordsDoor").global_position
		"cabinet": target = records_office.call("cabinet_position")
	var metres := INF if stage in ["done", "robbery_done"] else Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target.x, target.z))
	objective_tracker.call("set_objective", stage, metres)
	map_widget.call("set_map_state", player.global_position, _area_id(), stage, _story_state.get("flags", {}), location.text)

func _begin_dialogue(entry_id: String) -> void:
	var result: Dictionary = _call_bridge("begin_at", [entry_id])
	if result.get("ok", false):
		_weapon_ready = false
		_weapon.set_readied(false)
		mode = "dialogue"
		player.enabled = false
		if entry_id.begins_with("cabinet_"):
			records_office.call("open_cabinet")
		_set_talking_for_entry(entry_id)
		_apply(result)
	else:
		_show_status(str(result.get("error", "Dialogue failed.")))

func _choose(id: String) -> void:
	var was_paid := bool(_story_state.get("flags", {}).get("pay_returned", false))
	var had_records: bool = _story_state.get("flags", {}).get("records_collected", false)
	var previous: Dictionary = _call_bridge("view").get("data", {})
	var player_line: Dictionary = {}
	for choice in previous.get("choices", []):
		if choice.id == id:
			player_line = VOICES.entry("Tessa Ward", choice.text)
	var result: Dictionary = _call_bridge("choose", [id])
	if result.get("ok", false) and not player_line.is_empty():
		var audio := VOICES.clip("Tessa Ward", player_line.lookup_text)
		if audio != null:
			_set_speaking(false)
			var completed: bool = await panel.play_player_reply(player_line.spoken_text, audio)
			player.get_node("ModelSlot").call("set_talking", false)
			if not completed:
				return
	if result.get("ok", false):
		if not bool(result.get("data", {}).get("in_dialogue", true)):
			_refresh_world()
			_end_dialogue()
			return
		if id == "leave_records" or id == "close":
			records_office.call("close_cabinet")
		elif id == "look_again":
			records_office.call("open_cabinet")
	_apply(result)
	_refresh_world()
	if not was_paid and bool(_story_state.get("flags", {}).get("pay_returned", false)):
		_ending_pending = true
	if not had_records and bool(_story_state.get("flags", {}).get("records_collected", false)):
		_show_status("Harbor history added to Inventory.")

func _return_to_questions() -> void:
	if mode == "dialogue":
		if _ending_pending:
			_end_dialogue()
		else:
			_apply(_call_bridge("finish_response"), false)

func _set_speaking(active: bool) -> void:
	if panel._player_reply:
		player.get_node("ModelSlot").call("set_talking", active)
		return
	if _talking_actor != null:
		var slot := _talking_actor.get_node_or_null("ModelSlot")
		if slot != null:
			slot.call("set_talking", active)

func _apply(result: Dictionary, speak_line := true) -> void:
	if not result.get("ok", false):
		_show_status(str(result.get("error", "Dialogue failed.")))
		return
	var view: Dictionary = result.get("data", {})
	panel.show_view(view, speak_line)

func _end_dialogue() -> void:
	if bridge != null:
		_call_bridge("end_dialogue")
	if _talking_actor == $RecordsOffice/CabinetFocus:
		records_office.call("close_cabinet")
	_set_talking_actor(null)
	mode = "explore"
	player.enabled = true
	panel.hide_panel()
	if _ending_pending:
		_ending_pending = false
		call_deferred("_play_ending")

func _save() -> bool:
	var result: Dictionary = _call_bridge("save_json")
	if not result.get("ok", false):
		_show_status(str(result.get("error", "Save failed.")))
		return false
	var data: Dictionary = result.get("data", {})
	var write_error: Error = SAVE.save(str(data.get("save", "")), player.global_position, save_path, combat_profile_id, _chapters, _rendezvous.snapshot())
	_show_status("Saved in %s." % ("Civic Records Office" if _area_id() == "records_office" else "Lantern Quay") if write_error == OK else "Could not write save: %s" % error_string(write_error))
	return write_error == OK

func _load() -> bool:
	var read_result: Dictionary = SAVE.load(save_path)
	if not read_result.get("ok", false):
		_show_status(str(read_result.get("error", "Load failed.")))
		return false
	var data: Dictionary = read_result.get("data", {})
	var restored_profile := str(data.get("combat_profile", PROFILES.DEFAULT_ID))
	if not PROFILES.is_valid(restored_profile):
		_show_status("Combat profile is invalid.")
		return false
	var coordinates: Array = data.get("player", [])
	var restored_position := Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
	if not is_finite(restored_position.x) or not is_finite(restored_position.y) or not is_finite(restored_position.z) or restored_position.length() > 1000.0:
		_show_status("Saved position is invalid.")
		return false
	# Revision-7 saves predate the encounter fact. The chapter result remains
	# authoritative, including victory before the player picks up the payroll.
	var restored_narrative = JSON.parse_string(str(data.get("narrative", "")))
	if restored_narrative is Dictionary and restored_narrative.get("story_id") == "lantern_quay" and restored_narrative.get("revision") == 7:
		var restored_state = restored_narrative.get("state")
		if restored_state is Dictionary:
			var restored_flags = restored_state.get("flags")
			if restored_flags is Dictionary:
				restored_flags["raiders_defeated"] = bool(data.chapters.get("dockside_robbery", false))
	var result: Dictionary = _call_bridge("load_save", [JSON.stringify(restored_narrative)])
	if not result.get("ok", false):
		_show_status(str(result.get("error", "Load failed.")))
		return false
	_chapters = data.chapters.duplicate(true)
	set_combat_profile(restored_profile)
	player.global_position = restored_position
	_refresh_area_visibility()
	camera_rig.call("focus_after_teleport", 0.0 if _area_id() == "records_office" else rad_to_deg(player.rotation.y), _area_id() == "records_office")
	var saved_narrative: Variant = JSON.parse_string(str(data.get("narrative", "")))
	var saved_state: Dictionary = saved_narrative.get("state", {})
	if saved_state.get("in_dialogue", false):
		mode = "dialogue"
		player.enabled = false
		var current_view := _call_bridge("view")
		var entry_id := str(current_view.get("data", {}).get("node_id", ""))
		if entry_id == "cabinet_greeting" or entry_id == "cabinet_taken":
			records_office.call("open_cabinet")
		elif entry_id == "cabinet_left":
			records_office.call("close_cabinet")
		_set_talking_for_entry(entry_id)
		_apply(current_view)
	else:
		_set_talking_actor(null)
		records_office.call("close_cabinet")
		mode = "explore"
		player.enabled = true
		panel.hide_panel()
	_refresh_world()
	_rendezvous.restore(data.get("companions", {}), _story_state.flags, player)
	_refresh_area_visibility()
	_show_status("Loaded %s." % ("Civic Records Office" if _area_id() == "records_office" else "Lantern Quay"))
	return true

func load_journey() -> bool:
	return _load()


func _refresh_area_visibility() -> void:
	# The office cutaway lives offstage at x=160 for its interior route. Hide
	# its renderers from the open harbor so it cannot float on the sea horizon;
	# visibility does not disable the office's physics or interactions.
	var inside := _area_id() == "records_office"
	records_office.visible = inside
	$CivicClerk.visible = inside
	_mara_office = $Mara.position.x > 120
	$Mara.visible = inside == _mara_office


func _set_talking_for_entry(entry_id: String) -> void:
	if entry_id.begins_with("cabinet_"):
		_set_talking_actor($RecordsOffice/CabinetFocus)
		return
	for npc in npcs:
		var prefix := str(npc["entry"]).get_slice("_", 0) + "_"
		if entry_id.begins_with(prefix):
			_set_talking_actor(npc["node"] as Node3D)
			return
	_set_talking_actor(null)


func _set_talking_actor(actor: Node3D) -> void:
	if _talking_actor != null:
		var previous_slot := _talking_actor.get_node_or_null("ModelSlot")
		if previous_slot != null:
			previous_slot.call("set_talking", false)
		var previous_name := _talking_actor.get_node_or_null("Name") as Label3D
		if previous_name != null:
			previous_name.visible = false
	_talking_actor = actor
	if _talking_actor != null:
		var active_slot := _talking_actor.get_node_or_null("ModelSlot")
		if active_slot != null:
			active_slot.call("set_talking", true)
		var active_name := _talking_actor.get_node_or_null("Name") as Label3D
		if active_name != null:
			active_name.visible = false
		camera_rig.call("enter_dialogue", _talking_actor)
	else:
		camera_rig.call("exit_dialogue")

func _refresh_world() -> void:
	var result: Dictionary = _call_bridge("state_json")
	if not result.get("ok", false):
		return
	var state: Dictionary = result.get("data", {})
	_story_state = state
	var flags: Dictionary = state.get("flags", {})
	_rendezvous.reconcile(flags)
	_pay_chest.set_filled(bool(flags.get("pay_returned", false)))
	var defeated := bool(_chapters.get("dockside_robbery", false))
	_pay_loot.visible = defeated and not bool(flags.get("pay_recovered", false))
	for actor in _garden_watch.get_children():
		actor.visible = not defeated or actor.name == "corsair_raider"
		actor.get_node("Art").set_conscious(not defeated)
		if defeated and actor.name == "corsair_raider":
			actor.position = preload("res://scripts/payroll_pouch.gd").quay_position()
			actor.get_node("Art").rotation.z = PI * .5
			actor.get_node("Art").position.y = .15
		elif not defeated:
			actor.transform = actor.get_meta("home_transform")
			actor.get_node("Art").rotation.z = 0
			actor.get_node("Art").position.y = 0
	var lit: bool = flags.get("oil_shared", false) or flags.get("pay_returned", false)
	lamp.light_energy = 0.0
	hub.set_beacon_lit(lit)
	var shade: StandardMaterial3D = $Mara/LampShade.material_override as StandardMaterial3D
	if shade != null:
		shade.albedo_color = Color("ffd36b") if lit else Color("8a5436")
	hub.call("set_gate_open", bool(flags.get("gate_open", false)))
	hub.call("set_shortcut_open", bool(flags.get("shortcut_open", false)))
	records_office.call("set_records_collected", bool(flags.get("records_collected", false)))
	_refresh_navigation()

func _call_bridge(method: String, args: Array = []) -> Dictionary:
	var raw: String = str(bridge.callv(method, args))
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Narrative extension returned invalid JSON."}
	return parsed

func prepare_garden_demo() -> void:
	for flag in ["robbery_known", "mara_recruited", "gate_open"]:
		_call_bridge("set_world_flag", [flag, true])
	_refresh_world()

func finish_garden_chapter(won: bool) -> void:
	_garden_threshold_armed = false
	if won:
		_chapters["dockside_robbery"] = true
		_call_bridge("set_world_flag", ["raiders_defeated", true])
		_refresh_world()
		player.global_position = _pay_loot.global_position + Vector3(-1.5, .8, .12)
		_rendezvous.follow_after_battle(player, player.position + Vector3(-1.5, 0, .2), _pay_loot.global_position + Vector3(.6, 1, -1.2))
	else:
		player.global_position = Vector3(29, 1.05, -2)
	player.rotation.y = deg_to_rad(-85.5)
	camera_rig.call("focus_after_teleport", -85.5, false)
	_refresh_world()
	if won:
		var scene := preload("res://scripts/garden_confrontation.gd").new()
		scene.demo = self
		scene.resolution = true
		scene.finished.connect(func() -> void:
			_show_status("Search the Crimson Raider for the stolen payroll.", 5.0)
		)
		add_child(scene)

func _build_pay_chest() -> void:
	_pay_chest = PAY_CHEST.new()
	_pay_chest.name = "RansackedPayrollChest"
	_pay_chest.position = Vector3(-.8, .22, -2.5)
	records_office.add_child(_pay_chest)
	_pay_loot = preload("res://scripts/payroll_pouch.gd").new()
	_pay_loot.name = "PayrollPouch"
	_pay_loot.position = Vector3(.4, .15, 0)
	_garden_watch.get_node("corsair_raider").add_child(_pay_loot)
	_pay_loot.hide()

func play_opening() -> void:
	mode = "opening"
	player.enabled = false
	camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	var opening := preload("res://scripts/quay_opening.gd").new()
	opening.name = "QuayOpening"
	opening.finished.connect(func() -> void:
		mode = "explore"
		player.enabled = true
		camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
		player.rotation.y = deg_to_rad(30.0)
		camera_rig.focus_after_teleport(30.0, false)
	)
	add_child(opening)

func _play_ending() -> void:
	_leave_records_office()
	player.position = Vector3(-2, 1.05, 2)
	_rendezvous.finish_at_quay()
	player.rotation.y = deg_to_rad(30.0)
	mode = "opening"
	player.enabled = false
	camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	var ending := preload("res://scripts/quay_opening.gd").new()
	ending.name = "QuayEnding"
	ending.section = "ending_early" if _story_state.flags.get("oil_shared", false) else "ending"
	ending.finished.connect(func() -> void:
		mode = "explore"
		player.enabled = true
		camera_rig.process_mode = Node.PROCESS_MODE_INHERIT
		camera_rig.focus_after_teleport(30.0, false)
	)
	add_child(ending)

func _build_garden_watch() -> void:
	_garden_watch = Node3D.new()
	_garden_watch.name = "GardenWatch"
	add_child(_garden_watch)
	var layout := preload("res://scripts/garden_layout.gd")
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/command_garden.json"))
	for entry in [["hound", "lantern_sentinel"], ["sentinel", "iron_sentinel"], ["corsair_raider", "crimson_corsair"]]:
		var actor := Node3D.new()
		actor.name = entry[0]
		var point: Array = geometry.spawns[entry[0]]
		actor.position = layout.point(Vector3(41.3 + float(point[0]) / 1.7, .54, -2.0 + float(point[1]) / 1.7))
		actor.rotation.y = PI * .5
		actor.set_meta("home_transform", actor.transform)
		_garden_watch.add_child(actor)
		var art := preload("res://scripts/command_adversary.gd").new()
		art.name = "Art"
		actor.add_child(art)
		art.configure(entry[1])

func _check_garden_threshold() -> void:
	var at := player.position
	if at.x < 30.0: _garden_threshold_armed = true
	if not _garden_threshold_armed or not _story_state.get("flags", {}).get("gate_open", false) or _chapters.get("dockside_robbery", false): return
	# The doorway crosses x=32, before the imported bridge climbs to the terrace.
	if at.x >= 32.0 and at.x <= 34.0 and absf(at.z + 2.0) < 1.65:
		if _rendezvous.assembled():
			_garden_threshold_armed = false
			chapter_requested.emit(combat_profile_id)
		else:
			player.position.x = 31.8
			player.velocity.x = 0
			_show_status("Mara is on her way. Wait here with Ivo.", 3.0)
