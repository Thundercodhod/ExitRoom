extends CharacterBody3D
# The Frog: a tall humanoid frog that watches the player. It never attacks. It
# turns its head to follow the player, walks closer to take a good look but stops
# at a set distance, and backs away if the player steps toward it. Scenes can also
# make it vanish when seen, move when it is not being looked at, or sit down
# (passenger seat).
#
# Hunt mode (start_hunt / stop_hunt): it runs at the player leaning forward and
# swings its left arm out to clutch them: RUN -> REACH -> HOLD (hand snaps shut)
# -> RECOVER -> RUN. If the player is inside catch_range while the hand closes
# it emits caught_player and stands over them; the level decides what happens.
#
# Create it like the other actors: CharacterBody3D.new() + set_script().
#
#   frog.game = level                      # optional, needs a `playing` bool
#   frog.target = player                   # needs `camera`/`pivot` like player.gd (optional)
#   frog.bounds = Rect2(x, z, width, depth)   # optional: enables path finding around walls
#   frog.position = Vector3(...)           # feet position
#   add_child(frog)

signal vanished
signal reappeared
signal relocated(point: Vector3)
signal settled            # reached its viewing distance
signal hunt_started
signal clutch_started     # the arm starts swinging out
signal clutch_missed      # the hand closed on nothing
signal caught_player

const FrogModel = preload("res://assets/models/enemy/frog.glb")
const NavGrid = preload("res://scripts/nav_grid.gd")
const HeadTracker = preload("res://scripts/frog_head_tracker.gd")
const ChasePose = preload("res://scripts/frog_chase_pose.gd")

enum Mode { WATCH, SITTING, GONE, HUNT }
enum Clutch { RUN, REACH, HOLD, RECOVER, CAUGHT }
enum Move { HOLD, APPROACH, RETREAT }

# Tuning (change after creating, before or after add_child)
var keep_distance := 3.5          # where it likes to stand from the player
var distance_tolerance := 0.5     # closer than keep - tolerance: back away; farther than keep + tolerance: come closer
var approach_speed := 1.3
var retreat_speed := 1.0
var approach_range := 40.0        # ignores a player farther away than this
var approach_enabled := true
var head_tracking := true
var turn_body := true             # turn the whole body toward the player, not only the head
var turn_rate := 3.0

# Hunt tuning
var hunt_speed := 3.0             # running speed while chasing
var lunge_speed := 4.2            # short burst while the arm swings out
var hunt_turn_rate := 9.0
var clutch_range := 2.0           # starts a grab when the player is this close
var catch_range := 1.1            # the grab connects inside this distance (arm is ~0.6 m long)
var close_time := 0.12            # the hand must be shut this long before a catch counts
var reach_time := 0.25            # arm swings out
var hold_time := 0.3              # arm stays out, hand snaps shut
var recover_time := 0.4           # arm pulls back after a miss
var clutch_cooldown := 1.5        # seconds of plain running before the next grab

# Clip speeds: ground speed (m/s) of the planted foot in the baked walk clip.
const WALK_CLIP_SPEED := 1.5
const ANIM_BLEND := 0.25
const STOP_SPEED := 0.12

var game: Node3D
var target: Node3D
var bounds := Rect2()
var mode := Mode.WATCH
var move_state := Move.HOLD

var nav
var nav_ready := false
var path: Array[Vector3] = []
var path_index := 0
var repath_timer := 0.0
var rng := RandomNumberGenerator.new()

var skeleton: Skeleton3D
var tracker
var chase_pose
var clutch := Clutch.RUN
var _clutch_timer := 0.0
var _cooldown_timer := 0.0
var player_animation: AnimationPlayer
var anim_names := {}
var current_anim := &""
var model: Node3D
var body_shape: CollisionShape3D

var _vanish_distance := -1.0
var _vanish_delay := 0.25
var _seen_timer := 0.0
var _relocations: Array[Vector3] = []
var _relocation_delay := 0.4
var _unseen_timer := 0.0


func _ready() -> void:
	rng.randomize()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.8
	body_shape = CollisionShape3D.new()
	body_shape.shape = shape
	body_shape.position.y = 0.95
	add_child(body_shape)
	# frog.glb faces +Z (glTF), the actor faces -Z like everything else here.
	model = FrogModel.instantiate() as Node3D
	model.name = "FrogModel"
	model.rotation.y = PI
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	player_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if skeleton:
		tracker = HeadTracker.new()
		tracker.name = "HeadTracker"
		skeleton.add_child(tracker)
		tracker.setup("Neck", "Head")
		# Chase posture (lean, left-arm reach, fingers); idle unless hunting.
		chase_pose = ChasePose.new()
		chase_pose.name = "ChasePose"
		skeleton.add_child(chase_pose)
		skeleton.move_child(chase_pose, tracker.get_index())  # posture first, head tracking on top
		chase_pose.setup()
	_resolve_animations()
	_play_animation("idle", 1.0)
	if bounds.has_area():
		_build_nav_when_ready()


