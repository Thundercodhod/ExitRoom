extends Node3D

@onready var player = $Player
@export_range(0.5, 4.0, 0.1) var hall_figure_vanish_distance := 1.8
var hall_figure_vanished := false
var stage := 0
var busy := false
var started := false
var paused := false
var door_busy := false
var overlay: ColorRect
var ui: CanvasLayer
var title_screen: Control
var pause_screen: Control
var objective: Label
var subtitle: Label
var subtitle_plate: ColorRect
var prompt: Label
var chapter: Label
var shade: ColorRect
var time_card: Label
var effect: ShaderMaterial
var subtitle_id := 0
var subtitle_clock := 0.0
var subtitle_hold := 0.0
var instant_text := false
var drone: AudioStreamPlayer
var scrape: AudioStreamPlayer3D
var ending_screen: Control
var episode_finished := false

const BODY_FONT := "res://ui/fonts/ChakraPetch-Regular.ttf"
const TITLE_FONT := "res://ui/fonts/ChakraPetch-Bold.ttf"
const FALLBACK_FONT := "res://Room407/assets/NotoSansThai.ttf"
const ENDING := "ผมไม่เก็บอะไรเลย วิ่งลงบันไดไปทั้งชุดนอน\nพอโทรหาเจ้าของหอ เขาบอกว่าผมคืนกุญแจไปตั้งแต่คืนก่อนแล้ว\n\nตอน 07:16 มีข้อความเสียงส่งมาจากเบอร์ของผมเอง\n“มีคนยืนอยู่หน้าห้อง มันใส่เสื้อเหมือนผมเลย” แล้วก็มีเสียงเคาะ\n\nกล่องเสื้อผ้ายังอยู่ที่นั่น ผมยอมซื้อใหม่ ยังไงก็ไม่กลับไป\nส่วนข้อความนั้น ผมลบไปแล้ว วันถัดมามันก็ส่งมาอีก"
const OBJECTIVES := [
	"ห้อง 406 · อ่านใบรับห้องบนตู้ข้างประตู",
	"คืนแรก · เปิดกล่องย้ายบ้าน",
	"เก็บของแล้ว · เข้านอน",
	"03:07 · ตรวจเสียงที่ประตูห้องข้าง ๆ",
	"ประตูไม่เปิด · กลับไปพักในห้อง 406",
	"07:16 · ตรวจประตู 407 อีกครั้ง",
	"เก็บแรงไว้ · พักก่อนเฝ้าทางเดินคืนนี้",
	"คืนที่สอง · เข้าไปในห้อง 407",
	"อ่านใบตรวจห้องบนตู้ในห้อง 407",
	"พลิกใบตรวจห้อง · อ่านบรรทัดสุดท้าย"
]

