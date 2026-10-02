extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	for i in 32:
		await process_frame
	await RenderingServer.frame_post_draw

func shot(pos: Vector3, target: Vector3, path: String) -> void:
	var camera:=Camera3D.new()
	current_scene.add_child(camera)
	camera.global_position=pos
	camera.look_at(target)
	camera.fov=66
	camera.current=true
	await settle()
	root.get_texture().get_image().save_png(path)
	camera.queue_free()

func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	current_scene.begin_game()
	current_scene.player.visible=false
	current_scene.player.set_physics_process(false)
	current_scene.get_node("PrologueHUD").hide()
	await shot(Vector3(24.6,1.68,-147.1),Vector3(19,1.33,-149),"res://preview-abandoned-house-revised.png")
	current_scene.player.visible=true
	current_scene.player.position=Vector3(23.5,0.12,-148.0)
	current_scene.player.pivot.rotation.y=1.15
	current_scene.player.camera.current=true
	current_scene.get_node("PrologueHUD").show()
	await settle()
	root.get_texture().get_image().save_png("res://preview-house-gameplay.png")
	quit()