func _build_nav_when_ready() -> void:
	# Colliders created in the same frame are only visible to queries a couple of
	# physics frames later.
	await get_tree().physics_frame
	await get_tree().physics_frame
	nav = NavGrid.new()
	nav.bounds = bounds
	nav.radius = 0.4
	nav.build(get_world_3d().direct_space_state)
	nav_ready = true


# ---------------------------------------------------------------- scene helpers

func sit() -> void:
	_reset_chase_pose()
	mode = Mode.SITTING
	move_state = Move.HOLD
	velocity = Vector3.ZERO
	path.clear()
	body_shape.disabled = true
	_play_animation("sit", 1.0)


func stand() -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.WATCH
	body_shape.disabled = false
	_play_animation("idle", 1.0)


func vanish() -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.GONE
	_reset_chase_pose()
	visible = false
	velocity = Vector3.ZERO
	path.clear()
	body_shape.disabled = true
	vanished.emit()


func appear_at(point: Vector3, sitting := false) -> void:
	global_position = point
	visible = true
	mode = Mode.WATCH
	_reset_chase_pose()
	body_shape.disabled = false
	if sitting:
		sit()
	else:
		_play_animation("idle", 1.0)
	reappeared.emit()


# Starts chasing the player. Pending vanish / relocation rules are dropped.
func start_hunt() -> void:
	if mode == Mode.GONE or target == null:
		return
	clear_scene_rules()
	body_shape.disabled = false
	mode = Mode.HUNT
	move_state = Move.HOLD
	clutch = Clutch.RUN
	_clutch_timer = 0.0
	_cooldown_timer = 0.6  # a beat of running before the first grab
	path.clear()
	repath_timer = 0.0
	hunt_started.emit()


# Back to watching (keeps its distance again). The posture eases out.
func stop_hunt() -> void:
	if mode != Mode.HUNT:
		return
	mode = Mode.WATCH
	clutch = Clutch.RUN
	path.clear()


func is_hunting() -> bool:
	return mode == Mode.HUNT


func clutch_name() -> String:
	return Clutch.keys()[clutch]


# Disappears once the player has had it in view for `delay` seconds while closer than `distance`.
func vanish_when_seen_within(distance: float, delay := 0.25) -> void:
	_vanish_distance = distance
	_vanish_delay = delay
	_seen_timer = 0.0


# Jumps to `point` the next time the player has not been looking at it for
# `delay` seconds. Calls queue up: each one is a separate jump.
func relocate_when_unseen(point: Vector3, delay := 0.4) -> void:
	_relocations.append(point)
	_relocation_delay = delay
	_unseen_timer = 0.0


# Drops any pending vanish / relocation rule (e.g. when a scene is reset).
func clear_scene_rules() -> void:
	_vanish_distance = -1.0
	_seen_timer = 0.0
	_relocations.clear()
	_unseen_timer = 0.0


func pending_relocations() -> int:
	return _relocations.size()


func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		rotation.y = atan2(-d.x, -d.z)


# True when the player's camera has the frog's head or torso in view with nothing
# solid in between.
func is_seen(camera: Camera3D = null) -> bool:
	if mode == Mode.GONE or not visible:
		return false
	if camera == null:
		camera = _target_camera()
	if camera == null:
		return false
	for height in [1.6, 0.95]:
		var p: Vector3 = global_position + Vector3.UP * height
		if camera.is_position_in_frustum(p) and _clear_line(camera.global_position, p):
			return true
	return false


func distance_to_target() -> float:
	if target == null:
		return INF
	var d := target.global_position - global_position
	d.y = 0.0
	return d.length()


# Angle in radians between the head's forward direction and the player's head
# (measured after head tracking was applied).
func head_error() -> float:
	if tracker == null or target == null:
		return 0.0
	return tracker.tracking_error


# ---------------------------------------------------------------- per frame

func _physics_process(delta: float) -> void:
	if mode == Mode.GONE:
		return
	var running := game == null or bool(game.get("playing"))
	if tracker:
		tracker.tracking = head_tracking and target != null and running
		if target != null:
			tracker.target_position = _look_point()
	if not running:
		_stop(delta)
		return
	_update_scene_rules(delta)
	if mode == Mode.GONE:
		return
	match mode:
		Mode.WATCH:
			_watch(delta)
		Mode.SITTING:
			_apply_gravity(delta)
		Mode.HUNT:
			_hunt(delta)
	_update_chase_pose(delta)


