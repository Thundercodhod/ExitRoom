extends Node
signal display_mode_changed(enabled: bool, message: String)
signal transition_finished
## Episode selection, saved preferences and completion; no mid-episode checkpoint.
const Style = preload("res://scripts/anthology_style.gd")
const MENU := "res://main_menu.tscn"
const EPISODES := [
	{"id":"last_visit","number":"01","title":"THE LAST VISIT","thai":"บ้านที่ยังรอ","scene":"res://prologue_village.tscn","tag":"ธาม / งานซ่อมไฟ / 23:48 น.","hook":"เพื่อนฝากให้แวะไปเช็กไฟ\nผมกะว่าแป๊บเดียวก็เสร็จ","summary":"ธามรับงานตรวจบ้านก่อนขายหลังปิดร้าน เจ้าของย้ายออกไปหลายเดือนแล้ว แต่พอเขาไปถึง ไฟในบ้านกลับเปิดอยู่ และมีเสียงคนเคาะประตูจากข้างใน"},
	{"id":"after_hours","number":"02","title":"AFTER HOURS","thai":"กะสุดท้าย","scene":"res://backrooms_level.tscn","tag":"ริน / ช่างซ่อมบำรุง / 22:06 น.","hook":"ฉันเข้าไปเพราะนึกว่ามีคนติดอยู่\nตอนนั้นยังห่วงว่าเขาจะกลับบ้านยังไง","summary":"รินมารับกะดึกแทนเพื่อนที่ลาป่วย ก่อนเลิกงานเธอได้ยินคนเรียกจากห้องเก็บของ จึงหยิบไฟฉายเข้าไปดู พอจะเดินกลับ ทางเดินที่คุ้นเคยกลับไม่พาเธอไปที่เดิม"},
	{"id":"room407","number":"03","title":"ROOM 407","thai":"ห้องที่ไม่มีใครเช่า","scene":"res://Room407/main.tscn","tag":"ธีร์ / ห้องเช่าชั่วคราว / เจ็ดคืน","hook":"ห้องเก่าท่อน้ำแตก ผมเลยต้องย้ายมาอยู่ชั่วคราว\nคืนแรกก็มีข้อความจากคนที่ผมไม่รู้จัก","summary":"ธีร์เช่าห้องใกล้ที่ทำงานระหว่างรอช่างซ่อมท่อน้ำ เขาขนมาแค่เสื้อผ้ากับนาฬิกาปลุก แต่คนห้องข้าง ๆ กลับรู้ทั้งชื่อและเวลาที่เขาตื่น"},
	{"id":"passenger","number":"04","title":"THE PASSENGER","thai":"ผู้โดยสาร","scene":"res://frog_chapter.tscn","tag":"ภาคิน / ทางเลียบทุ่ง / 23:46 น.","hook":"ถนนใหญ่ปิดซ่อม ผมเลยอ้อมมาทางนี้\nขับอยู่ดี ๆ รถก็ดับ","summary":"ภาคินกำลังขับรถกลับหลังเก็บของออกจากห้องเช่าของพ่อ รถเสียบนถนนเลียบทุ่งที่ไม่มีสัญญาณโทรศัพท์ เขาจึงเดินไปขอความช่วยเหลือที่บ้านหลังเดียวซึ่งยังเปิดไฟอยู่"}
]
var settings := {"master":.8,"ambience":.7,"sfx":.85,"fullscreen":false,"reduced_motion":false,"instant_text":false}
var completed: Array[String] = []
var selected_id := "last_visit"
var menu_page := "home"
var modal: CanvasLayer
var modal_kind := ""
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var previous_pause := false
var changing := false
var display_busy := false
var display_message := "F11 หรือ Alt + Enter เพื่อสลับเต็มหน้าจอ"
var windowed_size := Vector2i(1280,720)
var windowed_position := Vector2i.ZERO
var windowed_mode := DisplayServer.WINDOW_MODE_WINDOWED
var transition_layer: CanvasLayer
var curtain: ColorRect
var transition_title: Label
var transition_gain := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for title in ["Ambience","SFX"]:
		if AudioServer.get_bus_index(title)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,title)
	load_preferences()
	apply_preferences()
	# Browsers require a direct click/key gesture for entering fullscreen.
	if OS.has_feature("web"):
		settings.fullscreen = is_fullscreen()
		display_message = "กดสวิตช์เต็มหน้าจอ หรือ Alt + Enter · Esc เพื่อออก"
	else:
		set_fullscreen.call_deferred(bool(settings.fullscreen))
	get_tree().node_added.connect(_node_added)
	get_tree().scene_changed.connect(_scene_changed)

func episode(id: String) -> Dictionary:
	for entry in EPISODES:
		if entry.id==id: return entry
	return EPISODES[0]

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://anthology.cfg")!=OK: return
	for key in settings:
		var value: Variant = config.get_value("settings",key,settings[key])
		if typeof(value)==typeof(settings[key]): settings[key] = value
	for id in config.get_value("progress","completed",[]):
		if id is String and not completed.has(id): completed.append(id)
	selected_id = config.get_value("progress","selected","last_visit")

