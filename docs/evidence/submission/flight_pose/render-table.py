#!/usr/bin/env python3
"""Rendered runs (flight-capture.gd, 30 fps movie) per runtime and scene.
Usage: render-table.py <dir> <out.json> <tag> [<tag> ...]
Reads <dir>/<tag>-<scene>.json for scene in office, front, side, wall and
<tag>-open-room.json / <tag>-ledge-room.json (the review-camera runs).
Depth = cm below the floor collider top, worst foot, from the per-step log.
  pre  = steps while the scripted flight runs (office: from flight start)
  post = steps after the hand-off; time = movie seconds after the hand-off frame
Rest = every Kim body below 0.05 m/s on 15 consecutive frames after the
hand-off; otherwise the last logged step is reported as 'last (not at rest)'."""
import json, sys

src, out, tags = sys.argv[1], sys.argv[2], sys.argv[3:]
SCENES = [("office", "office"), ("front", "front"), ("side", "side"), ("wall", "wall"), ("open", "open-room"), ("ledge", "ledge-room")]
LABEL = {"base": "aecd0f1", "c434672": "c434672", "fix": "ee08dbb"}


def feet(r, key):
    return max(r[s][key] for s in ("L", "R"))


def one(path):
    d = json.load(open(path))
    steps = [r for r in d["steps"] if "L" in r]
    hand = next(e for e in d["events"] if e["event"].startswith("flight_end"))
    pre = [r for r in steps if r["flight"]]
    post = [r for r in steps if not r["flight"] and r["frame"] >= hand["frame"]]
    frames = sorted(d["frames"], key=lambda f: f["frame"])
    rest, run = None, 0
    for f in frames:
        if f["frame"] <= hand["frame"]:
            continue
        run = run + 1 if f["fastest_body_m_s"] < 0.05 else 0
        if run >= 15:
            rest = f["frame"]
            break
    res = {"end": hand["event"][len("flight_end_"):], "handoff_frame": hand["frame"], "handoff_game_s": hand["game_s"]}
    for name, rows in (("pre", pre), ("post", post)):
        for key in ("shoe_cm", "collider_cm"):
            p = max(rows, key=lambda r: feet(r, key)) if rows else None
            res[f"{name}_{key}"] = feet(p, key) if p else None
            if name == "post" and p:
                res[f"post_{key}_step"] = p["step"]
                res[f"post_{key}_frame"] = p["frame"]
                res[f"post_{key}_s_after_handoff"] = round((p["frame"] - hand["frame"]) / 30.0, 3)
    res["down_steps"] = sum(1 for r in post if any(r[s]["floor_normal_down"] for s in ("L", "R")))
    if rest is not None:
        r = [x for x in post if x["frame"] <= rest][-1]
        res["rest"] = {"reached": True, "frame": rest, "s_after_handoff": round((rest - hand["frame"]) / 30.0, 2),
                       "shoe_cm": feet(r, "shoe_cm"), "collider_cm": feet(r, "collider_cm")}
    else:
        r = post[-1]
        res["rest"] = {"reached": False, "last_frame": r["frame"], "last_fastest_m_s": frames[-1]["fastest_body_m_s"],
                       "shoe_cm": feet(r, "shoe_cm"), "collider_cm": feet(r, "collider_cm")}
    return res


table = {}
print("scene  runtime | pre shoe/coll | post shoe max (s) | post coll max | down | rest / last")
for scene, name in SCENES:
    for tag in tags:
        try:
            r = one(f"{src}/{tag}-{name}.json")
        except FileNotFoundError:
            continue
        table[f"{LABEL.get(tag, tag)}-{scene}"] = r
        rest = r["rest"]
        rt = (f"rest {rest['s_after_handoff']:.2f}s shoe {rest['shoe_cm']:.2f} coll {rest['collider_cm']:.2f}" if rest["reached"]
              else f"last f{rest['last_frame']} NOT at rest ({rest['last_fastest_m_s']} m/s) shoe {rest['shoe_cm']:.2f} coll {rest['collider_cm']:.2f}")
        pre = f"{r['pre_shoe_cm']:.2f}/{r['pre_collider_cm']:.2f}" if r["pre_shoe_cm"] is not None else "-"
        print(f"{scene:6} {LABEL.get(tag, tag):8} | {pre:13} | {r['post_shoe_cm']:6.2f} ({r['post_shoe_cm_s_after_handoff']:.2f}s) | {r['post_collider_cm']:6.2f} | {r['down_steps']:3d} | {rt}")
json.dump(table, open(out, "w"), indent=1)
