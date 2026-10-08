extends SceneTree

class TestGame extends Node3D:
	var playing := true

var failures := 0
var vanished_count := 0
var relocated_count := 0
var settled_count := 0
var clutch_count := 0
var missed_count := 0
var caught_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame

func solid(parent: Node, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func new_fixture(wall: bool) -> TestGame:
	var fixture := TestGame.new()
	root.add_child(fixture)
	solid(fixture, Vector3(0, -0.25, 0), Vector3(40, 0.5, 40))
	if wall:
		solid(fixture, Vector3(0, 1, 0), Vector3(6, 2, 0.4))
	return fixture

func make_player(fixture: Node, pos: Vector3) -> CharacterBody3D:
	var p := CharacterBody3D.new()
	p.set_script(load("res://scripts/player.gd"))
	p.game = fixture
	p.position = pos
	fixture.add_child(p)
	return p

func make_frog(fixture: Node, player: Node3D, pos: Vector3, use_nav := false) -> CharacterBody3D:
	var f := CharacterBody3D.new()
	f.set_script(load("res://scripts/frog_watcher.gd"))
	f.game = fixture
	f.target = player
	f.position = pos
	if use_nav:
		f.bounds = Rect2(-12, -12, 24, 24)
	fixture.add_child(f)
	f.vanished.connect(func(): vanished_count += 1)
	f.relocated.connect(func(_p): relocated_count += 1)
	f.settled.connect(func(): settled_count += 1)
	f.clutch_started.connect(func(): clutch_count += 1)
	f.clutch_missed.connect(func(): missed_count += 1)
	f.caught_player.connect(func(): caught_count += 1)
	return f

func yaw_towards(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(-d.x, -d.z)

func body_error(frog: Node3D, player: Node3D) -> float:
	var d := player.global_position - frog.global_position
	d.y = 0.0
	var forward := -frog.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized().angle_to(d.normalized())

# Final (rendered) bone position, read through a BoneAttachment3D so it includes
# every skeleton modifier, not just what a modifier believes it set.
func attach(frog: Node3D, bone: String) -> BoneAttachment3D:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	frog.skeleton.add_child(att)
	return att

# Angle between the rendered head's facing and the direction to `point`.
func real_head_error(frog: Node3D, head: BoneAttachment3D, point: Vector3) -> float:
	var s: Skeleton3D = frog.skeleton
	var local_forward: Vector3 = s.get_bone_global_rest(s.find_bone("Head")).basis.inverse() * Vector3.BACK
	var forward: Vector3 = (head.global_transform.basis * local_forward).normalized()
	return forward.angle_to((point - head.global_position).normalized())

func flat_distance(a: Node3D, b: Node3D) -> float:
	var d := a.global_position - b.global_position
	d.y = 0.0
	return d.length()

func run() -> void:
	for action in ["forward", "back", "left", "right", "sprint", "flashlight", "interact", "pause_game"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

	# 1. Model, clips and head tracker
	var fx := new_fixture(false)
	var player := make_player(fx, Vector3(0, 0.15, 0))
	var frog := make_frog(fx, player, Vector3(0, 0.05, -14))
	await frames(10)
	check(frog.skeleton != null and frog.skeleton.get_bone_count() == 50, "Frog skeleton (50 bones) is found")
	check(frog.anim_names.has("idle") and frog.anim_names.has("walk") and frog.anim_names.has("sit"), "Idle, walk and sit clips are found")
	check(frog.tracker != null, "Head tracker is attached")
	fx.queue_free()
	await frames(2)

	# 2. The head follows the player even when the body does not turn
	fx = new_fixture(false)
	player = make_player(fx, Vector3(-4, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, 0))
	frog.turn_body = false
	frog.approach_enabled = false
	await frames(90)
	check(body_error(frog, player) > 1.3, "Body is not turned toward the player in this test")
	var tracked: float = frog.head_error()
	check(tracked < 0.45, "Head turns toward the player (error %.2f rad)" % tracked)
	var head_att := attach(frog, "Head")
	await frames(5)
	var real: float = real_head_error(frog, head_att, player.pivot.global_position)
	check(real < 0.2, "Rendered head really faces the player (error %.2f rad)" % real)
	await frames(120)
	check(frog.head_error() < 0.45, "Head tracking stays steady over time (error %.2f rad)" % frog.head_error())
	frog.head_tracking = false
	await frames(90)
	check(frog.head_error() > 1.0, "Head returns to the animated pose when tracking is off")
	fx.queue_free()
	await frames(2)

	# 3. Walks up to its viewing distance and stops there
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -14))
	settled_count = 0
	var closest := 99.0
	var walked_anim := false
	for i in 720:
		await physics_frame
		closest = minf(closest, flat_distance(frog, player))
		if frog.current_anim == frog.anim_names.get("walk", &"") and frog.player_animation.speed_scale > 0.3:
			walked_anim = true
	var d: float = flat_distance(frog, player)
	check(walked_anim, "Walk clip plays while it approaches")
	check(d > 3.0 and d < 4.1, "Settles near its viewing distance (%.2f m)" % d)
	check(closest > 3.0, "Never comes closer than the minimum (%.2f m)" % closest)
	check(settled_count >= 1 and frog.move_state == frog.Move.HOLD, "Settled signal emitted and it stands still")
	check(body_error(frog, player) < 0.4, "Faces the player while watching")
	check(frog.current_anim == frog.anim_names["idle"], "Idle clip plays while it watches")
	# 4. Backs away when the player steps toward it
	player.global_position = frog.global_position + Vector3(0, 0.15, 1.5)
	player.velocity = Vector3.ZERO
	var reversed := false
	var closest2 := 99.0
	for i in 420:
		await physics_frame
		closest2 = minf(closest2, flat_distance(frog, player))
		if frog.player_animation.speed_scale < -0.3:
			reversed = true
	d = flat_distance(frog, player)
	check(reversed, "Walks backwards (clip played in reverse) to back away")
	check(d > 3.0, "Restores its distance after the player steps close (%.2f m)" % d)
	check(body_error(frog, player) < 0.5, "Keeps facing the player while backing away")
	fx.queue_free()
	await frames(2)

	# 5. Goes around a wall to get to its viewing spot
	fx = new_fixture(true)
	player = make_player(fx, Vector3(0, 0.15, 6))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6), true)
	var widest := 0.0
	for i in 900:
		await physics_frame
		widest = maxf(widest, absf(frog.global_position.x))
	d = flat_distance(frog, player)
	check(widest > 2.9, "Detours around the wall (max |x| %.1f)" % widest)
	check(d < 4.6, "Reaches viewing distance on the far side of the wall (%.2f m)" % d)
	fx.queue_free()
	await frames(2)

	# 6. Being seen: in view, out of view, behind a wall
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(4)
	check(frog.is_seen(), "Frog is seen when the player faces it")
	player.pivot.rotation.y += PI
	await frames(4)
	check(not frog.is_seen(), "Frog is not seen when the player faces away")
	fx.queue_free()
	await frames(2)
	fx = new_fixture(true)
	player = make_player(fx, Vector3(0, 0.15, 5))
	frog = make_frog(fx, player, Vector3(0, 0.05, -5))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(4)
	check(not frog.is_seen(), "Frog behind a wall is not seen")
	fx.queue_free()
	await frames(2)

	# 7. Moves only while unseen
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -8))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	relocated_count = 0
	var target_point := Vector3(0, 0.05, -4)
	frog.relocate_when_unseen(target_point, 0.3)
	await frames(90)
	check(relocated_count == 0 and frog.global_position.distance_to(Vector3(0, 0.05, -8)) < 0.3, "Does not move while the player is looking at it")
	player.pivot.rotation.y += PI
	await frames(60)
	check(relocated_count == 1 and frog.global_position.distance_to(target_point) < 0.3, "Jumps to the next spot once the player looks away")
	fx.queue_free()
	await frames(2)

	# 8. Vanishes when looked at from close range, and can reappear
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -6))
	frog.approach_enabled = false
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position) + PI
	vanished_count = 0
	frog.vanish_when_seen_within(8.0, 0.2)
	await frames(60)
	check(vanished_count == 0 and frog.visible, "Stays while the player is not looking")
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(60)
	check(vanished_count == 1 and not frog.visible, "Vanishes once the player looks at it")
	frog.appear_at(Vector3(3, 0.05, -3))
	check(frog.visible and frog.global_position.distance_to(Vector3(3, 0.05, -3)) < 0.1, "Can reappear somewhere else")
	fx.queue_free()
	await frames(2)

	# 9. Sitting (passenger seat)
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -10))
	await frames(10)
	frog.sit()
	var seat := frog.global_position
	await frames(90)
	check(frog.current_anim == frog.anim_names["sit"], "Sit clip plays")
	check(frog.global_position.distance_to(seat) < 0.05, "Does not walk while sitting")
	frog.stand()
	await frames(10)
	check(frog.current_anim != frog.anim_names["sit"], "Stands up again")
	fx.queue_free()
	await frames(2)

	# 10. Hunt: runs leaning forward, swings the left arm out and catches
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -12), true)
	await frames(10)
	clutch_count = 0
	caught_count = 0
	missed_count = 0
	var wrist_att := attach(frog, "L_Wrist")
	var hunt_head := attach(frog, "Head")
	var hips_att := attach(frog, "Hips")
	var real_hand := INF
	var real_lean := 0.0
	var head_level := INF
	frog.start_hunt()
	var top_speed := 0.0
	var top_anim := 0.0
	var best_hand := INF
	var best_aim := INF
	var max_lean := 0.0
	var reach_before_grab := 0.0
	for i in 300:
		await physics_frame
		top_speed = maxf(top_speed, Vector2(frog.velocity.x, frog.velocity.z).length())
		top_anim = maxf(top_anim, frog.player_animation.speed_scale)
		max_lean = maxf(max_lean, frog.chase_pose.lean)
		if clutch_count == 0:
			reach_before_grab = maxf(reach_before_grab, frog.chase_pose.reach)
		if frog.clutch_name() == "RUN" and frog.chase_pose.lean > 0.99:
			var inv: Transform3D = frog.global_transform.affine_inverse()
			real_lean = maxf(real_lean, -(inv * hunt_head.global_position - inv * hips_att.global_position).z)
			head_level = minf(head_level, real_head_error(frog, hunt_head, player.pivot.global_position))
		if frog.clutch_name() in ["HOLD", "CAUGHT"]:
			real_hand = minf(real_hand, wrist_att.global_position.distance_to(frog.chase_pose.reach_target))
			best_hand = minf(best_hand, frog.chase_pose.hand_error)
			best_aim = minf(best_aim, frog.chase_pose.aim_error)
		if caught_count > 0:
			break
	check(frog.is_hunting(), "Hunt mode is on")
	check(top_speed > 2.7, "Runs at chase speed (%.1f m/s)" % top_speed)
	check(top_anim > 1.7, "Walk clip is sped up into a run (x%.2f)" % top_anim)
	check(max_lean > 0.95, "Leans forward while chasing (%.2f)" % max_lean)
	check(reach_before_grab < 0.05, "Arm stays down while just running")
	check(clutch_count >= 1, "Starts a grab when close")
	check(best_aim < deg_to_rad(8.0), "Left arm points straight at the player's chest (%.1f deg)" % rad_to_deg(best_aim))
	check(best_hand < 0.2, "Left hand gets to the player's chest (%.2f m off)" % best_hand)
	check(real_lean > 0.2, "Rendered head is ahead of the hips while running (%.2f m)" % real_lean)
	check(head_level < 0.35, "Rendered head looks at the player while running (%.2f rad)" % head_level)
	check(real_hand < 0.2, "Rendered left wrist reaches the player's chest (%.2f m)" % real_hand)
	check(caught_count == 1 and frog.clutch_name() == "CAUGHT", "Catches a player who stays in range")
	check(frog.chase_pose.grip > 0.9, "Hand is clenched on the catch")
	var held := frog.global_position
	await frames(30)
	check(frog.global_position.distance_to(held) < 0.1, "Stands still after the catch")
	fx.queue_free()
	await frames(2)

	# 11. Hunt: a missed grab pulls the arm back and keeps running
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -8), true)
	await frames(10)
	clutch_count = 0
	caught_count = 0
	missed_count = 0
	var dodge := func():
		# Jump the player away the moment the arm swings out.
		var away: Vector3 = (player.global_position - frog.global_position)
		away.y = 0.0
		player.global_position += away.normalized() * 4.0
	frog.clutch_started.connect(dodge)
	frog.start_hunt()
	var run_after_miss := false
	var miss_frame := -1
	var second_grab_frame := -1
	for i in 420:
		await physics_frame
		if missed_count == 1 and miss_frame < 0:
			miss_frame = i
		if miss_frame >= 0 and frog.clutch_name() == "RUN" and frog.chase_pose.reach < 0.05:
			run_after_miss = true
		if clutch_count >= 2 and second_grab_frame < 0:
			second_grab_frame = i
			frog.clutch_started.disconnect(dodge)
	check(missed_count >= 1 and caught_count == 0, "Grab misses when the player dodges")
	check(run_after_miss, "Arm pulls back and it runs normally again")
	var gap := (second_grab_frame - miss_frame) / 60.0 if second_grab_frame >= 0 else 0.0
	check(second_grab_frame >= 0 and gap >= frog.recover_time + frog.clutch_cooldown - 0.05, "Waits before grabbing again (%.2f s)" % gap)
	fx.queue_free()
	await frames(2)

	# 12. Hunt: a hiding player is not caught; stop_hunt eases back to watching
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -4))
	await frames(10)
	caught_count = 0
	player.hiding = true
	frog.start_hunt()
	await frames(150)
	check(caught_count == 0, "Does not catch a hiding player")
	frog.stop_hunt()
	await frames(240)
	check(not frog.is_hunting() and frog.chase_pose.lean < 0.05 and frog.chase_pose.reach < 0.05, "Posture eases out after the hunt stops")
	check(frog.distance_to_target() > 2.8, "Backs off to its watching distance again (%.1f m)" % frog.distance_to_target())
	fx.queue_free()
	await frames(2)

	# 13. Threat: staring at it from close up for 5 s sets off the hunt
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -3))
	frog.approach_enabled = false
	frog.threat_enabled = true
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	var stages := []
	var on_stage := func(n): stages.append(n)
	frog.threat_stage_changed.connect(on_stage)
	frog.reset_threat()       # start the clock now (it may have seen us during setup)
	stages.clear()
	await frames(60)          # ~1 s
	check(stages.has(1) and not stages.has(2), "Stage 1 (noticed) right away, not yet stage 2")
	await frames(70)          # ~2.2 s
	check(stages.has(2) and not stages.has(3), "Stage 2 (stops backing off) after 2 s")
	await frames(130)         # ~4.3 s
	check(stages.has(3) and not frog.is_hunting(), "Stage 3 (about to go) after 4 s, not hunting yet")
	await frames(60)          # ~5.3 s
	check(frog.is_hunting(), "Hunts after 5 s of being stared at")
	fx.queue_free()
	await frames(2)

	# 14. Threat needs BOTH close range and looking; it drains instead of resetting
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -3))
	frog.approach_enabled = false
	frog.threat_enabled = true
	await frames(10)
	player.set_third_person(false)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position) + PI
	await frames(360)
	check(frog.threat < 0.01 and not frog.is_hunting(), "Close but looking away: no threat")
	player.global_position = Vector3(0, 0.15, 4)   # 7 m away
	await frames(5)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(360)
	check(frog.threat < 0.01 and not frog.is_hunting(), "Looking from outside the range: no threat")
	player.global_position = Vector3(0, 0.15, 0)
	await frames(5)
	player.pivot.rotation.y = yaw_towards(player.global_position, frog.global_position)
	await frames(180)
	var peak: float = frog.threat
	player.pivot.rotation.y += PI
	await frames(90)
	check(peak > 2.7 and frog.threat > peak - 1.8 and frog.threat < peak - 1.2, "Looking away drains it gradually (%.1f -> %.1f s)" % [peak, frog.threat])
	fx.queue_free()
	await frames(2)

	# 15. Choke: lifts the player by the throat (checked on the rendered bones)
	fx = new_fixture(false)
	player = make_player(fx, Vector3(0, 0.15, 0))
	frog = make_frog(fx, player, Vector3(0, 0.05, -3), true)
	await frames(10)
	var choke: Node3D = Node3D.new()
	choke.set_script(load("res://scripts/frog_choke.gd"))
	fx.add_child(choke)
	var choke_done := [false]
	choke.finished.connect(func(): choke_done[0] = true)
	frog.caught_player.connect(func(): choke.start(frog, player))
	frog.start_hunt()
	var pskel: Skeleton3D = player.body_visual.find_child("Skeleton3D", true, false)
	var p_neck := BoneAttachment3D.new(); p_neck.bone_name = "neck"; pskel.add_child(p_neck)
	var p_lhand := BoneAttachment3D.new(); p_lhand.bone_name = "LeftHand"; pskel.add_child(p_lhand)
	var p_rhand := BoneAttachment3D.new(); p_rhand.bone_name = "RightHand"; pskel.add_child(p_rhand)
	var f_wrist := attach(frog, "L_Wrist")
	var lift := 0.0
	var throat_gap := INF
	var hands_gap := INF
	var started_at := -1
	var ended_at := -1
	var held_during := true
	for i in 600:
		await physics_frame
		await process_frame
		if choke.running and started_at < 0:
			started_at = i
		if choke.running and choke.t > 1.6:
			lift = maxf(lift, player.global_position.y)
			held_during = held_during and player.held
			throat_gap = minf(throat_gap, f_wrist.global_position.distance_to(p_neck.global_position))
			hands_gap = minf(hands_gap, maxf(p_lhand.global_position.distance_to(f_wrist.global_position), p_rhand.global_position.distance_to(f_wrist.global_position)))
		if choke_done[0]:
			ended_at = i
			break
	check(started_at >= 0, "Choke starts on the catch")
	check(lift > 0.35, "Player is lifted off the ground (feet %.2f m up)" % lift)
	check(held_during, "Player has no control while held")
	check(throat_gap < 0.16, "Frog's rendered wrist is at the player's throat (%.2f m)" % throat_gap)
	check(hands_gap < 0.2, "Player's rendered hands claw at the frog's wrist (%.2f m)" % hands_gap)
	var dur := (ended_at - started_at) / 60.0
	check(ended_at > 0 and dur > 3.0 and dur < 4.2, "Ends black after about 3.4 s (%.1f s)" % dur)
	choke.cleanup()
	frog.stop_hunt()
	await frames(5)
	check(not player.held and player.camera.current, "Cleanup hands control and the camera back")
	check(pskel.find_child("StrugglePose", false, false) == null or pskel.find_child("StrugglePose", false, false).is_queued_for_deletion(), "Struggle pose removed")
	fx.queue_free()
	await frames(2)

	print("EXITROOM_FROG_TEST_FAILURES=", failures)
	quit(1 if failures > 0 else 0)
