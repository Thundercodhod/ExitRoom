extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(8)
	var lobby = current_scene
	check(lobby.name == "GardenLobby" and lobby.overlay.visible, "Garden opens as the lobby")
	check(lobby.player.body_visual.find_child("HazmatDemo", true, false) != null, "Hazmat is available in the lobby")
	lobby.begin_roaming()
	await frames(35)
	check(lobby.player.is_on_floor(), "Garden has a walkable floor")
	lobby.player.position = Vector3(5.2, 0.12, -5.8)
	await frames(2)
	check(lobby.prompt.text.contains("BACKROOMS"), "Lobby start marker offers level one")
	lobby.start_level_one()
	await scene_changed
	await frames(35)
	var level = current_scene
	check(level.name == "BackroomsLevel01" and level.playing, "Backrooms starts directly from lobby")
	check(level.player.is_on_floor(), "Hazmat stands on Backrooms floor")
	var initial: Vector3 = level.player.position
	Input.action_press("forward")
	await frames(40)
	Input.action_release("forward")
	check(level.player.position.distance_to(initial) > 0.4, "Player moves through level one")
	level.player.position = Vector3(-10.5, 0.1, 10.5)
	await frames(2)
	check(level.prompt.text.contains("E"), "Backrooms exit can be activated")
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	level._unhandled_input(event)
	await scene_changed
	await frames(3)
	check(current_scene.name == "GardenLobby", "Exit returns to the garden lobby")
	check(current_scene.menu_title.text.contains("สำเร็จ"), "Lobby acknowledges level completion")
	print("EXITROOM_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
