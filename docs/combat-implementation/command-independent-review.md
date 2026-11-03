# Command independent implementation review

Date: 2026-10-22. Reviewer: `lcd_review`, independent of Command authors. **Current verdict: PASS for the first Command vertical slice independent review gate at `a5298c1` plus `fd79ce9`. CR-01–08 are resolved within the reviewed scope.** Root owns final integration/native acceptance; its reported 44/44 native checks are distinct from the independently executed core tests below. This does not accept all nineteen scenarios, the complete Command content set, physical controllers or Steam Deck behavior. The accepted foundation boundary is retained.

## Scope and provenance

- Canonical branch at capture: `impl/combat-command`, HEAD `bef88c44ebd8ead28f4af6201ac6d91969244009`, incorporating core `bdf677a`. Core was clean at capture; root's bridge/trial/UI work was uncommitted. Review/test copy: `/tmp/oathshaper-command-review-bef88c4`; captured overlay hashes are in its `source-snapshot.json`.
- Read the accepted Command design and nineteen scenarios in `.agent-worktrees/combat-design/command/docs/combat-design/profiles/command/`, current implementation evidence, core operations/validators/geometry, and native entry/bridge/trial/ledger/input/save paths. No source edits, foundation suite rerun, workflow automation, external publication or Godot rebuild. workflow automation was explicitly disabled; the combined engineering method's bounded evidence/ownership/review controls were applied without a native workflow claim.
- Budget: normal 25 tool calls / 30 minutes, maximum 40 / 45; one bounded discovery pass and targeted probes, with a protected repair-review/report reserve. Budgets are observed limits, not controller enforcement.
- Overlay references below use captured `command_trial.gd` SHA256 `3939d025ad168ac0ef2d67db350263b7a25530cd9e8cabd9a5d7501dcedfe413`, `command_bridge.rs` `43f759aec798a856f79114471f453bc50f0a363960a4f85de6fc120ff4338bd3`, and `command_ledger.gd` `cf0035d0e8d2548124db9329ed52a30ccf83aadcb4925ac705cc270eba7eaac7`. Later root edits are not silently treated as this snapshot.

Criteria: rejected-operation atomicity across facade and kernel; command/occurrence identity; resources and exact claims; source lifetime; valid paid/pending restore; pause ownership; host geometry authority; practical entry→orders→Ledger→save/restore reachability; and honest separation of fixture, native automation and physical controller evidence.

## Narrow repair recheck — 2026-10-22

Core repairs `de95fae` and `81cfd06` were integrated as `48bc0fa` and `a5298c12575684856061e88b5b5d1297d617d7ed`, on foundation `7bb798b`. The reviewer exported that exact core/geometry cut to `/tmp/oathshaper-command-rereview-a5298c1`, reduced only the temporary workspace to its core member, and ran the focused checks below. The native script was captured separately with SHA256 `1acb81744c5e51a31c52d1d16d224ea520dccd24b88aee3e2b81dad72c6d5a9d`. Mutable story/copy cleanup was excluded.

| Finding | Repair inspected at this cut | Independent result |
| --- | --- | --- |
| CR-01 | `command/mod.rs:615–646`: facade checkpoint changes only on newly committed revision | PASS: replay Start after an intervening queued order preserves the complete outer save and original camp checkpoint. |
| CR-02 | `command/mod.rs:613–640`: stable typed restore-token payload plus atomic foundation resume/submit | PASS: conflicting ID leaves bytes unchanged; stale acknowledgement and an ordinary command retain the restore barrier; fresh acknowledgement succeeds; cached acknowledgement after another command preserves complete save. |
| CR-03 | `command/mod.rs:240–323`: exact resource/item/shared-source/binding claim count and paid-item relationship | PASS: missing consumable claim, missing claim+instance, paid-marker mismatch and removal of each individual equipped-source read reject without replacing live save. A final-unit dressing used on another ally disappears, its paid windup restores, and subsequent ticks proceed. |
| CR-04 | `command/combat.rs:613–639`: range movement clamp only when LOS is clear | PASS: original 7.5 m occluded crossbow trace moves within the 3 m ten-tick speed limit, preserves original approach deadline if still approaching, and attacks by tick 55. |
| CR-05 | `command/mod.rs:217–230`: inclusive integer coordinate bounds | PASS: `i64::MIN`, `i64::MAX`, −100001 and 100001 reject without panic, live-save mutation or generation change. |
| CR-06 | `command/rules.rs:148–160`: Mend armor exception after common magic/Silence check | PASS: trained heavy-armored Mara admits Mend, rejects Gale for armor, and rejects Mend under Silence. This executes the author's focused fixture independently. |
| CR-07 | Captured `command_trial.gd:270–283,326–327,396–405,627–651`: modal-owned Previous/Next buttons and sticks use the same handler, with focus neighbors; confirmation remains isolated | PASS by source inspection, supported by root's prior native R3/B result. The added buttons themselves have not been independently exercised on a native or physical device. |

