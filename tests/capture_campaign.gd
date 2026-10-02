extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func shot(file: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.buildtmp/" + file + ".png")

func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	await shot("campaign-intro")
	current_scene.begin_game()
	current_scene.player.position = Vector3(23.5, 0.12, -148.0)
	current_scene.interact()
	await shot("campaign-cassette")
	change_scene_to_file("res://backrooms_level.tscn")
	await scene_changed
	await shot("campaign-backrooms")
	change_scene_to_file("res://Room407/main.tscn")
	await scene_changed
	await shot("campaign-room407")
	current_scene.start()
	current_scene.stage = 8
	current_scene.interact("future_note")
	await shot("campaign-frog-teaser")
	quit()
