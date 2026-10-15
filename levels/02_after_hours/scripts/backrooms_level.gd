extends Node3D
const VolumeControls = preload("res://scripts/volume_controls.gd")

const PlayerScript = preload("res://scripts/player.gd")
const SpiderScript = preload("res://scripts/spider_enemy.gd")
const SPAWN := Vector3(9.5, 0.12, -9.5)
const EXIT := Vector3(-10.5, 0.0, 10.5)
const SPIDER_BOUNDS := Rect2(-12.7, -13.25, 25.4, 26.5)
const DEFAULT_STATUS := "หาประตูหนีไฟสีเขียว"
const SPIDER_ALERT := "มันได้ยินคุณแล้ว  /  หาที่กำบัง"
# The fire door's magnetic lock has no power until the breaker is reset. The
# breaker sits in the far bottom room, about 28 m of corridor from both the
# spawn and the exit, so the walk takes the player past every incident.
const BREAKER := Vector3(2.6, 0.0, 12.2)          # on the south wall, facing -Z
const BREAKER_STAND := Vector3(2.6, 0.0, 11.3)
const BREAKER_STATUS := "ประตูล็อกแม่เหล็ก  /  หาตู้เบรกเกอร์แล้วรีเซ็ตไฟ"
const RETURN_STATUS := "ไฟมาแล้ว  /  กลับไปที่ประตูหนีไฟ"
const ANNOUNCE_DISTANCE := 7.0                   # first announcement once she leaves the start
const KNOCK_EVERY := 3.2                          # seconds of walking between knocks
const ENDING := "พอผลักประตูออกมา ฉันก็เจอลานจอดรถ ฟ้าสว่างแล้ว\nฉันวิ่งไปหาพี่ รปภ. ขอให้ช่วยเรียกรถ มือสั่นจนกดมือถือไม่ถูก\n\nเขาดูหน้าจอแล้วถามว่าออกมาทางไหน ในระบบไม่มีใครเปิดประตูชั้นนั้นเลย\nฉันยังไม่ทันตอบ วิทยุบนโต๊ะเขาก็ดังขึ้น\n\n“พี่ อย่าเปิดประตูนะ คนข้างนอกไม่ใช่หนู”\nพี่ รปภ. ค่อย ๆ หันมามองฉัน\nฉันจำได้ เสียงในวิทยุนั่นมันเสียงฉัน"

var playing := false
var was_captured := false
var player: CharacterBody3D
var spider: CharacterBody3D
var caught := false
var ui: CanvasLayer
var caught_overlay: Control
var retry_button: Button
var font: Font
var overlay: Control
var prompt: Label
var status: Label
var flicker_light: OmniLight3D
var elapsed := 0.0
var intro_title: Label
var intro_copy: Label
var volume_controls: GridContainer
var begin_button: Button
var clue: Label
var started := false
var finished := false
var story_beat := 0
var chase_seen := false
var near_exit_seen := false
var power_on := false
var objective := DEFAULT_STATUS
var lock_seen := false
var resetting := false
var knock_seen := false
var walk_clock := 0.0
var lamps: Array[OmniLight3D] = []
var exit_glow: OmniLight3D
var exit_sign: Label3D
var lock_light: OmniLight3D
var lock_lamp: StandardMaterial3D
var breaker_led: OmniLight3D
var breaker_lever: MeshInstance3D
var knocker: AudioStreamPlayer3D
var title_font: Font


func _ready() -> void:
	setup_inputs()
	font = load("res://ui/fonts/ChakraPetch-Regular.ttf") as Font
	title_font = load("res://ui/fonts/ChakraPetch-Bold.ttf") as Font
	if font == null:
		font = load("res://NotoSansThai.ttf") as Font
	if title_font == null:
		title_font = font
	setup_environment()
	prepare_backrooms_materials()
	setup_collisions()
	setup_lights()
	setup_exit()
	setup_breaker()
	player = CharacterBody3D.new()
	player.name = "AfterHoursPlayer"
	player.set_script(PlayerScript)
	player.game = self
	player.position = SPAWN
	add_child(player)
	player.set_third_person(false)
	player.pivot.rotation.y = 2.35
	player.body_visual.rotation.y = 2.35 - PI
	setup_ui()
	setup_spider()
	if get_tree().root.has_meta("retry_backrooms"):
		get_tree().root.remove_meta("retry_backrooms")
		begin_game()
	else:
		show_intro()


func setup_inputs() -> void:
	var actions := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "interact": KEY_E, "flashlight": KEY_F, "pause_game": KEY_ESCAPE}
	for action in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = actions[action]
		InputMap.action_add_event(action, key)