Executed results: **16 existing facade tests and 16 existing private Command tests passed**. The latter run also included two copied/strengthened narrow private fixtures (18 total). **Five independently written public repair checks passed.** A sixth public test deliberately asserts the newly found CR-08 defect and also passes; that sixth result is defect evidence, never acceptance. The first draft of the expanded test incorrectly assumed Lunge owned a resource claim (it has two source/binding reads), and initially attempted the valid consumed-item case on self; the former harness expectation was corrected, while the latter exposed CR-08. No foundation, narrative or Godot build was rerun, and author-reported broader counts are not presented as reviewer execution.

### CR-08 — P2, resolved: legal self-targeted healing waited for nonexistent LOS

**Evidence at `a5298c1`:** `command/combat.rs:19–28` special-cases only target kind `self`; a legal ally target represented by `actor_id == action.actor` instead requires `los:clerk:clerk`. `command/space.rs:32–33` deliberately excludes same-actor pairs from LOS requests.

**Executed trace:** start garden; queue clerk `inventory.use` of `dressing-stack-1` targeting actor `clerk`; acknowledge contact; advance five ticks with valid fixture observations. The order remains unpaid `approach`, deadline 60, travel 0 at its starting position. There can be no matching self-LOS observation. Mend on its caster has the same mechanism; low-health self-dressing AI uses this legal target form. The original CR-03 validator repair passes when the consumed item targets another ally.

**Minimum repair:** treat an already validated same-actor ally target as geometrically clear, while retaining living/biological/Silence/source eligibility and ordinary geometry for other actors. Regress self-dressing through activation, final-unit consumption and paid save/restore, plus self-Mend payment/effect. This was sent to the author; no canonical or author-worktree core changes were made by the reviewer.

**Repair/recheck:** `fd79ce9` changes only the runtime `action_clear` predicate (plus tests/evidence): an actor target equal to the acting actor is clear only for an ally-target ability (`command/combat.rs:25–30`). The reviewer applied those committed source/test files to the frozen scratch cut, inspected the three-line rule change, inverted the original self-target defect assertion and added a self-target version of the paid-final-unit restore check. **All seven independent public repair checks passed.** Both new author fixtures were independently executed: dressing consumes its final item at tick 0, restores paid windup at tick 5, heals Health 42→56 exactly once; Mend spends 16 Focus and heals Health 25→43, while Silence rejects it. The targeted private run was 2/2. Thus CR-08 is closed, without bypassing biological, living, source or Silence validation.

**Gate:** PASS for the first vertical slice within the independent review scope; there are no remaining CR-01–08 blockers. Root reports 44/44 current native checks, separately owned, and retains responsibility for integrating this final core fix and its native/commit gate. No broad review or future profile implementation is required by these findings. Full nineteen-case acceptance, rolled initiative, complete progression/weapon-set/content coverage, physical-controller/Deck behavior and newly mutable UI copy remain outside this verdict. Retain the coverage table below as historical baseline, not the current repaired state.

## Historical baseline findings

### CR-01 — P1: cached encounter start replaces the retry snapshot

**Evidence:** `crates/oathshaper-core/src/command/mod.rs:504–529` captures a fresh pre-submit snapshot and assigns it whenever the returned receipt is accepted, including a cached receipt. Related obligation: CMD-11 and shared receipt idempotency.

