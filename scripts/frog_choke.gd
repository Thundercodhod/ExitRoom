extends Node3D
# The frog's catch: it takes the player by the throat with its left hand, lifts
# them off the ground and holds them there while the screen closes in to black.
#
#   var choke := FrogChoke.new()
#   add_child(choke)                 # anywhere in the level
#   choke.finished.connect(...)      # screen is fully black: reset the level here
#   choke.start(frog, player)        # frog should be in HUNT with clutch CAUGHT
#   ...
#   choke.cleanup()                  # gives control back (call while still black)
#
# Timeline (seconds): 0-0.4 pull in to the throat, 0.4-1.4 lift, 1.4-3.4 hold
# while the vignette closes, 3.4 black -> finished.
# The hold points below are where the hand goes; the player is placed so that
# the front of their throat is in it.

signal lifted       # feet are off the ground (end of the lift)
signal finished     # fully black

const StrugglePose = preload("res://scripts/player_struggle_pose.gd")

const PULL_TIME := 0.4
const LIFT_END := 1.4
const HOLD_END := 3.4
# Hold points, relative to the frog: forward along its facing, toward its left
# hand side, and height above its feet. The lift raises the throat ~0.35 m.
const LOW_POINT := Vector3(0.12, 1.40, 0.55)    # (left, up, forward)
const HIGH_POINT := Vector3(0.15, 1.76, 0.36)    # ~0.42 m lift, near full arm reach
const THROAT_DEPTH := 0.07   # the neck bone is mid-neck; the hand sits on the front of the throat

var frog: CharacterBody3D
var player: CharacterBody3D
var t := 0.0
var running := false
var struggle
var camera: Camera3D
var dark: ColorRect
var breath: AudioStreamPlayer
var heartbeat: AudioStreamPlayer

var _start_throat := Vector3.ZERO
var _neck_offset := Vector3.ZERO
var _frog_wrist: BoneAttachment3D
var _cam_from := Vector3.ZERO
var _cam_to := Vector3.ZERO
var _lift_emitted := false
var _was_visible := true


func start(the_frog: CharacterBody3D, the_player: CharacterBody3D) -> void:
	frog = the_frog
	player = the_player
	t = 0.0
	running = true
	_lift_emitted = false
	player.held = true
	player.velocity = Vector3.ZERO
	player._play_animation("idle", 1.0)
	# The player faces the frog (model faces +Z, same formula as player.gd).
	var to_frog := frog.global_position - player.global_position
	to_frog.y = 0.0
	if to_frog.length() > 0.01:
		player.body_visual.rotation.y = atan2(to_frog.x, to_frog.z)
	_was_visible = player.body_visual.visible
	player.body_visual.visible = true       # seen from the cinematic camera
	var skel := player.body_visual.find_child("Skeleton3D", true, false) as Skeleton3D
	_start_throat = player.global_position + Vector3.UP * 1.42
	_neck_offset = Vector3.UP * 1.42
	if skel:
		var neck := skel.find_bone("Neck")
		if neck >= 0:
			_start_throat = skel.global_transform * skel.get_bone_global_pose(neck).origin
			_neck_offset = _start_throat - player.global_position
		struggle = StrugglePose.new()
		struggle.name = "StrugglePose"
		skel.add_child(struggle)
		struggle.setup()
	_frog_wrist = BoneAttachment3D.new()
	_frog_wrist.bone_name = "L_Wrist"
	frog.skeleton.add_child(_frog_wrist)
	frog.hold_throat(_start_throat)
	_setup_camera()
	_setup_screen()
	_setup_audio()


func is_lifted() -> bool:
	return _lift_emitted


# The point the frog holds the throat at, for the hold phase.
func high_point() -> Vector3:
	return _frog_point(HIGH_POINT)


func cleanup() -> void:
	running = false
	if is_instance_valid(frog):
		frog.release_throat()
	if is_instance_valid(_frog_wrist):
		_frog_wrist.queue_free()
	if struggle and is_instance_valid(struggle):
		struggle.queue_free()
	struggle = null
	if is_instance_valid(player):
		player.held = false
		player.body_visual.visible = _was_visible
		player.camera.current = true
	for n in [camera, breath, heartbeat]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(dark):
		dark.get_parent().queue_free()


