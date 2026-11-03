# Lantern Quay material maps

Current distribution status: the [2026-11-03 Meshy rights review](../../meshes/README.md) supersedes earlier provisional Meshy-permission caveats in these import notes. The owner confirmed paid/private generation; official terms permit distribution of that output. Third-party notices remain applicable.

These albedo PNGs were generated for Oathshaper on 2026-10-21 with the built-in OpenAI image generator. They replace the original 64 px arithmetic-pattern placeholders and the in-code dock and paver tiles. Godot uses linear filtering, generated mipmaps, and UV repetition on scene-owned geometry. There are no authored normal, roughness, height, or metallic maps in this set. The prompts asked for seamless textures, but pixel-perfect edge continuity has not been certified; the actual 1280 × 800 engine captures are the visual check.

| Map | Dimensions | Runtime surface | Prompt brief |
| --- | ---: | --- | --- |
| `dock_planks_albedo.png` | 1254 × 1254 | Central quay and bridges | Top-down weathered brown planks, staggered joints, small nails, flat light |
| `limestone_pavers_albedo.png` | 1254 × 1254 | Court, market, bluff, office floor, fallback garden path | Top-down irregular warm cream limestone setts, restrained gray stones, flat light |
| `seawall_masonry_albedo.png` | 2048 × 768 | Pale parapet course and dark tidal course | Front-on horizontal ashlar wall, cream upper stones, dark wet lower stones, no rail or scene |
| `coastal_foliage_albedo.png` | 1254 × 1254 | Fallback garden tree crowns and bed foliage | Dense muted sage and olive coastal broadleaves, no tree silhouette |
| `coastal_bark_albedo.png` | 1254 × 1254 | Fallback garden tree trunks | Vertical warm gray-brown fibrous bark with subtle lichen, no trunk silhouette |
| `coastal_grass_albedo.png` | 1254 × 1254 | Fallback walkable garden ground | Top-down short dense muted olive and sage coastal grass, tiny soil gaps, flat light |

The dock, paver, and seawall prompts used the in-repository [Lantern Quay environment concept](../../../../docs/images/lantern-quay-meshy-environment-concept.png) for palette and construction reference; the pavers also used the [Lantern Garden concept](../../../../docs/images/lantern-garden-meshy-concept.png). The foliage, bark, and grass prompts were text-only. No texels were extracted from a Meshy GLB for these six maps. The concepts are separate generated art references, and the Meshy rights review records distribution permission for the owner-supplied GLBs. The other six maps and their exact generation prompts are recorded in [SECONDARY_PROVENANCE.md](SECONDARY_PROVENANCE.md).

These color maps cover original Godot geometry outside the imported garden and its blockout fallback. The current garden uses its owner's embedded GLB maps instead. The fitted garden floor, bridge, and minimap coordinates are documented in the [district map](../../../../docs/hub-map.md); scene-owned colliders and barriers still govern movement. The Stonewatch tower and facade shaders use a different, owner-supplied texture source; see [the parent texture README](../README.md#stonewatch-beacon-atlas-extracts).
