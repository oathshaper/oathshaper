# ADR: a small engine contract for different RPG systems

Date: 2026-10-22. Status: **design-reviewed foundation v1**, with findings and repairs in the [evaluation](lcd-evaluation.md). Scope: engine design, not implemented Rust APIs or human acceptance of every profile. This ADR supersedes universal mechanical assumptions in the earlier [foundation plan](../combat-foundation-plan.md), while retaining its pure-Rust rules/Godot presentation boundary. See the [research rights notice](../research/NOTICE.md).

## 1. Decision and motivation

The least common denominator is **identity, validated commands, atomic state changes, explainable views and versioned recovery**. Health, classes, inventories, turns, mana, action queues and damage formulas are optional RPG services or profile policies. A profile must be able to define a radically different RPG while retaining save integrity, party identity, authoring, input ownership and evidence.

This is smaller than a universal `Combatant` with every possible stat and a universal attack lifecycle. It is also more useful than an untyped bag of arbitrary callbacks: each extension has an owner, schema, lifecycle, validation boundary and visible capabilities.

The current [core](../../crates/oathshaper-core/src/lib.rs) implements deterministic narrative state only. The [catalog](../../godot/content/rpg_catalog.json) contains read-only preview builds, not owned item instances or executable ability definitions. No existing Rust combat API constrains this decision.

### Required kernel, optional services, authored profile

| Boundary | Owns | Must not prescribe |
| --- | --- | --- |
| Kernel | Stable identities, content references, authority/revision checks, transactions, receipts, observable events, save/restore envelope, deterministic ordering facilities, audience filtering | Health, class count, party size, real-time vs turns, inventory capacity, ability grammar, d20 math, pause behavior |
| Reusable RPG services | Inventory ownership, equipment bindings, grant provenance, progression graphs, resource accounting, conditions, party membership, targeting queries, skill checks | A universal slot list, mana requirement, one progression tree, one damage pipeline, one reservation stage |
| Profile modules | Rule math, scheduler, spatial authority, control/AI policy, content pack, resource/cost semantics, inventory policy, recovery, rewards and native UX | Mutating another module's state without the declared transaction interface |
| Godot host | Input devices, UI layout, camera, physics observations, audio/animation/VFX, asset representation | Independently deciding costs, eligibility, reward ownership or save validity |

An optional service can be omitted or replaced by a profile-specific implementation of its declared capability. Its absence is meaningful: Flow does not need a conventional backpack to have collectible styles. The UI queries capabilities and offers only supported operations.

## 2. Kernel invariants

1. **Identity survives presentation.** `EntityId` refers to an actor, item or world object independently of scene node, portrait, active profile and selected character. Content definitions use namespaced IDs and immutable versions/hashes. An actor may lack resources or equipment.
2. **One authority per mutable domain.** A manifest names the module that owns each state namespace. Competing owners or unsupported required capabilities fail profile validation. Shared IDs are references, not permission to write another namespace.
3. **A command has a result once.** Deduplicate by logical session/epoch and command ID, after validating the current live activation generation and issuer authority. Fingerprint the complete semantic envelope, including actor, command kind, targets, expected versions and payload. A repeated ID with the same fingerprint returns its stored receipt; changed semantics are rejected. Check deduplication before stale-revision rejection so a lost response can be recovered safely, but filter cached receipts for the currently authorized audience. Publish receipt-retention/epoch rules; old epochs cannot reexecute after compaction.
4. **A committed step is atomic.** Every affected service prepares against one snapshot, the coordinator verifies the read/write versions and invariants, then commits mutations, events, command/occurrence/narrative receipts, consumed observation positions and entropy advancement together where applicable. Preparation uses speculative entropy and bookkeeping. A terminal gameplay rejection discards that speculative work and commits only the admitted command's rejection receipt and ledger sequence; gameplay state/revision, entropy, occurrence records and observation cursors stay unchanged. Multi-stage actions use several explicit transactions; atomicity does not mean an entire ten-second channel is one indivisible operation. Storage/WAL implementation remains a later choice.
5. **Presentation requests effects; rules commit them.** Animation callbacks and input are observations/intents. A duplicate contact callback cannot inflict duplicate damage. Modules define unique effect-occurrence keys for repeated beams, targets and periodic ticks; the kernel deduplicates those keys within their declared lifetime.
6. **Preview is read-only.** It spends no resources or RNG and returns known costs, predicates, uncertainty and reason codes. Execution revalidates against current authoritative state. A preview is never a permission token.
7. **Views respect knowledge.** Pass an audience/observer into preview, AI queries, logs and UI views. Hidden targets, stats and uncommitted enemy orders must not leak through reasons, forecasts or telemetry shown to that audience.
8. **Recovery is versioned and fenced.** Save the manifest/content hashes, state namespaces, logical execution epoch, receipt state, entropy streams, pending commitments, decision windows and required observations. Restore validates the complete candidate before replacing a live session, then activates it with a fresh host-owned generation. That generation is authority for live producers, not a value restored from the save; old inputs, control leases and callbacks cannot enter the new timeline.
9. **Facts cross into narrative once.** Authored mappings consume committed encounter/skill outcomes with stable event IDs. Store application receipts. A scene reload or repeated reward notification cannot duplicate a quest effect, moral change or item grant.
10. **Unsupported behavior fails visibly.** Unknown required schema versions, missing mechanics, incompatible module combinations and unresolved migrations prevent execution. Inspection may display an unavailable pack, but cannot silently substitute another ruleset.

