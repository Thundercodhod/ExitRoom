extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const START_SIGN := Vector3(5.2, 0.0, -6.3)

var playing := false
var player: CharacterBody3D
var font: Font
var overlay: Control
var menu_title: Label
var menu_copy: Label
var prompt: Label
var wide_camera: Camera3D


func _ready() -> void:
	setup_inputs()
	font = ThemeDB.fallback_font
	wide_camera = $Camera
	wide_camera.look_at(Vector3(0, 2.1, 0), Vector3.UP)
	wide_camera.fov = 48.0
	setup_collisions()
	setup_start_sign()
	player = CharacterBody3D.new()
	player.name = "LobbyPlayerHazmatDemo"
	player.set_script(PlayerScript)
	player.game = self
	player.position = Vector3(2.0, 0.12, -4.8)
	add_child(player)
	player.pivot.rotation.y = 2.75
	player.body_visual.rotation.y = 2.75 - PI
	player.camera.current = false
	wide_camera.current = true
	setup_ui()
	if get_tree().root.has_meta("backrooms_complete"):
		get_tree().root.remove_meta("backrooms_complete")
		show_menu("ด่านแรกสำเร็จ", "คุณออกจาก Backrooms และกลับมาที่สวนแล้ว\nกดเริ่มด่าน 1 เพื่อเล่นอีกครั้ง หรือเดินเล่นใน lobby", true)
	else:
		show_menu("EXIT ROOM  /  GARDEN LOBBY", "สวนสำหรับรอเริ่มเกม\nเดินชมสวนและน้ำพุ หรือเริ่มด่านแรกใน Backrooms\n\nHazmat เป็นตัวละครชั่วคราวระหว่างรอโมเดลจริง", true)


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


func add_box_collider(name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.collision_layer = 1
	body.position = pos
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)


func setup_collisions() -> void:
	# The garden GLB is a decorative scene. These simple shapes give the lobby
	# a stable walking surface without adding collision to its dense fountain.
	add_box_collider("GardenWalkableGround", Vector3(0, -0.11, 0), Vector3(16.1, 0.2, 16.1))
	for x in [-8.1, 8.1]:
		add_box_collider("GardenBoundaryX", Vector3(x, 1.0, 0), Vector3(0.2, 2.0, 16.4))
	for z in [-8.1, 8.1]:
		add_box_collider("GardenBoundaryZ", Vector3(0, 1.0, z), Vector3(16.4, 2.0, 0.2))
	var fountain := StaticBody3D.new()
	fountain.name = "FountainBasinCollision"
	fountain.collision_layer = 1
	fountain.position = Vector3(0, 0.55, 0)
	add_child(fountain)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 2.96
	cylinder.height = 1.1
	shape.shape = cylinder
	fountain.add_child(shape)


func stone_material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


func add_marker_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> void:
	var object := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	object.mesh = mesh
	object.material_override = material
	object.position = pos
	parent.add_child(object)


func setup_start_sign() -> void:
	var sign_root := Node3D.new()
	sign_root.name = "StartLevelOneMarker"
	sign_root.position = START_SIGN
	add_child(sign_root)
	var wood := stone_material(Color(0.20, 0.16, 0.12))
	var gold := stone_material(Color(0.88, 0.64, 0.28), 0.6)
	add_marker_box(sign_root, Vector3(0, 1.05, 0), Vector3(1.35, 0.60, 0.10), wood)
	for x in [-0.57, 0.57]:
		add_marker_box(sign_root, Vector3(x, 0.49, 0), Vector3(0.08, 0.98, 0.10), wood)
	add_marker_box(sign_root, Vector3(0, 1.37, -0.06), Vector3(1.43, 0.05, 0.06), gold)
	var label := Label3D.new()
	label.text = "LEVEL 01\nBACKROOMS"
	label.font = font
	label.font_size = 32
	label.pixel_size = 0.0038
	label.modulate = Color(1.0, 0.86, 0.56)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 1.05, -0.12)
	sign_root.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.36)
	light.light_energy = 1.2
	light.omni_range = 4.0
	light.position = Vector3(0, 1.8, -0.5)
	sign_root.add_child(light)


func styled_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func setup_ui() -> void:
	var ui := CanvasLayer.new()
	ui.name = "LobbyHUD"
	add_child(ui)
	var header := styled_label("GARDEN LOBBY  /  EXIT ROOM", 19, Color(0.97, 0.91, 0.72))
	header.position = Vector2(26, 22)
	ui.add_child(header)
	prompt = styled_label("", 20, Color(1.0, 0.86, 0.51))
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-185, -76)
	ui.add_child(prompt)
	var hint := styled_label("WASD เดิน  •  เมาส์ หมุนกล้อง  •  E เริ่มด่าน  •  F ไฟฉาย  •  Esc เมนู", 15, Color(0.95, 0.92, 0.8))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -40)
	ui.add_child(hint)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.04, 0.69)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 26)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	menu_title = styled_label("", 34, Color(0.93, 0.88, 0.68))
	content.add_child(menu_title)
	menu_copy = styled_label("", 20, Color(0.92, 0.94, 0.90))
	content.add_child(menu_copy)
	var roam := Button.new()
	roam.text = "เดินเล่นในสวน  /  EXPLORE"
	roam.custom_minimum_size.y = 50
	roam.add_theme_font_override("font", font)
	roam.pressed.connect(begin_roaming)
	content.add_child(roam)
	var start := Button.new()
	start.text = "เริ่มด่าน 1  /  BACKROOMS"
	start.custom_minimum_size.y = 50
	start.add_theme_font_override("font", font)
	start.pressed.connect(start_level_one)
	content.add_child(start)
	roam.grab_focus.call_deferred()


func show_menu(title: String, copy: String, show_wide: bool) -> void:
	playing = false
	menu_title.text = title
	menu_copy.text = copy
	overlay.show()
	if show_wide:
		wide_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func begin_roaming() -> void:
	overlay.hide()
	wide_camera.current = false
	player.camera.current = true
	playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func start_level_one() -> void:
	playing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().root.set_meta("from_lobby", true)
	get_tree().change_scene_to_file("res://backrooms_level.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if playing:
			show_menu("GARDEN LOBBY", "พักที่สวนก่อนเริ่มด่านแรก", false)
		else:
			begin_roaming()
	if event.is_action_pressed("interact") and playing and player.global_position.distance_to(START_SIGN) < 2.2:
		start_level_one()


func _process(_delta: float) -> void:
	if is_instance_valid(player):
		prompt.text = "E  เริ่มด่าน 1 / BACKROOMS" if playing and player.global_position.distance_to(START_SIGN) < 2.2 else ""
