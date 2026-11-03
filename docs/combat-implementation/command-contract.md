# Command implementation and bridge contract

Date: 2026-10-22. Status: **proposed integration contract; no runtime implementation or acceptance**. Command-first work is authorized, but dependent Rust implementation waits for root's explicit independent foundation gate. Root owns GDExtension, Godot scenes, HUD/input and save-file integration; `flow_design` will own the Command Rust profile/content/tests in its assigned worktree. This document does not resume other profiles.

## Baseline and ownership

The authority is the independently reviewed Command packet in branch `design/combat-command`, files `docs/combat-design/profiles/command/{design.md,scenarios.json}` (nineteen CMD cases), plus the [LCD](../combat-design/lcd.md). Use that packet's original formulas and level-six fixtures, never the earlier presentation catalog's Health/Focus numbers. The [foundation audit](../combat-design/lcd-implementation-audit.md) remains a prerequisite, not an implementation to duplicate.

Observed current boundaries: canonical `oathshaper-core` contains narrative rules; `oathshaper-godot/src/lib.rs` exposes `NarrativeBridge`; `demo.gd` and `save_store.gd` currently save narrative/location/profile selection, not combat. Draft foundation `ee7b134` in the foundation worktree offers typed `runtime::Profile`, `Session<P>`, `HostAuthority`, `Envelope`, transactions, filtered views/receipts and optional `rpg::RpgState`. Its repairs are in progress. Names below are the proposed Command-facing contract; foundation method signatures are not frozen until the gate.

Command implements **one** typed `Profile`: `State = CommandState`, `Command = CommandIntent`, `Advance = CommandStep`, `View = CommandView`, `Preview = CommandPreview`. Implement its existing `preview`, `prepare_command`, `prepare_advance`, `project`, `validate`, `decide_ai` and `quiescent` seams. `CommandGame` owns the accepted `Session<CommandProfile>`, host authority and privately issued player/AI/system leases. It is an adapter, not another generic engine, RNG, receipt ledger or transaction system. Shared source-read claims versus exclusive gear mutation must use the gated foundation/provider contract; do not emulate several readers by reserving several copies of one sword.

Planned owned files after gate: `crates/oathshaper-core/src/command/{mod.rs,content.rs,view.rs}` and `crates/oathshaper-core/tests/command.rs`, plus one module export agreed with root. Root owns the GDExtension class and Godot files. Any required foundation repair returns to its owner rather than being hidden in Command.

## Stable facade and transport

```rust
impl CommandGame {
    pub fn new(seed: u64) -> Result<Self, CommandError>;
    pub fn view(&self) -> serde_json::Value;
    pub fn submit(&mut self, input: serde_json::Value)
        -> Result<serde_json::Value, CommandError>;
    pub fn advance(&mut self, ticks: u32)
        -> Result<serde_json::Value, CommandError>;
    pub fn save_json(&self) -> Result<String, CommandError>;
    pub fn restore_json(&mut self, source: &str)
        -> Result<serde_json::Value, CommandError>;

    // Required for equipment/progression/target comparison without mutation.
    pub fn preview(&self, request: serde_json::Value)
        -> Result<serde_json::Value, CommandError>;
    // Trusted host adapter only; never a UI submit action.
    pub fn space_requests(&self) -> Vec<SpaceRequest>;
    pub fn observe_space(&mut self, frame: SpaceFrame)
        -> Result<(), CommandError>;
}
```

`new` constructs an isolated garden trial at its camp with the Command content manifest. Production uses the seeded foundation entropy stream. Exact CMD-03 rolls use a test-only recorded fixture driver, not a public `set_roll`, `damage` or `force_victory` action. Scenario constructors and privileged views remain test-only. Restore is an instance method so invalid candidates leave the current live session untouched.

Root's `CommandBridge` is a `RefCounted` sibling of `NarrativeBridge`, preserving that existing interface. Proposed methods are `create(seed_decimal)`, `view()`, `submit(json)`, `preview(json)`, `advance(ticks)`, `save_json()`, `restore_json(json)` and a host-only observation adapter. JSON strings cross GDExtension as the narrative bridge already does. The bridge constructs authority; neither player JSON nor save contents can issue leases or claim system authority. `view` always projects the player audience. No UI-supplied audience/debug toggle exists.

Outer responses follow `{"ok":true,"data":...}` / `{"ok":false,"error":{"code":"...","message":"..."}}`. Transport/schema/stale-authority failures use the error form; admitted gameplay rejection is `ok:true` with a durable rejected receipt. A receipt is `{command_id,status,revision,ledger_sequence,action_id:null|string,pause_token:null|string,reasons:[{code,message}],events:[...]}`. Returning a cached receipt never repeats its effects; the accompanying view is the **current** projection, not the old receipt's state. Exposed event IDs deduplicate presentation and narrative consumers.

All versioned JSON types reject unknown fields. IDs, generation, epoch, revision and ledger sequence are opaque strings; this avoids integer precision loss through JSON consumers. Tick counters and bounded resource quantities are JSON integers. Public actor/target `position` is `[x,z]` in finite meters relative to the Command arena origin. Internal spatial state and canonical recorded observations use integer millimeters, converted once at the trusted adapter; rendering does not round-trip positions through UI commands. Wire schemas are `command.action/v1`, `command.view/v1`, `command.preview/v1` and `command.space/v1`. Saves retain the foundation's manifest/schema envelope rather than introducing a competing receipt format.

```json
{
  "schema": "command.action/v1",
  "command_id": "input-0042",
  "generation": "7",
  "expected_revision": "91",
  "action": {
    "kind": "queue.enqueue",
    "actor_id": "mara",
    "ability_id": "binding_current",
    "source_id": "learned:mara:binding_current:1",
    "target": {"kind":"point", "actor_id":null, "position":[2.0,0.0]}
  }
}
```

