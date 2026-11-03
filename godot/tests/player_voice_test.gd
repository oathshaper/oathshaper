extends SceneTree
var checks := 0
var failures := 0
var replies: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func run() -> void:
	var scene := preload("res://scenes/demo.tscn").instantiate()
	scene.save_path = "user://voice-test-no-save.json"
	root.add_child(scene)
	await process_frame
	var panel = scene.panel
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 8000
	var bytes := PackedByteArray()
	bytes.resize(8000)
	clip.data = bytes
	panel.player_reply_finished.connect(func(done: bool) -> void: replies.append(done))
	panel.play_player_reply("Where does Ivo stand watch?", clip)
	check(panel._player_reply and panel.buttons.is_empty(), "Player reply suppresses stale choices")
	check(panel.speaker.text == "Tessa Ward", "Player is the subtitle speaker")
	check(panel.voice_player.stream == clip, "Player clip is actually assigned")
	panel.set_presentation_paused(true)
	var remaining: float = panel._line_remaining
	panel._process(2.0)
	check(panel._line_remaining == remaining and panel.voice_player.stream_paused, "Ledger pause freezes player voice and timer")
	panel.set_presentation_paused(false)
	panel._finish_line()
	check(replies == [true] and not panel._player_reply, "Skip completes presentation once")
	panel.play_player_reply("Mara's ready. Let's get the payroll back.", clip)
	panel.hide_panel()
	check(replies == [true, false], "Closing or loading cancels stale pending reply")
	panel.play_player_reply("Until next time.", clip)
	panel._process(1.0)
	check(replies == [true, false, true], "Clip duration finishes player line automatically")
	check(not FileAccess.file_exists(scene.save_path), "Voice presentation never writes campaign state")
	print("PLAYER_VOICE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
