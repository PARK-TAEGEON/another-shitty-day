"""Open either blend and pass an image directory, then optionally 'relaxed' or 'hip'."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
out=Path(args[0]).resolve()
out.mkdir(exist_ok=True,parents=True)
sc=bpy.context.scene
original=sc.camera
sc.cycles.samples=96
sc.cycles.adaptive_threshold=.029
sc.render.resolution_percentage=100
sc.render.resolution_x=sc.render.resolution_y=460
prefix=('Hand  |','Relaxed finger','Opposed thumb','Finger nail','Thumbnail','Poplin cuff','Hand study','Jacket sleeve with elbow ease','Outer sleeve seam','Sleeve horn button')
closecam=bpy.data.cameras.new('Hand evidence')
closecam.type='ORTHO'
closecam.ortho_scale=.30
cam=bpy.data.objects.new('Hand evidence',closecam)
sc.collection.objects.link(cam)
sc.camera=cam
meshes=[o for o in sc.objects if o.type=='MESH']
for mode,sign,center,normal in [('relaxed',1,(.543,-.086,.743),(1,-.12,.02)),('hip',-1,(-.404,-.207,.888),(-.91,-.34,-.24))]:
    if len(args)>1 and mode not in args[1:]:continue
    for o in meshes:
        mid=o.matrix_world @ sum((Vector(v) for v in o.bound_box),Vector())/8
        o.hide_render=not (o.name.startswith(prefix) and mid.x*sign>0)
    c=Vector(center)
    n=Vector(normal).normalized()
    side=Vector((0,1,0))
    side=(side-side.dot(n)*n).normalized()
    for label,direction in [('palm',-n),('back',n),('edge',side),('thumb',-side)]:
        cam.location=c+direction*1.5
        cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
        sc.render.filepath=str(out/(mode+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
if len(args)==1:
    for o in meshes:o.hide_render=False
    sc.render.resolution_x,sc.render.resolution_y=720,840
    sc.camera=original
    sc.render.filepath=str(out/'body.png')
    bpy.ops.render.render(write_still=True)
    # Show the contact on the jacket with the entire character present.
    sc.camera=cam
    sc.render.resolution_x=sc.render.resolution_y=540
    center=Vector((-.435,-.165,.940))
    direction=Vector((-.88,-.90,.16)).normalized()
    cam.location=center+direction*1.8
    cam.rotation_euler=(-direction).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale=.49
    sc.render.filepath=str(out/'waist_context.png')
    bpy.ops.render.render(write_still=True)
