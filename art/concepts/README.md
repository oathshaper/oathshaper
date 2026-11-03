# Oathshaper concept references

Current distribution status: the [2026-11-03 Meshy rights review](../../godot/assets/meshes/README.md) supersedes earlier provisional Meshy-permission caveats in these import notes. The owner confirmed paid/private generation; official terms permit distribution of that output. Third-party notices remain applicable.

These are original 1024×1536 RGBA concept images generated with OpenAI image generation from Oathshaper-specific prompts on 2026-10-19 and 2026-10-20. No reference prototype, BioWare, or third-party images were supplied to generate them. The PNGs are modeling references, not runtime meshes, textures, or rigs. The [2026-10-20 character prompts](character-prompts.md) record the exact new image requests. User-supplied Meshy GLBs for Mara, Ivo, and the lantern tower are imported separately; see [their provenance and limits](../../godot/assets/meshes/README.md).

| File | Intended role | Approximate in-game scale |
| --- | --- | --- |
| `mara-meshy-reference.png` | Mara, harbor lantern keeper; full-body neutral pose | 1.7 m tall |
| `ivo-meshy-reference.png` | Ivo, tide-gate keeper; full-body neutral pose | 1.8 m tall |
| `lantern-tower-meshy-reference.png` | Civic-court landmark; single freestanding structure | About 14 m tall, 4×4 m base |
| `player-meshy-reference.png` | Player wayfarer; clear A-pose for later humanoid rigging | About 1.7 m tall |
| `civic-clerk-meshy-reference.png` | Civic clerk; clear A-pose for future model and rig | About 1.7 m tall |
| `vendor-meshy-reference.png` | West-market vendor; clear A-pose for future model and rig | About 1.75 m tall |

The generated images have transparent margins. Inspect any resulting 3D model for unwanted background geometry, hand/face topology, UVs, rigging, and texture quality before replacing more Godot placeholders. The hub loads `godot/assets/meshes/lantern_tower.glb` in place of `LandmarkTower/TowerArt`; its collision and light remain separate. Character model slots load `godot/assets/meshes/{player,mara,ivo,clerk,vendor}.glb` and preserve scene collision, interaction, and labels. Mara and Ivo have supplied models; the player, clerk, and vendor retain primitive art until modeled. The [rigging guide](../../docs/rigging.md) defines the expected skeleton and animation clips. Exact generation inputs were not independently inspected; owner-confirmed paid/private generation and official distribution terms are recorded in the current Meshy rights review.
