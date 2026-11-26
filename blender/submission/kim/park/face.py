"""Park's head-local mesh and expression pivots. Blender Z up, -Y forward."""
import math
import bpy
from mathutils import Matrix, Vector


def _linear(v):
    v = v / 255.0
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4


def _material(name, hex_color, roughness=.74, metal=0.0):
    m = bpy.data.materials.new("Park · " + name)
    color = tuple(_linear(int(hex_color[i:i+2], 16)) for i in (0, 2, 4)) + (1.,)
    m.diffuse_color = color
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    return m


def _mesh(name, vs, fs, material, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vs, [], fs)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for p in mesh.polygons:
        p.use_smooth = smooth
    return obj


def _cat(points, t):
    n = len(points)-1
    u = min(max(t, 0), 1) * n
    j = min(int(u), n-1)
    t = u - j
    a, b, c, d = [Vector(points[max(0, min(n, j+k))]) for k in (-1,0,1,2)]
    return .5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t**3)


def _tube(name, points, radii, mat, squash=1.0, samples=32, sides=8):
    # A tapered, swept cross-section. radii control thickness at each knot.
    vs, fs = [], []
    for i in range(samples+1):
        t = i/samples
        p = _cat(points, t)
        forward = (_cat(points,min(1,t+.001))-_cat(points,max(0,t-.001))).normalized()
        axis = Vector((0,1,0))
        if abs(forward.dot(axis)) > .92:
            axis = Vector((1,0,0))
        wide = forward.cross(axis).normalized()
        deep = forward.cross(wide).normalized()
        radius = max(.0003,_cat([(r,0,0) for r in radii], t).x)
        for k in range(sides):
            a = 2*math.pi*k/sides
            vs.append(tuple(p + radius*(math.cos(a)*wide + squash*math.sin(a)*deep)))
            if i:
                lower = (i-1)*sides
                q = (k+1)%sides
                fs.append((lower+k,lower+q,lower+sides+q,lower+sides+k))
    fs.append(tuple(reversed(range(sides))))
    fs.append(tuple(samples*sides+k for k in range(sides)))
    return _mesh(name, vs, fs, mat)


def _rings(name, rows, mat):
    vs, fs = [], []
    n = len(rows[0])
    for i,row in enumerate(rows):
        vs.extend(row)
        if i:
            a = (i-1)*n
            for j in range(n):
                k = (j+1)%n
                fs.append((a+j,a+k,a+n+k,a+n+j))
    fs.extend([tuple(reversed(range(n))), tuple((len(rows)-1)*n+i for i in range(n))])
    return _mesh(name,vs,fs,mat)


# Chin, mandible, malar plane, brow, forehead and crown.
# (z, half-width, front depth, back depth, sagittal offset)
PROFILE = [
    (-.328,.015,.027,.020,-.060),(-.319,.074,.084,.061,-.050),
    (-.294,.112,.131,.094,-.031),(-.249,.131,.147,.108,-.019),
    (-.181,.136,.148,.120,-.013),(-.105,.148,.143,.140,-.010),
    (-.035,.163,.143,.168,-.008),(.036,.179,.148,.186,-.003),
    (.106,.181,.160,.194, .004),(.166,.187,.164,.192, .005),
    (.228,.178,.157,.175,.009),(.274,.145,.131,.145,.012),
    (.310,.089,.090,.089,.012),(.325,.012,.018,.020,.013),
]


def _profile(z):
    if z <= PROFILE[0][0]:
        return PROFILE[0][1:]
    for idx in range(1,len(PROFILE)):
        a,b=PROFILE[idx-1],PROFILE[idx]
        if z <= b[0]:
            t=(z-a[0])/(b[0]-a[0])
            return tuple(v+(w-v)*t for v,w in zip(a[1:],b[1:]))
    return PROFILE[-1][1:]


def _bump(x,z,cx,cz,rx,rz):
    return math.exp(-((x-cx)/rx)**2-((z-cz)/rz)**2)


