# Current-game continuity run and teaching exercise

Date: 2026-10-26. Local validation on the local Apple Silicon workstation, Godot 4.3.stable. No public release or student trial was performed.

## What ran

```sh
python3 scripts/check-continuity.py --output docs/continuity-runs/20261026-current
```

The [report](README.md) and [machine receipt](report.json) retain the commands, source hashes, scope, observations and engine diagnostics. This used the current working game scripts and assets. The preexisting editor changes to `godot/project.godot` were included in the source hash and left uncommitted; they were not authored by this work.

| Layer | Result |
|---|---|
| Boolean menu matrix | 2,048 states, three applicability rules, no findings |
| Authored narrative journeys | Three routes, 57 operations, no injected world flags; gate reached and expected state retained |
| Native Command chapter | Oil shared, kept and undecided: 219 passing assertions each; victory earned, payroll recovered and returned, save/load and reward idempotence checked |
| Travel/camera/grip | 309 passing assertions on current scripts and rigs |
| Voice | 87 passing assertions, 73 current manifest clips |
| Rust workspace | 127 tests plus one documentation test passed; [log](rust-tests.txt) |
| Rust formatting and Clippy | Passed; [Clippy log](clippy.txt) |
| Python report boundary | Six tests passed: missing/malformed evidence, budgets, script errors, diagnostic origin, count mismatch and warning severity |
| Narrative-only command | Passed with engine behavior explicitly excluded |

The five native suites contain **1,053 passing assertions**, including repeated route samples. That is not a count of distinct bugs, scenes or independently covered behaviors.

## Student fault exercise

Executed the commands in the [continuity lab](../../tutorials/continuity-lab.md) against a disposable copy of the story:

1. Remove `ask_lamp.hide_when` from the copy.
2. Replay the unchanged journey and rule files through the production narrative evaluator.
3. Observe exit 1 at step 3: oil was shared and the response returned, yet the darkness topic remains visible.
4. Restore the original visibility condition in the copy and rerun: exit 0, all three authored journeys pass.

Evidence: [failure trace](lesson-failure.json), [repaired trace](lesson-repaired.json), [exercise receipt](lesson-exercise.json). This is a seeded regression demonstration of a known playtest defect. It is not a newly discovered production bug or a measurement of labor savings.

## Boundaries and reporting correction

- Narrative `enter` operations assume the host permits access. They do not prove physical navigation. The authored journeys end at the garden gate; native fixtures exercise the subsequent battle and return.
- Native fixtures use player placement for some approaches. Companion movement and combat then run through current gameplay methods. There is no general navigation bot or exhaustive route search.
- Camera and rig checks sample geometry and transforms. Visual composition, performance, acting quality and physical controller feel still require playtesting.
- Known Godot 4.3 dummy-renderer null-mesh and resource-at-exit diagnostics remain in the logs and are counted in the report. Passing continuity assertions do not establish clean resource teardown. Unknown engine errors fail the runner.
- During verification, ANSI color sequences were found to defeat the original diagnostic counter. The counter now strips those sequences and recognizes only the documented message/location pairs. The final full run was made after this correction; the reporting regression is covered by a test.
- Checked source hashes were compared after the final run; no checked source had changed. Git HEAD identifies the base, while the hashes identify the uncommitted implementation used in this run. Asset bytes are identified by repository state rather than a full separate asset hash inventory.

## Teaching proposal

[Research specification 011](../../research/011-agent-assisted-game-design-teaching.md) describes an agent-assisted first game followed by focused lessons on continuity, worldbuilding, mesh production, skeletons/equipment, voice and integration. It includes an individual transfer assessment and a pilot design, supported by five primary or official teaching sources. It is a teaching proposal; no course approval, partnership, learning gain or 60–70% work reduction has been established.
