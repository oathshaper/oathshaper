# LCD implementation audit

## Current gate — independent repair review of `2f481ff`

Date: 2026-10-22. Reviewer: `lcd_review`. **GO: Command implementation may start against foundation `2f481ff49b69b498e600cfd8c6c753797bf3b2f2`.** No blocking correctness finding remains within this bounded foundation review. The five original findings below are resolved at this checkpoint. This accepts the shared Rust contract as a dependency; it does not accept a playable Command demo or freeze every future adapter API.

The user has now authorized a Command-first playable demo. The paused-goal statements in the initial audit below describe its earlier checkpoint. No goal status, core file, profile implementation or Godot file was changed by this review.

### Reviewed criteria and repair disposition

Reviewed the `ee7b134..2f481ff` foundation changes and handoff: numerical conservation and atomic rejection; source/grant/read-claim lifetime; complete participant authority versus effect targets; typed receipt and ledger restore; optional/replacement provider ownership; contrasting time/control models; fresh-session restore and pending-operation barriers. Current code references below are pinned to `2f481ff` under `crates/oathshaper-core/`.

| Finding | Current evidence and disposition |
| --- | --- |
| LCD-I1 | **Resolved.** `src/rpg/mod.rs:551,566,684` validates positive/affordable claims before later operations can erase them and checks negation/accumulation. Independent reserve-then-consume probes at current 10 test `i64::MIN`, −7, 0, 1, 10, 11 and `i64::MAX`: only 1 and 10 succeed, leaving 9 and 0; every rejection preserves the full state. Author tests also exercise multiple quantity claims and overflow. |
| LCD-I2 | **Resolved.** `src/rpg/mod.rs:274,316,463` computes full before/after removal deltas, binds equipment sources to their recipient or explicit remote emitter, and checks affected old slots/items. Independent mixed `ItemRead`/`BindingRead` trace releases one reader and still rejects a two-hand rebind; releasing the last permits removal, reports `item-fire`, and preserves independently learned Fire. Existing tests cover transfer to another recipient and explicit source revocation. |
| LCD-I3 | **Resolved.** Typed `Fingerprint` at `src/runtime/mod.rs:392` and candidate validation at `:844` reject malformed payload/operation/actor/principal/participants and broken receipt chains before replacement. Eight additional corruptions preserve save bytes, generation and usable prior authority. A fresh session can restore valid pending state and recover its existing receipt without paying again. |
| LCD-I4 | **Resolved for the trusted registered-profile boundary.** `Profile::participants` at `src/runtime/mod.rs:332` plus admission at `:673` check every declared controlled actor before execution **and cached receipt return**. Independent trace spends A/B/C from 10/10/8 to 2/2/0 against an uncontrolled enemy, restores into a fresh session, rejects retry with only A/B authority, then returns the original receipt under A/B/C authority without another spend. Profiles must accurately declare participants; arbitrary Rust code is not sandboxed. |
| LCD-I5 | **Resolved.** `src/runtime/manifest.rs:65,82,150` permits a minimal profile, declares unique capabilities/namespaces and rejects omitted built-in data. A replacement resource/custom-time profile runs with empty built-in resources, survives fresh-session restore at charge 6/time 7, and rejects cost 7. Additional probes reject removal of the kernel, overlapping ownership and missing provider requirements. Shared source readers now have explicit claim types. |

### Architectural coverage and limits

`tests/runtime_kernel.rs:886` exercises a turn activity paying two actions and six resource points before an interrupting reaction: actions 3→1, resource 10→4, no delivered effect; planning/execution interval advance waits for the pending decision to resolve. This is bounded Tactics/Orders phase composition evidence, not their complete adapters. `:936,1546` exercise Confluence-like joint admission, insufficient third-participant resource and revoked authority. `:1150,1238` exercise a continuous paid action, rollback of rejected observations/RNG, duplicate effect prevention, interruption and source loss with original recovery retained.

The continuous fresh-load probe additionally restores after its first effect at tick 2: resource remains 7, impact count and entropy draws remain 1 after repeated observation 1, pending work blocks transition/epoch closure, and recovery at tick 4 clears it without another payment/effect. Removing its source claim from the save rejects before replacement. These fixtures cover turn, reaction, continuous and joint-control seams without imposing Health, a common clock or party cardinality. The nine-style matrix below remains a **design mapping**; no real style is accepted by these fixture results.

Independent execution completed:

