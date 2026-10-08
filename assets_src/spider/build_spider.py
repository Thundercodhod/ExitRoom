import bpy, bmesh, math, os, sys, statistics
from mathutils import Vector, Matrix

SRC = "/Users/saran/3d-game-project/assets_src/spider"
OUT_GLB = "/Users/saran/3d-game-project/assets/models/enemy/spider.glb"
OUT_BLEND = SRC + "/spider_rigged.blend"
SCALE = float(os.environ.get("SPIDER_SCALE", "0.5"))
K = SCALE / 0.5
PREVIEW = os.environ.get("SPIDER_PREVIEW", "1") == "1"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=SRC + "/Spider(no-rigged).fbx")
sp = bpy.data.objects["Spider"]; ey = bpy.data.objects["Eyes"]
bpy.context.scene.render.fps = 30
for o in (sp, ey):
    o.data.transform(Matrix.Scale(SCALE, 4) @ o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    o.data.update()

# ---------- materials ----------
img = bpy.data.images.load(SRC + "/Spider_1.png"); img.pack()
nt = bpy.data.materials["Spider_1"].node_tree
for n in list(nt.nodes):
    if n.type in ('NORMAL_MAP', 'TEX_IMAGE'): nt.nodes.remove(n)
tex = nt.nodes.new('ShaderNodeTexImage'); tex.image = img
b = nt.nodes["Principled BSDF"]
nt.links.new(tex.outputs['Color'], b.inputs['Base Color'])
b.inputs['Roughness'].default_value = 0.85; b.inputs['Metallic'].default_value = 0.0
nte = bpy.data.materials["Eyes"].node_tree
for n in list(nte.nodes):
    if n.type == 'NORMAL_MAP': nte.nodes.remove(n)
eb = nte.nodes["Principled BSDF"]
eb.inputs['Base Color'].default_value = (0.8, 0.02, 0.02, 1)
eb.inputs['Emission Color'].default_value = (1, 0.05, 0.05, 1)
eb.inputs['Emission Strength'].default_value = 3.0
eb.inputs['Roughness'].default_value = 0.3
sp.name = "SpiderMesh"; ey.name = "SpiderEyes"

# ---------- segment legs (connected pieces outside the body core) ----------
bm = bmesh.new(); bm.from_mesh(sp.data); bm.verts.ensure_lookup_table()
C = Vector((0.0, 0.2 * SCALE, 0.0)); R = 0.6 * SCALE
def rad(p): return math.hypot(p.x - C.x, p.y - C.y)
keep = {v.index for v in bm.verts if rad(v.co) >= R}
seen = set(); comps = []
for vi in keep:
    if vi in seen: continue
    st = [vi]; seen.add(vi); comp = []
    while st:
        c = st.pop(); comp.append(c)
        for e in bm.verts[c].link_edges:
            w = e.other_vert(bm.verts[c]).index
            if w in keep and w not in seen: seen.add(w); st.append(w)
    comps.append(comp)
legs = []
for c in comps:
    if len(c) < 70: continue
    pts = [bm.verts[i].co.copy() for i in c]
    legs.append({"verts": c, "cen": sum(pts, Vector()) / len(pts)})
assert len(legs) == 8, [len(c) for c in comps]
for side, sign in (("R", 1), ("L", -1)):
    group = sorted([l for l in legs if l["cen"].x * sign > 0], key=lambda l: -l["cen"].y)
    for i, l in enumerate(group): l["name"] = "%s%d" % (side, i + 1)
for l in legs:
    pts = [(i, bm.verts[i].co.copy()) for i in l["verts"]]
    ds = [rad(p) for _, p in pts]; d0, d1 = min(ds), max(ds)
    nb = 8; bins = [[] for _ in range(nb)]
    for (i, p), d in zip(pts, ds):
        bins[min(nb - 1, int((d - d0) / (d1 - d0 + 1e-9) * nb))].append(p)
    cl = [sum(b_, Vector()) / len(b_) for b_ in bins if b_]
    u = Vector((cl[0].x - C.x, cl[0].y - C.y, 0)).normalized()
    hip = cl[0].copy() - u * 0.14 * K
    tip = max((p for _, p in pts), key=lambda p: rad(p))
    mid = cl[1:-1] if len(cl) > 3 else cl
    knee = max(mid, key=lambda p: p.z).copy()
    l.update(hip=hip, knee=knee, tip=tip, u=u)

# ---------- armature ----------
arm_data = bpy.data.armatures.new("SpiderArmature")
arm = bpy.data.objects.new("SpiderArmature", arm_data)
bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
eds = arm_data.edit_bones
body = eds.new("Body"); body.head = Vector((0, 0.0, 0.22 * K)); body.tail = Vector((0, 0.22 * K, 0.22 * K))
for l in legs:
    up = eds.new(l["name"] + "_Upper"); up.head = l["hip"]; up.tail = l["knee"]; up.parent = body
    lo = eds.new(l["name"] + "_Lower"); lo.head = l["knee"]; lo.tail = l["tip"]; lo.parent = up
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- weights ----------
def sstep(a, b_, x):
    t = max(0.0, min(1.0, (x - a) / (b_ - a))); return t * t * (3 - 2 * t)
vg_body = sp.vertex_groups.new(name="Body"); vgs = {}
for l in legs:
    for part in ("Upper", "Lower"):
        vgs[l["name"] + "_" + part] = sp.vertex_groups.new(name=l["name"] + "_" + part)
leg_of = {}
for l in legs:
    for i in l["verts"]: leg_of[i] = l
for v in sp.data.vertices:
    l = leg_of.get(v.index)
    if not l:
        vg_body.add([v.index], 1.0, 'REPLACE'); continue
    p = v.co; d = rad(p)
    w_leg = sstep(R, R + 0.18 * K, d)
    ldir = (l["tip"] - l["knee"]).normalized()
    w_low = sstep(-0.05 * K, 0.05 * K, (p - l["knee"]).dot(ldir))
    wb = 1.0 - w_leg; wu = w_leg * (1 - w_low); wl = w_leg * w_low
    if wb > 0.001: vg_body.add([v.index], wb, 'REPLACE')
    if wu > 0.001: vgs[l["name"] + "_Upper"].add([v.index], wu, 'REPLACE')
    if wl > 0.001: vgs[l["name"] + "_Lower"].add([v.index], wl, 'REPLACE')
eg = ey.vertex_groups.new(name="Body"); eg.add(list(range(len(ey.data.vertices))), 1.0, 'REPLACE')
for o in (sp, ey):
    o.parent = arm
    m = o.modifiers.new("Armature", 'ARMATURE'); m.object = arm

# ---------- animation helpers ----------
bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')
pbs = arm.pose.bones
for pb in pbs: pb.rotation_mode = 'QUATERNION'
Z = Vector((0, 0, 1)); X = Vector((1, 0, 0)); Y = Vector((0, 1, 0))
def upd(): bpy.context.view_layer.update()
def rot_about(pb, pivot, axis, ang):
    M = Matrix.Translation(pivot) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-pivot)
    pb.matrix = M @ pb.matrix