def _sculpt(x,z):
    # Sculpt the nose directly into the mid-face. The bridge widens into
    # nostril wings; the dark accents have no disconnected floating nose mesh.
    h=.048*_bump(x,z,0,.039,.031,.124)
    h+=.045*_bump(x,z,.002,-.043,.027,.088)
    h+=.095*_bump(x,z,-.003,-.086,.031,.040)
    h+=.030*_bump(abs(x),z,.032,-.092,.015,.018)
    h-=.011*_bump(abs(x),z,.040,-.098,.007,.015)
    h+=.004*_bump(abs(x),z,.012,-.141,.007,.020)
    h+=.012*_bump(abs(x),z,.126,-.020,.043,.048)
    h-=.011*_bump(abs(x),z,.098,-.147,.024,.065)
    h+=.005*_bump(abs(x),z,.045,-.154,.017,.025)
    h-=.0035*_bump(x,z,0,-.263,.008,.014)
    h-=.021*_bump(abs(x),z,.086,.063,.050,.032)
    h+=.011*_bump(abs(x),z,.083,.135,.062,.028)
    h+=.012*_bump(x,z,.003,-.174,.082,.042)
    h+=.014*_bump(x,z,0,-.261,.080,.044)
    h-=.008*_bump(x,z,0,-.216,.070,.020)
    return h


def _front(x,z):
    w,front,back,offset = _profile(z)
    t=min(1,abs(x)/w)
    # Squared front quarter of a slim jaw.
    c=max(0,1-t**2.38)**(1/2.38)
    return offset-front*c-_sculpt(x,z)*c**4


def _face_surface(skin):
    rows=[]
    for i in range(83):
        z=PROFILE[0][0]+(PROFILE[-1][0]-PROFILE[0][0])*i/82
        w,front,back,offset=_profile(z)
        row=[]
        for j in range(112):
            a=2*math.pi*j/112
            x=w*math.sin(a)
            if math.cos(a)>=0:
                y=_front(x,z)
            else:
                y=offset-back*math.cos(a)
            row.append((x,y,z))
        rows.append(row)
    return _rings("Park • continuous cheek jaw and nose",rows,skin)


def _ellipsoid(name, center, radii, mat, seg=24, bands=12):
    rows=[]
    for i in range(bands+1):
        a=-math.pi*.5+.002+(math.pi-.004)*i/bands
        row=[]
        for j in range(seg):
            t=math.tau*j/seg
            row.append((center[0]+radii[0]*math.cos(a)*math.sin(t),
                        center[1]-radii[1]*math.cos(a)*math.cos(t),
                        center[2]+radii[2]*math.sin(a)))
        rows.append(row)
    return _rings(name,rows,mat)


def _face_line(name,coords,mat):
    points=[(x,_front(x,z)-d,z) for x,z,d,r in coords]
    return _tube(name,points,[r for x,z,d,r in coords],mat,.60)


def _ear(side,skin,crease):
    vs=[];fs=[]
    for i,(radius,depth) in enumerate([(.006,-.001),(.35,-.006),(.56,.004),(.74,-.005),(.89,-.019),(1,.003),(.85,.021),(.01,.033)]):
        for j in range(32):
            t=math.tau*j/32
            u=.045*math.sin(t)*(1+.15*math.cos(t))
            z=.064*math.cos(t)+.003
            vs.append((side*(.175+radius*(u+.024)+.007*math.cos(t)),.006+depth+.27*u*radius,z*radius+.002))
            if i:
                a=(i-1)*32;k=(j+1)%32
                face=(a+j,a+k,a+32+k,a+32+j)
                fs.append(face if side<0 else face[::-1])
    obj=_mesh("Park • sculpted ear "+str(side),vs,fs,skin)
    inside=_tube("Park • ear fold "+str(side),[(side*x,y,z) for x,y,z in [
        (.186,-.003,-.011),(.192,-.014,.009),(.207,-.018,.017),(.215,-.008,.012)]],
        [.001,.003,.0025,.0005],crease,.6,16)
    return [obj,inside]


def _group(name,pivot,objects):
    empty=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(empty)
    empty.empty_display_type="PLAIN_AXES"
    empty.empty_display_size=.016
    empty.location=pivot
    for obj in objects:
        obj.parent=empty
        obj.location-=Vector(pivot)
    return empty


