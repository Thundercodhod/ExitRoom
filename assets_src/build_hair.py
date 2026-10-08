"""Hair for the M.6 student: scalp cap + tapered strand clumps + grey ahoge.
exec(open(PATH).read()); build_hair()
Angles: phi 0 = front (-Y), +phi toward character's left (+X). el = elevation on the head ellipsoid.
"""
exec(open("/Users/saran/3d-game-project/assets_src/gen_helpers.py").read())
import math
from mathutils import Vector

HC = Vector((0, -0.02, 0.94))       # head centre (matches build_body P["head"])
HR = Vector((0.27, 0.26, 0.235))    # head radii

# (name, phi_root, el_root, phi_tip, el_tip, width, thick, tip_flare)
STRANDS = [
    # fringe over the forehead (tips stay above the eyes)
    ("Fringe.1", -40, 58, -58, -18, 0.125, 0.045, 0.02),
    ("Fringe.2", -22, 62, -36, -8, 0.125, 0.045, 0.015),
    ("Fringe.3", -6, 64, -14, -4, 0.115, 0.045, 0.012),
    ("Fringe.4", 4, 66, 18, -10, 0.13, 0.05, 0.015),      # the big sweep toward the character's left
    ("Fringe.5", 20, 60, 40, -18, 0.13, 0.045, 0.02),
    ("Fringe.6", 38, 56, 58, -24, 0.12, 0.045, 0.025),
    # side locks down to the cheeks
    ("Side.R1", -70, 45, -80, -55, 0.11, 0.045, 0.012),
    ("Side.L1", 72, 45, 84, -52, 0.11, 0.045, 0.012),
    ("Side.R2", -95, 45, -104, -46, 0.14, 0.05, 0.03),
    ("Side.L2", 96, 45, 108, -42, 0.14, 0.05, 0.03),
    ("Side.R3", -58, 40, -72, -34, 0.10, 0.04, 0.035),
    ("Side.L3", 60, 40, 76, -30, 0.10, 0.04, 0.035),
    # back of the head down to the nape
    ("Back.1", 125, 60, 130, -48, 0.15, 0.05, 0.03),
    ("Back.2", 147, 62, 150, -50, 0.15, 0.05, 0.02),
    ("Back.3", 169, 64, 172, -52, 0.15, 0.05, 0.03),
    ("Back.4", 191, 64, 188, -52, 0.15, 0.05, 0.02),
    ("Back.5", 213, 62, 210, -50, 0.15, 0.05, 0.03),
    ("Back.6", 235, 60, 230, -48, 0.15, 0.05, 0.02),
    # crown tufts for volume / messy silhouette
    ("Crown.1", 0, 82, -10, 5, 0.13, 0.05, 0.015),
    ("Crown.2", 45, 82, 60, 0, 0.13, 0.05, 0.015),
    ("Crown.3", 90, 82, 100, -8, 0.14, 0.05, 0.015),
    ("Crown.4", 135, 82, 140, -12, 0.14, 0.05, 0.01),
    ("Crown.5", 180, 82, 180, -14, 0.14, 0.05, 0.01),
    ("Crown.6", 225, 82, 220, -12, 0.14, 0.05, 0.01),
    ("Crown.7", 270, 82, 262, -8, 0.14, 0.05, 0.015),
    ("Crown.8", 315, 82, 300, 0, 0.13, 0.05, 0.015),
]

AHOGE = [(0.0, 0.0, 1.16), (-0.03, -0.02, 1.31), (0.07, -0.01, 1.36), (0.10, 0.05, 1.28)]

WIDTH_K = 1.35      # chunkier locks
THICK_K = 1.35
CROWN_FLARE_K = 0.5
EXTRA_STRANDS = [
    # fill the sides behind the side locks
    ("Side.R4", -118, 50, -124, -46, 0.15, 0.05, 0.02),
    ("Side.L4", 118, 50, 126, -44, 0.15, 0.05, 0.02),
    ("Side.R5", -84, 50, -92, -40, 0.13, 0.05, 0.02),
    ("Side.L5", 84, 50, 94, -38, 0.13, 0.05, 0.02),
]


def surf(phi, el, out):
    p, e = math.radians(phi), math.radians(el)
    return HC + Vector(((HR.x + out) * math.cos(e) * math.sin(p),
                        -(HR.y + out) * math.cos(e) * math.cos(p),
                        (HR.z + out) * math.sin(e)))


def lerp(a, b, t):
    return a + (b - a) * t


def remove_prefix(prefixes):
    for ob in list(coll().objects):
        if any(ob.name == p or ob.name.startswith(p + ".") for p in prefixes):
            bpy.data.objects.remove(ob, do_unlink=True)


def build_cap(mat):
    cap = superellipsoid("HairCap", tuple(HC + Vector((0, 0.012, 0.012))), (0.29, 0.285, 0.248),
                         e1=0.95, e2=0.95, segs=40, rings=20, material=mat)
    me = cap.data
    bm = bmesh.new(); bm.from_mesh(me)
    off = cap.location
    def keep(co):
        w = co + off
        rel = w - HC
        front = rel.y < -0.08
        if front and w.z < 1.07:          # open face
            return False
        if w.z < 0.80 and rel.y < 0.05:   # sides stop at cheek level
            return False
        if w.z < 0.79:                    # nape
            return False
        return True
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co)], context='VERTS')
    bm.to_mesh(me); bm.free(); smooth(me)
    return cap


def build_hair():
    remove_prefix(["HairCap", "Hair", "Fringe", "Side", "Back", "Crown", "Ahoge"])
    hair_m = mat("M_Hair", "#3A241F", rough=0.5)
    curl_m = mat("M_HairCurl", "#9C9C9C", rough=0.55)
    build_cap(hair_m)
    for (name, p0, e0, p1, e1, w, th, flare) in STRANDS + EXTRA_STRANDS:
        if name.startswith("Crown"):
            flare *= CROWN_FLARE_K
        pts = [surf(p0, e0, 0.028),
               surf(lerp(p0, p1, 0.35), lerp(e0, e1, 0.35), 0.05),
               surf(lerp(p0, p1, 0.75), lerp(e0, e1, 0.75), 0.048),
               surf(p1, e1, 0.03 + flare)]
        tube_along(name, pts, w * WIDTH_K, th * THICK_K, HC, segs=14, sides=10, taper_pow=0.75, material=hair_m)
    tube_along("Ahoge", AHOGE, 0.07, 0.04, HC, segs=18, sides=10, taper_pow=0.85, material=curl_m,
               flat_dir=(0, -1, 0.2))
    bpy.ops.wm.save_mainfile()
