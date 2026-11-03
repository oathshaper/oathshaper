# Quaternius animation sources

The free **Standard** editions of [Universal Animation Library](https://quaternius.itch.io/universal-animation-library) and [Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2), downloaded October 28, 2026. Each contains 43 animation tracks, including a reference T-pose. These are not the larger paid editions.

Both supplied archives include the same CC0 dedication, reproduced in [LICENSE.txt](LICENSE.txt). Credit: Quaternius. Original in-place Unreal/Godot GLBs are kept here for reproducible retargeting; they are outside the exported game's resource directory. [manifest.json](manifest.json) records source pages, archive and GLB hashes, and clip names. No purchase was required.

Current use: `UAL1_Standard.glb` → `Walk_Loop` → Tessa's `Walk`, and `Jog_Fwd_Loop` → Tessa's `Run`. The remaining tracks are available source material, not claims of implemented combat animation.

## Build and compare

From the repository root, with Blender 5.0.1:

```sh
blender -b --python-exit-code 1 --python tools/rigging/retarget_library.py
godot --headless --editor --path godot --import
godot --path godot --script res://tools/preview_animation_library.gd
```

The default bake creates an ignored comparison asset with the donor idle, walk and jog. Install the gaits individually while retaining the game's idle:

```sh
blender -b --python-exit-code 1 --python tools/rigging/retarget_library.py -- --install-walk
blender -b --python-exit-code 1 --python tools/rigging/retarget_library.py -- --install-run
godot --headless --editor --path godot --import
```

Each install computes a phase offset against the other gait so transitions keep the same leg forward. It measures grounded foot travel to set stride distance (currently Walk 1.138 m/cycle; Run 3.537 m/cycle). Original texture payload hashes, triangle count and all 72 joints must survive before the new GLB replaces the installed asset. Missing stride samples prevent installation.

## What students can inspect

1. `MAP` connects the library's humanoid roles to this character's named bones.
2. Reference-pose calibration straightens limb axes while preserving the target's bone roll and skin bindings. A name match alone cannot handle a T-pose versus an A-pose.
3. Rotations transfer in armature space, then become local rotations down the target hierarchy. Body motion stays in place; Godot owns world movement and collision.
4. The bake measures the deformed soles and corrects floor contact. This is flat-floor calibration, not a terrain IK system.
5. Loop and ground checks catch geometric failures; the comparison viewer and actual game capture remain necessary to judge motion and clothing deformation.

The source idle was previewed but is not installed. Combat clips still need grip, contact timing, transitions and actor-specific review. They are not interchangeable with the game's current procedural attacks merely because the library contains sword animations.
