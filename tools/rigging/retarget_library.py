"""Bake CC0 Quaternius motions onto the party's existing skins (Blender 5).

blender -b --python-exit-code 1 --python tools/rigging/retarget_library.py
The default output is a comparison asset, never the live player asset.
"""

from pathlib import Path
import json
import math
import sys
import statistics
import tempfile
import os
import bpy
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from import_party_assets import inspect

SOURCE = ROOT / "tools/rigging/sources/quaternius/UAL1_Standard.glb"
CHARACTER = sys.argv[sys.argv.index("--character")+1] if "--character" in sys.argv else "player"
assert CHARACTER in ["player", "mara", "ivo"]
TARGET = ROOT / f"godot/assets/meshes/rigged/{CHARACTER}_rigged.glb"
DEST = Path(sys.argv[sys.argv.index("--output")+1]) if "--output" in sys.argv else ROOT / f".artifacts/animation-library/{CHARACTER}_library_candidate.glb"
PARTY = CHARACTER != "player"
INSTALL_ALL = "--install-party" in sys.argv
INSTALL_RUN = "--install-run" in sys.argv
INSTALL = "--install-walk" in sys.argv or INSTALL_RUN or "--install-party" in sys.argv
INSTALL_CLIP = "Run" if INSTALL_RUN else "Walk"
if INSTALL:
    DEST = TARGET
MAP = {
    "pelvis": "Hips",
    "spine_01": "Spine",
    "spine_02": "Torso",
    "spine_03": "Chest",
    "neck_01": "Neck",
    "Head": "Head",
}
for side, long, short in [("l", "Left", "L"), ("r", "Right", "R")]:
    for a, b in [
        ("clavicle", "Clavicle"),
        ("upperarm", "UpperArm"),
        ("lowerarm", "Forearm"),
        ("hand", "Hand"),
        ("thigh", "UpperLeg"),
        ("calf", "LowerLeg"),
        ("foot", "Foot"),
    ]:
        MAP[a + "_" + side] = short + b


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path), merge_vertices=True)
    objects = set(bpy.data.objects) - before
    return next(o for o in objects if o.type == "ARMATURE"), objects


def bind(arm, action):
    arm.animation_data_create()
    arm.animation_data.action = action
    if action.slots:
        arm.animation_data.action_slot = action.slots[0]


def curves(action):
    return [
        f
        for layer in action.layers
        for strip in layer.strips
        for bag in strip.channelbags
        for f in bag.fcurves
    ]


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
target, target_objects = load(TARGET)
baseline_info = inspect(TARGET)
original_actions = {a.name: a for a in bpy.data.actions}
# Missing intermediate spine bones are valid on the compact NPC rigs.
MAP = {source: name for source, name in MAP.items() if name in target.data.bones}
for obj in target_objects:
    if obj.animation_data:
        obj.animation_data_clear()
for b in target.pose.bones:
    b.matrix_basis.identity()
source, source_objects = load(SOURCE)
source_actions = {
    a.name: a for a in bpy.data.actions if a.name not in ["Idle", "Walk", "Run"]
}
source.animation_data_clear()
target.animation_data_create()
bpy.context.view_layer.update()
mesh = next(o for o in target_objects if o.type == "MESH" and len(o.vertex_groups) > 0)

if CHARACTER == "mara" and "--repair-coat" in sys.argv:
    from rig_characters import stabilize_rear_coat_weights
    stabilize_rear_coat_weights(mesh)

# Pose-space rotations are relative to a calibrated anatomical reference,
# not interchangeable Euler angles or matching bone names. Preserve target
# roll and skin bind matrices; only swing limb axes to the donor reference.
reference = {}
for sb, tb in MAP.items():
    s, t = source.data.bones[sb], target.data.bones[tb]
    q = t.matrix_local.to_quaternion()
    if any(k in tb for k in ["UpperArm", "Forearm", "Hand", "UpperLeg", "LowerLeg"]):
        q = (t.tail_local - t.head_local).rotation_difference(
            s.tail_local - s.head_local
        ) @ q
    if tb in ["LFoot", "RFoot"] and not PARTY:
        q = (
            Quaternion(Vector((0, 0, 1)), math.radians(-10 if tb == "LFoot" else 12))
            @ q
        )
    if PARTY and tb in ["LUpperLeg", "RUpperLeg"]:
        # Generated NPC meshes have a wider source stance. Adduct the thigh,
        # keeping the calf reference vertical instead of bowing the whole leg.
        q = Quaternion(Vector((0, 1, 0)), math.radians(6 if tb == "LUpperLeg" else -6)) @ q
    if PARTY and tb in ["LFoot", "RFoot"]:
        q = Quaternion(Vector((0, 0, 1)), math.radians(-8 if tb == "LFoot" else 8)) @ q
    reference[tb] = q

