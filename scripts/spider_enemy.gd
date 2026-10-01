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

signal caught_player

const SpiderModel = preload("res://assets/models/enemy/spider.glb")

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
	var model := SpiderModel.instantiate() as Node3D
	model.name = "SpiderModel"
	add_child(model)
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
