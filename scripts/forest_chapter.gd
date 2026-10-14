extends Node3D
## Episode 05 — THE CAMPFIRE / กองไฟกลางป่า
## Phakin wakes in a forest after blacking out at the wheel (end of Episode 04).
## Goal: walk the trail to the campfire. Leave the trail and the frog hunts him;
## when it catches him he wakes at the start again, but the night has moved on.
## The frog and Pladuk only look hostile: they keep him on the right path.
const PlayerScript = preload("res://scripts/player.gd")
const FrogScript = preload("res://scripts/frog_watcher.gd")
const ChokeScript = preload("res://scripts/frog_choke.gd")
const ShoulderScript = preload("res://scripts/pladuk_shoulder.gd")
const HeadTilt = preload("res://scripts/head_tilt.gd")
const EPISODE_ID := "forest"
const OBJECTIVE := "เดินไปที่กองไฟ"
const START := Vector3(0, .05, 1.5)
const OFF_TRAIL_WARN := 6.0       # metres from the trail centre before the frog shows itself
const OFF_TRAIL_FAR := 11.0       # this far out it hunts at once
const WARN_TIME := 3.0            # seconds off the trail after the warning before it hunts
const BACK_ON_TRAIL := 3.0        # within this, a warning or hunt is called off
const CAMP_REACH := 3.2
const START_MINUTES := 23 * 60 + 52
const MINUTES_PER_CATCH := 37
const REAL_SECONDS_PER_MINUTE := 6.0
const WAKE_LINES := ["ที่ไหนเนี่ย... เมื่อกี้ผมยังขับรถอยู่เลย",
	"ตื่นอีกแล้ว... ตรงเดิม ต้นไม้ต้นเดิม",
	"กองไฟนั่นเล็กลงกว่าเดิม ผมหลับไปนานแค่ไหนกัน",
	"คอไม่เจ็บเลยสักนิด ทั้งที่มันบีบแน่นขนาดนั้น"]
const EPILOGUE := "ที่กองไฟไม่มีใครนั่งอยู่ แต่ฟืนเพิ่งถูกเติม\nขอนไม้ข้าง ๆ ยังอุ่น เหมือนมีคนเพิ่งลุกไป\n\nผมนอนลงตรงนั้น ฟังเสียงไฟแตกเปาะแปะ\nก่อนหลับ ผมได้ยินเสียงคนคุยกันเบา ๆ อยู่อีกฝั่งกองไฟ\nหนึ่งในนั้นหัวเราะเหมือนพ่อ\n\nEPISODE 06 — เร็ว ๆ นี้"
enum Stage { INTRO, WAKE, WALK, WARNED, HUNTED, CAUGHT, CAMP, END }
var stage := Stage.INTRO
var playing := false
var busy := false
var started := false
var paused := false
var player: CharacterBody3D
var frog: CharacterBody3D
var head_tilt: SkeletonModifier3D
var shoulder: Node3D
var trail: Curve3D
var campfire_spot: Vector3
var frog_peek: Vector3
var choke: Node3D
var catches := 0
var clock_minutes := float(START_MINUTES)
var warn_time := 0.0
var peek_active := false
var peek_seen := 0.0
var peek_unseen := 0.0
var peek_age := 0.0
var ending_presented := false
var rng := RandomNumberGenerator.new()
var frog_leaving := false
var leave_unseen := 0.0
var bird_timer := 6.0
var croak_timer := 4.0
# UI (same look as Episode 04)
var objective: Label
var clock_label: Label
var prompt: Label
var subtitle: Label
var subtitle_backdrop: PanelContainer
var overlay: ColorRect
var panel: CenterContainer
var panel_title: Label
var panel_text: Label
var panel_button: Button
var menu_button: Button
var caption_time := 0.0
var caption_reveal := 0.0
# Sound
var night: AudioStreamPlayer
var fire_sound: AudioStreamPlayer3D
var bird: AudioStreamPlayer3D
var far_croak: AudioStreamPlayer3D
var croak: AudioStreamPlayer3D
var breath: AudioStreamPlayer
var sound: AudioStreamPlayer
var warn_breath: AudioStreamPlayer3D
var forest_silent := false
var night_tween: Tween
# Campfire pieces (shrink each time he is caught)
var fire_light: OmniLight3D
var fire_glow: MeshInstance3D
var flames: Node3D
var fire_energy := 2.4

