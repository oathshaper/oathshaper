extends SceneTree
const AUDIO := preload("res://scripts/game_audio.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 800)
	var mixer := AUDIO.ensure(root)
	check(mixer == AUDIO.ensure(root), "Single mixer survives repeated scene requests")
	await process_frame
	await process_frame
	for stream in mixer._streams.values(): check(stream != null and stream.get_length() > 0, "Every curated effect is imported")
	check(mixer._beds.size() == 2, "Exactly two ambience layers")
	check(not mixer._beds[0].playing, "Title keeps waterfront ambience silent")
	check(mixer._music.playing and mixer._music.stream.loop and mixer._music.bus == "Music", "Approved music loops on its own bus")
	check(is_equal_approx(mixer._music.stream.get_length(), 28.5), "Imported music contains the complete crossfaded loop")
	mixer.context = "quay"
	await create_timer(.15).timeout
	check(mixer._beds[0].playing and mixer._beds[0].stream.loop, "Quay starts looping ambience")
	var pool_size: int = mixer.get_child_count()
	for i in range(20): mixer.cue("strike")
	check(mixer.get_child_count() == pool_size and mixer.played == 1, "Cue burst is throttled with a bounded player pool")
	var combat := preload("res://scripts/combat_audio.gd").new()
	root.add_child(combat)
	var view := {"session":{"generation":"test"}, "clock":{"paused":true}, "logs":[]}
	combat.apply_view(view)
	view.logs = [{"id":"hit1", "kind":"healing", "details":{}}]
	combat.apply_view(view)
	var played: int = combat.played
	combat.apply_view(view)
	check(played == 1 and combat.played == played, "Committed event plays once; repaint is silent")
	combat.muted = true
	combat.cue("queue")
	check(combat.played == played, "Preview mute suppresses event sounds")
	combat.muted = false
	var action := {"schema":"flow.view/v1", "session":{"generation":"flow", "tick":1}, "actors":[{"id":"player", "health":{"current":20}}]}
	combat.apply_view(action)
	await create_timer(.15).timeout
	action.actors[0].health.current = 15
	action.session.tick = 2
	combat.apply_view(action)
	played = combat.played
	combat.apply_view(action)
	check(played == 2 and combat.played == played, "Flow committed pool loss plays once")
	combat.apply_view({"schema":"vanguard.view/v1", "generation":"vg", "tick":0, "actors":{"player":{"id":"player","hp":600}}, "shots":0})
	check(combat.played == played, "Vanguard initial projection does not replay history")
	await create_timer(2.0).timeout
	var music_volume: float = mixer._music.volume_db
	var music_position: float = mixer._music.get_playback_position()
	mixer.context = "office"
	await create_timer(.3).timeout
	check(mixer._music.volume_db < music_volume - 2.0, "Office lowers the music mix")
	check(mixer._music.get_playback_position() > music_position, "Room transitions preserve music playback position")
	mixer.context = "quay"
	await create_timer(.3).timeout
	music_volume = mixer._music.volume_db
	var voice := AudioStreamPlayer.new()
	root.add_child(voice)
	AUDIO.route_voice(voice)
	voice.stream = mixer._beds[0].stream
	voice.play()
	await create_timer(.3).timeout
	check(voice.bus == "Dialogue" and mixer.duck_db < -5, "Speech is routed and ducks the ambience")
	check(mixer._music.volume_db < music_volume - 5, "Spoken dialogue ducks music as well")
	voice.stop()
	await create_timer(1.8).timeout
	check(is_zero_approx(mixer.duck_db), "Duck releases after speech ends")
	check(is_equal_approx(mixer._music.volume_db, music_volume), "Music returns to its previous mix after speech")
	var old: float = mixer.levels.SFX
	mixer.set_level("SFX", 0, true, "user://audio-test.cfg")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Zero slider value actually mutes its bus")
	mixer.set_level("SFX", .5, true, "user://audio-test.cfg")
	mixer.configure("user://audio-test.cfg")
	check(is_equal_approx(mixer.levels.SFX, .5), "Volume persists and reloads")
	mixer.set_level("SFX", old, false)
	var old_music: float = mixer.levels.Music
	mixer.set_level("Music", 0, true, "user://audio-test.cfg")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music can be muted independently")
	mixer.set_level("Music", .45, true, "user://audio-test.cfg")
	mixer.configure("user://audio-test.cfg")
	check(is_equal_approx(mixer.levels.Music, .45), "Music volume persists and reloads")
	mixer.set_level("Music", old_music, false)
	DirAccess.remove_absolute("user://audio-test.cfg")
	var title := preload("res://scripts/combat_frontend.gd").new()
	root.add_child(title)
	title.open_title(false)
	await process_frame
	var audio_button: Button
	for button in title._buttons:
		if button.text == "Audio": audio_button = button
	check(audio_button != null and audio_button.get_global_rect().end.y < 800, "Title exposes an accessible Audio button")
	audio_button.grab_focus()
	audio_button.pressed.emit()
	await process_frame
	check(paused and mixer._settings_panel != null, "Audio settings pause gameplay")
	var sliders: Array[Node] = mixer._settings_panel.find_children("*", "HSlider", true, false)
	check(sliders.size() == 6 and sliders[0].has_focus(), "All six sliders support keyboard/controller focus")
	for slider in sliders: check(slider.get_global_rect().end.y < 800, "Slider fits Steam Deck height")
	for button in mixer._settings_panel.find_children("*", "Button", true, false):
		check(button.get_global_rect().end.y < 800, "Audio settings buttons fit Steam Deck height")
	check(mixer._music.playing and mixer._music.can_process(), "Music continues while settings pause the scene")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oath-audio-settings.png")
	mixer._settings_panel._close()
	check(not paused, "Closing settings restores gameplay pause state")
	check(audio_button.has_focus(), "Closing settings returns focus to its entry button")
	await process_frame
	check(mixer.context == "quay" and mixer._beds.size() == 2, "Settings do not duplicate or reset world ambience")
	voice.queue_free()
	combat.queue_free()
	title.queue_free()
	root.remove_meta("oathshaper_audio")
	mixer.queue_free()
	await process_frame
	await process_frame
	print("GAME_AUDIO: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