- **5 new adversarial probe functions passed**, with additional cases inside each; the 19 copied author tests were filtered out of that run. They reuse the pinned author's fixture constructors/adapters while supplying new boundary traces and assertions.
- **19 foundation tests + 23 existing narrative tests passed** in a separate locked core-crate run; **1 documentation example compiled**. The latter is API compilation evidence only.
- Foundation worktree remained clean at the reviewed SHA. No Godot build, workflow automation operation, network research or runtime/core edit occurred.

### Remaining integration obligations — do not block starting Command

These are unimplemented host/profile responsibilities, not newly discovered foundation defects:

1. **Command must connect queue and source policy.** Use complete participant declarations, exact resource/item reservations and shared source reads; atomically cancel/release dependent work on source loss. Acceptance trace: queue two wand actions, cancel one, attempt to replace the wand, then cancel the last. The independent service trace verifies the remaining reader blocks replacement; Command's queue/HUD wiring still needs its own test.
2. **GameSession must own actual activation.** `src/runtime/mod.rs:796` only prepares a transition against a quiescent source. A successful callback does not switch a profile, revoke its live producers or apply narrative rewards. Acceptance trace: failed destination preparation leaves source usable; successful activation replaces the active route and rejects callbacks carrying its old lease/generation. The first half is tested; actual activation is outside this checkpoint.
3. **Storage and narrative handoff require their later integration gate.** `save_json` proves serialized state/receipt recovery, not atomic file replacement, crash durability or once-only reward application across modules. Test interrupted save replacement and duplicated encounter reward delivery when that host layer exists. The unchanged narrative regression suite is not proof of the new cross-module handoff.
4. **Trusted profiles own game legality and hidden views.** Test actual Command target knowledge, AI control, save/pending relationships and resource/source policy. Provider declarations and participants cannot verify the honesty of arbitrary Rust implementations. This is the documented registration model, not a missing plugin sandbox.

**Minimum prerequisite to begin Command: use the independently reviewed foundation checkpoint and retain its core regressions. No additional foundation repair or implementation of the other eight profiles is required by this review.** Playable demo acceptance still needs Command content, host/bridge integration, persistence and visible input/UI evidence.

---

## Historical initial audit — `ee7b134`

Date: 2026-10-22. Independent auditor: `lcd_review`. Scope: shared contracts and contrasting mechanisms, not a repeat of all 173 proposed profile cases. At this initial checkpoint the larger implementation goal remained **paused**. Canonical changes are this report and its durable probe source under `docs/combat-design/evidence/`; build outputs live under `/tmp`.

### Initial gate decision

**The designed LCD is suitable; the draft foundation is not ready to freeze as the common dependency for nine profile implementations.** No inspected profile requires a mandatory Health field, universal clock, fixed party size, shared damage formula or common action lifecycle. Keep the reviewed boundary in [lcd.md](lcd.md). Complete a small foundation repair/test gate before dependent branches start. Individual play-system/UI detail can remain in the later profile goals.

This distinguishes three evidence levels:

| Level | Evidence and present conclusion |
| --- | --- |
| Designed | Canonical `evaluation/combat-systems` at `a868076323f8b9cd87c670855d6fea7e2c5a92ed`; LCD and independent design repairs in [lcd-evaluation.md](lcd-evaluation.md); nine separate profile packets indexed in [review-index.md](review-index.md). Suitable shared boundary, subject to ordinary implementation feedback. |
| Implemented draft | Unmerged `impl/combat-foundation` at `ee7b134064545d078fb1802b5c0bdddccc852680`. Its [checkpoint](../../.agent-worktrees/combat-implementation/foundation/docs/combat-implementation/foundation.md), lines 3/20–33, correctly labels compilation-only scaffolding, known defects and no real adapter registration. |
| Verified in this audit | Nine isolated Rust probe functions executed against that draft source. Six reproduce defects/limitations; three verify bounded positive traces. “9 passed” means the assertions describing those outcomes held; it is **not** a foundation acceptance result. No Godot, runtime profile, controller, balance or source-game test was run. |

## Prioritized findings

All draft line references below are pinned to `ee7b134`; these are implementation findings, not reasons to add game-specific mechanics to the kernel. Several were already disclosed in `foundation.md:29–32`; the probes independently substantiate them.

### LCD-I1 — P1: a consumed invalid claim can mint resources

Evidence: [rpg/mod.rs](../../.agent-worktrees/combat-implementation/foundation/crates/oathshaper-core/src/rpg/mod.rs), lines 220–248,463–484,581–589. `Reserve` inserts an unchecked amount; `ConsumeClaim` removes and negates it; only the final candidate validates remaining claims.

Executed counterexample: resource bounds 0..20, current 10; one batch reserves amount −7 and consumes that claim. The batch succeeds with current 17 and no claims. The invalid amount disappears before validation. This violates conservation even though final bounds are legal. Negating `i64::MIN` is also unsafe at the same operator; that boundary was inspected, not executed here.

