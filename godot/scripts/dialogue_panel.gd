extends Control

signal selected(choice_id: String)
signal player_reply_finished(completed: bool)
const VOICES := preload("res://scripts/voice_library.gd")
signal cancelled
signal response_finished
signal speaking_changed(active: bool)
signal input_observed(event: InputEvent)

@onready var speaker: Label = $Panel/Margin/VBox/Speaker
@onready var subtitle: Label = $Panel/Margin/VBox/Subtitle
@onready var choices: VBoxContainer = $Panel/Margin/VBox/Choices
@onready var voice_player: AudioStreamPlayer = $VoicePlayer
@onready var content_panel: PanelContainer = $Panel
@onready var content_margin: MarginContainer = $Panel/Margin
@onready var back_hint: Label = $Panel/Margin/VBox/BackHint

const MIN_CONTENT_HEIGHT := 352.0
const RESPONSE_CONTENT_HEIGHT := 180.0
const TOP_BAR_HEIGHT := 72.0
const BOTTOM_BAR_HEIGHT := 48.0
const REVEAL_SECONDS := 0.28

var buttons: Array[Button] = []
var selected_index := -1
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _reveal: Tween
var _is_response := false
var _line_remaining := 0.0
var _presentation_paused := false
var _using_controller := false
var _player_reply := false
var _voice_quiet := 0.0
var _voice_gesture_active := false
var _choice_scroll: ScrollContainer


func _ready() -> void:
	preload("res://scripts/game_audio.gd").route_voice(voice_player)
	selected.connect(func(_id: String) -> void: preload("res://scripts/game_audio.gd").ensure(self).cue("queue"))
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.name = "ChoiceScroll"
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choice_scroll.follow_focus = true
	choices.get_parent().add_child(_choice_scroll)
	choices.reparent(_choice_scroll)
	choices.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_configure_compact_layout()
	_top_bar = _make_bar("TopLetterbox", false)
	_bottom_bar = _make_bar("BottomLetterbox", true)
	move_child(_top_bar, 0)
	move_child(_bottom_bar, 1)
	_reset_letterbox()


func _place(control: Control, left: float, top: float, right: float, bottom: float, inset_top := 0.0, inset_bottom := 0.0) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = inset_top
	control.offset_right = 0.0
	control.offset_bottom = inset_bottom


func _configure_compact_layout() -> void:
	content_margin.add_theme_constant_override("margin_left", 28)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 28)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	speaker.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_font_size_override("font_size", 20)
	back_hint.add_theme_font_size_override("font_size", 16)
	_place(speaker, 0.0, 0.0, 0.47, 0.0, 0.0, 66.0)
	_place(subtitle, 0.0, 0.0, 0.47, 1.0, 74.0, 0.0)
	_place(_choice_scroll, 0.51, 0.0, 1.0, 1.0, 0.0, -56.0)
	_place(back_hint, 0.51, 1.0, 1.0, 1.0, -48.0, 0.0)


