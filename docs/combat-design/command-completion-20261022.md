# Command encounter completion

## Scope and delivery

Baseline: `b7c174a`, clean `release/demo-20261022` in `.`. workflow automation remains disabled by the user's explicit instruction. Work stays in this checkout, with disjoint file ownership and coordinated extension rebuilds. No publication or licensing changes.

Acceptance:

1. Spoken topics selected from Mara, the clerk and Ivo remain grey on return, re-entry and save/load; exits and navigation remain usable. Existing flags migrate only history they actually establish.
2. After the records establish public passage, the promised companions visibly assemble at the garden gate. The gate-to-encounter transition preserves story continuity and provides a real party choice.
3. All three supplied Meshy adversaries appear with their textures and suitable scale. Their combat roles differ. Any generated rigs and mesh reductions retain provenance and are verified visually.
4. Command has a compact, legible HUD: selectable portraits and resource bars, selected enemy name/health, contextual actions, visible queued orders, pause/resume and disengagement. The world and characters remain prominent.
5. Equipment selection uses body slots plus a filtered inventory list and item comparison/action. Party, abilities and inventory operate on the real core state.
6. Verify the actual route from records through a winnable encounter, recovery/retry, reward and save/load. Review screenshots at 1280×800. Run Obelus on new player-facing copy. Commit and relaunch the verified game; rebuild the local archive once.

The supplied KOTOR screenshots inform interaction placement and density. Use original Oathshaper art, icons, language and visual styling; no copied game assets. The publisher's [KOTOR manual](https://cdn.steamstatic.com/steam/apps/32370/manuals/KOTORI_Manual.pdf) is the primary reference for party possession, action queue, pause and equipment-slot selection.

## Ownership

- Dialogue worker: narrative core/history, authored disable conditions, focused dialogue tests.
- Same worker, subsequent slice: Command enemy data/rules/AI/view and Rust tests.
- Mesh worker: adversary imports/derivatives/provenance, stage presentation and camera, focused render test.
- Root: exploration companions, Command HUD/trial/ledger integration, copy review, combined validation and package.
- Independent reviewer: bounded completed diff and evidence, read-only.

## Operating bounds

Observed-only planning limits: initial discovery 15 minutes/15 tool calls; each implementation slice 30 minutes/30 calls before recording progress and contracting scope to the remaining acceptance requirements; integration/review reserve 30 minutes. No model overrides or provider/billing claims. Maximum three simultaneous implementers beyond root, no nested delegation. Each failed check requires a concrete diagnosis before another run; preserve failure logs. No broad historical-source scans or repeated full suites without a specific remaining risk.

## Progress

- Located all three requested GLBs in Downloads.
- Confirmed missing narrative choice history; the panel's grey styling already works when given completed state.
- Confirmed the current chapter promises Mara and the clerk, while Ivo guards the gate; there is no exploration rendezvous logic. The roster includes all three. The implementation must make the promised meeting visible rather than changing text to hide the missing behavior.
- Confirmed Command currently uses two primitive enemy presentations and a large debug-like HUD that obscures the garden.

## Implemented and reviewed

- Narrative choice history persists by node and choice ID; terminal exits and repeatable navigation remain usable. Old Mara/clerk flags backfill known history. An old Ivo question with no recorded effect cannot be reconstructed and can be asked once after upgrade.
- After records are collected, Mara and the clerk follow quay/bridge routes; Ivo steps to the assembly after opening passage. The party waits for their arrival before entering. Campaign Command deploys player/Mara/Ivo; the clerk can replace either companion through the Party menu at camp.
- Imported all three supplied models, reduced to 165,000 triangles total, with original texture payloads and modest authored weighted rigs. Each has idle, walk, strike and hit clips. Source and derivative hashes and limitations are in the adversary asset README/manifest.
- Iron Sentinel fights in melee and braces; Lantern Sentinel uses ranged arcs; Crimson Corsair lunges. Defeating all three awards the seal once. AI retargeting failures no longer globally pause combat.
- Command uses close third person framing, selected enemy health/actions, portrait possession with health/resource bars, action icons, editable orders, pause/resume and disengagement. Equipment uses body slots beside compatible owned items and real comparisons. Inventory dressings use the same queue and resource ledger as other actions.
- Independent review found stale portrait bars and missing inventory Use metadata. Both were fixed and covered. Native integration found that deployment invalidated visibility during contact pause; the host now observes geometry and commits it with advance(0), which cannot process AI, orders, costs or time. This path is separately tested, including the restore barrier.

### Verification available before packaging

- Native dialogue persistence test passed; narrative Rust tests include reentry and legacy defaults.
- Native three-model stage test: 46 checks, zero failures; actual skins, clips, camera clearance, pause, hand attachment and selected target ring.
- Native Command route: 509 checks, zero failures. Cabinet records → Ivo opens gate → visible assembly → player/Mara/Ivo combat → earned victory at tick 402 → return → save/reload. All enemies defeated; remaining HP player 13, Mara 50, Ivo 46. An earlier AFK test lost; the accepted test issues normal attack orders rather than relying on unattended companions.
- Native Command input/queue/save/ledger test: 45 checks, zero failures. Native new controls/party/targeting/Inventory Use test: 27 checks, zero failures. Real equipment projection at 1280×800: 273 checks, zero failures.
- Vanguard shared-stage regression: 23 checks passed headless and native with capture; an initial native run had input/timing failures, retained in local logs. No claim that all nine combat styles are implemented.
- Obelus reviewed seven rendered text exports with four positive controls. No rejected-copy matches; remaining heuristic findings are adjudicated in the Command copy review. A bounded independent source review found no remaining P1/P2 issue after the fixes.

### Compatibility and reference boundaries

Command combat snapshots now require content manifest v4 because the encounter contains a third actor. Older Command snapshots fail with the existing incompatible-content message; journey/narrative saves remain compatible. Source exports did not contain rigs: locally authored prototype animation is explicitly distinguished from supplied art. The KOTOR manual is cited for descriptive interface research; names/trademarks belong to their owners, and no endorsement or affiliation is asserted. No KOTOR artwork, UI frame, screenshots or game data were copied into the shipped game.

Publication, final license choice and physical handheld acceptance remain separate. This task creates a local candidate only.

### Full project gate

`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot ./scripts/check.sh` exited 0 on this candidate. Rust format, strict workspace Clippy, 115 tests and one doctest passed. Dialogue validation and all listed native bridge tests passed, including menu previews (10,730), Command controls (27), Command ledger (275), equipment (273), Flow (294), Vanguard (23), chapter route (512 sampled checks in headless mode), and generated voices (59). The headless dummy renderer still emits its existing mesh-surface diagnostics; the inspected native captures and native focused tests do not show that renderer error. These diagnostics are not counted as gameplay acceptance.

The separate native chapter run reports 509 checks because its authored route sampling depends on how far NPCs move during rendered frame settling. Both runs require the same exact gate assembly, actual attack commands, three defeated enemies, one reward and a durable journey save.