Minimum repair: validate claim identity, target, strictly positive quantity and checked arithmetic before inserting/consuming it; ensure operation-local checks cannot be bypassed by later operations in the same batch. Retain final whole-candidate validation. Add negative, zero, minimum-integer, overflow, overclaim and consume-own-share cases. A rejected batch must preserve every resource, item and claim.

### LCD-I2 — P1: equipment/grant invalidation does not preserve its advertised dependencies

Evidence: `rpg/mod.rs:233–243,260–271,394–438,543–550`.

Three executed counterexamples:

1. Equip wand on A and give A its equipment-derived Fire grant; atomically unequip, transfer ownership to B and equip B. A still has Fire, because `source_exists` checks whether **any** actor equips the item. Source existence alone does not express the binding required by the grant.
2. Explicit `RevokeSource` removes the grant but returns an empty `ServiceChanges.revoked_grants`. An adapter relying on that delta to cancel dependent pending effects receives no invalidation notice.
3. Bind one item to A's left/right hands; claim the right binding for an action; rebind the same item to left only. The operation succeeds and removes the claimed right binding because it checks requested slots but not all old slots it removes.

Minimum repair: make source validity express the intended binding/recipient or an explicit remote/party grant policy; do not globally prohibit legitimate auras. Compute complete before/after revocation deltas, including explicit removal. Check claims on every affected old/new item and binding. In the same transaction, adapters must choose their declared cancellation/snapshot/refund policy and preserve independently learned grants. These are required for Cadence relic replacement, Momentum mastery, Oathbound runes and Confluence participant invalidation.

### LCD-I3 — P1: restore accepts malformed receipt semantics

Evidence: [runtime/mod.rs](../../.agent-worktrees/combat-implementation/foundation/crates/oathshaper-core/src/runtime/mod.rs), lines 629–637,740–797. Runtime fingerprints contain operation, actor, principal, expected revision and payload, but restore checks only that each fingerprint is a JSON object, plus several ledger fields.

Executed counterexample: accept one command, serialize its save, replace that receipt's fingerprint with `{}`, then restore. Restore succeeds and rotates authority, importing a receipt that cannot match its legitimate command. A later legitimate retry is rejected as semantic reuse rather than recovering its prior acceptance. This concerns malformed schema/relationships, not cryptographic protection against a player deliberately editing a save.

Minimum repair: serialize a typed fingerprint and validate required fields, principal consistency, operation/payload shape and ledger invariants before replacement. Give profile restore validation the necessary read-only candidate context for pending-action/source/claim relationships; document which kernel/profile validator owns each relationship. Preserve the existing validate-before-swap and fresh-generation behavior. Add malformed fingerprint, mismatched principal, invalid pending claim and whole-live-state-preservation cases.

### LCD-I4 — P1 before linked/team adapters: group authority is not yet available to the profile

Evidence: `runtime/mod.rs:184–195,242–249,266–276,563–566,617–629`; LCD lines 84/96–98; Confluence design lines 19/25/97 and Orders design lines 15/60.

The host lease can authorize a set of actors, but admission checks only `Envelope.actor`; `Transaction` exposes principal/audience and no lease scope or host-owned participant authorization query. Consider a lease authorizing A only and a legal-looking combo payload listing A+B+C. Admission can authorize A, while the profile lacks the actual lease scope needed to check B/C. Party membership and available resources are insufficient evidence of this command's control rights. This is an API inspection finding, not an executed exploit or a claim that trusted Rust profiles are sandboxed.

Minimum prerequisite: provide a host-validated group-command capability/participant set, or a transaction-scoped authorization query, and test that losing any required participant's authority rejects the whole command without resource/readiness changes. Controlled participants must remain distinct from effect targets; damaging an enemy must not require authority to command that enemy. A separate system-advance lease does not solve player-issued team command authorization.

### LCD-I5 — P2 API-freeze gap: replacement capabilities cannot be declared through the current manifest

Evidence: `runtime/mod.rs:14–49`, versus LCD lines 22/27/42–45/68. The manifest has a required-capability list, but its validator recognizes only six hardcoded kernel/RPG strings and has no module ownership/providers declaration.

Executed characterization: an otherwise valid empty-state profile declaring its own implemented `probe.timer/v1` capability is rejected by `Session::new`. Omitting the declaration would hide rather than validate the dependency. The current typed profile can still keep custom mechanics in its own state, so this is an incomplete registration boundary, not proof the LCD cannot support them.

