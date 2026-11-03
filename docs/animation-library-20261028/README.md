# Free animation library trial — October 28, 2026

## Installed result

Tessa's `Walk` now uses Quaternius UAL1 `Walk_Loop`, transferred to her existing Meshy skin. The earlier Meshy `Run` and local `Idle` remain. Both free Standard packs are available under `tools/rigging/sources/quaternius/`, with 43 tracks each (including their reference poses), original licenses and source hashes. No paid animation pack was needed.

The new walk was selected after inspecting front/side sampled poses against both the donor mannequin and the preceding Meshy motion. This is a first integration for playtesting, not a claim that every source clip or NPC rig is production-ready.

## Motion evidence

- [Donor comparison](donor-comparison.mp4): the pre-install Meshy motion, library motions on Tessa, and original donor mannequin. This was captured before phase alignment. The library idle and jog shown here were **not** installed.
- [Installed motion in the quay](walk-run-gameplay.mp4): actual character slot at 1.5, 4.5 and 2 m/s, three seconds each. The camera follows from a fixed angle. Section changes reposition the actor deliberately. At 4.5 m/s the existing Run plays.
- [Numerical gait report](gait.json): 121 samples per clip, including interpolation between baked keys.
- [Checks](checks.txt): actual Godot import, required clips, hand grips, placement, stride, transitions, and Command encounter regression.

The walk's sampled sole height is -1.45 to +2.12 mm relative to the floor. Median forward-facing contact headings are approximately 1.0° and 2.3°. Its loop closes without measured ankle discontinuity. These are geometric checks; the recordings allow a person to judge timing and appearance.

The old and new cycles initially disagreed about the leading leg. The bake offsets Walk by 0.825 cycles against the retained Run; normalized leg-gap mean squared error drops from 0.515 to 0.012. A separate Godot check measures the imported poses, not just the report. Stride distance is measured from the grounded backward foot motion: 1.138 game metres per walk cycle. Run remains 3.2 metres.

Texture payload hashes are unchanged, as are the triangle count and all 72 joints. Retargeting runs offline; the game plays ordinary baked tracks. No model inference or per-frame retarget solver was added.

## Reproduction and remaining work

See [source and teaching notes](../../tools/rigging/sources/quaternius/README.md) for build commands. `verify_party_gait.py` accepts an optional GLB path after `--`, followed by `--clip Walk` to isolate a candidate. `preview_animation_library.gd` compares installed/candidate/donor scenes; `capture_locomotion_movie.gd` records the actual quay motion.

Only locomotion was integrated. Sword attacks, blocks, impacts, casting and deaths in the downloaded libraries still need weapon contact, gameplay event timing and transitions. Mara and Ivo retain their existing rigs. This run did not validate a physical Steam Deck or uneven-terrain foot placement.
