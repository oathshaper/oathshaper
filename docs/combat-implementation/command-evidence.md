# Command runtime evidence

## Slice A — core checkpoint, 2026-10-22

Foundation base: dbbf7bab4409023625181da926e2dfa097403850 (independent foundation gate authorized by root). Core implements the existing typed Profile/Session contract; RpgState owns resources, shared source claims, item reservations, bindings and grants. No Godot/foundation changes are part of this checkpoint.

Implemented: three deployed party actors and reserve Ivo; seeded enemy/companion orders through private AI leases; 100 ms windup/impact/recovery with approach; nested pause ownership; possession/selection; source-scoped attacks, magic and tech; camp gear and inventory transfers; persistent depletion; camp rest; craft/buy/sell; attributed skill checks; clerk level-up; native save/restore prompt and generation fencing. Public action payloads reject unknown fields and cannot inject effects. Geometry uses the root-owned JSON and typed host observations.

Ten integration tests cover CMD-01, CMD-02, CMD-05, CMD-07, CMD-08, CMD-10, CMD-12 and CMD-13 subsets, plus geometry observation fencing and pure previews. These are core checks, not complete CMD case acceptance or native UI evidence.

Remaining for slice B: exact CMD-03 recorded-roll fixture, complete six-build allocation/respec and source shrink, guest/progression policy reconciliation, full AI role rules and replacement, retreat/retry adversarial coverage, grants ghost presentation, claimed capacity/source loss, weapon sets/upgrades/salvage, full restore cross-ledger validation, UI/controller integration, physical Deck verification. Rendering and native flow are owned by root.

Test commands: `cargo test -p oathshaper-core`; `cargo clippy -p oathshaper-core --all-targets -- -D warnings`; `git diff --check`. Results recorded with the commit handoff.

## Follow-up: recorded encounter and host cursor

The private `#[cfg(test)]` CMD-03 recorded-roll fixture passes through tick82: Health80/50/54, Mara Focus12, battery2, 300 trial XP and45 credits. The fixture supplies explicit enemy target choices through ordinary AI leases; production has no roll injection API.

`CommandGame::next_observation_sequence(producer: &str) -> u64` exposes the next committed host cursor. Discarding staged geometry after an AI admission does not consume a sequence. Host adapters must query this method for each new frame, including after restore. A regression covers both invalidation and restored cursor continuity.

## Slice B checkpoint — progression, source loss and restoration

Six private unit fixtures and twelve public facade tests pass. Added evidence:

- CMD-04 lens capacity/depletion survives remove and re-equip; its lost binding remains a disabled ghost.
- CMD-06 clerk level7 yields maximum69/current61 with debt8; a complete 100-credit respec preview with99 credits changes nothing.
- CMD-15 six visible complete serial respec plans produce distinct disciplines, Focus/skill budgets and legal equipment; acquisition-time prerequisites and persistent Health depletion are checked. These plans cover the implemented power catalog; late feat/power chains remain content work.
- CMD-17 maximum86/debt40/current46 becomes56/40/16. Bind18 and Mend16 cancel as whole orders; Gale10 remains/free6 despite queue reordering. Save/restore preserves the result.
- CMD-19 named helper contributes the entire check18 while the player remains speaker.
- Restoring paid windup with manual+ledger+selector pauses retires obsolete UI token ownership when the safe restore prompt is acknowledged, preserving paid resources and queued intent. Logical automatic reasons remain separately acknowledgeable.

Core also adds typed salvage and installed arc-edge upgrade transactions, knowledge-scoped enemy lists/targets, stricter build/capacity/claim/impact-cursor restore checks, and disabled ghosts for lost grants. `revoke_item_source` is a trusted Rust host method; the public JSON parser cannot obtain its system authority.

Manifest content/rules version is now2 (`command-garden/v2`). Earlier slice-A runtime saves are deliberately incompatible; no migration or accepted production save format is claimed. Shared garden geometry remains `garden-1`.