**Executed trace:** submit one valid `encounter.start`; saved checkpoint has phase `camp`. Resubmit the identical envelope. Kernel session bytes stay identical, but the facade checkpoint now has phase `encounter`. A duplicate request changes the future Retry result and can preserve spent resources/progress that should have been reset.

**Repair:** apply checkpoint/host lifecycle changes only for a newly committed transition; cached acceptance must return the original outcome without recapturing state. Check the complete outer save before/after retry, then exercise defeat→Retry against the original pre-encounter contents.

### CR-02 — P1: a rejected restore acknowledgement unlocks the kernel

**Evidence:** `command/mod.rs:500–526` calls `resume_after_restore()` before submitting the acknowledgement. Related obligation: CMD-10 and rejected-operation atomicity.

**Executed trace:** save after a successful command; restore; acknowledge the restore token using that command's already-used ID. Submission returns a fingerprint error. The facade still displays `restore_prompt`, but a new `party.select` command is accepted and changes recipient because the underlying session is already unpaused.

**Repair:** make resume plus acknowledged transition atomic, including admission errors, gameplay rejection and cached retry. Preserve the exact public acknowledgement identity when mapping to the trusted command; a failed acknowledgement must retain both pause layers, and an identical successful acknowledgement retry must be recoverable. Root reports a new `resume_and_submit` foundation seam at `7bb798b`; integration/recheck pending at this report stage.

### CR-03 — P1: restore accepts an unpaid consumable order with neither item nor claim

**Evidence:** `command/mod.rs:225–281` checks resource claims but does not require dressing's item claim/paid-item relationship; dressing is excluded from the grant check. Related obligations: CMD-10/13.

**Executed trace:** queue clerk using `dressing-stack-1`; serialize; remove the corresponding claim and item from candidate `rpg`; restore succeeds with the unpaid dressing order still queued. This demonstrates incomplete candidate validation, not a cryptographic save-authentication requirement. It was not necessary to run the malformed order to establish the invalid published commitment.

**Repair:** derive and validate the exact expected unpaid resource/item/source/binding claims for every queued/approaching action; validate paid consumable snapshots and their released quantity claims separately. Reject malformed target/phase relationships before swap. A rejected corrupt candidate must preserve live bytes, generation and leases. Add missing-claim-only, missing-item-plus-claim and paid-item mismatch cases, plus a valid final-unit-consumed save.

### CR-04 — P1: an in-range but occluded order never follows its valid route

**Evidence:** `command/combat.rs:501–534`, especially `remaining = max(distance - range, 0)` and `travel = min(speed, waypoint_distance, remaining)`. Related obligation: CMD-14.

**Executed numeric trace:** clerk with crossbow at `[2,5]` m, sentinel at `[9.5,5]`, another party member at `[9,2]` revealing it. The shared garden adapter returns a multi-waypoint route around `east_south_bed` and blocked direct LOS. Distance 7.5 m is below the 15 m range, so computed travel is zero. After ten ticks clerk is still at `[2000,5000]` mm in approach despite the valid route; the deadline can then fail a reachable order.

**Repair:** advance along the validated route until a range-and-LOS-valid firing position exists. The range stop condition applies only once firing geometry is legal. Retain speed limits, original approach deadline, knowledge constraints and bounded replanning.

### CR-05 — P2: malformed integer coordinates panic during restore validation

**Evidence:** `command/mod.rs:218` uses signed `abs()` to validate a serialized `i64` position.

**Executed trace:** set saved player X to `i64::MIN`; `restore_json` panics with “attempt to negate with overflow” in the debug core build, caught by the review harness. This is a validation-boundary panic, not a demonstrated Godot release-process crash. Unchecked release arithmetic also does not provide a valid range rejection.

**Repair:** compare against the allowed inclusive range without negation, and use checked arithmetic for save-controlled sums/deadlines. Require an error plus unchanged live state for minimum/maximum integer coordinates; do not rely on catching panics in the bridge.

### CR-06 — P2: the armor predicate incorrectly blocks Mend

