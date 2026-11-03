extends Control
## Isolated playable Vanguard host. The hub consumes has_won() before finished.
signal finished
const STAGE := preload("res://scripts/vanguard_stage.gd")
const UI := preload("res://scripts/combat_theme.gd")
const CHAPTER := preload("res://scripts/garden_chapter.gd")
const HINTS := preload("res://scripts/input_hints.gd")
class AimReticle:
	extends Control
	func _draw() -> void:
		var center := size * .5
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + direction * 7, center + direction * 18, Color("091114"), 5, true)
			draw_line(center + direction * 7, center + direction * 18, Color.WHITE, 2, true)
		draw_circle(center, 3, Color("091114"))
		draw_circle(center, 1.5, Color.WHITE)
var preview_mode := false
var campaign_mode := false
var play_intro := false
var _confrontation: Node3D
var bridge: RefCounted
var state: Dictionary = {}
var stage: Node3D
var viewport: SubViewport
var _layer: CanvasLayer
var _hud: Control
var _status: Label
var _target: Label
var _heat: Label
var _health: Label
var _squad: Label
var _notice: Label
var _reticle: Control
var _cover_hint: Label
var _cover_waypoint: Label
var _modal: Control
var _wheel_actor := "mara"
var _buttons: Dictionary = {}
var _remainder := 0.0
var _won := false
var _closing := false
var _mouse_aim := false
var _right_stick := Vector2.ZERO
var _left_stick := Vector2.ZERO
var _trigger := false
var _preview_time := 0.0
var _notice_time := 0.0

func has_won() -> bool:
	return _won

var _audio := preload("res://scripts/combat_audio.gd").new()

func _ready() -> void:
	_audio.muted = preview_mode
	add_child(_audio)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	stage = STAGE.new()
	viewport.add_child(stage)
	_layer = CanvasLayer.new()
	# The menu hosts this trial on canvas 30. The root overlay must draw above
	# that world's opaque SubViewportContainer (cinematics own layer 40).
	var world_layer := get_canvas_layer_node()
	_layer.layer = world_layer.layer + 1 if world_layer != null else 1
	add_child(_layer)
	_build_hud()
	if not ClassDB.class_exists("VanguardBridge"):
		_notice.text = "Vanguard extension unavailable"
		return
	bridge = ClassDB.instantiate("VanguardBridge")
	_publish(_call("create").get("data", {}))
	if preview_mode:
		submit({"kind":"begin"})
	elif campaign_mode:
		_begin()
	elif play_intro:
		_confrontation = preload("res://scripts/garden_confrontation.gd").play_trial(self, func() -> void:
			_confrontation = null
			_begin())
	else:
		_briefing()

func _call(method: String, args: Array = []) -> Dictionary:
	var result = JSON.parse_string(bridge.callv(method, args))
	if not result is Dictionary:
		return {"ok":false}
	if not result.get("ok", false):
		message(str(result.get("error", "Vanguard request failed")))
	return result

func submit(action: Dictionary) -> Dictionary:
	if bridge == null or _closing:
		return {}
	var result := _call("submit", [JSON.stringify(action)])
	if result.get("ok", false):
		_publish(result.data.view)
		var receipt: Dictionary = result.data.receipt
		if receipt.status == "rejected":
			message(str(receipt.reason.message))
		return receipt
	return {}

func _publish(data: Dictionary) -> void:
	if data.get("schema", "") != "vanguard.view/v1":
		return
	state = data
	_won = _won or state.status == "won"
	_audio.apply_view(state)
	stage.apply_view(state)
	var p: Dictionary = state.actors.player
	var weapon: Dictionary = p.weapons[p.active]
	_status.text = "THE QUAY ROBBERY   /   VANGUARD"
	_health.text = "TESSA WARD  ·  BREACHER\nShields %d / %d   Health %d / %d%s" % [p.shields / 60, p.shield_max / 60, p.hp / 60, p.hp_max / 60, "   Barrier %d" % (p.barrier / 60) if p.barrier > 0 else ""]
	_heat.text = "%s  ·  %s\nHEAT  %d%%  %s\n%s" % [str(weapon.kind).to_upper(), str(weapon.module).capitalize(), weapon.heat / 60, "OVERHEATED · cool to 30%" if weapon.latched else "", ("LB  Swap weapon    X  Holster" if HINTS.controller_active() else "Q  Swap weapon    R  Holster")]
	_squad.text = "MARA  ·  %d shields  /  %d health  ·  %s\nIVO  ·  %d shields  /  %d health  ·  %s" % [state.actors.mara.shields / 60, state.actors.mara.hp / 60, state.actors.mara.stance, state.actors.ivo.shields / 60, state.actors.ivo.hp / 60, state.actors.ivo.stance]
	_target.text = ""
	if state.aim != null and state.actors.has(state.aim):
		var target: Dictionary = state.actors[state.aim]
		_target.text = "%s\nShields %d  ·  Health %d%s" % [target.name, target.shields / 60, target.hp / 60, "  ·  Anchored" if state.aim == "sentinel" else ""]
	_reticle.modulate = Color("efa078") if state.aim != null else UI.INK
	_update_cover_hint()
	if state.status in ["won", "lost", "surrender"] and _modal == null and not is_instance_valid(_confrontation) and not preview_mode:
		_outcome()

