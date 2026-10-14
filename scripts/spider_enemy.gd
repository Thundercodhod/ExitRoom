extends CharacterBody3D
# Giant spider enemy. Patrols the level, notices the player by sight or by the
# noise of sprinting, chases along a grid path and catches the player when it
# reaches them. Create it like the player: CharacterBody3D.new() + set_script().
#
#   spider.game = level            # needs a `playing` bool
#   spider.target = player         # needs `hiding` and `sprinting` like player.gd
#   spider.bounds = Rect2(x, z, width, depth)   # XZ area the spider can walk in
#   add_child(spider)
#   spider.caught_player.connect(...)
#
# Ceiling crawl: while it patrols, the model hangs upside down on the ceiling
# (path finding and the collider stay on the floor, so nothing else changes).
# When it notices the player it skitters to the nearest wall and climbs down it
# head first, or drops straight down with a thud when no wall is close; when it
# gives up the search it climbs back up. Set ceiling_crawl = false to turn it off.

signal caught_player

const SpiderModel = preload("res://assets/models/enemy/spider.glb")
const SkitterSound = preload("res://audio/spider/skitter.wav")
const AggroSound = preload("res://audio/spider/aggro.wav")   # it has seen you
const ClimbSound = preload("res://audio/spider/climb.wav")   # legs on the wall
const ThudSound = preload("res://audio/spider/thud.wav")

enum State { PATROL, CHASE, SEARCH, ATTACK, CAUGHT }

const PATROL_SPEED := 1.1
const CHASE_SPEED := 3.2
const SIGHT_RANGE := 12.0
const NEAR_SIGHT := 3.5          # notices the player at this range even from behind
const SIGHT_HALF_ANGLE := 75.0   # degrees
const HEARING_RANGE := 8.0       # only while the player sprints
const ATTACK_RANGE := 1.5
const HIT_RANGE := 1.9
const HIT_TIME := 0.45
const ATTACK_TIME := 1.0
const LOSE_TIME := 3.5
const SEARCH_TIME := 3.0
const GRID_CELL := 0.4
const BODY_RADIUS := 0.42
const BODY_HEIGHT := 0.45
const MIN_START_DISTANCE := 14.0
# Planted-foot ground speed (m/s) of the baked clips: playback speed is scaled
# by speed / clip speed so the feet do not slide.
const WALK_CLIP_SPEED := 0.45
const RUN_CLIP_SPEED := 1.49
const ANIM_BLEND := 0.15
const WALL_REACH := 3.0          # climbs down a wall this close, otherwise drops
const WALL_GAP := 0.45           # body distance from the wall once down
const CEILING_TO_WALL_TIME := 0.35
const WALL_DESCENT_TIME := 0.8
const TURN_UPRIGHT_TIME := 0.25
const DROP_TIME := 0.35
const ASCENT_SPEED := 0.55       # climbing back up is slower than coming down

var game: Node3D
var target: Node3D
var bounds := Rect2(-12.0, -12.0, 24.0, 24.0)
var start_far_from_target := true
var state := State.PATROL
var rng := RandomNumberGenerator.new()

var grid: AStarGrid2D
var grid_ready := false
var path: Array[Vector3] = []
var path_index := 0
var repath_timer := 0.0
var wait_timer := 0.0
var lose_timer := 0.0
var search_timer := 0.0
var attack_timer := 0.0
var attack_hit_done := false
var last_known := Vector3.ZERO
var player_animation: AnimationPlayer
var anim_names := {}
var current_anim := &""
var model: Node3D
var ceiling_crawl := true
var ceiling_height := 2.39       # floor to ceiling where it walks (Backrooms: 2.39 m)
var on_ceiling := false
var climbing := false
var last_descent := ""           # "wall" or "drop", for tests and tuning
var _climb_keys: Array[Transform3D] = []
var _climb_times: Array[float] = []
var _climb_t := 0.0
var _climb_end_body := Vector3.ZERO
var _climb_to_ceiling := false
var _climb_sound_at_end: AudioStream
var skitter: AudioStreamPlayer3D
var thump: AudioStreamPlayer3D
var screech: AudioStreamPlayer3D


