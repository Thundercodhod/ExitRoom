extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func save_view(path: String) -> void:
	for i in 28:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	print("CAPTURE ", path, " ", error)

func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	current_scene.begin_game()
	await save_view("res://preview-first-person-prologue.png")
	current_scene.player.position = Vector3(23.5, 0.12, -148.0)
	current_scene.player.pivot.rotation.y = 1.15
	await save_view("res://preview-first-person-house.png")
	change_scene_to_file("res://backrooms_level.tscn")
	await scene_changed
	current_scene.begin_game()
	await save_view("res://preview-first-person-backrooms.png")
	quit()