def _eyes(side,side_name,mats):
    cx,cz=side*.089,.057+(-.004 if side<0 else .002)
    def point(t,v):
        x=cx+side*.062*t
        opening=.037 if side<0 else .040
        lid_bias=.78 if side<0 and v>0 else (1.0 if v>0 else .92)
        z=cz-.012*t+opening*max(0,1-t*t)**.62*v*lid_bias
        # Outward offset is intentionally larger than the socket depth so an
        # eye opening around its pivot stays in front of the face at .48 scale.
        y=_front(x,cz)-.014-.009*(1-t*t)*(1-.38*v*v)
        return (x,y,z)
    vs=[];fs=[]
    for j in range(13):
        v=-1+2*j/12
        for i in range(25):
            t=-1+2*i/24
            vs.append(point(t,v))
            if i and j:
                a=j*25+i
                face=(a-26,a-25,a,a-1)
                fs.append(face if side>0 else face[::-1])
    objs=[_mesh("Park • ivory sclera "+side_name,vs,fs,mats["ivory"])]
    # Slight glance to one side rather than a crossed gaze.
    x=cx-.020
    t=(x-cx)/(side*.062); y=point(t,0)[1]-.002
    objs.append(_ellipsoid("Park • iris "+side_name,(x,y,cz+.001),(.019,.004,.026),mats["iris"]))
    objs.append(_ellipsoid("Park • pupil "+side_name,(x,y-.003,cz+.002),(.010,.003,.019),mats["dark"]))
    objs.append(_ellipsoid("Park • catchlight "+side_name,(x-.005,y-.006,cz+.016),(.003,.0015,.005),mats["ivory"],12,6))
    ts=[-.997,-.74,-.28,.20,.68,.997]
    for k,mat,radii in [(1,mats["lash"],[.001,.0035,.0045,.005,.004,.0008]),(-1,mats["lip"],[.0007,.0016,.0022,.0024,.0018,.0006])]:
        p=[Vector(point(t,k)) + Vector((0,-.002,0)) for t in ts]
        objs.append(_tube("Park • lid "+side_name+str(k),p,radii,mat,.55))
    anchor=(cx,_front(cx,cz)-.014,cz)
    return _group("ParkEye"+side_name,anchor,objs)


def _brow(side,n,mats):
    stations=[(.021,.153,.0015),(.040,.130,.010),(.066,.127,.013),(.115,.133,.012),(.145,.136,.008),(.162,.114,.001)]
    if side>0:
        stations=[(x,z-.009+.017*(1-(x-.022)/.14),r) for x,z,r in stations]
    coords=[(side*x,z,.006,r) for x,z,r in stations]
    obj=_face_line("Park • worried tapered brow "+n,coords,mats["hair"])
    return _group("ParkBrow"+n,(side*.087,-.154,.133),[obj])


def _mouth(mats):
    # Full-height negative-space shape, teeth inset in upper third. Runtime
    # scales both at an invariant pivot for the original open/close control.
    cx,cz=-.003,-.177
    def point(t,v):
        x=cx+.069*t
        arc=math.sqrt(max(0,1-t*t))
        z=cz+.008*(1-t*t)-.009*t+.042*arc*v
        y=_front(x,cz)-.006-.002*arc
        return (x,y,z)
    def patch(name,low,high,depth,mat,limit=1):
        vs=[];fs=[]
        for j,v in enumerate([low,high]):
            for i in range(29):
                t=(-1+2*i/28)*limit
                x,y,z=point(t,v)
                vs.append((x,y-depth,z))
                if j and i:
                    a=j*29+i;fs.append((a-30,a-29,a,a-1))
        return _mesh(name,vs,fs,mat)
    objs=[patch("Park • speaking mouth", -1,1,.0008,mats["mouth"]),
          patch("Park • upper teeth", .47,.92,.002,mats["ivory"],.82)]
    for k in [-1,1]:
        ps=[point(t,k) for t in [-.99,-.76,-.33,.15,.65,.99]]
        objs.append(_tube("Park • lip contour "+str(k),ps,[.001,.003,.004,.0045,.003,.0007],mats["lip"],.72))
    root=_group("ParkMouth",(cx,-.17,cz),objs)
    root.rotation_euler.y=math.radians(8)
    return root