func _ready() -> void:
	rng.randomize()
	for action_name in {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause_game":KEY_ESCAPE}:
		if InputMap.has_action(action_name): continue
		InputMap.add_action(action_name)
		var key := InputEventKey.new()
		key.physical_keycode = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause_game":KEY_ESCAPE}[action_name]
		InputMap.action_add_event(action_name,key)
	trail = ($World/Trail as Path3D).curve
	campfire_spot = ($World/CampfireSpot as Node3D).global_position
	frog_peek = ($World/FrogPeek as Node3D).global_position
	fire_light = $World/Campsite/FireLight
	fire_glow = $World/Campsite/FireGlow
	flames = $World/Campsite/Campfire.find_child("campfire_flames", true, false) as Node3D
	tune_world()
	setup_player()
	setup_frog()
	setup_audio()
	setup_ui()
	update_clock()
	show_panel("THE CAMPFIRE  /  กองไฟกลางป่า","ภาคิน / ทางกลับจากห้องเช่าของพ่อ / 23:52\n\n“ใกล้ถึงปั๊มแล้วใช่ไหมนะ.....”\nผมจำได้แค่นั้น ไฟปั๊มอยู่ข้างหน้า\nแล้วตาก็กะพริบ ครั้งแล้วครั้งเล่า\n\nWASD เดิน · เมาส์มอง · Shift วิ่ง\nF ไฟฉาย · V มุมกล้อง · Esc พัก · F1 เมนู","ลืมตา")
	play_cue("tape",-23.0)

# Far trees fade into the fog anyway: stop drawing them past it. Tree crowns
# keep no collision, so walking under branches never snags on an invisible box.
func tune_world() -> void:
	for group_name in ["Trees","Undergrowth"]:
		var g := get_node_or_null("World/"+group_name)
		if g == null: continue
		for m in g.find_children("*","GeometryInstance3D",true,false):
			(m as GeometryInstance3D).visibility_range_end = 48.0
			(m as GeometryInstance3D).visibility_range_end_margin = 4.0
		for body in g.find_children("Collision","StaticBody3D",true,false):
			if String(body.get_parent().name).ends_with("_crown"): body.queue_free()
	# The pack's own loops: the fire burns, trees sway (each from its own point in the loop).
	var fire_anim := $World/Campsite/Campfire.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if fire_anim and fire_anim.has_animation("burn"): fire_anim.play("burn")
	for anim in get_node("World").find_children("AnimationPlayer","AnimationPlayer",true,false):
		var player_anim := anim as AnimationPlayer
		if player_anim.has_animation("sway"):
			player_anim.play("sway")
			player_anim.seek(rng.randf() * player_anim.current_animation_length, true)
	var giant := get_node_or_null("World/GiantTree")
	if giant:
		for body in giant.find_children("Collision","StaticBody3D",true,false):
			if String(body.get_parent().name).ends_with("_crown"): body.queue_free()

func setup_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.set_script(PlayerScript)
	player.game = self
	player.position = START
	add_child(player)
	player.set_third_person(false)
	var look: ShaderMaterial = player.get_node("RetroHorrorLook").get_child(0).material
	look.set_shader_parameter("exposure",1.2)
	look.set_shader_parameter("vignette_strength",.34)
	look.set_shader_parameter("pixel_height",360.0)
	player.torch.spot_range = 24
	player.torch.visible = false
	shoulder = Node3D.new()
	shoulder.name = "PladukShoulder"
	shoulder.set_script(ShoulderScript)
	shoulder.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.camera.add_child(shoulder)
	shoulder.setup(player)
	shoulder.enabled = false

func setup_frog() -> void:
	frog = CharacterBody3D.new()
	frog.name = "Frog"
	frog.process_mode = Node.PROCESS_MODE_PAUSABLE
	frog.set_script(FrogScript)
	frog.game = self
	frog.target = player
	frog.approach_enabled = false
	frog.bounds = Rect2(-40,-106,80,116)
	frog.position = frog_peek
	add_child(frog)
	# The curious head tilt, applied after the frog's own head tracking.
	if frog.skeleton:
		head_tilt = HeadTilt.new()
		head_tilt.name = "HeadTilt"
		frog.skeleton.add_child(head_tilt)
		head_tilt.setup("Head")
	frog.vanish()
	frog.caught_player.connect(_on_frog_caught)
	warn_breath = AudioStreamPlayer3D.new()
	warn_breath.process_mode = Node.PROCESS_MODE_PAUSABLE
	warn_breath.stream = looped("res://audio/frog_chapter/breath.wav")
	warn_breath.pitch_scale = .62
	warn_breath.volume_db = -2
	warn_breath.position = Vector3(0,1.6,0)
	frog.add_child(warn_breath)
	croak = AudioStreamPlayer3D.new()
	croak.process_mode = Node.PROCESS_MODE_PAUSABLE
	croak.stream = load("res://audio/forest/croak.wav")
	croak.unit_size = 6
	croak.volume_db = -4
	croak.position = Vector3(0,1.2,0)
	frog.add_child(croak)

func looped(path: String) -> AudioStreamWAV:
	var s := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = s.data.size()/2
	return s

func setup_audio() -> void:
	night = AudioStreamPlayer.new()
	night.stream = looped("res://audio/forest/night.wav")
	night.volume_db = -80
	if AudioServer.get_bus_index("Ambience") >= 0: night.bus = &"Ambience"
	night.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(night)
	night.play()
	fire_sound = AudioStreamPlayer3D.new()
	fire_sound.stream = looped("res://audio/forest/fire.wav")
	fire_sound.position = campfire_spot + Vector3(0,.6,0)
	fire_sound.unit_size = 4
	fire_sound.max_distance = 40
	fire_sound.volume_db = -6
	fire_sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fire_sound)
	fire_sound.play()
	bird = AudioStreamPlayer3D.new()
	bird.stream = load("res://audio/forest/bird.wav")
	bird.unit_size = 14
	bird.volume_db = -10
	bird.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bird)
	far_croak = AudioStreamPlayer3D.new()
	far_croak.stream = load("res://audio/forest/croak.wav")
	far_croak.unit_size = 12
	far_croak.volume_db = -12
	far_croak.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(far_croak)
	breath = AudioStreamPlayer.new()
	breath.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(breath)
	sound = AudioStreamPlayer.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)