The facade maps this to the host-owned player lease and current logical epoch; clients cannot submit `lease`, `issuer`, `role`, entropy or authority participants. `actor_id` is an intended recipient, not proof of control. The kernel checks its lease and the profile checks deployment/legality. Same ID + same fingerprint returns the original terminal receipt, even after resources improve. Reusing an ID with changed fields rejects. Retrying a stale/invalid preview requires a fresh ID/current revision, not an automatic spend retry.

`submit` returns `{receipt,view}`. `advance` returns `{requested_ticks,consumed_ticks,stop_reason,events,view}`; bound one call to 100 ticks and stop on pause, missing space, terminal outcome or failed step. Each tick uses the kernel transaction path; committed earlier ticks remain if a later tick cannot run. UI views are never accepted as replacement state. `preview` returns `{revision,allowed,reasons,costs,targets?,changes?,required_confirmations}` without a receipt, entropy draw, observation consumption or mutation. Confirmation resubmits the actual typed intent and revalidates; a preview is no authorization token.

## View consumed by Godot

`command.view/v1` always contains the following keys; empty collections are arrays/objects, not omitted. Optional undiscovered values are `null` with a knowledge label, never a real hidden value rendered transparent.

| Key | Required shape and meaning |
| --- | --- |
| `session` | `{profile_id:"command",generation,epoch,revision,ledger_sequence,content_hash,tick,tick_ms:100,phase}`; phase `camp`, `exploration`, `encounter`, `victory`, `defeat` or `restore_prompt` |
| `clock` | `{paused,pause_reasons:[{token,owner,label,acknowledgeable}],can_advance}`; show every active reason, not one boolean invented by UI |
| `party` | `{roster_ids,deployed_ids,recipient_id,possessed_id,inspected_id,camera_follow_id}`; three deployed, reserve Ivo inspectable, clerk guest status retained |
| `actors` | Party members and observable enemies: `{id,name,faction,body,roster_status,conscious,position,health,focus,battery,stats,conditions,active_action,queue,ai,knowledge}`. Reserve entries have no world position or command authority |
| Actor `health`, `focus` | Per resource `{maximum,debt,current,reserved,free}`; use `current=max(0,maximum-debt)` for Health/Focus, retaining debt above a shrunken maximum. Battery/item quantities use their proper counted-resource representation, not Focus |
| `active_action` | Null or `{id,ability_id,source_id,target,state,activation_at,impact_at,recovery_at,paid_costs,reserved_costs,interruptible}`; state includes `approach`, `windup`, `recovery`; approach also exposes deadline/known route uncertainty |
| `queue` | At most four waiting `{id,admission_sequence,ability_id,source_id,target,reserved_costs,state,activation_at,impact_at,recovery_at,timing_certain,reasons}` entries. Unknown times are null. No hidden enemy future orders |
| `actions` | Recipient's known actions, including blocked/ghost bindings: `{id,name,category,rank,source_id,source_label,target_kind,range_m,radius_m,costs,available,reasons,cooldown_remaining_ticks}`. Known wrong-armor actions stay visible; availability uses the same predicate as submission |
| `targets` | Known entities/valid ground constraints for the current preview; `{id,label,relation,position,knowledge,identified_defenses}`. Do not send undiscovered hazards, secret immunity, enemy planned routes or exact saves |
| `equipment` | Inspected actor's body slots, active/alternate set references and instance bindings; comparison reports final Defense/resources/grant deltas and required unbinds atomically |
| `inventory` | Accessible containers and stable instances/stacks with definition, quantity, reserved/free, owner/binding, favorite/quest flags, permitted operations/reasons. Camp storage and reserve-bound gear are inspectable with access restrictions |
| `progression` | Serial class allocations, XP/current/pending level, attributes, purchased ranks, feats/powers, unspent budgets, prerequisites, respec price and legal next choices; story unlocks remain distinct |
| `world_actions` | Revealed Devices/Medicine/Insight/etc. checks with checker, tool/material cost, known DC and eligibility; authored helper option names one full check contributor |
| `logs` | Bounded ordered visible events `{id,tick,kind,actor_id?,target_id?,text,details}` and last event cursor. Details include rolls/modifiers only where the observer may know them |
| `encounter` | `{id,objective,status,can_retreat,outcome,reward_receipt_id,trial:true}`. Outcome/rewards are explicit committed facts, not inferred from animations |
| `space` | `{waiting,reason}` only. Typed requests are fetched separately through host-only `space_requests()`; no hidden actor/query payload in the public view |

The implementation keeps `CommandView` typed internally and serializes it once. Model/view copies never become a second resource ledger in GDScript. The following exact field shapes are normative; the notation is documentation, not a proposed TypeScript runtime. All fields are required unless their type explicitly includes null. `Id` is an opaque string, `Tick` is a nonnegative integer, positions are meters, and all `*_at` values are absolute simulation ticks, not seconds.

