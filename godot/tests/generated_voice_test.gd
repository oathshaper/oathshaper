extends SceneTree
## Imported production clips through the actual dialogue and chapter players.
const VOICES := preload("res://scripts/voice_library.gd")
var checks := 0
var failures := 0
var evidence := preload("res://tests/continuity_receipt.gd").new()
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	evidence.record(description, value)
	checks += 1
	if not value:
		failures += 1
		push_error(description)
func run() -> void:
	create_timer(60).timeout.connect(func() -> void: quit(1))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VOICES.SCRIPT))
	check(manifest.lines.size() >= 40, "Full chapter and quay voice script is present")
	for line in manifest.lines:
		var clip := VOICES.clip(line.speaker, line.lookup_text)
		check(clip != null and clip.get_length() > 0.0, "Imported audio loads: " + line.speaker + " / " + line.lookup_text)
	check(VOICES.clip("Mara", "A line that was never recorded.") == null, "Unrecorded variants cannot borrow another clip")
	if failures: quit(1); return
	var demo := preload("res://scenes/demo.tscn").instantiate()
	demo.save_path = "user://generated-voice-%s.json" % Time.get_ticks_usec()
	root.add_child(demo)
	await process_frame
	var panel = demo.panel
	demo._begin_dialogue("mara_greeting")
	check(panel.voice_player.playing and panel.voice_player.stream != null, "Actual Mara greeting starts playback")
	demo._choose("share_oil")
	check(panel._player_reply and panel.speaker.text == "Tessa Ward" and panel.voice_player.playing, "Accepted choice starts the recorded player reply")
	var committed: Dictionary = demo._call_bridge("save_json")
	panel.set_presentation_paused(true)
	var remaining: float = panel._line_remaining
	await create_timer(.25).timeout
	check(is_equal_approx(panel._line_remaining, remaining) and panel.voice_player.stream_paused, "Actual player recording pauses with presentation")
	panel.set_presentation_paused(false)
	await create_timer(remaining + .35).timeout
	check(not panel._player_reply and panel.speaker.text == "Mara" and panel._is_response, "Natural playback completion presents the NPC response")
	check(panel.voice_player.playing and panel.voice_player.stream == VOICES.clip("Mara", panel.subtitle.text), "The exact NPC response recording is playing")
	check(demo._call_bridge("save_json") == committed and demo._story_state.moral == 2, "Playback completion does not repeat the accepted choice")
	panel._finish_line()
	check(not panel._is_response and not panel.voice_player.playing, "Response skip returns silently to its menu")
	check(not FileAccess.file_exists(demo.save_path), "Voice playback never creates campaign saves")
	demo._end_dialogue()
	root.remove_child(demo)
	demo.queue_free()
	await process_frame
	var modal := PanelContainer.new()
	root.add_child(modal)
	preload("res://scripts/chapter_voice.gd").attach(modal, preload("res://scripts/garden_chapter.gd").story().briefing)
	var speakers := modal.find_children("*", "AudioStreamPlayer", true, false)
	check(speakers.size() == 1, "Chapter modal owns one speech player")
	var narrator: AudioStreamPlayer = speakers[0]
	var first := narrator.stream
	check(first != null and narrator.playing, "Chapter briefing starts its first recorded speaker")
	if DisplayServer.get_name() == "headless":
		# Godot's dummy audio driver does not provide the hardware playback clock.
		# The native-window gate exercises the real audio-finished transition.
		narrator.finished.emit()
	else:
		await create_timer(first.get_length() + .35).timeout
	check(narrator.playing and narrator.stream != first, "Audio-finished advances to the next chapter speaker")
	modal.queue_free()
	await process_frame
	await process_frame
	check(not is_instance_valid(narrator), "Closing the modal destroys its speech player")
	print("GENERATED_VOICE: %d checks, %d failures" % [checks, failures])
	evidence.finish("voice-playback", "Current imported clips and real dialogue players: identity, duration, pause, cancellation and no duplicated choice effect. Not acting-quality assessment.", {"clips": manifest.lines.size()})
	quit(1 if failures else 0)
