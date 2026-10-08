extends SceneTree
# Generates the player's idle, walk and run as ordinary Animation resources:
#   res://assets/models/player/player_idle.tres   (breathing, weight shift)
#   res://assets/models/player/player_walk.tres   (1.4 m/s)
#   res://assets/models/player/player_run.tres    (4.8 m/s)
#
# Run headless from the project folder:
#   godot --headless --path . --script res://tools/build_player_gait.gd
#
# How it works: the feet are planned first. During stance a foot is planted on
# the ground and moves backward under the body at exactly the ground speed
# (that is what stops sliding); heel strike pivots on the heel, toe-off pivots
# on the toe. In swing it arcs forward to the next contact. The hips bob, sway
# and twist; two-bone IK bends the legs to reach the feet; the spine counter-
# twists, the arms swing against the legs, and the head keeps a level gaze.
# The model comes in a T-pose with no animations, so everything starts from a
# relaxed standing pose built here (arms down, palms in, fingers loosely
# curled). Every bone is keyed, so the clips can be edited in Godot's
# Animation editor afterwards. Bone names are Godot's humanoid names (the
# import renames the rig with player_better_rig_bone_map.tres).
#
# Phase 0 = left heel contact, 0.5 = right heel contact (player.gd relies on
# both clips sharing this so it can blend them in step).
# Skeleton space of player_better_rig.glb: faces +Z, left is +X, ground at y = 0.
# Hip height is solved per clip ("hip_height": -1): the highest pelvis that
# keeps every leg within MAX_REACH of full extension through the whole cycle,
# so the planted foot never has to slide to stay reachable.

const MODEL := "res://assets/models/player/player_better_rig.glb"
const MAX_REACH := 0.98
const OUT_DIR := "res://assets/models/player/"
const FPS := 60.0   # the run push-off lasts ~0.07 s; fewer keys let the toe drift between them

const IDLE := {
	"name": "player_idle", "cycle": 4.0,
	"breath": 1.6, "shift": 0.014, "head_drift": 2.5,
}
const WALK := {
	"name": "player_walk", "speed": 1.4, "cycle": 0.96, "duty": 0.60,
	"hip_height": -1.0, "bob": 0.022, "bob_in_flight": false, "sway": 0.02,
	"pelvis_yaw": 7.0, "lean": 3.0, "lift": 0.10, "lift_peak": 0.5, "kick_back": 0.0,
	"contact_pitch": -16.0, "toe_off_pitch": 30.0, "foot_width": 1.0, "stance_shift": 0.0,
	"arm_swing": 18.0, "arm_out": 4.0, "elbow": 14.0, "elbow_swing": 12.0,
	"spine_twist": 1.15, "fist": 0.15,
}
const RUN := {
	"name": "player_run", "speed": 4.8, "cycle": 0.60, "duty": 0.27,
	"hip_height": -1.0, "bob": 0.03, "bob_in_flight": true, "sway": 0.008,
	"pelvis_yaw": 9.0, "lean": 16.0, "lift": 0.36, "lift_peak": 0.36, "kick_back": 0.16,
	"contact_pitch": -4.0, "toe_off_pitch": 46.0, "foot_width": 0.8, "stance_shift": -0.07,
	"arm_swing": 40.0, "arm_out": 7.0, "elbow": 88.0, "elbow_swing": 12.0,
	"spine_twist": 1.25, "fist": 0.8,
}
# Relaxed standing pose built from the T-pose.
const ARM_DOWN := 76.0        # degrees from horizontal
const ARM_FORWARD := 4.0
const ELBOW_REST := 10.0
const FINGER_CURL := 14.0     # per joint, relaxed hand
const FIST_CURL := 52.0       # per joint, closed hand (blended by "fist")

