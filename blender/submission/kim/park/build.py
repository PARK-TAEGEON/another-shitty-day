"""Build Park's office character. Run with blender -b --python-exit-code 1 --python this_file.

The named controls are the existing office NPC's shoulder, elbow, hip, knee,
ankle, head and tie pivots. Local geometry follows their typing, startle and
walk automatically. Blender metres, forward -Y. "Left" matches the actor's
original negative-X control. The editable source keeps clothing details separate.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

FOLDER = Path(__file__).resolve().parent
ROOT = FOLDER.parents[3]
sys.path.insert(0, str(FOLDER))


def material(name, rgb, roughness=0.8, metal=0):
    def linear(value):
        n = int(value, 16) / 255
        return n / 12.92 if n <= 0.04045 else ((n + 0.055) / 1.055) ** 2.4
    color = tuple(linear(rgb[i:i+2]) for i in (0, 2, 4)) + (1.0,)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metal
    return mat


def pivot(name, parent, at):
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.empty_display_type = "PLAIN_AXES"
    obj.empty_display_size = 0.045
    obj.parent = parent
    obj.location = at
    return obj


def geometry(name, parent, vertices, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(mat)
    data.update()
    if smooth:
        for polygon in data.polygons:
            polygon.use_smooth = True
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    return obj


def loft(name, parent, rows, mat, segments=24, exponent=0.9):
    """Horizontal cross-sections specified bottom-up as (z, rx, ry, x, y)."""
    points, faces = [], []
    for z, rx, ry, x, y in rows:
        for i in range(segments):
            angle = 2 * math.pi * i / segments
            u, v = math.cos(angle), math.sin(angle)
            points.append((x + rx * math.copysign(abs(u)**exponent, u),
                           y + ry * math.copysign(abs(v)**exponent, v), z))
    for band in range(len(rows)-1):
        for i in range(segments):
            a = band*segments+i
            b = band*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(range(len(points)-segments,len(points))))
    return geometry(name,parent,points,faces,mat,smooth=True)


def strand(name,parent,points,radius,mat):
    curve = bpy.data.curves.new(name,"CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    curve.use_fill_caps = True
    path = curve.splines.new("BEZIER")
    path.bezier_points.add(len(points)-1)
    for knot,co in zip(path.bezier_points,points):
        knot.co = co
        knot.handle_left_type = knot.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name,curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    curve.materials.append(mat)
    return obj


def panel(name, parent, points, mat, thickness=0.004):
    # Primarily on front (-Y): arbitrary 3D ribbon or panel with closed back.
    n = len(points)
    vertices = list(points)+[(x,y+thickness,z) for x,y,z in points]
    faces = [tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj = geometry(name,parent,vertices,faces,mat)
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def button(name,parent,x,y,z,radius,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.location = x,y,z
    obj.scale = radius, radius*0.35, radius
    obj.data.materials.append(mat)
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj


def torso():
    c = pivot("ParkTorso",None,(0,0,0))
    # Narrow, sloping shoulders and a small bloused shirt above a high belt.
    loft("Oxford shirt | tapered yoke",c,[
        (.812,.162,.116,0,.002),(.841,.174,.120,0,.003),
        (.875,.183,.131,-.001,.001),(.91,.203,.140,-.003,0),
        (.945,.206,.146,-.004,.001),(1.007,.189,.131,-.005,.004),
        (1.12,.184,.136,-.007,.008),(1.25,.202,.144,-.007,.012),
        (1.355,.218,.146,-.005,.008),(1.394,.226,.138,-.003,.005),
        (1.425,.211,.126,0,.002),(1.465,.130,.097,0,-.006),
        (1.49,.073,.071,0,-.014)],cloth,32,.90)
    loft("Neck | forward set",c,[
        (1.431,.064,.058,0,-.003),(1.484,.067,.063,0,-.010),
        (1.55,.058,.058,-.002,-.020),(1.635,.066,.066,-.003,-.035),
        (1.66,.056,.047,-.003,-.040)],skin,24)
    loft("Trousers | hip and rise",c,[
        (.687,.042,.057,0,.008),(.703,.092,.085,0,.008),
        (.727,.150,.109,0,.005),
        (.762,.188,.139,0,.004),(.821,.177,.126,0,.002),
        (.854,.171,.121,0,.002)],slack,28,.9)
    loft("Belt | stained leather",c,[(.832,.182,.130,0,0),
        (.837,.184,.132,0,0),(.875,.181,.131,0,0),(.88,.178,.127,0,0)],leather)
    for x in (-.121,.119):
        panel("Trouser belt keeper",c,[(x-.012,-.112,.883),(x+.012,-.112,.883),
              (x+.013,-.113,.828),(x-.011,-.113,.828)],slack)
    panel("Belt plate",c,[(-.037,-.137,.877),(.038,-.137,.877),
          (.038,-.138,.837),(-.037,-.138,.837)],metal)
    panel("Buckle inset",c,[(-.027,-.141,.869),(.028,-.141,.869),
          (.028,-.142,.845),(-.027,-.142,.845)],leather)
    strand("Buckle tongue",c,[(-.012,-.146,.858),(.029,-.146,.858)],.002,metal)
    for sx in (-1,1):
        panel("Button-down collar leaf",c,[(sx*.045,-.075,1.496),
              (sx*.089,-.066,1.487),(sx*.14,-.084,1.447),
              (sx*.112,-.123,1.385),(sx*.021,-.128,1.442)],cuff)
        button("Collar button",c,sx*.109,-.127,1.398,.006,button_mat)
    panel("Left breast pocket",c,[(.077,-.139,1.317),(.16,-.113,1.317),
           (.158,-.116,1.241),(.115,-.139,1.22),(.075,-.145,1.238)],cloth)
    strand("Pocket top seam",c,[(.076,-.141,1.305),(.115,-.134,1.303),(.157,-.119,1.305)],.0017,stitch)
    strand("Shirt placket",c,[(.010,-.132,1.43),(.006,-.137,1.255),(.005,-.132,1.11),(.008,-.148,.945),(.009,-.129,.88)],.003,stitch)
    for z,y in [(1.27,-.141),(1.11,-.138),(.95,-.150),(.895,-.138)]:
        button("Shell shirt button",c,.009,y,z,.006,button_mat)
    # Front folds run from the tucked waist into the side seams.
    for sx in (-1,1):
        for i in range(2):
            strand("Pressed waist fold",c,[(sx*(.068+.045*i),-.131,.882),
                (sx*(.088+.044*i),-.145+.027*i,.926),
                (sx*(.108+.046*i),-.125+.029*i,.981+.017*i)],.002,cloth_shadow)
        strand("Shirt side seam",c,[(sx*.174,.045,.88),(sx*.194,.050,.947),
               (sx*.178,.046,1.065),(sx*.195,.045,1.28)],.0023,stitch)
    t=pivot("ParkTie",c,(0,-.181,1.405))
    # Original tie pivot is slightly ahead of this thinner shirt.
    loft("Tie knot | four-in-hand",t,[(-.018,.015,.012,0,.027),
             (.002,.024,.018,0,.031),(.035,.033,.018,-.002,.037),
             (.047,.019,.015,-.002,.048)],tie,14,.83)
    panel("Tie | narrow blade",t,[(-.014,.027,-.010),(.014,.027,-.010),
          (.027,.026,-.17),(.041,.025,-.366),(.044,.026,-.49),
          (.012,.032,-.534),(-.036,.026,-.49),(-.028,.025,-.36),
          (-.020,.026,-.17)],tie)
    for sx in (-1,1):
        strand("Lanyard | cotton tape",c,[(sx*.089,-.037,1.479),
              (sx*.119,-.112,1.405),(sx*.086,-.148,1.286),
              (sx*.043-.016,-.153,1.134),(-.027,-.150,1.072)],.0047,strap)
    strand("Pass clip",c,[(-.028,-.151,1.075),(-.028,-.155,1.051)],.0035,metal)
    def badge_panel(name,x0,x1,z0,z1,y,mat):
        panel(name,c,[(x0,y,z1),(x1,y,z1+.001),(x1+.002,y,z0),(x0+.002,y,z0-.001)],mat,.003)
    badge_panel("Pass | clear sleeve",-.065,.012,.946,1.052,-.155,metal)
    badge_panel("Employee ID",-.06,.007,.951,1.048,-.159,paper)
    badge_panel("ID dark header",-.059,.007,1.038,1.048,-.162,strap)
    badge_panel("ID portrait field",-.054,-.031,.974,1.028,-.162,cuff)
    button("ID silhouette",c,-.044,-.164,1.012,.0045,stitch)
    for i in range(3):
        badge_panel("ID microprint",-.026,.002-i*.004,.992-i*.007,.994-i*.007,-.163,stitch)
    return c


def arm(parent,side):
    label = "Right" if side>0 else "Left"
    up=pivot("ParkArm"+label,parent,(side*.255,0,1.38))
    rows=[(-.292,.060,.063,.003,.001),(-.258,.067,.071,.004,.004),
          (-.219,.075,.073,.004,.006),(-.198,.069,.071,.004,.007),
          (-.151,.075,.075,.005,.003),(-.086,.083,.083,.004,.003),
          (-.036,.083,.080,.001,.003),(.005,.071,.074,-.003,0),
          (.041,.049,.056,-.022,-.001),(.061,.022,.036,-.039,-.002)]
    loft("Shirt sleeve | easing and shoulder",up,[(z,rx,ry,x*side,y) for z,rx,ry,x,y in rows],cloth)
    loft("Double rolled sleeve",up,[(-.282,.065,.068,side*.003,0),
      (-.275,.073,.077,side*.004,0),(-.25,.078,.079,side*.004,.003),
      (-.23,.073,.074,side*.004,.004),(-.225,.069,.073,side*.004,.005)],cuff)
    loft("Roll seam",up,[(-.266,.075,.078,side*.004,.001),
      (-.261,.076,.079,side*.004,.002),(-.258,.076,.078,side*.004,.003)],cloth_shadow)
    el=pivot("ParkElbow"+label,up,(0,0,-.285))
    loft("Forearm | ulna and wrist",el,[(-.256,.035,.034,side*.003,-.005),
         (-.236,.036,.037,side*.003,-.005),(-.196,.038,.042,side*.003,-.005),
         (-.136,.047,.051,side*.004,0),(-.075,.056,.058,side*.004,.005),
         (-.026,.058,.063,side*.002,.006),(.013,.053,.056,0,.004),
         (.041,.035,.037,0,.001)],skin)
    # Open, tapered fingers give a readable typing hand viewed side-on.
    loft("Hand | palm",el,[(-.324,.030,.042,side*.006,-.018),(-.31,.035,.046,side*.006,-.015),
         (-.275,.034,.045,side*.005,-.010),(-.252,.029,.036,side*.004,-.008),
         (-.234,.030,.032,side*.003,-.004)],skin)
    for i,(y,length) in enumerate([(-.043,.068),(-.018,.076),(.006,.070),(.027,.056)]):
        w=.0130 if i in (1,2) else .011
        z=-.303+(i==3)*.007
        loft("Typing finger "+str(i+1),el,[(z-length,.004,.005,side*.001,y-.014),
          (z-length+.007,w*.82,w*.76,side*.004,y-.014),
          (z-.039,w*.89,w*.88,side*.015,y-.010),(z-.017,w,w,side*.021,y-.006),
          (z,w*.89,w*.93,side*.018,y)],skin,12)
    loft("Hand | opposed thumb",el,[(-.336,.007,.008,side*-.027,-.059),
         (-.328,.012,.013,side*-.027,-.061),(-.305,.015,.016,side*-.019,-.057),
         (-.275,.020,.023,side*-.009,-.041),(-.256,.012,.015,0,-.025)],skin,16)


def leg(parent,side):
    label="Right" if side>0 else "Left"
    th=pivot("ParkThigh"+label,parent,(side*.125,0,.78))
    sh=pivot("ParkShin"+label,th,(0,0,-.36))
    ft=pivot("ParkFoot"+label,sh,(0,0,-.31))
    loft("Slacks | thigh",th,[(-.393,.064,.070,side*.001,-.003),(-.375,.077,.080,0,-.002),
      (-.357,.082,.086,0,-.002),
      (-.311,.084,.093,0,0),(-.215,.087,.1,side*-.002,.002),
      (-.120,.094,.106,side*-.004,.003),(-.025,.105,.114,side*-.008,.005),
      (.041,.090,.106,side*-.012,.005)],slack,26,.91)
    loft("Slacks | calf",sh,[(-.321,.066,.073,0,0),(-.298,.074,.079,0,.004),
      (-.277,.067,.074,.001,.007),(-.252,.068,.078,side*.002,.005),
      (-.205,.063,.076,0,.006),(-.139,.070,.079,0,.012),
      (-.084,.078,.086,0,.015),(-.032,.078,.084,0,.004),
      (.02,.077,.081,0,-.001),(.04,.053,.056,0,0)],slack)
    for parent_p,z1,z2,x in [(th,-.03,-.323,.083),(sh,-.045,-.267,.069)]:
        strand("Outseam",parent_p,[(side*x,.026,z1),
               (side*(x+.001),.014,(z1+z2)/2),(side*(x-.003),.017,z2)],.002,slack_edge)
    # The low heel and asymmetrical toe share the same ankle transform as the original shoe.
    loft("Oxford | outsole",ft,[(-.102,.083,.145,0,-.047),(-.099,.089,.150,0,-.047),
         (-.084,.090,.151,0,-.047),(-.077,.086,.147,0,-.047)],sole,28,.76)
    loft("Oxford | leather upper",ft,[(-.083,.086,.148,0,-.048),(-.069,.088,.145,0,-.047),
      (-.049,.084,.138,0,-.039),(-.028,.079,.116,0,-.024),(.003,.069,.089,0,-.002),
      (.029,.061,.066,0,.010),(.041,.052,.055,0,.012)],leather,28,.80)
    strand("Oxford | toe cap stitching",ft,[(-.065,-.138,-.054),(-.040,-.149,-.038),
           (0,-.153,-.033),(.040,-.149,-.038),(.065,-.138,-.054)],.0017,scuff)
    for i in range(4):
        y=-.052+i*.013
        z=.004+i*.005
        strand("Oxford | crossed laces",ft,[(-.031,y,z),(-.002,y-.008,z+.009),(.029,y+.007,z)],.0025,sole)


def merge_for_export():
    # Keep object pivots while collapsing static material panels into one mesh
    # per driven part. Joining after saving retains editable details in Blender.
    for obj in tuple(bpy.context.scene.objects):
        if obj.type == "CURVE":
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.convert(target="MESH")
    for parent in [obj for obj in bpy.context.scene.objects if obj.type == "EMPTY"]:
        children=[obj for obj in parent.children if obj.type=="MESH" and not obj.children]
        if len(children)<2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for child in children:
            child.select_set(True)
        active=next((child for child in children if child.matrix_basis.is_identity),children[0])
        bpy.context.view_layer.objects.active=active
        bpy.ops.object.join()
        active.name = parent.name + " geometry"


bpy.ops.wm.read_factory_settings(use_empty=True)
cloth=material("Washed slate Oxford","8495A4")
cuff=material("Oxford reverse weave","A1B0BA")
cloth_shadow=material("Fold shadow","71818F")
stitch=material("Slate stitching","657786")
button_mat=material("Worn horn buttons","B8B2A7",.57)
slack=material("Charcoal twill","383838")
slack_edge=material("Press and outseam","41403F")
leather=material("Brown oxford leather","4A3D39",.48)
sole=material("Heel and sole","2C2829")
scuff=material("Leather scuff","63504A")
metal=material("Brushed nickel","AAA098",.36,.45)
paper=material("Matte pass","E2DED1")
strap=material("Badge ribbon","454953")
tie=material("Ink silk","41404B",.59)
skin=material("Park | hands and neck","C78C68",.77)
torso_node=torso()
for s in (-1,1):
    arm(torso_node,s)
    leg(torso_node,s)
head=pivot("ParkHead",torso_node,(0,-.025,1.80))
import face
for obj in face.build_head():
    obj.parent=head
# Open the editable source on Park's resting expression. The game drives those
# same groups from neutral GLB transforms each frame.
eyes = [bpy.data.objects["ParkEye" + side] for side in ("L", "R")]
for eye in eyes:
    eye.scale.z = 0.48
mouth = bpy.data.objects["ParkMouth"]
mouth.scale.z = 0.12
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.shading.color_type = "MATERIAL"
            space.overlay.show_overlays = False
            space.region_3d.view_distance = 3.65
            space.region_3d.view_location = (0, 0, 1.12)
            space.region_3d.view_rotation = Vector((-.65, 4.3, -.40)).to_track_quat("-Z", "Y")
            space.region_3d.view_perspective = "ORTHO"
bpy.ops.object.select_all(action="DESELECT")
torso_node.select_set(True)
bpy.context.view_layer.objects.active = torso_node
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(FOLDER / "park_office.blend"), compress=True)
for control in [*eyes, mouth]:
    control.scale.z = 1.0
merge_for_export()
bpy.ops.export_scene.gltf(filepath=str(ROOT / "game/assets/rig_slice/park_office.glb"),
                          export_animations=False, export_cameras=False, export_lights=False)
