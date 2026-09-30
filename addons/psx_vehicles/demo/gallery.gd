extends Node
## The pack's gallery: each prop on its own or all of them laid out, turned with the mouse, its
## animations on buttons. With PSX Look installed (res://addons/psx_look/), they show through it.
## Keys: left / right, 1 to 3 for the animations, A for all, P for PSX Look. A pack with a level
## (props.json's "layout") shows it on L and walks it on W: WASD and the mouse, Shift to run, E to
## open what is in front, F for the torch, Esc to stop. A pack with guns (a held prop's "gun" in
## props.json) has a range on G: its targets downrange, its ammunition on the floor to walk over,
## the guns in hand on the wheel or 1 to 9; left button to fire, right to aim, R to reload.

const PSX_LOOK := "res://addons/psx_look/"
const FLOOR := Color(0.13, 0.12, 0.11)
const WALL := Color(0.2, 0.19, 0.17)
const GAP := 0.05
const WRAP := 24.0  # the widest line of the all-props view
const EYE := 1.6
const STEP := 0.3  # the highest edge the walker steps up
const CUT := 2.9  # the level's view leaves out what stands this high: an upper storey
const BACKSTOP := 16.0  # the range's far wall
const HOLES := 64  # bullet holes kept

## Hides the panel and stops the camera turning on its own, for the store captures.
@export var still := false
## Opens on the first prop. Off for the captures of a set: Godot 4.7 errors on a converted prop's
## scene put up again in the frame after its first instance went.
@export var start := true

var dir: String
var props: Array
var level: Dictionary
var walker: CharacterBody3D
var guns: Array
var ranging := false
var view := Node3D.new()  # the gun in hand, under the camera
var gun_node: Node3D
var gun: Dictionary
var loaded := {}  # rounds in each gun, by its name
var spare := {}  # rounds carried, by the ammunition's name
var aim := 0.0  # 0 from the hip, 1 down the sights
var aiming := false
var firing := false
var wait := 0.0  # until the gun fires again
var reloading := 0.0
var reload_time := 1.0
var kick := 0.0
var sway := Vector2.ZERO
var bob := 0.0
var flash := MeshInstance3D.new()
var flash_light := OmniLight3D.new()
var flash_left := 0.0
var holes: Array = []
var hud := CanvasLayer.new()
var ammo_label := Label.new()
var note := Label.new()
var note_left := 0.0
var torch: SpotLight3D
var sun := DirectionalLight3D.new()
var rim := DirectionalLight3D.new()
var index := 0
var all_view := false
var world := Node3D.new()
var shown := Node3D.new()
var cam := Camera3D.new()
var wall := MeshInstance3D.new()
var ground := MeshInstance3D.new()
var env := Environment.new()
var yaw := 0.5
var pitch := -0.4
var rise := 0.2  # how far below its target the camera may go
var dist := 1.0
var target := Vector3.ZERO
var idle := 0.0
var psx_screen: Control
var psx_on := false
var ui := CanvasLayer.new()
var icon := TextureRect.new()
var title := Label.new()
var info := Label.new()
var anim_bar := HBoxContainer.new()
var psx_button := Button.new()


func _ready() -> void:
	dir = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/props.json"))
	props = data["props"]
	level = data.get("layout", {})
	guns = props.filter(func(p): return p.has("gun"))
	add_child(world)
	_stage()
	world.add_child(shown)
	world.add_child(cam)
	cam.add_child(view)
	_flash()
	cam.current = true
	cam.fov = 40
	_ui()
	if ResourceLoader.exists(PSX_LOOK + "psx_screen.gd"):
		psx_screen = load(PSX_LOOK + "psx_screen.gd").new()
		psx_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(psx_screen)
		move_child(psx_screen, 0)
		set_psx(true)
	else:
		psx_button.hide()
	if start:
		show_prop(0)


func _stage() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.62)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.04, 0.05)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	world.add_child(sun)
	rim.rotation_degrees = Vector3(-25, 150, 0)
	rim.light_color = Color(0.5, 0.6, 0.9)
	rim.light_energy = 0.4
	world.add_child(rim)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.position.y = -0.003  # under a floor piece, not through it
	ground.material_override = _flat(FLOOR)
	world.add_child(ground)
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 6)
	wall.mesh = quad
	wall.position = Vector3(0, 3, -0.002)
	wall.material_override = _flat(WALL)
	world.add_child(wall)