var skel: Skeleton3D
var track_root := ""            # node path prefix used by the glb's own clips
var idle_local := {}            # bone -> Transform3D (local pose, idle frame 0)
var idle_global := {}           # bone -> Transform3D
var local := {}                 # working pose
var bones := {}                 # name -> index
var heel_off := Vector3.ZERO    # from the ankle to the heel / toe, foot flat
var toe_off := {}
var ankle_flat_y := 0.0
var _last_ankle_goal := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model: Node3D = load(MODEL).instantiate()
	root.add_child(model)
	skel = model.find_child("Skeleton3D", true, false)
	# Clips are played by an AnimationPlayer whose root is the model's root.
	track_root = String(model.get_path_to(skel))
	await process_frame
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = i
		idle_local[i] = skel.get_bone_rest(i)
	_relax_pose()
	for i in skel.get_bone_count():
		idle_global[i] = _global_of(i, idle_local)
	for side in ["Left", "Right"]:
		var ankle: Vector3 = idle_global[bones[side + "Foot"]].origin
		toe_off[side] = idle_global[bones[side + "Toes"]].origin - ankle
	ankle_flat_y = (idle_global[bones["LeftFoot"]].origin.y + idle_global[bones["RightFoot"]].origin.y) * 0.5
	heel_off = Vector3(0, -(ankle_flat_y - 0.03), -0.05)   # heel just above the ground, behind the ankle
	var idle_anim := _build_idle(IDLE)
	print("GAIT saved %s (%.2f s, %d tracks) err=%d" % [OUT_DIR + IDLE.name + ".tres", idle_anim.length, idle_anim.get_track_count(), ResourceSaver.save(idle_anim, OUT_DIR + IDLE.name + ".tres")])
	for base_cfg in [WALK, RUN]:
		var cfg: Dictionary = base_cfg.duplicate()
		if cfg.hip_height < 0.0:
			cfg.hip_height = _solve_hip_height(cfg)
		var anim := _build(cfg)
		print("GAIT %s hip height %.3f, max leg reach %.3f of %.3f" % [cfg.name, cfg.hip_height, _max_reach(cfg), _leg_length("Left")])
		var path: String = OUT_DIR + cfg.name + ".tres"
		var err := ResourceSaver.save(anim, path)
		print("GAIT saved %s (%.2f s, %d tracks) err=%d" % [path, anim.length, anim.get_track_count(), err])
	quit()


func _build(cfg: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = cfg.cycle
	anim.loop_mode = Animation.LOOP_LINEAR
	anim.set_meta("ground_speed", cfg.speed)
	anim.set_meta("stride", cfg.speed * cfg.cycle)     # metres travelled per cycle
	var rot_tracks := {}
	for name in bones:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [track_root, name]))
		rot_tracks[bones[name]] = t
	var hips_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_pos, NodePath("%s:Hips" % track_root))
	var frames := int(round(cfg.cycle * FPS))
	for f in frames + 1:
		var p := float(f) / frames
		_pose(cfg, fposmod(p, 1.0))
		var time: float = cfg.cycle * p
		for b in rot_tracks:
			anim.rotation_track_insert_key(rot_tracks[b], time, local[b].basis.get_rotation_quaternion())
		anim.position_track_insert_key(hips_pos, time, local[bones["Hips"]].origin)
	return anim


# ------------------------------------------------------------------- the pose

func _pose(cfg: Dictionary, p: float) -> void:
	local = idle_local.duplicate()
	var tau := TAU
	# Pelvis: height, sideways sway over the stance foot, twist toward the leading leg.
	var hips: int = bones["Hips"]
	var h: float = cfg.hip_height
	if cfg.bob_in_flight:   # running: lowest at mid-stance, highest in flight
		h -= cfg.bob * cos(2.0 * tau * (p - cfg.duty * 0.5))
	else:                   # walking: highest at mid-stance, lowest at double support
		h += cfg.bob * cos(2.0 * tau * (p - cfg.duty * 0.5))
	var sway: float = cfg.sway * cos(tau * (p - cfg.duty * 0.5))
	var yaw := deg_to_rad(-cfg.pelvis_yaw) * cos(tau * p)          # left hip forward at left contact
	var hips_basis: Basis = Basis(Quaternion(Vector3.UP, yaw)) * idle_global[hips].basis
	local[hips] = Transform3D(hips_basis, Vector3(idle_global[hips].origin.x + sway, h, idle_global[hips].origin.z))

	# Spine: lean forward (running) and counter-twist so the shoulders face ahead.
	var lean_q := Quaternion(Vector3.RIGHT, deg_to_rad(cfg.lean))
	var twist_q := Quaternion(Vector3.UP, -yaw * cfg.spine_twist)
	# Legs hang off "Spine" in this rig, so the upper body bends from the bone above it.
	_rotate_global(bones["Bone_004"], lean_q * twist_q, 1.0)

	# Legs.
	for side in ["Left", "Right"]:
		var phase := fposmod(p - (0.0 if side == "Left" else 0.5), 1.0)
		_leg(cfg, side, phase)

	# Arms swing against the legs; elbows bend more on the forward swing.
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		var c := cos(tau * p) * s                     # +1: this arm is fully back
		var swing := deg_to_rad(cfg.arm_swing) * c
		var out := deg_to_rad(cfg.arm_out) * s
		var arm: int = bones[side + "UpperArm"]
		_rotate_global(arm, Quaternion(Vector3.FORWARD, -out) * Quaternion(Vector3.RIGHT, swing), 1.0)
		var bend := deg_to_rad(cfg.elbow - ELBOW_REST + cfg.elbow_swing * maxf(-c, 0.0))
		_rotate_global(bones[side + "LowerArm"], Quaternion(Vector3.RIGHT, -bend), 1.0)
		_curl_fingers(side, deg_to_rad(FIST_CURL - FINGER_CURL) * cfg.fist)

	# Head: keep the idle gaze (level, facing ahead) whatever the body does.
	var head: int = bones["Head"]
	_set_global_basis(head, idle_global[head].basis)


