extends SceneTree

class TestGame extends Node3D:
	var playing := true

var failures := 0
var catches := 0

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

func make_player(fixture: Node, pos: Vector3) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.game = fixture
	p.position = pos
	fixture.add_child(p)
	return p

func make_spider(fixture: Node, player: Node3D, pos: Vector3, yaw: float) -> CharacterBody3D:
	var s := CharacterBody3D.new()
	s.set_script(load("res://scripts/spider_enemy.gd"))
	s.game = fixture
	s.target = player
	s.bounds = Rect2(-12, -12, 24, 24)
	s.start_far_from_target = false
	s.position = pos
	s.rotation.y = yaw
	fixture.add_child(s)
	s.caught_player.connect(func(): catches += 1)
	return s

func new_fixture(wall: bool) -> TestGame:
	var fixture := TestGame.new()
	root.add_child(fixture)
	solid(fixture, Vector3(0, -0.25, 0), Vector3(30, 0.5, 30))
	if wall:
		solid(fixture, Vector3(0, 1, 0), Vector3(3, 2, 0.4))
	return fixture

func run() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "flashlight", "interact", "pause_game"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	# 1. Patrols on its own when the player is far away.
	var fx := new_fixture(false)
	var player := make_player(fx, Vector3(10, 0.15, 10))
	var spider := make_spider(fx, player, Vector3(-8, 0.05, -8), 0.0)
	await frames(8)
	check(spider.grid_ready, "Navigation grid is built")
	check(spider.player_animation != null and spider.anim_names.has("idle") and spider.anim_names.has("walk") and spider.anim_names.has("run") and spider.anim_names.has("attack"), "Idle, walk, run and attack clips are found")
	var start := spider.global_position
	await frames(150)
	check(spider.state_name() == "PATROL", "Spider patrols while the player is far away")
	check(spider.global_position.distance_to(start) > 0.5, "Patrolling spider actually moves")
	check(spider.is_on_floor(), "Spider stands on the floor")
	fx.playing = false
	var frozen := spider.global_position
	await frames(30)
	check(spider.global_position.distance_to(frozen) < 0.2, "Spider stops while the game is paused")
	fx.queue_free()
	await frames(2)

	# 2. Sees the player in the open, chases and catches them.
	fx = new_fixture(false)
	catches = 0
	player = make_player(fx, Vector3(0, 0.15, 0))
	spider = make_spider(fx, player, Vector3(0, 0.05, -8), PI)
	await frames(8)
	check(spider.can_see_target(), "Spider sees a player in the open")
	await frames(20)
	check(spider.state_name() == "CHASE", "Spider starts chasing")
	await frames(240)
	check(catches == 1, "Spider catches the player (signal emitted once)")
	check(spider.state_name() == "CAUGHT", "Spider stays in the caught state afterwards")
	fx.queue_free()
	await frames(2)

	# 3. Walks around an obstacle to reach the player.
	fx = new_fixture(true)
	catches = 0
	player = make_player(fx, Vector3(0, 0.15, 3))
	spider = make_spider(fx, player, Vector3(0, 0.05, -3), PI)
	await frames(8)
	check(not spider.can_see_target(), "A wall blocks the line of sight")
	var found: bool = spider.plan_path(player.global_position)
	var detour := false
	for point in spider.path:
		if absf(point.x) > 1.6:
			detour = true
	check(found and detour, "Path goes around the wall instead of through it")
	spider.last_known = player.global_position
	spider.state = spider.State.CHASE
	await frames(330)
	check(catches == 1, "Spider reaches the player around the wall")
	fx.queue_free()
	await frames(2)

	# 4. Hiding, range and noise.
	fx = new_fixture(false)
	catches = 0
	player = make_player(fx, Vector3(0, 0.15, 0))
	spider = make_spider(fx, player, Vector3(0, 0.05, -5), PI)
	await frames(8)
	player.set_hiding(true)
	player.sprinting = true
	check(not spider.can_see_target() and not spider.can_hear_target(), "A hiding player is neither seen nor heard")
	player.set_hiding(false)
	player.sprinting = false
	check(spider.can_see_target(), "Player is seen again after leaving the hiding spot")
	spider.global_position = Vector3(0, 0.05, -20)
	check(not spider.can_see_target(), "Player is out of sight range")
	spider.global_position = Vector3(0, 0.05, -7)
	spider.rotation.y = 0.0
	check(not spider.can_see_target(), "Player behind the spider is not seen")
	check(not spider.can_hear_target(), "Walking is silent")
	player.sprinting = true
	check(spider.can_hear_target(), "Sprinting nearby is heard even from behind")
	fx.queue_free()
	await frames(2)

	print("EXITROOM_SPIDER_TEST_FAILURES=", failures)
	quit(1 if failures > 0 else 0)