## The muzzle flash: a six-pointed star drawn here, and its light, up for a frame or two.
func _flash() -> void:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5)
			var v := clampf(1.0 - d.length() / 16.0 / (0.45 + 0.55 * absf(cos(d.angle() * 3.0))), 0, 1)
			img.set_pixel(x, y, Color(1, 0.7 + 0.3 * v, 0.3 + 0.6 * v, v))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.albedo_texture = ImageTexture.create_from_image(img)
	flash.mesh = QuadMesh.new()
	flash.mesh.size = Vector2(0.3, 0.3)
	flash.material_override = m
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_light.light_color = Color(1.0, 0.75, 0.4)
	flash_light.light_energy = 6.0
	flash_light.omni_range = 6.0
	for n in [flash, flash_light]:
		n.hide()
		view.add_child(n)
	var key := OmniLight3D.new()  # the gun in hand's own, over the shoulder: the gun is on layer 2
	key.light_cull_mask = 2
	key.position = Vector3(0.35, 0.35, 0.25)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 0.9
	key.omni_range = 2.0
	view.add_child(key)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	m.metallic_specular = 0.0
	return m


func _ui() -> void:
	add_child(ui)
	var top := VBoxContainer.new()
	top.position = Vector2(20, 16)
	ui.add_child(top)
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(icon)
	for l in [title, info]:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		top.add_child(l)
	title.add_theme_font_size_override("font_size", 26)
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(0.85, 0.82, 0.75)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 16
	ui.add_child(bar)
	_button(bar, "<", func() -> void: show_prop(index - 1))
	_button(bar, ">", func() -> void: show_prop(index + 1))
	bar.add_child(anim_bar)
	_button(bar, "All", toggle_all)
	if not level.is_empty():
		_button(bar, "Level", show_level)
		_button(bar, "Walk", walk.bind(true))
	if not guns.is_empty():
		_button(bar, "Range", firing_range.bind(true))
	psx_button.text = "PSX Look"
	psx_button.toggle_mode = true
	psx_button.focus_mode = Control.FOCUS_NONE
	psx_button.toggled.connect(set_psx)
	bar.add_child(psx_button)
	var hint := Label.new()
	hint.text = "drag to turn, wheel to zoom"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-16, 16)
	ui.add_child(hint)
	ui.visible = not still
	add_child(hud)
	hud.hide()
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.position += Vector2(-24, -20)
	ammo_label.add_theme_font_size_override("font_size", 24)
	note.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	note.grow_horizontal = Control.GROW_DIRECTION_BOTH
	note.position.y -= 90
	var dot := ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(1, 1, 1, 0.7)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	var keys := Label.new()
	keys.text = "left button fire, right aim, R reload, wheel or 1-%d guns, F torch, Esc out" % mini(9, guns.size())
	keys.position = Vector2(20, 16)
	keys.modulate = Color(1, 1, 1, 0.5)
	keys.visible = not still
	for c in [ammo_label, note, keys]:
		c.add_theme_color_override("font_shadow_color", Color.BLACK)
		c.add_theme_constant_override("shadow_offset_x", 2)
		c.add_theme_constant_override("shadow_offset_y", 2)
	for c in [ammo_label, note, dot, keys]:
		hud.add_child(c)