def _glasses(mats):
    parts=[]
    for side,n in [(1,"L"),(-1,"R")]:
        cx=.092
        # A pantoscopic frame wraps toward the temples. Short corner arcs
        # soften the rectangle without giving Park round spectacles.
        coords=[(-.072,.046),(-.054,.053),(.055,.054),(.078,.045),(.080,.016),
                (.072,-.044),(.052,-.057),(-.048,-.054),(-.068,-.045),(-.075,-.001)]
        ps=[]
        for u,v in coords:
            x=side*(cx+u)
            y=-.198+.052*(abs(x)/.18)**2 + .045*v
            ps.append((x,y,.061+v-.045*u))
        # Sample cyclically to avoid flat end caps at the nose corner.
        loop=[_cat([ps[(i+j)%len(ps)] for j in (-1,0,1,2)],(1+t/6)/3)
              for i in range(len(ps)) for t in range(6)]
        ring=[]
        for j,p in enumerate(loop):
            d=(loop[(j+1)%len(loop)]-loop[(j-1)%len(loop)]).normalized()
            w=d.cross(Vector((0,-1,0))).normalized()
            v=d.cross(w); thick=.006+.0011*(p.z>.07)
            ring.append([tuple(p+thick*(math.cos(k*math.tau/8)*w+math.sin(k*math.tau/8)*v)) for k in range(8)])
        vs=[p for row in ring for p in row]; fs=[];N=len(ring)
        for j in range(N):
            for k in range(8):
                fs.append((8*j+k,8*j+(k+1)%8,8*((j+1)%N)+(k+1)%8,8*((j+1)%N)+k))
        parts.append(_mesh("Park • acetate rim "+n,vs,fs,mats["frame"]))
        ps=[(side*x,y,z) for x,y,z in [(.169,-.148,.094),(.178,-.131,.093),(.185,-.053,.089),(.185,.016,.066),(.184,.050,.024)]]
        parts.append(_tube("Park • glasses arm "+n,ps,[.006,.0055,.0045,.004,.002],mats["frame"],.72))
        parts.append(_ellipsoid("Park • hinge rivet "+n,(side*.168,-.151,.101),(.0032,.003,.0024),mats["silver"],12,6))
    parts.append(_tube("Park • saddle bridge",[(-.020,-.196,.085),(-.013,-.206,.096),(0,-.213,.098),(.013,-.206,.096),(.020,-.196,.085)],[.0048,.0058,.006,.0058,.0048],mats["frame"],.86))
    # Slightly askew as in the seated colleague portrait.
    axis=Vector((0,-.20,.067))
    tilt=Matrix.Translation(axis) @ Matrix.Rotation(math.radians(2.8),4,"Y") @ Matrix.Translation(-axis)
    for part in parts:
        part.data.transform(tilt)
    return parts


def _cap(mats):
    rows=[]
    for i in range(33):
        t=i/32
        row=[]
        for j in range(80):
            a=j*math.tau/80
            front=math.cos(a); side=math.sin(a)
            # Sideburn and nape extend below the swept forehead hairline.
            low=.016+.191*(max(0,front)**1.25)-.115*max(0,-front)
            low-=.055*math.exp(-((abs(side)-.94)/.068)**2)*max(0,front)
            low+=.028*side*max(0,front)
            z=low+(.354-low)*t
            # The forehead has a squarer section than an ellipse. Sample the
            # same skin section at this height, then expand it outwards. An
            # independently shifted ellipse clips the temple at a grazing view.
            crown = min(1.0,max(0.0,(z-.230)/.080))
            skin_z=min(.325, z-crown*.022)
            w,fd,bd,y0=_profile(skin_z)
            base_x=w*side
            base_y=_front(base_x,skin_z) if front>=0 else y0-bd*front
            cover=1.065+.045*max(0.0,1-abs(z-.145)/.25)
            x=base_x*cover
            y=y0+(base_y-y0)*cover
            row.append((x,y,z))
        rows.append(row)
    return _rings("Park • tapered hairline and nape",rows,mats["hair"])


def _lock(name,path,widths,thickness,mat):
    vs=[];fs=[];N=30;sides=12
    for i in range(N+1):
        t=i/N
        p=_cat(path,t)
        tangent=(_cat(path,min(1,t+.002))-_cat(path,max(0,t-.002))).normalized()
        radial=Vector((p.x*.8,p.y-.025,p.z-.13))
        radial.normalize()
        lateral=tangent.cross(radial).normalized()
        normal=lateral.cross(tangent).normalized()
        if normal.dot(radial)<0:normal.negate()
        w=max(.00065,_cat([(v,0,0) for v in widths],t).x)
        for k in range(sides):
            a=math.tau*k/sides
            vs.append(tuple(p+lateral*w*math.cos(a)+normal*thickness*w*math.sin(a)))
            if i:
                lo=(i-1)*sides;q=(k+1)%sides
                fs.append((lo+k,lo+q,lo+sides+q,lo+sides+k))
    fs.extend([tuple(reversed(range(sides))),tuple(N*sides+k for k in range(sides))])
    return _mesh(name,vs,fs,mat)


