extends Label
## Readable clue text, separate from the next objective.

var remaining := 0.0
var reveal_clock := 0.0
var plate: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 125
	offset_right = -125
	offset_top = -190
	offset_bottom = -82
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_override("font", load("res://ui/fonts/ChakraPetch-Regular.ttf"))
	add_theme_font_size_override("font_size", 23)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", Color(0.86, 0.93, 0.92))
	add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	add_theme_constant_override("outline_size", 3)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate = ColorRect.new()
	plate.color = Color(.01,.015,.015,.88)
	plate.show_behind_parent = true
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.offset_left = -18
	plate.offset_right = 18
	add_child(plate)
	plate.hide()

func show_clue(words: String) -> void:
	text = words
	visible_characters = 0
	reveal_clock = 0
	remaining = maxf(18.0,float(words.length())/38.0+9.0)
	plate.show()

func _process(delta: float) -> void:
	# Do not consume reading time while a menu is open.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	remaining = maxf(0.0, remaining - delta)
	reveal_clock += delta
	var settings := get_node_or_null("/root/Anthology")
	visible_characters = -1 if settings and settings.settings.instant_text else int(reveal_clock*38.0)
	if remaining == 0.0:
		text = ""
		plate.hide()