func _button(box: Container, text: String, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 44
	b.pressed.connect(pressed)
	box.add_child(b)
	return b


## Shows the prop at `i` (wrapping round) alone, framed.
func show_prop(i: int) -> void:
	index = posmod(i, props.size())
	all_view = false
	_clear()
	_dark(false)
	var p: Dictionary = props[index]
	var held: bool = p["place"] == "hand"
	var lift := Vector3(0, 0.2 - p["min"][2], 0) if held else Vector3.ZERO  # upright in the air, room below for a magazine to drop
	_place(p, lift)
	var lo := _gd(p["min"]) + lift
	var hi := _gd(p["max"]) + lift
	var box := AABB(lo, Vector3.ZERO).expand(hi)
	target = box.get_center()
	dist = maxf(0.12, box.size.length() * 0.5 / sin(deg_to_rad(cam.fov * 0.5)) * 1.15)
	var hung: bool = lo.y > 1.5 and p["place"] != "wall"  # a ceiling and what hangs from it: seen from below
	pitch = 0.35 if hung else (-0.75 if box.size.y < 0.1 else -0.3)
	rise = 0.8 if hung else 0.2
	yaw = 0.5
	wall.visible = p["place"] == "wall" or held
	if held:  # from the right, where a gun's ejection port is: its side filling the view, before the
		# wall and lit from over the camera's shoulder
		pitch = -0.12
		yaw = -1.35
		cam.fov = 20  # long, so a gun's near and far ends are drawn to one scale
		var t := tan(deg_to_rad(cam.fov * 0.5))
		dist = maxf(box.size.z / cam.get_viewport().get_visible_rect().size.aspect(), box.size.y) * 0.5 / t * 1.2
		var back := Basis.from_euler(Vector3(0, yaw, 0))
		wall.basis = back
		wall.position = Vector3(target.x, 3, target.z) - back.z * maxf(0.3, box.size.z * 0.6)
		sun.rotation = Vector3(-0.6, yaw + 0.6, 0)
	var icon_path := "%s/icons/%s.png" % [dir, p["name"]]
	icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	icon.visible = icon.texture != null
	title.text = p["title"]
	info.text = "%s  |  %d / %d  |  %d triangles  |  %s m\n%s" % [
		p["group"].capitalize(), index + 1, props.size(), p["tris"], _size(p["size"]), p["note"]]
	for b in anim_bar.get_children():
		b.queue_free()
	for a in p["anims"]:
		_button(anim_bar, a["name"], func() -> void: play(a["name"]))


## Every prop at once: the wall props on the wall, the floor props before it and the small
## items and held ones in front, a cluster per group.
func show_all() -> void:
	all_view = true
	_clear()
	_dark(false)
	for b in anim_bar.get_children():
		b.queue_free()
	var rows := {"wall": [], "floor": [], "item": []}
	for p in props:
		rows["item" if p["place"] == "hand" else p["place"]].append(p)
	var wall_width := _row(rows["wall"], 0.0, 0.18, true).x
	var floor_size := _row(rows["floor"], 0.3, 0.25)
	var groups: Array = []
	var by_group := {}
	for p in rows["item"]:
		if p["group"] not in by_group:
			by_group[p["group"]] = []
			groups.append(p["group"])
		by_group[p["group"]].append(p)
	var clusters: Array = []
	for g in groups:
		clusters.append(_cluster(by_group[g]))
	var per_row := ceili(clusters.size() / 2.0)
	var z := 0.3 + floor_size.y + 0.6
	var width := maxf(wall_width, floor_size.x)
	for r in range(0, clusters.size(), per_row):
		var line := clusters.slice(r, r + per_row)
		var line_width := 0.0
		var depth := 0.0
		for c in line:
			line_width += c.get_meta("size").x + 0.25
			depth = maxf(depth, c.get_meta("size").y)
		width = maxf(width, line_width)
		var x := -line_width * 0.5
		for c in line:
			c.position = Vector3(x, 0, z)
			x += c.get_meta("size").x + 0.25
		z += depth + 0.35
	wall.visible = true
	(ground.mesh as PlaneMesh).size = Vector2(maxf(40, width + 4), maxf(40, 2 * z + 4))
	target = Vector3(0, 0.45, z * 0.45)
	dist = maxf(5.2, maxf(width, z) * 0.75)
	pitch = -0.42
	yaw = 0.0
	icon.hide()
	title.text = "All %d props" % props.size()
	info.text = "%d triangles in all" % props.reduce(func(s, p): return s + p["tris"], 0)


func toggle_all() -> void:
	if all_view:
		show_prop(index)
	else:
		show_all()


## Props laid out as given: [name, [x, y, z] in metres, turn in degrees], for a composed shot.
func show_set(items: Array) -> void:
	all_view = true
	_clear()
	_dark(false)
	var named := {}
	for p in props:
		named[p["name"]] = p
	for it in items:
		var p: Dictionary = named[it[0]]
		var n := _place(p, Vector3(it[1][0], it[1][1], it[1][2]))
		n.rotation_degrees.y = it[2] if it.size() > 2 else 0.0
		if p["place"] == "hand":
			_lay(n, p)
	wall.visible = true


## The level: its pieces where the layout puts them ([name, [x, y, z] in Blender's metres, turn in
## degrees]) and its lights, in the dark; as a plan, lit enough to read from above and without its
## upper storey.
func show_level(plan := true) -> void:
	all_view = true
	_clear()
	_dark(true)
	for b in anim_bar.get_children():
		b.queue_free()
	var named := {}
	for p in props:
		named[p["name"]] = p
	var box := AABB()
	for it in level["pieces"]:
		var n := _place(named[it[0]], _gd(it[1]))
		n.rotation_degrees.y = it[2]
		n.visible = not plan or it[1][2] < CUT
		box = box.expand(n.position)
	for l in level.get("lights", []):
		var o := OmniLight3D.new()
		o.position = _gd(l["at"])
		o.light_color = Color(l["color"][0], l["color"][1], l["color"][2])
		o.light_energy = l["energy"]
		o.omni_range = l["range"]
		o.set_meta("energy", o.light_energy)
		o.set_meta("flicker", l.get("flicker", false))
		shown.add_child(o)
	if plan:
		env.ambient_light_energy = 0.5
		env.fog_density = 0.01
	target = box.get_center()
	dist = box.size.length() * 0.75
	pitch = -1.0
	yaw = 0.3
	icon.hide()
	title.text = "The demo level"
	info.text = "%d pieces, %d lights. Walk (W) to go in" % [level["pieces"].size(), level.get("lights", []).size()]


## Into the level on foot at the layout's `start` ([x, y, z, turn]), or back out to the view.
func walk(on: bool) -> void:
	if on == (walker != null) or level.is_empty():
		return
	if on:
		show_level(false)
		_on_foot(_gd(level["start"]), deg_to_rad(level["start"][3]) + PI)
	else:
		_off_foot()
		show_level()


func _on_foot(at: Vector3, turn: float) -> void:
	walker = CharacterBody3D.new()
	var body := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.75
	body.shape = capsule
	body.position.y = capsule.height / 2
	walker.add_child(body)
	walker.floor_snap_length = STEP
	walker.position = at
	yaw = turn
	pitch = 0.0
	world.add_child(walker)
	torch = SpotLight3D.new()
	torch.spot_range = 14.0
	torch.spot_angle = 24.0
	torch.light_energy = 2.0
	torch.shadow_enabled = true
	torch.visible = false
	cam.add_child(torch)
	if not still:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.hide()


func _off_foot() -> void:
	walker.queue_free()
	walker = null
	torch.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.visible = not still


## The range, on foot with a gun in hand, or back out to the prop.
func firing_range(on: bool) -> void:
	if on == ranging or guns.is_empty():
		return
	if walker:
		_off_foot()
	if not on:
		ranging = false
		firing = false
		aiming = false
		hud.hide()
		gun_node.queue_free()
		gun_node = null
		flash.hide()
		flash_light.hide()
		show_prop(index)
		return
	all_view = true
	ranging = true
	_clear()
	_dark(false)
	for b in anim_bar.get_children():
		b.queue_free()
	_range_room()
	var named := {}
	for p in props:
		named[p["name"]] = p
	var targets := props.filter(func(p): return p["group"] == "targets")
	var spots := [Vector3(-0.3, 0, -5.5), Vector3(1.7, 0, -7.5), Vector3(-1.8, 0, -9), Vector3(0.8, 0, -11.5), Vector3(-3.0, 0, -13)]
	for k in spots.size() if targets else 0:
		_place(targets[k % targets.size()], spots[k])
	if "ammo_crate" in named:
		_place(named["ammo_crate"], Vector3(3.2, 0, 3.2)).rotation_degrees.y = -20
	loaded = {}
	spare = {}
	var ammo: Array = []
	for g in guns:
		var a: String = g["gun"]["ammo"]
		loaded[g["name"]] = g["gun"]["rounds"]
		spare[a] = maxi(spare.get(a, 0), g["gun"]["rounds"] * 2)
		if a in named and a not in ammo:
			ammo.append(a)
	for k in ammo.size():  # on the floor behind the booths, to walk over; back after a while
		var n := _place(named[ammo[k]], Vector3((k - (ammo.size() - 1) / 2.0) * 0.6, 0, 2.6))
		n.rotation_degrees.y = 25.0 * sin(k * 2.3)
		n.set_meta("ammo", ammo[k])
		n.set_meta("amount", spare[ammo[k]])
	holes.clear()
	_on_foot(Vector3(0, 0, 1.2), 0.0)
	hud.show()
	equip(0)


## An indoor range: booths at the firing line (z 0) and lanes down to a backstop, lit by
## fluorescent tubes between the baffles under its ceiling.
func _range_room() -> void:
	const W := 4.0  # half its width
	const H := 3.0
	ground.visible = false
	wall.visible = false
	sun.visible = false
	rim.visible = false
	env.ambient_light_energy = 0.55
	var stops := StaticBody3D.new()  # walls, floor and ceiling, for the walker and the shots
	for plane in [Plane(Vector3.UP, 0), Plane(Vector3.DOWN, -H), Plane(Vector3.BACK, -BACKSTOP), Plane(Vector3.RIGHT, -W),
			Plane(Vector3.LEFT, -W), Plane(Vector3.FORWARD, -4)]:
		var s := CollisionShape3D.new()
		s.shape = WorldBoundaryShape3D.new()
		s.shape.plane = plane
		stops.add_child(s)
	shown.add_child(stops)
	var mid := (4.0 - BACKSTOP) / 2
	var long := 4.0 + BACKSTOP
	_block(Vector3(2 * W, 0.02, long), Vector3(0, -0.01, mid), Color(0.34, 0.33, 0.31))  # concrete
	_block(Vector3(2 * W, 0.005, 0.1), Vector3(0, 0.002, -0.05), Color(0.85, 0.7, 0.1))  # the firing line
	_block(Vector3(2 * W, 0.02, long), Vector3(0, H + 0.01, mid), Color(0.14, 0.14, 0.15))
	for x in [-W, W]:
		_block(Vector3(0.02, H, long), Vector3(x, H / 2, mid), Color(0.46, 0.45, 0.41))  # block walls
		_block(Vector3(0.03, 1.0, long), Vector3(x, 0.5, mid), Color(0.26, 0.31, 0.29))  # painted below
	_block(Vector3(2 * W, H, 0.02), Vector3(0, H / 2, 4.0), Color(0.46, 0.45, 0.41))
	_block(Vector3(2 * W, H, 0.3), Vector3(0, H / 2, -BACKSTOP), Color(0.1, 0.09, 0.08))  # rubber backstop
	_block(Vector3(2 * W, 0.6, 1.2), Vector3(0, H - 0.3, -BACKSTOP + 0.6), Color(0.16, 0.15, 0.14))  # its hood
	for x in [-2.6, -1.0, 1.0, 2.6]:  # booth partitions and the shelf across them
		_block(Vector3(0.06, 1.7, 1.0), Vector3(x, 0.85, 0.5), Color(0.2, 0.23, 0.23), true)
	_block(Vector3(2 * W, 0.05, 0.35), Vector3(0, 1.0, 0.18), Color(0.22, 0.19, 0.16), true)
	for z in range(-2, -int(BACKSTOP), -3):  # baffles
		_block(Vector3(2 * W, 0.5, 0.12), Vector3(0, H - 0.25, z), Color(0.24, 0.23, 0.22))
	for z in [2.4, -0.5, -3.5, -6.5, -9.5, -12.5]:  # tubes, and a light for each (the web renderer takes 8 a mesh)
		for x in ([-1.8, 1.8] if z > 0 else [-1.4, 1.4]):
			_block(Vector3(1.2, 0.06, 0.2), Vector3(x, H - 0.4, z), Color(1.0, 0.96, 0.85), false, true)
			_block(Vector3(1.3, 0.04, 0.26), Vector3(x, H - 0.35, z), Color(0.3, 0.3, 0.3))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0, H - 0.5, z)
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.light_energy = 0.9 if z > 0 else 1.2
		lamp.omni_range = 6.0
		lamp.omni_attenuation = 0.8
		shown.add_child(lamp)


