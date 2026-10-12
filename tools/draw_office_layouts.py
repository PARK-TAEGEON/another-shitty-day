#!/usr/bin/env python3
"""Render the three office proposals from metre-based geometry; no game edits.

Run from any directory: python tools/draw_office_layouts.py
Pillow and the repository's Korean UI font are the only drawing dependencies.
Route checks concern fixed 2-D geometry, not Godot navigation or animated NPCs.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs/design/office-layout-options.json"
OUT = ROOT / "docs/preview"
FONT = ROOT / "game/assets/fonts/KoreanUI.ttf"

INK = "#28383B"
MUTED = "#667675"
PAPER = "#F4F3EC"
WHITE = "#FFFFFF"
ZONE = {"work": "#E9EFE4", "meeting": "#E5F0F3", "copy": "#F1E8DB",
        "lounge": "#EFE4DF", "hall": "#E9E8E0"}
ORANGE = "#D45F29"
BLUE = "#286FA8"
GREEN = "#317B64"
PURPLE = "#805C95"


def font(size):
    return ImageFont.truetype(str(FONT), max(8, round(size)))


def text(draw, at, value, size=24, fill=INK, anchor="mm", stroke=0):
    draw.multiline_text(at, value, font=font(size), fill=fill, anchor=anchor,
                        align="center" if anchor == "mm" else "left", spacing=5,
                        stroke_width=stroke, stroke_fill=PAPER)


def wrap(draw, value, size, max_width):
    lines, line = [], ""
    for word in value.split():
        proposed = (line + " " + word).strip()
        if line and draw.textlength(proposed, font=font(size)) > max_width:
            lines.append(line)
            line = word
        else:
            line = proposed
    if line:
        lines.append(line)
    return "\n".join(lines)


def dashed(draw, points, fill, width=3, dash=12, gap=8):
    phase = 0.0
    for a, b in zip(points, points[1:]):
        length = math.dist(a, b)
        if not length:
            continue
        ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        t = 0.0
        while t < length:
            cycle = phase % (dash + gap)
            amount = min(length - t, (dash if cycle < dash else dash + gap) - cycle)
            if cycle < dash:
                draw.line((a[0] + ux*t, a[1] + uy*t,
                           a[0] + ux*(t+amount), a[1] + uy*(t+amount)),
                          fill=fill, width=width)
            phase += amount + 0.00001
            t += amount + 0.00001


def arrow(draw, points, fill, width=5, head=14, is_dashed=False):
    if is_dashed:
        dashed(draw, points, fill, width, 13, 8)
    else:
        draw.line(points, fill=fill, width=width, joint="curve")
    a, b = points[-2:]
    theta = math.atan2(b[1]-a[1], b[0]-a[0])
    verts = [b, (b[0]-head*math.cos(theta-.48), b[1]-head*math.sin(theta-.48)),
             (b[0]-head*math.cos(theta+.48), b[1]-head*math.sin(theta+.48))]
    draw.polygon(verts, fill=fill)


def segment_distance(p, a, b):
    dx, dy = b[0]-a[0], b[1]-a[1]
    length2 = dx*dx + dy*dy
    t = max(0, min(1, ((p[0]-a[0])*dx + (p[1]-a[1])*dy)/length2)) if length2 else 0
    return math.dist(p, (a[0]+t*dx, a[1]+t*dy))


def rect_distance(p, rect):
    x, y, w, h = rect
    return math.hypot(max(x-p[0], 0, p[0]-x-w), max(y-p[1], 0, p[1]-y-h))


def validate(layout):
    """Sample route centre lines every <= 1 cm against solid fixed footprints."""
    checks, issues = [], []
    actors = layout["actors"]
    counts = {"desks": sum(f["type"] == "desk" for f in layout["furniture"]),
              "department": sum(a["affiliation"] == "department" for a in actors),
              "other_department": sum(a["affiliation"] == "other" for a in actors)}
    assert counts == {"desks": 6, "department": 5, "other_department": 2}, counts
    for route in layout["routes"]:
        min_distance, closest = float("inf"), ""
        for a, b in zip(route["points"], route["points"][1:]):
            samples = max(1, math.ceil(math.dist(a, b) / .01))
            for step in range(samples + 1):
                p = [a[i] + (b[i]-a[i])*step/samples for i in (0, 1)]
                for item in layout["furniture"]:
                    distance = rect_distance(p, item["rect"])
                    if distance < min_distance:
                        min_distance, closest = distance, item["id"]
                for wall in layout["walls"]:
                    distance = segment_distance(p, wall["start"], wall["end"]) - wall["thickness_m"]/2
                    if distance < min_distance:
                        min_distance, closest = distance, wall["id"]
        margin = min_distance - route["radius_m"]
        checks.append({"route": route["id"], "actor_radius_m": route["radius_m"],
                       "minimum_fixed_geometry_clearance_m": round(min_distance, 3),
                       "minimum_body_edge_clearance_m": round(margin, 3),
                       "nearest_object": closest, "passes": margin >= .015})
        if margin < .015:
            issues.append(f"{layout['id']} {route['id']} clips {closest}: {margin:.3f} m margin")
    # Check furniture interiors, while allowing touching edges.
    for index, a in enumerate(layout["furniture"]):
        ax, ay, aw, ah = a["rect"]
        for b in layout["furniture"][index+1:]:
            bx, by, bw, bh = b["rect"]
            if min(ax+aw, bx+bw)-max(ax, bx) > .005 and min(ay+ah, by+bh)-max(ay, by) > .005:
                issues.append(f"Overlapping furniture: {a['id']} / {b['id']}")
    return {"method": "2D fixed-footprint route sampling at <= 0.01m, 0.34m actor radius",
            "scope": "Schematic geometry only; in-engine camera, animation and dynamic collision validation pending",
            "counts": counts, "routes": checks, "issues": issues, "passes": not issues}


def floorplan(image, layout, origin, scale, compact=False):
    d = ImageDraw.Draw(image)
    ox, oy = origin
    p = lambda xy: (ox + xy[0]*scale, oy + xy[1]*scale)
    box = lambda r: (*p(r[:2]), *p((r[0]+r[2], r[1]+r[3])))
    ratio = scale / 86
    w, h = layout["room"]["width_m"], layout["room"]["depth_m"]
    d.rectangle(box([0, 0, w, h]), fill="#FBFBF7")
    d.rectangle(box(layout["entry_corridor"]["rect"]), fill=ZONE["hall"])
    for zone in layout["zones"]:
        d.rectangle(box(zone["rect"]), fill=ZONE.get(zone["type"], ZONE["work"]))
    # A very light metre grid keeps scale readable without implying floor tiles.
    for x in range(1, 14):
        d.line((*p((x, 0)), *p((x, h))), fill="#DFE4DC", width=1)
    for y in range(1, 12):
        d.line((*p((0, y)), *p((w, y))), fill="#DFE4DC", width=1)

    # Circulation bands represent fixed-furniture clearance, not extra walls.
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for way in layout["circulation"]:
        od.line([p(q) for q in way["points"]], fill=(255, 255, 255, 140),
                width=round(way["width_m"]*scale), joint="curve")
    player = next(a for a in layout["actors"] if a["id"] == "player")
    px, py = player["position"]
    radius = layout["opening"]["radius_m"]
    fan = [(px, py)] + [(px + radius*math.cos(math.radians(a)), py + radius*math.sin(math.radians(a)))
                        for a in range(-145, -34, 5)]
    od.polygon([p(q) for q in fan], fill=(49, 123, 100, 17))
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rectangle(box([0, 0, w, h]), fill=255)
    image.alpha_composite(Image.composite(overlay, Image.new("RGBA", image.size), mask))
    d = ImageDraw.Draw(image)

    # Room names sit in reserved floor space; smaller shared labels can be stacked.
    for zone in layout["zones"]:
        label = zone["label"]
        if zone["id"] == "hall":
            label = "중앙\n복도"
        if layout["id"] == "C" and zone["id"] == "copy":
            label = "복사"
        size = (21 if compact else 26)*ratio
        if zone["id"] == "work_north":
            size = 20*ratio
        text(d, p(zone["label_position"]), label, size, fill="#536461")

    for item in layout["furniture"]:
        r = item["rect"]
        x0, y0, x1, y1 = box(r)
        is_player = item.get("owner_id") == "player"
        fill = "#EDD4A8" if is_player else ("#D4B998" if item["type"] == "desk" else "#DBD6CA")
        if item["type"] == "sofa":
            fill = "#B7C6BB"
        d.rounded_rectangle((x0, y0, x1, y1), radius=4*ratio, fill=fill,
                            outline="#7A8173", width=max(1, round(2*ratio)))
        # A small monitor strip makes dedicated work desks unmistakable.
        if item["type"] == "desk":
            mx = (x0+x1)/2
            d.rounded_rectangle((mx-.26*scale, y0+.09*scale, mx+.26*scale, y0+.16*scale),
                                radius=2, fill="#4B5D5F")
        label = item["label"]
        if item["type"] == "desk":
            size = (21 if not compact else 23)*ratio
            cy = (y0+y1)/2 + .07*scale
            text(d, ((x0+x1)/2, cy), label, size)
        elif not compact:
            size = 17*ratio
            if r[2] < 1 and r[3] > 1:
                label = "\n".join("프린터" if "프린터" in label else "서류장")
                size = 16*ratio
            elif d.textlength(label, font(size)) > x1-x0-8:
                label = label.replace(" · ", "\n").replace(" ", "\n")
                size = min(size, 15*ratio)
            text(d, ((x0+x1)/2, (y0+y1)/2), label, size)

    for wall in layout["walls"]:
        pts = [p(wall["start"]), p(wall["end"])]
        kind = wall["type"]
        if kind == "glass":
            d.line(pts, fill="#6C9CA3", width=max(3, round(.12*scale)))
            d.line(pts, fill="#D9F4F2", width=max(1, round(.055*scale)))
        elif kind in ("low", "opening") or wall["height_m"] < 1.7:
            color = "#66775A" if wall["height_m"] < 1.2 else "#566662"
            d.line(pts, fill=color, width=max(4, round(.14*scale)))
            dashed(d, pts, "#E6EAD8", max(1, round(2*ratio)), 8*ratio, 5*ratio)
        else:
            d.line(pts, fill=INK, width=max(4, round(.13*scale)))

    for door in layout["doors"]:
        a, b = door["start"], door["end"]
        # Threshold only: walls have genuine gaps at these coordinates.
        dashed(d, [p(a), p(b)], "#8E9992", max(1, round(ratio)), 4*ratio, 6*ratio)
        if door["id"] != "entry" and not compact:
            x, y = (a[0]+b[0])/2, (a[1]+b[1])/2
            text(d, p((x, y)), f"{door['width_m']:.1f} m", 16*ratio,
                 fill=MUTED, stroke=2)

    for route in layout["routes"]:
        pts = [p(q) for q in route["points"]]
        # Small paper under-stroke separates paths from the metre grid.
        d.line(pts, fill="#FBFBF1", width=max(4, round(8*ratio)), joint="curve")
        arrow(d, pts, ORANGE if route["id"] == "boss" else BLUE,
              width=max(3, round(5*ratio)), head=16*ratio, is_dashed=route["id"] == "guard")

    for actor in layout["actors"]:
        ax, ay = p(actor["position"])
        is_player = actor["id"] == "player"
        color = GREEN if is_player else BLUE if actor["affiliation"] == "security" else PURPLE if actor["affiliation"] == "other" else INK
        rr = (.31 if is_player else .28)*scale
        if is_player:
            arrow(d, [(ax, ay-.22*scale), (ax, ay-.94*scale)], GREEN,
                  width=max(3, round(4*ratio)), head=14*ratio)
        # Back and arms of the seat; six dedicated desk positions are counted.
        if actor.get("desk_id"):
            d.arc((ax-rr-.06*scale, ay-rr, ax+rr+.06*scale, ay+rr+.13*scale),
                  start=5, end=175, fill="#86917F", width=max(2, round(3*ratio)))
        d.ellipse((ax-rr, ay-rr, ax+rr, ay+rr), fill=color, outline=WHITE,
                  width=max(2, round(3*ratio)))
        label_size = (20 if len(actor["short"]) < 2 else 16)*ratio
        text(d, (ax, ay), actor["short"], label_size, fill=WHITE)

    # Dimension lines are outside the room and identical in every proposal.
    dimension(d, p((0, -.39)), p((14, -.39)), "14.0 m", 20*ratio)
    dimension(d, p((-.43, 0)), p((-.43, 12)), "12.0 m", 20*ratio, vertical=True)
    if not compact:
        # Short local annotations, with all wall-height keys in the sidebar.
        divider = next(z for z in layout["walls"] if z["id"] == layout["opening"]["divider_id"])
        a, b = divider["start"], divider["end"]
        text(d, p(((a[0]+b[0])/2, a[1]+.22)), "빼꼼 가림막 1.54 m", 16*ratio, fill="#52615B", stroke=1)
        if layout["id"] == "B":
            text(d, p((8.7, 2.3)), "폭 1.8 m", 16*ratio, fill=MUTED)
        elif layout["id"] == "C":
            text(d, p((8.5, 10.8)), "회의실 둘레 1.6 m", 18*ratio, fill=MUTED)
        else:
            text(d, p((7.6, 8.05)), "주통로 약 2.0 m", 18*ratio, fill=MUTED)
    # Entrance is visible as an actual opening, not a drawn door on a solid wall.
    text(d, p((10.55, 12.72)), "층 입구\n1.8 m", (18 if not compact else 22)*ratio, fill=MUTED)
    text(d, p((8.7, 13.65)), "공용 복도 → 경비 진입", (19 if not compact else 23)*ratio, fill=BLUE)
    sx, sy = p((.1, 12.7))
    d.line((sx, sy, sx+2*scale, sy), fill=INK, width=max(2, round(3*ratio)))
    for x in (0, 1, 2):
        d.line((sx+x*scale, sy-5*ratio, sx+x*scale, sy+5*ratio), fill=INK, width=2)
    text(d, (sx, sy+19*ratio), "0", 17*ratio)
    text(d, (sx+2*scale, sy+19*ratio), "2 m", 17*ratio)


def dimension(d, a, b, label, size, vertical=False):
    d.line((a, b), fill="#87948E", width=1)
    for x, y in (a, b):
        d.line((x-5, y+5, x+5, y-5), fill="#87948E", width=2)
    mid = ((a[0]+b[0])/2, (a[1]+b[1])/2)
    if vertical:
        text(d, (mid[0]-27, mid[1]), label, size)
    else:
        text(d, (mid[0], mid[1]-17), label, size)


def sidebar(image, layout):
    d = ImageDraw.Draw(image)
    x, y, width = 1388, 254, 408
    d.rounded_rectangle((x-20, y-10, x+width, 1450), radius=18, fill="#FFFFFF")
    text(d, (x, y+15), "같은 조건", 27, anchor="la")
    lines = ["내부 14 × 12 m · 168 m²", "내 자리 1 + 같은 부서 5", "타 부서 2 + 경비 진입"]
    yy = y+65
    for line in lines:
        text(d, (x, yy), line, 22, anchor="la")
        yy += 36
    d.line((x, yy+6, x+width-24, yy+6), fill="#DADFD7", width=2)
    yy += 40
    text(d, (x, yy), "이 안의 플레이", 27, anchor="la")
    yy += 49
    for index, note in enumerate(layout["notes"]):
        wrapped = wrap(d, note, 22, width-55)
        text(d, (x, yy), f"{index+1}.", 22, fill=GREEN, anchor="la")
        text(d, (x+31, yy), wrapped, 22, anchor="la")
        yy += (wrapped.count("\n")+1)*31+17
    yy += 4
    trade = wrap(d, "고려할 점  " + layout["tradeoff"], 20, width-27)
    text(d, (x, yy), trade, 20, fill=MUTED, anchor="la")
    yy += (trade.count("\n")+1)*28+30
    d.line((x, yy, x+width-24, yy), fill="#DADFD7", width=2)
    yy += 26
    text(d, (x, yy), "동선과 가림막", 26, anchor="la")
    yy += 52
    for col, dashed_path, label in [(ORANGE, False, f"상사 접근 {layout['metrics']['boss_route_length_m']:.1f} m"),
                                    (BLUE, True, "경비 진입 경로"),
                                    (GREEN, False, "플레이어의 첫 시야")]:
        arrow(d, [(x, yy+13), (x+61, yy+13)], col, width=4, head=12, is_dashed=dashed_path)
        text(d, (x+78, yy), label, 21, anchor="la")
        yy += 43
    keys = [("#66775A", "낮은 가림막 1.10 m"), ("#566662", "첫 장면 가림막 1.54 m"),
            ("#80AEB4", "유리벽 2.70 m · 통과 불가")]
    for col, label in keys:
        d.line((x, yy+12, x+60, yy+12), fill=col, width=8)
        text(d, (x+78, yy), label, 20, anchor="la")
        yy += 42
    yy += 14
    text(d, (x, yy), "나  플레이어    김  김 팀장", 19, anchor="la")
    yy += 31
    text(d, (x, yy), "박·이·최·정  부서 직원", 19, anchor="la")
    yy += 31
    text(d, (x, yy), "타1·타2  타 부서    경  경비", 19, anchor="la")
    yy += 45
    text(d, (x, yy), "통로 여유", 23, anchor="la")
    yy += 37
    cc = layout["clearances"]
    text(d, (x, yy), f"주통로 {cc['main_aisle_m']:.1f} m / 보조 {cc['secondary_aisle_m']:.1f} m", 20, anchor="la")
    yy += 30
    text(d, (x, yy), f"층 입구 {cc['entry_m']:.1f} m" + (f" / 실 입구 {cc['room_doors_m']:.1f} m" if "room_doors_m" in cc else " / 코너 개방"), 20, anchor="la")


def individual(layout):
    image = Image.new("RGBA", (1850, 1610), PAPER)
    d = ImageDraw.Draw(image)
    text(d, (73, 52), "DESK BREAKER  /  사무실 구조 검토", 21, fill=MUTED, anchor="la")
    text(d, (72, 106), layout["id"] + "  " + layout["title"], 44, anchor="la")
    if layout["recommended"]:
        d.rounded_rectangle((1570, 100, 1777, 151), radius=24, fill=GREEN)
        text(d, (1673, 125), "추천안", 26, fill=WHITE)
    text(d, (74, 167), layout["subtitle"], 26, fill=MUTED, anchor="la")
    floorplan(image, layout, (118, 272), 86)
    sidebar(image, layout)
    d = ImageDraw.Draw(image)
    d.line((72, 1473, 1778, 1473), fill="#CBD3C8", width=2)
    text(d, (74, 1494), "첫 F 장면 유지  |  옆자리 박 대리의 놀람 → 가림막 위 김 팀장 → 짧은 접근과 잔소리", 23, anchor="la")
    text(d, (74, 1532), "검토용 평면 제안 · 세 안의 외곽과 축척 동일 · 고정 가구 기준 동선 확인 · 엔진 적용 전", 20, fill=MUTED, anchor="la")
    text(d, (74, 1561), "표시 치수는 게임 공간 설계용이며 건축·피난 법규 인증을 뜻하지 않습니다.", 18, fill=MUTED, anchor="la")
    return image.convert("RGB")


def comparison(layouts):
    image = Image.new("RGBA", (2820, 1400), PAPER)
    d = ImageDraw.Draw(image)
    text(d, (67, 42), "사무실 구조 3안", 42, anchor="la")
    text(d, (69, 103), "같은 14 × 12 m · 책상 6개 · 같은 부서 5명 + 타 부서 2명 · 승인된 첫 장면 유지", 25, fill=MUTED, anchor="la")
    s = 55
    titles = {"A": "열린 부서 중심", "B": "중앙 복도 + 네 공간", "C": "유리 회의실 + 순환"}
    for index, layout in enumerate(layouts):
        left = 55+index*928
        d.rounded_rectangle((left, 159, left+906, 1265), radius=20, fill="#FFFFFF")
        text(d, (left+27, 189), f"{layout['id']}  {titles[layout['id']]}", 31, anchor="la")
        if layout["recommended"]:
            d.rounded_rectangle((left+721, 181, left+863, 225), radius=20, fill=GREEN)
            text(d, (left+792, 203), "추천", 24, fill=WHITE)
        floorplan(image, layout, (left+88, 290), s, compact=True)
        d = ImageDraw.Draw(image)
        text(d, (left+35, 1110), f"주통로 {layout['clearances']['main_aisle_m']:.1f} m  ·  상사 접근 {layout['metrics']['boss_route_length_m']:.1f} m", 24, anchor="la")
        short = {"A": "한 덩어리 부서, 빠른 소동 확산", "B": "공간 관계가 명확한 작은 회사", "C": "유리 너머 반응, 두 갈래 이동"}[layout["id"]]
        text(d, (left+35, 1153), short, 28, anchor="la")
        text(d, (left+35, 1202), layout["tradeoff"], 20, fill=MUTED, anchor="la")
    # Compact shared legend for apples-to-apples reading.
    y = 1320
    arrow(d, [(74, y), (137, y)], ORANGE, 5, 15)
    text(d, (150, y), "상사 접근", 25, anchor="lm")
    arrow(d, [(362, y), (425, y)], BLUE, 5, 15, True)
    text(d, (438, y), "경비 진입", 25, anchor="lm")
    arrow(d, [(651, y+16), (651, y-17)], GREEN, 5, 15)
    text(d, (676, y), "첫 시야", 25, anchor="lm")
    text(d, (970, y), "나: 플레이어  |  김·박·이·최·정: 같은 부서  |  타1·타2: 타 부서  |  경: 경비", 24, anchor="lm")
    text(d, (73, 1364), "실제 벽 틈을 출입구로 표시. 가림막: 낮음 1.10 m / 빼꼼 1.54 m / 유리벽 2.70 m.  게임 배치 비교안이며 아직 엔진에 적용하지 않았습니다.", 20, fill=MUTED, anchor="la")
    return image.convert("RGB")


def main():
    data = json.loads(DATA.read_text())
    # Remove floating-point display noise from generated metre coordinates.
    def rounded(value):
        if isinstance(value, float):
            return round(value, 3)
        if isinstance(value, list):
            return [rounded(v) for v in value]
        if isinstance(value, dict):
            return {k: rounded(v) for k, v in value.items()}
        return value
    data = rounded(data)
    for layout in data["layouts"]:
        layout["validation"] = validate(layout)
        print(layout["id"], json.dumps(layout["validation"], ensure_ascii=False))
    if any(not a["validation"]["passes"] for a in data["layouts"]):
        raise SystemExit("Resolve geometry issues before publishing diagrams")
    data["status"] = "layout_comparison_review"
    DATA.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    OUT.mkdir(parents=True, exist_ok=True)
    for layout in data["layouts"]:
        path = OUT / f"office-layout-{layout['id'].lower()}.png"
        individual(layout).save(path)
        print(path)
    path = OUT / "office-layout-comparison.png"
    comparison(data["layouts"]).save(path)
    print(path)


if __name__ == "__main__":
    main()
