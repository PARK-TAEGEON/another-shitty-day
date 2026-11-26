#!/usr/bin/env python3
"""Landing spread: shoe floor penetration across sideways start offsets.
Usage: spread.py <dir of <tree>-<fixture>-<offset>.json> <tree> [<tree> ...]
Peak is split at the hand-off: before (ragdoll start + flight) and after (landing).
'last' is the final sample; 'rest' says whether every body was below 0.05 m/s then."""
import json, os, sys, statistics as st
FLOOR = -0.02
src, trees = sys.argv[1], sys.argv[2:]
def one(path):
    d = json.load(open(path))
    end = next((e["frame"] for e in d["events"] if e["event"].startswith("flight_end")), None)
    rows = [r for r in d["frames"] if r.get("shoe_lowest_m") is not None]
    pen = lambda r: max(0.0, FLOOR - r["shoe_lowest_m"]) * 100
    pre = max((pen(r) for r in rows if end is None or r["frame"] <= end), default=0)
    post = max((pen(r) for r in rows if end is not None and r["frame"] > end), default=0)
    last = rows[-1]
    return {"pre": pre, "post": post, "peak": max(pre, post), "last": pen(last),
            "rest": last["fastest_body_m_s"] < 0.05, "asleep": last["sleeping_bodies"]}
fixtures = ["front", "side", "wall", "open", "ledge"]
result = {}
print(f"{'fixture':7} {'tree':5} | {'post-handoff peak cm: median / max':34} | {'last cm: median / max':22} | n>5cm post | at rest")
for f in fixtures:
    for t in trees:
        runs = [one(os.path.join(src, n)) for n in sorted(os.listdir(src)) if n.startswith(f"{t}-{f}-") and n.endswith(".json")]
        if not runs: continue
        post = [r["post"] for r in runs]; last = [r["last"] for r in runs]; pre = [r["pre"] for r in runs]
        result[f"{t}-{f}"] = {"n": len(runs), "pre_peak_cm": [round(x, 2) for x in pre], "post_peak_cm": [round(x, 2) for x in post],
                              "last_cm": [round(x, 2) for x in last], "last_at_rest": [r["rest"] for r in runs], "asleep_bodies": [r["asleep"] for r in runs]}
        print(f"{f:7} {t:5} | {st.median(post):6.2f} / {max(post):6.2f}  (pre-handoff max {max(pre):4.2f})     | {st.median(last):5.2f} / {max(last):5.2f}      | {sum(x > 5 for x in post):2d}/{len(post)}       | {sum(r['rest'] for r in runs)}/{len(runs)}")
json.dump(result, open(os.path.join(src, "spread-summary.json"), "w"), indent=1)
