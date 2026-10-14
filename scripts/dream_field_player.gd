extends CharacterBody3D
## Independent first-person controls; no stamina limit in the free-roam field.
const STEPS := [
	preload("res://audio/dream_field/grass_step_1.wav"),
	preload("res://audio/dream_field/grass_step_2.wav"),
	preload("res://audio/dream_field/grass_step_3.wav"),
	preload("res://audio/dream_field/grass_step_4.wav")
]
@onready var camera: Camera3D = $Camera3D
@onready var capsule: CollisionShape3D = $CollisionShape3D
var locked := false
var crouching := false
var reduced_motion := false
var pitch := 0.0
var travelled := 0.0
var gait := 0.0
var footstep: AudioStreamPlayer
var step_index := 0
const EYE_HEIGHT := 1.64

func _ready() -> void:
	floor_snap_length = .35
	floor_stop_on_slope = true
	capsule.shape = capsule.shape.duplicate()
	footstep = AudioStreamPlayer.new()
	footstep.bus = &"SFX"
	footstep.volume_db = -24.0
	add_child(footstep)

func _unhandled_input(event: InputEvent) -> void:
	if locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * .0020
		pitch = clampf(pitch - event.relative.y * .0020, -1.35, 1.35)
		camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	var running := false
	var wants_crouch := not locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_physical_key_pressed(KEY_CTRL)
	if wants_crouch:
		set_crouching(true)
	elif crouching and can_stand():
		set_crouching(false)
	if not locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = (basis * Vector3(axis.x, 0, axis.y)).normalized()
		running = Input.is_physical_key_pressed(KEY_SHIFT)
		if is_on_floor() and not crouching and Input.is_physical_key_pressed(KEY_SPACE): velocity.y = 4.0
	var speed := 1.35 if crouching else (5.3 if running else 2.9)
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 13.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 13.0)
	if not is_on_floor(): velocity.y -= 19.0 * delta
	var previous := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - previous.x, global_position.z - previous.z).length()
	if is_on_floor() and moved > .002:
		travelled += moved
		gait += moved * 4.6
		if travelled > (1.65 if running else 1.25):
			travelled = 0.0
			footstep.stream = STEPS[step_index % STEPS.size()]
			step_index += 1
			footstep.pitch_scale = randf_range(.91, 1.10)
			footstep.play()
	var bob := sin(gait) * .012 if not reduced_motion and moved > .002 and is_on_floor() else 0.0
	var eye_height := .86 if crouching else EYE_HEIGHT
	camera.position.y = eye_height if reduced_motion else lerpf(camera.position.y, eye_height + bob, 1.0 - exp(-delta * 12.0))

func set_crouching(value: bool) -> void:
	if crouching == value: return
	crouching = value
	(capsule.shape as CapsuleShape3D).height = .96 if value else 1.74
	capsule.position.y = .50 if value else .88

func can_stand() -> bool:
	var standing := CapsuleShape3D.new()
	standing.radius = .26
	standing.height = 1.74
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing
	query.transform = Transform3D(global_basis, global_position + Vector3(0,.90,0))
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
