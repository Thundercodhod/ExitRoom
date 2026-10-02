extends Node3D

@onready var player = $Player
@export_range(0.5, 4.0, 0.1) var hall_figure_vanish_distance := 1.8
var hall_figure_vanished := false
var stage := 0
var busy := false
var started := false
var paused := false
var door_busy := false
var overlay: ColorRect
var ui: CanvasLayer
var title_screen: Control
var pause_screen: Control
var objective: Label
var subtitle: Label
var prompt: Label
var chapter: Label
var shade: ColorRect
var effect: ShaderMaterial
var subtitle_id := 0
var drone: AudioStreamPlayer
var scrape: AudioStreamPlayer3D
var ending_screen: Control

const OBJECTIVES := [
	"ห้อง 406 · อ่านเอกสารบนตู้ข้างประตู",
	"เปิดกล่องย้ายบ้านในห้อง",
	"เหนื่อยแล้ว · เข้านอนบนเตียง",
	"03:07 · เสียงมาจากห้องข้าง ๆ",
	"ประตูล็อกอยู่ · กลับไปพักในห้อง 406",
	"07:16 · ออกไปดูว่าประตู 407 ยังอยู่ไหม",
	"ไม่มีประตูแล้ว · กลับห้องและพักจนถึงคืนถัดไป",
	"คืนที่สอง · เข้าไปในห้อง 407",
	"อ่านเอกสารบนตู้ในห้อง 407",
	"พบบันทึกแล้ว · อ่านเอกสารอีกครั้งเพื่อดูคำเตือน"
]

func _ready() -> void:
	make_ui()
	set_407(false)
	$Room407/SleepingDouble.visible=false
	var animation:AnimationPlayer=$HallFigure.find_child("AnimationPlayer",true,false)
	if animation:
		for clip in animation.get_animation_list():
			if str(clip).to_lower().contains("idle"):
				animation.get_animation(clip).loop_mode=Animation.LOOP_LINEAR
				animation.play(clip)
				break
	drone=AudioStreamPlayer.new()
	var stream=(load("res://Room407/audio/drone.wav") as AudioStreamWAV).duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=stream.data.size()/2
	drone.stream=stream
	drone.volume_db=-33
	add_child(drone)
	drone.play()
	scrape=AudioStreamPlayer3D.new()
	scrape.stream=load("res://Room407/audio/drag_placeholder.wav")
	scrape.position=Vector3(3,0.6,-3)
	scrape.volume_db=-7
	scrape.max_distance=18
	add_child(scrape)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	player.locked=true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture.call_deferred(arg.get_slice("=",1))

func text(parent: Node, value: String, pos: Vector2, size: int, color:=Color(.88,.86,.79)) -> Label:
	var l:=Label.new()
	l.text=value
	l.position=pos
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	if ResourceLoader.exists("res://Room407/assets/NotoSansThai.ttf"):
		l.add_theme_font_override("font",load("res://Room407/assets/NotoSansThai.ttf"))
	parent.add_child(l)
	return l

