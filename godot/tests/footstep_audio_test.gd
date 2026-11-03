extends SceneTree
class Walker extends CharacterBody3D:
	var enabled := true
	func _physics_process(_delta: float) -> void:
		velocity.y = -1.0
		move_and_slide()

var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ground := StaticBody3D.new()
	world.add_child(ground)
	var floor_shape := CollisionShape3D.new()
	floor_shape.name = "CentralQuayCollision"
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(100, .2, 100)
	ground.add_child(floor_shape)
	var walker := Walker.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.shape.height = 1.0
	shape.shape.radius = .2
	walker.add_child(shape)
	walker.position.y = .65
	world.add_child(walker)
	var steps := preload("res://scripts/footstep_audio.gd").new()
	walker.add_child(steps)
	var mixer := preload("res://scripts/game_audio.gd").ensure(root)
	await create_timer(.3).timeout
	check(walker.is_on_floor(), "Test actor reaches solid floor")
	check(mixer.played == 0, "Standing still is silent")
	walker.velocity.x = 2.0
	await create_timer(.7).timeout
	check(mixer.played > 0 and mixer._last.has("step_wood"), "Actual walking on quay selects timber steps")
	walker.velocity.x = 0
	await create_timer(.1).timeout
	var before: int = mixer.played
	await create_timer(.4).timeout
	check(mixer.played == before, "Stopping cancels the step cadence")
	walker.position.x += 8.0
	await create_timer(.1).timeout
	check(mixer.played == before, "Teleport does not sound like a footstep")
	floor_shape.name = "CivicCourtCollision"
	walker.velocity.x = 2.0
	await create_timer(.7).timeout
	check(mixer._last.has("step_stone"), "Masonry selects the stone palette")
	walker.enabled = false
	before = mixer.played
	await create_timer(.5).timeout
	check(mixer.played == before, "Disabled exploration does not emit steps")
	world.queue_free()
	root.remove_meta("oathshaper_audio")
	mixer.queue_free()
	await process_frame
	print("FOOTSTEP_AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
