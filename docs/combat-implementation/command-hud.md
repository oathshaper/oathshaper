# Command HUD queue and input refinement

Date: 2026-10-22. Status: **implemented and verified as a UI projection; root verifies integrated input/rules**. Owned changes are limited to `godot/scripts/command_hud.gd` and this note. Existing root changes in that HUD (including the Trial button) are preserved. No stage, trial, core, bridge or shared test file was edited.

## Public interface

Existing `requested(action: Dictionary)`, `_buttons`, `actor(id)`, `set_category(index)`, `page_actions(direction)`, `choose_number(index)` and `show_message(message)` remain available. The new public method is:

```gdscript
hud.set_input_device(true)  # controller
hud.set_input_device(false) # keyboard/mouse
```

Root chooses the device from its own input routing. Repeating the same value is a no-op. The HUD does not register global shortcuts or take ownership of the action selector.

Keyboard hints follow the current host mapping: Tab cycles party, F1–F3 choose portraits, I/C opens the ledger, Space pauses, 1–6 chooses the visible hotbar, Q opens actions, E performs the default attack. Controller hints show LB/RB party, X actions, Menu ledger, View pause, D-pad focus, A choose and B back. Selector-specific Q/E or LB/RB category routing remains root-owned and is not advertised as a world shortcut.

## Queue editing

Clicking/focusing and confirming `_buttons["queue:" + action_id]` selects that future order locally. Selection does not remove it or change any reservation. The HUD then exposes:

| Key | Effect |
| --- | --- |
| `queue_earlier` | Emits `queue.reorder` with the complete current order-ID list after one adjacent earlier swap |
| `queue_later` | Emits `queue.reorder` with the complete current order-ID list after one adjacent later swap |
| `queue_remove` | Emits `queue.remove` for the selected stable action ID and current recipient |
| `clear` | Existing `queue.clear_future`; disabled when no future orders exist |
| `stop` | Existing `ui.stop`; root still confirms paid interruption/recovery |

Earlier/Later are disabled at the ends. Queue tooltips identify the ability, known target, human source, reserved costs and projected failure reasons. The active action is displayed separately and cannot enter the future-order editor. Reorder computes a proposed ID list without changing the view; the controller/core publishes the accepted result. A removed/activated selection disappears when the next authoritative view no longer contains it.

The existing native trial test must select a queue tile and then press `queue_remove` where it formerly expected tile-click removal. Root was notified of this interaction change before implementation.

## Action cues and source identity

Unavailable/ghost actions have genuinely disabled buttons, a readable reason line and a tooltip containing the full projected reason list. Number selection of a blocked action reports its reason without emitting a targeting request. Unknown actions are omitted. Action tooltips include the human source label, costs, target type, range/radius and recovery where provided.

The HUD uses `source_label` verbatim. If the current core still sends its grant ID as the label, it applies only typography (word separators/capitalization), without inferring a source rule. `flow_design` was asked to provide named learned/equipment source labels in its own core scope. Exact grant identity remains in the authoritative view; the HUD does not create or replace it.

Action clicks and `choose_number` now emit `ui.choose_action {ability_id, source_id}`. Each row/focus key is `action:<ability_id>:<source_id>`, so learned and equipment grants of one ability remain distinct. The first visible source also retains the compatibility alias `_buttons["action:" + ability_id]`; that alias does not change what the actual row emits. A lost source falls back to the category rather than silently rebinding. Root accepts the optional source ID, preserves it through its selector, and owns equipped-weapon default attack selection.

## Stable state and focus

Each recipient has independent category, action page, last action/category/queue focus key and selected future order. These preferences live in the HUD instance, not the combat save or a second resource model. Returning to a character restores that context if the control still exists. If an order/action disappears or becomes disabled, focus falls back to the current category, selected portrait or Pause. A view refresh does not steal focus from an external modal/world context.

`_clear` removes dynamic entries from `_buttons` **before** detaching/queue-freeing controls, including references that are still valid until the end of the frame. The registry therefore does not expose freed or detached party/action/queue controls. Dispatch validates the current control and suppresses disabled/preview requests.

The interaction fingerprint includes only displayed party/queue/action facts. Actor positions, unrelated actor properties and tick-only updates do not rebuild controls; time, resource summaries, pause labels and logs still refresh. This preserves a focused control while actors move.

## Layout and verification

The party rail is 228 pixels wide, with compact `current / maximum HP` captions, visible F1–F3 labels on keyboard, and one-line AI/queue status. The bottom panel expands for the selected-order editor; party cycling remains visible above it. Long action/queue names retain full tooltips, while compact reason cues keep failure meaning on-screen. Objectives come from the view rather than a fixed sample chapter.

Godot 4.3 script parsing passed. The bounded temporary driver `/tmp/oathshaper_command_hud_test.gd` uses explicit synthetic `CommandView` fixtures and checks:

- Complete earlier/later/remove payloads and no speculative queue mutation.
- Disabled action mouse/number behavior and human source tooltip.
- No rebuild for actor-position/tick-only changes.
- Immediate stale-registry cleanup and stable focus fallback after removal.
- Independent per-character category/page/focus restoration, including distinct grants of the same ability and no implicit rebinding on source loss.
- Device-specific hints and preview request suppression.
- 1280×800 bounds and absence of party/editor overlap, including all four waiting orders.

The rendered run passed **139 checks with zero failures**, including source-specific click/number requests, duplicate ability sources and focus recovery after source removal. Both keyboard/three-order and controller/four-order images were visually inspected. Artifacts: `/tmp/oathshaper-command-hud-queue.png` and `/tmp/oathshaper-command-hud-controller.png`. These fixture results do not establish live gameplay, physical-controller feel or queue-rule correctness; root runs the integrated trial checks.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --check-only --script res://scripts/command_hud.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot \
  --script /tmp/oathshaper_command_hud_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 \
  --script /tmp/oathshaper_command_hud_test.gd -- --capture
git diff --check -- godot/scripts/command_hud.gd docs/combat-implementation/command-hud.md
```

Both owned files are left uncommitted for root. No resident restart, broad build, dependency update or workflow automation operation was used.
