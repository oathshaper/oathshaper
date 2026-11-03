# Flow release slice

## Surrender and resource update — 1 November 2026

Flow surrender uses a voiced in-world shot with accept/decline choices. Victory exits the trial automatically into the shared garden resolution and exploration, including menu chapter entry. Payroll collection remains a separate interaction. See [outcome verification](garden-outcome-20261101.md).

Harbor normal attacks cost no Focus. Harbor power retains its base 10 Focus cost (efficiency training still applies). Focus recovers at 4 points per second, capped at its maximum, starting two seconds after the last Focus expenditure and only outside slow time. Pause stops recovery. The due tick uses the existing serialized cooldown map, so Flow v2 saves remain loadable. This is an Oathshaper balance choice, not a reproduction of Jade Empire's weapon resource rule.

Idle dodge uses a temporary backward vector and no longer changes persistent walking input. Pause and resume clear cached movement, guard and trigger state. Native 3 → Enter and post-dodge idle tests pass; the original report's exact preceding input sequence was not captured.

## Current amendments — 1 November 2026

The earlier checkpoints below are historical. The current cast and v2 save boundary are documented in [the playtest repair](../flow-playtest-repair-20261101.md). Harbor blade now uses the sabre. Target projection and attack admission share a living-target fallback: retain a living manual target; otherwise prefer an unobstructed nearby enemy; project an empty target when none remain. Active attacks retain their committed target. The additional `targeting` view object supplies `distance` and `line_of_sight`; `hero.target_id` and `party.selected_target_id` agree. See [the control comparison and remaining gaps](../research/014-jade-empire-input-and-flow-followup.md).

Base daaee1c. Independent real-time `FlowProfile` uses reviewed Session authority, receipts, observations and RpgState resources/items/grants. It does not use Command's queue/scheduler. The shared garden geometry wire and deterministic geometry fixture are reused; no Command combat rule is called.

## Host integration

`FlowBridge` exposes create(decimal seed), view(), submit(action JSON), preview(action JSON), advance(ticks), save_json(), restore_json(save), space_requests(), space_sequence(), observe_space(frame JSON). Responses are JSON `{ok,data}` or `{ok:false,error:{code,message}}`. Public intent envelope is `{schema:"flow.action/v1",command_id,generation,expected_revision,action}`; identifiers/revisions are strings. `flow_trial.gd` is a Control with `finished` signal, `preview_mode=false`, `campaign_mode=false`, `seed_value="20261022"`, and monotonic `has_won()`. Root owns campaign persistence after reading that result; standalone/preview never writes campaign.

Actions use snake-case `kind`: start, camp, retry, pause/unpause `{token}`, resume `{token}`, style `{style}`, assign `{slot,style}`, target `{actor_id}`, move `{direction:[x,z]}`, attack `{verb}`, guard/heal/focus/enhance `{enabled}`, dodge, follower `{mode}`, preset `{preset}`, train `{style,track}`, attribute `{attribute}`, equip `{item_id,socket}`, unequip `{socket}`, rest, surrender `{accept}`. AI intents are private and rejected by public transport. Style IDs stone/gale/harbor/still, presets stone/gale/harbor/storm, verbs normal/power/area. Omitted verbs reject without borrowing another style.

View schema `flow.view/v1`: session strings generation/revision/ledger_sequence plus tick/tick_ms50/phase; clock paused/pause_reasons/restore_token; hero style/diamond/target_id/focus_mode/chi_enhancement/healing/preset/attributes/ranks/skills; actor identity/position in meters/resources/conditions/active_action; follower mode/version/support_remaining/next_pulse; verbs cost/resource/damage/range/startup/recovery; inventory copper/items; progression level/xp/style_points/attribute_points; encounter won/surrender/objective; logs. Actor projection includes shared stage presentation fields only. Host ticks require complete current fenced SpaceFrame, with sequence from space_sequence. Admission may invalidate staged geometry; pump again without consuming wall-time debt when consumed_ticks is zero.

## First checkpoint evidence and limits

Four core tests pass: all base preset/gem transactions and no free refill; absent Gale power rejection; Focus entry/pause/exit and save acknowledgment; real Still→Stone resonance bonus. Initial actors use accepted Body/Spirit/Mind formulas, six style points, Warden80/Runner48/Deputy64, Mara's independent Health/Chi and finite support budget. Live enemy AI is separate from the authored worked trace; no exact FLOW-01 full encounter or human balance claim.

Not yet claimed: transformation assets/clearance, additional learned style templates, Smoke/Ember/technology, complete skill interaction routes, consumable vendors, gem upgrades/third socket, buffer window, exact contact-volume arcs/projectile simulation, alternate follower kits, retreat, every design scenario, physical Deck validation. Supported runtime must be independently reviewed and demonstrated through native controls before release acceptance. Shared rigs currently use existing procedural combat presentation; this is not Jade animation parity.

## Native checkpoint

`flow_trial.gd` now implements the lifecycle above. It renders the shared imported garden and rigs through the shared presentation-only stage, and owns its own HUD/input/menu. The left diamond uses 18px style labels, Health/Chi/Focus bars, exact resource costs and explicit missing verbs. Actor/skill score, style training, two gem sockets, four preset rebuilds, one Mara follower and chapter save/load are reachable from its paused menu. Tab stays within the modal; controller B closes a modal without dodging; D-pad chooses styles only in combat. World mouse input is received inside the SubViewport, so HUD clicks cannot also attack. Camera mouse orbit uses middle drag because right click is the power attack.

`campaign_mode` changes the exit caption to Return to quay. `has_won` latches only the core's committed encounter result and remains true for the current host lifetime. Root must integrate shared narrative completion and voice attachment. The host never edits campaign state. Native profile saves use `user://oathshaper_flow_trial_v1.json`.

Core uses forward 90-degree Palm and 120-degree staff-sweep tests, explicit front guard, paid startup cancellation, real Chi healing and a finite support budget. Targeted projectiles have flight time and a fixed destination; their current collision model is endpoint radius plus current sight, not a swept moving projectile body. Contacts use authored planar geometry and simple capsule sweeps; animation is presentational. The complete design's one-attack buffer, precise impact-boundary cancellation, form geometry, additional item/style/follower kits, full skills/economy and exact worked encounter remain outside this checkpoint. They are not accepted merely because the source document specifies them.
