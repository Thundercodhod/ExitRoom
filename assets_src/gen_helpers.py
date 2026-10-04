"""Procedural build helpers for the M.6 student player model.
Run inside Blender: exec(open(PATH).read())
Convention: character faces -Y, Z up, feet at z=0. Units: metres.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix

COLL_NAME = "Player"

# Safety guard: only ever modify our own file.
if not bpy.data.filepath.endswith("3d-game-project/assets_src/player.blend"):
    raise RuntimeError("Wrong file open in Blender: %r (expected assets_src/player.blend)" % bpy.data.filepath)


def coll():
    sc = bpy.context.scene
    c = bpy.data.collections.get(COLL_NAME)
    if c is None:
        c = bpy.data.collections.new(COLL_NAME)
        sc.collection.children.link(c)
    return c


def srgb_to_lin(h):
    h = h.lstrip('#')
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


def mat(name, hexcol, rough=0.6, metal=0.0, sss=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    col = srgb_to_lin(hexcol)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if "Subsurface Weight" in bsdf.inputs:
        bsdf.inputs["Subsurface Weight"].default_value = sss
    m.diffuse_color = col  # solid-view colour
    return m


def new_obj(name, me, material=None, parent=None):
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    ob = bpy.data.objects.new(name, me)
    coll().objects.link(ob)
    if material:
        ob.data.materials.append(material)
    if parent:
        ob.parent = parent
    return ob


def smooth(me):
    for p in me.polygons:
        p.use_smooth = True


def _sp(c, e):
    return math.copysign(abs(c) ** e, c)


def superellipsoid(name, center, radii, e1=1.0, e2=1.0, segs=32, rings=16,
                   taper=0.0, material=None, bulge=None):
    """Rounded box/egg. e<1 boxier, e=1 ellipsoid.
    taper>0 widens the bottom (x,y scaled by 1 - taper*zn).
    bulge: optional fn(Vector local_unit)->scale factor."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    rx, ry, rz = radii
    for v in bm.verts:
        x, y, z = v.co
        r = math.sqrt(x * x + y * y)
        cu, su = r, z
        if r > 1e-6:
            cv, sv = x / r, y / r
        else:
            cv, sv = 1.0, 0.0
        nx = _sp(cu, e1) * _sp(cv, e2)
        ny = _sp(cu, e1) * _sp(sv, e2)
        nz = _sp(su, e1)
        k = 1.0 - taper * nz
        if bulge:
            k *= bulge(Vector((nx, ny, nz)))
        v.co = Vector((rx * nx * k, ry * ny * k, rz * nz))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    smooth(me)
    ob = new_obj(name, me, material)
    ob.location = center
    return ob


def ring_band(name, center_z, rx, ry, height, thick, e2=1.0, segs=64, material=None):
    """Closed tube band around the body (belt, waistband)."""
    bm = bmesh.new()
    loops = []
    for (dr, dz) in ((0, -height / 2), (thick, -height / 2), (thick, height / 2), (0, height / 2)):
        loop = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            x = _sp(math.cos(a), e2) * (rx + dr)
            y = _sp(math.sin(a), e2) * (ry + dr)
            loop.append(bm.verts.new((x, y, center_z + dz)))
        loops.append(loop)
    for li in range(4):
        a, b = loops[li], loops[(li + 1) % 4]
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    smooth(me)
    return new_obj(name, me, material)


def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return p0 * u ** 3 + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t ** 3


def tube_along(name, pts, width, thick, head_center, segs=12, sides=8,
               taper_pow=0.8, root_scale=1.0, material=None, flat_dir=None):
    """Tapered, flattened strand following a cubic bezier (hair, ahoge).
    Width lies across the scalp; thickness points away from head_center."""
    p0, p1, p2, p3 = [Vector(p) for p in pts]
    hc = Vector(head_center)
    bm = bmesh.new()
    rings = []
    samples = [bezier(p0, p1, p2, p3, i / segs) for i in range(segs + 1)]
    for i, pos in enumerate(samples):
        t = i / segs
        if i < segs:
            tan = (samples[i + 1] - pos).normalized()
        else:
            tan = (pos - samples[i - 1]).normalized()
        out = (pos - hc) if flat_dir is None else Vector(flat_dir)
        n = (out - tan * out.dot(tan)).normalized()
        side = tan.cross(n).normalized()
        prof = (1 - t) ** taper_pow
        # slightly fuller near the root, swelling a bit in the first third
        swell = 1.0 + 0.25 * math.sin(math.pi * min(t / 0.6, 1.0))
        w = width * 0.5 * prof * swell * (root_scale if t == 0 else 1.0)
        th = thick * 0.5 * prof * swell
        if i == segs:
            rings.append([bm.verts.new(pos)])
            continue
        ring = []
        for s in range(sides):
            a = 2 * math.pi * s / sides
            ring.append(bm.verts.new(pos + side * (math.cos(a) * w) + n * (math.sin(a) * th)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for s in range(sides):
            s2 = (s + 1) % sides
            if len(b) == 1:
                bm.faces.new((a[s], a[s2], b[0]))
            else:
                bm.faces.new((a[s], a[s2], b[s2], b[s]))
    bm.faces.new(list(reversed(rings[0])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    smooth(me)
    return new_obj(name, me, material)


def surface_hit(target, origin, direction):
    """Ray-cast onto an object in world space; returns (location, normal) or (None, None)."""
    mw = target.matrix_world
    inv = mw.inverted()
    o = inv @ Vector(origin)
    d = (inv.to_3x3() @ Vector(direction)).normalized()
    ok, loc, nor, _ = target.ray_cast(o, d, depsgraph=bpy.context.evaluated_depsgraph_get())
    if not ok:
        return None, None
    return mw @ loc, (mw.to_3x3().inverted().transposed() @ nor).normalized()


def align_to_normal(ob, loc, normal, up=Vector((0, 0, 1))):
    """Place ob at loc with its local -Y facing along the surface normal (like the character)."""
    fwd = Vector(normal).normalized()          # outward
    y = -fwd
    x = y.cross(up)
    if x.length < 1e-6:
        x = Vector((1, 0, 0))
    x.normalize()
    z = x.cross(y).normalized()
    m = Matrix((x, y, z)).transposed()
    ob.matrix_world = Matrix.Translation(loc) @ m.to_4x4()


def add_mod(ob, kind, **kw):
    m = ob.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m
