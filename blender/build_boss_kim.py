"""Rebuild the original Kim mesh/rig and bake five CC0 UAL clips.
Blender 5.2: blender -b --python blender/build_boss_kim.py -- --ual /path/to/standard.glb
No source mannequin geometry is retained. Coordinates: metres, Z up, -Y front.
"""
import bpy, math, sys, json, argparse
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--ual',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.render.fps=30
scene.unit_settings.system='METRIC'
bpy.ops.import_scene.gltf(filepath=args.ual)
src=next(o for o in bpy.data.objects if o.type=='ARMATURE')
src.name='UAL_SOURCE_TEMP'
source_actions={a.name:a for a in bpy.data.actions}
selected={'Idle':'Idle_Loop','Walk':'Walk_Loop','Idle_Talking':'Idle_Talking_Loop','Hit_Head':'Hit_Head','Hit_Chest':'Hit_Chest'}
samples={}
source_rest={b.name:b.matrix_local.to_quaternion() for b in src.data.bones}
for out,name in selected.items():
 a=source_actions[name]
 src.animation_data.action=a
 src.animation_data.action_slot=a.slots[0]
 frames=int(math.ceil(a.frame_range[1]))
 samples[out]=[]
 for frame in range(frames+1):
  scene.frame_set(frame)
  samples[out].append({b.name:b.matrix.to_quaternion().copy() for b in src.pose.bones})
for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
scene.frame_set(0)

def mat(name,hexcolor,rough=.85):
 def linear(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 m=bpy.data.materials.new(name); m.diffuse_color=(*[linear(int(hexcolor[i:i+2],16)/255) for i in (0,2,4)],1)
 m.use_nodes=True; bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=m.diffuse_color; bs.inputs['Roughness'].default_value=rough
 return m
M={n:mat(n,c,r) for n,c,r in [('Charcoal wool','302d30',.98),('Trouser','28272b',.95),('Lapel','3b373a',.9),('Ivory shirt','e9e0ca',.92),('Ox blood tie','742832',.78),('Skin','c98760',.87),('Lip','9b5845',.9),('Hair','241d1b',.91),('Eye white','ece7d9',.6),('Iris','30261f',.5),('Shoe','1c1d20',.4),('Buckle','8c8b83',.35)]}
bone_defs={}
mapping={'Pelvis':'DEF-hips','Spine':'DEF-spine.001','Chest':'DEF-spine.003','Neck':'DEF-neck','Head':'DEF-head'}
def bone(name,head,tail,parent=None): bone_defs[name]=(Vector(head),Vector(tail),parent)
bone('Root',(0,0,0),(0,0,.15))
bone('Pelvis',(0,0,.84),(0,0,1.03),'Root')
bone('Spine',(0,0,1.03),(0,0,1.26),'Pelvis')
bone('Chest',(0,0,1.26),(0,0,1.52),'Spine')
bone('Neck',(0,0,1.52),(0,-.015,1.64),'Chest')
bone('Head',(0,-.015,1.64),(0,-.015,2.10),'Neck')
bone('Jaw',(0,-.10,1.72),(0,-.26,1.69),'Head')
for side,s in [('L',1),('R',-1)]:
 bone('UpperArm.'+side,(s*.43,0,1.47),(s*.65,0,1.19),'Chest')
 bone('Forearm.'+side,(s*.65,0,1.19),(s*.79,-.025,.94),'UpperArm.'+side)
 bone('Hand.'+side,(s*.79,-.025,.94),(s*.87,-.035,.80),'Forearm.'+side)
 bone('UpperLeg.'+side,(s*.20,0,.86),(s*.21,-.015,.46),'Pelvis')
 bone('LowerLeg.'+side,(s*.21,-.015,.46),(s*.22,0,.12),'UpperLeg.'+side)
 bone('Foot.'+side,(s*.22,0,.12),(s*.22,-.22,.07),'LowerLeg.'+side)
 bone('Brow.'+side,(s*.12,-.223,1.995),(s*.24,-.223,2.018),'Head')
 for target,source in [('UpperArm','upper_arm'),('Forearm','forearm'),('Hand','hand'),('UpperLeg','thigh'),('LowerLeg','shin'),('Foot','foot')]: mapping[target+'.'+side]='DEF-'+source+'.'+side
 for i in range(4):
  x=s*.857; z=.824; y=-.078+i*.036
  length=[.10,.115,.105,.08][i]
  bone('Finger%d.%s'%(i,side),(x,y,z),(x+s*length*.55,y,z-length),'Hand.'+side)
 bone('Thumb.'+side,(s*.79,-.06,.89),(s*.78,-.10,.79),'Hand.'+side)
rigdata=bpy.data.armatures.new('ASD_Humanoid_A')
rig=bpy.data.objects.new('KimRig',rigdata); scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig; rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,(h,t,p) in bone_defs.items():
 b=rigdata.edit_bones.new(name); b.head=h;b.tail=t
 if p:b.parent=rigdata.edit_bones[p]
 b.use_deform=True
bpy.ops.object.mode_set(mode='OBJECT')
rig.show_in_front=True

meshes=[]
def mesh(name,verts,faces,material,weights):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);data.materials.append(M[material]);meshes.append(obj)
 for p in data.polygons:p.use_smooth=True
 for i,v in enumerate(verts):
  w=weights(Vector(v)) if callable(weights) else {weights:1}
  total=sum(w.values())
  for group,value in w.items():
   vg=obj.vertex_groups.get(group) or obj.vertex_groups.new(name=group);vg.add([i],value/total,'REPLACE')
 mod=obj.modifiers.new('Skin / four influence maximum','ARMATURE');mod.object=rig;obj.parent=rig
 return obj
