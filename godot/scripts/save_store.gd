extends RefCounted

const PATH := "user://oathshaper_m1.save.json"
const HUB_PATH := "user://oathshaper_hub_v4.save.json"
const PROFILES := preload("res://scripts/combat_profiles.gd")

static func save(narrative_save: String, player_position: Vector3, path: String = PATH, profile_id := "command", chapters: Dictionary = {}, companions: Dictionary = {}) -> Error:
	if not preload("res://scripts/companion_rendezvous.gd").valid_snapshot(companions) or not _valid_chapters(chapters) or not PROFILES.is_valid(profile_id) or not player_position.is_finite() or player_position.length() > 1000.0:
		return ERR_INVALID_DATA
	var data: String = JSON.stringify({
		"schema": 3,
		"narrative": narrative_save,
		"player": [player_position.x, player_position.y, player_position.z],
		"combat_profile": profile_id,
		"chapters": chapters,
		"companions": companions
	})
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(data)
	file.close()
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(path)
	)

static func load(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "No save exists."}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "Save header is invalid."}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Save header is invalid."}
	var schema: Variant = parsed.get("schema")
	# JSON numbers are floats; Array.has() compares types as well as values.
	if typeof(schema) not in [TYPE_INT, TYPE_FLOAT] or (schema != 1 and schema != 2 and schema != 3):
		return {"ok": false, "error": "Save header is invalid."}
	var position: Variant = parsed.get("player")
	if typeof(position) != TYPE_ARRAY or position.size() != 3:
		return {"ok": false, "error": "Saved position is invalid."}
	for coordinate in position:
		if typeof(coordinate) != TYPE_FLOAT and typeof(coordinate) != TYPE_INT:
			return {"ok": false, "error": "Saved position is invalid."}
		if not is_finite(float(coordinate)):
			return {"ok": false, "error": "Saved position is invalid."}
	if Vector3(position[0], position[1], position[2]).length() > 1000.0:
		return {"ok": false, "error": "Saved position is invalid."}
	if typeof(parsed.get("narrative")) != TYPE_STRING:
		return {"ok": false, "error": "Narrative save is missing."}
	if schema >= 2:
		if typeof(parsed.get("combat_profile")) != TYPE_STRING or not PROFILES.is_valid(str(parsed.get("combat_profile"))):
			return {"ok": false, "error": "Combat profile is invalid."}
	else:
		parsed["combat_profile"] = PROFILES.DEFAULT_ID
	if schema == 3:
		if not parsed.has("chapters") or not _valid_chapters(parsed.chapters):
			return {"ok": false, "error": "Chapter progress is invalid."}
	else:
		parsed["chapters"] = {}
	if not parsed.get("companions", {}) is Dictionary or not preload("res://scripts/companion_rendezvous.gd").valid_snapshot(parsed.get("companions", {})):
		return {"ok": false, "error": "Companion travel is invalid."}
	return {"ok": true, "data": parsed}

static func _valid_chapters(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for id in value:
		if id != "dockside_robbery" or not value[id] is bool:
			return false
	return true
