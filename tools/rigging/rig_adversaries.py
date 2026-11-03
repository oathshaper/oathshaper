"""Author modest in-place skins and clips for the static Meshy adversaries.

blender -b --python-exit-code 1 --python tools/rigging/rig_adversaries.py
These are local prototype rigs, not animations supplied by Meshy. Combat rules
remain host-owned; the host samples Idle, Walk, Strike and Hit by simulation time.
"""
import sys
import math
import json
import hashlib
import struct
from pathlib import Path
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from rig_characters import add_bone, build_armature, skin_mesh, stabilize_coat_weights, make_action, ground_action

OUT = Path(__file__).resolve().parents[2] / "godot/assets/meshes/adversaries"
SOURCE = Path(__file__).resolve().parents[2] / "target/adversary-meshes"

def mechanical_rig(mesh, kind):
    data = bpy.data.armatures.new("AdversaryRig")
    arm = bpy.data.objects.new("AdversaryRig", data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = data.edit_bones
    add_bone(bones, "Hips", (0, 0, 0), (0, 0, .25))
    if kind == "iron_sentinel":
        add_bone(bones, "Head", (0, -.43, .18), (0, -.88, .25), "Hips")
        add_bone(bones, "Tail", (0, .50, .24), (0, .9, .32), "Hips")
        limbs = [(f"{side}{end}", x, y) for side, x in [("L", .23), ("R", -.23)] for end, y in [("Front", -.45), ("Rear", .48)]]
        for name, x, y in limbs:
            add_bone(bones, name + "Upper", (x, y, .16), (x, y + .035, -.18), "Hips")
            add_bone(bones, name + "Lower", (x, y + .035, -.18), (x, y, -.48), name + "Upper")
            add_bone(bones, name + "Foot", (x, y, -.48), (x, y - .1, -.54), name + "Lower")
    else:
        add_bone(bones, "Head", (0, 0, .12), (0, 0, .90), "Hips")
        limbs = [("L", .48, -.25), ("R", -.48, -.25), ("Rear", 0, .50)]
        for name, x, y in limbs:
            add_bone(bones, name + "Upper", (x*.7, y*.7, -.12), (x*1.25, y*1.2, -.50), "Hips")
            add_bone(bones, name + "Lower", (x*1.25, y*1.2, -.50), (x*1.38, y*1.30, -.87), name + "Upper")
            add_bone(bones, name + "Foot", (x*1.38, y*1.30, -.87), (x*1.40, y*1.5, -.94), name + "Lower")
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.data.bones:
        mesh.vertex_groups.new(name=bone.name)
    segments = {b.name: (b.head_local.copy(), b.tail_local.copy()) for b in arm.data.bones}
    def distance(point, name):
        a, b = segments[name]
        d = b-a
        return (point - (a + d * max(0, min(1, (point-a).dot(d)/d.length_squared)))).length
    for vertex in mesh.data.vertices:
        p = vertex.co
        candidates = ["Hips"]
        if kind == "iron_sentinel":
            if p.y < -.40 and p.z > -.12: candidates += ["Head"]
            elif p.y > .55 and p.z > .12: candidates += ["Tail"]
            if p.z < .10:
                limb = ("L" if p.x >= 0 else "R") + ("Front" if p.y < 0 else "Rear")
                candidates += [limb+x for x in ["Upper", "Lower", "Foot"]]
        else:
            if p.z > -.10: candidates += ["Head"]
            if p.z < .0:
                limb = min(limbs, key=lambda v: (p.x-v[1])**2+(p.y-v[2])**2)[0]
                candidates += [limb+x for x in ["Upper", "Lower", "Foot"]]
        nearest = sorted([(distance(p, n), n) for n in candidates])[:2]
        weights = [(math.exp(-d*26), n) for d, n in nearest]
        total = sum(w for w, _ in weights)
        for w, name in weights:
            mesh.vertex_groups[name].add([vertex.index], w/total, "REPLACE")
    mesh.parent = arm
    modifier = mesh.modifiers.new("Weighted adversary skin", "ARMATURE")
    modifier.object = arm
    return arm, [v[0] for v in limbs]

def inspect(path):
    data = path.read_bytes()
    n = struct.unpack_from("<I", data, 12)[0]
    g = json.loads(data[20:20+n])
    blob = data[28+n:]
    textures = []
    for image in g["images"]:
        view = g["bufferViews"][image["bufferView"]]
        textures.append(hashlib.sha256(blob[view.get("byteOffset", 0):view.get("byteOffset", 0)+view["byteLength"]]).hexdigest())
    return {"bytes":len(data), "sha256":hashlib.sha256(data).hexdigest(), "skin_bones":len(g["skins"][0]["joints"]) if g.get("skins") else 0,
            "animations":[a["name"] for a in g.get("animations", [])], "image_sha256":sorted(textures)}

OUT.mkdir(parents=True, exist_ok=True)
manifest = json.loads((SOURCE / "manifest.json").read_text())
for kind in ["lantern_sentinel", "iron_sentinel", "crimson_corsair"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / (kind + ".glb")), merge_vertices=True)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if kind == "crimson_corsair":
        mesh.scale = (.5, .5, .5)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        low = min(v.co.z for v in mesh.data.vertices)
        height = max(v.co.z for v in mesh.data.vertices)-low
        arm = build_armature(low, height)
        skin_mesh(mesh, arm)
        stabilize_coat_weights(mesh, player=True)
        limbs = []
    else:
        arm, limbs = mechanical_rig(mesh, kind)
        low = min(v.co.z for v in mesh.data.vertices)
    bpy.context.scene.render.fps = 24
    def pose(phase, moving=False, attack=0.0, hit=0.0):
        s = math.sin(phase)
        if kind == "crimson_corsair":
            return {"Spine":(-hit*7, attack*10, s*.35), "Chest":(0, attack*12, 0),
                    "LUpperArm":(-s*10 if moving else 5, 0, 12), "RUpperArm":((s*10 if moving else 8)+attack*46, 0, -12),
                    "RForearm":(20+attack*24, 0, 0), "LForearm":(12, 0, 0),
                    "LUpperLeg":(s*18 if moving else 0,0,0), "RUpperLeg":(-s*18 if moving else 0,0,0),
                    "LLowerLeg":(max(0,s)*12 if moving else 0,0,0), "RLowerLeg":(max(0,-s)*12 if moving else 0,0,0)}
        result = {"Head":(attack*9-hit*5, 0, s*(1 if not moving else .3)), "Hips":(-hit*4,0,0)}
        for i, limb in enumerate(limbs):
            cycle = math.sin(phase + (math.pi if i in [1,2] else 0)) if len(limbs) == 4 else math.sin(phase+i*math.tau/3)
            result[limb+"Upper"] = ((cycle*15 if moving else 0),0,0)
            result[limb+"Lower"] = ((max(0,-cycle)*18 if moving else 0),0,0)
            result[limb+"Foot"] = ((-cycle*5 if moving else 0),0,0)
        return result
    clips = [make_action(arm,"Idle",[(f,pose((f-1)*math.tau/144)) for f in range(1,146,12)]),
             make_action(arm,"Walk",[(f,pose((f-1)*math.tau/24,True)) for f in range(1,26,3)]),
             make_action(arm,"Strike",[(f,pose(0,attack=a)) for f,a in [(1,0),(5,-.4),(10,1),(17,0)]]),
             make_action(arm,"Hit",[(f,pose(0,hit=a)) for f,a in [(1,0),(4,1),(10,0)]])]
    for clip in clips: ground_action(mesh,arm,clip,low)
    for track in arm.animation_data.nla_tracks: track.mute = True
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True); arm.select_set(True)
    path = OUT / (kind + "_rigged.glb")
    bpy.ops.export_scene.gltf(filepath=str(path),export_format="GLB",use_selection=True,export_skins=True,export_animations=True,
        export_animation_mode="NLA_TRACKS",export_force_sampling=True,export_frame_range=False,export_morph=False)
    info = inspect(path)
    assert info["image_sha256"] == manifest[kind]["original"]["image_sha256"]
    manifest[kind]["authored_rig"] = info
    print("RIG", kind, json.dumps(info), flush=True)
(OUT/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
