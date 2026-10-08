extends CharacterBody3D

# Rigged with Godot's humanoid bone names at import (player_better_rig_bone_map.tres).
const MainCharacterScene = preload("res://assets/models/player/player_better_rig.glb")

# A heel touched the ground (also plays the footstep sound). Enemies can listen.
signal stepped(running: bool)

# Third-person by default. Press V in game to switch to first-person and back.
const THIRD_PERSON_DEFAULT := true
const CAMERA_DISTANCE := 2.4
const CAMERA_SHOULDER := 0.3
const FOV_THIRD := 65.0
const FOV_FIRST := 73.0
# Movement speeds (m/s). The idle, walk and run clips are generated for this
# model by tools/build_player_gait.gd (re-run it if you change the speeds).
const WALK_SPEED := 1.4
const SPRINT_SPEED := 4.8
const IdleClip = preload("res://assets/models/player/player_idle.tres")
const WalkClip = preload("res://assets/models/player/player_walk.tres")
const RunClip = preload("res://assets/models/player/player_run.tres")

var game: Node3D
var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var body_visual: Node3D
var player_animation: AnimationPlayer
var anim_names := {}
var current_anim := &""
var third_person := THIRD_PERSON_DEFAULT
var torch: SpotLight3D
var stamina := 100.0
var hiding := false
# Set by a cinematic that moves the player directly (e.g. the frog's choke):
# no input, no gravity, no animation changes until it is cleared.
var held := false
var sprinting := false
# Gait: one shared phase drives both cycles (0 = left heel down, 0.5 = right),
# so blending walk <-> run never crosses the legs. See _update_animation.
var gait_phase := 0.0
var anim_tree: AnimationTree
var _move_blend := 0.0
var _run_blend := 0.0
var _idle_time := 0.0
var footstep: AudioStreamPlayer
var atmosphere_audio: AudioStreamPlayer
var pitch := -0.05
const STEP_HEIGHT := 0.30
const JUMP_SPEED := 6.4

func _ready() -> void:
	if not InputMap.has_action("jump"):
		InputMap.add_action("jump")
		var jump_key := InputEventKey.new()
		jump_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("jump", jump_key)
	if not InputMap.has_action("toggle_view"):
		InputMap.add_action("toggle_view")
		var view_key := InputEventKey.new()
		view_key.physical_keycode = KEY_V
		InputMap.action_add_event("toggle_view", view_key)
	floor_snap_length = 0.32
	floor_stop_on_slope = true
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.87
	add_child(col)
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.55, 0)
	add_child(pivot)
	# The spring arm pitches with the mouse. In third-person it pulls the camera
	# back behind the player and shortens when a wall is in the way; with length 0
	# (first-person) the camera sits right at the eyes.
	spring_arm = SpringArm3D.new()
	spring_arm.name = "CameraArm"
	var arm_shape := SphereShape3D.new()
	arm_shape.radius = 0.2
	spring_arm.shape = arm_shape
	spring_arm.collision_mask = 1
	spring_arm.rotation.x = pitch
	pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.near = 0.05
	spring_arm.add_child(camera)
	camera.current = true
	body_visual = Node3D.new()
	body_visual.name = "PlayerVisual"
	add_child(body_visual)
	body_visual.rotation.y = PI
	# player_better_rig.glb is 1.70 m tall with its feet at y = 0 and faces +Z,
	# so levels keep setting body_visual.rotation.y = yaw - PI.
	var model := MainCharacterScene.instantiate() as Node3D
	model.name = "MainCharacter"
	body_visual.add_child(model)
	# The model ships without animations; the generated clips play on this.
	player_animation = AnimationPlayer.new()
	player_animation.name = "AnimationPlayer"
	model.add_child(player_animation)
	_resolve_animations()
	_setup_anim_tree()
	_play_animation("idle", 1.0)
	_apply_view()
	torch = SpotLight3D.new()
	torch.position = Vector3(0.12, -0.12, -0.08)
	torch.light_color = Color(0.88, 0.92, 0.78)
	torch.light_energy = 3.2
	torch.spot_range = 19.0
	torch.spot_angle = 38.0
	torch.spot_attenuation = 1.1
	torch.shadow_enabled = true
	torch.rotation.x = pitch
	pivot.add_child(torch)
	footstep = AudioStreamPlayer.new()
	footstep.stream = load("res://audio/step.wav")
	footstep.volume_db = -15
	add_child(footstep)
	atmosphere_audio = AudioStreamPlayer.new()
	if AudioServer.get_bus_index("Ambience") >= 0:
		atmosphere_audio.bus = &"Ambience"
	var drone := (load("res://audio/drone.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	drone.loop_mode = AudioStreamWAV.LOOP_FORWARD
	atmosphere_audio.stream = drone
	atmosphere_audio.volume_db = -29
	add_child(atmosphere_audio)
	atmosphere_audio.play()
	var darkness := CanvasLayer.new()
	darkness.name = "RetroHorrorLook"
	darkness.layer = 1
	add_child(darkness)
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	# Draw before the scene HUD, so only the world receives the retro effect.
	vignette_material.shader = preload("res://assets/shaders/retro_horror.gdshader")
	vignette.material = vignette_material
	darkness.add_child(vignette)

func _unhandled_input(event: InputEvent) -> void:
	if not game.playing or held:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -0.85, 0.55)
		spring_arm.rotation.x = pitch
		torch.rotation.x = pitch
	if event.is_action_pressed("flashlight") and not hiding:
		torch.visible = not torch.visible
	if event.is_action_pressed("toggle_view"):
		set_third_person(not third_person)

func _physics_process(delta: float) -> void:
	if not game.playing:
		return
	if held:
		velocity = Vector3.ZERO
		sprinting = false
		return
	if hiding:
		stamina = minf(100, stamina + delta * 16)
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (Basis(Vector3.UP, pivot.rotation.y) * Vector3(input.x, 0, input.y)).normalized()
	sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and stamina > 1
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	stamina = clampf(stamina + (-24 if sprinting else 15) * delta, 0, 100)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 18)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 18)
	var grounded := is_on_floor()
	velocity.y -= 22 * delta
	if grounded:
		velocity.y = -0.1
	if grounded and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_SPEED
	elif grounded and direction.length() > 0.1:
		try_step_up(direction * speed * delta)
	move_and_slide()
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if direction.length() > 0.1:
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(direction.x, direction.z), delta * 12)
	_update_animation(ground_speed, delta)

