# Lantern Quay textures

Current distribution status: the [2026-11-03 Meshy rights review](../meshes/README.md) supersedes earlier provisional Meshy-permission caveats in these import notes. The owner confirmed paid/private generation; official terms permit distribution of that output. Third-party notices remain applicable.

The scene's authored dock and building surfaces use the [generated material maps](materials/README.md): dock planks, limestone paving, two-course seawall masonry, roof slate, timber, rope, rock, and sailcloth. Grass and soil, foliage, and bark maps remain for the garden blockout fallback. The [imported Seaside Garden](../meshes/README.md#seaside-garden) uses its owner's three embedded JPEG material maps. The original 64 px placeholder tiles and the in-code dock/paver image generators have been retired. Godot repeats the generated maps by surface size with mipmaps; floors, barriers, buildings, and interactables retain scene-owned collision. The material README records map prompts and provenance. No reference prototype assets were copied.

## Stonewatch Beacon atlas extracts

The three JPEGs under `tower/` are **byte-for-byte extractions**, without
cropping or re-encoding, from the owner-supplied
[`lantern_tower.glb`](../meshes/lantern_tower.glb) (`Meshy_AI_Stonewatch_Beacon_1020143106_texture.glb`).
The source GLB SHA-256 is
`74406720a6aaeef3a465cfcebea08439735bb81c6694aedc56bdc638b194a4fe`.
Run [`scripts/extract_tower_textures.py`](../../../scripts/extract_tower_textures.py)
to verify that source hash and rebuild the exact payloads.

| Embedded role | File | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Base color | `tower/stonewatch_base_color.jpg` | 3,076,940 | `498dfaa1910026c0b4d97a96dceaa2cc83c20fc1de63cdab6d549a9d454204c5` |
| Metallic/roughness | `tower/stonewatch_metallic_roughness.jpg` | 1,826,911 | `c30a1125d6ccd2c950ca4826f5b9814258f835e26daca7a584b4edc99ad1d6e1` |
| Tangent-space normal | `tower/stonewatch_normal.jpg` | 2,295,292 | `73c4ff0df18adc8f7fe020bfcdd17d8983daac8316748d3e0160fa2ed282e518` |

Each is a 2048 × 2048 packed UV atlas for that particular tower mesh. The
whole image would put doors, lanterns, and other unrelated islands across a
box facade. [`tower_atlas_stone.gdshader`](../../shaders/tower_atlas_stone.gdshader)
samples only two coherent stone regions: a dark 36 × 240 pixel strip on the
archive's lower corner buttresses and a pale 62 × 300 pixel strip on the
records-door jambs, upper archive corner piers, and quay-facing market piers.
Each region appears once per narrow face at approximately its source
aspect. [`tower_facade_bricks.gdshader`](../../shaders/tower_facade_bricks.gdshader)
samples six 51 × 23 pixel patches within the coherent pale stone column of
that same base-color atlas for the larger building facades. It lays out
staggered 1 × 0.5 m blocks in shader space with narrow mortar joints and
stable per-block variation. Market, archive, lantern-room fallback, and distant
buildings use the same actual tower stone with different restrained tints;
there is no newly encoded derivative image or atlas-wide tiling. Other quay
surfaces use the separately generated material maps. The extracted normal and
metallic/roughness maps are preserved for authoring, while the box supports
and facades use base color only; their box tangents do not match the tower's.
The imported tower continues to use all three embedded maps itself.

These extracts inherit the source GLB's rights. The current Meshy rights review records the paid/private generation and distribution permission. The newly generated environment maps above have separate
provenance and are not extractions from the tower GLB.
