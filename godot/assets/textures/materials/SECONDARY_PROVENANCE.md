# Secondary environment material maps

Created 2026-10-21 with the built-in OpenAI image generation tool. These are original generated PNG color/albedo maps, each 1254 × 1254 pixels. No stock textures or third-party image files were used. The project concepts `docs/images/lantern-quay-meshy-environment-concept.png` and `docs/images/lantern-garden-meshy-concept.png` were inspected for palette and material context; they were not submitted as image-generation inputs. The maps have no authored normal, roughness, metallic, or displacement channels.

| File | Intended use | Orientation |
| --- | --- | --- |
| `slate_roof_albedo.png` | Quay buildings and beacon roofs | Shingle courses run horizontally |
| `coastal_rock_albedo.png` | Modeled sea wall bases and shoreline stone | Direction independent fine basalt |
| `grass_soil_albedo.png` | Fallback garden planting-bed ground | Direction independent |
| `weathered_timber_albedo.png` | Crates, doors, and short beams | Planks run vertically |
| `braided_rope_albedo.png` | Post wraps and dock rope details | Twisted strands run vertically |
| `sailcloth_canvas_albedo.png` | Awnings and cargo canvas | Fine plain weave |

The prompts requested seamless repetition. Visual 2 × 2 repeat previews were inspected for all six maps. Exact pixel-for-pixel edge continuity was not certified; inspect long or high-tiling surfaces in the engine before treating them as mathematically seamless. The selected coastal rock map uses fine basalt grain instead of large cobbles because the finer pattern repeated more cleanly and lets the mesh supply the block shapes.

## Final prompts

### `slate_roof_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: dark slate roof tiles for the lantern quay buildings and beacon roof
Subject: many small, overlapping coastal slate shingles viewed perfectly straight-on from above, arranged in uniform horizontal courses with subtly irregular hand-cut edges and thin mortar-dark gaps
Style/medium: physically based game material source, detailed painterly realism consistent with a warm nautical fantasy environment
Color palette: blue-black, charcoal, muted slate gray, slight salt-weathered cool highlights; avoid pure black
Lighting: flat even diffuse light, no directional shadows, reflections, ambient occlusion, or vignette
Composition: full-frame orthographic surface texture, square; seamless tile at left/right and top/bottom edges, natural variation without a central focal feature
Constraints: color/albedo only; no normal/depth/roughness map, no perspective, no objects, no scenery, no text, no border, no watermark
```

### `coastal_rock_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: dark coastal basalt stone surface, for modeled sea wall blocks at a nautical fantasy harbor
Subject: continuous fine-grained blue-charcoal stone with many small natural flecks, narrow hairline fractures, restrained salt weathering and scarce muted olive lichen specks; no individual rocks or block outlines
Style/medium: detailed painterly realism with clear PBR game-material texture
Composition: perfectly flat orthographic square surface, evenly distributed microtexture, mathematically seamless-looking continuity across each opposing edge; no central feature, no large motifs
Lighting: uniform diffuse studio illumination; base color only, no directional shadows, specular highlights, ambient occlusion, vignette or baked edge shading
Constraints: no cobbles, pebbles, big cracks, mortar, shoreline scene, water, foam, text, border, logo, watermark, normal/height/roughness map
```

### `grass_soil_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: coastal garden ground, a natural grass and soil blend for the lantern garden planting beds
Subject: sparse, short olive-green and muted sage grass clumps interspersed with exposed dry umber sandy soil and a few tiny pale grit flecks; mixed at fine scale so repeated beds do not form obvious large patches
Style/medium: detailed painterly realism consistent with a warm nautical fantasy environment
Composition: perfectly overhead orthographic, full-bleed square surface, genuinely seamless at all four edges, distributed stochastic fine detail with no central subject
Lighting: neutral, even diffuse illumination; base color only, no cast shadows, specular highlights, ambient occlusion, or vignette
Constraints: no individual tall plants, leaves, flowers, trees, paths, cobbles, water, text, border, logo, or watermark; no normal, height, or roughness map
```

### `weathered_timber_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: weathered timber for crates, doors, and short railing beams at a nautical fantasy harbor
Subject: several broad upright oak planks with dark narrow joints, visible warm brown grain, restrained knots, small cracks and salt-worn softened edges; durable working timber, no metal hardware
Style/medium: detailed painterly realism with readable PBR game-material texture
Composition: perfectly front-facing orthographic full-frame square surface, vertical planks continuing seamlessly left/right and top/bottom, regular enough for repetition but with understated per-plank variation
Lighting: flat, even diffuse illumination; base color only, no cast shadows, specular highlights, ambient occlusion, or vignette
Color palette: warm tobacco-brown and umber, some desaturated driftwood gray highlights, dark joints
Constraints: no furniture, crates as objects, handles, hinges, nails, text, border, logo, or watermark; no normal, height, or roughness map
```

### `braided_rope_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: thick braided mooring rope texture for post wraps and dock rail details
Subject: close-up continuous twisted natural hemp cord, repeating vertical strands with a clear diagonal lay, individually visible fibers but no separated rope objects or background
Style/medium: detailed painterly realism with clean game-material readability
Composition: perfectly flat, front-facing orthographic square surface covered edge-to-edge by the braid pattern; the fiber structure is seamlessly repeatable on every edge with no focal point
Lighting: flat even diffuse illumination; base color only, no cast shadows, specular highlights, ambient occlusion, or vignette
Color palette: muted golden flax, sandy beige, weathered tawny brown
Constraints: no rope coil, knots, posts, dock, water, text, border, logo, or watermark; no normal, height, or roughness map
```

### `sailcloth_canvas_albedo.png`

```text
Use case: stylized-concept
Asset type: square repeatable albedo/base-color texture for a Godot 3D environment material
Primary request: sailcloth canvas for subtle harbor awning and bundled cargo material
Subject: tight plain-weave natural linen or heavy cotton, dense visible crossing fibers, slight uneven yarn thickness and salt-weathered discoloration, no illustration or pattern
Style/medium: detailed painterly realism with PBR game-material clarity
Composition: perfectly flat, front-facing orthographic square surface, seamless at all four edges, fine weave filling the frame evenly without a focal mark
Lighting: flat even diffuse illumination; base color only, no cast shadows, specular highlights, ambient occlusion, or vignette
Color palette: warm ivory, muted flax cream and sandy beige, understated umber wear
Constraints: no folds, drape, sail shape, seams, stitches, eyelets, objects, text, border, logo, or watermark; no normal, height, or roughness map
```
