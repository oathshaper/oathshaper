# Combat systems: prior art and architectural consequences

> Comparative research and independent design proposals. See the [Research and third-party rights notice](NOTICE.md); references do not imply affiliation or permission to reuse source-game assets.

Research date: **2026-10-21**. Depth: **deep**. Status: research and design; no combat implementation is claimed. Companion deliverables: [implementation plan](../combat-foundation-plan.md) and [interactive interface study](../design/combat-profile-preview.html).

## Research summary

Oathshaper can support these games' different combat experiences by separating the RPG state model, action scheduling, direct control, and presentation. The strongest common foundation is a party of persistent actors with owned equipment, granted abilities, resources, effects, and relationships; the largest differences are who controls those actors, when actions resolve, and how the player selects them. Build six curated profiles around that foundation, with explicit balance and save boundaries, rather than exposing every combination as supported.

## Key findings

1. **Queueing and pausing are separate capabilities.** The KOTOR II manual describes per-character action queues and commands during combat pause. Queue exhaustion is a behavior decision; it is not a reliable definition of encounter completion. This is verified family precedent, not a claim that every KOTOR I edge case is identical. [S01: official manual, 2004/2005](https://cdn.akamai.steamstatic.com/steam/apps/208580/manuals/KOTORII_Manual.pdf).
2. **Jade Empire is a distinct party/control model.** Its manual describes one active follower, Attack/Support modes, and restrictions on changing followers during combat. Its martial, weapon, magic, transformation, and support styles are not simply different weapon slots. Tactical pause and Focus also demonstrate that an action game can expose planning assistance. [S02: Special Edition manual, 2007, printed pp. 17–23](https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453).
3. **The Mass Effect reference is a third-person squad shooter.** Mass Effect 2 combines direct shooting with squad orders, a paused command interface, power cooldowns, and armor/shield/barrier defenses. Oathshaper should support a first-person control variant as well, but that requires its own camera, aiming, and animation work. [S03: EA PC manual, 2010, pp. 9–17](https://eaassets-a.akamaihd.net/eahelp/manuals/mass-effect-2-manuals_PC_en_GB.pdf).
4. **BG3 presentation and Pathfinder rules are different layers.** Larian identifies BG3 with D&D 5e. Its combat article discusses shared initiative opportunities; that is useful interaction precedent, not a specification for Paizo mechanics. Pathfinder's encounter rules explicitly use three actions and a reaction, while Paizo markets Starfinder 2e as compatible with Pathfinder 2e. [S04: BG3 official overview](https://baldursgate3.game/about), [S05: Larian development article, 2020-08-07](https://baldursgate3.game/news/a-little-about-combat-stealth_3), [S06: Player Core encounter rules](https://2e.aonprd.com/Rules.aspx?ID=2007), [S07: Paizo Starfinder overview](https://store.paizo.com/starfinder/).
5. **Two useful missing styles stress different scheduler assumptions.** An action/ATB hybrid separates ordinary action from resource-gated commands; simultaneous planning separates order submission from joint execution. These are worthwhile fifth and sixth garden profiles. [S09: PlayStation's Square Enix presentation coverage, 2019-06-11](https://blog.playstation.com/archive/2019/06/11/square-enix-dives-deep-into-final-fantasy-vii-remake-gameplay/), [S10: Mode 7's Frozen Synapse store description, released 2011-05-26](https://store.steampowered.com/app/98200/Frozen_Synapse/).
6. **Party AI needs an authorable policy, not just an attack loop.** Dragon Age: Origins distinguishes general behavior from ordered condition/action tactics. That is a good precedent for companion defaults that yield to explicit player orders. [S08: EA PC manual, 2009, Tactics and Items sections](https://eaassets-a.akamaihd.net/eahelp/manuals/dragon-age-origins-manuals_PC.pdf).
7. **Combat mode switching affects balance and continuity.** Obsidian released turn-based combat for the original Pillars of Eternity in April 2026, and later documented a warning when changing modes during an encounter. This is evidence that mode-switch boundaries deserve explicit UX. It does not prove arbitrary rulesets or equipment can be converted safely. [S11: release announcement, 2026-04-06](https://www.obsidian.net/news/eternity/turn-based-mode-has-fully-come-to-pillars-of-eternity), [S12: official patch 3.9.5.0](https://www.obsidian.net/news/obsidian/poe-3950).
8. **An ability's origin, ownership, execution, and effects should be independent.** Epic's Gameplay Ability System documents ownership and ability lifecycles. Lyra separately models carried inventory and equipped representations that grant abilities. These are architectural precedents; Oathshaper will implement its own Rust contracts. [S13: GAS overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/understanding-the-unreal-engine-gameplay-ability-system), [S14: Lyra inventory/equipment](https://dev.epicgames.com/documentation/en-us/unreal-engine/lyra-inventory-and-equipment-in-unreal-engine).
9. **A deterministic rules core does not make Godot physics deterministic.** Godot explicitly warns against that assumption. Replay guarantees must state whether recorded spatial observations are inputs, or whether movement and hit tests also run in a deterministic simulator. [S15: Godot physics introduction, current documentation](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html).

## Detailed analysis

### What each reference contributes

The following are **Oathshaper design implications**, not attempts to reproduce proprietary games exactly.

| Reference | Preserve the useful experience | Design implication | Avoid assuming |
| --- | --- | --- | --- |
| KOTOR family | Watch the party act, pause, redirect, inspect upcoming actions | Actor queues, explicit cancellation, auto-pause triggers, controllable companions | An empty queue means victory; AI may silently replace player orders |
| Jade Empire | Responsive close combat, quick style changes, a helpful follower | Direct locomotion, targeting, combo windows, Attack/Support follower policy | Every companion needs full tactical micromanagement |
| Mass Effect 2 | Aim and fire while commanding specialist companions | Reticle targeting, cover, reloads, layered defenses, squad power selection | Tech is merely a spell renamed; a shooter is only a camera change |
| BG3 presentation + Paizo rules | Clear turn order, action previews, spatial tactics | Initiative, movement budgets, reactions, outcome explanation, tactical camera | D&D and PF/SF share an interchangeable action economy |
| FFVII Remake/Rebirth family | Basic action builds opportunities for deliberate commands | Gauge scheduler, slow-time planning, actor switching | Slow time and pause are the same clock state |
| Frozen Synapse | Plan the squad's next interval, then observe consequences | Commit plans, resolve both teams together, present uncertain predictions | The opponent may react to unrevealed orders after commit |

Square Enix's Rebirth battle page explicitly describes normal attacks filling ATB used by abilities and spells. It is a useful current publisher corroboration of the hybrid family, not a source for exact Remake balancing. [S18: Square Enix battle overview, undated](https://www.square-enix.com/ffvii/en-us/games/rebirth/battle/).

Other genres fit within these axes: an isometric loot/action RPG changes controls, targeting, inventory emphasis, and encounter scale; an MMO-like tab-target game changes cooldowns, casts, threat, and networking; a stamina/parry game changes execution and interruption windows. They do not require three more garden modes now. Online authority, large raids, and fighting-game precision are separate future projects. A first-person dungeon crawler uses another camera/control adapter; it must not silently inherit third-person aiming assumptions.

### Inventory, powers, and archetypes

**Proposal:** model an item definition separately from a particular owned item, its equipped bindings, its world representation, and abilities granted while equipped. Keep persistent ammunition and durability on the item instance, so putting a gun away does not refill it. Represent a learned spell, trained style, implant power, and weapon maneuver as different *sources of an ability*, with separate acquisition and preparation rules.

Give an ability independent fields for origin, delivery, resource costs, target constraints, timing, effects, and presentation cues. An EMP may counter a technological shield without countering a spiritual ward. A weapon can deliver either effect. Typed tags help select rules; tags alone should not become an unbounded scripting language.

Archetype is another independent definition: progression, training, resource model, and available grants. Party role is a loadout/behavior intention such as protector, skirmisher, marksman, controller, or support. A character can occupy different roles in different profiles without replacing their story identity.

Include noncombat skills, tools, consumables, ammunition, wearable gear, mods, quest objects, currency, encumbrance policy, and trade/loot transactions in the model. Crafting, durability, and procedural loot need extension points now; full crafting economies and hundreds of items do not belong in the first combat slice.

### Party autonomy and relationships

Keep **roster membership**, **deployment**, **current controller**, **formation**, **AI behavior**, and **relationships** separate. A recruited companion can remain off-field. A support-mode follower needs defined presence and vulnerability rules. Summons need owners and lifetimes; they are not automatically permanent companions.

Ordered companion tactics should include health/resource thresholds, allowed consumables, preferred range, focus target, and retreat/hold position. Explicit orders outrank autonomous tactics until completed or explicitly invalidated. Show why an order failed. Prevent automated consumable use from silently exhausting the party's rare items.

Morality should be author-configurable: a bipolar axis, multiple independent values, or no moral classification. The Mass Effect manual exposes Paragon and Renegade meters; collapsing every game's ethics into one scalar would unnecessarily constrain authors. Keep companion affinity and faction reputation distinct. Oathshaper currently has Mercy `-5..+5` and Ivo affinity, so the first sheet should preserve those semantics and place Mercy immediately below the player portrait. Multiple axes require a versioned narrative migration, not a UI-only change. [S03](https://eaassets-a.akamaihd.net/eahelp/manuals/mass-effect-2-manuals_PC_en_GB.pdf).

### Action clocks, consequences, and determinism

**Proposal:** use integer simulation ticks, stable IDs, explicit random-stream versions, and a totally ordered command/event log. Different schedulers decide when the same kinds of action contracts may advance. Turn durations, action cooldowns, and narrative deadlines must be typed; never interpret every duration as a floating-point number of seconds.

Rules determine affordability, legal targets, hit resolution, effects, and interruption. Godot owns animation, audio, UI, input and physical presentation. Action clips need authored contact windows, but a missed animation callback must not remove or duplicate damage. A recorded action ID and hit index identify each permitted impact.

For the first action modes, record Godot's authoritative position/visibility/contact observations as part of the command stream. Rust can then replay **those accepted observations and commands** deterministically. Input-only replay across platforms is a stronger promise reserved for a later deterministic spatial simulator. Tactical grid simulation can meet that stronger promise earlier.

Godot's 4.3 NavigationAgent documentation also separates navigation helpers from actual actor movement. Garden pathfinding, collision, cover, and aim obstruction must be authored and tested as separate concerns. [S16: pinned-version navigation documentation](https://docs.godotengine.org/en/4.3/tutorials/navigation/navigation_using_navigationagents.html).

### Interface, accessibility, and mode switching

**Proposal:** the main menu selects a curated **combat profile**, combining timing, rules, control, equipment/ability configuration, and interface layout. A separate optional visual theme only changes presentation. Preview party size, controls, and equipment before applying a profile.

Profile-aware pages must change their useful information: a style deck/amulet view for martial action, weapons/mods/shields for a shooter, action costs and spell preparation for tactical play. Journal, relationships, map, save/load, and accessibility retain familiar locations. Shared input actions and view models keep this consistent without one enormous conditional UI script.

At 1280×800, use 18–22 px body text, clear focus, readable resource labels, and controls that work without hover. The Steamworks review guidance calls for controller support and legibility; our chosen text sizes are project targets, not a claim of Deck verification. [S17: Steamworks compatibility review](https://partner.steamgames.com/doc/steamhardware/compat).

## Repository evidence and reuse assessment

Inspected live on 2026-10-21. Oathshaper baseline `05aa7b6`; reference prototype `778159cee98bb07a3e7dd70e8f01b9190a18bbaf`, clean working tree, read-only. No source, rules text, or assets copied from reference prototype for this research.

| Local surface | Actual evidence | Consequence |
| --- | --- | --- |
| `crates/oathshaper-core/src/lib.rs` | Strict story validation, atomic choice effects, single moral value, affinity, versioned saves, `choose_with_events` | Preserve narrative authority; add a typed combat outcome boundary |
| `godot/scripts/journal_menu.gd` | Character text, placeholder equipment slots, records inventory derived from a story flag | Build real inventory/party models before claiming functional equipment |
| `godot/scripts/character_model_slot.gd` and `docs/rigging.md` | Rigged derivatives with Idle/Walk/Talk | Need attack, defense, aim, reload, hit, downed and transition clips |
| `godot/scripts/hub_environment.gd`, `docs/hub-map.md` | Actual imported garden, bridge, simple floor/bed/rail collision | Add navigable and combat-semantic geometry to this mesh layout |
| reference prototype `rules/core/combat_input.gd` | Semantic selection/targeting state emits intents without executing them | Adapt the command boundary; add complete execution-time legality checks |
| reference prototype `rules/core/attack_preview.gd` | Computes degree bands and reach; tests assert no HP/action mutation | Adapt pure previews and transparent outcome explanations |
| reference prototype `rules/core/{combat,initiative,turn_state,conditions,equipment,spellcasting}.gd` | Substantial GDScript tactical rules, PF-specific content and conventions | Candidate algorithms for a separately reviewed Rust rules module |
| reference prototype `rules/tests/test_attack_preview.gd`, `rules/tests/simulations/test_sim_combat_input.gd` | Nonmutation checks and seeded randomized command exercises | Adapt invariant and simulation test strategies |

The existing [reuse audit](../reuse-audit.md) remains applicable. The reference's Godot RNG is not a specified cross-language replay algorithm. Its equipment dictionaries are not a generic persistent inventory. Its tactical implementation is useful prior work, not a complete production combat framework or a Rust crate. These tests were **read, not executed**, during this research.

## Sources and evidence

All links were researched on **2026-10-21**. Eighteen substantive primary/reference sources are cited above. Manuals describe their editions; dated previews are historical design evidence, not claims about every current patch. Source IDs below resolve to the inline links in this report.

| ID | Source / date | Evidence used |
| --- | --- | --- |
| S01 | LucasArts KOTOR II PC manual, 2004/2005 | Queues, pause, party command model |
| S02 | Jade Empire Special Edition PC manual, 2007 | Style families, follower modes, tactical assistance |
| S03 | EA Mass Effect 2 PC manual, 2010 | Squad commands, defenses, resources, morality UI |
| S04 | Larian BG3 About, undated | D&D rules basis |
| S05 | Larian combat/stealth article, 2020-08-07 | Historical initiative presentation |
| S06 | Archives of Nethys reproduction of Player Core, 2023 sourcebook | PF2 encounter action economy |
| S07 | Paizo Starfinder overview, current undated page | SF2/PF2 compatibility statement |
| S08 | EA Dragon Age: Origins manual, 2009 | Tactics versus behavior, party inventory |
| S09 | PlayStation coverage of Square Enix's presentation, 2019-06-11 | ATB/tactical slow-time concept |
| S10 | Mode 7 Steam publisher page, 2011 release | Simultaneous planned squad turns |
| S11 | Obsidian announcement, 2026-04-06 | Original Pillars turn-based release |
| S12 | Obsidian patch 3.9.5.0, 2026 | Mode-switch warning during encounters |
| S13 | Epic GAS overview, current documentation | Ownership and ability lifecycle |
| S14 | Epic Lyra inventory/equipment, current documentation | Definitions, instances, equipment grants |
| S15 | Godot physics introduction, current documentation | Physics determinism limitation |
| S16 | Godot 4.3 NavigationAgents, versioned documentation | Navigation/movement boundary |
| S17 | Valve Steamworks compatibility review, current documentation | Controller and readability acceptance |
| S18 | Square Enix Rebirth battle overview, undated | Action-generated ATB and command spending |

## Research gaps and limitations

- **KOTOR I exact queue/autopause edge cases:** three hosted manual URLs failed retrieval. KOTOR II supplies verified family evidence; instrumented original-game testing would be needed for exact fidelity. No invented queue length or timing is treated as canonical.
- **No hands-on reference-game comparison in this pass.** Manuals establish mechanics, not animation quality, latency, or camera feel. Those require recorded play sessions and Oathshaper controller testing.
- **Rules/content rights remain unresolved.** [Paizo's license entry point](https://paizo.com/licenses) was found, but a later direct fetch returned 403. Before distributing a PF/SF module, inspect the exact sourcebooks, current license text, required attribution, and the reference project's code provenance. This report does not grant clearance or relicense reference prototype. User-supplied Meshy assets retain their existing unverified redistribution status.
- **Edition precision:** the tactical pack must pin PF remaster/SF2 final rules and errata. A 2024 playtest is not a final SF2 specification. BG3 mechanics are not the default implementation contract.
- **Engine age:** the official 4.3 documentation now labels that release unsupported. Current project pins are Godot 4.3 and godot-rust 0.2.4 (`api-4-3`). Evaluate an engine upgrade in a separate compatibility task before broader release; do not bundle a silent upgrade into combat work.
- **Performance and feel:** the garden derivative remains approximately 900k triangles. More actors, effects and shadows require target-device measurement. Neither this report nor the browser mockup proves Linux gameplay, physical Deck performance, or controller feel.

## Search methodology

Deep pass: 14 web tool calls, using batched searches, official manual reads, targeted finds, and follow-up verification. Broad searches located the four requested reference families; targeted queries covered party AI, inventory/equipment separation, additional timing models, current mode-switch precedent, deterministic boundaries, and platform requirements. Repository inspection supplied implementation-specific evidence.

Representative queries: `KOTOR manual combat action queue autopause`; `Jade Empire Special Edition manual followers support`; `Mass Effect 2 manual squad powers shields`; `BG3 official combat initiative`; `Pathfinder 2e encounters three actions`; `Starfinder second edition compatibility`; `Dragon Age Origins manual tactics`; `Lyra inventory equipment differences`; `Gameplay Ability System ownership effects`; `Final Fantasy VII Remake ATB Tactical Mode`; `Frozen Synapse simultaneous turns`; `Pillars Eternity turn based switch 2026`; `Godot physics deterministic`; `Godot 4.3 NavigationAgents`; `Steam Deck compatibility text controller`; `Paizo ORC license`.

Forums, wikis, and news results helped locate leads but do not establish the technical contracts here. Search-result crawl dates were not treated as publication dates. Unsupported details and inaccessible sources are explicitly marked above. The proposed architecture and acceptance criteria are engineering recommendations derived from these sources and the inspected code, not claims about existing Oathshaper functionality.
