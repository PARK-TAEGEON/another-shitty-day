#!/usr/bin/env python3
"""Floor contacts of the feet from contact-trace.gd logs.
Usage: contact-summary.py <trace.json> [<trace.json> ...]
Per log: post hand-off steps, floor contacts per foot shape (0 = box, 1-12 =
edge capsules), floor contacts whose normal (from the floor towards the foot,
world space, Y up) points down, and the deepest steps with their contacts."""
import json, sys

for path in sys.argv[1:]:
    d = json.load(open(path))
    floor = d["floor"]
    post = [r for r in d["steps"] if not r["flight"]]
    by_shape, down = {}, []
    for r in post:
        for side in ("L", "R"):
            for c in r[side]["contacts"]:
                if c["other"] != floor:
                    continue
                n = [float(x) for x in c["normal_world_towards_foot"].strip("()").split(",")]
                by_shape[c.get("foot_shape", "?")] = by_shape.get(c.get("foot_shape", "?"), 0) + 1
                if n[1] < -0.5:
                    down.append((r["step"], side, c.get("foot_shape", "?"), c["normal_world_towards_foot"], c["point_on_foot_world"], r[side]["collider_pen_cm"]))
    deepest = max(post, key=lambda r: max(r["L"]["shoe_pen_cm"], r["R"]["shoe_pen_cm"]))
    print(f"== {path}\n floor {floor} top {d['floor_top']:.4f} m | post steps {len(post)} | floor contacts by foot shape {dict(sorted(by_shape.items()))}")
    print(f" downward floor normals: {len(down)}")
    for x in down[:8]:
        print(f"   step {x[0]} Foot.{x[1]} shape {x[2]} normal {x[3]} point {x[4]} collider depth {x[5]} cm")
    s = deepest
    print(f" deepest shoe step {s['step']}: L shoe {s['L']['shoe_pen_cm']} collider {s['L']['collider_pen_cm']} | R shoe {s['R']['shoe_pen_cm']} collider {s['R']['collider_pen_cm']} cm")
