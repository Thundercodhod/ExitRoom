extends CharacterBody3D

const MainCharacterScene = preload("res://assets/models/player/main_character.glb")

# Third-person by default. Press V in game to switch to first-person and back.
const THIRD_PERSON_DEFAULT := true
const CAMERA_DISTANCE := 2.4
const CAMERA_SHOULDER := 0.3
const FOV_THIRD := 65.0
const FOV_FIRST := 73.0
# Ground speed (m/s) of the planted foot in each baked clip. Used to scale the
# playback speed so feet do not slide on the floor.
const WALK_CLIP_SPEED := 0.22
const RUN_CLIP_SPEED := 1.98
const WALK_CLIP_MAX_SPEED := 0.6
const ANIM_BLEND := 0.2

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
var sprinting := false
var step_clock := 0.0
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
	# main_character.glb is 1.64 m tall with its feet at y = 0 and faces +Z, like
	# the old Hazmat demo, so levels keep setting body_visual.rotation.y = yaw - PI.
	var model := MainCharacterScene.instantiate() as Node3D
	model.name = "MainCharacter"
	body_visual.add_child(model)
	player_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_resolve_animations()
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
	if not game.playing:
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
	if hiding:
		stamina = minf(100, stamina + delta * 16)
		return
	var input := Input.get_vector("left", "right", "forward", "back")
	var direction := (Basis(Vector3.UP, pivot.rotation.y) * Vector3(input.x, 0, input.y)).normalized()
	sprinting = Input.is_action_pressed("sprint") and input.length() > 0.1 and stamina > 1
	var speed := 4.8 if sprinting else 2.65
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
		step_clock += delta * (1.55 if sprinting else 1)
		if step_clock > 0.43:
			step_clock = 0
			footstep.pitch_scale = randf_range(0.85, 1.1)
			footstep.play()
	_update_animation(ground_speed)

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

# Find the baked clips by keyword so the code works whether or not the importer
# keeps the "-loop" suffix on the animation names.
func _resolve_animations() -> void:
	if not player_animation:
		return
	for key in ["idle", "walk", "run"]:
		for clip in player_animation.get_animation_list():
			if String(clip).to_lower().begins_with(key):
				anim_names[key] = clip
				player_animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _play_animation(key: String, speed: float) -> void:
	if not player_animation or not anim_names.has(key):
		return
	var clip: StringName = anim_names[key]
	if current_anim != clip:
		current_anim = clip
		player_animation.play(clip, ANIM_BLEND)
	player_animation.speed_scale = speed

func _update_animation(ground_speed: float) -> void:
	if ground_speed < 0.15:
		_play_animation("idle", 1.0)
	elif ground_speed < WALK_CLIP_MAX_SPEED:
		_play_animation("walk", ground_speed / WALK_CLIP_SPEED)
	else:
		_play_animation("run", ground_speed / RUN_CLIP_SPEED)


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