```typescript
type Id = string;
type Tick = number;
type Position = [number, number]; // [x,z], meters in CommandArenaOrigin
type Reason = {code:string, message:string};
type Pool = {current:number, reserved:number, maximum:number, free:number, debt:number|null};
type Target = {kind:"none"|"self"|"actor"|"point", actor_id:Id|null, position:Position|null};
type Cost = {resource_id:Id, label:string, amount:number, unit:"focus"|"item"|"battery"|"opportunity"|"credits"};
type ActionEntry = {
  id:Id, admission_sequence:Id, ability_id:Id, source_id:Id, actor_id:Id,
  target:Target, state:"waiting"|"approach"|"windup"|"recovery",
  activation_at:Tick|null, impact_at:Tick|null, recovery_at:Tick|null,
  approach_deadline_at:Tick|null, timing_certain:boolean,
  reserved_costs:Cost[], paid_costs:Cost[], interruptible:boolean, reasons:Reason[]
};
type AvailableAction = {
  id:Id, name:string, category:"weapon"|"powers"|"tech"|"items"|"movement",
  rank:number, source_id:Id, source_label:string,
  target_kind:"none"|"self"|"enemy"|"ally"|"point", range_m:number|null,
  radius_m:number|null, costs:Cost[], available:boolean, reasons:Reason[],
  cooldown_remaining_ticks:number, known:boolean, ghost:boolean
};
type Actor = {
  id:Id, name:string, faction:"party"|"hostile"|"neutral", body:string,
  roster_status:"deployed"|"reserve"|"guest_deployed"|"guest_reserve"|"encounter",
  conscious:boolean, position:Position|null,
  health:Pool, focus:Pool|null, battery:Pool|null,
  stats:{level:number|null, defense:number|null, attack:number|null, power_dc:number|null,
    saves:{fortitude:number|null,reflex:number|null,will:number|null}},
  conditions:{id:Id,kind:string,label:string,expires_at:Tick|null}[],
  active_action:ActionEntry|null, queue:ActionEntry[],
  ai:{policy:"conservative"|"balanced"|"spend",empty_policy:"role"|"assist"|"basic"|"hold",
    hold_after_orders:boolean,last_reason:string|null}|null,
  knowledge:"party"|"visible"|"identified"
};
type Item = {
  id:Id,definition_id:Id,name:string,container_id:Id,quantity:number,reserved:number,free:number,
  bound_actor_id:Id|null,bound_slots:string[],binding_version:Id,host_item_id:Id|null,
  favorite:boolean,quest_protected:boolean,accessible:boolean,reasons:Reason[],
  operations:{kind:string,available:boolean,reasons:Reason[]}[]
};
type Progression = {
  actor_id:Id,build_version:Id,xp:number,level:number,pending_levels:number,
  classes:{id:Id,level:number}[],attributes:{id:Id,base:number,gear:number,total:number}[],
  skills:{id:Id,rank:number,governing_modifier:number,bonus:number,total:number,max_rank:number}[],
  feats:{id:Id,rank:number}[],powers:{id:Id,rank:number,source_id:Id}[],
  unspent:{skill_points:number,feat_choices:number,power_choices:number,attribute_points:number},
  next_choices:{kind:string,id:Id,cost:number,available:boolean,reasons:Reason[]}[],
  respec:{cost:number,currency:"credits",available:boolean,reasons:Reason[]}
};
type CommandView = {
  schema:"command.view/v1",
  session:{profile_id:"command",generation:Id,epoch:Id,revision:Id,ledger_sequence:Id,
    content_hash:string,tick:Tick,tick_ms:100,
    phase:"camp"|"exploration"|"encounter"|"victory"|"defeat"|"restore_prompt"},
  clock:{paused:boolean,can_advance:boolean,
    pause_reasons:{token:Id,owner:string,label:string,acknowledgeable:boolean}[]},
  party:{roster_ids:Id[],deployed_ids:Id[],recipient_id:Id,possessed_id:Id|null,
    inspected_id:Id,camera_follow_id:Id|null},
  actors:Actor[],actions:AvailableAction[],
  targets:{id:Id,label:string,relation:"ally"|"enemy"|"neutral",position:Position,
    knowledge:"visible"|"identified",identified_defenses:{defense:number|null,
      fortitude:number|null,reflex:number|null,will:number|null}}[],
  equipment:{actor_id:Id,binding_version:Id,body:string,slots:{id:Id,item_id:Id|null}[],active_set_id:Id|null,
    sets:{id:Id,name:string,main_hand:Id|null,offhand:Id|null}[]},
  inventory:{currency:{credits:number},containers:{id:Id,name:string,accessible:boolean}[],items:Item[]},
  progression:Progression,
  world_actions:{id:Id,name:string,checker_id:Id,helper_id:Id|null,dc:number|null,
    costs:Cost[],available:boolean,reasons:Reason[]}[],
  logs:{id:Id,tick:Tick,kind:string,actor_id:Id|null,target_id:Id|null,text:string,
    details:{roll:number|null,modifier:number|null,threshold:number|null,
      damage:number|null,healing:number|null,resource_delta:number|null}}[],
  log_cursor:Id|null,
  encounter:{id:Id|null,objective:string,status:"none"|"active"|"won"|"lost"|"retreated",
    can_retreat:boolean,outcome:"victory"|"defeat"|"retreat"|"peaceful"|null,
    reward_receipt_id:Id|null,checkpoint_id:Id|null,camp_id:Id|null,trial:true},
  space:{waiting:boolean,reason:Reason|null}
};
```

`actions` always belongs to `party.recipient_id`; `equipment`/`progression` belong to `party.inspected_id`. The HUD need not infer this from list order. `active_action` includes an unpaid approach while the four future entries remain in `queue`. `impact_at` may be null during approach. Party health/focus/debt are visible; visible hostile Health is public in this trial, hostile debt/Focus/queue/unknown stats remain null or empty according to their field types. Unknown Focus is null, distinct from a party actor's zero-capacity pool. Missing known abilities are disabled ghosts, while undiscovered abilities are omitted entirely. No enemies outside observation scope appear in `actors` or `targets`.

For the contact-pause queue example, Mara's `focus` is exactly `{"current":56,"reserved":28,"maximum":56,"free":28,"debt":0}` after removing Mend. `active_action` is null, and her two queue entries have state `waiting`; releasing the last pause token makes Bind active at tick0, with `impact_at:10`, `recovery_at:30`, `paid_costs:[18 Focus]`, Focus38/reserved10/free28. Root can bind to those fields immediately once the facade exists. List availability evaluates known source/equipment/resources and queue capacity; target-specific range/LOS/approach legality comes from `preview` and is rechecked on submit. A future queued action need not wait for the active action to recover before admission.

### Shared renderer and isolated preview

The playable Command trial and its UI preview must instantiate the same `CommandGame`, consume the same `CommandView` and use the same renderer/HUD. Preview creation gets an independent host/session/seed and runs a deterministic replay of valid commands against an exact geometry fixture; its inventory, leases, outcomes, saves and trial rewards cannot reference or mutate the user's live journey. The renderer may receive an external `preview` label/control mode, but never a second catalog-based resource/action implementation. A preview replay can pause at contact, a paid windup, gear comparison or victory; its read-only presentation mode prevents users from submitting mutations to the live session. Normal seeded preview replay is separate from the privileged CMD-03 recorded-roll test driver.