func message(text: String) -> void:
	_notice.text = text
	_notice_time = 4.0

func _label(parent: Control, text: String, rect: Rect2, size := 18, color := UI.INK) -> Label:
	var node := UI.label(text, size, color)
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_hud)
	var backplate := Panel.new()
	backplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backplate.add_theme_stylebox_override("panel", UI.style(Color(.035,.055,.07,.82), Color(.35,.45,.48,.6)))
	_hud.add_child(backplate)
	backplate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	backplate.offset_left = 16
	backplate.offset_right = -16
	backplate.offset_top = -155
	backplate.offset_bottom = -12
	var header := Panel.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_stylebox_override("panel", UI.style(Color(.035,.055,.07,.82), Color(.35,.45,.48,.6)))
	_hud.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 16
	header.offset_right = -16
	header.offset_top = 12
	header.offset_bottom = 124
	_status = _label(_hud, "", Rect2(32, 22, 760, 28), 19, UI.BRASS)
	_label(_hud, CHAPTER.story().objective, Rect2(32, 54, 700, 32), 17)
	_health = _label(_hud, "", Rect2(32, 660, 650, 64), 20)
	_squad = _label(_hud, "", Rect2(32, 725, 760, 55), 16, Color("9ad6dd"))
	_heat = _label(_hud, "", Rect2(850, 654, 400, 118), 19)
	_anchor_rect(_health, Vector2(0, 1), Rect2(32, -140, 650, 64))
	_anchor_rect(_squad, Vector2(0, 1), Rect2(32, -75, 760, 55))
	_anchor_rect(_heat, Vector2(1, 1), Rect2(-430, -146, 400, 118))
	_target = _label(_hud, "", Rect2(440, 140, 400, 70), 20)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target.add_theme_color_override("font_outline_color", Color("091114"))
	_target.add_theme_constant_override("outline_size", 6)
	_anchor_rect(_target, Vector2(.5, 0), Rect2(-200, 140, 400, 70))
	_reticle = AimReticle.new()
	_reticle.name = "AimReticle"
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_reticle)
	_anchor_rect(_reticle, Vector2(.5, .5), Rect2(-22, -22, 44, 44))
	_notice = _label(_hud, "", Rect2(290, 554, 700, 38), 18, UI.BRASS)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_theme_color_override("font_outline_color", Color("091114"))
	_notice.add_theme_constant_override("outline_size", 6)
	_anchor_rect(_notice, Vector2(.5, 1), Rect2(-350, -246, 700, 38))
	var cover_panel := Panel.new()
	cover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover_panel.add_theme_stylebox_override("panel", UI.style(Color(.035,.055,.07,.9), UI.BRASS))
	_hud.add_child(cover_panel)
	_anchor_rect(cover_panel, Vector2(.5, 1), Rect2(-350, -206, 700, 40))
	_cover_hint = _label(cover_panel, "", Rect2(12, 3, 676, 34), 18, UI.BRASS)
	_cover_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _label(_hud, "", Rect2(32, 92, 1216, 28), 16, UI.MUTED)
	HINTS.attach(_hud).bind(controls,
		"WASD  Move    RMB  Aim    LMB  Fire    Space  Cover    Tab  Squad powers    Esc  Menu",
		"Left stick  Move    Right stick  Aim    LT  Sight    RT  Fire    A  Cover    RB  Squad powers    Start  Menu")
	_cover_waypoint = _label(_hud, "", Rect2(0, 0, 160, 50), 17, UI.BRASS)
	_cover_waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover_waypoint.add_theme_color_override("font_outline_color", Color("091114"))
	_cover_waypoint.add_theme_constant_override("outline_size", 7)

