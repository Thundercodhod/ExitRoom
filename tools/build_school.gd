extends SceneTree
const Kit = preload("res://tools/abandoned_kit.gd")
const ImportedHouse = preload("res://tools/imported_house.gd")

# Generates an editable, modular low-poly school scene from named Godot nodes.

var scene_root: Node3D
var mat: Dictionary = {}
var furnishings: Dictionary = {}


func _initialize() -> void:
	call_deferred("build")


func attach(parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = scene_root


func group(parent: Node, name: String, where: Vector3 = Vector3.ZERO) -> Node3D:
	var item := Node3D.new()
	item.name = name
	item.position = where
	attach(parent, item)
	return item


func surface(name: String, tint: Color, texture_name: String = "", tile: float = 1.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = name
	result.albedo_color = tint
	result.roughness = 0.93
	if texture_name != "":
		result.albedo_texture = load("res://assets/textures/%s" % texture_name)
		result.uv1_triplanar = true
		result.uv1_scale = Vector3(tile, tile, tile)
	mat[name] = result
	return result


func block(parent: Node, name: String, where: Vector3, size: Vector3, material: Material, solid: bool = false, angle: float = 0.0) -> Node3D:
	var anchor: Node3D = StaticBody3D.new() if solid else Node3D.new()
	anchor.name = name
	anchor.position = where
	anchor.rotation.z = angle
	if solid:
		(anchor as StaticBody3D).collision_layer = 1
	attach(parent, anchor)
	var display := MeshInstance3D.new()
	display.name = "Visual"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	display.mesh = box_mesh
	display.material_override = material
	attach(anchor, display)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		attach(anchor, collision)
	return anchor


func text3d(parent: Node, name: String, words: String, where: Vector3, tint: Color, font_size: int = 44) -> void:
	var sign := Label3D.new()
	sign.name = name
	sign.text = words
	sign.position = where
	sign.modulate = tint
	sign.font_size = font_size
	sign.pixel_size = 0.004
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	attach(parent, sign)


func light(parent: Node, name: String, where: Vector3, energy: float, radius: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.name = name
	lamp.position = where
	lamp.light_color = Color(0.90, 0.86, 0.70)
	lamp.light_energy = energy
	lamp.omni_range = radius
	lamp.shadow_enabled = false
	attach(parent, lamp)


func chair(parent: Node, name: String, where: Vector3) -> void:
	var seat := group(parent, name, where)
	Kit.chair(seat,Vector3.ZERO,furnishings,scene_root)


func desk(parent: Node, name: String, where: Vector3) -> void:
	var item := group(parent, name, where)
	block(item, "Top", Vector3(0, 0.78, 0), Vector3(1.25, 0.10, 0.7), mat.OldWood)
	block(item,"FrontApron",Vector3(0,0.62,-0.27),Vector3(1.14,0.20,0.06),mat.OldWood)
	block(item,"DeskShelf",Vector3(0,0.52,0),Vector3(1.12,0.045,0.6),mat.OldWood)
	for x in [-0.49, 0.49]:
		for z in [-0.25, 0.25]:
			block(item, "Leg_%s_%s" % [x, z], Vector3(x, 0.37, z), Vector3(0.06, 0.74, 0.06), mat.DarkMetal)


func classroom(parent: Node, name: String, side: int, center_z: float, variant: int) -> void:
	var room := group(parent, name, Vector3(side * 10.1, 0, center_z))
	block(room, "ClassroomFloor", Vector3(0, 0.015, 0), Vector3(12.0, 0.03, 12.8), mat.ConcreteFloor, true)
	# Outer walls and partitions make each bay visibly separate.
	block(room, "OuterWall", Vector3(side * 5.88, 1.8, 0), Vector3(0.25, 3.6, 12.8), mat.GreyPlaster, true)
	block(room, "FarPartition", Vector3(0, 1.8, -6.25), Vector3(12.0, 3.6, 0.23), mat.GreyPlaster, true)
	block(room, "NearPartition", Vector3(0, 1.8, 6.25), Vector3(12.0, 3.6, 0.23), mat.GreyPlaster, true)
	block(room,"PaintedLowerWall",Vector3(0,0.56,-6.11),Vector3(11.9,1.08,0.04),furnishings.paint)
	block(room,"DadoRail",Vector3(0,1.12,-6.07),Vector3(11.9,0.055,0.06),mat.OldWood)
	block(room,"FloorSkirting",Vector3(0,0.11,-6.07),Vector3(11.9,0.18,0.055),mat.OldWood)
	var inner_x := -side * 5.7
	block(room, "HallWallNorth", Vector3(inner_x, 1.8, -4.4), Vector3(0.22, 3.6, 3.4), mat.GreyPlaster, true)
	block(room, "HallWallSouth", Vector3(inner_x, 1.8, 4.4), Vector3(0.22, 3.6, 3.4), mat.GreyPlaster, true)
	block(room, "HallDoorLintel", Vector3(inner_x, 3.10, 0), Vector3(0.22, 1.0, 5.4), mat.GreyPlaster, true)
	block(room, "BoardFrame", Vector3(0, 2.05, -6.04), Vector3(4.9, 1.65, 0.10), mat.OldWood)
	block(room, "Chalkboard", Vector3(0, 2.05, -5.975), Vector3(4.7, 1.45, 0.035), mat.Chalkboard)
	block(room,"ChalkTray",Vector3(0,1.25,-5.91),Vector3(4.9,0.065,0.15),mat.OldWood)
	for row in 3:
		for col in 3:
			var x := -3.0 + col * 2.5
			if col == 1 and side == 1:
				x=0.4
			var z := -2.5 + row * 2.45
			desk(room, "Desk_%d_%d" % [row, col], Vector3(x, 0, z))
			chair(room, "Chair_%d_%d" % [row, col], Vector3(x+0.10*(row%2), 0.04, z + 0.70))
	Kit.cabinet(room,Vector3(4.5,0.03,-5.55),furnishings,scene_root)
	Kit.books(room,Vector3(-3.3,0.835,-2.5),furnishings,scene_root,4)
	var practical:=OmniLight3D.new()
	practical.name="WindowBounceAndFurnitureShadows"
	practical.position=Vector3(side*3.9,2.8,-1.7)
	practical.light_color=Color(0.90,0.84,0.68)
	practical.light_energy=1.2
	practical.omni_range=10.0
	practical.shadow_enabled=true
	practical.shadow_bias=0.06
	attach(room,practical)
	if variant == 1:
		block(room, "OverturnedShelf", Vector3(3.8, 0.8, 1.2), Vector3(0.65, 1.5, 3.8), mat.OldWood, true, 0.4)
	if variant == 2:
		block(room, "TeacherCabinet", Vector3(3.9, 1.1, -4.8), Vector3(1.9, 2.2, 0.55), mat.OldWood, true)
	for window in 2:
		var z := -3.0 + window * 6.0
		block(room, "BoardedWindow_%d" % window, Vector3(side * 6.07, 2.6, z), Vector3(0.09, 1.7, 2.2), mat.DarkGlass)
		block(room, "BrokenBoard_%d" % window, Vector3(side * 6.17, 2.5, z), Vector3(0.10, 0.21, 2.5), mat.OldWood, false, 0.11)


func build() -> void:
	scene_root = Node3D.new()
	scene_root.name = "AbandonedSchool"
	scene_root.set_script(load("res://scripts/abandoned_school.gd"))
	surface("GreyPlaster", Color(0.79, 0.83, 0.84), "worn_plaster_wall.jpg", 0.36)
	surface("ConcreteFloor", Color(0.69, 0.72, 0.72), "worn_concrete_floor.jpg", 0.36)
	surface("ConcretePillar", Color(0.64, 0.68, 0.70), "worn_concrete_floor.jpg", 0.36)
	surface("OldWood", Color(0.54, 0.49, 0.43), "weathered_planks.jpg", 0.50)
	surface("DarkMetal", Color(0.16, 0.20, 0.23))
	surface("SeatBlue", Color(0.15, 0.30, 0.54))
	surface("Chalkboard", Color(0.055, 0.13, 0.13))
	surface("DarkGlass", Color(0.11, 0.15, 0.17))
	surface("SchoolYard", Color(0.28, 0.31, 0.29), "asphalt_06.jpg", 0.36)
	surface("Paper", Color(0.86, 0.79, 0.60))
	surface("SignalGreen", Color(0.16, 0.72, 0.51))
	furnishings=Kit.palette()
	var source_materials:=ImportedHouse.school_materials()
	for key in source_materials:
		furnishings[key]=source_materials[key]
	mat.GreyPlaster=furnishings.wall
	mat.ConcreteFloor=furnishings.floor
	mat.ConcretePillar=furnishings.ceiling
	mat.OldWood=furnishings.wood
	mat.SeatBlue=furnishings.blue
	(mat.SignalGreen as StandardMaterial3D).emission_enabled = true
	(mat.SignalGreen as StandardMaterial3D).emission = Color(0.16, 0.72, 0.51)
	(mat.SignalGreen as StandardMaterial3D).emission_energy_multiplier = 1.3

	var world := WorldEnvironment.new()
	world.name = "ColdSchoolAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.065, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.69, 0.64)
	environment.ambient_light_energy = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.11, 0.16, 0.18)
	environment.fog_density = 0.014
	world.environment = environment
	attach(scene_root, world)
	var sky_light := DirectionalLight3D.new()
	sky_light.name = "OvercastSky"
	sky_light.rotation_degrees = Vector3(-38, 35, 0)
	sky_light.light_color = Color(0.67, 0.78, 0.84)
	sky_light.light_energy = 0.05
	sky_light.shadow_enabled = false
	attach(scene_root, sky_light)

	var grounds := group(scene_root, "01_CourtyardAndMainHall")
	block(grounds, "WalkableCourtyard", Vector3(0, -0.13, 11), Vector3(54, 0.26, 35), mat.SchoolYard, true)
	block(grounds, "EntireSchoolGroundFloor", Vector3(0, -0.13, -75), Vector3(33, 0.26, 148), mat.ConcreteFloor, true)
	block(grounds, "MainHallFloor", Vector3(0, 0.02, -72), Vector3(7.5, 0.05, 129), mat.ConcreteFloor)
	# Facade: broad entrance opening, repeated columns, battered concrete beams.
	for side in [-1, 1]:
		block(grounds, "EntryFacade_%d" % side, Vector3(side * 9.3, 3.0, -7.0), Vector3(14.0, 6.0, 0.36), mat.GreyPlaster, true)
		block(grounds, "EntryColumn_%d" % side, Vector3(side * 2.3, 3.0, -7.0), Vector3(0.5, 6.0, 0.52), mat.ConcretePillar, true)
	block(grounds, "EntryBeam", Vector3(0, 5.55, -7.0), Vector3(5.0, 0.9, 0.52), mat.ConcretePillar, true)
	text3d(grounds, "FadedSchoolName", "โรงเรียนเก่า", Vector3(0, 6.0, -6.7), Color(0.8, 0.84, 0.82), 62)
	for bay in 9:
		var z := -17.0 - bay * 14.0
		for side in [-1, 1]:
			block(grounds, "HallPillar_%d_%d" % [bay, side], Vector3(side * 3.8, 1.8, z), Vector3(0.40, 3.6, 0.48), mat.ConcretePillar, true)
			block(grounds, "HallTopBeam_%d_%d" % [bay, side], Vector3(side * 10.0, 3.44, z), Vector3(12.8, 0.26, 0.42), mat.ConcretePillar)
		block(grounds, "CeilingBay_%02d" % bay, Vector3(0, 3.70, z - 5.4), Vector3(31.5, 0.22, 14.0), mat.ConcretePillar)
		block(grounds, "FlickeringFluorescent_%02d" % bay, Vector3(0, 3.54, z - 4.2), Vector3(0.16, 0.08, 1.4), mat.Paper)
		light(grounds, "ColdHallLight_%02d" % bay, Vector3(0, 3.20, z - 4.2), 0.72, 10.0)
	# Pillars and a raised balcony give the hall the layered depth of the reference.
	for side in [-1, 1]:
		block(grounds, "UpperWalkway_%d" % side, Vector3(side * 6.7, 4.15, -71.0), Vector3(5.5, 0.22, 124.0), mat.ConcreteFloor)
		block(grounds, "BalconyRailTop_%d" % side, Vector3(side * 4.05, 5.2, -71.0), Vector3(0.11, 0.1, 124.0), mat.DarkMetal)
		for rail in 18:
			block(grounds, "BalconyRailPost_%d_%02d" % [side, rail], Vector3(side * 4.05, 4.65, -12.0 - rail * 7.0), Vector3(0.08, 1.05, 0.08), mat.DarkMetal)
		block(grounds, "LongOuterWall_%d" % side, Vector3(side * 16.25, 3.0, -72.0), Vector3(0.32, 6.0, 129.0), mat.GreyPlaster, true)
	# Blue waiting chairs near the front hall echo the reference without copying its layout.
	for row in 2:
		for col in 4:
			chair(grounds, "WaitingSeat_%d_%d" % [row, col], Vector3(-2.6 + col * 1.65, 0, -14.0 - row * 1.7))

	var rooms := group(scene_root, "02_ClassroomsAndClues")
	for row in 7:
		var z := -25.0 - row * 14.0
		classroom(rooms, "ClassroomWest_%02d" % row, -1, z, row % 3)
		classroom(rooms, "ClassroomEast_%02d" % row, 1, z, (row + 1) % 3)
	var diary := group(rooms, "MaysDiary", Vector3(10.5, 0.86, -53.0))
	block(diary, "OldDiary", Vector3.ZERO, Vector3(0.32, 0.06, 0.26), mat.Paper)
	text3d(diary, "DiaryHint", "สมุดของเมย์", Vector3(0, 0.42, 0), Color(1.0, 0.92, 0.68), 32)
	desk(rooms,"ArchiveKeyTable",Vector3(-10.6,0,-99.5))
	var key := group(rooms, "ArchiveKey", Vector3(-10.6, 0.86, -99.5))
	block(key, "KeyBody", Vector3.ZERO, Vector3(0.28, 0.05, 0.10), mat.SignalGreen)
	text3d(key, "KeyHint", "กุญแจห้องประกาศ", Vector3(0, 0.45, 0), Color(0.78, 1.0, 0.83), 30)

	var end_room := group(scene_root, "03_AnnouncementRoomAndExit")
	block(end_room, "EndWallLeft", Vector3(-11.0, 2.8, -139), Vector3(11, 5.6, 0.32), mat.GreyPlaster, true)
	block(end_room, "EndWallRight", Vector3(11.0, 2.8, -139), Vector3(11, 5.6, 0.32), mat.GreyPlaster, true)
	block(end_room, "RadioControlDesk", Vector3(0, 0.9, -133.0), Vector3(2.7, 1.0, 0.9), mat.OldWood, true)
	var radio := group(end_room, "AnnouncementSwitch", Vector3(0, 1.48, -133.0))
	block(radio, "SwitchConsole", Vector3.ZERO, Vector3(0.62, 0.14, 0.42), mat.DarkMetal)
	block(radio, "Indicator", Vector3(0.18, 0.1, 0), Vector3(0.08, 0.04, 0.08), mat.SignalGreen)
	text3d(end_room, "SpeakTheTruth", "ใครเห็นเมย์หลังเลิกเรียน", Vector3(0, 3.8, -138.6), Color(0.9, 0.93, 0.88), 45)
	var door := group(end_room, "ExitToGarden", Vector3(0, 0, -140.0))
	block(door, "DarkDoor", Vector3(0, 1.35, 0), Vector3(2.4, 2.7, 0.18), mat.DarkMetal)
	block(door, "GreenExitLight", Vector3(0, 2.9, 0.15), Vector3(1.6, 0.18, 0.16), mat.SignalGreen)
	light(door, "ExitGlow", Vector3(0, 2.4, 1.0), 1.1, 5.5)

	var overview := Camera3D.new()
	overview.name = "EditorOverviewCamera"
	overview.position = Vector3(37, 28, 27)
	overview.rotation_degrees = Vector3(-25, 42, 0)
	overview.far = 260.0
	attach(scene_root, overview)
	var packed := PackedScene.new()
	var result := packed.pack(scene_root)
	if result != OK:
		push_error("School scene pack failed: %s" % result)
		quit(1)
		return
	result = ResourceSaver.save(packed, "res://abandoned_school.tscn")
	if result != OK:
		push_error("School scene save failed: %s" % result)
		quit(1)
		return
	print("Built editable abandoned school scene at res://abandoned_school.tscn")
	scene_root.free()
	quit(0)
