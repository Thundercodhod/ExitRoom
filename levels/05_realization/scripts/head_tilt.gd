extends SkeletonModifier3D
## Rolls a head bone around its own forward axis (a curious tilt), on top of the
## animation and any head tracking that runs before it. Add it as the LAST child
## of the Skeleton3D so it applies after the other modifiers.
## Kept separate from frog_head_tracker.gd so the Episode 04 frog stays untouched.

var tilt := 0.0              # target roll, radians
var catch_up := 3.0          # higher = snappier
var _applied := 0.0
var _head := -1
var _forward_local := Vector3.BACK


func setup(head_name: String) -> void:
	var skeleton := get_skeleton()
	_head = skeleton.find_bone(head_name)
	if _head >= 0:
		_forward_local = skeleton.get_bone_global_rest(_head).basis.inverse() * Vector3.BACK


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _head < 0:
		return
	_applied = lerpf(_applied, tilt, clampf(catch_up * delta, 0.0, 1.0))
	if absf(_applied) < 0.0005:
		return
	var pose := skeleton.get_bone_global_pose(_head)
	var axis := (pose.basis * _forward_local).normalized()
	pose.basis = Basis(axis, _applied) * pose.basis
	var parent := skeleton.get_bone_parent(_head)
	var parent_global := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_global.affine_inverse() * pose
	skeleton.set_bone_pose_rotation(_head, local.basis.get_rotation_quaternion())