## Typed actions and input ownership

| Action kind | Payload / rule |
| --- | --- |
| `pause.acquire`, `pause.release`, `pause.acknowledge` | Acquire a named authorized owner (`manual`, `ledger`, `selector`, `targeting`, `dialogue`), receive an opaque token; release that exact owned token. Acknowledge only an exposed automatic/restore token. No `resume_all` |
| `party.select`, `party.possess`, `party.inspect`, `party.camera` | Explicit actor ID and purpose. `party.possess` has an explicit `select` boolean; the portrait default uses `true` to select and possess atomically. `false` preserves the recipient; inspection of reserve changes neither. Downed possession rejects |
| `queue.enqueue` | Actor, ability/source, tagged target (`none`,`self`,`actor`,`point`) and optional declared item/set/opportunity ID. Append; if idle/unpaused it may activate immediately. At most four waiting entries, excluding active |
| `queue.remove`, `queue.reorder`, `queue.clear_future`, `queue.stop_clear` | Stable action IDs, complete desired waiting order for reorder. Clear future never touches active. Stop-clear requires explicit confirmation intent and retains paid cost/recovery |
| `movement.intent` | Possessed actor and normalized desired direction, updated on input change; cleared on modal entry/possession loss. Accepted only when ordinary action commitment permits movement, never a free windup cancel. Core requests a path and owns speed/collision outcome |
| `ai.configure` | Actor, `conservative`/`balanced`/`spend`, empty-queue policy and Hold-after-orders. Explicit player replacement of AI waiting order is atomic; invalid replacement preserves original AI order/claim |
| `equipment.apply`, `weapon_set.activate` | Complete instance/slot plan with expected binding versions and explicit dependent-order cancellation list if confirmed. Camp restrictions/active locks remain enforced |
| `inventory.use`, `inventory.transfer`, `loot.take` | Stable instance/quantity and recipient/source container. Use becomes the same queued three-second action as the hotbar, including exploration |
| `shop.buy`, `shop.sell`, `craft`, `dismantle`, `upgrade.apply` | Stock/recipe/host/upgrade IDs, quantities, selected trained crafter and explicit protected-item choices; use one multi-service commit, fixed content prices, no menu refill |
| `progression.level`, `progression.respec` | Complete serial allocation and any necessary unbind plan. Rejection changes no XP/currency/debt/grants. Garden-free respec is distinct from paid campaign fixture cases |
| `skill.use`, `dialogue.assist` | Authored interaction/option, checker and tool/target IDs. Core returns an attributed once-only outcome; root maps only declared facts into NarrativeSession |
| `encounter.start`, `encounter.retreat`, `encounter.retry`, `camp.enter`, `camp.rest` | Authorized location/context; start captures the full checkpoint; retry restores it through fresh authority. Rest takes 50 simulation ticks and refills neither consumables nor campaign rewards |
| `profile.prepare_exit` | Readiness/barrier result only; reject any unsettled operation. Root coordinates destination validation/commit through the gated host lifecycle; Command cannot deactivate itself before the destination succeeds |

### Normative action payload examples

Each object below is the exact `action` member of the earlier `command.action/v1` envelope. Every actual submission supplies a fresh `command_id` plus the latest `generation` and `expected_revision` from the view. IDs shown for existing gear are the accepted fixtures; receipt, pause, action and version IDs are illustrative opaque values and must be read from the current view/receipt. An example is structurally valid, not permission to bypass its phase, resource or prerequisite checks. Null target fields are required. Unknown keys reject.

```json
[
  {"kind":"party.select","actor_id":"mara"},
  {"kind":"party.possess","actor_id":"mara","select":true},
  {"kind":"party.possess","actor_id":"player","select":false},
  {"kind":"party.inspect","actor_id":"ivo"},
  {"kind":"party.camera","actor_id":null},
  {"kind":"pause.acquire","owner":"ledger","context_id":"ledger-main"},
  {"kind":"pause.release","token":"pause-0044"},
  {"kind":"pause.acknowledge","token":"pause-contact-1"},
  {"kind":"encounter.start","encounter_id":"garden_patrol"},
  {"kind":"encounter.retreat","encounter_id":"garden_patrol"},
  {"kind":"encounter.retry","checkpoint_id":"checkpoint-0001"},
  {"kind":"camp.enter","camp_id":"garden_camp"},
  {"kind":"camp.rest","camp_id":"garden_camp"},
  {"kind":"queue.remove","actor_id":"mara","action_id":"action-0012"},
  {"kind":"queue.reorder","actor_id":"mara","action_ids":["action-0013","action-0011"]},
  {"kind":"queue.clear_future","actor_id":"mara"},
  {"kind":"queue.stop_clear","actor_id":"mara","confirm_paid_cost":true},
  {"kind":"movement.intent","actor_id":"player","direction":[0.0,1.0]},
  {"kind":"ai.configure","actor_id":"mara","policy":"balanced","empty_policy":"role","hold_after_orders":true},
  {"kind":"equipment.apply","actor_id":"player","expected_binding_version":"4","changes":[{"slot_id":"main_hand","item_id":"staff-9"},{"slot_id":"offhand","item_id":"staff-9"}],"cancel_action_ids":[]},
  {"kind":"equipment.apply","actor_id":"player","expected_binding_version":"5","changes":[{"slot_id":"focus_tool","item_id":null}],"cancel_action_ids":[]},
  {"kind":"weapon_set.activate","actor_id":"player","set_id":"player_set_2","expected_binding_version":"6","cancel_action_ids":[]},
  {"kind":"inventory.use","actor_id":"mara","item_id":"dressing-stack-1","target":{"kind":"actor","actor_id":"player","position":null}},
  {"kind":"inventory.transfer","item_id":"dressing-stack-1","quantity":1,"from_container_id":"party_pack","to_container_id":"camp_storage"},
  {"kind":"progression.level","actor_id":"clerk","expected_build_version":"1","class_id":"scout","skills":[{"id":"devices","ranks":2},{"id":"lore","ranks":2},{"id":"medicine","ranks":2}],"feats":["marksmanship_ii"],"powers":[],"attributes":[],"unbind_item_ids":[]},
  {"kind":"profile.prepare_exit"}
]
```