## 3. Proposed boundaries and data

These names illustrate contracts. They do not require a specific ECS, inheritance hierarchy or plugin ABI.

```text
ProfileManifest
  id/version; kernel compatibility; content hashes
  modules[{id/version, owned namespaces, capabilities, requirements}]
  rules; scheduling; spatial authority; controls; AI; UI; persistence policy

CommandEnvelope
  live activation generation; logical session/epoch; command ID; issuer authority
  actor/selection references
  expected state or domain versions; namespaced command kind; typed payload

DecisionContext
  observer knowledge; current snapshot; named clocks; observations; entropy handles

CommitPlan
  read/write set; expected versions; typed mutations; reservation changes
  emitted events; occurrence IDs; resulting decision windows
  receipt changes; speculative entropy/observation cursor changes

CommandReceipt
  accepted/rejected; committed revision; action/plan ID if applicable
  structured reasons; observable events; next legal choices

ModuleSnapshot
  namespace/version; content dependency hashes; typed state; restore validator
```

Extension payloads are opaque to unrelated modules but schema-validated by their owner. Use a registered Rust implementation for the initial build; no downloaded executable plugins or arbitrary generated scripts are required. Declarative content selects registered rules/operators. A later scripting boundary requires its own execution and resource limits.

Proposed operations: `describe_capabilities`, `validate_content`, `preview`, `prepare_command`, `prepare_advance`, `validate_restore`, `observe`. The host coordinates snapshots and commits. `prepare_advance` accepts a profile-defined time/phase event; it does not imply all profiles run on seconds. Mutation is possible only through a committed plan. Pure Rust rules remain independent of Godot nodes.

Avoid requiring a fixed `start → impact → recovery` action state machine. A simple consumed item may commit immediately; a channeled power may have many impacts; a simultaneous plan may involve several actors and deferred reactions. Reusable action-state helpers can implement those patterns without making them kernel law.

**Admission and terminal results:** stale-generation or unauthorized inputs fail before trusted-ledger admission. Every admitted command receives one durable terminal acceptance or rejection. After a resource rejection, an identical retry returns that original rejection even if resources later recover; a renewed attempt uses a new command ID and current expected versions. Fingerprint mismatches never overwrite a stored result. Internal preparation retries may remain unpublished until a terminal result is chosen. Receipt-ledger sequence is separate from gameplay revision, so recording a rejection does not invalidate unrelated gameplay previews.

## 4. Time, space and control are profile contracts

### Time and reservations

Named time domains include simulation ticks, actor turns, rounds, readiness cycles, planning intervals and narrative time. Values from different domains are not implicitly convertible. UI/audio wall time is separate. Profiles define which clocks advance during menus, targeting, pause, hitstop, dialogue, reaction windows and execution cinematics.

