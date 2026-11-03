# UI copy and chapter continuity

Latest: [Command HUD, equipment, party and inventory review](command-completion.md). Previous correction: [chooser delivery, full menu preview, and rendered Obelus review](menu-correction.md).

Reviewed 2026-10-22 using `$humanizer`, its routed nonfiction critic, and the local `../obelus` Markdown adapter. One authorized revision pass addressed five causes. The player-facing chapter has no dependency on the number or identity of combat styles.

## Applied changes

| Finding | Revision | Disposition |
| --- | --- | --- |
| Repeated slogans and comparisons between versions of the garden break the fourth wall | Removed from the launcher, inspector, journal and HTML study. Style explanations stay in the configuration screens. | Agent-editable; applied |
| Opening stakes are vague or contradict the clerk knowing where the records are | The closed garden gate creates a concrete dispute over public passage; the clerk identifies the archive. | Agent-editable; applied |
| Retrieving the records produces another vague teaser | The ledger establishes a public right of passage and identifies a civic stamp that differs from the gate seal. | Agent-editable; applied |
| Sharing oil somehow opens a dangerous flooded route | Ivo can use the lit pier marker to watch the raised crossing; the lower road remains flooded. | Agent-editable; applied |
| Implementation commentary appears inside the adventure | Removed trial/practice chatter and atomic-operation explanations. Kept concise availability, controls, costs, save boundaries and confirmation text. | Agent-editable; applied |

The [shared chapter](../../godot/content/garden_chapter.json) supplies the briefing, evidence, objective and resolution. The party recovers a substituted seal; the clerk can challenge the closure with that seal and the ledger. Returning to camp after victory preserves the resolved story instead of repeating the opening briefing.

## Evidence and limits

- [Before inventory](copy-before.md) and [after inventory](copy-after.md): source-literal extraction with source locations and deduplication. The initial inventory contains 1,170 unique strings, including short format fragments and internal diagnostics.
- Reproduce extraction with `python3 scripts/export_ui_copy.py --output docs/ui-copy-review/copy-current.md`.
- [Humanizer routing](humanizer-route.json): nonfiction, medium confidence. The mixed interface inventory is not an essay; essay rhythm and conclusion rules do not transfer automatically.
- [Before semantic audit](humanizer-semantic-before.json) and [after semantic audit](humanizer-semantic-after.json): local offline embeddings, no authorship classifier. Both report ten heuristic groups, none high severity. This is not a quality score or a claim that every flag is resolved.
- [Obelus batch summary](obelus-summary.json): the full inventory exceeded its 500-unit limit, so it was split into batches of at most 80 source sections; later long batches used 30. Raw batches are retained locally at `/tmp/oathshaper-ui-copy-audit-20261022`; compact evidence is kept here.
- Source paths dominate repetition and semantic-similarity flags. Repeated labels across different screens, precise “all future reservations” rules and “All styles” navigation are intentional keeps. Proposed “fast strikes” and “faster shield recovery” remain inside explicitly marked build previews; they are not evidence of implemented systems.
- Controls, costs, availability and destructive-action warnings were protected. Fictional dialogue voice was preserved, including Mara's opening line. Research attribution and the HTML study's status notice remain.
- Godot captures inspect actual 1280×800 briefing, outcome, launcher, profile cards and Command Overview. Literal extraction does not prove every dynamically assembled sentence, shader label or engine-generated error was reviewed. Physical Steam Deck and voice playback acceptance remain separate.

No accepted critic finding remains unapplied. No author question was needed for these reversible story and UI changes. Later release scope and asset/voice decisions are tracked in the implementation plan.
