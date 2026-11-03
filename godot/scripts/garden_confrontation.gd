extends Node3D
## Both the quay and the menu's chapter entry use this automatic scene.
## Staging never commits narrative choices, moves the party, or awards a result.
signal finished
class SkipInput:
	extends Node
	var scene: Node3D
	func _input(event: InputEvent) -> void:
		if is_instance_valid(scene): scene._input(event)
const UI := preload("res://scripts/combat_theme.gd")
const VOICES := preload("res://scripts/voice_library.gd")
const CHAPTER := preload("res://scripts/garden_chapter.gd")
var demo: Node3D
var stage: Node3D
var host: Control
var resolution := false
var surrender := false
var _decision: Callable
var _awaiting_choice := false
var _choice_row: HBoxContainer
var _skip: Button
var _hint: Label
var _bottom: PanelContainer
var _temporary_actors: Array[String] = []
var _hidden: Array[Dictionary] = []
var _weapons: Array[Dictionary] = []
var _subtitle_layer: CanvasLayer
var _camera: Camera3D
var _audio: AudioStreamPlayer
var _caption: Label
var _speaker: Label
var _lines: Array[Dictionary] = []
var _actors: Array[Node3D] = []
var _saved_actors: Array[Dictionary] = []
var _previous: Dictionary = {}
var _index := -1
var _remaining := 1.4
var _done := false
var _look := Vector3.ZERO
var _push := Vector3.ZERO

static func play_trial(trial: Control, begin: Callable) -> Node3D:
	var scene := load("res://scripts/garden_confrontation.gd").new() as Node3D
	scene.stage = trial.stage
	scene.host = trial
	# Resume on the next event cycle so Skip cannot become a combat command.
	scene.finished.connect(begin.call_deferred)
	trial.stage.add_child(scene)
	return scene

static func play_surrender(trial: Control, decide: Callable) -> Node3D:
	var scene := load("res://scripts/garden_confrontation.gd").new() as Node3D
	scene.stage = trial.stage
	scene.host = trial
	scene.surrender = true
	scene._decision = decide
	trial.stage.add_child(scene)
	return scene

func _ready() -> void:
	name = "GardenSurrender" if surrender else ("GardenResolution" if resolution else "GardenConfrontation")
	if host != null:
		_take_stage()
	else:
		_take_quay()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cast := _actors.duplicate()
	if _companion() not in cast: cast.append(_companion())
	for actor in cast:
		var slot: Node = actor.get_node_or_null("ModelSlot")
		var label: Label3D = actor.get_node_or_null("Name")
		_saved_actors.append({"actor": actor, "transform": actor.transform, "slot": slot,
			"velocity": actor.velocity if actor is CharacterBody3D else Vector3.ZERO,
			"speed": slot.locomotion_speed if slot != null else 0.0,
			"slot_process": slot.process_mode if slot != null else Node.PROCESS_MODE_INHERIT,
			"label": label, "label_visible": label.visible if label != null else false})
		if label != null: label.hide()
		# Rigged actors read their body's velocity, not locomotion_speed. The
		# cinematic owns a stationary pose even if it interrupts movement.
		if actor is CharacterBody3D: actor.velocity = Vector3.ZERO
		if slot != null:
			slot.locomotion_speed = 0.0
			slot.set_talking(false)
			if host != null: slot.process_mode = Node.PROCESS_MODE_ALWAYS
		if host != null:
			for name in ["Weapon", "Firearm"]:
				var weapon: Node = actor.get_node_or_null(name)
				if weapon != null:
					_weapons.append({"node": weapon, "readied": weapon._readied})
					weapon.set_readied(false)
		var facing: Vector3 = (_actors[1] if actor == _actors[2] else _actors[2]).global_position - actor.global_position
		# Stage models all face local -Z; the quay's NPC slots face local +Z.
		var reverse: bool = host != null or (actor == demo.player if resolution else actor in [_actors[1], _actors[2]])
		actor.rotation.y = atan2(facing.x, facing.z) + (PI if reverse else 0.0)
	_camera = Camera3D.new()
	_camera.fov = 48
	_camera.near = .08
	add_child(_camera)
	_camera.make_current()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	preload("res://scripts/game_audio.gd").route_voice(_audio)
	_build_subtitles()
	_lines = CHAPTER.dialogue_lines("surrender" if surrender else ("resolution" if resolution else "briefing"))
	_camera.global_position = _actors[1].global_position + Vector3(-3.5, 3.0, 3.0)
	if host != null: _camera.position = Vector3(-6, 3.5, .9)
	_look = _actors[1].global_position.lerp(_actors[2].global_position, .48) + Vector3.UP * .8
	_push = Vector3(.12, 0, 0)
	_camera.look_at(_look)

