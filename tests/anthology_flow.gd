extends SceneTree
## Integration contract for the anthology; preserves the user's preferences.
const PROTECTED_TEXT := {
	"res://scripts/frog_watcher.gd":"cc2f6f431fcc906e0ab62383c80f09e4500773aa720f61f442ca7e2ca117d1bf",
	"res://scripts/frog_head_tracker.gd":"2026ceddd95f530db638888cdaa3baad31823ac2f94a2a78fba7eb58cf390ac3",
	"res://scripts/frog_test.gd":"dab7f3b614e11a1815781aeb74f10035270fd50e9475dd5c4da1f78f541a062a",
	"res://tests/frog_watcher.gd":"2b1e6130d98decf7e27627b394e713da2fc84addf8faf466c81f73b9794f80ac",
	"res://frog_test.tscn":"afa9a0cf886be014a3df5d92212a18f6813c36560cfe004fefe96c87c5aef556",
	"res://assets/models/enemy/frog.glb.import":"900fb7db8051c7d0c924392eeca7085fff561e11a636a76908c08c9c6efeec70"
}
const ORIGINAL_FROG_MODEL_SHA := "f3706fab50332c1fe96acb7621a68497e7eb149bbf6c4a6772f952a0d398a315"
var failures := 0
var anthology: Node
var had_preferences := false
var original_preferences := ""
var finishing := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1

func frames(count := 3) -> void:
	for i in count: await process_frame

func wait_scene(path: String) -> bool:
	var deadline := Time.get_ticks_msec()+12000
	while Time.get_ticks_msec()<deadline:
		if current_scene and current_scene.scene_file_path==path and not anthology.changing:
			await frames(4)
			return true
		await process_frame
	check(false,"scene loads within 12 seconds: "+path)
	return false

func wait_condition(condition: Callable, label: String, seconds := 25.0) -> bool:
	var deadline := Time.get_ticks_msec()+int(seconds*1000.0)
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	var ok: bool = condition.call()
	check(ok,label)
	return ok

func keep_preferences() -> void:
	had_preferences = FileAccess.file_exists("user://anthology.cfg")
	if had_preferences: original_preferences = FileAccess.get_file_as_string("user://anthology.cfg")

func restore_preferences() -> void:
	if had_preferences:
		var file := FileAccess.open("user://anthology.cfg",FileAccess.WRITE)
		if file: file.store_string(original_preferences)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://anthology.cfg"))

func finish() -> void:
	if finishing: return
	finishing = true
	if anthology: anthology.close_modal(false)
	paused = false
	restore_preferences()
	print("ANTHOLOGY_FAILURES=",failures)
	quit(1 if failures else 0)

func verify_resources() -> void:
	for key in ["ui_move","ui_accept","tape","knock","message","door","sting","fluorescent","low_pulse","menu_ambience"]:
		var path: String = "res://audio/anthology/"+key+".wav"
		check(ResourceLoader.exists(path),"sound resource exists: "+key)
		if ResourceLoader.exists(path):
			var clip := load(path) as AudioStream
			check(clip!=null and clip.get_length()>0.0,"sound contains playable audio: "+key)
	for file in ["ChakraPetch-Regular.ttf","ChakraPetch-Bold.ttf"]:
		var path: String = "res://ui/fonts/"+file
		check(ResourceLoader.exists(path),"bundled story font exists: "+file)
		if ResourceLoader.exists(path):
			var font := load(path) as Font
			var supports_thai := font!=null
			for letter in "ผู้โดยสารบ้านที่ยังรอกะสุดท้ายห้องที่ไม่มีใครเช่า":
				if font==null or not font.has_char(letter.unicode_at(0)): supports_thai = false
			check(supports_thai,"Thai characters and combining marks covered: "+file)
	for path in PROTECTED_TEXT:
		var normalized := FileAccess.get_file_as_string(path).replace("\r\n","\n")
		check(normalized.sha256_text()==PROTECTED_TEXT[path],"protected original unchanged: "+path)
	check(FileAccess.get_sha256("res://assets/models/enemy/frog.glb")==ORIGINAL_FROG_MODEL_SHA,"original frog model bytes unchanged")

