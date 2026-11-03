extends Node
## Shared last-device preference, gated by actual connection state.
static var last_device := ""
var _bindings: Array[Dictionary] = []
var _shown_controller := false

static func controller_active() -> bool:
	return not Input.get_connected_joypads().is_empty() and last_device != "keyboard"

static func observe(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > .35):
		if Input.get_connected_joypads().has(event.device): last_device = "controller"
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		last_device = "keyboard"

static func attach(parent: Node) -> Node:
	var helper := preload("res://scripts/input_hints.gd").new()
	helper.name = "InputHints"
	parent.add_child(helper)
	return helper

func bind(control: Control, keyboard: String, controller: String, property := "text") -> void:
	_bindings.append({"control": control, "keyboard": keyboard, "controller": controller, "property": property})
	control.set(property, controller if controller_active() else keyboard)

func _input(event: InputEvent) -> void:
	observe(event)

func _process(_delta: float) -> void:
	var active := controller_active()
	if active == _shown_controller: return
	_shown_controller = active
	for entry in _bindings:
		if is_instance_valid(entry.control):
			entry.control.set(entry.property, entry.controller if active else entry.keyboard)
