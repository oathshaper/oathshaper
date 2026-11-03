"""Make bounded game meshes from the owner's dense Meshy exports.

blender -b --python-exit-code 1 --python tools/rigging/prepare_adversaries.py -- /path/to/downloads
The originals are read only; their UVs and embedded material images are retained.
"""
from pathlib import Path
import json
import hashlib
import struct
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
# Intermediate static derivatives stay outside Godot and release exports.
OUT = ROOT / "target/adversary-meshes"
ASSETS = {
    "lantern_sentinel": ("Meshy_AI_Lantern_Sentinel_1022201654_texture.glb", 60000),
    "iron_sentinel": ("Meshy_AI_Iron_Sentinel_1022202019_texture.glb", 60000),
    "crimson_corsair": ("Meshy_AI_Crimson_Corsair_1022202011_texture.glb", 45000),
}

def inspect(path):
    data = path.read_bytes()
    n = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20+n])
    blob = data[28+n:]
    images = []
    for image in g.get("images", []):
        view = g["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        images.append(hashlib.sha256(blob[start:start+view["byteLength"]]).hexdigest())
    return {
        "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data),
        "triangles": sum(g["accessors"][p["indices"]]["count"]//3 for m in g["meshes"] for p in m["primitives"]),
        "vertices": sum(g["accessors"][p["attributes"]["POSITION"]]["count"] for m in g["meshes"] for p in m["primitives"]),
        "skins": len(g.get("skins", [])), "animations": len(g.get("animations", [])),
        "image_sha256": sorted(images),
    }

source = Path(sys.argv[sys.argv.index("--") + 1]).expanduser()
OUT.mkdir(parents=True, exist_ok=True)
manifest = {}
for key, (filename, target) in ASSETS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src = source / filename
    bpy.ops.import_scene.gltf(filepath=str(src), merge_vertices=True)
    mesh = next(x for x in bpy.context.scene.objects if x.type == "MESH")
    mesh.name = key
    bpy.context.view_layer.objects.active = mesh
    modifier = mesh.modifiers.new("Game mesh budget", "DECIMATE")
    modifier.ratio = min(1.0, target / len(mesh.data.polygons))
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    dest = OUT / (key + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format="GLB", export_image_format="AUTO", export_animations=False, export_yup=True)
    original, derivative = inspect(src), inspect(dest)
    assert original["image_sha256"] == derivative["image_sha256"], "Embedded textures must remain byte identical"
    manifest[key] = {"source": filename, "original": original, "game_mesh": derivative}
    print("ASSET", key, json.dumps(manifest[key]), flush=True)
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
