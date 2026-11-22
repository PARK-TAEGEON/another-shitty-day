"""Open the atelier boss_kim.blend and run with -- OUTPUT.blend [--relaxed-only]."""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

argv=sys.argv[sys.argv.index('--')+1:]
scene=bpy.context.scene
skin=bpy.data.materials['01  |  Warm ochre skin']
nail=bpy.data.materials['24  |  Nail']
old_prefix=('Hand  |','Relaxed finger','Opposed thumb','Finger nail','Thumbnail')
V=Vector
pi=math.pi

def mesh(name,vertices,faces,collection):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    collection.objects.link(obj)
    return obj

def shell(name,rings,col):
    size=len(rings[0])
    faces=[(j*size+i,j*size+(i+1)%size,(j+1)*size+(i+1)%size,(j+1)*size+i)
           for j in range(len(rings)-1) for i in range(size)]
    faces.extend([tuple(reversed(range(size))),tuple(range((len(rings)-1)*size,len(rings)*size))])
    return mesh(name,[p for ring in rings for p in ring],faces,col)

def g(x,center,width):
    return math.exp(-((x-center)/width)**2)
def signpow(x,p):
    return math.copysign(abs(x)**p,x)
def soften(obj):
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    mod=obj.modifiers.new('Interpolate sections','SUBSURF')
    mod.levels=2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)

