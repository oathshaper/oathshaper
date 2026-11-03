# Character archetypes, equipment and inventory: coverage and implementation contract

> Comparative research and independent design proposals. See the [Research and third-party rights notice](NOTICE.md); references do not imply affiliation or permission to reuse source-game assets.

Research date: 2026-10-22. Depth: deep. Read alongside [combat UX contracts](006-combat-ux-contracts.md) and [three ATB profiles](005-three-atb-profiles.md).

## Research summary

An archetype is a package of decisions: what the actor can do, what it costs, what enables it, how it develops, and what another party member does better. Oathshaper should separate a character's identity, a profile's progression rules, a loadout, a current combat role, and the UI used to control them. Four differentiated sample actors demonstrate that contract; they do not exhaust the source games' class systems.

## 1. Key findings

1. **“Hybrid” must name the disciplines being combined.** A combat/tech scout and a tech/biotic defender need different actions, defenses, equipment and progression. One universal hybrid makes the choice meaningless.
2. **A role is not always a class.** Jade-style training, FF7-style unique character mechanics plus sockets, Chrono-style personal techniques, and FFVI-style signature commands are distinct models. A rigid Warrior/Mage/Rogue enum cannot represent them faithfully.
3. **Inventory layout is not inventory capacity.** A grid can be a visual index or an actual spatial packing puzzle. Weight, Bulk, number of stacks, per-item stack limits and equipment restrictions are independent policies.
4. **Identical menus can conceal different rules.** Learned, prepared, item-granted, socket-granted, stance-enabled and linked actions need provenance. Removing an item must affect only capabilities that depend on it.
5. **A credible build has a weakness and a development path.** Four renamed attacks, with the same costs and animations, do not create four archetypes.

## 2. Reference coverage and proposed archetypes

The reference facts below extend the evidence in report 006. All Oathshaper names, build selections, examples and proposed rules are original design decisions. They are not claims about implemented mechanics.

### Command — class progression, skills, feats and powers