func test_menu() -> bool:
	if not await wait_scene(anthology.MENU): return false
	var menu := current_scene
	var has_navigation := menu.has_method("select_episode") and menu.has_method("show_page") and menu.has_method("play_selected")
	check(has_navigation,"menu exposes working episode navigation")
	if not has_navigation: return false
	check(menu.find_children("*","Button",true,false).size()>=4,"menu has usable navigation buttons")
	for section in ["episodes","options","credits","home"]:
		menu.show_page(section)
		await frames()
		check(menu.page==section and menu.pages[section].visible,"menu opens "+section)
	menu.show_page("options")
	var slider := menu.pages.options.get_node("masterSlider") as HSlider
	slider.value = 37
	check(is_equal_approx(anthology.settings.master,.37),"settings slider updates master volume")
	var instant := menu.pages.options.get_node("instant_textToggle") as CheckButton
	instant.button_pressed = true
	check(anthology.settings.instant_text,"reading toggle updates instant-text option")
	menu.show_page("episodes")
	return true

func check_ending(id: String, original_scene: Node) -> void:
	await wait_condition(func(): return anthology.modal_kind=="ending" and not anthology.changing,"ending transition completes: "+id)
	check(current_scene==original_scene,"episode ending stays independent: "+id)
	check(anthology.modal_kind=="ending" and anthology.modal!=null,"ending presents anthology overlay: "+id)
	check(anthology.completed.has(id),"completion recorded: "+id)
	check(paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"ending freezes play and releases mouse: "+id)
	var persisted := ConfigFile.new()
	check(persisted.load("user://anthology.cfg")==OK and id in persisted.get_value("progress","completed",[]),"completion persisted: "+id)

func ending_menu() -> bool:
	if anthology.modal:
		var button := anthology.modal.find_child("EpisodeMenuButton",true,false) as Button
		check(button!=null,"ending has a return-to-episodes button")
		if button: button.pressed.emit()
		else: anthology.return_to_menu()
	else: anthology.return_to_menu()
	var loaded := await wait_scene(anthology.MENU)
	check(not paused and anthology.modal==null and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"menu restores input and clears paused overlay")
	if loaded: check(current_scene.page=="episodes","return opens episode selection directly")
	return loaded

func test_last_visit(scene: Node) -> void:
	check(scene.overlay.visible and not scene.playing,"Last Visit starts at a readable introduction")
	check(scene.intro_copy.text.contains("ธาม"),"Last Visit names its own protagonist")
	await scene.begin_game()
	scene.player.global_position = scene.BACK_DOOR
	scene.interact()
	check(scene.story_stage==0,"Last Visit cannot skip its evidence")
	scene.player.global_position = scene.CASSETTE
	scene.interact()
	check(scene.story_stage==1,"cassette advances first independent story beat")
	scene.player.global_position = scene.MARBLE
	scene.interact()
	check(scene.story_stage==2,"marble unlocks the last door")
	scene.player.global_position = scene.BACK_DOOR
	scene.interact()
	await check_ending("last_visit",scene)

func test_after_hours(scene: Node) -> void:
	check(scene.overlay.visible and not scene.playing,"After Hours starts at a readable introduction")
	check(scene.intro_copy.text.contains("ริน"),"After Hours names its own protagonist")
	scene.player.global_position = scene.EXIT
	var use := InputEventAction.new()
	use.action = "interact"
	use.pressed = true
	scene._unhandled_input(use)
	check(not scene.finished and anthology.modal==null,"After Hours cannot exit from its introduction")
	await scene.begin_game()
	anthology.show_pause()
	check(paused and anthology.modal_kind=="pause","global pause works within an episode")
	anthology.close_modal()
	check(not paused and scene.playing,"global pause restores active gameplay")
	scene._unhandled_input(use)
	await check_ending("after_hours",scene)

