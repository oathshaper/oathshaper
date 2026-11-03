# Garden adversaries

Current distribution status: the [2026-11-03 Meshy rights review](../README.md) supersedes earlier provisional Meshy-permission caveats in these import notes. The owner confirmed paid/private generation; official terms permit distribution of that output. Third-party notices remain applicable.

The project owner supplied three private Meshy exports from their Downloads folder on October 22, 2026. These game meshes derive from those exports. Their supplied base-color, normal and metallic/roughness image payloads are preserved **byte for byte**, verified by SHA-256. The original exports remain untouched outside the repository.

| Character | Original triangles | Game triangles | Authored bones | In-game height |
| --- | ---: | ---: | ---: | ---: |
| Lantern Sentinel | 1,562,824 | 60,000 | 11 | 2.05 m |
| Iron Sentinel | 1,729,424 | 60,000 | 15 | 1.20 m |
| Crimson Corsair | 987,176 | 45,000 | 19 | 1.92 m |

The Lantern is a tripod construct; the Iron Sentinel is an armored quadruped. The Crimson Corsair is a humanoid raider. Their original textured shapes, colors and material maps define their appearance. No primitive body substitutes are used in the stage.

## Derivation

The supplied exports contain **no skin, bones or animation clips**. Blender 5.0.1 was used locally to reduce the geometry while retaining UVs, then author weighted skins and `Idle`, `Walk`, `Strike` and `Hit` clips. The humanoid uses fitted automatic weights with a lower-coat repair; the mechanical characters use bounded anatomical regions and joint weights. Every vertex has normalized skin weights. Clips are in place, with per-frame grounding. These are modest prototype animations; there is no motion capture or facial animation.

The application samples the clips for host-driven movement, attacks and damage. Pausing combat freezes their poses. A defeated actor stops animating. The Crimson Corsair's sabre uses the same bone attachment as party equipment. Collision and combat resolution remain independent of the render mesh.

Rebuild from the original exports:

```sh
blender -b --python-exit-code 1 --python tools/rigging/prepare_adversaries.py -- /path/to/downloads
blender -b --python-exit-code 1 --python tools/rigging/rig_adversaries.py
```

The first step writes intermediate static meshes under ignored `target/adversary-meshes`. Only the three final rigged meshes are included in the game. [manifest.json](manifest.json) records source filenames, complete source and derivative hashes, geometry counts, and all texture hashes.

## Verification

`godot/tests/adversary_stage_test.gd` imports the actual models in Godot, checks weighted skeletons, all four clips, supplied material maps, triangle budgets, paused poses, model selection and close-camera obstacle avoidance. It renders idle, walking, striking and a party encounter in the imported garden at 1280 × 800. These captures were visually inspected; armor and faces remain intact in the sampled poses. The camera uses separate canopy volumes to avoid branches above the walkable path.

## Rights

The owner reports paid-plan, private generation of the supplied Meshy assets. The [parent provenance notes](../README.md) record that statement and the remaining input-source verification limits. These derivatives inherit the source asset rights. The repository's MIT code license does not independently license the supplied meshes or their textures.
