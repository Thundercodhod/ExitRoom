extends SceneTree
# Generates the player's walk and run cycles as ordinary Animation resources:
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
# Everything starts from frame 0 of the model's idle clip and is keyed per
# bone, so the result can be edited in Godot's Animation editor afterwards.
#
# Phase 0 = left heel contact, 0.5 = right heel contact (player.gd relies on
# both clips sharing this so it can blend them in step).
# Skeleton space of main_character.glb: faces +Z, left is +X, ground at y = 0.
# Legs are short (thigh 0.35 m + shin 0.38 m), so the cycles are quick and
# the hip heights are chosen to keep the leg within reach at heel strike.

const MODEL := "res://assets/models/player/main_character.glb"
const OUT_DIR := "res://assets/models/player/"
const FPS := 60.0   # the run push-off lasts ~0.07 s; fewer keys let the toe drift between them

const WALK := {
	"name": "player_walk", "speed": 1.4, "cycle": 0.70, "duty": 0.58,
	"hip_height": 0.885, "bob": 0.025, "bob_in_flight": false, "sway": 0.018,
	"pelvis_yaw": 6.0, "lean": 3.0, "lift": 0.09, "lift_peak": 0.5, "kick_back": 0.0,
	"contact_pitch": -14.0, "toe_off_pitch": 32.0, "foot_width": 1.0, "stance_shift": 0.0,
	"arm_swing": 21.0, "arm_out": 6.0, "elbow": 12.0, "elbow_swing": 10.0,
	"spine_twist": 1.15,
}
const RUN := {
	"name": "player_run", "speed": 4.8, "cycle": 0.54, "duty": 0.28,
	"hip_height": 0.82, "bob": 0.03, "bob_in_flight": true, "sway": 0.008,
	"pelvis_yaw": 9.0, "lean": 18.0, "lift": 0.34, "lift_peak": 0.36, "kick_back": 0.22,
	"contact_pitch": -4.0, "toe_off_pitch": 46.0, "foot_width": 0.8, "stance_shift": -0.06,
	"arm_swing": 38.0, "arm_out": 9.0, "elbow": 88.0, "elbow_swing": 12.0,
	"spine_twist": 1.25,
}

var skel: Skeleton3D
var track_root := ""            # node path prefix used by the glb's own clips
var idle_local := {}            # bone -> Transform3D (local pose, idle frame 0)
var idle_global := {}           # bone -> Transform3D
var local := {}                 # working pose
var bones := {}                 # name -> index
var heel_off := Vector3.ZERO    # from the ankle to the heel / toe, foot flat
var toe_off := {}
var ankle_flat_y := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model: Node3D = load(MODEL).instantiate()
	root.add_child(model)
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	skel = model.find_child("Skeleton3D", true, false)
	track_root = String(ap.get_node(ap.root_node).get_path_to(skel))
	var idle := ""
	for c in ap.get_animation_list():
		if String(c).begins_with("idle"):
			idle = c
	ap.play(idle)
	ap.seek(0.0, true)
	ap.pause()
	await process_frame
	for i in skel.get_bone_count():
		bones[skel.get_bone_name(i)] = i
		idle_local[i] = skel.get_bone_pose(i)
	for i in skel.get_bone_count():
		idle_global[i] = _global_of(i, idle_local)
	for side in ["Left", "Right"]:
		var ankle: Vector3 = idle_global[bones[side + "Foot"]].origin
		toe_off[side] = idle_global[bones[side + "ToeBase"]].origin - ankle
	ankle_flat_y = (idle_global[bones["LeftFoot"]].origin.y + idle_global[bones["RightFoot"]].origin.y) * 0.5
	heel_off = Vector3(0, -(ankle_flat_y - 0.03), -0.05)   # heel just above the ground, behind the ankle
	for cfg in [WALK, RUN]:
		var anim := _build(cfg)
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
		if name.ends_with("_end") or name.ends_with("_End") or name == "headfront":
			continue
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
	_rotate_global(bones["Spine02"], lean_q * twist_q, 1.0)

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
		var arm: int = bones[side + "Arm"]
		_rotate_global(arm, Quaternion(Vector3.FORWARD, -out) * Quaternion(Vector3.RIGHT, swing), 1.0)
		var bend := deg_to_rad(cfg.elbow + cfg.elbow_swing * maxf(-c, 0.0))
		_rotate_global(bones[side + "ForeArm"], Quaternion(Vector3.RIGHT, -bend), 1.0)

	# Head: keep the idle gaze (level, facing ahead) whatever the body does.
	var head: int = bones["Head"]
	_set_global_basis(head, idle_global[head].basis)


func _leg(cfg: Dictionary, side: String, phase: float) -> void:
	var up: int = bones[side + "UpLeg"]
	var knee: int = bones[side + "Leg"]
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
