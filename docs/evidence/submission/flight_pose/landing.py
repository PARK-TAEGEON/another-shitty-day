#!/usr/bin/env python3
"""Landing review from flight-capture.gd --review-cam=room|wall runs (rendered, 30 fps).
Usage: landing.py <dir> <out-dir> <fixture> <tag> [<tag> ...]
Reads <dir>/<tag>-<fixture>-room.{json,mp4} and -wall: two recordings of the same
input. Rendered hit-stop runs on the wall clock (hit_presenter.gd uses
Time.get_ticks_msec), so the two recordings can diverge after an impact; the
script checks their physics step logs and, if they differ, reports each camera's
run on its own (key "<runtime> wall").
Writes to <out-dir>:
  landing-<fixture>.json   per tag: hand-off, first floor impact, deepest shoe and
                           collider step, rest; each with physics step, video
                           frame, movie time and game time
  landing-<fixture>-max.jpg  5 consecutive frames around each tag's deepest
                           shoe step (room and wall row per tag), labelled
  landing-<fixture>-review.mp4  tags side by side (room camera over wall camera),
                           same frames
Depth = cm below the floor collider top (positive = in the floor), worst foot.
First floor impact = first post hand-off step with a foot collider within 0.5 cm
of the floor top. Rest = every Kim body below 0.05 m/s for 15 frames (0.5 s).
Rendered runs include hit-stop, so game time and movie time differ; the step
log records the drawn-frame count at each physics step."""
import json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

src, out, fixture, tags = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 14)
LABEL = {"base": "aecd0f1", "c434672": "c434672", "fix": "fix"}
CAMS = ["room", "wall"]
# Fixed crop (x0, y0, x1, y1 in the 1280x720 render) around the landing feet per
# fixture and camera, the same for every runtime.
CROP = {("ledge", "room"): (300, 200, 1140, 640), ("ledge", "wall"): (360, 150, 1200, 590),
        ("open", "room"): (300, 200, 1140, 640), ("open", "wall"): (260, 150, 1100, 590)}


def feet(r, key):
    return max(r[s][key] for s in ("L", "R"))


def analyse(tag, cam="room"):
    d = json.load(open(f"{src}/{tag}-{fixture}-{cam}.json"))
    other = json.load(open(f"{src}/{tag}-{fixture}-{'wall' if cam == 'room' else 'room'}.json"))
    same = other["steps"] == d["steps"] and other["events"] == d["events"]
    frames = {f["frame"]: f for f in d["frames"]}
    steps = [r for r in d["steps"] if "L" in r]
    hand = next(e for e in d["events"] if e["event"].startswith("flight_end"))
    post = [r for r in steps if not r["flight"]]

    def at(r):
        f = frames.get(r["frame"], {})
        return {"step": r["step"], "frame": r["frame"], "movie_s": round(r["frame"] / 30.0, 3),
                "game_s": f.get("game_s"), "shoe_cm": feet(r, "shoe_cm"), "collider_cm": feet(r, "collider_cm"),
                "floor_normal_down": sum(r[s]["floor_normal_down"] for s in ("L", "R"))}

    first = next((r for r in post if feet(r, "collider_cm") >= -0.5), None)
    deep_shoe = max(post, key=lambda r: feet(r, "shoe_cm"))
    deep_col = max(post, key=lambda r: feet(r, "collider_cm"))
    rest, run = None, 0
    for fr in sorted(frames):
        if fr <= hand["frame"]:
            continue
        run = run + 1 if frames[fr]["fastest_body_m_s"] < 0.05 else 0
        if run >= 15:
            rest = fr
            break
    rest_step = next((r for r in reversed(post) if r["frame"] <= rest), None) if rest else None
    return {
        "room_and_wall_renders_same_physics": same,
        "floor": d["floor"],
        "handoff": {"event": hand["event"], "frame": hand["frame"], "movie_s": hand["movie_s"], "game_s": hand["game_s"],
                    "step": next((r["step"] for r in post), None)},
        "first_floor_impact": at(first) if first else None,
        "deepest_shoe": at(deep_shoe),
        "deepest_collider": at(deep_col),
        "pre_handoff_max": {"shoe_cm": max((feet(r, "shoe_cm") for r in steps if r["flight"]), default=None),
                            "collider_cm": max((feet(r, "collider_cm") for r in steps if r["flight"]), default=None)},
        "down_contact_steps": sum(1 for r in post if any(r[s]["floor_normal_down"] for s in ("L", "R"))),
        "rest": dict(at(rest_step), reached=True) if rest_step else {"reached": False, "last": at(post[-1]),
                                                                     "last_fastest_m_s": d["frames"][-1]["fastest_body_m_s"]},
    }, steps, frames


