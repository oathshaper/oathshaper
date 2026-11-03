# Native Command party ledger

Date: 2026-10-22. Status: **implemented UI projection; root integration and live Command acceptance pending**. This file documents `godot/scripts/command_ledger.gd`. It does not claim that fixture UI tests prove gameplay, physical controller feel, storage persistence or the facade's equipment/progression rules.

## Controller attachment

```gdscript
var ledger := preload("res://scripts/command_ledger.gd").new()
add_child(ledger)
ledger.requested.connect(_on_command_ui_request)
# After the controller acquires its own ledger pause token:
ledger.open(current_command_view)
# On every authoritative refresh:
ledger.apply_view(current_command_view)
# Only while ledger is the top context:
if ledger.visible and ledger.handle_input(event):
    get_viewport().set_input_as_handled()
# The root closes nested contexts first, then closes this ledger and releases its token:
ledger.close()
```

`open(view: Dictionary)`, `apply_view(view: Dictionary, force := false)` and `close()` never acquire/release pause tokens or advance simulation. `close()` hides the control without emitting a second close request. The visible Close button emits `{"kind":"ui.close_ledger"}`. Root owns Escape/B, held-input suppression, targeting, nested comparison/confirmation, and pause ownership. No global input callback in the ledger competes with those contexts.

Set `interaction_enabled = false` while a comparison or confirmation owns the input context; requests and explicit tab/actor navigation are suppressed. Root must route input only to the top context and restore focus appropriately after dismissing its modal. `handle_input` handles LB/RB or Ctrl+PageUp/PageDown for tabs, and L3/R3 or brackets for inspection. Brackets remain text input when an edit field owns focus. Tab and directional focus neighbors stay within the ledger. Native OptionButton popups retain their standard Godot interactions.

### Outbound requests

| Request | Purpose |
| --- | --- |
| `party.inspect {actor_id}` | Select a sheet, including reserve actors; never changes recipient/possession/camera locally |
| `ui.preview {action}` | Complete authored equipment, set, progression, skill, craft, shop or other capability action; root previews and confirms through the facade |
| `ui.inventory_use {actor_id,item_id}` | Root starts ordinary item targeting/queue flow for this explicit actor, preserving the order recipient |
| `ai.configure {actor_id,policy,empty_policy,hold_after_orders}` | Explicit full AI setting edit for inspected actor |
| `ui.save`, `ui.load` | Root's dedicated trial slot, load confirmation and storage error handling |
| `ui.close_ledger` | Request root dismissal and owned pause-token release |

No outgoing message includes a lease, generation, command ID, entropy, replacement view or invented resource change. The controller constructs current transport envelopes. Complete metadata actions retain their expected build/binding versions; preview is not authorization to submit a stale plan.

## View contract

The ledger reads only `command.view/v1` and the agreed extensions below. Original portrait files are selected by known actor identity; all resources, build facts, item quantities, statuses and choices come from the view. There is no dependency on the old presentation catalog. Mercy is labeled **Trial neutral** beside the avatar, with an explicit statement that this practice trial assigns no campaign morality; no invented morality score/bar is shown.

- `party.inspected_id` selects portrait, equipment and progression. `party.recipient_id` is shown separately. Reserve actors remain inspectable and cannot start an item order.
- Character displays classes, XP/levels, attributes, attack/defense/saves, skills and unspent budgets. Progression plans remain unavailable when the core exposes no complete plan. A chosen preset displays every initial attribute, serial level/class, rank purchase, feat, power, attribute increment and unbind before Compare becomes actionable.
- Equipment displays actual body slots and owned-instance names, metadata plans, lock/rejection reasons and active/alternate sets. Two-hand occupancy uses the exact complete metadata action; no guessed slot aliases or duplicated item instances.
- Powers displays the inspected actor's learned powers and feats. Current action costs/source/availability are shown only when inspected equals recipient, since top-level `actions` belongs to the recipient. Unknown actions are omitted, blocked known entries remain visible.
- Party exposes roster status and exact AI settings. It does not implement deployment swaps through inspection.
- Inventory provides name search (Enter to apply), container and usable/equipment/reserved/favorite/quest filters, item lists beside details, free/reserved counts, source grants, occupancy and permitted-operation reasons. Use requests the ordinary scheduler path. Equipment and economy operations reach comparison through authored metadata.
- Journal shows only projected objective, known skill checks and visible logs, plus exposed skill/camp/encounter capabilities. Save routes dedicated-slot requests to root.

### Metadata agreed with `flow_design`

These are view-only extensions, not a new action parser or UI-owned rule catalog:

```text
equipment.options[] = {
  id, label, item_id: string|null, slot_ids: string[],
  action: complete equipment.apply action, available, reasons
}
progression.presets[] = {
  id, name, description, action: complete progression.level|progression.respec,
  available, reasons
}
capabilities[] = {
  id, label, description, action: complete typed action, available, reasons
}
inventory.items[] additionally exposes:
  category, description, compatible_slots, occupies_slots, grants
```

Equipment options include null-item unbind plans and all occupancy/unbind changes; the UI filters options by selected slot and forwards `action` unchanged. The first agreed progression preset is the fully implemented clerk level-seven allocation; future unavailable respec must not fabricate a plan. Capability descriptions identify authored prices/materials/crafter where relevant. The core is responsible for only exposing legal known choices and complete payloads. Missing optional metadata produces an explicit unavailable/empty projection, never sample inventory or hidden allocation defaults.

## Verification

Owned test: `godot/tests/command_ledger_test.gd`. Fixtures are explicitly synthetic UI snapshots, not real class construction, recipe legality or simulation evidence. The test exercises every tab, resource projection, inspect-versus-recipient ownership, complete two-hand and progression payloads, queue-targeting requests, metadata economy routing, AI settings, reserve restrictions, B ownership, confirmation lock, focus containment, input scope, source-view immutability and 1280×800 bounds.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --check-only --script res://scripts/command_ledger.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --script res://tests/command_ledger_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 \
  --script res://tests/command_ledger_test.gd -- --capture
git diff --check -- godot/scripts/command_ledger.gd \
  godot/tests/command_ledger_test.gd docs/combat-implementation/command-ledger.md
```

Verification passed on Godot 4.3: script parse check; **269 assertions / zero failures** headless; **271 assertions / zero failures** with rendering (two additional capture-selection assertions). Both 1280×800 inventory and equipment captures were visually inspected. Owned-file trailing-whitespace and newline checks also passed; `git diff --check` reported no tracked whitespace errors.

The rendered check runs its own short fixture process, does not restart a resident, and exports `/tmp/oathshaper-command-ledger.png` and `/tmp/oathshaper-command-ledger-equipment.png`. Root commits these three owned files together; this worker does not stage or commit concurrent stage/HUD/bridge/core changes.

## Remaining integration gates

1. Root connects requests, acquires/releases exactly the ledger's pause token, protects nested modal focus and preserves recipient through inventory targeting.
2. Actual `CommandGame::view` supplies the agreed metadata; real preview/confirm results must reflect equipment locks, resource debt, source revocation and progression legality.
3. Native user runs verify keyboard/controller navigation, comparison cancellation, save/load failure, and restored paid queues with the integrated 3D trial. Fixture projections do not establish these results.
