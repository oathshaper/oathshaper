# Party weapon derivatives

Current distribution status: the [2026-11-03 Meshy rights review](../README.md) supersedes earlier provisional Meshy-permission caveats in these import notes. The owner confirmed paid/private generation; official terms permit distribution of that output. Third-party notices remain applicable.

Prepared from the owner's October 28 Meshy downloads by `tools/rigging/import_party_assets.py` with Blender 5.0.1. Original downloads remain untouched. [manifest.json](manifest.json) records source names/hashes, derivative hashes, geometry and embedded image hashes, including the separately stored Tessa rig.

| Runtime asset | Source filename | Triangles | Physical size |
| --- | --- | ---: | --- |
| sabre | Meshy_AI_Curved_Saber_1028144210_texture.glb | 8,000 | 0.90m long |
| buckler | Meshy_AI_Bronze_Guardian_Shiel_1028144226_texture.glb | 10,000 | 0.42m diameter |
| staff | Meshy_AI_Crystalwood_Staff_1028144234_texture.glb | 6,000 | 1.75m long |
| mace | Meshy_AI_Ironclad_Mace_1028144203_texture.glb | 8,000 | 0.65m long |

All original embedded texture payloads are byte-identical in the derivatives. The duplicate saber download with `(1)` in its name was identical and was not imported twice. `.tscn` wrappers provide `PrimaryGrip` and impact points; the staff also provides `SupportGrip`. Dimensions are in metres, independent of actor scale.

Tessa uses `Meshy_AI_Emerald_Pathfinder_All_Animations.glb` as her source. It includes the matching 8K texture and 72-joint skin, so the separate static 8K and high-density exports are not needed at runtime. See [integration and limitations](../../../../docs/party-assets-20261028/README.md).

These are owner-supplied Meshy assets. The existing [asset provenance statement](../README.md) applies; this import does not assign the code license or the CC0 license of unrelated animation libraries to these meshes.