func save_preferences() -> void:
	var config := ConfigFile.new()
	for key in settings: config.set_value("settings",key,settings[key])
	config.set_value("progress","completed",completed)
	config.set_value("progress","selected",selected_id)
	config.save("user://anthology.cfg")

func apply_preferences() -> void:
	for pair in [["Master","master"],["Ambience","ambience"],["SFX","sfx"]]:
		var volume := clampf(float(settings[pair[1]]),0.0,1.0)
		if pair[0]=="Master": volume *= transition_gain
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(volume))
	var scene := get_tree().current_scene
	if scene: apply_accessibility(scene)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func _process(_delta: float) -> void:
	# Esc can exit browser fullscreen without going through our settings toggle.
	if OS.has_feature("web") and not display_busy:
		var actual := is_fullscreen()
		if actual!=bool(settings.fullscreen):
			settings.fullscreen = actual
			save_preferences()
			display_mode_changed.emit(actual,display_message)

func set_fullscreen(enabled: bool) -> void:
	if display_busy or DisplayServer.get_name()=="headless": return
	display_busy = true
	var was_fullscreen := is_fullscreen()
	if enabled!=was_fullscreen:
		if enabled:
			windowed_size = DisplayServer.window_get_size()
			windowed_position = DisplayServer.window_get_position()
			windowed_mode = DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			if not OS.has_feature("web"):
				DisplayServer.window_set_size(windowed_size)
				DisplayServer.window_set_position(windowed_position)
				if windowed_mode==DisplayServer.WINDOW_MODE_MAXIMIZED:
					DisplayServer.window_set_mode(windowed_mode)
	# The OS applies this asynchronously. Persist what actually happened.
	for i in 3: await get_tree().process_frame
	settings.fullscreen = is_fullscreen()
	display_message = "F11 หรือ Alt + Enter เพื่อสลับเต็มหน้าจอ"
	if OS.has_feature("web"):
		display_message = "กดสวิตช์เต็มหน้าจอ หรือ Alt + Enter · Esc เพื่อออก"
	if bool(settings.fullscreen)!=enabled:
		display_message = "คลิกสวิตช์อีกครั้งเพื่ออนุญาตเต็มหน้าจอ" if OS.has_feature("web") else "หากเล่นใน Godot ให้ปิด Embed Game on Next Play หรือเปิดเกมด้วย Play.cmd"
	save_preferences()
	display_busy = false
	display_mode_changed.emit(bool(settings.fullscreen),display_message)

func _build_transition() -> void:
	if transition_layer: return
	transition_layer = CanvasLayer.new()
	transition_layer.name = "SceneTransition"
	transition_layer.layer = 120
	transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(transition_layer)
	curtain = ColorRect.new()
	curtain.color = Color(0,0,0,0)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.add_child(curtain)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.add_child(center)
	transition_title = Style.label("",30,Style.INK,true)
	transition_title.modulate.a = 0
	transition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(transition_title)
	transition_layer.hide()

func _set_transition_gain(value: float) -> void:
	transition_gain = value
	AudioServer.set_bus_volume_db(0,linear_to_db(float(settings.master)*value))