func make_ui() -> void:
	var retro:=CanvasLayer.new()
	retro.layer=1
	add_child(retro)
	overlay=ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	effect=ShaderMaterial.new()
	effect.shader=load("res://Room407/assets/shaders/retro_horror.gdshader")
	effect.set_shader_parameter("pixel_height",270.0)
	effect.set_shader_parameter("softness",.52)
	effect.set_shader_parameter("exposure",.98)
	effect.set_shader_parameter("vignette_strength",.3)
	overlay.material=effect
	retro.add_child(overlay)
	ui=CanvasLayer.new()
	ui.layer=4
	add_child(ui)
	chapter=text(ui,"ROOM 407     /     01 — เข้าพัก",Vector2(34,25),17,Color(.72,.62,.44))
	objective=text(ui,OBJECTIVES[0],Vector2(34,53),20)
	prompt=text(ui,"",Vector2(0,525),20)
	prompt.size.x=1280
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle=text(ui,"",Vector2(120,588),22)
	subtitle.size=Vector2(1040,105)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_constant_override("outline_size",6)
	subtitle.add_theme_color_override("font_outline_color",Color(.03,.035,.045,.9))
	text(ui,"·",Vector2(635,347),24)
	text(ui,"WASD เดิน   Shift เร่งเดิน   E สำรวจ   F ไฟฉาย   Esc เมนู",Vector2(34,688),14,Color(.55,.57,.58))
	shade=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0,0,0,0)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	title_screen=Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(title_screen)
	var panel:=ColorRect.new()
	panel.color=Color(.015,.018,.022,.91)
	panel.size=Vector2(630,720)
	title_screen.add_child(panel)
	text(title_screen,"EXITROOM / ความทรงจำก่อนกลับบ้าน",Vector2(65,147),13,Color(.62,.56,.42))
	text(title_screen,"ROOM 407",Vector2(60,178),66)
	text(title_screen,"ห้องที่ไม่มีอยู่",Vector2(66,268),30)
	text(title_screen,"“ห้องคุณคือ 406\nที่นี่ไม่มีห้อง 407”",Vector2(67,347),24)
	text(title_screen,"เลขบนทางออกพานนท์กลับหอพัก ก่อนวันที่ยายเสีย",Vector2(67,452),17,Color(.58,.61,.63))
	var button:=Button.new()
	button.text="เข้าพัก  →"
	button.position=Vector2(66,560)
	button.size=Vector2(240,53)
	button.add_theme_font_size_override("font_size",23)
	button.add_theme_font_override("font",load("res://Room407/assets/NotoSansThai.ttf"))
	title_screen.add_child(button)
	button.pressed.connect(start)
	pause_screen=Control.new()
	pause_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(pause_screen)
	var bg:=ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color=Color(.015,.018,.022,.95)
	pause_screen.add_child(bg)
	text(pause_screen,"หยุดพัก",Vector2(100,110),42)
	text(pause_screen,"Esc  กลับเข้าเกม\nM  ลดการเคลื่อนไหวกล้อง\nR  เริ่มเรื่องใหม่",Vector2(100,205),25)
	text(pause_screen,"Assets provided by Vicious Potato Studios\nBoxes by PomidorkaStudios\nHouse texture adaptations: NeoKG (CC BY 4.0) · Wood / plaster: Poly Haven\nดูรายชื่อและสถานะเครดิตเพิ่มเติมใน ASSET_CREDITS.md",Vector2(100,510),17)
	pause_screen.visible=false
	make_ending()

func start() -> void:
	started=true
	title_screen.hide()
	player.locked=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	say("ผมชื่อนนท์... ผมจำห้องนี้ได้ นี่คือคืนก่อนยายเสีย\nผมเพิ่งย้ายมาทำงาน เจ้าของหอย้ำว่า ที่นี่ไม่มีห้อง 407",8)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode==KEY_ESCAPE and started and not busy and not ending_screen.visible:
		paused=not paused
		pause_screen.visible=paused
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
		player.locked=paused
	if event.physical_keycode==KEY_M:
		player.reduced_motion=not player.reduced_motion
		say("ลดการเคลื่อนไหวกล้อง: "+("เปิด" if player.reduced_motion else "ปิด"))
	if event.physical_keycode==KEY_R and started and (paused or stage==9):
		get_tree().reload_current_scene()
		return
	if event.physical_keycode==KEY_E and started and not paused and not busy and not player.locked:
		var n:Node=player.target()
		if n:interact(str(n.get_meta("action")))

func _process(_delta: float) -> void:
	if not started or paused or ending_screen.visible:return
	if stage==4 and not busy and not player.locked and not hall_figure_vanished and $HallFigure.visible:
		if player.global_position.distance_squared_to($HallFigure.global_position)<=hall_figure_vanish_distance*hall_figure_vanish_distance:
			hall_figure_vanished=true
			$HallFigure.hide()
	objective.text=OBJECTIVES[stage]
	var n:Node=player.target()
	prompt.text="[ E ]  "+str(n.get_meta("hint")) if n and not busy else ""
	if stage==7 and not busy and player.global_position.distance_to(Vector3(2.3,0,-4.25))<2.2:
		reveal()

