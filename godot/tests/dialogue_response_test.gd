extends SceneTree
## Timed response behavior through the real Rust bridge and Godot panel.

var demo: Node3D
var panel: Control
var save_path := "user://response_test_%d.json" % Time.get_ticks_usec()
var voice_path := "user://response_voice_%d.tres" % Time.get_ticks_usec()


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Response test failed: " + message)
		quit(1)
	return condition


func _node_id() -> String:
	return str(demo.call("_call_bridge", "view").get("data", {}).get("node_id", ""))


func _choice_button(choice_id: String) -> Button:
	for button in panel.get("buttons"):
		if button.get_meta("choice_id", "") == choice_id:
			return button
	return null


func _topic_is_grey(choice_id: String) -> bool:
	var button := _choice_button(choice_id)
	return button != null and button.disabled and button.text.begins_with("✓") and button.tooltip_text == "Already asked"


func _tap(button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


func _finish_player_reply() -> void:
	# This suite owns NPC response timing; player speech has a separate gate.
	if panel.get("_player_reply"):
		panel.call("_finish_line")
		await process_frame


func _run() -> void:
	demo = (load("res://scenes/demo.tscn") as PackedScene).instantiate()
	demo.set("save_path", save_path)
	root.add_child(demo)
	await process_frame
	await process_frame
	panel = demo.get_node("CanvasLayer/DialoguePanel")
	panel.set_process(false) # Advance the real panel clock deterministically.
	demo.call("_begin_dialogue", "mara_greeting")
	await create_timer(.35).timeout
	panel._select_index(panel.buttons.size() - 1)
	await process_frame
	await process_frame
	if not _expect(panel._choice_scroll.scroll_vertical > 0 and panel._choice_scroll.get_global_rect().end.y <= panel.back_hint.get_global_rect().position.y, "Long question menus scroll to the focused choice above the controls"):
		return
	panel._select_index(panel.buttons.find(_choice_button("share_oil")))
	await _tap(JOY_BUTTON_A)
	await _finish_player_reply()
	if not _expect(_node_id() == "mara_thanks" and panel.get("buttons").is_empty() and panel.visible, "choosing oil shows only Mara's response"):
		return
	var duration := float(panel.get("_line_remaining"))
	var skip_hint := "Ⓑ Skip" if not Input.get_connected_joypads().is_empty() else "Esc: Skip"
	if not _expect(duration > 0.0 and duration < 30.0 and (panel.get("back_hint") as Label).text.contains(skip_hint), "response uses a bounded presentation duration and connection-aware skip hint"):
		return
	await _tap(JOY_BUTTON_A)
	if not _expect(_node_id() == "mara_thanks", "confirm cannot accidentally choose through a response"):
		return
	panel.call("_process", duration - 0.1)
	if not _expect(_node_id() == "mara_thanks", "response remains until its reading time has elapsed"):
		return
	panel.call("_process", 0.2)
	await create_timer(0.35).timeout
	if not _expect((panel.get("content_panel") as Control).anchor_top <= 0.56, "returning from the short response band restores enough room for question buttons"):
		return
	if not _expect(_node_id() == "mara_greeting" and demo.get("mode") == "dialogue" and panel.get("selected_index") == 0 and float(panel.get("_line_remaining")) == 0.0, "timeout automatically restores questions and focus without replaying the greeting"):
		return
	var mara_slot := demo.get_node("Mara/ModelSlot")
	if not _expect((mara_slot.get("_animation_player") as AnimationPlayer).current_animation == mara_slot.get("_idle_clip"), "Mara idles while the player chooses"):
		return
	if not _expect(demo.get("_story_state")["moral"] == 2, "automatic return does not repeat the oil effect"):
		return
	panel._select_index(panel.buttons.find(_choice_button("ask_for_favor")))
	await _tap(JOY_BUTTON_A) # Ask where Ivo is.
	await _finish_player_reply()
	await _tap(JOY_BUTTON_B)
	if not _expect(_node_id() == "mara_greeting" and demo.get("mode") == "dialogue" and _choice_button("ask_for_favor").disabled, "B skips immediately to questions and the asked choice stays grey"):
		return
	await _tap(JOY_BUTTON_B)
	if not _expect(demo.get("mode") == "explore" and not panel.visible, "B at the menu exits conversation"):
		return
	demo.call("_begin_dialogue", "mara_greeting")
	if not _expect(_topic_is_grey("ask_for_favor") and not _choice_button("leave").disabled, "Mara's asked topic stays grey on reentry while leaving remains available"):
		return
	demo.call("_end_dialogue")

	demo.call("_begin_dialogue", "clerk_greeting")
	panel._select_index(panel.buttons.find(_choice_button("ask_about_records")))
	await _tap(JOY_BUTTON_A)
	await _finish_player_reply()
	var clerk_time := float(panel.get("_line_remaining"))
	await _tap(JOY_BUTTON_START)
	panel.call("_process", 100.0)
	if not _expect(_node_id() == "clerk_records" and is_equal_approx(float(panel.get("_line_remaining")), clerk_time), "opening the ledger suspends the response countdown"):
		return
	await _tap(JOY_BUTTON_START)
	if not _expect(bool(demo.call("_save")), "a response can be saved"):
		return
	demo.call("_end_dialogue")
	if not _expect(bool(demo.call("_load")) and _node_id() == "clerk_records" and float(panel.get("_line_remaining")) > 0.0, "loading a response restarts its presentation with its return menu intact"):
		return
	panel.call("_process", clerk_time + 0.1)
	if not _expect(_node_id() == "clerk_greeting", "loaded clerk response returns to the clerk's questions"):
		return
	if not _expect(_topic_is_grey("ask_about_records"), "the clerk's records topic stays grey after loading a response and automatic return"):
		return
	demo.call("_end_dialogue")
	demo.call("_begin_dialogue", "clerk_greeting")
	if not _expect(_topic_is_grey("ask_about_records") and not _choice_button("open_shortcut").disabled, "clerk topic history survives reentry without disabling an unused consequential choice"):
		return
	demo.call("_end_dialogue")
	demo.call("_begin_dialogue", "ivo_gate")
	demo.call("_choose", "ask_about_gate")
	await _finish_player_reply()
	panel.call("_process", 100.0)
	if not _expect(_node_id() == "ivo_gate" and _topic_is_grey("ask_about_gate") and _choice_button("open_gate").disabled, "Ivo's answered topic becomes grey but the gate still waits for recruitment"):
		return
	if not _expect(bool(demo.call("_save")), "save completed conversation history"):
		return
	demo.call("_end_dialogue")
	if not _expect(bool(demo.call("_load")) and _topic_is_grey("ask_about_gate"), "Ivo's completed topic survives the full game save/load path"):
		return
	for pair in [["mara_greeting", "ask_for_favor"], ["clerk_greeting", "ask_about_records"], ["ivo_gate", "ask_about_gate"]]:
		demo.call("_end_dialogue")
		demo.call("_begin_dialogue", pair[0])
		if not _expect(_topic_is_grey(pair[1]) and not _choice_button("leave").disabled, "%s completed topic is grey after save/load and repeated rendering" % pair[0]):
			return

	# A generated silent fixture tests duration/pause, not audio content quality.
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 8000
	var samples := PackedByteArray()
	samples.resize(32000) # Two seconds of mono 16-bit silence.
	clip.data = samples
	if not _expect(ResourceSaver.save(clip, voice_path) == OK, "create voice-duration fixture"):
		return
	demo.call("_begin_dialogue", "mara_thanks")
	var response: Dictionary = demo.call("_call_bridge", "view").get("data", {})
	var voice_entry := preload("res://scripts/voice_library.gd").entry(response.speaker, response.text)
	var original_path: String = voice_entry.path
	voice_entry.path = voice_path
	panel.call("show_view", response)
	if not _expect(absf(float(panel.get("_line_remaining")) - 2.45) < 0.01, "a voice clip determines response duration plus a short tail"):
		return
	panel.call("set_presentation_paused", true)
	panel.call("_process", 20.0)
	if not _expect((panel.get("voice_player") as AudioStreamPlayer).stream_paused and _node_id() == "mara_thanks", "voice and countdown pause together"):
		return
	panel.call("set_presentation_paused", false)
	panel.call("_process", 2.5)
	if not _expect(_node_id() == "mara_greeting" and not (panel.get("voice_player") as AudioStreamPlayer).playing, "voiced response returns once and stops audio"):
		return
	demo.call("_begin_dialogue", "mara_thanks")
	voice_entry.path = "res://assets/audio/missing-response.ogg"
	response["voice"] = voice_path # A stale node-wide clip must not be reused.
	panel.call("show_view", response)
	if not _expect(is_equal_approx(float(panel.get("_line_remaining")), float(panel.call("estimated_line_seconds", response["text"]))), "missing voice falls back to subtitle reading time"):
		return
	voice_entry.path = original_path
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	escape.pressed = false
	Input.parse_input_event(escape)
	await process_frame
	if not _expect(_node_id() == "mara_greeting" and (panel.get("back_hint") as Label).text.contains("Esc"), "keyboard Escape skips to the same menu and restores keyboard hints"):
		return
	demo.call("_end_dialogue")
	demo.call("_begin_dialogue", "vendor_greeting")
	panel.call("_process", 100.0)
	if not _expect(_node_id() == "vendor_greeting", "an old response cannot redirect a later conversation"):
		return

	# One full response uses ordinary frame processing, without clock injection.
	demo.call("_choose", "ask_about_tower")
	await _finish_player_reply()
	var real_duration := float(panel.get("_line_remaining"))
	panel.set_process(true)
	await create_timer(real_duration + 0.25).timeout
	if not _expect(_node_id() == "vendor_greeting" and demo.get("mode") == "dialogue", "ordinary frame time returns the vendor response without any input"):
		return
	demo.call("_end_dialogue")
	for path in [save_path, voice_path]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Timed response checks passed: automatic return, B/Esc skip, ledger pause, voice duration, missing audio, save/load, focus, no repeated effects, and persistent grey topics for Mara, clerk and Ivo")
	root.remove_child(demo)
	demo.queue_free()
	quit(0)
