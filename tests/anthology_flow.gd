extends SceneTree
## Integration contract for the anthology; preserves the user's preferences.
# Fingerprints of the frog files. Updated when the frog gained hunt mode, the
# stare threat timer and the choke catch (and the head tracker pose fix); edit
# these on purpose whenever those files are meant to change.
const PROTECTED_TEXT := {
	"res://scripts/frog_watcher.gd":"89bd3f9e15dd588ad84350490d8d59eff5cf4754ff3da00a42ce5db7462dc622",
	"res://scripts/frog_head_tracker.gd":"fc502f04a267c2ebe8bce99fa012da4d6298660004114fb54ad4aa2a012df9f9",
	"res://scripts/frog_test.gd":"f45ac5d12c86ef84771bc5424515d1d39acaa90b3e4260fe283caf008468fd03",
	"res://tests/frog_watcher.gd":"8d06afb8428fca7d9214a2a440e2881041f1018e020aecc86f5c92cd6d2fb6a7",
	"res://frog_test.tscn":"842cb776c7d79745e87816fb916a47132796711b9109a78003e78de95d039b4a",
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
	for key in ["ui_move","ui_accept","tape","knock","message","door","sting","fluorescent","low_pulse"]:
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
	var music: AudioStreamPlayer = anthology.menu_music
	check(music!=null and music.playing and not music.stream_paused,"main menu plays background music")
	check(music!=null and String(music.stream.resource_path).ends_with("menu_music.mp3") and (music.stream as AudioStreamMP3).loop,"menu music is the recorded track and loops")
	check(music!=null and music.bus==&"Music","menu music plays on its own Music bus")
	menu.show_page("options")
	var music_slider := menu.pages.options.get_node("musicSlider") as HSlider
	check(music_slider!=null,"options has a music volume slider")
	if music_slider:
		music_slider.value = 45
		check(is_equal_approx(anthology.settings.music,.45) and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),.45),"music slider sets the Music bus volume")
		music_slider.value = 70
	var slider := menu.pages.options.get_node("masterSlider") as HSlider
	slider.value = 37
	check(is_equal_approx(anthology.settings.master,.37),"settings slider updates master volume")
	var instant := menu.pages.options.get_node("instant_textToggle") as CheckButton
	instant.button_pressed = true
	check(anthology.settings.instant_text,"reading toggle updates instant-text option")
	await frames(2)
	check_hover(slider,"options slider")
	check_hover(instant,"options toggle")
	menu.show_page("episodes")
	await frames(2)
	var box := menu.episode_buttons[1] as Button
	check_hover(box,"episode box")
	var ticks := sfx_count("ui_move")
	box.mouse_entered.emit()
	check(sfx_count("ui_move")==ticks,"sweeping quickly across boxes does not stutter")
	var presses := sfx_count("ui_accept")
	box.pressed.emit()
	check(sfx_count("ui_accept")==presses+1,"pressing an episode box plays the press sound once")
	box.disabled = true
	anthology._last_ui_hover = -1000
	ticks = sfx_count("ui_move")
	box.mouse_entered.emit()
	check(sfx_count("ui_move")==ticks,"a disabled button stays silent")
	box.disabled = false
	return true

# UI sounds playing right now, by file name (each play_sfx adds one player).
func sfx_count(key: String) -> int:
	var n := 0
	for child in anthology.get_children():
		if child is AudioStreamPlayer and child.stream and String(child.stream.resource_path).ends_with("/"+key+".wav"): n += 1
	return n

# The cursor passing over `control` plays exactly one hover tick.
func check_hover(control: Control, label: String) -> void:
	anthology._last_ui_hover = -1000
	var before := sfx_count("ui_move")
	control.mouse_entered.emit()
	check(sfx_count("ui_move")==before+1,"hover sound: "+label)

