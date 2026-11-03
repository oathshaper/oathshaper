extends Node
## Read-only feedback for committed combat events; repainting never repeats audio.
var muted := false
var _seen: Dictionary = {}
var _generation := ""
var _paused := true
var _mixer: Node
var played := 0
var _health: Dictionary = {}
var _shots := 0
var _tick := -1

func _ready() -> void:
	_mixer = preload("res://scripts/game_audio.gd").ensure(self)

func cue(kind: String) -> void:
	if not muted and is_instance_valid(_mixer) and _mixer.cue(kind): played += 1

func _apply_action_view(view: Dictionary) -> void:
	# Flow and Vanguard expose pools/counters, not Command's typed event log.
	# Compare committed state; never infer effects from localized prose.
	var generation := str(view.get("generation", view.get("session", {}).get("generation", "")))
	var tick := int(view.get("tick", view.get("session", {}).get("tick", 0)))
	var fresh := generation != _generation or tick < _tick or _tick < 0
	var paused: bool = view.get("clock", {}).get("paused", not view.get("pauses", []).is_empty())
	if not fresh and paused != _paused: cue("pause")
	_paused = paused
	var next: Dictionary = {}
	var actors: Variant = view.get("actors", [])
	var entries: Array = actors.values() if actors is Dictionary else actors
	for actor in entries:
		var id := str(actor.id)
		var hp := int(actor.get("hp", actor.get("health", {}).get("current", 0)))
		next[id] = hp
		if not fresh and _health.has(id):
			if hp > int(_health[id]): cue("heal")
			elif hp < int(_health[id]): cue("strike")
	var shots := int(view.get("shots", 0))
	if not fresh and shots > _shots: cue("shot")
	_generation = generation
	_tick = tick
	_shots = shots
	_health = next

func apply_view(view: Dictionary) -> void:
	if view.get("schema", "") in ["flow.view/v1", "vanguard.view/v1"]:
		_apply_action_view(view)
		return
	var generation := str(view.session.generation)
	if generation != _generation:
		_generation = generation
		_seen.clear()
		for event in view.get("logs", []): _seen[str(event.id)] = true
		_paused = view.clock.paused
		return
	if _paused != bool(view.clock.paused): cue("pause")
	_paused = view.clock.paused
	for event in view.get("logs", []):
		var id := str(event.id)
		if _seen.has(id): continue
		_seen[id] = true
		match str(event.kind):
			"attack": cue("strike" if int(event.details.get("damage", 0)) > 0 else "miss")
			"healing": cue("heal")
			"damage", "save", "push", "interrupt": cue("power")
