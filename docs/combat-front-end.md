# Combat front end

Implemented and checked directly in Godot 4.3 on macOS, 2026-10-22. The title opens before Lantern Quay. **New Game** and **Load Game** lead to the style picker. Load preselects the saved style and allows an override. Starting a new journey from the Ledger asks before discarding unsaved progress and leaves the existing save intact.

## Walkthrough

1. Choose New Game, browse the numbered style cards, optionally Inspect Kit, then Start Journey. The two-column list scrolls to keep controller focus visible; B/Esc first closes a kit inspection. The garden illustration is a fresh in-engine capture without HUD elements.
2. Open **Tab / Menu → Character** for the avatar, Mercy meter and Ivo affinity. **←/→ or LB/RB** changes pages; **Q/E or X/Y** changes the inspected actor. Equipment and Combat Style show that actor's authored kit, abilities, sources and costs. **PgUp/PgDn or the right stick** scrolls long pages. All combat values are explicitly marked as proposed.
3. Change styles from Combat Style without losing narrative progress. Up/down reaches **Start New Journey**; B/Esc returns to exploration.
4. **Q / Ⓧ** readies a weapon. **LMB / RT** performs a practice strike/shot and leaves it ready. **Esc / Ⓑ** sheathes. Flow uses an unarmed guard and punch. View remains Map.
5. Save with F5 or the Ledger; load with F9, the Ledger or title. The style persists.

| Skin | Family / reference | Presentation |
| --- | --- | --- |
| Command | Real time with pause / KOTOR | Sabre, buckler, coat, focus; powers and queues |
| Oathbound | Command variant / Dragon Age: Origins | Four-person party target; sword, shield, mail, staff, rogue tools; talents and tactics |
| Flow | Direct action / Jade Empire | Martial, weapon, magic and support styles |
| Vanguard | Squad shooter / Mass Effect | Carbine, sidearm, harness, shield and tech modules |
| Tactics | Initiative / three-action tactical RPG | Weapon, shield, armor, preparation and ammunition |
| Momentum | Action / command-gauge hybrid | Weapon sockets, commands and supplies |
| Confluence | Live ATB / Chrono Trigger | On-field readiness, changing target geometry, dual/triple techniques |
| Cadence | Classic ATB / Final Fantasy VI | Four roles, speed-based gauges, Active/Wait submenus, relics and learned magic |
| Orders | Simultaneous planning | Repeater, close weapon, gadgets and reserves |

This slice includes UI, loadout previews, save metadata and skeletal practice poses. Damage, enemies, equipment transactions, companion deployment/AI, resources, queues, cooldowns, initiative and combat schedulers remain planned. The character keeps her existing coat model across skins; armor meshes do not yet change.

## Architecture

- `main.gd` owns a modal CanvasLayer above the demo, suspends the running scene during selection, and validates a candidate journey before replacing the active one.
- `party_catalog.gd` reads the shared `content/rpg_catalog.json`: 36 original builds with distinct resources, skills, kits, actions, tradeoffs and progression. It is read-only design data, not an inventory engine. `tools/export_party_catalog.py` generates the browser study's identical catalog.
- `combat_profiles.gd` holds stable skin IDs and author-readable metadata. Oathbound's `family` is `command`. Actual item instances and combat costs belong to the future Rust RPG model.
- `save_store.gd` schema 2 adds `combat_profile`; schema 1 defaults to Command. Malformed profiles, schema types and positions fail before narrative mutation. Title and demo share `HUB_PATH`.
- `weapon_presentation.gd` attaches original primitive practice weapons to `RHand`. `combat_pose.gd` uses Godot 4.3 SkeletonModifier3D after the locomotion clip, preserving leg animation. The regenerated player rig repairs 278 coat vertices that followed the arm during strikes; source Meshy GLBs remain untouched.
- One RT threshold crossing produces one strike; release is required before another. Menu, map, dialogue and profile screens take priority. Dialogue sheathes automatically.
- The wordmark uses the mockup's Georgia serif treatment with Liberation Serif and DejaVu Serif system fallbacks. No font binaries are redistributed; rendering can differ on systems without these fonts.

See [combat UX contracts](research/006-combat-ux-contracts.md), [archetype and inventory requirements](research/007-archetypes-equipment-inventory.md), and the [research rights notice](research/NOTICE.md).

## Verification

```sh
cargo test --workspace --locked
Godot --headless --path godot --editor --quit
Godot --headless --path godot --script res://tests/combat_frontend_test.gd
Godot --headless --path godot --script res://tests/route_integration_test.gd
Godot --path godot --resolution 1280x800 --write-movie /tmp/combat.avi --fixed-fps 30 --script res://tests/combat_frontend_test.gd -- capture
Godot --path godot --resolution 1280x800 --write-movie /tmp/poses.avi --fixed-fps 30 --script res://tools/capture_combat_pose.gd
```

The focused suite checks profile persistence and migration, malformed data, controller navigation, all nine skins, scrolling focus, kit inspection, cancellation, failed-load preservation, load overrides, trigger latching, modal input, hand attachment and visible UI bounds. It exits nonzero on failed assertions and prints success only when every check passes. `scripts/check.sh` includes it. The [ATB research and design](research/005-three-atb-profiles.md) describes the proposed schedulers; these menu definitions do not implement them.

Before the menu redesign, 23 Rust tests passed; the focused Godot suite passed 488 checks headless and 496 with eight graphical captures. The existing integration, dialogue-response, records-office and rig-slot checks also passed, and all five character GLBs passed the skin/clip verifier. The macOS graphical run logged one driver-level texture warning; captures were inspected, but the warning has not been diagnosed. That is historical evidence; current verification is recorded below.

Rendered evidence: [title](images/combat-title-1280x800.png), [picker](images/combat-picker-1280x800.png), [party](images/combat-party-1280x800.png), [equipment](images/combat-equipment-1280x800.png), [abilities](images/combat-powers-1280x800.png), [sabre pose](images/combat-pose-command-strike.png).

Checked on Apple M4 Pro using OpenGL compatibility at 1280×800, with injected controller events. No physical controller, Steam Deck or new Linux acceptance run was performed for this slice. The headless dummy renderer emits existing `mesh_get_surface_count: Parameter m is null` cleanup messages; graphical combat captures provide the visual check. These are first-pass animation poses.

## Implementation scope

Chapter automation remains proposed. See the [release status](release-status.md) for the playable features and validation limits of the current candidate.

## Actor preview verification — 2026-10-22

The final Godot suite passed **4,691 checks with rendering** and **4,676 headless checks**. The graphical suite checks all 36 builds across Character, Equipment and Combat Style, verifies actor-specific rendered content, controller actor cycling with page retention, read-only narrative state, right-stick scrolling, and viewport bounds. The prior launcher/save/weapon input regressions remain included. The browser check passes 144 actor/page states and nine bookmark/back flows with no script errors. Screenshots were inspected at 1280×800. See [Mara as a tech specialist](images/combat-vanguard-mara-character-1280x800.png), [Ivo's weapon styles](images/combat-flow-ivo-abilities-1280x800.png), and [the updated browser equipment sheet](images/combat-archetype-study-1280x800.png).

This validates preview content and navigation; it does not validate combat balance, AI, equipment transactions or a physical Steam Deck. Public-release asset rights remain pending under the research notice.

The records-route integration also passed: locked door, clerk clue, controller map and Ledger navigation, cabinet collection, and save/load into a fresh scene. Its page checks now use page names while navigating through controller shoulder events, and its save assertion checks schema 2 with the persisted combat profile.
