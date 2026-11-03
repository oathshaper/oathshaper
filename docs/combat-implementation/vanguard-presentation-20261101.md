# Vanguard presentation repair — 2026-11-01

## Reproduction

Opening Vanguard through the main menu rendered the world on canvas layer 30,
but its HUD and modal menus used the default layer 1. The opaque world covered
the entire UI. Standalone tests had passed because they hosted the same trial at
the scene root. Checking `visible` alone did not catch the launch-path failure.

The first actor projection also calculated velocity from the origin to each
spawn position. Tessa received a velocity of 60 m/s and the companions received
larger values. The cinematic cleared the slots' `locomotion_speed`, but rigged
characters read their parent body's `velocity`. Freezing gameplay therefore
left the actors running in place.

## Changes

- Place the Vanguard overlay above its host's canvas layer. Cinematic subtitles
  remain above the gameplay overlay.
- Anchor the HUD and crosshair to the viewport. Draw an outlined crosshair with
  a target color and show the aimed enemy's name and vitals once, in the HUD.
- Show a nearby cover waypoint, a floor bracket, and contextual enter/leave/peek
  controls. Cover eligibility and its affordance share the geometry query.
- Raise Tessa's visible model when peeking. Incoming sight can reach her while
  exposed; releasing aim restores the planter's protection.
- Calculate locomotion from authoritative positions across advancing ticks.
  Spawn, reset, death and pause do not create movement.
- Give cinematic staging ownership of body velocity as well as slot speed,
  restoring the saved state on exit.
- Use the existing connected-controller/last-input helper for combat hints.

## Verification

Native Godot 4.3 on macOS, OpenGL Compatibility renderer:

| Suite | Result | Scope |
| --- | --- | --- |
| `vanguard_presentation_test.gd` | 30 passed | Actual menu entry, three idle/talking intro shots, natural handoff, rendered HUD and centered crosshair at two window sizes, squad menu input, movement into cover, peek/fire/protection, exit, cinematic interruption of movement |
| `vanguard_trial_test.gd` | 23 passed | Loadout, native firing and heat, squad powers, keyboard/controller event paths, cover and earned victory |
| `garden_confrontation_test.gd` | 73 passed | Shared campaign/menu introductions, automatic handoff and native skip for Command, Flow and Vanguard |

The new presentation test compares HUD-on and HUD-off rendered pixels. It also
checks the native actor animation clips and exercises cover through input,
observed geometry and core state rather than patching actor positions/resources.
Intro timing is accelerated in the automated suites. Screenshots of the actual
menu launch, intro, combat, squad menu, cover and peek were inspected.

Run the focused test from the repository root:

```sh
godot --path godot --resolution 1280x800 \
  --script res://tests/vanguard_presentation_test.gd
```

Capture filenames default to `/tmp/oathshaper-vanguard-presentation-*.png`.
Pass `-- --output=/path/to/prefix` to choose a different prefix.

Cover still uses the existing lowered rig pose rather than a dedicated crouch
animation. Smooth cover-entry, crouch and lean clips remain presentation work.
These checks establish this local renderer and input-event path; they are not a
Steam Deck or physical-controller acceptance result. The shared intro run emitted
one OpenGL texture-sampler warning without failing its checks.
