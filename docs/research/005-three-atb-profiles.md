# Three ATB profiles for Oathshaper

> Comparative research and independent design proposals. See the [Research and third-party rights notice](NOTICE.md); references do not imply affiliation or permission to reuse source-game assets.

2026-10-22 · Focused research and design · Four primary sources

## Summary and implementation boundary

Keep **Momentum** for action-driven ATB, add **Confluence** for live, on-field readiness and linked party techniques, and add **Cadence** for classic menu ATB. Share gauge accounting, costs, statuses and party state, while keeping clocks, control modes and command commitment rules explicit.

All three now appear in the Godot style picker and Ledger with original starter equipment and ability previews. The existing draw/strike/sheathe presentation works for them. **ATB gauges, enemy damage, tactical slow motion, linked attacks and Active/Wait behavior are design work below, not working combat systems.**

## 1. Prior art

### Final Fantasy VII Remake / Intergrade lineage

Square Enix's [Remake combat guide](https://blog.playstation.com/?p=223238) describes two ATB bars, spending a filled bar on an ability/spell/item, faster gain through standard attacks, character switching and enemy stagger. The later [Rebirth battle guide](https://www.square-enix.com/ffvii/en-us/games/rebirth/battle/) explicitly describes tactical-menu slowdown, passive and attack-driven gain, and spell costs combining ATB and MP. Its distinct synergy systems should not be conflated with ordinary ATB or claimed as base Remake behavior.

Momentum borrows the action/command rhythm. Numerical rates and resource rules below are Oathshaper proposals, not a reproduction of Square's formulas. This review did not separately verify every INTERmission mechanic.

### Chrono Trigger

Square Enix's [official product description](https://gb.store.square-enix-games.com/chrono-trigger---digital) identifies ATB Version 2: commands become available with a full gauge while enemies change position, and two/three characters combine techniques. Confluence emphasizes readiness, target geometry and coordinated participation. The proposed encounter remains in its exploration setting with actors moving into combat positions; direct action dodging is not required for this profile.

### Final Fantasy VI

