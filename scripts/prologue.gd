extends Node3D
## Standalone episode. The authored village and its props remain intact.

const PlayerScript = preload("res://scripts/player.gd")
const CASSETTE := Vector3(21.8, 0.99, -148.6)
const MARBLE := Vector3(35.0, 0.3, -154.0)
const BACK_DOOR := Vector3(23.0, 0.0, -169.5)
const ENDING := "ผมกลับถึงรถก็รีบโทรหาภรรยา บอกว่าอย่าเพิ่งเปิดประตูให้ใคร\nเธอเงียบไป แล้วถามว่า “จะให้เปิดทำไม ก็เข้ามาแล้วนี่”\n\nผมบอกให้เธอเข้าห้องนอน ล็อกประตู แล้วโทรหาตำรวจ\nเธอไม่ยอมวางสาย บอกว่าคนที่โต๊ะกินข้าวกำลังมองมาทางเธอ\n\nจนวันนี้เธอก็ยังยืนยันว่าคนคนนั้นเป็นผม\nแต่ผมจำได้ว่าตอนนั้น มือผมยังเปื้อนดินจากหลังบ้านอยู่เลย"

var playing := false
var story_stage := 0
var player: CharacterBody3D
var prompt: Label
var objective: Label
var overlay: Control
var intro_title: Label
var intro_copy: Label
var continue_button: Button
var font: Font
var title_font: Font
var was_captured := false
var wavering_lamp: OmniLight3D
var atmosphere_clock := 0.0
var clue: Label
var started := false
var finished := false
var approach_seen := false
var last_stage_time := 0.0
var knock_played := false


func _ready() -> void:
	setup_inputs()
	font = load("res://ui/fonts/ChakraPetch-Regular.ttf") as Font
	title_font = load("res://ui/fonts/ChakraPetch-Bold.ttf") as Font
	if font == null:
		font = load("res://NotoSansThai.ttf") as Font
	if title_font == null:
		title_font = font
	player = CharacterBody3D.new()
	player.name = "LastVisitPlayer"
	player.set_script(PlayerScript)
	player.game = self
	player.position = Vector3(0, 0.12, 6.0)
	add_child(player)
	player.set_third_person(false)
	player.pivot.rotation.y = 0.0
	player.body_visual.rotation.y = -PI
	player.torch.visible = true
	player.torch.light_energy = 1.7
	var street_lamps := find_children("PoolOfWarmLight", "OmniLight3D", true, false)
	if street_lamps.size() > 1:
		wavering_lamp = street_lamps[1] as OmniLight3D
	setup_ui()
	$"04_StoryObjectsAndExit/CassetteInteraction/CassetteText".text = "เทปที่เปิดค้างไว้"
	$"04_StoryObjectsAndExit/CassetteInteraction/CassetteText".font = font
	$"04_StoryObjectsAndExit/DoorToBackrooms/FaintMessage".text = "อย่าออกประตูหน้า"
	$"04_StoryObjectsAndExit/DoorToBackrooms/FaintMessage".font = font
	update_story_visuals()
	show_intro()
	if "--preview-house" in OS.get_cmdline_user_args():
		player.position = Vector3(24, 0.10, -134.5)
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
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	result.add_theme_constant_override("shadow_offset_y", 2)
	return result


func make_button(words: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size.y = 50
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 20)
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.06, 0.09, 0.09, 0.95)
	base.border_width_left = 2
	base.border_color = Color(0.44, 0.51, 0.46)
	base.content_margin_left = 20
	button.add_theme_stylebox_override("normal", base)
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.20, 0.19)
	hover.border_color = Color(0.84, 0.79, 0.58)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.pressed.connect(callback)
	button.mouse_entered.connect(func(): sound("ui_move", -25))
	return button