func set_hiding(value: bool) -> void:
	hiding = value
	_apply_view()
	torch.visible = not value
	velocity = Vector3.ZERO

func set_third_person(value: bool) -> void:
	third_person = value
	_apply_view()

func _apply_view() -> void:
	spring_arm.spring_length = CAMERA_DISTANCE if third_person else 0.0
	camera.position.x = CAMERA_SHOULDER if third_person else 0.0
	camera.fov = FOV_THIRD if third_person else FOV_FIRST
	# Hide the body in first-person (it would block the view) and while hiding.
	body_visual.visible = third_person and not hiding

# Idle, walk and run are the generated clips. anim_names maps idle/walk/run to
# the clip names (other scripts and tests use it).
func _resolve_animations() -> void:
	if not player_animation:
		return
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", IdleClip)
	lib.add_animation("walk", WalkClip)
	lib.add_animation("run", RunClip)
	player_animation.add_animation_library("gait", lib)
	anim_names["idle"] = &"gait/idle"
	anim_names["walk"] = &"gait/walk"
	anim_names["run"] = &"gait/run"


# idle → seek(clock) ─────────────────┐
# walk → seek(phase) ┐                 ├ move (Blend2) → out
# run  → seek(phase) ┴ gait (Blend2) ──┘
# The tree never advances on its own (manual mode, advance(0)): every clip is
# placed explicitly, so the feet stay in step with the body, which only moves
# on physics ticks, however fast frames are rendered.
func _setup_anim_tree() -> void:
	if not player_animation or not anim_names.has("idle"):
		return
	var bt := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = anim_names["idle"]
	var walk := AnimationNodeAnimation.new()
	walk.animation = anim_names["walk"]
	var run := AnimationNodeAnimation.new()
	run.animation = anim_names["run"]
	bt.add_node("idle", idle)
	bt.add_node("walk", walk)
	bt.add_node("run", run)
	bt.add_node("idle_seek", AnimationNodeTimeSeek.new())
	bt.add_node("walk_seek", AnimationNodeTimeSeek.new())
	bt.add_node("run_seek", AnimationNodeTimeSeek.new())
	bt.add_node("gait", AnimationNodeBlend2.new())
	bt.add_node("move", AnimationNodeBlend2.new())
	bt.connect_node("walk_seek", 0, "walk")
	bt.connect_node("run_seek", 0, "run")
	bt.connect_node("gait", 0, "walk_seek")
	bt.connect_node("gait", 1, "run_seek")
	bt.connect_node("idle_seek", 0, "idle")
	bt.connect_node("move", 0, "idle_seek")
	bt.connect_node("move", 1, "gait")
	bt.connect_node("output", 0, "move")
	anim_tree = AnimationTree.new()
	anim_tree.name = "GaitTree"
	anim_tree.tree_root = bt
	player_animation.get_parent().add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(player_animation)
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim_tree.active = true