## A box of flat colour in the shown set: `solid` to stand in the way, `lit` to glow.
func _block(size: Vector3, at: Vector3, c: Color, solid := false, lit := false) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mat := _flat(c)
	if lit:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var m := MeshInstance3D.new()
	m.mesh = box
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = at
	shown.add_child(m)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		body.add_child(shape)
		m.add_child(body)


## Takes the gun at `i` (wrapping round) in hand.
func equip(i: int) -> void:
	if gun_node:
		gun_node.queue_free()
	gun = guns[posmod(i, guns.size())]
	gun_node = _place(gun, Vector3.ZERO, view)
	for body in gun_node.find_children("*", "StaticBody3D", true, false):
		body.free()
	for mi in gun_node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as MeshInstance3D).layers = 2
	reloading = 0.0
	wait = 0.2
	kick = 0.0
	flash.scale = Vector3.ONE * (1.3 if gun["group"] in ["shotguns", "launchers"] else 1.0)
	_hud()


## Fires the gun in hand: a round from it, its "fire" animation and its "cycle" after, a flash and
## a kick; a ray from the middle of the view (a spread of pellets from a shotgun) leaves a hole where
## it lands, and a target plays its animation. Empty, it reloads.
func shoot() -> void:
	var g: Dictionary = gun["gun"]
	if loaded[gun["name"]] <= 0:
		reload()
		return
	loaded[gun["name"]] -= 1
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var length := player.get_animation(g["fire"]).length
	var speed := maxf(1.0, length * g["rate"]) if g.get("auto", false) else 1.0
	player.stop()
	player.play(g["fire"], -1, speed)
	wait = length / speed
	if g.has("cycle") and loaded[gun["name"]] > 0:
		player.queue(g["cycle"])
		wait += player.get_animation(g["cycle"]).length
	flash_left = 0.06
	flash.rotation.z = randf() * TAU
	kick = 1.0
	pitch += 0.03 if gun["group"] in ["shotguns", "launchers"] else 0.012
	var pellets := 8 if gun["group"] == "shotguns" else 1
	var spread := lerpf(0.025, 0.003, aim) + (0.035 if pellets > 1 else 0.0)
	for k in pellets:
		_bullet(spread)
	_hud()


