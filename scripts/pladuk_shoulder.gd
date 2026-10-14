extends Node3D
## Pladuk hangs off Phakin's back. Only its face ever reaches his right shoulder,
## and only in first person: the moment the view switches to third person it is gone.
## Add as a child of the player's camera, then call setup(player).

const PladukScene = preload("res://3Dmodel_import/pladuk.glb")

signal leaned_in
signal leaned_out

# Camera-space point the face sits at: in view (right edge) and hidden (behind the ear).
const FACE_SHOWN := Vector3(.40, .03, -.46)    # eye level: clear of the subtitle box
const FACE_HIDDEN := Vector3(.50, -.08, .32)
const LEAN_IN_TIME := 1.6     # slow, so it is noticed late
const LEAN_OUT_TIME := .9

var player: CharacterBody3D
var rig: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var eyes := PackedInt32Array()
var lean := 0.0               # 0 hidden .. 1 face at the shoulder
var enabled := true           # the chapter turns it off for cutscenes
var pressure := 0.0           # 0..1 from the chapter: leans come sooner when it is high
var rng := RandomNumberGenerator.new()
var _wait := 0.0
var _hold := 0.0
var _tween: Tween
var leaning := false
var face_light: OmniLight3D

func setup(p: CharacterBody3D) -> void:
	player = p
	rng.randomize()
	rig = PladukScene.instantiate() as Node3D
	rig.name = "Pladuk"
	add_child(rig)
	for m in rig.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton = rig.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		for bone in ["left_eye", "right_eye"]:
			var i := skeleton.find_bone(bone)
			if i >= 0: eyes.append(i)
	# A faint, cold light on its face only: barely there in the dark.
	face_light = OmniLight3D.new()
	face_light.name = "FaceLight"
	face_light.light_color = Color(.62, .72, .86)
	face_light.light_energy = .55
	face_light.omni_range = .75
	face_light.omni_attenuation = 1.6
	face_light.visible = false
	add_child(face_light)
	anim = rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Idle_Crawl"):
		anim.get_animation("Idle_Crawl").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle_Crawl")
	player.view_changed.connect(_on_view_changed)
	_wait = rng.randf_range(6.0, 10.0)   # the first one comes early
	_apply()

func _on_view_changed(_third: bool) -> void:
	_apply()

# Seconds until the next lean. Shorter while pressure is high.
func next_wait() -> float:
	return lerpf(rng.randf_range(15.0, 40.0), rng.randf_range(4.0, 9.0), clampf(pressure, 0.0, 1.0))

func lean_in() -> void:
	if leaning or not enabled: return
	leaning = true
	_hold = rng.randf_range(1.2, 2.0)
	_tween_to(1.0, LEAN_IN_TIME)
	leaned_in.emit()

func lean_out() -> void:
	if not leaning: return
	leaning = false
	_tween_to(0.0, LEAN_OUT_TIME)
	_wait = next_wait()
	leaned_out.emit()

# Gone at once (cutscene, catch, third person); the timer starts over.
func hide_now() -> void:
	if _tween: _tween.kill()
	leaning = false
	lean = 0.0
	_wait = next_wait()
	_apply()

func is_showing() -> bool:
	return rig != null and rig.visible

func _tween_to(value: float, seconds: float) -> void:
	if _tween: _tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "lean", value, seconds)

func _process(delta: float) -> void:
	if player == null: return
	var game: Node = player.game
	var running := game == null or bool(game.get("playing"))
	if player.third_person or not enabled:
		if lean > 0.0 or leaning: hide_now()
		return
	if running:
		if leaning:
			if lean >= .999:
				_hold -= delta
				if _hold <= 0.0: lean_out()
		else:
			_wait -= delta
			if _wait <= 0.0: lean_in()
	_apply()

func _apply() -> void:
	if rig == null: return
	rig.visible = enabled and not player.third_person and lean > .01
	face_light.visible = rig.visible
	if not rig.visible: return
	var target := FACE_HIDDEN.lerp(FACE_SHOWN, lean)
	face_light.position = target * .55
	# The model faces +Z: turn it so the face looks back at the camera (the eyes).
	rig.basis = Basis.looking_at(-target.normalized(), Vector3.UP, true)
	var face := _face_in_rig()
	rig.position = target - rig.basis * face

# Midpoint of the eyes in the rig's own (unrotated) space.
func _face_in_rig() -> Vector3:
	if skeleton == null or eyes.is_empty():
		return Vector3(0, .9, .3)
	var sum := Vector3.ZERO
	for i in eyes:
		sum += skeleton.global_transform * skeleton.get_bone_global_pose(i).origin
	var world := sum / eyes.size()
	return rig.global_transform.affine_inverse() * world