def rings(name,rows,material,weights,n=24,power=2):
 # rows z, half-width, half-depth, front/back centre; squircle allows a broad jaw.
 vs=[]
 for z,rx,ry,cy in rows:
  for i in range(n):
   a=i*math.tau/n;c=math.cos(a);s=math.sin(a)
   vs.append((rx*math.copysign(abs(c)**(2/power),c),cy+ry*math.copysign(abs(s)**(2/power),s),z))
 fs=[]
 for j in range(len(rows)-1):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 fs.append(tuple(reversed(range(n))));fs.append(tuple((len(rows)-1)*n+i for i in range(n)))
 return mesh(name,vs,fs,material,weights)
def ellipsoid(name,center,scale,material,weights,n=20,r=12):
 rows=[]
 for j in range(r+1):
  a=math.pi*j/r
  rows.append((center[2]-scale[2]*math.cos(a),max(.001,scale[0]*math.sin(a)),max(.001,scale[1]*math.sin(a)),center[1]))
 obj=rings(name,rows,material,weights,n)
 if center[0]:
  for v in obj.data.vertices:v.co.x+=center[0]
 return obj
def panel(name,points,material,weights,thick=.008):
 vs=[(x,y-thick/2,z) for x,y,z in points]+[(x,y+thick/2,z) for x,y,z in points]
 n=len(points);fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]
 fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
 return mesh(name,vs,fs,material,weights)
def tube(name,points,radii,material,weights,n=12):
 vs=[]
 for j,p in enumerate(points):
  p=Vector(p);t=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])
  t.normalize();a=t.cross(Vector((0,1,0))).normalized();b=t.cross(a).normalized()
  rx,ry=(radii[j],radii[j]) if isinstance(radii[j],(int,float)) else radii[j]
  for i in range(n):vs.append(tuple(p+a*math.cos(i*math.tau/n)*rx+b*math.sin(i*math.tau/n)*ry))
 fs=[]
 for j in range(len(points)-1):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 fs.extend([tuple(reversed(range(n))),tuple((len(points)-1)*n+i for i in range(n))])
 return mesh(name,vs,fs,material,weights)
def cloth_strip(name,rows,material,weights):
 vs=[]
 for z,w,y in rows:vs.extend([(-w,y,z),(w,y,z)])
 return mesh(name,vs,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(rows)-1)],material,weights)
def torso_w(v):
 z=v.z
 if z<1.03:
  t=max(0,min(1,(z-.87)/.16));return {'Pelvis':1-t,'Spine':t}
 t=max(0,min(1,(z-1.12)/.23));return {'Spine':1-t,'Chest':t}
