extends Node
## One mix for the whole application. Audio is presentation, never game state.
const SETTINGS := "user://audio_settings.cfg"
const BUSES := ["Master", "Music", "UI", "SFX", "Ambience", "Dialogue"]
const ROOT := "res://assets/audio/cc0/"
const MUSIC := "res://assets/audio/music/lantern_quay.ogg"
const CUES := {
	"select": ["UI", -15.0, "interface-sounds/select_001"],
	"queue": ["UI", -13.0, "interface-sounds/click_001"],
	"reject": ["UI", -14.0, "interface-sounds/error_001"],
	"pause": ["UI", -17.0, "interface-sounds/minimize_001"],
	"strike": ["SFX", -10.0, "impact-sounds/impactMetal_light_000", "impact-sounds/impactMetal_light_001", "impact-sounds/impactMetal_light_002"],
	"miss": ["SFX", -10.0, "rpg-audio/knifeSlice", "rpg-audio/knifeSlice2"],
	"heal": ["SFX", -18.0, "impact-sounds/impactBell_heavy_000"],
	"power": ["SFX", -16.0, "impact-sounds/impactBell_heavy_001"],
	"shot": ["SFX", -16.0, "sci-fi-sounds/laserSmall_000", "sci-fi-sounds/laserSmall_001", "sci-fi-sounds/laserSmall_002"],
	"draw": ["SFX", -13.0, "rpg-audio/drawKnife1"],
	"door_open": ["SFX", -12.0, "rpg-audio/doorOpen_1"],
	"door_close": ["SFX", -12.0, "rpg-audio/doorClose_1"],
	"step_wood": ["SFX", -16.0, "impact-sounds/footstep_wood_000", "impact-sounds/footstep_wood_001", "impact-sounds/footstep_wood_002", "impact-sounds/footstep_wood_003"],
	"step_stone": ["SFX", -16.0, "impact-sounds/footstep_concrete_000", "impact-sounds/footstep_concrete_001", "impact-sounds/footstep_concrete_002", "impact-sounds/footstep_concrete_003"],
}
var levels: Dictionary = {}
var context := "title"
var played := 0
var duck_db := 0.0
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _beds: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _last: Dictionary = {}
var _last_variant: Dictionary = {}
var _cursor := 0
var _rng := RandomNumberGenerator.new()
var _settings_panel: CanvasLayer
var _quitting := false
var _previous_auto_accept_quit := true

static func ensure(owner: Node) -> Node:
	var root := owner.get_tree().root
	if root.has_meta("oathshaper_audio"):
		var existing: Node = root.get_meta("oathshaper_audio")
		if is_instance_valid(existing): return existing
	var service: Node = load("res://scripts/game_audio.gd").new()
	service.name = "GameAudio"
	service.process_mode = Node.PROCESS_MODE_ALWAYS
	service.configure()
	root.set_meta("oathshaper_audio", service)
	# Callers may be inside a scene's _ready, while its parent is busy.
	root.add_child.call_deferred(service)
	return service

static func route_voice(player: AudioStreamPlayer) -> void:
	ensure(player)
	player.bus = "Dialogue"
	player.add_to_group("dialogue_audio")

func configure(path := SETTINGS) -> void:
	var settings := ConfigFile.new()
	settings.load(path)
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
		set_level(bus, float(settings.get_value("volume", bus, .8 if bus == "Music" else 1.0)), false)

func set_level(bus: String, value: float, persist := true, path := SETTINGS) -> void:
	if bus not in BUSES: return
	levels[bus] = clampf(value, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(levels[bus], 0.0001)))
	if persist:
		var settings := ConfigFile.new()
		for key in levels: settings.set_value("volume", key, levels[key])
		settings.save(path)

func _ready() -> void:
	_previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	_rng.randomize()
	for kind in CUES:
		for file in CUES[kind].slice(2):
			_streams[file] = load(ROOT + file + ".ogg")
	for i in range(12):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for file in ["gentle_water", "harbor"]:
		var bed := AudioStreamPlayer.new()
		var stream := load(ROOT + file + ".ogg") as AudioStreamOggVorbis
		stream.loop = true
		bed.stream = stream
		bed.bus = "Ambience"
		bed.volume_db = -60.0
		add_child(bed)
		_beds.append(bed)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	var music_stream := load(MUSIC) as AudioStreamOggVorbis
	music_stream.loop = true
	_music.stream = music_stream
	_music.bus = "Music"
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()

func _release_playback() -> void:
	set_process(false)
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_streams.clear()
	_players.clear()
	_beds.clear()
	_music = null

func quit_game() -> void:
	if _quitting: return
	_quitting = true
	var tree := get_tree()
	_release_playback()
	# Godot 4.3's audio thread needs a mix interval to retire stopped Vorbis
	# playback before the resource cache is destroyed (godotengine/godot#76745).
	await tree.create_timer(.15, true, false, true).timeout
	tree.quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()

func _exit_tree() -> void:
	_release_playback()
	get_tree().auto_accept_quit = _previous_auto_accept_quit

func cue(kind: String) -> bool:
	if not CUES.has(kind) or _players.is_empty(): return false
	var now := Time.get_ticks_msec()
	var cooldown := 900 if kind == "heal" else 180 if kind == "power" else 120 if kind.begins_with("step_") else 65
	if now - int(_last.get(kind, -1000)) < cooldown: return false
	_last[kind] = now
	var cue: Array = CUES[kind]
	var count := cue.size() - 2
	var variant := _rng.randi_range(0, count - 1)
	if count > 1 and variant == int(_last_variant.get(kind, -1)): variant = (variant + 1) % count
	_last_variant[kind] = variant
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = _streams[cue[2 + variant]]
	player.bus = cue[0]
	player.volume_db = cue[1]
	player.pitch_scale = _rng.randf_range(.96, 1.04) if cue[0] == "SFX" else 1.0
	player.play()
	played += 1
	return true

func _process(delta: float) -> void:
	var speaking := false
	for voice in get_tree().get_nodes_in_group("dialogue_audio"):
		if voice.playing and not voice.stream_paused and voice.can_process():
			speaking = true
			break
	duck_db = move_toward(duck_db, -8.0 if speaking else 0.0, delta * (32.0 if speaking else 5.0))
	if is_instance_valid(_music):
		var music_target := (-4.0 if context == "title" else -11.0 if context == "office" else -8.0) + duck_db
		_music.volume_db = move_toward(_music.volume_db, music_target, delta * 24.0)
	for index in range(_beds.size()):
		var bed := _beds[index]
		var target := (-22.0 if index == 0 else -34.0) + duck_db
		if context == "office": target -= 15.0
		elif context == "title": target = -60.0
		bed.volume_db = move_toward(bed.volume_db, target, delta * 14.0)
		if context != "title" and not bed.playing: bed.play()
		elif context == "title" and bed.volume_db <= -59.0: bed.stop()

func open_settings() -> void:
	if is_instance_valid(_settings_panel): return
	_settings_panel = load("res://scripts/audio_settings.gd").new()
	_settings_panel.mixer = self
	get_tree().root.add_child(_settings_panel)
