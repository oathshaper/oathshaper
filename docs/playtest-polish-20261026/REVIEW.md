# Dialogue and continuity review

Date: 2026-10-26. One bounded revision following the playtest. No further plot rewrite.

## Protected story

The unlit tower made the robbery harder to see. Mara sends the player to the clerk's office. The clerk is unharmed; her payroll chest was forced open. Mara helps with healing; Ivo has confined the raider and his two mechanical guards in the garden. The player recovers the payroll from the raider, returns it to the clerk, and Mara can buy oil. Sharing oil can light the tower earlier. The garden is not a route out of town. Records remain optional history.

## Review actually performed

- Humanizer router and semantic audit over the exported dialogue.
- One review-only fiction/continuity critic; no delegated rewrite.
- Local Obelus CLI, fiction profile, [before](obelus-before.json.gz) and [after](obelus-after.json.gz) the revision (unaltered JSON outputs, gzip-compressed for storage). Both reports identify their coverage: deterministic completed, source mapping complete, semantic and factual verification not run by Obelus itself.
- Separate semantic similarity audit using the local writing-audit tool. This is an editing aid, not a story-causality oracle.
- Independent Rust continuity checker and Godot gameplay checks. Neither requires the editorial tools.

The router interpreted the word “rewrite” inside a negative instruction as revision intent. The critic was explicitly constrained to review-only. Actual changes were authorized by the user's playtest requests.

## Consolidated causes and resolution

| Cause | Classification | Applied correction |
|---|---|---|
| Mara's dark-tower topic and base greeting survive the light event | Agent-editable | Hide the topic when oil is shared or payroll returned; add the lit-tower greeting below later quest variants |
| Mara asks whether the clerk is hurt, but the player cannot answer | Agent-editable | “She's safe. He stole the payroll. Will you come with me?” |
| The guards' boat origin is unsupported and “hired machines” obscures who controls them | Agent-editable | Ivo calls them the raider's guards and describes his own failed attempt to stop the raider |
| “Get Mara” runs into the reason without a beat | Agent-editable | Authored paragraph break, separately generated speech segments and a 550 ms inter-segment pause; body speech gestures stop during quiet audio |
| Escort promises have no continuous movement implementation | Agent-editable | Forward-facing weighted walk clips, route following, door handoff and travel-state save/load; explicit cutscene transfers remain |

## Findings retained after the revision

Obelus: four medium-priority deterministic findings before and after. The separate semantic audit: five medium-priority findings before and after, no high-severity findings. Counts are not acceptance scores.

- **Intentional keep:** repeated `flag / id / pay_returned / value` strings are exported condition metadata, not lines the player hears. They account for the high-confidence repeated-phrase finding and several recap findings.
- **Intentional keep:** “heard,” “would,” and similar terms convey witness knowledge or ordinary requests in dialogue. Their aggregate lexical count does not establish unclear speech.
- **Intentional keep:** taking payroll and returning payroll share vocabulary because they are distinct actions involving the same object. Combining them would erase a gameplay step.

The accepted semantic findings were checked against the changed source spans and implemented travel behavior. No author questions remain. Facial expressions are not implemented: the current rigs have no facial blendshapes. Speech timing and body-animation transitions are the delivered improvement. Acting quality still needs listening and playtesting.