func test_room407(scene: Node) -> void:
	check(scene.title_screen.visible and scene.player.locked,"Room407 starts at its own locked title")
	await scene.start()
	scene.interact("future_note")
	check(scene.stage==0 and anthology.modal==null,"Room407 final note cannot skip earlier evidence")
	scene.interact("note")
	scene.interact("unpack")
	await scene.sleep_transition()
	await scene.interact("door407")
	await scene.sleep_transition()
	scene.interact("wall")
	await scene.sleep_transition()
	await scene.reveal()
	scene.interact("future_note")
	await frames()
	check(scene.stage==9,"Room407 completes its two-night story")
	check(not scene.episode_finished,"Room407 leaves the final document readable before ending")
	scene.interact("future_note")
	await check_ending("room407",scene)

func test_passenger(scene: Node) -> void:
	check(scene.panel.visible and not scene.playing,"Passenger starts at its own introduction")
	check(scene.panel_text.text.contains("ภาคิน") and not scene.panel_text.text.contains("โรงแรม"),"Passenger introduces a standalone driver")
	await scene.panel_continue()
	anthology.settings.instant_text = true
	scene.say("ทดสอบข้อความภาษาไทย")
	check(scene.subtitle.visible_characters==-1,"Passenger honors instant story text preference")
	anthology.settings.instant_text = false
	scene.say("ทดสอบข้อความภาษาไทย")
	check(scene.subtitle.visible_characters==0,"Passenger supports typed story subtitles")
	# Full traversal remains in tests/frog_chapter.gd; exercise the real repair
	# interaction and final cinematic here to verify the anthology boundary.
	scene.stage = scene.Stage.RETURN
	scene.player.position = Vector3(.3,.05,1.8)
	scene.interact("car")
	await wait_condition(func(): return scene.ending_presented,"Passenger repair and passenger cinematic reach ending")
	check(scene.stage==scene.Stage.END and scene.frog.mode==scene.frog.Mode.SITTING,"Passenger preserves repaired-car/frog-seat final sequence")
	await check_ending("passenger",scene)

func test_persistence() -> void:
	var expected_completed: Array = anthology.completed.duplicate()
	anthology.settings.master = .37
	anthology.settings.ambience = .28
	anthology.settings.instant_text = true
	anthology.settings.reduced_motion = true
	anthology.save_preferences()
	anthology.settings.master = .8
	anthology.settings.ambience = .7
	anthology.settings.instant_text = false
	anthology.settings.reduced_motion = false
	anthology.completed.clear()
	anthology.load_preferences()
	check(is_equal_approx(anthology.settings.master,.37) and is_equal_approx(anthology.settings.ambience,.28),"saved audio preferences reload")
	check(anthology.settings.instant_text and anthology.settings.reduced_motion,"saved readability preferences reload")
	check(anthology.completed==expected_completed and anthology.completed.size()==4,"all four completions reload without duplicates")
	anthology.apply_preferences()
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))),.37),"master volume preference reaches audio mixer")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))),.28),"ambience preference reaches separate mixer bus")

func run() -> void:
	keep_preferences()
	create_timer(100.0).timeout.connect(func(): check(false,"suite finishes within 100 seconds"); finish())
	anthology = root.get_node_or_null("Anthology")
	if not anthology:
		check(false,"Anthology autoload is configured")
		finish()
		return
	verify_resources()
	anthology.completed.clear()
	anthology.settings.reduced_motion = false
	check(ProjectSettings.get_setting("application/run/main_scene")==anthology.MENU,"F5 opens the anthology menu")
	change_scene_to_file(anthology.MENU)
	if not await test_menu():
		finish()
		return
	for index in anthology.EPISODES.size():
		var entry: Dictionary = anthology.EPISODES[index]
		var menu := current_scene
		menu.show_page("episodes")
		menu.select_episode(index)
		menu.play_selected()
		check(anthology.changing and paused and current_scene==menu,"scene change first freezes outgoing scene under a fade")
		anthology.launch_episode("passenger")
		check(anthology.selected_id==entry.id,"second launch is ignored during transition")
		if not await wait_scene(entry.scene): break
		check(anthology.selected_id==entry.id,"selection launches requested episode: "+entry.id)
		match entry.id:
			"last_visit": await test_last_visit(current_scene)
			"after_hours": await test_after_hours(current_scene)
			"room407": await test_room407(current_scene)
			"passenger": await test_passenger(current_scene)
		if not await ending_menu(): break
	test_persistence()
	finish()
