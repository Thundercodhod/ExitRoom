extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(count := 3) -> void:
	for i in count:
		await physics_frame
	await process_frame

func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	await frames()
	var village = current_scene
	village.begin_game()
	village.player.position = village.BACK_DOOR
	village.interact()
	check(village.story_stage == 0, "Back door cannot skip the cassette and marble")
	village.player.position = Vector3(23.5, 0.12, -148.0)
	village.interact()
	check(village.story_stage == 1 and village.clue.text.contains("406"), "Cassette links May's disappearance to room 406")
	village.player.position = village.MARBLE
	village.interact()
	check(village.story_stage == 2 and village.clue.text.contains("เมย์"), "Marble clue is separate from the objective")
	village.player.position = village.BACK_DOOR
	village.interact()
	await scene_changed
	await frames()
	var backrooms = current_scene
	check(backrooms.name == "BackroomsLevel01", "Village transitions directly into Backrooms")
	check(backrooms.overlay.visible, "Backrooms introduction gives time to read")
	backrooms.player.position = backrooms.EXIT
	var use := InputEventAction.new()
	use.action = "interact"
	use.pressed = true
	backrooms._unhandled_input(use)
	await frames()
	check(current_scene == backrooms, "Paused Backrooms cannot trigger the exit")
	backrooms.begin_game()
	backrooms._unhandled_input(use)
	await scene_changed
	await frames()
	var room = current_scene
	check(room.has_node("Room406") and room.has_node("Room407"), "Backrooms exit loads the actual ROOM 407 scene")
	check(room.title_screen.visible and room.player.locked, "ROOM 407 restores title UI and mouse control")
	room.start()
	room.interact("future_note")
	check(room.stage == 0 and not room.ending_screen.visible, "Future note cannot skip the chapter")
	room.interact("note")
	room.interact("unpack")
	await room.sleep_transition()
	await room.interact("door407")
	await room.sleep_transition()
	room.interact("wall")
	await room.sleep_transition()
	await room.reveal()
	room.interact("future_note")
	check(room.stage == 9 and room.ending_screen.visible, "Final note opens the frog bridge")
	check(room.player.locked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Final letter locks movement for reading")
	room.close_ending()
	check(not room.player.locked and not room.ending_screen.visible, "Closing the letter returns control")
	room.interact("future_note")
	check(room.ending_screen.visible, "Final letter can be read again")
	room.restart_story()
	await scene_changed
	await frames()
	check(current_scene.name == "VillagePrologue" and current_scene.story_stage == 0, "Replay starts at grandma's house")
	print("EXITROOM_CAMPAIGN_FAILURES=", failures)
	quit(1 if failures else 0)
