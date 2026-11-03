# Dialogue review and reconciliation

Date: 2026-10-26. Requested scope: expire obsolete conversation options, remove accidental player/reply echoes, and build a reusable checker for dialogue permutations. Preserve the approved dockside payroll robbery.

## Tools actually used

- Humanizer's router selected fiction and one fiction critic. [Router receipt](humanizer-route.json).
- The routed audit ran with `--semantic`. Its output contains lexical findings and semantic questions, not a semantic approval verdict. [Original audit](humanizer-semantic-before.json).
- One review-only critic inspected the exported alternatives, with instructions to preserve the approved plot and avoid treating mutually exclusive branches as continuous dialogue. Its material findings are reconciled below.
- The local Obelus CLI ran on both exports: `node ../obelus/scripts/review.mjs --profile fiction --output <report> <export>`. [Before](obelus-before.json.gz), [after](obelus-after.json.gz). These are gzip-compressed, unmodified JSON reports. Obelus explicitly records semantic/factual/voice-fit verification as not run; its deterministic findings are not author approval.
- The revised script received another [deterministic Humanizer audit](humanizer-after.json), plus a direct comparison of changed spans against the critic's findings.
- The independent Rust scanner ran on both the previous committed story/voice manifest and revised content. It uses the actual narrative evaluator to distinguish available sequences from merely adjacent lines in an export.

Exports: [before](dialogue-before.md), [after](dialogue-after.md). These are source-location indexes of alternatives, not a performance transcript.

## Consolidated decisions

| Cause and evidence | Classification | Resolution |
|---|---|---|
| Ivo's `ask_about_gate` and `ask_sentries` remain available after the guards are defeated; the former sends the player to fetch an already recruited Mara. Vendor directions still place Ivo at the gate. | Agent-editable | Host victory now sets a persisted fact. Ivo's preparation choices expire; Mara and clerk greetings also reflect victory before loot collection. Recruitment retires the fetch-Mara topic. Vendor directions retain places and omit the changing NPC location. |
| Corsair `share_oil`: “get the tower burning again”; Mara `mara_thanks` immediately repeats the same phrase. | Agent-editable | Mara thanks the player and describes filling the reservoir. Her clip was regenerated. |
| `ivo_gate_history` and `ivo_sentries` both repeat the near-decapitation anecdote; history also repeats the greeting's closed-gate explanation. | Agent-editable | History explains why Ivo needs help; the machine question explains their relationship to the raider and the risk of being surrounded. The authored pause before “We'll need someone…” remains. Both clips were regenerated. |
| The clerk's known-robbery greeting can recap pursuit directions; Mara asks the player to check on the clerk and the player agrees. | Intentional-keep | The clerk recap supports a player returning before pursuit; completed-topic history already disables the asked account, and victory now expires it. Corsair's agreement acknowledges a requested action. The scanner retains that warning for review. |
| Repeated “Until next time,” source-label openings, qualification counts, and the final exported goodbye appear in Humanizer/Obelus findings. | Intentional-keep | Goodbyes belong to separate exits; source labels are metadata. “Heard,” “would,” and similar phrasing express character knowledge or a request. Removing these to improve an aggregate prose score would damage the dialogue. |

No author questions remain for these changes. No further plot revision was made. The unharmed clerk, stolen wages on the raider, darkness aiding the theft, optional early oil, Mara's healing role, and Ivo guarding the captured raider are protected facts.

## Scanner results

Using the same final checker on each content revision:

| Content | Explored dialogue states | Conditional entries | Warnings |
|---|---:|---:|---:|
| Previous commit `8e89867` | 9,402 | 187 | 6 |
| Revised script | 11,804 | 363 | 1 |

Both complete their stated scope with no unexplored frontier. The larger revised state space includes the new victory fact. Five authored cutscene groups were also scanned in each version. Findings are directed pairs: the two orders of Ivo's anecdote count separately.

The previous six warnings are the oil echo, the obsolete garden-gate directions, Corsair's agreement to check on the clerk, the closed-gate recap, and both orders of Ivo's anecdote. The remaining warning is the intentional agreement. [Before report](repetition-before.json), [after report](repetition-after.json).

`repetition-initial-window.json` preserves an early diagnostic from the initial three-line-window prototype; it is not the final coverage method or the baseline for the table above. The shipped checker compares all earlier speech within a conversation path. [Algorithm and limits](../dialogue-script-checker.md).

## Unresolved review limits

The deterministic Humanizer and Obelus finding types remain present after revision: repeated multiword phrase, repeated sentence start, lexical qualification count, restatement cluster and repeated conclusion. The high-confidence repetitions/openings are the separate goodbyes and export metadata described above. Their continued presence is disclosed rather than treated as a clean report. There is no new high-confidence finding category.

The script scanner detects shared phrases, not semantic paraphrases or acting affectations. Logical entry contexts include impossible world states. Native checks verify new clip identity, timing and cancellation; no listening review or new rendered playthrough was performed in this pass.