func interact(action: String) -> void:
	match action:
		"note":
			say("ใบรับห้อง — นนท์ / 406\nอย่าเปิดประตูให้ใครหลังตีสาม แม้เสียงนั้นจะเรียกชื่อคุณ",8)
			if stage==0:stage=1
		"unpack":
			if stage==1:
				stage=2
				say("เสื้อผ้า กับข้อความจากเมย์: พี่กลับมาถึงบึงแล้วเหรอ?\nแต่คืนนั้นผมอยู่ที่นี่... แล้วใครเรียกน้องอยู่หลังบ้านยาย",6)
			else:say("ของทั้งหมดของผมอยู่ในกล่องใบเดียว")
		"bed":
			if stage in [2,4,6]:sleep_transition()
			else:say("ขอจัดการสิ่งที่ค้างอยู่ก่อน")
		"wall":
			if stage==5:
				stage=6
				say("ไม่มีรอยประตู ไม่มีแม้แต่ขอบวงกบ\nเจ้าของหอบอกทางโทรศัพท์ว่า ‘ตรงนั้นเป็นกำแพงมาตลอด’",9)
			else:say("วอลเปเปอร์เก่า แห้ง และเย็นกว่าผนังส่วนอื่น")
		"door406":toggle_door($Door406)
		"door407":
			if stage==3:
				stage=4
				$HallFigure.visible=not hall_figure_vanished
				say("407 ... เมื่อเย็นตรงนี้ยังเป็นกำแพง\nเสียงลากหยุดทันทีที่ผมจับลูกบิด",8)
				await player.focus_on(Vector3(4,1.7,0))
			elif stage>=7:toggle_door($Door407)
		"double":
			if stage==7:reveal()
		"future_note":
			if stage in [8, 9]:
				stage=9
				chapter.text="ROOM 407 / เสียงที่ยืมชื่อเรา"
				show_ending()
			else:say("ลายมือบนกระดาษนี้ดูคุ้นตา")

func toggle_door(door: Node3D) -> void:
	if door_busy:return
	# Never close a leaf through a player standing in its sweep area.
	if absf(door.rotation.y)>.2 and player.position.distance_to(door.position)<1.4:
		say("ถอยจากบานประตูก่อนปิด")
		return
	door_busy=true
	var angle:=0.0 if absf(door.rotation.y)>.2 else deg_to_rad(96)
	var t:=create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(door,"rotation:y",angle,.6)
	await t.finished
	door_busy=false

func say(line: String, seconds:=5.0) -> void:
	subtitle_id+=1
	var id:=subtitle_id
	subtitle.text=line
	await get_tree().create_timer(seconds).timeout
	if id==subtitle_id:subtitle.text=""

func enabled(n: Node, value: bool) -> void:
	if n is Node3D:n.visible=value
	if n is CollisionShape3D:n.set_deferred("disabled",not value)
	for c in n.get_children():enabled(c,value)

func set_407(value: bool) -> void:
	enabled($Door407,value)
	enabled($Wall407,not value)

func sleep_transition() -> void:
	busy=true
	player.locked=true
	var t:=create_tween()
	t.tween_property(shade,"color:a",1.0,1.2)
	await t.finished
	player.position=Vector3(-4.0,.04,-3.5)
	player.rotation.y=PI
	player.pitch=0
	player.camera.rotation.x=0
	player.velocity=Vector3.ZERO
	if stage==2:
		stage=3
		set_407(true)
		scrape.play()
		chapter.text="คืนแรก     /     03:07"
		say("ครืด... ครืด...\nเสียงลากเฟอร์นิเจอร์ดังจากอีกฝั่งของผนัง",8)
	elif stage==4:
		stage=5
		$HallFigure.visible=false
		set_407(false)
		$WorldEnvironment.environment.ambient_light_energy=.65
		chapter.text="เช้าวันถัดมา     /     07:16"
		say("แสงเช้าปลุกผม ก่อนนาฬิกาจะดัง\nผมจำเลขบนประตูนั้นได้ชัดเจน",7)
	elif stage==6:
		stage=7
		set_407(true)
		$Door407.rotation.y=deg_to_rad(-96)
		$Room407/SleepingDouble.visible=true
		$WorldEnvironment.environment.ambient_light_energy=.22
		chapter.text="คืนที่สอง     /     03:07"
		say("คืนนี้ไม่มีเสียงลาก\nแต่ผมได้ยินเสียงนาฬิกาปลุกของตัวเอง... จากห้องข้าง ๆ",8)
	await get_tree().create_timer(.7).timeout
	t=create_tween()
	t.tween_property(shade,"color:a",0.0,1.2)
	await t.finished
	player.locked=false
	busy=false

