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
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	await frames(8)
	var scene = current_scene
	check(scene.name == "VillagePrologue", "The village prologue scene loads")
	check(scene.get_node_or_null("01_LandAndRoad/RoadSection_00") != null, "The long road is editable geometry")
	check(scene.get_node_or_null("02_HousesAndVillageLandmarks/GrandmaHouse_Editable") != null, "Grandma's house is editable geometry")
	check(scene.player.body_visual.find_child("HazmatDemo", true, false) != null, "The temporary player is present")
	scene.begin_game()
	await frames(20)
	check(scene.player.is_on_floor(), "The player stands on the village terrain")
	var before: Vector3 = scene.player.global_position
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	check(scene.player.global_position.distance_to(before) > 0.4, "The player walks along the road")
	scene.player.global_position = Vector3(23.5, 0.12, -148.0)
	await frames(3)
	scene.interact()
	check(scene.story_stage == 1, "Listening to the cassette advances the story")
	scene.player.global_position = Vector3(35, 0.12, -154)
	await frames(3)
	scene.interact()
	check(scene.story_stage == 2, "Finding the marble unlocks the garden gate")
	scene.player.global_position = Vector3(23, 0.12, -169.5)
	await frames(3)
	scene.interact()
	await scene_changed
	await frames(4)
	check(current_scene.name == "GardenLobby", "The garden gate enters the lobby")
	check(current_scene.menu_title.text.contains("สวนที่ไม่ควร"), "The lobby acknowledges the prologue")
	print("EXITROOM_PROLOGUE_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