func _leg(cfg: Dictionary, side: String, phase: float) -> void:
	var up: int = bones[side + "UpperLeg"]
	var knee: int = bones[side + "LowerLeg"]
	var foot: int = bones[side + "Foot"]
	var ankle_idle: Vector3 = idle_global[foot].origin
	# stance_shift < 0: land closer under the body, push off further behind.
	var cz: float = ankle_idle.z + cfg.stance_shift
	var x := lerpf(0.0, ankle_idle.x, cfg.foot_width)
	var reach: float = cfg.speed * cfg.cycle * cfg.duty      # distance the planted foot travels
	var duty: float = cfg.duty
	var ankle: Vector3
	var pitch: float
	if phase < duty:
		# Stance: the planted point slides back under the body at ground speed.
		var s := phase / duty
		var z := cz + reach * 0.5 - reach * s
		var flat := Vector3(x, ankle_flat_y, z)
		pitch = _stance_pitch(cfg, s)
		ankle = _pivot(flat, pitch, side)
	else:
		# Swing: from the toe-off pose to the next contact pose.
		var s := (phase - duty) / (1.0 - duty)
		var start := _pivot(Vector3(x, ankle_flat_y, cz - reach * 0.5), deg_to_rad(cfg.toe_off_pitch), side)
		var end := _pivot(Vector3(x, ankle_flat_y, cz + reach * 0.5), deg_to_rad(cfg.contact_pitch), side)
		var zs := _smoother(pow(s, 1.0 + cfg.kick_back * 3.0))
		ankle = Vector3(x, lerpf(start.y, end.y, s), lerpf(start.z, end.z, zs))
		var lift_s: float = clampf(s / (2.0 * cfg.lift_peak), 0.0, 1.0) if s < cfg.lift_peak else 0.5 + 0.5 * (s - cfg.lift_peak) / (1.0 - cfg.lift_peak)
		ankle.y += cfg.lift * sin(PI * lift_s)
		ankle.z -= cfg.kick_back * sin(PI * s) * (1.0 - s)
		pitch = lerpf(deg_to_rad(cfg.toe_off_pitch), deg_to_rad(cfg.contact_pitch), _smoother(s))
	_last_ankle_goal[side] = ankle
	_two_bone_ik(up, knee, foot, ankle)
	_set_global_basis(foot, Basis(Quaternion(Vector3.RIGHT, pitch)) * idle_global[foot].basis)


# Heel strike -> flat -> rising onto the toe.
func _stance_pitch(cfg: Dictionary, s: float) -> float:
	var contact := deg_to_rad(cfg.contact_pitch)
	var off := deg_to_rad(cfg.toe_off_pitch)
	if s < 0.18:
		return lerpf(contact, 0.0, _smoother(s / 0.18))
	if s < 0.55:
		return 0.0
	return lerpf(0.0, off, _smoother((s - 0.55) / 0.45))


