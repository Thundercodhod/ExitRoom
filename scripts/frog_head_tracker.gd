extends SkeletonModifier3D
# Turns the neck and head toward a world-space point on top of whatever the
# animation is playing. It works out the head's forward axis from the rest pose,
# so it does not depend on how the bones happen to be oriented in the model.
# The model faces +Z in skeleton space (glTF convention).

var target_position := Vector3.ZERO
var tracking := false
var max_angle := deg_to_rad(85.0)   # total turn away from the animated pose
var neck_share := 0.4               # part of the turn done by the neck, the rest by the head
var catch_up := 5.0                 # higher = snappier

# Angle between the head's forward direction and the target, measured right after
# the turn was applied (the skeleton does not keep modified poses between frames,
# so this is the value to read from outside).
var tracking_error := 0.0

var _neck := -1
var _head := -1
var _head_forward_local := Vector3.BACK
var _applied := Quaternion.IDENTITY


func setup(neck_name: String, head_name: String) -> void:
	var skeleton := get_skeleton()
	_neck = skeleton.find_bone(neck_name)
	_head = skeleton.find_bone(head_name)
	if _head >= 0:
		_head_forward_local = skeleton.get_bone_global_rest(_head).basis.inverse() * Vector3.BACK


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or _head < 0:
		return
	var pose := skeleton.get_bone_global_pose(_head)
	var forward := (pose.basis * _head_forward_local).normalized()
	var local_target := skeleton.global_transform.affine_inverse() * target_position
	var direction := (local_target - pose.origin).normalized()
	var desired := Quaternion.IDENTITY
	if tracking and direction.length() > 0.5 and forward.cross(direction).length() > 0.0001:
		desired = Quaternion(forward, direction)
		var angle := desired.get_angle()
		if angle > max_angle:
			desired = Quaternion.IDENTITY.slerp(desired, max_angle / angle)
	_applied = _applied.slerp(desired, clampf(catch_up * delta, 0.0, 1.0))
	var head_new := pose
	if _applied.get_angle() >= 0.0005:
		# Work out both new global transforms first: the skeleton caches child
		# poses, so reading the head again after changing the neck would be stale.
		var neck_turn := Quaternion.IDENTITY.slerp(_applied, neck_share)
		var parent_of_head := Transform3D.IDENTITY
		if _neck >= 0:
			var neck_old := skeleton.get_bone_global_pose(_neck)
			var neck_new := neck_old
			neck_new.basis = Basis(neck_turn) * neck_old.basis
			_set_global_pose(skeleton, _neck, neck_new)
			head_new.origin = neck_new.origin + neck_turn * (pose.origin - neck_old.origin)
			parent_of_head = neck_new
		else:
			parent_of_head = skeleton.get_bone_global_pose(skeleton.get_bone_parent(_head))
		head_new.basis = Basis(_applied) * pose.basis
		_set_global_pose(skeleton, _head, head_new, parent_of_head)
	var after_direction := (local_target - head_new.origin).normalized()
	tracking_error = (head_new.basis * _head_forward_local).normalized().angle_to(after_direction)


# Sets a bone so that its global (skeleton space) transform becomes `global_pose`.
# The parent's new global transform can be passed in when it was changed in the
# same pass.
func _set_global_pose(skeleton: Skeleton3D, bone: int, global_pose: Transform3D, parent_pose: Variant = null) -> void:
	var parent_global: Transform3D
	if parent_pose != null:
		parent_global = parent_pose
	else:
		var parent := skeleton.get_bone_parent(bone)
		parent_global = skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	# Godot 4: bone global pose = parent global pose * bone pose (the pose is not
	# relative to the rest transform).
	var pose := parent_global.affine_inverse() * global_pose
	skeleton.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
