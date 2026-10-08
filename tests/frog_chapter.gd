extends SceneTree

var failures := 0
var chapter
var capture := false

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1

func frames(count := 8) -> void:
	for i in count: await physics_frame
	await process_frame
	await process_frame

func shot(title: String) -> void:
	if not capture: return
	await frames(10)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.buildtmp/frog-"+title+".png")

func aim(pos: Vector3, point: Vector3) -> void:
	chapter.player.position = pos
	chapter.player.velocity = Vector3.ZERO
	await chapter.look_at_point(point,.01)
	await frames()

func idle() -> void:
	var deadline := Time.get_ticks_msec()+30000
	while chapter.busy and Time.get_ticks_msec()<deadline: await process_frame
	check(not chapter.busy,"cinematic releases control")

func run() -> void:
	change_scene_to_file("res://frog_chapter.tscn")
	await scene_changed
	chapter = current_scene
	await frames()
	check(chapter.frog.mode==chapter.frog.Mode.GONE,"frog hidden before the failed start")
	check(chapter.get_node("World/BinbunGrass").get_child_count()==72,"chunked Binbun grass loaded")
	var grass: MultiMesh = chapter.get_node("World/BinbunGrass").get_child(0).multimesh
	if capture: check(grass.get_instance_transform(0).origin.length()>1,"grass transforms survived scene serialization")
	await shot("title")
	chapter.panel_continue()
	await aim(Vector3(.3,.1,1.8),Vector3(2.4,.95,2.5))
	check(chapter.target()!=null and chapter.target().get_meta("action")=="car","car reachable by interaction ray")
	chapter.interact("car")
	await idle()
	check(chapter.stage==chapter.Stage.FIELD,"failed starter leads to field")
	check(not chapter.frog.approach_enabled,"existing frog stays still during field encounter")
	var pause := InputEventAction.new()
	pause.action = "pause_game"
	pause.pressed = true
	chapter._unhandled_input(pause)
	var paused_position: Vector3 = chapter.player.position
	await create_timer(.3).timeout
	check(paused and not chapter.playing and chapter.player.position==paused_position,"pause freezes gameplay")
	chapter.panel_continue()
	check(not paused and chapter.playing,"pause resumes gameplay")
	await aim(Vector3(0,.05,-7),Vector3(0,1.7,-31))
	await shot("approach")
	# Real collision sweep through front door and hallway, not just teleport assertions.
	await aim(Vector3(0,.05,-29),Vector3(0,1.5,-35))
	await frames()
	check(not chapter.player.test_move(chapter.player.global_transform,Vector3(0,0,-3)),"front doorway traversable")
	await aim(Vector3(0,.05,-32),Vector3(3.8,.84,-33.9))
	check(chapter.stage==chapter.Stage.NOTE,"house entry advances objective")
	check(chapter.frog.mode==chapter.frog.Mode.GONE,"field frog vanishes at fence")
	await aim(Vector3(2.3,.05,-32.9),Vector3(3.8,.84,-33.9))
	check(chapter.target()!=null and chapter.target().get_meta("action")=="note","warning note reachable")
	chapter.interact("note")
	check(chapter.reading and not chapter.playing,"note can be read without a timer")
	await shot("note")
	chapter.panel_continue()
	await create_timer(1).timeout
	await shot("window")
	await idle()
	check(chapter.stage==chapter.Stage.BATTERY and chapter.frog.mode==chapter.frog.Mode.GONE,"blackout ends with frog absent and controls restored")
	await aim(Vector3(0,.05,-38.8),Vector3(0,1,-43))
	check(not chapter.player.test_move(chapter.player.global_transform,Vector3(0,0,-3)),"bedroom doorway traversable")
	await aim(Vector3(.4,.05,-41.3),Vector3(.85,.38,-42.7))
	check(chapter.target()!=null and chapter.target().get_meta("action")=="battery","jump starter reachable")
	await shot("bedroom")
	chapter.interact("battery")
	chapter.player.position = Vector3(0,.05,-40.95)
	await frames()
	await create_timer(2).timeout
	await shot("407")
	await idle()
	check(chapter.stage==chapter.Stage.RETURN,"407 reveal leads to return objective")
	check(not chapter.get_node("World/House/Bedroom407/JumpStarter").visible,"starter collected once")
	await aim(Vector3(0,.05,-39),Vector3(0,1,0))
	check(not chapter.player.test_move(chapter.player.global_transform,Vector3(0,0,3)),"revealed door leaves exit clear")
	# Frog's relocation queue must not advance while watched; existing unit suite covers ray occlusion.
	await aim(Vector3(0,.05,-22),Vector3(-4,1.3,-23))
	var before: Vector3 = chapter.frog.position
	await create_timer(.7).timeout
	check(chapter.frog.position.distance_to(before)<.2,"return frog does not jump while watched")
	# Staring at it from close up: threat -> hunt -> choke -> restart at the bedroom door.
	check(chapter.frog.threat_enabled,"threat rule is on for the walk back")
	await aim(Vector3(-1.2,.05,-21.6),Vector3(-4,1.4,-23))
	var t0 := Time.get_ticks_msec()
	while not chapter.frog.is_hunting() and Time.get_ticks_msec()-t0 < 9000: await process_frame
	var hunt_after := (Time.get_ticks_msec()-t0)/1000.0
	check(chapter.frog.is_hunting() and hunt_after > 4.0,"staring for ~5 s starts the hunt (%.1f s)" % hunt_after)
	while chapter.choke == null and Time.get_ticks_msec()-t0 < 15000: await process_frame
	check(chapter.choke != null and chapter.busy,"standing still gets you caught and choked")
	if chapter.choke and capture:
		while chapter.choke.t < 2.0: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.buildtmp/frog-choke.png")
	while chapter.catches == 0 and Time.get_ticks_msec()-t0 < 25000: await process_frame
	await idle()
	check(chapter.catches == 1 and chapter.choke == null,"choke ends and the chapter recovers")
	check(chapter.stage==chapter.Stage.RETURN and chapter.player.position.distance_to(chapter.RETURN_START)<.3,"restart puts you back at the bedroom door")
	check(chapter.frog.mode==chapter.frog.Mode.WATCH and chapter.frog.global_position.distance_to(chapter.RETURN_FROG)<.3 and chapter.frog.threat<.01,"frog back at its first spot, threat cleared")
	check(not chapter.player.held and chapter.player.camera.current,"player control and view restored")
	await create_timer(1.2).timeout
	check(chapter.overlay.color.a < .05,"screen fades back in")
	await aim(Vector3(0,.05,-21),Vector3(0,1,-5))
	await create_timer(.7).timeout
	await shot("return")
	await aim(Vector3(.3,.05,1.8),Vector3(2.4,.95,2.5))
	chapter.interact("car")
	var deadline := Time.get_ticks_msec()+30000
	while chapter.stage!=chapter.Stage.REPAIRED and Time.get_ticks_msec()<deadline: await process_frame
	check(chapter.stage==chapter.Stage.REPAIRED,"repair starts engine")
	await create_timer(7.2).timeout
	await shot("passenger")
	check(chapter.frog.mode==chapter.frog.Mode.SITTING,"original sitting animation used in passenger seat")
	check(chapter.frog.global_position.distance_to(Vector3(2.88,.28,4.05))<.1,"seated frog remains at passenger seat")
	while chapter.stage!=chapter.Stage.END and Time.get_ticks_msec()<deadline: await process_frame
	await create_timer(1.3).timeout
	check(chapter.stage==chapter.Stage.END and chapter.panel.visible,"ends at black title after repaired car")
	await shot("ending")
	print("FROG_CHAPTER_FAILURES=",failures)
	quit(failures)
