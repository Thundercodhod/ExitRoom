extends Label
## Readable clue text, separate from the next objective.

var remaining := 0.0

func _ready() -> void:
	position = Vector2(26, 92)
	size = Vector2(900, 150)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_theme_font_override("font", load("res://NotoSansThai.ttf"))
	add_theme_font_size_override("font_size", 21)
	add_theme_color_override("font_color", Color(0.86, 0.93, 0.92))
	add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.04))
	add_theme_constant_override("outline_size", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_clue(words: String) -> void:
	text = words
	remaining = 18.0

func _process(delta: float) -> void:
	# Do not consume reading time while a menu is open.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining == 0.0:
		text = ""
