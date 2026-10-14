extends SceneTree
## Exercise real controls, collision, pause, bounded grass, and the wake transition.
const Terrain=preload("res://scripts/dream_field_terrain.gd")
var failures:=0
var manager:Node
var saved:=""
var had_save:=false
var finishing:=false

func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures+=1
func key(code:Key,pressed:bool,echo:=false)->void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	event.echo=echo
	Input.parse_input_event(event)
func settle(seconds:=.25)->void:
	await create_timer(seconds).timeout
	await process_frame
func shot(name:String)->void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.buildtmp/dream-field/"+name+".png")
func finish()->void:
	if finishing: return
	finishing=true
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	key(KEY_CTRL,false)
	if manager: manager.close_modal(false)
	paused=false
	if had_save:
		var file:=FileAccess.open("user://anthology.cfg",FileAccess.WRITE)
		file.store_string(saved)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://anthology.cfg"))
	print("DREAM_FIELD_FAILURES=",failures)
	quit(1 if failures else 0)

func run()->void:
	create_timer(70.0).timeout.connect(func(): check(false,"field suite finishes within 70 seconds"); finish())
	had_save=FileAccess.file_exists("user://anthology.cfg")
	if had_save: saved=FileAccess.get_file_as_string("user://anthology.cfg")
	manager=root.get_node("Anthology")
	await settle()
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.size=Vector2i(1280,720)
	change_scene_to_file(manager.MENU)
	await scene_changed
	await settle()
	var menu=current_scene
	menu.show_page("episodes")
	var index:int=manager.EPISODES.size()-1
	menu.select_episode(index,false)
	check(menu.episode_buttons[index].name=="Episode06","selector includes level 06")
	var button:Button=menu.episode_buttons[index]
	check(button.position.y+button.size.y<620,"fifth selector card fits without covering footer")
	check(menu.start_button.text.contains("เดินเล่น"),"free-roam entry does not claim a story")
	await shot("menu-level06")
	menu.play_selected()
	while manager.changing: await process_frame
	await settle(.6)
	var field=current_scene
	check(field.scene_file_path=="res://dream_field.tscn","menu launches the real field")
	check(field.playing and not field.player.locked,"free exploration starts without a story panel")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var player:CharacterBody3D=field.player
	check(player.is_on_floor(),"player stands on terrain instead of falling")
	check(field.monument.get_node_or_null("StatueSocket/CatStatue")!=null,"cat statue replaces the screaming face")
	check(field.monument.find_children("MouthEntry","Area3D",true,false).is_empty(),"cat has no obsolete mouth trigger")
	if DisplayServer.get_name()!="headless":
		for prop_name in ["MeadowFlowers","DistantPineForest"]:
			var props:MultiMeshInstance3D=field.get_node("World/"+prop_name)
			check(props.multimesh.get_instance_transform(0).origin.length()>1.0 and props.multimesh.get_instance_color(0).r>.9,prop_name+" retains baked placement and colours")
	var start:Vector3=player.position
	key(KEY_W,true)
	await settle(.8)
	key(KEY_W,false)
	var walked:float=player.position.distance_to(start)
	check(walked>1.4,"W moves the player through the field")
	await settle(.2)
	start=player.position
	key(KEY_SHIFT,true)
	key(KEY_W,true)
	await settle(.8)
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	check(player.position.distance_to(start)>walked*1.3,"Shift provides unrestricted running")
	key(KEY_CTRL,true)
	await settle(.4)
	check(player.crouching and player.camera.position.y<1.0,"Ctrl lowers both the camera and collider")
	key(KEY_CTRL,false)
	await settle(.4)
	check(not player.crouching and player.camera.position.y>1.5,"standing height restores safely")
	key(KEY_E,true)
	key(KEY_E,false)
	await settle()
	check(not field.waking,"E at a distance does not exit the field")
	manager.show_pause()
	var frozen:Vector3=player.position
	key(KEY_W,true)
	await settle(.3)
	key(KEY_W,false)
	check(paused and player.position.is_equal_approx(frozen),"pause freezes movement")
	manager.close_modal()
	await settle()
	check(not paused and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"resume restores exploration")
	var count:int=field.grass.get_child_count()
	player.position=Vector3(260,Terrain.height_at(260,-180)+.1,-180)
	await settle(1.2)
	while not field.grass.pending.is_empty(): await process_frame
	check(field.grass.get_child_count()==count and count==81,"walking far recycles a fixed grass pool")
	check(field.grass.centre.x>10,"grass follows exploration beyond the starting area")
	for sound in field.ambient:
		check(sound.playing and sound.stream.get_length()>8.0,"ambient recording remains playable and looped")
	player.position=field.monument.position+Vector3(0,.08,2.85)
	player.rotation.y=0
	player.pitch=0
	player.camera.rotation.x=0
	await settle(.5)
	check(field.can_wake() and field.prompt.text.contains("ตื่น"),"looking at the nearby cat shows the wake prompt")
	await shot("wake-prompt")
	player.rotation.y=PI
	check(not field.can_wake(),"looking away prevents accidental waking")
	player.rotation.y=0
	key(KEY_E,true,true)
	await settle(.2)
	check(not field.waking,"key repeat cannot accidentally trigger waking")
	key(KEY_E,true)
	key(KEY_E,false)
	await settle(.8)
	check(field.waking and player.locked and field.curtain.color.a>.1 and field.curtain.color.a<1.0,"E starts a visible fade and locks movement")
	check(field.ambient[0].volume_db < -25.0,"wind fades with the picture")
	await shot("wake-fade")
	while current_scene==field or manager.changing: await process_frame
	check(current_scene.scene_file_path==manager.MENU and current_scene.page=="episodes","waking returns directly to selection")
	check(not paused and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"return restores menu input")
	finish()