rest_local = {
    b.name: (
        b.parent.matrix_local.inverted() @ b.matrix_local
        if b.parent
        else b.matrix_local
    ).to_quaternion()
    for b in target.data.bones
}
source_hip = source.data.bones["pelvis"].head_local.copy()
leg_scale = (
    target.data.bones["LUpperLeg"].length + target.data.bones["LLowerLeg"].length
) / (source.data.bones["thigh_l"].length + source.data.bones["calf_l"].length)
groups = {
    g.index
    for g in mesh.vertex_groups
    if g.name in ["LFoot", "RFoot"] or "Toe" in g.name
}
soles = [
    v.index
    for v in mesh.data.vertices
    if sum(g.weight for g in v.groups if g.group in groups) > 0.5
]
floor_z = min((mesh.matrix_world @ mesh.data.vertices[i].co).z for i in soles) if PARTY else -0.475
report = {
    "source": str(SOURCE.relative_to(ROOT)),
    "source_sha256": inspect(SOURCE)["sha256"],
    "license": "CC0-1.0",
    "map": MAP,
    "clips": {},
}
feet = {}
for side, long in [("L", "Left"), ("R", "Right")]:
    indices = {
        g.index
        for g in mesh.vertex_groups
        if g.name == side + "Foot" or long + "Toe" in g.name
    }
    feet[side] = [
        v.index
        for v in mesh.data.vertices
        if sum(g.weight for g in v.groups if g.group in indices) > 0.5
    ]
# Some compact skins assign the whole boot to the shin. Use an anatomical
# sole sample in that case rather than silently installing an ungrounded gait.
for side in feet:
    if not feet[side]:
        low = min((mesh.matrix_world @ v.co).z for v in mesh.data.vertices)
        feet[side] = [v.index for v in mesh.data.vertices
                      if (mesh.matrix_world @ v.co).z < low + .06
                      and (mesh.matrix_world @ v.co).x * (1 if side == "L" else -1) > .025]
        assert feet[side], "No sole vertices for " + side
