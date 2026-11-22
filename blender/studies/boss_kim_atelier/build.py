"""Boss Kim, a static character study. Run in Blender's Python environment.

blender -b --python build.py -- --out ./output --quality final
The file contains editable meshes, native procedural materials and named cameras.
"""
import argparse
import bisect
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector
from math import sin, cos, pi, exp, sqrt, atan2

cli = argparse.ArgumentParser()
cli.add_argument('--out', type=Path, default=Path(__file__).resolve().parent)
cli.add_argument('--quality', choices=['proof','final'], default='final')
cli.add_argument('--views', nargs='+', default=['front','profile','back','three_quarter','portrait'])
cli.add_argument('--save', action='store_true')
args = cli.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
out = args.out.resolve()
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
tau = 2*pi

def section(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c

def clamp(x, a=0, b=1):
    return max(a,min(b,x))

def smooth(x):
    x=clamp(x)
    return x*x*(3-2*x)

def gauss(x,z,cx,cz,wx,wz):
    return exp(-((x-cx)/wx)**2-((z-cz)/wz)**2)

def rgb(h):
    def lin(v):
        return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    return tuple(lin(int(h[i:i+2],16)/255) for i in (0,2,4))

def material(name, color, roughness=.65, metallic=0):
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*rgb(color),1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=roughness
    p.inputs['Metallic'].default_value=metallic
    return m

def texture(m, scale, dark, light, bump_strength=.12, distance=.0007):
    nt=m.node_tree
    p=nt.nodes.get('Principled BSDF')
    tex=nt.nodes.new('ShaderNodeTexNoise')
    geom=nt.nodes.new('ShaderNodeNewGeometry')
    nt.links.new(geom.outputs['Position'],tex.inputs['Vector'])
    tex.inputs['Scale'].default_value=scale
    tex.inputs['Detail'].default_value=2.4
    ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(*rgb(dark),1)
    ramp.color_ramp.elements[1].color=(*rgb(light),1)
    nt.links.new(tex.outputs['Fac'],ramp.inputs[0])
    nt.links.new(ramp.outputs[0],p.inputs['Base Color'])
    bump=nt.nodes.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=bump_strength
    bump.inputs['Distance'].default_value=distance
    nt.links.new(tex.outputs['Fac'],bump.inputs['Height'])
    nt.links.new(bump.outputs[0],p.inputs['Normal'])
    return m

skin=material('01  |  Warm ochre skin','D89570',.60)
skin.node_tree.nodes.get('Principled BSDF').inputs['Subsurface Weight'].default_value=.035
skin_nt=skin.node_tree
skin_attr=skin_nt.nodes.new('ShaderNodeVertexColor')
skin_attr.layer_name='Complexion'
skin_nt.links.new(skin_attr.outputs['Color'],skin_nt.nodes.get('Principled BSDF').inputs['Base Color'])
rim_skin=material('02  |  Eyelid warmth','BF795F',.64)
crease=material('03  |  Warm occlusion','653C34',.79)
mouth=material('04  |  Lip separation','663A34',.73)
white=material('05  |  Warm sclera','EEE2CB',.32)
iris=material('06  |  Umber iris','624639',.34)
limbus=material('07  |  Deep umber','2E2423',.41)
glint=material('08  |  Catchlight','FFF4DB',.35)
for m in [white,iris,limbus]:
    shader=m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Specular IOR Level'].default_value=.11
    shader.inputs['Roughness'].default_value=.49
hair=texture(material('09  |  Brushed espresso','3A2E2A',.60),195,'16151A','3D302C',.09,.00035)
brow=material('10  |  Brows','382B28',.74)
wool=texture(material('11  |  Smoke brown worsted','483F40',.89),420,'343032','5B5151',.2,.0009)
lapel=texture(material('12  |  Pressed lapel','514749',.76),380,'393338','665955',.16,.0007)
trouser=texture(material('13  |  Pressed trousers','423C3E',.90),440,'312E33','594F4D',.16,.0007)
shirt=texture(material('14  |  Bone poplin','EBE3D3',.85),490,'D3CABB','FAF2E1',.09,.0004)
wine=texture(material('15  |  Oxblood silk','722F3B',.52),340,'692C35','903F43',.14,.0007)
motif=material('16  |  Silk jacquard','AB6B59',.61)
seam=material('17  |  Welt edge','393235',.90)
stitch=material('18  |  Warm binding','615451',.81)
button=material('19  |  Dark horn','3C3231',.4)
brass=material('20  |  Aged nickel','BAAD91',.32,.76)
leather=texture(material('21  |  Espresso calfskin','332C2A',.37),240,'242022','443633',.08,.00045)
sole=material('22  |  Dark sole','272528',.7)
laces=material('23  |  Waxed laces','443733',.65)
nail=material('24  |  Nail','D89D83',.52)
skin_base=rgb('D99972')

def mix(a,b,t):
    return tuple(i*(1-t)+j*t for i,j in zip(a,b))

def mesh(name, verts, faces, mat, sub=0, color=None):
    d=bpy.data.meshes.new(name)
    d.from_pydata(verts,[],faces)
    d.update()
    ob=bpy.data.objects.new(name,d)
    group.objects.link(ob)
    d.materials.append(mat)
    for p in d.polygons:
        p.use_smooth=True
    if mat==skin:
        attr=d.color_attributes.new(name='Complexion',type='FLOAT_COLOR',domain='POINT')
        colors=[]
        for v in verts:
            colors.extend((*(color(*v) if color else skin_base),1))
        attr.data.foreach_set('color',colors)
    if sub:
        mod=ob.modifiers.new('Tailored subdivision','SUBSURF')
        mod.levels=mod.render_levels=sub
    return ob

def surface(name, fn, nu,nv,mat, wrap=False, flip=False, sub=0, color=None):
    stride=nu if wrap else nu+1
    vs=[fn(i/nu,j/nv) for j in range(nv+1) for i in range(stride)]
    fs=[]
    for j in range(nv):
        for i in range(nu):
            a=j*stride+i
            b=j*stride+(i+1)%stride
            f=(a,b,b+stride,a+stride)
            fs.append(f[::-1] if flip else f)
    return mesh(name,vs,fs,mat,sub,color)

def line(name,pts,radii,mat,sides=8,sub=1):
    """An elliptical cross-section swept parallel to its preceding frame."""
    vs=[]
    old=None
    for i,pos in enumerate(pts):
        p=Vector(pos)
        t=(Vector(pts[min(i+1,len(pts)-1)])-Vector(pts[max(0,i-1)])).normalized()
        if old is None:
            guide=Vector((0,-1,0)) if abs(t.y)<.8 else Vector((0,0,1))
        else:
            guide=old
        n=(guide-t*t.dot(guide)).normalized()
        b=t.cross(n).normalized()
        old=n
        r=radii[i] if isinstance(radii,list) else radii
        rn,rb=r if isinstance(r,tuple) else (r,r)
        for j in range(sides):
            a=tau*j/sides
            vs.append(tuple(p+n*(rn*cos(a))+b*(rb*sin(a))))
    fs=[]
    for i in range(len(pts)-1):
        for j in range(sides):
            k=i*sides+j
            m=i*sides+(j+1)%sides
            fs.append((k,m,m+sides,k+sides))
    fs.extend([tuple(reversed(range(sides))),tuple(range(len(vs)-sides,len(vs)))])
    return mesh(name,vs,fs,mat,sub)

class Profile:
    """Monotone cubic interpolation of art-directed horizontal sections."""
    def __init__(self, rows):
        self.z=[r[0] for r in rows]
        self.channels=[]
        for ys in zip(*(r[1:] for r in rows)):
            ds=[(b-a)/(v-u) for a,b,u,v in zip(ys,ys[1:],self.z,self.z[1:])]
            ms=[ds[0]]+[2*a*b/(a+b) if a*b>0 else 0 for a,b in zip(ds,ds[1:])]+[ds[-1]]
            self.channels.append((ys,ms))
    def __call__(self,z):
        i=max(0,min(len(self.z)-2,bisect.bisect_right(self.z,z)-1))
        h=self.z[i+1]-self.z[i]
        t=clamp((z-self.z[i])/h)
        return tuple((1+2*t)*(1-t)**2*y[i]+t*(1-t)**2*h*m[i]+t*t*(3-2*t)*y[i+1]+t*t*(t-1)*h*m[i+1] for y,m in self.channels)

def signpow(v,p):
    return math.copysign(abs(v)**p,v)

def ell(name,c,sc,mat,sub=1):
    def fn(u,v):
        a=tau*u
        b=pi*(v*.998+.001)
        return (c[0]+sc[0]*cos(a)*sin(b),c[1]-sc[1]*sin(a)*sin(b),c[2]-sc[2]*cos(b))
    return surface(name,fn,20,14,mat,True,True,sub)

group=section('01   •   Facial sculpture')
# Width, front and rear depth have independent stations; the chin overhangs the throat.
head=Profile([(1.475,.015,-.120,-.102),(1.492,.115,-.203,.005),(1.519,.205,-.249,.090),
 (1.55,.252,-.274,.128),(1.595,.262,-.280,.145),(1.665,.252,-.267,.156),
 (1.745,.231,-.246,.174),(1.83,.209,-.226,.181),(1.915,.199,-.198,.178),
 (1.992,.183,-.176,.164),(2.04,.165,-.157,.15),(2.079,.127,-.127,.116),
 (2.109,.066,-.066,.067),(2.119,.002,-.012,-.008)])
mouth_w=.146
def lip_z(x):
    u=x/mouth_w
    return 1.726-.036*u*u+.008*u+.0018*cos(u*2*pi)

def face_relief(x,z):
    a=abs(x)
    shelf=.065*gauss(a,z,0,1.603,.187,.062)-.007*gauss(x,z,0,1.605,.011,.022)
    # Canthi sit inside the orbit, with a zygomatic plane beneath its outer corner.
    cheek=.036*gauss(a,z,.148,1.797,.070,.063)+.012*gauss(a,z,.175,1.653,.045,.065)
    orbit=-.032*gauss(a,z,.091,1.891,.067,.035)
    bone=.025*gauss(a,z,.083,1.945,.085,.032)
    bridge=.065*gauss(x,z,0,1.892,.036,.078)
    tip_z=1.811+.011*smooth(a/.047)
    apex=.093*exp(-(a/.044)**2.5-abs((z-tip_z)/(.051 if z>=tip_z else .029))**2.15)
    ala=.061*gauss(a,z,.049,1.815,.020,.022)-.026*gauss(a,z,.038,1.813,.009,.017)
    muzzle=.015*gauss(x,z,0,1.748,.118,.049)
    philtrum=.004*gauss(a,z,.014,1.754,.006,.021)
    jawbreak=-.013*gauss(x,z,0,1.658,.120,.014)
    m=lip_z(x)
    lipmask=exp(-(abs(x)/.135)**6)
    lips=lipmask*(.009*exp(-((z-m-.006)/.007)**2)+.014*exp(-((z-m+.010)/.012)**2)-.009*exp(-((z-m)/.0037)**2))
    fold_center=.059+clamp((1.81-z)/.14)*.11
    fold=-.011*exp(-((a-fold_center)/.008)**2-((z-1.754)/.063)**2)
    bag=.014*gauss(a,z,.091,1.858,.056,.014)-.005*gauss(a,z,.096,1.845,.050,.006)
    glabella=-.008*gauss(a,z,.016,1.963,.005,.023)
    return shelf+cheek+orbit+bone+bridge+apex+ala+muzzle+philtrum+jawbreak+lips+fold+bag+glabella

def front_y(x,z):
    w,front,back=head(z)
    t=clamp(abs(x)/w)
    return (back+front)/2-(back-front)/2*max(0,1-t**2.50)**(1/2.50)-face_relief(x,z)*smooth((1-t)*4.3)

def face_pos(u,v):
    z=1.475+(2.119-1.475)*v
    a=tau*u
    w,f,b=head(z)
    x=w*sin(a)
    y=front_y(x,z) if cos(a)>=0 else (b+f)/2+(b-f)/2*max(0,1-(abs(x)/w)**2.2)**(1/2.2)
    # The mandible fans out in front of the ear, then narrows into the nape.
    lower=1-smooth((z-1.62)/.245)
    rear=smooth((1-cos(a))*.53)
    x*=1-.53*rear*lower
    y-=.035*rear*lower
    z+=.019*rear*lower
    # Let the septum and the tip turn under in profile, independently of the alae.
    nasal_drop=.012*gauss(x,z,0,1.813,.034,.029)
    z-=nasal_drop*max(0,cos(a))**4
    return x,y,z

def complexion(x,y,z):
    f=smooth((-.05-y)/.12)
    blush=clamp(.43*gauss(abs(x),z,.15,1.809,.077,.051)+.55*gauss(x,z,0,1.822,.066,.032))
    col=mix(skin_base,rgb('CB795E'),f*min(1,1.40*blush))
    col=mix(col,rgb('AB8375'),f*.32*gauss(abs(x),z,.09,1.868,.067,.019))
    col=mix(col,rgb('A47D6C'),f*.23*gauss(x,z,0,1.615,.195,.065))
    orbital=gauss(abs(x),z,.093,1.864,.061,.017)
    col=mix(col,rgb('BE856E'),.29*f*orbital)
    return mix(col,rgb('AE705F'),f*.63*exp(-((z-lip_z(x)+.004)/.011)**2-(abs(x)/.138)**8))
surface('Face  |  continuous orbital, nasal and mandibular planes',face_pos,192,170,skin,True,color=complexion)
ell('Neck beneath jaw',(0,.002,1.486),(.158,.143,.147),skin)
# Sculpt the crease into the same face coordinates and taper both termini.
xs=[mouth_w*(2*i/36-1) for i in range(37)]
line('Compressed asymmetric mouth',[(x,front_y(x,lip_z(x))-.0023,lip_z(x)) for x in xs],
     [.0007+.0025*sin(pi*i/36)**.65 for i in range(37)],mouth,8)
for s in [-1,1]:
    pts=[]
    for i in range(13):
        t=i/12
        x=s*(.036+.023*t)
        z=1.804+.006*sin(t*pi)-.002*t
        pts.append((x,front_y(x,z)-.0014,z))
    line('Nostril under alar wing',pts,[.0008+.0038*sin(i*pi/12)**.8 for i in range(13)],crease,8)
    # The concha is excavated within one ear surface; its outer rim and antihelix are continuous.
    def ear(u,v,s=s):
        a=tau*u
        r=.002+.998*v
        x=s*(.223+r*.047*cos(a)*(1+.15*sin(a))+.014*r*sin(a))
        z=1.821+r*.080*sin(a)
        y=-.012+.013*sin(a)-.049*exp(-((r-.81)/.19)**2)-.018*exp(-((r-.43)/.14)**2)*(1+.4*sin(a))+.027*r*cos(a)
        return x,y,z
    surface('Ear  |  helix and conchal bowl',ear,50,18,skin,True,s>0,color=lambda x,y,z:mix(skin_base,rgb('BA715B'),.43))
    def ear_back(u,v):
        a=tau*u
        r=.002+.998*v
        x,_,z=ear(u,v)
        _,rim_y,_=ear(u,1)
        y=rim_y+.061*(1-r**1.8)
        return x,y,z
    surface('Ear  |  rear cartilage',ear_back,50,18,skin,True,s<0)
    ell('Ear attachment',(s*.216,.012,1.818),(.040,.044,.070),skin)
    ell('Tragus',(s*.204,-.058,1.807),(.011,.013,.018),skin)

group=section('02   •   Eyes and expression')
for s in [-1,1]:
    # Almond patch, iris and lids all use a common curved corneal surface.
    xc=.090*s
    zc=1.891+(.003 if s>0 else 0)
    ew=.064
    def eye_limits(u):
        shape=max(0,1-u*u)
        return (-.014*shape**.66+.005*u*s,.015*shape**.68+.005*u*s+(.003 if s>0 else 0)*shape)
    def eye_y(x,z):
        u=(x-xc)/ew
        t=(z-zc)/.033
        return front_y(x,zc)-.006-.024*max(0,1-u*u)-.003*(1-min(t*t,2))+.006*t*t
    def eye_fn(u,v):
        q=u*2-1
        bot,top=eye_limits(q)
        z=zc+bot+(top-bot)*v
        x=xc+ew*q
        return x,eye_y(x,z),z
    surface('Visible sclera',eye_fn,48,14,white)
    def disk(name,dx,dz,rx,rz,offset,mat):
        def fn(u,v):
            a=tau*u
            r=.001+.999*v
            x=xc+dx+rx*r*cos(a)
            z=zc+dz+rz*r*sin(a)
            bot,top=eye_limits(clamp((x-xc)/ew,-1,1))
            z=clamp(z,zc+bot+.0001,zc+top-.0001)
            return (x,eye_y(x,z)-offset,z)
        surface(name,fn,36,6,mat,True,True)
    disk('Iris rim',.022,.003,.017,.019,.0009,limbus)
    disk('Iris',.022,.003,.0142,.0158,.0014,iris)
    disk('Pupil',.022,.003,.008,.0095,.0019,limbus)
    disk('Corneal reflection',.017,.010,.0027,.003,.0024,glint)
    for upper in [False,True]:
        def lid(u,v):
            q=u*2-1
            x=xc+ew*q
            bot,top=eye_limits(q)
            rim=zc+(top if upper else bot)
            span=(.041 if upper else -.030)*(.30+.70*(1-q*q))
            z=rim+span*v
            y0=eye_y(x,rim)-.0014
            y1=front_y(x,z)+.0015
            y=y0*(1-smooth(v))+y1*smooth(v)-(.010 if upper else .014)*sin(pi*v)*(1-q*q)
            return x,y,z
        surface('Orbicular upper lid' if upper else 'Lower lid pad',lid,48,12,skin,flip=not upper,color=lambda x,y,z:mix(complexion(x,y,z),rgb('BB7D65'),.24))
        pts=[lid(i/36,0) for i in range(37)]
        line('Upper waterline' if upper else 'Lower waterline',pts,
             [.00035+(.0022 if upper else .0011)*sin(i*pi/36)**.65 for i in range(37)],brow if upper else rim_skin,8)
    def under_eye(u,v):
        q=2*u-1
        x=xc+.054*q
        z=zc-.027+.010*q*q+.003*q*s-.0056*sin(pi*u)*v
        return x,front_y(x,z)-.00045-.0006*sin(pi*v),z
    undereye=surface('Subtle lower orbit crease',under_eye,36,4,skin,flip=True,
        color=lambda x,y,z:mix(complexion(x,y,z),rgb('A36F5D'),.15))
    pts=[]
    rr=[]
    for i in range(19):
        t=i/18
        x=s*(.021+.146*t)
        z=1.925+.014*exp(-(t/.065)**2)+.049*smooth((t-.18)/.61)-.020*smooth((t-.78)/.22)+(.010 if s<0 else -.004)*sin(pi*t)
        pts.append((x,front_y(x,z)-.007,z))
        rr.append((.0015+.014*sin(pi*t)**.48,.0015+.021*sin(pi*t)**.43))
    line('Angled eyebrow',pts,rr,brow,12)

group=section('03   •   Parted coiffure')
def angdist(a,b):
    return (a-b+pi)%tau-pi

def coiffure(a,t,extra=0):
    # Map a hairline to a displaced crown. The flow converges behind the side part.
    c=cos(a)
    hairline=1.759+.254*smooth((c+.14)/1.04)-.027*exp(-(angdist(abs(angdist(a,0)),1.30)/.13)**2)
    hairline+=.013*sin(3*a)+.008*cos(5*a)+.005*sin(9*a)+.0055*cos(13*a)*max(0,-c)+.012*exp(-(angdist(a,.65)/.17)**2)
    h=sin(t*pi/2)
    z=hairline+(2.116-hairline)*h
    w,f,b=head(z)
    sweep=(.76+.42*c)*sin(t*pi*.78)*smooth(t/.52)+.14*c*sin(pi*t)
    aa=a+sweep
    # Several wide asymmetric lobes share an uninterrupted mass at the part.
    phase=11*a+.70*sin(3*a)+.38*sin(5*a)+.9*t
    wave=.5+.5*cos(phase)
    lobe=(.003+.021*wave**.95+.004*(.5+.5*cos(2*phase+.7)))*sin(pi*(.03+.94*t))**.50
    groove=.012*exp(-(angdist(a,.58)/.067)**2)*sin(pi*t)**.6
    # Subordinate carved channels stay embedded and diminish at the nape.
    comb=.0032*(.5+.5*cos(phase*3+.8*sin(phase+4*t)))**1.4*sin(pi*t)**.55
    volume=(.006+lobe+comb-groove+extra)*max(0,1-t)**.48
    cx=.041*t**2
    cy=.046*t**2
    x=cx+(w+volume)*sin(aa)
    # Follow the flatter front of the forehead and the rounder back of the skull.
    yy=abs(cos(aa))
    dep=max(0,1-abs(sin(aa))**2.5)**.4 if cos(aa)>0 else yy
    y=cy+(b+f)/2-math.copysign(((b-f)/2+volume)*dep,cos(aa))
    z+=.002+.016*h+.045*(.52+.48*c)*sin(t*pi)**1.25+.86*lobe*sin(t*pi)-.022*exp(-(angdist(a,.58)/.14)**2)*sin(t*pi)
    return x,y,z
cap=surface('Combed hair  |  parted crown, temples and nape',lambda u,v:coiffure(tau*u,v*.998),360,66,hair,True)
edge=cap.modifiers.new('Tapered hairline return','SOLIDIFY')
edge.thickness=.0028
edge.offset=-1
pigment=cap.data.color_attributes.new(name='Combed tone',type='FLOAT_COLOR',domain='POINT')
colors=[]
for j in range(67):
    t=j/66
    for i in range(360):
        a=tau*i/360
        phase=11*a+.70*sin(3*a)+.38*sin(5*a)+.9*t
        lobe=.5+.5*cos(phase)
        grain=.5+.5*cos(phase*3+.7*sin(phase+t*4))
        color=mix(rgb('211C20'),rgb('473933'),.12+.52*lobe+.21*grain)
        silver=.29*exp(-((abs(angdist(a,0))-1.57)/.40)**2-((t-.20)/.33)**2)*grain
        colors.extend((*mix(color,rgb('817269'),silver),1))
pigment.data.foreach_set('color',colors)
fiber=hair.node_tree.nodes.new('ShaderNodeVertexColor')
fiber.layer_name='Combed tone'
hair.node_tree.links.new(fiber.outputs['Color'],hair.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
hair.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=.26
# Hair coordinates run from hairline to crown along each sculpted lock.
# Fine comb marks follow that flow through the temples and rear swirl.
uv=cap.data.uv_layers.new(name='Comb direction')
for poly in cap.data.polygons:
    ids=list(poly.vertices)
    seam_cross=max(idx%360 for idx in ids)-min(idx%360 for idx in ids)>180
    for loop_id,idx in zip(poly.loop_indices,ids):
        u=(idx%360)/360
        if seam_cross and u<.5:
            u+=1
        uv.data[loop_id].uv=(u,idx//360/66)
nt=hair.node_tree
coord=nt.nodes.new('ShaderNodeUVMap')
coord.uv_map='Comb direction'
scale=nt.nodes.new('ShaderNodeVectorMath')
scale.operation='MULTIPLY'
scale.inputs[1].default_value=(5.6,.85,1)
nt.links.new(coord.outputs['UV'],scale.inputs[0])
fibers=nt.nodes.new('ShaderNodeTexWave')
fibers.wave_type='BANDS'
fibers.bands_direction='X'
fibers.inputs['Scale'].default_value=9.4
fibers.inputs['Distortion'].default_value=2.1
fibers.inputs['Detail Scale'].default_value=2.6
nt.links.new(scale.outputs[0],fibers.inputs['Vector'])
tones=nt.nodes.new('ShaderNodeValToRGB')
tones.color_ramp.elements[0].color=(.54,.54,.54,1)
tones.color_ramp.elements[1].color=(1,1,1,1)
nt.links.new(fibers.outputs['Fac'],tones.inputs[0])
tint=nt.nodes.new('ShaderNodeMixRGB')
tint.blend_type='MULTIPLY'
tint.inputs[0].default_value=.63
nt.links.new(fiber.outputs[0],tint.inputs[1])
nt.links.new(tones.outputs[0],tint.inputs[2])
bs=nt.nodes.get('Principled BSDF')
nt.links.new(tint.outputs[0],bs.inputs['Base Color'])
relief=nt.nodes.new('ShaderNodeBump')
relief.inputs['Strength'].default_value=.22
relief.inputs['Distance'].default_value=.0014
nt.links.new(fibers.outputs['Fac'],relief.inputs['Height'])
nt.links.new(relief.outputs[0],bs.inputs['Normal'])
# Pose the complete facial sculpture as one editable static assembly.
head_groups=list(bpy.data.collections)
pivot=bpy.data.objects.new('Head attitude  |  chin lifted',None)
group.objects.link(pivot)
pivot.empty_display_size=.035
pivot.location=(0,0,1.49)
for c in head_groups:
    for ob in list(c.objects):
        if ob!=pivot and ob.type=='MESH':
            ob.parent=pivot
            ob.location.z-=1.49
pivot.scale=(1.055,1,.900)
pivot.rotation_euler=(math.radians(-4),math.radians(3),0)
group=section('04   •   Cut and sewn tailoring')
body=Profile([(.643,.405,.225,.020),(.68,.412,.233,.027),(.77,.420,.263,.003),
 (.88,.434,.291,-.013),(1.005,.442,.325,-.029),(1.105,.439,.319,-.023),
 (1.23,.430,.266,.009),(1.36,.437,.228,.021),(1.445,.423,.206,.028),
 (1.488,.349,.190,.029),(1.522,.222,.157,.019),(1.545,.146,.128,.008)])
def bodypoint(a,z,off=0):
    w,d,cy=body(z)
    x=(w+off)*signpow(sin(a),.87)
    y=cy-(d+off)*signpow(cos(a),.87)
    return x,y,z

def bodyfront(x,z,off=0):
    w,d,cy=body(z)
    return cy-(d+off)*max(0,1-(abs(x)/(w+off))**(2/.87))**(.87/2)

opening=Profile([(.643,.235),(.70,.186),(.79,.198),(.97,.139),(1.073,.089),(1.20,.084),
 (1.33,.102),(1.44,.132),(1.49,.149),(1.545,.121)])
def coat_pos(u,v):
    z=.643+.902*v
    w,d,cy=body(z)
    amin=math.asin(clamp((opening(z)[0]/w)**(1/.87)))
    a=amin+(tau-2*amin)*u
    x,y,z=bodypoint(a,z,.011)
    h=1-smooth(v/.20)
    # Rounded fronts and a small center-back kick vent are cut into the hem.
    z+=h*(.036*exp(-(min(u,1-u)/.044)**2)+.095*exp(-((u-.5)/.0055)**2))
    # Bias-cut folds converge at the open quarters and soften across the back waist.
    side_angle=abs(angdist(a,0))
    below_chest=exp(-((side_angle-.90)/.52)**2)
    dart=.006*exp(-((z-(.96+.17*(side_angle-.72)))/.017)**2)
    dart-=.004*exp(-((z-(.94+.17*(side_angle-.72)))/.017)**2)
    drape=.006*sin(5*a+2*z)*smooth((1.14-z)/.44)
    blades=.008*exp(-((side_angle-2.40)/.29)**2-((z-1.35)/.18)**2)
    fall=drape+dart*below_chest+blades
    return x+fall*sin(a),y-fall*cos(a),z
coat=surface('Open jacket  |  curved quarters and rear vent',coat_pos,136,60,wool)
mod=coat.modifiers.new('Rolled fabric edge','SOLIDIFY')
mod.thickness=.006
mod.offset=-1
# Underlying shirt narrows beneath the high waist. Colour remains continuous between lapels.
def shirt_pos(u,v):
    z=.768+.775*v
    a=tau*u
    x,y,z=bodypoint(a,z,-.004)
    wrinkle=.008*sin(26*a+7*z)*exp(-((z-.836)/.062)**2)*max(0,cos(a))
    return x,y+wrinkle,z
surface('Ivory shirt body',shirt_pos,86,38,shirt,True)
for xside in [-1,1]:
    def lapel_fn(u,v,s=xside):
        # Notch is a cut into the outer edge, just below the collar.
        z=1.085+.425*v
        edge=opening(z)[0]+.002
        width=.131*(sin(v*pi*.65)**.85)+.002
        width-=.051*max(0,1-abs((v-.757)/.031))
        x=s*(edge+width*u)
        lift=.009+.012*(1-u)**2+.005*sin(u*pi)
        return x,bodyfront(x,z,.012)-lift,z
    lp=surface('Notched lapel, rolled break',lapel_fn,11,62,lapel,flip=xside<0)
    sol=lp.modifiers.new('Fold thickness','SOLIDIFY')
    sol.thickness=.003
    pts=[lapel_fn(.967,.08+.90*i/40) for i in range(41)]
    line('Lapel pick seam',pts,.0008,stitch,5,0)
    pts=[coat_pos(0 if xside>0 else 1,i/32*.526) for i in range(33)]
    line('Turned front hem',pts,.0026,wool,7,1)
    # 3D notched collar and folded shirt points, each pinned to the neckline.
    def collar_piece(name,top,outer,tip,base,mat,offset):
        def fn(u,v):
            start=(top[0]*(1-u)+outer[0]*u,top[1]*(1-u)+outer[1]*u)
            end=(base[0]*(1-u)+tip[0]*u,base[1]*(1-u)+tip[1]*u)
            x=xside*(start[0]*(1-v)+end[0]*v)
            z=start[1]*(1-v)+end[1]*v
            return x,bodyfront(x,z,offset)-.006*sin(pi*v),z
        o=surface(name,fn,10,12,mat,flip=xside>0)
        sol=o.modifiers.new('Folded edge','SOLIDIFY')
        sol.thickness=.004
    collar_piece('Jacket collar leaf',(.103,1.535),(.195,1.509),(.265,1.441),(.156,1.465),lapel,.025)
    collar_piece('Ivory collar point',(.018,1.504),(.107,1.54),(.125,1.443),(.043,1.47),shirt,.034)
    # Flapped pockets follow both the curvature of the belly and the slight slope of the opening.
    def pocket(u,v,s=xside):
        x=s*(.240+.131*u)
        z=.877+.030*u-.044*v+.005*v*(2*u-1)**2
        return x,bodyfront(x,z,.018)-.004*sin(pi*v),z
    pk=surface('Slanted hip pocket flap',pocket,16,6,lapel,flip=xside>0)
    pk.modifiers.new('Flap thickness','SOLIDIFY').thickness=.0035
    line('Pocket mouth',[pocket(i/20,.025) for i in range(21)],.0024,seam,8)
    pts=[coat_pos(.225 if xside>0 else .775,.06+.86*i/30) for i in range(31)]
    line('Side body panel seam',pts,.0014,seam,6)
# Center back seam terminates at the open vent.
line('Rear center seam',[coat_pos(.5,.095+.90*i/28) for i in range(29)],.00165,seam,7)
# Collar stand circles the back of the neck, connecting both collar leaves.
def stand(u,v):
    a=.76+(tau-1.52)*u
    z=1.508+.045*v
    return (.167+.043*(1-v))*sin(a),.017-(.154+.047*(1-v))*cos(a),z
surface('Back collar stand',stand,68,8,lapel)
line('Collar roll along nape',[stand(i/46,.92) for i in range(47)],.003,lapel,9)
for z in [.823,.887,.95]:
    x=-.025
    y=bodyfront(x,z,-.004)
    ell('Shirt button at placket',(x,y-.002,z),(.007,.003,.007),shirt,0)
# Breast welt, placed on the wearer's left.
pts=[]
for i in range(17):
    x=.237+.102*i/16
    z=1.327+.015*i/16
    pts.append((x,bodyfront(x,z,.018),z))
line('Breast welt',pts,[(.0025,.0058)]*17,lapel,8)
# High waist, belt, and the curved visible tie blade.
surface('Leather belt fitted to waist',lambda u,v:bodypoint(tau*u,.764+.034*v,.002),92,4,leather,True)
bx=-.009
for name,x1,z1,x2,z2 in [('upper',-.047,.797,.048,.797),('lower',-.047,.765,.048,.765),('left',-.047,.765,-.047,.797),('right',.048,.765,.048,.797),('prong',.048,.781,.009,.781)]:
    pts=[(bx+x1,bodyfront(bx+x1,z1,.010),z1),(bx+x2,bodyfront(bx+x2,z2,.010),z2)]
    line('Buckle '+name,pts,.0039,brass,8,0)
tie=Profile([(.819,.002),(.858,.053),(.91,.066),(1.05,.058),(1.23,.042),(1.41,.026),(1.465,.031)])
def tiepoint(u,v):
    z=.819+.646*v
    w=tie(z)[0]
    x=.013*(1-v)+w*(u*2-1)
    return x,bodyfront(x,z,-.003)-.010-.006*(1-(2*u-1)**2)-.004*sin(3*pi*u+v)*exp(-((v-.91)/.12)**2),z
blade=surface('Tie blade  |  curved silk',tiepoint,22,56,wine)
blade.modifiers.new('Silk thickness','SOLIDIFY').thickness=.003
def knot(u,v):
    a=tau*u
    z=1.447+.062*v
    w=.023+.018*v-.008*v**8
    return w*sin(a),bodyfront(0,z,.018)-.010-(.018+.004*v)*cos(a),z
surface('Four-in-hand knot',knot,32,17,wine,True)
for level in (0,1):
    pts=[knot(i/32,level) for i in range(32)]
    mesh('Knot return',pts,[tuple(range(32)) if level else tuple(reversed(range(32)))],wine)
# A small woven lozenge repeat follows the front of the draped tie.
vs=[]
fs=[]
for j in range(15):
    v=.085+j*.057
    w=tie(.819+.646*v)[0]
    for col in range(-3,4):
        u=.5+(col+(j%2)*.5)*.026/(2*w)
        if not .08<u<.92:
            continue
        k=len(vs)
        for du,dv in [(0,.004),(.0026/(2*w),0),(0,-.004),(-.0026/(2*w),0)]:
            x,y,z=tiepoint(u+du,v+dv)
            vs.append((x,y-.0007,z))
        fs.append((k,k+1,k+2,k+3))
mesh('Jacquard lozenges',vs,fs,motif)
for z in [.974,1.079]:
    x=-opening(z)[0]-.025
    y=bodyfront(x,z,.021)
    ell('Horn jacket button',(x,y-.002,z),(.014,.0055,.014),button,0)
    for h in [-1,1]:
        ell('Button hole',(x+.003*h,y-.007,z),(.0017,.001,.0024),seam,0)

group=section('05   •   Sleeves, trousers and hands')
sleeve=Profile([(.852,.060,.071,.545,-.084),(.865,.075,.084,.544,-.082),(.902,.081,.089,.543,-.075),
 (1.025,.091,.102,.538,-.039),(1.106,.100,.112,.526,-.012),(1.157,.107,.117,.518,-.001),
 (1.24,.117,.135,.496,.017),(1.357,.129,.150,.457,.028),(1.414,.125,.143,.429,.026),
 (1.452,.107,.115,.401,.027),(1.475,.073,.076,.391,.029),(1.481,.009,.010,.386,.031)])
leg=Profile([(.102,.115,.140,.224,-.001),(.115,.135,.150,.224,-.004),
 (.149,.137,.153,.225,-.011),(.169,.133,.145,.226,-.012),(.20,.134,.145,.225,-.007),
 (.235,.133,.137,.221,-.007),(.338,.137,.149,.214,-.010),(.401,.147,.163,.210,-.018),
 (.49,.156,.173,.198,-.010),(.58,.177,.181,.186,.005),(.663,.187,.199,.181,.018),
 (.747,.182,.202,.178,.022),(.768,.144,.158,.177,.027)])
def legpoint(a,z,s):
    w,d,xc,yc=leg(z)
    ankle=exp(-((z-.176)/.065)**2)
    knee=exp(-((z-.37)/.12)**2)
    fold=.008*ankle*sin(z*105+3.3*cos(a)+.6*s)*(.25+.75*max(0,cos(a-.3*s)))+.004*knee*sin(z*62+2.8*sin(a))*(.28+.72*max(0,-cos(a)))
    press=.006*exp(-(angdist(a,0)/.16)**2)*smooth((z-.13)/.14)
    zz=z+.013*ankle*cos(a*2+.4*s)
    return s*(xc+(w+fold)*signpow(sin(a),.93)),yc-(d+fold+press)*signpow(cos(a),.93),zz
def tailored_trousers():
    """Join both legs at a single saddle and share the front and rear rise edges."""
    verts=[]
    faces=[]
    lookup={}
    def vid(p):
        key=tuple(round(n,6) for n in p)
        if key not in lookup:
            lookup[key]=len(verts)
            verts.append(p)
        return lookup[key]
    crotch=.555
    zs=[.102+(crotch-.102)*j/42 for j in range(43)]+[crotch+(.796-crotch)*j/28 for j in range(1,29)]
    for side in [-1,1]:
        last=[]
        for z in zs:
            row=[]
            stand=min(z,crotch)
            gap=leg(stand)[2]-leg(stand)[0]
            close=smooth((stand-.385)/(crotch-.385))
            for i in range(65):
                t=i/64
                a=-pi/2+tau*t
                x,y,zz=legpoint(a,stand,side)
                x-=side*gap*close*max(0,-sin(a))**2
                if z>crotch:
                    blend=smooth((z-crotch)/(.796-crotch))
                    a2=pi*t
                    w=.401
                    d=.262
                    xc=side*w*signpow(sin(a2),.88)
                    yc=.002-d*signpow(cos(a2),.88)
                    x=x*(1-blend)+xc*blend
                    y=y*(1-blend)+yc*blend
                if i in (0,64) and z>=crotch:
                    x=0
                row.append(vid((x,y,z+zz-stand)))
            if last:
                for i in range(64):
                    f=(last[i],last[i+1],row[i+1],row[i])
                    faces.append(f if side>0 else f[::-1])
            last=row
    return mesh('Trousers  |  continuous seat, fork and two pressed legs',verts,faces,trouser)
tailored_trousers()
def sleevepoint(a,z,s):
    w,d,xc,yc=sleeve(z)
    wrinkle=.0065*sin(70*z+2.3*sin(a))*exp(-((z-1.14)/.078)**2)+.003*sin(21*z+3*a)
    return s*(xc+(w+wrinkle)*sin(a)),yc-(d+wrinkle)*cos(a),z+.010*cos(a-.5)*exp(-((z-.87)/.07)**2)
for s in [-1,1]:
    earlier=set(group.objects)
    surface('Jacket sleeve with elbow ease',lambda u,v:sleevepoint(tau*u,.852+.629*v,s),52,55,wool,True,s<0)
    pts=[sleevepoint(1.7,.86+.54*i/26,s) for i in range(27)]
    line('Outer sleeve seam',pts,.0013,seam,6)
    for i in range(3):
        x,y,z=sleevepoint(1.70,.884+.020*i,s)
        ell('Sleeve horn button',(x+.001*s,y,z),(.004,.0085,.0085),button,0)
    surface('Poplin cuff',lambda u,v:(s*(.547+(.072+.003*v)*sin(tau*u)),-.085-(.078+.002*v)*cos(tau*u),.827+.044*v+.008*cos(tau*u-.5)),44,6,shirt,True,s<0)
    pts=[legpoint(1.63,.13+.55*i/31,s) for i in range(32)]
    line('Outseam',pts,.0015,seam,6)
    pts=[legpoint(tau*i/55,.118,s) for i in range(56)]
    line('Trouser hem',pts,.0015,stitch,6,0)
    # Palm turns inwards. Four separate finger paths curl toward the thigh and the thumb opposes the index.
    hand_prof=Profile([(.706,.027,.047,.558,-.105),(.723,.041,.063,.558,-.101),
     (.751,.048,.070,.556,-.096),(.784,.051,.069,.554,-.093),(.812,.047,.062,.549,-.086),
     (.831,.043,.057,.546,-.084),(.859,.048,.058,.546,-.084)])
    def palm(u,v):
        a=tau*u
        z=.706+.153*v
        w,d,x,y=hand_prof(z)
        return s*(x+w*signpow(sin(a),.9)),y-d*signpow(cos(a),.85),z
    surface('Hand  |  metacarpal fan',palm,36,24,skin,True,s<0)
    for j in range(4):
        yc=-.15+j*.032
        length=[.087,.098,.09,.073][j]
        z0=.747-.006*j
        pts=[(s*.561,yc,z0),(s*.572,yc-.001,z0-.024),(s*.572,yc-.005,z0-.047),
             (s*.563,yc-.008,z0-.064),(s*.542,yc-.009,z0-length),(s*.531,yc-.008,z0-length+.001)]
        sc=1-.045*j
        line('Relaxed finger %d'%(j+1),pts,[(r*sc,r*.9*sc) for r in [.019,.020,.018,.017,.015,.008]],skin,10,2)
        ell('Finger nail %d'%(j+1),(s*.558,yc-.002,z0-.068),(.006,.0095,.010),nail,1)
    line('Opposed thumb',[(s*.543,-.125,.805),(s*.539,-.155,.798),(s*.534,-.175,.778),
         (s*.528,-.180,.750),(s*.522,-.178,.729)],[(.027,.029),(.026,.027),(.023,.023),(.019,.020),(.013,.015)],skin,12,2)
    ell('Thumbnail',(s*.536,-.190,.747),(.009,.004,.013),nail,1)

    if s<0:
        gesture=Profile([(.63,-.166,-.108,.133),(.72,-.160,-.107,.132),(.83,-.122,-.10,.125),
            (.89,-.072,-.09,.110),(1.025,.073,-.065,.073),(1.14,.111,-.021,.045),
            (1.24,.092,.010,.022),(1.36,.039,.009,.009),(1.48,0,0,0)])
        for ob in set(group.objects)-earlier:
            if ob.name.startswith(('Outseam','Trouser hem')):
                continue
            for vert in ob.data.vertices:
                x,y,z=vert.co
                dx,dy,dz=gesture(z)
                tilt=.65*exp(-((z-.856)/.086)**2)
                center=-sleeve(clamp(z,.852,1.481))[2]
                vert.co=(x-dx,y+dy,z+dz+(x-center)*tilt)
group=section('06   •   Benchmade oxfords')
shoe=Profile([(-.272,.012,.055),(-.265,.069,.078),(-.238,.109,.091),(-.187,.128,.101),
 (-.132,.128,.112),(-.085,.119,.137),(-.038,.107,.163),(.018,.100,.169),(.064,.105,.143),
 (.103,.099,.123),(.121,.076,.104),(.132,.010,.092)])
def shoe_xyz(s,x,y,z):
    ang=s*.095
    return s*.225+x*cos(ang)-y*sin(ang),x*sin(ang)+y*cos(ang),z
for s in [-1,1]:
    def vamp(u,v):
        y=-.272+.404*v
        w,h=shoe(y)
        a=pi*u
        return shoe_xyz(s,w*cos(a),y,.034+(h-.034)*sin(a)**.68)
    surface('Oxford  |  last-shaped upper',vamp,36,58,leather,flip=True)
    for t in [0,1]:
        pts=[vamp(j/36,t) for j in range(37)]
        mesh('Heel counter end' if t else 'Toe end',pts,[tuple(reversed(range(37))) if t else tuple(range(37))],leather)
    def outsole(u,v):
        a=tau*u
        y=-.065-.204*cos(a)
        w=shoe(y)[0]
        lateral=(1 if sin(a)>=0 else -1)
        x=lateral*(w+.0035)*min(1,abs(sin(a))/.21)
        bottom=.009+.010*exp(-((y+.035)/.06)**2)
        return shoe_xyz(s,x,y,bottom+(.036-bottom)*v)
    surface('Stacked outsole',outsole,84,8,sole,True)
    pts=[outsole(i/80,.93) for i in range(81)]
    line('Welt rand',pts,.0027,leather,7)
    pts=[vamp(i/40,.262+.035*sin(pi*i/40)) for i in range(41)]
    line('Toe cap seam',pts,.0016,stitch,7)
    for side in [-1,1]:
        pts=[vamp(.50+side*(.205+.24*t),.486+.38*t) for t in [i/18 for i in range(19)]]
        line('Quarter facing',pts,.0024,leather,7)
    for j in range(4):
        v=.447+j*.046
        for k in [-1,1]:
            pts=[vamp(.5+k*(t-.5)*.275,v+.037*t) for t in [i/8 for i in range(9)]]
            line('Cross lace',[(x,y,z+.0024) for x,y,z in pts],.0024,laces,7)

group=section('07   •   Studio and cameras')
floor=material('Studio  |  blue slate','647880',.95)
def studio_mesh():
    # Place the entire cove outside every camera. The shallow foreground rake
    # makes the exact horizontal views meet the floor at the shoes in all directions.
    rows=[(.001,-.003),(.33,-.003),(.70,-.023),(1.4,-.075),(3.2,-.175),(4.3,-.210)]
    for j in range(1,25):
        a=pi*j/48
        rows.append((4.3+1.45*sin(a),-.21+1.45*(1-cos(a))))
    rows.append((5.75,8))
    vs=[(r*sin(tau*i/160),r*cos(tau*i/160),z) for r,z in rows for i in range(160)]
    fs=[]
    for row in range(len(rows)-1):
        for i in range(160):
            a=row*160+i
            b=row*160+(i+1)%160
            fs.append((a,b,b+160,a+160))
    cove=mesh('Seamless studio cove',vs,fs,floor)
    cove.visible_shadow=False
    cove.visible_diffuse=False
    return cove
cove=studio_mesh()

def aim(ob,target):
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,target,power,size,color):
    data=bpy.data.lights.new(name,'AREA')
    data.energy=power
    data.shape='DISK'
    data.size=size
    data.color=color
    o=bpy.data.objects.new(name,data)
    group.objects.link(o)
    o.location=loc
    aim(o,target)
area('Warm softbox',(-3.15,-4.1,4.7),(0,0,1.14),445,2.75,(1,.84,.72))
area('Sky bounce',(3.25,-2.6,2.65),(0,0,1.24),125,2.9,(.80,.88,1))
area('Hair edge',(1.95,2.65,4.3),(0,0,1.36),500,2.5,(1,.90,.80))
area('Back fill',(-1.9,1.65,2.7),(0,0,1.0),110,2.6,(.83,.91,1))
scene.world=bpy.data.worlds.new('Diffuse studio fill')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.60,.65,.72,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.23
views={}
for name,angle,elev,target,scale in [('front',0,0,1.050,2.30),('profile',90,0,1.050,2.30),
  ('back',180,0,1.050,2.30),('three_quarter',-32,3,1.050,2.30),('portrait',-16,1.0,1.801,.89)]:
    cam=bpy.data.cameras.new(name)
    cam.type='ORTHO'
    cam.ortho_scale=scale
    ob=bpy.data.objects.new('View  |  '+name,cam)
    group.objects.link(ob)
    a=math.radians(angle)
    ob.location=(3.20*sin(a),-3.20*cos(a),target+3.20*math.tan(math.radians(elev)))
    aim(ob,(0,0,target))
    views[name]=ob
scene.render.engine='CYCLES'
scene.cycles.samples=140 if args.quality=='final' else 24
scene.cycles.adaptive_threshold=.026 if args.quality=='final' else .10
scene.cycles.use_denoising=False
scene.cycles.max_bounces=5
scene.render.resolution_x=960
scene.render.resolution_y=1120
scene.render.resolution_percentage=100 if args.quality=='final' else 45
scene.render.image_settings.file_format='PNG'
scene.render.image_settings.color_mode='RGB'
scene.render.film_transparent=False
scene.view_settings.view_transform='AgX'
scene.view_settings.look='AgX - Medium High Contrast'
scene.unit_settings.system='METRIC'
scene.camera=views['three_quarter']
scene['Study']='01 | Static appearance proof. Authored at -Y forward, Z up.'
scene['Reference']='art/references/approved/five-staff-unlikable-approved.png'
scene['Secondary reference']='art/references/concept-wip/boss-kim-turnaround-v1-concept.png'
for screen in bpy.data.screens:
    for area_ui in screen.areas:
        if area_ui.type=='VIEW_3D':
            space=area_ui.spaces.active
            space.region_3d.view_perspective='CAMERA'
            space.overlay.show_overlays=False
            space.shading.color_type='MATERIAL'
bpy.context.preferences.filepaths.save_version=0
if args.save or args.quality=='final':
    scene.render.filepath='//three_quarter.png'
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'boss_kim.blend'),compress=True)
for name in args.views:
    scene.camera=views[name]
    scene.render.filepath=str(out/(name+'.png'))
    bpy.ops.render.render(write_still=True)