func setup_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "YellowFluorescentAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.065, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.76, 0.54)
	environment.ambient_light_energy = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.16, 0.14, 0.07)
	environment.fog_density = 0.018
	world.environment = environment
	add_child(world)


func prepare_backrooms_materials() -> void:
	# The supplied GLB marks every surface as unlit. Give its textured walls,
	# ceiling and carpet normal lighting so the corridor can fall into shadow.
	var lit_materials := {}
	for node in $OriginalBackrooms.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var key := source.get_instance_id()
			if not lit_materials.has(key):
				var material := source.duplicate() as BaseMaterial3D
				if source.resource_name == "Ceiling_Lights":
					material.albedo_color = Color(0.44, 0.41, 0.30)
				else:
					material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				lit_materials[key] = material
			mesh.set_surface_override_material(surface, lit_materials[key])


func setup_collisions() -> void:
	# The supplied GLB has a 2-triangle floor and separate wall meshes.
	# Keep the original visuals; derive collision only from the wall pieces.
	var wall_names := ["Object_6", "Object_8", "Object_9", "Object_10", "Object_11", "Object_12"]
	for node in $OriginalBackrooms.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.name in wall_names:
			mesh.create_trimesh_collision()
	var floor_body := StaticBody3D.new()
	floor_body.name = "ReliableCarpetCollision"
	floor_body.collision_layer = 1
	add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(25.4, 0.2, 26.5)
	shape.shape = box
	shape.position = Vector3(0, -0.12, 0)
	floor_body.add_child(shape)


func setup_lights() -> void:
	for x in [-9.0, -3.0, 3.0, 9.0]:
		for z in [-9.0, -3.0, 3.0, 9.0]:
			var lamp := OmniLight3D.new()
			lamp.name = "Fluorescent %s %s" % [x, z]
			lamp.position = Vector3(x, 2.37, z)
			lamp.light_color = Color(1.0, 0.91, 0.66)
			lamp.light_energy = 0.72 if int(x + z) % 12 == 0 else 0.48
			lamp.omni_range = 7.0
			lamp.shadow_enabled = false
			add_child(lamp)
			lamps.append(lamp)
			if x == 3.0 and z == 3.0:
				flicker_light = lamp


func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.65
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func add_exit_box(parent: Node3D, local_position: Vector3, size: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = local_position
	parent.add_child(visual)


func setup_exit() -> void:
	var exit_root := Node3D.new()
	exit_root.name = "Level01Exit"
	exit_root.position = EXIT
	add_child(exit_root)
	var green := emissive(Color(0.12, 0.52, 0.27), 0.8)
	var dark := emissive(Color(0.035, 0.055, 0.04), 0.0)
	add_exit_box(exit_root, Vector3(0, 1.02, 0.92), Vector3(1.38, 2.04, 0.08), dark)
	for side in [-0.72, 0.72]:
		add_exit_box(exit_root, Vector3(side, 1.04, 0.84), Vector3(0.08, 2.12, 0.12), green)
	add_exit_box(exit_root, Vector3(0, 2.10, 0.84), Vector3(1.5, 0.12, 0.12), green)
	var sign := Label3D.new()
	sign.text = "EXIT\nSTAFF ONLY"
	sign.font = font
	sign.font_size = 48
	sign.pixel_size = 0.005
	sign.modulate = Color(0.35, 0.42, 0.36)   # unlit until the power comes back
	exit_sign = sign
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.3, 0.45)
	exit_root.add_child(sign)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.36, 1.0, 0.58)
	glow.light_energy = 0.0
	glow.omni_range = 4.5
	glow.position = Vector3(0, 1.5, 0.3)
	exit_root.add_child(glow)
	exit_glow = glow
	# A small red lamp on the lock: the door is dead until the breaker is reset.
	lock_lamp = emissive(Color(0.9, 0.08, 0.05), 2.4)
	add_exit_box(exit_root, Vector3(0.52, 1.18, 0.86), Vector3(0.12, 0.12, 0.06), lock_lamp)
	lock_light = OmniLight3D.new()
	lock_light.light_color = Color(1.0, 0.18, 0.1)
	lock_light.light_energy = 0.7
	lock_light.omni_range = 2.2
	lock_light.position = Vector3(0.52, 1.18, 0.6)
	exit_root.add_child(lock_light)