func _bullet(spread: float) -> void:
	var b := cam.global_basis
	var to := (-b.z + b.x * randfn(0, spread) + b.y * randfn(0, spread)).normalized()
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + to * 60.0)
	q.exclude = [walker.get_rid()]
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var body: Node3D = hit["collider"]
	var hole := MeshInstance3D.new()
	hole.mesh = QuadMesh.new()
	hole.mesh.size = Vector2(0.025, 0.025)
	hole.material_override = _flat(Color(0.03, 0.03, 0.03))
	body.add_child(hole)
	var n: Vector3 = hit["normal"]
	hole.global_transform = Transform3D(Basis.looking_at(-n, Vector3.RIGHT if absf(n.y) > 0.9 else Vector3.UP),
			hit["position"] + n * 0.003)
	holes.append(hole)
	if holes.size() > HOLES:
		var old: Node = holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var prop: Node = body
	while prop and not prop.has_meta("prop"):
		prop = prop.get_parent()
	if prop and prop.get_meta("prop")["group"] == "targets" and not prop.get_meta("prop")["anims"].is_empty():
		var player := prop.find_child("AnimationPlayer", true, false) as AnimationPlayer
		player.stop()
		player.play(prop.get_meta("prop")["anims"][0]["name"])


## Fills the gun in hand from what is carried, through its "reload" animation, or a dip of the gun.
func reload() -> void:
	var g: Dictionary = gun["gun"]
	if reloading > 0 or loaded[gun["name"]] >= g["rounds"] or spare.get(g["ammo"], 0) <= 0:
		return
	var player := gun_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	reload_time = 1.2
	if g.has("reload"):
		player.stop()
		player.play(g["reload"])
		reload_time = player.get_animation(g["reload"]).length
	reloading = reload_time


