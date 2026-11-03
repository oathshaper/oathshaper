extends Control
signal requested(action: Dictionary)
const UI := preload("res://scripts/combat_theme.gd")
const NAMES := {"stone":"Stone palm", "gale":"Gale hand", "harbor":"Harbor blade", "still":"Still water"}
var state: Dictionary = {}
var _gauges: Dictionary = {}
var _resource_labels: Dictionary = {}
var _target: Label
var _follower: Label
var _log: Label
var _message: Label
var _mode: Label
var _style_description: Label
var _action_status: Label
var _pause_button: Button
var _device_controller := false
var _message_until := 0
const HINTS := preload("res://scripts/input_hints.gd")
const STYLE_HELP := {"stone":"Martial · Free strikes; power breaks guard", "gale":"Magic · Ranged attacks spend Chi", "harbor":"Weapon · Free swings; power spends Focus", "still":"Support · Set up a martial power strike"}
var _diamond: Array[Button] = []
var _verbs: Array[Button] = []
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := PanelContainer.new()
	left.position = Vector2(16, 16)
	left.custom_minimum_size = Vector2(324, 0)
	left.add_theme_stylebox_override("panel", UI.style(Color("15252be8"), UI.BRASS))
	add_child(left)
	var hints := preload("res://scripts/input_hints.gd").attach(self)
	var col := VBoxContainer.new()
	left.add_child(col)
	col.add_child(UI.label("Tessa Ward", 22, UI.INK, true))
	for resource in ["health", "chi", "focus"]:
		var caption := UI.label("", 18)
		col.add_child(caption)
		_resource_labels[resource] = caption
		var gauge := ProgressBar.new()
		gauge.show_percentage = false
		gauge.custom_minimum_size.y = 7
		gauge.add_theme_stylebox_override("background", UI.style(Color("080f11"), Color.TRANSPARENT))
		gauge.add_theme_stylebox_override("fill", UI.style({"health":Color("cf7770"),"chi":Color("81b9d8"),"focus":Color("d9bd79")}[resource], Color.TRANSPARENT))
		col.add_child(gauge)
		_gauges[resource] = gauge
	var diamond := Control.new()
	diamond.custom_minimum_size = Vector2(288, 180)
	col.add_child(diamond)
	for i in range(4):
		var index := i
		var b := UI.button("", func() -> void:
			if not state.is_empty(): requested.emit({"kind":"style", "style":state.hero.diamond[index]}))
		b.position = [Vector2(74,0), Vector2(148,62), Vector2(74,124), Vector2(0,62)][i]
		b.custom_minimum_size = Vector2(140,56)
		b.size = Vector2(140,56)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 16)
		for mode in ["normal", "hover", "focus", "pressed"]:
			var box := UI.style(UI.PANEL if mode != "focus" else Color.TRANSPARENT, UI.BRASS if mode != "normal" else Color("415054"))
			box.content_margin_left = 6
			box.content_margin_right = 6
			box.content_margin_top = 4
			box.content_margin_bottom = 4
			b.add_theme_stylebox_override(mode, box)
		diamond.add_child(b)
		_diamond.append(b)
	_style_description = UI.label("",16,UI.MUTED)
	col.add_child(_style_description)
	_mode = UI.label("",18,UI.BRASS)
	col.add_child(_mode)
	_follower = UI.label("",16)
	col.add_child(_follower)
	var follower_button := UI.button("Mara: switch Support / Attack", func() -> void:
		if not state.is_empty(): requested.emit({"kind":"follower", "mode":"attack" if state.follower.mode == "support" else "support"}))
	follower_button.custom_minimum_size.y = 40
	follower_button.add_theme_font_size_override("font_size",16)
	col.add_child(follower_button)
	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -325
	right.offset_right = -20
	right.offset_top = 20
	right.add_theme_stylebox_override("panel", UI.style(Color("15252be8"), UI.BRASS))
	add_child(right)
	var rc := VBoxContainer.new()
	right.add_child(rc)
	_target = UI.label("",20,UI.INK,true)
	rc.add_child(_target)
	var target_button := UI.button("Next target", func() -> void: requested.emit({"kind":"ui.target"}))
	rc.add_child(target_button)
	hints.bind(target_button, "Next target · Tab / wheel", "Next target · R3")
	_pause_button = UI.button("",func() -> void: requested.emit({"kind":"ui.pause"}))
	rc.add_child(_pause_button)
	var menu_button := UI.button("",func() -> void: requested.emit({"kind":"ui.menu"}))
	hints.bind(menu_button,"Ledger · I / Esc","Ledger · L3")
	rc.add_child(menu_button)
	_log = UI.label("",16,UI.MUTED)
	rc.add_child(_log)
	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -185
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_bottom = -15
	bottom.add_theme_stylebox_override("panel", UI.style(Color("15252be8"), UI.BRASS))
	add_child(bottom)
	var bc := VBoxContainer.new()
	bottom.add_child(bc)
	_message = UI.label("",18)
	hints.bind(_message, "WASD Move    Shift Guard    Space Dodge", "Left stick Move    LT Guard    B Dodge")
	bc.add_child(_message)
	_action_status = UI.label("",18,UI.BRASS)
	bc.add_child(_action_status)
	var row := HBoxContainer.new()
	bc.add_child(row)
	for id in ["normal","power","area"]:
		var verb: String = id
		var button := UI.button(id,func() -> void: requested.emit({"kind":"attack","verb":verb}))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",18)
		row.add_child(button)
		_verbs.append(button)
	for entry in [["Heal · Q", "ui.heal", "Heal · LB"], ["Slow time · F", "ui.focus", "Slow time · RB"]]:
		var kind: String = entry[1]
		var button := UI.button(entry[0], func() -> void: requested.emit({"kind":kind}))
		row.add_child(button)
		button.add_theme_font_size_override("font_size",18)
		hints.bind(button, entry[0], entry[2])
	var hint := UI.label("",18,UI.MUTED)
	bc.add_child(hint)
	hints.bind(hint, "1–4 Styles    E Chi enhancement    V Library    MMB Camera", "D-pad Styles    A Chi enhancement    View Library    Right stick Camera")
