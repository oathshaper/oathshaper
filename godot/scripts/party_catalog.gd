extends RefCounted

## Read-only authored build study. These values do not modify combat or saves.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/rpg_catalog.json"))
		assert(parsed is Dictionary and parsed.get("status") == "design_preview", "Invalid party preview catalog")
		_data = parsed
	return _data

static func actors() -> Array:
	return data().actors.duplicate(true)

static func profile(id: String) -> Dictionary:
	return data().profiles[id].duplicate(true)

static func build(profile_id: String, actor_id: String) -> Dictionary:
	return profile(profile_id).builds[actor_id]
