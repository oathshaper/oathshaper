extends RefCounted
## Rendered acceptance uses scripted input in an unfocusable, click-through window.
## This helper is excluded from exported game packs.
const MARKER := "oathshaper_acceptance_input"

static func install(window: Window) -> void:
	Input.use_accumulated_input = false
	window.unfocusable = true
	window.mouse_passthrough = true
	if DisplayServer.get_name() != "headless":
		# SceneTree._initialize runs before the native root window is registered.
		attach_window.call_deferred(window)

static func attach_window(window: Window) -> void:
	DisplayServer.window_set_input_event_callback(func(event: InputEvent) -> void:
		if event.get_meta(MARKER, false): window.push_input(event), window.get_window_id())

static func send(event: InputEvent) -> void:
	event.set_meta(MARKER, true)
	Input.parse_input_event(event)
