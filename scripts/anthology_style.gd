extends RefCounted
## Shared original typography and palette for the anthology.
const INK := Color("e5e1d6")
const MUTED := Color("949d99")
const ACCENT := Color("d75055")
const GOLD := Color("cbbd83")

static func font(bold := false) -> Font:
	return load("res://ui/fonts/ChakraPetch-Bold.ttf" if bold else "res://ui/fonts/ChakraPetch-Regular.ttf")

static func label(words: String, size: int, color := INK, bold := false) -> Label:
	var n := Label.new()
	n.text = words
	n.add_theme_font_override("font",font(bold))
	n.add_theme_font_size_override("font_size",size)
	n.add_theme_color_override("font_color",color)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return n

static func panel(color := Color(.023,.033,.034,.94), border := Color(.3,.36,.34,.35)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s

static func button(words: String, size := 22) -> Button:
	var b := Button.new()
	b.text = words
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",font(true))
	b.add_theme_font_size_override("font_size",size)
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",Color.WHITE)
	b.add_theme_color_override("font_focus_color",Color.WHITE)
	b.add_theme_stylebox_override("normal",panel(Color(.02,.03,.031,.75)))
	b.add_theme_stylebox_override("hover",panel(Color(.17,.075,.08,.95),ACCENT))
	b.add_theme_stylebox_override("focus",panel(Color(.11,.065,.07,.8),GOLD))
	b.add_theme_stylebox_override("pressed",panel(Color(.28,.09,.1,.98),ACCENT))
	b.custom_minimum_size.y = 52
	return b
