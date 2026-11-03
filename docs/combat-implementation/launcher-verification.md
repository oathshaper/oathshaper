# Launcher typography and layout correction

2026-10-22 · `evaluation/combat-systems` · base `3f37153`

## Change

The user supplied the old six-row, sans-serif launcher alongside the serif card study in `docs/design/combat-profile-preview.html`. A fresh source render already had the nine-profile grid. This change bundles Libre Baskerville for consistent display typography, gives the wordmark proper glyph spacing, increases card title size and padding, tunes the three visible card rows for 1280×800, and restores the study's darker palette and garden caption. Body text and controller glyphs keep the UI font.

The source font is unmodified and pinned; its copyright, SIL OFL terms and source hash are in `godot/assets/fonts/`. The study used Georgia. Libre Baskerville is the redistribution-friendly implementation choice, not a claim of pixel-identical type.

## Evidence

- Godot 4.3, macOS / Apple M4 Pro, Compatibility renderer.
- Font import: `Godot --headless --path godot --editor --import --quit`, exit 0.
- Rendered integration: `Godot --path godot --resolution 1280x800 --script res://tests/combat_frontend_test.gd`, `COMBAT_FRONTEND_OK: 4636 checks`. Log: `/tmp/oathshaper-launcher-check-20261022.log`. Covers nine-card controller reachability and scroll visibility, kit navigation, bounds, and existing save/input behavior.
- Native captures: `Godot --path godot --script res://tools/capture_frontend.gd`. Files below contain actual rendered dimensions. The capture utility does not start a journey or write a save.
- A previous headless integration run passed but emitted dummy-renderer mesh diagnostics; the headed run above supersedes it for visual verification. The headed log includes one macOS driver texture diagnostic; the captured garden artwork renders correctly. This is not a warning-free renderer claim.
- The host clamps requested 1920×1080 windows to 1728×1080. The initial capture filenames incorrectly used the requested dimensions. PNG-header inspection caught that; the capture utility now names files using the actual image size. An attempted embedded-window capture was also constrained and exited 1. No 1920×1080 validation is claimed.

| Screen | Deck dimensions | Desktop dimensions |
| --- | --- | --- |
| Title | [1280×800](../images/launcher-title-1280x800.png) | [1728×1080](../images/launcher-title-1728x1080.png) |
| Profiles | [1280×800](../images/launcher-profiles-1280x800.png) | [1728×1080](../images/launcher-profiles-1728x1080.png) |

Root inspected these renders for typography, card/label fit, artwork, and the mockup's hierarchy. Independent non-editing review by `flow_design` found no actionable issues within the launcher scope and confirmed that PNG dimensions match filenames. Hardware Steam Deck testing and exported-package testing are not claimed; controller navigation was simulated through Godot's input path on macOS. Other screens using the shared heading font were exercised by the integration suite but were not independently visually reviewed.

## Delivery boundary

Only launcher presentation, shared display typography, font assets and capture evidence change. No combat mechanics, game-save format or story changes are included. The larger combat implementation goal remains paused and incomplete. workflow automation stays disabled under the user's instruction. Existing Godot PID 48454 was preserved; updated normal game PID 399 was launched separately with log `/tmp/oathshaper-launcher-ui-20261022.log`. Startup used the Compatibility renderer without script errors. Process IDs are point-in-time evidence. Rollback is a local revert of this presentation commit; no data migration is involved.
