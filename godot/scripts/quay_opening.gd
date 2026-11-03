extends Node3D
## Three short in-engine shots. New journeys only; skipping has no story effects.
signal finished
const UI := preload("res://scripts/combat_theme.gd")
const VOICES := preload("res://scripts/voice_library.gd")
var _camera: Camera3D
var _previous_camera: Camera3D
var _audio: AudioStreamPlayer
var _caption: Label
var _speaker: Label
var _lines: Array = []
var _index := -1
var _remaining := 0.0
var _done := false
var _pan := Vector3.ZERO
var _look := Vector3.ZERO
var section := "opening"

func _ready() -> void:
	_previous_camera = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 55
	add_child(_camera)
	_camera.make_current()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	preload("res://scripts/game_audio.gd").route_voice(_audio)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -160
	panel.add_theme_stylebox_override("panel", UI.style(Color("091114"), Color("8b7c57")))
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_speaker = UI.label("", 20, UI.BRASS, true)
	column.add_child(_speaker)
	_caption = UI.label("", 23)
	_caption.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_caption)
	var hint := UI.label("", 16, UI.MUTED)
	column.add_child(hint)
	preload("res://scripts/input_hints.gd").attach(self).bind(hint, "Enter · Continue     Esc · Skip", "Ⓐ Continue     Ⓑ Skip")
	var skip := UI.button("Skip", finish)
	skip.position = Vector2(24, 24)
	layer.add_child(skip)
	_lines = JSON.parse_string(FileAccess.get_file_as_string("res://content/garden_chapter.json")).get(section, [])
	_next()

func _next() -> void:
	if _done: return
	_index += 1
	if _index >= _lines.size():
		finish()
		return
	var line: Dictionary = _lines[_index]
	_speaker.text = line.speaker
	_caption.text = line.text
	_audio.stop()
	_audio.stream = VOICES.clip(line.speaker, line.text)
	_remaining = maxf(6.0, str(line.text).split(" ").size() / 2.7)
	if _audio.stream != null:
		_remaining = maxf(_remaining, _audio.stream.get_length() + .6)
		_audio.play()
	match str(line.shot):
		"mara":
			_camera.position = Vector3(-4.8, 3.0, 4.0)
			_look = Vector3(0, 1.8, -.5)
			_pan = Vector3(.06, 0, -.03)
		"gate":
			_camera.position = preload("res://scripts/garden_layout.gd").point(Vector3(37, 2.0, -2))
			_look = preload("res://scripts/garden_layout.gd").point(Vector3(44, 1.15, -2))
			_pan = Vector3(.12, 0, 0)
		"tower":
			_camera.position = Vector3(13, 7, -9)
			_look = Vector3(0, 7.0, -23)
			_pan = Vector3(-.07, 0, -.08)
		"office":
			_camera.position = Vector3(-1.5, 3.0, -18)
			_look = Vector3(-9.5, 1.8, -26)
			_pan = Vector3(-.08, 0, -.04)
		"quay":
			_camera.position = Vector3(12, 8, 13)
			_look = Vector3(0, 2, -12)
			_pan = Vector3(-.08, .015, -.02)
	_camera.look_at(_look)

func _process(delta: float) -> void:
	if _done: return
	_camera.position += _pan * delta
	_camera.look_at(_look)
	_remaining -= delta
	if _remaining <= 0: _next()

func _input(event: InputEvent) -> void:
	if _done or event.is_echo(): return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			finish()
		elif event.keycode == KEY_ENTER:
			_next()
		else: return
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			finish()
		elif event.button_index == JOY_BUTTON_A:
			_next()
		else: return
	else: return
	get_viewport().set_input_as_handled()

func finish() -> void:
	if _done: return
	_done = true
	_audio.stop()
	if is_instance_valid(_previous_camera): _previous_camera.make_current()
	finished.emit()
	queue_free()
