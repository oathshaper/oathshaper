# Three-style integration review

2026-10-22. Local candidate on `release/demo-20261022`. This record joins the individual Command, Flow and Vanguard evidence; it does not claim the full nine-style design is implemented.

## Independent findings and repairs

| Reviewer | Finding | Repair and narrow recheck |
| --- | --- | --- |
| `vanguard_runtime` | Flow projectile restores accepted invalid owners, targets and action identities | Validate persisted projectile identities, bounded damage/destination and remaining flight; rejected restores preserve the previous save. Eleven malformed cases plus a valid paid projectile. Narrow recheck passed. |
| `vanguard_runtime` | Flow modal input could leave held orbit/trigger/guard state behind | Clear latches on modal open and consume releases while the modal owns input. Native input regression: seven checks. Narrow recheck passed. |
| `vanguard_runtime` | Turning Palm's cooldown blocked unrelated Stone verbs | Scope its two-second cooldown to `stone:area`; retain Still Water's shared cooldown. Narrow recheck passed. |
| `vanguard_runtime` | Flow impacts could consume LOS measured before movement | Include exact actor positions in spatial query identities; consume observations matching committed positions. Tests cover blocked/clear transitions and rejected movement. Narrow recheck passed. |
| `flow_design` | Vanguard powered shots bypassed holster and tucked-cover restrictions | Share emission readiness across ordinary fire and powered-shot admission, activation and impact. Narrow recheck passed. |
| `flow_design` | Vanguard coordinate subtraction could overflow before widening | Convert operands before subtraction in distance and knockback calculations. Extreme-position regressions preserve state on rejected observations. Narrow recheck passed. |
| `vanguard_runtime` | Conditional dialogue could play the wrong node-level recording | Require an exact speaker/text entry; missing variants use subtitle timing. Native test deliberately supplies a wrong legacy clip and confirms it is ignored. Narrow recheck passed. |
| `vanguard_runtime` | A changed player-spoken line could reuse an old audio filename | Output identity includes speaker, lookup text and spoken text. All 46 manifest entries were checked. Narrow recheck passed. |
| `vanguard_runtime` | Release manifests captured HEAD after building, permitting mismatched provenance | Capture a clean revision before staging and reject dirty or advanced source before manifest creation. An isolated Git fixture checks clean, dirty and advanced states. Narrow recheck passed. |

Command's prior review is in [command-independent-review.md](command-independent-review.md). The records route, single-application player choice effects, presentation cancellation and save compatibility also received independent source/probe review.

## Combined native gate

After rebuilding the shared extension, actual Godot 4.3 windows on the M4 Pro at 1280×800 passed:

| Entry point | Result | Local transcript |
| --- | --- | --- |
| Visible profile overview → Play → own runtime → overview, all three styles | 16 checks, zero failures | `/tmp/oathshaper-playable_profiles-joined.log` |
| Command title entry, queues, targeting, party sheet, save/load, victory and crafting | 45 checks, zero failures | `/tmp/oathshaper-command_trial-joined.log` |
| Flow direct input, costs, save/load, follower, earned victory and rewards | 294 checks, zero failures | `/tmp/oathshaper-flow_trial-joined.log` |
| Vanguard aiming, cover, squad powers, heat, modules, earned victory and exit | 23 checks, zero failures | `/tmp/oathshaper-vanguard_trial-joined.log` |
| Keep oil → records cabinet → public passage → earned Command victory → quay save/load | 14 checks, zero failures | `/tmp/oathshaper-chapter_route-joined.log` |

The route tests identify visible modal actions by caption; adding a speech-player child exposed the old positional child lookups. Player-reply presentation is completed through the same skip path used by Back before proceeding to the next story step.

`cargo test -p oathshaper-core --locked`: 104 passing tests including one documentation test. `cargo clippy -p oathshaper-core --all-targets --locked -- -D warnings`: passed. Core log: `/tmp/oathshaper-core-integrated.log`.

Rendered Flow and Vanguard captures were inspected after integration. Flow now uses a close action camera and visible Health/Chi/Focus bars. Vanguard's carbine follows the existing two-hand rig and grip solver. These are procedural demonstration animations and adversaries, not final character or weapon art.

## Remaining boundaries

- The 45-line speech bank passed a subsequent 59-check native gate (`/tmp/oathshaper-generated_voice-voiced.log`): every exact clip loads, player speech pauses/resumes and naturally hands off to its NPC response, effects remain single-application, chapter speakers sequence on audio completion and closing stops playback. The timed-response, records-route and general native bridge suites also passed with speech imported. Transcription/acting quality remains a separate check; the voice audit records its flags.
- Physical controller/Steam Deck play, Intel Mac runtime and Linux/Windows execution are not established by these native macOS tests. The subsequent extracted macOS release passed five native gameplay/playback gates; see [release-builds.md](../release-builds.md).
- Each style's omissions remain listed in its contract and [release status](../release-status.md). The broader equipment/build gallery still includes design previews.
- This review covers a local candidate. No repository has been pushed publicly.

## Complete source gate

After adapting the older subtitle-only route checks to complete player speech before asserting NPC/world presentation, `GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot sh scripts/check.sh` exited 0. Log: `/tmp/oathshaper-final-source-check.log`. This includes Rust format, strict workspace Clippy, workspace tests, dialogue validation, the existing map/rig/office/controller/save suites, 10,602 front-end assertions, the three playable profiles and both voice suites.

Headless Godot emits its known dummy-renderer `mesh_get_surface_count` diagnostics for the imported meshes. The native-window evidence above establishes rendered behavior separately. The headless voice test injects an audio-finished event for chapter sequencing; the native-window test waited for actual audio completion. Neither is a human assessment of the generated performances.