def make(side):
    relaxed=side==1
    title='relaxed' if relaxed else 'hip'
    col=bpy.data.collections.new('Hand study | '+title)
    scene.collection.children.link(col)
    # Local coordinates are width (index to little), length from wrist, and dorsal depth.
    # Only the digits articulate between variants. The palm outline and wrist sections are shared.
    if relaxed:
        anchor=V((.548,-.085,.830))
        long=V((.06,-.065,-1)).normalized()
        outward=V((.955,-.29,.04))
    else:
        anchor=V((-.44496,-.19935,.954))
        long=V((.40043,-.28615,-.87050)).normalized()
        outward=V((-.87378,-.40535,-.26869))
    dorsal=(outward-long*outward.dot(long)).normalized()
    across=long.cross(dorsal).normalized()
    if across.y<0:across.negate()
    def world(p):
        return anchor+across*p[0]+long*p[1]+dorsal*p[2]

    shapes=[]
    nails=[]
    nail_axes={}
    skeletal_marks=[]
    rings=[]
    stations=[(-.045,.038,.025),(-.025,.041,.028),(-.006,.043,.027),
              (.012,.044,.026),(.030,.051,.026),(.053,.061,.027),
              (.078,.066,.026),(.093,.066,.025),(.105,.062,.023),
              (.114,.052,.018),(.119,.036,.011),(.120,.010,.004)]
    for d,w,h in stations:
        ring=[]
        for i in range(64):
            a=2*pi*i/64
            u=w*signpow(math.cos(a),.87)
            sine=math.sin(a)
            n=h*signpow(sine,.76)
            if sine<0:
                # Thenar and hypothenar pads frame a shallower central palm.
                thenar=.017*g(u,-.034,.025)*g(d,.053,.037)
                heel=.010*g(u,.041,.020)*g(d,.057,.040)
                pads=.006*g(d,.095+.08*u,.013)
                n+=(-thenar-heel-pads+.006*g(u,.002,.021)*g(d,.062,.031))*abs(sine)
            else:
                n+=sine*(.0023*sum(g(u,i,.006) for i in [-.045,-.015,.017,.043])*g(d,.083,.033))
            # The little finger starts closer to the wrist. Knuckles sit on an arc.
            dd=d-max(0,d/.120)**2*(.015*max(0,u/.065)+.005*min(0,u/.065)**2)
            ring.append((u,dd,n))
        rings.append(ring)
    palm=shell('Palm and carpal arch',rings,col)
    soften(palm)
    shapes.append(palm)

    def digit(name,centers,widths,depths,axis):
        centers=[V(c) for c in centers]
        rings=[]
        bases=[]
        for i,c in enumerate(centers):
            tangent=(centers[min(i+1,len(centers)-1)]-centers[max(i-1,0)]).normalized()
            width=(axis-tangent*tangent.dot(axis)).normalized()
            top=width.cross(tangent).normalized()
            # For the thumb the nail faces the radial side as well as the back.
            if name=='Thumb':
                if top.dot(V((-.8,0,.45)))<0:top.negate()
            elif top.z<0:top.negate()
            bases.append((width,top))
            ring=[]
            for k in range(20):
                a=2*pi*k/20
                ring.append(c+width*widths[i]*signpow(math.cos(a),.90)+top*depths[i]*signpow(math.sin(a),.88))
            rings.append(ring)
        for k,strength in [(3,1.0),(6,.66)]:
            direction=(centers[k+1]-centers[k-1]).normalized()
            skeletal_marks.append((centers[k],direction,*bases[k],widths[k],depths[k],strength))
        obj=shell(name,rings,col)
        soften(obj)
        shapes.append(obj)
        # Nail plate is a curved inset following the last phalanx all the way to the tip.
        idx=len(centers)-3
        start,end=centers[idx],centers[idx+1]
        width,normal=bases[idx]
        verts=[]
        faces=[]
        for j in range(11):
            v=j/10
            t=.18+.79*v
            c=start.lerp(end,t)
            w=(widths[idx]*(1-t)+widths[idx+1]*t)
            h=(depths[idx]*(1-t)+depths[idx+1]*t)
            for k in range(13):
                q=(k-6)/6
                breadth=.69*(.72+.28*math.sin(pi*v)**.5)
                rel=q*breadth
                verts.append(c+width*(rel*w)+normal*(h*(1-rel**2)**.45+.0001+.00055*(1-q*q)*math.sin(pi*v)))
                if j and k:
                    a=j*13+k
                    faces.append((a-14,a-13,a,a-1))
        ob=mesh('Hand study | '+title+' | '+name+' nail',verts,faces,col)
        ob.data.materials.append(nail)
        nails.append(ob)
        nail_axes[ob]=normal

    for j,(name,u,base,length,r) in enumerate([
        ('Index',-.047,.102,.088,.0154),('Middle',-.016,.109,.097,.0161),
        ('Ring',.016,.104,.090,.0150),('Little',.046,.093,.074,.0129)]):
        bend=([16,26,35,45] if relaxed else [12,17,23,32])[j]
        spread=([-.055,-.012,.040,.093] if relaxed else [-.19,-.045,.085,.21])[j]
        root=V((u,base-.016,.003))
        pts=[root]
        # MCP, PIP and DIP each have a short, fuller ring on either side.
        for amount,angle in [(.017,0),(.029,5+j*1.8),(.018,8+j*1.8),(.009,bend),
                             (.017,bend+4),(.008,bend+12),(.017,bend+20),(.006,bend+25)]:
            a=math.radians(angle)
            step=amount*length/.105
            pts.append(pts[-1]+V((spread*step,math.cos(a)*step,-math.sin(a)*step)))
        digit(name,pts,[r*x for x in [1.06,1.03,.91,.98,.91,.80,.83,.73,.26]],
              [r*x for x in [1.05,1.03,.88,.97,.91,.80,.78,.70,.24]],V((1,0,0)))
    # Thumb starts deep in the thenar pad, narrows at its web, and opposes the index.
    thumb=[(-.022,.028,-.012),(-.034,.042,-.022),(-.049,.055,-.027),
           (-.061,.066,-.030),(-.068,.078,-.034),(-.070,.091,-.039),
           (-.070,.100,-.042),(-.068,.116,-.048),(-.066,.121,-.049)]
    if not relaxed:
        thumb=[(u-.010*max(0,d-.04)/.08,d,n+.010*max(0,d-.04)/.08) for u,d,n in thumb]
    digit('Thumb',thumb,[.024,.024,.021,.0178,.016,.0155,.016,.013,.005],
          [.021,.022,.020,.017,.016,.014,.014,.011,.004],V((.45,0,-.86)))

    bpy.ops.object.select_all(action='DESELECT')
    for ob in shapes:ob.select_set(True)
    bpy.context.view_layer.objects.active=palm
    bpy.ops.object.join()
    palm.name='Hand study | '+title+' | continuous skin'
    palm.data.remesh_voxel_size=.00135
    bpy.ops.object.voxel_remesh()
    for typ,properties in [('SMOOTH',{'factor':.85,'iterations':9}),('DECIMATE',{'ratio':.40})]:
        mod=palm.modifiers.new('Blend webs and retain silhouette',typ)
        for k,v in properties.items():setattr(mod,k,v)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    palm.data.materials.clear()
    palm.data.materials.append(skin)
    attr=palm.data.color_attributes.new(name='Complexion',type='FLOAT_COLOR',domain='POINT')
    def linear(h):
        return [((int(h[i:i+2],16)/255+.055)/1.055)**2.4 for i in [0,2,4]]
    base,flush=linear('D99972'),linear('C88569')
    for i,vert in enumerate(palm.data.vertices):
        u,d,n=vert.co
        amt=.23*g(d,.105,.019)+.31*g(d,.186,.022)+.18*g(u,-.052,.033)*g(d,.07,.053)
        # Flexion lines wrap towards the finger pads. Fade each incision before its endpoints.
        palmar=max(0,min(1,(-n-.006)/.014))
        distal=g(d,.090-.21*u-1.15*u*u,.00145)*g(u,.005,.047)
        middle=g(d,.065+.31*u+1.5*u*u,.00165)*g(u,.001,.044)
        life=g(u,-.008-7*(d-.054)**2-.22*(d-.054),.00155)*g(d,.053,.030)
        wrist=g(d,.001+.09*u,.00165)*g(u,0,.031)
        fold=palmar*(.73*distal+.64*middle+.64*life+.40*wrist)
        vert.co.z+=.0020*fold
        amt+=.40*fold
        # The extensor tendons fan from the wrist into four dorsal knuckles.
        back=max(0,min(1,(n-.007)/.013))
        for root in [-.047,-.016,.016,.046]:
            axis=root*(.52+.48*min(1,max(0,d/.106)))
            vert.co.z+=back*(.0029*g(u,axis,.0055)*g(d,.063,.036)+
                        .0037*g(u,root,.010)*g(d,.100-.12*root,.012))
        for c,tan,width,top,r,h,strength in skeletal_marks:
            delta=vert.co-c
            if delta.length_squared>.00052:continue
            longitudinal=delta.dot(tan)
            lateral=delta.dot(width)
            height=delta.dot(top)
            face=min(1,abs(height)/h)**2
            ridge=g(longitudinal+.0022*(lateral/r)**2,0,.0016)
            ridge+=.52*g(longitudinal+.0015*(lateral/r)**2,.0042,.0013)
            groove=ridge*face*g(lateral,0,r*.72)*strength
            vert.co-=top*math.copysign(.00120*groove,height)
            amt+=.31*groove
        amt=min(1,amt)
        attr.data[i].color=(*(a+(b-a)*amt for a,b in zip(base,flush)),1)
    palm.data.update()
    tree=BVHTree.FromPolygons([v.co for v in palm.data.vertices],[p.vertices[:] for p in palm.data.polygons])
    for ob in nails:
        normal=nail_axes[ob]
        for v in ob.data.vertices:
            hit,_,_,_=tree.ray_cast(v.co+normal*.012,-normal,.027)
            if hit is not None:
                across_plate=(v.index%13-6)/6
                along_plate=v.index//13/10
                v.co=hit+normal*(.00018+.00065*(1-across_plate**2)*math.sin(pi*along_plate))
    for ob in [palm]+nails:
        for v in ob.data.vertices:v.co=world(v.co.copy())
        if across.cross(long).dot(dorsal)<0:ob.data.flip_normals()
        for poly in ob.data.polygons:poly.use_smooth=True
        ob.data.update()
    for ob in list(scene.objects):
        if ob.name.startswith(old_prefix):
            center=sum((V(p) for p in ob.bound_box),V())/8
            if center.x*side>0:bpy.data.objects.remove(ob,do_unlink=True)

make(1)
if '--relaxed-only' not in argv:make(-1)
bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(Path(argv[0]).resolve()),compress=True)
