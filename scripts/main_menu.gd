extends Node3D
const Style = preload("res://scripts/anthology_style.gd")
var page := "home"
var selected := 0
var stage: Control
var pages := {}
var episode_buttons: Array[Button] = []
var preview: TextureRect
var preview_title: Label
var hook: Label
var summary: Label
var tag: Label
var start_button: Button
var camera: Camera3D
var film: ShaderMaterial
var elapsed := 0.0
var ambient: AudioStreamPlayer
var loading := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	build_backdrop()
	var ui := CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	stage = Control.new()
	stage.name = "MenuCanvas"
	stage.size = Vector2(1280,720)
	ui.add_child(stage)
	for key in ["home","episodes","options","credits"]:
		var content := Control.new()
		content.name = key.capitalize()+"Page"
		content.size = Vector2(1280,720)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(content)
		pages[key] = content
	build_home()
	build_episodes()
	build_options()
	build_credits()
	for i in Anthology.EPISODES.size():
		if Anthology.EPISODES[i].id==Anthology.selected_id: selected = i
	select_episode(selected,false)
	show_page(Anthology.menu_page)
	Anthology.menu_page = "home"
	ambient = AudioStreamPlayer.new()
	var loop := load("res://audio/anthology/menu_ambience.wav") as AudioStreamWAV
	ambient.stream = loop
	ambient.bus = &"Ambience"
	ambient.volume_db = -19
	add_child(ambient)
	ambient.finished.connect(ambient.play)
	ambient.play()

