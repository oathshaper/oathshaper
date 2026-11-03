extends SceneTree
## Reproducible rendered Command benchmark. No campaign saves are read/written.
## Godot 4.3: --path godot --resolution 1280x800 --script res://tools/profile_combat.gd
## Optional -- --output=/absolute/report.json. Reports time in milliseconds.
## The 12-second engine timer can take longer in wall time when frames stall.
class Probe:
	extends "res://scripts/command_trial.gd"
	var samples: Dictionary = {}
	var recording := false
	var frames: Array[float] = []
	var last_usec := 0
	func record(key: String, us: int) -> void:
		if recording:
			if not samples.has(key): samples[key] = []
			samples[key].append(float(us) / 1000.0)
	func _ready() -> void:
		super._ready()
		stage.set_process(false)
	func _call(method: String, arguments: Array = []) -> Dictionary:
		var start := Time.get_ticks_usec()
		var result := super._call(method, arguments)
		record("bridge_" + method, Time.get_ticks_usec() - start)
		return result
	func _publish(data: Dictionary) -> void:
		var start := Time.get_ticks_usec()
		super._publish(data)
		record("publish", Time.get_ticks_usec() - start)
	func _satisfy_space() -> bool:
		var start := Time.get_ticks_usec()
		var result := super._satisfy_space()
		record("space", Time.get_ticks_usec() - start)
		return result
	func _process(delta: float) -> void:
		var start := Time.get_ticks_usec()
		if recording and last_usec > 0: frames.append(float(start - last_usec) / 1000.0)
		last_usec = start
		if recording and _preview_resumed and state.encounter.status not in ["won", "lost"] and state.clock.paused:
			_toggle_pause()
		super._process(delta)
		record("host_frame", Time.get_ticks_usec() - start)
		if stage != null:
			start = Time.get_ticks_usec()
			stage._process(delta)
			record("stage_frame", Time.get_ticks_usec() - start)

var trial: Probe
func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var sum := 0.0
	for value in values: sum += value
	return {"count":values.size(), "mean_ms":sum / values.size(), "p50_ms":sorted[int((values.size()-1)*.5)], "p95_ms":sorted[int((values.size()-1)*.95)], "max_ms":sorted[-1], "total_ms":sum}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The combat benchmark requires a rendered window; headless frame times are not representative.")
		quit(2)
		return
	root.size = Vector2i(1280,800)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	trial = Probe.new()
	trial.preview_mode = true
	root.add_child(trial)
	await create_timer(3.0).timeout
	trial._preview_resumed = true
	trial._toggle_pause()
	trial.recording = true
	trial.last_usec = 0
	var began := Time.get_ticks_msec()
	await create_timer(12.0).timeout
	trial.recording = false
	var result := {"schema":1,"fixture":"command-preview-auto-resume","engine":Engine.get_version_info().string,"target_fps":60,"window":[1280,800],"wall_ms":Time.get_ticks_msec()-began,"frame":stats(trial.frames),"methods":{},"tick":trial.state.session.tick,"phase":trial.state.session.phase,"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method"),"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	for key in trial.samples: result.methods[key] = stats(trial.samples[key])
	var output := "/tmp/oathshaper-combat-profile.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write combat profile: " + output)
		quit(2)
		return
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("COMBAT_PROFILE ",JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.trim_suffix(".json")+".png")
	quit()