func setup_breaker() -> void:
	var root := Node3D.new()
	root.name = "BreakerPanel"
	root.position = BREAKER
	add_child(root)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.42, 0.43, 0.40)
	grey.roughness = 0.55
	grey.metallic = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.07)
	add_exit_box(root, Vector3(0, 1.35, -0.06), Vector3(0.62, 0.84, 0.12), grey)       # cabinet
	add_exit_box(root, Vector3(0, 1.35, -0.125), Vector3(0.5, 0.7, 0.01), dark)        # open door recess
	for row in 3:
		for col in 4:
			add_exit_box(root, Vector3(-0.15 + col * 0.1, 1.55 - row * 0.16, -0.14), Vector3(0.05, 0.09, 0.03), grey)
	var lever := MeshInstance3D.new()
	var lever_mesh := BoxMesh.new()
	lever_mesh.size = Vector3(0.09, 0.2, 0.05)
	lever.mesh = lever_mesh
	lever.material_override = emissive(Color(0.75, 0.12, 0.08), 0.6)
	lever.position = Vector3(0.2, 1.08, -0.15)
	lever.rotation.x = -0.6                       # tripped: pointing down
	root.add_child(lever)
	breaker_lever = lever
	var tag := Label3D.new()
	tag.text = "MAIN / ชั้น B"
	tag.font = font
	tag.font_size = 32
	tag.pixel_size = 0.004
	tag.modulate = Color(0.9, 0.86, 0.6)
	tag.position = Vector3(0, 1.86, -0.13)
	tag.rotation.y = PI
	root.add_child(tag)
	breaker_led = OmniLight3D.new()
	breaker_led.light_color = Color(1.0, 0.25, 0.12)
	breaker_led.light_energy = 0.8
	breaker_led.omni_range = 2.6
	breaker_led.position = Vector3(0, 1.4, -0.5)
	root.add_child(breaker_led)
	knocker = AudioStreamPlayer3D.new()
	knocker.name = "WallKnock"
	knocker.stream = load("res://audio/anthology/knock.wav")
	knocker.volume_db = -4.0
	knocker.unit_size = 3.0
	knocker.bus = &"SFX"
	add_child(knocker)


func styled_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func make_button(words: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size.y = 50
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.10, 0.07, 0.95)
	style.border_width_left = 2
	style.border_color = Color(0.62, 0.58, 0.32)
	style.content_margin_left = 20
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.20, 0.12)
	hover.border_color = Color(0.87, 0.78, 0.43)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	return button


func setup_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "BackroomsHUD"
	ui.layer = 5
	add_child(ui)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 26)
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_right", 26)
	ui.add_child(top)
	var header := VBoxContainer.new()
	top.add_child(header)
	header.add_child(styled_label("02   /   AFTER HOURS", 17, Color(0.84, 0.78, 0.55)))
	status = styled_label(DEFAULT_STATUS, 20, Color(0.96, 0.95, 0.83))
	header.add_child(status)
	prompt = styled_label("", 20, Color(0.6, 1.0, 0.69))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-230, -232)
	prompt.size.x = 460
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(prompt)
	clue = Label.new()
	clue.set_script(preload("res://scripts/story_caption.gd"))
	ui.add_child(clue)
	var hint := styled_label("WASD เดิน   /   SHIFT วิ่ง   /   E สำรวจ   /   F ไฟฉาย   /   ESC พัก   /   F1 เมนู", 14, Color(0.70, 0.69, 0.56))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -76)
	ui.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.026, 0.02, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.055, 0.035, 0.96)
	panel_style.border_width_top = 2
	panel_style.border_color = Color(0.62, 0.56, 0.30)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 38)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	content.add_child(styled_label("EXITROOM   /   EPISODE 02", 16, Color(0.65, 0.64, 0.47)))
	intro_title = styled_label("AFTER HOURS  /  กะสุดท้าย", 40, Color(0.95, 0.9, 0.59))
	intro_title.add_theme_font_override("font", title_font)
	content.add_child(intro_title)
	intro_copy = styled_label("", 21, Color(0.86, 0.85, 0.76))
	intro_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_copy.custom_minimum_size.x = 704
	content.add_child(intro_copy)
	volume_controls = VolumeControls.new()
	volume_controls.font = intro_copy.get_theme_font("font")
	volume_controls.accent = Color(0.80, 0.72, 0.40)
	volume_controls.visible = false
	content.add_child(volume_controls)
	begin_button = make_button("เริ่มกะสุดท้าย  /  BEGIN EPISODE", begin_game)
	content.add_child(begin_button)
	content.add_child(make_button("กลับหน้าเลือกตอน  /  EPISODES", return_to_menu))
	begin_button.grab_focus.call_deferred()
	setup_caught_ui()


