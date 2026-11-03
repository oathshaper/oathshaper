"""Build the shorter civic beacon from the owner's original Meshy GLB.

Run: blender --background --python scripts/build_tower_variant.py

The source remains untouched.  Its door and stone plinth gain 18% height; the
long shaft is compressed enough to keep the lantern roof at the same 10.63 m
placed height.  Godot supplies width, grounding, and collision.
"""

import hashlib
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "godot/assets/meshes/lantern_tower.glb"
OUTPUT = ROOT / "godot/assets/meshes/lantern_tower_civic.glb"
SOURCE_SHA256 = "74406720a6aaeef3a465cfcebea08439735bb81c6694aedc56bdc638b194a4fe"

# Source mesh uses centred, normalized Meshy coordinates.  The lower joint is
# above the door/plinth; the upper joint is just below the lantern room.  The
# shaft factor compensates for the taller base, keeping total height fixed.
SHAFT_BOTTOM = -0.22
SHAFT_TOP = 0.32
SOURCE_BOTTOM = -0.47582998871803284
BASE_HEIGHT_FACTOR = 1.18
SHAFT_HEIGHT_FACTOR = 0.55 - (SHAFT_BOTTOM - SOURCE_BOTTOM) * (BASE_HEIGHT_FACTOR - 1.0) / (SHAFT_TOP - SHAFT_BOTTOM)


def fit_tower(y: float) -> float:
    if y <= SHAFT_BOTTOM:
        return SOURCE_BOTTOM + (y - SOURCE_BOTTOM) * BASE_HEIGHT_FACTOR
    base_top = SOURCE_BOTTOM + (SHAFT_BOTTOM - SOURCE_BOTTOM) * BASE_HEIGHT_FACTOR
    if y <= SHAFT_TOP:
        return base_top + (y - SHAFT_BOTTOM) * SHAFT_HEIGHT_FACTOR
    shaft_top = base_top + (SHAFT_TOP - SHAFT_BOTTOM) * SHAFT_HEIGHT_FACTOR
    return shaft_top + (y - SHAFT_TOP)


if hashlib.sha256(SOURCE.read_bytes()).hexdigest() != SOURCE_SHA256:
    raise RuntimeError("Tower source changed; review the fit before rebuilding")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
if len(meshes) != 1:
    raise RuntimeError(f"Expected one source tower mesh, found {len(meshes)}")

for vertex in meshes[0].data.vertices:
    # Blender is Z-up; the source GLB's vertical Y imports as Blender Z.
    vertex.co.z = fit_tower(vertex.co.z)
meshes[0].data.update()

bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT),
    export_format="GLB",
    export_apply=True,
    export_materials="EXPORT",
)
print(f"Built {OUTPUT} from {SOURCE}")