The [official Advance manual, printed pp. 30–34](https://csassets.nintendo.com/noaext/image/private/t_KA_PDF/AGB_Final_Fantasy_VI?_a=BATCtdAA0) documents speed-dependent gauge fill, commands at full readiness, Active timing, and Wait pausing during ability/item/magic submenus. It also describes switching among ready characters, character-specific commands and front/back rows. Cadence uses these distinctions instead of treating Wait as initiative combat. The source is the Advance manual; port-specific timing quirks are outside this design.

## 2. Proposed profiles

| Policy | Momentum | Confluence | Cadence |
| --- | --- | --- | --- |
| Party target | Player + two allies | Player + two allies | Player + three allies |
| Gauge | Two spendable segments per actor | One full readiness gauge per actor | One full readiness gauge per actor |
| Gain | Validated action events + slow passive gain | Speed-based time | Speed-based time |
| Player control | Move, attack, guard, evade; switch actor | Select actor/technique/target in the live field | Select a ready actor's command from formation view |
| Command browsing | Tactical slowdown; proposed default 1/10 simulation rate | Active by default; optional Wait accessibility policy | Active or Wait, with explicit submenu pauses |
| Spending | One/two segments; additional mana or consumable cost | One actor's gauge, or all participants' gauges for a link | Full gauge plus command-specific costs |
| Distinct mechanic | Stagger, sockets, coordinated command timing | Dual/triple arts and line/radius targeting | Role commands, learned magic, relics, front/back rows |

**Momentum:** RT performs basic actions; successful actions build gauge. The command overlay shows every companion's charges and allows orders without transferring direct control. A spell spends ATB and mana together. Basic attacks, guard and movement remain available while charging. No ATB for swinging harmlessly at empty water. Damage received, successful guard and other gain events are configurable rules. Failed target validation spends nothing; after action start, authored interruption/refund rules apply.

**Confluence:** a ready ally can act alone or hold readiness for a link. `Crosscurrent` pairs the Corsair's sweep with Mara's gale; `Harbor concord` combines all three. Show every participant's readiness, cost and affected area. Reserve all participants/resources atomically. Proposed spatial policy: validate the area and target at commitment, resolve against authoritative positions at the authored impact tick. A preview forecasts a hit against moving foes. Mark unavailable participants and preserve solo actions.

**Cadence:** show four roster rows with HP, mana and readiness. A full gauge unlocks Attack, the actor's Art, Magic and Item. Switching to another ready actor preserves readiness. Active keeps the clock running while browsing. Wait freezes it only for configured ability/item/spell selection states, including their target selection in our proposal; the top-level command list still runs. A separate pause menu always pauses. Rows, equipment-granted commands and learned magic remain independent modules.

### Equipment and menus

- **Momentum / Commands & sockets:** resonant sabre, gale/guard shards, corsair coat, tempo ring and recovery supplies. Sockets grant abilities through the shared ability-source contract.
- **Confluence / Techniques & links:** tidecut sabre, wayfarer vest, confluence knot, Gale arc, Crosscurrent and dew tonics. The eventual link browser shows actors and prerequisites. Affinity may unlock authored links; no universal morality gate is imposed.
- **Cadence / Commands & relics:** runed cutlass, harbor shield, warden coat, echo sigil, Tide drill and restoratives. Distinguish learned spells from commands granted by roles or equipped relics.

These are original placeholder names and definitions. No Final Fantasy or Chrono Trigger characters, art, spell lists or data were copied. Current gear rows are previews, not inventory transactions.

## 3. Framework boundary

Proposed Rust components:

- `BattleClock`: fixed integer simulation ticks and rational rate policy. Normal, tactical-slow and paused clocks apply equally to all actors. Menu transitions are explicit commands, never inferred from a rendered Control's visibility.
- `ReadinessPolicy`: capacity, gain source, speed/status modifiers, reset behavior and retention. Distinguish spendable segments from permission to issue a command.
- `CommandPolicy`: legality, participants, resources, targeting, cast/impact/recovery ticks, cancellation and interruption.
- `PartyOrderPolicy`: direct control, actor orders and optional condition-based companion tactics. Gambit-like automation is a reusable AI policy; it differs from Orders' simultaneous plan resolution.
- `AbilitySource`: learned, equipment, role, link or temporary effect. Keep action budget, mana, stamina, charges, ammunition, cooldowns and consumables distinct.

Use integer gauge units and accumulated remainders for fractional gain. Order simultaneous events by tick, authored priority, actor ID and command sequence. Revalidate legality at commitment. Link reservation succeeds for every participant/resource or changes nothing. Death or interruption follows the link's authored cancellation policy.

Godot owns camera, input, motion and UI. Rust owns gauges, legality, resources and outcomes. Animation completion is not the authoritative hit clock. Save the tick, rate/mode, gauges/remainders, pending actions, reservations, statuses, combat poses and RNG state. A loaded battle resumes the same policy. Change campaign styles outside encounters; repeatable garden trials restore the campaign checkpoint rather than converting active battles between schedulers.

## 4. Garden demonstration and acceptance

Use the same three-actor party and original opponents across ATB trials; add a fourth ally for Cadence. Hold layout, starting resources and objective stable.

1. **Momentum:** land basic strikes, fill a segment, open slow commands, order Mara's gale, switch to Ivo, and exploit a stagger window.
2. **Confluence:** hold the Corsair's gauge for Mara, preview a line through moving targets, commit Crosscurrent, and verify both costs. Repeat with three actors and an interrupted participant.
3. **Cadence:** compare slow/fast actors, switch ready actors, execute a unique Art, and show the clock stopping in Wait's Magic submenu but continuing at the top-level menu.

Future tests: deterministic replay at differing render rates; exact slowdown; no gain during pause; Active/Wait transitions; atomic link costs; ready-event tie ordering; target movement; insufficient resources; interruption/refunds; save/load during charging and committed actions; no duplicate narrative rewards from trials. Physical-controller acceptance must include actor switching, costs, targeting, cancellation and returning to exploration.

## Research method and limitations

Searched official Square Enix pages for Remake ATB/tactical mode, Chrono Trigger Version 2/links, and FFVI Active/Wait; read the four primary sources above. No binaries were inspected or numerical parity claimed. Some localized web articles returned empty shells, so the accessible Square-authored PlayStation guide and official manual were used. The runtime policies and acceptance sequence are proposals requiring implementation and playtesting.
