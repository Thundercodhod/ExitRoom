import bpy, math, os, statistics
from mathutils import Vector, Matrix

SRC = "/Users/saran/3d-game-project/assets_src/frog"
OUT_GLB = "/Users/saran/3d-game-project/assets/models/enemy/frog.glb"
OUT_BLEND = SRC + "/frog_rigged.blend"
TARGET_HEIGHT = float(os.environ.get("FROG_HEIGHT", "1.9"))
PREVIEW = os.environ.get("FROG_PREVIEW", "1") == "1"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=SRC + "/Meshy_AI_Character_Frog.glb")
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
mesh = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name == "Mesh_0")
for o in list(bpy.data.objects):
    if o.name == "Icosphere":
        bpy.data.objects.remove(o, do_unlink=True)

# ---------- readable bone names (the Meshy rig only has numbered bones) ----------
NAMES = {
    'Bone_000': 'Hips', 'Bone_001': 'Spine', 'Bone_004': 'Spine1', 'Bone_003': 'Spine2', 'Bone_002': 'Chest',
    'Bone_017': 'Neck', 'Bone_016': 'Head', 'Bone_015': 'Head_End',
    'Bone_027': 'R_Shoulder', 'Bone_026': 'R_UpperArm', 'Bone_025': 'R_LowerArm', 'Bone_024': 'R_Wrist', 'Bone_023': 'R_Hand',
    'Bone_041': 'R_F1_a', 'Bone_040': 'R_F1_b', 'Bone_039': 'R_F1_c',
    'Bone_049': 'R_F2_a', 'Bone_048': 'R_F2_b', 'Bone_047': 'R_F2_c', 'Bone_046': 'R_F2_d',
    'Bone_045': 'R_F3_a', 'Bone_044': 'R_F3_b', 'Bone_043': 'R_F3_c', 'Bone_042': 'R_F3_d',
    'Bone_022': 'L_Shoulder', 'Bone_021': 'L_UpperArm', 'Bone_020': 'L_LowerArm', 'Bone_019': 'L_Wrist', 'Bone_018': 'L_Hand',
    'Bone_030': 'L_F1_a', 'Bone_029': 'L_F1_b', 'Bone_028': 'L_F1_c',
    'Bone_038': 'L_F2_a', 'Bone_037': 'L_F2_b', 'Bone_036': 'L_F2_c', 'Bone_035': 'L_F2_d',
    'Bone_034': 'L_F3_a', 'Bone_033': 'L_F3_b', 'Bone_032': 'L_F3_c', 'Bone_031': 'L_F3_d',
    'Bone_009': 'R_UpLeg', 'Bone_008': 'R_Leg', 'Bone_007': 'R_Foot', 'Bone_006': 'R_Toe', 'Bone_005': 'R_Toe_End',
    'Bone_014': 'L_UpLeg', 'Bone_013': 'L_Leg', 'Bone_012': 'L_Foot', 'Bone_011': 'L_Toe', 'Bone_010': 'L_Toe_End',
}
for b in arm.data.bones:
    if b.name in NAMES: b.name = NAMES[b.name]
for g in mesh.vertex_groups:
    if g.name in NAMES: g.name = NAMES[g.name]
assert all(n in arm.data.bones for n in NAMES.values()), "bone rename failed"
assert all(g.name in arm.data.bones for g in mesh.vertex_groups), [g.name for g in mesh.vertex_groups if g.name not in arm.data.bones]

# ---------- scale to the target height (bones + mesh) ----------
cur_h = mesh.dimensions.z
S = TARGET_HEIGHT / cur_h
mesh.data.transform(Matrix.Scale(S, 4)); mesh.data.update()
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for eb in arm.data.edit_bones:
    h, t = eb.head.copy() * S, eb.tail.copy() * S
    eb.head = h; eb.tail = t
bpy.ops.object.mode_set(mode='OBJECT')
bpy.context.view_layer.update()
print("SCALE", round(S, 4), "height now", round(mesh.dimensions.z, 3))

# ---------- pose helpers ----------
bpy.context.preferences.edit.keyframe_new_interpolation_type = 'LINEAR'
bpy.ops.object.mode_set(mode='POSE')
pbs = arm.pose.bones
for pb in pbs: pb.rotation_mode = 'QUATERNION'
X = Vector((1, 0, 0)); Y = Vector((0, 1, 0)); Z = Vector((0, 0, 1))
deg = math.radians
def upd(): bpy.context.view_layer.update()
def rot(name, axis, ang):
    pb = pbs[name]; piv = pb.head.copy()
    pb.matrix = Matrix.Translation(piv) @ Matrix.Rotation(ang, 4, axis) @ Matrix.Translation(-piv) @ pb.matrix
    upd()