func build_backdrop() -> void:
	var world := (load("res://frog_field_world.tscn") as PackedScene).instantiate()
	world.name = "MenuBackdrop"
	add_child(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var environment: Environment = world.get_node("Night").environment.duplicate()
	world.get_node("Night").environment = environment
	environment.fog_density = .025
	environment.ambient_light_energy = .65
	camera = Camera3D.new()
	camera.fov = 62
	camera.position = Vector3(7.5,1.85,-22.5)
	add_child(camera)
	camera.look_at(Vector3(-.5,1.8,-34))
	camera.current = true
	# Existing vegetation silhouettes frame the photographed space, without
	# changing either the authored episode scene or the source tree model.
	for data in [[Vector3(-9,0,-32),.6],[Vector3(9,0,-38),.8],[Vector3(-11,0,-43),.9]]:
		var tree := (load("res://tree/dead_tree.glb") as PackedScene).instantiate() as Node3D
		tree.position = data[0]
		tree.scale = Vector3.ONE*float(data[1])
		add_child(tree)
	var post := CanvasLayer.new()
	post.layer = 1
	add_child(post)
	var image := ColorRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film = ShaderMaterial.new()
	film.shader = load("res://ui/menu_film.gdshader")
	image.material = film
	post.add_child(image)

func place(parent: Node, node: Control, pos: Vector2, size := Vector2.ZERO) -> Control:
	node.position = pos
	if size!=Vector2.ZERO: node.size = size
	parent.add_child(node)
	return node

func text(parent: Node, words: String, pos: Vector2, size: int, color := Style.INK, bold := false) -> Label:
	var n := Style.label(words,size,color,bold)
	place(parent,n,pos)
	return n

func line(parent: Node, pos: Vector2, width: float, color := Color(.55,.6,.56,.3)) -> void:
	var n := ColorRect.new()
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(parent,n,pos,Vector2(width,1))

func button(parent: Node, words: String, pos: Vector2, size: Vector2, action: Callable, font_size := 23) -> Button:
	var b := Style.button(words,font_size)
	place(parent,b,pos,size)
	b.pressed.connect(func(): Anthology.play_sfx("ui_accept",-21); action.call())
	b.mouse_entered.connect(func(): Anthology.play_sfx("ui_move",-29))
	b.focus_entered.connect(func(): Anthology.play_sfx("ui_move",-29))
	return b

func build_home() -> void:
	var root: Control = pages.home
	text(root,"INDEPENDENT TALES OF PSYCHOLOGICAL HORROR",Vector2(68,57),15,Style.MUTED)
	text(root,"VOL. 01    /    ภาษาไทย",Vector2(1004,57),15,Style.MUTED)
	line(root,Vector2(68,94),1144)
	text(root,"SOME PLACES KEEP A PART OF YOU.",Vector2(70,226),19,Style.GOLD)
	var shadow := text(root,"EXITROOM",Vector2(65,254),100,Color(.24,.075,.09),true)
	shadow.add_theme_constant_override("outline_size",1)
	text(root,"EXITROOM",Vector2(61,250),100,Style.INK,true)
	text(root,"ประตูปิดแล้ว\nแต่บางอย่างยังตามออกมา",Vector2(72,377),25,Style.INK)
	text(root,"4 เรื่องเล่า  ·  4 คืนที่ไม่มีใครอยากกลับไป",Vector2(72,469),17,Style.MUTED)
	var first := button(root,"01   เลือกเรื่อง",Vector2(884,272),Vector2(326,61),func(): show_page("episodes"),27)
	first.name = "EpisodesButton"
	button(root,"02   ตั้งค่า",Vector2(884,344),Vector2(326,61),func(): show_page("options"),27)
	button(root,"03   เครดิต",Vector2(884,416),Vector2(326,61),func(): show_page("credits"),27)
	button(root,"04   ออกจากเกม",Vector2(884,488),Vector2(326,61),func(): get_tree().quit(),27)
	line(root,Vector2(68,630),1144)
	text(root,"AN ANTHOLOGY OF QUIET HORRORS",Vector2(68,649),16,Style.MUTED)
	text(root,"หูฟังช่วยให้ได้ยินสิ่งที่อยู่พ้นสายตา",Vector2(840,649),16,Style.MUTED)

func header(root: Control, title: String, sub: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(.009,.016,.019,.85)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(root,dim,Vector2.ZERO,Vector2(1280,720))
	text(root,title,Vector2(64,36),44,Style.INK,true)
	text(root,sub,Vector2(66,97),17,Style.MUTED)
	button(root,"← เมนูหลัก",Vector2(1036,47),Vector2(180,49),func(): show_page("home"),19)
	line(root,Vector2(64,134),1152)

func build_episodes() -> void:
	var root: Control = pages.episodes
	header(root,"EPISODES","เลือกเรื่องใดก่อนก็ได้ · ตัวละครและเหตุการณ์ของแต่ละตอนไม่ต่อกัน")
	for i in Anthology.EPISODES.size():
		var data: Dictionary = Anthology.EPISODES[i]
		var b := button(root,"",Vector2(64,160+i*111),Vector2(412,96),func(): select_episode(i),20)
		b.name = "Episode"+data.number
		text(b,data.number,Vector2(18,10),24,Style.ACCENT,true)
		text(b,data.title,Vector2(64,14),23,Style.INK,true)
		text(b,data.thai,Vector2(64,51),19,Style.MUTED)
		episode_buttons.append(b)
	preview = TextureRect.new()
	preview.name = "EpisodePreview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	place(root,preview,Vector2(512,160),Vector2(704,230))
	var shade := ColorRect.new()
	shade.color = Color(.01,.01,.01,.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(root,shade,Vector2(512,160),Vector2(704,230))
	preview_title = text(root,"",Vector2(536,320),31,Color.WHITE,true)
	preview_title.add_theme_constant_override("outline_size",5)
	preview_title.add_theme_color_override("font_outline_color",Color.BLACK)
	tag = text(root,"",Vector2(514,401),15,Style.GOLD)
	hook = text(root,"",Vector2(512,430),25,Style.INK,true)
	hook.size = Vector2(704,75)
	summary = text(root,"",Vector2(512,516),18,Style.MUTED)
	summary.size = Vector2(704,86)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	start_button = button(root,"เริ่มเรื่อง  →",Vector2(512,621),Vector2(704,52),play_selected,23)
	start_button.name = "StartEpisodeButton"
	text(root,"เล่นใหม่เริ่มจากต้นตอน\nบันทึกเฉพาะตอนที่เล่นจบและการตั้งค่า",Vector2(67,623),16,Style.MUTED)

func select_episode(index: int, sound := true) -> void:
	selected = clampi(index,0,Anthology.EPISODES.size()-1)
	var entry: Dictionary = Anthology.EPISODES[selected]
	Anthology.selected_id = entry.id
	var path: String = "res://ui/previews/"+entry.id+".png"
	if ResourceLoader.exists(path): preview.texture = load(path)
	else: preview.texture = null
	preview_title.text = entry.title+"   /   "+entry.number
	tag.text = entry.tag
	hook.text = entry.hook
	summary.text = entry.summary
	start_button.text = ("เล่นอีกครั้ง" if Anthology.completed.has(entry.id) else "เริ่มเรื่อง")+"   /   EPISODE "+entry.number+"  →"
	for i in episode_buttons.size():
		var b := episode_buttons[i]
		b.add_theme_stylebox_override("normal",Style.panel(Color(.14,.065,.07,.95) if i==selected else Color(.021,.033,.035,.92),Style.ACCENT if i==selected else Color(.3,.36,.34,.35)))
	if sound: Anthology.play_sfx("ui_move",-25)

func play_selected() -> void:
	if loading: return
	loading = true
	start_button.text = "กำลังเปิดเรื่อง..."
	start_button.disabled = true
	Anthology.launch_episode(Anthology.EPISODES[selected].id)

func reset_start_button() -> void:
	loading = false
	start_button.disabled = false
	select_episode(selected,false)

func build_options() -> void:
	var root: Control = pages.options
	header(root,"OPTIONS","ปรับเสียงและการแสดงผลให้เล่นได้สบาย · บันทึกอัตโนมัติ")
	text(root,"AUDIO",Vector2(220,170),22,Style.GOLD,true)
	var row := 215
	for data in [["เสียงทั้งหมด","master"],["เสียงบรรยากาศ","ambience"],["เสียงประกอบ","sfx"]]:
		text(root,data[0],Vector2(220,row+3),22)
		var slider := HSlider.new()
		slider.name = data[1]+"Slider"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = float(Anthology.settings[data[1]])*100
		place(root,slider,Vector2(560,row),Vector2(390,36))
		var value := text(root,str(int(slider.value))+"%",Vector2(980,row+3),20,Style.MUTED)
		slider.value_changed.connect(func(v):
			Anthology.settings[data[1]] = v/100.0
			value.text = str(int(v))+"%"
			Anthology.apply_preferences()
			Anthology.save_preferences())
		row += 62
	line(root,Vector2(220,418),825)
	text(root,"DISPLAY & READING",Vector2(220,446),22,Style.GOLD,true)
	row = 493
	for data in [["เต็มหน้าจอ","fullscreen"],["ลดการเคลื่อนไหวของกล้อง","reduced_motion"],["แสดงบทพูดทันที (ปิดการพิมพ์ทีละตัว)","instant_text"]]:
		var check := CheckButton.new()
		check.name = data[1]+"Toggle"
		check.text = data[0]
		check.add_theme_font_override("font",Style.font())
		check.add_theme_font_size_override("font_size",21)
		check.button_pressed = Anthology.settings[data[1]]
		place(root,check,Vector2(220,row),Vector2(825,43))
		if data[1]=="fullscreen":
			check.button_pressed = Anthology.is_fullscreen() if DisplayServer.get_name()!="headless" else false
			check.toggled.connect(func(v):
				check.disabled = true
				await Anthology.set_fullscreen(v)
				check.set_pressed_no_signal(Anthology.is_fullscreen())
				check.disabled = false)
			Anthology.display_mode_changed.connect(func(enabled,_message): check.set_pressed_no_signal(enabled))
		else:
			check.toggled.connect(func(v): Anthology.settings[data[1]] = v; Anthology.apply_preferences(); Anthology.save_preferences())
		row += 52
	var display_hint := text(root,Anthology.display_message,Vector2(225,663),15,Style.MUTED)
	Anthology.display_mode_changed.connect(func(_enabled,message): display_hint.text = message)

func build_credits() -> void:
	var root: Control = pages.credits
	header(root,"CREDITS","EXITROOM · เรื่องสั้นสยองขวัญ 4 ตอน")
	var scroll := ScrollContainer.new()
	place(root,scroll,Vector2(190,163),Vector2(900,495))
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation",19)
	scroll.add_child(stack)
	for data in [
		["THE STORIES","THE LAST VISIT · AFTER HOURS · ROOM 407 · THE PASSENGER\nเรื่องแต่งแนวจิตวิทยาสยองขวัญ แต่ละตอนเล่นได้อย่างอิสระ"],
		["ART & CHARACTERS","โมเดลกบและระบบตัวละครจากทีมผู้สร้างโปรเจกต์\nห้องและเฟอร์นิเจอร์: Vicious Potato Studios · กล่อง: PomidorkaStudios\nLow-poly Furnished Abandoned House: NeoKG (CC BY 4.0)\nพื้นผิว: Poly Haven · Godot Grass Shader: Binbun (CC0)"],
		["TYPE & SOUND","Chakra Petch: Cadson Demak · VT323: Peter Hull (SIL OFL)\nเสียงบรรยากาศและเอฟเฟกต์เพิ่มเติม: สังเคราะห์ขึ้นสำหรับ ExitRoom\nเสียงและสินทรัพย์เดิม: ดู ASSET_CREDITS.md และ Room407/ASSET_CREDITS.md"],
		["THANK YOU FOR PLAYING","ขอบคุณที่เล่น ExitRoom\nกลับมาเลือกเรื่องอื่นได้จากเมนูหลัก"]]:
		stack.add_child(Style.label(data[0],23,Style.GOLD,true))
		var copy := Style.label(data[1],20)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.custom_minimum_size.x = 850
		stack.add_child(copy)

func show_page(key: String) -> void:
	if not pages.has(key): return
	page = key
	for item in pages: pages[item].visible = item==key
	if key=="episodes":
		select_episode(selected,false)
		episode_buttons[selected].grab_focus()
	elif key=="home":
		pages.home.get_node("EpisodesButton").grab_focus()
	else:
		for child in pages[key].get_children():
			if child is Button: child.grab_focus(); break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE: show_page("home")

func _process(delta: float) -> void:
	if not stage: return
	var view := get_viewport().get_visible_rect().size
	var factor := minf(view.x/1280.0,view.y/720.0)
	stage.scale = Vector2.ONE*factor
	stage.position = (view-Vector2(1280,720)*factor)*.5
	film.set_shader_parameter("reduced_motion",Anthology.settings.reduced_motion)
	if not Anthology.settings.reduced_motion:
		elapsed += delta
		camera.position.x = 7.5+sin(elapsed*.12)*.08
		camera.look_at(Vector3(-.5,1.8,-34))