def _hair(mats):
    objects=[_cap(mats)]
    # Interlocking banks sweep away from an off-centre part. Each lock has
    # a broad ribbon root and a pointed tip; the centre quiff breaks the crown.
    locks=[
        ([(.099,-.122,.213),(.083,-.147,.260),(.035,-.119,.321),(-.041,-.067,.352),(-.107,-.010,.359),(-.137,.024,.320)], [.035,.053,.054,.049,.026,.002],"hair_mid"),
        ([(.057,-.145,.209),(.025,-.149,.258),(-.028,-.139,.288),(-.101,-.118,.280),(-.171,-.081,.245)], [.029,.047,.041,.029,.002],"hair_light"),
        ([(.053,-.058,.289),(.036,-.027,.342),(-.024,.019,.358),(-.082,.051,.352),(-.127,.091,.308)], [.020,.045,.044,.031,.001],"hair"),
        ([(-.017,-.143,.214),(-.041,-.155,.280),(-.097,-.126,.300),(-.145,-.100,.266),(-.209,-.043,.230)], [.035,.052,.045,.034,.001],"hair"),
        ([(-.007,-.131,.284),(-.058,-.135,.305),(-.129,-.092,.307),(-.188,-.045,.266),(-.214,-.023,.245)], [.025,.042,.036,.022,.001],"hair_mid"),
        ([(-.044,-.120,.288),(-.087,-.129,.260),(-.142,-.107,.224),(-.175,-.090,.186),(-.194,-.069,.148)], [.025,.040,.037,.030,.001],"hair_mid"),
        ([(-.091,-.090,.260),(-.147,-.095,.220),(-.172,-.068,.173),(-.176,-.060,.103),(-.180,-.045,.068)], [.025,.036,.032,.019,.001],"hair"),
        ([(-.115,.016,.278),(-.173,.038,.230),(-.198,.047,.176),(-.205,.035,.136)], [.035,.039,.027,.002],"hair_mid"),
        ([(.034,-.115,.231),(.080,-.118,.274),(.135,-.086,.301),(.170,-.035,.286),(.202,.013,.232)], [.037,.043,.038,.025,.001],"hair"),
        ([(.053,-.110,.232),(.103,-.131,.243),(.150,-.097,.225),(.178,-.075,.174),(.204,-.055,.148)], [.030,.039,.036,.027,.001],"hair_light"),
        ([(.095,-.084,.234),(.151,-.084,.203),(.177,-.075,.156),(.183,-.055,.099),(.190,-.033,.064)], [.035,.035,.030,.021,.001],"hair_mid"),
        ([(.096,.005,.278),(.155,.015,.267),(.193,.042,.222),(.210,.056,.171)], [.030,.039,.032,.001],"hair_mid"),
        ([(.026,-.012,.321),(.060,.061,.319),(.113,.126,.270),(.147,.139,.210)], [.028,.050,.038,.002],"hair_mid"),
        ([(-.029,.006,.317),(-.055,.076,.318),(-.126,.124,.268),(-.159,.133,.202)], [.040,.054,.034,.001],"hair"),
    ]
    for i,(path, widths, color) in enumerate(locks):
        objects.append(_lock("Park • swept lock %02d"%i,path,widths,.32,mats[color]))
    return objects


def build_head():
    """Return unparented, head-local roots; caller parents to its ParkHead pivot."""
    palette={
        "skin":("C78C68",.77),"crease":("A36751",.83),"lip":("AB7160",.76),
        "mouth":("49292A",.82),"ivory":("E6DDCD",.47),"iris":("5A4031",.45),
        "dark":("221919",.37),"lash":("614233",.79),"hair":("332823",.64),
        "hair_mid":("40302A",.67),"hair_light":("49362C",.66),"frame":("302F2E",.40),
    }
    mats={key:_material(key,col,rough) for key,(col,rough) in palette.items()}
    mats["silver"]=_material("hinge","AFA69A",.36,.52)
    parts=[_face_surface(mats["skin"])]
    for side,n in [(1,"L"),(-1,"R")]:
        parts.extend(_ear(side,mats["skin"],mats["crease"]))
        parts.append(_eyes(side,n,mats))
        parts.append(_brow(side,n,mats))
        # Only recess accents, with the highlights supplied by office lighting.
        parts.append(_face_line("Park • nostril "+n,[(side*.014,-.109,.002,.0009),(side*.022,-.104,.003,.0027),(side*.032,-.100,.002,.0017),(side*.037,-.092,.001,.0004)],mats["crease"]))
        parts.append(_face_line("Park • under-eye fold "+n,[(side*.040,.012,.0009,.0004),(side*.074,.000,.0012,.0017),(side*.109,.000,.0011,.0016),(side*.139,.015,.0009,.0004)],mats["crease"]))
    parts.append(_mouth(mats))
    for sign,corner_z in [(-1,-.169),(1,-.188)]:
        parts.append(_face_line("Park • downturned mouth corner "+str(sign),
              [(sign*.057,corner_z+.003,.003,.001), (sign*.067,corner_z-.001,.003,.0022),
               (sign*.073,corner_z-.010,.002,.0017), (sign*.075,corner_z-.018,.001,.0004)],mats["crease"]))
    parts.extend(_glasses(mats));parts.extend(_hair(mats))
    for root in parts:
        root["park_control"]=root.name if root.type=="EMPTY" else "Head"
    return parts
