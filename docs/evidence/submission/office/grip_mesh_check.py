"""Compare actual evaluated cup surfaces with the world-space hand sample from Godot."""
import json
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

samples = [Vector(p) for p in json.loads(Path("/tmp/asd-office-hand.json").read_text())]
graph = bpy.context.evaluated_depsgraph_get()
deepest, nearest = 0., float("inf")
for obj in bpy.context.scene.objects:
    ev = obj.evaluated_get(graph)
    mesh = ev.to_mesh()
    mesh.calc_loop_triangles()
    tree = BVHTree.FromPolygons([ev.matrix_world @ v.co for v in mesh.vertices],
                                [tuple(t.vertices) for t in mesh.loop_triangles], all_triangles=True)
    # Ray parity also handles concave rims and ambiguous nearest-edge normals.
    direction = Vector((1., .3187, .2031)).normalized()
    for sample in samples:
        point, normal, _, distance = tree.find_nearest(sample)
        origin = sample
        crossings = 0
        while True:
            hit = tree.ray_cast(origin, direction)[0]
            if hit is None:
                break
            crossings += 1
            origin = hit + direction * .000001
        if crossings % 2:
            deepest = max(deepest, distance)
        if obj.name.startswith("Handle"):
            nearest = min(nearest, distance)
    ev.to_mesh_clear()
print("OFFICE_GRIP_MESH", dict(samples=len(samples), max_penetration_m=deepest, handle_gap_m=nearest))
assert samples and deepest < .002 and nearest < .003
