extends Control
signal finished
class WorldInput:
	extends Node
	signal unhandled(event: InputEvent)
	func _unhandled_input(event: InputEvent) -> void: unhandled.emit(event)
const CHAPTER := preload("res://scripts/garden_chapter.gd")
const STAGE := preload("res://scripts/flow_stage.gd")
const SPACE := preload("res://scripts/command_space.gd")
const HUD := preload("res://scripts/flow_hud.gd")
const UI := preload("res://scripts/combat_theme.gd")
var preview_mode := false
var campaign_mode := false
var play_intro := false
var _confrontation: Node3D
var seed_value := "20261022"
var save_path := "user://oathshaper_flow_trial_v2.json"
var bridge: RefCounted
var state: Dictionary = {}
var stage: Node3D
var viewport: SubViewport
var hud: Control
var _layer: CanvasLayer
var _modal: PanelContainer
var _space := SPACE.new()
var _serial := 0
var _prefix := ""
var _debt := 0.0
var _won := false
var _closing := false
var _stick := Vector2.ZERO
var _orbit := Vector2.ZERO
var _direction := Vector2.ZERO
var _trigger := false
var _guard := false
var _preview_tick := -1
var _last_phase := ""
var _focus_buttons: Array[Button] = []
func has_won() -> bool: return _won
var _audio := preload("res://scripts/combat_audio.gd").new()

func _ready() -> void:
	_audio.muted = preview_mode
	add_child(_audio)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prefix = "flow-%s-%s-" % [Time.get_ticks_usec(),get_instance_id()]
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280,800)
	container.add_child(viewport)
	var world_input := WorldInput.new()
	viewport.add_child(world_input)
	world_input.unhandled.connect(_world_input)
	stage = STAGE.new()
	viewport.add_child(stage)
	_layer = CanvasLayer.new()
	viewport.add_child(_layer)
	hud = HUD.new()
	_layer.add_child(hud)
	hud.requested.connect(_request)
	if not ClassDB.class_exists("FlowBridge"):
		hud.show_message("Flow extension unavailable.")
		return
	bridge = ClassDB.instantiate("FlowBridge")
	var result := _call("create",[seed_value])
	if result.get("ok",false): _publish(result.data)
	if preview_mode: submit({"kind":"start"}); submit({"kind":"follower","mode":"attack"})
	elif campaign_mode: _begin_encounter()
	elif play_intro:
		_confrontation = preload("res://scripts/garden_confrontation.gd").play_trial(self, func() -> void:
			_confrontation = null
			_begin_encounter())
	else: _camp()
func _call(method: String, args: Array = []) -> Dictionary:
	if bridge == null: return {"ok":false}
	var result = JSON.parse_string(bridge.callv(method,args))
	if not result is Dictionary: return {"ok":false}
	if not result.get("ok",false): hud.show_message(str(result.get("error",{}).get("message","Flow failed")))
	return result
func _publish(data: Dictionary) -> void:
	state = data.get("view",data)
	if state.get("schema") != "flow.view/v1": return
	_won = _won or bool(state.encounter.won)
	_audio.apply_view(state)
	stage.apply_view(state)
	hud.apply_view(state)
func submit(action: Dictionary) -> Dictionary:
	if state.is_empty() or _closing: return {}
	_serial += 1
	var result := _call("submit",[JSON.stringify({"schema":"flow.action/v1","command_id":_prefix+str(_serial),"generation":state.session.generation,"expected_revision":state.session.revision,"action":action})])
	if not result.get("ok",false): return {}
	_publish(result.data)
	var receipt: Dictionary = result.data.receipt
	if receipt.status == "rejected": hud.show_message(str(receipt.reason.message))
	return receipt
func pump_tick() -> Dictionary:
	var requests := _call("space_requests")
	var cursor := _call("space_sequence")
	if not requests.get("ok",false) or not cursor.get("ok",false): return {}
	var observed := _call("observe_space",[JSON.stringify(_space.frame(requests.data,str(cursor.data)))])
	if not observed.get("ok",false): return {}
	var result := _call("advance",[1])
	if result.get("ok",false): _publish(result.data); return result.data
	return {}
