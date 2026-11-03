# Combat UX contracts: what makes each inspiration feel familiar

> Comparative research and independent design proposals. See the [Research and third-party rights notice](NOTICE.md); references do not imply affiliation or permission to reuse source-game assets.

Research date: 2026-10-22. Depth: deep. Companion report: [archetypes, equipment and inventory](007-archetypes-equipment-inventory.md). Builds and numerical examples below are **Oathshaper designs**, not extracted game data. A contract describes required behavior; it is not an implementation claim.

## Research summary

The nine profiles require different control and information structures. A common character sheet is useful, but a common combat HUD, identical party control, or one universal action resource would erase the distinctions the player is choosing. Equipment, progression and party identity must drive both the available actions and the way those actions are presented.

## 1. Evidence and edition boundaries

1. **KOTOR → Command.** The original Xbox manual documents party switching, pausing, queued commands, separate skills/feats/powers, a filtered party inventory, and equipment restrictions. Its mundane classes are Soldier, Scout and Scoundrel; later Jedi paths are Guardian, Sentinel and Consular. The three paths differ in advancement, not simply color. [Original manual, mirrored transcription](https://manuals.plus/m/9b6fd57baee9ecf727bee54f9b535606567d0f9b99f0ad43ce896ae4c203cedf). The [publisher-hosted KOTOR II manual](https://cdn.akamai.steamstatic.com/steam/apps/208580/manuals/KOTORII_Manual.pdf) corroborates the queue/party interface, but sequel-only progression must not be attributed to KOTOR I.
2. **Jade Empire → Flow.** Body, Spirit and Mind support Health, Chi and Focus. Magic, transformation and healing use Chi; weapons and Focus mode use Focus. Martial, magic, weapon, support and transformation styles have different purposes. Block, ordinary attack and power attack counter each other. The equipment emphasis is amulet/gems and learned styles. One follower can attack or support. [Special Edition PC manual, printed pp. 9–23](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453). Four directional style slots on the left are the requested Oathshaper controller design; the PC edition has additional keyboard quick slots.
3. **Mass Effect → Vanguard.** ME1 has three specialist disciplines and three pairwise hybrids: Soldier, Engineer, Adept, Infiltrator, Vanguard and Sentinel. It uses Shepard plus two ordered squadmates, weapon/power wheels, shields, weapon heat, equipment upgrades, omni-tools and bio-amps. Soldier is a weapon specialist, not a dedicated melee class. [ME1 Xbox manual, pp. 6, 14–21](https://eaassets-a.akamaihd.net/eahelp/manuals/mass-effect-manuals_Microsoft%20XBOX360_en_US.pdf). Thermal clips and later-game power behavior require a separate edition preset; see [ME2 PC manual](https://eaassets-a.akamaihd.net/eahelp/manuals/mass-effect-2-manuals_PC_en_GB.pdf). Do not quietly combine ME1 heat with ME2 reload costs or claim direct squad possession as original behavior.
4. **Dragon Age: Origins → Oathbound.** Three base classes develop specializations. Four-person party control, pause, a quickbar, weapon sets, stamina/mana, fatigue, sustained powers and ordered condition/action tactics interact. Tactics evaluate top-down; behavior governs broader positioning. Inventory capacity is expandable, not a weight simulation. [PC manual, pp. 8–17, 20–33](https://eaassets-a.akamaihd.net/eahelp/manuals/dragon-age-origins-manuals_PC.pdf). The console has party cycling, a radial and six shortcuts in two layers. [Xbox manual, pp. 4–6](https://eaassets-a.akamaihd.net/eahelp/manuals/dragon-age-origins-manuals_Microsoft%20XBOX360.pdf). Preserve both interaction models rather than shrinking a desktop bar onto the Deck.
5. **BG3 → Tactics interface.** Larian describes customizable controller radials, a system radial, cursor mode and tactical camera access. [Larian's controller design article, 2023-09-05](https://blog.playstation.com/2023/09/05/how-baldurs-gate-3-adapts-its-expansive-rpg-gameplay-for-your-dualsense-controller/). Its class system supports class levels, subclasses and multiclassing; the [official toolkit guide](https://docs.baldursgate3.game/Adding_Classes_and_Subclasses) separates those progressions and hotbar groups. [Patch 8](https://baldursgate3.game/news/the-final-patch-new-subclasses-photo-mode-and-cross-play_138) added subclasses; older articles' counts are historical. **BG3's rules are not Pathfinder's three-action rules.** Our initiative presentation can feel familiar while explicitly selecting a different rules adapter.
6. **FF7 Remake/Intergrade → Momentum.** Basic action builds ATB; commands spend it, and tactical selection slows combat. Direct control can switch while issuing ally commands remains possible. [Square Enix combat guide](https://blog.playstation.com/?p=223238). Weapon proficiency can permanently teach an ability; materia grants are equipment-dependent. Unique character actions persist alongside that flexible loadout. [Official weapon/ability preview](https://blog.playstation.com/?p=218885). INTERmission's Yuffie/Sonon coordination is distinct from freely switching between all base-game protagonists. [Square Enix INTERmission guide](https://blog.playstation.com/?p=350053). Rebirth's extra synergy systems are an extension, not the definition of Remake ATB.
7. **Chrono Trigger → Confluence.** The official description emphasizes time-based readiness, moving enemy positions and two/three-character techniques. [Square Enix product page](https://gb.store.square-enix-games.com/chrono-trigger---digital). Our design combines readiness with spatial targeting and participant requirements. Exact original frame timing and all character-specific exceptions were not verified here.
8. **FFVI → Cadence.** The Advance manual documents speed-based readiness, Active/Wait, ready-character switching, formation rows, distinct character commands, equipment eligibility, relics and magicite learning. Wait applies to particular selection menus, not every moment a character is ready. [Nintendo-hosted official manual, printed pp. 22–42](https://csassets.nintendo.com/noaext/image/private/t_KA_PDF/AGB_Final_Fantasy_VI?_a=BATCtdAA0). Advance is the evidence baseline; Pixel Remaster timing and command conveniences require separate verification.
9. **Frozen Synapse → Orders.** Simultaneous planning and detailed squad orders are the reference. [Developer's Steam description](https://store.steampowered.com/app/98200/Frozen_Synapse/). The proposed Oathshaper three-second plan, class roster and inventory are authored extensions.

## 2. Required profile behavior

Everything in this section is a proposed Oathshaper contract. Acceptance must exercise it with real enemies and real costs before calling a profile playable.

### Command: party portraits, action bar and visible queues

- Left: deployed portraits with health, conditions and selected actor. Bottom: that actor's bindable attack/power/item bar. Above it: current action plus queued orders, with target portraits. Pause state must be unmistakable.
- Keyboard: number shortcuts and portrait selection; controller: party cycling and a category selector. An action belongs to the selected actor, even while the camera follows another actor. Keep command selection distinct from camera following.
- Pause on first hostile contact is configurable. Manual pause permits editing each actor's queue. Empty-queue policy is explicit: autoattack, assist, hold, or pause. Do not stop all combat whenever one actor runs out of queued powers.
- Reorder/remove future commands, clear a queue, inspect costs, and distinguish an executing action from a reserved future action. Invalidated targets produce an explanation and follow a defined fallback.
- Queueing an item must not duplicate it. Resource reservation prevents three queued casts from all spending the same remaining resource. A canceled future command releases its reservation.
- First garden lesson: pause, queue a control power on Mara, switch to the Corsair, queue a follow-up, resume, then cancel a third order. Every portrait and queue must keep its own state.

### Flow: a style diamond and three resource bars

- Left: four directional style slots, active style enlarged, its resource icon visible. Top-left: Health, Chi, Focus with labels as well as colors. A follower strip exposes Attack/Support and the current support effect.
- Ordinary attack, power attack, block, evade, heal and Focus mode need direct bindings. Style switching must not bury guard/heal behind a menu. Keyboard and controller layouts may differ while preserving those verbs.
- Chi enhancement and Focus mode require an unmistakable on/off state and drain feedback. Healing competes with magic for Chi; weapons compete with time manipulation for Focus. A low resource should change the player's decision, not merely tint an icon.
- Styles can train across the four showcased builds. The build names mean initial investment, not permanent class restrictions. Give Support and Transformation their own browser categories rather than losing them under “magic.”
- Show immunity, setup status, remaining combo window and a valid finisher. Give an ordinary attack option when a resource is exhausted. Follower support is not a second fully possessed player character.
- First lesson: block, break a guard, apply a support setup, switch to a martial finisher, heal, then observe why weapon use drains Focus.

### Vanguard: aim, cover and squad commands

- Center: aim reticle and target defense layers. Lower right: heat **or** ammunition/reload, selected weapon and consumables. Lower left: health/shields and two squad portraits. Power overlay shows ownership and cooldown per power.
- Keep player movement, aiming, cover transitions and weapon handling responsive. Commanding Ivo's biotic action must not silently transfer control to him. Companion commands select actor, power and target.
- The default proposed preset is **ME1-inspired heat + individual power cooldowns**. A later preset may use clips and different cooldown rules. Both need separate tutorials, resource displays and balance tests.
- “Vanguard” is Oathshaper's profile name; its combat/biotic archetype is called **Stormbreaker** to avoid a profile/class ambiguity.
- The requested close-range combat actor is a Breacher adaptation. It carries a firearm and has a melee response; do not describe it as ME1's canonical melee class. Engineer, biotic specialist and all three hybrids require distinct capability definitions.
- Draw/fire leaves a weapon readied. Cancel first exits targeting/radials; sheathing is available in ordinary play. A shared global B binding must not steal a profile's combat action.
- First lesson: use tech against a shielded target, a biotic against a valid target, then finish with the Breacher. Reveal blocked powers and their reason before charging a cooldown.

### Oathbound: direct orders plus explainable companion tactics

- Four portraits, per-character health and stamina/mana, pause, hold/follow, selectable units, weapon-set swap and a populated quickbar. On controller use a radial and two shortcut layers.
- The tactics editor needs ordered rows: subject → condition → action → target. Include enable/disable, move row, presets, editable thresholds and a live “why this row did/did not fire” view.
- Separate “keep distance/hold position” behavior from “ally health below 35% → heal.” Explicit commands take priority; the AI resumes only at the documented boundary.
- Show reserved resource from sustained powers, remaining usable resource, armor fatigue and actual adjusted cost. A strong armor upgrade may be a poor caster upgrade. Explain both consequences together.
- Telegraph spell areas, friendly-fire policy, flanking/backstab opportunities, threats, buffs and dispels. Friendly fire is encounter/difficulty policy, not an undocumented engine constant.
- First lesson: hold the defender at a choke, manually place the caster's area, let the healer's top-priority rule fire, then inspect its reasoning. Disable the rule and confirm the behavior changes.

### Tactics: initiative is not merely a row of portraits

- Top: initiative with current actor, upcoming turns, defeated actors and reaction interruptions. Left: party selection/grouping. Bottom: selected actor's action resources, movement, ability groups and End Turn.
- Selection for inspection does not grant a turn. Eligible shared turns, if supported by an adapter, are explicit. The PF2-inspired adapter initially uses individual initiative.
- Show path cost, hazards, range, line of sight, affected targets, hit/save reasoning and required hands. Permit preview/cancel without committing movement or spending an action.
- **PF2 adapter:** three actions plus reaction, multiple-attack penalty, typed degrees of success, focus/spell resources and Bulk. **Possible D&D-like adapter:** action/bonus/reaction plus movement and different spell rules. Never render three identical dots over D&D action costs.
- Reaction prompts show trigger, actor, effect and remaining reaction. Add automatic/ask/never preferences per reaction. A prompt owns input; End Turn must not dismiss it accidentally.
- First lesson: select Ivo while Corsair acts, inspect his sheet without moving initiative, Stride/Strike/Raise Shield, then accept or decline a reaction. The combat log must reconcile every cost and roll.

### Momentum: action that earns decisions

- Three party strips show health, MP and two ATB segments. Target UI shows pressure and stagger separately. A character-specific action has a direct binding and visible state.
- Direct attacks, guard and dodge remain available without ATB. Tactical mode slows simulation while allowing party-wide orders. An ally can receive an order without transferring direct control.
- Every menu command exposes ATB, MP, charges and target requirements together. Spending an item also has a command cost; its item count is a separate resource.
- Sockets, linked sockets, weapon proficiency and unique character actions are separate systems. Flexible shared spells must not erase different normal attacks, ranges and signature mechanics.
- Optional automatic basic-action assistance is a distinct accessibility policy. It does not turn this into Cadence.
- First lesson: build ATB, command Mara, switch to Ivo, increase stagger, spend a two-segment finisher. Unequip a spell socket and verify the spell disappears; a mastered weapon art remains.

### Confluence: readiness plus relationships between techniques

- Three readiness bars, HP/MP, Attack/Tech/Item, and a link browser grouped by participants. Enemy movement and line/radius previews matter.
- A ready actor can act alone or wait for a partner. Show the missing participant, missing technique, readiness and individual cost for every unavailable link.
- Linked commands reserve all participants atomically. A player cannot spend Mara's gauge elsewhere after committing a two-person technique. An incapacitated participant follows a documented cancel/refund policy.
- Use on-field encounter framing; do not force real-time dodging or free WASD locomotion into a menu-based readiness system. Keyboard/controller can still move a target cursor.
- First lesson: hold one gauge, wait for another, align a line attack, commit a dual technique, then test a three-person technique and an unavailable participant.

### Cadence: character-specific commands inside classic ATB

- Four stable rows: portrait/name, HP/MP, status, ATB. A ready actor opens Attack / signature command / Magic / Item. Highlight which actor owns the command menu.
- Active continues during command selection. Wait follows an explicit submenu policy; show a small clock-stopped indicator. Full pause remains distinct. Changing the preference must not reset gauges.
- Ready-character switching preserves readiness. Target ally/enemy/all toggles are discoverable. Row changes and defend remain reachable on both input devices.
- A machinist selects a tool; a pugilist enters or selects a technique; an arcanist selects magic. Accessibility can replace timed input with a list without replacing the character's role.
- Relics that alter a command update the menu; learned spells survive removal of their teaching focus. Summon availability and spell acquisition progress are separate.
- First lesson: compare Active and Wait while another gauge fills, switch ready actors, use two different signature command interfaces, and show front/back-row effects.

### Orders: complete plans and honest uncertainty

- Timeline per actor, world paths, facing/aim cones, action durations and a single team Commit. Inspect all plans without changing their owner.
- Preview is labeled as a forecast and uses only known enemy information. Mark branches that depend on uncertain enemy movement. Never present an enemy's hidden order as known.
- Before commitment, edit/remove segments or undo. After commitment, both sides resolve under the same locked-plan policy. Watch/replay controls do not alter simulation.
- First lesson: move an observer, lay smoke, synchronize a crossing, commit, then compare forecast and actual result. Include a broken line-of-sight case.

## 3. Shared interaction rules

| Concern | Contract |
| --- | --- |
| Input ownership | Menu → target selection → reaction/dialogue → world; one consumer per event. B/Esc unwinds one layer. |
| Hotbar binding | Bind actor + ability source + variant. Never point only at a display index that changes when gear changes. |
| Party switching | Preserve each actor's target, queue, resource state and bar. Restore appropriate camera without a sudden 180-degree flip. |
| Unavailable action | Keep a trained action inspectable with a specific reason: wrong weapon, cooldown, no charge, range, silence, no participant. Hide obsolete narrative choices separately. |
| Accessibility | Rebindable inputs, input-device glyphs, hold/toggle alternatives, shape/text alongside color, readable 1280×800 layout. Full pause is available independently of a style's battle clock. |
| Equipment preview | Show before/after stats and actions gained/lost. Applying a change must be atomic and respect current battle rules. |
| Narrative | Morality belongs near the player avatar; companion opinion belongs to the companion. Never invent an NPC morality score from affinity. |
| Save/load | Persist actor selection, bindings, loadouts, learned skills and profile-specific progression. Encounter saves additionally require clock, queues, reservations, statuses and RNG. |
| Style change | At a safe boundary, retain narrative identity and each style's own build. Do not translate a mana pool into ammo or discard out-of-profile equipment. |

## 4. Release gates and present gaps

The current code has a title/picker, profile persistence, a Ledger, narrative gameplay, and practice weapon poses. **There is no implemented enemy combat scheduler, damage resolution, tactical AI, ATB simulation, working inventory transaction system or party possession.** Actor-specific preview data improves inspection but does not satisfy the contracts above.

Before showing “playable” for a profile, require: complete controller-only garden lesson; complete keyboard lesson; one deliberate invalid action with correct explanation; one equipment change that changes an action; companion differentiation; defeat/recovery; pause/menu clock correctness; save/load continuation; and a visual check at 1280×800. Use semantic assertions as well as screenshots. A green screenshot test cannot prove a functioning battle system.

Recommended implementation order: shared actor/item/ability contracts → Tactics adapter as the first verifiable action-accounting slice → Command + Oathbound queue and tactics → Flow direct action → Vanguard aiming/defenses → the three distinct ATB clocks → Orders planning. This retains the foundation plan's tactical-first implementation sequence while Command remains the default menu selection. Keep profiles individually labeled as previews until their gates pass. The same garden should contain authored situations that expose each system, rather than one stationary dummy with nine HUDs.

## Research method, sources and limits

Deep research used original manuals, publisher-hosted documents, developer-authored PlayStation articles, Larian toolkit/patch notes and publisher product pages. Searches covered each game's class, inventory, party, quickbar/radial and battle-clock terms; manual sections were cross-read against console/PC editions. Sources were accessed 2026-10-22. The evidence register is the inline links above and the linked archetype report.

The KOTOR I publisher PDF was inaccessible; the mirrored original-manual transcription is lower confidence for exact button glyphs than a scanned page. Jade's original Xbox and Chrono's SNES manual scans exceeded web size limits and returned HTTP 403 when downloaded; they are **not** counted as verified sources. Therefore exact original controller mappings and Chrono timing exceptions remain verification tasks. No reference game was launched during this research. Numerical parity, animation cancel windows, AI priorities not documented in manuals, and physical Steam Deck comfort remain unverified. Reports distinguish those gaps from explicit Oathshaper choices.