func _ready() -> void:
	rng.randomize()
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := SphereShape3D.new()
	shape.radius = BODY_RADIUS
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = BODY_RADIUS  # sphere rests on the floor so the model's feet touch it
	add_child(col)
	# spider.glb faces -Z (Godot forward) with its feet at y = 0.
	model = SpiderModel.instantiate() as Node3D
	model.name = "SpiderModel"
	add_child(model)
	# Its sounds move with the model (ceiling, wall or floor).
	skitter = AudioStreamPlayer3D.new()
	skitter.name = "Skitter"
	var loop := SkitterSound.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	skitter.stream = loop
	skitter.unit_size = 3.0
	skitter.max_distance = 22.0
	model.add_child(skitter)
	thump = AudioStreamPlayer3D.new()
	thump.name = "Thump"
	thump.unit_size = 5.0
	thump.max_distance = 30.0
	model.add_child(thump)
	screech = AudioStreamPlayer3D.new()
	screech.name = "Screech"
	screech.stream = AggroSound
	screech.unit_size = 6.0
	screech.max_distance = 40.0
	screech.volume_db = -2.0
	model.add_child(screech)
	if ceiling_crawl:
		_hang_on_ceiling()
	player_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_resolve_animations()
	_play_animation("idle", 1.0)
	_build_grid_when_ready()


func _build_grid_when_ready() -> void:
	# Colliders created in the same frame are only visible to queries a couple
	# of physics frames later.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_grid()
	grid_ready = true
	if start_far_from_target and target != null:
		_relocate_far_from_target()
	_pick_patrol_point()


func state_name() -> String:
	return State.keys()[state]


# ---------------------------------------------------------------- navigation grid

func _build_grid() -> void:
	var size := Vector2i(ceili(bounds.size.x / GRID_CELL), ceili(bounds.size.y / GRID_CELL))
	grid = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2(GRID_CELL, GRID_CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = BODY_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for x in size.x:
		for y in size.y:
			var c := _cell_center(Vector2i(x, y))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, BODY_HEIGHT, c.y))
			if not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(Vector2i(x, y), true)


func _cell_center(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * GRID_CELL


func _world_to_cell(p: Vector3) -> Vector2i:
	var cell := Vector2i(floori((p.x - bounds.position.x) / GRID_CELL), floori((p.z - bounds.position.y) / GRID_CELL))
	return Vector2i(clampi(cell.x, 0, grid.region.size.x - 1), clampi(cell.y, 0, grid.region.size.y - 1))


func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 12):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := cell + Vector2i(dx, dy)
				if grid.region.has_point(c) and not grid.is_point_solid(c):
					return c
	return cell


