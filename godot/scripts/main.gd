extends Node
const DEMO_SCENE := preload("res://scenes/demo.tscn")
const FRONTEND := preload("res://scripts/combat_frontend.gd")
const AUDIO := preload("res://scripts/game_audio.gd")
const SAVE := preload("res://scripts/save_store.gd")
@export var save_path := SAVE.HUB_PATH
var _demo: Node3D
var _frontend: Control
var _busy := false
var _trial: Control
var _trial_from_campaign := false
var _trial_profile := "command"
var _confrontation: Node3D

func _ready() -> void:
	AUDIO.ensure(self)
	var overlay := CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	_frontend = FRONTEND.new()
	overlay.add_child(_frontend)
	_frontend.new_game.connect(_start_new)
	_frontend.load_game.connect(_start_load)
	_frontend.profile_selected.connect(_apply_style)
	_frontend.cancelled.connect(_return_to_ledger)
	_frontend.trial_requested.connect(_open_command_trial)
	var saved := SAVE.load(save_path)
	_frontend.open_title(FileAccess.file_exists(save_path), "", str(saved.get("data", {}).get("combat_profile", "command")))

func _start_new(profile_id: String) -> void:
	_open_demo(profile_id, false)

func _start_load(profile_id: String) -> void:
	_open_demo(profile_id, true)

func _open_demo(profile_id: String, loading: bool, opening := true) -> void:
	if _busy:
		return
	_busy = true
	# A failed load never destroys the running journey.
	var candidate := DEMO_SCENE.instantiate() as Node3D
	candidate.save_path = save_path
	add_child(candidate)
	if candidate.bridge == null or (loading and not candidate.load_journey()):
		var message := str(candidate.status.text)
		remove_child(candidate)
		candidate.queue_free()
		_frontend.show_error(message)
		_busy = false
		return
	candidate.set_combat_profile(profile_id)
	if is_instance_valid(_demo):
		remove_child(_demo)
		_demo.queue_free()
	_demo = candidate
	_demo.sync_combat_input()
	_demo.combat_style_requested.connect(_choose_style)
	_demo.new_game_requested.connect(_choose_new_journey)
	_demo.chapter_requested.connect(func(profile: String) -> void: _open_chapter(profile, true))
	_frontend.close_frontend()
	if not loading and opening:
		_demo.play_opening()
	_busy = false

func _suspend_demo() -> void:
	_demo.process_mode = Node.PROCESS_MODE_DISABLED
	_demo.get_node("CanvasLayer").hide()

func _choose_style() -> void:
	_suspend_demo()
	_frontend.open_style_picker(_demo.combat_profile())

func _choose_new_journey() -> void:
	_suspend_demo()
	_frontend.open_picker(_demo.combat_profile(), FileAccess.file_exists(save_path), "", "new", true)

func _return_to_ledger() -> void:
	_frontend.close_frontend()
	_demo.process_mode = Node.PROCESS_MODE_INHERIT
	_demo.get_node("CanvasLayer").show()
	_demo.sync_combat_input()
	_demo.journal.focus_current_page()

func _apply_style(profile_id: String) -> void:
	_demo.set_combat_profile(profile_id)
	_return_to_ledger()

func _open_command_trial() -> void:
	_open_chapter(_frontend._selected, false)

func _open_chapter(profile: String, from_campaign: bool, play_intro := true) -> void:
	if is_instance_valid(_trial) or is_instance_valid(_confrontation):
		return
	var path := "res://scripts/%s_trial.gd" % profile
	if profile not in ["command", "flow", "vanguard"] or not ResourceLoader.exists(path):
		if from_campaign:
			_demo._show_status("This combat style is coming soon. Choose Command, Flow or Vanguard in the Ledger.")
		else:
			_frontend.show_error("This combat style is not available yet.")
		return
	if from_campaign and play_intro:
		_confrontation = preload("res://scripts/garden_confrontation.gd").new()
		_confrontation.demo = _demo
		_confrontation.finished.connect(func() -> void:
			_confrontation = null
			# The skip event belongs to the cinematic, never to the new combat UI.
			_open_chapter.call_deferred(profile, true, false)
		)
		_demo.add_child(_confrontation)
		return
	AUDIO.ensure(self).context = "quay"
	_trial_from_campaign = from_campaign
	_trial_profile = profile
	if from_campaign:
		_suspend_demo()
		_demo.hide()
	_frontend.hide()
	_frontend.process_mode = Node.PROCESS_MODE_DISABLED
	_trial = load(path).new()
	_trial.campaign_mode = from_campaign
	_trial.play_intro = not from_campaign
	_frontend.get_parent().add_child(_trial)
	_trial.stage.set_beacon_lit(not from_campaign or bool(_demo._story_state.flags.get("oil_shared", false)) or bool(_demo._story_state.flags.get("pay_returned", false)))
	_trial.finished.connect(_close_command_trial)

func _close_command_trial() -> void:
	var won := false
	var profile: String = _trial_profile
	if is_instance_valid(_trial):
		won = _trial.has_won()
		_trial.get_parent().remove_child(_trial)
		_trial.queue_free()
	_trial = null
	_frontend.process_mode = Node.PROCESS_MODE_INHERIT
	if won and not _trial_from_campaign:
		if not is_instance_valid(_demo):
			_open_demo(profile, false, false)
		# A menu chapter starts at the garden. Establish only its prerequisite
		# facts; oil, optional records and payroll collection remain untouched.
		_demo.prepare_garden_demo()
		_trial_from_campaign = true
	if _trial_from_campaign:
		_trial_from_campaign = false
		_frontend.close_frontend()
		_demo.process_mode = Node.PROCESS_MODE_INHERIT
		_demo.show()
		_demo.get_node("CanvasLayer").show()
		_demo.finish_garden_chapter(won)
		_demo.sync_combat_input()
		return
	AUDIO.ensure(self).context = "title"
	_frontend.show()
	if is_instance_valid(_frontend._inspector):
		_frontend._inspector._tabs[0].grab_focus()
	elif not _frontend._buttons.is_empty():
		_frontend._buttons[0].grab_focus()
