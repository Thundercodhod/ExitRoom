extends SceneTree

class TestGame extends Node3D:
	var playing := true

var failures := 0
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	if not ok:
		failures+=1

func frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame

func solid(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body:=StaticBody3D.new()
	body.position=pos
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	collision.shape=shape
	body.add_child(collision)
	parent.add_child(body)

var k := 1.0

func run() -> void:
	for action in ["forward","back","left","right","sprint","flashlight","interact","pause_game"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var fixture:=TestGame.new()
	root.add_child(fixture)
	solid(fixture,Vector3(0,-0.25,-3),Vector3(12,0.5,20))
	solid(fixture,Vector3(0,0.11,-2),Vector3(3,0.22,2))
	solid(fixture,Vector3(0,1,-5),Vector3(3,2,0.4))
	player=CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.game=fixture
	player.position=Vector3(0,0.15,0)
	fixture.add_child(player)
	# Walking durations below were tuned for the old 2.65 m/s walk; scale them so
	# the same distances are covered at the current walking speed.
	k = 2.65 / player.WALK_SPEED
	await frames(20)
	check(player.third_person and player.body_visual.visible, "Third-person view shows the character by default")
	check(player.camera.global_position.distance_to(player.pivot.global_position) > 0.5, "Third-person camera sits behind the player")
	check(player.player_animation != null and player.anim_names.has("idle") and player.anim_names.has("walk") and player.anim_names.has("run"), "Idle, walk and run clips are found")
	player.set_third_person(false)
	await frames(3)
	check(player.camera.get_parent() == player.spring_arm and absf(player.camera.global_position.y - player.global_position.y - 1.55) < 0.02, "First-person camera stays at player eye height")
	check(not player.body_visual.visible, "Character does not block the first-person view")
	player.set_third_person(true)
	await frames(3)
	check(player.is_on_floor(),"Player starts grounded")
	Input.action_press("forward")
	await frames(int(62 * k))
	Input.action_release("forward")
	check(player.position.z < -1.5 and player.position.y > 0.15,"Walks onto a 22 cm raised floor without jumping")
	Input.action_press("forward")
	await frames(int(100 * k))
	Input.action_release("forward")
	check(player.position.z > -4.65 and player.position.z < -4.3,"Tall wall still blocks movement")
	player.position=Vector3(4,0.15,0)
	player.velocity=Vector3.ZERO
	await frames(20)
	var start_y:=player.position.y
	Input.action_press("jump")
	await frames(14)
	check(player.position.y > start_y+0.55,"Space action jumps above a half-metre ledge")
	Input.action_release("jump")
	await frames(60)
	check(player.is_on_floor() and absf(player.position.y-start_y)<0.06,"Player lands after jumping")
	fixture.queue_free()
	await frames(2)
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	current_scene.begin_game()
	player=current_scene.player
	player.position=Vector3(24,0.1,-133)
	await frames(15)
	Input.action_press("forward")
	await frames(int(320 * k))
	Input.action_release("forward")
	print("HOUSE ROUTE END ",player.position)
	check(player.position.z < -140,"Walks from the village path through grandma's doorway")
	check(player.position.z < -146.5,"Can reach the furnished kitchen from the front entrance")
	Input.action_press("forward")
	await frames(int(20 * k))
	Input.action_release("forward")
	Input.action_press("left")
	await frames(int(10 * k))
	Input.action_release("left")
	current_scene.interact()
	check(current_scene.story_stage==1,"Can collect the cassette after physically walking into the kitchen")
	Input.action_press("right")
	await frames(int(10 * k))
	Input.action_release("right")
	Input.action_press("back")
	await frames(int(250 * k))
	Input.action_release("back")
	print("HOUSE EXIT END ",player.position)
	check(player.position.z > -139,"Can leave the house again through the same doorway")
	print("EXITROOM_TRAVERSAL_FAILURES=",failures)
	quit(1 if failures else 0)
