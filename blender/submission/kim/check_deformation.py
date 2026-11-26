"""Audit the skin on the actual office GLB. Run with Blender, from the repo root.

blender -b -t 2 --factory-startup --python-exit-code 1 --python blender/submission/kim/check_deformation.py
"""
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[3]
ASSET = ROOT / "game/assets/rig_slice/boss_kim_game.glb"
REPORT = ROOT / "docs/evidence/submission/kim/deformation.json"
sys.path.insert(0, str(ROOT / "blender/rig_slice"))
from audit import audit

GAMEPLAY = ("Idle", "Walk", "Idle_Talking", "Hit_Chest", "Hit_Head")
SAMPLE_FPS = 30


def vertex_positions(obj):
    points = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", points)
    transform = np.asarray(obj.matrix_world)
    return points.reshape(-1, 3) @ transform[:3, :3].T + transform[:3, 3]


def lengths(points, edges):
    return np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)


def contact_surfaces(mesh):
    # Ignore cuffs, as their overlap with wrist skin is intentional.
    groups = [g.name for g in mesh.vertex_groups]
    garment = {"Spine", "Pelvis", "Chest", "Clavicle", "UpperLeg", "LowerLeg"}
    fingers = ("Hand", "Thumb", "Index", "Middle", "Ring", "Little")
    labels = []
    for v in mesh.data.vertices:
        bones = [groups[g.group] for g in v.groups if g.weight > 0.01]
        if bones and all(b.split(".")[0] in garment for b in bones):
            labels.append("garment")
        elif bones and all(b.startswith(fingers) for b in bones):
            labels.append("hand")
        else:
            labels.append("")
    faces = {"hand": [], "garment": []}
    for poly in mesh.data.polygons:
        indices = poly.vertices[:]
        label = labels[indices[0]]
        if not label or any(labels[i] != label for i in indices):
            continue
        if label == "garment" and mesh.data.materials[poly.material_index].name != "Cloth":
            continue
        faces[label].append(indices)
    surfaces = {}
    for name, triangles in faces.items():
        if not triangles:
            raise ValueError("Missing sample surface: " + name)
        vertices, local_indices = np.unique(triangles, return_inverse=True)
        surfaces[name] = (vertices, local_indices.reshape(-1, 3).tolist())
    return surfaces


def surface_tree(points, surface):
    indices, triangles = surface
    return BVHTree.FromPolygons(points[indices].tolist(), triangles, all_triangles=True)


