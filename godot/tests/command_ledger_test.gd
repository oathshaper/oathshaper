extends SceneTree
## Bounded synthetic CommandView fixtures test UI projection/routing, never combat mechanics.
var failures := 0
var assertions := 0
var requests: Array[Dictionary] = []
var ledger: Control

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		push_error(message)

func pool(current: int, maximum: int, reserved := 0) -> Dictionary:
	return {"current": current, "maximum": maximum, "reserved": reserved, "free": current - reserved, "debt": maximum - current}

func member(id: String, display: String, status: String, hp: int, focus: Variant) -> Dictionary:
	return {"id": id, "name": display, "faction": "party", "body": "organic", "roster_status": status, "conscious": true, "position": null if status == "reserve" else [0, 0], "health": pool(hp, hp), "focus": focus, "battery": pool(3, 3) if id == "clerk" else null, "stats": {"level": 6, "defense": 12, "attack": 4, "power_dc": 16 if focus != null else null, "saves": {"fortitude": 3, "reflex": 4, "will": 5}}, "conditions": [], "active_action": null, "queue": [], "ai": {"policy": "balanced", "empty_policy": "role", "hold_after_orders": false, "last_reason": null}, "knowledge": "party"}

func fixture(inspected := "mara") -> Dictionary:
	var equipment_action := {"kind": "equipment.apply", "actor_id": inspected, "expected_binding_version": "bind-9", "changes": [{"slot_id": "main_hand", "item_id": "staff-1"}, {"slot_id": "offhand", "item_id": "staff-1"}], "cancel_action_ids": []}
	var level_plan := {"kind": "progression.level", "actor_id": inspected, "expected_build_version": "build-1", "class_id": "scout", "skills": [{"id": "devices", "ranks": 2}, {"id": "lore", "ranks": 2}, {"id": "medicine", "ranks": 2}], "feats": ["marksmanship_ii"], "powers": [], "attributes": [], "unbind_item_ids": []}
	return {
		"schema": "command.view/v1", "session": {"profile_id": "command", "generation": "1", "epoch": "1", "revision": "7", "ledger_sequence": "8", "content_hash": "ui-fixture-only", "tick": 10, "tick_ms": 100, "phase": "camp"},
		"clock": {"paused": true, "can_advance": false, "pause_reasons": [{"token": "opaque", "owner": "ledger", "label": "Party ledger", "acknowledgeable": false}]},
		"party": {"roster_ids": ["player", "mara", "clerk", "ivo"], "deployed_ids": ["player", "mara", "clerk"], "recipient_id": "player", "possessed_id": "player", "inspected_id": inspected, "camera_follow_id": "player"},
		"actors": [member("player", "Tessa Ward", "deployed", 80, null), member("mara", "Mara", "deployed", 50, pool(38, 56, 10)), member("clerk", "Civic clerk", "guest_deployed", 62, null), member("ivo", "Ivo", "reserve", 71, null)],
		"actions": [{"id": "recipient_only_marker", "name": "Recipient-only action", "category": "weapon", "rank": 1, "source_id": "source-1", "source_label": "Equipped blade", "target_kind": "enemy", "range_m": 2, "radius_m": null, "costs": [], "available": true, "reasons": [], "cooldown_remaining_ticks": 0, "known": true, "ghost": false}], "targets": [],
		"equipment": {"actor_id": inspected, "binding_version": "bind-9", "body": "organic", "slots": [{"id": "main_hand", "item_id": null}, {"id": "offhand", "item_id": null}], "active_set_id": "set-1", "sets": [{"id": "set-1", "name": "Primary", "main_hand": null, "offhand": null}], "options": [{"id": "staff-plan", "label": "Equip survey staff · both hands", "item_id": "staff-1", "slot_ids": ["main_hand", "offhand"], "action": equipment_action, "available": true, "reasons": []}]},
		"inventory": {"currency": {"credits": 99}, "containers": [{"id": "party_pack", "name": "Party pack", "accessible": true}], "items": [
			{"id": "dressing-1", "definition_id": "dressing", "name": "Field dressing", "container_id": "party_pack", "quantity": 2, "reserved": 1, "free": 1, "bound_actor_id": null, "bound_slots": [], "binding_version": "0", "host_item_id": null, "favorite": true, "quest_protected": false, "accessible": true, "reasons": [], "operations": [{"kind": "inventory.use", "available": true, "reasons": []}], "category": "consumable", "description": "UI fixture dressing description.", "compatible_slots": [], "occupies_slots": [], "grants": []},
			{"id": "staff-1", "definition_id": "staff", "name": "Survey staff", "container_id": "party_pack", "quantity": 1, "reserved": 0, "free": 1, "bound_actor_id": null, "bound_slots": [], "binding_version": "0", "host_item_id": null, "favorite": false, "quest_protected": false, "accessible": true, "reasons": [], "operations": [{"kind": "equipment.apply", "available": true, "reasons": []}], "category": "weapon", "description": "UI fixture staff description.", "compatible_slots": ["main_hand"], "occupies_slots": ["main_hand", "offhand"], "grants": ["staff_attack"]}
		]},
		"progression": {"actor_id": inspected, "build_version": "build-1", "xp": 2100, "level": 6, "pending_levels": 1, "classes": [{"id": "scout", "level": 3}, {"id": "storm_mystic", "level": 3}], "attributes": [{"id": "spirit", "base": 3, "gear": 0, "total": 3}], "skills": [{"id": "medicine", "rank": 3, "governing_modifier": 1, "bonus": 0, "total": 4, "max_rank": 7}], "feats": [{"id": "fieldwork", "rank": 1}], "powers": [{"id": "binding_current", "rank": 1, "source_id": "learned:bind"}], "unspent": {"skill_points": 6, "feat_choices": 1, "power_choices": 0, "attribute_points": 0}, "next_choices": [{"kind": "skill", "id": "devices", "cost": 1, "available": true, "reasons": []}], "respec": {"cost": 100, "currency": "credits", "available": false, "reasons": [{"code": "credits", "message": "Requires 100 credits"}]}, "presets": [{"id": "level-7", "name": "Scout level seven", "description": "Complete fixture plan: three skill purchases and Marksmanship II.", "action": level_plan, "available": true, "reasons": []}]},
		"world_actions": [{"id": "gate", "name": "Survey gate", "checker_id": "clerk", "helper_id": null, "dc": 14, "costs": [], "available": true, "reasons": []}],
		"capabilities": [{"id": "craft-kit", "label": "Assemble field kit", "description": "4 scrap and 20 credits; trained crafter: Civic clerk.", "action": {"kind": "craft", "recipe_id": "fixture-recipe", "crafter_id": "clerk", "quantity": 1}, "available": true, "reasons": []}],
		"logs": [{"id": "event-1", "tick": 10, "kind": "trial", "actor_id": null, "target_id": null, "text": "Visible test event", "details": {"roll": null, "modifier": null, "threshold": null, "damage": null, "healing": null, "resource_delta": null}}], "log_cursor": "event-1", "encounter": {"id": null, "objective": "Synthetic UI projection fixture", "status": "none", "can_retreat": false, "outcome": null, "reward_receipt_id": null, "checkpoint_id": null, "camp_id": "garden_camp", "trial": true}, "space": {"waiting": false, "reason": null}
	}

