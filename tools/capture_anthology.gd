extends SceneTree
## Render real project scenes for the episode selector and visual QA.
var menus_only := false

func _initialize() -> void:
	menus_only = "--menus" in OS.get_cmdline_user_args()
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
			["last_visit","res://prologue_village.tscn",Vector3(17.5,2,-137),Vector3(24,1.8,-150)],
			["after_hours","res://backrooms_level.tscn",Vector3(9.5,1.6,-9.5),Vector3(-1,1.6,-3)],
			["room407","res://Room407/main.tscn",Vector3(-3.6,1.62,-.65),Vector3(-5.3,1,-4.25)],
			["passenger","res://frog_chapter.tscn",Vector3(-4,1.65,-22),Vector3(0,1.7,-33)]
		]
		for config in setups:
			change_scene_to_file(config[1])
			await scene_changed
			await settle()
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
	for i in 4:
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
	for config in [["last_visit","res://prologue_village.tscn"],["after_hours","res://backrooms_level.tscn"],["room407","res://Room407/main.tscn"],["passenger","res://frog_chapter.tscn"]]:
		change_scene_to_file(config[1])
		await scene_changed
		await save("res://.buildtmp/intro-"+config[0]+".png")
	quit()

func capture_endings() -> void:
	var manager := root.get_node("Anthology")
	var saved_progress: Array = manager.completed.duplicate()
	var saved_id: String = manager.selected_id
	for config in [["last_visit","res://scripts/prologue.gd","ENDING"],["after_hours","res://scripts/backrooms_level.gd","ENDING"],["room407","res://Room407/scripts/story.gd","ENDING"],["passenger","res://scripts/frog_chapter.gd","EPILOGUE"]]:
		var script: GDScript = load(config[1])
		await manager.complete_episode(config[0],script.get_script_constant_map()[config[2]])
		await save("res://.buildtmp/ending-"+config[0]+".png")
		manager.close_modal()
	manager.completed.assign(saved_progress)
	manager.selected_id = saved_id
	manager.save_preferences()
