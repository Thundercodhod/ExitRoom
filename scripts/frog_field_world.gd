extends RefCounted
## Environment only. The friend's frog model and scripts are never modified.

var world: Node3D
var mats := {}

func material(color: Color, texture := "") -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if not texture.is_empty():
		m.albedo_texture = load(texture)
		m.uv1_triplanar = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m

func box(parent: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = title
	n.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	parent.add_child(n)
	if solid:
		var body := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		c.shape = s
		body.add_child(c)
		n.add_child(body)
	return n

func light(parent: Node3D, title: String, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var n := OmniLight3D.new()
	n.name = title
	n.position = pos
	n.light_color = color
	n.light_energy = energy
	n.omni_range = radius
	n.shadow_enabled = true
	parent.add_child(n)
	return n

func label(parent: Node3D, title: String, value: String, pos: Vector3, size := 40) -> Label3D:
	var n := Label3D.new()
	n.name = title
	n.text = value
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.003
	n.outline_size = 0
	parent.add_child(n)
	return n

func action(n: Node, key: String, hint: String) -> void:
	n.set_meta("action", key)
	n.set_meta("hint", hint)

func build(parent: Node3D) -> Node3D:
	world = Node3D.new()
	world.name = "World"
	parent.add_child(world)
	mats.wood = material(Color(.42,.34,.24), "res://assets/textures/weathered_planks.jpg")
	mats.wall = material(Color(.72,.72,.61), "res://Room407/assets/textures/plastered_wall_albedo.jpg")
	mats.dark = material(Color(.055,.069,.064))
	mats.metal = material(Color(.27,.32,.3))
	mats.dirt = material(Color(.22,.23,.14), "res://assets/textures/worn_concrete_floor.jpg")
	var env := WorldEnvironment.new()
	env.name = "Night"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(.024,.042,.052)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(.46,.59,.62)
	e.ambient_light_energy = .75
	e.fog_enabled = true
	e.fog_light_color = Color(.06,.085,.09)
	e.fog_density = .013
	env.environment = e
	world.add_child(env)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.rotation_degrees = Vector3(-48,-25,0)
	moon.light_color = Color(.57,.71,.78)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	world.add_child(moon)
	box(world,"Earth",Vector3(0,-.2,-18),Vector3(90,.4,100),mats.dirt)
	box(world,"Road",Vector3(0,.009,9),Vector3(90,.025,7),material(Color(.34,.35,.33),"res://assets/textures/asphalt_06.jpg"),false)
	for x in range(-42,43,8):
		box(world,"RoadMark",Vector3(x,.027,9),Vector3(3,.008,.1),material(Color(.63,.6,.4)),false)
	box(world,"Footpath",Vector3(0,.012,-11),Vector3(2.5,.03,40),mats.dirt,false)
	# Invisible perimeter prevents wandering off the map; the field stays open.
	for x in [-44,44]:
		var b := box(world,"Boundary",Vector3(x,3,-18),Vector3(1,6,100),mats.dark)
		b.visible = false
	for z in [-67,31]:
		var b := box(world,"Boundary",Vector3(0,3,z),Vector3(90,6,1),mats.dark)
		b.visible = false
	grass()
	house()
	car()
	box(world,"UtilityCabinet",Vector3(-4,1,14),Vector3(1,2,.6),mats.metal)
	label(world,"CabinetWarning","HIGH VOLTAGE",Vector3(-4,1.5,13.68),22).rotation.y = PI
	for x in [-17,19]:
		box(world,"TelephonePole",Vector3(x,4.5,14),Vector3(.22,9,.22),mats.wood)
		box(world,"Crossbar",Vector3(x,8.3,14),Vector3(2.3,.15,.15),mats.wood,false)
	return world

func grass() -> void:
	# Use the supplied shader directly, bypassing demo materials with old res:// paths.
	var m := ShaderMaterial.new()
	m.shader = load("res://Grass/assets/BinbunGrass/src/shader/grass.gdshader")
	m.set_shader_parameter("shape_atlas",load("res://Grass/assets/BinbunGrass/src/texture/basic/grass_basic_atlas.png"))
	m.set_shader_parameter("shape_texture",load("res://Grass/assets/BinbunGrass/src/texture/basic/grass_basic_02.png"))
	m.set_shader_parameter("use_atlas",true)
	m.set_shader_parameter("billboard",true)
	m.set_shader_parameter("alpha_mode",2)
	m.set_shader_parameter("alpha_cut_start",.35)
	m.set_shader_parameter("alpha_cut_end",.65)
	m.set_shader_parameter("wind_velocity",Vector2(1.8,.65))
	var noise := NoiseTexture2D.new()
	noise.width = 128
	noise.height = 128
	noise.seamless = true
	var source := FastNoiseLite.new()
	source.seed = 407
	source.frequency = .035
	noise.noise = source
	m.set_shader_parameter("noise_texture",noise)
	m.set_shader_parameter("wind_texture",noise)
	var palette := GradientTexture1D.new()
	palette.gradient = Gradient.new()
	palette.gradient.colors = PackedColorArray([Color(.03,.055,.025),Color(.12,.18,.065),Color(.28,.3,.13)])
	palette.gradient.offsets = PackedFloat32Array([0,.65,1])
	m.set_shader_parameter("color_gradient",palette)
	var blade := QuadMesh.new()
	blade.size = Vector2(.8,.72)
	blade.center_offset = Vector3(0,.36,0)
	blade.subdivide_depth = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 407
	var patches := Node3D.new()
	patches.name = "BinbunGrass"
	world.add_child(patches)
	# Small batches allow distance culling. Clear the road, footpath and house yard.
	for tx in range(-4,4):
		for tz in range(-6,3):
			var transforms: Array[Transform3D] = []
			for i in 650:
				var x := tx*10.0+rng.randf_range(0,10)
				var z := tz*10.0+rng.randf_range(0,10)
				if (z>4.5 and z<13.5) or (absf(x)<1.65 and z>-29 and z<7) or (absf(x)<6.7 and z< -28 and z> -46):
					continue
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.75,1.35)),Vector3(x,0,z)))
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = blade
			mm.instance_count = transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i,transforms[i])
			var patch := MultiMeshInstance3D.new()
			patch.name = "Grass_%d_%d" % [tx+4,tz+6]
			patch.multimesh = mm
			patch.material_override = m
			patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			patch.visibility_range_end = 62
			patches.add_child(patch)