**Evidence:** `command/rules.rs:142–152` rejects every `ab.magic` in heavy armor; `command/content.rs:34` makes Mend magic. CMD-07 explicitly permits Mend on a living ally with any armor while blocking Gale. This finding is source-inspected, not a separate executed probe.

**Repair:** give armor eligibility its own predicate/field; retain Mend's magic tag and Silence restriction. Test trained heavy armor: Mend permitted, Gale blocked; under Silence both magical powers remain blocked while Disrupt remains tech.

### CR-07 — P2: actor cycling is unavailable in target selection

**Evidence:** captured `godot/scripts/command_trial.gd:260–272,551–552,577–578`. Target choice is a generic modal; `_input` returns before L3/R3 handling whenever that modal exists, and it has no focusable actor-cycle controls. CMD-18 requires cycling in selectors/targeting, discarding only uncommitted target preview, while confirmation blocks cycling.

**Trace:** select Mara→choose Bind→target menu→press R3: no recipient transition is handled. A confirmation and a target selector currently have the same early-return rule.

**Repair:** distinguish modal contexts; permit cycling in selector/targeting, preserve pause and per-actor category/focus, discard the uncommitted preview, and keep confirmation isolated. Root reports this repair in progress with native R3/B automation; source or scripted-input evidence does not establish physical-controller acceptance.

## Corrections and work already in progress

A preliminary claim that bare-floor clicks could not reach `_queue_target` was **withdrawn** after checking literal tabs: the call is outside actor-to-point coercion and does accept floor points. No floor-click defect is retained from that source claim. Root subsequently ran an actual-pixel regression and found a distinct routing problem: `SubViewportContainer` consumed pointer input before the root unhandled-input callback. Root added a viewport-owned `WorldInput` relay and reports 34/34 native checks passing, including a real floor pixel, R3 target cancellation, B preserving contact pause, and save/resume. The reviewer inspected the relay and regression assertions; this result remains root-owned native evidence. The original test's direct `_queue_target` calls did not cover that route.

`flow_design` identified AI replacement, chosen-source weapon math, richer role AI/Assist and retreat as already in progress before findings were sent. They are not relabeled as new discoveries. The author has acknowledged all six core findings and is preparing focused regressions. Root owns CR-07 and native integration; `command_design` owns queue editing/category-focus work. Repairs require a narrow review against their actual SHA/overlay before this report changes verdict. Root's current target-cycle code passes source recheck for L3/R3; the original focusable Previous/Next actor requirement is still pending in the selector/target modal at this intermediate review, because generic HUD requests are blocked while it is open. Root has been sent that narrow remainder.

## Evidence and scenario coverage

Executed against frozen core `bef88c4`:

- **12 existing public facade tests passed.**
- **6 existing private Command scenario fixtures passed**, including exact tick-82 garden totals, source shrink, lens debt, level 7, six builds and helper check.
- **5 independent defect-reproduction functions passed their assertions describing the defects**: CR-01–05 (CR-05 catches the expected panic). This is evidence of defects, not acceptance. The first exploratory filter also matched the existing `preview_has_no_mutation` test; the final `review_reproduces` filters isolated the new tests.
- Native bridge, launcher, HUD/Ledger, transport and save flow were source-reviewed. No physical controller, Steam Deck or end-to-end Godot run was independently executed by this reviewer. The reviewer inspected root-generated contact/combat screenshots at `/tmp/oathshaper-command-contact.png` and `/tmp/oathshaper-command-combat.png`; these show legible resource/queue/pause information and actual rendered encounter states, not independent input execution. Root's native runs have a separate evidence owner.

