extends Node
## A room to try the pack's textures in: floor, walls, a trim along their foot, ceiling, a door with
## a sign over it, two windows and decals, each surface cycled through the textures that fit it,
## or all of them set at once from textures.json's "sets". With PSX Look installed
## (res://addons/psx_look/), it shows through it.
## Keys: up / down (or 1 to 7) pick a surface, left / right its texture, Space the next set,
## X the decals, P PSX Look; WASD to walk, drag to look, Shift to hurry.

const PSX_LOOK := "res://addons/psx_look/"
const W := 4.5  # the room, x -2.25..2.25, z -3..3, a metre a tile
const D := 6.0
const H := 2.7
const TRIM := 1.0  # a trim texture is a wall's lower metre
const EYE := 1.6
const SURFACES := ["floor", "wall", "trim", "ceiling", "door", "window", "sign"]

## Hides the panel, for the store captures.
@export var still := false

var dir: String
var textures: Array
var sets: Dictionary
var set_names: Array
var set_index := -1
var chosen := {}  # surface -> texture name, "" for none
var surface := 0
var world := Node3D.new()
var meshes := {}  # surface -> [MeshInstance3D]
var decals := Node3D.new()
var lamp := OmniLight3D.new()
var cam := Camera3D.new()
var env := Environment.new()
var yaw := 0.0
var pitch := -0.08
var psx_screen: Control
var psx_on := false
var ui := CanvasLayer.new()
var swatch := TextureRect.new()
var title := Label.new()
var info := Label.new()
var psx_button := Button.new()


func _ready() -> void:
	dir = (get_script() as Script).resource_path.get_base_dir().get_base_dir()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/textures.json"))
	textures = data["textures"]
	sets = data.get("sets", {})
	set_names = sets.keys()
	add_child(world)
	_stage()
	world.add_child(decals)
	world.add_child(cam)
	cam.current = true
	cam.fov = 70
	cam.near = 0.05
	look(Vector3(0, EYE, 2.6), 0.0, -0.08)
	_ui()
	if ResourceLoader.exists(PSX_LOOK + "psx_screen.gd"):
		psx_screen = load(PSX_LOOK + "psx_screen.gd").new()
		psx_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(psx_screen)
		move_child(psx_screen, 0)
	else:
		psx_button.hide()
	for s in SURFACES:
		var fits := fitting(s)
		chosen[s] = fits[0] if fits and s != "trim" else ""
	if set_names:
		show_set(set_names[0])
	else:
		_refresh()
	if psx_screen:
		set_psx(true)


func _stage() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.03)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	lamp.position = Vector3(0, H - 0.4, 0)
	lamp.omni_range = 11.0
	lamp.omni_attenuation = 0.8
	lamp.light_energy = 1.6
	lamp.shadow_enabled = true
	world.add_child(lamp)
	var hx := W / 2
	var hz := D / 2
	_add("floor", _quad(Vector3(-hx, 0, -hz), Vector3(W, 0, 0), Vector3(0, 0, D), Vector2(W, D)))
	_add("ceiling", _quad(Vector3(-hx, H, hz), Vector3(W, 0, 0), Vector3(0, 0, -D), Vector2(W, D)))
	# each wall from its left end, seen from inside, along its length
	for w in [[Vector3(-hx, 0, -hz), Vector3(W, 0, 0)], [Vector3(hx, 0, -hz), Vector3(0, 0, D)],
			[Vector3(hx, 0, hz), Vector3(-W, 0, 0)], [Vector3(-hx, 0, hz), Vector3(0, 0, -D)]]:
		var along: Vector3 = w[1]
		_add("wall", _quad(w[0] + Vector3(0, H, 0), along, Vector3(0, -(H - TRIM), 0), Vector2(along.length(), H - TRIM)))
		_add("wall_low", _quad(w[0] + Vector3(0, TRIM, 0), along, Vector3(0, -TRIM, 0), Vector2(along.length(), TRIM)))
	_add("door", _quad(Vector3(-0.5, 2.0, -hz + 0.01), Vector3(1, 0, 0), Vector3(0, -2, 0), Vector2.ONE))
	_add("window", _quad(Vector3(-hx + 0.01, 2.2, 0.5), Vector3(0, 0, -1), Vector3(0, -1, 0), Vector2.ONE))
	_add("window", _quad(Vector3(hx - 0.01, 2.2, -0.5), Vector3(0, 0, 1), Vector3(0, -1, 0), Vector2.ONE))
	_add("sign", MeshInstance3D.new())  # sized to its texture in _refresh