func _update_scene_rules(delta: float) -> void:
	if _vanish_distance > 0.0 and target != null:
		if distance_to_target() < _vanish_distance and is_seen():
			_seen_timer += delta
			if _seen_timer >= _vanish_delay:
				_vanish_distance = -1.0
				vanish()
				return
		else:
			_seen_timer = 0.0
	if not _relocations.is_empty():
		if is_seen():
			_unseen_timer = 0.0
		else:
			_unseen_timer += delta
			if _unseen_timer >= _relocation_delay:
				var point: Vector3 = _relocations.pop_front()
				global_position = point
				velocity = Vector3.ZERO
				path.clear()
				_unseen_timer = 0.0
				relocated.emit(point)


func _watch(delta: float) -> void:
	if target == null:
		_stop(delta)
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	var dist := offset.length()
	var to_player := offset.normalized() if dist > 0.01 else -global_transform.basis.z
	_update_move_state(dist)
	if not approach_enabled or move_state == Move.HOLD:
		_stop(delta)
		if turn_body and dist < approach_range:
			_turn_towards(to_player, delta)
		_update_animation(1.0)
		return
	var speed := approach_speed if move_state == Move.APPROACH else retreat_speed
	var goal := target.global_position + (-to_player) * keep_distance
	goal.y = global_position.y
	var move_dir := _direction_to_goal(goal, delta)
	if move_dir == Vector3.ZERO:
		# Arrived at the spot (or boxed in): stop and watch from here.
		_settle()
		_stop(delta)
		return
	# Face the player while walking toward or away from them; for sideways
	# detours face the way it is going.
	var along := move_dir.dot(to_player)
	var walk_sign := 1.0
	var face := to_player
	if along < -0.5:
		walk_sign = -1.0
	elif along <= 0.5:
		face = move_dir
	if turn_body:
		_turn_towards(face, delta)
	velocity.x = move_toward(velocity.x, move_dir.x * speed, delta * 6.0)
	velocity.z = move_toward(velocity.z, move_dir.z * speed, delta * 6.0)
	_apply_gravity(delta)
	move_and_slide()
	_update_animation(walk_sign)


# ---------------------------------------------------------------- hunt

func _hunt(delta: float) -> void:
	if target == null:
		stop_hunt()
		return
	var dist := distance_to_target()
	var offset := target.global_position - global_position
	offset.y = 0.0
	var to_player := offset.normalized() if dist > 0.01 else -global_transform.basis.z
	_turn_towards(to_player, delta, hunt_turn_rate)
	_cooldown_timer = maxf(_cooldown_timer - delta, 0.0)
	_clutch_timer += delta
	var speed := hunt_speed
	match clutch:
		Clutch.RUN:
			if _cooldown_timer <= 0.0 and dist <= clutch_range:
				_set_clutch(Clutch.REACH)
				clutch_started.emit()
		Clutch.REACH:
			speed = lunge_speed
			if _clutch_timer >= reach_time:
				_set_clutch(Clutch.HOLD)
		Clutch.HOLD:
			speed = hunt_speed * 0.5
			if _clutch_timer >= close_time and dist <= catch_range and not bool(target.get("hiding")):
				_set_clutch(Clutch.CAUGHT)
				velocity.x = 0.0
				velocity.z = 0.0
				caught_player.emit()
			elif _clutch_timer >= hold_time:
				_set_clutch(Clutch.RECOVER)
				clutch_missed.emit()
		Clutch.RECOVER:
			speed = hunt_speed * 0.6
			if _clutch_timer >= recover_time:
				_set_clutch(Clutch.RUN)
				_cooldown_timer = clutch_cooldown
		Clutch.CAUGHT:
			_stop(delta)
			_update_hunt_animation()
			return
	# Stop just short of the player's body instead of pushing into it.
	var move_dir := Vector3.ZERO
	if dist > 0.75:
		move_dir = _direction_to_goal(target.global_position, delta)
	velocity.x = move_toward(velocity.x, move_dir.x * speed, delta * 14.0)
	velocity.z = move_toward(velocity.z, move_dir.z * speed, delta * 14.0)
	_apply_gravity(delta)
	move_and_slide()
	_update_hunt_animation()


func _set_clutch(next: Clutch) -> void:
	clutch = next
	_clutch_timer = 0.0