`party.select` changes only the order recipient. `party.possess(select:true)` validates the actor once and changes recipient and possession in one transaction; if possession is illegal, neither changes. `select:false` changes only possession. `party.inspect` changes only inspected actor; `party.camera` changes only camera follow, with null selecting free camera. No action clears committed queues. `pause.acquire` returns its generated token in the receipt's `pause_token` field; a repeated accepted command returns the same token. `context_id` is a host UI context identity, unique among that owner's live contexts. Releasing a token never acknowledges another owner's pause. Contact/defeat/restore tokens originate in the core and cannot be acquired by naming their owner in UI JSON.

Equipment `changes` is an atomic patch against `expected_binding_version`: omitted slots remain unchanged; null unbinds; all occupancy changes needed for a two-handed item must be present. The two hand entries referencing the same staff represent one owned instance occupying two slots. The profile checks body fit, permissions, source locks and all affected current bindings before applying any entry. `cancel_action_ids` must exactly name the dependent future orders the user explicitly agreed to cancel; it cannot cancel an unrelated actor's order or paid action. Unequip uses the same operation with null, not a second mutation path. Both per-actor and item binding versions are projected; the per-actor version is the optimistic comparison token for this plan.

`progression.level` buys exactly the next level, with all rank increments and choices validated at acquisition. Each `attributes` entry is `{id,amount}` and each power entry is `{id,rank}`; these arrays are empty when no award is spent. The clerk example is the authored level 6→7 plan and requires XP 2100 at camp. Omitted earned choices are banked according to the design. The complete respec action shape is:

```typescript
{
  kind:"progression.respec",actor_id:Id,expected_build_version:Id,
  initial_attributes:{id:string,value:number}[],
  levels:{class_id:string,skills:{id:string,ranks:number}[],feats:string[],
    powers:{id:string,rank:number}[],attributes:{id:string,amount:number}[]}[],
  unbind_item_ids:Id[]
}
```

`initial_attributes` contains all six named base modifiers; `levels` contains exactly one allocation per retained level, ordered from 1. The awakening flag is authoritative story/trial state, never submitted. Full serial validation prevents late prerequisites being used retroactively. The whole plan is sent to pure `preview` before submit; a preview request is exactly `{schema:"command.preview/v1",generation,expected_revision,action}` with no command ID and no stored server draft. Preview returns `{available,reasons,view}`: `view` is the hypothetical player-filtered `CommandView`; it never replaces live state, consumes RNG, claims an item or changes revision. Submit always revalidates against the live version. JSON examples are documentary; `initial_attributes` and level choices must come from the player's explicit allocation or a visible preset preview, not hidden UI defaults.

`encounter.start` accepts only the authored encounter at an eligible camp/exploration context and captures its complete checkpoint before spawn/activation. It cannot reset an active encounter or reroll current enemies. `encounter.retry` requires the current exposed checkpoint ID; after defeat it restores all pre-encounter resources/items/roll state and rotates authority. Repeating a completed encounter is a new encounter instance with trial-only once-per-instance rewards. `camp.enter` is legal after settled victory/retreat or at the safe camp marker in exploration; it is rejected during an active encounter or pending operation. Authored camp placements come from content, never client coordinates. `camp.rest` starts the 50-tick activity and acquires no automatic full pause that would prevent its progress. Return to campaign uses `profile.prepare_exit`, never a shortcut that leaves an active trial unresolved.

No gameplay submit can set HP/Focus, award XP, inject a die, grant arbitrary gear, perform an impact or mark a target dead. Mandatory source loss/authoritative story outcomes enter a separate host/system path with specific typed effects and once-only provenance; public JSON cannot request that authority.

Godot owns modal focus, input glyphs and camera. It acquires/releases Command pause tokens as each context opens/closes; Back is not a stop action. Keyboard/controller mappings follow Command design, including selector LB/RB categories versus L3/R3 recipient, target abandonment on actor change, and confirm dialogs that suppress recipient changes. Root must clear held input on modal transitions/load/disconnect. Favorites store actor + ability family/variant/source, not list index. Simulation time is accumulated in Godot at 100 ms but discarded wall-time backlog while paused must not burst through on Resume; fractional unpaused remainder is retained deliberately.

## Tick, space and 3D garden handshake

At logical tick T: expire conditions, resolve due impacts in fixed encounter initiative order with immediate interruption, finish recovery/approach, activate ready heads, then evaluate edge-based auto-pauses. A current-tick activation pump after an accepted unpaused enqueue or final pause release permits the documented tick0 activation and tick10 impact without inventing a +1 tick delay. It never reprocesses due impacts. Later activations are once-only under action IDs. Every ordinary action has windup10/recovery-end30 ticks from activation; Move has its own bounded path lifecycle. Approach replans at most every10 ticks and expires after60.

`advance(n)` stops before consuming a tick whose required canonical observations are missing/stale. `observe_space` stages only typed frames for the current generation, expected tick/revision, producer sequence and geometry revision; the profile transaction consumes that frame cursor together with the step. A rejection cannot advance its observation cursor or RNG. Duplicate frames are harmless only when their fingerprint agrees. Save includes committed observations and pending request identity; old live producers are fenced after restore.

`SpaceRequest` and `SpaceFrame` are host-only typed records, available to both the Godot adapter and an exact headless geometry fixture. The public bridge action parser cannot construct them:

