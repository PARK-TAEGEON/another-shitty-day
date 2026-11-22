"""blender -b --python build.py -- <hands-study.blend> <repo-root> [player|kim]"""
import bpy
import math
import sys
from mathutils import Vector as V, Matrix as M, Quaternion as Q
from pathlib import Path
from math import sin, cos, pi
src, repo, *only = sys.argv[sys.argv.index('--') + 1:]
root = Path(repo).resolve()
author = root / 'blender/rig_slice'
assets = root / 'game/assets/rig_slice'
evidence = root / 'docs/evidence/rig_slice'
for d in (author, assets, evidence):
    d.mkdir(parents=True, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0

def mat(name, hex, rough=0.8):
    color = [((int(hex[i:i + 2], 16) / 255 + 0.055) / 1.055) ** 2.4 for i in (0, 2, 4)]
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = m.diffuse_color
    p.inputs['Roughness'].default_value = rough
    return m

def activate(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o

def apply(o, mod):
    activate(o)
    bpy.ops.object.modifier_apply(modifier=mod.name)

def make_mesh(name, vs, fs, material, weights, sub=0):
    me = bpy.data.meshes.new(name)
    me.from_pydata(vs, [], fs)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    me.materials.append(material)
    # Wind shells consistently including mirrored hands.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    for i, ws in enumerate(weights):
        for n, w in ws.items():
            vg = o.vertex_groups.get(n) or o.vertex_groups.new(name=n)
            vg.add([i], w, 'REPLACE')
    if sub:
        mod = o.modifiers.new('Rounded joint loops', 'SUBSURF')
        mod.levels = sub
        apply(o, mod)
    return o

def mixbones(a, b, t):
    return {a: 1 - t, b: t} if 0.0001 < t < 0.9999 else {b if t >= 0.9999 else a: 1.0}

def armature(name, defs):
    arm = bpy.data.armatures.new(name)
    o = bpy.data.objects.new(name, arm)
    bpy.context.collection.objects.link(o)
    activate(o)
    bpy.ops.object.mode_set(mode='EDIT')
    for n, (h, t, par) in defs.items():
        b = arm.edit_bones.new(n)
        b.head = h
        b.tail = t
        if par:
            b.parent = arm.edit_bones[par]
    bpy.ops.object.mode_set(mode='OBJECT')
    o.show_in_front = True
    return o

def bind(o, rig):
    o.parent = rig
    mod = o.modifiers.new('Skin', 'ARMATURE')
    mod.object = rig

def save(name):
    bpy.context.preferences.filepaths.save_version = 0
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.overlay.show_overlays = False
            area.spaces.active.shading.color_type = 'MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(author / (name + '.blend')), compress=True)

def ringmesh(name, rows, convert, mat, weight, sub=1):
    v = []
    w = []
    f = []
    count = 20
    for j, (h, rx, rz, cy) in enumerate(rows):
        for k in range(count):
            a = k * 2 * pi / count
            v.append(convert((rx * cos(a), h, cy + rz * sin(a))))
            w.append(weight(h))
            if j:
                i = (j - 1) * count + k
                l = (j - 1) * count + (k + 1) % count
                f.append((i, l, l + count, i + count))
    f.extend([tuple(range(count)), tuple(range(len(v) - count, len(v)))])
    return make_mesh(name, v, f, mat, w, sub)

def hand(tag, convert, defs, skin, nail, sub=2, viewmodel=False):
    """Welded palm with four distal sockets and a radial side socket. Joint support
    rings receive two adjacent phalanges. Thumb opposition has a separate CMC axis."""
    base = 'Hand' + tag
    verts = []
    weights = []
    faces = []
    nailobjs = []
    digits = []
    idx = {}

    def vertex(p, w):
        verts.append(convert(p))
        weights.append(w)
        return len(verts) - 1
    hs = [-0.048, -0.028, -0.003, 0.017, 0.035, 0.056, 0.078, 0.096, 0.105]
    widths = [0.029, 0.03, 0.029, 0.034, 0.04, 0.045, 0.047, 0.048, 0.047]
    for j, (h, rx) in enumerate(zip(hs, widths)):
        for k in range(9):
            q = (k - 4) / 4
            for side in [-1, 1]:
                d = 0.015 + 0.005 * sin(max(0, h) / 0.105 * pi * 0.8)
                z = side * d * (1 - 0.32 * abs(q) ** 2)
                if side < 0:
                    z -= 0.008 * math.exp(-((q + 0.59) / 0.34) ** 2 - ((h - 0.049) / 0.03) ** 2)
                else:
                    z += 0.003 * math.exp(-((h - 0.097) / 0.02) ** 2) * (1 + 0.4 * cos((k - 1) * pi))
                off = -0.013 * q * q - 0.004 * q
                p = (q * rx, h + off * max(0, h / 0.105) ** 2, z)
                idx[j, k, side] = vertex(p, {base: 1})
    for j in range(len(hs) - 1):
        for k in range(8):
            for s in [-1, 1]:
                faces.append([idx[j, k, s], idx[j, k + 1, s], idx[j + 1, k + 1, s], idx[j + 1, k, s]])
        for k in [0, 8]:
            if k == 0 and j in [3, 4]:
                continue
            faces.append([idx[j, k, -1], idx[j, k, 1], idx[j + 1, k, 1], idx[j + 1, k, -1]])
    for k in range(8):
        faces.append([idx[0, k, -1], idx[0, k + 1, -1], idx[0, k + 1, 1], idx[0, k, 1]])
    for i, (label, L) in enumerate([('Index', 0.084), ('Middle', 0.093), ('Ring', 0.087), ('Little', 0.072), ('Thumb', 0.09)]):
        thumb = i == 4
        if thumb:
            last = [idx[j, 0, s] for j, s in [(3, -1), (4, -1), (5, -1), (5, 1), (4, 1), (3, 1)]]
            org = V((-0.054 if viewmodel else -0.037, 0.038, -0.003))
            axis = V((-0.62, 0.67, -0.41)).normalized()
            width = V((0.45, 0.72, 0.18))
            width = (width - axis * width.dot(axis)).normalized()
            radius = 0.0132
        else:
            k = i * 2
            last = [idx[8, k, -1], idx[8, k + 1, -1], idx[8, k + 2, -1], idx[8, k + 2, 1], idx[8, k + 1, 1], idx[8, k, 1]]
            q = (i - 1.5) * 0.5
            org = V((q * 0.047, 0.105 - 0.013 * q * q - 0.004 * q, 0))
            axis = V((q * 0.085, 1, -0.035)).normalized()
            width = V((1, 0, 0))
            radius = [0.0134, 0.0138, 0.0131, 0.0116][i]
        dorsal = width.cross(axis).normalized()
        if dorsal.z < 0:
            dorsal.negate()
        lengths = [0, 0.45, 0.75, 1.0]
        names = [label + str(k + 1) + tag for k in range(3)]
        for j, n in enumerate(names):
            joint = org + axis * L * lengths[j]
            if viewmodel and (not thumb) and (j == 0):
                joint.z -= 0.0065
            defs[n] = (convert(joint), convert(org + axis * L * lengths[j + 1]), names[j - 1] if j else base)
        digits.append((label, names, org, axis, width, dorsal))
        # Widen the blend across both sides of each hinge for the deep first-person fist.
        p0, p1, d0, d1 = (0.21, 0.61, 0.61, 0.96) if viewmodel else (0.37, 0.54, 0.675, 0.825)
        for t in [0.028, 0.09, 0.2, 0.36, 0.425, 0.45, 0.475, 0.54, 0.66, 0.72, 0.75, 0.78, 0.86, 0.92, 0.965, 0.993, 1.0]:
            center = org + axis * (L * t)
            radius_factor = (1 - 0.23 * t) * (1 + 0.06 * cos((t - 0.45) * 2 * pi / 0.3))
            if t > 0.92:
                radius_factor *= max(0.12, math.sqrt(max(0, 1 - ((t - 0.92) / 0.081) ** 2)))
            r = radius * radius_factor
            if t < 0.15:
                w = mixbones(base, names[0], min(1, 0.08 + 6.5 * t if viewmodel else 0.52 + 3.6 * t))
            elif t < p1:
                w = mixbones(names[0], names[1], max(0, min(1, (t - p0) / (p1 - p0 if viewmodel else 0.16))))
            else:
                w = mixbones(names[1], names[2], max(0, min(1, (t - d0) / (d1 - d0))))
            ring = []
            for u, v in [(-0.9, -0.64), (0, -1), (0.9, -0.64), (0.9, 0.64), (0, 1), (-0.9, 0.64)]:
                ring.append(vertex(center + width * (u * r) + dorsal * (v * r * 0.94), w))
            for k in range(6):
                faces.append((last[k], last[(k + 1) % 6], ring[(k + 1) % 6], ring[k]))
            last = ring
        faces.append(last)
        # Low-profile nail embedded in the dorsal side of the last phalanx.
        nv = []
        nf = []
        for j, t in enumerate([0.795, 0.83, 0.91, 0.945]):
            for k in range(5):
                a = (k - 2) / 2
                b = 0.7 if j in [0, 3] else 1
                nv.append(convert(org + axis * (L * t) + width * (a * b * radius * 0.5) + dorsal * (radius * (0.64 - 0.13 * a * a))))
                if j and k:
                    z = j * 5 + k
                    nf.append((z - 6, z - 5, z, z - 1))
        nailobjs.append(make_mesh(label + ' nail' + tag, nv, nf, nail, [{names[2]: 1}] * len(nv), 1))
    return ([make_mesh('Palm and fingers' + tag, verts, faces, skin, weights, sub)] + nailobjs, digits)

def rotbone(rig, n, axis, angle):
    b = rig.data.bones[n]
    local = b.matrix_local.to_quaternion().inverted() @ axis.normalized()
    rig.pose.bones[n].rotation_quaternion = Q(local, angle)

def render(path, cam, percent=100):
    sc = bpy.context.scene
    sc.camera = cam
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 18
    sc.cycles.use_denoising = False
    sc.render.resolution_percentage = percent
    sc.render.filepath = str(evidence / path)
    bpy.ops.render.render(write_still=True)

def player():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = 30
    skin = mat('Caricature skin', 'C99577', 0.86)
    nail = mat('Muted nail', 'D5A38A')
    cloth = mat('Blue grey shirting', 'B0C1C5', 0.94)
    cuff = mat('Pressed cuff', 'C0CCCD')
    button = mat('Cuff button', 'D5D2B7')
    rigs = []
    for side in [-1, 1]:
        tag = '.L' if side < 0 else '.R'

        def cv(p):
            return V((p[0] * side, -p[2], p[1]))
        defs = {'UpperArm' + tag: (cv((0, -0.66, 0.36)), cv((0, -0.32, 0.094)), None), 'Forearm' + tag: (cv((0, -0.32, 0.094)), cv((0, -0.015, 0)), 'UpperArm' + tag), 'Hand' + tag: (cv((0, -0.015, 0)), cv((0, 0.09, 0)), 'Forearm' + tag)}
        obs, digits = hand(tag, cv, defs, skin, nail, viewmodel=True)
        srows = [(-0.7, 0.081, 0.078, 0.39), (-0.62, 0.084, 0.078, 0.34), (-0.47, 0.079, 0.071, 0.22), (-0.36, 0.077, 0.067, 0.135), (-0.33, 0.077, 0.067, 0.1), (-0.3, 0.07, 0.064, 0.08), (-0.245, 0.06, 0.052, 0.046), (-0.195, 0.054, 0.047, 0.022), (-0.15, 0.049, 0.04, 0.007), (-0.135, 0.052, 0.042, 0.004), (-0.123, 0.045, 0.037, 0.003), (-0.108, 0.047, 0.038, 0.002), (-0.086, 0.039, 0.033, 0), (-0.078, 0.038, 0.032, 0)]

        def sleeveweights(z):
            return mixbones('UpperArm' + tag, 'Forearm' + tag, max(0, min(1, (z + 0.37) / 0.1)))
        obs.append(ringmesh('Shirt' + tag, srows, cv, cloth, sleeveweights))
        obs.append(ringmesh('Stitched barrel cuff' + tag, [(-0.09, 0.042, 0.035, 0), (-0.087, 0.043, 0.036, 0), (-0.082, 0.042, 0.035, 0), (-0.043, 0.036, 0.029, 0), (-0.039, 0.036, 0.029, 0), (-0.036, 0.035, 0.028, 0)], cv, cuff, sleeveweights))
        # Rigid button detail, on dorsal/radial cuff edge.
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, location=cv((-0.028, -0.061, 0.019)))
        bt = bpy.context.object
        bt.name = 'Button' + tag
        bt.scale = (0.005, 0.003, 0.005)
        bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
        bt.data.materials.append(button)
        vg = bt.vertex_groups.new(name='Forearm' + tag)
        vg.add(list(range(len(bt.data.vertices))), 1, 'REPLACE')
        obs.append(bt)
        rig = armature('Player' + tag, defs)
        for o in obs:
            bind(o, rig)
        # Author each finger rotation in its rest-bone coordinate system.
        for pose, amount in [('open', 0), ('carry', 0.4), ('opposition', 0.665), ('loose', 0.93), ('fist', 1)]:
            frame = {'open': 1, 'carry': 10, 'opposition': 15, 'loose': 20, 'fist': 30}[pose]
            sc.frame_set(frame)
            for label, names, org, direction, width, back in digits:
                for k, n in enumerate(names):
                    if label == 'Thumb':
                        # Aim the thumb from the thenar pad across the curled index and middle.
                        targets = [V((-0.14, 0.605, -0.79)), V((0.47, 0.49, -0.74)), V((0.96, 0.21, -0.18))]
                        if pose == 'opposition':
                            targets[0] = V((-0.26, 0.58, -0.78))
                        if pose == 'fist':
                            targets[1:] = [V((0.49, 0.57, -0.65)), V((0.98, 0.24, -0.05))]
                        target = targets[k]
                        prev = direction if k == 0 else targets[k - 1].normalized()
                        cumulative = cv(direction).rotation_difference(cv(target.normalized()))
                        parent = Q() if k == 0 else cv(direction).rotation_difference(cv(prev))
                        delta = parent.inverted() @ cumulative
                        b = rig.data.bones[n].matrix_local.to_quaternion()
                        rig.pose.bones[n].rotation_quaternion = Q().slerp(b.inverted() @ delta @ b, amount)
                    else:
                        idx = ['Index', 'Middle', 'Ring', 'Little'].index(label)
                        angle = [76 + idx * 2, 108 - idx, 75 + idx * 1.5][k]
                        # Mirroring changes axial handedness.
                        rotbone(rig, n, cv((1, 0, 0)), math.radians(-angle) * amount * side)
                    rig.pose.bones[n].keyframe_insert('rotation_quaternion', frame=frame)
        rig.animation_data.action.name = 'Grip' + tag
        # Export with the authored animation. Godot samples the track at exact key times.
        activate(rig)
        for o in obs:
            o.select_set(True)
        anim = rig.animation_data
        action = anim.action
        anim.action = None
        track = anim.nla_tracks.new()
        track.name = 'Grip'
        track.strips.new('Grip', 1, action)
        bpy.ops.export_scene.gltf(filepath=str(assets / ('player_' + ('left' if side < 0 else 'right') + '.glb')), use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS', export_frame_range=False, export_force_sampling=True)
        anim.nla_tracks.remove(track)
        anim.action = action
        rigs.append((rig, obs))
    sc.render.fps = 30
    sc.frame_start = 1
    sc.frame_end = 30
    sc.frame_set(20)
    camdata = bpy.data.cameras.new('Godot vertical FOV 77')
    camdata.sensor_fit = 'VERTICAL'
    camdata.sensor_height = 24
    camdata.lens = 12 / math.tan(math.radians(77 / 2))
    camdata.clip_start = 0.045
    cam = bpy.data.objects.new('Player camera', camdata)
    sc.collection.objects.link(cam)
    cam.rotation_euler.x = pi / 2
    sc.camera = cam
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.resolution_percentage = 100
    conv = M(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
    for side, (rig, obs) in zip([-1, 1], rigs):
        lx = V((0, 0.984, -0.18)).normalized() * -side
        fy = V((0, -0.18, -0.984)).normalized()
        source = M((lx, fy, lx.cross(fy))).transposed()
        pitch = M.Rotation(0.12, 3, 'X')
        rest = pitch @ M.Rotation(-0.13, 3, 'X') @ source
        pos = V((side * 0.265, -0.188, -0.385))
        rig.matrix_world = M.Translation(conv @ pos) @ (conv @ rest @ conv.inverted()).to_4x4() @ M.Scale(1.2, 4)
    sc.world = bpy.data.worlds.new('Studio')
    sc.world.use_nodes = True
    sc.world.node_tree.nodes['Background'].inputs[0].default_value = (0.6, 0.64, 0.67, 1)
    for x in [-1, 1]:
        d = bpy.data.lights.new('Softbox', 'AREA')
        d.energy = 40
        d.shape = 'DISK'
        d.size = 1.2
        o = bpy.data.objects.new('Softbox', d)
        sc.collection.objects.link(o)
        o.location = (x, -0.22, 0.9)
        o.rotation_euler = (V((0, 0.35, -0.3)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    save('player_arms')
    render('player_projection.png', cam, 100)
    # Three views of the same tight fist, in the arm's anatomical coordinates.
    sc.frame_set(30)
    rig, obs = rigs[1]
    for o in rigs[0][1]:
        o.hide_render = True
    sc.render.resolution_x = sc.render.resolution_y = 520
    close = bpy.data.objects.new('Fist inspection', bpy.data.cameras.new('Fist inspection'))
    sc.collection.objects.link(close)
    close.data.type = 'ORTHO'
    close.data.ortho_scale = 0.235
    target = rig.matrix_world @ V((0, 0.014, 0.06))
    for name, direction in [('dorsal', (0.21, -1, 0.24)), ('thumb', (-1, 0.2, 0.17)), ('palm', (0.18, 1, 0.3))]:
        d = rig.matrix_world.to_3x3() @ V(direction).normalized()
        close.location = target + d * 0.5
        close.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
        render('fist_' + name + '.png', close)
if not only or only[0] == 'player':
    player()

def kim():
    bpy.ops.wm.open_mainfile(filepath=str(Path(src).resolve()))
    sc = bpy.context.scene
    sc.render.fps = 30
    # Keep the silhouette and complexion of the source. Flatten procedural shading
    # into a compact vertex-colour palette that survives glTF import.
    palette = {}
    for name, rough, metal in [('Skin and hair', 0.74, 0), ('Cloth', 0.89, 0), ('Leather and eyes', 0.44, 0), ('Metal', 0.39, 0.65)]:
        m = mat(name, 'FFFFFF', rough)
        bs = m.node_tree.nodes.get('Principled BSDF')
        bs.inputs['Metallic'].default_value = metal
        attr = m.node_tree.nodes.new('ShaderNodeVertexColor')
        attr.layer_name = 'Albedo'
        m.node_tree.links.new(attr.outputs[0], bs.inputs['Base Color'])
        palette[name] = m

    def tag(s):
        return '.L' if s > 0 else '.R'
    defs = {}

    def bone(n, h, t, p=None):
        defs[n] = (V(h), V(t), p)
    bone('Root', (0, 0, 0), (0, 0, 0.12))
    bone('Pelvis', (0, 0, 0.64), (0, 0, 0.88), 'Root')
    bone('Spine', (0, 0, 0.88), (0, 0.01, 1.14), 'Pelvis')
    bone('Chest', (0, 0.01, 1.14), (0, 0.025, 1.46), 'Spine')
    bone('Neck', (0, 0.025, 1.46), (0, 0, 1.55), 'Chest')
    bone('Head', (0, 0, 1.55), (0, -0.02, 2.06), 'Neck')

    def ap(s, p):
        sh = V((s * 0.389, 0.026, 1.426))
        return sh + M.Rotation(math.radians(-28 * s), 3, 'Y') @ (V(p) - sh)
    handobs = []
    chains = {}
    for s in [-1, 1]:
        t = tag(s)
        sh = (s * 0.389, 0.026, 1.426)
        e = ap(s, (s * 0.518, 0, 1.14))
        wr = ap(s, (s * 0.547, -0.085, 0.831))
        bone('Clavicle' + t, (s * 0.06, 0.02, 1.43), sh, 'Chest')
        bone('UpperArm' + t, sh, e, 'Clavicle' + t)
        bone('Forearm' + t, e, wr, 'UpperArm' + t)

        def cv(p):
            u, d, n = p
            cuff_blend = max(0, min(1, (0.008 - d) / 0.056))
            return ap(s, (s * (0.547 + n * (1.16 + 0.28 * cuff_blend) + 0.035 * d), -0.085 + u * (1.22 + 0.14 * cuff_blend) - 0.07 * d, 0.831 - d * 1.04))
        bone('Hand' + t, wr, cv((0, 0.1, 0)), 'Forearm' + t)
        os, digs = hand(t, cv, defs, mat('Hand tone' + t, 'D99972'), mat('Nail tone' + t, 'D99D87'), 1)
        handobs += os
        chains[t] = digs
        bone('UpperLeg' + t, (s * 0.185, 0.012, 0.72), (s * 0.216, -0.016, 0.39), 'Pelvis')
        bone('LowerLeg' + t, (s * 0.216, -0.016, 0.39), (s * 0.224, 0.01, 0.13), 'UpperLeg' + t)
        bone('Foot' + t, (s * 0.224, 0.01, 0.13), (s * 0.225, -0.2, 0.053), 'LowerLeg' + t)

    def clamp(x):
        return min(1, max(0, x))

    def weights(o, z, x, typ, s):
        t = tag(s)
        if typ == 'head':
            return {'Head': 1} if not o.name.startswith('Neck') else mixbones('Chest', 'Head', clamp((z - 1.48) / 0.09))
        if typ == 'shoe':
            return {'Foot' + t: 1}
        if typ == 'leg':
            if z > 0.55:
                return mixbones('UpperLeg' + t, 'Pelvis', clamp((z - 0.55) / 0.15))
            return mixbones('LowerLeg' + t, 'UpperLeg' + t, clamp((z - 0.33) / 0.14))
        if typ == 'arm':
            if z > 1.38:
                return mixbones('UpperArm' + t, 'Clavicle' + t, 0.48 * clamp((z - 1.38) / 0.11))
            return mixbones('Forearm' + t, 'UpperArm' + t, clamp((z - 1.07) / 0.15))
        if z > 1.33 and abs(x) > 0.25:
            return mixbones('Chest', 'Clavicle' + t, clamp((z - 1.33) / 0.15) * clamp((abs(x) - 0.25) / 0.16) * 0.78)
        return mixbones('Spine', 'Chest', clamp((z - 1.05) / 0.25)) if z > 1.05 else mixbones('Pelvis', 'Spine', clamp((z - 0.82) / 0.23))
    keep = []

    def finish(o, typ, mirror=False):
        name = o.name
        wm = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = M.Identity(4)
        for mod in list(o.modifiers):
            apply(o, mod)
        o.data.transform(wm)
        for v in o.data.vertices:
            if mirror:
                v.co.x = -v.co.x
            x, y, z = v.co
            s = 1 if x >= 0 else -1
            if typ != 'hand':
                for n, w in weights(o, z, x, typ, s).items():
                    vg = o.vertex_groups.get(n) or o.vertex_groups.new(name=n)
                    vg.add([v.index], w, 'REPLACE')
            if typ == 'arm':
                v.co = ap(s, v.co)
        if mirror:
            o.data.flip_normals()
        om = o.data.materials[0]
        n = om.name
        attr = o.data.color_attributes.get('Complexion') or o.data.color_attributes.get('Combed tone')
        color = om.diffuse_color[:]
        if attr is not None:
            attr.name = 'Albedo'
        else:
            attr = o.data.color_attributes.new(name='Albedo', type='FLOAT_COLOR', domain='POINT')
            attr.data.foreach_set('color', list(color) * len(attr.data))
        material = 'Cloth' if typ in ['coat', 'leg', 'arm'] else 'Skin and hair'
        if typ == 'shoe' or n.startswith(('05', '06', '07', '08', '19', '21')):
            material = 'Leather and eyes'
        if n.startswith('20'):
            material = 'Metal'
        o.data.color_attributes.active_color = attr
        o.data.materials.clear()
        o.data.materials.append(palette[material])
        initial = sum((len(p.vertices) - 2 for p in o.data.polygons))
        # Simplify dense non-articulating surfaces aggressively. Sleeve and leg station
        # rings retain their intermediate weights at the flexion zones.
        if typ != 'hand' and initial > 160:
            ratio = 0.36 if typ in ['arm', 'leg'] else 0.102 if typ == 'head' else 0.16
            if name.startswith('Combed hair'):
                ratio = 0.065
            mod = o.modifiers.new('Silhouette simplification', 'DECIMATE')
            mod.ratio = max(90 / initial, ratio)
            apply(o, mod)
        keep.append(o)
    for o in list(sc.objects):
        if o.type != 'MESH' or o in handobs:
            continue
        group = o.users_collection[0].name
        if group.startswith('07'):
            continue
        if group.startswith('Hand study'):
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        typ = 'head' if group[:2] in ['01', '02', '03'] else 'shoe' if group.startswith('06') else 'coat'
        if group.startswith('05'):
            typ = 'leg' if o.name.startswith(('Trousers', 'Outseam', 'Trouser hem')) else 'arm'
            if typ == 'arm':
                avg = sum((v.co.x for v in o.data.vertices)) / len(o.data.vertices)
                if avg < 0:
                    bpy.data.objects.remove(o, do_unlink=True)
                    continue
                mirror = o.copy()
                mirror.data = o.data.copy()
                o.users_collection[0].objects.link(mirror)
                finish(mirror, typ, True)
        finish(o, typ)
    for o in handobs:
        finish(o, 'hand')
    activate(keep[0])
    for o in keep:
        o.select_set(True)
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'Boss Kim • game mesh'
    rig = armature('Kim common humanoid', defs)
    bind(body, rig)
    activate(rig)
    for frame in [1, 20, 40, 60]:
        sc.frame_set(frame)
        for b in rig.pose.bones:
            b.rotation_quaternion = Q()
        if frame > 1:
            for s in [-1, 1]:
                t = tag(s)
                rotbone(rig, 'Clavicle' + t, V((0, 1, 0)), math.radians(-s * (6 if frame == 20 else 2)))
                rotbone(rig, 'UpperArm' + t, V((0, 1, 0)), math.radians(-s * (37 if frame == 20 else 8)))
                rotbone(rig, 'Forearm' + t, V((1, 0, 0)), math.radians(-65 if frame == 40 else -12))
                rotbone(rig, 'Hand' + t, V((0, 1, 0)), math.radians(s * (16 if frame != 20 else 5)))
                for label, names, *_ in chains[t]:
                    for k, n in enumerate(names):
                        rotbone(rig, n, V((0, 1, 0)) if label != 'Thumb' else V((1, 0, 0)), math.radians((s if label != 'Thumb' else 1) * (39 if frame == 60 else 9)))
        for b in rig.pose.bones:
            b.keyframe_insert('rotation_quaternion', frame=frame)
    rig.animation_data.action.name = 'Shoulder elbow wrist and finger checks'
    sc.frame_start = 1
    sc.frame_end = 60
    sc.frame_set(1)
    activate(rig)
    body.select_set(True)
    anim = rig.animation_data
    action = anim.action
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = 'Joint_review'
    track.strips.new('Joint_review', 1, action)
    bpy.ops.export_scene.gltf(filepath=str(assets / 'boss_kim_game.glb'), use_selection=True, export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True)
    anim.nla_tracks.remove(track)
    anim.action = action
    sc.frame_set(1)
    cam = bpy.data.objects['View  |  three_quarter']
    cam.data.ortho_scale = 2.63
    sc.camera = cam
    save('boss_kim_game')
    for f, n in [(1, 'kim_A'), (20, 'kim_shoulders'), (40, 'kim_elbows'), (60, 'kim_grip')]:
        sc.frame_set(f)
        render(n + '.png', cam, 54)
if not only or only[0] == 'kim':
    kim()