## A quad from its top-left corner `a` along `u` (to the right) and `v` (down), seen from the side
## v x u points to, its UV running to `uv`: a metre a tile. Cut in half-metre cells, as a PS1 level
## was, so PSX Look's affine textures swim rather than fold.
func _quad(a: Vector3, u: Vector3, v: Vector3, uv: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(v.cross(u).normalized())
	var nu := maxi(1, ceili(u.length() / 0.5))
	var nv := maxi(1, ceili(v.length() / 0.5))
	for j in nv:
		for i in nu:
			for c in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var fu := float(i + c[0]) / nu
				var fv := float(j + c[1]) / nv
				st.set_uv(Vector2(uv.x * fu, uv.y * fv))
				st.add_vertex(a + u * fu + v * fv)
	return st.commit()


func _add(s: String, mesh: Variant) -> void:
	var mi: MeshInstance3D = mesh if mesh is MeshInstance3D else MeshInstance3D.new()
	if mesh is Mesh:
		mi.mesh = mesh
	world.add_child(mi)
	if s not in meshes:
		meshes[s] = []
	meshes[s].append(mi)


## The pack's textures that fit a surface, by name: any seamless one on the floor, walls and
## ceiling; the trims; the doors, windows and signs.
func fitting(s: String) -> Array:
	var out := []
	for t in textures:
		var n: String = t["name"]
		var ok: bool = t["tiling"] == "both" if s in ["floor", "wall", "ceiling"] \
			else t["tiling"] == "across" if s == "trim" \
			else t["category"] == "sign" if s == "sign" \
			else t["category"] == "door_window" and n.begins_with(s)
		if ok:
			out.append(n)
	return out


func material(name: String) -> StandardMaterial3D:
	return load("%s/materials/%s.tres" % [dir, name])


func texture(name: String) -> Dictionary:
	for t in textures:
		if t["name"] == name:
			return t
	return {}


## Dresses the room as textures.json's set `name`: a texture per surface ("" or none for none; no
## ceiling is the open sky), "decals" as [texture, surface, at, metres wide] and a "light" colour.
## A decal is on the floor or ceiling at [x, z], on the back wall at [x, height], on the left or
## right at [z, height].
func show_set(name: String) -> void:
	set_index = set_names.find(name)
	var s: Dictionary = sets[name]
	for k in SURFACES:
		var t: Variant = s.get(k, "")
		chosen[k] = t if t is String and (t == "" or not texture(t).is_empty()) else ""
	for n in decals.get_children():
		n.queue_free()
	for i in s.get("decals", []).size():
		var d: Array = s["decals"][i]
		if not texture(d[0]).is_empty():
			_decal(d[0], d[1], Vector2(d[2][0], d[2][1]), d[3], i)
	lamp.light_color = Color(s.get("light", "ffffff"))
	env.ambient_light_color = lamp.light_color.lerp(Color(0.6, 0.6, 0.7), 0.5)
	env.background_color = Color(0.05, 0.06, 0.1) if chosen["ceiling"] == "" else Color(0.02, 0.02, 0.04)
	_refresh()


func _decal(name: String, on: String, at: Vector2, size: float, i: int) -> void:
	var t := texture(name)
	var wh: Vector2 = Vector2(t["size"][0], t["size"][1]) / float(t["size"][0]) * size
	var lift := 0.012 + 0.002 * i  # off its surface, and each off the one before
	var hx := W / 2
	var hz := D / 2
	var q: ArrayMesh
	match on:
		"floor":
			q = _quad(Vector3(at.x - wh.x / 2, lift, at.y - wh.y / 2), Vector3(wh.x, 0, 0), Vector3(0, 0, wh.y), Vector2.ONE)
		"back":
			q = _quad(Vector3(at.x - wh.x / 2, at.y + wh.y / 2, -hz + lift), Vector3(wh.x, 0, 0), Vector3(0, -wh.y, 0), Vector2.ONE)
		"right":
			q = _quad(Vector3(hx - lift, at.y + wh.y / 2, at.x - wh.x / 2), Vector3(0, 0, wh.x), Vector3(0, -wh.y, 0), Vector2.ONE)
		"left":
			q = _quad(Vector3(-hx + lift, at.y + wh.y / 2, at.x + wh.x / 2), Vector3(0, 0, -wh.x), Vector3(0, -wh.y, 0), Vector2.ONE)
		"ceiling":
			q = _quad(Vector3(at.x - wh.x / 2, H - lift, at.y + wh.y / 2), Vector3(wh.x, 0, 0), Vector3(0, 0, -wh.y), Vector2.ONE)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.set_meta("source", material(name))
	decals.add_child(mi)
	_paint(mi)


## Puts each surface's chosen texture on it: its material, or PSX Look's version of it.
func _refresh() -> void:
	var trim: String = chosen["trim"]
	for s in meshes:
		var name: String = trim if s == "wall_low" and trim != "" else chosen["wall" if s == "wall_low" else s]
		for mi in meshes[s]:
			mi.visible = name != ""
			if name != "":
				mi.set_meta("source", material(name))
				_paint(mi)
	var sign: String = chosen["sign"]
	if sign != "":
		var t := texture(sign)
		var wh := Vector2(t["size"][0], t["size"][1]) / 128.0
		var q := _quad(Vector3(-wh.x / 2, 2.06 + wh.y, -D / 2 + 0.01), Vector3(wh.x, 0, 0), Vector3(0, -wh.y, 0), Vector2.ONE)
		meshes["sign"][0].mesh = q
	lamp.position.y = H - 0.4 if chosen["ceiling"] != "" else 4.5
	_label()


func _paint(mi: MeshInstance3D) -> void:
	mi.material_override = mi.get_meta("source")
	if psx_on:
		load(PSX_LOOK + "psx.gd").convert(mi)


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
	for mi in world.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("source"):
			_paint(mi)


## Steps the picked surface's texture on by `by` through those that fit it; a trim can be none.
func step(by: int) -> void:
	var s: String = SURFACES[surface]
	var fits := fitting(s)
	if s in ["trim", "ceiling", "sign", "window"]:
		fits.push_front("")
	if fits.is_empty():
		return
	chosen[s] = fits[posmod(fits.find(chosen[s]) + by, fits.size())]
	_refresh()


func pick(i: int) -> void:
	surface = posmod(i, SURFACES.size())
	_label()


func next_set() -> void:
	if set_names:
		show_set(set_names[posmod(set_index + 1, set_names.size())])


## Stands the camera at `at`, turned `turn` from looking down -z and tilted `tilt`, in radians.
func look(at: Vector3, turn: float, tilt: float) -> void:
	cam.position = at
	yaw = turn
	pitch = tilt


func _ui() -> void:
	add_child(ui)
	var top := HBoxContainer.new()
	top.position = Vector2(20, 16)
	top.add_theme_constant_override("separation", 14)
	ui.add_child(top)
	swatch.custom_minimum_size = Vector2(72, 72)
	swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swatch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	top.add_child(swatch)
	var words := VBoxContainer.new()
	top.add_child(words)
	for l in [title, info]:
		l.add_theme_color_override("font_shadow_color", Color.BLACK)
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		words.add_child(l)
	title.add_theme_font_size_override("font_size", 24)
	info.add_theme_font_size_override("font_size", 15)
	info.modulate = Color(0.85, 0.82, 0.75)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.position.y -= 16
	ui.add_child(bar)
	_button(bar, "Surface", func() -> void: pick(surface + 1))
	_button(bar, "<", step.bind(-1))
	_button(bar, ">", step.bind(1))
	if sets.size() > 1:
		_button(bar, "Next set", next_set)
	_button(bar, "Decals", func() -> void: decals.visible = not decals.visible)
	psx_button.text = "PSX Look"
	psx_button.toggle_mode = true
	psx_button.focus_mode = Control.FOCUS_NONE
	psx_button.toggled.connect(set_psx)
	bar.add_child(psx_button)
	var hint := Label.new()
	hint.text = "WASD to walk, drag to look\nup / down: surface, left / right: texture\nspace: next set, X: decals, P: PSX Look"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.position += Vector2(-16, 16)
	ui.add_child(hint)
	ui.visible = not still


func _button(box: Container, text: String, pressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 44
	b.pressed.connect(pressed)
	box.add_child(b)


func _label() -> void:
	var s: String = SURFACES[surface]
	var name: String = chosen.get(s, "")
	title.text = "%s: %s" % [s.capitalize(), name if name != "" else "none"]
	var t := texture(name)
	info.text = ("%s  |  %d x %d px" % [t["category"].replace("_", " & "), t["size"][0], t["size"][1]]) if t else ""
	if set_index >= 0:
		info.text += ("  |  " if info.text else "") + "set: " + set_names[set_index]
	swatch.texture = material(name).albedo_texture if name != "" else null


func _process(delta: float) -> void:
	var move := Vector3(_key(KEY_D) - _key(KEY_A), 0, _key(KEY_S) - _key(KEY_W))
	var speed := 3.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.8
	cam.position += Basis(Vector3.UP, yaw) * move.limit_length(1.0) * speed * delta
	cam.position.x = clampf(cam.position.x, -W / 2 + 0.3, W / 2 - 0.3)
	cam.position.z = clampf(cam.position.z, -D / 2 + 0.3, D / 2 - 0.3)
	pitch = clampf(pitch, -1.4, 1.4)
	cam.rotation = Vector3(pitch, yaw, 0)


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		yaw -= event.relative.x * 0.006
		pitch -= event.relative.y * 0.006
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				step(-1)
			KEY_RIGHT:
				step(1)
			KEY_UP:
				pick(surface - 1)
			KEY_DOWN:
				pick(surface + 1)
			KEY_SPACE:
				if not event.echo:
					next_set()
			KEY_X:
				if not event.echo:
					decals.visible = not decals.visible
			KEY_P:
				if not event.echo:
					set_psx(not psx_on)
			_:
				var n: int = event.keycode - KEY_1
				if n >= 0 and n < SURFACES.size():
					pick(n)