func _companion() -> Node3D:
	return stage.actors.mara if host != null else demo.get_node("Mara")

func _take_quay() -> void:
	_previous = {"camera": get_viewport().get_camera_3d(), "mode": demo.mode,
		"enabled": demo.player.enabled, "rig_process": demo.camera_rig.process_mode,
		"hud_visible": demo.get_node("CanvasLayer").visible, "mouse": Input.mouse_mode}
	demo.mode = "opening"
	demo.player.enabled = false
	demo.player.velocity = Vector3.ZERO
	demo.camera_rig.process_mode = Node.PROCESS_MODE_DISABLED
	demo.get_node("CanvasLayer").hide()
	_actors = [demo.get_node("Ivo"), demo.player, demo.get_node("GardenWatch/corsair_raider")]
	if resolution: _actors = [demo.get_node("Ivo"), demo.get_node("Mara"), demo.player]

func _hide_for_scene(node: Node) -> void:
	if node == null: return
	_hidden.append({"node": node, "visible": node.visible})
	node.hide()

func _take_stage() -> void:
	_previous = {"camera": get_viewport().get_camera_3d(), "mouse": Input.mouse_mode,
		"host_process": host.process_mode, "poses": {}}
	host.process_mode = Node.PROCESS_MODE_DISABLED
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_for_scene(host._layer)
	_hide_for_scene(stage.markers)
	_hide_for_scene(stage.get_node_or_null("ShotTracer"))
	_hide_for_scene(stage._effects)
	# A chapter preview can have a different roster. Stage the story actors
	# without changing its party, inventory, combat clock, or save data.
	var positions := {"player": Vector3(-2.4, 0, .5), "ivo": Vector3(-2.8, 0, -.9),
		"mara": Vector3(-4, 0, 1.5), "corsair_raider": Vector3(3.2, 0, 0),
		"hound": Vector3(4.5, 0, -2), "sentinel": Vector3(4.5, 0, 2)}
	for id in stage.actors:
		var actor: Node3D = stage.actors[id]
		_previous.poses[id] = {"transform": actor.transform, "visible": actor.visible}
		if not positions.has(id): _hide_for_scene(actor)
	for id in positions:
		if not stage.actors.has(id):
			stage._create_actor({"id": id, "faction": "party" if id in ["player", "mara", "ivo"] else "hostile",
				"appearance": {"main_hand": "unarmed", "offhand": "none"}})
			_temporary_actors.append(id)
		var actor: Node3D = stage.actors[id]
		actor.position = positions[id]
		actor.show()
		_hide_for_scene(actor.get_node_or_null("SelectionRing"))
		_hide_for_scene(actor.get_node_or_null("Nameplate"))
	_actors = [stage.actors.ivo, stage.actors.player, stage.actors.corsair_raider]
	if surrender:
		_actors = [stage.actors.corsair_raider, stage.actors.player, stage.actors.ivo]
		for id in ["hound", "sentinel"]: _hide_for_scene(stage.actors[id])

func _build_subtitles() -> void:
	var layer := CanvasLayer.new()
	_subtitle_layer = layer
	# Main's menu and its embedded chapter live on layer 30.
	layer.layer = 40 if host != null else 25
	if host != null:
		# A disabled SubViewportContainer cannot forward root input. Keep the
		# cinematic controls in the root viewport while gameplay stays frozen.
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		host.add_child(layer)
		var input := SkipInput.new()
		input.scene = self
		layer.add_child(input)
	else:
		add_child(layer)
	var top := ColorRect.new()
	top.color = Color("080c0e")
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 54
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(top)
	var bottom := PanelContainer.new()
	_bottom = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -160
	bottom.add_theme_stylebox_override("panel", UI.style(Color("091114"), Color("8b7c57")))
	layer.add_child(bottom)
	var column := VBoxContainer.new()
	bottom.add_child(column)
	_speaker = UI.label("", 20, UI.BRASS, true)
	column.add_child(_speaker)
	_caption = UI.label("", 23)
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_caption)
	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 20)
	column.add_child(_choice_row)
	var hint := UI.label("", 16, UI.MUTED)
	_hint = hint
	column.add_child(hint)
	var hints := preload("res://scripts/input_hints.gd").attach(layer)
	hints.bind(hint, "Esc · Skip", "Ⓑ Skip")
	var skip := UI.button("Skip", finish)
	_skip = skip
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.offset_left = -160
	skip.offset_right = -16
	skip.offset_top = 8
	skip.offset_bottom = 46
	layer.add_child(skip)
	hints.bind(skip, "Esc · Skip", "Ⓑ Skip")

