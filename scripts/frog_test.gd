extends Node3D
# Sandbox for the Frog: open frog_test.tscn and press F6.
# The player is the normal player (WASD / Shift / mouse / F flashlight / V camera).
# Number keys change the frog's rules, the HUD shows what it is doing.

const PlayerScript = preload("res://scripts/player.gd")
const FrogScript = preload("res://scripts/frog_watcher.gd")

const ARENA := Rect2(-18, -18, 36, 36)
const PLAYER_START := Vector3(0, 0.1, 9)
const FROG_START := Vector3(0, 0.05, -9)

var playing := false
var player: CharacterBody3D
var frog: CharacterBody3D
var font: Font
var info: Label
var help: Label
var pause_label: Label
var was_captured := false
var message := ""
var message_time := 0.0
var vanish_rule := false
var relocate_count := 0


func _ready() -> void:
	setup_inputs()
	font = load("res://NotoSansThai.ttf") as Font
	if font == null:
		font = ThemeDB.fallback_font
	else:
		font.fallbacks = [ThemeDB.fallback_font]
	setup_environment()
	setup_arena()
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.game = self
	player.position = PLAYER_START
	add_child(player)
	spawn_frog()
	setup_ui()
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


func setup_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.04, 0.07)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.8)
	environment.ambient_light_energy = 0.35
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.04, 0.05, 0.09)
	environment.fog_density = 0.012
	world.environment = environment
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, 35, 0)
	moon.light_color = Color(0.7, 0.78, 1.0)
	moon.light_energy = 0.5
	add_child(moon)


func solid_box(box_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)


func setup_arena() -> void:
	# Floor with a 2 m grid so distances are easy to judge.
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0, -0.25, 0)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(ARENA.size.x, 0.5, ARENA.size.y)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color(0.16, 0.17, 0.2))
	image.set_pixel(1, 1, Color(0.16, 0.17, 0.2))
	image.set_pixel(1, 0, Color(0.11, 0.12, 0.14))
	image.set_pixel(0, 1, Color(0.11, 0.12, 0.14))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(ARENA.size.x / 2.0, ARENA.size.y / 2.0, 1)
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = ARENA.size
	plane.mesh = plane_mesh
	plane.material_override = material
	add_child(plane)
	# Obstacles to walk around and to hide behind.
	var stone := Color(0.3, 0.3, 0.34)
	solid_box("WallA", Vector3(-3.5, 1.25, -2), Vector3(7, 2.5, 0.5), stone)
	solid_box("WallB", Vector3(6, 1.25, -5), Vector3(0.5, 2.5, 6), stone)
	solid_box("Pillar", Vector3(2, 1.5, 3), Vector3(1, 3, 1), stone)
	# Boundary and 5 m markers along the middle line.
	for z in range(-15, 16, 5):
		solid_box("Marker%d" % z, Vector3(-8, 0.5, z), Vector3(0.2, 1, 0.2), Color(0.8, 0.7, 0.2))


func spawn_frog() -> void:
	frog = CharacterBody3D.new()
	frog.name = "Frog"
	frog.set_script(FrogScript)
	frog.game = self
	frog.target = player
	frog.bounds = ARENA
	frog.position = FROG_START
	add_child(frog)
	frog.face_towards(player.global_position)
	frog.vanished.connect(_on_frog_vanished)
	frog.relocated.connect(func(p): flash("Frog jumped to %s" % [p.snapped(Vector3(0.1, 0.1, 0.1))]))
	frog.settled.connect(func(): flash("Frog settled at %.1f m" % frog.distance_to_target()))


func setup_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	info = styled_label(15, Color(0.85, 0.95, 0.85))
	info.position = Vector2(16, 12)
	hud.add_child(info)
	help = styled_label(14, Color(0.9, 0.85, 0.7))
	help.text = "WASD เดิน  Shift วิ่ง  F ไฟฉาย  V สลับมุมกล้อง  Esc หยุด/เล่นต่อ\n1 เดินเข้าหา on/off   2 หายเมื่อถูกมอง   3 ย้ายเข้ามา 4 ม. ตอนไม่ได้มอง   4 นั่ง/ยืน\n5 รีเซ็ตกบ   6 หันหัวตาม on/off   7 หันทั้งตัว on/off   - / = ระยะยืนดู ลด/เพิ่ม"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16
	help.offset_top = -78
	hud.add_child(help)
	pause_label = styled_label(34, Color(1, 1, 1))
	pause_label.text = "หยุดอยู่ — กด Esc เล่นต่อ"
	pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_label.hide()
	hud.add_child(pause_label)


