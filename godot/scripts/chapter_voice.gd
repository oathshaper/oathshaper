extends AudioStreamPlayer
const VOICES := preload("res://scripts/voice_library.gd")
var _lines: Array = []
static func attach(panel: Control, text: String) -> void:
	var narrator := load("res://scripts/chapter_voice.gd").new() as AudioStreamPlayer
	panel.add_child(narrator)
	narrator.play_dialogue(text)
func play_dialogue(text: String) -> void:
	preload("res://scripts/game_audio.gd").route_voice(self)
	for line in text.split("\n\n"):
		var boundary := line.find(": \"")
		if boundary < 0: continue
		var speaker := line.left(boundary)
		var spoken := line.substr(boundary + 3).trim_suffix("\"")
		var audio := VOICES.clip(speaker, spoken)
		if audio != null: _lines.append(audio)
	finished.connect(_next)
	_next()
func _next() -> void:
	if _lines.is_empty(): return
	stream = _lines.pop_front()
	play()
