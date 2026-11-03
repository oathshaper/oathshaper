# Garden surrender and return — 1 November 2026

## Behavior

- Flow and Vanguard surrender use the shared cinematic camera and left-aligned subtitle bar. The Crimson Raider says: “I surrender! Take the payroll pouch. Just call them off.” The spoken line uses the existing local cast and exact-text voice manifest.
- The scene freezes gameplay and hides the combat HUD, markers and shot effects. It presents **Accept surrender** and **Continue fighting** after the line. Skip advances to this decision; it never chooses. Choice dispatch is deferred until cinematic ownership is restored, preventing the confirming input from firing an attack.
- Accept commits the profile's victory. Decline resumes combat and cannot reopen the same offer. An outright defeat of all enemies also completes the encounter.
- Both campaign and standalone menu victories return automatically to the cleared garden, play Ivo and Mara's resolution, then release exploration beside the raider's payroll pouch. No camp/result screen intervenes. Looting and returning the payroll remain separate story events.
- Menu entry establishes the robbery, recruitment and gate prerequisites when continuing into exploration. Existing oil decisions, records and payroll flags are preserved. The transition does not autosave.
- Vanguard now includes the actual Crimson Raider alongside Lantern and Iron Sentinels. Default squad AI targets the guards first; explicit orders may target the raider. When his guards fall and he survives, he offers surrender. Vanguard's manifest identifies this six-actor encounter as `vanguard-garden-slice/v3`.

## Flow fixes retained with this change

Normal Harbor blade attacks are free; power costs 10 Focus before training modifiers. Focus recovers at 4/second after two seconds without spending it, outside slow time, with no recovery during pause. The HUD explains free swings and recovery. An idle dodge now borrows a backward vector for its travel window without latching walking input. Pause/resume neutralizes cached input.

## Verification

- Full Rust core suite: **146 tests passed**, including a real Vanguard rule test for offer, pause, accept, decline, duplicate decision rejection and no repeated offer after decline. Clippy passed with warnings denied. Host extension rebuilt.
- Native rendered Flow input: **14 checks passed**, including real `Input.parse_input_event` delivery of 3 then Enter, stationary ticks afterwards, idle dodge ending, paused stick suppression and fresh movement after resuming.
- Native Flow earned combat → garden: **12 checks passed**.
- Native Flow surrender accept → garden: **20 checks passed**. A bounded save fixture supplies the rare offer state through the actual bridge. Decline: **13 checks passed**.
- Native Vanguard earned combat → surrender accept → garden: **19 checks passed**. Decline with earned combat: **12 checks passed**.
- Native Vanguard controls/cover/squad/outcome regression: **23 checks passed**.
- Shared opening/confrontation regression: **73 checks passed** across campaign and menu entry for Command, Flow and Vanguard, including native skip and restoration. Cinematic timers were accelerated in the test.
- Rendered surrender and resolution frames inspected at 1280×800. The new voice clip is 3.56 seconds; generator PCM checks passed. Existing recordings are reused with hash verification and previous provenance retained.

Reproduce the outcome test with `Godot --path godot --script res://tests/garden_outcome_test.gd -- --style=flow` or `--style=vanguard`. Add `--surrender-fixture` for the Flow offer branch, `--decline` for rejection, and `--capture` for rendered frames. This exercises public bridge commands and native UI input; it is not a physical-controller, Steam Deck or human balance acceptance.

An initial headless input run passed its assertions but emitted Godot dummy-renderer mesh errors; the rendered native input run passed without those errors. The multi-scene intro regression emitted one macOS OpenGL texture warning and passed its assertions. No claim is made here that all asset/rendering warnings are resolved.
