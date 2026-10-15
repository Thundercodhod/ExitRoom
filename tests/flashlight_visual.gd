extends SceneTree
## Render identical views with the torch off/on; exercise real input, including echo.
var failures := 0
var tag := "after"
var manager: Node
const VIEWS := [
	["last_visit","res://levels/01_last_visit/prologue_village.tscn",Vector3(23.5,.12,-148),Vector3(19,1.5,-149)],
	["after_hours","res://levels/02_after_hours/backrooms_level.tscn",Vector3(8,.1,-8),Vector3(4,1.55,-8)],
	["room407","res://levels/03_room407/main.tscn",Vector3(-3.6,.05,-.65),Vector3(-5.3,1.3,-4.25)],
	["passenger","res://levels/04_passenger/frog_chapter.tscn",Vector3(-4,.05,-23),Vector3(0,1.5,-33)]
]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures += 1

func settle(seconds := .3) -> void:
	await create_timer(seconds).timeout
	await RenderingServer.frame_post_draw

func capture(id: String, state: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("res://.buildtmp/lighting/"+tag+"-"+id+"-"+state+".png")
	print("CAPTURE ",id," ",state)

func press(player: Node, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_F
	event.physical_keycode = KEY_F
	event.pressed = true
	event.echo = echo
	player._unhandled_input(event)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.buildtmp/lighting")
	manager = root.get_node("Anthology")
	manager.settings.reduced_motion = true
	manager.settings.master = 0.0
	manager.apply_preferences()
	for view in VIEWS:
		change_scene_to_file(view[1])
		await scene_changed
		await settle()
		var scene := current_scene
		var player: Node3D = scene.player
		if view[0]=="room407":
			scene.player.locked = false
		else:
			scene.playing = true
			player.set_third_person(false)
		# Stop narrative events and actors; the captured light/shader remain live.
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		# The Passenger gives its actors an explicit PAUSABLE mode, which overrides
		# inheritance from the scene. Freeze those too (otherwise gravity moves the view).
		for node in scene.find_children("*", "", true, false):
			node.process_mode = Node.PROCESS_MODE_DISABLED
		for layer in scene.find_children("*","CanvasLayer",true,false):
			if layer.name!="RetroHorrorLook" and not (view[0]=="room407" and layer.layer==1): layer.hide()
		player.global_position = view[2]
		var direction: Vector3 = (view[3]-player.camera.global_position).normalized()
		var yaw := atan2(-direction.x,-direction.z)
		var pitch := asin(direction.y)
		if view[0]=="room407":
			player.rotation.y = yaw
			player.camera.rotation.x = pitch
		else:
			player.pivot.rotation.y = yaw
			player.spring_arm.rotation.x = pitch
			player.torch.rotation.x = pitch
		player.pitch = pitch
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.torch.visible = false
		await capture(view[0],"off-1")
		await capture(view[0],"off-2")
		press(player)
		check(player.torch.visible,"one press turns torch on: "+view[0])
		press(player,true)
		check(player.torch.visible,"held key does not strobe: "+view[0])
		await capture(view[0],"on-1")
		await capture(view[0],"on-2")
		press(player)
		check(not player.torch.visible,"second press turns torch off: "+view[0])
		await capture(view[0],"off-again")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("FLASHLIGHT_FAILURES=",failures)
	quit(1 if failures else 0)
