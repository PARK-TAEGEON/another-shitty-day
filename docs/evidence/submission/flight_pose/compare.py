#!/usr/bin/env python3
"""Summarise flight-capture.gd logs: before (B-*) vs after (A-*).
Usage: compare.py <log-dir> <out.json>"""
import json, sys, os

GROUPS = {"torso": ["Chest"], "head": ["Head"], "arms": ["UpperArm.L", "UpperArm.R"],
          "legs": ["UpperLeg.L", "UpperLeg.R"], "knees": ["LowerLeg.L", "LowerLeg.R"],
          "elbows": ["Forearm.L", "Forearm.R"]}

def summarise(path):
    d = json.load(open(path))
    ev = {e["event"]: e for e in d["events"]}
    start = ev.get("flight_start")
    end = next((e for e in d["events"] if e["event"].startswith("flight_end")), None)
    rows = d["frames"]
    out = {"events": d["events"], "shoe": d["shoe"]}
    if not start or not end:
        return out
    flight = [r for r in rows if start["frame"] <= r["frame"] <= end["frame"]]
    def groups(r):
        t = r["turn_since_flight_start_deg"]
        return {k: max(t.get(n, 0.0) for n in v) for k, v in GROUPS.items()}
    first_two = None
    rigid = 0
    for r in flight:
        g = groups(r)
        moving = [k for k, v in g.items() if v >= 5.0]
        if len(moving) < 2:
            rigid += 1
        elif first_two is None:
            first_two = {"frame": r["frame"], "game_s_after_flight_start": round(r["game_s"] - start["game_s"], 4),
                         "u": r["u"], "groups_deg": {k: round(v, 1) for k, v in g.items()}}
    gap0 = flight[0]["max_joint_gap_mm"]
    after = [r for r in rows if r["frame"] > end["frame"]]
    landing = next((r for r in after if r["max_joint_step_deg"] > 10.0), None)
    FLOOR = -0.02
    shoe = [r for r in rows if r.get("shoe_lowest_m") is not None]
    pen = lambda r: round(max(0.0, FLOOR - r["shoe_lowest_m"]) * 100, 2)
    last = shoe[-1] if shoe else None
    out["shoe_cm"] = {
        "peak_before_handoff": max((pen(r) for r in shoe if r["frame"] <= end["frame"]), default=None),
        "peak_after_handoff": max((pen(r) for r in shoe if r["frame"] > end["frame"]), default=None),
        "peak_after_handoff_frame": max((r for r in shoe if r["frame"] > end["frame"]), key=pen, default={}).get("frame"),
        "last": pen(last) if last else None,
        "last_frame": last["frame"] if last else None,
        "last_fastest_body_m_s": last["fastest_body_m_s"] if last else None,
        "last_sleeping_bodies": last["sleeping_bodies"] if last else None,
        "last_is_rest": bool(last and last["fastest_body_m_s"] < 0.05),
    }
    out.update({
        "flight_frames": len(flight),
        "end_kind": end["event"], "end_u": end.get("u"),
        "first_two_groups_over_5deg": first_two,
        "frames_with_fewer_than_two_groups_moving": rigid,
        "fold_at_end_deg": {k: round(v, 1) for k, v in groups(flight[-1]).items()},
        "max_joint_step_deg_during_flight_after_first_frame": max(r["max_joint_step_deg"] for r in flight[1:]),
        "joint_gap_mm_at_flight_start": gap0,
        "max_joint_gap_change_mm_during_flight": round(max(abs(r["max_joint_gap_mm"] - gap0) for r in flight), 2),
        "handoff": {
            "max_joint_step_deg_first_3_frames": max((r["max_joint_step_deg"] for r in after[:3]), default=None),
            "max_joint_gap_change_mm_first_10_frames": round(max((abs(r["max_joint_gap_mm"] - flight[-1]["max_joint_gap_mm"]) for r in after[:10]), default=0.0), 2),
            "frames_until_first_step_over_10deg": (landing["frame"] - end["frame"]) if landing else None,
            "pelvis_y_at_that_frame": landing["pelvis"] if landing else None,
        },
        "overlap_frames_during_flight": [r["frame"] for r in flight if r["wall_or_furniture_overlap"]],
        "overlap_frames_after": [[r["frame"], r["wall_or_furniture_overlap"]] for r in after if r["wall_or_furniture_overlap"]][:12],
        "max_joint_gap_mm_after": max((r["max_joint_gap_mm"] for r in after), default=None),
    })
    return out

def main():
    src, dst = sys.argv[1], sys.argv[2]
    result = {}
    for name in sorted(os.listdir(src)):
        if name.endswith(".json") and (name.startswith("B-") or name.startswith("A-")):
            result[name[:-5]] = summarise(os.path.join(src, name))
    json.dump(result, open(dst, "w"), indent=1, ensure_ascii=False)
    print(f"{'run':16} {'end':18} {'endU':>5} {'2grp@s':>7} {'rigidF':>6} {'stepFl':>6} {'gapΔ':>5} {'hoStep':>6} {'hoGapΔ':>6} {'ovl':>4} {'shoePk':>6} {'shoeEnd':>7} {'pkPre':>6} {'pkPost':>6} {'rest':>5}")
    for k, v in result.items():
        if "end_kind" not in v:
            print(k, "no flight"); continue
        f2 = v["first_two_groups_over_5deg"]
        print(f"{k:16} {v['end_kind']:18} {v['end_u']:5.3f} {('%.3f' % f2['game_s_after_flight_start']) if f2 else '  none':>7} {v['frames_with_fewer_than_two_groups_moving']:6d} "
              f"{v['max_joint_step_deg_during_flight_after_first_frame']:6.1f} {v['max_joint_gap_change_mm_during_flight']:5.1f} "
              f"{v['handoff']['max_joint_step_deg_first_3_frames']:6.1f} {v['handoff']['max_joint_gap_change_mm_first_10_frames']:6.1f} "
              f"{len(v['overlap_frames_during_flight']):4d} {v['shoe']['peak_floor_penetration_m']*100:5.2f}cm {v['shoe']['last_floor_penetration_m']*100:6.2f}cm"
              f" {v['shoe_cm']['peak_before_handoff']:6.2f} {v['shoe_cm']['peak_after_handoff']:6.2f} {str(v['shoe_cm']['last_is_rest']):>5}")

main()
