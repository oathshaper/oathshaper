# Lab: find a stale conversation with the continuity checker

Audience: students who have played Lantern Quay and can run a terminal command. No Rust knowledge is needed for the first pass. Updated: 2026-10-26. [Research and teaching proposal](../research/011-agent-assisted-game-design-teaching.md).

## Run the current game checks

Use a checkout with the project's assets, Python 3.10+, Rust/Cargo and Godot 4.3.stable on macOS or Linux; these are the hosts supported by the current extension-build script. The [project README](../../README.md) covers setup. From the repository root:

```sh
python3 scripts/check-continuity.py
```

The command prints each stage and the path to its report. Open that directory's `README.md`, then follow a stage's evidence link. It scans dialogue repetition across branches, builds the host extension, imports the current Godot project, and runs the three oil routes plus travel/camera/grip, Command controls and voice checks. A running game can remain open; the tests use their own processes and temporary saves.

If Godot is installed elsewhere:

```sh
python3 scripts/check-continuity.py --godot /path/to/godot
```

For a quick narrative-only iteration:

```sh
python3 scripts/check-continuity.py --logic-only
```

That report explicitly excludes engine behavior. Exit codes are 0 for passing the requested scope, 1 for a failed check and 2 for incomplete work or invalid setup. A missing receipt or a timeout cannot produce a pass. Phrase warnings may coexist with a passing contract check; read the findings.

The report also counts engine diagnostics. Two known Godot 4.3 headless-renderer/exit messages are retained without failing continuity assertions. This does not establish clean resource teardown. Unexpected engine errors fail the run.

## Predict the failure

In the game, sharing oil lights the tower. A present-tense question about why the tower is dark should disappear. Before using the agent, write down:

1. Which fact changes when oil is shared?
2. Which menu choice becomes obsolete?
3. What sequence of actions would expose the defect?
4. Could a correct menu-state check prove that Mara actually walked to the tower?

## Introduce a fault in a copy

This exercise changes a disposable story file. The game and its rule contract stay intact.

```sh
python3 - <<'PY'
import json
from pathlib import Path
story = json.loads(Path('godot/content/lantern_quay.json').read_text())
node = next(n for n in story['nodes'] if n['id'] == 'mara_greeting')
choice = next(c for c in node['choices'] if c['id'] == 'ask_lamp')
choice['hide_when'] = []
out = Path('.artifacts/continuity-lesson')
out.mkdir(parents=True, exist_ok=True)
(out / 'broken-story.json').write_text(json.dumps(story))
PY
```

Run the actual narrative evaluator against the unchanged rules and journeys:

```sh
cargo run --quiet --locked -p oathshaper-core --bin replay_continuity -- \
  .artifacts/continuity-lesson/broken-story.json \
  godot/content/lantern_quay.continuity.json \
  godot/content/lantern_quay.journeys.json \
  > .artifacts/continuity-lesson/failure.json
```

**Expected result: exit 1.** In `failure.json`, the `oil-shared` journey fails at step 3, after returning from Mara's response. Both `oil_shared` and `oil_decided` are true, and `ask_lamp` is still visible. The trace starts from the initial story state; no flag was injected into the replay.

Have the agent explain the report, then check its explanation against the source. Restore the copied choice's `hide_when` from the original story, rerun the command and compare the reports. Deleting the rule to make the report green does not repair the defect.

## Open the mechanism

| Artifact | What to inspect |
|---|---|
| [Story](../../godot/content/lantern_quay.json) | Choice effects and runtime visibility |
| [Rules](../../godot/content/lantern_quay.continuity.json) | Independent expectations about applicable dialogue |
| [Journeys](../../godot/content/lantern_quay.journeys.json) | Actual enter, choose, response-return and save/load operations |
| [Rust checker](../../crates/oathshaper-core/src/continuity.rs) | The Boolean matrix (currently 12 flags) and menu observations |
| [Replay engine](../../crates/oathshaper-core/src/continuity_replay.rs) | Production `NarrativeSession` calls and the first failing prefix |
| [Game check manifest](../../godot/content/lantern_quay.checks.json) | Which Godot fixtures run for this chapter |
| [Godot chapter route](../../godot/tests/chapter_route_test.gd) | Earned combat victory, loot, return and save/load checks |
| [Receipt collector](../../godot/tests/continuity_receipt.gd) | How repeated observations become inspectable evidence |

The rules are authored expectations, not another dialogue engine. Both matrix and replay inspect views produced by the real narrative evaluator. A heuristic phrase match only raises a suspicion. A contract violation means an explicit expectation did not hold; the expectation itself can still be wrong.

The matrix includes impossible combinations. The replay proves a sequence of narrative operations under host entry assumptions. The Godot fixtures exercise real host behavior but use fixture placement for some player approaches. None is an exhaustive navigation test. Camera rays also cannot establish that a shot looks good.

## Explain and transfer

Submit the failing trace, the repaired trace, and a short explanation of the difference between a rule, a heuristic and a reachable route. Identify one thing the tool did not check.

Then, individually, add a small analogous rule for an obsolete topic in a different chapter or inspect an instructor-provided unfamiliar defect. Predict the result before running it. Explain the observation without relying on the agent's summary.

For a second exercise, use the [dialogue repetition checker](../dialogue-script-checker.md) to distinguish an accidental echo from an intentional acknowledgment. It includes a reproducible seeded fault and explains how equivalent histories merge.

Related: [continuity pipeline specification](../research/010-continuity-checking-pipeline.md), [dialogue authoring](../authoring.md), [world/storyboard pipeline](../research/008-playable-storyboard-content-pipeline.md), [rigging](../rigging.md).
