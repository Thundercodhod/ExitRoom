extends SceneTree
var game: Node3D
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS " if value else "FAIL ")+message)
	if not value:failures.append(message)
func walk(from: Vector3,to: Vector3) -> void:
	var p=game.player
	p.position=from
	p.velocity=Vector3.ZERO
	for i in range(180):
		await physics_frame
		var delta=to-p.position
		p.velocity=Vector3(delta.x,0,delta.z).normalized()*2.5
		p.velocity.y=-1
		p.move_and_slide()
		if Vector2(delta.x,delta.z).length()<.08:break
	check(Vector2(p.position.x-to.x,p.position.z-to.z).length()<.22,"walk through doorway to "+str(to))
func run() -> void:
	game=load("res://Room407/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start()
	game.player.set_physics_process(false)
	game.player.locked=true
	await physics_frame
	check(game.get_node("Room406/Bed").find_children("*","MeshInstance3D",true,false).size()==1,"one furniture mesh, no duplicate inherited nodes")
	var mesh:MeshInstance3D=game.get_node("Room406/Bed").find_children("*","MeshInstance3D",true,false)[0]
	check(mesh.get_aabb().position.y>=-.01 and mesh.get_aabb().end.y<1,"bed dimensions and ground origin")
	var box_position:Vector3=game.get_node("Room406/Openbox").global_position
	for spec in [[Vector3(-2,.03,-1.6),Vector3(-1.45,1.125,-1.8),"note"],[box_position+Vector3(-.8,.05,-1),box_position+Vector3(0,.15,0),"unpack"],[Vector3(-4.5,.03,-3),Vector3(-5.7,.45,-4.25),"bed"]]:
		game.player.position=spec[0]
		game.player.camera.look_at(spec[1])
		await physics_frame
		var target:Node=game.player.target()
		check(target!=null and str(target.get_meta("action",""))==spec[2],"interaction ray reaches "+spec[2])
	if absf(game.get_node("Door406").rotation.y)<.2:
		await game.toggle_door(game.get_node("Door406"))
	await walk(Vector3(-4,.03,1.7),Vector3(-4,.03,-2.0))
	await walk(Vector3(-4,.03,-2),Vector3(-4,.03,1.7))
	var hit=game.player.test_move(Transform3D(Basis.IDENTITY,Vector3(4,.03,1)),Vector3(0,0,-2))
	check(hit,"407 wall blocks passage before apparition")
	game.interact("note")
	game.interact("unpack")
	check(game.stage==2,"arrival objectives advance")
	await game.sleep_transition()
	check(game.stage==3 and game.get_node("Door407").visible and not game.get_node("Wall407").visible,"night one appears")
	await game.interact("door407")
	check(game.stage==4 and not game.player.locked,"camera pull returns control")
	var figure:Node3D=game.get_node("HallFigure")
	var approach_origin:Vector3=game.player.position
	game.player.position=figure.position+Vector3(-2.5,0,0)
	await process_frame
	await process_frame
	check(figure.visible,"hall figure remains visible at a distance")
	game.paused=true
	game.player.position=figure.position+Vector3(-1.5,0,0)
	await process_frame
	await process_frame
	check(figure.visible,"hall figure does not vanish while paused")
	game.paused=false
	await process_frame
	await process_frame
	check(not figure.visible and game.hall_figure_vanished,"approaching hall figure makes it vanish")
	game.player.position=approach_origin
	await game.interact("door407")
	await process_frame
	check(not figure.visible and game.stage==4,"figure stays gone after retreat and repeated door interaction")
	await game.sleep_transition()
	check(game.stage==5 and not game.get_node("Door407").visible,"morning restores wall")
	game.interact("wall")
	check(game.stage==6,"morning evidence read")
	await game.sleep_transition()
	check(game.stage==7 and game.get_node("Room407/SleepingDouble").visible,"night two reveals double")
	await physics_frame
	await walk(Vector3(4,.03,1.7),Vector3(4,.03,-2))
	await game.reveal()
	check(game.stage==8 and not game.player.locked,"reveal releases camera")
	game.interact("future_note")
	check(game.stage==9,"chapter completes")
	var ap:AnimationPlayer=game.get_node("HallFigure").find_child("AnimationPlayer",true,false)
	var skeleton:Skeleton3D=game.get_node("HallFigure").find_children("*","Skeleton3D",true,false)[0]
	for name in ["idle","walk","run","sit","crouch_down","stand_up"]:
		check(ap.has_animation(name),"animation "+name+" imported")
		if ap.has_animation(name):
			ap.play(name)
			ap.seek(0,true)
			var initial:Array[Transform3D]=[]
			for i in skeleton.get_bone_count():initial.append(skeleton.get_bone_pose(i))
			ap.seek(ap.get_animation(name).length*.4,true)
			var moved:=false
			for i in skeleton.get_bone_count():
				if not initial[i].is_equal_approx(skeleton.get_bone_pose(i)):moved=true
			check(moved,"animation moves skeleton: "+name)
	check(game.effect.get_shader_parameter("pixel_height")==270.0,"retro pixel rendering retained")
	print("PLAYTEST_COMPLETE failures=",failures.size())
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