```text
SpaceRequest {
  id, generation, geometry_revision, tick, state_revision,
  kind: pose | visibility | los | path | swept_path | ground,
  actor_id, target_actor_id?, from_mm:[x,z], to_mm:[x,z],
  radius_mm, maximum_distance_mm, required_for: admission | activation | impact | movement
}
SpaceFrame {
  generation, geometry_revision, tick, state_revision,
  producer_id, sequence,
  results:[{request_id,valid,reason_code,
    position_mm:[x,z]?, visible:bool?, clear:bool?,
    path_mm:[[x,z],...], ground_height_mm:number?}]
}
```

The exact variant determines which optional result values must be present; mismatched type, request, generation, geometry revision, state revision or tick fails validation. Headless fixtures implement the same route/LOS requests with authored walls/anchors and recorded result sequences, including blocked and revised geometry cases. Live Godot performs the corresponding nav/collision/ray queries. Requests are host-side data, never an enemy-plan tooltip. `SpaceFrame` supplies requested actor/target poses, identified visibility/LOS, collision-clear path waypoints, ground clearance and request IDs. It does not supply hit chances, damage, resources or secret knowledge decisions. Core requests only what the next step needs; root's adapter can query hidden enemies for authoritative simulation, but those results never flow verbatim into player view. `advance` cannot block forever silently: return `waiting_for_space` plus host query IDs while leaving gameplay unchanged. Invalid/unreachable paths follow the six-second approach/failure rule, not fabricated direct-line movement.

The garden uses a root-owned `CommandArenaOrigin` marker at the agreed imported terrace origin `(41.3,0.54,-2)` with unit-scale orthonormal X/Z basis. Combat coordinates are physical meters; do not multiply them by the existing visual scale1.7. Core 2D coordinates map to `origin + right*x/1000 + forward*z/1000`; Godot supplies floor height and renders motion from canonical poses. Root verifies anchors/path/LOS against actual collision/nav; an incompatible arena refuses start visibly. No teleporting through rails, no damage from animation callbacks, and no input-only Godot replay claim. Rendering interpolates committed poses and events; all logical movement, costs and RNG stay in Rust.

Root owns a shared data-only `godot/content/command_garden.json`; Rust reads the exact same bytes with `include_str!`, and content/geometry hashes are saved. Schema `command.garden/v1` records the arena origin/basis and physical-meter geometry: main terrace `x[-4.59,13.77], z[-8.84,8.84]`, west ramp `x[-8.33,-4.59], z[-1.7,2.72]`, and four raised-bed rectangles centered at `(-3.91,-5.61)`, `(-3.91,5.44)`, `(5.78,-5.61)`, `(5.78,5.44)`, each size `[5.27,4.59]`. The source GLB presentation transform is root-owned (`BasisY(-PI/2)*scale15.64`, translation `(-0.9452,1.4705,0)`); it is not a second transform applied to these already-authored combat coordinates. The origin/geometry assumptions require root's actual collision check before runtime acceptance.

The JSON also records fixture spawns, exit/camp/interaction anchors, obstacle IDs, geometry version and authored routes/portals needed by the deterministic host adapter. Read requests/results in the same local frame; convert scene queries at this boundary. Headless and Godot adapters consume this shared geometry and can replay the same canonical observations; no Godot type enters `oathshaper-core`. If geometry changes, stale observations reject until new matching results exist. The worked trace's z0–2 corridor is deliberately clear of beds. Collision/navigation outside that authored footprint does not silently extend legal encounter space.

Actor IDs are fixed: `player` (display name Corsair), `mara` (Mara), `clerk` (Civic clerk), `ivo` (Ivo), `hound` (Hound), `sentinel` (Sentinel). IDs never derive from display names. Initial recipient, possession and camera follow are `player`; inspected actor is `player`.

Deploy Corsair `(0,0)`, Mara `(-2000,0)`, clerk `(-2000,2000)` in internal millimeters (public view `[0,0]`, `[-2,0]`, `[-2,2]` meters); Ivo reserve. Hound `(2000,0)`, sentinel `(6000,2000)`. Use real distinct rig/weapon identities where available; missing animation is a labeled presentation limit, never a replacement for numerical effects. The existing garden capture is not collision evidence. NPC policies run through the same profile legality/claims path: hound approaches/attacks the nearest observable living party actor, stable-ID tie break; sentinel shoots the nearest visible living party actor and waits/reacquires while Disabled/LOS-blocked. Exact CMD-03 target choices/rolls are an authored deterministic fixture; live seeded AI still exercises movement and choices.

Companions obey the accepted hazard → low-health consumable policy → role → visible basic/hold order. They create at most one AI waiting order; Conservative spends no limited resources, Balanced retains at least20% free Focus and one device charge/encounter, Spend may use legal resources. Role logs explain visible decisions. Hold-after-orders suppresses refill. Possession/inspection never clears queues, lends reserve equipment or grants readiness. Live AI and exact scripted fixture runs are separate evidence, both required.

## Numerical/content boundary and save behavior

| Fixture | Values required from the design |
| --- | --- |
| Corsair, Arms6 | HP80, Might3/Agility2/Body2; blade attack10 with Single blade I, Defense15 with light coat/buckler; Lunge −2 attack/+4 damage |
| Mara, Scout3/Storm mystic3 | HP50, Focus56, Spirit3, Medicine3, DC16, Defense12; Bind18, Gale10, Mend16, Veil20; depletion debt persists independently of maximum |
| Clerk, Scout6 | HP62, ranged attack7, Defense15, Devices4+Intellect2+Fieldwork2=8; three survey-tool charges; guest narrative status |
| Hound / sentinel | HP30/18, Defense13/15; hound attack4/damage6/Will1/Reflex2; sentinel attack5/damage8/deviceDC14. Root does not disable attacks; successful Disrupt does |
| Exact result | At tick82: HP80/50/54, Mara Focus12, battery2; hound damage33, sentinel23; one reward300 XP/45 trial credits/one trial seal. Corsair approaches12 ticks from tick60, activates72, impacts82 |