func text_of(node: Node) -> String:
	var copy := str(node.text) + "\n" if node is Label or node is BaseButton else ""
	for child in node.get_children():
		copy += text_of(child)
	return copy

func click(key: String) -> void:
	var button: Button = ledger._buttons.get(key)
	check(button != null, "Expected button: " + key)
	if button != null:
		check(not button.disabled, "Button available: " + key)
		button.pressed.emit()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	ledger = preload("res://scripts/command_ledger.gd").new()
	root.add_child(ledger)
	ledger.requested.connect(func(action: Dictionary) -> void: requests.append(action))
	var view := fixture()
	var original := JSON.stringify(view)
	ledger.open(view)
	await process_frame
	await process_frame
	check(text_of(ledger).contains("Focus  38 / 56"), "Projected current Focus is shown without recomputation")
	check(text_of(ledger).contains("10 reserved · 28 free"), "Reserved and free values remain distinct")
	check(text_of(ledger).contains("Mercy · Neutral"), "Mercy appears near the character portrait")
	check(not text_of(ledger).contains("Recipient-only action"), "Character tab cannot use recipient actions as inspected build")
	click("inspect:ivo")
	check(requests.back() == {"kind": "party.inspect", "actor_id": "ivo"}, "Reserve portrait emits inspect only")
	check(ledger._view.party.recipient_id == "player", "Inspection request does not locally change recipient")
	ledger._select_tab(1)
	click("slot:main_hand")
	click("gear:staff-plan")
	check(requests.back() == {"kind": "ui.preview", "action": view.equipment.options[0].action}, "Both-hand plan forwards exact core metadata to preview")
	check(requests.back().action.changes.size() == 2, "Two-hand plan retains both occupancy entries")
	ledger._select_tab(2)
	check(text_of(ledger).contains("Binding Current"), "Inspected powers are shown")
	check(not text_of(ledger).contains("Recipient-only action"), "Inspected companion does not borrow recipient availability")
	ledger._select_tab(3)
	click("ai_apply")
	check(requests.back() == {"kind": "ai.configure", "actor_id": "mara", "policy": "balanced", "empty_policy": "role", "hold_after_orders": false}, "AI edit carries inspected actor and full policy")
	ledger._select_tab(4)
	click("item:dressing-1")
	click("inventory_use")
	check(requests.back() == {"kind": "ui.inventory_use", "actor_id": "mara", "item_id": "dressing-1"}, "Inventory Use asks root for the same targeting/queue path")
	click("capability:craft-kit")
	check(requests.back() == {"kind": "ui.preview", "action": view.capabilities[0].action}, "Craft recipe/crafter/cost intent is metadata-owned")
	ledger._filter = "reserved"
	ledger._render()
	check(ledger._buttons.has("item:dressing-1") and not ledger._buttons.has("item:staff-1"), "Reservation filter changes projection only")
	ledger._filter = "all"
	ledger._select_tab(0)
	click("preset:level-7")
	check(text_of(ledger).contains("Devices +2 ranks") and text_of(ledger).contains("Marksmanship Ii"), "Complete preset allocation is visible before preview")
	click("preset_preview")
	check(requests.back() == {"kind": "ui.preview", "action": view.progression.presets[0].action}, "Progression sends complete plan with build version")
	var before := requests.size()
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	check(not ledger.handle_input(back), "B remains root-owned for nested context dismissal")
	check(requests.size() == before, "B cannot issue a gameplay command")
	var next := InputEventJoypadButton.new()
	next.button_index = JOY_BUTTON_RIGHT_STICK
	next.pressed = true
	check(ledger.handle_input(next), "Controller inspect cycle handled in ledger context")
	check(requests.back() == {"kind": "party.inspect", "actor_id": "clerk"}, "Inspection cycle preserves recipient and possession")
	ledger.interaction_enabled = false
	before = requests.size()
	ledger._request({"kind": "ui.save"})
	check(not ledger.handle_input(next) and requests.size() == before, "Confirmation lock prevents request/input leakage")
	ledger.interaction_enabled = true
	ledger._select_tab(5)
	check(text_of(ledger).contains("Visible test event"), "Journal renders projected event text")
	ledger._select_tab(6)
	click("save_trial")
	check(requests.back() == {"kind": "ui.save"}, "Save delegates dedicated-slot persistence")
	click("load_trial")
	check(requests.back() == {"kind": "ui.load"}, "Load delegates confirmation and restore")
	check(JSON.stringify(view) == original, "No UI interaction mutates the supplied view")
	var reserve_view := fixture("ivo")
	ledger.apply_view(reserve_view)
	check(ledger._view.party.recipient_id == "player", "Reserve view refresh preserves recipient")
	ledger._select_tab(4)
	click("item:dressing-1")
	check(ledger._buttons.inventory_use.disabled, "Reserve inspection cannot start an item order")
	ledger._select_tab(0)
	await process_frame
	await process_frame
	check(ledger._buttons.close.size.x >= 180, "Close caption retains visible width")
	check(ledger.size == Vector2(1280, 800), "Ledger uses 1280x800 viewport")
	check(ledger._page.get_global_rect().end.x <= 1263, "Page does not overflow viewport horizontally")
	for tab in range(7):
		ledger._select_tab(tab)
		await process_frame
		check(ledger._scroll.get_global_rect().end.x <= 1263, "Tab %d scroll frame fits width" % tab)
		check(ledger._scroll.size.y > 300, "Tab %d retains readable scroll area" % tab)
		var focusables: Array[Control] = []
		ledger._collect_focus(ledger, focusables)
		for control in focusables:
			check(ledger.is_ancestor_of(control.get_node(control.focus_next)), "Tab focus stays in ledger")
			check(ledger.is_ancestor_of(control.get_node(control.focus_neighbor_bottom)), "Controller focus stays in ledger")
	ledger._select_tab(4)
	ledger._filter = "all"
	ledger.apply_view(view, true)
	click("item:dressing-1")
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-ledger.png")
		ledger._select_tab(1)
		click("slot:main_hand")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/oathshaper-command-ledger-equipment.png")
	ledger.close()
	check(not ledger.handle_input(next), "Hidden ledger cannot intercept gameplay input")
	print("COMMAND_LEDGER_TEST: %d assertions, %d failures (UI projection only)" % [assertions, failures])
	quit(1 if failures else 0)
