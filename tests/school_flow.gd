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
	change_scene_to_file("res://abandoned_school.tscn")
	await scene_changed
	await frames(8)
	var school = current_scene
	check(school.name == "AbandonedSchool", "The abandoned school loads")
	check(school.get_node_or_null("01_CourtyardAndMainHall/HallPillar_0_-1") != null, "Hall columns are editable nodes")
	check(school.get_node_or_null("02_ClassroomsAndClues/ClassroomEast_02") != null, "Classrooms are editable nodes")
	school.begin_game()
	await frames(30)
	check(school.player.is_on_floor(), "The player stands on the school floor")
	school.player.global_position = Vector3(10.5, 0.12, -53.0)
	await frames(3)
	school.interact()
	check(school.story_stage == 1, "The diary moves the story forward")
	school.player.global_position = Vector3(-10.6, 0.12, -99.5)
	await frames(3)
	school.interact()
	check(school.story_stage == 2, "The archive key opens the next objective")
	school.player.global_position = Vector3(0, 0.12, -133.0)
	await frames(3)
	school.interact()
	check(school.story_stage == 3, "The announcement activates the exit")
	school.player.global_position = Vector3(0, 0.12, -140.0)
	await frames(3)
	school.interact()
	await scene_changed
	await frames(4)
	check(current_scene.name == "GardenLobby", "School exit returns to the lobby")
	check(current_scene.menu_title.text.contains("โรงเรียน"), "Lobby recognizes school completion")
	print("EXITROOM_SCHOOL_TEST_FAILURES=", failures)
	quit(1 if failures else 0)