def measure():
    initial_hash = hashlib.sha256(ASSET.read_bytes()).hexdigest()
    asset = audit(ASSET)
    missing = set((*GAMEPLAY, "Joint_review")).difference(asset["clips"])
    if missing:
        raise ValueError("Missing GLB clips: " + ", ".join(sorted(missing)))

    scene = bpy.context.scene
    scene.render.fps = SAMPLE_FPS
    bpy.ops.import_scene.gltf(filepath=str(ASSET))
    rig, = (obj for obj in scene.objects if obj.type == "ARMATURE")
    mesh, = (obj for obj in scene.objects if obj.type == "MESH" and obj.find_armature() == rig)
    rest = vertex_positions(mesh)
    edges = np.empty(len(mesh.data.edges) * 2, dtype=np.int32)
    mesh.data.edges.foreach_get("vertices", edges)
    edges = edges.reshape(-1, 2)
    rest_length = lengths(rest, edges)
    # Tiny or coincident tessellation edges can multiply almost without moving.
    edges = edges[rest_length > 0.001]
    rest_length = lengths(rest, edges)
    midpoints = rest[edges].mean(axis=1)
    joint_positions = {
        bone.name: np.asarray(rig.matrix_world @ bone.head_local)
        for bone in rig.data.bones
    }
    regions = {}
    for region, bone_name in (("shoulder", "UpperArm"), ("elbow", "Forearm"), ("knee", "LowerLeg")):
        left = np.linalg.norm(midpoints - joint_positions[bone_name + ".L"], axis=1)
        right = np.linalg.norm(midpoints - joint_positions[bone_name + ".R"], axis=1)
        regions[region] = np.minimum(left, right) < 0.20
    shoes = {}
    for side in ("L", "R"):
        index = mesh.vertex_groups["Foot." + side].index
        shoes[side] = [v.index for v in mesh.data.vertices
                       if any(g.group == index and g.weight > 0.99 for g in v.groups)]
        if not shoes[side]:
            raise ValueError("No shoe vertices bound to Foot." + side)

    tracks = rig.animation_data.nla_tracks
    actions = {track.name: track.strips[0].action for track in tracks}
    for track in tracks:
        track.mute = True
    dependency_graph = bpy.context.evaluated_depsgraph_get()
    surfaces = contact_surfaces(mesh)
    clips = {}
    for name in (*GAMEPLAY, "Joint_review"):
        rig.animation_data.action = None
        for bone in rig.pose.bones:
            bone.matrix_basis = Matrix.Identity(4)
        rig.animation_data.action = actions[name]
        start, end = map(float, actions[name].frame_range)
        # Include fractional endpoints and skip near-duplicate frames from float import.
        frames = np.unique(np.round([start, *range(math.ceil(start), math.floor(end) + 1), end], 4))
        severe = np.zeros(len(edges), dtype=bool)
        largest_delta = 0.0
        contact_frames = 0
        region_growth = {name: 0.0 for name in regions}
        peak = None
        sole_heights = {"L": [], "R": []}
        for frame in frames:
            whole = math.floor(frame)
            scene.frame_set(whole, subframe=float(frame - whole))
            points = vertex_positions(mesh.evaluated_get(dependency_graph))
            if not np.isfinite(points).all():
                raise ValueError(f"{name} has nonfinite vertices at frame {frame}")
            hands = surface_tree(points, surfaces["hand"])
            clothes = surface_tree(points, surfaces["garment"])
            if hands.overlap(clothes):
                contact_frames += 1
            actual = lengths(points, edges)
            delta = actual - rest_length
            for region, mask in regions.items():
                region_growth[region] = max(region_growth[region], float(np.max(delta[mask])))
            severe |= (actual > 2 * rest_length) & (delta > 0.01)
            i = int(np.argmax(delta))
            if peak is None or delta[i] > largest_delta:
                largest_delta = float(delta[i])
                near = min(joint_positions, key=lambda b: np.linalg.norm(joint_positions[b] - midpoints[i]))
                peak = {"frame": float(frame), "nearest_bone_head": near,
                        "rest_mm": round(rest_length[i] * 1000, 2),
                        "posed_mm": round(actual[i] * 1000, 2),
                        "growth_mm": round(largest_delta * 1000, 2)}
            for side, indices in shoes.items():
                sole_heights[side].append(points[indices, 2].min())
        support = np.minimum(sole_heights["L"], sole_heights["R"])
        clips[name] = {
            "sample_count": len(frames),
            "frames_with_hand_torso_or_trouser_intersection": contact_frames,
            "materially_stretched_edges": int(severe.sum()),
            "largest_edge_growth": peak,
            "peak_edge_growth_within_200mm_of_joint_mm": {
                region: round(1000 * growth, 2) for region, growth in region_growth.items()
            },
            "lowest_shoe_per_frame_range_mm": [round(1000 * min(support), 2), round(1000 * max(support), 2)],
            "shoe_minimum_z_range_mm": {
                s: [round(min(z) * 1000, 2), round(max(z) * 1000, 2)]
                for s, z in sole_heights.items()
            },
        }
    if hashlib.sha256(ASSET.read_bytes()).hexdigest() != initial_hash:
        raise RuntimeError("GLB changed during measurement; rerun the audit")
    return {
        "source": ASSET.relative_to(ROOT).as_posix(),
        "sha256": initial_hash,
        "blender": bpy.app.version_string,
        "sample_fps": SAMPLE_FPS,
        "glb": asset,
        "rest_height_mm": round(np.ptp(rest[:, 2]) * 1000, 2),
        "measured_edges": len(edges),
        "method": (
            "Imported office GLB, Blender coordinates. Count unique edges per clip with rest length "
            ">1 mm, more than 2x stretch and more than 10 mm growth. Peak reports the greatest "
            "absolute growth among all measured edges. Shoe heights are measured before NPC placement."
        ),
        "contact_test": (
            "Triangle BVH overlap of hands and fingers vs torso and trousers. Includes Cloth-material "
            "garment triangles whose vertices carry only spine, chest, clavicle, pelvis or leg weights "
            "above 0.01. Sleeves and cuffs are excluded."
        ),
        "limits": (
            "Independent clothing surfaces may slide, separate or interpenetrate without stretching "
            "their own edges. This audit samples clip poses and excludes Godot layering and Jolt simulation."
        ),
        "clips": clips,
    }


if __name__ == "__main__":
    report = measure()
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print("Saved", REPORT)
