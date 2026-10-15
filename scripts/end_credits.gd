extends CanvasLayer
## End roll shown after waking at the cat in Level 06. The field stays dimly
## visible behind it and the music keeps playing. Hold Space/E/click to speed up,
## Esc to skip. Emits `finished` once the last line has left (or on skip).
signal finished

const Style = preload("res://scripts/anthology_style.gd")
const Credits = preload("res://scripts/credits_data.gd")
const DURATION := 75.0      # seconds at normal speed
const FAST := 4.0
const WIDTH := 900.0

var roll: VBoxContainer
var hint: Label
var speed := 0.0
var done := false
var elapsed := 0.0

func _ready() -> void:
	layer = 8
	roll = VBoxContainer.new()
	roll.name = "Roll"
	roll.add_theme_constant_override("separation", 10)
	roll.custom_minimum_size.x = WIDTH
	add_child(roll)
	build()
	hint = Style.label("กดค้าง SPACE / E / คลิก เพื่อเร่ง   ·   ESC ข้าม", 15, Color(1,1,1,.45))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -460
	hint.offset_right = -34
	hint.offset_top = -46
	hint.offset_bottom = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)
	await get_tree().process_frame
	var screen := get_viewport().get_visible_rect().size
	roll.position = Vector2((screen.x - WIDTH) / 2.0, screen.y)
	speed = (roll.size.y + screen.y) / DURATION

func line(words: String, size: int, color := Style.INK, bold := false) -> Label:
	var item := Style.label(words, size, color, bold)
	item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.custom_minimum_size.x = WIDTH
	item.add_theme_color_override("font_outline_color", Color(.03,.025,.02,.85))
	item.add_theme_constant_override("outline_size", 5)
	roll.add_child(item)
	return item

func gap(height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	roll.add_child(space)

func section(heading: String, body: String) -> void:
	line(heading, 20, Style.GOLD, true)
	line(body, 22)
	gap(46)

func build() -> void:
	line("EXITROOM", 64, Style.INK, true)
	line(Credits.CLOSING_LINE, 24, Color("e0c9a5"))
	gap(120)
	section("สร้างโดย", Credits.team_text())
	section("รายวิชา", Credits.COURSE)
	section("อาจารย์ประจำวิชา", Credits.ADVISOR+"\n"+Credits.SCHOOL)
	section("เรื่องเล่าทั้งหมด", "\n".join(Credits.episode_lines()))
	for data in Credits.SECTIONS:
		section(data[0], "\n".join(data[1]))
	section("เครื่องมือ", "Made with Godot Engine")
	var license := line(Engine.get_license_text(), 13, Color(1,1,1,.45))
	license.name = "GodotLicense"
	gap(160)
	line(Credits.THANKS, 30, Style.INK, true)
	gap(40)

func holding() -> bool:
	return Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _process(delta: float) -> void:
	if done or speed <= 0.0: return
	elapsed += delta
	roll.position.y -= speed * delta * (FAST if holding() else 1.0)
	hint.modulate.a = 1.0 - smoothstep(6.0, 9.0, elapsed)
	if roll.position.y + roll.size.y < get_viewport().get_visible_rect().size.y * .45:
		finish()

func _unhandled_input(event: InputEvent) -> void:
	if done: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		finish()

func finish() -> void:
	if done: return
	done = true
	finished.emit()