# Every rendered frame: breathe (idle clock) and show the current gait phase.
# Runs even when gameplay is paused for a cutscene, so the idle stays alive.
func _process(delta: float) -> void:
	_idle_time += delta
	_apply_blends()


# Kept for other scripts (e.g. the frog's choke puts the player in idle).
func _play_animation(key: String, _speed: float) -> void:
	if not anim_names.has(key):
		return
	current_anim = anim_names[key]
	_move_blend = 0.0 if key == "idle" else 1.0
	_run_blend = 1.0 if key == "run" else 0.0
	_apply_blends()


# Advances the shared gait phase by distance covered / stride length, so a foot
# on the ground moves back exactly as fast as the body moves forward.
func _update_animation(ground_speed: float, delta: float) -> void:
	if not anim_tree:
		return
	var walk_stride: float = WalkClip.get_meta("stride")
	var run_stride: float = RunClip.get_meta("stride")
	_run_blend = clampf((ground_speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0)
	# Fade in from idle over the first ~60 % of walking speed.
	_move_blend = clampf(ground_speed / (WALK_SPEED * 0.6), 0.0, 1.0)
	var stride := lerpf(walk_stride, run_stride, _run_blend)
	var before := gait_phase
	gait_phase = fposmod(gait_phase + ground_speed / stride * delta, 1.0)
	# Footstep on each heel contact (phase 0 and 0.5).
	if _move_blend > 0.5 and (gait_phase < before or (before < 0.5 and gait_phase >= 0.5)):
		footstep.pitch_scale = randf_range(0.85, 1.1) * lerpf(1.0, 1.15, _run_blend)
		footstep.volume_db = lerpf(-15.0, -10.0, _run_blend)
		footstep.play()
		stepped.emit(_run_blend > 0.5)
	if _move_blend <= 0.0:
		current_anim = anim_names["idle"]
	else:
		current_anim = anim_names["run"] if _run_blend > 0.5 else anim_names["walk"]
	_apply_blends()


func _apply_blends() -> void:
	if not anim_tree:
		return
	anim_tree.set("parameters/move/blend_amount", _move_blend)
	anim_tree.set("parameters/gait/blend_amount", _run_blend)
	var idle_len := player_animation.get_animation(anim_names["idle"]).length
	anim_tree.set("parameters/idle_seek/seek_request", fposmod(_idle_time, idle_len))
	anim_tree.set("parameters/walk_seek/seek_request", gait_phase * WalkClip.length)
	anim_tree.set("parameters/run_seek/seek_request", gait_phase * RunClip.length)
	anim_tree.advance(0.0)
func try_step_up(motion: Vector3) -> void:
	# Raise only when a low obstacle blocks us, the capsule clears it, and a
	# walkable landing is found. Tall walls and low ceilings remain solid.
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if hit.get_normal().y > 0.65:
		return
	if test_move(global_transform, Vector3.UP * STEP_HEIGHT):
		return
	var raised := global_transform
	raised.origin.y += STEP_HEIGHT
	var step_motion := motion.normalized() * maxf(motion.length(), 0.34)
	if test_move(raised, step_motion):
		return
	raised.origin += step_motion
	var landing := KinematicCollision3D.new()
	if test_move(raised, Vector3.DOWN * (STEP_HEIGHT + 0.05), landing):
		var rise := STEP_HEIGHT + landing.get_travel().y
		if landing.get_normal().y > 0.7 and rise > 0.015:
			global_position = raised.origin + landing.get_travel() + Vector3.UP * 0.005