| Cases | Demonstrated subset / remaining acceptance |
| --- | --- |
| CMD-01/02 | Exact resource reservations, durable rejection, nested pause and paid-stop/readiness tests pass; full input flow remains native evidence. |
| CMD-03 | Exact recorded-roll encounter fixture passes. Production uses fixed `INITIATIVE` (`content.rs:5`), whereas design line 23 describes encounter initiative rolls; this is an explicit remaining design/implementation reconciliation, not proof of rolled initiative. |
| CMD-04/05 | Lens debt/ghost and atomic staff replacement pass. Complete construct/body/stale competing equip and native comparison paths are not established by those tests. |
| CMD-06/15 | Concrete clerk level 7, 99-credit rejection and six serial respec fixtures pass. Full progression catalog/story unlocks and every invalid acquisition case remain incomplete as disclosed. |
| CMD-07 | Source/relationship rejection subset passes; heavy-armor Mend fails the authored rule (CR-06). Full Silence/construct combinations are not accepted here. |
| CMD-08 | Selection/possession/reserve distinction passes; atomic waiting-AI replacement is a later author repair. |
| CMD-09/18 | Source-review only for native modal ownership; CR-07 remains open at captured overlay. Physical controller acceptance unavailable. |
| CMD-10 | Paid windup/generation/cursor positive traces pass; CR-02/03/05 block robust malformed/rejected restore acceptance. |
| CMD-11 | Original retry snapshot can be replaced by duplicate Start (CR-01). Complete defeat→Retry→victory/reward native path not independently accepted. |
| CMD-12 | Craft/replay/resource atomicity passes; full salvage/protected/stale-sale/native workbench path not established by this test. |
| CMD-13 | Shared dressing overreservation passes; invalid restore is accepted (CR-03). Single-unit cancellation/new-ID/paid-miss sequence remains a separate obligation. |
| CMD-14 | Geometry freshness checks pass; valid occluded approach stalls (CR-04). |
| CMD-16 | Trial exit/persistence boundary is separate from full cross-profile migration, which the current contract explicitly defers. Do not call the full scenario complete. |
| CMD-17/19 | Numeric source-shrink priority and named full-check helper fixtures pass. Native presentation, invalidated-helper and full replay permutations remain separate checks. |

Entry wiring exists: title `combat_frontend.gd:240`→`main.gd:81`→real `CommandBridge`→camp→contact/orders→Ledger→opaque trial save/restore; campaign/front-end is suspended and returned. `command_trial_test.gd` exercises much of this path but uses direct method calls for some targeting and calls `_finish` directly for exit. This is useful integration coverage; it does not establish every visible control, complete outcome loop, physical device behavior or full nineteen-case acceptance.

## Original minimum gate (superseded by the repair recheck)

Repair CR-01–07, retain their failing/pre-repair evidence, rerun focused regressions and obtain a narrow independent recheck. Finish the already-declared Command/host slices and reconcile the nineteen-case map before claiming complete Command. No other profile implementation or broad foundation rerun is required by these findings.

## Reproduction source

The frozen scratch workspace contains only the core crate plus authored geometry. Its workspace member list was reduced to core in `/tmp`, requiring scratch-only lock reconciliation via `--offline`; canonical Cargo files were unchanged. To recreate, export `Cargo.toml`, `Cargo.lock`, `crates/oathshaper-core` and `godot/content/command_garden.json` from `bef88c44ebd8ead28f4af6201ac6d91969244009` into a temporary directory, keep only the core member, and copy the pinned public `tests/command.rs` to `tests/independent_review.rs`. Append the first block below to that copied test. Append the second block to the temporary private `src/command/tests.rs` (for its private fixture constructor). All mutations remain in scratch.

```sh
cargo test --offline -p oathshaper-core --test independent_review review_reproduces -- --nocapture
cargo test --offline -p oathshaper-core --lib review_reproduces -- --nocapture
cargo test --offline -p oathshaper-core --test command
cargo test --offline -p oathshaper-core --lib command::tests::cmd
```

<details>
<summary>Public-boundary defect reproductions</summary>

