# Dialogue repetition, event expiry and combat pauses

Date: 2026-10-26. Local implementation and verification; no publication or license change.

## Delivered

- A standalone [dialogue script checker](../dialogue-script-checker.md), integrated into the continuity runner and standard check script. It follows enabled branches with real effects, variants and completed-choice history; compares every earlier utterance on each conversation path; includes voiced player choices and authored cutscene sequences; and reports concrete witness paths. Equivalent states and heard-line sets merge. Budget exhaustion and unsupported numeric entry conditions report incomplete coverage.
- Ivo's preparation topics expire after combat. A new persisted `raiders_defeated` fact distinguishes victory from picking up the payroll. Mara and the clerk respond appropriately during that interval. Recruitment expires the instruction to fetch Mara. Existing revision-7 game saves derive the new fact from their saved chapter result.
- Accidental oil-response and Ivo anecdote echoes removed, with the approved plot preserved. Seven changed/new lines received locally generated voice clips. The production manifest contains 76 clips; current identity/duration checks pass. No listening review was performed.
- Queued attacks against a defeated target clear together and release their reservations. They cause one interruption, rather than another pause on each Resume. The action-failed pause also suppresses a redundant empty-orders pause. Valid orders survive transient stun. Pause on encounter contact and when the controlled character needs orders remain available.
- Student documentation explains graph traversal, state equivalence, false positives, scope and a reproducible repetition exercise. The teaching research specification links it as an additional focused lesson.

## Verification

| Check | Result / evidence |
|---|---|
| Rust workspace tests | 138 passed, zero failures, including the new traversal and pause regressions. [Log](rust-tests.txt). |
| Rust formatting / Clippy | Formatting passed; Clippy passed with warnings denied. [Clippy log](clippy.txt). |
| Reporter tests | Six Python tests passed, including incomplete dialogue scans and heuristic-warning classification. |
| Dialogue script scan | 11,804 states, 363 conditional entries, 12,040 transitions, five authored sequence groups. No remaining frontier or budget omissions. One intentional acknowledgment warning. [Report](current-game/dialogue-script.json). |
| Applicability matrix | 4,096 Boolean combinations; 15,872 rule/state matches; seven rules; no findings. [Report](current-game/matrix.json). |
| Narrative replays | Shared, kept and undecided oil routes pass. [Report](current-game/replay.json). |
| Native Godot fixtures | 1,100 assertions, zero failures across three earned-victory chapter routes, travel/camera/grip, Command controls and voice playback. [Current run](current-game/README.md). |
| Native pause input | Focused Resume button + Space toggles once; key repeat submits nothing; the next fresh press resumes once. Included in the 38 Command control assertions. |
| Voice sequencing | Eight player-voice checks pass. Response timing, skip, pause, cancellation, save/load and persistent completed topics pass. [Player log](player-voice.txt), [response log](dialogue-response.txt). |
| Editorial tools | Humanizer, its routed critic and the local Obelus CLI were used. Five root causes reconciled; no unreported clean-writing verdict. [Review](REVIEW.md). |

The repeated-resume regression was reproduced before the combat fix: three queued strikes at an incapacitated target were not retired together. [Failing baseline](pause-regression-before.txt), [passing targeted regression](pause-regression-after.txt). The final full suite also exercises it.

The first runtime pass is retained in [first-runtime-pass.tar.gz](first-runtime-pass.tar.gz) as a public evidence copy. Workstation paths and archive owner metadata were normalized; test results are unchanged. See [evidence handling](../EVIDENCE.md). Only the transient-stun unit-test fixture changed after that pass; the final run hashes the finished source tree. The preexisting local `godot/project.godot` edit was included in runtime observations but left outside this change's commit.

## Evidence boundaries

This is coverage of enabled dialogue permutations within connected conversations and authored sequences, not arbitrary world interaction orders or semantic paraphrases. Logical entry contexts can be physically unreachable. One readable path is retained for each warning; no claim is made about enumerating infinitely repeated loop performances.

Native fixtures use temporary saves and some fixture positioning. They earn combat outcomes but are not navigation bots or a new visual playthrough. Known Godot 4.3 dummy-renderer/exit-resource diagnostics are retained in the reports; no clean teardown or physical-controller claim is made. The completed source build is available to the next game process; an already running game keeps its loaded extension.

## Run again

```sh
python3 scripts/check-continuity.py
```

Use `--logic-only` for a quick script iteration without Godot. For a standalone repetition report, see the [checker instructions](../dialogue-script-checker.md).
