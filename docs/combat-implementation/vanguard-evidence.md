# Vanguard verification evidence

Subsequent integration: the two independent findings were repaired and rechecked; the complete core suite and 23-check native Vanguard gate passed. See [release-review.md](release-review.md). The original isolated-worker record below is retained as historical evidence.

2026-10-22, isolated worktree `.agent-worktrees/combat-implementation/vanguard`, base `daaee1c`. workflow automation not applicable by explicit instruction. Independent integration review is owned by the parent agent; this author record is not an independent approval.

## Passed

- `cargo test -p oathshaper-core --test vanguard`: 10 tests. Pause ownership and frozen clocks/resources; heat latch/cooling and swap retention; stale/teleport frame rollback; shield gating and separate cooldowns; preactivation rejection versus effect-miss costs; actual module damage/heat; single pending channel/cancellation; defeat and no reward; powered-shot interruption with no heat; draw-before-fire.
- `cargo clippy --workspace --all-targets --locked -- -D warnings`: passed after scoped fixes.
- GDExtension builds on the native macOS host and exports `VanguardBridge`.
- `/Applications/Godot.app/Contents/MacOS/Godot --path godot --script res://tests/vanguard_trial_test.gd -- --capture`: `VANGUARD_TRIAL_TEST: 23 checks, 0 failures`. Actual 1280×800 OpenGL native window. Covers briefing module choice, target ray, Tab pause, Mara overload, clerk throw with displacement, fire/heat, quick swap, RB/B controller selector, menu/finished, early leave without victory, WASD into cover, physical sight obstruction, contextual B, earned victory, outcome and monotonic victory after restart.
- `git diff --check`: passed.

Native captures were inspected at `/tmp/oathshaper-vanguard-briefing.png`, `-wheel.png`, `-combat.png`, `-cover.png`, and `-outcome.png`; each is1280×800. Native transcript: `/tmp/oathshaper-vanguard-native.log`. The parent may archive these with its final release evidence. The captures demonstrate this profile's shoulder view, readable bottom HUD, paused native squad powers, tucked cover and story outcome.

## Failure and repair evidence

Initial native test exposed an ally behind the shoulder camera obstructing the camera ray; the host now ignores actors behind the muzzle for aim and fades nearby companion presentation. Expanded outcome test exposed modal creation recursively entering the victory modal while releasing trigger input; modal ownership is now installed before submitting those mutations. Both are included in the final native traversal. Core tests also enforced the ordinary shot channel before a subsequent power order; the test waits for the actual channel release instead of weakening the rule.

The headless dummy renderer produced mesh-storage diagnostics for imported art. Native renderer validation is the visual acceptance evidence; the headless run is not recorded as a rendering pass.

`cargo test --workspace` failed two narrative text assertions: `choice_changes_later_line_and_cannot_repeat` at `crates/oathshaper-core/tests/narrative.rs:77` expects `promise`, and `clerk_lead_marks_records_and_cabinet_pickup_survives_save` at line266 expects `found the old harbor records`. Those tests, narrative implementation and source content are unchanged from the base in this worktree. The parent was informed; this scoped implementation does not edit their ownership surface. Full workspace acceptance therefore remains open at this checkpoint.

No production/deployment test, physical Steam Deck run, paid API, external publication, or full20-scenario design acceptance was performed. Remaining product scope is explicitly listed in `vanguard-contract.md`.