def segment_w(v,a,b,joint,width):
 t=max(0,min(1,(joint-v.z)/width+.5));return {a:1-t,b:t}
def sleeve_w(v,a,b):
 chest=max(0,min(.85,(v.z-1.37)/.16))
 weights=segment_w(v,a,b,1.19,.19)
 return {**{k:w*(1-chest) for k,w in weights.items()},'Chest':chest}

# A continuous torso shell, fitted shirt, tailored lapels and protruding belly.
rings('Jacket / weighted torso',[(.82,.33,.20,.0),(.88,.42,.255,-.035),(1.02,.46,.315,-.045),(1.16,.46,.32,-.04),(1.30,.45,.27,0),(1.43,.46,.235,0),(1.49,.39,.205,0),(1.54,.19,.145,0)],'Charcoal wool',torso_w,power=2.7)
cloth_strip('Shirt exposed belly',[(1.53,.12,-.171),(1.49,.14,-.222),(1.43,.15,-.252),(1.30,.17,-.287),(1.16,.21,-.38),(1.02,.21,-.379),(.88,.17,-.309)],'Ivory shirt',torso_w)
for s in [-1,1]:
 panel('Notched lapel',[(s*.12,-.23,1.52),(s*.31,-.215,1.47),(s*.24,-.275,1.35),(s*.30,-.287,1.34),(s*.10,-.357,1.13)],'Lapel',torso_w)
 panel('Collar',[(s*.015,-.25,1.49),(s*.125,-.225,1.55),(s*.165,-.25,1.42),(s*.068,-.28,1.45)],'Ivory shirt','Chest')
 panel('Pocket flap',[(s*.25,-.309,1.01),(s*.4,-.236,1.04),(s*.4,-.237,.985),(s*.25,-.31,.955)],'Lapel',torso_w)
ellipsoid('Tie knot',(0,-.278,1.458),(.067,.031,.054),'Ox blood tie','Chest')
cloth_strip('Tie blade',[(1.44,.036,-.289),(1.30,.044,-.307),(1.16,.063,-.395),(1.04,.084,-.397),(.965,.002,-.37)],'Ox blood tie',torso_w)
rings('Trousers / hips',[(.70,.29,.20,0),(.79,.36,.235,0),(.87,.36,.235,-.005),(.90,.33,.22,0)],'Trouser','Pelvis',power=2.5)
rings('Leather belt',[(.866,.359,.239,0),(.90,.34,.234,0)],'Shoe','Pelvis',power=2.5)
panel('Belt buckle',[(-.055,-.247,.90),(.055,-.247,.90),(.055,-.247,.854),(-.055,-.247,.854)],'Buckle','Pelvis')
for side,s in [('L',1),('R',-1)]:
 upper='UpperArm.'+side;fore='Forearm.'+side
 tube('Continuous jacket sleeve '+side,[(s*.35,0,1.43),(s*.46,0,1.415),(s*.59,0,1.28),(s*.65,0,1.19),(s*.705,-.01,1.09),(s*.78,-.02,.965)],[(.135,.15),(.15,.16),(.125,.13),(.117,.12),(.107,.112),(.091,.098)],'Charcoal wool',lambda v,a=upper,b=fore:sleeve_w(v,a,b))
 tube('Ivory cuff '+side,[(s*.773,-.02,.982),(s*.80,-.025,.93)],[.091,.086],'Ivory shirt',fore)
 ellipsoid('Palm '+side,(s*.833,-.027,.863),(.088,.051,.09),'Skin','Hand.'+side)
 for i in range(4):
  h,t,_=bone_defs['Finger%d.%s'%(i,side)]
  tube('Finger '+str(i)+side,[h,(h+t)/2,t],[.023,.022,.017],'Skin','Finger%d.%s'%(i,side))
 h,t,_=bone_defs['Thumb.'+side];tube('Thumb '+side,[h,(h+t)/2,t],[.034,.03,.023],'Skin','Thumb.'+side)
 tube('Continuous trouser leg '+side,[(s*.2,0,.82),(s*.20,-.003,.68),(s*.21,-.015,.49),(s*.21,-.014,.43),(s*.22,0,.24),(s*.22,0,.125)],[(.175,.21),(.164,.183),(.143,.15),(.135,.14),(.127,.13),(.125,.13)],'Trouser',lambda v,a='UpperLeg.'+side,b='LowerLeg.'+side:segment_w(v,a,b,.46,.17))
 ellipsoid('Shoe '+side,(s*.22,-.10,.092),(.15,.265,.082),'Shoe','Foot.'+side)
 tube('Sole '+side,[(s*.22,.09,.045),(s*.22,-.29,.045)],[(.147,.023),(.136,.023)],'Shoe','Foot.'+side)

