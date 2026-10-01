extends CharacterBody3D

var camera: Camera3D
var torch: SpotLight3D
var locked := false
var reduced_motion := false
var pitch := 0.0
var step_time := 0.0
var footstep: AudioStreamPlayer

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	var shape := CapsuleShape3D.new()
	shape.radius = 0.23
	shape.height = 1.7
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.86
	add_child(col)
	camera = Camera3D.new()
	camera.position.y = 1.62
	camera.fov = 70
	camera.near = 0.04
	camera.current = true
	add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.15,-0.13,0)
	torch.light_color = Color(0.87,0.9,0.79)
	torch.light_energy = 1.6
	torch.spot_range = 13
	torch.spot_angle = 32
	torch.shadow_enabled = true
	torch.visible = false
	camera.add_child(torch)
	footstep = AudioStreamPlayer.new()
	footstep.stream = load("res://audio/step.wav")
	footstep.volume_db = -23
	add_child(footstep)

func _unhandled_input(event: InputEvent) -> void:
	if locked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * 0.002
		pitch = clampf(pitch-event.relative.y*0.002,-1.3,1.3)
		camera.rotation.x = pitch
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		torch.visible = not torch.visible

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if not locked and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var axis := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction = (basis * Vector3(axis.x,0,axis.y)).normalized()
		if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE): velocity.y=4.5
	var speed := 3.3 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.1
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*12)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*12)
	if not is_on_floor(): velocity.y -= 15*delta
	move_and_slide()
	if is_on_floor() and direction.length()>0.1:
		step_time += delta
		if step_time>0.5:
			step_time=0
			footstep.pitch_scale=randf_range(.9,1.1)
			footstep.play()

func focus_on(point: Vector3) -> void:
	locked=true
	velocity=Vector3.ZERO
	var d := (point-camera.global_position).normalized()
	var yaw := atan2(-d.x,-d.z)
	var end_yaw := rotation.y + wrapf(yaw-rotation.y,-PI,PI)
	var end_pitch := asin(clampf(d.y,-1,1))
	var t := create_tween().set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self,"rotation:y",end_yaw,.65 if reduced_motion else .22)
	t.tween_property(camera,"rotation:x",end_pitch,.65 if reduced_motion else .22)
	await t.finished
	pitch=end_pitch
	await get_tree().create_timer(.55).timeout
	locked=false

func target() -> Node:
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*2.6,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return null
	var n: Node = hit.collider
	while n:
		if n.has_meta("action"): return n
		n=n.get_parent()
	return null