def reset():
    for pb in pbs:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
    upd()
legnames = sorted(l["name"] for l in legs)
legu = {l["name"]: l["u"] for l in legs}
legfwd = {n: (1.0 if Z.cross(legu[n]).y > 0 else -1.0) for n in legnames}
BODY_PIVOT = Vector((0, 0.1 * K, 0.25 * K))
def pose(bodyp, legp):
    """bodyp: dict(dz,dy,pitch,roll); legp: name -> (swing, lift, flex) in radians (swing forward positive)"""
    reset()
    bp = pbs["Body"]
    rot_about(bp, BODY_PIVOT, X, bodyp.get("pitch", 0.0)); upd()
    rot_about(bp, BODY_PIVOT, Y, bodyp.get("roll", 0.0)); upd()
    bp.matrix = Matrix.Translation(Vector((0, bodyp.get("dy", 0.0), bodyp.get("dz", 0.0)))) @ bp.matrix; upd()
    for n in legnames:
        sw, li, fl = legp.get(n, (0.0, 0.0, 0.0))
        up = pbs[n + "_Upper"]; lo = pbs[n + "_Lower"]
        if abs(sw) > 1e-6:
            rot_about(up, up.head.copy(), Z, legfwd[n] * sw); upd()
        d = Vector((up.tail.x - up.head.x, up.tail.y - up.head.y, 0.0))
        axis = d.normalized().cross(Z).normalized() if d.length > 1e-6 else X
        if abs(li) > 1e-6:
            rot_about(up, up.head.copy(), axis, li); upd()
        if abs(fl) > 1e-6:
            d = Vector((lo.tail.x - lo.head.x, lo.tail.y - lo.head.y, 0.0))
            axis = d.normalized().cross(Z).normalized() if d.length > 1e-6 else axis
            rot_about(lo, lo.head.copy(), axis, fl); upd()
def key(frame):
    for pb in pbs:
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)
def smooth(a, b_, x): return sstep(a, b_, x)
deg = math.radians
GROUP_A = {"R1", "L2", "R3", "L4"}
FRONT = {"R1", "L1"}
def gait(t, A, L, F, bob, pitch=0.0, front_scale=0.6):
    legp = {}
    for n in legnames:
        ph = 0.0 if n in GROUP_A else 0.5
        tp = (t + ph) % 1.0
        sc = front_scale if n in FRONT else 1.0
        if tp < 0.5:
            s = A * (1 - 2 * (tp / 0.5)); li = 0.0; fl = 0.0
        else:
            q = (tp - 0.5) / 0.5
            s = -A + 2 * A * q; li = L * math.sin(math.pi * q); fl = F * math.sin(math.pi * q)
        legp[n] = (s * sc, li, fl)
    return {"dz": bob * math.sin(2 * math.pi * t * 2), "pitch": pitch}, legp
