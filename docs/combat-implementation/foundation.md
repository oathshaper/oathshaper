# Rust foundation checkpoint

Date: 2026-10-22. Current status: **tested implementation candidate; independent review pending**. Worktree: `.agent-worktrees/combat-implementation/foundation`; branch: `impl/combat-foundation`. No real combat profile is registered by this patch. Command gameplay, GameSession, the bridge and Godot remain separate implementation work.

The earlier `ee7b134` checkpoint compiled but was paused before tests. The canonical [LCD implementation audit](../combat-design/lcd-implementation-audit.md) rejected it with five findings. This revision repairs those findings and supplies executable regression cases; the audit's historical findings remain valid for `ee7b134`.

## Public API and ownership

`oathshaper_core::runtime` exports:

- `Profile` with typed associated `State`, `Command`, `Advance`, `View`, `Preview`. Required methods: `manifest`, `preview`, `prepare_command`, `prepare_advance`, `project`, `validate`. Optional methods: `participants`, `validate_restore`, `decide_ai`, conservative `quiescent`.
- `Session<P>::new(profile, state, rpg, seed, session_id, &mut host)`; `submit(Envelope<Command>)`, `advance(Envelope<Advance>)`, `preview`, `view`, `ai_commands`, `save_json`, `restore_json`, `close_epoch`, `ensure_quiescent`, `prepare_transition`, and trusted host lease/restore methods.
- `Envelope<T>` fields remain `generation`, `epoch`, `id`, `lease`, `expected_revision`, `actor: Option<String>`, `payload`. An admitted operation returns `Receipt` with accepted/rejected status. Invalid authority/generation/identity admission returns an error without adding a receipt.
- `Transaction<State>` holds a private candidate: cloned state, RPG services, entropy, event buffer, occurrence identities and observation cursors. Profiles prepare it; the session validates it before publishing state and receipt together. Rule failure discards all candidate changes but retains the admitted rejection in the receipt ledger. Receipt sequence and gameplay revision are distinct.
- `HostAuthority`, `Principal`, `Role`, `LeaseScope`, readonly `ParticipantAuthority`, `ReadContext`, `RestoreContext`, `Manifest`, `ProviderSpec`, and versioned SplitMix64 entropy. No Godot or wall-clock dependency.

`oathshaper_core::rpg` offers optional item/container, equipment binding, grant source, investment dependency, integral resource and claim services. `RpgState::apply` and `apply_with_policy` publish an entire validated batch or leave the original untouched. `InventoryPolicy` supplies capacity/body checks; `RecipePolicy` prepares a concrete batch. Recipes, prices, levels, ability prerequisites, class/armor restrictions, refunds, damage, timers, cancellation policy and player knowledge belong to profiles. No Health, turn clock, party size or inventory capacity algebra is mandatory.

### Host attachment example

This generic attachment is also a compiled documentation example on `Session`. The host supplies a real `Profile`; test adapters are never registered as content.

```rust
use oathshaper_core::{rpg::RpgState, runtime::*};
use std::collections::BTreeSet;

fn attach<P: Profile>(profile: P, state: P::State, rpg: RpgState,
                      command: P::Command) -> RuleResult<String> {
    let mut host = HostAuthority::default();
    let mut session = Session::new(profile, state, rpg, 42, "practice-01", &mut host)?;
    let lease = session.issue_lease(&mut host,
        Principal { id: "local-player".into(), role: Role::Player }, "player",
        LeaseScope { actors: BTreeSet::from(["student".into()]),
                     system_commands: false, advance: false })?;
    let receipt = session.submit(Envelope {
        generation: session.generation(), epoch: session.epoch(),
        id: "intent-1".into(), lease, expected_revision: session.revision(),
        actor: Some("student".into()), payload: command,
    })?;
    // Inspect receipt.status; a rule rejection is also a retained receipt.
    assert!(matches!(receipt.status, Status::Accepted | Status::Rejected));
    session.save_json()
}
```

The host retains `HostAuthority` and lease issuance outside the player command surface. `Role::Ai` uses `ai_commands` for ordinary typed proposals, then submits each through the same envelope and authority checks. The kernel gives AI no mutation shortcut. Profiles must project knowledge appropriate to `ReadContext::observer`; events and rejection reasons are independently audience-filtered on every return, including retry.

### Complete group authority

`Profile::participants(actor, command)` declares every actor whose controlled action/resource is committed by the intent. The kernel always adds the outer actor. Admission verifies the entire set against the live host-issued scope before rules execute or a cached receipt is returned. Enemy effect targets are not controlled participants merely because they are named targets.

`tx.authority().require(members.iter().map(String::as_str))` provides an additional readonly guard inside a group operator. The profile is trusted Rust code and must declare all controlled participants; the kernel cannot infer intent from arbitrary payloads. Command cooperative operators must implement this method. Advance requires a distinct host-authorized `advance` lease and no outer actor.

### Providers and state namespaces

`Manifest::minimal` registers only the immutable kernel and profile state owner. `Manifest::new` additionally registers six optional built-in RPG providers. Each `ProviderSpec` names versioned capabilities, exclusively owned namespaces and requirements. Registration rejects duplicate capability owners, overlapping namespaces and unsatisfied requirements. The exact manifest is part of save compatibility.

