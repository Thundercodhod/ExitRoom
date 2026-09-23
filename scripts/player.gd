extends CharacterBody3D

const HazmatScene = preload("res://3Dmodel_import/backrooms_rigged_hazmat.glb")

var game: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var body_visual: Node3D
var hazmat_animation: AnimationPlayer
var torch: SpotLight3D
var stamina := 100.0
var hiding := false
var sprinting := false
var step_clock := 0.0
var footstep: AudioStreamPlayer
var pitch := -0.15

func _ready() -> void:
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
	arm = SpringArm3D.new()
	arm.spring_length = 2.6
	arm.margin = 0.18
	arm.collision_mask = 1
	var camera_shape := SphereShape3D.new()
	camera_shape.radius = 0.14
	arm.shape = camera_shape
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 73
	camera.near = 0.08
	arm.add_child(camera)
	camera.current = true
	body_visual = Node3D.new()
	body_visual.name = "HazmatVisual"
	add_child(body_visual)
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
	torch.position = Vector3(0.28, -0.2, -0.25)
	torch.light_color = Color(0.88, 0.92, 0.78)
	torch.light_energy = 5.0
	torch.spot_range = 19.0
	torch.spot_angle = 38.0
	torch.spot_attenuation = 1.1
	torch.shadow_enabled = true
	pivot.add_child(torch)
	footstep = AudioStreamPlayer.new()
	footstep.stream = load("res://audio/step.wav")
	footstep.volume_db = -15
	add_child(footstep)

func _unhandled_input(event: InputEvent) -> void:
	if not game.playing:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pivot.rotation.y -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -0.85, 0.55)
		arm.rotation.x = pitch
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
	velocity.y -= 22 * delta
	if is_on_floor():
		velocity.y = -0.1
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
	body_visual.visible = not value
	torch.visible = not value
	velocity = Vector3.ZERO
