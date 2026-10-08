extends SkeletonModifier3D
# Chase posture for the Frog, layered on top of whatever clip is playing (the
# walk clip, sped up, while it hunts). Same idea as frog_head_tracker.gd.
#
#   lean   0..1  bends the spine forward into a charging run
#   reach  0..1  left arm swings forward toward `reach_target` (two-bone IK)
#   grip  -1..1  left fingers: -1 spread wide open, 0 animated pose, 1 clenched
#
# The frog script drives the three weights; with all of them at 0 this does
# nothing, so every other behaviour looks exactly as before.
# Skeleton space: the model faces +Z, its left side is +X, bones point along +Y.

var lean := 0.0
var reach := 0.0
var grip := 0.0
var reach_target := Vector3.ZERO     # world space, usually the player's chest

var max_lean := deg_to_rad(24.0)
var spread_angle := deg_to_rad(-28.0)  # per finger joint, negative opens the hand
var clench_angle := deg_to_rad(62.0)
# Where the elbow points while reaching (skeleton space, from the shoulder):
# out to the side and down, the way a grab swings.
var elbow_pole := Vector3(0.6, -0.7, -0.25)

# Read back by tests / debug HUD: distance from the left wrist to reach_target
# after the IK was applied, in metres.
var hand_error := INF
# Angle (radians) between the extended arm and the direction to reach_target:
# small means the arm points right at the player even if they are out of reach.
var aim_error := INF

var _spine1 := -1
var _spine2 := -1
var _chest := -1
var _upper := -1
var _lower := -1
var _wrist := -1
var _fingers: Array[int] = []


func setup() -> void:
	var s := get_skeleton()
	# Lean from the waist up: in this rig both legs hang off "Spine", so the
	# bend starts one bone higher and is shared with the chest for a curve.
	_spine1 = s.find_bone("Spine1")
	_spine2 = s.find_bone("Spine2")
	_chest = s.find_bone("Chest")
	_upper = s.find_bone("L_UpperArm")
	_lower = s.find_bone("L_LowerArm")
	_wrist = s.find_bone("L_Wrist")
	_fingers.clear()
	for i in s.get_bone_count():
		if s.get_bone_name(i).begins_with("L_F"):
			_fingers.append(i)


func _process_modification_with_delta(_delta: float) -> void:
	var s := get_skeleton()
	if s == null or _spine1 < 0 or _spine2 < 0 or _chest < 0 or _upper < 0 or _lower < 0 or _wrist < 0:
		return
	if lean < 0.001 and reach < 0.001 and absf(grip) < 0.001:
		hand_error = INF
		aim_error = INF
		return

	# 1. Lean, 60% at Spine1 and 40% at Chest. Each rotation moves everything
	# above it rigidly around that bone's origin, so the arm's new global poses
	# are `lean_xf * old` with lean_xf = chest turn * waist turn.
	var amount := max_lean * clampf(lean, 0.0, 1.0)
	var spine1_old := s.get_bone_global_pose(_spine1)
	var spine2_old := s.get_bone_global_pose(_spine2)
	var chest_old := s.get_bone_global_pose(_chest)
	var q_waist := Quaternion(Vector3.RIGHT, amount * 0.6)
	var waist_xf := Transform3D(Basis(q_waist), spine1_old.origin - q_waist * spine1_old.origin)
	var chest_pivot := waist_xf * chest_old.origin
	var q_chest := Quaternion(Vector3.RIGHT, amount * 0.4)
	var chest_xf := Transform3D(Basis(q_chest), chest_pivot - q_chest * chest_pivot)
	var lean_xf := chest_xf * waist_xf
	# Read every animated pose before changing anything (the skeleton may or may
	# not refresh cached child poses after a set).
	var shoulder := lean_xf * s.get_bone_global_pose(s.get_bone_parent(_upper))
	var upper := lean_xf * s.get_bone_global_pose(_upper)
	var lower := lean_xf * s.get_bone_global_pose(_lower)
	var wrist := lean_xf * s.get_bone_global_pose(_wrist)
	if lean > 0.001:
		_set_global_pose(s, _spine1, waist_xf * spine1_old)
		_set_global_pose(s, _chest, lean_xf * chest_old, waist_xf * spine2_old)

	# 2. Left-arm reach (two-bone IK: shoulder → elbow → wrist).
	if reach > 0.001:
		var w := clampf(reach, 0.0, 1.0)
		var shoulder_p := upper.origin
		var elbow_p := lower.origin
		var wrist_p := wrist.origin
		var len_a := shoulder_p.distance_to(elbow_p)
		var len_b := elbow_p.distance_to(wrist_p)
		var goal := s.global_transform.affine_inverse() * reach_target
		var to_goal := goal - shoulder_p
		var dist := clampf(to_goal.length(), absf(len_a - len_b) + 0.01, (len_a + len_b) * 0.995)
		var dir := to_goal.normalized() if to_goal.length() > 0.001 else Vector3.BACK
		var cos_a := clampf((len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist), -1.0, 1.0)
		var bend := elbow_pole - dir * elbow_pole.dot(dir)
		if bend.length() < 0.001:
			bend = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
		bend = bend.normalized()
		var elbow_goal := shoulder_p + dir * (len_a * cos_a) + bend * (len_a * sqrt(1.0 - cos_a * cos_a))
		var wrist_goal := shoulder_p + dir * dist

		var q_upper := Quaternion((elbow_p - shoulder_p).normalized(), (elbow_goal - shoulder_p).normalized())
		q_upper = Quaternion.IDENTITY.slerp(q_upper, w)
		var upper_new := Transform3D(Basis(q_upper) * upper.basis, shoulder_p)
		var elbow_now := shoulder_p + q_upper * (elbow_p - shoulder_p)
		var forearm_now := (q_upper * (wrist_p - elbow_p)).normalized()
		var forearm_goal := (wrist_goal - elbow_goal).normalized()
		# At w = 1 the forearm lands exactly on the IK goal; in between it eases.
		var q_lower := Quaternion(forearm_now, forearm_now.slerp(forearm_goal, w).normalized())
		var lower_new := Transform3D(Basis(q_lower * q_upper) * lower.basis, elbow_now)
		_set_global_pose(s, _upper, upper_new, shoulder)
		_set_global_pose(s, _lower, lower_new, upper_new)
		var rot_total := q_lower * q_upper
		var wrist_now := elbow_now + rot_total * (wrist_p - elbow_p)
		hand_error = wrist_now.distance_to(goal)
		aim_error = (wrist_now - shoulder_p).angle_to(to_goal)
	else:
		hand_error = INF
		aim_error = INF

	# 3. Fingers: curl every left finger joint around its own X axis. Each joint
	# inherits its parent's curl, so the whole finger bends in an arc.
	if absf(grip) > 0.001:
		var angle := spread_angle * -minf(grip, 0.0) + clench_angle * maxf(grip, 0.0)
		var curl := Quaternion(Vector3.RIGHT, angle)
		for b in _fingers:
			s.set_bone_pose_rotation(b, s.get_bone_pose_rotation(b) * curl)


# Makes `bone` end up at `global_pose` (skeleton space). Bone global pose =
# parent global pose * bone pose (Godot 4 bone poses are not relative to rest).
# Pass the parent's new global pose when it was changed in this same pass.
func _set_global_pose(skeleton: Skeleton3D, bone: int, global_pose: Transform3D, parent_pose: Variant = null) -> void:
	var parent_global: Transform3D
	if parent_pose != null:
		parent_global = parent_pose
	else:
		var parent := skeleton.get_bone_parent(bone)
		parent_global = skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var pose := parent_global.affine_inverse() * global_pose
	skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
