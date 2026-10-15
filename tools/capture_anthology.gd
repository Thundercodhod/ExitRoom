extends SceneTree
## Render real project scenes for the episode selector and visual QA.
var menus_only := false
var only := ""   # --only=<episode id>: render just that preview

func _initialize() -> void:
	menus_only = "--menus" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	call_deferred("run")

func settle() -> void:
	for i in 20: await process_frame
	await create_timer(.35).timeout
	await RenderingServer.frame_post_draw

func save(path: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://ui/previews")
	DirAccess.make_dir_recursive_absolute("res://.buildtmp")
	if "--endings" in OS.get_cmdline_user_args():
		await capture_endings()
		quit()
		return
	if not menus_only:
		var setups := [
			["last_visit","res://levels/01_last_visit/prologue_village.tscn",Vector3(17.5,2,-137),Vector3(24,1.8,-150)],
			["after_hours","res://levels/02_after_hours/backrooms_level.tscn",Vector3(9.5,1.6,-9.5),Vector3(-1,1.6,-3)],
			["room407","res://levels/03_room407/main.tscn",Vector3(-3.6,1.62,-.65),Vector3(-5.3,1,-4.25)],
			["passenger","res://levels/04_passenger/frog_chapter.tscn",Vector3(-4,1.65,-22),Vector3(0,1.7,-33)],
			["forest","res://levels/05_realization/forest_chapter.tscn",Vector3(1.4,1.6,2.6),Vector3(-1.2,1.3,-12)]
		]
		for config in setups:
			if not only.is_empty() and config[0] != only: continue
			change_scene_to_file(config[1])
			await scene_changed
			await settle()
			if config[0] == "forest":
				# The frog peeking from behind the giant tree, as on waking.
				current_scene.frog.appear_at(current_scene.frog_peek)
				current_scene.frog.face_towards(config[2])
			for layer in current_scene.find_children("*","CanvasLayer",true,false): layer.hide()
			var camera := Camera3D.new()
			current_scene.add_child(camera)
			camera.position = config[2]
			camera.look_at(config[3])
			camera.current = true
			camera.fov = 70
			await save("res://ui/previews/"+config[0]+".png")
		quit()
		return
	change_scene_to_file("res://main_menu.tscn")
	await scene_changed
	await save("res://.buildtmp/menu-home.png")
	current_scene.show_page("episodes")
	for i in root.get_node("Anthology").EPISODES.size():
		current_scene.select_episode(i,false)
		await save("res://.buildtmp/menu-episode-%d.png" % (i+1))
	current_scene.show_page("options")
	await save("res://.buildtmp/menu-options.png")
	current_scene.show_page("credits")
	await save("res://.buildtmp/menu-credits.png")
	current_scene.show_page("home")
	root.size = Vector2i(1920,1080)
	await save("res://.buildtmp/menu-home-1080.png")
	root.size = Vector2i(1280,720)
	for config in [["last_visit","res://levels/01_last_visit/prologue_village.tscn"],["after_hours","res://levels/02_after_hours/backrooms_level.tscn"],["room407","res://levels/03_room407/main.tscn"],["passenger","res://levels/04_passenger/frog_chapter.tscn"],["forest","res://levels/05_realization/forest_chapter.tscn"]]:
		change_scene_to_file(config[1])
		await scene_changed
		await save("res://.buildtmp/intro-"+config[0]+".png")
	quit()

func capture_endings() -> void:
	var manager := root.get_node("Anthology")
	var saved_progress: Array = manager.completed.duplicate()
	var saved_id: String = manager.selected_id
	for config in [["last_visit","res://levels/01_last_visit/scripts/prologue.gd","ENDING"],["after_hours","res://levels/02_after_hours/scripts/backrooms_level.gd","ENDING"],["room407","res://levels/03_room407/scripts/story.gd","ENDING"],["passenger","res://levels/04_passenger/scripts/frog_chapter.gd","EPILOGUE"],["forest","res://levels/05_realization/scripts/forest_chapter.gd","EPILOGUE"]]:
		var script: GDScript = load(config[1])
		await manager.complete_episode(config[0],script.get_script_constant_map()[config[2]])
		await save("res://.buildtmp/ending-"+config[0]+".png")
		manager.close_modal()
	manager.completed.assign(saved_progress)
	manager.selected_id = saved_id
	manager.save_preferences()
