extends SceneTree
## Run with: Godot --headless --path . --script tests/episode_village_backrooms.gd
## Records completion in memory; never writes anthology progress.

class RecordingAnthology extends Node:
	var completions: Array[String] = []
	var sounds: Array[String] = []
	var settings := {"instant_text": true}
	func play_sfx(key: String, _volume: float = -18.0) -> void:
		sounds.append(key)
	func complete_episode(id: String, _narrative: String) -> void:
		completions.append(id)
	func return_to_menu() -> void:
		pass

var errors: Array[String] = []
var recorded: RecordingAnthology

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)
		push_error(message)

func run_checks() -> void:
	var actual := root.get_node_or_null("Anthology")
	if actual:
		actual.name = "AnthologyOutsideThisTest"
		recorded = RecordingAnthology.new()
		recorded.name = "Anthology"
		root.add_child(recorded)
	else:
		recorded = RecordingAnthology.new()
		recorded.name = "Anthology"
		root.add_child(recorded)

	var village: Node = load("res://prologue_village.tscn").instantiate()
	root.add_child(village)
	await process_frame
	check(not village.playing, "Village must open on its standalone introduction")
	check(not village.player.third_person, "Village must start in first person")
	check(village.get_node("04_StoryObjectsAndExit/CassetteInteraction/CassetteText").text == "เทปที่เปิดค้างไว้", "Cassette retains an old campaign sign")
	check(village.get_node("04_StoryObjectsAndExit/DoorToBackrooms/FaintMessage").text == "อย่าออกประตูหน้า", "Back door retains an old campaign sign")
	var marble: Node3D = village.get_node("04_StoryObjectsAndExit/BlueMarbleInteraction")
	check(marble.visible and marble.global_position.distance_to(village.CASSETTE) < 1.0, "Marble must be seen inside before the tape moves it")
	village.begin_game()
	village.interact()
	check(village.story_stage == 0, "Tape must not activate from spawn")
	village.player.global_position = village.CASSETTE
	village.interact()
	check(village.story_stage == 1 and marble.global_position.is_equal_approx(village.MARBLE), "Tape must move the same marble outside")
	check(recorded.sounds.has("tape"), "Tape interaction must cue audio")
	village.show_intro()
	var paused_clock: float = village.atmosphere_clock
	village._process(30.0)
	check(village.atmosphere_clock == paused_clock, "Village scares must stop while paused")
	village.begin_game()
	village.player.global_position = village.MARBLE
	village.interact()
	check(village.story_stage == 2 and not marble.visible, "Collecting marble must enable the ending route")
	village.player.global_position = village.BACK_DOOR
	village.interact()
	check(village.finished and not village.playing, "Village ending must stop player control")
	check(recorded.completions == ["last_visit"], "Village must complete its own episode")
	village.interact()
	check(recorded.completions.size() == 1, "Village ending cannot repeat on interaction")
	village.queue_free()
	await process_frame

	var backrooms: Node = load("res://backrooms_level.tscn").instantiate()
	root.add_child(backrooms)
	await process_frame
	check(not backrooms.playing and not backrooms.player.third_person, "Backrooms must open in first person on its own introduction")
	var sign := backrooms.get_node("Level01Exit").find_children("*", "Label3D", true, false)[0] as Label3D
	check(sign.text == "EXIT\nSTAFF ONLY", "Backrooms exit must not promise another campaign level")
	backrooms.begin_game()
	# Headless has no pointer capture; emulate the in-game capture transition.
	backrooms.was_captured = false
	backrooms._process(19.0)
	check(backrooms.story_beat == 1, "The first announcement must occur during play")
	backrooms.show_intro()
	var paused_elapsed: float = backrooms.elapsed
	backrooms._process(30.0)
	check(backrooms.elapsed == paused_elapsed, "Backrooms story events must stop while paused")
	backrooms.begin_game()
	var use := InputEventAction.new()
	use.action = "interact"
	use.pressed = true
	backrooms._unhandled_input(use)
	check(not backrooms.finished, "Backrooms exit cannot trigger from spawn")
	backrooms.player.global_position = backrooms.EXIT
	backrooms._unhandled_input(use)
	check(backrooms.finished and not backrooms.playing, "Backrooms exit must stop player control")
	check(recorded.completions == ["last_visit", "after_hours"], "Backrooms must end independently")
	backrooms.finish_episode()
	check(recorded.completions.size() == 2, "Backrooms ending cannot repeat")
	backrooms.queue_free()
	await process_frame
	recorded.queue_free()
	await process_frame
	if actual:
		actual.name = "Anthology"
	if errors.is_empty():
		print("PASS: village and Backrooms independent progression, signs, first person, pause and completion")
	quit(0 if errors.is_empty() else 1)