A pause/time-scale request has an owner and affected domains. Releasing a menu's token cannot resume a still-open reaction decision. The profile defines how overlapping scale requests compose; no universal real-time slowdown rule is imposed.

Reservations use typed claim handles: fungible quantities, specific item instances, actor readiness, occupied hands or spatial/time slots. The service enforces capacity/exclusivity; the profile chooses when to reserve, consume, release or refund. The earlier reports conflict on whether queued actions reserve immediately or at activation. **Neither is a kernel default.** Command must state its queue policy; Confluence must atomically reserve several ready actors; Orders may reserve a whole planning budget. Persist commitments and their invalidation rules.

### Space and replay

Tactics may own a grid/path-cost model in Rust. Flow/Vanguard may consume canonical Godot contact, aim, pose and visibility observations. A rules replay is deterministic for the same initial state, content, ordered commands, entropy and canonical observations; it is not a promise of input-only cross-platform Godot physics replay.

The spatial capability identifies units, coordinate system, precision, tick/revision, query visibility and authority. Cover, elevation, occupancy, interaction reach and hit volumes are explicit query contracts. A shot cannot mix a new camera ray with an old target pose without an authored reconciliation policy. Client prediction or networking is a later design, not hidden in these interfaces.

### Party/control

Roster membership, deployed presence, UI selection, direct possession, command authority, camera following and AI ownership are independent. Selecting a companion for inspection does not advance initiative or possess them. A profile may allow one controlled actor, full party switching, orders-only followers, pets, reserve actors or no party.

Control leases identify who may issue which commands and when. The host issues and validates leases against the active generation; callers cannot gain authority by supplying an actor ID or an issuer field. Player orders and AI share the same legality/commit path. Their precedence and interruption policy belong to the profile. The civic clerk is a training guest in the demo, not implicitly recruited in narrative state.

## 5. Optional RPG services and their extension seams

| Service | Common correctness contract | Authored policy / replacement points |
| --- | --- | --- |
| Inventory | Unique instance/container ownership; atomic split/merge/transfer/consume; no container cycles; no losing protected items | Shared stash vs actor bags; slots, weight, Bulk, spatial packing or unrestricted collections; stack equivalence; access times; loot/sale/crafting rules |
| Equipment | Bind carried instances; enforce authored occupancy; compare against selected actor; atomic swaps | Body-specific slots, hands, weapon sets, armor eligibility, runes/sockets, transformations, cosmetic override, combat swap cost |
| Grants | Track source ID, recipient, ability/modifier and lifetime; revoke only dependent grants | Learned vs equipped vs temporary vs partner link; mastery persists separately; policy for in-flight actions after source loss |
| Progression | Versioned acquisition records, prerequisites, investments and authorized respec transactions | Classes/levels, feats/dedications, style ranks, weapon mastery, personal technique graphs, use-based skills, classless builds |
| Resource accounting | Named typed units, bounds, claims, deductions and receipts | Health/mana/chi/focus; heat increasing toward a cap; shield layers; ammo; charges; spell slots; ATB segments; no-resource actions |
| Abilities | Stable definition and source; legality and observable reasons; typed targeting/cost/execution contracts | Spells, gadgets, martial styles, commands, reactions, links, transformations, summons, interactions and signatures |
| Effects/defenses | Source attribution, bounded iteration, versioned rule operators, explainable outcomes | Damage order, saves, degrees of success, immunity, absorb/resist, guard/poise, stagger, stacking, dispel, duration and death rules |
| World skills | A check/interaction uses the same authoritative actor capabilities and commits consequences once | Dialogue, locks, traps, perception, stealth, crafting, medicine, traversal, tech terminals; passive/active/opposed/deterministic checks |
| Encounter | Stable participants and objectives; single outcome/reward receipt; authored join/leave transitions | Reinforcements, surrender, nonlethal defeat, revival, flight, resets, resting, XP and loot allocation |

Origin tags such as magic, tech, martial or divine do not dictate costs or delivery. A tech ability may expend ammunition, reserve charge or run on cooldown; a spell may spend a slot and require free hands. Types and rules prevent invalid combinations; tags support authoring/search and explicit interactions.