The content layer must derive gear, grants, attributes, skills and six build patterns from authored allocations rather than hard-code actor-specific exceptions. Implement all nineteen scenario requirements, including construct compatibility, recipes, legal level7 allocation and failed respec. The first integrated slice may expose only complete abilities from the design's vertical-slice list; other entries must remain explicitly unavailable until their behavior exists. Do not claim complete level20/alternate-body/feat-chain implementation from the garden slice. New vendor stock or equipment fixture values absent from the packet must be explicitly authored in content/evidence, never sourced from the old preview catalog by accident.

`save_json` is a settled-tick snapshot of all Command namespaces plus kernel receipts, entropy, claims, snapshots/locks, observations, cooldowns, encounter/retry identity and trial reward ledger. `restore_json` first validates the whole candidate, then rotates host generation/reissues private leases and creates a safe `restore_prompt` token. Persist logical menu reasons/view preferences, but replace nonexistent UI-object ownership with the restore prompt; rebuilding open menus issues new tokens before releasing it. No old callback may apply an impact, and restores cannot charge an already-paid windup again.

The first integration uses a dedicated opaque trial slot, `user://oathshaper_command_trial_v1.json`, containing `CommandGame::save_json()` without changing the campaign narrative save schema. Entering the trial suspends the underlying campaign scene/session untouched; Return restores that suspended scene/session. Trial load validates Command content, claims and geometry dependencies into a candidate before replacing only the trial. Save-file crash durability is a host concern. `encounter.retry` restores the entire pre-encounter snapshot with fresh authority; trial XP/currency/items never enter campaign accounting. `profile.prepare_exit` checks camp and every pending operation before the host returns to the suspended campaign. Full campaign/profile migration is a later integration gate, not required for this independent trial slot.

## Nineteen-case implementation/evidence map

All statuses are **planned**. Rust tests prove rules; bridge/HUD tests prove integration; actual keyboard/controller runs prove the reachable input path. One does not substitute for another.

| Case | Core assertion / subsystem | Root bridge/Godot evidence |
| --- | --- | --- |
| CMD-01 | Focus56→reserve44/free12, reject Veil without RNG change, remove Mend→28/28; nested pause tokens | Queue costs and all pause reasons visible; Ledger close leaves contact/manual ownership intact |
| CMD-02 | Paid Gale stopped5 retains readiness30 and cost; Basic unavailable29/available30 | Stop warning; windup ends without refund or rapid attack exploit |
| CMD-03 | Exact recorded-roll garden through82, fixed initiative, Root versus Disable, once-only damage/reward | Three actors/two enemies render canonical positions/actions; visible logs reconcile totals |
| CMD-04 | Lens capacity0 preserves debt18; remove/re-equip/save retains12/30; learned grant independent | Crossed source binding and exact capacity/current display |
| CMD-05 | Atomic staff replacement, Defense15→14, stale bound instance and construct slot failure | Body-aware comparison/confirm; original gear preserved on reject |
| CMD-06 | Clerk level7 at2100XP; six skills, Marksmanship II, HP69/current61/debt8;99-credit respec fails | Complete allocation preview; no free refill or partial purchase |
| CMD-07 | Heavy armor blocks Gale, Mend cannot repair construct, Silence permits tech Disrupt | Consistent availability from categories and Inventory Use |
| CMD-08 | Selection/possession independent; reserve cannot deploy; AI Gale10 replaced by Bind18 atomically; invalid replacement rolls back | Recipient/camera change retains queues and labels guest/reserve |
| CMD-09 | Token ownership/order state unaffected by modal navigation | 1280×800 controller Back stack, held-confirm suppression, target/queue/ledger path |
| CMD-10 | Paid tick5 save restores claims/RNG; fresh generation; impact10 once; corrupt candidate leaves live intact | Resume screen, HUD reconstruction, fenced old callbacks |
| CMD-11 | Defeat pause, no resurrection/reserve rescue; complete retry restores two dressings; reward once | Retry/Load reachable; victory cannot arise from temporary disable |
| CMD-12 | Craft4scrap+20credits once, salvage2, protected/stale sale race atomic | Camp workbench/crafter/stock and exclusion reasons |
| CMD-13 | One dressing shared claim; original rejection durable; paid miss after activation | Inventory Use invokes scheduler and shows reservation |
| CMD-14 | Approach deadline60/replan10; fail pause once; actor identity retained; paid dead-target miss | Actual blocked-route/LOS observation; failure reason without hidden immunity leak |
| CMD-15 | Six legal level6 graphs differ in attack/HP/skills/feats/powers; early feats/third class/unawakened path rejected | Six build comparison and prerequisites, no cosmetic-only claim |
| CMD-16 | Quiescence rejects pending camp operation; exit preparation does not partially mutate | Host destination failure preserves live Command; round trip preserves debt/instance/trial credits |
| CMD-17 | Max86/debt40/current46→56/40/16; admission-order Bind/Mend canceled, Gale10 retained/free6 even after reorder; replay inert | One reconciled resource/queue view and failure pause, no transient overreservation |
| CMD-18 | Recipient change abandons only preview and preserves per-actor state/tokens | L3/R3 and focusable header buttons; LB/RB categories; confirmation consumes switch input |
| CMD-19 | Helper full check18 beats17; Corsair10 fails; eligibility recheck and consequence once | Named checker/contributions, speaker unchanged, no reserve/stacked helper |

## Delivery gates

1. **Before code:** root confirms independent repaired-foundation acceptance and supplies the exact worktree/base SHA. Reconcile this facade against the accepted APIs, especially read claims, complete authority and host observation/provider registration. No dependent runtime edits before that message.
2. **Core slice A:** typed content/fixtures, scheduler/pause/claims/queue/AI/space, rules cases01–04/07–08/10–11/13–14/17. Preserve a recoverable commit before UI integration. This is not all of Command.
3. **Core slice B:** equipment/sets/upgrades/body policies, skills/economy/serial progression/respec and lifecycle cases05–06/12/15–16/19; all required ability interactions must execute rather than merely appear in JSON.
4. **Root integration:** normal launcher→garden camp→skill route/contact→queue combat→loot/recovery→changed gear/build→next encounter, plus save/restore/retry. Complete cases09/18 with native keyboard/controller and source/action/cost/event telemetry. Retain existing narrative and launcher behavior.
5. **Independent review:** challenge resources/authority/source loss, NPC decisions, hidden views, stale observations, save candidate failure and physical UI reachability. Track unresolved scenario rows honestly. Core test counts, snapshots or a successful scripted fight alone do not establish complete playability, physical Deck validation or balance.