func house() -> void:
	var h := Node3D.new()
	h.name = "House"
	world.add_child(h)
	box(h,"Floor",Vector3(0,-.06,-35),Vector3(10,.12,10),mats.wood)
	box(h,"Ceiling",Vector3(0,3.05,-35),Vector3(10,.16,10),mats.wood)
	# Front doorway, living room window on the east wall, kitchen on the west.
	for side in [-1,1]:
		box(h,"FrontWall",Vector3(side*3,1.5,-30),Vector3(4,3,.2),mats.wall)
	box(h,"DoorLintel",Vector3(0,2.7,-30),Vector3(2,.6,.2),mats.wall)
	box(h,"WestWall",Vector3(-5,1.5,-35),Vector3(.2,3,10),mats.wall)
	box(h,"EastFront",Vector3(5,1.5,-31.5),Vector3(.2,3,3),mats.wall)
	box(h,"EastBack",Vector3(5,1.5,-37.5),Vector3(.2,3,5),mats.wall)
	box(h,"WindowLow",Vector3(5,.45,-34),Vector3(.2,.9,2),mats.wall)
	box(h,"WindowHigh",Vector3(5,2.75,-34),Vector3(.2,.5,2),mats.wall)
	for z in [-35,-34,-33]:
		box(h,"WindowFrame",Vector3(5,1.65,z),Vector3(.18,1.6,.045),mats.wood,false)
	var glass := material(Color(.18,.25,.22,.12))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box(h,"Glass",Vector3(5,1.7,-34),Vector3(.04,1.65,2),glass)
	for x in [-4,4]:
		box(h,"BackWall",Vector3(x,1.5,-40),Vector3(2,3,.2),mats.wall)
	# Clone the actual 407 room before adding it to the tree, so its story never runs.
	var reference := (load("res://Room407/main.tscn") as PackedScene).instantiate()
	var room := reference.get_node("Room407") as Node3D
	reference.remove_child(room)
	reference.free()
	room.name = "Bedroom407"
	room.position = Vector3(0,0,-40)
	strip_actions(room)
	h.add_child(room)
	# Remove only this copy's old note/boxes/body. Preserve its furniture layout.
	for title in ["Note","Openbox","Closedbox","SleepingDouble","PictureFrame"]:
		var old := room.get_node_or_null(title)
		if old: old.free()
	var pane := room.get_node("NightWindow") as MeshInstance3D
	pane.material_override = glass
	room.get_node("Lamp").rotation.z = .14
	var scorch := material(Color(.09,.07,.045))
	for i in 12:
		var a := -1.0 + i*.2
		box(room,"BurnCrescent",Vector3(-.65+cos(a)*.13,.562,-4.95+sin(a)*.13),Vector3(.032,.003,.032),scorch,false)
	box(room,"ChargerCable",Vector3(-.73,.08,-5.6),Vector3(.02,.02,.65),mats.dark,false)
	box(room,"ChargerTape",Vector3(-.73,.085,-5.5),Vector3(.04,.025,.09),material(Color(.72,.7,.58)),false)
	box(room,"BlanketMound",Vector3(-1.7,.57,-4.25),Vector3(.55,.24,1.25),material(Color(.28,.3,.25)),false)
	var door := Node3D.new()
	door.name = "BedroomDoor"
	door.position = Vector3(-.64,0,-40)
	door.rotation.y = -PI/2
	h.add_child(door)
	box(door,"DoorLeaf",Vector3(.64,1.17,0),Vector3(1.28,2.34,.08),mats.wood)
	label(door,"Number407","407",Vector3(.64,1.85,-.051),70).rotation.y = PI
	var jump := box(room,"JumpStarter",Vector3(.85,.38,-2.7),Vector3(.44,.55,.22),material(Color(.45,.19,.06)))
	action(jump,"battery","หยิบเครื่องจั๊มพ์แบตเตอรี่")
	box(jump,"Handle",Vector3(0,.32,0),Vector3(.24,.08,.07),mats.dark,false)
	box(jump,"StatusLED",Vector3(.1,.12,.115),Vector3(.035,.035,.01),material(Color(.2,.9,.25)),false)
	label(jump,"PowerLabel","12V",Vector3(0,0,.12),25)
	box(h,"NoteTable",Vector3(3.85,.76,-34),Vector3(1.55,.12,1.15),mats.wood)
	for x in [3.25,4.45]:
		for z in [-34.4,-33.6]: box(h,"TableLeg",Vector3(x,.38,z),Vector3(.08,.76,.08),mats.wood)
	var note := box(h,"WarningNote",Vector3(3.8,.84,-33.9),Vector3(.42,.02,.55),material(Color(.85,.8,.62)))
	action(note,"note","อ่านกระดาษบนโต๊ะ")
	for i in 5: box(note,"Ink",Vector3(0,.012,-.17+i*.07),Vector3(.3,.003,.015),mats.dark,false)
	box(h,"KitchenCounter",Vector3(-4.2,.48,-37.6),Vector3(1.3,.96,3.5),mats.wall)
	box(h,"Worktop",Vector3(-4.2,1,-37.6),Vector3(1.4,.09,3.6),mats.dark)
	box(h,"Fridge",Vector3(-4.2,1,-32),Vector3(1.25,2,1.2),mats.wall)
	box(h,"FridgeHandle",Vector3(-3.54,1.2,-31.7),Vector3(.07,.6,.07),mats.dark,false)
	box(h,"SofaSeat",Vector3(-2,.36,-33),Vector3(2.4,.7,.9),material(Color(.26,.29,.22)))
	box(h,"SofaBack",Vector3(-2,.8,-33.4),Vector3(2.4,1,.2),mats.wood)
	light(h,"PorchLamp",Vector3(0,2.5,-29.3),Color(1,.71,.4),2.5,12)
	light(h,"LivingLamp",Vector3(1.4,2.65,-33.7),Color(1,.76,.48),2.2,9)
	light(h,"KitchenLamp",Vector3(-3,2.5,-37),Color(.86,.83,.61),1.2,6)
	# Low fence frames the approach without trapping the player.
	for x in range(-7,8):
		if abs(x)<2: continue
		box(h,"FencePost",Vector3(x,.55,-27.8),Vector3(.1,1.1,.1),mats.wood)
	for side in [-1,1]:
		for y in [.35,.8]: box(h,"FenceRail",Vector3(side*4.5,y,-27.8),Vector3(5,.08,.08),mats.wood,false)
	for x in [-2.7,2.7]:
		var roof := box(h,"Roof",Vector3(x,3.5,-38),Vector3(6,.18,17),mats.dark,false)
		roof.rotation.z = -.18*signf(x)

