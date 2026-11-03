# Party weapon references

Original concept images generated on 2026-10-27 with the built-in image generation tool. Exact prompts are in [prompts.json](prompts.json). These are image-to-mesh references; they have not replaced the in-game equipment yet.

Upload each PNG separately to Meshy. Return the textured GLBs for fitting to the party's hands.

| Image | Used by | Target size | Attachment |
| --- | --- | --- | --- |
| [Harbor sabre](harbor-sabre.png) | Player | 0.90 m long | PrimaryGrip inside the leather handle |
| [Buckler](party-buckler.png) | Player and Ivo | 0.42 m diameter | PrimaryGrip at the rear central handgrip |
| [Ash staff](mara-ash-staff.png) | Mara | 1.75 m long | PrimaryGrip and SupportGrip on the two leather grip zones |
| [Guard mace](ivo-guard-mace.png) | Ivo | 0.65 m long | PrimaryGrip inside the leather handle |

## Import and fitting

The dimensions are intended physical sizes, not measurements of the images. Scale each imported model in metres. Keep the grips free of decorations and check that the sabre guard leaves room for fingers. The buckler image shows its face: its rear handgrip must be checked or added on the resulting mesh.

After import, add named Marker3D nodes to a weapon scene. The existing `equipment_mount.gd` contract requires `PrimaryGrip`, plus `SupportGrip` for the staff. Align the grip orientation with the character hand, check both hands through attack and idle poses, then set the scene path in `godot/content/equipment_mounts.json`. Mesh generation alone does not supply these verified attachment points.

Optional impact markers can identify the blade/head contact points (`ImpactTip`, `ImpactBase`) and the shield centre (`GuardCenter`). The images contain no hands, characters, lettering, or scenery that should become part of the weapon mesh.
