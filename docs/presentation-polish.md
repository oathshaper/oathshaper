# Office surfaces, breathing and archive exit

Verified on macOS / Apple M4 Pro / Godot 4.3 Compatibility renderer, 2026-10-21.

## Changes

- **Wall-top shimmer:** the office walls and their coping both ended at Y=3.4, leaving overlapping visible faces. Caps now sit above the wall (Y=3.4–3.58), and cap corners meet edge-to-edge. Side walls also butt against the north wall instead of overlapping its exterior faces. Textured stone remains on the caps; this was a depth-overlap problem, not a missing texture.
- **Cadenced idle:** the initial quiet breathing pass was too small to see in gameplay. Rebuilt all five rig derivatives with a perceptible torso sway every eight beats, breathing every four beats, and slightly different tempos (7.04–8.38 seconds per sway). The neck counterbalances the torso; hips and both feet remain planted. Talk uses the same slow cadence. The standing corrections, player Walk samples, source GLBs and embedded textures are preserved.
- **Archive return:** the player and camera face east into Civic Court. Transfers clear old velocity and reset the movement basis, so W moves away from the door immediately. The return point is now 2.7 metres farther into the court. A camera-only collision envelope covers the door surround and sign that protrude beyond the building collider, leaving room for the lens. This uses named physics layer 8, excluded from the player's collision mask.

## Evidence

The regenerated assets passed `python3 scripts/verify-rigged-glbs.py`. The Blender gait check retained the previous ankle/boot lane and heading measurements, with zero measured floor error. A binary-content comparison against the preceding Git revision confirmed identical embedded image payloads for all five derivatives and identical player Walk sample data.

Godot headless checks passed after the cadence/clearance refinement:

- `headless_test.gd`: existing scene checks plus sampled Idle/Talk motion and planted feet, seamless loops, outward exit heading, matching camera direction, and immediate W travel into the court. Arrival checks require more than 3.5 metres from focus to camera, a clear 20 cm camera sphere, and all four near-plane corners outside the actual door meshes.
- `route_integration_test.gd`: locked door, clerk clue, controller events, map/journal, cabinet collection, save/load and return route.
- `rig_slot_test.gd`: rig selection and procedural/static fallback contracts.

The unchanged wall/cap geometry also passed `records_office_test.gd` in the preceding `7529c99` pass; that check was not repeated for this refinement.

The headless import/checks still emit the previously observed Godot dummy-renderer `mesh_get_surface_count: Parameter "m" is null` diagnostic. They exit successfully; graphical capture logs have no corresponding rendering error. These are macOS checks with synthetic controller events, not a new Linux or physical-controller/Steam Deck test. Rust code was unchanged and its tests were not rerun for this presentation pass.

Graphical evidence comes from `godot/tools/capture_office_polish.gd`, which uses the actual demo scene without writing saves. The temporary lineup is only for comparing the animations; normal NPC positions are unchanged.

- [Office wall caps](images/office-coping-fixed-1280x800.png) and [second camera angle](images/office-coping-fixed-orbit-1280x800.png).
- [Archive arrival facing Civic Court](images/archive-exit-facing-court-1280x800.png).
- [Five-character idle video](images/quiet-character-breathing.mp4) and [still](images/quiet-character-breathing-1280x800.png).
- [Idle and Talk at normal gameplay camera distances](images/cadenced-idle-gameplay.mp4): ten seconds in exploration, then ten seconds in Mara's dialogue view; [exploration still](images/cadenced-idle-exploration-1280x800.png).

To reproduce the captures:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 --script res://tools/capture_office_polish.gd
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 --write-movie /tmp/oathshaper-cadenced-idle.avi --fixed-fps 30 --script res://tools/capture_office_polish.gd -- video
ffmpeg -y -i /tmp/oathshaper-cadenced-idle.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -an -movflags +faststart docs/images/quiet-character-breathing.mp4
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1280x800 --write-movie /tmp/oathshaper-cadence-gameplay.avi --fixed-fps 30 --script res://tools/capture_office_polish.gd -- gameplay-video
ffmpeg -y -i /tmp/oathshaper-cadence-gameplay.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -an -movflags +faststart docs/images/cadenced-idle-gameplay.mp4
```
