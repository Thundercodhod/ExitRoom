"""Rebuilds the unified skin body + clothing shells for the M.6 student.
exec(open(PATH).read()) inside Blender (player.blend must be open).
Tunable proportions are in the P dict at the top.
"""
import os
exec(open(os.path.join(os.path.dirname("/Users/saran/3d-game-project/assets_src/gen_helpers.py"), "gen_helpers.py")).read())
import math, glob
from mathutils import Vector, Matrix

P = dict(
    head=((0, -0.02, 0.94), (0.27, 0.26, 0.235)),
    torso=((0, 0.0, 0.53), (0.29, 0.25, 0.25)),
    hips=((0, 0.0, 0.33), (0.265, 0.24, 0.14)),
    shoulder=((0.30, 0, 0.63), (0.38, 0, 0.53), 0.092),   # right side mirrored
    thigh=((0.12, 0, 0.21), 0.09),
    shin=((0.12, 0, 0.19), (0.12, 0, 0.10), 0.062),
    arm_x=0.40, arm_tilt=10.0,
    shirt_bottom=0.395, shirt_neck=0.765, sleeve_end=0.118,
    shorts_top=0.448, shorts_bottom=0.145,
)
M = bpy.data.materials
K = 1 / 0.575


def remove(name):
    ob = bpy.data.objects.get(name)
    if ob and COLL_NAME in [c.name for c in ob.users_collection]:
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and getattr(data, "users", 1) == 0:
            for coll_ in (bpy.data.meshes, bpy.data.metaballs, bpy.data.curves):
                if data.name in coll_ and coll_[data.name] == data:
                    coll_.remove(data)
                    break


def arm_axis(sx):
    (x0, y0, z0), (x1, y1, z1), r = P["shoulder"]
    p0 = Vector((sx * x0, y0, z0)); p1 = Vector((sx * x1, y1, z1))
    return p0, (p1 - p0).normalized()


# ------------------------------------------------------------------ skin
def build_skin():
    for n in ("SkinMeta", "Skin"):
        remove(n)
    mb = bpy.data.metaballs.new("SkinMeta")
    mb.resolution = mb.render_resolution = 0.008
    mb.threshold = 0.6
    meta = bpy.data.objects.new("SkinMeta", mb); coll().objects.link(meta)

    def ell(c, r):
        e = mb.elements.new(type='ELLIPSOID'); e.co = c; e.radius = K
        e.size_x, e.size_y, e.size_z = r

    def cap(p0, p1, r):
        p0, p1 = Vector(p0), Vector(p1); d = p1 - p0
        e = mb.elements.new(type='CAPSULE'); e.co = (p0 + p1) / 2; e.radius = r * K
        e.size_x = d.length / 2
        e.rotation = Vector((1, 0, 0)).rotation_difference(d.normalized())

    ell(*P["head"]); ell(*P["torso"]); ell(*P["hips"])
    for sx in (-1, 1):
        (a, b, r) = P["shoulder"]
        cap((sx * a[0], a[1], a[2]), (sx * b[0], b[1], b[2]), r)
        (tc, tr) = P["thigh"]
        e = mb.elements.new(type='BALL'); e.co = (sx * tc[0], tc[1], tc[2]); e.radius = tr * K
        (s0, s1, sr) = P["shin"]
        cap((sx * s0[0], s0[1], s0[2]), (sx * s1[0], s1[1], s1[2]), sr)

    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(meta.evaluated_get(dg)); me.name = "Skin"
    meta.hide_viewport = meta.hide_render = True
    skin = new_obj("Skin", me, M["M_Skin"])
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    skin.select_set(True)
    bpy.context.view_layer.objects.active = skin
    ov = dict(active_object=skin, object=skin, selected_objects=[skin], selected_editable_objects=[skin])
    skin.data.remesh_voxel_size = 0.01
    with bpy.context.temp_override(**ov):
        bpy.ops.object.voxel_remesh()
        r = bpy.ops.object.quadriflow_remesh(target_faces=7000, use_mesh_symmetry=True, smooth_normals=True, seed=3)
    if 'FINISHED' not in r:
        # fallback: coarser voxel grid (all quads) when QuadriFlow refuses the mesh
        skin.data.remesh_voxel_size = 0.015
        with bpy.context.temp_override(**ov):
            bpy.ops.object.voxel_remesh()
    smooth(skin.data)
    return skin


