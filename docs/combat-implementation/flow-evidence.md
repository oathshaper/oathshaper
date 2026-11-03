# Flow first playable checkpoint evidence

Date: 2026-10-22. Original author evidence; independent findings, repairs and the subsequent combined gate are recorded in [release-review.md](release-review.md). Base daaee1c, initial core commit b6c79f4. No publishing, provider calls or campaign mutations occurred.

## Executed

- `cargo test -p oathshaper-core --test flow`: nine passing regressions. They cover preset/gem requirements and clamped current resources; explicit missing verbs; Focus entry/pause/payment-boundary exit/save; support-to-martial Resonance damage; Speaker gem's exact skill-score deltas; follower full-interval reset and finite budget; paid weapon cancellation and corrupt-pose rejection; durable duplicate payment; and staff front-arc exclusion.
- `cargo clippy -p oathshaper-godot --all-targets -- -D warnings`: passes for core and bridge.
- `cargo build --locked -p oathshaper-godot`: bridge compiled and loaded by actual Godot 4.3.
- Native 1280×800 real renderer suite `godot/tests/flow_trial_test.gd`: 294 checks on the final source/extension, zero failures. It uses the real bridge and exact authored host geometry, pays Gale's cost, saves/restores paid state, completes a live-AI encounter, accepts surrender, receives 80 copper/level2 once, latches `has_won`, checks modal Tab/B and D-pad selection. Final log: `/tmp/oathshaper-flow-native-verified.log`, exit0. No physical Deck/controller-device run is claimed; controller events are synthetic.
- Checked rendered `/tmp/oathshaper-flow-combat.png` and `/tmp/oathshaper-flow-native.png`: garden loaded, rigs and ward models present, diamond/bar/action hierarchy readable at 1280×800. The outcome modal uses shared chapter story. Captures are local evidence, not packaged marketing assets.
- `git diff --check`: passes.

Headless initial native run emitted dummy renderer mesh diagnostics; the actual OpenGL/Metal run loaded meshes and completed without those diagnostics. One imported mesh produced a non-finite LOD normal warning during import. The initial menu parse error and test variable collision were repaired before passing native runs.

## Exact next acceptance work

1. Independent review of core timing/cost/source/restore rules and native context/focus boundaries. In particular challenge the current direct-input admission boundary versus due upkeep, cancellation/impact order, hostile half-rate movement, projectile endpoint limitations, and persisted action validation. Passing author tests is not this review.
2. Root integration: records/quay → Flow chapter → legitimate win → Return to quay persistence, then fresh launch/load; shared voice attachment is root-owned. Standalone preview must remain isolated.
3. Playtest keyboard plus physical controller/Deck for movement, target switching, guard/power timing, readable telegraphs, camera and follower behavior. Shared procedural rig motions/ward enemy models are current presentation, not finished martial animation or source-game parity.
4. Decide which omitted design features are required for this first release. No claim covers all19 design scenarios. Missing content/behavior is enumerated in flow-contract.md, including transformation, advanced library/items, broader exploration checks/economy, alternate followers, buffer, retreat, and exact scripted worked-encounter reconciliation.

This is a recoverable first playable slice; a completed authored design and passing fight do not establish release acceptance.

## Independent review repairs, 2026-10-22

Reviewer `vanguard_runtime` reported four defects in the first slice. These repairs passed author verification and the subsequent narrow independent recheck; see [release-review.md](release-review.md).

- **Projectile restore:** every persisted projectile now requires an existing owner and opposing target, a unique authored action identity within the serial cursor, bounded destination/damage and positive bounded remaining flight. Rejected restores preserve the complete prior save. The regression checks eleven malformed variants, including the missing-owner/Focus crash, plus successful restore and advancement of a real paid projectile.
- **Modal input:** opening a modal clears movement, orbit, trigger and guard latches. Joypad motion during the modal cannot arm movement or orbit for dismissal; releases retire trigger state. The input regression reproduces right-stick movement, menu open, release, close, then fresh movement/release.
- **Turning Palm:** its two-second cooldown uses `stone:area`; Stone normal/power remain available after cancellation/recovery. Still Water retains its shared six-second cooldown across both verbs.
- **Spatial observations:** LOS and push query identities now include exact source/target positions. Each frame requests the bounded combinations of current and proposed positions; impact resolution consumes only the combination matching the movements that actually committed. Rejected movement uses the current-position answer. A later same-tick push makes mismatched LOS unavailable, conservatively suppressing an effect until another observation, rather than reusing the former sight line. This preserves the existing endpoint projectile model; it does not implement swept projectile contact.

Executed after repairs:

- `cargo test -p oathshaper-core --test flow --locked`: **14 passed**. New geometry cases cover clear-to-blocked, blocked-to-clear, blocked movement fallback for melee/projectiles, and moved-target push sweeps.
- `cargo clippy -p oathshaper-core --lib --locked -- -D warnings`: passed.
- `Godot --headless --path godot --script res://tests/flow_input_test.gd`: **7 checks, zero failures**, exit0; `/tmp/oathshaper-flow-input-repair.log`. This exercises the repaired native input script with the existing loaded bridge; it is not a rebuild or post-repair rendered encounter acceptance. Headless dummy mesh diagnostics are present.

Root owns the concurrent stage, HUD and voice integration. The two Flow trial input hunks preserve those changes. The subsequent combined extension build, 294-check native encounter run and narrow independent recheck passed; see the joined review record.