The source distinguishes three starting classes and three later Jedi paths, with separate skill/feat/power advancement. Some powers prohibit armor; armor compatibility must be visible in the action UI. [Original KOTOR manual](https://manuals.plus/m/9b6fd57baee9ecf727bee54f9b535606567d0f9b99f0ad43ce896ae4c203cedf).

Proposed coverage: weapon specialist; skill-heavy infiltrator; adaptable scout; melee mystic; power specialist; balanced investigator. Those are six development patterns, not six skins for the same stat array. A nonhuman or construct actor additionally needs an equipment-body policy rather than a humanoid armor assumption.

| Garden actor | Build and defining choice | Equipment/actions | Weakness and development |
| --- | --- | --- | --- |
| Corsair | Duelist; rapid single-target weapon orders | One-handed blade, offhand choice; lunge, riposte | Limited area control; advance weapon feats or broaden skills |
| Mara | Storm mystic; spend finite power to control a group | Casting-compatible coat and focus; gust, binding current, mend | Lower armor and power exhaustion; choose control versus recovery progression |
| Ivo | Bulwark; protect an ally while holding a lane | Shield, armor, defensive stance; interpose, suppress | Slow target changes; armor/weapon feats trade against broad skills |
| Clerk | Pathfinder; open opportunities with technical skills | Precision weapon, utility kit; expose weakness, disrupt device | Fragile under pressure; improve investigation and device access |

Required sheet sections: attributes; class levels/path; skill ranks and governing attribute; feats/prerequisites; powers with armor/alignment conditions; defenses; equipped slots; action queue. Morality influences only authored rules, never an assumed universal spell discount.

### Flow — investment across styles, not exclusive classes

The reference's primary abilities and learned styles support mixed investment. Style advancement and character advancement are separate. Its Charm, Intuition and Intimidation connect noncombat decisions to attributes. [Jade Empire manual, printed pp. 13–23](https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/7110/manuals/Jade%20Empire%20manual%20revised.pdf?t=1729270453).

| Garden actor | Initial emphasis | Distinct decision loop | Cost pressure |
| --- | --- | --- | --- |
| Corsair | Martial / Stone disciple | Read guard → interrupt → finish in reach | Must close distance; Chi-enhanced strikes compete with healing |
| Mara | Magic / Gale sage | Zone targets → switch element/control → recover Chi | Healing and attacks share Chi; needs a resource-free fallback |
| Ivo | Weapon / Blade dancer | Exploit reach → spend Focus → return to martial style | Weapon use and Focus mode compete for the same reserve |
| Clerk | Hybrid / Storm adept | Support setup → martial finisher → situational spell | Broader toolbox, shallower early specialization |

Every build can train other allowed styles. All retain Health/Chi/Focus, block, evade and heal. Include five style categories, style upgrades, four quick assignments, amulet sockets, gem conditions, follower Attack/Support effects, and separate conversation skills. Transformation requires its own form, resource drain and animation coverage; it cannot be represented honestly by recoloring a punch.

### Vanguard — six discipline combinations

ME1's three pure classes and three hybrids provide the coverage baseline; later series editions alter their signature moves and equipment rules. [ME1 manual](https://eaassets-a.akamaihd.net/eahelp/manuals/mass-effect-manuals_Microsoft%20XBOX360_en_US.pdf). The table is an Oathshaper adaptation; “Biotic” identifies the inspiration, while original fiction can rename its supernatural discipline.

| Coverage | Oathshaper archetype | Required capability difference | Garden representation |
| --- | --- | --- | --- |
| Combat / Soldier | Breacher | Broad firearm training, resilience, close-range melee response | Corsair |
| Tech / Engineer | Field engineer | Disable devices, strip shields, aid allies; omni-tool analogue | Mara |
| Biotic / Adept | Gravitic adept | Displacement, suspension, barrier manipulation; amplifier analogue | Ivo |
| Combat + tech / Infiltrator | Saboteur | Precision weapons and disruption; positioning over tanking | Additional build definition required |
| Combat + biotic / Vanguard | Stormbreaker | Close-range force and weapons; risk/reward approach | Additional build definition required |
| Tech + biotic / Sentinel | Storm sentinel | Layered protection/control with reduced weapon specialization | Clerk |

The showcase covers four of the six. The remaining two must have selectable build definitions before calling this class family complete. Do not invent a fourth base discipline called Hybrid. Do not give every actor the same carbine, emitter and four power names.

The sheet needs weapon training, armor eligibility, active defenses, per-power cooldowns, tech tool and biotic amplifier eligibility, weapon heat behavior, modules, and squad-order defaults. Equipment stats should expose tradeoffs such as heat capacity versus damage or barrier recovery versus maximum capacity. A melee-heavy adaptation needs explicit animations, collision, approach and survivability work; it is not achieved by renaming a shotgun.

### Oathbound — three classes plus specialization

Origins' base Warrior/Rogue/Mage classes lead to specializations. Warrior paths include Berserker, Champion, Templar and Reaver; Rogue includes Assassin, Bard, Duelist and Ranger; Mage includes Arcane Warrior, Blood Mage, Shapeshifter and Spirit Healer. [PC manual, printed pp. 16–17](https://eaassets-a.akamaihd.net/eahelp/manuals/dragon-age-origins-manuals_PC.pdf). The showcase's spell warrior is a mage specialization, not a fourth base class.

| Garden actor | Build | Required distinction |
| --- | --- | --- |
| Corsair | Warrior / Ashguard | Threat, shield control, stamina, heavy protection and fatigue |
| Mara | Mage / Cinder scholar | Mana, areas, control and friendly-fire preview; low physical durability |
| Ivo | Rogue / Shadow scout | Flanking, stealth, precision, utility skills; positional damage requirements |
| Clerk | Mage / Spellwarden | Sustained protection and martial specialization; reserved mana reduces casting freedom |

Coverage beyond the four examples: two-handed and dual-weapon warrior builds; archer/duelist/assassin/buffer/summoner rogue builds; healing, control, damaging, transformation and risky-resource mage builds. Each specialization changes at least one action, passive rule, AI tactic or equipment permission. Required progression is attributes → skills → talent/spell chains → specialization; show unmet prerequisites and the next attainable upgrade.

### Tactics — classes, subclasses and archetypes are adapter-specific

BG3's twelve classes provide a useful coverage checklist: Barbarian, Bard, Cleric, Druid, Fighter, Monk, Paladin, Ranger, Rogue, Sorcerer, Warlock and Wizard. Its [official Patch 8 announcement](https://baldursgate3.game/news/the-final-patch-new-subclasses-photo-mode-and-cross-play_138) and [class toolkit documentation](https://docs.baldursgate3.game/Adding_Classes_and_Subclasses) demonstrate subclass and level-progression distinctions. They do not make those classes interchangeable with PF2 classes.

For PF2, archetype dedication is a feat-based extension with prerequisites and restrictions, rather than ordinary class-level splitting. [Player Core dedication rules](https://2e.aonprd.com/Rules.aspx?ID=2128). Its encounter actions are a separate rule system. [Player Core playing the game](https://2e.aonprd.com/Rules.aspx?ID=2263).

Proposed first four builds: Corsair shield fighter; Mara prepared elementalist; Ivo skill-heavy skirmisher; Clerk divine warden. Coverage backlog must also include spontaneous and pact-like casting, martial discipline resources, rage, performance support, shapeshifting, pet/summon control, oath-dependent abilities, and ranged exploration specialists. These are capabilities to support, not a promise to ship twelve classes in the first garden slice.

The adapter owns ability scores, proficiency, armor rules, feats, spell preparation/repertoire, slot rank, focus resources, resting/recovery, reactions and multiclass rules. UI must show this adapter's terminology. A PF2 character's Bulk is not kilograms, and a D&D bonus action is not a spare PF2 action. Starfinder 2e requires its own audited class/equipment/technology pack; borrowing a sibling Godot implementation does not establish rules coverage.

### Momentum — unique actor mechanics plus flexible sockets

The reference separates character-specific actions from equippable materia and permanently learned weapon abilities. [Official FF7 Remake ability preview](https://blog.playstation.com/?p=218885). INTERmission also shows why a new character can change the combat grammar, rather than merely gain different numbers. [Square Enix's Yuffie guide](https://blog.playstation.com/?p=350053).

Proposed roster: Corsair changes between mobile and committed blade stances; Mara places a casting zone; Ivo builds a pressure-combo tier; Clerk uses a ranged charged shot and cover support. These have different attack animations, effective ranges, unique-action states and stagger contributions. Shared spell sockets remain transferable within compatibility rules. Thus two actors with the same healing socket still play differently.

Required sheet: unique action and its state, weapon proficiency progress, unlocked permanent arts, socket type/links, socket growth, armor/accessory effects, MP/ATB/limit-like resources, and independent summon availability. Keep Remake, INTERmission and Rebirth extensions separately labeled.

### Confluence — personal techniques and party combinations

The reference supports two/three-character techniques and changing battlefield positions. [Square Enix's Chrono Trigger description](https://gb.store.square-enix-games.com/chrono-trigger---digital). Exact original unlock tables are outside the verified evidence.

Proposed roster: Corsair blade sweeps and line attacks; Mara elemental zones and recovery; Ivo impact strikes and physical support; Clerk precision marks and protective techniques. Each actor has a personal technique progression. A separate graph derives available links from participants and learned prerequisites. A link is not a consumable item or a transferable personal spell.

The link browser must answer: who participates, which personal techniques unlock it, who is deployed/ready, which resources each spends, what geometry it uses, and what happens if a participant is disabled. Reserve actors remain inspectable but cannot contribute to an active link. Include a spoiler setting for undiscovered combinations.

### Cadence — command identity survives shared magic

The reference uses different character commands and control schemes, including Blitz, Bushido, Rage and Slot, alongside equipment and spell learning. [FFVI Advance manual, printed pp. 32–42](https://csassets.nintendo.com/noaext/image/private/t_KA_PDF/AGB_Final_Fantasy_VI?_a=BATCtdAA0).

Proposed roster: Corsair selects a committed blade art; Mara chooses magic and a temporary amplification state; Ivo uses an acquired tool collection; Clerk performs sequence-based martial arts. Later coverage: stealing, throwing expendable items, enemy-skill learning, command mimicry, summons and chance-based commands. These need different selectors and state, not just an “Art” label over identical damage calls.

Required sheet: signature-command instructions, learned magic/progress, current teaching focus, weapon/armor eligibility, two relic effects, formation row and status immunities. A relic can replace or transform a command. Persist learned spells independently of the teaching item, while temporary item grants disappear when removed. Show exceptions explicitly instead of assuming every actor learns every spell.

### Orders — operational roles from kit and plan constraints

The [Frozen Synapse developer description](https://store.steampowered.com/app/98200/Frozen_Synapse/) supports the simultaneous-planning reference. Oathshaper's RPG progression is an extension.

Proposed roster: Corsair assault lead; Mara observer/recon; Ivo combat engineer; Clerk medic. Range, setup time, sight, suppression, smoke, explosives, healing charges and carrying burden determine different plans. A medic's order can fail because the ally moved before treatment; the UI must forecast uncertainty and report the actual cause. No mana bar is needed to make the roles distinct.

## 3. Inventory and equipment policy

### Reference-informed defaults, proposed for Oathshaper

These defaults are design choices. Exact item caps and balance numbers require tuning; no arbitrary draft value should be presented as a source game's rule.

| Profile | Primary browser | Capacity model | Equipment structure and important comparison |
| --- | --- | --- | --- |
| Command | Shared categorized list; icon index optional | No weight penalty by default; per-item stacks | Humanoid/body-specific slots, proficiency, armor restrictions, upgrades; actions gained/lost |
| Flow | Styles library + amulet/gem collection | Collection eligibility and socket count | Learned styles are not bag objects; gems affect stats/conditions; training persists |
| Vanguard | Squad gear comparison and module lists | Item/stack capacity configurable; default no weight | Weapon families, armor, tech tool, amplifier, upgrades; heat, defenses, cooldown effects |
| Oathbound | Shared filtered list beside selected actor | Expandable stack-slot capacity | Armor pieces, accessories, two weapon sets, runes, fatigue and stat requirements |
| Tactics | Actor inventories with grid/list views | Adapter-specific weight or Bulk | Hands, held/worn/stowed access, proficiency, containers, battle action cost |
| Momentum | Weapon/armor socket editor + item list | Stack limits; no weight by default | Linked sockets, transferable grants, weapon mastery, accessory tradeoffs |
| Confluence | Item list + personal technique/link browser | Stack limits; no spatial packing by default | Character weapon eligibility, armor/charm; links live in progression, not bags |
| Cadence | Category list, equipment and relic screens | Stack limits; no weight by default | Character eligibility, command-changing relics, learned magic and teaching focus |
| Orders | Kit list + optional spatial bag grid | Optional load/space constraints | Load affects authored movement/setup; charges and ammo constrain the plan |

PF2 distinguishes held, worn and stowed items, and drawing/using them can require separate actions. [Carrying items](https://2e.aonprd.com/Rules.aspx?ID=2148). Bulk accounts for awkwardness as well as size/weight; it must not be treated as a cosmetic weight label. [Bulk](https://2e.aonprd.com/Rules.aspx?ID=2153).

### Inventory operations required for a real implementation

1. Stable item instance IDs, quantity, durability/charges, upgrades, provenance, container and owner. A definition describes an item type; an instance holds its mutable state.
2. Separate carried ownership, equipped binding, active weapon set, socket insertion and quick-use binding. Equipping cannot duplicate the item; unequipping cannot destroy it.
3. Compare against the **selected actor**, including required proficiency, body shape, slot compatibility, stat/level restrictions, two-handed occupancy and unique-equipped groups.
4. Preview aggregate changes: derived stats, available actions, effective costs, reserved resource, set bonuses, range, capacity, and penalties. “+4 damage” alone is insufficient.
5. Equip/unequip/swap/transfer/stack-split/consume/sell/drop as atomic transactions. Reject without partial mutation when a receiving container is full or an item is reserved by a command.
6. Capacity policies are composable: unlimited; distinct-stack slots; scalar mass with soft/hard thresholds; Bulk with its own rounding; optional spatial placement/rotation. Grid auto-sort is reversible and cannot lose items.
7. Search and filters: usable by selected actor, new, quest, consumable, material, equipment, rarity and source. Sort by name/type/value/weight and compare; include junk/favorite protection.
8. Quest objects are protected from destructive actions, survive profile changes, and remain readable. Do not copy a sample quest item into every actor's pack.
9. Containers require cycle prevention; transfer considers source/destination nesting, equipment and stack rules. A bag inside itself must be impossible.
10. Battle rules determine whether swapping, drinking, drawing and transferring cost time/actions or are disallowed. Menus cannot bypass the scheduler.

## 4. Ability and progression contract

Suggested data boundaries:

```text
ActorIdentity   narrative ID, portrait, relationships, body/rig capabilities
ProfileBuild    actor ID + profile ID + rules version + progression
Progression     class/path levels OR style ranks OR personal techniques
ItemDefinition slot families, requirements, grants, stack/capacity traits
ItemInstance   stable ID, definition, charges, upgrades, container, ownership
Equipment      slot bindings, active set, sockets, cosmetic overrides
AbilitySource  learned | class | style | item | socket | link | temporary
Ability        targeting, costs, cast/impact/recovery, effects, interruption
CombatState    current resources, cooldowns, reservations, statuses, queues
Presentation   hotbar/radial bindings, selector type, input hints, forecasts
```

These are planned interfaces, not existing Rust types.

Every action definition needs target kind, range/shape, line-of-sight policy, ally/enemy/self eligibility, resource costs, accuracy/save/resistance rules, effect duration/stacking, interrupt/cancel behavior and animation intent. “Magic” or “Tech” is a source/category tag, not a cost type. A spell can require mana and time; a device can require a charge and a free hand.

Availability is a structured result: `known`, `granted`, `prepared`, `equipped`, `legal_target`, `affordable`, `ready`, `blocked_reasons[]`. The UI derives explanation from that same result used to commit an action. Do not create one set of rules in tooltips and another in the scheduler.

Progression must define acquisition, investment, prerequisites, respec/refund, persistence and migration. Distinguish temporary access from mastery. A character can know an ability while unable to use it because of armor, silence, preparation or a missing partner. Unavailable abilities remain inspectable; undiscovered story unlocks can remain hidden.

Noncombat capability coverage: dialogue, investigation, locks/devices, traps, medicine, crafting/recipes, harvesting, traversal, stealth/perception and faction/relationship access. Mark unsupported systems instead of displaying impressive but inert skill ranks. Level-up should show an immediate usable benefit and the next meaningful choice.

## 5. Party, narrative and animation completeness

- A roster entry is not the same as a deployed combat actor. Track reserve/deployed/directly controlled/ordered/incapacitated separately. The civic clerk is a training guest, not automatically recruited into the story.
- Companion AI needs role behavior, resource conservation, danger avoidance and explicit-order precedence. Conditions must inspect the correct actor and use deterministic priority.
- Healing, recovery, revival and defeat policies must be profile-specific and visible. Pets/summons need ownership, command cost, duration, death and persistence rules.
- Keep narrative morality and companion affinity independent of combat class. A mage is not morally better than a fighter. Never assign a fabricated NPC morality number merely to fill the avatar panel.
- Each signature action needs an animation intent: weapon family/grip, stance, locomotion, attack/cast, impact, hit response and recovery. Equipment attachments must follow rig bones. Bow draw, shield brace, two-handed strike, ranged aim and transformation cannot share a generic punch pose indefinitely.
- Asset generation should start from one canonical mesh/rig with validated skeleton mapping; separate pose references do not guarantee matching topology. See [pose-guided animation research](004-pose-guided-character-animation.md). Approve animation silhouettes and feet/contact behavior before multiplying the content catalog.

## 6. Acceptance matrix: prevent missing details from becoming UX failures

| Test | Observable acceptance |
| --- | --- |
| Switch actor in every profile | Portrait, role, resources, equipment, skills and actions all change appropriately; selected page persists |
| Shared spell on two Momentum actors | Both gain the spell, but their unique action/range/weapon play remains different |
| Remove grant source | Only dependent actions disappear; learned/mastered actions remain |
| Wrong equipment | Explain the specific unmet requirement before confirmation; no silent fallback |
| Full bag or two-hand conflict | Preview resolution; failed operation leaves all instances and quantities unchanged |
| Link without a participant | Display missing actor/readiness/cost; no resource deduction |
| Tactical adapter switch | Correct action and capacity terminology; no mixed D&D/PF2 rules |
| Flow resource exhaustion | Martial fallback and healing tradeoff remain clear; no fake universal mana pool |
| DAO tactic and sustained ability | Rule priority and reserved-resource/fatigue effect visibly change outcomes |
| Cadence distinct commands | Different selector and effect for tool, martial sequence and magic |
| Save and load | Same actor builds, quantities, mastery, bindings and profile state; no duplicate grants |
| Controller-only operation | Select actor/page/item, inspect requirements, compare, cancel and return without losing focus |

## 7. Delivery boundary and priority

The immediate correction is a differentiated, actor-specific preview catalog shared by the live Ledger and HTML study. It must explicitly label numerical values as prototype data and avoid pretending preview selection recruits or possesses an NPC. A four-person showcase does not fulfill the additional archetype coverage listed above.

Next implementation should make one vertical slice real: item instance → equip transaction → derived ability → actor action bar → queued/direct command → resource deduction → visible outcome → save/load. Then extend that contract to each profile's distinct rules. Shipping all nine as visual skins before this loop works would repeat the current problem.

## Sources, methodology and limitations

The two reports use **20 distinct primary-document or official sources**: 16 linked in report 006, plus Player Core playing-the-game, dedication, carrying-items and Bulk pages here. One original manual is accessed through a third-party transcription. Archives of Nethys is the official rules reference and reproduces the identified Player Core text. Access date: 2026-10-22.

Searches targeted original manuals and developer explanations for classes, specialization, inventory, styles, party switching, radials, ATB, mastery and linked techniques. Source facts are deliberately separated from Oathshaper proposals. This is a behavioral design deep dive, not an exhaustive transcription of every spell, feat, item or subclass. Exact numerical parity, every port's mappings, full Starfinder coverage, source-game play sessions and physical Steam Deck validation remain open. The acceptance matrix makes those gaps testable instead of treating a large list of names as completeness.
