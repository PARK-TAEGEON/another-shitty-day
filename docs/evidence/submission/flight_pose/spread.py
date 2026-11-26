#!/usr/bin/env python3
"""Landing spread from flight-capture.gd logs named <tag>-<fixture>-<offset>.json.
Usage: spread.py <dir> <tag> [<tag> ...]   (writes <dir>/spread-summary.json)

Per physics step (the 'steps' log: flight start to the end of the log), per
foot, depth below the top face of the floor collider of the foot collider (all
its shapes) and of the shoe hull. Positive = below the floor.
  pre   steps during the scripted flight (before the hand-off)
  post  steps after the hand-off
Rest: every Kim body below 0.05 m/s on 15 consecutive frames (0.5 s at 30 fps)
after the hand-off; rest values are read on the last step of the frame where
that window completes. A run that never reaches rest reports 'last' values only,
marked not at rest. 'down' = post steps where a floor contact pushed a foot
downwards (contact normal from the floor towards the foot pointing down)."""
import json, os, sys, statistics as st

FIXTURES = ["front", "side", "wall", "open", "ledge"]
REST_SPEED, REST_FRAMES = 0.05, 15


def feet(r, key):
    return max(r[s][key] for s in ("L", "R") if s in r)


def one(path):
    d = json.load(open(path))
    steps = [r for r in (d.get("steps") or []) if "L" in r]
    pre = [r for r in steps if r["flight"]]
    post = [r for r in steps if not r["flight"]]
    handoff = next(e for e in d["events"] if e["event"].startswith("flight_end"))
    hand_frame = handoff["frame"]
    frames = [f for f in d["frames"] if f["frame"] > hand_frame]
    rest_frame, run = None, 0
    for f in frames:
        run = run + 1 if f["fastest_body_m_s"] < REST_SPEED else 0
        if run >= REST_FRAMES:
            rest_frame = f["frame"]
            break
    by_frame = {}
    for r in post:
        by_frame[r["frame"]] = r
    peak = lambda rows, key: max(rows, key=lambda r: feet(r, key)) if rows else None
    out = {"end": handoff["event"][len("flight_end_"):], "handoff_frame": hand_frame}
    for name, rows in (("pre", pre), ("post", post)):
        for key in ("shoe_cm", "collider_cm"):
            p = peak(rows, key)
            out[f"{name}_{key}"] = feet(p, key) if p else 0.0
            out[f"{name}_{key}_s_after_handoff"] = round((p["frame"] - hand_frame) / 30.0, 3) if p else None
    out["down_steps"] = sum(1 for r in post if any(r[s]["floor_normal_down"] for s in ("L", "R")))
    if rest_frame is not None and rest_frame in by_frame:
        r = by_frame[rest_frame]
        out["rest"] = {"reached": True, "s_after_handoff": round((rest_frame - hand_frame) / 30.0, 2),
                       "shoe_cm": feet(r, "shoe_cm"), "collider_cm": feet(r, "collider_cm")}
    else:
        last = post[-1]
        out["rest"] = {"reached": False, "last_s_after_handoff": round((last["frame"] - hand_frame) / 30.0, 2),
                       "last_fastest_m_s": d["frames"][-1]["fastest_body_m_s"],
                       "last_shoe_cm": feet(last, "shoe_cm"), "last_collider_cm": feet(last, "collider_cm")}
    return out


def main():
    src, tags = sys.argv[1], sys.argv[2:]
    result = {}
    print(f"{'fixture':6} {'runtime':8} | post shoe cm med/max | post collider med/max | pre shoe/coll max | >5cm runs | down runs | rest runs (s med/max) | rest shoe max")
    for f in FIXTURES:
        for t in tags:
            prefix = f"{t}-{f}-"
            names = [n for n in os.listdir(src) if n.startswith(prefix) and n.endswith(".json")]
            names.sort(key=lambda n: float(n[len(prefix):-5]))
            if not names:
                continue
            runs = [one(os.path.join(src, n)) for n in names]
            offsets = [n[len(prefix):-5] for n in names]
            for o, r in zip(offsets, runs):
                r["offset_m"] = o
            result[f"{t}-{f}"] = runs
            a = [r["post_shoe_cm"] for r in runs]
            c = [r["post_collider_cm"] for r in runs]
            rested = [r["rest"] for r in runs if r["rest"]["reached"]]
            rs = [x["s_after_handoff"] for x in rested]
            rest_txt = f"{len(rested):2d}/{len(runs)} ({st.median(rs):5.2f}/{max(rs):5.2f})" if rs else f" 0/{len(runs)}"
            rest_shoe = f"{max(x['shoe_cm'] for x in rested):6.2f}" if rested else "   -  "
            print(f"{f:6} {t:8} | {st.median(a):6.2f} / {max(a):6.2f}      | {st.median(c):6.2f} / {max(c):6.2f}        | "
                  f"{max(r['pre_shoe_cm'] for r in runs):5.2f} / {max(r['pre_collider_cm'] for r in runs):5.2f}   | "
                  f"{sum(x > 5 for x in a):2d}/{len(a)}     | {sum(r['down_steps'] > 0 for r in runs):2d}/{len(runs)}     | {rest_txt}        | {rest_shoe}")
    json.dump(result, open(os.path.join(src, "spread-summary.json"), "w"), indent=1)


main()