func _process(delta: float) -> void:
	if bridge == null or _closing or state.is_empty(): return
	if _orbit.length() > .15 and _modal == null: stage.orbit(_orbit * delta * 200.0)
	if state.clock.paused or state.session.phase != "encounter":
		_debt = 0
	else:
		if not preview_mode: _movement()
		else: _preview()
		_debt = minf(_debt+delta,.25)
		for i in range(12):
			if _debt < .05: break
			var result := pump_tick()
			if result.get("consumed_ticks",0)>0: _debt -= .05
			elif result.get("stop_reason") != "waiting_for_space": break
	if str(state.session.phase) != _last_phase:
		_last_phase = str(state.session.phase)
		if not preview_mode and _last_phase in ["victory","defeat","surrender"]: _outcome()
func _request(action: Dictionary) -> void:
	if _modal != null: return
	match str(action.kind):
		"ui.pause": _toggle_pause()
		"ui.target": _next_target()
		"ui.menu": _menu()
		"ui.focus": submit({"kind":"focus","enabled":not state.hero.focus_mode})
		"ui.heal": submit({"kind":"heal","enabled":not state.hero.healing})
		_: submit(action)
func _begin_encounter() -> void:
	submit({"kind":"start"})
	submit({"kind":"pause","token":"ready"})
func _neutralize_input() -> void:
	_direction = Vector2.ZERO
	_stick = Vector2.ZERO
	_orbit = Vector2.ZERO
	_trigger = false
	_guard = false
	submit({"kind":"move","direction":[0,0]})
	submit({"kind":"guard","enabled":false})
	submit({"kind":"heal","enabled":false})
func _toggle_pause() -> void:
	if state.session.phase != "encounter": return
	_neutralize_input()
	for token in ["ready","manual"]:
		if state.clock.pause_reasons.has(token):
			submit({"kind":"unpause","token":token})
			return
	submit({"kind":"pause","token":"manual"})
func _next_target(direction := 1) -> void:
	var ids: Array = []
	for actor in state.actors:
		if actor.faction == "hostile" and actor.conscious: ids.append(actor.id)
	if ids.is_empty(): return
	var hero: Dictionary = hud.actor("player")
	ids.sort_custom(func(a: String, b: String) -> bool:
		var pa: Array = hud.actor(a).position
		var pb: Array = hud.actor(b).position
		var aa := atan2(float(pa[1])-float(hero.position[1]),float(pa[0])-float(hero.position[0]))
		var ab := atan2(float(pb[1])-float(hero.position[1]),float(pb[0])-float(hero.position[0]))
		return a < b if is_equal_approx(aa,ab) else aa < ab)
	var i := ids.find(state.hero.target_id)
	submit({"kind":"target","actor_id":ids[0 if i < 0 else posmod(i+direction,ids.size())]})
func _movement() -> void:
	var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if _stick.length()>.2: input = _stick
	var world: Vector3 = stage.camera.global_basis.x*input.x + stage.camera.global_basis.z*input.y
	var direction := Vector2(world.x,world.z).normalized() if input.length()>.1 else Vector2.ZERO
	if direction.distance_to(_direction)>.05:
		_direction = direction
		submit({"kind":"move","direction":[direction.x,direction.y]})
func _pause() -> void:
	_neutralize_input()
	if not state.clock.pause_reasons.has("menu"): submit({"kind":"pause","token":"menu"})
func _close(resume := true) -> void:
	if is_instance_valid(_modal): _layer.remove_child(_modal); _modal.queue_free()
	_modal = null
	if resume and state.clock.pause_reasons.has("menu"): submit({"kind":"unpause","token":"menu"})
