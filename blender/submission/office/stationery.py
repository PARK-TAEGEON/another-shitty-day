"""Export optional desktop props, preserving the damage-animation pivots."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build import box, export, group


def keyboard():
    body = box("Body", (.60,.045,.22), (0,0,0), "chalk", .009)
    box("Well", (.575,.004,.193), (0,.022,0), "steel", .002, body)
    for row in range(3):
        for col in range(11):
            key = row*11 + col
            color = "signal" if key == 10 else ("graphite" if col == 10 else "paper")
            cap = box(f"Key{key:02}", (.041,.016,.040), (-.255+col*.05,.032,-.07+row*.05), color, .003)
            if col in (4,7) and row == 1:
                box(f"Home{key}", (.014,.0015,.003), (0,.008, .009), "steel", .0006, cap)
    box("Space", (.24,.016,.029), (0,.032,.081), "paper", .003)


def paper():
    for i in range(4):
        sheet = box(f"Sheet{i}", (.28,.009,.35), (i*.012,i*.014,0), "chalk" if i%2==0 else "paper", .002)
        sheet.rotation_euler.z = i*.07
        if i == 3:
            box("Letterhead", (.105,.0015,.015), (-.061,.005,-.128), "teal", .0007, sheet)
            for row, width in enumerate([.19,.17,.20,.12,.15]):
                box(f"Rule{row}", (width,.0015,.004), (-.11+width/2,.005,-.047+.024*row), "steel", .0007, sheet)
    box("Label", (.051,.003,.034), (.136,.048,.103), "signal", .0015)


def binder():
    box("Back", (.24,.009,.32), (0,-.028,0), "teal", .003)
    box("Spine", (.017,.065,.32), (-.112,0,0), "graphite", .004)
    pages = box("Pages", (.21,.043,.28), (.015,0,.01), "chalk", .003)
    box("Index", (.018,.003,.048), (.100,.012,-.067), "signal", .001, pages)
    hinge = group("Hinge", (-.12,.036,0))
    box("Cover", (.24,.01,.32), (.12,0,0), "teal", .004, hinge)
    box("Ticket", (.133,.003,.063), (.123,.006,-.060), "chalk", .0015, hinge)
    for i,width in enumerate([.086,.053]):
        box(f"Title{i}", (width,.0015,.005), (.074+width/2,.008,-.072+i*.020), "steel", .0006, hinge)


for builder in (keyboard, paper, binder):
    export(builder.__name__, builder)
