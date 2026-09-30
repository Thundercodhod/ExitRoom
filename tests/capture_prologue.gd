extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await process_frame
	await RenderingServer.frame_post_draw


func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	current_scene.begin_game()
	await frames(24)
	root.get_texture().get_image().save_png("res://preview-prologue-road.png")
	current_scene.player.global_position = Vector3(0, 0.12, -63.0)
	await frames(24)
	root.get_texture().get_image().save_png("res://preview-prologue-bridge.png")
	current_scene.player.global_position = Vector3(24, 0.12, -133.0)
	await frames(24)
	root.get_texture().get_image().save_png("res://preview-prologue-house.png")
	quit()
