"""Build small, reproducible skinned animation prototypes from Meshy GLBs.

Run from the repository root:
    blender -b --python-exit-code 1 --python tools/rigging/rig_characters.py -- clerk
    blender -b --python-exit-code 1 --python tools/rigging/rig_characters.py -- vendor
    blender -b --python-exit-code 1 --python tools/rigging/rig_characters.py -- mara
    blender -b --python-exit-code 1 --python tools/rigging/rig_characters.py -- ivo

Blender 5.0.1 is the validated authoring version. Source GLBs are untouched.
This is a deliberately simple first-pass rig, with human review still required
for coat deformation and motion polish.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree


REPO = Path(__file__).resolve().parents[2]
SOURCE_DIR = REPO / "godot/assets/meshes"
OUTPUT_DIR = SOURCE_DIR / "rigged"
# Tessa now uses the supplied Meshy skin/animations. Keep the old prototype
# authoring functions for reference, but don't overwrite her provider rig.
PARTS = ("clerk", "vendor", "mara", "ivo")


def add_bone(edit_bones, name, head, tail, parent=None):
    bone = edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    if parent is not None:
        bone.parent = edit_bones[parent]
    return bone


def build_armature(z_min: float, height: float, character: str = "") -> bpy.types.Object:
    """Fit a human skeleton to the Meshy characters' near-identical bounds."""
    def z(fraction: float) -> float:
        return z_min + height * fraction

    data = bpy.data.armatures.new("Humanoid")
    arm = bpy.data.objects.new("Humanoid", data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bones = data.edit_bones
    add_bone(bones, "Hips", (0, 0, z(.40)), (0, 0, z(.52)))
    add_bone(bones, "Spine", (0, 0, z(.52)), (0, 0, z(.65)), "Hips")
    add_bone(bones, "Chest", (0, 0, z(.65)), (0, 0, z(.77)), "Spine")
    add_bone(bones, "Neck", (0, 0, z(.77)), (0, 0, z(.82)), "Chest")
    add_bone(bones, "Head", (0, 0, z(.82)), (0, 0, z(.99)), "Neck")
    for side, sign in (("L", 1), ("R", -1)):
        # Source-space landmarks from the actual meshes. The generic wrists
        # were below Ivo's fingertips, leaving his hands weighted to forearms.
        arm_fit = {
            "ivo": [(sign * .115, 0, .245), (sign * .150, -.035 if side == "L" else .080, .115),
                    (sign * .170, -.095 if side == "L" else .092, .030),
                    (sign * .174, -.103 if side == "L" else .075, -.030)],
            "mara": [(sign * .118, .005, .240), (sign * .183, .005, .135),
                     (sign * .229, -.008, .050), (sign * .245, -.018, -.025)],
        }.get(character)
        shoulder, elbow, wrist, fingers = arm_fit or [
            (sign * .13, 0, z(.74)), (sign * .17, 0, z(.56)),
            (sign * .21, 0, z(.43)), (sign * .22, 0, z(.33))]
        add_bone(bones, f"{side}Clavicle", (sign * .055, 0, z(.75)),
                 shoulder, "Chest")
        add_bone(bones, f"{side}UpperArm", shoulder, elbow, f"{side}Clavicle")
        add_bone(bones, f"{side}Forearm", elbow, wrist, f"{side}UpperArm")
        add_bone(bones, f"{side}Hand", wrist, fingers, f"{side}Forearm")
        add_bone(bones, f"{side}UpperLeg", (sign * .077, 0, z(.41)),
                 (sign * .085, 0, z(.26)), "Hips")
        add_bone(bones, f"{side}LowerLeg", (sign * .085, 0, z(.26)),
                 (sign * .085, 0, z(.085)), f"{side}UpperLeg")
        add_bone(bones, f"{side}Foot", (sign * .085, 0, z(.085)),
                 (sign * .085, -.06, z(.025)), f"{side}LowerLeg")
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


def skin_mesh(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    raw = [[(group.group, group.weight) for group in vert.groups if group.weight > 0]
           for vert in mesh.data.vertices]
    covered = sum(bool(entries) for entries in raw)
    if covered != len(raw):
        # Bone heat misses small disconnected details (buttons, hair and trim)
        # in these generated meshes. Copy weights from the closest skinned
        # surface point instead of letting the details remain static in space.
        tree = KDTree(covered)
        for index, entries in enumerate(raw):
            if entries:
                tree.insert(mesh.data.vertices[index].co, index)
        tree.balance()
        farthest = 0.0
        for index, entries in enumerate(raw):
            if entries:
                continue
            _, donor, distance = tree.find(mesh.data.vertices[index].co)
            raw[index] = list(raw[donor])
            farthest = max(farthest, distance)
        print(f"REPAIRED unweighted={len(raw) - covered} nearest_max_distance={farthest:.4f}")
        if farthest > .08:
            raise RuntimeError("Unweighted geometry too far from skinned surface")
    # glTF supports four influences in one JOINTS_0/WEIGHTS_0 set. Prune and
    # normalize explicitly to avoid exporter-dependent truncation.
    for index, entries in enumerate(raw):
        strongest = sorted(entries, key=lambda pair: pair[1], reverse=True)[:4]
        total = sum(weight for _, weight in strongest)
        if total <= 0:
            raise RuntimeError(f"Vertex {index} has zero skin weight")
        original_groups = {entry.group for entry in mesh.data.vertices[index].groups}
        for group_index in original_groups:
            mesh.vertex_groups[group_index].remove([index])
        for group_index, weight in strongest:
            mesh.vertex_groups[group_index].add([index], weight / total, "REPLACE")
    final = [sum(entry.weight for entry in vert.groups) for vert in mesh.data.vertices]
    print(f"WEIGHTS vertices={len(final)} covered={sum(weight > 0 for weight in final)} min={min(final):.4f} max={max(final):.4f} groups={len(mesh.vertex_groups)}")
    if not any(mod.type == "ARMATURE" and mod.object == arm for mod in mesh.modifiers):
        raise RuntimeError("No armature modifier after automatic weighting")


def stabilize_coat_weights(mesh: bpy.types.Object, player: bool = False, character: str = "") -> None:
    """Keep coat tails from following nearby forearm bones.

    Automatic bone heat assigns some coat vertices near the source A-pose
    hands to arm bones. The lower garment is part of the main connected mesh,
    so select its waist-and-skirt region by position, leaving the outer arm
    line alone, and transfer only the stray arm weight to the torso.
    """
    groups = {group.name: group for group in mesh.vertex_groups}
    arm_names = ("LUpperArm", "RUpperArm", "LForearm", "RForearm", "LHand", "RHand")
    arm_indices = {groups[name].index for name in arm_names}
    hand_indices = {groups[name].index for name in ("LHand", "RHand")}
    hips = groups["Hips"]
    spine = groups["Spine"]
    repaired = 0
    arm = next(mod.object for mod in mesh.modifiers if mod.type == "ARMATURE")
    for vertex in mesh.data.vertices:
        point = mesh.matrix_world @ vertex.co
        lower, upper = (-0.24, 0.02) if player else (-0.16, 0.10)
        if character == "mara": lower, upper = -.34, .14
        width = .215 if character == "mara" and point.z < .035 else .19
        if not (lower < point.z < upper and abs(point.x) < width):
            continue
        if character != "mara" and abs(point.x) > 0.15 and abs(point.y) < 0.045:
            continue  # Sleeve, forearm, and hand near the side of the body.
        transfer = 1.0
        if character == "mara":
            # Keep sleeve/skin vertices with the arm, including the inner
            # elbow. A rectangular coat mask cut across that curved surface.
            for name in arm_names:
                bone = arm.data.bones[name]
                a, b = arm.matrix_world @ bone.head_local, arm.matrix_world @ bone.tail_local
                axis = b - a
                nearest = a + axis * max(0, min(1, (point-a).dot(axis) / axis.length_squared))
                radius = .048 if "UpperArm" in name else .030
                transfer = min(transfer, max(0, min(1, ((point-nearest).length-radius) / .025)))
            if transfer <= 0: continue
        original = {entry.group: entry.weight for entry in vertex.groups}
        if not player and character != "mara" and any(original.get(index, 0.0) > 0.01 for index in hand_indices):
            continue
        hips_weight = original.get(hips.index, 0.0)
        spine_weight = original.get(spine.index, 0.0)
        torso_weight = hips_weight + spine_weight
        if torso_weight < 0.05 and character != "mara":
            continue  # Actual hands have arm weights but no torso anchor.
        arm_weight = sum(entry.weight for entry in vertex.groups if entry.group in arm_indices) * transfer
        if arm_weight < 0.05:
            continue
        for name in arm_names:
            if transfer >= 1:
                groups[name].remove([vertex.index])
            elif original.get(groups[name].index, 0) > 0:
                groups[name].add([vertex.index], original[groups[name].index] * (1-transfer), "REPLACE")
        hips_share = hips_weight / torso_weight if torso_weight > .001 else (1.0 if point.z < 0 else 0.0)
        hips.add([vertex.index], hips_weight + arm_weight * hips_share, "REPLACE")
        if spine_weight > 0 or hips_share < 1:
            spine.add([vertex.index], spine_weight + arm_weight * (1.0 - hips_share), "REPLACE")
        repaired += 1
    print(f"STABILIZED coat_vertices={repaired}")


def stabilize_rear_coat_weights(mesh):
    """Keep the rear coat panel from folding independently with each shin.

    This is a smooth source-space garment mask, not a runtime cloth solver.
    The hem retains a little thigh motion; boot/arm weights stay outside it.
    """
    groups = {g.name: g for g in mesh.vertex_groups}
    hips = groups["Hips"].index
    changed = 0
    def ramp(lo, hi, v):
        t = max(0., min(1., (v-lo)/(hi-lo)))
        return t*t*(3-2*t)
    for vertex in mesh.data.vertices:
        p = mesh.matrix_world @ vertex.co
        mask = ramp(-.245, -.19, p.z) * (1-ramp(-.065, -.025, p.z))
        mask *= ramp(.015, .055, p.y) * (1-ramp(.15, .215, abs(p.x)))
        if mask <= .001: continue
        original = {g.group:g.weight for g in vertex.groups}
        thigh = groups["LUpperLeg" if p.x > 0 else "RUpperLeg"].index
        weights = {i:w*(1-mask) for i,w in original.items()}
        weights[hips] = weights.get(hips,0) + mask*.88
        weights[thigh] = weights.get(thigh,0) + mask*.12
        strongest = sorted(weights.items(),key=lambda x:x[1],reverse=True)[:4]
        total = sum(w for _,w in strongest)
        for i in original: mesh.vertex_groups[i].remove([vertex.index])
        for i,w in strongest: mesh.vertex_groups[i].add([vertex.index],w/total,"REPLACE")
        changed += 1
    print("COAT_PANEL stabilized_vertices="+str(changed))


def pose_at(
    arm: bpy.types.Object,
    frame: int,
    rotations: dict[str, tuple[float, float, float]],
    root_lift: float = 0.0,
) -> None:
    bpy.context.scene.frame_set(frame)
    for bone in arm.pose.bones:
        angles = rotations.get(bone.name, (0, 0, 0))
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = tuple(math.radians(a) for a in angles)
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)
    if root_lift:
        # The inward leg pose lowers the generated boots about 9 mm in model
        # space. Lift the rig inside its scene-owned root so grounding still
        # places their soles on the original floor plane.
        hips = arm.pose.bones["Hips"]
        hips.location = (0.0, root_lift, 0.0)
        hips.keyframe_insert(data_path="location", frame=frame, group="Hips")


def make_action(arm: bpy.types.Object, name: str, samples: list[tuple[int, dict]], root_lift: float = 0.0) -> bpy.types.Action:
    if arm.animation_data is None:
        arm.animation_data_create()
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    for frame, rotations in samples:
        pose_at(arm, frame, rotations, root_lift)
    action.use_frame_range = True
    action.frame_start = samples[0][0]
    action.frame_end = samples[-1][0]
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, samples[0][0], action)
    strip.action_frame_start = samples[0][0]
    strip.action_frame_end = samples[-1][0]
    strip.repeat = 1
    channel_count = sum(
        len(bag.fcurves)
        for layer in action.layers
        for strip in layer.strips
        for bag in strip.channelbags
    )
    print(f"ACTION {name} frames={samples[0][0]}..{samples[-1][0]} channels={channel_count}")
    if channel_count == 0:
        raise RuntimeError(f"{name} contains no bone keyframes")
    return action