func _line_free(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	if steps == 0:
		return true
	for i in range(steps + 1):
		var t := float(i) / steps
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if grid.is_point_solid(c):
			return false
	return true


func plan_path(destination: Vector3) -> bool:
	if not grid_ready:
		return false
	var from := _nearest_free_cell(_world_to_cell(global_position))
	var to := _nearest_free_cell(_world_to_cell(destination))
	var cells := grid.get_id_path(from, to)
	if cells.is_empty():
		path.clear()
		path_index = 0
		return false
	# String-pull: keep only the corners that cannot be cut.
	var result: Array[Vector3] = []
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _line_free(cells[i], cells[j]):
			j -= 1
		var c := _cell_center(cells[j])
		result.append(Vector3(c.x, 0.0, c.y))
		i = j
	path = result
	path_index = 0
	return not path.is_empty()


func _random_free_position(min_distance: float, max_distance: float, around: Vector3) -> Variant:
	for attempt in 40:
		var cell := Vector2i(rng.randi_range(0, grid.region.size.x - 1), rng.randi_range(0, grid.region.size.y - 1))
		if grid.is_point_solid(cell):
			continue
		var c := _cell_center(cell)
		var p := Vector3(c.x, 0.0, c.y)
		var d := Vector2(p.x - around.x, p.z - around.z).length()
		if d >= min_distance and d <= max_distance:
			return p
	return null


func _relocate_far_from_target() -> void:
	var p: Variant = _random_free_position(MIN_START_DISTANCE, 100.0, target.global_position)
	if p != null:
		global_position = Vector3(p.x, global_position.y, p.z)
		velocity = Vector3.ZERO


func _pick_patrol_point() -> void:
	var p: Variant = _random_free_position(6.0, 18.0, global_position)
	if p != null and plan_path(p):
		wait_timer = 0.0
	else:
		wait_timer = 1.0


# ---------------------------------------------------------------- perception

func _flat_offset_to_target() -> Vector3:
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset


func _target_hiding() -> bool:
	return target != null and bool(target.get("hiding"))


func _has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, target.global_position + Vector3.UP * 1.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func can_see_target() -> bool:
	if target == null:
		return false
	var offset := _flat_offset_to_target()
	var dist := offset.length()
	if _target_hiding():
		return dist < 1.2
	if dist > SIGHT_RANGE:
		return false
	if dist > NEAR_SIGHT:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		if forward.normalized().dot(offset.normalized()) < cos(deg_to_rad(SIGHT_HALF_ANGLE)):
			return false
	return _has_line_of_sight()


func can_hear_target() -> bool:
	if target == null or _target_hiding():
		return false
	return bool(target.get("sprinting")) and _flat_offset_to_target().length() <= HEARING_RANGE


# ---------------------------------------------------------------- state machine

func _set_state(next: State) -> void:
	state = next
	match next:
		State.CHASE:
			lose_timer = 0.0
			repath_timer = 0.0
		State.SEARCH:
			search_timer = SEARCH_TIME
			path.clear()
		State.ATTACK:
			attack_timer = 0.0
			attack_hit_done = false
			_play_animation("attack", 1.0, true)
		State.PATROL:
			wait_timer = rng.randf_range(0.5, 1.5)
			path.clear()


func _physics_process(delta: float) -> void:
	if not grid_ready:
		_apply_gravity(delta)
		move_and_slide()
		return
	if game != null and not game.playing:
		_stop(delta)
		_update_sound()
		return
	if climbing:
		_stop(delta)
		_update_climb(delta)
		_update_sound()
		return
	# It has noticed the player (or was told to chase): come down first.
	if ceiling_crawl and on_ceiling and state in [State.CHASE, State.ATTACK]:
		_begin_descent()
		return
	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)
		State.SEARCH:
			_search(delta)
		State.ATTACK:
			_attack(delta)
		State.CAUGHT:
			_stop(delta)
	_update_animation()
	_update_sound()


func _patrol(delta: float) -> void:
	if can_see_target() or can_hear_target():
		last_known = target.global_position
		_set_state(State.CHASE)
		return
	if path.is_empty() or path_index >= path.size():
		_stop(delta)
		wait_timer -= delta
		if wait_timer <= 0.0:
			_pick_patrol_point()
		return
	if _follow_path(delta, PATROL_SPEED):
		_set_state(State.PATROL)


func _chase(delta: float) -> void:
	var sees := can_see_target()
	if sees or can_hear_target():
		last_known = target.global_position
		lose_timer = 0.0
	else:
		lose_timer += delta
	var dist := _flat_offset_to_target().length()
	if sees and dist < ATTACK_RANGE and not _target_hiding():
		_set_state(State.ATTACK)
		return
	if lose_timer > LOSE_TIME:
		_set_state(State.SEARCH)
		return
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = 0.3
		plan_path(last_known)
	if path.is_empty() or path_index >= path.size():
		if not sees:
			_set_state(State.SEARCH)
		else:
			_move_towards(last_known, CHASE_SPEED, delta)
		return
	_follow_path(delta, CHASE_SPEED)


func _search(delta: float) -> void:
	if can_see_target() or can_hear_target():
		last_known = target.global_position
		_set_state(State.CHASE)
		return
	_stop(delta)
	rotation.y += delta * 1.4
	search_timer -= delta
	if search_timer <= 0.0:
		_set_state(State.PATROL)
		_pick_patrol_point()
		if ceiling_crawl and not on_ceiling:
			_begin_ascent()


func _attack(delta: float) -> void:
	_stop(delta)
	if target != null:
		_face(_flat_offset_to_target(), delta, 14.0)
	attack_timer += delta
	if not attack_hit_done and attack_timer >= HIT_TIME:
		attack_hit_done = true
		if target != null and not _target_hiding() and _flat_offset_to_target().length() <= HIT_RANGE:
			_set_state(State.CAUGHT)
			caught_player.emit()
			return
	if attack_timer >= ATTACK_TIME:
		_set_state(State.CHASE)


# ---------------------------------------------------------------- movement

func _apply_gravity(delta: float) -> void:
	velocity.y -= 20.0 * delta
	if is_on_floor():
		velocity.y = -0.1


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 14.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 14.0)
	_apply_gravity(delta)
	move_and_slide()