# Eases the posture weights toward what the current hunt phase wants.
func _update_chase_pose(delta: float) -> void:
	if chase_pose == null:
		return
	var want_lean := 0.0
	var want_reach := 0.0
	var want_grip := 0.0
	var reach_rate := 6.0
	var grip_rate := 8.0
	if mode == Mode.HUNT:
		want_lean = 1.0
		match clutch:
			Clutch.REACH:
				want_reach = 1.0
				want_grip = -1.0                       # fingers spread
				reach_rate = 1.0 / maxf(reach_time, 0.01)
			Clutch.HOLD, Clutch.CAUGHT:
				want_reach = 1.0
				want_grip = 1.0                        # snap shut
				reach_rate = 1.0 / maxf(reach_time, 0.01)
				grip_rate = 14.0
			Clutch.RECOVER:
				want_reach = 0.0
				want_grip = 0.0
				reach_rate = 1.0 / maxf(recover_time, 0.01)
	chase_pose.lean = move_toward(chase_pose.lean, want_lean, delta * 3.0)
	chase_pose.reach = move_toward(chase_pose.reach, want_reach, delta * reach_rate)
	chase_pose.grip = move_toward(chase_pose.grip, want_grip, delta * grip_rate)
	if target != null:
		chase_pose.reach_target = target.global_position + Vector3.UP * 1.2


func _reset_chase_pose() -> void:
	clutch = Clutch.RUN
	if chase_pose:
		chase_pose.lean = 0.0
		chase_pose.reach = 0.0
		chase_pose.grip = 0.0


func _update_hunt_animation() -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed < STOP_SPEED:
		_play_animation("idle", 1.0)
	else:
		# The walk clip sped up to match: ~2x at running speed.
		_play_animation("walk", ground_speed / WALK_CLIP_SPEED)


func _update_move_state(dist: float) -> void:
	if dist > approach_range:
		move_state = Move.HOLD
		return
	match move_state:
		Move.HOLD:
			if dist > keep_distance + distance_tolerance:
				move_state = Move.APPROACH
			elif dist < keep_distance - distance_tolerance:
				move_state = Move.RETREAT
		Move.APPROACH:
			if dist <= keep_distance + 0.25:
				_settle()
		Move.RETREAT:
			if dist >= keep_distance - 0.25:
				_settle()


func _settle() -> void:
	move_state = Move.HOLD
	settled.emit()


# Flat unit vector toward the goal, following a grid path when one is available.
func _direction_to_goal(goal: Vector3, delta: float) -> Vector3:
	if nav_ready:
		repath_timer -= delta
		if repath_timer <= 0.0:
			repath_timer = 0.4
			path = nav.plan(global_position, goal)
			path_index = 0
		while path_index < path.size():
			var to := path[path_index] - global_position
			to.y = 0.0
			if to.length() < 0.3:
				path_index += 1
			else:
				return to.normalized()
		return Vector3.ZERO if path.is_empty() and (goal - global_position).length() < 0.5 else _flat_direction(goal)
	return _flat_direction(goal)


func _flat_direction(point: Vector3) -> Vector3:
	var d := point - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.3 else Vector3.ZERO


func _turn_towards(direction: Vector3, delta: float, rate := -1.0) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	var r := turn_rate if rate < 0.0 else rate
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * r, 0.0, 1.0))


func _apply_gravity(delta: float) -> void:
	velocity.y -= 20.0 * delta
	if is_on_floor():
		velocity.y = -0.1


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	_apply_gravity(delta)
	move_and_slide()
	if mode == Mode.WATCH:
		_update_animation(1.0)


# ---------------------------------------------------------------- helpers

func _target_camera() -> Camera3D:
	if target == null:
		return null
	var cam: Variant = target.get("camera")
	return cam as Camera3D


func _look_point() -> Vector3:
	var pivot: Variant = target.get("pivot")
	if pivot is Node3D:
		return (pivot as Node3D).global_position
	return target.global_position + Vector3.UP * 1.5


func _clear_line(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- animation

# Find the baked clips by keyword so the code works whether or not the importer
# keeps the "-loop" suffix on the animation names.
func _resolve_animations() -> void:
	if not player_animation:
		return
	for key in ["idle", "walk", "sit"]:
		for clip in player_animation.get_animation_list():
			if String(clip).to_lower().begins_with(key):
				anim_names[key] = clip
				player_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR


func _play_animation(key: String, speed: float) -> void:
	if not player_animation or not anim_names.has(key):
		return
	var clip: StringName = anim_names[key]
	if current_anim != clip:
		current_anim = clip
		player_animation.play(clip, ANIM_BLEND)
	player_animation.speed_scale = speed


# walk_sign: +1 walking forward, -1 walking backwards (the clip is played in reverse)
func _update_animation(walk_sign: float) -> void:
	if mode != Mode.WATCH:
		return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed < STOP_SPEED:
		_play_animation("idle", 1.0)
	else:
		_play_animation("walk", walk_sign * ground_speed / WALK_CLIP_SPEED)