Minimum prerequisite: choose a bounded registry/composed-profile manifest for registered Rust providers, with unique ownership and required-capability validation. No dynamic plugin loader is required. Demonstrate a profile that replaces/omits a standard RPG service and declares its custom timing/spatial capability without editing a universal mechanic enum. Keep empty `RpgState` legal.

Command's queue also exposes a concrete claim-policy requirement: several entries may share a read claim on one weapon while equipment mutation requires exclusivity (`Command design:29`). The draft's item-quantity and exclusive binding claims are not automatically shared source-read locks. Specify a suitable profile-owned/provider claim policy and test two queued readers against one exclusive gear edit; do not reserve multiple physical copies of the weapon to emulate read access.

## Nine-style compatibility matrix

All nine rows are **designed** in the accepted packets. “Draft seam” means a generic interface exists in `ee7b134`; none of these real adapters is implemented or behavior-tested by that checkpoint. The audit's three positive kernel traces are shared plumbing evidence only.

| Style | Clock and control | Special shared seam / draft and tested status |
| --- | --- | --- |
| Command | 100 ms simulation, full-pause menus; three actors, possession and queued orders | Exact queue reservations plus shared gear readers/exclusive edits. Generic transactions exist; read-claim policy and queue adapter untested. |
| Flow | 50 ms world ticks plus hostile half-rate accumulation; direct player plus follower modes | Canonical observations, separate clock domains, buffered intent and source invalidation. Typed Advance can carry this; no timed adapter executed. |
| Vanguard | 60 Hz fixed ticks, full-pause wheel; player aim plus orders to two companions | Heat/headroom, individual cooldowns, observed aim/contact and actor action channel. Optional state can express them; heat/observation adapter untested. |
| Oathbound | 100 ms ticks, full-pause planning; four actors with possession and conditional AI | Sustained capacity versus depletion debt, repricing at activation, source/grant invalidation. Generic records exist; known claim/grant defects block reliance. |
| Tactics | Individual turns plus campaign time; current actor and scoped reactions | Restricted action tokens, specific preparations, reaction decision leases and grid authority. Typed State/Advance fit; no turn/reaction adapter proof yet. |
| Momentum | Continuous simulation and Tactical slow/pause modes; three actors, possession distinct from recipient | Gauge subunits, accepted-cost snapshots and learned/equipped source separation. Generic transaction/projection seams exist; adapter untested. |
| Confluence | Readiness fill, one effect lane, Live/Wait; jointly command up to three actors | Atomic participant readiness/MP/items and cancellation; host authority for **every** participant remains unresolved (LCD-I4). No joint adapter executed. |
| Cadence | 20 Hz gauges with rational remainder, Active/Wait and FIFO; select ready actors | Queue lane ownership, equipment command replacement and persistent learned sources. Generic state fits; grant defects and adapter proof remain. |
| Orders | Paused planning/review, sealed 100 × 50 ms execution intervals; team plans | Max-alternative versus sum-sequential claims, pair transfers, enemy-observer separation and exact staged debit. Generic transaction fits; team authority/provider and sealed-plan proof remain. |
| Tactics + Orders stress composition | Explicit planning/initiative phase followed by simultaneous execution, with authored reaction boundaries | Same IDs/receipts are compatible. Phase/time ownership, participant leases, overlapping claims and reaction ordering must be specified and exercised in a small fixture. This is an LCD stress case, **not** a completed tenth ruleset or tested hybrid. |

The minimum architectural proof is two contrasting test adapters plus targeted joint-claim and hybrid-phase fixtures, not nine full implementations. A hybrid must choose its scheduler/authority rules explicitly; combining the two existing UIs cannot establish those rules.

## Does the arithmetic fit the different systems?

Yes at the designed boundary, provided the following quantities remain separate. These are representation checks, not verification of every profile formula. Profile references refer to the accepted branch tips in the review index; their `design.md` files remain in their owned worktrees.