def ground_action(mesh: bpy.types.Object, arm: bpy.types.Object, action: bpy.types.Action, floor_z: float) -> None:
    """Key hip height so one boot meets the authored floor each frame.

    Measure the evaluated skinned mesh at 24 fps with hip translation zero,
    then write only Hips location keys. This keeps the actor root stationary;
    Godot owns all world movement and collision.
    """
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    arm.animation_data.action = action
    if action.slots:
        arm.animation_data.action_slot = action.slots[0]
    hips = arm.pose.bones["Hips"]
    lifts = []
    for frame in range(int(action.frame_start), int(action.frame_end) + 1):
        bpy.context.scene.frame_set(frame)
        hips.location = (0.0, 0.0, 0.0)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        sole_z = min((evaluated.matrix_world @ vertex.co).z for vertex in deformed.vertices)
        evaluated.to_mesh_clear()
        lift = floor_z - sole_z
        hips.location = (0.0, lift, 0.0)
        hips.keyframe_insert(data_path="location", frame=frame, group="Hips")
        lifts.append(lift)
    arm.animation_data.action = None
    print(f"GROUNDED {action.name} frames={len(lifts)} hip_lift={min(lifts):.4f}..{max(lifts):.4f}")


def verify_player_gait(mesh: bpy.types.Object, arm: bpy.types.Object, action: bpy.types.Action, floor_z: float) -> None:
    """Check the evaluated Walk, including in-between frames, for straight boots.

    Check the skinned boot vertices as well as the knees and ankles. The Foot
    bone's tail is an arbitrary rig endpoint and does not describe where the
    actual textured boot points on this source mesh.
    """
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    arm.animation_data.action = action
    if action.slots:
        arm.animation_data.action_slot = action.slots[0]
    foot_regions = {}
    for side in ("L", "R"):
        foot_group = mesh.vertex_groups[f"{side}Foot"].index
        foot_ids = [
            vertex.index for vertex in mesh.data.vertices
            if any(group.group == foot_group and group.weight > 0.5 for group in vertex.groups)
        ]
        if len(foot_ids) < 20:
            raise RuntimeError(f"Too few weighted {side} boot vertices to verify Walk")
        rest_y = sorted(mesh.data.vertices[index].co.y for index in foot_ids)
        front_limit = rest_y[int(0.1 * len(rest_y))]
        rear_limit = rest_y[int(0.9 * len(rest_y))]
        foot_regions[side] = (
            foot_ids,
            [index for index in foot_ids if mesh.data.vertices[index].co.y <= front_limit],
            [index for index in foot_ids if mesh.data.vertices[index].co.y >= rear_limit],
        )
    min_ankle_lane = float("inf")
    min_boot_lane = float("inf")
    heading_ranges = {side: [float("inf"), -float("inf")] for side in ("L", "R")}
    max_knee_to_ankle = 0.0
    max_floor_error = 0.0
    for frame in range(int(action.frame_start), int(action.frame_end) + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        for side, sign in (("L", 1.0), ("R", -1.0)):
            knee = arm.matrix_world @ arm.pose.bones[f"{side}LowerLeg"].head
            ankle = arm.matrix_world @ arm.pose.bones[f"{side}Foot"].head
            min_ankle_lane = min(min_ankle_lane, sign * ankle.x)
            max_knee_to_ankle = max(max_knee_to_ankle, abs(knee.x - ankle.x))
            foot_ids, front_ids, rear_ids = foot_regions[side]
            min_boot_lane = min(
                min_boot_lane,
                *(sign * (evaluated.matrix_world @ deformed.vertices[index].co).x for index in foot_ids),
            )
            front = sum((evaluated.matrix_world @ deformed.vertices[index].co for index in front_ids), Vector()) / len(front_ids)
            rear = sum((evaluated.matrix_world @ deformed.vertices[index].co for index in rear_ids), Vector()) / len(rear_ids)
            heading = math.degrees(math.atan2(front.x - rear.x, rear.y - front.y))
            heading_ranges[side][0] = min(heading_ranges[side][0], heading)
            heading_ranges[side][1] = max(heading_ranges[side][1], heading)
        sole_z = min((evaluated.matrix_world @ vertex.co).z for vertex in deformed.vertices)
        evaluated.to_mesh_clear()
        max_floor_error = max(max_floor_error, abs(sole_z - floor_z))
    arm.animation_data.action = None
    print(
        f"GAIT ankle_lane_min={min_ankle_lane:.4f} boot_lane_min={min_boot_lane:.4f} "
        f"boot_heading_L={heading_ranges['L'][0]:.2f}..{heading_ranges['L'][1]:.2f} "
        f"boot_heading_R={heading_ranges['R'][0]:.2f}..{heading_ranges['R'][1]:.2f} "
        f"knee_ankle_max={max_knee_to_ankle:.4f} floor_error_max={max_floor_error:.5f}"
    )
    max_heading = max(abs(value) for bounds in heading_ranges.values() for value in bounds)
    if min_ankle_lane < 0.03 or min_boot_lane < 0.015 or max_heading > 5.0 or max_knee_to_ankle > 0.015 or max_floor_error > 0.002:
        raise RuntimeError("Player Walk crosses its boot lanes, toes outward, bows at the shins, or loses floor contact")


def idle_rotations(phase: float) -> dict[str, tuple[float, float, float]]:
    # One slow torso sway per eight beats, one breath per four. Keep the
    # pelvis and feet still; counterbalance the neck rather than nodding.
    # This must read at the exploration camera's distance, not just close up.
    sway = math.sin(phase)
    breath = .5 - .5 * math.cos(2 * phase)
    return {
        "Spine": (.20 * breath, 0, 2.1 * sway),
        "Chest": (-.70 * breath, 0, .9 * sway),
        "Neck": (0, 0, -.9 * sway),
        "Head": (0, 0, -.35 * sway),
        "LClavicle": (.45 * breath, 0, 0),
        "RClavicle": (-.45 * breath, 0, 0),
        "LUpperArm": (.20 * breath, 0, -.6 * sway),
        "RUpperArm": (-.20 * breath, 0, -.6 * sway),
    }


def walk_rotations(phase: float) -> dict[str, tuple[float, float, float]]:
    stride = math.sin(phase)
    bob = math.cos(2 * phase)
    return {
        "Hips": (1.5 * bob, 0, .7 * stride),
        "Spine": (-1.5 * bob, 0, -1.2 * stride),
        "Chest": (1.2 * bob, 0, -.8 * stride),
        "Head": (-.6 * bob, 0, .4 * stride),
        "LUpperLeg": (26 * stride, 0, 0),
        "RUpperLeg": (-26 * stride, 0, 0),
        "LLowerLeg": (20 * max(0, stride), 0, 0),
        "RLowerLeg": (20 * max(0, -stride), 0, 0),
        "LFoot": (-8 * stride, 0, 0),
        "RFoot": (8 * stride, 0, 0),
        "LUpperArm": (-18 * stride, 0, 0),
        "RUpperArm": (18 * stride, 0, 0),
        "LForearm": (8 + 4 * stride, 0, 0),
        "RForearm": (8 - 4 * stride, 0, 0),
    }


def talk_rotations(phase: float) -> dict[str, tuple[float, float, float]]:
    gesture = .5 - .5 * math.cos(2 * phase)
    result = idle_rotations(phase)
    result.update({
        "Head": (.20 * gesture, 0, result["Head"][2]),
        "RUpperArm": (2 * gesture, 0, result["RUpperArm"][2]),
        "RForearm": (6 * gesture, 0, 0),
    })
    return result


def player_standing_rotations(phase: float, walking: bool = False) -> dict[str, tuple[float, float, float]]:
    """Bring the Corsair's source A-pose into a relaxed, narrow stance.

    Apply the same rest correction throughout both clips. Otherwise the arms
    and boots pop back out to the generated source pose on the first walk frame.
    Local bone Z rotates each limb toward the body with this fitted skeleton.
    Counter-rotate the shins to keep the knees and ankles in parallel lanes.
    The source boots themselves toe outward, so correct their local heading
    independently of the thigh and shin alignment.
    """
    rotations = walk_rotations(phase) if walking else idle_rotations(phase)
    corrections = {
        "LUpperArm": 21.0,
        "RUpperArm": -21.0,
        "LForearm": 7.0,
        "RForearm": -7.0,
        "LUpperLeg": 14.0,
        "RUpperLeg": -14.0,
        "LLowerLeg": -14.0,
        "RLowerLeg": 14.0,
        "LFoot": 12.0,
        "RFoot": -13.0,
    }
    for bone, correction in corrections.items():
        x, y, z = rotations.get(bone, (0.0, 0.0, 0.0))
        rotations[bone] = (x, y, z + correction)
    return rotations


def mara_standing_rotations(phase: float, talking: bool = False, walking: bool = False) -> dict[str, tuple[float, float, float]]:
    """Adduct Mara's source A-pose limbs around weighted arm and leg joints.

    These are local bone Z rotations: with the fitted bone rolls, positive is
    inward on her left and negative is inward on her right. The forearms need
    less correction because the upper-arm rotation also carries their joints.
    """
    rotations = walk_rotations(phase) if walking else talk_rotations(phase) if talking else idle_rotations(phase)
    corrections = {
        "LUpperArm": 20.0,
        "RUpperArm": -20.0,
        "LForearm": 8.0,
        "RForearm": -8.0,
        "LUpperLeg": 9.0,
        "RUpperLeg": -9.0,
    }
    for bone, correction in corrections.items():
        x, y, z = rotations.get(bone, (0.0, 0.0, 0.0))
        rotations[bone] = (x, y, z + correction)
    return rotations


NPC_STANDING_CORRECTIONS = {
    "clerk": {"LUpperArm": 22.0, "RUpperArm": -22.0, "LForearm": 8.0, "RForearm": -8.0,
              "LUpperLeg": 1.0, "RUpperLeg": -1.0,
              "LLowerLeg": 6.0, "RLowerLeg": -6.0, "LFoot": -6.0, "RFoot": 6.0},
    "vendor": {"LUpperArm": 20.0, "RUpperArm": -20.0, "LForearm": 7.0, "RForearm": -7.0,
               "LUpperLeg": 1.0, "RUpperLeg": -1.0,
               "LLowerLeg": 6.0, "RLowerLeg": -6.0, "LFoot": -6.0, "RFoot": 6.0},
    "ivo": {"LUpperArm": 5.0, "RUpperArm": -5.0, "LForearm": 0.0, "RForearm": 0.0,
            "LUpperLeg": 5.0, "RUpperLeg": -5.0},
}


def npc_standing_rotations(name: str, phase: float, talking: bool = False, walking: bool = False) -> dict[str, tuple[float, float, float]]:
    """Keep each stationary NPC's rest correction in both Idle and Talk."""
    rotations = walk_rotations(phase) if walking else talk_rotations(phase) if talking else idle_rotations(phase)
    for bone, correction in NPC_STANDING_CORRECTIONS[name].items():
        x, y, z = rotations.get(bone, (0.0, 0.0, 0.0))
        rotations[bone] = (x, y, z + correction)
    return rotations


def export_character(name: str) -> None:
    source = SOURCE_DIR / f"{name}.glb"
    target = OUTPUT_DIR / f"{name}_rigged.glb"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(source), merge_vertices=True)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"Expected one source mesh, got {len(meshes)}")
    mesh = meshes[0]
    mesh.name = f"{name.capitalize()}Mesh"
    corners = [mesh.matrix_world @ Vector(corner) for corner in mesh.bound_box]
    low = min(c.z for c in corners)
    high = max(c.z for c in corners)
    arm = build_armature(low, high - low, name)
    skin_mesh(mesh, arm)
    if name in {"player", "clerk", "vendor", "mara", "ivo"}:
        stabilize_coat_weights(mesh, player=name == "player", character=name)
        if name == "mara": stabilize_rear_coat_weights(mesh)
    scene = bpy.context.scene
    scene.render.fps = 24
    # 58–69 beats/minute, eight beats per sway, four per breath. Individual
    # tempos avoid a synchronized crowd. Talk keeps the same slow body rhythm.
    frames_per_beat = {"player": 22, "mara": 23, "ivo": 25, "clerk": 24, "vendor": 21}[name]
    idle_end = 1 + 8 * frames_per_beat
    idle_frames = sorted(set(range(1, idle_end + 1, 3)) | {idle_end})
    idle_pose = mara_standing_rotations if name == "mara" else player_standing_rotations if name == "player" else (lambda phase: npc_standing_rotations(name, phase))
    idle = make_action(arm, "Idle", [(frame, idle_pose(2 * math.pi * (frame - 1) / (idle_end - 1))) for frame in idle_frames], 0.009 if name == "mara" else 0.0035 if name == "player" else 0.0)
    if name in NPC_STANDING_CORRECTIONS:
        ground_action(mesh, arm, idle, low)
    if name == "player":
        walk_frames = [1, 7, 13, 19, 25]
        walk = make_action(
            arm,
            "Walk",
            [(frame, player_standing_rotations(2 * math.pi * i / 4, walking=True)) for i, frame in enumerate(walk_frames)],
        )
        ground_action(mesh, arm, walk, low)
        verify_player_gait(mesh, arm, walk, low)
    else:
        talk_frames = idle_frames
        talk_pose = (lambda phase: mara_standing_rotations(phase, talking=True)) if name == "mara" else (lambda phase: npc_standing_rotations(name, phase, talking=True))
        talk = make_action(arm, "Talk", [(frame, talk_pose(2 * math.pi * (frame - 1) / (idle_end - 1))) for frame in talk_frames], 0.009 if name == "mara" else 0.0)
        if name in NPC_STANDING_CORRECTIONS:
            ground_action(mesh, arm, talk, low)
    if name in {"mara", "ivo"}:
        walk_pose = (lambda phase: mara_standing_rotations(phase, walking=True)) if name == "mara" else (lambda phase: npc_standing_rotations(name, phase, walking=True))
        walk = make_action(arm, "Walk", [(frame, walk_pose(2 * math.pi * (frame - 1) / 32)) for frame in range(1, 34, 2)])
        ground_action(mesh, arm, walk, low)
    scene.frame_set(1)
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_frame_range=False,
        export_morph=False,
    )
    print(f"EXPORTED {target} bytes={target.stat().st_size}")


def main() -> None:
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else list(PARTS)
    if not names or any(name not in PARTS for name in names):
        raise SystemExit(f"Choose from {PARTS}. For Tessa use import_party_assets.py -- ~/Downloads tessa")
    for name in names:
        export_character(name)


if __name__ == "__main__":
    main()