soles = sorted(set(soles).union(*feet.values()))
if PARTY: floor_z = min((mesh.matrix_world @ mesh.data.vertices[i].co).z for i in soles)
for output, clip in [
    ("Idle", "Idle_Loop"),
    ("Walk", "Walk_Loop"),
    ("Run", "Jog_Fwd_Loop"),
]:
    if ((PARTY or INSTALL_ALL) and output == "Idle") or (INSTALL and not INSTALL_ALL and not PARTY and output != INSTALL_CLIP):
        action = original_actions[output]
        track = target.animation_data.nla_tracks.new()
        track.name = output
        strip = track.strips.new(output, 0, action)
        strip.action_frame_start, strip.action_frame_end = action.frame_range
        track.mute = True
        continue
    donor = source_actions[clip]
    bind(source, donor)
    first, last = map(round, donor.frame_range)
    samples = []
    for frame in range(first, last + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        samples.append(
            (
                {
                    tb: source.pose.bones[sb].matrix.to_quaternion()
                    @ source.data.bones[sb].matrix_local.to_quaternion().inverted()
                    @ reference[tb]
                    for sb, tb in MAP.items()
                },
                source.pose.bones["pelvis"].head.copy(),
                min(
                    source.pose.bones["foot_l"].head.z,
                    source.pose.bones["foot_r"].head.z,
                ),
            )
        )
    action = bpy.data.actions.new("Library_" + output)
    bind(target, action)
    lifts = []
    contacts = []
    for frame, (world, hip, source_floor) in enumerate(samples):
        bpy.context.scene.frame_set(frame)
        solved = {}
        for b in target.pose.bones:
            b.matrix_basis.identity()
            b.rotation_mode = "QUATERNION"
            parent = solved[b.parent.name] if b.parent else Quaternion()
            if b.name in world:
                b.rotation_quaternion = (
                    rest_local[b.name].inverted() @ parent.inverted() @ world[b.name]
                )
            solved[b.name] = parent @ rest_local[b.name] @ b.rotation_quaternion
        # In-place body: lateral sway and vertical movement, never forward root travel.
        delta = (hip - source_hip) * leg_scale
        delta.y = 0
        hb = target.pose.bones["Hips"]
        hb.location = target.data.bones["Hips"].matrix_local.to_3x3().inverted() @ delta
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        low = min((evaluated.matrix_world @ deformed.vertices[i].co).z for i in soles)
        sole_heights = {
            side: min(
                (evaluated.matrix_world @ deformed.vertices[i].co).z for i in indices
            )
            for side, indices in feet.items()
        }
        evaluated.to_mesh_clear()
        # Preserve airborne portions of the donor jog; walk keeps a support foot.
        flight = (
            max(0, source_floor - min(s[2] for s in samples)) * leg_scale
            if output == "Run"
            else 0
        )
        floor = floor_z + flight * target.matrix_world.to_scale().z
        lift = floor - low
        lifts.append(lift * 2)
        hb.location += target.data.bones["Hips"].matrix_local.to_3x3().inverted() @ (
            target.matrix_world.to_3x3().inverted() @ Vector((0, 0, lift))
        )
        contacts.append(
            {
                side: {
                    "height": (height + lift - floor_z) * 2,
                    "travel": (
                        target.matrix_world @ target.pose.bones[side + "Foot"].head
                    ).y
                    * 2,
                }
                for side, height in sole_heights.items()
            }
        )
        for b in target.pose.bones:
            b.keyframe_insert("rotation_quaternion", frame=frame, group=b.name)
            b.keyframe_insert("location", frame=frame, group=b.name)
        # Assignments above are computed from absolute poses before any new keys.
    for f in curves(action):
        for key in f.keyframe_points:
            key.interpolation = "LINEAR"
    if (INSTALL_ALL or PARTY) and output == "Run" or (INSTALL and not INSTALL_ALL and not PARTY):
        # Both clips must put the same leg forward at the same normalized phase.
        # Match the new loop to the retained gait before the runtime crossfade.
        count = len(samples) - 1
        poses = []
        walk_gap = []
        run_gap = []
        for frame in range(count):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            poses.append(
                {
                    b.name: (b.location.copy(), b.rotation_quaternion.copy())
                    for b in target.pose.bones
                }
            )
            walk_gap.append(
                target.pose.bones["LFoot"].head.y - target.pose.bones["RFoot"].head.y
            )
        run = baked_walk if INSTALL_ALL or PARTY else original_actions["Walk" if INSTALL_RUN else "Run"]
        bind(target, run)
        for frame in range(count):
            at = (
                run.frame_range[0]
                + (run.frame_range[1] - run.frame_range[0]) * frame / count
            )
            bpy.context.scene.frame_set(int(at), subframe=at % 1)
            bpy.context.view_layer.update()
            run_gap.append(
                target.pose.bones["LFoot"].head.y - target.pose.bones["RFoot"].head.y
            )
        walk_gap = [v / max(abs(x) for x in walk_gap) for v in walk_gap]
        run_gap = [v / max(abs(x) for x in run_gap) for v in run_gap]
        errors = [
            sum(
                (walk_gap[(f + offset) % count] - run_gap[f]) ** 2 for f in range(count)
            )
            / count
            for offset in range(count)
        ]
        offset = min(range(count), key=lambda i: errors[i])
        bind(target, action)
        for frame in range(count + 1):
            for name, (location, rotation) in poses[(frame + offset) % count].items():
                bone = target.pose.bones[name]
                bone.location = location
                bone.rotation_quaternion = rotation
                bone.keyframe_insert("location", frame=frame, group=name)
                bone.keyframe_insert("rotation_quaternion", frame=frame, group=name)
        report["run_walk_phase" if INSTALL_RUN or INSTALL_ALL or PARTY else "walk_run_phase"] = {
            "run_offset" if INSTALL_RUN or INSTALL_ALL or PARTY else "walk_offset": offset / count,
            "normalized_leg_gap_mse_before": errors[0],
            "normalized_leg_gap_mse_after": errors[offset],
        }
    if output == "Walk": baked_walk = action
    target.animation_data.action = None
    track = target.animation_data.nla_tracks.new()
    track.name = output
    strip = track.strips.new(output, 0, action)
    strip.action_frame_start = 0
    strip.action_frame_end = len(samples) - 1
    track.mute = True
    report["clips"][output] = {
        "donor": clip,
        "seconds": (len(samples) - 1) / 30,
        "sole_correction_metres": [min(lifts), max(lifts)],
    }
    velocities = [
        (b[side]["travel"] - a[side]["travel"]) * 30
        for a, b in zip(contacts, contacts[1:])
        for side in feet
        if max(a[side]["height"], b[side]["height"]) < 0.025
        and b[side]["travel"] > a[side]["travel"]
    ]
    if output != "Idle" and velocities:
        report["clips"][output]["cycle_distance_metres"] = round(
            statistics.median(velocities) * (len(samples) - 1) / 30, 3
        )

if PARTY and "Talk" in original_actions:
    target.animation_data.action = None
    track = target.animation_data.nla_tracks.new()
    track.name = "Talk"
    action = original_actions["Talk"]
    strip = track.strips.new("Talk", 0, action)
    strip.action_frame_start, strip.action_frame_end = action.frame_range
    track.mute = True

for o in source_objects:
    bpy.data.objects.remove(o, do_unlink=True)
for b in target.pose.bones:
    b.matrix_basis.identity()
bpy.context.scene.frame_set(0)
DEST.parent.mkdir(parents=True, exist_ok=True)
fd, temporary = tempfile.mkstemp(suffix=".glb", dir=DEST.parent)
os.close(fd)
bpy.ops.export_scene.gltf(
    filepath=temporary,
    export_format="GLB",
    export_image_format="AUTO",
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_force_sampling=True,
    export_frame_range=False,
    export_morph=False,
)
result = inspect(Path(temporary))
if INSTALL:
    assert report["clips"][INSTALL_CLIP].get("cycle_distance_metres", 0) > .1, "No grounded stride samples; do not install"
assert baseline_info["image_sha256"] == result["image_sha256"], (
    "Embedded texture payloads changed"
)
assert baseline_info["joints"] == result["joints"], "Target skeleton changed"
assert baseline_info["triangles"] == result["triangles"], "Target geometry changed"
DEST.parent.mkdir(parents=True, exist_ok=True)
os.replace(temporary, DEST)
report_path = DEST.with_suffix(".retarget.json")
if INSTALL and report_path.exists():
    previous = json.loads(report_path.read_text())
    report["clips"] = {**previous.get("clips", {}), **report["clips"]}
    for key in ([] if INSTALL_ALL else ["walk_run_phase", "run_walk_phase"]):
        if key in previous and key not in report:
            report[key] = previous[key]
report_path.write_text(json.dumps(report, indent=2) + "\n")
if INSTALL and (PARTY or INSTALL_ALL):
    motion = {"run_speed_threshold": 2.8, "reference_height_metres": 2.0 if PARTY else 1.9}
    for clip in ["Walk", "Run"]:
        motion[clip.lower()+"_cycle_distance"] = report["clips"][clip]["cycle_distance_metres"]
        motion[clip.lower()+"_source"] = "Quaternius UAL1 / " + report["clips"][clip]["donor"] + " (CC0)"
    TARGET.with_suffix(".motion.json").write_text(json.dumps(motion, indent=2)+"\n")
elif INSTALL:
    motion = json.loads(TARGET.with_suffix(".motion.json").read_text())
    motion[INSTALL_CLIP.lower() + "_cycle_distance"] = report["clips"][INSTALL_CLIP]["cycle_distance_metres"]
    motion[INSTALL_CLIP.lower() + "_source"] = "Quaternius UAL1 / " + report["clips"][INSTALL_CLIP]["donor"] + " (CC0)"
    TARGET.with_suffix(".motion.json").write_text(json.dumps(motion, indent=2) + "\n")
if INSTALL and CHARACTER == "player":
    path = ROOT / "godot/assets/meshes/equipment/manifest.json"
    manifest = json.loads(path.read_text())
    manifest["assets"]["tessa"]["game_mesh"] = result
    for clip in (["walk", "run"] if INSTALL_ALL else [INSTALL_CLIP.lower()]):
        manifest["assets"]["tessa"][clip + "_retarget"] = report
    path.write_text(json.dumps(manifest, indent=2) + "\n")
print("RETARGET", json.dumps(report), flush=True)