| Profile / contrasting mechanism | Required shared support; arithmetic stays in the adapter |
| --- | --- |
| Command — pending queue | Reserve exact Focus and item quantities when queued, consume them on activation, share source read claims. Current 56 / reserved 28 / free 28 must not count anticipated healing as funds. Contrast Oathbound's projected, unreserved future spell price; this is deliberately not one shared queue policy. See Command 29–33. |
| Flow — multiple clock rates | World ticks and hostile half-rate action accumulation remain distinct; fixed-point integer accumulation avoids free time on pause. No kernel wall-clock advance is needed. See Flow 27–35. |
| Vanguard — heat rises toward a ceiling | Heat emission/cooling/latch is not a mana subtraction. Represent bounded heat plus profile operators or separate headroom; an ordinary consumptive claim must not silently invert its sign. See Vanguard heat contract and reviewed powered-shot cases. |
| Oathbound — debt plus sustained capacity | Keep maximum M, debt D, current U=max(0,M−D), reserve S and free U−S separate. Debt can exceed a reduced maximum; storing debt in a resource bounded by that maximum would lose it. M100/D80→M50, tonic35 gives D45/U5; restored M100 gives U55. Debt belongs in profile state or an explicitly suitable service. See Oathbound 84/112. |
| Tactics — action token and specific preparation | A two-action activity and an individually prepared Gust instance are distinct claims; rank1 Gust cannot spend a rank1 Mend preparation. Restricted quickened tokens and reactions have separate eligibility. See Tactics 30/34/36 and prepared-casting contract. |
| Momentum — fixed-point gauge and admission | Two ATB segments may use integral subunits; slow-time menus change the simulation schedule, not the unit or cost. Accepted cost and later interruption remain separate commits. |
| Confluence — atomic multi-person readiness | Claim each participant/readiness/resource together. If third actor has 7 MP against a cost 8, first two actors must retain all readiness/MP. Cap loss cancels the whole unpaid composite under profile policy. See Confluence 19/25/60/97. |
| Cadence — queued lane and teaching/grant provenance | Per-actor readiness, serial lane and Active/Wait clocks do not become a universal turn. A replaced equipment command must not erase independently learned magic/mastery. See Cadence 52/56/85 and teaching contract. |
| Orders — sealed alternatives | Mutually exclusive branches costing 2 or 5 rounds reserve max(2,5)=5; a later sequential cost 3 makes 8, not 10. Firing consumes each reserved round at its stage; canceled treatment releases its charge. See Orders 15/21/23. |

All nine can fit identity + authority + atomic changes + filtered views + recovery. The draft's scalar resource helper is optional and consumptive; it must not become the mandatory model for heat, debt, prepared spell identity, spatial claims or party readiness. A global revision and whole-state clone can be a correct conservative first implementation of atomic preparation; per-domain concurrency optimization is not a prerequisite.

## Positive evidence and remaining proof gate

The executed positive traces showed:

- A failed multi-resource batch preserves the original `RpgState`.
- A profile that mutates candidate state, draws RNG, records an occurrence/observation and then rejects leaves gameplay state/revision, entropy, occurrence set and observation cursor unchanged; only one terminal rejection receipt is added. Repeating its ID returns the stored result. Successful retry of an already accepted ID does not reroll/apply again; a newly authorized audience receives the correctly filtered cached event.
- Restoring a valid save changes generation, removes old leases, remains paused and rejects an old-generation input before ledger admission.

These are narrow unit traces. No complete turn/reaction adapter or continuous timed-observation adapter was exercised; no cross-profile switch transaction, real narrative reward integration, storage crash durability, multi-participant authority or physical host replay was demonstrated. In-memory/save-serialized receipts are not proof of WAL/fsync durability. The foundation checkpoint explicitly acknowledges this boundary.

Minimum next gate, before branching real implementations:

1. Repair LCD-I1–I3 and the already recorded claim/investment validation issues; convert reproductions into regressions expecting rejection/correct reconciliation. Bound dependency validation rather than unbounded recursive traversal.
2. Resolve LCD-I4–I5 with a small explicit API decision and adverse authority/provider cases. Preserve profile replacement and source-specific lifetime policy.
3. Implement **test-only** contrasting adapters required by LCD section 9: a paid turn activity interrupted by a reaction, and a continuous action with timed resources/canonical observations. Include a profile with no HP/party/inventory requirement.
4. Add atomic three-actor claims, a small Tactics/Orders phase composition and equipment-grant revocation fixtures; test one missing resource/participant authority, shared source readers versus exclusive equipment edits, source loss, independent learned-source survival, partial-cost failure and rollback. These are foundation test fixtures, not production profiles.
5. Add save/retry/hidden-information/epoch/switch-barrier cases, including a pending noncombat item operation. Demonstrate that failed destination preparation leaves the original source session intact. Keep core/profile namespace and narrative application ownership explicit.
6. Run focused core regressions and retain the existing narrative suite; review the resulting API/checkpoint independently. Then create profile implementation goals against that tested checkpoint. UI/assets/pacing/balance remain their later work.

This report does not resume the paused goal or implement these prerequisites.

## Reproducible probe evidence

Durable source: [lcd-foundation-probes.rs](evidence/lcd-foundation-probes.rs). It contains test-only adapters and defect reproductions; it is documentation evidence and is not registered or compiled into Oathshaper's runtime.

