extends CharacterBody3D

const HazmatScene = preload("res://3Dmodel_import/backrooms_rigged_hazmat.glb")

var game: Node3D
var pivot: Node3D
var camera: Camera3D
var body_visual: Node3D
var hazmat_animation: AnimationPlayer
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
	camera = Camera3D.new()
	camera.fov = 73
	camera.near = 0.05
	camera.rotation.x = pitch
	pivot.add_child(camera)
	camera.current = true
	body_visual = Node3D.new()
	body_visual.name = "HazmatVisual"
	add_child(body_visual)
	# Keep the demo model available for future cutscenes, but outside the view
	# of the first-person camera so its helmet never blocks the scene.
	body_visual.visible = false
	body_visual.rotation.y = PI
	var suit := HazmatScene.instantiate() as Node3D
	suit.name = "HazmatDemo"
	body_visual.add_child(suit)
	# The imported character spans 3.21 m and starts 0.33 m below origin.
	# These measured values make the demo suit 1.70 m tall on the floor.
	suit.scale = Vector3.ONE * 0.53
	suit.position.y = 0.176
	suit.rotation.y = 0.0
	var helper := suit.find_child("Icosphere", true, false)
	if helper is Node3D:
		(helper as Node3D).visible = false
	hazmat_animation = suit.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if hazmat_animation:
		var run_cycle := hazmat_animation.get_animation("mixamo_com")
		if run_cycle:
			run_cycle.loop_mode = Animation.LOOP_LINEAR
			hazmat_animation.play("mixamo_com")
			hazmat_animation.speed_scale = 0.0
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
		camera.rotation.x = pitch
		torch.rotation.x = pitch
	if event.is_action_pressed("flashlight") and not hiding:
		torch.visible = not torch.visible

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
	if direction.length() > 0.1:
		if hazmat_animation:
			hazmat_animation.speed_scale = 1.0 if sprinting else 0.58
		body_visual.rotation.y = lerp_angle(body_visual.rotation.y, atan2(direction.x, direction.z), delta * 12)
		step_clock += delta * (1.55 if sprinting else 1)
		body_visual.position.y = sin(step_clock * 16) * 0.025
		if step_clock > 0.43:
			step_clock = 0
			footstep.pitch_scale = randf_range(0.85, 1.1)
			footstep.play()
	else:
		if hazmat_animation:
			hazmat_animation.speed_scale = 0.0
		body_visual.position.y = 0

func set_hiding(value: bool) -> void:
	hiding = value
	body_visual.visible = false
	torch.visible = not value
	velocity = Vector3.ZERO


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
