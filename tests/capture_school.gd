extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func run() -> void:
	change_scene_to_file("res://abandoned_school.tscn")
	await scene_changed
	current_scene.begin_game()
	await frames(22)
	root.get_texture().get_image().save_png("res://preview-school-entry.png")
	current_scene.player.global_position = Vector3(0, 0.12, -45)
	await frames(22)
	root.get_texture().get_image().save_png("res://preview-school-hall.png")
	current_scene.player.global_position = Vector3(10.2, 0.12, -48.5)
	await frames(22)
	root.get_texture().get_image().save_png("res://preview-school-classroom.png")
	quit()