This document was prepared by reading the reviewed design/scenarios, canonical narrative/Godot boundaries and the draft foundation/audit. No compilation, web research, workflow automation call, runtime test or combat implementation was performed for this contract.

## Core slice A projection additions (2026-10-22)

The compiled core adds `actor.appearance:{main_hand,offhand,armor}` using scene weapon/armor kinds. Item fields add `category`, `description`, `compatible_slots:string[]`, `occupies_slots:string[]`, and `grants:string[]`. `inventory.capacity` is null (unlimited list) and `used_stacks` counts actual instances/stacks. `equipment.options` contains `{id,label,description,item_id,slot_ids,action,available,reasons}` and sends the complete atomic occupancy plan; the renderer must not infer two-hand exceptions. `progression.presets` contains `{id,name,label,description,action,available,reasons}`. Top-level `capabilities` contains equivalent authored action affordances for camp, crafting, purchases and skill interactions.

Canonical abilities currently implemented: `basic`, `lunge`, `binding_current`, `gale_arc`, `mend`, `veil`, `gust`, `disrupt_device`, `pinning_bolt`, `dressing`, `brace`. Native `SpaceFrame`/`SpaceRequest` structs are serde serializable. Each host frame must cover the complete current request list and use the next producer sequence; after a restore the host adapter must resume its saved producer cursor (pending integration refinement). `advance` currently consumes at most one observed tick per call, reports `remaining_ticks`, and uses a zero-time activation pump before consuming a tick when an actor becomes ready at the current boundary. The bridge should service requests and repeat advancement, not assume an `advance(100)` call consumed 100 ticks.

Serial respec, weapon-set actions, full role AI, mandatory capacity-shrink reconciliation, exact recorded CMD-03 and several advanced content cases remain subsequent work; the first core checkpoint does not claim all nineteen cases.

Host cursor clarification: call `CommandGame::next_observation_sequence(producer: &str) -> u64` for each frame and serialize that value as its opaque `sequence` string. Staging is not consumption; command/AI admission may invalidate a staged frame. The method reflects saved committed state after restore. `SpaceRequest` remains unchanged.

## Slice B contract reconciliation

`progression.respec` now accepts the documented complete serial allocation. All six development presets are projected as full `progression.presets[].action` values with prerequisites, unbind plans, previews and atomic commits. The garden costs0; a private paid-context fixture validates the100-credit rule. Resource debt persists across every rebuild. Public `dismantle:{actor_id,item_id}` salvages an arc edge to two scrap; `upgrade.apply:{actor_id,host_item_id,upgrade_item_id}` installs that edge into an owned sabre using a trained crafter.

Host-only `CommandGame::revoke_item_source(&str)` atomically removes an item source and reconciles affected pending resource claims in original admission order. It is not a public UI action. Lost grants project as disabled ghost actions. `actor` knowledge projection omits hostile actors/targets outside current party observation.

Restore acknowledgement retires all saved UI-owned pause contexts, including manual, ledger, selector, targeting and dialogue. Logical automatic reasons remain intact and independently acknowledgeable. No absent UI object retains an unreleasable token. Restoring does not alter paid action timing, cost or future orders. Runtime manifest version2 rejects earlier slice-A saves instead of silently inventing a migration.

## Reviewed-core repair contract (2026-10-22)

Current runtime manifest is **version 3 / `command-garden/v3`**. New saved Ward and pursuit state makes earlier prototype saves incompatible. The public action/view schema names remain v1. This is an isolated trial save, not a campaign migration.

- `target.select` accepts `{kind:"target.select",target_id:"sentinel"}` or null to clear. It updates `party.selected_target_id`; Assist AI uses that visible target. Selecting a recipient or possessing an actor remains separate.
- `actor.ai.last_reason` is a current human-readable decision/hold explanation. An available equipped ranged shot is legal without pursuit. The six-meter AI pursuit allowance limits **additional travel beyond weapon reach**, and active AI approaches track/cap actual travel at six meters. Explicit player approaches retain their six-second deadline. This interpretation was agreed during native trial testing; it prevents a crossbow user at eight meters from idling against a visible enemy within its fifteen-meter range.
- `actions[].source_label` names the equipped item or learned ability. Lost grants remain labeled disabled ghosts. `conditions` labels show remaining/original Ward absorption.
- All host observations must contain the exact current request set, required per-variant fields, bounded coordinates and complete path endpoints. Gust adds ordinary `swept_path` queries for consecutive 0.25-meter displacement candidates up to two meters; adapters need no effect-specific authority. A blocked candidate stops the push. Gust deals no damage.
- Restore acknowledgment is an atomic system-authorized `Session::resume_and_submit` operation. Rejection leaves the restored kernel paused. Identical accepted acknowledgment retries return the same receipt. Old UI pause contexts retire only on a newly accepted acknowledgment. Replayed encounter starts do not replace the pre-encounter checkpoint.
- Lunge uses four-meter admission reach and at most two meters movement, with two-meter final reach. Bind rank I has a two-meter radius. Mend has eight-meter range, permits any trained armor, and remains subject to Silence. Veil requires unarmored/robe equipment and grants nearby deployed allies twelve arc/frost absorption for nine seconds; it never stacks or heals an existing Ward.
- Serial presets now enforce each supported path's power family. Blade adept currently offers learned Gust/Mend; Investigator Bind/Gust/Mend; Storm mystic the full implemented catalog. Absent late abilities are not represented as working grants.
