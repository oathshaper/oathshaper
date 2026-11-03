# Command: playable first slice

Validated 2026-10-22 on macOS, Godot 4.3.stable, Compatibility renderer, 1280×800. Core integrated through `1193d13`; foundation restore transaction `7bb798b`. This record covers the first playable slice, not all nineteen design scenarios or all nine profiles.

## Reach it

Title → **The Disputed Charter**, or Combat styles → Command → Overview → Play The Disputed Charter. The Overview embeds the same Godot host and rules adapter used by the playable chapter. The garden uses the imported optimized mesh and scene-owned geometry observations.

The flood ledger establishes a public right of passage. Mara and the clerk accompany the protagonist to recover a substituted gate seal. Victory yields evidence the clerk can lodge against the closure. The chapter's shared story data contains no combat-profile identity. Checkpoint `63f62f3` connects the cabinet → Ivo → garden route, including the path where the player keeps the lantern oil. The title also offers a standalone chapter entry.

## Implemented

- Distinct Corsair, Mara and clerk builds; Ivo available for reserve inspection. Party possession and order recipient switch together; inspection is separate.
- Contact/manual/menu pause ownership, one active action plus four future orders, sourced abilities, resource reservation, cancellation, interruption and paid windup.
- Actual enemy/companion decisions, observed route/LOS, health and conditions, victory/defeat, retry checkpoint and one receipted reward.
- Native HUD with party portraits, resource totals, action categories, queue editing, targeting, input-device hints and combat log.
- Party ledger with equipment comparisons and atomic changes, inventory, powers, companion policy, craft/shop/skill offers, six complete build presets and a concrete level-up path.
- Save and restore through the Rust facade with fresh authority and a paused restore barrier. The chapter slot is separate from the Lantern Quay save.
- Imported rigged party actors, attached weapon meshes, procedural adversaries and generated adversary modeling references. Production attack clips and mesh replacements remain art work.

## Acceptance evidence

| Check | Result | Boundary |
| --- | --- | --- |
| Native launcher → chapter → contact → party/queue/target → paid save/load → victory → craft → menu | **45 checks, 0 failures** | Actual Godot transport, renderer and native key/gamepad-event dispatch; test `godot/tests/command_trial_test.gd` |
| Native ground target | Pass | Projected garden pixel dispatched through SubViewport input, not a direct target callback |
| Launcher and nine preview sheets | **10,611 checks** | Headless layout/focus/catalog gate after story and Coming soon changes |
| Dialogue response regression | Pass: timed response checks | Existing timing and return routes after changed dialogue text |
| Command HUD fixture | **139 checks, 0 failures** | Source-specific actions, queue controls, focus, layout and controller hints |
| Ledger fixture | **269 headless / 271 rendered checks** | Earlier current ledger mechanics; copy-only changes subsequently exercised in host |
| Core independent review | **PASS CR01–08** | 16 facade +16 original private tests, seven expanded public probes and two self-healing regressions; [packet](command-independent-review.md) |
| Build | Pass | Locked host extension build; atomic replacement preserves resident processes |
| Rendered captures | Inspected | Title, nine cards, Command Overview, chapter briefing/outcome/contact/combat/inventory at1280×800; desktop host clamps requested1920×1080 to1728×1080 |

Run the native integration gate:

```sh
sh scripts/build-host.sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://tests/command_trial_test.gd -- --capture
```

The capture runner writes `/tmp/oathshaper-command-{briefing,contact,combat,outcome,inventory}.png`. Launcher captures are under `docs/images/launcher-*`. Headless Godot emits dummy-renderer `mesh_get_surface_count` null-mesh diagnostics while freeing imported meshes; rendered launcher capture also reports GL texture cleanup leaks on process exit. Assertions passed, but these diagnostics are recorded rather than described as a warning-free run.

## Remaining boundaries

- Full level-20 progression, weapon sets, all body variants and every Command design scenario remain open in the core evidence packet.
- Physical controller and Steam Deck playtests are not claimed; injected native events and1280×800 desktop captures cover only their stated boundaries.
- Other eight profiles remain previews at this checkpoint. Release scope now prioritizes Flow and Vanguard; 04–09 show Coming soon.
- Voice generation, public asset-redistribution confirmation, organization/repository creation, CI builds and publication are separate release work.
- Prototype save schema v3 rejects older v1/v2 Command saves; no migration claim. The hub envelope is now schema3 with chapter completion, and loads schema1/2 journeys with no completed chapter.
- No publication, remote push, paid Meshy operation or license change occurred in this slice.