func _anchor_rect(control: Control, anchor: Vector2, rect: Rect2) -> void:
	control.set_anchor(SIDE_LEFT, anchor.x)
	control.set_anchor(SIDE_RIGHT, anchor.x)
	control.set_anchor(SIDE_TOP, anchor.y)
	control.set_anchor(SIDE_BOTTOM, anchor.y)
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _update_cover_hint() -> void:
	if state.is_empty(): return
	var p: Dictionary = state.actors.player
	var candidate: Dictionary = stage.cover_candidate(Vector2(p.position[0], p.position[1]) / 1000.0)
	var button := "A" if HINTS.controller_active() else "Space"
	if p.cover:
		_cover_hint.text = "%s  Leave cover   ·   %s  Peek and aim" % [button, "LT" if HINTS.controller_active() else "RMB"]
	elif not candidate.is_empty() and candidate.available:
		_cover_hint.text = "%s  Take cover" % button
	else:
		_cover_hint.text = "Move beside a planter to take cover"
	_cover_waypoint.hide()
	if candidate.is_empty() or candidate.distance >= 5 or candidate.available or p.cover or p.hp <= 0: return
	var at: Vector2 = candidate.point
	var marker := Vector3(at.x, stage._space.height_at(at) + 1.65, at.y)
	if stage.camera.is_position_behind(marker): return
	var screen: Vector2 = stage.camera.unproject_position(marker) * _hud.size / Vector2(viewport.size)
	if not Rect2(80, 145, _hud.size.x - 160, _hud.size.y - 400).has_point(screen): return
	_cover_waypoint.position = screen - Vector2(80, 40)
	_cover_waypoint.text = "Cover · %.0f m\n⌄" % candidate.distance
	_cover_waypoint.show()