# ------------------------------------------------------------------ shells
def shell(name, skin, cuts, offset, material, extra=None):
    """cuts: list of (plane_co, plane_no, geom_filter or None). Keeps the side opposite plane_no."""
    remove(name)
    bm = bmesh.new(); bm.from_mesh(skin.data)
    for co, no, filt in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        if filt:
            fs = [f for f in bm.faces if all(filt(v.co) for v in f.verts)]
            es = {e for f in fs for e in f.edges}; vs = {v for f in fs for v in f.verts}
            geom = list(vs) + list(es) + fs
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, dist=1e-6)
        kill = [v for v in bm.verts if (v.co - Vector(co)).dot(Vector(no)) > 1e-5 and (filt is None or filt(v.co))]
        bmesh.ops.delete(bm, geom=kill, context='VERTS')
    # drop tiny loose islands
    islands, seen = [], set()
    for v in bm.verts:
        if v in seen: continue
        stack, isl = [v], []
        while stack:
            x = stack.pop()
            if x in seen: continue
            seen.add(x); isl.append(x)
            stack.extend(e.other_vert(x) for e in x.link_edges)
        islands.append(isl)
    biggest = max(len(i) for i in islands)
    for isl in islands:
        if len(isl) < 0.05 * biggest:
            bmesh.ops.delete(bm, geom=isl, context='VERTS')
    bm.normal_update()
    for v in bm.verts:
        v.co = v.co + v.normal * offset(v.co)
    if extra:
        extra(bm)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); smooth(me)
    ob = new_obj(name, me, material)
    return ob


def build_clothes(skin):
    # --- shirt: cut bottom, neck, and each sleeve cuff perpendicular to the arm
    cuts = [((0, 0, P["shirt_bottom"]), (0, 0, -1), None),
            ((0, 0, P["shirt_neck"]), (0, 0, 1), None)]
    for sx in (-1, 1):
        p0, d = arm_axis(sx)
        def filt(co, sx=sx, p0=p0, d=d):
            if co.x * sx < 0.26: return False
            rel = Vector(co) - p0; t = rel.dot(d)
            return (rel - d * t).length < 0.14 and t > 0.0
        cuts.append((p0 + d * P["sleeve_end"], d, filt))

    def shirt_off(co):
        off = 0.012
        for sx in (-1, 1):
            if co.x * sx > 0.26:
                p0, d = arm_axis(sx)
                rel = Vector(co) - p0; t = rel.dot(d)
                if (rel - d * t).length < 0.14 and t > P["sleeve_end"] - 0.03:
                    off += 0.004 * min(1.0, (t - (P["sleeve_end"] - 0.03)) / 0.03)
        return off

    shirt = shell("Shirt", skin, cuts, shirt_off, M["M_Shirt"])
    add_mod(shirt, "SOLIDIFY", thickness=0.006, offset=-1.0)
    add_mod(shirt, "SUBSURF", levels=1, render_levels=2)

    # --- shorts: clean top/bottom cuts, flared leg openings
    def flare(bm):
        for v in bm.verts:
            if v.co.z < 0.20:
                sx = 1 if v.co.x >= 0 else -1
                dv = Vector((v.co.x - sx * P["thigh"][0][0], v.co.y, 0))
                if dv.length > 1e-6:
                    v.co += dv.normalized() * (0.20 - v.co.z) * 0.45
    shorts = shell("Shorts", skin,
                   [((0, 0, P["shorts_top"]), (0, 0, 1), None),
                    ((0, 0, P["shorts_bottom"]), (0, 0, -1), None)],
                   lambda co: 0.014, M["M_Navy"], extra=flare)
    add_mod(shorts, "SOLIDIFY", thickness=0.007, offset=-1.0)
    add_mod(shorts, "SUBSURF", levels=1, render_levels=2)
    return shirt, shorts


# ------------------------------------------------------------------ arms (forearm + mitten, separate so they never fuse with the hips)
def cut_skin_sleeves(skin):
    """Remove the upper-arm skin beyond the sleeve cuff so only the forearm shows."""
    bm = bmesh.new(); bm.from_mesh(skin.data)
    for sx in (-1, 1):
        p0, d = arm_axis(sx)
        def filt(co, sx=sx, p0=p0, d=d):
            if co.x * sx < 0.26: return False
            rel = Vector(co) - p0; t = rel.dot(d)
            return (rel - d * t).length < 0.14 and t > 0.0
        fs = [f for f in bm.faces if all(filt(v.co) for v in f.verts)]
        es = {e for f in fs for e in f.edges}; vs = {v for f in fs for v in f.verts}
        co = p0 + d * (P["sleeve_end"] - 0.01)
        bmesh.ops.bisect_plane(bm, geom=list(vs) + list(es) + fs, plane_co=co, plane_no=d, dist=1e-6)
        kill = [v for v in bm.verts if (v.co - co).dot(d) > 1e-5 and filt(v.co)]
        bmesh.ops.delete(bm, geom=kill, context='VERTS')
    bm.to_mesh(skin.data); bm.free(); smooth(skin.data)