func _face(direction: Vector3, delta: float, turn_rate := 8.0) -> void:
	if Vector2(direction.x, direction.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), clampf(delta * turn_rate, 0.0, 1.0))


# Returns true when the end of the path has been reached.
func _follow_path(delta: float, speed: float) -> bool:
	while path_index < path.size():
		var to := path[path_index] - global_position
		to.y = 0.0
		if to.length() < 0.3:
			path_index += 1
		else:
			break
	if path_index >= path.size():
		_stop(delta)
		return true
	_move_towards(path[path_index], speed, delta)
	return false


func _move_towards(point: Vector3, speed: float, delta: float) -> void:
	var to := point - global_position
	to.y = 0.0
	var direction := to.normalized()
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 16.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 16.0)
	_face(direction, delta)
	_apply_gravity(delta)
	move_and_slide()


# ---------------------------------------------------------------- animation

# Find the baked clips by keyword so the code works whether or not the importer
# keeps the "-loop" suffix on the animation names.
func _resolve_animations() -> void:
	if not player_animation:
		return
	for key in ["idle", "walk", "run", "attack"]:
		for clip in player_animation.get_animation_list():
			if String(clip).to_lower().begins_with(key):
				anim_names[key] = clip
				var animation := player_animation.get_animation(clip)
				animation.loop_mode = Animation.LOOP_NONE if key == "attack" else Animation.LOOP_LINEAR


func _play_animation(key: String, speed: float, restart := false) -> void:
	if not player_animation or not anim_names.has(key):
		return
	var clip: StringName = anim_names[key]
	if current_anim != clip or restart:
		current_anim = clip
		player_animation.play(clip, ANIM_BLEND)
	player_animation.speed_scale = speed


func _update_animation() -> void:
	if state == State.ATTACK:
		return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed < 0.1:
		_play_animation("idle", 1.0)
	elif ground_speed < 2.0:
		_play_animation("walk", ground_speed / WALK_CLIP_SPEED)
	else:
		_play_animation("run", ground_speed / RUN_CLIP_SPEED)


# ---------------------------------------------------------------- ceiling crawl

func _hang_on_ceiling() -> void:
	on_ceiling = true
	# Upside down (a half turn about its own length), feet on the ceiling.
	model.transform = Transform3D(Basis(Vector3.BACK, PI), Vector3(0.0, ceiling_height, 0.0))


func _stand_upright() -> void:
	on_ceiling = false
	model.transform = Transform3D.IDENTITY


# Closest wall around the body within WALL_REACH: {point, normal}, or {} when none.
func _nearest_wall() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	var best := {}
	var best_d := INF
	for i in 16:
		var a := TAU * i / 16.0
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(cos(a), 0.0, sin(a)) * WALL_REACH, 1, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty() or absf(hit.normal.y) > 0.3:
			continue
		var d := from.distance_to(hit.position)
		if d < best_d:
			best_d = d
			var n: Vector3 = hit.normal
			n.y = 0.0
			best = {"point": Vector3(hit.position.x, 0.0, hit.position.z) + Vector3(0.0, global_position.y, 0.0), "normal": n.normalized()}
	return best


func _yaw_basis(forward: Vector3) -> Basis:
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	return Basis.looking_at(forward.normalized(), Vector3.UP)


func _start_climb(keys: Array[Transform3D], times: Array[float], end_body: Vector3, to_ceiling: bool, end_sound: AudioStream) -> void:
	climbing = true
	_climb_keys = keys
	_climb_times = times
	_climb_t = 0.0
	_climb_end_body = end_body
	_climb_to_ceiling = to_ceiling
	_climb_sound_at_end = end_sound
	velocity = Vector3.ZERO
	model.top_level = true
	model.global_transform = keys[0]
	_play_animation("run", 1.6)