func setup_spider() -> void:
	spider = CharacterBody3D.new()
	spider.name = "SpiderEnemy"
	spider.set_script(SpiderScript)
	spider.game = self
	spider.target = player
	spider.bounds = SPIDER_BOUNDS
	add_child(spider)
	spider.caught_player.connect(on_player_caught)


func setup_caught_ui() -> void:
	caught_overlay = Control.new()
	caught_overlay.name = "CaughtOverlay"
	caught_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caught_overlay.hide()
	ui.add_child(caught_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.035, 0.025, 0.020, 0.96)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caught_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caught_overlay.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	center.add_child(content)
	content.add_child(styled_label("หนีไม่ทัน", 40, Color(0.89, 0.78, 0.52)))
	content.add_child(styled_label("มันได้ยินเสียงวิ่ง\nลองอ้อมหลังผนังให้พ้นสายตา แล้วรอให้มันเดินผ่านไปก่อน", 21, Color(0.87, 0.85, 0.77)))
	retry_button = make_button("ลองอีกครั้ง  /  RETRY", restart_level)
	content.add_child(retry_button)
	content.add_child(make_button("กลับหน้าเลือกตอน  /  EPISODES", return_to_menu))


func on_player_caught() -> void:
	if caught or finished:
		return
	caught = true
	playing = false
	sound("sting", -15)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	caught_overlay.show()
	retry_button.grab_focus.call_deferred()


func restart_level() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.has_method("launch_episode"):
		anthology.launch_episode("after_hours")
	else:
		get_tree().reload_current_scene()


func show_intro() -> void:
	playing = false
	if started:
		intro_copy.text = "พักเกมอยู่\n\nกดเล่นต่อเมื่อพร้อม"
		begin_button.text = "เดินต่อ  /  RESUME"
	else:
		intro_copy.text = "ฉันชื่อริน เป็นช่างซ่อมบำรุงอยู่ที่ตึกสำนักงานแห่งหนึ่ง\nคืนนั้นเพื่อนไม่สบาย เลยมารับกะแทน\n\nสี่ทุ่มกว่า เก็บเครื่องมือเสร็จ กำลังจะกลับอยู่แล้ว\nดันได้ยินคนเรียกจากห้องเก็บของ\nฉันนึกว่าพี่แม่บ้านโดนล็อกไว้ เลยหยิบไฟฉายเข้าไปดู\n\nเดินเข้าไปไม่กี่ก้าวเอง พอหันกลับมา... ประตูอยู่ไหนก็ไม่รู้"
	volume_controls.visible = started   # only on the pause screen, not the intro
	if started: volume_controls.refresh()
	overlay.show()
	begin_button.grab_focus.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_game() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if not started and anthology and anthology.has_method("reveal_gameplay"):
		await anthology.reveal_gameplay(_begin_game)
	else:
		_begin_game()

func _begin_game() -> void:
	if caught or finished:
		return
	overlay.hide()
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	was_captured = true
	if not started:
		started = true
		sound("fluorescent", -22)
		clue.show_clue("22:06 น.\nเดี๋ยวนะ... เมื่อกี้ยังมีประตูอยู่ตรงนี้เลย")


func sound(key: String, volume: float = -20.0) -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("play_sfx"):
		anthology.play_sfx(key, volume)


func return_to_menu() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("return_to_menu"):
		anthology.return_to_menu()


func finish_episode() -> void:
	if finished or caught:
		return
	finished = true
	playing = false
	prompt.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound("door", -17)
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("complete_episode"):
		anthology.complete_episode("after_hours", ENDING)
	else:
		intro_title.text = "AFTER HOURS  /  END"
		intro_copy.text = ENDING
		begin_button.hide()
		overlay.show()


func _unhandled_input(event: InputEvent) -> void:
	if caught or finished:
		return
	if event.is_action_pressed("pause_game"):
		if playing:
			show_intro()
		else:
			begin_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact") and playing:
		if player.global_position.distance_to(EXIT) < 1.8:
			if power_on: finish_episode()
			else: door_locked()
		elif not power_on and not resetting and player.global_position.distance_to(BREAKER_STAND) < 1.6:
			reset_breaker()


func door_locked() -> void:
	sound("knock", -24)
	objective = BREAKER_STATUS
	status.text = objective
	if not lock_seen:
		lock_seen = true
		clue.show_clue("ล็อกแม่เหล็ก ไฟไม่เข้าเลย...\nต้องไปรีเซ็ตเบรกเกอร์ ตู้หลักน่าจะอยู่ห้องฝั่งล่างสุด")