# The whole forest stops at once (crickets, birds, frogs). Only the fire keeps going.
func silence_forest() -> void:
	forest_silent = true
	if night_tween: night_tween.kill()
	night.volume_db = -80
	if bird.playing: bird.stop()
	if far_croak.playing: far_croak.stop()

func wake_forest(seconds := 4.0) -> void:
	forest_silent = false
	if night_tween: night_tween.kill()
	night_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	night_tween.tween_property(night,"volume_db",-13.0,seconds)

func play_sound(file: String, volume := -10.0) -> void:
	sound.stream = load("res://audio/forest/"+file+".wav")
	sound.volume_db = volume
	sound.play()

func update_clock() -> void:
	var m := int(clock_minutes) % (24*60)
	if clock_label: clock_label.text = "%02d:%02d" % [m/60, m%60]

func episode_font(bold := false) -> Font:
	var path := "res://ui/fonts/ChakraPetch-Bold.ttf" if bold else "res://ui/fonts/ChakraPetch-Regular.ttf"
	if ResourceLoader.exists(path): return load(path) as Font
	return load("res://NotoSansThai.ttf") as Font

func make_label(size: int, color := Color(.89,.91,.81)) -> Label:
	var n := Label.new()
	n.add_theme_font_override("font",episode_font())
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	n.add_theme_color_override("font_outline_color",Color(.015,.025,.022,.95))
	n.add_theme_constant_override("outline_size",4)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

