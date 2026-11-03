# LCD design evaluation

Scope: [LCD ADR](lcd.md) and [run contract](README.md). This is an agentic design evaluation. No new RPG runtime exists and no combat behavior test is claimed.

## Baseline and intermediate commits

- User-approved main checkpoint: `e0c5006`, preserving the existing front end, 36 actor previews, practice poses and research.
- Initial design: `8bbcbbb`, containing LCD, run contract, profile packet format and structure-only checker.
- Fresh baseline: `cargo test --workspace --locked` passed 23 tests before the source checkpoint; catalog export parity passed. Existing Godot capture results remain historical evidence in `../combat-front-end.md`.
- Staging revealed five Markdown hard-break lines flagged by `git diff --cached --check` in report 008. They were normalized in `8bbcbbb`; no history was rewritten. Subsequent diff checks pass.
- Checker characterization: missing packet rejected, complete structural fixture accepted, duplicate case ID rejected and false runtime status rejected. These validate only packet structure; no gameplay inference follows.

## Independent review 1

Reviewer: `/root/lcd_review`, separate read-only agent/context. Reviewed initial ADR and selected research sections. It evaluated all ten stress cases, optional-service replacement, identity/authority, transactions, deduplication/replay, knowledge filtering, grant invalidation, skills/progression/loot, save switching and native UX. Verdict: **request changes before profile branching**.

| Finding | Evidence in initial commit | Counterexample | Disposition |
| --- | --- | --- | --- |
| LCD-01 · blocking | `lcd.md` invariants 3/8 and save section | Load a save from before potion command C; delayed C has the restored epoch but no receipt and spends the restored potion | Repaired in design: live activation generation is host-owned, fresh on restore, distinct from persistent logical identity; stale inputs/leases/callbacks rejected; restored actions rebind observations |
| LCD-02 · blocking | Switching prohibited only in encounters; world skills and reservations exist elsewhere | Crafting reserves a campaign item; switch lets the other profile use it while the old operation can later complete | Repaired in design: atomic lifecycle barrier with complete pending-operation inventory; initial implementation rejects unsettled operations; destination/ownership/story access validate before activation |
| LCD-03 · clarification | Deduplication described payload equality only | Same ID/payload changes actor or command kind; wrong cached acceptance returned | Repaired in design: fingerprint complete semantic envelope; validate current authority and filter receipt audience before returning cached receipt |
| LCD-04 · clarification | Atomic bookkeeping not enumerated | Failed preparation advances RNG, or effects commit without a durable occurrence receipt | Repaired in design: speculative entropy/observation cursors and all applicable receipts join the same atomic commit |

## Reasoned counterexample traces

These traces evaluate the written contract; they were not executed in Godot.

1. Save S contains potion P and logical epoch L. Active generation G1 consumes P via C. Restoring S validates first and activates G2. A delayed G1/C request is rejected before receipt lookup or mutation. A new G2 command can intentionally consume P. A saved logical action resumes only through a new G2-bound observation producer.
2. Craft K reserves item I outside combat. Switch request reaches the lifecycle barrier. The initial policy detects K and rejects with the pending-operation reason; no item transfer, refund or profile activation occurs. Creator cancels K through its documented settlement, then retries the switch with a new command ID and current revision. Destination validates against the resulting state; either the full switch commits or source state remains active.
3. Preparing an attack obtains speculative random sample R and plans cost/effect/receipt. A competing revision invalidates its read set. Terminal rejection commits only its command rejection receipt and ledger sequence; there is no effect, cost, occurrence receipt, observation consumption or entropy advancement. A later newly identified accepted command consumes from the committed entropy stream, with deterministic ordering supplied by its profile.

## Review 2

Reviewer: `/root/lcd_recheck`, fresh read-only context, reviewed `152a1dc` and the diff from `8bbcbbb`. It found LCD-01 through LCD-04 resolved and no additional overconstraint across the ten stress cases. It requested one clarification before acceptance:

- **LCD-05:** initial repair text said rejection publishes no receipt, contradicting invariant 3's terminal-result guarantee. An authorized resource-rejected command C could later return a different error or succeed when retried with the same ID. The new repair defines admitted commands' durable terminal rejection receipts, a separate ledger sequence, and new IDs for renewed attempts. Unauthorized/stale-generation input cannot append the trusted ledger. Internal unpublished preparation retries remain possible.

## Review 3

Reviewer: `/root/lcd_receipt_review`, fresh read-only context, reviewed `152a1dc..1039333`. Verdict: **accepted design clarification**, no blocker in the focused scope. It verified terminal retry stability, deduplication ordering, gameplay-state isolation and authority admission. Combined with review 2's resolution of LCD-01 through LCD-04 and ten-profile stress assessment, this completes the independent LCD design gate. No runtime validation was performed.

The foundation freeze follows this evaluation record. `design/combat-lcd` identifies that common checkpoint; the main-branch review index will record its exact SHA and the profile branches derived from it. Human review may still revise any design.
