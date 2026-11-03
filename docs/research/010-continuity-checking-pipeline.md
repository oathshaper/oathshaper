# Continuity checking for playable chapters

Research date: 2026-10-26. Status: research, pipeline specification, dialogue checks, authored narrative replays and a runner for current Godot fixtures. The proposed labor saving is unmeasured. Read [the research notice](NOTICE.md) for attribution and independence; no third-party game assets or dialogue are reproduced here.

## Research summary

Game teams repeatedly spend time reaching a particular quest state, replaying branches after edits, reproducing bugs, and checking that dialogue, animation, audio and world state agree. Existing narrative tools validate conditions and support quick replay; production automation also drives actual game clients. Oathshaper should join these practices in a deterministic continuity pipeline, independent of Humanizer and Obelus, with human review for motivation, clarity and performance.

The strongest initial opportunity is reducing repeated setup and verification work. A 60–70% reduction in **manual continuity-checking time** is a hypothesis to test, not an established industry result or a forecast of total development savings.

## Key findings

1. **Branches multiply the work.** Ubisoft describes the growth in action combinations and the difficulty of manually checking them across game contexts, including coexistence of new and old features. This supports checking state combinations and replaying affected paths, but does not establish a percentage of labor saved by heuristics. [Ubisoft La Forge, 2020](https://www.ubisoft.com/en-us/studio/laforge/news/4bmoklgq9Hynfa87doKFfQ/artificial-intelligence-through-learning-or-pavlovian-algorithm) (accessed 2026-10-26).
2. **Reaching the bug is part of the cost.** Ubisoft's 2019 Division session describes client bots for mission completion, bug reproduction, reports, and assisting solo testing of multiplayer missions. A reproducible input trace is therefore a first-class output, not merely a pass/fail indicator. This conclusion uses the indexed official session abstract; the direct page redirected to GDC maintenance during research. [Paredes and Jones, GDC 2019](https://www.gdcvault.com/play/1026382/Automated-Testing-Using-AI-Controlled).
3. **A valid story graph is not a playable world.** Research on automated game testing explicitly treats navigation and dynamic world geometry as constraints on reachable logical states. A gate-opening flag cannot prove that a player can cross its doorway or that a companion can follow. [Prasetya et al., 2020](https://arxiv.org/abs/2009.07015) (original submission date, not the search engine's crawl date).
4. **Narrative tools already offer useful pieces.** Articy tests global variables, conditions and instructions in simulation, while explicitly excluding some template-property scripts. Ink's editor replays choices after edits. These are precedents for fast iteration, with an important boundary: an editor simulation does not establish engine behavior. [Articy scripting documentation](https://articy.com/help/adx/Scripting_in_articy.html), [inkle's ink and Inky overview](https://www.inklestudios.com/ink/) (accessed 2026-10-26).
5. **Line identity and applicability need explicit data.** Yarn Spinner separates the selection of eligible content from presentation, and uses line identifiers to resolve text and voice. Oathshaper can similarly check whether a line is still applicable, whether its recording matches the text, and whether a subtitle is allowed to finish before a transition. [Yarn Spinner saliency](https://docs.yarnspinner.dev/write-yarn-scripts/advanced-scripting/saliency), [custom dialogue presenters](https://docs.yarnspinner.dev/3.1/components/dialogue-view/custom-dialogue-views) (accessed 2026-10-26).
6. **Rules belong in the build pipeline.** Unreal's data-validation tooling supports custom asset rules and command-line CI checks. It is a useful model for running project-specific checks whenever content changes, without an LLM call. [Epic data validation documentation](https://dev.epicgames.com/documentation/unreal-engine/data-validation-in-unreal-engine) (accessed 2026-10-26).
7. **Story comprehension still needs people.** Ubisoft's narrative-review session stresses that story feedback often arrives too late to make substantial changes. A continuity checker should prepare short, reachable review scenes early; it cannot infer that a twelve-year-old understands the stakes. This uses the official indexed abstract, not a watched recording. [Dankoff, GDC 2015](https://www.gdcvault.com/play/1022166).

## Detailed analysis: recurring work and candidate rules

The following priorities are design inferences from the sources and this project's playtest, not measured rankings of industry expenditure.

| Repeated task | Deterministic or heuristic check | Evidence to return | What it cannot establish |
|---|---|---|---|
| Revisit dialogue after each quest event | Evaluate actual menu views against fact applicability; flag contradictory present-tense topics | Node, choice, world facts, shortest known reproduction | Whether an unannotated sentence implies a fact |
| Test optional actions in different orders | Bounded graph traversal, pairwise flag combinations, authored alternate routes | Exact input sequence, reached states and unexplored budget | Exhaustive coverage of an unbounded game |
| Verify quest completion and rewards | Preconditions, reachable completion, inventory conservation, idempotent reward check | Before/after state and offending transition | Whether the reward feels satisfying |
| Track companion entrances and exits | Actor travel obligation, maximum displacement/speed, portal handoff, arrival timeout | Timeline and world positions; exempt cutscenes explicitly | Whether a walk feels natural from numbers alone |
| Find missing encounter triggers | Cross trigger from each approach; check one encounter starts and cannot retrigger | Trigger volume, movement trace, event count | Whether encounter timing is dramatically right |
| Check staging after camera or mesh edits | Frustum coverage, occluder rays to head/torso, camera-volume sweep, minimum actor separation | Screenshot, camera transform, blocked rays and duration | Whether the shot is attractive |
| Recheck props and weapon attachments | Required bones/sockets, grip distance, ground contact, permitted pose ranges | Asset/socket identity and failing pose frame | All clipping, deformation or animation quality |
| Re-record and reconnect voice after edits | Text/delivery hashes, missing clips, clip duration, subtitle coverage, cancellation | Line ID, obsolete file, timing discrepancy | Acting quality, accent, emotion or pronunciation |
| Re-test after save/load | Replay the same observation before/after serialization; compare relevant state | Save revision and a state diff | Every historical save version unless fixtures exist |
| Re-check controls and prompts | Connected/active device, reachable focus, action binding and matching glyph | UI context and actual input device | Physical device feel without hardware testing |
| Triage and reproduce a reported issue | Group findings by first divergent transition and attach the trace | One task per cause, rather than one per screenshot | Ownership or priority without project policy |

## Proposed system

### Inputs owned by the chapter

- **Facts:** world and character knowledge, with producers, consumers and persistence. `tower_lit` derives from `oil_shared OR pay_returned`; it is not a second independently mutable truth.
- **Applicability:** a line or topic's required world facts. The runtime's visibility rules are checked against this independently authored contract.
- **Transitions:** dialogue choices, combat results, travel, cutscenes and inventory changes. External events need prerequisites; tests must not grant success arbitrarily.
- **Travel obligations:** actor, origin, destination, permitted portal, speed and arrival policy. A cutscene relocation is explicit and cannot silently exempt ordinary walking.
- **Presentation budgets:** camera visibility, spacing, grounding and voice timing tolerances, with project-specific overrides.

Keep these contracts small and readable. Editing a quest should invalidate its affected checks automatically. A creator should see “Mara asks why the tower is dark after you light it” with a **Replay** action; they should not have to decipher a JSON assertion.

### Three checking stages

1. **On edit:** schema/reference validation, unsupported facts, contradictory requirements, dead targets, changed voice hashes, missing sockets. No rendering or network.
2. **On chapter build:** exercise the actual narrative evaluator, bounded alternate routes, save/reload and invariant checks. Return the explored scope; a budget limit yields **incomplete**, never a clean bill of health.
3. **On playable build:** instrumented Godot replays for routes, triggers, camera occlusion, actor spacing and presentation. Sample frames and state changes. User playthrough recordings can identify the scene to replay, but are not needed for routine checks.

Humanizer and Obelus remain optional editorial consumers. The checker must run with both absent, without model credentials. An LLM may propose a fact annotation or explain a finding; it cannot declare the invariant passed or silently rewrite the plot.

### Report contract

Each finding carries `rule_id`, severity, certainty (`contract_violation` or `heuristic_suspicion`), chapter/node/asset IDs, source location, observed/expected values, witness state or replay, coverage scope, and a suggested next action. Heuristic warnings are review tasks. Only explicit contract violations should fail CI by default. Suppressions require a scoped reason and expire when the relevant content changes.

Initial rules should cover stale dialogue applicability, contradictory state claims, missing prerequisites, repeatable rewards, companion discontinuity, encounter boundaries and stale voice. Add more only when a real defect demonstrates value. Rules should consume runtime observations or runtime evaluators; duplicating game logic in a parallel Python simulator would risk two disagreeing engines.

### First Oathshaper cases

- `tower_lit` forbids the *present-tense* question “Why is the tower dark?” and Mara's dark-tower greeting. A retrospective history question remains permissible if separately annotated.
- The clerk's report establishes that she is safe. Mara's health question must have an applicable reassuring reply.
- Recruitment creates a gate rendezvous obligation. Recovering the payroll changes Mara to following the player; Ivo stays with the prisoner.
- Crossing the open garden threshold begins the briefing once; proximity alone does not begin combat while talking to Ivo.
- A manual camera orbit remains the player's chosen heading. Obstruction correction may adjust the safe position without discarding that heading.

## Measuring the 60–70% target

Use **manual continuity work**, not all development or all QA, as the denominator:

`saving = 1 - (assisted setup + triage + replay review + rule maintenance minutes) / baseline manual minutes`

Record automation wall time separately. A 90% fast test pass rate is not a 90% labor saving. Do not count writing a regression test as finding a previously unknown bug.

Run a small pilot over at least 20 comparable continuity tasks across several chapter revisions. Include naturally reported bugs and a separate seeded-fault set. Alternate manual and assisted workflows across comparable tasks to reduce familiarity bias. Record setup, reproduction, review, false-positive investigation, fixes, rechecks and rule-maintenance time separately. Keep time spent implementing a fix outside the checking-time denominator and report it separately. Report median, range, sample size, confirmed defect detection, missed seeded defects and false-positive rate. Do not combine seeded and naturally occurring detection rates.

An arithmetic example, **not a forecast**: if automatable checking accounts for 80% of this narrow workload and the tool removes 85% of that work, the gross saving is 68%. If maintaining rules and reviewing false alarms costs another 8% of the baseline, the net saving is 60%. If continuity work is only 20% of a project, a 60% continuity saving corresponds to at most 12% of total work before downstream effects. Time to market also depends on which work lies on the critical path.

Pilot exit criteria: reproduce real defects, retain readable actionable reports, and show net time saved after maintenance. Keep playtest time focused on comprehension, camera quality and combat feel. Students can compare a failing trace, its invariant, the fix and the passing replay as a practical engineering exercise.

## Implemented first slice

The standalone Rust checker uses the same `NarrativeSession` menu evaluator as the game. It has no Humanizer, Obelus, model, network or Godot runtime dependency. Authored applicability rules live in [lantern_quay.continuity.json](../../godot/content/lantern_quay.continuity.json).

Run from the repository root:

```sh
cargo run --locked -p oathshaper-core --bin check_continuity -- \
  godot/content/lantern_quay.json godot/content/lantern_quay.continuity.json
```

It is also part of `scripts/check.sh`.

| Current behavior | Boundary |
|---|---|
| Validates rule, node, flag and choice references; rejects contradictory applicability | Boolean conditions only in version 1 |
| Checks forbidden visible choices and required enabled replies | Explicit author contracts; does not infer intent |
| Flags phrases inconsistent with annotated facts | Heuristic warning; not a CI failure by itself |
| Returns the first witness flags for each finding | A logical candidate state, not a proven walkable route |
| Enumerates up to 65,536 Boolean states | Initial numeric scores and fresh choice history; budget exhaustion is incomplete |
| Exit 0: complete within scope, no contract violations; 1: violation; 2: invalid/incomplete | Exit 0 may still include heuristic warnings |

The initial implementation snapshot had 11 flags: 2,048 combinations and 3,072 rule/state matches across three rules. The [previous content report](../playtest-polish-20261026/continuity-before.json) finds two stale choices and one stale-line suspicion. The [corrected content report](../playtest-polish-20261026/continuity-report.json) has no findings. These are regression demonstrations using known playtest bugs, not independently discovered defects or evidence of labor savings.

### Current chapter runner

Run the connected pipeline with:

```sh
python3 scripts/check-continuity.py
```

The [chapter manifest](../../godot/content/lantern_quay.checks.json) selects the story, voice script, rules, authored journeys and Godot fixtures. Reports retain commands, source hashes, check observations, first failing action sequences and scope. The command works without Obelus or model credentials. `--logic-only` explicitly excludes engine behavior.

- **Dialogue repetition:** the [script checker](../dialogue-script-checker.md) follows enabled branches with actual effects, variants and choice history. Every utterance is compared with all earlier speech on its path. Equivalent state/history/heard-line sets merge; loops and budgets have explicit completion reporting. Logical entry contexts and phrase warnings require review. This also supplies a focused student exercise.
- **Narrative replay:** three authored journeys share, keep or leave the oil undecided. They call the production evaluator's enter, choose, response-return, leave and save/load operations. No world flags or combat results are injected. Their endpoint is an open garden gate; host entry access is assumed.
- **Command chapter fixtures:** each oil route completes the current robbery chapter through real scene/gameplay methods, earns combat victory, returns the recovered wages to the clerk and checks save/load and reward idempotence. Some approaches use fixture positioning; this is not a navigation bot.
- **Travel, camera and grip:** existing native checks supply geometric and animation observations. They do not judge visual appeal or acting.
- **Voice:** checks cover current clip identity, duration, cancellation and event effects. No new voice generation is required.

The [initial run](../continuity-runs/20261026-current/README.md) records the first fixture set. The [dialogue and pause follow-up](../dialogue-pause-20261026/HANDOFF.md) adds the script scanner, victory applicability and native pause-input checks. The [student lab](../tutorials/continuity-lab.md) recreates a known stale-topic defect in a copy and explains its failing trace. The [teaching proposal](011-agent-assisted-game-design-teaching.md) places this exercise after an initial agent-assisted game project.

Reusable data-authored travel contracts, automatic route discovery, task deduplication and an editor Replay button remain proposed. The report aggregates the current tests; it is not the full editor or telemetry design above. Known Godot headless-renderer and resource-exit diagnostics are retained separately from assertion outcomes. Unexpected engine errors, missing receipts and timeouts cannot produce a pass.

## Research gaps and limitations

- No consulted source establishes a general 60–70% saving for game continuity heuristics. Do not use that number in launch claims without a measured pilot.
- Most sources describe capability or process, not controlled cost studies. Studio scale and genre vary.
- GDC pages were indexed but redirected to maintenance on direct opening; only their official abstracts informed this report.
- A logical witness may be physically unreachable. Label it as a candidate until a playable route establishes reachability.
- A sound rule can still encode the wrong design intent. Keep human ownership of facts, intentional exceptions and acceptance.
- Heuristics do not replace narrative craft, acting review, visual playtesting or accessibility testing with players.

## Search methodology

Focused research using official engine/tool documentation, developer conference abstracts, Ubisoft developer material and a primary research paper. Queries included “narrative design testing quests combinatorial bugs automated”, “GDC narrative testing”, “articy testing conditions simulation”, “Ubisoft automated testing navigation”, “ink testing stories”, “Unreal data validation commandlet”, and “Yarn Spinner saliency line ids”. Nine primary sources are linked above. General news and forum results were used only as leads; their claims were not adopted. Search-engine crawl dates were not treated as publication dates.