def idle(t):
    legp = {}
    for i, n in enumerate(legnames):
        legp[n] = (0.0, deg(2.5) * math.sin(2 * math.pi * (t + i * 0.125)), deg(3) * math.sin(2 * math.pi * (t + i * 0.125 + 0.25)))
    for n in FRONT:
        legp[n] = (deg(2) * math.sin(2 * math.pi * t), deg(9) * math.sin(2 * math.pi * (t + 0.1)), deg(6) * math.sin(2 * math.pi * (t + 0.35)))
    return {"dz": 0.006 * math.sin(2 * math.pi * t), "pitch": deg(1.2) * math.sin(2 * math.pi * (t + 0.2))}, legp
def attack(u):
    if u < 0.35: a = smooth(0, 0.35, u)
    elif u < 0.45: a = 1.0
    elif u < 0.58: a = 1.0 - 1.35 * smooth(0.45, 0.58, u)
    else: a = -0.35 * (1 - smooth(0.58, 1.0, u))
    pitch = a * (deg(26) if a > 0 else deg(22))
    legp = {}
    for n in legnames:
        idx = int(n[1])
        if idx == 1:   legp[n] = (a * deg(22), a * deg(62), a * deg(25))
        elif idx == 2: legp[n] = (a * deg(10), a * deg(28), a * deg(12))
        elif idx == 3: legp[n] = (-a * deg(4), -a * deg(3), 0.0)
        else:          legp[n] = (-a * deg(6), -a * deg(4), 0.0)
    dz = max(a, 0) * 0.05 + min(a, 0) * 0.03
    dy = -min(a, 0) * 0.16
    return {"dz": dz, "pitch": pitch, "dy": dy}, legp

anims = {
    "idle-loop": (96, lambda i, N: idle(i / N)),
    "walk-loop": (36, lambda i, N: gait(i / N, deg(15), deg(18), deg(24), 0.006)),
    "run-loop": (16, lambda i, N: gait(i / N, deg(22), deg(24), deg(34), 0.010, pitch=deg(-3))),
    "attack": (30, lambda i, N: attack(i / (N - 1))),
}
arm.animation_data_create()
tip_speed = {}
for name, (N, fn) in anims.items():
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    tips = []
    for i in range(N):
        bp, lp = fn(i, N)
        pose(bp, lp)
        key(i + 1)
        tips.append(pbs["R3_Lower"].tail.copy() - pbs["Body"].head.copy())
    act.use_fake_user = True
    # planted-foot ground speed (stance frames only): tip-to-body distance change per second
    zs = [t.z for t in tips]; zmin = min(zs)
    sp_list = []
    for i in range(1, N):
        if zs[i] < zmin + 0.01 and zs[i - 1] < zmin + 0.01:
            sp_list.append((tips[i] - tips[i - 1]).length * 30.0)
    tip_speed[name] = round(statistics.median(sp_list), 3) if sp_list else None
arm.animation_data.action = None
reset()
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- preview renders ----------
def render(tag, action, frame, loc, target, w=640, h=480):
    arm.animation_data.action = bpy.data.actions[action]
    bpy.context.scene.frame_set(frame)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = w; sc.render.resolution_y = h
    cam = bpy.data.objects.get("pcam")
    if cam is None:
        cam = bpy.data.objects.new("pcam", bpy.data.cameras.new("pcam")); sc.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (target - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.filepath = "/tmp/spider_prev_%s.png" % tag
    bpy.ops.render.render(write_still=True)
if PREVIEW:
    sc = bpy.context.scene
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.25, 0.25, 0.28, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); sun.rotation_euler = (0.8, 0.2, 0.6); sun.data.energy = 4
    sc.collection.objects.link(sun)
    T0 = Vector((0, 0.1, 0.25))
    render("rest_top", "idle-loop", 1, (0, 0.01, 4.2), Vector((0, 0.15, 0)))
    render("walk_a", "walk-loop", 9, (2.6, -2.6, 1.9), T0)
    render("walk_b", "walk-loop", 27, (2.6, -2.6, 1.9), T0)
    render("run_top", "run-loop", 5, (0, 0.01, 4.2), Vector((0, 0.15, 0)))
    render("attack", "attack", 14, (2.8, -2.2, 1.4), T0)
    arm.animation_data.action = None

# ---------- save + export ----------
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
for o in bpy.data.objects: o.select_set(o in (arm, sp, ey))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_yup=True,
    export_apply=False, export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_skins=True,
    export_image_format='AUTO', export_materials='EXPORT')
print("BUILD_OK legs", legnames, "tip_speed", tip_speed, "glb_bytes", os.path.getsize(OUT_GLB))