func _show(title: String, copy: String, entries: Array) -> void:
	_close(false)
	_pause()
	_modal = PanelContainer.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_modal.offset_left = -330
	_modal.offset_right = 330
	_modal.offset_top = -320
	_modal.offset_bottom = 320
	_modal.add_theme_stylebox_override("panel",UI.style(Color("12252b"),UI.BRASS,2))
	_layer.add_child(_modal)
	preload("res://scripts/chapter_voice.gd").attach(_modal, copy)
	var col := VBoxContainer.new()
	_modal.add_child(col)
	col.add_child(UI.label(title,26,UI.INK,true))
	col.add_child(UI.label(copy,18,UI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var buttons := VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(buttons)
	var focus: Array[Button] = []
	for entry in entries:
		var callback: Callable = entry[1]
		var button := UI.button(str(entry[0]),func() -> void: callback.call_deferred())
		button.custom_minimum_size.y = 46
		button.add_theme_font_size_override("font_size",18)
		buttons.add_child(button)
		focus.append(button)
	for i in range(focus.size()):
		focus[i].focus_neighbor_top = focus[i].get_path_to(focus[posmod(i-1,focus.size())])
		focus[i].focus_neighbor_bottom = focus[i].get_path_to(focus[posmod(i+1,focus.size())])
		focus[i].focus_previous = focus[i].focus_neighbor_top
		focus[i].focus_next = focus[i].focus_neighbor_bottom
	_focus_buttons = focus
	if not focus.is_empty(): focus[0].grab_focus()
func _camp() -> void:
	_show("Garden camp","Prepare your styles and amulet before entering the garden.",[["Enter the garden",func() -> void: _close(); submit({"kind":"start"})],["Training and amulet",_menu],["Rest at shrine",func() -> void: submit({"kind":"rest"});_camp()],["Load chapter",_load],["Return to quay" if campaign_mode else "Return to menu",_finish]])
func _menu() -> void:
	var a: Dictionary = state.hero.attributes
	var skill_labels := PackedStringArray()
	for skill in state.hero.skill_scores: skill_labels.append("%s %d" % [str(skill).capitalize(),state.hero.skill_scores[skill]])
	_show("Flow · Actor and equipment","Body %d · Spirit %d · Mind %d\nLevel %d · %d XP · %d copper\nStyle points %d · Attribute points %d\nSkills: %s" % [a.body,a.spirit,a.mind,state.progression.level,state.progression.xp,state.inventory.copper,state.progression.style_points,state.progression.attribute_points,", ".join(skill_labels)],[["Enter the garden" if state.session.phase == "camp" and not state.encounter.won else "Resume",_resume_or_start],["Style library / training",_library],["Amulet collection",_equipment],["Investment presets · 30 copper",_presets],["Mara: " + str(state.follower.mode),func() -> void: submit({"kind":"follower","mode":"attack" if state.follower.mode=="support" else "support"});_menu()],["Increase Body",func() -> void: submit({"kind":"attribute","attribute":0});_menu()],["Increase Spirit",func() -> void: submit({"kind":"attribute","attribute":1});_menu()],["Increase Mind",func() -> void: submit({"kind":"attribute","attribute":2});_menu()],["Audio",func() -> void: preload("res://scripts/game_audio.gd").ensure(self).open_settings()],["Save chapter",_save],["Load chapter",_load],["Return to quay" if campaign_mode else "Return to menu",_confirm_exit]])
func _presets() -> void:
	var entries: Array = []
	for preset in ["stone","gale","harbor","storm"]:
		var id: String = preset
		entries.append(["Rebuild as " + preset.capitalize(),func() -> void: submit({"kind":"preset","preset":id});_presets()])
	entries.append(["Back",_menu])
	_show("Investment presets","All four styles stay learned. Rebuild at camp for 30 copper; resources do not refill. Unbind incompatible gems first.",entries)
func _library() -> void:
	var entries: Array = []
	for style in ["stone","gale","harbor","still"]:
		var id: String = style
		entries.append([HUD.NAMES[id],func() -> void: _style_page(id)])
	entries.append(["Back",_menu])
	_show("Style library","Martial · Magic · Weapon · Support\nCross-train any learned style.",entries)
func _style_page(id: String) -> void:
	var entries: Array = []
	for i in range(4):
		var slot := i
		entries.append(["Assign " + ["↑ Up","→ Right","↓ Down","← Left"][i],func() -> void: submit({"kind":"assign","slot":slot,"style":id});_style_page(id)])
	for track in (["control","speed","efficiency"] if id=="still" else ["damage","speed","efficiency"]):
		var name: String = track
		var rank: int = state.hero.ranks.get(id+":"+name,0)
		entries.append(["Train %s %d → %d · %d points" % [name,rank,rank+1,rank+1],func() -> void: submit({"kind":"train","style":id,"track":name});_style_page(id)])
	entries.append(["Back",_library])
	_show(HUD.NAMES[id],"Assign freely while paused. Train at camp. Each higher rank costs one more style point.",entries)
func _equipment() -> void:
	var entries: Array = []
	for item in state.inventory.items:
		if item.protected: continue
		var id: String = item.id
		for socket in range(2):
			var slot: int = socket
			entries.append(["%s → socket %d%s" % [item.name.capitalize(),socket+1," · requirement unmet" if not item.eligible else ""],func() -> void: submit({"kind":"equip","item_id":id,"socket":slot});_equipment()])
	for socket in range(2):
		var slot: int = socket
		entries.append(["Clear socket %d" % [socket+1],func() -> void: submit({"kind":"unequip","socket":slot});_equipment()])
	entries.append(["Back",_menu])
	_show("Tideglass amulet","Two gem sockets · changes at camp\nStone: Body 8, +20 Health · Rain: Spirit 8, +10 Chi\nHawk: Mind 8, +10 Focus · Speaker: +2 Charm/Intuition",entries)
func _outcome() -> void:
	if _closing: return
	if state.session.phase == "surrender":
		if is_instance_valid(_confrontation): return
		_neutralize_input()
		_confrontation = preload("res://scripts/garden_confrontation.gd").play_surrender(self, func(accept: bool) -> void:
			_confrontation = null
			submit({"kind":"surrender","accept":accept}))
	elif state.session.phase == "victory":
		_closing = true
		_finish.call_deferred()
	else:
		_show("Defeated","Return to the gate with the complete pre-encounter state.",[["Retry from checkpoint",func() -> void: _close();submit({"kind":"retry"});_resume_restore();_camp()],["Load chapter",_load],["Return to quay" if campaign_mode else "Return to menu",_finish]])
func _save() -> void:
	var result := _call("save_json")
	if result.get("ok",false):
		var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
		if file == null: hud.show_message("Save failed.");return
		file.store_string(result.data.save)
		file.close()
		var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path+".tmp"),ProjectSettings.globalize_path(save_path))
		hud.show_message("Chapter saved." if error==OK else "Save failed.")