# Ankle position for a foot whose flat-footed ankle would be at `flat`, pitched
# by `pitch`: toes-up pivots on the heel, heel-up pivots on the toe, so the part
# touching the ground stays where it is.
func _pivot(flat: Vector3, pitch: float, side: String) -> Vector3:
	var q := Quaternion(Vector3.RIGHT, pitch)
	var off: Vector3 = heel_off if pitch < 0.0 else toe_off[side]
	return flat + off - q * off


func _two_bone_ik(up: int, knee: int, foot: int, goal: Vector3) -> void:
	var hip := _global_of(up, local).origin
	var k := _global_of(knee, local).origin
	var a := _global_of(foot, local).origin
	var len_a := hip.distance_to(k)
	var len_b := k.distance_to(a)
	var to_goal := goal - hip
	var dist := clampf(to_goal.length(), 0.05, (len_a + len_b) * 0.999)
	var dir := to_goal.normalized()
	var cos_a := clampf((len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist), -1.0, 1.0)
	var pole := Vector3(0.08 * signf(hip.x), 0.0, 1.0)     # knees forward, a touch outward
	var bend := (pole - dir * pole.dot(dir)).normalized()
	var knee_goal := hip + dir * (len_a * cos_a) + bend * (len_a * sqrt(1.0 - cos_a * cos_a))
	_rotate_global(up, Quaternion((k - hip).normalized(), (knee_goal - hip).normalized()), 1.0)
	var k2 := _global_of(knee, local).origin
	var a2 := _global_of(foot, local).origin
	_rotate_global(knee, Quaternion((a2 - k2).normalized(), (hip + dir * dist - k2).normalized()), 1.0)


# ------------------------------------------------------------------- pose maths

func _global_of(bone: int, pose: Dictionary) -> Transform3D:
	var parent := skel.get_bone_parent(bone)
	if parent < 0:
		return pose[bone]
	return _global_of(parent, pose) * pose[bone]


# Rotate a bone (and everything below it) by `q` in skeleton space, about its own origin.
func _rotate_global(bone: int, q: Quaternion, weight: float) -> void:
	var g := _global_of(bone, local)
	_set_global_basis(bone, Basis(Quaternion.IDENTITY.slerp(q, weight)) * g.basis)


func _set_global_basis(bone: int, basis: Basis) -> void:
	var parent := skel.get_bone_parent(bone)
	var parent_basis := _global_of(parent, local).basis if parent >= 0 else Basis.IDENTITY
	var lt: Transform3D = local[bone]
	local[bone] = Transform3D((parent_basis.inverse() * basis).orthonormalized(), lt.origin)