func _ready() -> void:
	make_ui()
	set_407(false)
	$Room407/SleepingDouble.visible = false
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.get("settings") is Dictionary:
		player.reduced_motion = bool(anthology.settings.get("reduced_motion", false))
		instant_text = bool(anthology.settings.get("instant_text", false))
	var animation: AnimationPlayer = $HallFigure.find_child("AnimationPlayer", true, false)
	if animation:
		for clip in animation.get_animation_list():
			if str(clip).to_lower().contains("idle"):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animation.play(clip)
				break
	drone = AudioStreamPlayer.new()
	var stream := (load("res://Room407/audio/drone.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = stream.data.size() / 2
	drone.stream = stream
	drone.volume_db = -33
	if AudioServer.get_bus_index("Ambience") >= 0:
		drone.bus = "Ambience"
	add_child(drone)
	drone.play()
	scrape = AudioStreamPlayer3D.new()
	scrape.stream = load("res://Room407/audio/drag_placeholder.wav")
	scrape.position = Vector3(3, 0.6, -3)
	scrape.volume_db = -12
	scrape.max_distance = 18
	if AudioServer.get_bus_index("SFX") >= 0:
		scrape.bus = "SFX"
	add_child(scrape)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.locked = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture.call_deferred(arg.get_slice("=", 1))

func game_font(bold := false) -> Font:
	var path := TITLE_FONT if bold else BODY_FONT
	return load(path if ResourceLoader.exists(path) else FALLBACK_FONT) as Font

func text(parent: Node, value: String, pos: Vector2, size: int, color := Color(.88, .86, .79), bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", game_font(bold))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func menu_button(parent: Node, value: String, pos: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = pos
	button.custom_minimum_size = Vector2(390, 52)
	button.size = button.custom_minimum_size
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_font_override("font", game_font(true))
	button.add_theme_color_override("font_color", Color(.86, .83, .74))
	button.add_theme_color_override("font_hover_color", Color(1.0, .93, .75))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.055, .058, .056, .8) if state == "normal" else Color(.16, .15, .115, .95)
		style.border_width_left = 2
		style.border_color = Color(.55, .47, .32) if state == "normal" else Color(.94, .77, .47)
		style.content_margin_left = 18
		style.content_margin_right = 18
		button.add_theme_stylebox_override(state, style)
	parent.add_child(button)
	button.pressed.connect(func():
		play_sound("ui_accept", -22)
		action.call())
	button.mouse_entered.connect(func(): play_sound("ui_move", -27))
	return button

func make_ui() -> void:
	var retro := CanvasLayer.new()
	retro.layer = 1
	add_child(retro)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect = ShaderMaterial.new()
	effect.shader = load("res://Room407/assets/shaders/retro_horror.gdshader")
	effect.set_shader_parameter("pixel_height", 270.0)
	effect.set_shader_parameter("softness", .52)
	effect.set_shader_parameter("exposure", .98)
	effect.set_shader_parameter("vignette_strength", .3)
	overlay.material = effect
	retro.add_child(overlay)
	ui = CanvasLayer.new()
	ui.layer = 4
	add_child(ui)
	chapter = text(ui, "EPISODE 03     /     ROOM 407     /     คืนแรก", Vector2(34, 25), 16, Color(.77, .64, .42), true)
	objective = text(ui, OBJECTIVES[0], Vector2(34, 52), 21)
	prompt = text(ui, "", Vector2(0, 521), 22, Color(.91, .85, .65), true)
	prompt.size.x = 1280
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_plate = ColorRect.new()
	subtitle_plate.position = Vector2(110, 568)
	subtitle_plate.size = Vector2(1060, 108)
	subtitle_plate.color = Color(.016, .019, .021, .86)
	subtitle_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(subtitle_plate)
	subtitle_plate.hide()
	subtitle = text(ui, "", Vector2(136, 579), 25)
	subtitle.size = Vector2(1008, 90)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_constant_override("outline_size", 3)
	subtitle.add_theme_color_override("font_outline_color", Color(.015, .018, .022, .95))
	text(ui, "·", Vector2(635, 347), 24)
	text(ui, "WASD เดิน    Shift เร่งเดิน    E สำรวจ    F ไฟฉาย    Esc พัก    F1 เมนูหลัก", Vector2(34, 688), 14, Color(.60, .61, .60))
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	time_card = text(shade,"",Vector2(0,320),32,Color(.87,.84,.73),true)
	time_card.size.x = 1280
	time_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_card.hide()
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(title_screen)
	var panel := ColorRect.new()
	panel.color = Color(.015, .018, .022, .94)
	panel.size = Vector2(730, 720)
	title_screen.add_child(panel)
	var rule := ColorRect.new()
	rule.position = Vector2(64, 147)
	rule.size = Vector2(42, 3)
	rule.color = Color(.79, .32, .21)
	title_screen.add_child(rule)
	text(title_screen, "EXITROOM     /     EPISODE 03", Vector2(64, 108), 17, Color(.73, .65, .49), true)
	text(title_screen, "ROOM 407", Vector2(58, 161), 76, Color(.91, .88, .79), true)
	text(title_screen, "ห้องที่ไม่มีใครเช่า", Vector2(66, 260), 32, Color(.83, .77, .62), true)
	text(title_screen, "“ช่างบอกว่าซ่อมท่อน้ำแค่สัปดาห์เดียว\nผมเลยเช่าห้องนี้ไว้ก่อน”", Vector2(66, 337), 27)
	var intro := text(title_screen, "ธีร์ / ผู้เช่าชั่วคราว\nอาคารพักอาศัยชานเมือง · คืนแรก · 22:48", Vector2(66, 450), 19, Color(.64, .66, .64))
	intro.size.x = 590
	menu_button(title_screen, "เข้าพัก   →", Vector2(66, 552), start).grab_focus()
	menu_button(title_screen, "กลับหน้าเลือกตอน", Vector2(66, 614), return_to_menu)
	pause_screen = Control.new()
	pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pause_screen)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(.015, .018, .022, .96)
	pause_screen.add_child(bg)
	text(pause_screen, "EPISODE 03 / ROOM 407", Vector2(100, 85), 17, Color(.77, .64, .42), true)
	text(pause_screen, "พักหายใจ", Vector2(96, 125), 48, Color(.88, .86, .79), true)
	menu_button(pause_screen, "เล่นต่อ   [ Esc ]", Vector2(100, 231), resume_game)
	menu_button(pause_screen, "เริ่มตอนนี้ใหม่", Vector2(100, 297), restart_story)
	menu_button(pause_screen, "กลับหน้าเลือกตอน", Vector2(100, 363), return_to_menu)
	text(pause_screen, "M  เปิด / ปิดการลดการเคลื่อนไหวกล้อง", Vector2(100, 450), 19, Color(.68, .66, .61))
	text(pause_screen, "Assets: Vicious Potato Studios / PomidorkaStudios\nTextures: NeoKG (CC BY 4.0) / Poly Haven\nรายละเอียดเครดิต: Room407/ASSET_CREDITS.md", Vector2(100, 556), 16, Color(.49, .51, .51))
	pause_screen.hide()
	make_ending()

func start() -> void:
	if started:
		return
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("reveal_gameplay"):
		await anthology.reveal_gameplay(_start_gameplay)
	else:
		_start_gameplay()

func _start_gameplay() -> void:
	started = true
	title_screen.hide()
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	say("ผมชื่อธีร์ ห้องเก่าท่อน้ำแตกจนต้องรื้อพื้น\nหอนี้อยู่ใกล้ที่ทำงาน ผมเลยขอเช่าแค่เจ็ดคืน ระหว่างรอช่างซ่อม", 9)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_ESCAPE and started and not busy and not ending_screen.visible:
		set_paused(not paused)
		get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_M and started and not episode_finished:
		player.reduced_motion = not player.reduced_motion
		var anthology := get_node_or_null("/root/Anthology")
		if anthology and anthology.get("settings") is Dictionary:
			anthology.settings["reduced_motion"] = player.reduced_motion
			if anthology.has_method("save_preferences"):
				anthology.save_preferences()
		say("ลดการเคลื่อนไหวกล้อง: " + ("เปิด" if player.reduced_motion else "ปิด"))
	if event.physical_keycode == KEY_R and started and paused:
		restart_story()
		return
	if event.physical_keycode == KEY_E and started and not paused and not busy and not player.locked:
		var node: Node = player.target()
		if node:
			interact(str(node.get_meta("action")))

func set_paused(value: bool) -> void:
	paused = value
	pause_screen.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	player.locked = paused
	player.velocity = Vector3.ZERO
	drone.stream_paused = paused
	scrape.stream_paused = paused
	if paused:
		pause_screen.find_children("*", "Button", true, false)[0].grab_focus()

func resume_game() -> void:
	set_paused(false)

func _process(delta: float) -> void:
	if not started or paused or episode_finished:
		return
	if not subtitle.text.is_empty():
		subtitle_clock += delta
		if not instant_text:
			subtitle.visible_characters = mini(int(subtitle_clock * 40.0), subtitle.text.length())
		if subtitle_clock > subtitle_hold:
			subtitle.text = ""
			subtitle_plate.hide()
	if stage == 4 and not busy and not player.locked and not hall_figure_vanished and $HallFigure.visible:
		if player.global_position.distance_squared_to($HallFigure.global_position) <= hall_figure_vanish_distance * hall_figure_vanish_distance:
			hall_figure_vanished = true
			$HallFigure.hide()
			play_sound("low_pulse", -22)
			say("เมื่อกี้ยังยืนอยู่ตรงนี้เลย ไปไหนแล้ว\nแล้วใครปิดไฟห้องผม ผมเปิดทิ้งไว้นี่", 8)
	objective.text = OBJECTIVES[clampi(stage, 0, OBJECTIVES.size() - 1)]
	var node: Node = player.target()
	prompt.text = "[ E ]  " + str(node.get_meta("hint")) if node and not busy and not player.locked else ""
	if stage == 7 and not busy and player.global_position.distance_to(Vector3(2.3, 0, -4.25)) < 2.2:
		reveal()

func interact(action: String) -> void:
	match action:
		"note":
			play_sound("tape", -24)
			say("ใบรับห้องเขียนว่า “ธีร์ / 406 / เจ็ดคืน”\nแต่ตรงจำนวนคนพักเขียนไว้สองคน คงกรอกผิด เดี๋ยวพรุ่งนี้ค่อยบอก", 10)
			if stage == 0:
				stage = 1
		"unpack":
			if stage == 1:
				stage = 2
				play_sound("message", -23)
				say("เบอร์ที่ไม่ได้บันทึก: “พรุ่งนี้ไม่ต้องตั้งปลุก 07:16 หรอก เดี๋ยวปลุกให้”\nผมตั้งเวลานี้จริง ๆ ตอนแรกก็นึกว่าเพื่อนแกล้ง", 10)
			else:
				say("เอามาแค่เสื้อผ้ากับนาฬิกาปลุก เดี๋ยวก็ได้กลับแล้ว")
		"bed":
			if stage in [2, 4, 6]:
				sleep_transition()
			else:
				say("ขอทำธุระให้เสร็จก่อน ค่อยนอน")
		"wall":
			if stage == 5:
				stage = 6
				play_sound("message", -24)
				say("ผมส่งรูปให้เจ้าของหอ ถามว่าประตูข้างห้องหายไปไหน\nเขาโทรกลับมาถามว่า “เมื่อคืนคืนกุญแจแล้วไม่ใช่เหรอ ยังไม่กลับอีก?”", 10)
			else:
				say("ผมจำไม่ผิดแน่ เมื่อคืนมีประตูตรงนี้")
		"door406":
			toggle_door($Door406)
		"door407":
			if stage == 3:
				busy = true
				stage = 4
				scrape.stop()
				$HallFigure.visible = not hall_figure_vanished
				play_sound("knock", -20)
				say("“ธีร์ กลับไปนอนเถอะ อย่าลืมคลุมเท้าด้วย”\nผมไม่ได้บอกชื่อเขา แล้วเรื่องนอนคลุมเท้า เขารู้ได้ยังไง", 10)
				await player.focus_on(Vector3(4, 1.7, 0))
				busy = false
			elif stage >= 7:
				toggle_door($Door407)
		"double":
			if stage == 7:
				reveal()
		"future_note":
			if stage == 8:
				stage = 9
				play_sound("tape", -22)
				chapter.text = "EPISODE 03     /     ใบตรวจห้องลงวันที่พรุ่งนี้"
				say("กระดาษลงวันที่พรุ่งนี้ เขียนชื่อผมกับเลขห้องไว้\n“ผู้เช่าจะยืนข้างตู้ อ่านหน้านี้ แล้วพลิกดูด้านหลัง”", 11)
			elif stage == 9:
				if not busy: finish_note()
			else:
				say("วันที่บนกระดาษเป็นวันพรุ่งนี้ ใครเขียนไว้")

func toggle_door(door: Node3D) -> void:
	if door_busy:
		return
	# Preserve the existing doorway safety check and collision geometry.
	if absf(door.rotation.y) > .2 and player.position.distance_to(door.position) < 1.4:
		say("ยืนขวางอยู่ ต้องถอยก่อน")
		return
	door_busy = true
	play_sound("door", -24)
	var angle := 0.0 if absf(door.rotation.y) > .2 else deg_to_rad(96)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(door, "rotation:y", angle, .6)
	await tween.finished
	door_busy = false

func say(line: String, seconds := 5.0) -> void:
	subtitle_id += 1
	subtitle.text = line
	subtitle.visible_characters = -1 if instant_text else 0
	subtitle_clock = 0.0
	# Reading time includes both the typewriter reveal and a full reading interval.
	subtitle_hold = maxf(seconds, float(line.length()) / 40.0 + 4.5)
	subtitle_plate.show()

func play_sound(sound: String, volume_db := -18.0) -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("play_sfx"):
		anthology.play_sfx(sound, volume_db)

func enabled(node: Node, value: bool) -> void:
	if node is Node3D:
		node.visible = value
	if node is CollisionShape3D:
		node.set_deferred("disabled", not value)
	for child in node.get_children():
		enabled(child, value)

func set_407(value: bool) -> void:
	enabled($Door407, value)
	enabled($Wall407, not value)

func sleep_transition() -> void:
	busy = true
	subtitle.text = ""
	subtitle_plate.hide()
	player.locked = true
	player.velocity = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(shade, "color:a", 1.0, 1.2)
	await tween.finished
	time_card.text = "03:07 น.  /  คืนนั้น" if stage==2 else ("07:16 น.  /  เช้าวันถัดมา" if stage==4 else "03:07 น.  /  คืนที่สอง")
	time_card.show()
	await get_tree().create_timer(.85,false).timeout
	time_card.hide()
	player.position = Vector3(-4.0, .04, -3.5)
	player.rotation.y = PI
	player.pitch = 0
	player.camera.rotation.x = 0
	player.velocity = Vector3.ZERO
	if stage == 2:
		stage = 3
		set_407(true)
		scrape.play()
		chapter.text = "EPISODE 03     /     คืนแรก     /     03:07"
		say("ใครลากอะไรอยู่ตอนนี้ ตีสามแล้วนะ\nพอผมลุกจากเตียง เสียงก็เงียบไป", 9)
	elif stage == 4:
		stage = 5
		$HallFigure.hide()
		set_407(false)
		scrape.stop()
		$WorldEnvironment.environment.ambient_light_energy = .65
		chapter.text = "EPISODE 03     /     เช้าวันถัดมา     /     07:16"
		say("ตื่นสายจนได้ นาฬิกาไม่ดังเลย\nเมื่อคืนผมตั้งปลุกไว้แล้วนะ จำได้ว่าลองกดฟังด้วย", 9)
	elif stage == 6:
		stage = 7
		set_407(true)
		$Door407.rotation.y = deg_to_rad(-96)
		$Room407/SleepingDouble.visible = true
		$WorldEnvironment.environment.ambient_light_energy = .22
		chapter.text = "EPISODE 03     /     คืนที่สอง     /     03:07"
		play_sound("fluorescent", -28)
		say("ผมว่าจะไม่นอน แต่เผลอหลับไปจนได้\nเสียงปลุกดังมาจากห้องข้าง ๆ คราวนี้ประตูเปิดอยู่", 10)
	await get_tree().create_timer(.7).timeout
	tween = create_tween()
	tween.tween_property(shade, "color:a", 0.0, 1.2)
	await tween.finished
	player.locked = false
	busy = false

func reveal() -> void:
	if busy or stage != 7:
		return
	busy = true
	stage = 8
	play_sound("sting", -25)
	say("เสื้อตัวนั้น... ผมใส่อยู่เหมือนกัน\nผมลองกลั้นหายใจ คนบนเตียงก็หยุดหายใจไปด้วย", 10)
	await player.focus_on(Vector3(2.3, .72, -4.85))
	var light: OmniLight3D = $Room407/BedLight
	var tween := create_tween()
	if player.reduced_motion:
		tween.tween_property(light, "light_energy", 1.0, .8)
	else:
		tween.tween_property(light, "light_energy", .35, .15)
		tween.tween_property(light, "light_energy", 1.1, .4)
	await tween.finished
	busy = false

func capture(view: String) -> void:
	start()
	subtitle.text = ""
	subtitle_plate.hide()
	if view == "bedroom":
		player.position = Vector3(-3.6, .03, -.65)
		player.rotation.y = 0
		player.pitch = -.06
	elif view == "double":
		stage = 8
		set_407(true)
		$Door407.rotation.y = deg_to_rad(-96)
		$Room407/SleepingDouble.visible = true
		player.position = Vector3(4, .03, -2.1)
		player.rotation.y = .58
		player.pitch = -.28
	else:
		player.position = Vector3(-6.7, .03, 1.8)
		player.rotation.y = -1.3
	player.camera.rotation.x = player.pitch
	player.locked = true
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://Room407/previews")
	get_viewport().get_texture().get_image().save_png("res://Room407/previews/" + view + ".png")
	get_tree().quit()

func make_ending() -> void:
	ending_screen = Control.new()
	ending_screen.name = "Room407Ending"
	ending_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ending_screen)
	var background := ColorRect.new()
	background.color = Color(.018, .021, .024, .99)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_screen.add_child(background)
	text(ending_screen, "EPISODE 03     /     END OF RECORDING", Vector2(100, 63), 17, Color(.73, .61, .41), true)
	text(ending_screen, "ห้องที่ไม่มีใครเช่า", Vector2(96, 110), 46, Color(.91, .87, .76), true)
	var letter := text(ending_screen, ENDING, Vector2(100, 200), 24)
	letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter.size = Vector2(1080, 327)
	menu_button(ending_screen, "กลับหน้าเลือกตอน", Vector2(100, 557), return_to_menu)
	menu_button(ending_screen, "เล่น ROOM 407 อีกครั้ง", Vector2(100, 620), restart_story)
	ending_screen.hide()

