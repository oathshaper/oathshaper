# Story review and replacement brief

## Outcome

Reject the ledger/public-passage premise. Its causal structure depends on geography the author rejects and makes a document necessary to confront an existing physical danger. More explanation cannot make the existing garden a route out of town.

## Priority findings

1. **Geography:** current-story.md:9,105 describes the garden as the crew's only dry way home. The playable terrace has one quay approach; no onward rescue route or stranded crew is presented. **High confidence; agent-editable after the author's robbery decision.**
2. **Ivo's motivation and progression:** current-story.md:37,102,111 replaces a safety problem with legal permission. demo.gd:228 requires records_collected before offering the garden encounter. Hostile faction assignment is unconditional for adversaries (command/content.rs:265); main.gd starts the combat session without a ledger instruction. The confusing connection comes from quest gating, not a ledger-powered combat mechanic. **High confidence; agent-editable.**
3. **Empty revelation:** current-story.md:111 promises to identify who ordered the closure; lines125,128 only restate that the seal is private. The antagonist's purpose remains unexplained and the payoff repeats the setup. **High confidence; agent-editable.**
4. **Unshown resolution:** current-story.md:130 says Mara can now bring her crew home. demo.gd:648 records victory and announces that future action. There is no rescue payoff in the scene. **High confidence after runtime inspection; agent-editable.**

## Intermediate replacement (superseded by the author)

A raider stole Mara's pay chest. Ivo pursued him into Lantern Garden and holds the entrance, but the thief has two mechanical bodyguards. The player agrees to help; Mara joins to recover her money and keep the party alive. The guards attack people approaching their employer and the chest. Defeat clears the way to the visible chest. The player retrieves it and hands it back to Mara. The returned chest remains beside her and the completed quest records the return.

The clerk and archive offer optional local history. They do not authorize help, change enemy allegiance, or block combat. Oil sharing remains an optional favor with its own small consequence, not permission to help a robbery victim.

## Keep

- Mara's practical support role and Ivo's watchkeeper role.
- The original garden, quay, tower and adversary assets.
- The vendor's dry humor; avoid turning every NPC into a quest announcer.
- A clear cause, action, and visible consequence shared by the three playable combat styles.

## Tool evidence and limits

Actual Obelus scripts/review.mjs ran against current-story.md: five deterministic findings, complete source mapping, semantic verdicts not run by that CLI. Humanizer routed one fiction critic; its four structural findings were checked against source and runtime. The local embedding audit ran with pinned MiniLM: one sentence pair above threshold, no paragraph pairs. This is a repetition signal, not plot approval. Ignore source-snapshot headings as review scaffolding, and keep repetition needed for alternative dialogue branches. No third-party model was given private text.

No reader comprehension result is claimed. The old review missed the geometry and progression defects; functional route tests did not validate the story's meaning.

## Final author-approved revision

See [final-story.md](final-story.md). The author retained the robbery and restored the clerk's role: the crime is discovered in her office, and the empty, broken chest stays there. Darkness from the unlit tower let the raider cross the court unnoticed. The raider carries the payroll pouch. Mara's missing wages explain her involvement; Ivo has chased the thief to a garden with a single entrance. The return goes to the clerk, who pays the dockworkers. Tower illumination provides the visible ending. Early donated oil is an alternative lighting path, not a requirement to rescue the wages.

### Resolution of the four findings

1. Geography: Ivo holds the garden's sole entrance. Nobody claims it leads out of town.
2. Causality: the office establishes a witnessed crime and lost wages; it never controls enemy aggression. The two machines protect their employer. The gate requires a recruited healer, with an explicit explanation; oil and optional historical records are irrelevant to this requirement.
3. Antagonist and reward: the Crimson Raider carries the missing money. Victory, looting, and returning it are separate states. The chest stays visibly open in the office and receives the returned coins.
4. Ending: the clerk pays Mara and the tower illuminates the actual quay. A skippable closing shot shows the tower and docks. Save/load retains both payroll and lighting outcomes.

### Final tool pass and retained findings

Actual Obelus reviewed the final source snapshot (`obelus-final.json`): one medium lexical heuristic, no high findings. Its ordinary words include "that", "over", and "enough". These are natural spoken references and quantities, retained intentionally. The local semantic audit (`semantic-final.json`) flags two repeated pairs: the opening and skippable conversation both establish the crash; the mutually exclusive endings both establish tower oil. These serve separate entry paths and are intentional. The CLI does not perform semantic plot acceptance; its generated S1 plan is not an executed judgment. No second autonomous rewrite was performed after the author-approved revision. No reader comprehension study or voice-performance acceptance is claimed.