func _reloaded() -> void:
	var g: Dictionary = gun["gun"]
	var take := mini(g["rounds"] - loaded[gun["name"]], spare[g["ammo"]])
	loaded[gun["name"]] += take
	spare[g["ammo"]] -= take
	_hud()


func _hud() -> void:
	var g: Dictionary = gun["gun"]
	ammo_label.text = "%s\n%d  /  %d" % [gun["title"], loaded[gun["name"]], spare.get(g["ammo"], 0)]


func _range_tick(delta: float) -> void:
	wait -= delta
	if reloading > 0:
		reloading -= delta
		if reloading <= 0:
			_reloaded()
	elif firing and wait <= 0:
		shoot()
		firing = firing and gun["gun"].get("auto", false)
	for n in shown.get_children():
		if not n.has_meta("ammo"):
			continue
		if n.has_meta("back"):
			n.set_meta("back", n.get_meta("back") - delta)
			if n.get_meta("back") <= 0:
				n.remove_meta("back")
				n.show()
		elif Vector2(n.position.x - walker.position.x, n.position.z - walker.position.z).length() < 0.6:
			spare[n.get_meta("ammo")] += n.get_meta("amount")
			n.hide()
			n.set_meta("back", 10.0)
			note.text = "+%d  %s" % [n.get_meta("amount"), n.get_meta("prop")["title"]]
			note_left = 2.0
			_hud()


## The gun in hand: from the hip or down its sights, swaying with the mouse, bobbing with the walk
## and kicking with a shot.
func _viewmodel(delta: float) -> void:
	aim = move_toward(aim, 1.0 if aiming else 0.0, delta * 6.0)
	kick = move_toward(kick, 0.0, delta * 7.0)
	sway = sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))
	var speed := Vector2(walker.velocity.x, walker.velocity.z).length()
	bob += delta * speed * 3.2
	var step := Vector3(cos(bob) * 0.008, -absf(sin(bob)) * 0.01, 0) * minf(1.0, speed) * (1.0 - aim * 0.8)
	var s := _gd(gun["gun"]["sight"])
	# turned round, its sight under the middle of the view: at arm's length for a handgun; a long gun
	# held a hand ahead of its butt and low enough to see over its stock
	var handgun: bool = gun["group"] == "handguns"
	var eye := 0.45 if handgun else maxf(0.3, s.z + gun["max"][1] - 0.12)
	var aimed := Vector3(-s.x, -s.y - (0.012 if handgun else 0.04), -eye + s.z)
	var hip := aimed + (Vector3(0.16, -0.13, -0.06) if handgun else Vector3(0.26, -0.2, -0.2))
	var dip := sin(clampf(1.0 - reloading / reload_time, 0, 1) * PI) if reloading > 0 and not gun["gun"].has("reload") else 0.0
	gun_node.position = hip.lerp(aimed, aim) + step + Vector3(sway.x, sway.y - dip * 0.08, kick * 0.04)
	# from the hip turned in a little toward the middle and canted, so its side and top both show
	var turn := (1.0 - aim) * Vector3(0.05, 0.22, 0.12)
	gun_node.rotation = turn + Vector3(-kick * 0.12 + dip * 0.6 + sway.y * 2.0, PI - sway.x * 2.0, dip * 0.4)
	cam.fov = lerpf(70.0, 50.0, aim)
	hud.get_node("Dot").visible = aim < 0.5
	flash_left -= delta
	flash.visible = flash_left > 0
	flash_light.visible = flash.visible
	flash.position = gun_node.transform * (_gd(gun["gun"]["muzzle"]) + Vector3(0, 0, 0.05))
	flash_light.position = flash.position
	note_left -= delta
	note.visible = note_left > 0