Still incomplete: complete role AI (hazard/Bind thresholds/Assist/hold semantics and replacement), weapon-set commitments, full retreat lifecycle, broad level advancement beyond the current concrete clerk plan, exact all-19 scenario completion and native input/render acceptance. These remain work, not waived gates.

## Slice C — independent findings and live-AI repair

Independent reviewer `lcd_review` reproduced six defects against canonical bef88c4 / core bdf677a. This checkpoint repairs them; independent reacceptance remains pending:

| Finding | Repair and executable regression |
| --- | --- |
| Accepted Start replay overwrites original checkpoint | Lifecycle side effects require a newly committed revision; exact save/checkpoint equality after retry |
| Rejected restore acknowledgment unpauses kernel | Root foundation atomic `resume_and_submit`; conflicting ID leaves pause intact, ordinary command rejects, identical successful acknowledgment returns cached receipt |
| Missing unpaid dressing/item claims restore successfully | Complete exact claim sets, item payment marker and shared equipment reads validated; missing item or source claims reject atomically |
| Minimum signed coordinate panics | Bounded comparisons replace `abs`; both integer extremes reject without panic or live mutation |
| Occluded ranged order within weapon range never moves | Follow validated route until firing LOS exists; garden bed trace moves by tick10 and attacks by tick55 |
| Heavy armor incorrectly blocks Mend | Heavy-trained Mara can order Mend; Gale rejects for armor, Mend rejects under Silence |

Additional executed checks cover atomic replacement of waiting AI orders, complete defeat retry, failed approach release at tick60, pending camp rest, two-target Bind priority, source-specific unarmed/bow reach, Gust wall-limited displacement with no damage, Veil area absorption by damage type, and ordinary default AI finishing the seed20261022 encounter after only Mara's opening Bind/Gale orders. The original recorded CMD-03 still reconciles tick82 Health80/50/54, Focus12, battery2 and one reward. Its recorded rolls remain private test fixtures only.

A native integration report found a visible sentinel eight meters from a crossbow user caused AI to hold under the old six-meter search cutoff. Root agreed pursuit should limit movement, while an already legal ranged attack should proceed. Core now caps AI approach travel at six meters beyond reach and projects the actual hold/decision reason. The default-AI regression is a separate ordinary-seeded encounter, not the recorded CMD-03 oracle.

Current core verification: **16 private Command tests + 16 facade tests**. Full crate tests, clippy with warnings denied and whitespace checks are run for this checkpoint. Root owns rendered/native evidence and the independent review verdict; these counts do not establish physical Deck acceptance or all nineteen complete scenario gates.

### Remaining scope, explicitly retained

- CMD-01–08,10–17,19 have named core fixtures/subset coverage. CMD-09 and18 require native input/controller evidence owned by root. No all-nineteen-complete claim is made.
- Rolled encounter initiative remains a fixed authored initiative order in this trial. Broader weapon sets, alternate body equipment fixtures, complete level20 feat/power content, hazard avoidance, Riposte/Interpose/Rally/Expose roles and all exploration inventory recipe variants remain later content/integration work.
- Defeat/retry is tested; exit-based unseen retreat is implemented but lacks a full native retreat completion fixture. Core actor movement uses the shared authored garden footprint; native collision/render parity belongs to root's adapter tests.
- The current rendered hound may be a mechanical ward-hound mesh. Core retains the design's organic Briar hound/body and CMD-03 mechanics; this is a documented presentation mismatch pending art integration.
- Saves are now manifest version3. No migration from earlier prototype saves is claimed.

### Narrow rereview CR08 — legal self-targeted healing

Independent rereview found that an ally-target action aimed at its caster requested nonexistent self-LOS and stalled in unpaid approach. Validated actor targets equal to the caster now count as spatially clear only for ally-target abilities. Existing living, body, grant, armor and Silence validation still applies. Two added regressions pass: clerk consumes the final dressing at activation, restores its paid windup without the absent item, and heals exactly once (42→56); Mara's self-Mend pays16 Focus and heals25→43, while Silence still rejects it. Focused tests, all-target clippy with warnings denied and diff checks pass. Total Command tests now18 private +16 facade; this paragraph records the focused repair run, not a rerun of every suite.
