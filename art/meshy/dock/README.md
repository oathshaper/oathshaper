# Market Bridge dock references

For a single-image Meshy trial, start with [`05-polished-single-view.png`](05-polished-single-view.png). It is a 1536 × 1024 RGBA concept render of the dock piece, generated with Codex's built-in image generation tool on 2026-10-20 by editing `03-northeast-quarter.png`. It adds wood grain, fasteners, and other artistic detail; use the four exact Godot renders below to check its proportions. It is an image, not an imported mesh or a verified 4K texture. If Meshy's batch mode makes one model per uploaded image, upload this one image for one dock model; combine the four measured views only in a workflow that explicitly supports multiple views of the same object.

The exact image-edit prompt was:

> Transform the supplied orthographic Godot dock render into a polished stylized 3D game asset concept while preserving its exact camera and geometry. One rectangular 4 m by 6 m plank deck; two opposite parallel waist-high timber parapets with narrow rope bands; both short ends open for walking through. Keep the width, wall spacing and three-quarter view recognizable from the reference. Add believable hand-crafted wood grain, gentle weathering, restrained brass-dark rope brackets, muted warm harbor colors. Deliberately modest early-2000s 3D RPG style with clean textures. Single isolated object on a truly transparent background, centered with full silhouette and generous margins. Soft even studio light; no ground plane. No people, boats, buildings, water, sky, fog, lamps, crates, posts, extra rails, side platforms, text, logo, watermark.

These four 2048 × 2048 PNGs show **one** existing 3D segment of Lantern Quay from
four complementary cameras. It is the `MarketBridge` floor and its two parallel
timber seawalls at world X `-12…-8`, Z `-2…4`. The deck is 4 m × 6 m with two open
ends; each wall is 4 m long, 0.85 m high, capped in timber, with a shallow rope
band on both faces. The floor top is at world Y `0.2 m`. The views are:

1. `01-south-face.png` — low view of the timber face and rope band.
2. `02-west-end.png` — open end, deck width, and wall spacing.
3. `03-northeast-quarter.png` — both walls, deck planks, and overall shape.
4. `04-overhead.png` — exact deck footprint and edge placement.

All four were captured from the same Godot 4.3 scene geometry with fixed
lighting, orthographic cameras, a plain background, and no HUD, characters,
water, buildings, or tower. The script hides unrelated district visuals for
capture; it does not move or remodel the bridge. Recreate the images with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path godot \
  --rendering-method gl_compatibility \
  --script res://tools/capture_meshy_dock.gd
```

For a Meshy image-to-3D run, submit the four images together if the chosen
workflow accepts multiple views. Use `03-northeast-quarter.png` as the primary
view otherwise, with the other three as shape references. A useful prompt is:

> Reconstruct a single modular timber dock connector from these four views.
> Preserve the 4 m × 6 m planked deck, two opposing 4 m timber parapets, rope
> bands, and open ends. Keep the muted wood colors. Add no people, buildings,
> water, text, lamps, or extra rails.

These are geometry references, not a finished asset specification. The existing
Godot deck uses a single box primitive, tiled plank pixels, and non-colliding
rope strips. A generated mesh may invent joinery, underside structure, or
texture detail; inspect its silhouette, scale, UVs, texture resolution, and
collision before replacing the project geometry. Exporting a 4K texture is a
separate Meshy setting or export choice; 2048 px reference images do not by
themselves guarantee 4K output.

The measured geometry and textures are original Oathshaper placeholders from
[`hub_environment.gd`](../../../godot/scripts/hub_environment.gd) and the
[hub texture generator](../../../godot/assets/textures/README.md). No
reference prototype assets or third-party reference images were used for these captures or the polished concept. The captures are reproducible project artifacts; the generated concept is an art-direction reference. Any Meshy-generated replacement needs its own source and reuse-rights record before distribution.