def capsule_mesh(name, top, bottom, r, material, hand_bulge=0.06, segs=24, rings=16):
    top, bottom = Vector(top), Vector(bottom)
    axis = top - bottom; half = axis.length / 2
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
    for v in bm.verts:
        z = v.co.z
        if z < 0:   # hand end: slightly fuller mitten
            k = 1.0 + hand_bulge * min(1.0, -z / r)
            v.co.x *= k; v.co.y *= k
        v.co.z = z + (half if z >= 0 else -half)
    rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=rot, verts=bm.verts)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); smooth(me)
    ob = new_obj(name, me, material)
    ob.location = (top + bottom) / 2
    return ob


def build_arms():
    tilt = math.radians(P["arm_tilt"])
    for side, sx in (("R", -1), ("L", 1)):
        remove(f"Arm.{side}")
        p0, d = arm_axis(sx)
        cuff = p0 + d * P["sleeve_end"]
        fdir = Vector((sx * math.sin(tilt), 0, -math.cos(tilt)))
        r = P["shoulder"][2] - 0.002
        top = cuff - d * 0.03                         # on the sleeve axis, just inside the cuff
        hand_bottom_z = 0.24
        length = (top.z - (hand_bottom_z + r)) / math.cos(tilt)
        bottom = top + fdir * length
        capsule_mesh(f"Arm.{side}", top, bottom, r, M["M_Skin"])


# ------------------------------------------------------------------ details
def radial_hit(target, z, a, off, outside=False, inner_wall=0.0):
    d = Vector((math.sin(a), -math.cos(a), 0))
    for dz in (0.0, -0.004, 0.004, -0.008, 0.008, -0.012):
        zz = z + dz
        if outside:
            loc, nor = surface_hit(target, Vector((0, 0, zz)) + d * 1.5, -d)
        else:
            loc, nor = surface_hit(target, (0, 0, zz), d)
        if loc is not None:
            loc = loc.copy(); loc.z = z   # keep the requested height
            return loc + d * (off + inner_wall)
    raise RuntimeError("miss at z=%.3f a=%.1f on %s" % (z, math.degrees(a), target.name))