Inventory layout and capacity are separate. A grid can be a view of a list, or physical packing can be an actual rule; the UI must say which. PF2 Bulk is its own capacity algebra, not kilograms with a new label. Each profile must specify equipped and nested items' contribution, overflow behavior, quest-item protection, quick bindings, purchases, crafting and respec recovery.

An equipment change prepares the new binding, grant delta, derived stats, capacity and affected commitments together. Show the result before commit. If source removal cancels an action, cancellation/refunds are in that transaction; a delayed callback cannot resurrect the removed grant. If an action snapshots its source at start, it retains the declared snapshot and cannot secretly reevaluate from the new weapon.

A progression transaction similarly validates points/currency, dependencies, derived grants, equipment legality and refund rules. A respec cannot leave an invalid equipped item or prepared spell silently active. Define whether it is removed, moved to storage or blocks the respec; preserve the original state on rejection.

## 6. UX must be native to the chosen profile

The engine shares semantic input verbs and accessibility services, not one mandatory HUD. Profiles supply a view contract for status, available actions, targets, queues/timelines, inventory, equipment, progression and inspection. Controls bind by input context and device; show circled controller glyphs and keyboard keys appropriately.

Availability includes discovery, acquisition/source, preparation, equipment, target legality, affordability, readiness and contextual blocks. The owning rules implementation supplies localized reason codes and meaningful quantities. Tooltip availability and execution use the same predicates, but execution always revalidates. Hidden information must be redacted rather than exposed through a precise failure explanation.

The common Ledger entry point and avatar/morality location remain familiar. Within it, a Flow style library, Vanguard mod comparison, Tactics preparation sheet, Momentum socket graph or Cadence command/relic screen can differ substantially. Actor-specific narrative morality and relationship are separate; unknown companion outlook is shown as unknown.

UI selection persistence, focus restoration, modal priority, text scaling, subtitles, color-independent indicators and remapping are common services. Each profile still specifies its own direct-action verbs, pause behavior, radial/quickbar organization and controller interaction costs. A back button first resolves its current modal context; it does not globally sheathe through a target selector.

## 7. Save, switching and content compatibility

Theme changes affect presentation only. A full profile change selects rules, content, controls, equipment/progression semantics and UX together. Disable full profile changes during an active encounter in the first implementation. Outside combat, switching still requires an atomic lifecycle barrier: stop admitting new operations; inspect every pending combat/world-skill/crafting/equipment/progression commitment; settle each by completion, declared cancellation/refund, explicitly safe suspension or supported migration. Suspension must prevent conflicting destination access to the same campaign objects. The first implementation permits only settled operations and rejects a switch with an actionable reason while any remain.

Prepare the destination against the complete settled snapshot, validate ownership, required story access and compatibility, then commit settlement plus migration plus activation together. Rejection preserves the original live session without partial cancellations or transfers. Every successful switch gets a fresh activation generation. A later implementation may add safe suspension/migration after defining the resource and clock semantics.

Keep common story identity and relationships once. Keep per-profile build/progression state in separate namespaces when concepts are not mechanically equivalent. Never infer that a learned Flow style is a physical Vanguard weapon or convert PF2 spell slots into mana without an authored migration.

For the demo, profile-specific trial kits and encounter rewards stay in their own trial state; changing profiles grants no duplicate campaign currency, healing or quest records. Transferable campaign objects need explicit cross-profile identity/mapping rules and a migration receipt. An unmapped item remains safely stored and inspectable with its original identity, or the switch is rejected if losing active access would block the story. No silent deletion or duplication.

Persist pending operations at a documented stable checkpoint. An action profile may disallow mid-impact saves while allowing a paused menu checkpoint; Orders may save a sealed plan plus exact execution state. A corrupt or unsupported save leaves the live session untouched. Loading old narrative revisions still needs the existing explicit migration contract; this design does not relax it.

