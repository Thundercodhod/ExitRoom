extends SceneTree
var model: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func shot(pos: Vector3, target: Vector3, path: String) -> void:
	camera.position=pos
	camera.look_at(target)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	model=load("res://3Dmodel_import/low-poly_furnished_abandoned_house.glb").instantiate()
	root.add_child(model)
	var world:=WorldEnvironment.new()
	world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(0.15,0.17,0.17)
	world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color=Color(0.85,0.84,0.77)
	world.environment.ambient_light_energy=0.7
	root.add_child(world)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-45,-30,0)
	sun.light_energy=0.6
	root.add_child(sun)
	camera=Camera3D.new()
	camera.current=true
	root.add_child(camera)
	await shot(Vector3(20,16,-15),Vector3(0,1,5),"res://preview-source-house-exterior.png")
	await shot(Vector3(-0.6,1.65,7.1),Vector3(5,1.3,9),"res://preview-source-house-kitchen.png")
	for n in model.find_children("*","MeshInstance3D",true,false):
		var a: AABB=n.global_transform*n.get_aabb()
		if a.position.y>2.2:
			n.hide()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=23
	await shot(Vector3(0,25,5.1),Vector3(0,0,5),"res://preview-source-house-plan.png")
	quit()