func setup_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left","right","top"]: margin.add_theme_constant_override("margin_"+side,28)
	ui.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	var chapter := make_label(15,Color(.64,.76,.62))
	chapter.text = "EPISODE 05  /  THE CAMPFIRE"
	stack.add_child(chapter)
	objective = make_label(22)
	stack.add_child(objective)
	clock_label = make_label(18,Color(.70,.67,.43))
	stack.add_child(clock_label)
	var dot := make_label(19)
	dot.text = "·"
	dot.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ui.add_child(dot)
	prompt = make_label(21)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt.offset_top = -70
	prompt.offset_bottom = -30
	ui.add_child(prompt)
	subtitle_backdrop = PanelContainer.new()
	subtitle_backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_backdrop.anchor_left = .15
	subtitle_backdrop.anchor_right = .85
	subtitle_backdrop.offset_top = -166
	subtitle_backdrop.offset_bottom = -82
	subtitle_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caption_style := StyleBoxFlat.new()
	caption_style.bg_color = Color(.018,.021,.019,.84)
	caption_style.border_color = Color(.70,.67,.43,.7)
	caption_style.border_width_left = 2
	caption_style.content_margin_left = 24
	caption_style.content_margin_right = 24
	caption_style.content_margin_top = 12
	caption_style.content_margin_bottom = 12
	subtitle_backdrop.add_theme_stylebox_override("panel",caption_style)
	ui.add_child(subtitle_backdrop)
	subtitle_backdrop.hide()
	subtitle = make_label(24,Color(.96,.94,.83))
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_backdrop.add_child(subtitle)
	overlay = ColorRect.new()
	overlay.color = Color(0,0,0,0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	panel = CenterContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(panel)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700,0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.018,.026,.024,.98)
	style.border_color = Color(.46,.49,.35)
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel",style)
	panel.add_child(card)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation",22)
	card.add_child(contents)
	panel_title = make_label(32,Color(.80,.80,.60))
	panel_title.add_theme_font_override("font",episode_font(true))
	contents.add_child(panel_title)
	panel_text = make_label(22)
	panel_text.custom_minimum_size.x = 620
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(panel_text)
	panel_button = Button.new()
	panel_button.custom_minimum_size.y = 48
	panel_button.add_theme_font_override("font",episode_font(true))
	panel_button.add_theme_font_size_override("font_size",22)
	style_button(panel_button)
	contents.add_child(panel_button)
	panel_button.pressed.connect(panel_continue)
	menu_button = Button.new()
	menu_button.text = "กลับไปเลือกตอน"
	menu_button.custom_minimum_size.y = 40
	menu_button.add_theme_font_override("font",episode_font())
	menu_button.add_theme_font_size_override("font_size",18)
	style_button(menu_button)
	contents.add_child(menu_button)
	menu_button.pressed.connect(return_to_menu)

func style_button(button: Button) -> void:
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.08,.12,.10,.8) if state == "normal" else Color(.19,.24,.17,.95)
		style.border_color = Color(.40,.46,.31) if state == "normal" else Color(.77,.80,.54)
		style.set_border_width_all(1)
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color(.91,.92,.79))
	button.add_theme_color_override("font_hover_color",Color(1,.97,.78))
	button.mouse_entered.connect(func(): play_cue("ui_move",-27.0))

func play_cue(cue: String, volume := -20.0) -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("play_sfx"):
		anthology.play_sfx(cue,volume)

func return_to_menu() -> void:
	play_cue("ui_accept",-22.0)
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("return_to_menu"):
		get_tree().paused = false
		anthology.return_to_menu()

func show_panel(title: String, text: String, button: String) -> void:
	panel_title.text = title
	panel_text.text = text
	panel_button.text = button
	menu_button.visible = get_node_or_null("/root/Anthology") != null
	panel.show()
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel_button.grab_focus()

func say(text: String, seconds := 5.0) -> void:
	subtitle.text = text
	subtitle.visible_characters = -1 if instant_text_enabled() else 0
	caption_reveal = 0.0
	caption_time = maxf(seconds,text.length()/38.0+2.5)
	subtitle_backdrop.show()

func instant_text_enabled() -> bool:
	var anthology := get_node_or_null("/root/Anthology")
	return anthology != null and bool(anthology.settings.get("instant_text",false))

func reduced_motion_enabled() -> bool:
	var anthology := get_node_or_null("/root/Anthology")
	return anthology != null and bool(anthology.settings.get("reduced_motion",false))

func lock_scene() -> void:
	busy = true
	playing = false
	player.velocity = Vector3.ZERO

func unlock_scene() -> void:
	busy = false
	playing = true

func wait_for(seconds: float) -> void:
	await get_tree().create_timer(seconds,false).timeout

