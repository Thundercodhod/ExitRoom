extends SceneTree
# Player walk / run cycles: speeds, planted feet that do not slide, footsteps on
# heel contact, smooth walk <-> run blending, and idle when standing still.

class TestGame extends Node3D:
	var playing := true

var failures := 0
var player: CharacterBody3D
var steps := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func attach(bone: String) -> BoneAttachment3D:
	var s: Skeleton3D = player.body_visual.find_child("Skeleton3D", true, false)
	var a := BoneAttachment3D.new()
	a.bone_name = bone
	s.add_child(a)
	return a


# Moves for `n` frames and returns {speed, steps, slide}: slide is the largest
# horizontal drift of a toe while it is on the ground (within 6 mm of its
# lowest point) over one contact.
func measure(n: int, toes: Array) -> Dictionary:
	var start := player.global_position
	var f0 := Engine.get_physics_frames()
	steps = 0
	var samples := {}
	for t in toes:
		samples[t] = []
	# Sample once per physics step (a rendered frame can contain several when
	# headless falls behind), right after the pose for that step is applied.
	while Engine.get_physics_frames() - f0 < n:
		await process_frame
		for t in toes:
			samples[t].append(t.global_position)
	var worst := 0.0
	for t in toes:
		var pts: Array = samples[t]
		var low := INF
		for p in pts:
			low = minf(low, p.y)
		var window: Array = []
		for p in pts + [Vector3(0, INF, 0)]:
			if p.y < low + 0.006:
				window.append(p)
			else:
				if window.size() >= 3:
					var a: Vector3 = window[0]
					var b: Vector3 = window[window.size() - 1]
					worst = maxf(worst, Vector2(b.x - a.x, b.z - a.z).length())
				window.clear()
	var moved := player.global_position - start
	var secs := (Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second)
	return {"speed": Vector2(moved.x, moved.z).length() / secs, "steps": steps, "slide": worst}


func run() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "jump", "flashlight", "interact", "pause_game"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var fx := TestGame.new()
	root.add_child(fx)
	var floor := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 0.5, 200)
	col.shape = box
	floor.add_child(col)
	floor.position = Vector3(0, -0.25, -80)
	fx.add_child(floor)
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.game = fx
	player.position = Vector3(0, 0.1, 0)
	fx.add_child(player)
	player.stepped.connect(func(_r): steps += 1)
	await frames(20)
	var toes := [attach("LeftToeBase"), attach("RightToeBase")]

	check(player.anim_tree != null and player.anim_tree.active, "Gait AnimationTree is running")
	check(player.WALK_SPEED == 1.4 and player.SPRINT_SPEED == 4.8, "Walk 1.4 m/s, sprint 4.8 m/s")

	# Walk
	Input.action_press("forward")
	await frames(40)
	var walk := await measure(126, toes)        # 2.1 s
	check(absf(walk.speed - 1.4) < 0.05, "Walks at 1.4 m/s (%.2f)" % walk.speed)
	check(walk.steps >= 5 and walk.steps <= 7, "About 6 footsteps in 2.1 s of walking (%d)" % walk.steps)
	check(walk.slide < 0.02, "Planted foot does not slide while walking (%.3f m)" % walk.slide)
	check(player.current_anim == player.anim_names["walk"], "Walking plays the walk cycle")

	# Run
	Input.action_press("sprint")
	await frames(40)
	var run_m := await measure(126, toes)
	check(absf(run_m.speed - 4.8) < 0.1, "Sprints at 4.8 m/s (%.2f)" % run_m.speed)
	check(run_m.steps >= 7 and run_m.steps <= 9, "About 8 footsteps in 2.1 s of running (%d)" % run_m.steps)
	check(run_m.slide < 0.02, "Planted foot does not slide while running (%.3f m)" % run_m.slide)
	check(player.current_anim == player.anim_names["run"], "Sprinting plays the run cycle")

	# Walk <-> run blend keeps the legs in step (shared phase, no jumps).
	Input.action_release("sprint")
	var max_jump := 0.0
	var last: float = player.gait_phase
	for i in 40:
		await physics_frame
		var d: float = fposmod(player.gait_phase - last, 1.0)
		max_jump = maxf(max_jump, d)
		last = player.gait_phase
	check(max_jump < 0.12, "Slowing from run to walk advances the cycle smoothly (max %.2f per frame)" % max_jump)

	# Stop
	Input.action_release("forward")
	await frames(60)
	steps = 0
	await frames(60)
	check(player.current_anim == player.anim_names["idle"] and steps == 0, "Standing still: idle, no footsteps")

	# Cinematics can force idle (used by the frog's choke).
	Input.action_press("forward")
	await frames(30)
	Input.action_release("forward")
	player._play_animation("idle", 1.0)
	check(player.anim_tree.get("parameters/move/blend_amount") == 0.0, "_play_animation(\"idle\") switches to idle")

	print("EXITROOM_GAIT_FAILURES=", failures)
	quit(1 if failures else 0)
