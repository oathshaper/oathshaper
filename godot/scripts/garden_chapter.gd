extends RefCounted
## Shared story copy. Combat profiles do not supply the chapter's premise or outcome.
static var _story: Dictionary = {}

static func story() -> Dictionary:
	if _story.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://content/garden_chapter.json"))
		assert(parsed is Dictionary, "Missing garden chapter")
		_story = parsed
	return _story

static func briefing_lines() -> Array[Dictionary]:
	return dialogue_lines("briefing")

static func dialogue_lines(section: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for line in str(story().get(section, "")).split("\n\n"):
		var boundary := line.find(": \"")
		if boundary >= 0:
			lines.append({"speaker": line.left(boundary), "text": line.substr(boundary + 3).trim_suffix("\"")})
	return lines