```rust
#[test]
fn review_reproduces_duplicate_start_replaces_checkpoint() {
 let mut g=CommandGame::new(1).unwrap();
 let intent=input(&g,json!({"kind":"encounter.start","encounter_id":"garden_patrol"}));
 assert_eq!(g.submit(intent.clone()).unwrap()["receipt"]["status"],"accepted");
 let before:Value=serde_json::from_str(&g.save_json().unwrap()).unwrap();
 let original:Value=serde_json::from_str(before["checkpoint"].as_str().unwrap()).unwrap();
 assert_eq!(original["state"]["phase"],"camp");
 assert_eq!(g.submit(intent).unwrap()["receipt"]["status"],"accepted");
 let after:Value=serde_json::from_str(&g.save_json().unwrap()).unwrap();
 let replaced:Value=serde_json::from_str(after["checkpoint"].as_str().unwrap()).unwrap();
 assert_eq!(replaced["state"]["phase"],"encounter");
 assert_ne!(before["checkpoint"],after["checkpoint"]);
 assert_eq!(before["session"],after["session"]);
}
#[test]
fn review_reproduces_failed_restore_ack_unpauses_kernel() {
 let mut g=CommandGame::new(2).unwrap();
 let old=input(&g,json!({"kind":"party.select","actor_id":"mara"}));
 g.submit(old.clone()).unwrap();let saved=g.save_json().unwrap();g.restore_json(&saved).unwrap();
 let token=g.view()["clock"]["pause_reasons"].as_array().unwrap().iter().find(|p|p["owner"]=="restore").unwrap()["token"].clone();
 let mut bad=input(&g,json!({"kind":"pause.acknowledge","token":token}));bad["command_id"]=old["command_id"].clone();
 assert!(g.submit(bad).is_err());assert_eq!(g.view()["session"]["phase"],"restore_prompt");
 let result=submit(&mut g,json!({"kind":"party.select","actor_id":"clerk"}));
 assert_eq!(result["receipt"]["status"],"accepted");assert_eq!(g.view()["party"]["recipient_id"],"clerk");
}

#[test]
fn review_reproduces_restore_missing_consumable_claim_and_instance() {
 let mut g=CommandGame::new(3).unwrap();start(&mut g);
 accepted(&mut g,json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("player")}));
 let mut save:Value=serde_json::from_str(&g.save_json().unwrap()).unwrap();
 let mut session:Value=serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
 session["rpg"]["claims"]=json!({});session["rpg"]["items"].as_object_mut().unwrap().remove("dressing-stack-1");
 save["session"]=json!(session.to_string());
 assert!(g.restore_json(&save.to_string()).is_ok());
 assert_eq!(actor(&g,"clerk")["queue"].as_array().unwrap().len(),1);
}
#[test]
fn review_reproduces_minimum_position_save_panics_instead_of_rejecting() {
 let mut g=CommandGame::new(4).unwrap();
 let mut save:Value=serde_json::from_str(&g.save_json().unwrap()).unwrap();
 let mut session:Value=serde_json::from_str(save["session"].as_str().unwrap()).unwrap();
 session["state"]["actors"]["player"]["position"]=json!([i64::MIN,0]);
 save["session"]=json!(session.to_string());
 assert!(std::panic::catch_unwind(std::panic::AssertUnwindSafe(||g.restore_json(&save.to_string()))).is_err());
}
```

</details>

<details>
<summary>Occluded approach fixture</summary>

```rust
#[test]
fn review_reproduces_in_range_occluded_order_never_follows_valid_path() {
 let (mut state,rpg)=content::initial().unwrap(); state.phase="encounter".into();
 for a in state.actors.values_mut(){a.hold=true;}
 state.actors.get_mut("clerk").unwrap().position=[2000,5000];
 state.actors.get_mut("sentinel").unwrap().position=[9500,5000];
 state.actors.get_mut("player").unwrap().position=[9000,2000];
 let mut g=fixture(state,rpg);
 order(&mut g,"clerk","basic","item:crossbow-clerk:basic",Target::actor("sentinel"));
 let frame=space::fixture_frame(&g.space_requests(),1).unwrap();
 let path=frame.results.iter().find(|r|r.request_id.starts_with("path:clerk:")).unwrap();
 assert_eq!(path.clear,Some(true));assert!(path.path_mm.len()>2);
 assert_eq!(frame.results.iter().find(|r|r.request_id=="los:clerk:sentinel").unwrap().clear,Some(false));
 tick(&mut g,10);
 assert_eq!(g.session.state().actors["clerk"].position,[2000,5000]);
 assert_eq!(g.session.state().actors["clerk"].active.as_ref().unwrap().phase,"approach");
}
```

</details>

## Repair recheck reproduction source

