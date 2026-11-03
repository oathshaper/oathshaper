extends Node3D
## Owner-supplied textured adversaries. Presentation follows host simulation ticks;
## it never applies damage or invents a combat outcome.
const MODELS := {
	"lantern_sentinel": {"path": "res://assets/meshes/adversaries/lantern_sentinel_rigged.glb", "height": 2.05},
	"iron_sentinel": {"path": "res://assets/meshes/adversaries/iron_sentinel_rigged.glb", "height": 1.20},
	"crimson_corsair": {"path": "res://assets/meshes/adversaries/crimson_corsair_rigged.glb", "height": 1.92},
}
const LEGACY := {"hound": "lantern_sentinel", "sentinel": "iron_sentinel", "corsair_raider": "crimson_corsair"}
var kind := "lantern_sentinel"
var model_height := 2.05
var model: Node3D
var _last_tick := 0
var _attack_tick := -100
var _paused := true
var animation: AnimationPlayer
var _pose_time := 0.0
var _reaction := ""
var _reaction_time := 0.0
var _conscious := true

static func model_for(actor: Dictionary) -> String:
	var chosen := str(actor.get("appearance", {}).get("model", ""))
	return chosen if MODELS.has(chosen) else str(LEGACY.get(str(actor.id), "lantern_sentinel"))

func configure(model_id: String) -> void:
	kind = model_id if MODELS.has(model_id) else "lantern_sentinel"
	if is_instance_valid(model):
		model.free()
	model = load(MODELS[kind].path).instantiate() as Node3D
	model.name = "ImportedAdversary"
	add_child(model)
	var bounds := imported_bounds()
	model_height = float(MODELS[kind].height)
	var factor := model_height / bounds.size.y
	model.scale = Vector3.ONE * factor
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	# All three supplied Meshy subjects face +Z. Stage actors face -Z.
	rotation.y = PI
	set_meta("source_model", kind)
	set_meta("has_supplied_rig", false)
	set_meta("has_authored_rig", true)
	animation = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_sample("Idle", 0.0)

func imported_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = model.global_transform.affine_inverse() * part.global_transform * part.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds

func _sample(clip: String, seconds: float) -> void:
	if animation.current_animation != clip:
		animation.play(clip)
	animation.seek(seconds, true)

func set_conscious(conscious: bool) -> void:
	_conscious = conscious

func set_motion(velocity: Vector3, tick: int, paused: bool) -> void:
	_paused = paused
	if paused or not _conscious or animation == null:
		return
	if tick < _last_tick:
		_attack_tick = -100
		_reaction = ""
		_pose_time = 0.0
	_last_tick = tick
	var delta := minf(get_process_delta_time(), .05)
	if not _reaction.is_empty():
		_reaction_time += delta
		var length := animation.get_animation(_reaction).length
		_sample(_reaction, minf(_reaction_time, length))
		if _reaction_time >= length:
			_reaction = ""
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var clip := "Walk" if speed > .10 else "Idle"
	_pose_time += delta * clampf(speed / 1.7, .5, 2.5) if clip == "Walk" else delta
	_sample(clip, fposmod(_pose_time, animation.get_animation(clip).length))

func show_attack() -> void:
	_attack_tick = _last_tick
	_reaction = "Strike"
	_reaction_time = 0.0

func show_hit() -> void:
	_reaction = "Hit"
	_reaction_time = 0.0