func check_ending(id: String, original_scene: Node) -> void:
	await wait_condition(func(): return anthology.modal_kind=="ending" and not anthology.changing,"ending transition completes: "+id)
	check(current_scene==original_scene,"episode ending stays independent: "+id)
	check(anthology.modal_kind=="ending" and anthology.modal!=null,"ending presents anthology overlay: "+id)
	check(anthology.completed.has(id),"completion recorded: "+id)
	var ending_button := anthology.modal.find_child("EpisodeMenuButton",true,false) as Button
	if ending_button: check_hover(ending_button,"ending card button ("+id+")")
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
	check(not scene.finished and anthology.modal==null,"After Hours door stays locked until the breaker is reset")
	scene.player.global_position = scene.BREAKER_STAND
	await scene.reset_breaker()
	# Headless has no pointer capture, so the scene pauses itself meanwhile; resume.
	scene._begin_game()
	scene.was_captured = false
	check(scene.power_on and scene.playing,"resetting the breaker powers the fire door")
	scene.player.global_position = scene.EXIT
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
	await wait_condition(func(): return scene.ending_presented,"Passenger repair and passenger cinematic reach ending",40.0)
	check(scene.stage==scene.Stage.END and scene.frog.mode==scene.frog.Mode.SITTING,"Passenger preserves repaired-car/frog-seat final sequence")
	await check_ending("passenger",scene)
	check(anthology.modal.find_child("NextEpisodeButton",true,false)!=null,"Passenger ending offers to continue into Episode 05")
	check(anthology.is_unlocked("forest"),"finishing Passenger unlocks Episode 05")

func test_forest(scene: Node) -> void:
	check(scene.panel.visible and not scene.playing,"Forest starts at its own introduction")
	check(scene.panel_text.text.contains("ภาคิน") and scene.panel_text.text.contains("ปั๊ม"),"Forest continues Phakin's story from Passenger")
	await scene.panel_continue()
	await wait_condition(func(): return scene.stage==scene.Stage.WALK,"Forest wake-up hands control to the player")
	# The full loop (warning, hunt, catch, restart) is covered by tests/forest_loop.gd.
	scene.player.global_position = scene.campfire_spot+Vector3(0,.05,2.4)
	await frames(4)
	scene.sleep_by_fire()
	await wait_condition(func(): return scene.ending_presented,"Forest campfire sleep reaches ending")
	await check_ending("forest",scene)

func test_persistence() -> void:
	var expected_completed: Array = anthology.completed.duplicate()
	anthology.settings.master = .37
	anthology.settings.ambience = .28
	anthology.settings.music = .33
	anthology.settings.instant_text = true
	anthology.settings.reduced_motion = true
	anthology.save_preferences()
	anthology.settings.master = .8
	anthology.settings.ambience = .7
	anthology.settings.music = .7
	anthology.settings.instant_text = false
	anthology.settings.reduced_motion = false
	anthology.completed.clear()
	anthology.load_preferences()
	check(is_equal_approx(anthology.settings.master,.37) and is_equal_approx(anthology.settings.ambience,.28),"saved audio preferences reload")
	check(is_equal_approx(anthology.settings.music,.33),"saved music volume reloads")
	check(anthology.settings.instant_text and anthology.settings.reduced_motion,"saved readability preferences reload")
	check(anthology.completed==expected_completed and anthology.completed.size()==anthology.EPISODES.filter(func(e): return not e.get("free_roam",false)).size(),"all completions reload without duplicates")
	anthology.apply_preferences()
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))),.37),"master volume preference reaches audio mixer")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))),.28),"ambience preference reaches separate mixer bus")

func run() -> void:
	keep_preferences()
	create_timer(160.0).timeout.connect(func(): check(false,"suite finishes within 160 seconds"); finish())
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
	check(not anthology.is_unlocked("forest"),"Episode 05 is locked until Episode 04 is finished")
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
		await wait_condition(func(): return anthology.menu_music.stream_paused,"menu music fades out and pauses in the episode: "+entry.id,4.0)
		var music_at: float = anthology.menu_music.get_playback_position()
		match entry.id:
			"last_visit": await test_last_visit(current_scene)
			"after_hours": await test_after_hours(current_scene)
			"room407": await test_room407(current_scene)
			"passenger": await test_passenger(current_scene)
			"forest": await test_forest(current_scene)
		if not await ending_menu(): break
		check(not anthology.menu_music.stream_paused and anthology.menu_music.playing,"menu music comes back with the menu: "+entry.id)
		check(anthology.menu_music.get_playback_position() >= music_at - .05,"menu music carries on instead of restarting: "+entry.id)
		check(anthology.find_children("*","AudioStreamPlayer",false,false).filter(func(n): return n.name.begins_with("MenuMusic")).size()==1,"only one menu music player after returning: "+entry.id)
	test_persistence()
	finish()
