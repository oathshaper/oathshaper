# Dialogue authoring

Edit `godot/content/lantern_quay.json` as UTF-8 JSON. Keep story, node, and choice IDs stable after release; change the story `revision` when edits make existing saves incompatible. Nodes hold `speaker`, `text`, optional `voice`, optional ordered `variants`, and `choices`. Each choice has an ID, text, a target node or `$exit` in `next`, optional `when` conditions, optional `hide_when` and `disable_when` rules, an optional `locked_reason`, and optional `effects`.

```json
{"id":"share_oil","text":"Share the oil.",
 "when":[{"kind":"flag","id":"oil_decided","value":false}],
 "hide_when":[[{"kind":"flag","id":"oil_decided","value":true}]],
 "effects":[{"kind":"set_flag","id":"oil_shared","value":true},
            {"kind":"set_flag","id":"oil_decided","value":true},
            {"kind":"add_moral","amount":2},
            {"kind":"add_affinity","companion":"ivo","amount":1}],
 "next":"mara_thanks"}
```

Declare flag IDs in `flags`, companion IDs in `companions`, and the moral value's `id`, label, bounds, and initial value in `moral`. `when` is an AND list. `hide_when` is an OR list of nonempty AND lists: use it when a choice has been spent or its branch has closed. A hidden choice is also rejected if its ID is submitted directly. A choice with unmet `when` conditions remains visible with a lock glyph and its `locked_reason` (or a generic fallback); controller focus skips it. `disable_when` keeps a choice visible but unavailable. Its ordered rules each have a nonempty `when` list and `reason`; the first matching rule wins before ordinary requirements. Set `completed: true` to show a check mark for a previously asked question. The same disabled choice is rejected if submitted directly.

```json
{"id":"ask_for_favor","text":"Ask where Ivo stands watch.",
 "when":[{"kind":"flag","id":"oil_shared","value":true},
         {"kind":"moral_at_least","value":2},
         {"kind":"affinity_at_least","companion":"ivo","value":1}],
 "disable_when":[{"when":[{"kind":"flag","id":"ivo_where_asked","value":true}],
                  "reason":"Already asked","completed":true}],
 "effects":[{"kind":"set_flag","id":"ivo_where_asked","value":true}],
 "next":"tide_gate"}
```

An authored choice with `"next":"$exit"` commits any effects, emits its stable choice event, and ends the conversation. Question menus include a Leave choice; B/Esc at a menu also leaves. The scene returns to exploration when the returned view has `in_dialogue: false`. Supported checks are `flag`, `moral_at_least`, and `affinity_at_least`; effects are `set_flag`, `add_moral`, and `add_affinity`. Effects either all commit or all fail. Conditions on variants are evaluated in file order; the first match replaces the node's base text.

For a spoken answer, author `return_to` instead of artificial "ask another question" choices:

```json
{"id":"mara_thanks","speaker":"Mara",
 "text":"Then take this promise: the quay will keep a light for you.",
 "return_to":"mara_greeting"}
```

The response displays without choice buttons, then **automatically returns** to its question menu. B/Esc skips immediately to that same menu. A/Enter does not select through the response. Godot uses the voice clip's duration plus 0.45 seconds, or estimates the subtitle at 156 words/minute plus short phrase pauses (minimum 2.2 seconds). Missing clips use the estimate. Opening the ledger pauses both speech and countdown. Returning to questions does not replay the greeting audio, and the NPC returns to Idle while awaiting a choice.

`return_to` must name an existing question menu: it cannot name another response, itself, `$exit`, or a node without choices. A response cannot also contain choices. Rust exposes `finish_response()` through the bridge; it changes only the current node, with no repeated effects or choice event. Timing remains in Godot. Saving during a response preserves its node and return destination; loading restarts the line's presentation time. The optional field keeps existing revision-4 save states compatible, so this presentation change retains revision 4. The cabinet's open/close/take interactions remain explicit choices.

Each NPC scene entry calls `NarrativeBridge.begin_at` with an authored node ID. The hub uses `mara_greeting`, `ivo_gate`, `clerk_greeting`, and `vendor_greeting`; the records cabinet interaction uses `cabinet_greeting`. Keep NPC IDs aligned with the `entry` values in `godot/scripts/demo.gd` and the cabinet ID aligned with its interaction call. An unknown ID produces an error and leaves the Rust session unchanged. `begin_at` resets the current dialogue node for that interaction while preserving flags, Mercy, and affinity. Skipping a response or leaving a menu does not undo committed choices.

The hub's `oil_shared`, `gate_open`, and `shortcut_open` flags are presentation inputs for Mara's lamp and the two barriers. Revision 3 added `records_clue` and `records_collected`; revision 4 adds `ivo_where_asked` for the one-time Mara question. Asking the clerk about the old harbor records sets the clue, while taking the folio from the cabinet sets the collected flag. The scene derives the objective waypoint, office record visibility, and journal Inventory display from these flags after a choice or save load. To add a new world consequence, author its condition and effect in JSON, then add a small Godot presentation mapping in `_refresh_world()`. Keep qualification rules in Rust rather than scene scripts. The [hub map](hub-map.md) gives the records door, barrier locations, and landmark GLB contract.

Use `voice` for a Godot `res://` AudioStream path such as an Ogg clip. An omitted or missing clip leaves the subtitle and controls usable. The demo ships no recordings; see [audio provenance](../godot/assets/audio/README.md). Before opening Godot, validate links and IDs:

```sh
cargo run --locked -p oathshaper-core --bin validate_dialogue -- godot/content/lantern_quay.json
```

The validator reports broken targets, duplicate node/choice IDs, unknown flag/companion IDs, unsupported schema fields, and invalid moral bounds. The Godot editor/CI equivalent is `Godot --headless --path godot --script res://tools/validate_dialogue.gd` after building the host extension.

Story revision 4 adds the one-time Ivo question and selectable terminal choices. The demo writes to `user://oathshaper_hub_v4.save.json`, preserving the earlier revision-3 slot. The Rust core rejects narrative saves from a different revision instead of silently applying them to changed content. Plan an explicit migration before expecting an older save to load.
