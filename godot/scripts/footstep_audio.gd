extends Node
## Travel-based contacts: never tick while blocked, airborne or teleported.
const AUDIO := preload("res://scripts/game_audio.gd")
var _previous := Vector3.ZERO
var _distance := 0.0
var _actor: CharacterBody3D
var _audio: Node

func _ready() -> void:
	_actor = get_parent() as CharacterBody3D
	_previous = _actor.global_position
	_audio = AUDIO.ensure(self)

func _physics_process(_delta: float) -> void:
	var moved := Vector2(_actor.global_position.x - _previous.x, _actor.global_position.z - _previous.z).length()
	_previous = _actor.global_position
	if not _actor.enabled or not _actor.is_on_floor() or moved > 1.0 or moved < .001:
		_distance = 0.0
		return
	_distance += moved
	# Step spacing follows the measured walk/run strides, without changing gait.
	var spacing := .569 if Vector2(_actor.velocity.x, _actor.velocity.z).length() < 2.8 else 1.6
	if _distance < spacing: return
	_distance = fmod(_distance, spacing)
	var query := PhysicsRayQueryParameters3D.create(_actor.global_position + Vector3.UP * .2, _actor.global_position + Vector3.DOWN * .7)
	query.exclude = [_actor.get_rid()]
	var hit := _actor.get_world_3d().direct_space_state.intersect_ray(query)
	var surface := "stone"
	if not hit.is_empty() and hit.collider is CollisionObject3D:
		var body: CollisionObject3D = hit.collider
		var owner: Node = body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
		var title := str(owner.name)
		if title.contains("Quay") or title.contains("Bridge") or title.contains("CourtSteps") or title.contains("Alley") or title.contains("Turn") or title.contains("Walk"):
			surface = "wood"
	_audio.cue("step_" + surface)
