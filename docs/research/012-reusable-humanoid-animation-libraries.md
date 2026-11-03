# Reusable humanoid animation libraries

Research checked October 28, 2026. Both Quaternius free Standard packs have now been downloaded: 43 tracks each, including their reference poses. Tessa uses the retargeted UAL1 walk; other library motions remain source material or comparison previews. No purchase was made. Refer to [research notice](NOTICE.md) for attribution and independence of the project.

## Recommendation

Use Quaternius's free Standard libraries first. They provide a shared humanoid animation vocabulary suitable for the student engine, with CC0 assets that can accompany editable examples. The library walk is now transferred to Tessa's existing skin; her Meshy run and locally authored idle remain installed. The library jog and idle were compared but not selected. Paid source editions remain optional if we need additional clips or source edits.

| Library | Coverage / formats | Current access | Relevance |
| --- | --- | --- | --- |
| [Quaternius Universal Animation Library](https://quaternius.itch.io/universal-animation-library) | 120+ animations across the full collection; directional movement, combat, firearms, emotes, deaths; Godot exports, Mixamo-compatible retargeting | Free Standard subset; Pro $9.99; Source $14.99; CC0 | General character movement and reactions |
| [Quaternius Universal Animation Library 2](https://quaternius.itch.io/universal-animation-library-2) | 130+ across the full collection; armed/melee combos with separate attacks and recoveries, parkour, work actions | Free Standard subset; Source $14.99; CC0 | Combat extensions, especially authored attacks/recovery |
| [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations) | 161 humanoid animations; melee, blocking, magic, ranged, movement, interactions; FBX/glTF | Animations free; Blender sources $14.99; CC0 | Broad alternative; author warns that motion designed for KayKit proportions may look different on other characters |
| [Mixamo](https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html) | Existing humanoid character/motion library | Free Adobe ID; royalty-free finished-game use | A natural technical candidate for the Mixamo-style export, but separate raw-file distribution restrictions matter for an engine repository |

The Quaternius listings offer root-motion and in-place variants. Use the in-place variants with Oathshaper's present scene-owned movement. Advertised totals refer to the full libraries, not a claim that the free Standard archives contain every clip. Pricing is a dated observation.

Adobe's [Mixamo distribution FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400?lang=en) distinguishes finished projects from redistribution of raw character/animation files. Do not treat permission to use a clip in a commercial game as permission to bundle the raw clip in a public engine library. A skeleton with Mixamo-compatible naming does not by itself make its animations Adobe assets or establish their license.

## Retargeting plan

The canonical engine interface should use a humanoid bone map, separate from each provider's naming. Godot's `BoneMap` and `SkeletonProfileHumanoid` support this workflow; bone rest orientation, proportions and position tracks need treatment in addition to names. Keep Tessa's current skin and remap animations to it, rather than swapping in a library mannequin. [Godot 4.3 retargeting documentation](https://docs.godotengine.org/en/4.3/tutorials/assets_pipeline/retargeting_3d_skeletons.html).

1. Inventory the downloaded archive and license; record hashes and original clip names.
2. Test one idle, forward/backward walk, sword strike, block, hit reaction and death on Tessa. Include hand contact and coat deformation in visual acceptance.
3. Bake to the existing body aliases or adapt the presentation interface to a normalized profile. Preserve unmapped finger/accessory joints deliberately.
4. Tag clips by gameplay purpose, weapon grip, loop, root policy, windup/contact/recovery events, blend group, and left/right foot phase. Keep gameplay damage authoritative in the combat engine.
5. Add locomotion blends and action states; replace procedural attack poses clip by clip. A library alone does not supply transitions, correct weapon contact, hit timing or AI decisions.
6. Run floor-contact, loop-seam, missing-bone, root-drift, grip-distance and required-action checks. Preview the resulting performance on every distinct body shape.

## Teaching use

The first lesson can let students select a character and a small action set, then run the pipeline and inspect the playable result. A later lesson exposes the bone map, rest pose, root motion, skin weights, blending and gameplay event timing. Present a failed retargeting example alongside the corrected version: it makes clear why a convincing model, a skeleton, a motion clip and an animation controller are separate parts.

## Current game boundary

[The integrated Meshy rig](../party-assets-20261028/README.md) has 72 joints; the previous stand-in has 19 body bones. Its Walk now comes from the CC0 library, with anatomical reference calibration, floor correction, measured stride distance and phase alignment to the retained Meshy Run. [Source manifest, license, build commands and teaching notes](../../tools/rigging/sources/quaternius/README.md). The provider file contains no attacks, blocks, hits or deaths. Those remain procedural in the current game even though suitable source clips are now available for future adaptation. Mara and Ivo still use local stand-in rigs and require separate skin/hand review.
