extends Node3D
## Story direction uses only the existing frog's public scene helpers.
const PlayerScript = preload("res://scripts/player.gd")
const FrogScript = preload("res://scripts/frog_watcher.gd")
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
var caption_time := 0.0
var elapsed := 0.0
var return_step := 0
var destination_pending := false
var cut_camera: Camera3D
var sound: AudioStreamPlayer
var ringing: AudioStreamPlayer3D
var engine: AudioStreamPlayer
var house_lights: Array[Light3D] = []

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
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(field)
	field.play()
	setup_ui()
	show_panel("DON'T FOLLOW THE FROG","ถนนชนบท · คืนเดียวกัน\n\nรถที่เคยจอดอยู่หน้าโรงแรมมาอยู่ตรงนี้ได้อย่างไร\nไฟฉุกเฉินยังติดอยู่ แต่เครื่องยนต์เงียบสนิท\n\nWASD เดิน  ·  เมาส์มอง  ·  Shift วิ่ง\nE สำรวจ  ·  F ไฟฉาย  ·  Esc พัก","เริ่มบทกบ")

func make_label(size: int, color := Color(.89,.91,.81)) -> Label:
	var n := Label.new()
	n.add_theme_font_override("font",load("res://NotoSansThai.ttf"))
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	n.add_theme_color_override("font_outline_color",Color(.015,.025,.022,.95))
	n.add_theme_constant_override("outline_size",5)
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
	chapter.text = "DON'T FOLLOW THE FROG   /   ถนนกลางทุ่ง"
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
	subtitle = make_label(23)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle.offset_left = 80
	subtitle.offset_right = -80
	subtitle.offset_top = -170
	subtitle.offset_bottom = -85
	ui.add_child(subtitle)
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
	style.bg_color = Color(.025,.043,.035,.98)
	style.border_color = Color(.25,.33,.21)
	style.set_border_width_all(1)
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	card.add_theme_stylebox_override("panel",style)
	panel.add_child(card)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation",22)
	card.add_child(contents)
	panel_title = make_label(32,Color(.73,.83,.59))
	contents.add_child(panel_title)
	panel_text = make_label(22)
	panel_text.custom_minimum_size.x = 620
	panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(panel_text)
	panel_button = Button.new()
	panel_button.custom_minimum_size.y = 48
	panel_button.add_theme_font_override("font",load("res://NotoSansThai.ttf"))
	panel_button.add_theme_font_size_override("font_size",22)
	contents.add_child(panel_button)
	panel_button.pressed.connect(panel_continue)

func show_panel(title: String, text: String, button: String) -> void:
	panel_title.text = title
	panel_text.text = text
	panel_button.text = button
	panel.show()
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel_button.grab_focus()

func panel_continue() -> void:
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
		say("ฉันจำได้ว่าจอดรถไว้หน้าโรงแรม...",5)

func say(text: String, seconds := 5.0) -> void:
	subtitle.text = text
	caption_time = seconds

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
	if event.is_action_pressed("pause_game") and started and not reading and stage != Stage.END:
		if paused:
			panel_continue()
		else:
			paused = true
			show_panel("พักเกม","WASD เดิน · E สำรวจ · F ไฟฉาย\nกลับไปยังรถหลังได้เครื่องจั๊มพ์แบตเตอรี่","เล่นต่อ")
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
		if caption_time<=0: subtitle.text = ""
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
		say("มีใครอยู่ไหมครับ รถผมเสีย...",5)
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
			else: say("แบตเตอรี่หมด ต้องหาเครื่องจั๊มพ์แบตเตอรี่จากบ้านกลางทุ่ง")
		"note":
			if stage in [Stage.HOUSE,Stage.NOTE]:
				stage = Stage.NOTE
				reading = true
				show_panel("DON'T LOOK AT IT.","If it knows you can see it,\nit will follow you.\n\nอย่ามองมัน\nถ้ามันรู้ว่าคุณมองเห็น มันจะตามคุณมา","วางกระดาษ")
			else: say("DON'T LOOK AT IT. If it knows you can see it, it will follow you.")
		"battery":
			if stage == Stage.BATTERY:
				$World/House/Bedroom407/JumpStarter.hide()
				stage = Stage.RECOGNITION
				objective.text = "นำเครื่องจั๊มพ์แบตเตอรี่กลับไปที่รถ"
				say("ยังมีไฟอยู่... น่าจะพอสตาร์ตรถได้")
			else: say("เครื่องจั๊มพ์แบตเตอรี่... ลองอ่านกระดาษข้างหน้าต่างก่อน")

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
	say("เครื่องยนต์หมุนอย่างอ่อนแรง... แล้วเงียบไป",3)
	await wait_for(2.4)
	say("โทรศัพท์ไม่มีสัญญาณ แต่บ้านกลางทุ่งยังเปิดไฟอยู่",5)
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
	overlay.color.a = 1
	await wait_for(2.0)
	frog.vanish()
	for n in house_lights: n.visible = true
	overlay.color.a = 0
	player.torch.visible = true
	stage = Stage.BATTERY
	objective.text = "หาอุปกรณ์ช่วยสตาร์ตรถ · สำรวจห้องนอนด้านใน"
	unlock_scene()

func recognize_room() -> void:
	lock_scene()
	# Swing the already-open door just enough to expose the inside number.
	var door := $World/House/BedroomDoor
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(door,"rotation:y",-.45,.7)
	await t.finished
	await look_at_point(Vector3(0,1.85,-40.2),.8)
	await wait_for(1.3)
	await look_at_point(Vector3(-.9,1,-44.8),1.2)
	ringing.play()
	await wait_for(1.5)
	# Leave a full opening for the return; the number stays attached to the door.
	t = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(door,"rotation:y",-PI/2,.5)
	await t.finished
	stage = Stage.RETURN
	objective.text = "Return to your car.  /  กลับไปที่รถ"
	frog.appear_at(Vector3(-4,.05,-23))
	frog.face_towards(player.position)
	unlock_scene()

func update_return() -> void:
	if player.position.z> -29: ringing.stop()
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
	overlay.color.a = 1
	await wait_for(.5)
	cut_camera = Camera3D.new()
	cut_camera.name = "DriverView"
	cut_camera.position = Vector3(1.92,1.5,4.2)
	cut_camera.fov = 78
	add_child(cut_camera)
	cut_camera.current = true
	player.torch.visible = false
	player.body_visual.hide()
	overlay.color.a = 0
	play_sound("starter")
	await wait_for(1.7)
	engine.play()
	stage = Stage.REPAIRED
	objective.text = ""
	say("เครื่องติดแล้ว... กลับได้แล้ว",4)
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
	t.tween_property(cut_camera,"quaternion",aim.basis.get_rotation_quaternion(),1.6)
	await t.finished
	say("“Now you can stop looking.”",4)
	await wait_for(3)
	overlay.color.a = 1
	subtitle.text = ""
	engine.stop()
	stage = Stage.END
	await wait_for(1)
	show_panel("DON'T FOLLOW THE FROG","จบบท","เล่นบทนี้อีกครั้ง")
