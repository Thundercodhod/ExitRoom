extends Node3D
## Story direction uses only the existing frog's public scene helpers.
const PlayerScript = preload("res://scripts/player.gd")
const FrogScript = preload("res://scripts/frog_watcher.gd")
const ChokeScript = preload("res://scripts/frog_choke.gd")
const RETURN_START := Vector3(0,.05,-39)       # just outside the bedroom door
const RETURN_FROG := Vector3(-4,.05,-23)
const RETURN_OBJECTIVE := "กลับไปที่รถ · ไม่ต้องรับสาย"
const EPISODE_ID := "passenger"
const EPILOGUE := "ผมขับต่อไป ไม่กล้าหันไปดูอีกจนถึงปั๊มที่มีคนอยู่\nพอเปิดไฟในรถ เบาะข้าง ๆ ก็ว่าง แต่เปียกจนชุ่ม\n\nวันต่อมาผมพาเพื่อนไปดู เราขับวนอยู่สองรอบก็หาทางเข้าบ้านไม่เจอ\nเครื่องจั๊มพ์แบตยังอยู่ท้ายรถ ผมยังไม่กล้าเอามาใช้\n\nมีเรื่องหนึ่งที่ผมไม่ได้บอกเพื่อน\nบางคืน ตอนดับเครื่อง ผมยังได้ยินเสียงปลดเข็มขัดจากเบาะข้าง ๆ"
enum Stage { CAR, FIELD, HOUSE, NOTE, BATTERY, RECOGNITION, RETURN, REPAIRED, END }
var stage := Stage.CAR
var playing := false
var busy := false
var started := false
var paused := false
var reading := false
var player: CharacterBody3D
var frog: CharacterBody3D
var objective: Label
var prompt: Label
var subtitle: Label
var overlay: ColorRect
var panel: CenterContainer
var panel_title: Label
var panel_text: Label
var panel_button: Button
var menu_button: Button
var subtitle_backdrop: PanelContainer
var caption_time := 0.0
var caption_reveal := 0.0
var elapsed := 0.0
var return_caption_step := 0
var return_step := 0
var destination_pending := false
var cut_camera: Camera3D
var sound: AudioStreamPlayer
var ringing: AudioStreamPlayer3D
var engine: AudioStreamPlayer
var house_lights: Array[Light3D] = []
var choke: Node3D
var catches := 0
var warn_breath: AudioStreamPlayer3D
var ending_presented := false