func _resume_restore() -> void:
	var token = state.clock.get("restore_token")
	if token != null: submit({"kind":"resume","token":token})
func _load() -> void:
	if not FileAccess.file_exists(save_path): hud.show_message("No saved chapter.");return
	var result := _call("restore_json",[FileAccess.get_file_as_string(save_path)])
	if result.get("ok",false):
		_close(false)
		_publish(result.data)
		_resume_restore()
		_debt=0
		_menu()
func _confirm_exit() -> void:
	_show("Leave the garden?","Unsaved chapter progress will be lost.",[["Return to quay" if campaign_mode else "Return to menu",_finish],["Stay",_menu]])
func _finish() -> void:
	_closing=true
	finished.emit()
func _preview() -> void:
	var tick: int = state.session.tick
	if tick == _preview_tick: return
	_preview_tick=tick
	if tick % 5 != 0: return
	var target: Dictionary = hud.actor(str(state.hero.target_id))
	if target.is_empty() or not target.conscious: _next_target();return
	var hero: Dictionary = hud.actor("player")
	var direction := Vector2(target.position[0]-hero.position[0],target.position[1]-hero.position[1])
	if direction.length()>1.6: direction=direction.normalized()
	else: direction=Vector2.ZERO
	submit({"kind":"move","direction":[direction.x,direction.y]})
	if hero.active_action == null: submit({"kind":"attack","verb":"power" if target.guard else "normal"})
