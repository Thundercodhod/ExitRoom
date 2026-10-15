extends SceneTree
## Episode 05: wake-up, frog peek, Pladuk on the shoulder, off-trail warning,
## hunt -> catch -> restart with the clock moved on, and the campfire ending.
## godot --headless --script res://tests/forest_loop.gd   (add -- --capture for screenshots, not headless)

var failures := 0
var chapter
var capture := false
var had_preferences := false
var original_preferences := ""

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
	DirAccess.make_dir_recursive_absolute("res://.buildtmp")
	root.get_texture().get_image().save_png("res://.buildtmp/forest-"+title+".png")

func wait_until(condition: Callable, seconds: float, message: String) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	var ok: bool = condition.call()
	check(ok, message)
	return ok

# A point `side` metres to the side of the trail at `offset` metres along it.
func beside_trail(offset: float, side: float) -> Vector3:
	var a: Vector3 = chapter.trail.sample_baked(offset)
	var b: Vector3 = chapter.trail.sample_baked(offset + .5)
	var right := (b - a).normalized().cross(Vector3.UP)
	return a + right * side + Vector3.UP * .05

func place(pos: Vector3) -> void:
	chapter.player.global_position = pos
	chapter.player.velocity = Vector3.ZERO
	await frames(4)

func run() -> void:
	had_preferences = FileAccess.file_exists("user://anthology.cfg")
	if had_preferences: original_preferences = FileAccess.get_file_as_string("user://anthology.cfg")
	var started_at := Time.get_ticks_msec()
	change_scene_to_file("res://levels/05_realization/forest_chapter.tscn")
	await scene_changed
	chapter = current_scene
	await frames()
	print("scene ready in ", Time.get_ticks_msec() - started_at, " ms")
	check(chapter.EPISODE_ID == "forest" and chapter.panel_title.text.contains("REALIZATION"), "forest episode opens with its own introduction")
	check(chapter.panel_text.text.contains("ใกล้ถึงปั๊มแล้วใช่ไหมนะ"), "introduction picks up from the end of Episode 04")
	check(chapter.get_node("World/Trees").get_child_count() > 100, "forest is planted (%d trees)" % chapter.get_node("World/Trees").get_child_count())
	check(chapter.trail.get_baked_length() > 80, "trail leads to the campfire")
	var turn_before: float = chapter.flames.rotation.y
	await create_timer(.3).timeout
	check(absf(chapter.flames.rotation.y - turn_before) > .01, "the campfire flames move (burn animation runs)")
	check((chapter.flames.material_override as StandardMaterial3D).disable_fog, "the flames are not tinted by the night fog")
	# The pieces get their atlas texture from props.tres through their .import files.
	var tree_mesh := chapter.get_node("World/Trees").find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var tree_mat := tree_mesh.get_active_material(0) as StandardMaterial3D
	check(tree_mat != null and tree_mat.albedo_texture != null and tree_mat.vertex_color_use_as_albedo, "forest pieces use the textured PSX material")
	var ground: MultiMesh = chapter.get_node("World/Ground").multimesh
	if DisplayServer.get_name() != "headless":   # the headless renderer does not keep MultiMesh data
		check(ground.instance_count > 500 and ground.get_instance_transform(ground.instance_count - 1).origin.length() > 10, "ground tiles kept their positions")
	check(chapter.frog.mode == chapter.frog.Mode.GONE, "frog hidden before waking up")
	var fire_stream := chapter.fire_sound.stream as AudioStreamWAV
	check(fire_stream.resource_path.ends_with("campfire.wav") or fire_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "the campfire plays the recorded crackle")
	check(fire_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and chapter.fire_sound.playing, "the crackle loops at the fire")
	await shot("title")

	# ---- waking up
	await chapter.panel_continue()
	check(chapter.stage == chapter.Stage.WAKE and chapter.overlay.color.a > .9, "starts on black, waking up")
	check(chapter.forest_silent, "silence before the gasp")
	await create_timer(1.6).timeout
	check(chapter.sound.playing and chapter.sound.stream.resource_path.ends_with("player_gasp.wav"), "waking up plays the recorded gasp")
	await shot("wake-blink")
	if not await wait_until(func(): return chapter.stage == chapter.Stage.WALK, 20, "wake-up finishes and hands control back"): return finish()
	check(chapter.peek_active and chapter.frog.mode != chapter.frog.Mode.GONE, "frog is peeking from behind the giant tree")
	check(chapter.frog.global_position.distance_to(chapter.frog_peek) < .3, "frog stands at the peek spot")
	check(is_equal_approx(chapter.head_tilt.tilt, deg_to_rad(28)), "frog's head is tilted")
	check(chapter.frog.is_seen(), "the wake-up look lands on the frog")
	check(chapter.head_tilt._applied > deg_to_rad(15), "the tilt is actually applied to the head bone")
	check(chapter.forest_silent, "seeing the frog silences the forest")
	check(absf(chapter.player.pivot.position.y - 1.55) < .05 and absf(chapter.player.camera.rotation.z) < .02, "Phakin is back on his feet")
	check(chapter.clock_label.text == "23:52", "clock starts at 23:52")
	await shot("peek")
	# Look away: it is gone when he looks back, and the forest comes back.
	await chapter.look_at_point(chapter.player.global_position + Vector3(0, 1.5, 10), .2)
	await wait_until(func(): return chapter.frog.mode == chapter.frog.Mode.GONE, 3, "frog is gone after looking away")
	check(not chapter.peek_active and chapter.head_tilt.tilt == 0.0, "peek ends and the tilt is cleared")
	await create_timer(.5).timeout
	check(not chapter.forest_silent and chapter.night.volume_db > -79, "forest sounds start coming back")
	chapter.wind_timer = 0.0
	await frames(3)
	check(chapter.wind.playing, "a wind gust comes through the trees on the walk")
	chapter.silence_forest()
	check(not chapter.wind.playing, "the gust stops when the forest goes silent")
	chapter.wind_timer = 0.0
	await frames(3)
	check(not chapter.wind.playing, "no gusts while the forest is silent")
	chapter.wake_forest(.1)

	# ---- Pladuk on the shoulder
	var shoulder = chapter.shoulder
	await chapter.look_at_point(chapter.player.global_position + Vector3(0, 1.5, -10), .2)
	check(not shoulder.is_showing(), "Pladuk is not in view between leans")
	shoulder.lean_in()
	check(shoulder.voice.playing and shoulder.voice.stream.resource_path.ends_with("pladuk_hello.wav"), "Pladuk's sound plays as it leans in")
	check(shoulder.voice.position.x > 0.0, "the sound comes from the right side, beside his ear")
	await create_timer(1.8).timeout
	check(shoulder.is_showing() and shoulder.lean > .99, "Pladuk leans in at the right shoulder in first person")
	var face: Vector3 = chapter.player.camera.global_transform.affine_inverse() * (shoulder.rig.global_transform * shoulder._face_in_rig())
	check(face.x > .15 and face.z < 0.0, "its face sits right of centre, in front of the camera (%s)" % face)
	check(chapter.player.camera.is_position_in_frustum(shoulder.rig.global_transform * shoulder._face_in_rig()), "its face is inside the view")
	await shot("pladuk-shoulder")
	chapter.player.set_third_person(true)
	await frames(2)
	check(not shoulder.is_showing() and not shoulder.leaning, "third person: Pladuk is gone at once")
	await shot("pladuk-third-person")
	chapter.player.set_third_person(false)
	await frames(2)
	check(not shoulder.is_showing(), "back to first person: it does not pop straight back")
	var mesh_shadows: bool = shoulder.rig.find_children("*", "GeometryInstance3D", true, false).all(func(m): return m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	check(mesh_shadows, "Pladuk casts no shadow")

	# ---- leaving the trail: warning, back on the trail: calm
	await place(beside_trail(20, 7.5))
	await frames(6)
	check(chapter.stage == chapter.Stage.WARNED, "7.5 m off the trail: warning")
	check(chapter.frog.mode != chapter.frog.Mode.GONE and chapter.frog.global_position.distance_to(chapter.player.global_position) > 5, "frog stands in the way, on the wrong side")
	check(chapter.shoulder.pressure >= 1.0, "Pladuk leans in sooner when he strays")
	await shot("warning")
	await place(beside_trail(20, .5))
	await frames(6)
	check(chapter.stage == chapter.Stage.WALK and not chapter.frog.is_hunting(), "back on the trail: no hunt")
	await chapter.look_at_point(chapter.frog.global_position + Vector3(0, 1.5, 0) - Vector3(0, 0, 0) + (chapter.player.global_position - chapter.frog.global_position) * 2, .2)
	await wait_until(func(): return chapter.frog.mode == chapter.frog.Mode.GONE, 4, "frog leaves once he looks away")

	# ---- straying far: hunt, catch, wake at the start later in the night
	var minutes_before: float = chapter.clock_minutes
	var energy_before: float = chapter.fire_energy
	await place(beside_trail(30, 12.5))
	await frames(6)
	check(chapter.stage == chapter.Stage.HUNTED and chapter.frog.is_hunting(), "12 m off the trail: the frog hunts")
	await wait_until(func(): return chapter.choke != null, 20, "frog catches him")
	await shot("caught")
	if not await wait_until(func(): return chapter.stage == chapter.Stage.WALK and chapter.catches == 1, 40, "he wakes at the start again"): return finish()
	check(chapter.player.global_position.distance_to(chapter.START) < .5, "back at the start of the trail")
	check(chapter.clock_minutes - minutes_before > 25, "the clock moved on (%s)" % chapter.clock_label.text)
	check(chapter.fire_energy < energy_before, "the campfire burned down")
	check(chapter.fire_sound.volume_db < chapter.FIRE_DB, "the smaller fire crackles more quietly")
	check(chapter.flames.scale.y < .99, "the flames themselves are smaller")
	check(not chapter.player.held and chapter.player.camera.current, "control and view restored after the catch")
	check(chapter.objective.visible and chapter.objective.text == chapter.OBJECTIVE, "objective back")

	# ---- the campfire
	await place(chapter.campfire_spot + Vector3(0, .05, 5))
	await frames(4)
	check(chapter.prompt.text == "", "no sleep prompt before reaching the fire")
	check(chapter.stage == chapter.Stage.WALK, "the walk to the fire along the trail stays calm")
	await chapter.look_at_point(chapter.campfire_spot + Vector3(0, .8, 0), .2)
	await shot("campfire")
	await place(chapter.campfire_spot + Vector3(0, .05, 2.4))
	await frames(4)
	check(chapter.prompt.text.contains("กองไฟ"), "sleep prompt beside the fire")
	chapter.player.set_third_person(true)
	await frames(2)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	await frames(4)
	check(chapter.stage == chapter.Stage.CAMP and chapter.busy, "E: sits down by the fire")
	check(not chapter.player.third_person, "the campfire ending switches to first person")
	await wait_until(func(): return chapter.ending_presented, 30, "falls asleep: episode ends")
	var anthology := root.get_node_or_null("Anthology")
	if anthology:
		while anthology.changing: await process_frame
		check(anthology.completed.has("forest"), "completion recorded")
	check(chapter.EPILOGUE.contains("EPISODE 06"), "ending points on to Episode 06")
	await shot("ending")
	finish()

func finish() -> void:
	if had_preferences:
		var preferences := FileAccess.open("user://anthology.cfg", FileAccess.WRITE)
		if preferences: preferences.store_string(original_preferences)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://anthology.cfg"))
	print("FOREST_FAILURES=", failures)
	quit(failures)
