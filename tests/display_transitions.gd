extends SceneTree
## Run with a real renderer: checks OS fullscreen, persistence, and visible fades.
var failures := 0
var anthology: Node
var saved := ""
var had_save := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1

func settle() -> void:
	for i in 5: await process_frame
	await create_timer(.2).timeout

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.buildtmp/"+name+".png")

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This test requires a real window.")
		quit(1)
		return
	had_save = FileAccess.file_exists("user://anthology.cfg")
	if had_save: saved = FileAccess.get_file_as_string("user://anthology.cfg")
	anthology = root.get_node("Anthology")
	await settle()
	await anthology.set_fullscreen(false)
	change_scene_to_file(anthology.MENU)
	await scene_changed
	await settle()
	var menu := current_scene
	menu.show_page("options")
	var toggle: CheckButton = menu.pages.options.get_node("fullscreenToggle")
	var original_size := DisplayServer.window_get_size()
	toggle.button_pressed = true
	while anthology.display_busy: await process_frame
	await settle()
	check(anthology.is_fullscreen() and toggle.button_pressed,"options toggle enters actual OS fullscreen")
	check(DisplayServer.window_get_size()==DisplayServer.screen_get_size(DisplayServer.window_get_current_screen()),"fullscreen covers the active monitor")
	await shot("fullscreen-options")
	menu.pages.options.get_node("masterSlider").value = 43
	check(anthology.is_fullscreen(),"changing audio does not reset the window mode")
	var prefs := ConfigFile.new()
	prefs.load("user://anthology.cfg")
	check(prefs.get_value("settings","fullscreen",false),"verified fullscreen preference is saved")
	var key := InputEventKey.new()
	key.keycode = KEY_F11
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	while anthology.display_busy: await process_frame
	check(not anthology.is_fullscreen() and not toggle.button_pressed,"F11 exits fullscreen and synchronizes toggle")
	check(DisplayServer.window_get_size()==original_size,"windowed size is restored")
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.alt_pressed = true
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	while anthology.display_busy: await process_frame
	check(anthology.is_fullscreen(),"Alt+Enter enters fullscreen")
	await anthology.set_fullscreen(false)
	menu.show_page("episodes")
	menu.select_episode(2,false)
	menu.play_selected()
	await create_timer(.5).timeout
	check(anthology.changing and anthology.curtain.color.a>.95,"start fades through an opaque frame")
	await shot("transition-start")
	while anthology.changing: await process_frame
	check(not anthology.transition_layer.visible and not paused,"fade reveals the new scene and releases pause")
	await current_scene.start()
	check(current_scene.started and not current_scene.player.locked,"intro fade restores gameplay controls")
	await shot("dialogue-room407")
	await anthology.return_to_menu()
	check(current_scene.page=="episodes" and not anthology.changing,"return transition reaches the selector")
	if had_save:
		FileAccess.open("user://anthology.cfg",FileAccess.WRITE).store_string(saved)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://anthology.cfg"))
	print("DISPLAY_TRANSITION_FAILURES=",failures)
	quit(failures)