ellipsoid('Thick neck',(0,0,1.585),(.17,.145,.13),'Skin',lambda v:segment_w(v,'Head','Neck',1.64,.18))
def face_w(v):
 j=max(0,min(.75,(1.87-v.z)/.16));return {'Head':1-j,'Jaw':j}
rings('Broad continuous face',[(1.59,.145,.125,-.04),(1.64,.26,.19,-.06),(1.72,.31,.225,-.065),(1.81,.30,.217,-.043),(1.92,.265,.198,-.002),(2.02,.247,.19,.015),(2.10,.215,.16,.015),(2.145,.11,.10,.025)],'Skin',face_w,n=32,power=3.2)
for side,s in [('L',1),('R',-1)]:
 ellipsoid('Ear '+side,(s*.284,.005,1.874),(.063,.056,.115),'Skin','Head')
 ellipsoid('Ear fold '+side,(s*.311,-.041,1.875),(.029,.012,.063),'Lip','Head')
 ellipsoid('Eye '+side,(s*.119,-.201,1.967),(.088,.027,.042),'Eye white','Head')
 ellipsoid('Iris '+side,(s*.106,-.228,1.957),(.025,.009,.027),'Iris','Head',n=16)
 ellipsoid('Eye glint '+side,(s*.101-.006,-.237,1.968),(.006,.004,.007),'Eye white','Head',n=12,r=6)
 tube('Heavy upper eyelid '+side,[(s*.041,-.224,1.978),(s*.11,-.23,1.987),(s*.194,-.20,1.973)],[.014,.017,.014],'Skin','Head')
 tube('Thick scowling brow '+side,[(s*.035,-.234,2.007),(s*.11,-.225,2.023),(s*.19,-.204,2.054),(s*.222,-.174,2.041)],[.026,.031,.033,.016],'Hair','Brow.'+side)
 tube('Cheek crease '+side,[(s*.117,-.251,1.852),(s*.179,-.269,1.81),(s*.219,-.259,1.77)],[.007,.006,.004],'Lip','Head',n=8)
ellipsoid('Long imperious nose',(0,-.235,1.93),(.067,.085,.112),'Skin','Head')
ellipsoid('Nose tip',(0,-.302,1.884),(.088,.060,.050),'Skin','Head')
for s in [-1,1]:ellipsoid('Nostril',(s*.052,-.337,1.871),(.021,.009,.013),'Lip','Head',n=12,r=6)
tube('Downturned mouth',[(-.178,-.274,1.755),(-.10,-.294,1.779),(0,-.3,1.788),(.10,-.294,1.779),(.178,-.274,1.755)],[.009,.01,.012,.01,.009],'Lip','Jaw')
tube('Lower lip',[(-.09,-.296,1.762),(0,-.308,1.77),(.09,-.296,1.762)],[.012,.019,.012],'Skin','Jaw')
tube('Chin cleft',[(0,-.292,1.7),(0,-.292,1.669)],[.005,.003],'Lip','Jaw',n=8)
# Swept-back, receding hair: broad sculptural cap and asymmetric swept locks.
rings('Hair cap',[(2.04,.235,.18,.035),(2.10,.246,.183,.04),(2.165,.202,.162,.055),(2.185,.08,.085,.08)],'Hair','Head',power=2.6)
for s in [-1,1]:
 ellipsoid('Side hair',(s*.235,.044,1.995),(.03,.151,.109),'Hair','Head')
for i in range(7):
 x=-.185+i*.058
 tube('Swept hair lock',[(x,-.11,2.096),(x+.025,-.08,2.17),(x+.044,.045,2.188),(x+.032,.16,2.105)],[.028,.035,.035,.025],'Hair','Head')