def flat(name):
    pb = pbs[name]
    pb.matrix = Matrix.Translation(pb.head.copy()) @ pb.bone.matrix_local.to_3x3().to_4x4()
    upd()
def reset():
    for pb in pbs:
        pb.location = (0, 0, 0); pb.rotation_quaternion = (1, 0, 0, 0)
    upd()
# Conventions (Blender space, the frog faces -Y, up is +Z):
#   rotation about +X by +a  : bends a body part that points up toward -Y (forward lean / nod),
#                              moves a hanging limb toward +Y (backwards).
def fwd(name, a): rot(name, X, -a)   # swing a hanging limb forward by a radians
def back(name, a): rot(name, X, a)   # bend a segment backwards (knee flex)
def lean(name, a): rot(name, X, a)   # lean a vertical chain forward
REST_ANKLE_Z = {}
for side in "LR":
    REST_ANKLE_Z[side] = pbs[side + "_Foot"].head.z

def pose(P):
    reset()
    # torso
    for name, key in (("Spine", "spine"), ("Spine1", "spine1"), ("Chest", "chest")):
        if P.get(key): lean(name, P[key])
    if P.get("twist"): rot("Chest", Z, P["twist"])
    if P.get("neck"): lean("Neck", P["neck"])
    if P.get("head"): lean("Head", P["head"])
    if P.get("head_yaw"): rot("Head", Z, P["head_yaw"])
    # arms
    for side in "LR":
        a = P.get(side + "_arm", 0.0); e = P.get(side + "_elbow", 0.0)
        if a: fwd(side + "_UpperArm", a)
        if e: fwd(side + "_LowerArm", e)
    # legs
    for side in "LR":
        f = P.get(side + "_thigh", 0.0); k = P.get(side + "_knee", 0.0)
        if f: fwd(side + "_UpLeg", f)
        if k: back(side + "_Leg", k)
        flat(side + "_Foot")
    # pin the pelvis so the lowest foot rests on the floor
    drop = min(pbs[s + "_Foot"].head.z - REST_ANKLE_Z[s] for s in "LR")
    dz = -drop + P.get("hips_dz", 0.0)
    hx = P.get("hips_dx", 0.0)
    if abs(dz) > 1e-6 or abs(hx) > 1e-6:
        pb = pbs["Hips"]; pb.matrix = Matrix.Translation(Vector((hx, 0, dz))) @ pb.matrix; upd()
def key_all(frame):
    for pb in pbs:
        pb.keyframe_insert("location", frame=frame, group=pb.name)
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=pb.name)

sin, cos, pi = math.sin, math.cos, math.pi
def idle(t):
    b = sin(2 * pi * t)
    return {"spine": deg(0.8) * b, "spine1": deg(0.8) * sin(2 * pi * t + 0.4), "chest": deg(1.2) * b,
            "head": deg(1.5) * sin(2 * pi * t + 1.0) + deg(2), "head_yaw": deg(3) * sin(2 * pi * t * 1 + 0.5),
            "neck": deg(1.0) * sin(2 * pi * t + 0.8), "twist": deg(1.2) * sin(2 * pi * t + 2.0),
            "L_arm": deg(1.5) * sin(2 * pi * t + 0.3), "R_arm": deg(1.5) * sin(2 * pi * t + 0.9),
            "L_elbow": deg(3) + deg(1.5) * b, "R_elbow": deg(3) + deg(1.5) * sin(2 * pi * t + 0.6),
            "L_knee": deg(2) + deg(1.0) * b, "R_knee": deg(2) + deg(1.0) * b,
            "L_thigh": deg(1.0) * b, "R_thigh": deg(1.0) * b}
