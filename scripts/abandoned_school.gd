extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const DIARY := Vector3(10.5, 0.86, -53.0)
const KEY := Vector3(-10.6, 0.86, -99.5)
const RADIO := Vector3(0, 1.48, -133.0)
const EXIT := Vector3(0, 0, -140.0)

var playing := false
var story_stage := 0
var player: CharacterBody3D
var font: Font
var objective: Label
var prompt: Label
var overlay: Control
var was_captured := false
var unreliable_lights: Array[OmniLight3D] = []
var atmosphere_clock := 0.0


func _ready() -> void:
	setup_inputs()
	font = load("res://NotoSansThai.ttf")
	font.fallbacks = [ThemeDB.fallback_font]
	player = CharacterBody3D.new()
	player.name = "SchoolPlayerHazmatDemo"
	player.set_script(PlayerScript)
	player.game = self
	player.position = Vector3(0, 0.12, 7.0)
	add_child(player)
	player.pivot.rotation.y = 0.0
	player.body_visual.rotation.y = -PI
	player.torch.visible = true
	var hall_lights := find_children("ColdHallLight_*", "OmniLight3D", true, false)
	for i in hall_lights.size():
		if i % 3 == 1:
			unreliable_lights.append(hall_lights[i] as OmniLight3D)
	setup_ui()
	update_story_visuals()
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


func label(words: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = words
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


func setup_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "SchoolHUD"
	add_child(hud)
	var chapter := label("ด่าน 02  /  โรงเรียนร้าง", 19, Color(0.75, 0.91, 0.96))
	chapter.position = Vector2(26, 20)
	hud.add_child(chapter)
	objective = label("", 21, Color(0.93, 0.95, 0.95))
	objective.position = Vector2(26, 52)
	hud.add_child(objective)
	prompt = label("", 20, Color(0.68, 1.0, 0.78))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-180, -80)
	hud.add_child(prompt)
	var hint := label("WASD เดิน  •  Space กระโดด  •  Shift วิ่ง  •  E สำรวจ  •  F ไฟฉาย  •  Esc เมนู", 15, Color(0.78, 0.88, 0.92))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -40)
	hud.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.05, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	content.add_child(label("โรงเรียนที่ไม่มีใครยกมือ", 35, Color(0.80, 0.94, 0.98)))
	content.add_child(label("เดินผ่านโถงยาวและห้องเรียนร้าง\nค้นสมุดของเมย์ แล้วเปิดคำให้การผ่านห้องประกาศ\n\nฉากนี้เป็นต้นแบบ low-poly สำหรับวางโมเดลและกิจกรรมเพิ่ม", 21, Color(0.90, 0.94, 0.95)))
	var begin := Button.new()
	begin.text = "เข้าโรงเรียน  /  BEGIN"
	begin.custom_minimum_size.y = 52
	begin.add_theme_font_override("font", font)
	begin.pressed.connect(begin_game)
	content.add_child(begin)
	begin.grab_focus.call_deferred()


func show_intro() -> void:
	playing = false
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_game() -> void:
	overlay.hide()
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update_story_visuals() -> void:
	$"02_ClassroomsAndClues/MaysDiary".visible = story_stage == 0
	$"02_ClassroomsAndClues/ArchiveKey".visible = story_stage == 1
	$"03_AnnouncementRoomAndExit/ExitToGarden/GreenExitLight".visible = story_stage == 3
	$"03_AnnouncementRoomAndExit/ExitToGarden/ExitGlow".visible = story_stage == 3
	match story_stage:
		0: objective.text = "หาสมุดของเมย์ในห้องเรียนฝั่งขวา"
		1: objective.text = "ตามหากุญแจห้องประกาศในห้องเรียนฝั่งซ้าย"
		2: objective.text = "ไปที่ห้องประกาศท้ายโถง แล้วเปิดเครื่องเสียง"
		3: objective.text = "คำให้การถูกเปิดแล้ว เดินออกทางประตูสีเขียว"


func interaction_position() -> Vector3:
	match story_stage:
		0: return DIARY
		1: return KEY
		2: return RADIO
		_: return EXIT


func interact() -> void:
	if not playing or player.global_position.distance_to(interaction_position()) > 2.6:
		return
	match story_stage:
		0:
			story_stage = 1
		1:
			story_stage = 2
		2:
			story_stage = 3
		3:
			playing = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().root.set_meta("school_complete", true)
			get_tree().change_scene_to_file("res://main.tscn")
			return
	update_story_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if playing:
			show_intro()
		else:
			begin_game()
	if event.is_action_pressed("interact"):
		interact()


func _process(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and was_captured and not captured:
		show_intro()
	was_captured = captured
	atmosphere_clock += delta
	for i in unreliable_lights.size():
		var pulse := sin(atmosphere_clock * 2.1 + float(i) * 3.7)
		unreliable_lights[i].light_energy = 0.08 if pulse < -0.92 else 0.56
	if not is_instance_valid(player):
		return
	if playing and player.global_position.distance_to(interaction_position()) < 2.6:
		match story_stage:
			0: prompt.text = "E  อ่านสมุดของเมย์"
			1: prompt.text = "E  เก็บกุญแจห้องประกาศ"
			2: prompt.text = "E  เปิดคำให้การผ่านลำโพง"
			_: prompt.text = "E  กลับไปยังสวน"
	else:
		prompt.text = ""
