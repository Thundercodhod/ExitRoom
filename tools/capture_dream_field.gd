extends SceneTree
const Terrain=preload("res://scripts/dream_field_terrain.gd")
## Real-renderer captures of the new field only; existing thumbnails are untouched.
func _initialize() -> void:
	call_deferred("run")

func save(path: String) -> void:
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path)

func run() -> void:
	create_timer(35.0).timeout.connect(func(): push_error("Dream capture timed out"); quit(1))
	DirAccess.make_dir_recursive_absolute("res://.buildtmp/dream-field")
	var manager := root.get_node("Anthology")
	manager.settings.master = 0.0
	manager.apply_preferences()
	await create_timer(.2).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	change_scene_to_file("res://dream_field.tscn")
	await scene_changed
	await create_timer(1.0).timeout
	var field := current_scene
	field.get_node("DreamHUD").hide()
	await save("res://.buildtmp/dream-field/wide.png")
	await save("res://ui/previews/dream_field.png")
	field.player.position = Vector3(3.0,Terrain.height_at(3,-10)+.08,-10)
	field.player.rotation.y = atan2(3.0,6.0)
	field.player.pitch = -.08
	field.player.camera.rotation.x = -.08
	field.get_node("DreamHUD").show()
	await save("res://.buildtmp/dream-field/approach.png")
	field.player.position = Vector3(15,Terrain.height_at(15,-5)+.08,-5)
	field.player.rotation.y = atan2(15.0,11.0)
	field.player.camera.rotation.x = -.01
	field.get_node("DreamHUD").hide()
	await save("res://.buildtmp/dream-field/side.png")
	print("DREAM_CAPTURE_COMPLETE")
	quit()
