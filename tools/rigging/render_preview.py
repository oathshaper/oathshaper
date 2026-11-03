"""Render a front or side diagnostic of a GLB with Blender Workbench.

Run: blender -b --python tools/rigging/render_preview.py -- model.glb out.png front
"""

import sys
from pathlib import Path

import bpy
from mathutils import Vector

arguments = sys.argv[sys.argv.index("--") + 1 :]
source, target, view = arguments[:3]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(Path(source).resolve()), merge_vertices=True)
if len(arguments) >= 5:
    action_name, frame = arguments[3], int(arguments[4])
    armatures = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected one armature, got {len(armatures)}")
    armature = armatures[0]
    action = bpy.data.actions.get(action_name)
    if action is None:
        raise RuntimeError(f"Missing {action_name}; found {list(bpy.data.actions.keys())}")
    armature.animation_data_create()
    armature.animation_data.action = action
    if action.slots:
        armature.animation_data.action_slot = action.slots[0]
    for track in armature.animation_data.nla_tracks:
        track.mute = True
    bpy.context.scene.frame_set(frame)

camera_data = bpy.data.cameras.new("PreviewCamera")
camera = bpy.data.objects.new("PreviewCamera", camera_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = (0, -2, 0) if view == "front" else ((2, 0, 0) if view == "side" else (0, 2, 0))
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 1.1
bpy.context.scene.camera = camera
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.filepath = str(Path(target).resolve())
scene.render.image_settings.file_format = "PNG"
bpy.ops.render.render(write_still=True)