Scratch package: `/tmp/oathshaper-lcd-audit-ee7b134-20261022`; source `src/lib.rs` SHA256 `41b2e8f8e6783b98ddbecb3b3f0279d181ef56481d9ccbd81af177a86f23e7bf`; scratch lock SHA256 `0ba33e3c5e97b623235a37fbb18e3887ba04479064f2a18996901d91aea1215d`. The path dependency points at the unchanged foundation crate. The final run pinned serde 1.0.228 / serde_json 1.0.149 and seeded its lock from the foundation lock; an earlier exploratory run used cached newer compatible versions and returned the same outcomes. No repository lockfile changed.

```sh
cargo test --offline \
  --manifest-path /tmp/oathshaper-lcd-audit-ee7b134-20261022/Cargo.toml --lib
```

To recreate the temporary package, start in the canonical repository, set `foundation_checkout` to a checkout of the exact draft SHA, and run the following. Dependencies must already be cached for offline execution. This setup writes only the temporary package.

```sh
foundation_checkout=./.agent-worktrees/combat-implementation/foundation
audit_tmp="$(mktemp -d /tmp/oathshaper-lcd-audit.XXXXXX)"
python3 - "$audit_tmp" "$foundation_checkout" <<'PY'
from pathlib import Path
import json, shutil, subprocess, sys
scratch, foundation = map(Path, sys.argv[1:])
assert subprocess.check_output(['git', '-C', str(foundation), 'rev-parse', 'HEAD'], text=True).strip() == 'ee7b134064545d078fb1802b5c0bdddccc852680'
(scratch / 'src').mkdir()
shutil.copyfile('docs/combat-design/evidence/lcd-foundation-probes.rs', scratch / 'src/lib.rs')
core = foundation / 'crates/oathshaper-core'
(scratch / 'Cargo.toml').write_text(
    '[package]\nname = "lcd-audit-probe"\nversion = "0.0.0"\nedition = "2021"\n'
    '[dependencies]\n'
    f'oathshaper-core = {{ path = {json.dumps(str(core))} }}\n'
    'serde = "=1.0.228"\nserde_json = "=1.0.149"\n'
)
shutil.copyfile(foundation / 'Cargo.lock', scratch / 'Cargo.lock')
PY
cargo test --offline --manifest-path "$audit_tmp/Cargo.toml" --lib
```

Final observed result: 9 probe functions completed, 0 failed. Names separate defect reproductions from bounded verification:

```text
reproduces_negative_claim_credit
reproduces_equipped_grant_wrong_recipient
reproduces_explicit_revoke_missing_delta
reproduces_old_binding_claim_bypass
reproduces_restore_accepts_empty_fingerprint
reproduces_profile_capability_rejected_by_fixed_kernel_list
verifies_batch_failure_keeps_all_resources
verifies_rejection_entropy_cursor_rollback_and_retry
verifies_restore_fence_and_pause
```

The essential conservation reproducer, using public draft APIs, is:

```rust
let mut r = RpgState::default();
r.apply(&[
    Mutation::PutResource(Resource {
        id: "mana".into(), owner: "A".into(), unit: "point".into(),
        minimum: 0, maximum: 20, current: 10,
    }),
    Mutation::Reserve(Claim {
        id: "c".into(), owner: "A".into(), action: "cast".into(),
        target: ClaimTarget::Resource { resource: "mana".into(), amount: -7 },
    }),
    Mutation::ConsumeClaim { id: "c".into() },
]).unwrap();
assert_eq!(r.resources()["mana"].current, 17); // observed defect, not desired behavior
```

No broad repository scan, external research, workflow automation, Godot build or real profile implementation occurred. Unrelated canonical Godot edits observed during the audit were left untouched. The historical profile scenario totals remain proposed acceptance obligations.


## Reproducing the independent repair probes

The current review scratch package is `/tmp/oathshaper-foundation-review-2f481ff`. Its combined `src/lib.rs` SHA256 is `d217cd2fa86394dc9e509bb29ca899706ecb6ea73c72dd0214f63354fef50457`; scratch lock SHA256 is `baff824f1f846df1d4f06f5d5a860ecad41e4dbce6f03356232d929e5af65b19`. Probe dependencies were pinned to serde 1.0.228 and serde_json 1.0.149; the separate core run used the foundation's unchanged lock (serde 1.0.229 / serde_json 1.0.154). Both runs succeeded.