func _smoother(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


# ------------------------------------------------------------------- base pose

# T-pose -> relaxed stand: fingers loosely curled, arms down with palms facing
# the thighs, elbows soft. Fingers first, so the arm rotations carry them.
func _relax_pose() -> void:
	local = idle_local
	for side in ["Left", "Right"]:
		_curl_fingers(side, deg_to_rad(FINGER_CURL))
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		var down := Quaternion(Vector3.BACK, -deg_to_rad(ARM_DOWN) * s)
		var fwd := Quaternion(Vector3.RIGHT, -deg_to_rad(ARM_FORWARD))
		_rotate_global(bones[side + "UpperArm"], fwd * down, 1.0)
		_rotate_global(bones[side + "LowerArm"], Quaternion(Vector3.RIGHT, -deg_to_rad(ELBOW_REST)), 1.0)
	idle_local = local


# Bends every finger joint toward the palm by `angle`. In the T-pose the palms
# face down, so each joint turns about (its direction x down); after the arms
# come down the same rotation still curls toward the palm.
func _curl_fingers(side: String, angle: float) -> void:
	if absf(angle) < 0.0001:
		return
	var palm := Vector3.DOWN
	for name in bones:
		if not (name.begins_with(side) and (name.contains("Index") or name.contains("Middle") or name.contains("Ring") or name.contains("Little") or name.contains("Thumb"))):
			continue
		var b: int = bones[name]
		var kids := skel.get_bone_children(b)
		if kids.is_empty():
			continue
		var g := _global_of(b, local)
		var tip := _global_of(kids[0], local).origin
		var dir := (tip - g.origin).normalized()
		var p := palm
		if name.contains("Thumb"):
			# The thumb folds across toward the index finger instead.
			p = (Vector3.LEFT if side == "Left" else Vector3.RIGHT) + Vector3.DOWN * 0.3
		var axis := dir.cross(p)
		if axis.length() < 0.01:
			continue
		var a := angle * (0.6 if name.contains("Thumb") else 1.0)
		_rotate_global(b, Quaternion(axis.normalized(), a), 1.0)


# ------------------------------------------------------------------- idle

# Breathing (chest and shoulders rise, ~4 breaths per loop), a slow weight
# shift from foot to foot with the feet planted (leg IK), a slight head drift.
func _build_idle(cfg: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = cfg.cycle
	anim.loop_mode = Animation.LOOP_LINEAR
	var rot_tracks := {}
	for name in bones:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [track_root, name]))
		rot_tracks[bones[name]] = t
	var hips_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(hips_pos, NodePath("%s:Hips" % track_root))
	var frames := int(round(cfg.cycle * 30.0))
	for f in frames + 1:
		var p := float(f) / frames
		local = idle_local.duplicate()
		var hips: int = bones["Hips"]
		var hg: Transform3D = idle_global[hips]
		var breath := sin(TAU * p * 4.0)            # 4 breaths per loop (~15 / min)
		var shift := sin(TAU * p)                   # one slow sway per loop
		var dip := 0.006 * (1.0 - cos(TAU * p * 2.0)) * 0.5
		local[hips] = Transform3D(Basis(Quaternion(Vector3.BACK, -0.012 * shift)) * hg.basis, hg.origin + Vector3(cfg.shift * shift, -0.012 - dip, 0.0))
		_rotate_global(bones["UpperChest"], Quaternion(Vector3.RIGHT, -deg_to_rad(cfg.breath) * 0.5 * (breath + 1.0)), 1.0)
		for side in ["Left", "Right"]:
			var s := 1.0 if side == "Left" else -1.0
			_rotate_global(bones[side + "Shoulder"], Quaternion(Vector3.BACK, deg_to_rad(1.2) * s * 0.5 * (breath + 1.0)), 1.0)
			# Feet stay where they stand.
			var foot: int = bones[side + "Foot"]
			_two_bone_ik(bones[side + "UpperLeg"], bones[side + "LowerLeg"], foot, idle_global[foot].origin)
			_set_global_basis(foot, idle_global[foot].basis)
		var head: int = bones["Head"]
		var drift := Quaternion(Vector3.UP, deg_to_rad(cfg.head_drift) * sin(TAU * p + 0.8)) * Quaternion(Vector3.RIGHT, deg_to_rad(cfg.head_drift) * 0.3 * sin(TAU * p * 2.0))
		_set_global_basis(head, Basis(drift) * idle_global[head].basis)
		var time: float = cfg.cycle * p
		for b in rot_tracks:
			anim.rotation_track_insert_key(rot_tracks[b], time, local[b].basis.get_rotation_quaternion())
		anim.position_track_insert_key(hips_pos, time, local[hips].origin)
	return anim


# ------------------------------------------------------------------- hip height

func _leg_length(side: String) -> float:
	var a: Vector3 = idle_global[bones[side + "UpperLeg"]].origin
	var b: Vector3 = idle_global[bones[side + "LowerLeg"]].origin
	var c: Vector3 = idle_global[bones[side + "Foot"]].origin
	return a.distance_to(b) + b.distance_to(c)


# Largest hip-to-ankle distance the cycle asks for (before IK clamps it).
func _max_reach(cfg: Dictionary) -> float:
	var worst := 0.0
	for f in 120:
		var p := f / 120.0
		_pose(cfg, p)
		for side in ["Left", "Right"]:
			var hip := _global_of(bones[side + "UpperLeg"], local).origin
			worst = maxf(worst, hip.distance_to(_last_ankle_goal[side]))
	return worst


func _solve_hip_height(cfg: Dictionary) -> float:
	var lo := 0.5
	var hi: float = idle_global[bones["Hips"]].origin.y
	var limit := _leg_length("Left") * MAX_REACH
	for i in 24:
		var mid := (lo + hi) * 0.5
		cfg.hip_height = mid
		if _max_reach(cfg) > limit:
			hi = mid
		else:
			lo = mid
	return lo
