extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	await frames(18)
	root.get_texture().get_image().save_png("res://preview-lobby.png")
	current_scene.begin_roaming()
	await frames(28)
	root.get_texture().get_image().save_png("res://preview-lobby-roam.png")
	current_scene.start_level_one()
	await scene_changed
	await frames(35)
	root.get_texture().get_image().save_png("res://preview-backrooms.png")
	quit()