# Store the actual reference in the authoring file as a packed image, not runtime geometry.
reference=bpy.data.images.load(str(ROOT/'art/references/approved/five-staff-unlikable-approved.png'));reference.pack()
rig['reference']='art/references/approved/five-staff-unlikable-approved.png'
rig['height_m']=2.22
rig['forward']='Blender -Y -> Godot +Z'
rig['status']='IMPLEMENTED; art and comedy approval pending'

# Retarget global orientation deltas onto an explicit T-neutral orientation, then
# solve local rotations against the target A rest. Proportions remain target-owned.
tneutral={}
for b in rigdata.bones:
 q=b.matrix_local.to_quaternion()
 if b.name.startswith(('UpperArm.','Forearm.','Hand.')):
  s=1 if b.name.endswith('.L') else -1
  q=Vector((0,1,0)).rotation_difference(Vector((s,0,0)))
 tneutral[b.name]=q
rig.animation_data_create()
for out,frames in samples.items():
 a=bpy.data.actions.new(out);rig.animation_data.action=a
 for fi,frame in enumerate(frames):
  desired={}
  for b in rigdata.bones:
   q=frame[mapping[b.name]] @ source_rest[mapping[b.name]].inverted() @ tneutral[b.name] if b.name in mapping else None
   if q is None:q=(desired[b.parent.name] @ b.parent.matrix_local.to_quaternion().inverted() @ b.matrix_local.to_quaternion()) if b.parent else b.matrix_local.to_quaternion()
   desired[b.name]=q
   local=(desired[b.parent.name].inverted() @ q) if b.parent else q
   rest=(b.parent.matrix_local.inverted() @ b.matrix_local).to_quaternion() if b.parent else b.matrix_local.to_quaternion()
   p=rig.pose.bones[b.name];p.rotation_mode='QUATERNION';p.rotation_quaternion=rest.inverted() @ local
   p.keyframe_insert('rotation_quaternion',frame=fi,group=b.name)
 a.use_fake_user=True
rig.animation_data.action=None
for p in rig.pose.bones:p.rotation_quaternion=Quaternion();p.location=(0,0,0);p.scale=(1,1,1)
scene.frame_set(0)
# Named deformation pose actions are also editable in the .blend.
for name,changes in {'QA_Arms_Raised':{'UpperArm.L':(0,0,-1.1),'UpperArm.R':(0,0,1.1)},'QA_Knees_90':{'LowerLeg.L':(1.57,0,0),'LowerLeg.R':(1.57,0,0)},'QA_Head_Turn':{'Head':(0,1.047,0)},'QA_Torso_Bend':{'Spine':(.5,0,0),'Chest':(.25,0,0)}}.items():
 a=bpy.data.actions.new(name);rig.animation_data.action=a
 for p in rig.pose.bones:
  p.rotation_quaternion=Quaternion()
  if p.name in changes:
   from mathutils import Euler
   p.rotation_quaternion=Euler(changes[p.name]).to_quaternion()
  p.keyframe_insert('rotation_quaternion',frame=0,group=p.name)
 a.use_fake_user=True
rig.animation_data.action=None
for p in rig.pose.bones:p.rotation_quaternion=Quaternion()
bpy.context.view_layer.update()
out=ROOT/'game/assets/characters/boss_kim';out.mkdir(parents=True,exist_ok=True)
source=ROOT/'blender/boss_kim';source.mkdir(parents=True,exist_ok=True)
stats={'height_m':2.22,'bones':len(rigdata.bones),'mesh_parts':len(meshes),'vertices':sum(len(o.data.vertices) for o in meshes),'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes),'clips':list(samples),'reference':rig['reference'],'max_weight_error':max(abs(sum(g.weight for g in v.groups)-1) for o in meshes for v in o.data.vertices)}
(source/'build-report.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(source/'boss_kim.blend'))
# Keep editable garment/face parts in .blend; ship one mesh with material surfaces.
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join()
meshes[0].name='KimSkinnedMesh'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'boss_kim.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True,export_yup=True)
print('KIM_BUILD_OK',json.dumps(stats))