func _fade(opaque: bool, heading := "") -> void:
	_build_transition()
	transition_layer.show()
	transition_title.text = heading
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	var duration := .22 if settings.reduced_motion else .45
	tween.tween_property(curtain,"color:a",1.0 if opaque else 0.0,duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(transition_title,"modulate:a",1.0 if opaque else 0.0,duration)
	tween.tween_method(_set_transition_gain,transition_gain,0.0 if opaque else 1.0,duration)
	await tween.finished
	if not opaque: transition_layer.hide()

func reveal_gameplay(action: Callable) -> void:
	if changing: return
	changing = true
	get_tree().paused = true
	await _fade(true)
	if action.is_valid(): action.call()
	await get_tree().create_timer(.12).timeout
	await _fade(false)
	get_tree().paused = false
	changing = false
	transition_finished.emit()

func _change_episode_scene(path: String, heading: String) -> void:
	if changing: return
	changing = true
	var old_pause := get_tree().paused
	var old_mouse := Input.mouse_mode
	get_tree().paused = true
	await _fade(true,heading)
	# Let the black frame reach the screen before loading or freeing a scene.
	await get_tree().process_frame
	var error := get_tree().change_scene_to_file(path)
	if error!=OK:
		await _fade(false)
		get_tree().paused = old_pause
		Input.mouse_mode = old_mouse
		changing = false
		var retry_scene := get_tree().current_scene
		if retry_scene and retry_scene.has_method("reset_start_button"): retry_scene.reset_start_button()
		transition_finished.emit()
		return
	await get_tree().scene_changed
	close_modal(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(.25).timeout
	await _fade(false,heading)
	get_tree().paused = false
	changing = false
	transition_finished.emit()

func apply_accessibility(scene: Node) -> void:
	var p := scene.get_node_or_null("Player")
	if p and "reduced_motion" in p: p.reduced_motion = settings.reduced_motion

func _node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		configure_audio.call_deferred(node)

func configure_audio(node: Node) -> void:
	if not is_instance_valid(node): return
	var path := String(node.stream.resource_path).to_lower() if node.stream else ""
	var ambient := path.contains("drone") or path.contains("field") or path.contains("ambience") or path.contains("fluorescent")
	if node.bus==&"Master": node.bus = &"Ambience" if ambient else &"SFX"

func _scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene:
		apply_accessibility(scene)
		if OS.has_feature("web"):
			# Keep the authored field intact; limit only what the browser draws.
			for grass in scene.find_children("Grass_*","MultiMeshInstance3D",true,false):
				grass.multimesh = grass.multimesh.duplicate()
				grass.multimesh.visible_instance_count = mini(grass.multimesh.instance_count,96)
				grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				grass.visibility_range_end = 36.0

func play_sfx(key: String, volume_db := -18.0) -> void:
	var path := "res://audio/anthology/"+key+".wav"
	if not ResourceLoader.exists(path): return
	var sound := AudioStreamPlayer.new()
	sound.stream = load(path)
	sound.bus = &"SFX"
	sound.volume_db = volume_db
	add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()

func launch_episode(id: String) -> void:
	if changing: return
	selected_id = episode(id).id
	save_preferences()
	var entry := episode(selected_id)
	await _change_episode_scene(entry.scene,"EPISODE "+entry.number+"\n"+entry.title)

func return_to_menu() -> void:
	if changing: return
	menu_page = "episodes"
	await _change_episode_scene(MENU,"")

func _input(event: InputEvent) -> void:
	if changing:
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_F11 or (event.keycode==KEY_ENTER and event.alt_pressed):
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()
		return
	if modal and modal_kind=="pause" and event.keycode in [KEY_ESCAPE,KEY_F1]:
		close_modal()
		get_viewport().set_input_as_handled()
	elif event.keycode==KEY_F1 and modal==null and get_tree().current_scene and get_tree().current_scene.scene_file_path!=MENU:
		show_pause()
		get_viewport().set_input_as_handled()

func make_modal(title: String, body: String) -> VBoxContainer:
	previous_mouse = Input.mouse_mode
	previous_pause = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal = CanvasLayer.new()
	modal.name = "EpisodeOverlay"
	modal.layer = 100
	modal.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(.009,.015,.016,.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size.x = 790
	card.add_theme_stylebox_override("panel",Style.panel(Color(.025,.03,.032,.96)))
	center.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",20)
	card.add_child(stack)
	stack.add_child(Style.label("EXITROOM  /  AN ANTHOLOGY OF QUIET HORRORS",15,Style.ACCENT,true))
	stack.add_child(Style.label(title,36,Style.INK,true))
	var copy := Style.label(body,23)
	copy.custom_minimum_size.x = 740
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(copy)
	return stack

func complete_episode(id: String, narrative: String) -> void:
	if modal_kind=="ending" or changing: return
	changing = true
	get_tree().paused = true
	await _fade(true)
	_present_ending(id,narrative)
	await get_tree().create_timer(.2).timeout
	await _fade(false)
	changing = false
	transition_finished.emit()

func _present_ending(id: String, narrative: String) -> void:
	close_modal(false)
	selected_id = id
	if not completed.has(id): completed.append(id)
	save_preferences()
	var entry := episode(id)
	var stack := make_modal("EPISODE "+entry.number+" — "+entry.title,narrative)
	modal_kind = "ending"
	stack.add_child(Style.label("จบเรื่อง  /  END OF RECORDING",17,Style.GOLD))
	var menu := Style.button("กลับไปเลือก Episode  →")
	menu.name = "EpisodeMenuButton"
	menu.pressed.connect(return_to_menu)
	stack.add_child(menu)
	var replay := Style.button("เล่นเรื่องนี้อีกครั้ง",19)
	replay.pressed.connect(func(): launch_episode(id))
	stack.add_child(replay)
	menu.grab_focus()

func show_pause() -> void:
	var stack := make_modal("พักเกม","กลับไปหน้าเลือกเรื่องได้ทุกเมื่อ\nเมื่อเริ่มเล่นใหม่ เรื่องนั้นจะเริ่มจากต้นตอน")
	modal_kind = "pause"
	var resume := Style.button("เล่นต่อ")
	resume.pressed.connect(close_modal)
	stack.add_child(resume)
	var menu := Style.button("กลับไปเลือก Episode",19)
	menu.pressed.connect(return_to_menu)
	stack.add_child(menu)
	resume.grab_focus()

func close_modal(restore := true) -> void:
	if modal:
		modal.queue_free()
		modal = null
		if restore:
			get_tree().paused = previous_pause
			Input.mouse_mode = previous_mouse
	modal_kind = ""
