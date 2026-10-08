extends SkeletonModifier3D
# The player being held up by the throat: both hands claw at the frog's wrist,
# the legs kick and dangle, the head is forced back. Layered on top of the idle
# clip; with weight 0 it does nothing.
#
#   weight      0..1  how far into the pose (hands up, head back, feet dangling)
#   kick        0..1  how hard the legs kick (the choke fades this out)
#   grab_point        world point the hands reach for (the frog's wrist)
#
# Skeleton space of main_character.glb: faces +Z, left side is +X, feet at y = 0.

var weight := 0.0
var kick := 0.0
var grab_point := Vector3.ZERO
var kick_speed := 9.0          # radians per second of the kick cycle

# Read back by tests: distance from each hand to its grab goal (metres).
var left_hand_error := INF
var right_hand_error := INF

var _t := 0.0
var _neck := -1
var _arms := {}   # side -> [upper, lower, hand]
var _legs := {}   # side -> [upleg, leg, foot]


func setup() -> void:
	var s := get_skeleton()
	_neck = s.find_bone("neck")
	for side in ["Left", "Right"]:
		_arms[side] = [s.find_bone(side + "Arm"), s.find_bone(side + "ForeArm"), s.find_bone(side + "Hand")]
		_legs[side] = [s.find_bone(side + "UpLeg"), s.find_bone(side + "Leg"), s.find_bone(side + "Foot")]


func _process_modification_with_delta(delta: float) -> void:
	var s := get_skeleton()
	if s == null or _neck < 0 or _arms.is_empty():
		return
	if weight < 0.001:
		left_hand_error = INF
		right_hand_error = INF
		return
	_t += delta * kick_speed
	var w := clampf(weight, 0.0, 1.0)

	# Read every animated pose first, then write.
	var neck := s.get_bone_global_pose(_neck)
	var arm_poses := {}
	for side in _arms:
		var b: Array = _arms[side]
		arm_poses[side] = [s.get_bone_global_pose(s.get_bone_parent(b[0])), s.get_bone_global_pose(b[0]), s.get_bone_global_pose(b[1]), s.get_bone_global_pose(b[2])]
	var leg_poses := {}
	for side in _legs:
		var b: Array = _legs[side]
		leg_poses[side] = [s.get_bone_global_pose(s.get_bone_parent(b[0])), s.get_bone_global_pose(b[0]), s.get_bone_global_pose(b[1]), s.get_bone_global_pose(b[2])]

	# Head forced back by the grip (rotation about +X tips the top toward -Z).
	var q_neck := Quaternion(Vector3.RIGHT, deg_to_rad(-28.0) * w)
	_set_global_pose(s, _neck, Transform3D(Basis(q_neck) * neck.basis, neck.origin))

	# Hands claw at the wrist from either side of it.
	var goal := s.global_transform.affine_inverse() * grab_point
	for side in _arms:
		var sign := 1.0 if side == "Left" else -1.0
		var p: Array = arm_poses[side]
		var hand_goal := goal + Vector3(0.05 * sign, -0.02, 0.0)
		var pole := Vector3(0.8 * sign, -0.45, 0.1)
		var err := _two_bone(s, _arms[side], p[0], p[1], p[2], p[3], hand_goal, pole, w)
		if side == "Left":
			left_hand_error = err
		else:
			right_hand_error = err

	# Legs: dangle (knees slack, toes down) and kick in opposite phase.
	for side in _legs:
		var phase := _t + (0.0 if side == "Left" else PI)
		var b: Array = _legs[side]
		var p: Array = leg_poses[side]
		var hip_angle := w * (0.12 + 0.45 * kick * sin(phase))
		var knee_angle := -w * (0.25 + 0.65 * kick * (0.5 + 0.5 * sin(phase + 1.3)))
		var foot_angle := w * 0.7
		var qh := Quaternion(Vector3.RIGHT, hip_angle)
		var qk := Quaternion(Vector3.RIGHT, knee_angle)
		var qf := Quaternion(Vector3.RIGHT, foot_angle)
		var up: Transform3D = p[1]
		var leg: Transform3D = p[2]
		var foot: Transform3D = p[3]
		var up_new := Transform3D(Basis(qh) * up.basis, up.origin)
		var knee_pos := up.origin + qh * (leg.origin - up.origin)
		var leg_new := Transform3D(Basis(qk * qh) * leg.basis, knee_pos)
		var foot_pos := knee_pos + (qk * qh) * (foot.origin - leg.origin)
		var foot_new := Transform3D(Basis(qf * qk * qh) * foot.basis, foot_pos)
		_set_global_pose(s, b[0], up_new, p[0])
		_set_global_pose(s, b[1], leg_new, up_new)
		_set_global_pose(s, b[2], foot_new, leg_new)


# Two-bone IK (same maths as frog_chase_pose.gd). Returns the end bone's
# distance to the goal at full weight.
func _two_bone(s: Skeleton3D, bones: Array, parent: Transform3D, upper: Transform3D, lower: Transform3D, end: Transform3D, goal: Vector3, pole: Vector3, w: float) -> float:
	var a := upper.origin
	var e := lower.origin
	var h := end.origin
	var len_a := a.distance_to(e)
	var len_b := e.distance_to(h)
	var to_goal := goal - a
	var dist := clampf(to_goal.length(), absf(len_a - len_b) + 0.01, (len_a + len_b) * 0.995)
	var dir := to_goal.normalized() if to_goal.length() > 0.001 else Vector3.UP
	var cos_a := clampf((len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist), -1.0, 1.0)
	var bend := pole - dir * pole.dot(dir)
	if bend.length() < 0.001:
		bend = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	bend = bend.normalized()
	var elbow_goal := a + dir * (len_a * cos_a) + bend * (len_a * sqrt(1.0 - cos_a * cos_a))
	var end_goal := a + dir * dist
	var q_up := Quaternion((e - a).normalized(), (elbow_goal - a).normalized())
	q_up = Quaternion.IDENTITY.slerp(q_up, w)
	var upper_new := Transform3D(Basis(q_up) * upper.basis, a)
	var elbow_now := a + q_up * (e - a)
	var fore_now := (q_up * (h - e)).normalized()
	var fore_goal := (end_goal - elbow_goal).normalized()
	var q_low := Quaternion(fore_now, fore_now.slerp(fore_goal, w).normalized())
	var lower_new := Transform3D(Basis(q_low * q_up) * lower.basis, elbow_now)
	_set_global_pose(s, bones[0], upper_new, parent)
	_set_global_pose(s, bones[1], lower_new, upper_new)
	var end_now := elbow_now + (q_low * q_up) * (h - e)
	return end_now.distance_to(goal)


# Bone global pose = parent global pose * bone pose (Godot 4).
func _set_global_pose(skeleton: Skeleton3D, bone: int, global_pose: Transform3D, parent_pose: Variant = null) -> void:
	var parent_global: Transform3D
	if parent_pose != null:
		parent_global = parent_pose
	else:
		var parent := skeleton.get_bone_parent(bone)
		parent_global = skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var pose := parent_global.affine_inverse() * global_pose
	skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