func _process(delta: float) -> void:
	if not running or not is_instance_valid(frog) or not is_instance_valid(player):
		return
	t += delta
	# Where the frog's hand (and the player's throat) should be right now.
	var low := _frog_point(LOW_POINT)
	var high := _frog_point(HIGH_POINT)
	var throat: Vector3
	if t < PULL_TIME:
		throat = _start_throat.lerp(low, _ease(t / PULL_TIME))
	elif t < LIFT_END:
		throat = low.lerp(high, _ease((t - PULL_TIME) / (LIFT_END - PULL_TIME)))
	else:
		var shake := 0.012 * Vector3(sin(t * 23.0), sin(t * 31.0 + 1.0), sin(t * 19.0 + 2.0))
		throat = high + shake
	frog.hold_throat(throat)
	player.global_position = throat - _neck_offset + _frog_forward() * THROAT_DEPTH

	if struggle:
		struggle.weight = clampf((t - 0.15) / 0.5, 0.0, 1.0)
		var fade := clampf((t - 0.6) / (HOLD_END - 0.6), 0.0, 1.0)
		struggle.kick = lerpf(1.0, 0.12, fade)
		struggle.kick_speed = lerpf(11.0, 3.5, fade)
		struggle.grab_point = _frog_wrist.global_position

	if not _lift_emitted and t >= LIFT_END:
		_lift_emitted = true
		lifted.emit()

	# Camera: low and to the side, looking up at the hold, slowly pushing in.
	var k := _ease(clampf(t / HOLD_END, 0.0, 1.0))
	camera.global_position = _cam_from.lerp(_cam_to, k)
	camera.look_at(throat + Vector3.DOWN * 0.7)

	# Screen closes in during the hold, then black.
	# Clear through the lift; closes slowly at first, then fast at the end.
	var closing := pow(clampf((t - LIFT_END) / (HOLD_END - LIFT_END), 0.0, 1.0), 1.7)
	(dark.material as ShaderMaterial).set_shader_parameter("closing", closing)
	if breath:
		breath.volume_db = lerpf(-6.0, -30.0, closing)
	if heartbeat:
		heartbeat.pitch_scale = lerpf(1.35, 0.6, closing)
		heartbeat.volume_db = lerpf(-14.0, -4.0, closing)
	if t >= HOLD_END:
		running = false
		(dark.material as ShaderMaterial).set_shader_parameter("closing", 1.0)
		dark.material.set_shader_parameter("black", 1.0)
		if breath:
			breath.stop()
		finished.emit()


func _frog_forward() -> Vector3:
	var forward := -frog.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


# A point in the frog's frame: x toward its left hand side, y up, z forward.
func _frog_point(local: Vector3) -> Vector3:
	var forward := _frog_forward()
	# The model is turned 180 degrees inside the actor, so the frog's own left
	# (skeleton +X, where the clutching arm is) is the actor's -X.
	var left := -frog.global_transform.basis.x
	left.y = 0.0
	left = left.normalized()
	return frog.global_position + left * local.x + Vector3.UP * local.y + forward * local.z


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _setup_camera() -> void:
	var forward := -frog.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# On the frog's left, the side of the clutching arm, so the hand on the
	# throat faces the camera.
	var side := -frog.global_transform.basis.x
	side.y = 0.0
	side = side.normalized()
	var mid := frog.global_position + forward * 0.45
	# Low and wide enough to keep both bodies and the gap under the player's
	# feet in frame, creeping in a little during the hold.
	# Camera height is kept above knee-high grass so the feet stay visible.
	_cam_from = mid + side * 3.4 - forward * 0.2 + Vector3.UP * 0.8
	_cam_to = mid + side * 2.8 - forward * 0.1 + Vector3.UP * 0.9
	camera = Camera3D.new()
	camera.name = "ChokeCamera"
	camera.fov = 58.0
	camera.near = 0.05
	add_child(camera)
	camera.global_position = _cam_from
	camera.look_at(_start_throat)
	camera.current = true


func _setup_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	dark = ColorRect.new()
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float closing : hint_range(0.0, 1.0) = 0.0;
uniform float black : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float r = length(p);
	float edge = mix(1.25, 0.1, closing);
	float v = smoothstep(edge - 0.4, edge, r);
	COLOR = vec4(0.0, 0.0, 0.0, max(v * (0.25 + 0.75 * closing), black));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	dark.material = mat
	layer.add_child(dark)


func _setup_audio() -> void:
	breath = AudioStreamPlayer.new()
	var b := (load("res://audio/frog_chapter/breath.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	b.loop_mode = AudioStreamWAV.LOOP_FORWARD
	b.loop_end = b.data.size() / 2
	breath.stream = b
	breath.volume_db = -6.0
	add_child(breath)
	breath.play()
	heartbeat = AudioStreamPlayer.new()
	var h := (load("res://audio/frog_chapter/heartbeat.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	h.loop_mode = AudioStreamWAV.LOOP_FORWARD
	h.loop_end = h.data.size() / 2
	heartbeat.stream = h
	heartbeat.volume_db = -14.0
	add_child(heartbeat)
	heartbeat.play()
