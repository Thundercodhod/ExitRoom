extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const CASSETTE := Vector3(21.8, 0.99, -148.6)
const MARBLE := Vector3(35.0, 0.3, -154.0)
const GARDEN_GATE := Vector3(23.0, 0.0, -169.5)

var playing := false
var story_stage := 0
var player: CharacterBody3D
var prompt: Label
var objective: Label
var overlay: Control
var intro_title: Label
var intro_copy: Label
var font: Font
var was_captured := false
var wavering_lamp: OmniLight3D
var atmosphere_clock := 0.0


func _ready() -> void:
	setup_inputs()
	font = load("res://NotoSansThai.ttf") as Font
	if font == null:
		font = ThemeDB.fallback_font
	else:
		font.fallbacks = [ThemeDB.fallback_font]
	player = CharacterBody3D.new()
	player.name = "ProloguePlayerHazmatDemo"
	player.set_script(PlayerScript)
	player.game = self
	player.position = Vector3(0, 0.12, 6.0)
	add_child(player)
	player.pivot.rotation.y = 0.0
	player.body_visual.rotation.y = -PI
	player.torch.visible = true
	player.torch.light_energy = 1.7
	var street_lamps := find_children("PoolOfWarmLight", "OmniLight3D", true, false)
	if street_lamps.size() > 1:
		wavering_lamp = street_lamps[1] as OmniLight3D
	setup_ui()
	update_story_visuals()
	show_intro()
	if "--preview-house" in OS.get_cmdline_user_args():
		player.position=Vector3(24,0.10,-134.5)
		begin_game()


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


func styled_label(words: String, size: int, tint: Color) -> Label:
	var result := Label.new()
	result.text = words
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", tint)
	return result


func setup_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "PrologueHUD"
	add_child(hud)
	var chapter := styled_label("บทนำ  /  ทางกลับบ้าน", 19, Color(0.98, 0.88, 0.68))
	chapter.position = Vector2(26, 20)
	hud.add_child(chapter)
	objective = styled_label("เดินตามถนนไปบ้านยาย", 21, Color(0.98, 0.95, 0.84))
	objective.position = Vector2(26, 52)
	hud.add_child(objective)
	prompt = styled_label("", 20, Color(0.59, 0.96, 0.89))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-170, -80)
	hud.add_child(prompt)
	var hint := styled_label("WASD เดิน  •  Space กระโดด  •  Shift วิ่ง  •  E สำรวจ  •  F ไฟฉาย  •  Esc เมนู", 15, Color(0.94, 0.90, 0.78))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -40)
	hud.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.04, 0.79)
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
	intro_title = styled_label("", 35, Color(0.98, 0.88, 0.67))
	content.add_child(intro_title)
	intro_copy = styled_label("", 21, Color(0.92, 0.94, 0.91))
	content.add_child(intro_copy)
	var continue_button := Button.new()
	continue_button.text = "เดินต่อ  /  CONTINUE"
	continue_button.custom_minimum_size.y = 52
	continue_button.add_theme_font_override("font", font)
	continue_button.pressed.connect(begin_game)
	content.add_child(continue_button)
	continue_button.grab_focus.call_deferred()


func show_intro() -> void:
	playing = false
	intro_title.text = "EXITROOM  /  ทางกลับบ้าน"
	intro_copy.text = "นนท์กลับบ้านต่างจังหวัดหลังยายเสีย\nเดินจากป้ายรถไปที่บ้าน เก็บเทปของยาย แล้วตามเสียงน้ำพุ\n\nHazmat ยังเป็นโมเดลผู้เล่นชั่วคราว"
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_game() -> void:
	overlay.hide()
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func update_story_visuals() -> void:
	var cassette := $"04_StoryObjectsAndExit/CassetteInteraction"
	var marble := $"04_StoryObjectsAndExit/BlueMarbleInteraction"
	var gate := $"04_StoryObjectsAndExit/PortalToGardenLobby"
	cassette.visible = story_stage == 0
	marble.visible = story_stage == 1
	gate.get_node("StrangeLight").visible = story_stage == 2
	gate.get_node("GardenGlow").visible = story_stage == 2
	gate.get_node("FaintMessage").visible = story_stage == 2
	match story_stage:
		0: objective.text = "เดินตามถนนไปบ้านยาย แล้วหาเทปบนโต๊ะ"
		1: objective.text = "เสียงน้ำพุดังจากหลังบ้าน หาลูกแก้วสีน้ำเงิน"
		2: objective.text = "เดินตามทางหลังบ้านไปยังประตูที่มีแสง"


func interaction_position() -> Vector3:
	match story_stage:
		0: return CASSETTE
		1: return MARBLE
		_: return GARDEN_GATE


func interact() -> void:
	if not playing or player.global_position.distance_to(interaction_position()) > 2.5:
		return
	match story_stage:
		0:
			story_stage = 1
			objective.text = "ยายพูดในเทป: ถ้าได้ยินเสียงจากที่ที่ไม่มีคน อย่าเพิ่งตอบ"
		1:
			story_stage = 2
			objective.text = "ลูกแก้วสีน้ำเงินเย็นจัด เสียงน้ำพุอยู่หลังบ้าน"
		2:
			playing = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().root.set_meta("from_prologue", true)
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
	if is_instance_valid(wavering_lamp):
		wavering_lamp.light_energy = 0.16 if sin(atmosphere_clock * 2.4) < -0.95 else 0.72
	if not is_instance_valid(player):
		return
	if playing and player.global_position.distance_to(interaction_position()) < 2.5:
		match story_stage:
			0: prompt.text = "E  ฟังเทปของยาย"
			1: prompt.text = "E  เก็บลูกแก้วสีน้ำเงิน"
			_: prompt.text = "E  ตามเสียงน้ำพุไปยังสวน"
	else:
		prompt.text = ""