Export the same four paths as above from `a5298c12575684856061e88b5b5d1297d617d7ed` to a new temporary workspace and keep only its core member. In a scratch `tests/independent_recheck.rs`, copy the helper functions before the first test in that commit's `tests/command.rs`, plus its `corrupt_session` helper; append this block. Run `cargo test --offline -p oathshaper-core --test independent_recheck audit_`. The last function intentionally reproduces CR-08 and must be inverted to require paid activation after repair. Existing core repair fixtures are reproducible with `cargo test --offline -p oathshaper-core --test command` and `cargo test --offline -p oathshaper-core --lib command::tests::`. For the reviewer's strengthened private geometry check, the ten-tick displacement bound is 3001 mm including rounding and any remaining approach must retain `deadline == Some(60)`; the committed fixture already checks motion and an attack by tick 55.

<details>
<summary>Independent public repair checks and the new self-target counterexample</summary>

```rust
#[test]
fn audit_cached_start_preserves_complete_save_after_intervening_order() {
 let mut g=CommandGame::new(301).unwrap();
 let start=input(&g,json!({"kind":"encounter.start","encounter_id":"garden_patrol"}));
 let receipt=g.submit(start.clone()).unwrap()["receipt"].clone();
 enqueue(&mut g,"mara","mend","learned:mara:mend:1",target("player"));
 let before=g.save_json().unwrap();
 assert_eq!(g.submit(start).unwrap()["receipt"],receipt);
 assert_eq!(g.save_json().unwrap(),before);
 let outer:Value=serde_json::from_str(&before).unwrap();
 let cp:Value=serde_json::from_str(outer["checkpoint"].as_str().unwrap()).unwrap();
 assert_eq!(cp["state"]["phase"],"camp");
}
#[test]
fn audit_restore_ack_conflict_stale_revision_and_cached_retry() {
 let mut g=CommandGame::new(302).unwrap();
 let prior=input(&g,json!({"kind":"party.select","actor_id":"mara"}));g.submit(prior.clone()).unwrap();
 g.restore_json(&g.save_json().unwrap()).unwrap();
 let token=g.view()["clock"]["pause_reasons"].as_array().unwrap().iter().find(|p|p["owner"]=="restore").unwrap()["token"].clone();
 let mut conflict=input(&g,json!({"kind":"pause.acknowledge","token":token}));conflict["command_id"]=prior["command_id"].clone();
 let before=g.save_json().unwrap();assert!(g.submit(conflict).is_err());assert_eq!(g.save_json().unwrap(),before);
 let mut stale=input(&g,json!({"kind":"pause.acknowledge","token":token}));stale["expected_revision"]=json!("0");
 assert_eq!(g.submit(stale).unwrap()["receipt"]["status"],"rejected");
 assert_eq!(g.view()["session"]["phase"],"restore_prompt");
 assert_eq!(submit(&mut g,json!({"kind":"party.select","actor_id":"clerk"}))["receipt"]["status"],"rejected");
 let ack=input(&g,json!({"kind":"pause.acknowledge","token":token}));let receipt=g.submit(ack.clone()).unwrap()["receipt"].clone();
 assert_eq!(receipt["status"],"accepted");accepted(&mut g,json!({"kind":"party.select","actor_id":"clerk"}));
 let before=g.save_json().unwrap();assert_eq!(g.submit(ack).unwrap()["receipt"],receipt);assert_eq!(g.save_json().unwrap(),before);
 assert_eq!(g.view()["clock"]["paused"],false);
}
#[test]
fn audit_consumable_and_each_shared_read_claim_are_required() {
 let mut g=CommandGame::new(303).unwrap();start(&mut g);
 accepted(&mut g,json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("clerk")}));
 let before=g.save_json().unwrap();
 for mode in 0..3 {let candidate=corrupt_session(&before,|s| {if mode<2 {s["rpg"]["claims"]=json!({});}if mode==1{s["rpg"]["items"].as_object_mut().unwrap().remove("dressing-stack-1");}if mode==2{s["state"]["actors"]["clerk"]["queue"][0]["paid_item"]=json!(true);}});assert!(g.restore_json(&candidate).is_err());assert_eq!(g.save_json().unwrap(),before);}
 let mut g=CommandGame::new(304).unwrap();start(&mut g);enqueue(&mut g,"player","lunge","item:sabre-4:lunge",target("hound"));
 let before=g.save_json().unwrap();let outer:Value=serde_json::from_str(&before).unwrap();let s:Value=serde_json::from_str(outer["session"].as_str().unwrap()).unwrap();
 let ids:Vec<String>=s["rpg"]["claims"].as_object().unwrap().keys().cloned().collect();assert!(ids.len()>=2);
 for id in ids {let candidate=corrupt_session(&before,|s|{s["rpg"]["claims"].as_object_mut().unwrap().remove(&id);});assert!(g.restore_json(&candidate).is_err(),"claim {id}");assert_eq!(g.save_json().unwrap(),before);}
}
#[test]
fn audit_paid_final_consumable_survives_restore_without_item() {
 let mut g=CommandGame::new(305).unwrap();let one=corrupt_session(&g.save_json().unwrap(),|s|s["rpg"]["items"]["dressing-stack-1"]["quantity"]=json!(1));g.restore_json(&one).unwrap();resume(&mut g);
 start(&mut g);accepted(&mut g,json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("player")}));resume(&mut g);tick_to(&mut g,8);
 let saved=g.save_json().unwrap();let outer:Value=serde_json::from_str(&saved).unwrap();let s:Value=serde_json::from_str(outer["session"].as_str().unwrap()).unwrap();
 assert!(s["rpg"]["items"].get("dressing-stack-1").is_none());assert_eq!(s["state"]["actors"]["clerk"]["active"]["paid_item"],true);
 let active=actor(&g,"clerk")["active_action"].clone();g.restore_json(&saved).unwrap();assert_eq!(actor(&g,"clerk")["active_action"],active);resume(&mut g);tick_to(&mut g,12);
}
#[test]
fn audit_extreme_positions_reject_without_panic_or_generation_change() {
 let mut g=CommandGame::new(306).unwrap();let before=g.save_json().unwrap();let generation=g.view()["session"]["generation"].clone();
 for coordinate in [i64::MIN,i64::MAX,-100001,100001] {let candidate=corrupt_session(&before,|s|s["state"]["actors"]["player"]["position"]=json!([coordinate,0]));let result=std::panic::catch_unwind(std::panic::AssertUnwindSafe(||g.restore_json(&candidate)));assert!(result.expect("restore must not panic").is_err());assert_eq!(g.save_json().unwrap(),before);assert_eq!(g.view()["session"]["generation"],generation);}
}

#[test]
fn audit_self_dressing_reproduces_missing_self_los() {
 let mut g=CommandGame::new(307).unwrap();start(&mut g);
 accepted(&mut g,json!({"kind":"inventory.use","actor_id":"clerk","item_id":"dressing-stack-1","target":target("clerk")}));resume(&mut g);tick_to(&mut g,5);
 let saved:Value=serde_json::from_str(&g.save_json().unwrap()).unwrap();let session:Value=serde_json::from_str(saved["session"].as_str().unwrap()).unwrap();let active=&session["state"]["actors"]["clerk"]["active"];
 assert_eq!(active["phase"],"approach");assert_eq!(active["paid_item"],false);assert_eq!(active["deadline"],60);assert_eq!(active["approach_travel_mm"],0);
}

```

</details>

### Final CR-08 probe adjustment

For `a5298c1` plus `fd79ce9`, retain the five positive public probes above. Rename the last counterexample to `audit_self_dressing_activates_without_self_los`, require `phase == "windup"`, `paid_item == true`, `activation <= 5`, and keep the zero-travel assertion; remove its old `deadline == 60` assertion. Duplicate `audit_paid_final_consumable_survives_restore_without_item` under a new name with the dressing target changed from `player` to `clerk`. These seven public tests pass. Run the two committed numeric self-heal fixtures with:

```sh
cargo test --offline -p oathshaper-core --lib command::tests::review_self -- --nocapture
```

The review changed only this report in the canonical workspace. Test/probe edits stayed in `/tmp/oathshaper-command-rereview-a5298c1`; the final source overlay there is the committed CR-08 `combat.rs` and private tests from `fd79ce9`. No independent native execution or physical-device claim was added.