func _input(event: InputEvent) -> void:
	if preview_mode or _closing or bridge==null: return
	if event is InputEventKey and event.echo: get_viewport().set_input_as_handled();return
	var back: bool = event.is_pressed() and ((event is InputEventKey and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B))
	if _modal != null:
		# Releases must retire input latches even while the modal owns input.
		# Stick motion is suppressed until a fresh event after dismissal.
		if event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_TRIGGER_RIGHT and event.axis_value <= .5: _trigger = false
			if event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value <= .5: _guard = false
			_stick = Vector2.ZERO
			_orbit = Vector2.ZERO
		if event is InputEventKey and event.pressed and (event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB):
			var current := viewport.gui_get_focus_owner()
			var index := _focus_buttons.find(current)
			if not _focus_buttons.is_empty(): _focus_buttons[posmod(index + (-1 if event.shift_pressed else 1),_focus_buttons.size())].grab_focus()
			get_viewport().set_input_as_handled()
			return
		if back and state.session.phase != "surrender": _close();get_viewport().set_input_as_handled()
		return
	var action: Dictionary = {}
	if event is InputEventKey:
		if event.keycode==KEY_SHIFT: action={"kind":"guard","enabled":event.pressed}
		elif event.keycode==KEY_Q: action={"kind":"heal","enabled":event.pressed}
		elif event.pressed:
			match event.keycode:
				KEY_P: _toggle_pause();get_viewport().set_input_as_handled()
				KEY_ENTER:
					if state.clock.pause_reasons.has("ready") or viewport.gui_get_focus_owner() == null:
						_toggle_pause();get_viewport().set_input_as_handled()
				KEY_1,KEY_2,KEY_3,KEY_4: action={"kind":"style","style":state.hero.diamond[event.keycode-KEY_1]}
				KEY_SPACE: action={"kind":"dodge"}
				KEY_R: action={"kind":"attack","verb":"area"}
				KEY_F: action={"kind":"focus","enabled":not state.hero.focus_mode}
				KEY_E: action={"kind":"enhance","enabled":not state.hero.chi_enhancement}
				KEY_TAB,KEY_T: _next_target(-1 if event.shift_pressed else 1);get_viewport().set_input_as_handled()
				KEY_I,KEY_ESCAPE,KEY_C: _menu()
				KEY_V: _library()
	elif event is InputEventJoypadButton:
		if event.button_index==JOY_BUTTON_LEFT_SHOULDER: action={"kind":"heal","enabled":event.pressed}
		elif event.pressed:
			match event.button_index:
				JOY_BUTTON_Y: action={"kind":"attack","verb":"power"}
				JOY_BUTTON_X: action={"kind":"attack","verb":"area"}
				JOY_BUTTON_A: action={"kind":"enhance","enabled":not state.hero.chi_enhancement}
				JOY_BUTTON_B: action={"kind":"dodge"}
				JOY_BUTTON_RIGHT_SHOULDER: action={"kind":"focus","enabled":not state.hero.focus_mode}
				JOY_BUTTON_DPAD_UP: action={"kind":"style","style":state.hero.diamond[0]}
				JOY_BUTTON_DPAD_RIGHT: action={"kind":"style","style":state.hero.diamond[1]}
				JOY_BUTTON_DPAD_DOWN: action={"kind":"style","style":state.hero.diamond[2]}
				JOY_BUTTON_DPAD_LEFT: action={"kind":"style","style":state.hero.diamond[3]}
				JOY_BUTTON_RIGHT_STICK: _next_target()
				JOY_BUTTON_START: _toggle_pause();get_viewport().set_input_as_handled()
				JOY_BUTTON_LEFT_STICK: _menu()
				JOY_BUTTON_BACK: _library()
	elif event is InputEventJoypadMotion:
		if state.clock.paused: return
		match event.axis:
			JOY_AXIS_LEFT_X: _stick.x=event.axis_value
			JOY_AXIS_LEFT_Y: _stick.y=event.axis_value
			JOY_AXIS_RIGHT_X: _orbit.x=event.axis_value
			JOY_AXIS_RIGHT_Y: _orbit.y=event.axis_value
			JOY_AXIS_TRIGGER_RIGHT:
				if event.axis_value>.5 and not _trigger: action={"kind":"attack","verb":"normal"}
				_trigger=event.axis_value>.5
			JOY_AXIS_TRIGGER_LEFT:
				if (event.axis_value>.5)!=_guard: action={"kind":"guard","enabled":event.axis_value>.5}
				_guard=event.axis_value>.5
	if not action.is_empty(): submit(action);get_viewport().set_input_as_handled()

func _world_input(event: InputEvent) -> void:
	if preview_mode or _closing or _modal != null: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: submit({"kind":"attack","verb":"normal"});viewport.set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT: submit({"kind":"attack","verb":"power"});viewport.set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_next_target(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			viewport.set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		stage.orbit(event.relative)
		viewport.set_input_as_handled()

func _resume_or_start() -> void:
	_close()
	if state.session.phase == "camp" and not state.encounter.won: submit({"kind":"start"})