Profiles can remove unused services, add timer/morale providers, or replace a service by removing its built-in declaration and registering a replacement. Custom/replacement data and operators live in typed profile state/code; built-in data for an unregistered provider must remain empty. Declarations describe trusted, statically composed Rust code; they do not load plugins or sandbox malicious providers. The test `CustomProvider` executes replacement resource costs and a custom timing counter with no built-in resource rows.

### Source and claim contract

- Resource/item quantity claims must be positive, existent and affordable immediately at reservation. Consumption uses checked arithmetic. An invalid intermediate state cannot be repaired by removing its evidence later in the batch.
- `ItemRead` and `BindingRead` allow simultaneous readers of one instance/binding. They conflict with quantity consumption and exclusive changes without duplicating items. Exclusive binding conflicts are checked in either admission order. Rebinding inspects removed old slots and affected items.
- `Source::Item { equipped: true, .. }` requires the recipient's binding. `Source::EquippedBy { item, actor }` explicitly represents a remote/aura emitter. Investment grants require the investment actor to equal the recipient. Access to unequipped items, shared inventory and body legality remain profile policy.
- `ServiceChanges::revoked_grants` reports every removed grant, including explicit revocation. Removing equipment's grant leaves an independent learned grant intact. A profile atomically cancels affected pending work and releases claims before forced source loss; ordinary equipment mutation is blocked while claimed. Paid costs and recovery deadlines are profile state, with no implicit revocation refund.
- Investment dependencies are checked iteratively for missing/cross-actor prerequisites and cycles. Profiles validate class-specific final respec state and supply exact refund/resource mutations.

### Saves, retries and lifecycle

Save schema is **2**. Schema 1 was an unaccepted draft; no migration is supplied. Saves omit live leases/generations. Successful restore validates the whole candidate, rotates generation, clears leases, and pauses execution until explicit host resume. Failure preserves the live session and its authority.

Stored fingerprints have typed operation, principal, actor, participants, expected revision and canonically round-trippable payload. Restore verifies these relationships, contiguous per-epoch receipt sequence/revision chains, RPG relationships, exact manifest and profile invariants. The optional `validate_restore` hook receives entropy draws, observations and occurrences through `RestoreContext` to validate profile-specific pending-operation relationships.

An identical logical ID returns its retained result after fresh authority checks; changed semantics fail. Admitted rejections remain rejected across resource changes and saves. Failed candidates consume no entropy, observation position or occurrence identity. `close_epoch` requires profile quiescence and no common claims, then clears epoch receipts/occurrences while retaining gameplay and observation cursors. Old-epoch envelopes remain invalid.

`prepare_transition` is a readonly source barrier and destination-preparation callback. Pending noncombat claims block it; failed preparation preserves the source. Atomic destination activation, authority invalidation on actual profile replacement and narrative handoff remain GameSession responsibilities. A successful callback alone does not switch profiles.

## Audit repairs and executable evidence

| Finding | Repair | Focused regression |
| --- | --- | --- |
| LCD-I1: invalid claims and arithmetic | Immediate claim/resource validation, checked arithmetic, own-share item consumption | Negative/zero/minimum/oversized claims cannot create credit; multiple claims settle only their share |
| LCD-I2: source recipient, incomplete deltas, old-slot bypass | Explicit remote source, recipient-bound grants, full removal diff, old item/slot/read checks | A-to-B equip removes A's item grant; learned grant survives; explicit revoke reports ID; two-hand rebind/readers block mutation |
| LCD-I3: opaque fingerprint restore | Typed fingerprint, canonical payload, relationship and exact epoch-ledger checks | Nine corrupt-save variants preserve bytes/generation/old lease; valid restore fences authority and retains retries |
| LCD-I4: hidden group participants | Declared participants verified against host scope; readonly transaction authority | Missing C scope spends nothing; insufficient C resource rolls back A/B; revoked lease cannot commit; enemy target needs no lease |
| LCD-I5: fixed capability gate, no shared reads | Unique provider ownership/dependencies/replacement/minimal manifests; read claims | Invalid providers reject; no-HP profile works; replacement costs/custom timer execute; read/exclusive conflicts work in both orders |

`tests/runtime_kernel.rs` has 19 tests with numeric expectations. Test-only turn/reaction and continuous adapters exercise paid interruption, source loss, learned grants, planning/execution boundaries, partial multi-resource failure, ordinary AI commands, filtered views/retries, observation rollback, duplicate effects, lifecycle barriers, crafting capacity, container cycles and dependency respec. These verify the shared contract, not Command gameplay, encounter balance or native input feel.

Verification commands (core crate only):

```sh
cargo test --locked -p oathshaper-core
cargo clippy --locked -p oathshaper-core --all-targets -- -D warnings
cargo fmt --all -- --check
git diff --check
```

## Remaining gates and limits

1. Independent foundation review by `lcd_review`; this author checkpoint is not self-approval.
2. Real Command implementation, design scenarios, NPCs, progression, items and source-loss policies against this API.
3. GameSession routing/activation, bridge serialization, Godot 3D/HUD and actual save-file persistence. Serialized receipt retention is not an fsync/WAL guarantee; host storage owns crash recovery.
4. Local trusted Rust authority is not hardened network authentication or a malicious-plugin sandbox.

## Verification receipt

Final author verification passed: 19 runtime integration tests, 23 existing narrative tests, and one compiled documentation example under `cargo test --locked -p oathshaper-core`; core `clippy --all-targets -- -D warnings`; workspace formatting check; and `git diff --check`. No dependency upgrade, broad workspace/Godot build, workflow automation operation or resident restart was used. Independent review is still pending.