func setup_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "LastVisitHUD"
	hud.layer = 5
	add_child(hud)
	var chapter := styled_label("01   /   THE LAST VISIT", 17, Color(0.83, 0.78, 0.61))
	chapter.position = Vector2(32, 24)
	hud.add_child(chapter)
	objective = styled_label("", 21, Color(0.93, 0.93, 0.85))
	objective.position = Vector2(32, 52)
	hud.add_child(objective)
	clue = Label.new()
	clue.set_script(preload("res://scripts/story_caption.gd"))
	hud.add_child(clue)
	prompt = styled_label("", 22, Color(0.91, 0.85, 0.64))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-210, -232)
	prompt.size.x = 420
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(prompt)
	var hint := styled_label("WASD เดิน   /   SHIFT วิ่ง   /   E สำรวจ   /   F ไฟฉาย   /   ESC พัก   /   F1 เมนู", 14, Color(0.66, 0.71, 0.68))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(32, -32)
	hud.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.015, 0.025, 0.025, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.045, 0.042, 0.96)
	panel_style.border_width_top = 2
	panel_style.border_color = Color(0.59, 0.57, 0.41)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 38)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	content.add_child(styled_label("EXITROOM   /   EPISODE 01", 16, Color(0.58, 0.67, 0.63)))
	intro_title = styled_label("", 40, Color(0.92, 0.86, 0.66))
	intro_title.add_theme_font_override("font", title_font)
	content.add_child(intro_title)
	intro_copy = styled_label("", 21, Color(0.82, 0.86, 0.81))
	intro_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_copy.custom_minimum_size.x = 704
	content.add_child(intro_copy)
	continue_button = make_button("เข้าบ้าน  /  BEGIN EPISODE", begin_game)
	content.add_child(continue_button)
	content.add_child(make_button("กลับหน้าเลือกตอน  /  EPISODES", return_to_menu))
	continue_button.grab_focus.call_deferred()


func show_intro() -> void:
	playing = false
	intro_title.text = "THE LAST VISIT  /  บ้านที่ยังรอ"
	if started:
		intro_copy.text = "พักเกมอยู่\n\nกดเล่นต่อเมื่อพร้อม"
		continue_button.text = "เดินต่อ  /  RESUME"
	else:
		intro_copy.text = "ผมชื่อธาม รับงานซ่อมไฟกับเพื่อนแถวบ้าน\n\nเย็นวันนั้นเพื่อนฝากให้ไปเช็กบ้านที่กำลังจะขาย\nผมต้องรอปิดร้านก่อน กว่าจะไปถึงก็เกือบเที่ยงคืน\nเจ้าของย้ายออกไปสามเดือนแล้ว แต่ยังมีของเหลืออยู่\n\nเขาบอกให้เช็กไฟ ล็อกประตู แล้วเอากุญแจมาคืน\nผมกะว่าไม่เกินครึ่งชั่วโมงก็น่าจะเสร็จ"
	overlay.show()
	continue_button.grab_focus.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_game() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if not started and anthology and anthology.has_method("reveal_gameplay"):
		await anthology.reveal_gameplay(_begin_game)
	else:
		_begin_game()

func _begin_game() -> void:
	if finished:
		return_to_menu()
		return
	overlay.hide()
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	was_captured = true
	sound("ui_accept", -24)
	if not started:
		started = true
		clue.show_clue("23:48 น.\nไฟเปิดอยู่แฮะ ไหนเพื่อนบอกว่าบ้านนี้ไม่มีใครอยู่แล้ว")