func strip_actions(n: Node) -> void:
	if n.has_meta("action"): n.remove_meta("action")
	if n.has_meta("hint"): n.remove_meta("hint")
	for c in n.get_children(): strip_actions(c)

func car() -> void:
	var c := Node3D.new()
	c.name = "Car"
	c.position = Vector3(2.4,0,4)
	world.add_child(c)
	var paint := material(Color(.29,.38,.35))
	box(c,"Chassis",Vector3(0,.52,0),Vector3(2,.52,4.4),paint)
	var hood := box(c,"Hood",Vector3(0,.94,-1.5),Vector3(1.96,.3,1.35),paint)
	action(hood,"car","ลองสตาร์ตรถ")
	box(c,"Trunk",Vector3(0,.9,1.65),Vector3(2,.35,1),paint)
	box(c,"Roof",Vector3(0,1.95,.15),Vector3(2,.12,2.5),paint,false)
	for x in [-.96,.96]:
		box(c,"Door",Vector3(x,.96,.1),Vector3(.08,.5,2.3),paint)
		for z in [-1,1.3]: box(c,"Pillar",Vector3(x,1.55,z),Vector3(.09,.8,.09),paint,false)
		for z in [-1.45,1.5]:
			var tire := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = .38
			mesh.bottom_radius = .38
			mesh.height = .2
			mesh.radial_segments = 12
			tire.mesh = mesh
			tire.material_override = mats.dark
			tire.position = Vector3(x,.4,z)
			tire.rotation.z = PI/2
			c.add_child(tire)
	for x in [-.48,.48]:
		box(c,"Seat",Vector3(x,.78,.1),Vector3(.76,.2,.82),mats.dark,false)
		box(c,"SeatBack",Vector3(x,1.15,.52),Vector3(.76,.85,.2),mats.dark,false)
	box(c,"Dashboard",Vector3(0,1.12,-.91),Vector3(1.8,.26,.36),mats.dark,false)
	label(c,"DashboardText","00   |   N   |   12V",Vector3(-.4,1.28,-.71),18)
	for x in [-.72,.72]:
		var lamp := light(c,"Hazard",Vector3(x,.95,-2.2),Color(1,.38,.06),1.4,4)
		lamp.add_to_group("frog_hazards",true)
		box(c,"Headlight",Vector3(x,.94,-2.2),Vector3(.43,.2,.03),material(Color(.9,.83,.55)),false)
	light(c,"CabinLight",Vector3(0,1.8,-.4),Color(.65,.8,.66),.7,2.7)

