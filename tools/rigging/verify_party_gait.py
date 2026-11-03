"""Evaluate the prepared Meshy rig in Blender, including between export keys.

blender -b --python-exit-code 1 --python tools/rigging/verify_party_gait.py
Prints measurements in game metres (the character slot scales the asset 2x).
This checks flat-floor locomotion, not uneven-terrain foot IK or combat poses.
"""
from pathlib import Path
import json
import math
import statistics
import sys
import bpy

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
asset = Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else ROOT / 'godot/assets/meshes/rigged/player_rigged.glb'
bpy.ops.import_scene.gltf(filepath=str(asset), merge_vertices=True)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.vertex_groups) > 0)
arm.animation_data_clear()
arm.animation_data_create()
feet = {}
for side, long in [('L', 'Left'), ('R', 'Right')]:
    groups = {g.index for g in mesh.vertex_groups if g.name == side + 'Foot' or g.name.startswith('mixamorig:' + long + 'Toe')}
    feet[side] = [v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in groups) > .5]
report = {}
for action in bpy.data.actions:
    if '--clip' in sys.argv and action.name != sys.argv[sys.argv.index('--clip')+1]: continue
    arm.animation_data.action = action
    if action.slots: arm.animation_data.action_slot = action.slots[0]
    samples = []
    for index in range(121):
        frame = action.frame_range[0] + (action.frame_range[1] - action.frame_range[0]) * index / 120
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        evaluated = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
        deformed = evaluated.to_mesh()
        row = {}
        for side, long in [('L', 'Left'), ('R', 'Right')]:
            foot = 2 * (arm.matrix_world @ arm.pose.bones[side + 'Foot'].head)
            toe = 2 * (arm.matrix_world @ arm.pose.bones['mixamorig:' + long + 'ToeBase'].head)
            vector = toe - foot
            sole = min(2 * (evaluated.matrix_world @ deformed.vertices[i].co).z for i in feet[side])
            row[side] = {'sole': sole + .95, 'foot': foot, 'toe': toe,
                         'flat': vector.y < -.10,  # Toe is forward of ankle; excludes vertical toe-off.
                         'heading': math.degrees(math.atan2(vector.x, -vector.y))}
        samples.append(row)
        evaluated.to_mesh_clear()
    floor = [min(s[side]['sole'] for side in feet) for s in samples]
    contacts = {side: [s[side]['heading'] for s in samples if s[side]['flat'] and s[side]['sole'] < .03] for side in feet}
    result = {
        'seconds': (action.frame_range[1] - action.frame_range[0]) / 30,
        'samples': len(samples), 'lowest_sole_range_metres': [min(floor), max(floor)],
        'ankle_separation_metres': [min(s['L']['foot'].x - s['R']['foot'].x for s in samples), max(s['L']['foot'].x - s['R']['foot'].x for s in samples)],
        'flat_contact_median_heading_degrees': {side: statistics.median(values) for side, values in contacts.items()},
        'loop_ankle_error_metres': max((samples[0][side]['foot'] - samples[-1][side]['foot']).length for side in feet),
    }
    assert result['loop_ankle_error_metres'] < .002, (action.name, 'loop seam', result)
    assert result['ankle_separation_metres'][0] > .09, (action.name, 'crossing feet', result)
    assert all(abs(a) < 10 for a in result['flat_contact_median_heading_degrees'].values()), (action.name, 'toe splay', result)
    if action.name != 'Run':
        assert max(abs(a) for a in floor) < .008, (action.name, 'floor contact', result)
    else:
        assert min(floor) > -.02 and max(floor) > .08, ('Run must retain flight, with bounded sole penetration', result)
    report[action.name] = result
print('PARTY_GAIT ' + json.dumps(report, indent=2))