def build_details(skin, shirt, shorts):
    for n in ("Belt", "Collar", "Placket", "Pocket", "PocketHem", "Badge", "Eye.L", "Eye.R",
              "Button.0", "Button.1", "Button.2"):
        remove(n)
    bpy.context.view_layer.update()
    # belt
    SEG = 80; bm = bmesh.new(); loops = []
    for (z, off) in ((0.38, 0.0), (0.38, 0.014), (0.44, 0.014), (0.44, 0.0)):
        loops.append([bm.verts.new(radial_hit(shorts, z, 2 * math.pi * i / SEG, off, outside=True)) for i in range(SEG)])
    for li in range(4):
        a, b = loops[li], loops[(li + 1) % 4]
        for i in range(SEG):
            j = (i + 1) % SEG; bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Belt"); bm.to_mesh(me); bm.free()
    belt = new_obj("Belt", me, M["M_Belt"]); smooth(me)
    add_mod(belt, "BEVEL", width=0.003, segments=2, limit_method='ANGLE')
    front = radial_hit(shorts, 0.41, 0.0, 0.014, outside=True)
    buckle = bpy.data.objects["Buckle"]
    bb = [buckle.matrix_world @ Vector(c) for c in buckle.bound_box]
    buckle.location.y += (front.y - 0.001) - max(v.y for v in bb)

    # collar
    W = 0.006; bm = bmesh.new(); rows = []; N = 64
    for i in range(N + 1):
        th = math.radians(18 + (360 - 36) * i / N)
        dfront = min(math.degrees(th), 360 - math.degrees(th))
        f = max(0.0, min(1.0, 1 - (dfront - 18) / 60.0))
        sgn = 1 if math.degrees(th) < 180 else -1
        th_out = th - sgn * math.radians(18) * f
        p0 = radial_hit(shirt, 0.755 - 0.02 * f, th, 0.004, inner_wall=W)
        p1 = radial_hit(shirt, 0.755 - 0.03 * f, th, 0.030, inner_wall=W) + Vector((0, 0, 0.022))
        p2 = radial_hit(shirt, 0.725 - 0.06 * f, (th + th_out) / 2, 0.024, inner_wall=W)
        p3 = radial_hit(shirt, 0.690 - 0.115 * f, th_out, 0.006, inner_wall=W)
        rows.append([bm.verts.new(p) for p in (p0, p1, p2, p3)])
    for i in range(N):
        for r in range(3):
            bm.faces.new((rows[i][r], rows[i + 1][r], rows[i + 1][r + 1], rows[i][r + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("Collar"); bm.to_mesh(me); bm.free()
    collar = new_obj("Collar", me, M["M_Shirt"]); smooth(me)
    p = me.polygons[(len(me.polygons) // 2) - 1]
    if p.normal.dot(Vector((p.center.x, p.center.y, 0)).normalized()) < 0:
        me.flip_normals()
    add_mod(collar, "SOLIDIFY", thickness=0.012, offset=-1.0)
    add_mod(collar, "SUBSURF", levels=2, render_levels=2)

    def decal(name, cx, cz, w, h, thick, material, res=8):
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=res, y_segments=res, size=0.5)
        bmesh.ops.scale(bm, vec=(w, h, 1), verts=bm.verts)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'X'), verts=bm.verts)
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        ob = new_obj(name, me, material)
        loc, nor = surface_hit(shirt, (cx, -1, cz), (0, 1, 0))
        ob.location = loc + nor * 0.01
        add_mod(ob, "SHRINKWRAP", target=shirt, wrap_method='NEAREST_SURFACEPOINT', wrap_mode='OUTSIDE_SURFACE', offset=0.002)
        add_mod(ob, "SOLIDIFY", thickness=thick, offset=1.0)
        add_mod(ob, "BEVEL", width=0.002, segments=2, limit_method='ANGLE')

    decal("Placket", 0.0, 0.565, 0.045, 0.25, 0.003, M["M_Shirt"])
    decal("Pocket", 0.165, 0.52, 0.10, 0.115, 0.005, M["M_Shirt"])
    decal("PocketHem", 0.165, 0.572, 0.10, 0.012, 0.007, M["M_Shirt"], res=4)

    for i, z in enumerate((0.655, 0.575, 0.495)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=16, radius1=0.011, radius2=0.011, depth=0.006)
        bmesh.ops.rotate(bm, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, 'X'), verts=bm.verts)
        me = bpy.data.meshes.new(f"Button.{i}"); bm.to_mesh(me); bm.free()
        b = new_obj(f"Button.{i}", me, M["M_Button"]); smooth(me)
        loc, nor = surface_hit(shirt, (0, -1, z), (0, 1, 0))
        align_to_normal(b, loc + nor * 0.006, nor)
        add_mod(b, "BEVEL", width=0.002, segments=2)

    font = bpy.data.fonts.load("/System/Library/Fonts/Supplemental/Krungthep.ttf", check_existing=True)
    cu = bpy.data.curves.new("Badge", 'FONT')
    cu.body = "ม.6"; cu.font = font; cu.size = 0.062; cu.extrude = 0.0015
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'
    badge = bpy.data.objects.new("Badge", cu); coll().objects.link(badge)
    badge.data.materials.append(M["M_Navy"])
    loc, nor = surface_hit(shirt, (-0.165, -1, 0.545), (0, 1, 0))
    zt = nor.normalized(); x = (-zt).cross(Vector((0, 0, 1))).normalized(); y = zt.cross(x).normalized()
    badge.matrix_world = Matrix.Translation(loc + nor * 0.004) @ Matrix((x, y, zt)).transposed().to_4x4()

    for side, sx in (("R", -1), ("L", 1)):
        loc, nor = surface_hit(skin, (sx * 0.08, -1.0, 0.825), (0, 1, 0))
        eye = superellipsoid(f"Eye.{side}", (0, 0, 0), (0.024, 0.012, 0.056), segs=20, rings=12, material=M["M_Eye"])
        align_to_normal(eye, loc + nor * 0.002, nor)


def build_all():
    skin = build_skin()
    shirt, shorts = build_clothes(skin)
    cut_skin_sleeves(skin)
    build_arms()
    bpy.context.view_layer.update()
    build_details(skin, shirt, shorts)
    bpy.ops.wm.save_mainfile()
    return skin, shirt, shorts