func reveal() -> void:
	busy=true
	stage=8
	say("เสื้อตัวนั้น... ใบหน้านั้น...\nคนที่อยู่บนเตียงคือผม... หรือมันกำลังหัดเป็นผม",9)
	await player.focus_on(Vector3(2.3,.72,-4.85))
	var l:OmniLight3D=$Room407/BedLight
	var t:=create_tween()
	t.tween_property(l,"light_energy",.18,.08)
	t.tween_property(l,"light_energy",1.4,.15)
	t.tween_property(l,"light_energy",.6,.1)
	t.tween_property(l,"light_energy",1.4,.25)
	await t.finished
	busy=false

func capture(view: String) -> void:
	start()
	subtitle.text=""
	if view=="bedroom":
		player.position=Vector3(-3.6,.03,-.65)
		player.rotation.y=0
		player.pitch=-.06
	elif view=="double":
		stage=8
		set_407(true)
		$Door407.rotation.y=deg_to_rad(-96)
		$Room407/SleepingDouble.visible=true
		player.position=Vector3(4,.03,-2.1)
		player.rotation.y=.58
		player.pitch=-.28
	else:
		player.position=Vector3(-6.7,.03,1.8)
		player.rotation.y=-1.3
	player.camera.rotation.x=player.pitch
	player.locked=true
	await get_tree().create_timer(2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://Room407/previews")
	get_viewport().get_texture().get_image().save_png("res://Room407/previews/"+view+".png")
	get_tree().quit()


func make_ending() -> void:
	ending_screen = Control.new()
	ending_screen.name = "FrogChapterTeaser"
	ending_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(ending_screen)
	var background := ColorRect.new()
	background.color = Color(0.018, 0.04, 0.035, 0.98)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_screen.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_screen.add_child(center)
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = 930
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)
	text(stack, "ใบรับห้อง 406 / ลงวันที่พรุ่งนี้", Vector2.ZERO, 20, Color(.66,.77,.68))
	text(stack, "‘คืนถัดไป อย่าให้เขารู้ว่าคุณตื่นอยู่’", Vector2.ZERO, 25)
	var letter := text(stack, "ลายมือของนนท์เขียนต่อไว้: มันไม่ได้ติดอยู่ในห้องนี้ มันกำลังจำเสียงเรา\nหลังใบรับห้องมีแผนที่บึงหลังบ้านยาย และข้อความสุดท้ายจากเมย์\n‘ถ้าได้ยินเสียงพี่จากบึง อย่าตามมา คนที่เดินนำหนูไม่ใช่พี่’", Vector2.ZERO, 22)
	letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter.custom_minimum_size.x = 930
	text(stack, "DON'T FOLLOW THE FROG", Vector2.ZERO, 43, Color(.69,.85,.59))
	text(stack, "จากหลังผนัง เสียงลากเงียบลง... เหลือเพียงเสียงกบจากบึง\nบทถัดไป / ยังไม่เปิดให้เล่น", Vector2.ZERO, 21)
	var explore := Button.new()
	explore.text = "เก็บบันทึก / สำรวจห้องต่อ"
	explore.custom_minimum_size.y = 48
	explore.add_theme_font_override("font", load("res://Room407/assets/NotoSansThai.ttf"))
	stack.add_child(explore)
	explore.pressed.connect(close_ending)
	var replay := Button.new()
	replay.text = "กลับไปเริ่มเรื่องที่บ้านยาย"
	replay.custom_minimum_size.y = 48
	replay.add_theme_font_override("font", load("res://Room407/assets/NotoSansThai.ttf"))
	stack.add_child(replay)
	replay.pressed.connect(restart_story)
	ending_screen.hide()


func show_ending() -> void:
	subtitle_id += 1
	subtitle.text = ""
	prompt.text = ""
	player.locked = true
	player.velocity = Vector3.ZERO
	ending_screen.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ending_screen.find_children("*", "Button", true, false)[0].grab_focus()


func close_ending() -> void:
	ending_screen.hide()
	player.locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart_story() -> void:
	var error := get_tree().change_scene_to_file("res://prologue_village.tscn")
	if error != OK:
		say("เปิดฉากบ้านยายไม่สำเร็จ กรุณาตรวจไฟล์โปรเจกต์")
