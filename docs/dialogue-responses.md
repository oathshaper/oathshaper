# Automatic responses and independent NPC sway

Verified on macOS, Apple M4 Pro, Godot 4.3 Compatibility renderer, 2026-10-21.

## Demo

Speak to Mara and share oil. Her answer appears in a compact subtitle band, with no artificial return choice. After the estimated spoken time, the question menu returns automatically. Ask about Ivo, then press controller B or keyboard Esc to skip the answer. The menu returns with that question greyed as already asked. B/Esc at the question menu leaves the conversation.

Voice clips determine duration when present; otherwise subtitles supply an estimate. Opening the ledger pauses both audio and the response countdown. Loading a saved response replays the line's presentation, preserving committed effects. Existing revision-4 saves remain compatible. See [authoring](authoring.md) for the validated `return_to` field and timing policy.

Each NPC starts at an independently randomized animation phase and tempo. Tempo drifts gradually between new targets, and Idle/Talk retain their phase. The player retains its authored cadence and speed-driven Walk. No mesh or skin changes were needed. See [rigging](rigging.md).

## Evidence

- [Recorded automatic return and B shortcut](images/timed-response-flow.mp4).
- [Response band](images/timed-response-1280x800.png), [automatic menu return](images/response-return-menu-1280x800.png), and [skipped response with completed question](images/response-skipped-1280x800.png).
- [Four NPCs with independent sway](images/npc-independent-sway.mp4). This temporary capture lineup leaves their normal scene positions unchanged.

Validation completed:

- `cargo test --locked --workspace`: 23 narrative tests passed, including broken return links, automatic-cycle rejection, atomic response completion, and save/load without repeated effects.
- `cargo clippy --workspace --all-targets --locked -- -D warnings`: passed.
- Rust content validator: 16 nodes, revision 4, valid.
- macOS GDExtension rebuilt; Godot headless import passed.
- `dialogue_response_test.gd`: real bridge/panel flow, deadline checks, one full response through ordinary frame time with no input, B/Esc skip, focus, layout restoration, ledger pause, saved response, clip duration, missing clip fallback, and stale countdown cancellation.
- `rig_slot_test.gd`: independent seeded phases/tempos, bounded gradual drift, Idle/Talk phase continuity, and existing rig/fallback checks.
- `headless_test.gd` and `route_integration_test.gd`: existing camera, movement, story, controller-event, records route, map/journal and save/load checks passed with the new response navigation.

The audio test creates and removes a two-second silent WAV resource; it validates duration and pause handling, not performed voice content. No sample speech was added. Graphical recording logs were clean. The headless renderer still reports its previously recorded `mesh_get_surface_count: Parameter "m" is null` diagnostic while tests exit successfully. These are macOS checks with synthetic controller events; Linux and a physical Steam Deck/controller were not retested in this pass.

Capture with `godot/tools/capture_response_flow.gd`, `--write-movie /tmp/responses.avi --fixed-fps 30`, and a 1280 × 800 window. Add `-- sway` for the NPC recording. The capture script does not write user saves.
