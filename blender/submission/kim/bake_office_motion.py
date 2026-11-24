"""Bake the office Kim's five shipped clips onto the approved 50-bone game rig.

Run from the repository root with Blender 4.3:
    blender -b --python-exit-code 1 --python blender/submission/kim/bake_office_motion.py
An optional argument after -- selects a separate input .blend (e.g. the original).
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector


ROOT = Path(__file__).resolve().parents[3]
SOURCE_GLB = ROOT / "game/assets/characters/boss_kim/boss_kim.glb"
BLEND = ROOT / "blender/rig_slice/boss_kim_game.blend"
GLB = ROOT / "game/assets/rig_slice/boss_kim_game.glb"
CLIPS = ("Idle", "Walk", "Idle_Talking", "Hit_Chest", "Hit_Head")
REVIEW_ACTION = "Shoulder elbow wrist and finger checks"
OFFICE_SIZE = 1.055
BODY_BONES = (
    "Root", "Pelvis", "Spine", "Chest", "Neck", "Head",
    *(part + side for side in (".L", ".R") for part in
      ("UpperArm", "Forearm", "Hand", "UpperLeg", "LowerLeg", "Foot")),
)


def read_office_clips():
    # Sample in a separate scratch scene. Import materials, object names, rest
    # axes and the original model never enter the deliverable .blend.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(SOURCE_GLB), bone_heuristic="BLENDER")
    donor = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    data = donor.animation_data
    actions = {track.name: track.strips[0].action for track in data.nla_tracks}
    data.use_nla = False
    rest_inverse = {
        name: donor.data.bones[name].matrix_local.to_quaternion().inverted()
        for name in BODY_BONES
    }
    clips = {}
    for name in CLIPS:
        action = actions[name]
        data.action = action
        poses = []
        start, end = map(round, action.frame_range)
        for frame in range(start, end + 1):
            scene.frame_set(frame)
            poses.append({
                bone: donor.pose.bones[bone].matrix.to_quaternion() @ rest_inverse[bone]
                for bone in BODY_BONES
            })
        clips[name] = poses
    return clips


def fit_office_height(rig, mesh):
    # Resize at the floor origin in both datablocks so bones, joints and skin
    # have unit object scale throughout the Jolt handoff. Safe on a second run.
    previously_applied = rig.data.get("office_size_factor", 1.0)
    factor = OFFICE_SIZE / previously_applied
    if abs(factor - 1.0) > 1e-6:
        size = Matrix.Scale(factor, 4)
        mesh.data.transform(size, shape_keys=True)
        rig.data.transform(size)
        rig.data["office_size_factor"] = OFFICE_SIZE


def smoothstep(lo, hi, value):
    t = min(1.0, max(0.0, (value - lo) / (hi - lo)))
    return t * t * (3.0 - 2.0 * t)


def smooth_trousers(mesh):
    # The trousers are one continuous surface. The original x-sign assignment
    # gave adjacent crotch vertices opposite thighs, producing a visible spike.
    groups = {name: mesh.vertex_groups[name] for name in
              ("UpperLeg.L", "UpperLeg.R", "LowerLeg.L", "LowerLeg.R", "Pelvis")}
    leg_ids = {group.index for name, group in groups.items() if name != "Pelvis"}
    for vertex in mesh.data.vertices:
        weights = {member.group: member.weight for member in vertex.groups}
        if not leg_ids.intersection(weights):
            continue
        x, _, z = vertex.co
        width = 0.25 * smoothstep(0.24, 0.52, z)
        left = smoothstep(-width, width, x) if width > 1e-6 else float(x > 0.0)
        # A broad, continuous transfer into the waistband carries a deep seated
        # crouch as well as the forward stride and the Jolt landing.
        pelvis = smoothstep(0.32, 0.83, z)
        if pelvis > 0.00001:
            groups["Pelvis"].add([vertex.index], pelvis, "REPLACE")
        elif groups["Pelvis"].index in weights:
            groups["Pelvis"].remove([vertex.index])
        upper = smoothstep(0.23, 0.64, z)
        for part, vertical in (("UpperLeg", upper), ("LowerLeg", 1 - upper)):
            left_share = left if part == "UpperLeg" else float(x > 0.0)
            for side, lateral in ((".L", left_share), (".R", 1 - left_share)):
                group = groups[part + side]
                weight = (1 - pelvis) * vertical * lateral
                if weight > 0.00001:
                    group.add([vertex.index], weight, "REPLACE")
                elif group.index in weights:
                    group.remove([vertex.index])


def smooth_sleeves(rig, mesh):
    for side in (".L", ".R"):
        upper, fore = (mesh.vertex_groups[n + side] for n in ("UpperArm", "Forearm"))
        clavicle = mesh.vertex_groups["Clavicle" + side]
        upper_bone, fore_bone = (rig.data.bones[g.name] for g in (upper, fore))
        axis = ((upper_bone.tail_local - upper_bone.head_local).normalized()
                + (fore_bone.tail_local - fore_bone.head_local).normalized()).normalized()
        for v in mesh.data.vertices:
            weights = {member.group: member.weight for member in v.groups}
            if upper.index not in weights and fore.index not in weights:
                continue
            offset = (v.co - fore_bone.head_local).dot(axis)
            flex = smoothstep(-0.19, 0.20, offset)
            arm_share = 1.0 - weights.get(clavicle.index, 0)
            for group, weight in ((upper, arm_share * (1 - flex)), (fore, arm_share * flex)):
                if weight > 0.00001:
                    group.add([v.index], weight, "REPLACE")
                elif group.index in weights:
                    group.remove([v.index])


def ground_clip(rig, mesh, action):
    # Office motions are in place. At every sample put the lowest rigid shoe
    # vertex on the floor, retaining swing height and leaving the actor capsule
    # and its horizontal movement to the game.
    scene = bpy.context.scene
    root = rig.pose.bones["Root"]
    rest_up = root.bone.matrix_local.to_quaternion().inverted() @ Vector((0, 0, 1))
    shoes = {}
    for side in (".L", ".R"):
        bone = rig.pose.bones["Foot" + side]
        group = mesh.vertex_groups[bone.name].index
        points = [bone.bone.matrix_local.inverted() @ v.co for v in mesh.data.vertices
                  if any(g.group == group and g.weight > 0.999 for g in v.groups)]
        shoes[bone.name] = np.array(points)
    for frame in range(round(action.frame_range[0]), round(action.frame_range[1]) + 1):
        scene.frame_set(frame)
        # Account for the root key already evaluated/interpolated at this frame.
        current_offset = root.location.dot(rest_up)
        lowest = min(np.min(points @ np.asarray(rig.pose.bones[name].matrix)[2, :3]
                            + rig.pose.bones[name].matrix[2][3])
                     for name, points in shoes.items())
        root.location = rest_up * (current_offset + 0.005 - lowest)
        root.keyframe_insert("location", frame=frame, group="Root")
    root.location = Vector((0, 0, 0))


def bake(rig, name, poses):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    rest = {p.name: p.bone.matrix_local.to_quaternion() for p in rig.pose.bones}
    # Keep the source rig's *armature-space* change from rest. For each target
    # bone solve its local key against the animated target parent. In particular
    # the new clavicles sit between chest and arms and keep their own rest pose.
    previous = {}
    for frame, source_delta in enumerate(poses):
        absolute = {}
        for p in rig.pose.bones:
            bone = p.name
            parent = p.parent
            rest_local = rest[parent.name].inverted() @ rest[bone] if parent else rest[bone]
            unkeyed = absolute[parent.name] @ rest_local if parent else rest_local
            if bone in source_delta:
                delta = source_delta[bone]
                if bone.startswith(("UpperLeg.", "LowerLeg.", "Foot.")):
                    # The donor's legs are longer. Keep standing feet level
                    # and its walking cadence, with a shorter stride for Kim.
                    if name == "Walk":
                        influence = 0.72 if bone.startswith("UpperLeg.") else 0.82
                    else:
                        influence = 0.0 if bone.startswith("Foot.") else 0.32
                    delta = Quaternion().slerp(delta, influence)
                target = delta @ rest[bone]
                local = unkeyed.inverted() @ target
            elif bone.startswith(("Index", "Middle", "Ring", "Little", "Thumb")):
                # Donor phalanges have no animated rotation. Relax the source
                # straight hand using the same bend axes as the joint review.
                side = 1 if bone.endswith(".L") else -1
                is_thumb = bone.startswith("Thumb")
                axis = Vector((1, 0, 0)) if is_thumb else Vector((0, 1, 0))
                angle = math.radians(6 if is_thumb else 11 * side)
                local = Quaternion(rest[bone].inverted() @ axis, angle)
                target = unkeyed @ local
            else:
                absolute[bone] = unkeyed
                continue
            absolute[bone] = target
            if bone in previous:
                local.make_compatible(previous[bone])
            p.rotation_quaternion = local
            previous[bone] = local.copy()
            p.keyframe_insert("rotation_quaternion", frame=frame, group=bone)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    return action


def write_office_files(clips, input_blend):
    bpy.ops.wm.open_mainfile(filepath=str(input_blend))
    scene = bpy.context.scene
    scene.render.fps = 30
    rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
    mesh, = [obj for obj in rig.children if obj.type == "MESH"]
    assert len(rig.data.bones) == 50
    fit_office_height(rig, mesh)
    smooth_trousers(mesh)
    smooth_sleeves(rig, mesh)
    anim = rig.animation_data
    anim.action = None
    review = bpy.data.actions[REVIEW_ACTION]
    review.use_fake_user = True
    for name in CLIPS:
        old = bpy.data.actions.get(name)
        if old:
            bpy.data.actions.remove(old)
    for p in rig.pose.bones:
        p.matrix_basis = Matrix.Identity(4)
    actions = {name: bake(rig, name, clips[name]) for name in CLIPS}
    for action in actions.values():
        anim.action = action
        ground_clip(rig, mesh, action)
        for curve in action.fcurves:
            if curve.data_path.endswith("location"):
                for key in curve.keyframe_points:
                    key.interpolation = "LINEAR"
    anim.action = None
    for track_name, action in {**actions, "Joint_review": review}.items():
        t = anim.nla_tracks.new()
        t.name = track_name
        t.strips.new(track_name, round(action.frame_range[0]), action)
    scene.frame_start = 0
    scene.frame_end = max(round(a.frame_range[1]) for a in actions.values())
    scene.frame_set(0)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (rig, mesh):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=str(GLB), use_selection=True, export_animations=True,
        export_animation_mode="NLA_TRACKS", export_force_sampling=True,
    )
    for t in list(anim.nla_tracks):
        anim.nla_tracks.remove(t)
    anim.action = actions["Idle"]
    scene.frame_end = round(actions["Idle"].frame_range[1])
    scene.frame_set(0)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)


source = Path(sys.argv[sys.argv.index("--") + 1]).resolve() if "--" in sys.argv else BLEND
write_office_files(read_office_clips(), source)
