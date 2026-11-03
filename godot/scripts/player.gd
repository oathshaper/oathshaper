extends CharacterBody3D
@export var speed := 4.5
@export var gravity := 20.0
@export var floor_snap_distance := 0.45
@export var turn_speed := 24.0
@export_range(0.1, 1.0, 0.05) var keyboard_lateral_speed_ratio := 0.7
@export_range(30.0, 720.0, 10.0) var keyboard_turn_degrees_per_second := 180.0
@export_range(0.01, 0.5, 0.01) var keyboard_lateral_ramp_seconds := 0.15
@onready var camera: Camera3D = get_node("../CameraRig/Camera3D")
var enabled := true
var _move_right := Vector3.RIGHT
var _move_forward := Vector3.FORWARD
var _move_basis_latched := false
var _move_source := ""
var _preferred_source := ""
var _keyboard_change_pending := false
var _stick_axes := Vector2.ZERO
var _stick_device := -1
var _keyboard_lateral_gain := 0.0
var backpedaling := false

const STICK_DEADZONE := 0.2


func _ready() -> void:
	floor_snap_length = floor_snap_distance
	add_child(preload("res://scripts/footstep_audio.gd").new())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.physical_keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_preferred_source = "keyboard"
		_keyboard_change_pending = true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if _stick_device != event.device:
			_stick_axes = Vector2.ZERO
			_stick_device = event.device
		if event.axis == JOY_AXIS_LEFT_X:
			_stick_axes.x = event.axis_value
		else:
			_stick_axes.y = event.axis_value
		if absf(event.axis_value) > STICK_DEADZONE:
			_preferred_source = "controller"


func reset_movement_basis() -> void:
	_move_basis_latched = false
	_move_source = ""
	_keyboard_lateral_gain = 0.0
	backpedaling = false


func _movement_input() -> Vector2:
	var keyboard := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	if keyboard.length_squared() > 1.0:
		keyboard = keyboard.normalized()
	var stick := Vector2.ZERO
	var length := _stick_axes.length()
	if length > STICK_DEADZONE:
		stick = _stick_axes / length * clampf((length - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
	var source := ""
	if _preferred_source == "keyboard" and not keyboard.is_zero_approx():
		source = "keyboard"
	elif _preferred_source == "controller" and not stick.is_zero_approx():
		source = "controller"
	elif not keyboard.is_zero_approx():
		source = "keyboard"
	elif not stick.is_zero_approx():
		source = "controller"
	if source != _move_source or (source == "keyboard" and _keyboard_change_pending):
		_move_basis_latched = false
	_move_source = source
	_keyboard_change_pending = false
	return keyboard if source == "keyboard" else stick if source == "controller" else Vector2.ZERO


func _physics_process(delta: float) -> void:
	# The supplied garden bridge climbs onto a raised stone terrace. Keep
	# vertical floor contact independent of the chase camera and input basis.
	var vertical_velocity := minf(velocity.y, 0.0) - gravity * delta if not is_on_floor() else 0.0
	if not enabled:
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		reset_movement_basis()
		move_and_slide()
		return
	var input := _movement_input()
	if input.length_squared() < 0.0025:
		reset_movement_basis()
		velocity = Vector3(0.0, vertical_velocity, 0.0)
		move_and_slide()
		return
	# The view may turn behind the actor while a key or stick direction is held.
	# Keep a continuous stick gesture in one world-space basis. Keyboard edges
	# deliberately sample the current view; they are distinct button decisions.
	if not _move_basis_latched:
		_move_forward = -camera.global_transform.basis.z
		_move_forward.y = 0.0
		_move_forward = _move_forward.normalized()
		_move_right = camera.global_transform.basis.x
		_move_right.y = 0.0
		_move_right = _move_right.normalized()
		_move_basis_latched = true
	# Keyboard side presses still turn toward travel, but a brief tap should
	# produce a measured sidestep instead of a full-speed, 90-degree snap.
	# The left stick keeps its direct analog steering response.
	var keyboard_lateral := _move_source == "keyboard" and absf(input.x) > 0.01
	_keyboard_lateral_gain = move_toward(_keyboard_lateral_gain, 1.0 if keyboard_lateral else 0.0, delta / keyboard_lateral_ramp_seconds)
	var lateral_input := input.x * keyboard_lateral_speed_ratio * _keyboard_lateral_gain if keyboard_lateral else input.x
	var direction: Vector3 = _move_right * lateral_input - _move_forward * input.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	# Reverse uses the captured view direction for travel but keeps the actor
	# facing forward. Turning toward reverse travel would make the chase camera
	# swing around and turn a held S into apparent forward movement.
	backpedaling = input.y > 0.01
	velocity = direction * speed
	velocity.y = vertical_velocity
	move_and_slide()
	if direction.length_squared() > 0.0025 and not backpedaling:
		var heading := atan2(-direction.x, -direction.z)
		if keyboard_lateral:
			rotation.y = rotate_toward(rotation.y, heading, deg_to_rad(keyboard_turn_degrees_per_second) * delta)
		else:
			rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-turn_speed * delta))