# The lights die, the breaker clunks, then the building comes back on with her
# own voice on the speakers. The noise draws the spider to this room.
func reset_breaker() -> void:
	resetting = true
	sound("door", -14)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	t.tween_property(breaker_lever, "rotation:x", 0.6, 0.25)
	for lamp in lamps: lamp.visible = false
	breaker_led.visible = false
	await get_tree().create_timer(1.6, false).timeout
	for i in 3:
		for lamp in lamps: lamp.visible = true
		await get_tree().create_timer(0.08, false).timeout
		for lamp in lamps: lamp.visible = false
		await get_tree().create_timer(0.12 + i * 0.05, false).timeout
	for lamp in lamps: lamp.visible = true
	power_on = true
	resetting = false
	exit_glow.light_energy = 1.3
	exit_sign.modulate = Color(0.7, 1.0, 0.7)
	lock_light.visible = false
	lock_lamp.albedo_color = Color(0.15, 0.85, 0.35)
	lock_lamp.emission = Color(0.15, 0.85, 0.35)
	sound("fluorescent", -16)
	objective = RETURN_STATUS
	status.text = objective
	# The clunk carries: a patrolling spider heads for the breaker room.
	if is_instance_valid(spider) and not caught and spider.state_name() == "PATROL":
		spider.plan_path(BREAKER_STAND)
	await get_tree().create_timer(1.1, false).timeout
	if finished or caught: return
	story_beat = maxi(story_beat, 2)
	sound("message", -19)
	clue.show_clue("“รออยู่ตรงนั้นนะ เดี๋ยวฉันไปหา”\nนั่นเสียงฉันนี่... ใครเอาเสียงฉันไปเปิด")


func _process(delta: float) -> void:
	# Web: the browser eats Esc and drops pointer lock itself, so pause when capture is lost.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and was_captured and not captured:
		show_intro()
	was_captured = captured
	if not playing:
		prompt.text = ""
		return
	elapsed += delta
	if is_instance_valid(flicker_light) and not resetting:
		flicker_light.light_energy = 0.72 if sin(elapsed * 3.7) > -0.94 else 0.07
	if is_instance_valid(spider) and not caught:
		status.text = SPIDER_ALERT if spider.state_name() == "CHASE" else objective
		if spider.state_name() == "CHASE" and not chase_seen:
			chase_seen = true
			sound("low_pulse", -18)
	# Incidents are tied to places, not time, so a straight walk cannot skip them.
	if story_beat == 0 and is_instance_valid(player) and player.global_position.distance_to(SPAWN) > ANNOUNCE_DISTANCE:
		story_beat = 1
		sound("message", -23)
		clue.show_clue("“พนักงานที่ยังอยู่ในอาคาร กรุณากลับไปที่ห้องเก็บของ”\nให้กลับไปทำไม... ปกติต้องเรียกลงข้างล่างสิ")
	# After the power is back something knocks behind the wall beside her, but
	# only while she is walking. When she stops, it stops.
	if power_on and is_instance_valid(player):
		var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.6
		if moving:
			walk_clock += delta
			if walk_clock >= KNOCK_EVERY:
				walk_clock = 0.0
				knock_behind_wall()
		elif knocker.playing:
			knocker.stop()
	if is_instance_valid(player):
		var exit_distance := player.global_position.distance_to(EXIT)
		if exit_distance < 1.8:
			prompt.text = "[ E ]  ผลักประตูหนีไฟ" if power_on else "[ E ]  ประตูหนีไฟ  (ไม่มีไฟเข้า)"
		elif not power_on and not resetting and player.global_position.distance_to(BREAKER_STAND) < 1.6:
			prompt.text = "[ E ]  รีเซ็ตเบรกเกอร์"
		else:
			prompt.text = ""
		if exit_distance < 5.0 and not near_exit_seen:
			near_exit_seen = true
			sound("message", -21)
			clue.show_clue("บัตรใคร... อ้าว นี่บัตรฉัน\nมุมบิ่นตรงเดียวกันเลย แต่ของฉันยังคล้องคออยู่นี่")


func knock_behind_wall() -> void:
	# From her left or right side, a little behind: the other side of the wall.
	var side := 1.0 if randf() < 0.5 else -1.0
	var right: Vector3 = player.pivot.global_basis.x
	var back: Vector3 = player.pivot.global_basis.z
	knocker.global_position = player.global_position + right * side * 2.4 + back * 0.8 + Vector3.UP * 1.2
	knocker.pitch_scale = randf_range(0.85, 1.0)
	knocker.play()
	if not knock_seen:
		knock_seen = true
		story_beat = maxi(story_beat, 3)
		clue.show_clue("เสียงอะไรอยู่หลังผนัง ตามมาตั้งแต่เมื่อกี้แล้ว\nพอฉันหยุด... มันก็หยุด")
