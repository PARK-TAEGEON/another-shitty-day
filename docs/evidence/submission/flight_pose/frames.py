#!/usr/bin/env python3
"""Consecutive 30fps frames, BEFORE row over AFTER row, labelled from the flight logs.
Usage: frames.py <dir with B-/A- mp4+json> <run> <first frame> <last frame> <out.jpg>"""
import json, subprocess, sys, tempfile, os
from PIL import Image, ImageDraw, ImageFont
src, run, first, last, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 13)
W, COLS = 300, 8
def grab(tag):
    tmp = tempfile.mkdtemp()
    subprocess.run(["ffmpeg", "-v", "error", "-i", f"{src}/{tag}-{run}.mp4", "-vf", f"select='between(n\\,{first}\\,{last})',scale={W}:-1",
                    "-vsync", "0", f"{tmp}/%04d.png"], check=True)
    log = json.load(open(f"{src}/{tag}-{run}.json"))
    rows = {r["frame"]: r for r in log["frames"]}
    events = {}
    for e in log["events"]:
        events.setdefault(e["frame"], []).append(e["event"].replace("flight_end_", "end_"))
    return [Image.open(f"{tmp}/{f}") for f in sorted(os.listdir(tmp))], rows, events
(bi, br, be), (ai, ar, ae) = grab("B"), grab("A")
H = bi[0].size[1]
n = min(len(bi), len(ai)); chunks = (n + COLS - 1) // COLS
sheet = Image.new("RGB", (W * COLS, chunks * (2 * H + 4)), "black")
d = ImageDraw.Draw(sheet)
for i in range(n):
    f = first + i; x = (i % COLS) * W; y = (i // COLS) * (2 * H + 4)
    for k, (ims, rows, ev, tag) in enumerate([(bi, br, be, "BEFORE"), (ai, ar, ae, "AFTER")]):
        sheet.paste(ims[i], (x, y + k * H))
        r = rows.get(f)
        label = f"{tag} f{f} {f/30:.3f}s"
        if r: label += f" g{r['game_s']:.3f} u{r['u']:.2f}" + (" FLY" if r["flight"] else "")
        d.rectangle((x, y + k * H, x + W, y + k * H + 16), fill=(0, 0, 0))
        d.text((x + 3, y + k * H + 1), label, fill=(255, 230, 0), font=font)
        if f in ev:
            d.rectangle((x, y + k * H + 17, x + W, y + k * H + 33), fill=(160, 0, 0))
            d.text((x + 3, y + k * H + 18), ",".join(ev[f]), fill="white", font=font)
sheet.save(out, quality=85)
print(out, n)
