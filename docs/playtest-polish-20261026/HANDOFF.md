# Playtest polish — 2026-10-26

Status: implemented and locally verified. Base: 9b6f6a6. No workflow automation. Existing godot/project.godot edits and the resident game were preserved. Nothing published.

## Authorized work

- Contextual dialogue: hide stale dark-tower topic, explicitly reassure Mara about the clerk, clarify mechanical guards, add an authored speech pause.
- Continuous companion travel and proper forward-facing walking; garden combat begins at the doorway threshold.
- Persistent manual camera orbit; exploration facing follows manual aim; foliage avoidance and combat separation; inspect Mara weapon pose.
- Remove floating environment labels; focus marker for interactables; device-aware hints; final arrival faces 30 degrees left.
- Independently research and implement a small heuristic continuity checker, separate from Humanizer/Obelus. Measure potential labor savings; 60–70% is a hypothesis, not an observed result.

## Decisions

No pending questions. Existing story and tower-light decisions remain accepted.

## Delivered

- Mara's obsolete tower/office topics are hidden; a lit-tower greeting and direct reassurance about the clerk replace the conflicting lines. Ivo's guards explanation is clearer. Changed voice lines were regenerated locally; his request to get Mara now has an authored 550 ms pause.
- Mara and Ivo have weighted Walk clips. Exploration travel uses their actual forward direction, slows through turns and grounds them. Mara follows the player's route after the battle, reaches a doorway before crossing it and preserves her pending route in saves. Legacy loads clear later escort state.
- Crossing the open doorway starts the garden encounter after the party assembles. Full chapter-route checks cover the trigger, combat, loot and return.
- Manual camera heading persists, exploration facing follows manual orbit, and the post-cutscene heading is 30 degrees left. Command camera tests use imported garden geometry and actor obstruction checks; party separation is wider.
- Mara's supporting arm uses a constrained two-bone reach; her readied staff grip and paused-pose stability pass the native fixture.
- Removed floating office/archive labels. Nearby interactions use a focus bracket. Controller prompts require a connected device, with keyboard fallback.
- Independent dialogue continuity checker, authored rules and research specification. Broader reusable world-continuity checks remain proposed; existing gameplay tests provide the initial cases.

## Evidence

- [Verification receipt](verification.json): 124 Rust tests and strict Clippy passed. All 24 configured Godot suites passed individually after corrections to the old camera/hint expectations. The latest continuity suite has 309 checks; the full chapter route has 218.
- [Native render log](native-render.txt): 308 checks, no failures or script errors. [1280 × 800 Command fixture capture](command-native.png). The last additional headless check tests legacy-save restoration.
- [Rig verification](rigs.txt): Mara and Ivo contain Idle, Talk and Walk clips; source Meshy files were not changed.
- [Editorial review](REVIEW.md): actual Humanizer/Obelus runs and one bounded continuity critic, with retained findings explained.
- [Before](continuity-before.json) and [after](continuity-report.json) checker reports: two stale choices plus one text suspicion on previous content, no findings on current content. Both cover 2,048 Boolean states. These are known-regression checks, not proof of physically reachable state coverage.
- [Research specification](../research/010-continuity-checking-pipeline.md): nine primary sources, recurring tasks, pipeline boundaries and a labor-saving pilot.

## Limits

The 60–70% labor saving is unmeasured. No physical controller or Steam Deck test was performed this pass. Headless suites emit dummy-renderer null-mesh and some cleanup diagnostics; final suites contain no script errors. Native camera samples do not prove every possible shot. Facial expressions still require suitable facial rigs; this change supplies speech pauses and body-gesture timing. Voice clips passed objective QC but were not listening-tested here. No new Linux release build was produced.
