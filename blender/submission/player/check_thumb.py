"""Evaluate the deformed welded skin on both hands at quarter-frame intervals."""
import json
import sys
from pathlib import Path

import bpy
from math import degrees
from mathutils.bvhtree import BVHTree


def inspect(hand, graph, measure_tip):
    evaluated = hand.evaluated_get(graph)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        triangles = [tuple(triangle.vertices) for triangle in mesh.loop_triangles]
        vertices = [v.co.copy() for v in mesh.vertices]
        tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
        intersections = sum(i < j and set(triangles[i]).isdisjoint(triangles[j])
                            for i, j in tree.overlap(tree))
        if not measure_tip:
            return intersections, None
        groups = [hand.vertex_groups[max(v.groups, key=lambda g: g.weight).group].name for v in mesh.vertices]
        index_middle = [t for t in triangles if all(groups[v].startswith(('Index','Middle')) for v in t)]
        fingers = BVHTree.FromPolygons(vertices, index_middle, all_triangles=True)
        thumb = [i for i, name in enumerate(groups) if name.startswith('Thumb3')]
        # Tip selection in anatomical rest space, mirrored for the left hand.
        sign = -1 if hand.name.endswith('.R') else 1
        distal = max(sign * hand.data.vertices[i].co.x for i in thumb)
        tip = [i for i in thumb if sign * hand.data.vertices[i].co.x >= distal - 0.004]
        gap = min(fingers.find_nearest(vertices[i])[3] for i in tip)
        return intersections, round(1000 * gap, 3)
    finally:
        evaluated.to_mesh_clear()


scene = bpy.context.scene
hands = [o for o in scene.objects if o.name.startswith('Palm and fingers')]
assert len(hands) == 2
report = {'sampled_poses_per_hand': 117, 'intersection_samples': {}, 'tip_clearance_mm': {},
          'max_thumb_rotation_per_frame_deg': 0.0}
previous = {}
for tick in range(4, 121):
    frame, fraction = divmod(tick, 4)
    scene.frame_set(frame, subframe=fraction / 4)
    graph = bpy.context.evaluated_depsgraph_get()
    for hand in hands:
        count, gap = inspect(hand, graph, tick in (80, 120))
        if count:
            report['intersection_samples'][f'{hand.name}@{tick / 4}'] = count
        if gap is not None:
            report['tip_clearance_mm'][f'{hand.name}@{frame}'] = gap
        if not fraction:
            for bone in hand.parent.pose.bones:
                if bone.name.startswith('Thumb'):
                    quat = bone.rotation_quaternion.copy()
                    if bone.name in previous:
                        angle = degrees(quat.rotation_difference(previous[bone.name]).angle)
                        step = min(angle, 360 - angle)
                        report['max_thumb_rotation_per_frame_deg'] = max(step, report['max_thumb_rotation_per_frame_deg'])
                    previous[bone.name] = quat
Path(sys.argv[-1]).write_text(json.dumps(report, indent=2) + '\n')
print('THUMB CHECK', report)
assert not report['intersection_samples']