On load/rewind/activation, discard old presentation callbacks and input queues, invalidate old leases and rebind restored logical actions to new host observation producers. An old command C arriving after a rewind is rejected by its stale activation generation even if C is absent from the restored receipt table. A newly chosen action receives a new command identity in the active generation. Offline deterministic replay uses a separate recorded-stream driver; it does not authorize live callbacks from the abandoned session.

## 8. Stress cases: prove freedom without losing integrity

| Case | What the kernel contributes | What the profile must own |
| --- | --- | --- |
| Command queue exceeds remaining power | Identity/receipts/claims/atomic commit | Whether future entries reserve or remain speculative; skip/hold/autopause and player explanation |
| Flow changes style while blocking | Input authority and committed state revision | Guard/cancel windows, style resource changes, chi heal/focus timing, follower mode |
| Vanguard tech/biotic combo hits shield | Canonical aim/contact and source/event identity | Shield interaction, heat/cooldowns, power validity, squad-only control and combo rules |
| Oathbound sustained power plus armor swap | Atomic binding/resource/grant changes | Fatigue, reserved mana, threat, priority tactics, friendly fire and interruption |
| Tactics reaction during a two-action activity | Decision window and owned pause token | Initiative, action budget, trigger ordering, degrees of success and movement interruption |
| Momentum menu order while slow time continues | Revision checks and atomic command cost | Gauge earned/spent, selected actor vs order recipient, pressure/stagger and interruption refunds |
| Confluence three-person technique | Atomic claims across three actors | Readiness, personal prerequisites, resource costs, disabled partner and target geometry |
| Cadence relic replaces a signature command | Provenance and atomic equipment mutation | Command grammar, learned magic persistence, Active/Wait scope and in-flight signature policy |
| Orders medic target moves during resolution | Observer filtering, sealed plan identity, replay ordering | Simultaneous timeline, information policy, movement conflict, range failure and cost settlement |
| Tactics/Orders hybrid | Same identities, transactions and persistence | Planning initiative versus simultaneous resolution; reservations, reactions, conflicts and phase UX |

No row requires adding a new kernel field named after a specific game mechanic. A profile pressure that genuinely violates this claim must be documented as an LCD change proposal, not hidden in a profile-specific core patch.

## 9. Alternatives, risks and implementation sequence

Rejected: a giant universal actor/stat/action structure (encodes one game's assumptions), nine unrelated mini-engines (duplicates ownership/recovery), and a universal UI skin over renamed resources (loses source-specific interaction). A fully dynamic plugin system is deferred until there is evidence that registered Rust modules are insufficient.

Main risks are overengineering optional services, an all-powerful callback escape hatch, accidental shared-resource semantics, opaque errors, and cross-profile duplication. Implement one end-to-end vertical slice before expanding the content library: owned item → legal equip → sourced ability → native action selection → profile execution → committed cost/effect → save/restore. Tactics remains the first runtime candidate because its turn-based rules are easier to inspect and reference prototype may supply reusable ideas; that is not a requirement for every other scheduler to emulate it.

The first foundation implementation should support only the kernel contracts exercised by two contrasting test adapters: a turn activity with a reaction, and a continuous action with a timed resource/observation. Add linked multi-actor reservations and equipment grant revocation as adversarial fixtures. No full profile implementation is authorized by this design pass.

Rollback is local Git history: the user-approved source checkpoint is `e0c5006`; profile branches fork only after this ADR's review. Do not rewrite a rejected design out of history. Revisit this ADR if two independently developed profiles need conflicting authority semantics, if serialization cannot capture a valid decision window, or if UI capabilities cannot represent a source-specific interaction without engine changes.

## 10. Design acceptance and evidence boundary

Independent review must challenge the ten stress cases, command deduplication, transaction atomicity, resource/grant invalidation, hidden-state filtering and save migration. It must also check that ordinary skills, loot, equipment and progression have not been lost behind scheduling abstractions.

Acceptance for this milestone is a reviewed, committed contract and a documented resolution of blocking design findings. Runtime unit/physics/controller/balance tests are **not applicable yet** and must not be claimed as passed. Subsequent profile evaluation requires concrete scenario traces and counterexamples; document structure checks only establish packet completeness.
