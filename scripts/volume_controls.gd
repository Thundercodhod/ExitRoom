extends GridContainer
## Compact volume sliders for the pause screens. Reads and writes the same
## settings as the menu's Options page (saved to user://anthology.cfg), so a
## change made mid-episode is still there in the menu and the next episode.

const ROWS := [["เสียงทั้งหมด","master","Master"],["เสียงบรรยากาศ","ambience","Ambience"],["เพลง","music","Music"],["เสียงประกอบ","sfx","SFX"]]

var font: Font
var font_size := 18
var ink := Color(.84,.85,.79)
var accent := Color(.80,.76,.52)
var slider_width := 300.0
var sliders := {}
var readouts := {}

func _init() -> void:
	name = "VolumeControls"
	columns = 3
	process_mode = Node.PROCESS_MODE_ALWAYS   # pause screens run with the tree paused
	add_theme_constant_override("h_separation",18)
	add_theme_constant_override("v_separation",4)

func _ready() -> void:
	for row in ROWS:
		var key: String = row[1]
		add_child(_label(row[0]))
		var slider := HSlider.new()
		slider.name = key+"Slider"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size = Vector2(slider_width,30)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style(slider)
		add_child(slider)
		var readout := _label("")
		readout.custom_minimum_size.x = 56
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(readout)
		sliders[key] = slider
		readouts[key] = readout
		slider.value_changed.connect(func(v: float):
			set_volume(key,v/100.0)
			readout.text = str(int(v))+"%")
	refresh()

## Pulls the current values back in (call when the pause screen opens).
func refresh() -> void:
	for row in ROWS:
		var key: String = row[1]
		if not sliders.has(key): continue
		var v := roundf(volume(key)*100.0)
		sliders[key].set_value_no_signal(v)
		readouts[key].text = str(int(v))+"%"

func volume(key: String) -> float:
	var anthology := _anthology(key)
	if anthology: return clampf(float(anthology.settings[key]),0.0,1.0)
	var bus := AudioServer.get_bus_index(_bus(key))
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus)),0.0,1.0) if bus>=0 else 1.0

func set_volume(key: String, value: float) -> void:
	var anthology := _anthology(key)
	if anthology:
		anthology.settings[key] = value
		anthology.apply_preferences()
		anthology.save_preferences()
		return
	var bus := AudioServer.get_bus_index(_bus(key))   # scene run on its own, no anthology
	if bus>=0: AudioServer.set_bus_volume_db(bus,linear_to_db(value))

# The anthology manager, if it is running and keeps this setting.
func _anthology(key: String) -> Node:
	var anthology := get_node_or_null("/root/Anthology")
	if anthology and anthology.get("settings") is Dictionary and anthology.settings.has(key) \
			and anthology.has_method("apply_preferences") and anthology.has_method("save_preferences"):
		return anthology
	return null

func _bus(key: String) -> String:
	for row in ROWS:
		if row[1]==key: return row[2]
	return "Master"

func _label(words: String) -> Label:
	var l := Label.new()
	l.text = words
	if font: l.add_theme_font_override("font",font)
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",ink)
	return l

func _style(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1,1,1,.14)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	track.set_corner_radius_all(2)
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = Color(accent,.85)
	var hot := track.duplicate() as StyleBoxFlat
	hot.bg_color = accent.lightened(.25)
	slider.add_theme_stylebox_override("slider",track)
	slider.add_theme_stylebox_override("grabber_area",filled)
	slider.add_theme_stylebox_override("grabber_area_highlight",hot)
