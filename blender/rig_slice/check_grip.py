"""Run in Blender with player_arms.blend open. Pass a JSON output path after --."""
import json
import sys
from pathlib import Path

import bpy
from mathutils.bvhtree import BVHTree


def count_intersections(hand, depsgraph):
    evaluated = hand.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    try:
        mesh.calc_loop_triangles()
        triangles = [tuple(t.vertices) for t in mesh.loop_triangles]
        vertices = [v.co.copy() for v in mesh.vertices]
        tree = BVHTree.FromPolygons(vertices, triangles, all_triangles=True)
        return sum(
            1 for i, j in tree.overlap(tree)
            if i < j and set(triangles[i]).isdisjoint(triangles[j])
        )
    finally:
        evaluated.to_mesh_clear()


scene = bpy.context.scene
hands = [o for o in scene.objects if o.name.startswith("Palm and fingers")]
assert len(hands) == 2
result = {}
for frame in range(1, 31):
    scene.frame_set(frame)
    graph = bpy.context.evaluated_depsgraph_get()
    result[frame] = {o.name: count_intersections(o, graph) for o in hands}
print("Nonadjacent triangle intersections on the deformed skin:", result)
Path(sys.argv[-1]).write_text(json.dumps(result, indent=2) + "\n")
assert all(n == 0 for sides in result.values() for n in sides.values())
