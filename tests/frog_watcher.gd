extends SceneTree

class TestGame extends Node3D:
	var playing := true

var failures := 0
var vanished_count := 0
var relocated_count := 0
var settled_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame

func solid(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func new_fixture(wall: bool) -> TestGame:
	var fixture := TestGame.new()
	root.add_child(fixture)
	solid(fixture, Vector3(0, -0.25, 0), Vector3(40, 0.5, 40))
	if wall:
		solid(fixture, Vector3(0, 1, 0), Vector3(6, 2, 0.4))
	return fixture

func make_player(fixture: Node, pos: Vector3) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.game = fixture
	p.position = pos
	fixture.add_child(p)
	return p

func make_frog(fixture: Node, player: Node3D, pos: Vector3, use_nav := false) -> CharacterBody3D:
	var f := CharacterBody3D.new()
	f.set_script(load("res://scripts/frog_watcher.gd"))
	f.game = fixture
	f.target = player
	f.position = pos
	if use_nav:
		f.bounds = Rect2(-12, -12, 24, 24)
	fixture.add_child(f)
	f.vanished.connect(func(): vanished_count += 1)
	f.relocated.connect(func(_p): relocated_count += 1)
	f.settled.connect(func(): settled_count += 1)
	return f

func yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

func body_error(frog: Node3D, player: Node3D) -> float:
	var d := player.global_position - frog.global_position
	d.y = 0.0
	var forward := -frog.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized().angle_to(d.normalized())

func flat_distance(a: Node3D, b: Node3D) -> float:
	var d := a.global_position - b.global_position
	d.y = 0.0
	return d.length()

func run() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "flashlight", "interact", "pause_game"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	# 1. Model, clips and head tracker
	var fx := new_fixture(false)
	var player := make_player(fx, Vector3(0, 0.15, 0))
	var frog := make_frog(fx, player, Vector3(0, 0.05, -14))
	await frames(10)
	check(frog.skeleton != null and frog.skeleton.get_bone_count() == 50, "Frog skeleton (50 bones) is found")
	check(frog.anim_names.has("idle") and frog.anim_names.has("walk") and frog.anim_names.has("sit"), "Idle, walk and sit clips are found")
	check(frog.tracker != null, "Head tracker is attached")
	fx.queue_free()
	await frames(2)

	# 2. The head follows the player even when the body does not turn
	fx = new_fixture(false)
	player = make_player(fx, Vector3(-4, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, 0))
	frog.turn_body = false
	frog.approach_enabled = false
	await frames(90)
	check(body_error(frog, player) > 1.3, "Body is not turned toward the player in this test")
	var tracked: float = frog.head_error()
	check(tracked < 0.45, "Head turns toward the player (error %.2f rad)" % tracked)
	await frames(120)
	check(frog.head_error() < 0.45, "Head tracking stays steady over time (error %.2f rad)" % frog.head_error())
	frog.head_tracking = false
	await frames(90)
	check(frog.head_error() > 1.0, "Head returns to the animated pose when tracking is off")
	fx.queue_free()
	await frames(2)

	# 3. Walks up to its viewing distance and stops there
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -14))
	settled_count = 0
	var closest := 99.0
	var walked_anim := false
	for i in 720:
		await physics_frame
		closest = minf(closest, flat_distance(frog, player))
		if frog.current_anim == frog.anim_names.get("walk", &"") and frog.player_animation.speed_scale > 0.3:
			walked_anim = true
	var d: float = flat_distance(frog, player)
	check(walked_anim, "Walk clip plays while it approaches")
	check(d > 3.0 and d < 4.1, "Settles near its viewing distance (%.2f m)" % d)
	check(closest > 3.0, "Never comes closer than the minimum (%.2f m)" % closest)
	check(settled_count >= 1 and frog.move_state == frog.Move.HOLD, "Settled signal emitted and it stands still")
	check(body_error(frog, player) < 0.4, "Faces the player while watching")
	check(frog.current_anim == frog.anim_names["idle"], "Idle clip plays while it watches")
	# 4. Backs away when the player steps toward it
	player.global_position = frog.global_position + Vector3(0, 0.15, 1.5)
	player.velocity = Vector3.ZERO
	var reversed := false
	var closest2 := 99.0
	for i in 420:
		await physics_frame
		closest2 = minf(closest2, flat_distance(frog, player))
		if frog.player_animation.speed_scale < -0.3:
			reversed = true
	d = flat_distance(frog, player)
	check(reversed, "Walks backwards (clip played in reverse) to back away")
	check(d > 3.0, "Restores its distance after the player steps close (%.2f m)" % d)
	check(body_error(frog, player) < 0.5, "Keeps facing the player while backing away")
	fx.queue_free()
	await frames(2)

	# 5. Goes around a wall to get to its viewing spot
	fx = new_fixture(true)
	player = make_player(fx, Vector3(0, 0.15, 6))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6), true)
	var widest := 0.0
	for i in 900:
		await physics_frame
		widest = maxf(widest, absf(frog.global_position.x))
	d = flat_distance(frog, player)
	check(widest > 2.9, "Detours around the wall (max |x| %.1f)" % widest)
	check(d < 4.6, "Reaches viewing distance on the far side of the wall (%.2f m)" % d)
	fx.queue_free()
	await frames(2)

	# 6. Being seen: in view, out of view, behind a wall
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(4)
	check(frog.is_seen(), "Frog is seen when the player faces it")
	player.pivot.rotation.y += PI
	await frames(4)
	check(not frog.is_seen(), "Frog is not seen when the player faces away")
	fx.queue_free()
	await frames(2)
	fx = new_fixture(true)
	player = make_player(fx, Vector3(0, 0.15, 5))
	frog = make_frog(fx, player, Vector3(0, 0.05, -5))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(4)
	check(not frog.is_seen(), "Frog behind a wall is not seen")
	fx.queue_free()
	await frames(2)

	# 7. Moves only while unseen
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -8))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	relocated_count = 0
	var target_point := Vector3(0, 0.05, -4)
	frog.relocate_when_unseen(target_point, 0.3)
	await frames(90)
	check(relocated_count == 0 and frog.global_position.distance_to(Vector3(0, 0.05, -8)) < 0.3, "Does not move while the player is looking at it")
	player.pivot.rotation.y += PI
	await frames(60)
	check(relocated_count == 1 and frog.global_position.distance_to(target_point) < 0.3, "Jumps to the next spot once the player looks away")
	fx.queue_free()
	await frames(2)

	# 8. Vanishes when looked at from close range, and can reappear
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position) + PI
	vanished_count = 0
	frog.vanish_when_seen_within(8.0, 0.2)
	await frames(60)
	check(vanished_count == 0 and frog.visible, "Stays while the player is not looking")
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(60)
	check(vanished_count == 1 and not frog.visible, "Vanishes once the player looks at it")
	frog.appear_at(Vector3(3, 0.05, -3))
	check(frog.visible and frog.global_position.distance_to(Vector3(3, 0.05, -3)) < 0.1, "Can reappear somewhere else")
	fx.queue_free()
	await frames(2)

	# 9. Sitting (passenger seat)
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -10))
	await frames(10)
	frog.sit()
	var seat := frog.global_position
	await frames(90)
	check(frog.current_anim == frog.anim_names["sit"], "Sit clip plays")
	check(frog.global_position.distance_to(seat) < 0.05, "Does not walk while sitting")
	frog.stand()
	await frames(10)
	check(frog.current_anim != frog.anim_names["sit"], "Stands up again")
	fx.queue_free()
	await frames(2)

	print("EXITROOM_FROG_TEST_FAILURES=", failures)
	quit(1 if failures > 0 else 0)