func actor(id: String) -> Dictionary:
	for a in state.get("actors",[]):
		if a.id == id: return a
	return {}
func _process(_delta: float) -> void:
	if _device_controller != HINTS.controller_active() and not state.is_empty(): apply_view(state)
	if _message_until > 0 and Time.get_ticks_msec() >= _message_until:
		_message_until = 0
		_message.text = "Left stick Move    LT Guard    B Dodge" if HINTS.controller_active() else "WASD Move    Shift Guard    Space Dodge"
func apply_view(value: Dictionary) -> void:
	state = value
	if _gauges.is_empty(): return
	_device_controller = HINTS.controller_active()
	var hero := actor("player")
	for resource in _gauges:
		_gauges[resource].max_value = hero[resource].maximum
		_gauges[resource].value = hero[resource].current
		_resource_labels[resource].text = "%s  %d / %d" % [resource.capitalize(),hero[resource].current,hero[resource].maximum]
	_resource_labels.focus.tooltip_text = "Recovers 4 Focus per second after 2 seconds without spending it. Recovery stops during slow time or pause."
	for i in range(4):
		var id: String = state.hero.diamond[i]
		_diamond[i].text = "%s%s\n%s" % [["↑","→","↓","←"][i],"" if _device_controller else "  " + str(i+1),NAMES[id]]
		var box := _diamond[i].get_theme_stylebox("normal") as StyleBoxFlat
		box.bg_color = Color("3d3829") if state.hero.style == id else UI.PANEL
		box.border_color = UI.BRASS if state.hero.style == id else Color("415054")
	_style_description.text = STYLE_HELP[state.hero.style]
	_mode.text = ("PAUSED  " if state.clock.paused else "") + ("Focus slow  " if state.hero.focus_mode else "") + ("Chi enhanced" if state.hero.chi_enhancement else "")
	_mode.visible = not _mode.text.is_empty()
	var follower := actor("mara")
	var ivo := actor("ivo")
	_follower.text = "Mara · %s · %d / %d HP\nIvo · Defend · %d / %d HP" % [state.follower.mode.capitalize(),follower.health.current,follower.health.maximum,ivo.health.current,ivo.health.maximum]
	var ready: bool = state.clock.pause_reasons.has("ready")
	_pause_button.text = ("Begin" if ready else "Resume" if state.clock.paused else "Pause") + (" · Menu" if _device_controller else " · Enter / P" if ready else " · P")
	var target := actor(str(state.hero.target_id))
	if not target.is_empty():
		_target.text = "%s\n%d / %d Health" % [target.name,target.health.current,target.health.maximum]
		var targeting: Dictionary = state.get("targeting",{})
		if targeting.get("distance") != null:
			_target.text += "\n%.1f m%s" % [float(targeting.distance)," · Obstructed" if not targeting.get("line_of_sight",false) else ""]
		for condition in target.conditions:
			if condition.label != "": _target.text += "\n" + str(condition.label)
		if target.active_action != null:
			_target.text += "\nHeavy strike · dodge!" if target.active_action.power and target.active_action.state == "windup" else "\n" + str(target.active_action.state).capitalize()
	else: _target.text = "No target"
	var lines := PackedStringArray()
	for line in state.logs.slice(maxi(0,state.logs.size()-3)): lines.append(str(line))
	_log.text = "\n".join(lines)
	for i in range(3):
		var verb: Dictionary = state.verbs[i]
		_verbs[i].disabled = not verb.available
		_verbs[i].tooltip_text = str(verb.get("reason",""))
		var names: Array = ["Strike", "Power", "Sweep"]
		if state.hero.style == "gale": names = ["Gust", "Power", "Gale burst"]
		elif state.hero.style == "still": names = ["Slow", "Set up", "Sweep"]
		var key: String = ["RT", "Y", "X"][i] if _device_controller else ["LMB", "RMB", "R"][i]
		_verbs[i].text = names[i] + " · " + key + ("\n%s · %.1f m" % ["Free" if verb.get("cost",0)==0 else "%d %s" % [verb.cost,verb.resource.capitalize()],verb.get("range",0)] if verb.get("supported",verb.available) else "\nNot in this style")
	_action_status.text = "Choose a style, then Begin. Mara heals; Ivo holds the front." if ready else "Paused · Choose a style or open the Ledger" if state.clock.paused else "Ready"
	if not state.clock.paused:
		if hero.active_action != null: _action_status.text = "Striking…" if hero.active_action.state == "windup" else "Recovering…"
		elif not state.verbs[0].available: _action_status.text = str(state.verbs[0].get("reason","Ready"))
func show_message(message: String) -> void:
	if _message != null:
		_message.text = message
		_message_until = Time.get_ticks_msec() + 3000
