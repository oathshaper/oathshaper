# Vanguard garden release slice

Base `daaee1c`, branch `impl/combat-vanguard`, isolated worktree `.agent-worktrees/combat-implementation/vanguard`. Accepted source: `docs/combat-design/profiles/vanguard/{design.md,scenarios.json,evaluation.md}` in the Vanguard design worktree, including root-accepted repairs at `32bd59f`. This is a bounded playable implementation of that design, not completion of its twenty full-profile scenarios. workflow automation is explicitly disabled for this delivery. No paid services, publication, or campaign save writes occur here.

## Integration

- `res://scripts/vanguard_trial.gd` extends `Control`. Connect `finished` before adding it. Optional `preview_mode` and `campaign_mode` default false.
- `has_won()` returns true only after the live Rust encounter resolves as won, and stays true through an isolated replay. The root hub owns campaign persistence and reads this before freeing the trial.
- `VanguardBridge.create()`, `view()`, `submit(json)`, `advance(json)` return the established `{ok,data}` transport envelope. Actions and host geometry frames are distinct typed deserialization boundaries.
- Register `pub mod vanguard` in core and `mod vanguard_bridge` in GDExtension. No Command gameplay file changes are required.
- Briefing and resolution read `garden_chapter.gd`. The parent owns any shared voice attachment.

## Implemented

The shared LCD `Session<VanguardProfile>` owns transactional commands, host-only advance capability, revision/generation envelopes, ordered observation consumption and rejection rollback. The profile owns its state through a minimal manifest. Every live health, shield, heat, cooldown, movement, control, pending-power, equipment and outcome change commits through that session. There is no alternate GDScript damage path.

The fixed party is Corsair/Breacher (160 HP, 150 shields, medium armor2; carbine/shotgun), Mara/Engineer (95/110; pistol/pulse tool), and civic clerk/Sentinel (110/130; pistol/concord tool/ward lens). The two authored synthetic sentries have 120/60 and 180/80 health/shields. They are encounter fixtures; their attack cadence is an original slice balance choice.

Implemented powers: Concussive shot and Fortify; Arc overload, Sabotage and Shield repair; Disrupt, Barrier pulse and Kinetic throw. These retain the design's individual cooldowns, windup and shield/control legality. The throw moves at most3m through host-tested swept segments and stops at obstacles. Pending powers claim one actor channel, activate on the next running tick, revalidate at effect, and retain activated cooldowns on cancellation/miss. Defensive companion powers are automatic below30% shields; offense powers are manual. Both companions fire automatically and accept independent Follow/Hold/Attack orders without changing direct player possession.

Weapons keep individual heat, emission timestamps, cadence, overheat latch100 and unlock threshold30. Cooling starts after0.5s at20/s; swap occupies0.4s, holster/draw0.3s, ordinary emission0.1s. Shield regeneration waits3s and restores20/s; health does not regenerate. Armor applies to health after shields; barrier absorbs before shields and expires after4s. Tech shield damage has no health overflow. Strict barrier improvement rejects equal/stronger current barriers, preserving their source/expiry.

Briefing offers a real standard/cooling/damage module choice on the player's carbine. Cooling changes damage−5/cooling+10 per second; damage changes damage+5/heat+5 per shot. This is a trial loadout selector with actual Rust stat consequences, not an inventory purchase or transferable module instance. Editing during combat rejects. All three actors retain distinct weapons, equipment descriptions and power sets.

## Native control and geometry

Third-person shoulder camera, relative mouse aim, controller right-stick look, WASD/left-stick movement, RMB/LT aim, LMB/RT fire, Q/LB swap, R/X draw/holster, Space/A cover, Tab/RB squad selector, Esc/Start menu, quick powers1–4. B closes the current modal, otherwise leaves cover, otherwise holsters a readied weapon, and does nothing when already holstered. Fire/aim while holstered starts draw and cannot emit before its channel completes. This slice uses toggle wheel input, not the full design's hold/toggle settings UI.

Godot supplies a same-step ordered geometry frame with bounded candidate positions, ray target, sight pairs and cover proximity. Rust validates tick, sequence, actor set and maximum movement before committing it. The host samples body obstruction, muzzle sight and authored planter collision. Friendly bodies can obstruct a shot; the camera ignores bodies behind the muzzle. The shared Command stage is reused only for imported garden, lighting, collision builders, rigged actor models and construct visuals. Vanguard replaces its view projection, camera, process loop, weapon props and observation path; no Command combat operation is reused.

Cover contract: Space enters a stationary tucked stance only within0.8m of an authored planter, whose actual collider blocks incoming sight when positioned between attacker and player. It is directional physical obstruction, not a universal damage reduction. Aim raises the source height and exposes the player; firing while tucked requires aim. There is no cover snapping, sliding, vaulting, blind fire or corner-peek animation. Walkable footprints and sweeps come from the measured garden geometry; no movement crosses the planter volumes.

## Explicit remaining scope

No full six-build selection, Ivo/Adept deployment, talent allocation/respec, Ledger progression, inventory ownership/capacity, equipment transfer, crafting, vendors, loot, world skills, gel/aid/revival, melee, authored escape, first-person mode, full remapping/accessibility settings, save/restore of in-flight combat, or campaign reward currency/XP is implemented here. The only persistence-facing result is legitimate chapter victory; the parent hub decides its campaign consequences. There are no hidden enemies or sensor powers in this fixed encounter, so the full design's hidden-state scenario is not accepted by this slice. Enemy movement/flanking and companion cover seeking remain future AI work. Follow uses reachable paths; Hold remains stationary; Attack targets the named observed enemy without pursuing it.

The firearm meshes are original simple props attached to the existing rigged bodies. Full firearm arm/aim/recoil animation and sound production remain art work. This implementation does not claim source-game parity, full scenario acceptance, or final balance acceptance.

Rollback: remove the two module registrations and the owned Vanguard files, or revert the Vanguard commit before root integration. No campaign format, shared mechanics, dependency or asset migration is involved.