## Opens (or shuts) the nearest thing in front that moves: a door plays its animation to the half,
## where it stands open, and on from there to shut; a loop starts or stops.
func use() -> void:
	var fwd := -cam.global_basis.z
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var best: Node3D
	var near := 2.0
	for n in shown.get_children():
		if not n.has_meta("prop") or n.get_meta("prop")["anims"].is_empty():
			continue
		var to: Vector3 = n.global_position - walker.global_position
		to.y = 0
		if to.length() < near and (to.length() < 0.6 or to.normalized().dot(fwd) > 0.4):
			best = n
			near = to.length()
	if not best:
		return
	var a: Dictionary = best.get_meta("prop")["anims"][0]
	var player := best.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if a["loop"]:
		if player.is_playing():
			player.stop()
		else:
			player.play(a["name"])
	elif player.is_playing():
		return
	elif best.get_meta("open", false):
		player.play(a["name"])
		best.set_meta("open", false)
	else:
		player.play(a["name"])
		player.seek(0.0, true)
		best.set_meta("stop", a["seconds"] / 2.0)
		best.set_meta("open", true)


func _dark(on: bool) -> void:
	sun.visible = not on
	rim.visible = not on
	ground.visible = not on
	wall.visible = not on
	env.ambient_light_energy = 0.12 if on else 0.7
	env.fog_density = 0.07 if on else 0.04
	cam.fov = 62 if on else 40  # wide, in the rooms
	rise = 0.2


func _physics_process(delta: float) -> void:
	if not walker:
		return
	var move := Vector3(_key(KEY_D, KEY_RIGHT) - _key(KEY_A, KEY_LEFT), 0, _key(KEY_S, KEY_DOWN) - _key(KEY_W, KEY_UP))
	var speed := 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.2
	move = Basis(Vector3.UP, yaw) * move.limit_length(1.0) * speed
	walker.velocity = Vector3(move.x, walker.velocity.y - 9.8 * delta, move.z)
	if walker.is_on_floor():
		walker.velocity.y = 0.0
		var step := Vector3(move.x, 0, move.z) * delta
		var hit := walker.move_and_collide(step, true)
		# up a stair: an edge in the way, and the way clear a step higher
		if hit and absf(hit.get_normal().y) < 0.6 \
				and not walker.test_move(walker.global_transform.translated(Vector3(0, STEP, 0)), step):
			walker.position.y += STEP
	walker.move_and_slide()
	if ranging:
		_range_tick(delta)
	elif walker.position.y < -20:
		walker.position = _gd(level["start"])