func _next() -> void:
	if _done: return
	_set_talking(false)
	_audio.stop()
	_index += 1
	if _index >= _lines.size():
		finish()
		return
	var line := _lines[_index]
	_speaker.text = line.speaker
	_caption.text = line.text
	_audio.stream = VOICES.clip(line.speaker, line.text)
	_remaining = maxf(3.0, str(line.text).split(" ").size() / 2.7 + .6)
	if _audio.stream != null:
		_remaining = _audio.stream.get_length() + .65
		_audio.play()
	_shot(_index)
	_set_talking(true)

func _shot(index: int) -> void:
	var actor := _actors[index]
	var other := _actors[1] if index == 2 else _actors[2]
	var toward := (other.global_position - actor.global_position).normalized()
	toward.y = 0
	toward = toward.normalized()
	var side := toward.cross(Vector3.UP)
	# Party roots are capsule centres; the adversary root is at its soles.
	_look = actor.global_position + Vector3.UP * (1.38 if host != null or (index == 2 and not resolution) else .55)
	var distance := 2.7 if host != null and index < 2 else 3.4
	var offset := (.3 if index == 0 else -.4) if host != null and index < 2 else 1.25
	_camera.global_position = _look + toward * distance + side * offset + Vector3.UP * .25
	_camera.fov = 43
	_camera.look_at(_look)
	_push = -toward * .035

func _set_talking(active: bool) -> void:
	if _index < 0 or _index >= _actors.size(): return
	var slot := _actors[_index].get_node_or_null("ModelSlot")
	if slot != null: slot.set_talking(active)

func _process(delta: float) -> void:
	if _done or _awaiting_choice: return
	_camera.global_position += _push * delta
	_camera.look_at(_look)
	_remaining -= delta
	if _remaining <= 0: _next()

func _input(event: InputEvent) -> void:
	if _done or event.is_echo(): return
	var skip: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE
	skip = skip or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if skip:
		get_viewport().set_input_as_handled()
		get_tree().root.set_input_as_handled()
		finish()

func _restore() -> void:
	_set_talking(false)
	_audio.stop()
	for saved in _saved_actors:
		if not is_instance_valid(saved.actor): continue
		saved.actor.transform = saved.transform
		if saved.actor is CharacterBody3D: saved.actor.velocity = saved.velocity
		if is_instance_valid(saved.slot):
			saved.slot.locomotion_speed = saved.speed
			saved.slot.process_mode = saved.slot_process
		if is_instance_valid(saved.label): saved.label.visible = saved.label_visible
	if is_instance_valid(_previous.camera): _previous.camera.make_current()
	Input.mouse_mode = _previous.mouse
	if host != null:
		for saved in _weapons:
			if is_instance_valid(saved.node): saved.node.set_readied(saved.readied)
		for saved in _hidden:
			if is_instance_valid(saved.node): saved.node.visible = saved.visible
		for id in _previous.poses:
			stage.actors[id].transform = _previous.poses[id].transform
			stage.actors[id].visible = _previous.poses[id].visible
		for id in _temporary_actors:
			stage.actors[id].free()
			stage.actors.erase(id)
		host.set_deferred("process_mode", _previous.host_process)
		return
	demo.mode = _previous.mode
	demo.player.enabled = _previous.enabled
	demo.camera_rig.process_mode = _previous.rig_process
	demo.get_node("CanvasLayer").visible = _previous.hud_visible
	demo.sync_combat_input()

func _present_choices() -> void:
	if _done or _awaiting_choice: return
	_awaiting_choice = true
	_set_talking(false)
	_audio.stop()
	if _index < 0:
		_index = 0
		_speaker.text = _lines[0].speaker
		_caption.text = _lines[0].text
		_shot(0)
	_skip.hide()
	_hint.hide()
	_bottom.offset_top = -230
	for accept in [true, false]:
		var button := UI.button("Accept surrender" if accept else "Continue fighting", _choose_surrender.bind(accept))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 48
		_choice_row.add_child(button)
	(_choice_row.get_child(0) as Button).grab_focus()

func _choose_surrender(accept: bool) -> void:
	if _done or not _awaiting_choice: return
	# Restore the host first; submit exactly one decision on the next event cycle.
	_end_scene()
	_decision.call_deferred(accept)

func finish() -> void:
	if _done: return
	if surrender:
		_present_choices()
		return
	_end_scene()

func _end_scene() -> void:
	if _done: return
	_done = true
	_restore()
	finished.emit()
	queue_free()

func _exit_tree() -> void:
	# The stage variant owns a sibling overlay so it can receive root input.
	if host != null and is_instance_valid(_subtitle_layer):
		_subtitle_layer.queue_free()
