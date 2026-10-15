extends Node3D
## Level 06: free exploration, one interaction, and a quiet return to the selector.
const Style = preload("res://scripts/anthology_style.gd")
const Terrain = preload("res://scripts/dream_field_terrain.gd")
const CONTROLS := "WASD เดิน   /   SHIFT วิ่ง   /   CTRL ย่อตัว   /   ESC พัก"
@onready var player: CharacterBody3D = $Player
@onready var monument: Node3D = $World/WakeMonument
@onready var grass: Node3D = $DryGrass
var playing := true
var waking := false
var prompt: Label
var hint: Label
var heading: Control
var curtain: ColorRect
var ambient: Array[AudioStreamPlayer] = []
const MUSIC := "res://audio/dream_field/field_music.mp3"
const MUSIC_DB := -14.0
var music: AudioStreamPlayer
var music_fade: Tween
const EndCredits = preload("res://scripts/end_credits.gd")
const CREDITS_DIM := .6
var credits: CanvasLayer
var time_in_field := 0.0
var was_captured := false

func _ready() -> void:
	player.position.y = Terrain.height_at(player.position.x, player.position.z) + .08
	player.pitch = .04
	player.camera.rotation.x = player.pitch
	player.reduced_motion = bool(Anthology.settings.reduced_motion)
	make_ui()
	start_ambience()
	Anthology.transition_finished.connect(on_entry_finished)
	if not Anthology.changing: on_entry_finished.call_deferred()

func make_ui() -> void:
	var film_layer := CanvasLayer.new()
	film_layer.layer = 1
	add_child(film_layer)
	var film := ColorRect.new()
	film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var film_material := ShaderMaterial.new()
	film_material.shader = preload("res://assets/dream_field/dream_film.gdshader")
	film.material = film_material
	film_layer.add_child(film)
	var layer := CanvasLayer.new()
	layer.name = "DreamHUD"
	layer.layer = 5
	add_child(layer)
	heading = Control.new()
	heading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(heading)
	var title := Style.label("06   /   DREAM FIELD", 17, Color("e0c9a5"), true)
	title.position = Vector2(34,28)
	heading.add_child(title)
	var subtitle := Style.label("ทุ่งในฝัน", 23, Color("ddd5c8"))
	subtitle.position = Vector2(34,54)
	heading.add_child(subtitle)
	var dot := Style.label("·", 20, Color(1,1,1,.55))
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(3,15)
	layer.add_child(dot)
	prompt = Style.label("", 26, Color("f3e8d3"), true)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -116
	prompt.offset_bottom = -69
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_outline_color", Color(.03,.025,.02,.95))
	prompt.add_theme_constant_override("outline_size", 6)
	layer.add_child(prompt)
	hint = Style.label(CONTROLS, 17, Color("e2d7c5"))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -43
	hint.offset_bottom = -17
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", Color(.03,.025,.02,.9))
	hint.add_theme_constant_override("outline_size", 4)
	layer.add_child(hint)
	curtain = ColorRect.new()
	curtain.color = Color(0,0,0,0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(curtain)

func start_ambience() -> void:
	for data in [["res://audio/dream_field/wind_loop.wav", -19.0], ["res://audio/dream_field/dry_grass_loop.wav", -24.0]]:
		var sound := AudioStreamPlayer.new()
		var clip := (load(data[0]) as AudioStreamWAV).duplicate() as AudioStreamWAV
		var frames := roundi(clip.get_length() * clip.mix_rate)
		clip.loop_mode = AudioStreamWAV.LOOP_FORWARD
		clip.loop_begin = 0
		clip.loop_end = frames
		sound.stream = clip
		sound.bus = &"Ambience"
		sound.volume_db = data[1]
		add_child(sound)
		ambient.append(sound)
		sound.play()
	# Quiet score over the wind (Epidemic Sound). Its own fade-in/out makes it loop cleanly.
	music = AudioStreamPlayer.new()
	music.name = "FieldMusic"
	var score := (load(MUSIC) as AudioStreamMP3).duplicate() as AudioStreamMP3
	score.loop = true
	music.stream = score
	music.bus = &"Music" if AudioServer.get_bus_index("Music") >= 0 else &"Master"
	music.volume_db = -60.0
	add_child(music)
	ambient.append(music)
	music.play()
	music_fade = create_tween()
	music_fade.tween_property(music, "volume_db", MUSIC_DB, 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func on_entry_finished() -> void:
	if not is_inside_tree() or waking: return
	# Web must capture the pointer from a direct click; native can do it at entry.
	if not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func can_wake() -> bool:
	if waking or not playing or player.locked: return false
	var target: Vector3 = monument.global_position + Vector3(0,1.65,0)
	var to_statue: Vector3 = target - player.camera.global_position
	return to_statue.length() < 4.2 and (-player.camera.global_basis.z).dot(to_statue.normalized()) > .65

func _unhandled_input(event: InputEvent) -> void:
	if waking: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Web confirms pointer lock asynchronously; _process records the result.
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Anthology.show_pause()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_wake():
			wake_up()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if waking: return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if was_captured and not captured and not Anthology.changing and Anthology.modal == null:
		Anthology.show_pause()
	was_captured = captured
	time_in_field += delta
	prompt.text = "[ E ]  ตื่นจากฝัน" if captured and can_wake() else ""
	hint.text = "คลิกเพื่อเดินสำรวจ   ·   กด E ที่รูปปั้นเพื่อตื่น" if not captured else CONTROLS
	hint.modulate.a = 1.0 if not captured or time_in_field < 10.0 else .42
	heading.modulate.a = 1.0 - smoothstep(4.0,7.0,time_in_field)
	# The large field has no visible walls. Keep a safety surface under the player
	# even if a debug teleport puts them beyond the authored terrain.
	if player.position.y < -10.0:
		player.position.y = Terrain.height_at(player.position.x, player.position.z) + .2
		player.velocity = Vector3.ZERO

func wake_up() -> void:
	if waking or Anthology.changing: return
	if not can_wake(): return
	waking = true
	playing = false
	player.locked = true
	player.velocity = Vector3.ZERO
	prompt.text = ""
	hint.hide()
	player.footstep.stop()
	if music_fade and music_fade.is_valid(): music_fade.kill()
	# Dim the field (not to black) and let the wind settle; the music carries the credits.
	var fade := create_tween().set_parallel(true)
	fade.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fade.tween_property(curtain, "color:a", CREDITS_DIM, 2.4)
	fade.tween_property(heading, "modulate:a", 0.0, .5)
	for sound in ambient:
		if sound != music: fade.tween_property(sound, "volume_db", -40.0, 2.4)
	if music.volume_db < MUSIC_DB: fade.tween_property(music, "volume_db", MUSIC_DB, 2.4)
	await fade.finished
	credits = EndCredits.new()
	credits.name = "EndCredits"
	add_child(credits)
	await credits.finished
	await get_tree().create_timer(1.2, false).timeout
	var out := create_tween().set_parallel(true)
	out.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	out.tween_property(curtain, "color:a", 1.0, 2.5)
	out.tween_property(credits.roll, "modulate:a", 0.0, 1.5)
	for sound in ambient: out.tween_property(sound, "volume_db", -70.0, 2.5)
	await out.finished
	await get_tree().create_timer(.35, false).timeout
	await Anthology.return_to_menu()