func _base_modal(owner: String) -> Control:
	_clear_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_modal)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_aim = false
	_trigger = false
	submit({"kind":"trigger", "pressed":false})
	submit({"kind":"aim", "pressed":false})
	if owner != "briefing" and owner != "outcome":
		submit({"kind":"pause", "owner":owner,"paused":true})
	var shade := ColorRect.new()
	shade.color = Color(.035,.055,.07,.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	_buttons.clear()
	return _modal

func _button(parent: Control, key: String, title: String, rect: Rect2, callback: Callable) -> Button:
	var button := UI.button(title, callback)
	button.position = rect.position
	button.size = rect.size
	button.custom_minimum_size = rect.size
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	_buttons[key] = button
	return button

func _clear_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func _briefing() -> void:
	var panel := _base_modal("briefing")
	_label(panel, "Squad loadout", Rect2(125, 85, 1000, 60), 36, UI.BRASS)
	_label(panel, "Vanguard · Aim your weapon, keep the squad together, and strip shields before using biotics.", Rect2(125, 310, 1020, 64), 21)
	_label(panel, "Loadout: Tessa Ward carries a carbine and shotgun. Mara's pulse tool disrupts weapons and shields. Ivo's ward lens protects allies and throws exposed enemies.", Rect2(125, 384, 1020, 90), 20, UI.MUTED)
	_label(panel, "Carbine module · cooling trades 5 damage for +10 cooling/s; damage adds 5 damage and 5 heat/shot.", Rect2(125, 488, 1020, 54), 18)
	for index in range(3):
		var module: String = ["standard","cooling","damage"][index]
		var current: String = state.actors.player.weapons[0].module
		_button(panel, "module:"+module, ("✓ " if current == module else "")+module.capitalize(), Rect2(125+index*342,552,320,58), func() -> void:
			submit({"kind":"equip","actor":"player","module":module})
			_briefing())
	_button(panel, "begin", "Enter the garden", Rect2(125, 657, 500, 62), _begin).grab_focus()
	_button(panel, "leave", "Return to quay" if campaign_mode else "Return to menu", Rect2(655, 657, 500, 62), _finish)

func _begin() -> void:
	_clear_modal()
	submit({"kind":"begin"})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _wheel() -> void:
	if state.status != "engaged":
		return
	var panel := _base_modal("wheel")
	_label(panel, "SQUAD POWERS", Rect2(410, 36, 500, 44), 30, UI.BRASS)
	_label(panel, "Time is paused · Select one power, then return to the fight", Rect2(300, 86, 800, 34), 18)
	var ids := ["player", "mara", "ivo"]
	for index in range(3):
		var id: String = ids[index]
		_button(panel,"actor:"+id,("● " if id == _wheel_actor else "")+str(state.actors[id].name),Rect2(200+index*300,140,280,54),func() -> void: _wheel_actor=id; _wheel())
	var actor: Dictionary = state.actors[_wheel_actor]
	var kit := "Medium harness · carbine + shotgun" if _wheel_actor == "player" else ("Light rig · pistol · pulse tool" if _wheel_actor == "mara" else "Light rig · pistol · concord tool + ward lens")
	_label(panel, actor.class+"\n"+kit, Rect2(245, 217, 800, 64), 20, UI.MUTED)
	var powers: Array = actor.powers
	var spots := [Vector2(160,330),Vector2(790,330),Vector2(470,475)]
	var first: Button
	for index in range(powers.size()):
		var power: String = powers[index]
		var remaining := maxi(0, int(actor.cooldowns.get(power,0))-int(state.tick))
		var title := power.replace("_", " ").capitalize()
		var detail := _power_detail(power)
		if remaining > 0:
			title += "  %.1fs" % (remaining / 60.0)
		var button := _button(panel,"power:"+power,title+"\n"+detail,Rect2(spots[index],Vector2(330,100)),func() -> void: _power(_wheel_actor,power))
		button.disabled = remaining > 0 or actor.hp <= 0 or actor.pending != null
		if first == null and not button.disabled:
			first = button
	var target_text := "Aim at an enemy before opening the wheel"
	if state.aim != null:
		target_text = "TARGET\n"+str(state.actors[state.aim].name)
	_label(panel,target_text,Rect2(500,342,280,100),20,UI.BRASS).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _wheel_actor != "player":
		for index in range(3):
			var stance: String = ["follow","hold","attack"][index]
			_button(panel,"order:"+stance,stance.capitalize(),Rect2(220+index*290,620,270,54),func() -> void:
				submit({"kind":"order","actor":_wheel_actor,"stance":stance,"target":str(state.aim) if state.aim != null else ""})
				_close_wheel())
	preload("res://scripts/input_hints.gd").attach(panel).bind(_button(panel,"resume","Resume",Rect2(430,710,420,54),_close_wheel), "Resume · Tab", "Resume · B")
	if first != null:
		first.grab_focus()

func _power_detail(power: String) -> String:
	match power:
		"arc_overload": return "TECH · Strip 60 shields"
		"disrupt": return "TECH · Strip 40 shields"
		"sabotage": return "TECH · Disable firearm for 2s"
		"shield_repair": return "TECH · Restore Tessa Ward's shields"
		"barrier_pulse": return "BIOTIC · Shield Tessa Ward for 4s"
		"kinetic_throw": return "BIOTIC · Unshielded targets only"
		"concussive_shot": return "COMBAT · 30 damage + stagger"
		"fortify": return "COMBAT · Reduce health damage"
	return ""

func _power(actor: String, power: String) -> void:
	var target: String = "player" if power in ["shield_repair","barrier_pulse","fortify"] else (str(state.aim) if state.aim != null else "")
	var receipt := submit({"kind":"power","actor":actor,"power":power,"target":target})
	if receipt.get("status") == "accepted":
		_close_wheel()

func _close_wheel() -> void:
	_clear_modal()
	submit({"kind":"pause","owner":"wheel","paused":false})
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _menu() -> void:
	var panel := _base_modal("menu")
	_label(panel,"Garden paused",Rect2(380,200,600,65),34,UI.BRASS)
	_label(panel,"Resume the fight, or regroup at the garden gate.",Rect2(300,280,700,64),20)
	_button(panel,"resume","Resume",Rect2(390,380,500,60),func() -> void:
		_clear_modal()
		submit({"kind":"pause","owner":"menu","paused":false})
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED).grab_focus()
	_button(panel,"restart","Restart encounter",Rect2(390,460,500,60),_restart)
	_button(panel,"leave","Return to quay" if campaign_mode else "Return to menu",Rect2(390,540,500,60),_finish)
	_button(panel,"audio","Audio",Rect2(390,620,500,60),func() -> void: preload("res://scripts/game_audio.gd").ensure(self).open_settings())

func _outcome() -> void:
	if _closing: return
	if state.status == "surrender":
		# State already owns the surrender pause. Defer to avoid reentering _publish.
		_right_stick = Vector2.ZERO
		_left_stick = Vector2.ZERO
		stage.move_axis = Vector2.ZERO
		_mouse_aim = false
		_trigger = false
		_confrontation = preload("res://scripts/garden_confrontation.gd").play_surrender(self, func(accept: bool) -> void:
			_confrontation = null
			submit({"kind":"surrender","accept":accept}))
		return
	if state.status == "won":
		_closing = true
		_finish.call_deferred()
		return
	var panel := _base_modal("outcome")
	_label(panel,"Party defeated",Rect2(180,185,940,60),36,UI.BRASS)
	_label(panel,"The sentries drove the party back. Regroup at the garden gate and try another approach.",Rect2(180,290,940,170),24)
	_button(panel,"restart","Try the encounter again",Rect2(180,565,440,65),_restart)
	_button(panel,"leave","Return to quay" if campaign_mode else "Return to menu",Rect2(660,565,440,65),_finish).grab_focus()

func _restart() -> void:
	_clear_modal()
	_publish(_call("create").get("data", {}))
	_briefing()

func _finish() -> void:
	_closing = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finished.emit()

func _exit_tree() -> void:
	if not preview_mode:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if bridge == null or state.is_empty() or _closing:
		return
	_update_cover_hint()
	_notice_time -= delta
	if _notice_time <= 0:
		_notice.text = str(state.log[-1]) if not state.log.is_empty() else ""
	if state.paused:
		_remainder = 0.0
		return
	if preview_mode:
		_preview_time += delta
		if _preview_time > 20:
			_preview_time = 0
			_publish(_call("create").get("data",{}))
			submit({"kind":"begin"})
	else:
		stage.look(_right_stick * delta * 700)
		var keyboard := Input.get_vector("move_left","move_right","move_forward","move_back")
		stage.move_axis = keyboard if keyboard.length() > _left_stick.length() else _left_stick
	_remainder += minf(delta,.1)
	while _remainder >= 1.0/60.0:
		var frame: Dictionary = stage.frame(state)
		var result := _call("advance",[JSON.stringify(frame)])
		if result.get("ok",false):
			if result.data.receipt.status == "rejected":
				message(result.data.receipt.reason.message)
				_remainder = 0
				break
			_publish(result.data.view)
		_remainder -= 1.0/60.0
		if state.paused or is_instance_valid(_confrontation):
			break

func _input(event: InputEvent) -> void:
	if preview_mode or bridge == null or _closing:
		return
	if event is InputEventMouseMotion and _modal == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		stage.look(event.relative)
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_RIGHT_X: _right_stick.x = event.axis_value if absf(event.axis_value) > .16 else 0
		if event.axis == JOY_AXIS_RIGHT_Y: _right_stick.y = event.axis_value if absf(event.axis_value) > .16 else 0
		if event.axis == JOY_AXIS_LEFT_X: _left_stick.x = event.axis_value if absf(event.axis_value) > .16 else 0
		if event.axis == JOY_AXIS_LEFT_Y: _left_stick.y = event.axis_value if absf(event.axis_value) > .16 else 0
		if _modal == null and event.axis == JOY_AXIS_TRIGGER_RIGHT:
			var down: bool = event.axis_value > .4
			if down != _trigger:
				_trigger=down; submit({"kind":"trigger","pressed":down})
		if _modal == null and event.axis == JOY_AXIS_TRIGGER_LEFT:
			var down: bool = event.axis_value > .4
			if down != _mouse_aim:
				_mouse_aim=down; submit({"kind":"aim","pressed":down})
	if event is InputEventMouseButton and _modal == null:
		if event.button_index == MOUSE_BUTTON_LEFT: submit({"kind":"trigger","pressed":event.pressed})
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_aim=event.pressed; submit({"kind":"aim","pressed":event.pressed})
	var key: int = event.physical_keycode if event is InputEventKey else 0
	var joy: int = event.button_index if event is InputEventJoypadButton else -1
	if not event.is_pressed() or (event is InputEventKey and event.echo):
		return
	if key == KEY_TAB or joy == JOY_BUTTON_RIGHT_SHOULDER:
		if _modal != null and state.pauses.has("wheel"): _close_wheel()
		elif _modal == null: _wheel()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE or joy == JOY_BUTTON_START or joy == JOY_BUTTON_B:
		if _modal != null:
			if state.pauses.has("wheel"): _close_wheel()
			elif state.pauses.has("menu"):
				_buttons.resume.pressed.emit()
		elif joy == JOY_BUTTON_B:
			if state.actors.player.cover: submit({"kind":"cover"})
			elif state.draw: submit({"kind":"holster"})
		else: _menu()
		get_viewport().set_input_as_handled()
	elif _modal == null:
		if key == KEY_SPACE or joy == JOY_BUTTON_A: submit({"kind":"cover"})
		elif key == KEY_Q or joy == JOY_BUTTON_LEFT_SHOULDER: submit({"kind":"swap"})
		elif key == KEY_R or joy == JOY_BUTTON_X: submit({"kind":"holster"})
		elif key == KEY_1: _power("mara","arc_overload")
		elif key == KEY_2: _power("ivo","kinetic_throw")
		elif key == KEY_3: _power("player","concussive_shot")
		elif key == KEY_4: _power("player","fortify")