func show_ending() -> void:
	if episode_finished:
		return
	episode_finished = true
	busy = true
	subtitle_id += 1
	subtitle.text = ""
	subtitle_plate.hide()
	prompt.text = ""
	player.locked = true
	player.velocity = Vector3.ZERO
	scrape.stop()
	drone.volume_db = -40
	play_sound("knock", -25)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("complete_episode"):
		anthology.complete_episode("room407", ENDING)
	else:
		ending_screen.show()
		ending_screen.find_children("*", "Button", true, false)[0].grab_focus()

func finish_note() -> void:
	busy = true
	player.locked = true
	player.velocity = Vector3.ZERO
	say("ด้านหลังมีแค่บรรทัดเดียว\n‘อ่านจบแล้วใช่ไหม ทีนี้ลองฟังเสียงหน้าประตู’",8)
	await get_tree().create_timer(4.0,false).timeout
	play_sound("knock",-20)
	await get_tree().create_timer(3.0,false).timeout
	show_ending()

func return_to_menu() -> void:
	player.locked = true
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("return_to_menu"):
		anthology.return_to_menu()
	elif ResourceLoader.exists("res://main_menu.tscn"):
		get_tree().change_scene_to_file("res://main_menu.tscn")

func restart_story() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("launch_episode"):
		anthology.launch_episode("room407")
	else:
		get_tree().reload_current_scene()
