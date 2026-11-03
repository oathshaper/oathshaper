extends RefCounted
## Exact subtitle identity selects audio, including conditional dialogue lines.
const SCRIPT := "res://content/voice_script.json"
static var _entries: Dictionary = {}
static var _loaded := false
static func entry(speaker: String, text: String) -> Dictionary:
	# The player was renamed after recording. Keep the original casting identity
	# and provenance hashes; the subtitle/HUD uses the current character name.
	if speaker == "Tessa Ward": speaker = "Corsair"
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(SCRIPT):
			var data = JSON.parse_string(FileAccess.get_file_as_string(SCRIPT))
			if data is Dictionary:
				for line in data.get("lines", []):
					_entries[str(line.key)] = line
	return _entries.get((speaker + "\n" + text).sha256_text(), {})
static func clip(speaker: String, text: String) -> AudioStream:
	var line := entry(speaker, text)
	var path: String = str(line.get("path", ""))
	if path.is_empty() or not ResourceLoader.exists(path, "AudioStream"):
		return null
	return load(path) as AudioStream
