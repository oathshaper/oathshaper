# RPG design review workspace

Status: design milestone complete. The LCD and all nine profile packets passed independent design review with recorded repairs. Started 2026-10-22 from main checkpoint `e0c5006`. The [LCD evaluation](lcd-evaluation.md) preserves five findings, their repairs and independent re-review; the [final branch index](review-index.md) records all profile tips and 173 proposed acceptance cases. Runtime and human design acceptance remain separate.

This work treats combat as the complete playable RPG system: party control, archetypes, progression, skills, equipment, inventory, magic, technology, abilities, defenses, conditions, encounter rules and their UX. The current demo implements profile/actor previews and practice animations; the specifications here do not claim those systems are playable.

## Deliverables

1. Review and commit the [least common denominator](lcd.md) on `main`. Keep mechanical policy replaceable.
2. Branch every profile from that exact reviewed commit: Command, Flow, Vanguard, Oathbound, Tactics, Momentum, Confluence, Cadence and Orders.
3. On each branch, commit a source-backed design, worked encounter/equipment/progression examples and an agentic evaluation; retain findings and repair commits.
4. Publish a local branch/commit review index on `main`, with comparison, limitations and how to inspect/rework each candidate. Keep profile proposals independent until human review.

A Tactics/Orders composition is a foundation stress case and a separate experimental design if the nine required profiles are complete. No profile is accepted merely because it shares a working menu skin.

## Run contract

- Authority: user requested the design pass, per-profile branches and intermediate commits, and explicitly authorized committing the existing work to `main`. workflow automation remains disabled at the user's instruction; the agentic SDLC review/Git discipline is applied directly.
- Scope: design documents, source references, proposed contracts, scenario traces and evaluation records. Runtime combat implementation, paid asset generation, publication, licensing changes and remote pushes are outside this pass.
- Source boundary: checkpoint `e0c5006` captures the previous preview/research work. Its baseline Rust suite passed 23 tests; the catalog export matches 36 builds. Earlier graphical evidence is historical, not a new acceptance run for these designs.
- Ownership: main agent owns LCD, synthesis and repairs. Profile authors own only their declared profile directories in isolated branch worktrees. Independent reviewers are read-only and do not review their own authored profiles. Every worker uses an explicit workdir.
- Milestones: LCD → each profile proposal → independent evaluation → necessary repair/review → local checkpoint → final synthesis. Subsequent profiles begin only after LCD review.
- Controls: local version history and ownership (`operating_evidence`); runtime/release acceptance (`not_applicable` to this design-only pass); source/idea attribution (`implemented` via linked research notice); profile behavior correctness (`designed`, evaluated with scenarios, unimplemented).
- No required human decision is parked. Designs choose documented defaults and record reversible alternatives; human acceptance of individual designs remains a later review, not a prerequisite to authoring them.

## Bounded work and review

Limits are `observed_only`, not controller-enforced. No model or billing claims are inferred from tool routing. Keep the inherited model and effort unless an observed failure requires a separately explained change.

| Milestone | Normal / maximum work | Exit or contraction |
| --- | --- | --- |
| LCD | One design pass, one review, up to two repair passes; 20 / 35 tool calls; 20 / 35 minutes | Commit the agreed boundary or record a concrete unresolved design issue; do not expand into runtime implementation |
| Each profile | 8–15 focused source operations; 25 / 40 total tool calls; 20 / 40 minutes | Stop broad searching once decision evidence is sufficient; preserve exact source gaps and finish the coherent design packet |
| Independent review | One bounded packet; 8 / 15 tool calls; 8 / 15 minutes | Return cited findings and scenario counterexamples; no repository-wide crawl, builds or duplicate full tests |
| Repair | Focused edits and checks; at most two passes per finding before a new decision | Retain failed proposals and unresolved issues; never re-label them accepted |
| Synthesis | Branch ancestry, packet completeness, links and substantive comparison | Reserve this work and necessary repair capacity before optional hybrid expansion |

Keep tool output under roughly 6,000 tokens per inspection, cite large sources by path, and record exact completion commits rather than copying transcripts. These bounds govern individual work packets; they do not shrink the user's full nine-profile objective.

## Profile packet acceptance

Each packet must contain all of the following, with a clear division between reference facts and original proposed design:

- Edition-specific prior art, direct sources, unsupported assumptions and intentional deviations.
- A playable loop and complete time/control contract, including cancellation, interruptions, AI, defeat and recovery.
- Archetype coverage and mechanically different builds; skills, progression, respec and noncombat uses.
- Equipment eligibility, upgrades, grants, inventory capacity and presentation, loot/economy, crafting policy, transactional edge cases and save identity.
- Ability acquisition/preparation, targeting, costs, defenses, conditions, immunity, stacking, cooldowns and companion interactions; magic/tech distinctions where applicable.
- Concrete keyboard/controller/Steam Deck UX, menu ownership and accessibility, party sheet and morality placement.
- A worked garden encounter plus a gear/grant change and a progression decision, with numeric examples checked for consistency and labeled as proposed.
- At least eight falsifiable acceptance scenarios including failure/recovery, and a branch-local evaluation with cited findings and dispositions.
- LCD capability mapping and any genuine pressure on the foundation; no silent core edits from a profile branch.
- Next implementable vertical slice, excluded future content, asset needs and remaining uncertainties.

See the [research rights notice](../research/NOTICE.md). All names and numerical designs authored for Oathshaper remain distinguishable from the mechanics of the referenced games.

## Branch checkpoint

See the [review index](review-index.md) for frozen foundation and profile branch tips, individual review state and local comparison instructions.
