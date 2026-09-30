extends SceneTree
const Kit = preload("res://tools/abandoned_kit.gd")
const ImportedHouse = preload("res://tools/imported_house.gd")

# Run once from the project directory with:
# godot --headless --path . --script res://tools/build_prologue.gd
# The saved scene contains editable nodes; this is only its layout generator.

var scene_root: Node3D
var materials: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	call_deferred("build")


func material(name: String, color: Color, roughness: float = 0.9, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.resource_name = name
	result.albedo_color = color
	result.roughness = roughness
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	materials[name] = result
	return result


func apply_texture(name: String, file_name: String, repeat_count: float = 2.0) -> void:
	var surface := materials[name] as StandardMaterial3D
	var image := load("res://assets/textures/%s" % file_name) as Texture2D
	if image == null:
		push_error("Texture could not be loaded: %s" % file_name)
		return
	surface.albedo_texture = image
	surface.uv1_triplanar = true
	surface.uv1_scale = Vector3.ONE * 0.35
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func attach(parent: Node, item: Node) -> void:
	parent.add_child(item)
	item.owner = scene_root


func group(parent: Node, name: String, position: Vector3 = Vector3.ZERO) -> Node3D:
	var item := Node3D.new()
	item.name = name
	item.position = position
	attach(parent, item)
	return item


func box(parent: Node, name: String, position: Vector3, size: Vector3, surface: Material, solid: bool = false, angle: float = 0.0) -> Node3D:
	var anchor: Node3D
	if solid:
		anchor = StaticBody3D.new()
		anchor.collision_layer = 1
	else:
		anchor = Node3D.new()
	anchor.name = name
	anchor.position = position
	anchor.rotation.z = angle
	attach(parent, anchor)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = surface
	attach(anchor, visual)
	if solid:
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		attach(anchor, collision)
	return anchor


func cylinder(parent: Node, name: String, position: Vector3, radius: float, height: float, surface: Material, solid: bool = false) -> Node3D:
	var anchor: Node3D
	if solid:
		anchor = StaticBody3D.new()
		anchor.collision_layer = 1
	else:
		anchor = Node3D.new()
	anchor.name = name
	anchor.position = position
	attach(parent, anchor)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	visual.mesh = mesh
	visual.material_override = surface
	attach(anchor, visual)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		attach(anchor, collision)
	return anchor


func sphere(parent: Node, name: String, position: Vector3, scale: Vector3, surface: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = name
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	visual.material_override = surface
	visual.position = position
	visual.scale = scale
	attach(parent, visual)


func label(parent: Node, name: String, words: String, position: Vector3, color: Color, size: int = 48) -> void:
	var item := Label3D.new()
	item.name = name
	item.text = words
	item.position = position
	item.font_size = size
	item.pixel_size = 0.0035
	item.modulate = color
	item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	item.no_depth_test = false
	attach(parent, item)


func omni(parent: Node, name: String, position: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	attach(parent, light)


func make_tree(parent: Node, name: String, position: Vector3, height: float) -> void:
	var tree := group(parent, name, position)
	cylinder(tree, "Trunk", Vector3(0, height * 0.45, 0), 0.22 * height / 5.0, height * 0.9, materials.wood_dark)
	sphere(tree, "CanopyLeft", Vector3(-0.7, height * 0.91, 0), Vector3(1.55, 1.1, 1.5) * height / 5.0, materials.leaves_dark)
	sphere(tree, "CanopyRight", Vector3(0.8, height * 1.0, 0.25), Vector3(1.4, 1.2, 1.4) * height / 5.0, materials.leaves)
	sphere(tree, "CanopyTop", Vector3(0.0, height * 1.14, -0.25), Vector3(1.35, 1.05, 1.35) * height / 5.0, materials.leaves_dark)


func make_house(parent: Node, name: String, position: Vector3, wall: Material, roof: Material, rotation_y: float = 0.0) -> void:
	var house := group(parent, name, position)
	house.rotation.y = rotation_y
	box(house, "RaisedFoundation", Vector3(0, 0.35, 0), Vector3(9.0, 0.7, 7.5), materials.concrete, true)
	box(house, "MainWalls", Vector3(0, 2.25, 0), Vector3(8.7, 3.1, 7.2), wall, true)
	box(house, "RoofLeft", Vector3(-2.35, 4.2, 0), Vector3(5.2, 0.28, 8.5), roof, false, 0.28)
	box(house, "RoofRight", Vector3(2.35, 4.2, 0), Vector3(5.2, 0.28, 8.5), roof, false, -0.28)
	box(house, "FrontDoor", Vector3(0.9, 1.75, 3.66), Vector3(1.35, 2.8, 0.09), materials.wood_dark)
	for index in 2:
		var x := -2.7 if index == 0 else 3.0
		box(house, "WindowFrame_%d" % index, Vector3(x, 2.2, 3.69), Vector3(1.3, 1.3, 0.12), materials.wood_dark)
		box(house, "WindowGlass_%d" % index, Vector3(x, 2.2, 3.77), Vector3(1.05, 1.0, 0.07), materials.window)
	box(house, "PorchStep", Vector3(0.9, 0.12, 4.25), Vector3(2.0, 0.24, 0.95), materials.concrete, true)
	box(house, "WarmDoorLight", Vector3(0.9, 3.35, 3.85), Vector3(0.3, 0.16, 0.16), materials.lamp)
	omni(house, "PorchLight", Vector3(0.9, 3.05, 4.0), Color(1.0, 0.68, 0.36), 0.55, 7.0)


func build() -> void:
	rng.seed = 43274
	scene_root = Node3D.new()
	scene_root.name = "VillagePrologue"
	scene_root.set_script(load("res://scripts/prologue.gd"))
	material("DuskRoad", Color(0.22, 0.215, 0.20))
	material("DirtPath", Color(0.39, 0.31, 0.23))
	material("FieldEarth", Color(0.24, 0.28, 0.18))
	material("FieldWater", Color(0.16, 0.28, 0.29), 0.34)
	material("VergeGrass", Color(0.27, 0.34, 0.20))
	material("Concrete", Color(0.48, 0.48, 0.44))
	material("WeatheredPlaster", Color(0.62, 0.60, 0.50))
	material("WarmPlaster", Color(0.70, 0.62, 0.46))
	material("DarkWood", Color(0.19, 0.13, 0.10))
	material("WoodFloor", Color(0.32, 0.21, 0.15))
	material("RustRedRoof", Color(0.36, 0.19, 0.14))
	material("SlateRoof", Color(0.25, 0.28, 0.29))
	material("DarkLeaves", Color(0.12, 0.23, 0.14))
	material("Leaves", Color(0.21, 0.34, 0.17))
	material("WindowGlass", Color(0.18, 0.24, 0.26), 0.15)
	material("LampWarm", Color(1.0, 0.75, 0.36), 0.3, 2.0)
	material("Cloth", Color(0.42, 0.35, 0.28))
	material("OldRadio", Color(0.22, 0.20, 0.16))
	material("PortalDark", Color(0.025, 0.07, 0.08), 0.2, 0.25)
	material("PortalRim", Color(0.34, 0.67, 0.62), 0.2, 1.8)
	apply_texture("DuskRoad", "asphalt_06.jpg", 2.0)
	apply_texture("Concrete", "worn_concrete_floor.jpg", 2.0)
	apply_texture("WeatheredPlaster", "worn_plaster_wall.jpg", 2.0)
	apply_texture("WarmPlaster", "worn_plaster_wall.jpg", 2.0)
	apply_texture("WoodFloor", "weathered_planks.jpg", 4.0)
	materials.road = materials.DuskRoad
	materials.dirt = materials.DirtPath
	materials.field = materials.FieldEarth
	materials.water = materials.FieldWater
	materials.grass = materials.VergeGrass
	materials.concrete = materials.Concrete
	materials.plaster = materials.WeatheredPlaster
	materials.plaster_warm = materials.WarmPlaster
	materials.wood_dark = materials.DarkWood
	materials.wood_floor = materials.WoodFloor
	materials.roof_red = materials.RustRedRoof
	materials.roof_slate = materials.SlateRoof
	materials.leaves_dark = materials.DarkLeaves
	materials.leaves = materials.Leaves
	materials.window = materials.WindowGlass
	materials.lamp = materials.LampWarm
	materials.fabric = materials.Cloth
	materials.radio = materials.OldRadio
	materials.portal_dark = materials.PortalDark
	materials.portal_rim = materials.PortalRim
	var aged := Kit.palette()
	materials.plaster = aged.wall
	materials.plaster_warm = aged.wall
	materials.concrete = aged.floor
	materials.wood_dark = aged.wood
	materials.wood_floor = aged.wood

	var world := WorldEnvironment.new()
	world.name = "DuskyVillageAtmosphere"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.065, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.51, 0.61, 0.70)
	environment.ambient_light_energy = 0.14
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.17, 0.20)
	environment.fog_density = 0.015
	world.environment = environment
	attach(scene_root, world)
	var moon := DirectionalLight3D.new()
	moon.name = "DuskSkyLight"
	moon.rotation_degrees = Vector3(-38, -26, 0)
	moon.light_color = Color(0.75, 0.81, 0.88)
	moon.light_energy = 0.24
	moon.shadow_enabled = true
	moon.light_cull_mask=1
	attach(scene_root, moon)

	var ground := group(scene_root, "01_LandAndRoad")
	box(ground, "EntireWalkableTerrain", Vector3(0, -0.24, -90), Vector3(110, 0.48, 225), materials.grass, true)
	for segment in 18:
		box(ground, "RoadSection_%02d" % segment, Vector3(0, 0.02, 10.0 - segment * 12.0), Vector3(8.5, 0.05, 12.1), materials.road)
	box(ground, "WestShoulder", Vector3(-5.2, 0.035, -88), Vector3(1.9, 0.06, 211), materials.dirt)
	box(ground, "EastShoulder", Vector3(5.2, 0.035, -88), Vector3(1.9, 0.06, 211), materials.dirt)
	for index in 18:
		box(ground, "WornCenterLine_%02d" % index, Vector3(0, 0.055, 10 - index * 11.5), Vector3(0.12, 0.012, 4.0), materials.concrete)
	box(ground, "PathToGrandmaHouse", Vector3(14.8, 0.07, -131), Vector3(23, 0.08, 4.8), materials.dirt)
	box(ground, "BackyardPath", Vector3(23, 0.065, -163), Vector3(23, 0.08, 4.0), materials.dirt)
	for side in [-1, 1]:
		box(ground, "PaddyField_%d" % side, Vector3(side * 31, -0.035, -93), Vector3(39, 0.03, 185), materials.field)
		for row in 9:
			box(ground, "RiceWater_%d_%d" % [side, row], Vector3(side * 31, -0.015, -13 - row * 20), Vector3(35, 0.015, 2.2), materials.water)
	# A narrow drainage canal breaks up the long walk. The road remains a bridge.
	box(ground, "BridgeDeck", Vector3(0, 0.1, -74), Vector3(9.2, 0.2, 7.0), materials.concrete, true)
	for side in [-1, 1]:
		box(ground, "BridgeRailing_%d" % side, Vector3(side * 4.5, 0.75, -74), Vector3(0.18, 1.4, 7.0), materials.wood_dark, true)
		box(ground, "CanalWater_%d" % side, Vector3(side * 28, -0.015, -74), Vector3(45, 0.02, 4.0), materials.water)

	var structures := group(scene_root, "02_HousesAndVillageLandmarks")
	make_house(structures, "HouseNearBusStop", Vector3(-18, 0, -19), materials.plaster_warm, materials.roof_red, PI / 2)
	make_house(structures, "HouseByField", Vector3(18, 0, -47), materials.plaster, materials.roof_slate, -PI / 2)
	make_house(structures, "HouseBeyondBridge", Vector3(-20, 0, -100), materials.plaster, materials.roof_red, PI / 2)
	make_house(structures, "HouseNearGrandma", Vector3(20, 0, -115), materials.plaster_warm, materials.roof_slate, -PI / 2)
	var shelter := group(structures, "BusStopAtVillageEdge", Vector3(-6.2, 0, 8.5))
	box(shelter, "Platform", Vector3(0, 0.12, 0), Vector3(5.5, 0.24, 3.1), materials.concrete, true)
	for x in [-2.2, 2.2]:
		box(shelter, "Post_%s" % x, Vector3(x, 1.55, -1.2), Vector3(0.14, 3.1, 0.14), materials.wood_dark, true)
	box(shelter, "WeatheredRoof", Vector3(0, 3.18, 0), Vector3(5.8, 0.2, 3.6), materials.roof_slate)
	box(shelter, "BenchSeat", Vector3(0, 0.55, -0.7), Vector3(3.4, 0.18, 0.55), materials.wood_dark, true)
	label(shelter, "BusStopSign", "บ้านเก่า", Vector3(0, 2.34, -1.36), Color(0.94, 0.88, 0.69))
	ImportedHouse.populate(structures,scene_root)
	box(structures,"HouseApproach",Vector3(24,0.015,-136),Vector3(3.2,0.03,10),materials.dirt)
	box(structures,"HouseSidePath",Vector3(35.8,0.015,-151),Vector3(3.8,0.03,35),materials.dirt)

	var roadside := group(scene_root, "03_RoadsideDetails")
	for index in 8:
		var z := 4.0 - index * 27.0
		var pole := group(roadside, "UtilityPole_%02d" % index, Vector3(-8.4, 0, z))
		cylinder(pole, "TimberPole", Vector3(0, 3.8, 0), 0.14, 7.6, materials.wood_dark, true)
		box(pole, "Crossbeam", Vector3(0, 7.1, 0), Vector3(1.8, 0.12, 0.12), materials.wood_dark)
		if index in [0, 2, 5, 6]:
			box(pole, "StreetLamp", Vector3(0.55, 5.7, 0), Vector3(0.42, 0.12, 0.30), materials.lamp)
			omni(pole, "PoolOfWarmLight", Vector3(0.65, 5.5, 0), Color(1, 0.71, 0.42), 1.0, 11.0)
	for index in 36:
		var side := -1 if index % 2 == 0 else 1
		var z := rng.randf_range(-195.0, 12.0)
		var x := side * rng.randf_range(14.0, 48.0)
		if side > 0 and z < -124.0 and z > -177.0 and x < 41.0:
			continue
		make_tree(roadside, "RoadsideTree_%02d" % index, Vector3(x, 0, z), rng.randf_range(4.8, 7.8))
	for index in 58:
		var side := -1 if index % 2 == 0 else 1
		var x := side * rng.randf_range(9.0, 49.0)
		var z := rng.randf_range(-188.0, 8.0)
		if side > 0 and z < -124.0 and z > -177.0 and x < 40.0:
			continue
		box(roadside, "DryRiceTuft_%02d" % index, Vector3(x, 0.3, z), Vector3(0.13, rng.randf_range(0.4, 0.85), 0.13), materials.grass)

	var story := group(scene_root, "04_StoryObjectsAndExit")
	var cassette := group(story, "CassetteInteraction", Vector3(21.8, 0.99, -148.6))
	box(cassette, "CassetteOnTable", Vector3.ZERO, Vector3(0.34, 0.08, 0.23), materials.radio)
	label(cassette, "CassetteText", "เทปของยาย", Vector3(0, 0.55, 0), Color(1, 0.88, 0.58), 36)
	var marble := group(story, "BlueMarbleInteraction", Vector3(35.0, 0.3, -154.0))
	sphere(marble, "LostBlueMarble", Vector3.ZERO, Vector3.ONE * 0.22, materials.portal_rim)
	omni(marble, "MarbleGlimmer", Vector3.ZERO, Color(0.31, 0.84, 0.9), 0.5, 2.5)
	var gate := group(story, "PortalToGardenLobby", Vector3(23.0, 0, -169.5))
	box(gate, "LeftGatePost", Vector3(-1.6, 1.5, 0), Vector3(0.32, 3.0, 0.55), materials.wood_dark, true)
	box(gate, "RightGatePost", Vector3(1.6, 1.5, 0), Vector3(0.32, 3.0, 0.55), materials.wood_dark, true)
	box(gate, "GateLintel", Vector3(0, 3.12, 0), Vector3(3.5, 0.27, 0.55), materials.wood_dark, true)
	box(gate, "DarkOpening", Vector3(0, 1.5, -0.1), Vector3(2.65, 2.9, 0.05), materials.portal_dark)
	box(gate, "StrangeLight", Vector3(0, 2.7, 0.02), Vector3(2.55, 0.04, 0.06), materials.portal_rim)
	omni(gate, "GardenGlow", Vector3(0, 1.8, 0.6), Color(0.47, 0.9, 0.84), 1.2, 7.5)
	label(gate, "FaintMessage", "กลับมารอที่น้ำพุ", Vector3(0, 3.6, 0), Color(0.67, 0.96, 0.86), 38)

	var camera := Camera3D.new()
	camera.name = "EditorOverviewCamera"
	camera.position = Vector3(22, 23, 25)
	camera.rotation_degrees = Vector3(-27, 35, 0)
	camera.far = 350.0
	attach(scene_root, camera)

	var packed := PackedScene.new()
	var pack_result := packed.pack(scene_root)
	if pack_result != OK:
		push_error("Could not pack prologue scene: %s" % pack_result)
		quit(1)
		return
	var save_result := ResourceSaver.save(packed, "res://prologue_village.tscn")
	if save_result != OK:
		push_error("Could not save prologue scene: %s" % save_result)
		quit(1)
		return
	print("Built editable village prologue at res://prologue_village.tscn")
	scene_root.free()
	quit(0)
