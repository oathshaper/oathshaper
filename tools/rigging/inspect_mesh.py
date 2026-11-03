"""Inspect the three source GLBs with Blender's real glTF importer.

Run: blender -b --python tools/rigging/inspect_mesh.py -- path/to/model.glb
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector


def main() -> None:
    source = Path(sys.argv[sys.argv.index("--") + 1])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=True)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    print(f"SOURCE {source.name} objects={len(meshes)}")
    for obj in meshes:
        corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        lower = [min(c[i] for c in corners) for i in range(3)]
        upper = [max(c[i] for c in corners) for i in range(3)]
        print(f"MESH {obj.name} verts={len(obj.data.vertices)} faces={len(obj.data.polygons)} bbox={lower}..{upper} transform={obj.matrix_world[:]}")
        print(f"MATERIALS {[mat.name if mat else None for mat in obj.data.materials]} UVS {len(obj.data.uv_layers)}")
        for fraction in (0.02, 0.08, 0.18, 0.28, 0.38, 0.48, 0.58, 0.68, 0.78, 0.88, 0.98):
            y = lower[1] + fraction * (upper[1] - lower[1])
            ys = [obj.matrix_world @ v.co for v in obj.data.vertices if abs((obj.matrix_world @ v.co).y - y) < 0.012]
            if ys:
                print(f"SLICE {fraction:.2f} y={y:.3f} count={len(ys)} x={min(v.x for v in ys):.3f}..{max(v.x for v in ys):.3f} z={min(v.z for v in ys):.3f}..{max(v.z for v in ys):.3f}")


if __name__ == "__main__":
    main()
