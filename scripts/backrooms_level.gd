extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const SPAWN := Vector3(9.5, 0.12, -9.5)
const EXIT := Vector3(-10.5, 0.0, 10.5)

var playing := false
var was_captured := false
var player: CharacterBody3D
var font: Font
var overlay: Control
var prompt: Label
var status: Label
var flicker_light: OmniLight3D
var elapsed := 0.0
var ambience: AudioStreamPlayer


func _ready() -> void:
	setup_inputs()
	# Bundled Thai font: web builds have no OS fonts to fall back on.
	font = load("res://NotoSansThai.ttf")
	font.fallbacks = [ThemeDB.fallback_font]
	setup_environment()
	setup_collisions()
	setup_lights()
	setup_exit()
	player = CharacterBody3D.new()
	player.name = "PlayerHazmatDemo"
	player.set_script(PlayerScript)
	player.game = self
	player.position = SPAWN
	add_child(player)
	player.pivot.rotation.y = 2.35
	player.body_visual.rotation.y = 2.35 - PI
	setup_audio()
	setup_ui()
	if get_tree().root.has_meta("from_lobby"):
		get_tree().root.remove_meta("from_lobby")
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
	environment.background_color = Color(0.19, 0.18, 0.11)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.76, 0.54)
	environment.ambient_light_energy = 1.05
	world.environment = environment
	add_child(world)


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
			lamp.light_energy = 2.1
			lamp.omni_range = 7.0
			lamp.shadow_enabled = false
			add_child(lamp)
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
	sign.text = "EXIT"
	sign.font = font
	sign.font_size = 48
	sign.pixel_size = 0.005
	sign.modulate = Color(0.7, 1.0, 0.7)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 2.3, 0.45)
	exit_root.add_child(sign)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.36, 1.0, 0.58)
	glow.light_energy = 1.3
	glow.omni_range = 4.5
	glow.position = Vector3(0, 1.5, 0.3)
	exit_root.add_child(glow)


func setup_audio() -> void:
	ambience = AudioStreamPlayer.new()
	ambience.stream = load("res://audio/drone.wav")
	ambience.volume_db = -22
	add_child(ambience)
	ambience.play()


func styled_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func setup_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "BackroomsHUD"
	add_child(ui)
	var top := MarginContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", 26)
	top.add_theme_constant_override("margin_top", 20)
	top.add_theme_constant_override("margin_right", 26)
	ui.add_child(top)
	var header := VBoxContainer.new()
	top.add_child(header)
	header.add_child(styled_label("LEVEL 01  /  THE BACKROOMS", 18, Color(0.95, 0.9, 0.61)))
	status = styled_label("หาทางออกที่มีไฟสีเขียว", 20, Color(0.96, 0.95, 0.83))
	header.add_child(status)
	prompt = styled_label("", 20, Color(0.6, 1.0, 0.69))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-170, -80)
	ui.add_child(prompt)
	var hint := styled_label("WASD เดิน  •  เมาส์ หมุนกล้อง  •  Shift วิ่ง  •  F ไฟฉาย  •  Esc พัก", 15, Color(0.82, 0.8, 0.62))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -40)
	ui.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.045, 0.03, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	content.add_child(styled_label("THE BACKROOMS", 36, Color(0.95, 0.9, 0.59)))
	content.add_child(styled_label("ด่านแรก  •  คุณหลงอยู่ในห้องสีเหลืองที่ไม่มีทางออกชัดเจน\nเดินสำรวจและมองหาแสงสีเขียวเพื่อออกจาก Backrooms\n\nHazmat เป็นตัวละครชั่วคราวระหว่างรอโมเดลตัวจริง", 20, Color(0.92, 0.91, 0.82)))
	var begin := Button.new()
	begin.text = "เริ่มด่าน  /  BEGIN"
	begin.custom_minimum_size.y = 50
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if playing:
			show_intro()
		else:
			begin_game()
	if event.is_action_pressed("interact") and playing and player.global_position.distance_to(EXIT) < 1.8:
		playing = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().root.set_meta("backrooms_complete", true)
		get_tree().change_scene_to_file("res://main.tscn")


func _process(delta: float) -> void:
	# Web: the browser eats Esc and drops pointer lock itself, so pause when capture is lost.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and was_captured and not captured:
		show_intro()
	was_captured = captured
	elapsed += delta
	if is_instance_valid(flicker_light):
		flicker_light.light_energy = 2.1 + (0.55 if sin(elapsed * 17.0) > 0.96 else 0.0)
	if is_instance_valid(player):
		prompt.text = "E  ออกจาก Backrooms / กลับสวน" if player.global_position.distance_to(EXIT) < 1.8 and playing else ""
