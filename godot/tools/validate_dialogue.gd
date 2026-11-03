extends SceneTree

func _init() -> void:
	var bridge: Object = ClassDB.instantiate("NarrativeBridge") as Object
	if bridge == null:
		push_error("NarrativeBridge extension is unavailable")
		quit(1)
		return
	var source: String = FileAccess.get_file_as_string("res://content/lantern_quay.json")
	var result: Variant = JSON.parse_string(str(bridge.call("validate_story", source)))
	if typeof(result) != TYPE_DICTIONARY or not result.get("ok", false):
		push_error(str(result.get("error", "Invalid validator response")))
		quit(1)
		return
	print("Dialogue valid: ", result.get("data", {}).get("id", ""))
	quit(0)
