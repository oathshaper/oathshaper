"""Prepare the owner's 2026-10-28 Meshy character and weapon exports.

Blender 5.0.1: blender -b --python-exit-code 1 --python
tools/rigging/import_party_assets.py -- ~/Downloads [tessa|weapons|all]
Sources are read-only. Textures, skin weights and finger bones are preserved.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import sys
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'godot/assets/meshes/equipment'
MANIFEST = OUT / 'manifest.json'
WEAPONS = {
    'sabre': ('Meshy_AI_Curved_Saber_1028144210_texture.glb', 8000, .90, .095),
    'buckler': ('Meshy_AI_Bronze_Guardian_Shiel_1028144226_texture.glb', 10000, .42, 0),
    'staff': ('Meshy_AI_Crystalwood_Staff_1028144234_texture.glb', 6000, 1.75, .77),
    'mace': ('Meshy_AI_Ironclad_Mace_1028144203_texture.glb', 8000, .65, .11),
}
BONES = {'Hips':'Hips', 'Spine':'Spine', 'Spine1':'Torso', 'Spine2':'Chest', 'Neck':'Neck', 'Head':'Head'}
for side, prefix in [('Left','L'), ('Right','R')]:
    for source, target in [('Shoulder','Clavicle'), ('Arm','UpperArm'), ('ForeArm','Forearm'), ('Hand','Hand'), ('UpLeg','UpperLeg'), ('Leg','LowerLeg'), ('Foot','Foot')]:
        BONES[side + source] = prefix + target

def inspect(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    images = []
    for image in doc.get('images', []):
        view = doc['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        images.append(hashlib.sha256(binary[start:start + view['byteLength']]).hexdigest())
    return {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw),
            'triangles': sum(doc['accessors'][p['indices']]['count'] // 3 for m in doc['meshes'] for p in m['primitives']),
            'joints': sum(len(s['joints']) for s in doc.get('skins', [])),
            'animations': [a['name'] for a in doc.get('animations', [])], 'image_sha256': sorted(images)}

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = 30

def track(arm, action, name):
    action.name = name
    nla = arm.animation_data.nla_tracks.new()
    nla.name = name
    strip = nla.strips.new(name, 0, action)
    strip.action_frame_start, strip.action_frame_end = action.frame_range
    nla.mute = True

def bind_action(arm, action):
    arm.animation_data.action = action
    if action.slots: arm.animation_data.action_slot = action.slots[0]

def align_feet(arm, mesh, action, standing=False, running=False):
    """Correct toe splay and sole contact without replacing the provider gait.

    Rotations are in armature space, independent of imported bone rolls. Run
    keeps its flight phases; Walk and Idle keep at least one sole on the floor.
    """
    bind_action(arm, action)
    feet = {g.index for g in mesh.vertex_groups if g.name in ['LFoot', 'RFoot'] or 'Toe' in g.name}
    soles = [v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in feet) > .5]
    floor = -.475  # The slot doubles this centred .95m asset to 1.9m.
    inverse_hip_rest = arm.data.bones['Hips'].matrix_local.to_3x3().inverted()
    lifts = []
    samples = []
    for frame in range(round(action.frame_range[0]), round(action.frame_range[1]) + 1):
        bpy.context.scene.frame_set(frame)
        bpy.context.view_layer.update()
        samples.append((frame, {bone.name: bone.matrix_basis.copy() for bone in arm.pose.bones}))
    for frame, original in samples:
        bpy.context.scene.frame_set(frame)
        for name, matrix in original.items(): arm.pose.bones[name].matrix_basis = matrix
        bpy.context.view_layer.update()
        corrections = [('LFoot', 'Z', -10), ('RFoot', 'Z', 12)]
        if standing:
            corrections = [('LUpperLeg', 'Y', 5), ('LLowerLeg', 'Y', -5),
                           ('RUpperLeg', 'Y', -5), ('RLowerLeg', 'Y', 5)] + corrections
        for name, axis, degrees in corrections:
            bone = arm.pose.bones[name]
            origin = bone.head.copy()
            bone.matrix = Matrix.Translation(origin) @ Matrix.Rotation(math.radians(degrees), 4, axis) @ Matrix.Translation(-origin) @ bone.matrix
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=name)
            bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        low = min((evaluated.matrix_world @ deformed.vertices[i].co).z for i in soles)
        evaluated.to_mesh_clear()
        lift = max(0, floor - low) if running else floor - low
        delta = arm.matrix_world.to_3x3().inverted() @ Vector((0, 0, lift))
        arm.pose.bones['Hips'].location += inverse_hip_rest @ delta
        arm.pose.bones['Hips'].keyframe_insert('location', frame=frame, group='Hips')
        lifts.append(lift * 2)
    return {'sole_correction_metres': [min(lifts), max(lifts)],
            'foot_yaw_degrees': {'L': -10, 'R': 12}, 'preserve_flight': running}

def tessa(source):
    reset()
    src = source / 'Meshy_AI_Emerald_Pathfinder_All_Animations.glb'
    bpy.ops.import_scene.gltf(filepath=str(src), merge_vertices=True)
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    for source_name, target in BONES.items():
        arm.data.bones['mixamorig:' + source_name].name = target
    # Rename only the body contract; all original finger/face joints survive.
    actions = list(bpy.data.actions)
    arm.animation_data_clear()
    arm.animation_data_create()
    for bone in arm.pose.bones: bone.matrix_basis.identity()
    bpy.context.view_layer.update()
    # Same centred .95-unit envelope as the existing 2x character slots.
    normalizer = bpy.data.objects.new('TessaScale', None)
    bpy.context.collection.objects.link(normalizer)
    for obj in list(bpy.context.scene.objects):
        if obj != normalizer and obj.parent is None: obj.parent = normalizer
    normalizer.scale = (0.95 / 1.7,) * 3
    normalizer.location.z = -.475
    contact = bpy.data.objects.new('GroundContact', None)
    bpy.context.collection.objects.link(contact)
    contact.location.z = -.475
    # Keep supplied gait poses. Remove horizontal root travel so the game's
    # CharacterBody remains the only owner of collision and world movement.
    gait_info = {}
    for action in actions:
        bind_action(arm, action)
        first, last = action.frame_range
        samples = []
        for frame in range(round(first), round(last) + 1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            samples.append((frame, arm.pose.bones['Hips'].location.copy(), arm.pose.bones['Hips'].head.copy()))
        displacement = samples[-1][2] - samples[0][2]
        gait_info[action.name] = {'seconds': (last-first)/30, 'root_travel_metres': Vector((displacement.x, displacement.y, 0)).length * .95/1.7*2}
        inverse_rest = arm.data.bones['Hips'].matrix_local.to_3x3().inverted()
        for frame, location, head in samples:
            delta = head - samples[0][2]
            arm.pose.bones['Hips'].location = location - inverse_rest @ Vector((delta.x, delta.y, 0))
            arm.pose.bones['Hips'].keyframe_insert('location', frame=frame, group='Hips')
        gait_info[action.name]['adaptation'] = align_feet(arm, mesh, action, running=action.name == 'Running')
        arm.animation_data.action = None
        track(arm, action, 'Walk' if action.name == 'Walking' else 'Run')
    # New authored standing clip, not a frozen walk frame. Apply rotations in
    # armature space to avoid assuming the provider's bone rolls match ours.
    idle = bpy.data.actions.new('Idle')
    bind_action(arm, idle)
    for frame in range(0, 241, 4):
        bpy.context.scene.frame_set(frame)
        phase = frame / 240 * math.tau
        for bone in arm.pose.bones:
            bone.matrix_basis.identity()
            bone.rotation_mode = 'QUATERNION'
        rotations = {
            'LUpperArm': (0, 15, 0), 'RUpperArm': (0, -15, 0),
            'Spine': (.3 * math.sin(phase*2), .9 * math.sin(phase), 0),
            'Chest': (.4 * math.sin(phase*2), .6 * math.sin(phase), 0),
            'Neck': (0, -.5 * math.sin(phase), 0),
        }
        for bone in arm.pose.bones:
            if bone.name in rotations:
                angles = rotations[bone.name]
                rotation = Matrix.Rotation(math.radians(angles[0]), 3, 'X') @ Matrix.Rotation(math.radians(angles[1]), 3, 'Y') @ Matrix.Rotation(math.radians(angles[2]), 3, 'Z')
                rest = bone.bone.matrix_local.to_3x3()
                bone.rotation_quaternion = (rest.inverted() @ rotation @ rest).to_quaternion()
            bone.keyframe_insert('rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert('location', frame=frame, group=bone.name)
            bone.keyframe_insert('scale', frame=frame, group=bone.name)
    align_feet(arm, mesh, idle, standing=True)
    arm.animation_data.action = None
    track(arm, idle, 'Idle')
    for bone in arm.pose.bones: bone.matrix_basis.identity()
    bpy.context.scene.frame_set(0)
    dest = ROOT / 'godot/assets/meshes/rigged/player_rigged.glb'
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', export_image_format='AUTO', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_frame_range=False, export_morph=False)
    original, result = inspect(src), inspect(dest)
    assert original['image_sha256'] == result['image_sha256'], 'Tessa textures changed'
    assert result['joints'] == original['joints'], 'Provider joints lost'
    # Measured from backward foot travel during the flat contact portion of the
    # in-place clips at the 1.9m game height. Stored with this rig, not all NPCs.
    motion = {'walk_cycle_distance': 1.5, 'run_cycle_distance': 3.2, 'run_speed_threshold': 2.8,
              'reference_height_metres': 1.9}
    dest.with_suffix('.motion.json').write_text(json.dumps(motion, indent=2) + '\n')
    return {'source': src.name, 'original': original, 'game_mesh': result, 'body_bone_aliases': BONES, 'gaits': gait_info, 'standing_clip': 'Locally authored 8-second breathing/sway; no new facial performance'}

def weapon(source, kind, spec):
    reset()
    filename, budget, length, grip_height = spec
    src = source / filename
    bpy.ops.import_scene.gltf(filepath=str(src), merge_vertices=True)
    mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    # Bake source transforms before measuring physical size and grip locations.
    mesh.data.transform(mesh.matrix_world)
    mesh.matrix_world.identity()
    bounds = [(min(v.co[i] for v in mesh.data.vertices), max(v.co[i] for v in mesh.data.vertices)) for i in range(3)]
    size = length / (bounds[2][1] - bounds[2][0])
    for vertex in mesh.data.vertices: vertex.co *= size
    low, high = bounds[2][0] * size, bounds[2][1] * size
    if kind == 'buckler':
        # Source faces -Y in Blender (+Z in Godot); grip sits behind the boss.
        center = Vector(((bounds[0][0]+bounds[0][1])*size/2, bounds[1][1]*size + .015, (low+high)/2))
        rotation = Matrix.Identity(4)
    else:
        height = low + grip_height
        grip_vertices = [v.co for v in mesh.data.vertices if abs(v.co.z - height) < .025]
        center = Vector((sum(v.x for v in grip_vertices)/len(grip_vertices), sum(v.y for v in grip_vertices)/len(grip_vertices), height))
        rotation = Matrix.Rotation(math.pi/2, 4, 'X')
    for vertex in mesh.data.vertices: vertex.co = rotation @ (vertex.co-center)
    bpy.context.view_layer.objects.active = mesh
    modifier = mesh.modifiers.new('Gameplay triangle budget', 'DECIMATE')
    modifier.ratio = min(1.0, budget / len(mesh.data.polygons))
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    mesh.name = kind
    for polygon in mesh.data.polygons: polygon.use_smooth = True
    dest = OUT / (kind + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', export_image_format='AUTO', export_animations=False)
    original, result = inspect(src), inspect(dest)
    assert original['image_sha256'] == result['image_sha256'], 'Weapon textures changed'
    sockets = {'PrimaryGrip': [0, 0, 0]}
    if kind == 'staff': sockets['SupportGrip'] = [0, 0, .26]
    if kind == 'sabre': sockets['ImpactBase'] = [0, 0, .08]
    sockets['GuardCenter' if kind == 'buckler' else 'ImpactTip'] = [0, 0, .04 if kind == 'buckler' else length-grip_height]
    lines = ['[gd_scene load_steps=2 format=3]', '', f'[ext_resource type="PackedScene" path="res://assets/meshes/equipment/{kind}.glb" id="1"]', '', f'[node name="{kind.capitalize()}" type="Node3D"]', '', '[node name="Model" parent="." instance=ExtResource("1")]']
    for name, position in sockets.items():
        lines += ['', f'[node name="{name}" type="Marker3D" parent="."]', 'position = Vector3(%s)' % ', '.join(str(x) for x in position)]
    (OUT / (kind + '.tscn')).write_text('\n'.join(lines)+'\n')
    return {'source': filename, 'original': original, 'game_mesh': result, 'size_metres': length, 'source_grip_center': list(center), 'sockets_metres': sockets}

def main():
    args = sys.argv[sys.argv.index('--')+1:]
    source = Path(args[0]).expanduser()
    mode = args[1] if len(args)>1 else 'all'
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'schema':1, 'tool':'Blender 5.0.1', 'assets':{}}
    if mode in ['all','tessa']:
        manifest['assets']['tessa'] = tessa(source)
        MANIFEST.write_text(json.dumps(manifest,indent=2)+'\n')
    if mode in ['all','weapons']:
        for kind, spec in WEAPONS.items():
            manifest['assets'][kind] = weapon(source, kind, spec)
            MANIFEST.write_text(json.dumps(manifest,indent=2)+'\n')
    print('PARTY_ASSETS', json.dumps(manifest), flush=True)

if __name__ == '__main__':
    main()