func styled_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	return label


func flash(text: String) -> void:
	message = text
	message_time = 4.0


func begin_game() -> void:
	playing = true
	pause_label.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pause_game() -> void:
	playing = false
	pause_label.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_frog_vanished() -> void:
	flash("Frog vanished (it was looked at)")
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(frog) or frog.mode != frog.Mode.GONE:
		return
	# Reappear at a random spot 10 to 14 m away, then arm the rule again.
	var angle := randf() * TAU
	var point := player.global_position + Vector3(sin(angle), 0, cos(angle)) * randf_range(10.0, 14.0)
	point.x = clampf(point.x, ARENA.position.x + 2, ARENA.end.x - 2)
	point.z = clampf(point.z, ARENA.position.y + 2, ARENA.end.y - 2)
	point.y = 0.05
	frog.appear_at(point)
	frog.face_towards(player.global_position)
	if vanish_rule:
		frog.vanish_when_seen_within(10.0, 0.3)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if playing:
			pause_game()
		else:
			begin_game()
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_1:
			frog.approach_enabled = not frog.approach_enabled
			flash("Approach: %s" % ("on" if frog.approach_enabled else "off"))
		KEY_2:
			vanish_rule = not vanish_rule
			if vanish_rule:
				frog.vanish_when_seen_within(10.0, 0.3)
			else:
				frog.clear_scene_rules()
			flash("Vanish when looked at within 10 m: %s" % ("on" if vanish_rule else "off"))
		KEY_3:
			var toward := player.global_position - frog.global_position
			toward.y = 0.0
			if toward.length() > 6.0:
				var point := frog.global_position + toward.normalized() * 4.0
				point.y = frog.global_position.y
				frog.relocate_when_unseen(point, 0.4)
				flash("Queued a 4 m jump toward you (%d pending). Look away from the frog." % frog.pending_relocations())
			else:
				flash("Too close to queue a jump")
		KEY_4:
			if frog.mode == frog.Mode.SITTING:
				frog.stand()
				flash("Frog stands")
			else:
				frog.sit()
				flash("Frog sits")
		KEY_5:
			frog.clear_scene_rules()
			vanish_rule = false
			frog.approach_enabled = true
			frog.head_tracking = true
			frog.turn_body = true
			frog.appear_at(FROG_START)
			frog.face_towards(player.global_position)
			player.global_position = PLAYER_START
			player.velocity = Vector3.ZERO
			player.pivot.rotation.y = 0.0
			flash("Reset")
		KEY_6:
			frog.head_tracking = not frog.head_tracking
			flash("Head tracking: %s" % ("on" if frog.head_tracking else "off"))
		KEY_7:
			frog.turn_body = not frog.turn_body
			flash("Turn body toward player: %s" % ("on" if frog.turn_body else "off"))
		KEY_MINUS:
			frog.keep_distance = maxf(1.5, frog.keep_distance - 0.5)
			flash("Viewing distance %.1f m" % frog.keep_distance)
		KEY_EQUAL:
			frog.keep_distance = minf(10.0, frog.keep_distance + 0.5)
			flash("Viewing distance %.1f m" % frog.keep_distance)


func _process(delta: float) -> void:
	# Pause when the mouse is released (web builds lose capture instead of Esc).
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if playing and was_captured and not captured:
		pause_game()
	was_captured = captured
	if message_time > 0.0:
		message_time -= delta
	if not is_instance_valid(frog) or not is_instance_valid(player):
		return
	var speed_scale := 0.0
	if frog.player_animation:
		speed_scale = frog.player_animation.speed_scale
	info.text = "Frog   distance %.1f m (stands at %.1f)   %s / %s\nanimation %s x%.2f   mode %s\nseen by you: %s   head error %.0f deg   approach %s   head tracking %s   turn body %s\n%s" % [
		frog.distance_to_target(), frog.keep_distance, frog.Move.keys()[frog.move_state], "walking" if frog.velocity.length() > 0.12 else "still",
		String(frog.current_anim), speed_scale, frog.Mode.keys()[frog.mode],
		"YES" if frog.is_seen() else "no", rad_to_deg(frog.head_error()),
		"on" if frog.approach_enabled else "off", "on" if frog.head_tracking else "off", "on" if frog.turn_body else "off",
		message if message_time > 0.0 else ""]
