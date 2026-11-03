# Garden confrontation and party polish

## Implemented

- Campaign garden entry stages an automatic voiced confrontation in the existing world. An establishing shot leads into Ivo, Tessa, and the raider's lines, then combat begins. Esc or controller B skips; there are no dialogue choices. Command starts paused for orders; Flow and Vanguard start live. The standalone combat preview retains its camp/loadout screen.
- Following companions no longer receive the interaction reticle just because they are nearby. Stop and look toward them to talk. The prompt and interaction key use the same selection rule.
- Floating actor name badges appear only for the reticled actor in exploration and combat. Party panels and dialogue subtitles continue to identify their characters.
- The player is **Tessa Ward** in new encounters, party screens, and subtitles. Existing voice recordings retain their internal `Corsair` casting identity for provenance; the display name resolves to that identity. This also explains the old casting label in the dialogue checker report. Enemy and equipment names were preserved.
- Tessa's Command weapon bar is **Brace / Basic attack / Lunge / Shield bash**. The equipped buckler grants Shield bash: a physical attack for 1d4 + Might damage on a hit; surviving targets are interrupted and stunned for 1.5 seconds unless immune. Impact is at 0.6 seconds and readiness returns at 3.6 seconds. The contextual target button still selects Basic attack.
- Four separate [weapon references](../../art/concepts/party-weapons/README.md) are ready for image-to-mesh generation. These images have not replaced the current equipment meshes. The buckler's rear grip and all attachment markers still need verification after the GLBs arrive.

## Verification

The [continuity report](current-game/README.md) passed all 15 scopes, with no unexpected diagnostics. Each of the three oil-choice story routes completed 224 checks. The report retains known Godot 4.3 headless dummy-renderer diagnostics and one phrase-echo warning: Mara's request to check on the clerk followed by the player's acknowledgement. This is evidence of tested paths, not an assertion of exhaustive coverage or clean resource teardown.

| Check | Result | Evidence |
| --- | --- | --- |
| `cargo test -p oathshaper-core --locked` | 139 tests including the doc test passed | [Rust log](verification/oath-core-test.txt) |
| Rendered Command trial at 1280 × 800 | 47 checks passed; four distinct weapon actions visible | [Log](verification/oath-command-render-final.txt), [capture](images/tessa-actions.png) |
| Rendered Command targeting | 30 checks passed; only the target's badge drawn | [Log](verification/oath-target-render.txt), [capture](images/target-only-badge.png) |
| Rendered confrontation with `--realtime --capture` | 37 checks passed at natural speech duration | [Log](verification/oath-garden-realtime.txt), [Ivo](images/ivo.png), [Tessa](images/tessa.png), [raider](images/raider.png) |
| Exploration companion focus | 13 checks passed for movement, deliberate focus, looking away, and hidden actors | [Receipt](current-game/companion-focus.json) |
| Campaign confrontation handoff | Command, Flow, and Vanguard enter combat without the old briefing modal | [Receipt](current-game/garden-confrontation.json) |

The normal-duration rendering command was:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 \
  --script res://tests/garden_confrontation_test.gd -- --realtime --capture
```

Its log predates the test receipt's wording fix: it says timers were accelerated, but this invocation used `--realtime`. The current fixture records `natural_playback` explicitly. Visual checks confirmed Tessa faces the raider and the speaking actor is visible in each shot.

The first full run caught two issues, both corrected before the final run: adding a shield ability displaced Basic attack from the contextual target button, and invalid-save fixtures produced parser diagnostics. Target actions now prioritize Basic attack; malformed save reads return a load error, and fixture writers close their files explicitly. Shield-bash tests cover hits, misses, stun immunity, interruption, invalid grant sources, and saved windup/recovery timing across 16 seeds.

## Local state and limits

The host extension was rebuilt using `scripts/build-host.sh`. The resident user game was left running; it needs a new launch to pick up these changes. No publishing or voice regeneration was performed. The unrelated `godot/project.godot` changes are excluded from this commit.

Existing standalone serialized combat states may retain their saved player name; new campaign encounters use Tessa Ward. These checks do not establish animation quality on Steam Deck, and no new performance claim is made.