To reproduce, create a temporary Cargo package with an `oathshaper-core` path dependency pointing at a checkout of exactly `2f481ff49b69b498e600cfd8c6c753797bf3b2f2`, plus those pinned serde dependencies. Copy that commit's `crates/oathshaper-core/tests/runtime_kernel.rs` into the temporary `src/lib.rs`, then append the Rust block below. Run:

```sh
cargo test --offline \
  --manifest-path /tmp/oathshaper-foundation-review-2f481ff/Cargo.toml --lib review_
```

The separate core command, from the foundation checkout, was:

```sh
cargo test --locked --offline \
  --manifest-path crates/oathshaper-core/Cargo.toml \
  --target-dir /tmp/oathshaper-foundation-core-review-target
```

<details>
<summary>Durable independent probe extension source</summary>

```rust
// Independent review extensions; fixture helpers above are pinned to 2f481ff.
#[test]
fn review_boundary_claims_and_partial_reader_release() {
    for amount in [i64::MIN, -7, 0, 1, 10, 11, i64::MAX] {
        let mut r=RpgState::default(); r.apply(&[Mutation::PutResource(resource("mana",10))]).unwrap();
        let before=r.clone();
        let result=r.apply(&[reserve("x","mana",amount),Mutation::ConsumeClaim{id:"x".into()}]);
        if [1,10].contains(&amount) { assert!(result.is_ok()); assert_eq!(r.resources()["mana"].current,10-amount); }
        else { assert!(result.is_err(),"amount {amount}"); assert_eq!(r,before); }
    }
    let mut r=gear();
    r.apply(&[
        Mutation::Reserve(claim("read1",ClaimTarget::ItemRead{item:"wand".into()})),
        Mutation::Reserve(claim("read2",ClaimTarget::BindingRead{actor:"A".into(),slot:"right".into(),item:"wand".into()})),
        Mutation::ReleaseClaim{id:"read1".into()},
    ]).unwrap();
    let before=r.clone();
    assert!(r.apply(&[equip("A","wand",&["left"])]).is_err()); assert_eq!(r,before);
    r.apply(&[Mutation::ReleaseClaim{id:"read2".into()}]).unwrap();
    let changes=r.apply(&[Mutation::Unequip{actor:"A".into(),slots:vec!["left".into(),"right".into()]}]).unwrap();
    assert_eq!(changes.revoked_grants.iter().map(|g|g.id.as_str()).collect::<Vec<_>>(),vec!["item-fire"]);
    assert!(r.has_ability("A","fire"));
}

#[test]
fn review_cached_group_retry_requires_every_live_participant_after_fresh_load() {
    let mut host=HostAuthority::default(); let mut r=gear();
    r.apply(&[Mutation::AdjustResource{id:"C".into(),delta:1}]).unwrap();
    let mut s=Session::new(Turn,turn_state(),r,0,"review-group",&mut host).unwrap();
    let all=lease(&mut s,&mut host,&["A","B","C"],"public",Role::Player);
    let intent=env(&s,&all,"joint",Some("A"),TurnCommand::Group{members:vec!["A".into(),"B".into(),"C".into()],target:"enemy".into()});
    let accepted=s.submit(intent.clone()).unwrap(); assert_eq!(accepted.status,Status::Accepted);
    let save=s.save_json().unwrap();
    let mut fresh=Session::new(Turn,turn_state(),gear(),99,"review-group",&mut host).unwrap();
    fresh.restore_json(&save,&mut host).unwrap();
    let limited=lease(&mut fresh,&mut host,&["A","B"],"public",Role::Player);
    let mut retry=intent.clone(); retry.generation=fresh.generation(); retry.lease=limited;
    assert!(fresh.submit(retry.clone()).is_err()); assert_eq!(fresh.save_json().unwrap(),save);
    retry.lease=lease(&mut fresh,&mut host,&["A","B","C"],"public",Role::Player);
    assert_eq!(fresh.submit(retry).unwrap(),accepted); assert_eq!(fresh.save_json().unwrap(),save);
    assert!(fresh.submit(intent).is_err());
    assert_eq!((fresh.rpg().resources()["A"].current,fresh.rpg().resources()["B"].current,fresh.rpg().resources()["C"].current),(2,2,0));
}

#[test]
fn review_fresh_pending_load_preserves_payment_observations_and_fences() {
    let mut host=HostAuthority::default(); let mut s=continuous(&mut host);
    let l=lease(&mut s,&mut host,&["A"],"public",Role::Player);
    let start=env(&s,&l,"start",Some("A"),ContinuousCommand::Start); s.submit(start.clone()).unwrap();
    s.advance(env(&s,&l,"hit",None,Tick{at:2,observation:1,reject:false})).unwrap();
    let saved=s.save_json().unwrap();
    let mut fresh=continuous(&mut host); fresh.restore_json(&saved,&mut host).unwrap();
    assert_eq!(fresh.save_json().unwrap(),saved); assert!(fresh.submit(start).is_err());
    assert!(fresh.prepare_transition(|_,_|Ok(())).is_err()); assert!(fresh.close_epoch().is_err());
    let mut corrupt:Value=serde_json::from_str(&saved).unwrap(); corrupt["rpg"]["claims"]=json!({});
    let generation=fresh.generation(); assert!(fresh.restore_json(&corrupt.to_string(),&mut host).is_err());
    assert_eq!(fresh.generation(),generation); assert_eq!(fresh.save_json().unwrap(),saved);
    let l=lease(&mut fresh,&mut host,&["A"],"public",Role::Player); fresh.resume_after_restore();
    fresh.advance(env(&fresh,&l,"duplicate-hit",None,Tick{at:2,observation:1,reject:false})).unwrap();
    assert_eq!((fresh.state().impacts,fresh.entropy_draws()),(1,1));
    fresh.advance(env(&fresh,&l,"recover",None,Tick{at:4,observation:2,reject:false})).unwrap();
    assert_eq!(fresh.rpg().resources()["A"].current,7); assert_eq!(fresh.state().impacts,1);
    assert!(fresh.state().pending.is_none()); fresh.ensure_quiescent().unwrap();
}

#[test]
fn review_typed_receipt_corruptions_preserve_generation_and_authority() {
    let mut host=HostAuthority::default(); let mut s=Session::new(Probe,0,RpgState::default(),7,"r",&mut host).unwrap();
    let l=lease(&mut s,&mut host,&["A"],"public",Role::Player);
    s.submit(env(&s,&l,"good",Some("A"),ProbeCommand{fail:false})).unwrap();
    s.submit(env(&s,&l,"bad",Some("A"),ProbeCommand{fail:true})).unwrap();
    let saved=s.save_json().unwrap(); let generation=s.generation();
    for i in 0..8 {
        let mut v:Value=serde_json::from_str(&saved).unwrap();
        match i {
            0=>v["receipts"]["good"]["fingerprint"]["operation"]=json!("bogus"),
            1=>v["receipts"]["good"]["fingerprint"]["actor"]=json!(""),
            2=>v["receipts"]["good"]["fingerprint"]["expected_revision"]=json!(99),
            3=>v["receipts"]["good"]["fingerprint"]["payload"]=json!(null),
            4=>v["receipts"]["bad"]["reason"]=json!(null),
            5=>v["receipts"]["bad"]["events"]=v["receipts"]["good"]["events"].clone(),
            6=>v["receipts"]["bad"]["revision"]=json!(2),
            _=>v["receipts"]["good"]["fingerprint"]["unknown"]=json!(true),
        }
        assert!(s.restore_json(&v.to_string(),&mut host).is_err(),"corruption {i}");
        assert_eq!(s.save_json().unwrap(),saved); assert_eq!(s.generation(),generation); assert!(s.view(&l).is_ok());
    }
}

#[test]
fn review_optional_provider_ownership_and_restored_replacement_execution() {
    let valid=CustomProvider.manifest();
    for i in 0..3 {
        let mut m=valid.clone();
        match i {
            0=>m.providers.retain(|p|p.id!="runtime.kernel"),
            1=>m.providers.push(ProviderSpec::new("shadow","runtime.child","custom/v1")),
            _=>{m.providers[1].requires.insert("missing.provider/v1".into());},
        }
        assert!(m.validate().is_err());
    }
    let mut host=HostAuthority::default();
    let mut s=Session::new(CustomProvider,CustomState{charge:10,pulses:0},RpgState::default(),0,"custom-review",&mut host).unwrap();
    let l=lease(&mut s,&mut host,&[],"public",Role::System);
    s.submit(env(&s,&l,"spend",None,4)).unwrap();
    s.advance(env(&s,&l,"time",None,7)).unwrap();
    let save=s.save_json().unwrap();
    let mut fresh=Session::new(CustomProvider,CustomState{charge:10,pulses:0},RpgState::default(),1,"custom-review",&mut host).unwrap();
    fresh.restore_json(&save,&mut host).unwrap(); fresh.resume_after_restore();
    let l=lease(&mut fresh,&mut host,&[],"public",Role::System);
    assert_eq!(fresh.submit(env(&fresh,&l,"overdraw",None,7)).unwrap().status,Status::Rejected);
    assert_eq!(fresh.state(),&CustomState{charge:6,pulses:7}); assert!(fresh.rpg().resources().is_empty());
}
```

</details>
