# Tessa rig and party weapon integration — 2026-10-28

Update: Tessa’s Walk was subsequently replaced with a retargeted CC0 library clip. See [the animation trial](../animation-library-20261028/README.md) for the current gait; measurements below describe the initial Meshy integration.

Implemented locally using the owner's new Meshy exports. Originals in Downloads remain unchanged. The static high-density Tessa export is not the runtime character; the supplied animated export already carries the matching 8K albedo, skin and lower-density geometry.

## Rig comparison

| | Previous stand-in | Supplied Meshy rig, adapted for the game |
| --- | --- | --- |
| Skeleton | 19 proportion-fitted body bones | 72 joints, including fingers and toes |
| Skin | Blender automatic weights with local coat repairs | Provider weights retained |
| Locomotion | Locally generated Walk; simple keyed limb swings | Supplied Walking and Running, adapted into Walk and Run |
| Standing | Authored slow Idle | New eight-second Idle; supplied file had no standing clip |
| Grip | Rigid hand attachments; fingers cannot close | Finger landmarks define palm frames; finger joints curl around handles |
| Geometry | 15,472 triangles | 10,258 triangles |
| Textures | Original 2K maps | Original 8K albedo, 4K normal/metallic-roughness maps |
| Combat | Procedural upper-body poses | Still procedural; source supplied no attacks, blocks, hits or deaths |

The stand-in established movement, state transitions and attachment contracts. The Meshy rig supplies a better locomotion and hand-deformation starting point. More bones alone do not correct a bad skin or supply missing animations. Mara and Ivo still use the older 19-bone rigs; their open grips and Mara's coat deformation remain visible limitations.

## Adaptation

- Kept all provider joints and texture payloads. Aliased the main body bones to the existing presentation interface; finger names remain available for finer poses.
- Normalized the asset to the established 1.9m game height. Added `GroundContact`: imported skin bounds already contain bind-space transforms, so applying the surrounding scene transform to those bounds again previously lifted Tessa above the garden.
- Reduced foot yaw by 10° on the left and 12° in the opposite direction on the right. Corrected hip height against evaluated boot soles. Walk maintains contact; Run retains flight phases.
- Removed horizontal root movement from the clips. The supplied cycles were already essentially in place; this is a controller-ownership guarantee, not a claim that the source had large root drift.
- Calibrated Walk to about 1.5m per cycle and Run to 3.2m at the current height. Playback follows actor speed. Walk/Run transitions preserve phase and use a 0.25m/s hysteresis band. Reverse movement uses Walk.
- Added four textured weapon scenes and named grip/impact sockets. Weapon geometry dropped from 632,750 to 32,000 triangles in total, with original image payloads preserved and Godot mesh LOD generation enabled.
- Included the rig's `.motion.json` calibration in all three export presets. The old stand-in generator no longer overwrites the player rig.

## Evidence

Blender evaluated 121 samples per clip, including times between exported keys. In Walk, the lowest sole stayed between **1.83mm below and 4.36mm above** the flat floor; ankle separation was **20.1–23.9cm**. Median foot heading during forward-facing contact was **−0.41° left / −0.72° right**. These measurements describe this flat-floor test, not terrain-aware foot IK.

Run retains about 17.5cm of maximum airborne sole clearance. Its interpolation still allows up to 1.35cm of sole penetration at some samples; this is a remaining polish limit. Loop ankle discontinuity was below one micrometre in both gaits.

- [Walk cycle](images/tessa-walk-cycle.png) and [Run cycle](images/tessa-run-cycle.png): front and side, phases 0%, 25%, 50%, 75%.
- [Tessa grip](images/tessa-grip.png): original sabre/buckler meshes on the provider hand rig.
- [Actual Command garden](images/command-garden.png): grounded character and imported weapons.
- [Gait measurements](verification/gait.txt).
- [Party assets](verification/party-assets.txt): 32 checks passed.
- [Equipment mounts](verification/equipment.txt): 12 checks passed.
- [Rig fallback/locomotion](verification/rig-slot.txt): passed with the native renderer.
- [Command](verification/command.txt): 47 checks; [Flow](verification/flow.txt): 294; [Vanguard](verification/vanguard.txt): 23. All passed.

Desktop evidence uses Godot 4.3 / OpenGL Compatibility on the local M4 Pro. The new 8K texture has not been profiled on Steam Deck. No game executable was exported or published by this change. The already running user game was left open and needs a fresh launch to load the replacement assets.

## Reproduce

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python tools/rigging/import_party_assets.py -- ~/Downloads all
/Applications/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 --python tools/rigging/verify_party_gait.py
python3 scripts/verify-rigged-glbs.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path godot --import
/Applications/Godot.app/Contents/MacOS/Godot --path godot --resolution 1800x1000 --script res://tests/party_asset_test.gd -- --capture
```

Source names, SHA-256s, texture hashes, triangle counts and sockets are in [the manifest](../../godot/assets/meshes/equipment/manifest.json). New reusable animation packs are researched separately in [the animation library note](../research/012-reusable-humanoid-animation-libraries.md); none of those packs is installed by this integration.
