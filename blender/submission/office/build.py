"""Run in Blender background mode. Dimensions and pivots below use Godot XYZ, metres."""
import math
from pathlib import Path

import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
OUTPUT = SOURCE.parents[2] / "game/assets/submission/office"
PALETTE = {
    "graphite": "283c42", "steel": "61767a", "alloy": "abbab0", "chalk": "e7dfc9",
    "oak": "cdaf86", "edge": "9c7954", "felt": "728785", "seam": "637977",
    "teal": "39716f", "paper": "d8e4cc", "signal": "de995c", "coffee": "493225",
}


def xyz(pos):
    x, y, z = pos
    return (x, -z, y)


def mat(key):
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    rgb = bytes.fromhex(PALETTE[key])
    rgba = [((v / 255 + .055) / 1.055) ** 2.4 for v in rgb] + [1]
    m.diffuse_color = rgba
    m.use_nodes = True
    node = m.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = rgba
    node.inputs["Roughness"].default_value = .86
    return m


def group(name, pos=(0, 0, 0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = xyz(pos)
    return obj


def box(name, size, pos, color, bevel=.006, parent=None):
    x, y, z = size
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (x, z, y)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.parent = parent
    obj.location = xyz(pos)
    obj.data.materials.append(mat(color))
    if bevel:
        mod = obj.modifiers.new("Pressed edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return obj


def lathe(name, profile, bands, parent=None):
    vertices, faces = [], []
    count = 32
    for radius, height in profile:
        for i in range(count):
            a = math.tau * i / count
            vertices.append((radius * math.cos(a), radius * math.sin(a), height))
    for ring in range(len(profile) - 1):
        for i in range(count):
            a = ring * count + i
            b = ring * count + (i + 1) % count
            faces.append((a, b, b + count, a + count))
    faces += [tuple(reversed(range(count))), tuple(range(len(vertices)-count, len(vertices)))]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    colors = list(dict.fromkeys(bands))
    for color in colors:
        mesh.materials.append(mat(color))
    for p in mesh.polygons:
        ring = min(p.index // count, len(bands)-1)
        p.material_index = colors.index(bands[ring])
    return obj


def mug():
    # Closed ceramic wall, contrasting unglazed foot and interior glaze.
    lathe("Body", [(.073,-.105),(.081,-.100),(.081,-.093),(.091,-.084),
                   (.095,.087),(.095,.102),(.092,.105),(.084,.105),(.082,.100),
                   (.078,.082),(.071,-.079)], ["chalk","chalk","teal","teal","chalk",
                   "chalk","chalk","chalk","chalk","chalk"])
    lathe("Coffee", [(.078,.104),(.078,.109),(.075,.112)], ["coffee","coffee"])
    for name, size, pos in [
        ("HandleUpper",(.09,.032,.035),(.112,.06,0)),
        ("HandleGrip",(.035,.12,.035),(.154,0,0)),
        ("HandleLower",(.09,.032,.035),(.112,-.06,0))]:
        box(name, size, pos, "teal", .003)


def monitor():
    h = group("Head",(0,.27,0))
    box("Housing",(.72,.44,.075),(0,0,0),"graphite",.015,h)
    box("Screen",(.65,.36,.008),(0,.01,.042),"teal",.004,h)
    # Graphic primitives share the screen's damage/flicker visibility.
    box("RowTitle",(.27,.022,.003),(-.154,.147,.048),"paper",.001,h)
    for i, width in enumerate([.23,.14,.19,.12]):
        box(f"RowList{i}",(width,.011,.003),(-.286+width/2,.085-i*.047,.048),"alloy",.001,h)
    for i,height in enumerate([.046,.092,.072,.130,.154]):
        box(f"RowBar{i}",(.032,height,.003),(.044+i*.048,-.10+height/2,.048),
            "signal" if i==4 else "paper",.001,h)
    box("Badge",(.06,.007,.003),(0,-.195,.039),"alloy",.001,h)
    box("RearCowl",(.45,.29,.023),(0,0,-.041),"steel",.011,h)
    for i in range(6):
        box(f"Vent{i}",(.19,.006,.002),(0,.089-i*.015,-.053),"graphite",.001,h)
    box("Stand",(.065,.20,.070),(0,-.02,0),"steel",.007)
    box("Base",(.33,.028,.24),(0,-.115,.015),"graphite",.012)


def desk():
    # The width adjustment stretches the slab and rail only. Legs stay 17 cm inboard.
    top = group("Surface")
    box("Nosing",(2.9,.105,1.3),(0,.98,0),"edge",.013,top)
    box("Laminate",(2.84,.028,1.26),(0,1.047,0),"oak",.008,top)
    box("Reveal",(2.87,.012,1.28),(0,1.030,0),"graphite",.003,top)
    rail = group("Rail")
    box("Apron",(2.70,.33,.06),(0,.72,-.44),"steel",.009,rail)
    for side, sign in [("Left",-1),("Right",1)]:
        leg = group(side,(sign*1.28,0,0))
        box(side+"Panel",(.096,.88,.94),(0,.47,0),"chalk",.012,leg)
        box(side+"Foot",(.11,.055,1),(0,.0125,0),"graphite",.009,leg)
        for i in range(3):
            box(side+f"Press{i}",(.004,.53,.014),(sign*.049,.50,.33-i*.042),"alloy",.001,leg)


def partition():
    # Replacement infill only. Original cap, posts and notices remain on their existing mounts.
    box("Felt",(2.7,1.5,.12),(0,0,0),"felt",.012)
    for sign in (-1,1):
        for x in (-.45,.45):
            box(f"Seam{sign}_{x}",(.010,1.46,.003),(x,0,sign*.061),"seam",.001)
        box(f"Kick{sign}",(2.68,.105,.005),(0,-.691,sign*.062),"steel",.002)
        box(f"Strip{sign}",(2.68,.026,.005),(0,.56,sign*.062),"alloy",.002)


def export(name, builder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    builder()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / (name + ".blend")), compress=True)
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (name + ".glb")), export_format="GLB",
                              export_apply=True, export_yup=True, export_animations=False)


if __name__ == "__main__":
    for build in (desk, partition, monitor, mug):
        export(build.__name__, build)