def walk(t, A=deg(20), K=deg(38), swing_arm=deg(11)):
    P = {}
    for side, ph in (("L", 0.0), ("R", 0.5)):
        u = 2 * pi * (t + ph)
        P[side + "_thigh"] = A * sin(u)
        P[side + "_knee"] = deg(5) + K * max(0.0, cos(u)) ** 1.6
    # arms swing against the legs
    P["L_arm"] = -swing_arm * sin(2 * pi * (t + 0.5)); P["R_arm"] = -swing_arm * sin(2 * pi * t)
    P["L_elbow"] = deg(10) + deg(6) * max(0.0, -sin(2 * pi * (t + 0.5)))
    P["R_elbow"] = deg(10) + deg(6) * max(0.0, -sin(2 * pi * t))
    P["spine"] = deg(3); P["chest"] = deg(2) + deg(1) * sin(4 * pi * t)
    P["twist"] = deg(4) * sin(2 * pi * t)
    P["head"] = deg(-2) + deg(1) * sin(4 * pi * t)
    P["head_yaw"] = -deg(3) * sin(2 * pi * t)
    return P
def sit(t):
    b = sin(2 * pi * t)
    return {"L_thigh": deg(90), "R_thigh": deg(90), "L_knee": deg(90), "R_knee": deg(90),
            "spine": deg(-4) + deg(0.6) * b, "chest": deg(-3) + deg(1.0) * b, "head": deg(4) + deg(1.2) * sin(2 * pi * t + 1.0),
            "head_yaw": deg(2.5) * sin(2 * pi * t + 0.5),
            "L_arm": deg(14), "R_arm": deg(14), "L_elbow": deg(78), "R_elbow": deg(78)}

anims = {"idle-loop": (120, idle), "walk-loop": (36, walk), "sit-loop": (120, sit)}
arm.animation_data_create()
stats = {}
for name, (N, fn) in anims.items():
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    ank = []
    for i in range(N):
        pose(fn(i / N))
        key_all(i + 1)
        ank.append((pbs["L_Foot"].head.copy(), pbs["R_Foot"].head.copy(), pbs["Hips"].head.copy(), pbs["Head"].head.copy()))
    act.use_fake_user = True
    # planted-foot ground speed (stance frames only), per foot, in m/s
    sp = []
    for foot in (0, 1):
        zs = [a[foot].z for a in ank]; zmin = min(zs)
        for i in range(1, N):
            if zs[i] < zmin + 0.012 and zs[i - 1] < zmin + 0.012:
                sp.append(abs(ank[i][foot].y - ank[i - 1][foot].y) * 30.0)
    stats[name] = {"frames": N, "stance_speed": round(statistics.median(sp), 3) if sp else None,
                   "hips_z_range": [round(min(a[2].z for a in ank), 3), round(max(a[2].z for a in ank), 3)],
                   "head_z": round(statistics.mean(a[3].z for a in ank), 3)}
arm.animation_data.action = None
reset()
bpy.ops.object.mode_set(mode='OBJECT')

# ---------- previews ----------
def render(tag, action, frame, loc, target, w=640, h=640):
    sc = bpy.context.scene
    arm.animation_data.action = bpy.data.actions[action] if action else None
    sc.frame_set(frame)
    sc.render.engine = 'BLENDER_EEVEE'; sc.render.resolution_x = w; sc.render.resolution_y = h
    cam = bpy.data.objects.get("pcam")
    if cam is None:
        cam = bpy.data.objects.new("pcam", bpy.data.cameras.new("pcam")); sc.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (target - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sc.render.filepath = "/tmp/frog_prev_%s.png" % tag
    bpy.ops.render.render(write_still=True)
if PREVIEW:
    sc = bpy.context.scene
    world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (0.35, 0.35, 0.38, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", 'SUN')); sun.rotation_euler = (0.9, 0.1, 0.5); sun.data.energy = 3.5
    sc.collection.objects.link(sun)
    c = Vector((0, 0, 0.95))
    render("front", None, 1, (0, -4.2, 1.1), c)
    render("idle", "idle-loop", 30, (3.0, -3.4, 1.4), c)
    render("walk_a", "walk-loop", 5, (4.2, 0.0, 1.0), c)
    render("walk_b", "walk-loop", 23, (4.2, 0.0, 1.0), c)
    render("sit", "sit-loop", 30, (4.2, 0.0, 0.8), Vector((0, 0, 0.7)))
    arm.animation_data.action = None

# ---------- save + export ----------
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
for o in bpy.data.objects: o.select_set(o in (arm, mesh))
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', use_selection=True, export_yup=True,
    export_apply=False, export_animations=True, export_animation_mode='ACTIONS',
    export_force_sampling=True, export_frame_step=1, export_skins=True,
    export_image_format='AUTO', export_materials='EXPORT')
print("BUILD_OK", stats, "glb_bytes", os.path.getsize(OUT_GLB))
