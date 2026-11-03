# Check repetition across dialogue branches

The script checker follows enabled choices through the same `NarrativeSession` used by the game. It compares every spoken line with all earlier lines on that conversation path, including the player's voiced choices. It runs locally without Obelus, Humanizer, Godot or model credentials.

## Run it

From the repository root:

```sh
cargo run --quiet --locked -p oathshaper-core --bin check_dialogue_script -- \
  godot/content/lantern_quay.json godot/content/voice_script.json \
  > dialogue-review.json
```

It also runs in `scripts/check.sh` and `python3 scripts/check-continuity.py`. The latter produces a Markdown summary linking to the findings. A final optional argument sets the state budget; the default is 250,000.

**Exit 0 means the stated exploration scope completed. It does not mean the dialogue has no repetition.** Findings are review warnings. Exit 2 means invalid input or incomplete coverage, including an exhausted budget. Read `complete_within_scope`, `limitations`, and `findings` together.

## What a finding shows

Each warning includes both speakers, their exact spoken text, node or choice identifiers, a repeated phrase, the number of intervening spoken lines, assumed starting flags, and an action path. For example, the previous oil exchange produced:

```text
enter:mara_greeting
choice:mara_greeting/share_oil

Corsair: Here. This should get the tower burning again.
Mara:    That's enough to get the tower burning again. ...
Phrase:  get the tower burning again
```

Review the whole exchange before changing it. “I'll deliver the knurled beets” / “Ah, the knurled beets, of course!” produces a warning too, even when the repetition is an intentional affectation. The tool does not judge delivery or silently rewrite dialogue.

The current chapter retains one warning: Mara asks the player to check on the clerk; Corsair agrees. That repetition confirms the player's commitment. The [review record](dialogue-pause-20261026/REVIEW.md) explains the retained and corrected findings.

## How it explores permutations

1. Find each conversation entry and the flags used by its connected choices, variants and return menus.
2. Enumerate those Boolean starting contexts. Ask the production evaluator which text and choices apply.
3. Follow every enabled choice. Preserve effects and completed-choice history. Resolve NPC text variants at each step.
4. Read the actual player speech from `voice_script.json`, using the choice source ID. NPC speech uses the manifest's spoken text when available, otherwise its dialogue text. Menu labels are not treated as voice lines.
5. Compare the new line with every distinct line already heard on that path. A finding needs a shared contiguous phrase of at least three words, with at least two words outside a small common-word list. Case and punctuation are normalized.
6. Merge states with identical narrative state, choice history and sets of heard utterances. Their future eligibility and possible repetition pairs are equivalent. Retain one concrete witness path for each finding.

Returning from a response to its question menu is silent in the game and adds no speech. Explicitly replaying the same authored line is excluded from warnings. Repeatable loops therefore do not require enumerating infinitely many identical performances. Distinct orders that expose an echo in opposite directions can produce separate findings.

Authored `chapter:<sequence>:<index>` voice sequences are also scanned in their specified order. The report counts these separately.

## Boundaries

- Boolean entry contexts include logically possible but physically unreachable worlds. `witness_flags` are assumptions; the path is evidence of dialogue evaluation, not of walking there.
- The scan covers permutations within a connected conversation and within each authored cutscene sequence. It does not permute arbitrary visits to different NPCs across the whole game.
- Numeric scores start at authored defaults. Numeric-gated conversations mark the result incomplete. An enabled transition that fails evaluation also marks it incomplete.
- State and memory growth are bounded. The report retains unexplored frontier and omitted-enqueue counts; reaching the budget cannot report complete coverage.
- Phrase matching will miss paraphrases and implications. It may flag a useful acknowledgment. It cannot decide whether a performance makes repetition funny, moving or annoying.
- The voice manifest must reflect the current script. Audio playback and text/clip identity are checked by separate native tests; this scan does not listen to recordings.

The source is [dialogue_script.rs](../crates/oathshaper-core/src/dialogue_script.rs). Its regression cases cover conditional exclusivity, effects changing available branches, silent returns, player speech differing from menu labels, distant repetition, repeatable loops and incomplete budgets. Those examples let students inspect why a warning appears and challenge an incorrect interpretation.

## Student exercise

Copy `lantern_quay.json` to an ignored `.artifacts/` directory. Change `mara_thanks.text` to start with “That's enough to get the tower burning again.” Run the command above with the copied story and the existing voice script. The changed NPC line has no matching manifest entry, so the checker uses that text; the player's actual spoken choice still comes from the manifest. This is a checker exercise, not an updated playable voice pack.

Find the warning and trace its two lines to their source. Explain why this repeats information, while “The whole payroll. Thank you.” can be a useful acknowledgment. Then propose one example the phrase heuristic would miss. Do not remove a finding simply to make the report look clean.

Related: [continuity lab](tutorials/continuity-lab.md), [teaching proposal](research/011-agent-assisted-game-design-teaching.md), [current chapter results](dialogue-pause-20261026/current-game/README.md).