func _key(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0


## Frames the view: target point, distance, yaw and pitch in radians.
func look(at: Vector3, distance: float, turn: float, tilt: float) -> void:
	target = at
	dist = distance
	yaw = turn
	pitch = tilt


func play(anim: String) -> void:
	for p in shown.get_children():
		var player := p.find_child("AnimationPlayer") as AnimationPlayer
		if player and player.has_animation(anim):
			player.stop()
			player.play(anim)


func set_psx(on: bool) -> void:
	if not psx_screen:
		return
	psx_on = on
	psx_button.set_pressed_no_signal(on)
	world.get_parent().remove_child(world)
	if on:
		psx_screen.viewport.add_child(world)
	else:
		add_child(world)
	psx_screen.visible = on
	for n in shown.get_children():
		_convert(n)
	if gun_node:
		_convert(gun_node)


func _convert(node: Node) -> void:
	if not psx_screen:
		return
	if psx_on:
		load(PSX_LOOK + "psx.gd").convert(node)
		return
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			(mi as MeshInstance3D).set_surface_override_material(s, null)


func _place(p: Dictionary, at: Vector3, parent: Node3D = shown) -> Node3D:
	var node: Node3D = load("%s/props/%s.tscn" % [dir, p["name"]]).instantiate()
	node.position = at
	node.set_meta("prop", p)
	parent.add_child(node)
	_convert(node)
	return node


## A held prop laid on its left side, on what `node` stands on.
func _lay(node: Node3D, p: Dictionary) -> void:
	node.rotation.z = -PI / 2
	node.position.y += p["max"][0]


## Props side by side from `back`, in lines no wider than WRAP: the floor's one behind the other,
## the wall's (`on_wall`) in two, one over the other. Returns the lines' width and depth.
func _row(list: Array, back: float, gap: float, on_wall := false) -> Vector2:
	var total := -gap
	var widest := 0.0
	for p in list:
		total += p["size"][0] + gap
		widest = maxf(widest, p["size"][0])
	var wrap := maxf(WRAP, total / 2.0 + widest + gap) if on_wall else WRAP
	var lines: Array = [[]]
	var width := -gap
	for p in list:
		if width + gap + p["size"][0] > wrap and not lines[-1].is_empty():
			lines.append([])
			width = -gap
		lines[-1].append(p)
		width += p["size"][0] + gap
	var size := Vector2.ZERO
	var z := back
	for k in lines.size():
		var line: Array = lines[k]
		width = -gap
		var depth := 0.0
		for p in line:
			width += p["size"][0] + gap
			depth = maxf(depth, p["size"][1])
		var x := -width * 0.5
		for p in line:
			var at := Vector3(x - p["min"][0], k * 3.0, 0.0) if on_wall else Vector3(x - p["min"][0], 0, z + p["max"][1])
			_place(p, at)
			x += p["size"][0] + gap
		size.x = maxf(size.x, width)
		z += depth + 0.3
	size.y = z - back - 0.3
	return size


## A group's items packed in rows under 0.6 m.
func _cluster(list: Array) -> Node3D:
	var c := Node3D.new()
	shown.add_child(c)
	var x := 0.0
	var z := 0.0
	var depth := 0.0
	var width := 0.0
	for p in list:
		var held: bool = p["place"] == "hand"  # laid down, the muzzle to the right
		var foot := Vector2(p["size"][1], p["size"][2]) if held else Vector2(p["size"][0], p["size"][1])
		if x > 0 and x + foot.x > 0.6:
			x = 0.0
			z += depth + GAP
			depth = 0.0
		if held:
			var n := _place(p, Vector3(x + p["max"][1], 0, z + p["max"][2]), c)
			n.rotation.y = PI / 2
			_lay(n, p)
		else:
			_place(p, Vector3(x - p["min"][0], 0, z + p["max"][1]), c)
		x += foot.x + GAP
		width = maxf(width, x - GAP)
		depth = maxf(depth, foot.y)
	c.set_meta("size", Vector2(width, z + depth))
	return c


func _clear() -> void:
	wall.transform = Transform3D(Basis.IDENTITY, Vector3(0, 3, -0.002))
	sun.rotation_degrees = Vector3(-55, -30, 0)
	for n in shown.get_children():
		shown.remove_child(n)
		n.queue_free()


func _gd(a: Array) -> Vector3:
	return Vector3(a[0], a[2], -a[1])


func _size(s: Array) -> String:
	return "%.2f x %.2f x %.2f" % [s[0], s[2], s[1]]


func _process(delta: float) -> void:
	for n in shown.get_children():
		if n.has_meta("stop"):
			var player := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player.current_animation_position >= n.get_meta("stop"):
				player.pause()
				n.remove_meta("stop")
		elif n is OmniLight3D and n.get_meta("flicker", false) and not still:
			n.light_energy = n.get_meta("energy") * (0.15 if randf() < 0.06 else 1.0)
	if walker:
		pitch = clampf(pitch, -1.4, 1.4)
		cam.position = walker.position + Vector3(0, EYE, 0)
		cam.rotation = Vector3(pitch, yaw, 0)
		cam.near = 0.02 if ranging else 0.05
		cam.far = 60.0
		if ranging:
			_viewmodel(delta)
		return
	idle += delta
	if not still and idle > 3.0:
		yaw += delta * 0.25
	pitch = clampf(pitch, -1.45, rise)
	var b := Basis.from_euler(Vector3(pitch, yaw, 0))
	cam.position = target + b * Vector3(0, 0, dist)
	cam.look_at(target)
	cam.near = dist * 0.02
	cam.far = dist * 20 + 20


func _unhandled_input(event: InputEvent) -> void:
	if walker:
		if event is InputEventMouseMotion:
			yaw -= event.relative.x * 0.004
			pitch -= event.relative.y * 0.004
			sway = (sway - event.relative * 0.00015).limit_length(0.02)
		elif event is InputEventMouseButton:
			if event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # again, after the browser let it go
			if ranging:
				match event.button_index:
					MOUSE_BUTTON_LEFT:
						firing = event.pressed
					MOUSE_BUTTON_RIGHT:
						aiming = event.pressed
					MOUSE_BUTTON_WHEEL_UP when event.pressed:
						equip(guns.find(gun) - 1)
					MOUSE_BUTTON_WHEEL_DOWN when event.pressed:
						equip(guns.find(gun) + 1)
		elif event is InputEventKey and event.pressed and not event.echo:
			if ranging and event.keycode >= KEY_1 and event.keycode <= KEY_9 and event.keycode - KEY_1 < guns.size():
				equip(event.keycode - KEY_1)
			match event.keycode:
				KEY_ESCAPE:
					if ranging:
						firing_range(false)
					else:
						walk(false)
				KEY_R:
					if ranging:
						reload()
				KEY_E:
					use()
				KEY_F:
					torch.visible = not torch.visible
				KEY_P:
					set_psx(not psx_on)
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.008
		pitch -= event.relative.y * 0.008
		idle = 0.0
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist *= 1.1
		idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				show_prop(index - 1)
			KEY_RIGHT:
				show_prop(index + 1)
			KEY_A:
				toggle_all()
			KEY_L:
				if not level.is_empty():
					show_level()
			KEY_W:
				walk(true)
			KEY_G:
				firing_range(true)
			KEY_P:
				set_psx(not psx_on)
			KEY_1, KEY_2, KEY_3:
				var anims: Array = props[index]["anims"]
				var k: int = event.keycode - KEY_1
				if not all_view and k < anims.size():
					play(anims[k]["name"])