# Noticed the player: to the nearest wall and down it head first, or straight down.
func _begin_descent() -> void:
	screech.play()
	var face := _flat_offset_to_target() if target != null else -global_transform.basis.z
	var upright := _yaw_basis(face)
	var start := model.global_transform
	var flip := Basis(Vector3.BACK, PI)
	var wall := _nearest_wall()
	if wall.is_empty():
		last_descent = "drop"
		var land := Transform3D(upright, global_position)
		_start_climb([start, land] as Array[Transform3D], [DROP_TIME] as Array[float], global_position, false, ThudSound)
		return
	last_descent = "wall"
	var n: Vector3 = wall.normal
	var foot: Vector3 = wall.point
	var head_down := Basis(n.cross(Vector3.UP).normalized(), n, Vector3.UP)
	var keys: Array[Transform3D] = [
		start,
		Transform3D(_yaw_basis(-n) * flip, foot + n * 0.05 + Vector3.UP * ceiling_height),
		Transform3D(head_down, foot + Vector3.UP * (ceiling_height - 1.0)),
		Transform3D(head_down, foot + Vector3.UP * 0.9),
		Transform3D(upright, foot + n * WALL_GAP)]
	var times: Array[float] = [CEILING_TO_WALL_TIME, 0.2, WALL_DESCENT_TIME, TURN_UPRIGHT_TIME]
	_start_climb(keys, times, foot + n * WALL_GAP, false, null)
	thump.stream = ClimbSound
	thump.play()


# Gave up the search: back up the nearest wall (or straight up) to the ceiling.
func _begin_ascent() -> void:
	var start := model.global_transform
	var flip := Basis(Vector3.BACK, PI)
	var wall := _nearest_wall()
	if wall.is_empty():
		var up := Transform3D(_yaw_basis(-global_transform.basis.z) * flip, global_position + Vector3.UP * ceiling_height)
		_start_climb([start, up] as Array[Transform3D], [DROP_TIME * 2.5] as Array[float], global_position, true, null)
		thump.stream = ClimbSound
		thump.play()
		return
	var n: Vector3 = wall.normal
	var foot: Vector3 = wall.point
	var head_up := Basis(n.cross(Vector3.DOWN).normalized(), n, Vector3.DOWN)
	var end_body := foot + n * WALL_GAP
	var keys: Array[Transform3D] = [
		start,
		Transform3D(head_up, foot + Vector3.UP * 0.9),
		Transform3D(head_up, foot + Vector3.UP * (ceiling_height - 1.0)),
		Transform3D(_yaw_basis(n) * flip, foot + n * 0.05 + Vector3.UP * ceiling_height),
		Transform3D(_yaw_basis(n) * flip, end_body + Vector3.UP * ceiling_height)]
	var times: Array[float] = []
	for t in [TURN_UPRIGHT_TIME, WALL_DESCENT_TIME, 0.2, CEILING_TO_WALL_TIME]:
		times.append(t / ASCENT_SPEED)
	_start_climb(keys, times, end_body, true, null)
	thump.stream = ClimbSound
	thump.play()


func _update_climb(delta: float) -> void:
	_climb_t += delta
	var t := _climb_t
	for i in _climb_times.size():
		if t <= _climb_times[i]:
			var k := smoothstep(0.0, 1.0, t / _climb_times[i])
			model.global_transform = _climb_keys[i].interpolate_with(_climb_keys[i + 1], k)
			return
		t -= _climb_times[i]
	_finish_climb()


func _finish_climb() -> void:
	climbing = false
	var final := _climb_keys[_climb_keys.size() - 1]
	model.top_level = false
	global_position = Vector3(_climb_end_body.x, global_position.y, _climb_end_body.z)
	# On the ceiling the last key is yaw * flip: take the flip off to get the heading.
	var yaw := final.basis * Basis(Vector3.BACK, PI).inverse() if _climb_to_ceiling else final.basis
	var forward := -yaw.z
	rotation.y = atan2(-forward.x, -forward.z)
	if _climb_to_ceiling:
		_hang_on_ceiling()
	else:
		_stand_upright()
	if _climb_sound_at_end:
		thump.stream = _climb_sound_at_end
		thump.play()


# Skittering while it moves (quiet up on the ceiling, loud and fast in a chase).
func _update_sound() -> void:
	if skitter == null:
		return
	var running := game == null or bool(game.playing)
	var moving := climbing or Vector2(velocity.x, velocity.z).length() > 0.1
	if not running or not moving:
		if skitter.playing:
			skitter.stop()
		return
	if not skitter.playing:
		skitter.play()
	var chasing := state == State.CHASE or climbing
	skitter.volume_db = -14.0 if on_ceiling and not climbing else (-3.0 if chasing else -9.0)
	skitter.pitch_scale = 1.35 if chasing else 1.0