def grab(tag, cam, first, last, width):
    tmp = tempfile.mkdtemp()
    x0, y0, x1, y1 = CROP.get((fixture, cam), (0, 0, 1280, 720))
    subprocess.run(["ffmpeg", "-v", "error", "-i", f"{src}/{tag}-{fixture}-{cam}.mp4", "-vf",
                    f"select='between(n\\,{first}\\,{last})',crop={x1 - x0}:{y1 - y0}:{x0}:{y0},scale={width}:-1",
                    "-vsync", "0", f"{tmp}/%04d.png"], check=True)
    return [Image.open(f"{tmp}/{f}") for f in sorted(os.listdir(tmp))]


result = {}
logs = {}
for tag in tags:
    info, steps, frames = analyse(tag)
    result[LABEL.get(tag, tag)] = info
    logs[(tag, "room")] = (steps, frames, info)
    if info["room_and_wall_renders_same_physics"]:
        logs[(tag, "wall")] = logs[(tag, "room")]
    else:
        winfo, wsteps, wframes = analyse(tag, "wall")
        result[LABEL.get(tag, tag) + " wall"] = winfo
        logs[(tag, "wall")] = (wsteps, wframes, winfo)
json.dump(result, open(f"{out}/landing-{fixture}.json", "w"), indent=1)

# Consecutive frames around each tag's deepest shoe step, room and wall camera,
# cropped to the landing feet (CROP).
W = 400
rows = []
for tag in tags:
    for cam in CAMS:
        steps, frames, info = logs[(tag, cam)]
        centre = info["deepest_shoe"]["frame"]
        rows.append((tag, cam, centre - 2, grab(tag, cam, centre - 2, centre + 2, W), steps, frames))
H = rows[0][3][0].size[1]
sheet = Image.new("RGB", (W * 5, len(rows) * (H + 40)), "black")
draw = ImageDraw.Draw(sheet)
for k, (tag, cam, first, ims, steps, frames) in enumerate(rows):
    y = k * (H + 40)
    for i, im in enumerate(ims[:5]):
        f = first + i
        sheet.paste(im, (i * W, y + 40))
        in_frame = [r for r in steps if r["frame"] == f and "L" in r]
        g = frames.get(f, {}).get("game_s")
        txt = f"{LABEL.get(tag, tag)} {cam} f{f}" + (f" g{g:.3f}s" if g is not None else "")
        txt2 = ("steps " + ",".join(str(r["step"]) for r in in_frame) + " shoe " +
                "/".join(f"{feet(r, 'shoe_cm'):.1f}" for r in in_frame) + "cm") if in_frame else "no physics step"
        draw.text((i * W + 4, y + 2), txt, fill="white", font=FONT)
        draw.text((i * W + 4, y + 20), txt2, fill="yellow", font=FONT)
sheet.save(f"{out}/landing-{fixture}-max.jpg", quality=88)

# Review video: one column per tag, room camera over wall camera, same frames.
inputs, labels, n = [], [], 0
for tag in tags:
    for cam in CAMS:
        inputs += ["-i", f"{src}/{tag}-{fixture}-{cam}.mp4"]
        labels.append(f"[{n}:v]scale=640:-1,drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:"
                      f"text='{LABEL.get(tag, tag)} {cam}  f%{{n}}':x=8:y=8:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.6[v{n}]")
        n += 1
cols = len(tags)
layout = "|".join(f"{c * 640}_{r * 360}" for c in range(cols) for r in range(2))
stack = "".join(f"[v{i}]" for i in range(n)) + f"xstack=inputs={n}:layout={layout}[out]"
subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", ";".join(labels) + ";" + stack, "-map", "[out]",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p", "-shortest",
                f"{out}/landing-{fixture}-review.mp4"], check=True)
for key in result:
    i = result[key]
    tag = key
    r = i["rest"]
    print(f"{fixture:5} {key:12} same-physics {i['room_and_wall_renders_same_physics']} handoff f{i['handoff']['frame']} | first impact "
          f"{'f%d step %d' % (i['first_floor_impact']['frame'], i['first_floor_impact']['step']) if i['first_floor_impact'] else '-'} | "
          f"deepest shoe {i['deepest_shoe']['shoe_cm']:.2f}cm f{i['deepest_shoe']['frame']} step {i['deepest_shoe']['step']} | "
          f"deepest collider {i['deepest_collider']['collider_cm']:.2f}cm f{i['deepest_collider']['frame']} | down {i['down_contact_steps']} | "
          + (f"rest f{r['frame']} shoe {r['shoe_cm']:.2f} collider {r['collider_cm']:.2f}" if r.get("reached") else f"not at rest (last {r['last_fastest_m_s']} m/s)"))