func _ready() -> void:
	for action_name in {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause_game":KEY_ESCAPE}:
		if InputMap.has_action(action_name): continue
		InputMap.add_action(action_name)
		var key := InputEventKey.new()
		key.physical_keycode = {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"interact":KEY_E,"flashlight":KEY_F,"pause_game":KEY_ESCAPE}[action_name]
		InputMap.action_add_event(action_name,key)
	player = CharacterBody3D.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.set_script(PlayerScript)
	player.game = self
	player.position = Vector3(0,.05,2.4)
	add_child(player)
	player.set_third_person(false)
	var look: ShaderMaterial = player.get_node("RetroHorrorLook").get_child(0).material
	look.set_shader_parameter("exposure",1.15)
	look.set_shader_parameter("vignette_strength",.3)
	look.set_shader_parameter("pixel_height",360.0)
	player.pivot.rotation.y = -.9
	player.torch.spot_range = 26
	frog = CharacterBody3D.new()
	frog.name = "Frog"
	frog.process_mode = Node.PROCESS_MODE_PAUSABLE
	frog.set_script(FrogScript)
	frog.game = self
	frog.target = player
	frog.approach_enabled = false
	frog.position = Vector3(-8,.05,-13)
	add_child(frog)
	frog.face_towards(player.position)
	frog.vanish()
	frog.relocated.connect(func(_p): destination_pending = false; frog.face_towards(player.position))
	frog.caught_player.connect(_on_frog_caught)
	frog.threat_stage_changed.connect(_on_threat_stage)
	# The frog's own breathing: positional, so it comes from where it stands.
	warn_breath = AudioStreamPlayer3D.new()
	warn_breath.process_mode = Node.PROCESS_MODE_PAUSABLE
	var breath_loop := (load("res://audio/frog_chapter/breath.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	breath_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	breath_loop.loop_end = breath_loop.data.size()/2
	warn_breath.stream = breath_loop
	warn_breath.pitch_scale = .62
	warn_breath.volume_db = -2
	warn_breath.position = Vector3(0,1.6,0)
	frog.add_child(warn_breath)
	for n in $World/House.find_children("*","Light3D",true,false): house_lights.append(n)
	sound = AudioStreamPlayer.new()
	sound.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(sound)
	ringing = AudioStreamPlayer3D.new()
	ringing.process_mode = Node.PROCESS_MODE_PAUSABLE
	ringing.position = Vector3(-1.7,.6,-44.25)
	ringing.stream = load("res://audio/frog_chapter/phone.wav")
	ringing.volume_db = -12
	add_child(ringing)
	engine = AudioStreamPlayer.new()
	engine.process_mode = Node.PROCESS_MODE_PAUSABLE
	engine.stream = load("res://audio/frog_chapter/engine.wav")
	engine.volume_db = -20
	add_child(engine)
	var field := AudioStreamPlayer.new()
	var atmosphere := (load("res://audio/frog_chapter/field.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	atmosphere.loop_mode = AudioStreamWAV.LOOP_FORWARD
	atmosphere.loop_end = atmosphere.data.size()/2
	field.stream = atmosphere
	field.volume_db = -12
	if AudioServer.get_bus_index("Ambience") >= 0: field.bus = &"Ambience"
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	field.play()
	setup_ui()
	show_panel("THE PASSENGER  /  ผู้โดยสาร","ภาคิน / กลับจากเก็บของที่ห้องเช่าของพ่อ / 23:46\n\nพ่อเสียไปเกือบปี ผมจ่ายค่าเช่าทิ้งไว้จนไม่ไหว\nวันนั้นเลยต้องไปขนของออก แล้วคืนกุญแจเสียที\n\nขากลับถนนใหญ่ปิดซ่อม ผมเลยใช้ทางเลียบทุ่ง\nขับมาได้พักหนึ่ง ไฟหน้าก็หรี่ลง แล้วเครื่องก็ดับ\nมองไปรอบ ๆ มีบ้านเปิดไฟอยู่แค่หลังเดียว\n\nWASD เดิน · เมาส์มอง · Shift วิ่ง\nE สำรวจ · F ไฟฉาย · Esc พัก · F1 เมนู","เริ่มเรื่อง")
	play_cue("tape",-23.0)

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
	chapter.text = "EPISODE 04  /  THE PASSENGER"
	stack.add_child(chapter)
	objective = make_label(22)
	stack.add_child(objective)
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
	menu_button.visible = not reading and get_node_or_null("/root/Anthology") != null
	panel.show()
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel_button.grab_focus()

func panel_continue() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if stage==Stage.END and anthology:
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
	if reading:
		reading = false
		window_event()
	elif paused:
		paused = false
		get_tree().paused = false
		playing = not busy
	else:
		started = true
		playing = true
		objective.text = "ลองสตาร์ตรถที่จอดอยู่ข้างถนน"
		say("เมื่อเช้ายังขับได้อยู่เลย ลองสตาร์ตอีกทีแล้วกัน",6)

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

func play_sound(file: String, volume := -12.0) -> void:
	sound.stream = load("res://audio/frog_chapter/"+file+".wav")
	sound.volume_db = volume
	sound.play()

func target() -> Node:
	var from: Vector3 = player.camera.global_position
	var q := PhysicsRayQueryParameters3D.create(from,from-player.camera.global_basis.z*2.8,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty(): return null
	var n: Node = hit.collider
	while n:
		if n.has_meta("action"): return n
		n = n.get_parent()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and started and not reading and stage != Stage.END and choke == null:
		if paused:
			panel_continue()
		else:
			paused = true
			show_panel("พักเกม","THE PASSENGER  /  ผู้โดยสาร\n\n"+objective.text+"\n\nWASD เดิน · E สำรวจ · F ไฟฉาย · Shift วิ่ง","เล่นต่อ")
			get_tree().paused = true
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and playing and not busy:
		var n := target()
		if n: interact(String(n.get_meta("action")))

func _process(delta: float) -> void:
	if get_tree().paused: return
	elapsed += delta
	for n in get_tree().get_nodes_in_group("frog_hazards"):
		n.visible = fmod(elapsed,1.25)<.45 and stage<Stage.REPAIRED
	if caption_time>0:
		caption_time -= delta
		caption_reveal += delta*38.0
		subtitle.visible_characters = -1 if instant_text_enabled() else int(caption_reveal)
		if caption_time<=0: subtitle.text = ""
	subtitle_backdrop.visible = not subtitle.text.is_empty() and not panel.visible
	if not playing:
		prompt.text = ""
		return
	var n := target()
	prompt.text = "[E] "+String(n.get_meta("hint")) if n else ""
	if stage == Stage.FIELD and player.position.z< -27:
		frog.clear_scene_rules()
		frog.vanish()
		stage = Stage.HOUSE
		objective.text = "เข้าไปขอความช่วยเหลือในบ้านที่เปิดไฟ"
		say("ขอโทษครับ มีใครอยู่ไหม รถผมเสียอยู่ตรงถนนครับ",5)
	if stage == Stage.HOUSE and player.position.z< -31:
		stage = Stage.NOTE
		objective.text = "สำรวจบ้าน · มีกระดาษอยู่บนโต๊ะข้างหน้าต่าง"
	if stage == Stage.RECOGNITION and player.position.z> -41.5:
		recognize_room()
	if stage == Stage.RETURN:
		update_return()

func interact(key: String) -> void:
	if not playing or busy: return
	match key:
		"car":
			if stage == Stage.CAR: failed_start()
			elif stage == Stage.RETURN: repair_car()
			else: say("ไฟหน้าหรี่ขนาดนี้ แบตน่าจะไม่ไหวแล้ว ลองไปขอให้เขาช่วยดูก่อน")
		"note":
			if stage in [Stage.HOUSE,Stage.NOTE]:
				stage = Stage.NOTE
				reading = true
				play_cue("tape",-27.0)
				show_panel("กระดาษข้างหน้าต่าง","เครื่องจั๊มพ์แบตอยู่ในห้องนอน\nเอาไปใช้ได้ ไม่ต้องเอามาคืน\n\nถ้าเห็นมันอยู่ข้างนอก อย่าเดินเข้าไปหา\nอย่าจ้องมัน และอย่าเรียกมัน\n\nตรงขอบกระดาษมีอีกบรรทัด ลายมือคนละคน\n“ไม่ว่าได้ยินเสียงใคร ก็ไม่ต้องตอบ”","[ วางกระดาษ ]")
			else: say("ไม่ต้องเอามาคืนด้วยเหรอ ขอให้ยังใช้ได้ก็พอ")
		"battery":
			if stage == Stage.BATTERY:
				$World/House/Bedroom407/JumpStarter.hide()
				stage = Stage.RECOGNITION
				objective.text = "นำเครื่องจั๊มพ์แบตเตอรี่กลับไปที่รถ"
				play_cue("ui_accept",-28.0)
				say("ไฟยังขึ้นอยู่ น่าจะใช้ได้ ขอยืมก่อนนะครับ")
			else: say("มีเครื่องจั๊มพ์แบตด้วย กระดาษข้างหน้าต่างเขียนไว้ว่าอะไรนะ")

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

func failed_start() -> void:
	lock_scene()
	var driver := Camera3D.new()
	driver.position = Vector3(1.92,1.5,4.2)
	driver.fov = 78
	add_child(driver)
	driver.current = true
	play_sound("starter")
	say("ไม่ติดแฮะ อย่าบอกนะว่าต้องนอนอยู่ตรงนี้",3)
	await wait_for(2.4)
	say("โทรออกไม่ได้เลย บ้านตรงนั้นยังมีไฟ ลองเดินไปถามดูแล้วกัน",5)
	await wait_for(1.5)
	player.camera.current = true
	driver.queue_free()
	stage = Stage.FIELD
	objective.text = "เดินตามทางหญ้าไปขอความช่วยเหลือที่บ้าน"
	frog.appear_at(Vector3(-8,.05,-13))
	frog.face_towards(player.position)
	await look_at_point(Vector3(0,2,-30),1.2)
	unlock_scene()

func window_event() -> void:
	lock_scene()
	subtitle.text = ""
	frog.clear_scene_rules()
	frog.appear_at(Vector3(5.65,.05,-34))
	frog.face_towards(player.position)
	play_sound("knock")
	await look_at_point(Vector3(5.65,1.55,-34))
	await wait_for(1.1)
	for n in house_lights: n.visible = false
	player.torch.visible = false
	play_cue("low_pulse",-23.0)
	overlay.color.a = 1
	await wait_for(2.0)
	frog.vanish()
	for n in house_lights: n.visible = true
	overlay.color.a = 0
	player.torch.visible = true
	stage = Stage.BATTERY
	objective.text = "หาอุปกรณ์ช่วยสตาร์ตรถ · สำรวจห้องนอนด้านใน"
	say("เมื่อกี้มีเสียงหายใจอยู่ข้างหู ผมยืนกลั้นหายใจแทบตาย",7)
	unlock_scene()

func recognize_room() -> void:
	lock_scene()
	# Swing the already-open door just enough to expose the inside number.
	var door := $World/House/BedroomDoor
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(door,"rotation:y",-.45,.7)
	play_cue("door",-26.0)
	await t.finished
	await look_at_point(Vector3(0,1.85,-40.2),.8)
	say("407... เลขเดียวกับห้องพ่อเลย",5)
	await wait_for(3.5)
	await look_at_point(Vector3(-.9,1,-44.8),1.2)
	say("สายชาร์จพันเทปแบบนี้ ของพ่อนี่ ผมเพิ่งเก็บใส่กล่องมาเอง",5)
	await wait_for(4.0)
	ringing.play()
	say("เสียงโทรศัพท์พ่อดังมาจากใต้ผ้าห่ม\nแต่เครื่องของพ่ออยู่ในกระเป๋าผม ผมปิดมันไว้แล้วด้วย",5)
	await wait_for(4.5)
	# Leave a full opening for the return; the number stays attached to the door.
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(door,"rotation:y",-PI/2,.5)
	await t.finished
	stage = Stage.RETURN
	objective.text = RETURN_OBJECTIVE
	frog.appear_at(RETURN_FROG)
	frog.face_towards(player.position)
	# The note has taught the rule: from here, staring at it up close sets it off.
	frog.threat_enabled = true
	unlock_scene()

func update_return() -> void:
	if player.position.z> -29: ringing.stop()
	# No captions or relocations while the frog is holding you.
	if choke != null:
		return
	if return_caption_step == 0 and player.position.z> -28:
		return_caption_step = 1
		say("เมื่อกี้มันอยู่หน้าบ้าน ทำไมมาอยู่ตรงนี้แล้ว",6)
	if return_caption_step == 1 and player.position.z> -12:
		return_caption_step = 2
		play_cue("low_pulse",-26.0)
		say("อย่าไปมองมัน เดินไปให้ถึงรถก่อน",6)
	# While it hunts it is not playing the relocation game.
	if frog.is_hunting():
		return
	# Queue one move per route milestone. Existing frog logic waits until unseen.
	# Also protect the destination: it must be outside the current view, avoiding pops.
	var points: Array[Vector3] = [Vector3(3.8,.05,-15),Vector3(-2.1,.05,-4)]
	var milestones := [-23.0,-13.0]
	if return_step<points.size() and not destination_pending and player.position.z>milestones[return_step]:
		var point := points[return_step]
		if not player.camera.is_position_in_frustum(point+Vector3.UP):
			frog.relocate_when_unseen(point,.4)
			destination_pending = true
			return_step += 1
	if player.position.z> -1 and not frog.is_seen():
		frog.clear_scene_rules()
		frog.vanish()

func repair_car() -> void:
	lock_scene()
	frog.threat_enabled = false
	warn_breath.stop()
	frog.clear_scene_rules()
	frog.vanish()
	ringing.stop()
	objective.text = "ต่อเครื่องจั๊มพ์แบตเตอรี่เข้ากับขั้วแบตเตอรี่"
	var hood := $World/Car/Hood
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(hood,"rotation:x",-.65,.6)
	await t.finished
	play_sound("clamp")
	say("ขั้วบวก... ขั้วลบ...",3)
	await wait_for(2.5)
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(hood,"rotation:x",0,.6)
	await t.finished
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(overlay,"color:a",1.0,.4)
	await t.finished
	await wait_for(.5)
	cut_camera = Camera3D.new()
	cut_camera.name = "DriverView"
	cut_camera.position = Vector3(1.92,1.5,4.2)
	cut_camera.fov = 78
	add_child(cut_camera)
	cut_camera.current = true
	player.torch.visible = false
	player.body_visual.hide()
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(overlay,"color:a",0.0,.65)
	await t.finished
	play_sound("starter")
	await wait_for(1.7)
	engine.play()
	stage = Stage.REPAIRED
	objective.text = ""
	say("ติดแล้ว ไปได้สักที",4)
	await wait_for(4.5)
	# The original sitting animation owns the pose; no skeleton/model edits.
	player.position = Vector3(1.92,0,4.2)
	frog.appear_at(Vector3(2.88,.28,4.05),true)
	# Let the existing SITTING branch and head tracker run during the cinematic.
	# Its optional game link would otherwise enter the paused WATCH stop branch.
	frog.game = null
	frog.turn_body = false
	frog.head_tracking = true
	frog.rotation.y = 0
	play_sound("seatbelt")
	await wait_for(.7)
	var aim := cut_camera.transform.looking_at(Vector3(2.88,1.5,4.05),Vector3.UP)
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(cut_camera,"quaternion",aim.basis.get_rotation_quaternion(),2.8 if reduced_motion_enabled() else 1.6)
	await t.finished
	say("“ไม่ต้องมองหาแล้ว”",4)
	await wait_for(3)
	overlay.color.a = 1
	subtitle.text = ""
	engine.stop()
	play_cue("tape",-24.0)
	stage = Stage.END
	await wait_for(1)
	ending_presented = true
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("complete_episode"):
		anthology.complete_episode(EPISODE_ID,EPILOGUE)
	else:
		show_panel("THE PASSENGER  /  ผู้โดยสาร",EPILOGUE,"เล่นตอนนี้อีกครั้ง")



# ---------------------------------------------------------------- threat & catch

func _on_threat_stage(n: int) -> void:
	if n >= 3:
		if not warn_breath.playing: warn_breath.play()
		# One dark pulse at the edge of the screen: it is about to come.
		var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		t.tween_property(overlay,"color:a",.35,.12)
		t.tween_property(overlay,"color:a",0.0,.5)
	elif warn_breath.playing:
		warn_breath.stop()


func _on_frog_caught() -> void:
	if choke != null: return
	busy = true                      # no interaction; the frog keeps running its pose
	warn_breath.stop()
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
	catches += 1
	choke.cleanup()
	choke.queue_free()
	choke = null
	restart_return()
	await wait_for(1.5)             # held on black
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(overlay,"color:a",0.0,1.0)
	say("ผมสะดุ้ง... ยังยืนอยู่หน้าประตูห้องนอน คอยังเจ็บอยู่เลย",5)
	busy = false


# Back to the start of the walk to the car, frog reset to its first spot.
func restart_return() -> void:
	frog.stop_hunt()
	frog.clear_scene_rules()
	frog.appear_at(RETURN_FROG)
	frog.threat_enabled = true
	return_step = 0
	destination_pending = false
	player.global_position = RETURN_START
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = PI             # facing the way out, toward the car
	player.pitch = 0
	player.spring_arm.rotation.x = 0
	player.torch.rotation.x = 0
	player.stamina = 100
	frog.face_towards(player.position)
	objective.text = RETURN_OBJECTIVE
	objective.visible = true
