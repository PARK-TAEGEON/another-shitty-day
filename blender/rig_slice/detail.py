"""blender -b boss_kim_game.blend --python detail.py -- OUTPUT_DIRECTORY"""
import bpy, sys
from pathlib import Path
from mathutils import Vector
d = Path(sys.argv[-1]).resolve()
s = bpy.context.scene
rig = next((o for o in s.objects if o.type == 'ARMATURE'))
cam = s.camera
s.render.resolution_x = 600
s.render.resolution_y = 460
s.render.resolution_percentage = 100
s.render.engine = 'CYCLES'
s.cycles.samples = 24
s.cycles.use_denoising = False
for name, frame, joint, scale in [('kim_wrist_flex', 40, 'Forearm.R', 0.92), ('kim_finger_flex', 60, 'Hand.R', 0.39)]:
    s.frame_set(frame)
    bone = rig.pose.bones[joint]
    target = rig.matrix_world @ bone.tail
    direction = Vector((-0.68, -0.72, 0.12))
    cam.location = target + direction * 2.0
    cam.rotation_euler = (-direction).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = scale
    s.render.filepath = str(d / (name + '.png'))
    bpy.ops.render.render(write_still=True)
s.frame_set(1)
s.render.resolution_x = 600
s.render.resolution_y = 700
for name in ['front', 'profile', 'back']:
    s.camera = bpy.data.objects['View  |  ' + name]
    s.camera.data.ortho_scale = 2.65
    s.render.filepath = str(d / ('kim_A_' + name + '.png'))
    bpy.ops.render.render(write_still=True)