func look_at_point(point: Vector3, seconds := .8) -> void:
	if reduced_motion_enabled(): seconds = maxf(seconds*2.0,1.6)
	var d: Vector3 = (point-player.camera.global_position).normalized()
	var yaw: float = player.pivot.rotation.y+wrapf(atan2(-d.x,-d.z)-player.pivot.rotation.y,-PI,PI)
	var pitch := asin(clampf(d.y,-1,1))
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_parallel(true)
	t.tween_property(player.pivot,"rotation:y",yaw,seconds)
	t.tween_property(player.spring_arm,"rotation:x",pitch,seconds)
	t.tween_property(player.torch,"rotation:x",pitch,seconds)
	await t.finished
	player.pitch = pitch

# ---------------------------------------------------------------- flow

func panel_continue() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if stage == Stage.END and anthology:
		anthology.launch_episode(EPISODE_ID)
		return
	if not started and anthology and anthology.has_method("reveal_gameplay"):
		await anthology.reveal_gameplay(_continue_panel)
	else:
		_continue_panel()

func _continue_panel() -> void:
	play_cue("ui_accept",-25.0)
	if stage == Stage.END:
		get_tree().reload_current_scene()
		return
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if paused:
		paused = false
		get_tree().paused = false
		playing = not busy
	else:
		started = true
		wake(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and started and stage != Stage.END and choke == null:
		if paused:
			panel_continue()
		else:
			paused = true
			show_panel("พักเกม","THE CAMPFIRE  /  กองไฟกลางป่า\n\n"+objective.text+"\n\nWASD เดิน · F ไฟฉาย · Shift วิ่ง · V มุมกล้อง","เล่นต่อ")
			get_tree().paused = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and playing and not busy and near_campfire():
		sleep_by_fire()

func near_campfire() -> bool:
	return Vector2(player.global_position.x-campfire_spot.x, player.global_position.z-campfire_spot.z).length() < CAMP_REACH

# Eyes snap open with a gasp, then flutter shut and open a few times
# (black -> blurred -> black -> clear), and he gets up off the ground.
func wake(first: bool) -> void:
	stage = Stage.WAKE
	lock_scene()
	silence_forest()
	shoulder.enabled = false
	shoulder.hide_now()
	objective.text = ""
	subtitle.text = ""
	overlay.color.a = 1.0
	player.global_position = START
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = 0.0
	player.pivot.position.y = .32          # lying on the forest floor
	player.camera.rotation.z = .42
	player.pitch = .5
	player.spring_arm.rotation.x = .5
	player.torch.rotation.x = .5
	player.stamina = 100
	update_clock()
	var look: ShaderMaterial = player.get_node("RetroHorrorLook").get_child(0).material
	look.set_shader_parameter("softness",1.0)
	await wait_for(1.4 if first else 1.0)
	play_sound("gasp",-4.0)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for step in [[.25,.07],[1.0,.16],[.45,.22],[1.0,.12],[.15,.35],[.9,.14],[0.0,.8]]:
		t.tween_property(overlay,"color:a",step[0],step[1])
	# Blurred at first, focusing over the blinks.
	var focus := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	focus.tween_method(func(v: float): look.set_shader_parameter("softness",v),1.0,.45,2.4)
	await t.finished
	breath.stream = load("res://audio/forest/pant.wav")
	breath.volume_db = -9
	breath.play()
	wake_forest(3.0)
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_parallel(true)
	t.tween_property(player.pivot,"position:y",1.55,2.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(player.camera,"rotation:z",0.0,2.0).set_trans(Tween.TRANS_SINE)
	await t.finished
	if first or catches % 2 == 0:
		start_peek()
	await look_at_point(frog_peek + Vector3(0,1.5,0) if peek_active else Vector3(0,1.6,-14), 1.4)
	var line: String = WAKE_LINES[0] if catches == 0 else WAKE_LINES[1 + (catches-1) % (WAKE_LINES.size()-1)]
	say(line, 5)
	objective.text = OBJECTIVE
	stage = Stage.WALK
	shoulder.enabled = true
	unlock_scene()

# The frog behind the giant tree, head tilted, watching him wake up.
func start_peek() -> void:
	frog.stop_hunt()
	frog.clear_scene_rules()
	frog.threat_enabled = false
	frog.appear_at(frog_peek)
	frog.face_towards(START)
	if head_tilt: head_tilt.tilt = deg_to_rad(28)
	peek_active = true
	peek_seen = 0.0
	peek_unseen = 0.0
	peek_age = 0.0

func end_peek() -> void:
	peek_active = false
	if head_tilt: head_tilt.tilt = 0.0
	frog.vanish()
	wake_forest(4.0)

func update_peek(delta: float) -> void:
	peek_age += delta
	if frog.is_seen():
		if peek_seen == 0.0:
			# The moment he really sees it, every animal in the forest goes quiet.
			silence_forest()
			play_cue("low_pulse",-24.0)
		peek_seen += delta
		peek_unseen = 0.0
	elif peek_seen > 0.0:
		peek_unseen += delta
	# Look away after a proper look, and it is gone when you look back.
	if (peek_seen > 1.2 and peek_unseen > .5) or (peek_age > 20.0 and not frog.is_seen()):
		end_peek()

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if get_tree().paused: return
	if caption_time>0:
		caption_time -= delta
		caption_reveal += delta*38.0
		subtitle.visible_characters = -1 if instant_text_enabled() else int(caption_reveal)
		if caption_time<=0: subtitle.text = ""
	subtitle_backdrop.visible = not subtitle.text.is_empty() and not panel.visible
	if peek_active: update_peek(delta)
	flicker_fire(delta)
	if not playing:
		prompt.text = ""
		return
	clock_minutes += delta / REAL_SECONDS_PER_MINUTE
	update_clock()
	ambient_calls(delta)
	prompt.text = "[E] นั่งลงพักข้างกองไฟ" if near_campfire() and stage in [Stage.WALK,Stage.WARNED] else ""
	update_trail(delta)

func trail_distance() -> float:
	var p := player.global_position
	var q := trail.get_closest_point(Vector3(p.x,0,p.z))
	return Vector2(p.x-q.x, p.z-q.z).length()

# Birds and far-off frogs, from random directions, unless the forest has gone quiet.
func ambient_calls(delta: float) -> void:
	if forest_silent: return
	bird_timer -= delta
	if bird_timer <= 0.0:
		bird_timer = rng.randf_range(9.0, 22.0)
		var a := rng.randf() * TAU
		bird.global_position = player.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(14, 26) + Vector3.UP * 7
		bird.pitch_scale = rng.randf_range(.85, 1.15)
		bird.play()
	croak_timer -= delta
	if croak_timer <= 0.0 and stage == Stage.WALK and frog.mode == frog.Mode.GONE:
		croak_timer = rng.randf_range(12.0, 30.0)
		# A croak from somewhere deep in the trees; the frog itself is not there.
		var a := rng.randf() * TAU
		far_croak.global_position = player.global_position + Vector3(cos(a), 0, sin(a)) * rng.randf_range(18, 30)
		far_croak.pitch_scale = rng.randf_range(.8, .95)
		far_croak.play()

# ---------------------------------------------------------------- the trail rule

func update_trail(delta: float) -> void:
	if choke != null: return
	if frog_leaving:
		leave_unseen = 0.0 if frog.is_seen() else leave_unseen + delta
		if leave_unseen > .6:
			frog_leaving = false
			frog.vanish()
	var d := trail_distance()
	match stage:
		Stage.WALK:
			shoulder.pressure = clampf((d - 2.0) / 4.0, 0.0, .6)
			if d > OFF_TRAIL_WARN:
				warn()
		Stage.WARNED:
			warn_time += delta
			if d < BACK_ON_TRAIL + 1.0:
				calm()
			elif warn_time > WARN_TIME or d > OFF_TRAIL_FAR:
				hunt()
		Stage.HUNTED:
			if d < BACK_ON_TRAIL:
				calm()

# It shows itself on the wrong side, standing in the way. Croaking.
func warn() -> void:
	stage = Stage.WARNED
	warn_time = 0.0
	frog_leaving = false
	if peek_active: end_peek()
	shoulder.pressure = 1.0
	var p := player.global_position
	var q := trail.get_closest_point(Vector3(p.x,0,p.z))
	var away := Vector3(p.x-q.x, 0, p.z-q.z).normalized()
	frog.appear_at(Vector3(p.x,.05,p.z) + away * 7.0)
	frog.face_towards(p)
	croak.play()
	play_cue("low_pulse",-26.0)

# Back on the trail: it lets him go, and leaves when he is not looking.
func calm() -> void:
	stage = Stage.WALK
	shoulder.pressure = 0.0
	warn_breath.stop()
	frog.stop_hunt()
	frog_leaving = true
	leave_unseen = 0.0

func hunt() -> void:
	stage = Stage.HUNTED
	if frog.mode == frog.Mode.GONE:
		var p := player.global_position
		frog.appear_at(p + (p - trail.get_closest_point(Vector3(p.x,0,p.z))).normalized() * 9.0)
	frog.start_hunt()
	warn_breath.play()
	croak.play()

# ---------------------------------------------------------------- caught: back to the start, later

func _on_frog_caught() -> void:
	if choke != null: return
	stage = Stage.CAUGHT
	busy = true
	warn_breath.stop()
	shoulder.enabled = false
	shoulder.hide_now()
	subtitle.text = ""
	prompt.text = ""
	objective.visible = false
	choke = Node3D.new()
	choke.set_script(ChokeScript)
	choke.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(choke)
	choke.finished.connect(_on_choke_finished)
	choke.start(frog, player)

func _on_choke_finished() -> void:
	overlay.color.a = 1
	choke.cleanup()
	choke.queue_free()
	choke = null
	catches += 1
	# The night has moved on while he was out, and the fire has burned down.
	clock_minutes += MINUTES_PER_CATCH + rng.randf_range(-6.0, 8.0)
	fire_energy = maxf(.8, fire_energy * .78)
	frog.stop_hunt()
	frog.clear_scene_rules()
	frog.threat_enabled = false
	frog.vanish()
	frog_leaving = false
	objective.visible = true
	busy = false
	wake(false)

func flicker_fire(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var f := 1.0 + sin(t * 13.0) * .06 + sin(t * 7.3 + 1.7) * .08 + sin(t * 23.0) * .03
	fire_light.light_energy = fire_energy * f
	var size := fire_energy / 2.4
	fire_glow.scale = Vector3.ONE * (.55 + .45 * size) * (1.0 + (f - 1.0) * .5)
	# A beacon from far away; up close the real light takes over.
	var away := player.global_position.distance_to(campfire_spot) if player else 99.0
	fire_glow.transparency = clampf(1.0 - (away - 6.0) / 14.0, 0.0, .92)
	if flames: flames.scale = Vector3.ONE * (.45 + .55 * size)

# ---------------------------------------------------------------- the campfire

func sleep_by_fire() -> void:
	stage = Stage.CAMP
	lock_scene()
	prompt.text = ""
	objective.text = ""
	shoulder.enabled = false
	shoulder.hide_now()
	frog_leaving = false
	if frog.mode != frog.Mode.GONE: frog.vanish()
	breath.stop()
	await look_at_point(campfire_spot + Vector3(0,.4,0), 1.4)
	say("อุ่นจัง... กลิ่นควันแบบนี้ เหมือนตอนเด็ก ๆ ที่ไปตั้งแคมป์กับพ่อ", 6)
	await wait_for(5.0)
	# Lies down beside the fire.
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP).set_parallel(true)
	t.tween_property(player.pivot,"position:y",.4,2.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(player.camera,"rotation:z",-.38,2.4).set_trans(Tween.TRANS_SINE)
	await t.finished
	say("หลับตาลงแป๊บเดียว... คงไม่เป็นไร", 4)
	# Slow, heavy blinks, each one a little longer, until they stay shut.
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	for step in [[1.0,.5],[0.2,.7],[1.0,.6],[.45,.9],[1.0,.8],[.75,1.1],[1.0,1.2]]:
		t.tween_property(overlay,"color:a",step[0],step[1])
	if night_tween: night_tween.kill()
	night_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	night_tween.tween_property(night,"volume_db",-40.0,6.0)
	await t.finished
	subtitle.text = ""
	await wait_for(1.2)
	stage = Stage.END
	ending_presented = true
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("complete_episode"):
		anthology.complete_episode(EPISODE_ID, EPILOGUE)
	else:
		show_panel("THE CAMPFIRE  /  กองไฟกลางป่า", EPILOGUE, "เล่นตอนนี้อีกครั้ง")