func _make_bar(bar_name: String, at_bottom: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = Color(0.025, 0.035, 0.05, 0.96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0 if at_bottom else 0.0
	bar.anchor_bottom = bar.anchor_top
	add_child(bar)
	return bar


func _reset_letterbox() -> void:
	if _reveal != null and _reveal.is_running():
		_reveal.kill()
	_top_bar.offset_bottom = 0.0
	_bottom_bar.offset_top = 0.0
	content_panel.anchor_top = 0.55
	content_panel.offset_bottom = 0.0


func _reveal_letterbox() -> void:
	if _reveal != null and _reveal.is_running():
		_reveal.kill()
	var viewport_height := maxf(size.y, 1.0)
	var top_height := minf(TOP_BAR_HEIGHT, viewport_height * 0.09)
	var bottom_height := minf(BOTTOM_BAR_HEIGHT, viewport_height * 0.06)
	var content_height := RESPONSE_CONTENT_HEIGHT if _is_response else MIN_CONTENT_HEIGHT
	var top_limit := 0.74 if _is_response else 0.56
	var panel_top := clampf(minf(top_limit, 1.0 - (content_height + bottom_height) / viewport_height), 0.2, top_limit)
	_reveal = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal.tween_property(_top_bar, "offset_bottom", top_height, REVEAL_SECONDS)
	_reveal.tween_property(_bottom_bar, "offset_top", -bottom_height, REVEAL_SECONDS)
	_reveal.tween_property(content_panel, "anchor_top", panel_top, REVEAL_SECONDS)
	_reveal.tween_property(content_panel, "offset_bottom", -bottom_height, REVEAL_SECONDS)

func show_view(view: Dictionary, speak_line := true) -> void:
	_abort_reply()
	var entering := not visible
	_is_response = view.get("return_to") != null
	visible = true
	if entering:
		_reset_letterbox()
	_reveal_letterbox()
	_configure_compact_layout()
	if _is_response:
		_place(speaker, 0.0, 0.0, 1.0, 0.0, 0.0, 32.0)
		_place(subtitle, 0.0, 0.0, 1.0, 1.0, 40.0, -40.0)
	speaker.text = str(view.get("speaker", ""))
	subtitle.text = str(view.get("text", ""))
	_line_remaining = estimated_line_seconds(subtitle.text) if speak_line else 0.0
	_voice_quiet = 0.0
	_voice_gesture_active = speak_line
	voice_player.stop()
	voice_player.stream = null
	var generated := VOICES.clip(speaker.text, subtitle.text)
	# A node-wide clip can describe a different conditional response. Only an
	# exact text entry may supply audio; absent variants retain subtitle timing.
	if speak_line and generated != null:
		var clip: Resource = generated
		if clip is AudioStream:
			voice_player.stream = clip
			voice_player.play()
			voice_player.stream_paused = _presentation_paused
			if clip.get_length() > 0.0:
				_line_remaining = clip.get_length() + 0.45
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	buttons.clear()
	selected_index = -1
	for choice in view.get("choices", []):
		var button := Button.new()
		button.text = str(choice.get("text", ""))
		if not choice.get("enabled", false):
			var reason: String = str(choice.get("locked_reason", ""))
			var marker := "✓" if choice.get("completed", false) else "🔒"
			button.text = "%s  %s\n%s" % [marker, button.text, reason]
			button.tooltip_text = reason
		button.disabled = not choice.get("enabled", false)
		button.custom_minimum_size = Vector2(0, 68 if button.disabled else 56)
		button.add_theme_font_size_override("font_size", 18 if button.disabled else 20)
		var choice_id: String = str(choice.get("id", ""))
		button.set_meta("choice_id", choice_id)
		button.pressed.connect(func() -> void: selected.emit(choice_id))
		choices.add_child(button)
		buttons.append(button)
	for index in range(buttons.size()):
		if not buttons[index].disabled:
			_select_index(index)
			break
	_update_back_hint()
	speaking_changed.emit(_line_remaining > 0.0 and not _presentation_paused)


func estimated_line_seconds(text: String) -> float:
	# Around 156 spoken words/minute plus a short reading/phrase allowance.
	var words := text.replace("\n", " ").split(" ", false).size()
	var pauses := text.count(".") + text.count(",") + text.count(";") + text.count("!") + text.count("?")
	return maxf(2.2, 0.65 + float(words) / 2.6 + float(pauses) * 0.15)


func set_presentation_paused(paused: bool) -> void:
	_presentation_paused = paused
	voice_player.stream_paused = paused
	speaking_changed.emit(visible and _line_remaining > 0.0 and not paused)


func _process(delta: float) -> void:
	if not visible or _presentation_paused or _line_remaining <= 0.0:
		return
	_update_voice_gesture(delta)
	_line_remaining = maxf(0.0, _line_remaining - delta)
	if _line_remaining <= 0.0:
		_finish_line()


func _finish_line() -> void:
	if _player_reply:
		_player_reply = false
		_line_remaining = 0.0
		voice_player.stop()
		speaking_changed.emit(false)
		player_reply_finished.emit(true)
		return
	var return_to_questions := _is_response
	_is_response = false
	_line_remaining = 0.0
	voice_player.stop()
	speaking_changed.emit(false)
	if return_to_questions:
		response_finished.emit()

func hide_panel() -> void:
	_abort_reply()
	visible = false
	_is_response = false
	_line_remaining = 0.0
	_presentation_paused = false
	_reset_letterbox()
	voice_player.stop()
	speaking_changed.emit(false)

func set_input_mode(controller: bool) -> void:
	_using_controller = controller
	_update_back_hint()

func _update_back_hint() -> void:
	if _is_response or _player_reply:
		back_hint.text = "Ⓑ Skip response" if _using_controller else "Esc: Skip response"
	else:
		back_hint.text = "D-pad/stick: Choose · Ⓐ Confirm · Ⓑ Leave" if _using_controller else "↑/↓: Choose · Enter: Confirm · Esc: Leave"

func _select_index(index: int) -> void:
	selected_index = index
	buttons[index].grab_focus()
	_ensure_current_choice_visible.call_deferred()

func _ensure_current_choice_visible() -> void:
	# A response can replace the menu before deferred layout has completed.
	if selected_index >= 0 and selected_index < buttons.size():
		_choice_scroll.ensure_control_visible(buttons[selected_index])

func _move_selection(direction: int) -> void:
	if buttons.is_empty() or selected_index < 0:
		return
	for step in range(1, buttons.size() + 1):
		var index: int = posmod(selected_index + direction * step, buttons.size())
		if not buttons[index].disabled:
			_select_index(index)
			return

func _input(event: InputEvent) -> void:
	if not visible:
		return
	input_observed.emit(event)
	if event.is_echo():
		return
	if event.is_action_pressed("dialogue_back"):
		if _is_response or _player_reply:
			_finish_line()
		else:
			cancelled.emit()
	elif event.is_action_pressed("dialogue_up"):
		_move_selection(-1)
	elif event.is_action_pressed("dialogue_down"):
		_move_selection(1)
	elif event.is_action_pressed("dialogue_confirm"):
		if selected_index >= 0 and not buttons[selected_index].disabled:
			selected.emit(str(buttons[selected_index].get_meta("choice_id")))
	else:
		return
	get_viewport().set_input_as_handled()

func play_player_reply(text: String, audio: AudioStream) -> bool:
	# Rules have accepted the choice already. This presentation interval only
	# delays the NPC reply; it never resubmits the choice or its effects.
	show_view({"speaker":"Tessa Ward", "text":text, "choices":[]}, false)
	_player_reply = true
	_is_response = false
	voice_player.stream = audio
	_line_remaining = audio.get_length() + 0.2
	voice_player.play()
	voice_player.stream_paused = _presentation_paused
	_update_back_hint()
	speaking_changed.emit(not _presentation_paused)
	return await player_reply_finished

func _abort_reply() -> void:
	if _player_reply:
		_player_reply = false
		player_reply_finished.emit(false)

func _update_voice_gesture(delta: float) -> void:
	# Let a phrase breathe: authored silence stops the talk gesture as well as
	# the voice. These body rigs have no facial blendshapes to drive lip acting.
	var stream := voice_player.stream as AudioStreamWAV
	if stream == null or stream.format != AudioStreamWAV.FORMAT_16_BITS or stream.stereo: return
	var data := stream.data
	var offset := int(voice_player.get_playback_position() * stream.mix_rate) * 2
	var peak := 0
	for sample in range(offset, mini(offset + 480, data.size() - 1), 2):
		peak = maxi(peak, absi(data.decode_s16(sample)))
	_voice_quiet = _voice_quiet + delta if peak < 180 else 0.0
	var speaking_now := voice_player.playing and _voice_quiet < .16
	if speaking_now != _voice_gesture_active:
		_voice_gesture_active = speaking_now
		speaking_changed.emit(speaking_now)