func update_story_visuals() -> void:
	var cassette := $"04_StoryObjectsAndExit/CassetteInteraction"
	var marble := $"04_StoryObjectsAndExit/BlueMarbleInteraction"
	var gate := $"04_StoryObjectsAndExit/DoorToBackrooms"
	cassette.visible = true
	# The same ordinary prop moves, making a small discrepancy tangible.
	marble.visible = story_stage < 2
	marble.global_position = CASSETTE + Vector3(0.40, 0.08, 0.0) if story_stage == 0 else MARBLE
	gate.get_node("StrangeLight").visible = story_stage == 2
	gate.get_node("BackDoorGlow").visible = story_stage == 2
	gate.get_node("FaintMessage").visible = story_stage == 2
	match story_stage:
		0: objective.text = "ตรวจบ้านหลังสุดถนน  /  สำรวจเทปบนโต๊ะ"
		1: objective.text = "ตามเสียงกลิ้งไปหลังบ้าน  /  หาลูกแก้วสีน้ำเงิน"
		2: objective.text = "ออกจากบ้านทางประตูหลัง"


func interaction_position() -> Vector3:
	match story_stage:
		0: return CASSETTE
		1: return MARBLE
		_: return BACK_DOOR


func interact() -> void:
	if not playing or player.global_position.distance_to(interaction_position()) > 2.5:
		return
	match story_stage:
		0:
			story_stage = 1
			sound("tape", -17)
			clue.show_clue("“อย่าออกประตูหน้า ผมลองแล้ว ออกทางหลังบ้าน”\nเสียงในเทปเหมือนผมมาก ขนาดเสียงกระแอมยังเหมือน\nเดี๋ยวนะ ลูกแก้วที่วางอยู่ข้างเครื่องเล่นเมื่อกี้หายไปไหน")
		1:
			story_stage = 2
			sound("message", -19)
			clue.show_clue("ลูกเมื่อกี้จริง ๆ ด้วย มันมาอยู่ตรงนี้ได้ยังไง\n00:17 — ภรรยา: “ถึงบ้านแล้วเหรอ ทำไมไม่ทักกันเลย”\nผมยังอยู่นี่ แล้วเธอเห็นใครเข้าบ้าน")
		2:
			finish_episode()
			return
	last_stage_time = atmosphere_clock
	knock_played = false
	update_story_visuals()


func finish_episode() -> void:
	finished = true
	playing = false
	prompt.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound("door", -16)
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("complete_episode"):
		anthology.complete_episode("last_visit", ENDING)
	else:
		intro_title.text = "THE LAST VISIT  /  END"
		intro_copy.text = ENDING
		continue_button.text = "กลับหน้าเลือกตอน  /  EPISODES"
		overlay.show()


func sound(key: String, volume: float = -20.0) -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("play_sfx"):
		anthology.play_sfx(key, volume)


func return_to_menu() -> void:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology != null and anthology.has_method("return_to_menu"):
		anthology.return_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if event.is_action_pressed("pause_game"):
		if playing:
			show_intro()
		else:
			begin_game()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		interact()


func _process(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and was_captured and not captured:
		show_intro()
	was_captured = captured
	if not playing or not is_instance_valid(player):
		prompt.text = ""
		return
	atmosphere_clock += delta
	if is_instance_valid(wavering_lamp):
		wavering_lamp.light_energy = 0.10 if sin(atmosphere_clock * 2.4) < -0.95 else 0.62
	if not approach_seen and player.global_position.distance_to(CASSETTE) < 22.0:
		approach_seen = true
		sound("knock", -24)
		clue.show_clue("ใครเคาะอยู่ข้างในหรือเปล่า\nผมตะโกนบอกว่ามาเช็กไฟ แต่ไม่มีใครตอบ")
	if story_stage > 0 and not knock_played and atmosphere_clock - last_stage_time > 8.0:
		knock_played = true
		sound("knock" if story_stage == 1 else "low_pulse", -20)
		# Sounds only: don't overwrite the clue while the player is reading it.
	if player.global_position.distance_to(interaction_position()) < 2.5:
		match story_stage:
			0: prompt.text = "[ E ]  เปิดเทป"
			1: prompt.text = "[ E ]  เก็บลูกแก้ว"
			_: prompt.text = "[ E ]  เปิดประตูหลังบ้าน"
	else:
		prompt.text = ""
