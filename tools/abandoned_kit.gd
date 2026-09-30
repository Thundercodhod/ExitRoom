extends RefCounted

# Shared, editable low-poly furnishings and metre-scaled aged materials.
static func aged(name: String, texture: String, tint: Color, tile_metres: float, grime: float = 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.resource_name = name
	m.shader = load("res://assets/shaders/aged_surface.gdshader")
	for pair in [["albedo_map", "albedo"], ["normal_map_tex", "normal"], ["roughness_map", "roughness"]]:
		m.set_shader_parameter(pair[0], load("res://assets/textures/abandoned/%s_%s.jpg" % [texture, pair[1]]))
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("metres_per_tile", tile_metres)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("normal_strength", 0.24)
	return m

static func plain(name: String, tint: Color, rough: float = 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.albedo_color = tint
	m.roughness = rough
	return m

static func palette() -> Dictionary:
	return {
		"wall": aged("DampLimePlaster", "worn_mossy_plasterwall", Color(0.84,0.83,0.77), 4.6, 0.27),
		"floor": aged("DustyGreyConcrete", "concrete_floor", Color(0.65,0.69,0.70), 3.2, 0.24),
		"ceiling": aged("AgedCeiling", "painted_plaster_wall", Color(0.68,0.66,0.60), 3.2, 0.26),
		"wood": aged("DarkWeatheredOak", "weathered_planks", Color(0.87,0.80,0.68), 2.0, 0.14),
		"paint": aged("FadedSagePaint", "plastered_wall_02", Color(0.38,0.43,0.37), 2.8, 0.40),
		"metal": plain("TarnishedIron",Color(0.19,0.18,0.15)),
		"ceramic": plain("StainedIvoryCeramic",Color(0.62,0.59,0.48),0.72),
		"bottle": plain("DustyGreenBottle",Color(0.15,0.23,0.19),0.5),
		"paper": plain("YellowedPaper",Color(0.66,0.59,0.42)),
		"rust": plain("WornTerracotta",Color(0.29,0.15,0.09)),
		"dark": plain("RecessShadow",Color(0.065,0.061,0.047)),
		"blue": aged("FadedBlueEnamel", "plastered_wall_02", Color(0.18,0.30,0.34),2.0,0.25)
	}

static func add(parent: Node, item: Node, owner_root: Node) -> void:
	parent.add_child(item)
	item.owner = owner_root

static func node(parent: Node, name: String, pos: Vector3, owner_root: Node) -> Node3D:
	var n := Node3D.new()
	n.name=name
	n.position=pos
	add(parent,n,owner_root)
	return n

static func box(parent: Node, name: String, pos: Vector3, size: Vector3, material: Material, owner_root: Node, solid: bool = false) -> Node3D:
	var n: Node3D = StaticBody3D.new() if solid else Node3D.new()
	n.name=name
	n.position=pos
	add(parent,n,owner_root)
	var v := MeshInstance3D.new()
	v.name="Mesh"
	var mesh := BoxMesh.new()
	mesh.size=size
	v.mesh=mesh
	v.material_override=material
	add(n,v,owner_root)
	if solid:
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size=size
		c.shape=s
		add(n,c,owner_root)
	return n

static func cylinder(parent: Node, name: String, pos: Vector3, bottom: float, top: float, height: float, material: Material, owner_root: Node, segments: int = 12) -> MeshInstance3D:
	var v := MeshInstance3D.new()
	v.name=name
	v.position=pos
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=bottom
	mesh.top_radius=top
	mesh.height=height
	mesh.radial_segments=segments
	mesh.rings=1
	v.mesh=mesh
	v.material_override=material
	add(parent,v,owner_root)
	return v

static func bottle(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node, height: float = 0.36) -> void:
	var n := node(parent,"Bottle",pos,owner_root)
	cylinder(n,"Body",Vector3(0,height*0.29,0),height*0.18,height*0.17,height*0.58,p.bottle,owner_root)
	cylinder(n,"Shoulder",Vector3(0,height*0.65,0),height*0.17,height*0.065,height*0.15,p.bottle,owner_root)
	cylinder(n,"Neck",Vector3(0,height*0.86,0),height*0.065,height*0.065,height*0.28,p.bottle,owner_root)
	cylinder(n,"Lip",Vector3(0,height,0),height*0.075,height*0.075,height*0.035,p.bottle,owner_root)

static func books(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node, count: int = 5) -> void:
	for i in count:
		var h := 0.20+0.035*(i%3)
		var at := pos+Vector3(i*0.075,h/2,0)
		box(parent,"BookCover",at,Vector3(0.055,h,0.17),p.wood if i%2==0 else p.paint,owner_root)
		box(parent,"BookSpineBand",at+Vector3(0,h*0.28,0.087),Vector3(0.058,0.012,0.005),p.paper,owner_root)

static func chair(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node, angle: float = 0.0) -> void:
	var n:=node(parent,"TimberChair",pos,owner_root)
	n.rotation.y=angle
	box(n,"Seat",Vector3(0,0.47,0),Vector3(0.48,0.055,0.47),p.wood,owner_root)
	for x in [-0.18,0.18]:
		for z in [-0.17,0.17]:
			box(n,"Leg",Vector3(x,0.225,z),Vector3(0.045,0.45,0.045),p.wood,owner_root)
		box(n,"BackUpright",Vector3(x,0.79,0.18),Vector3(0.045,0.63,0.045),p.wood,owner_root)
		box(n,"Stretcher",Vector3(x,0.20,0),Vector3(0.03,0.035,0.37),p.wood,owner_root)
	for y in [0.75,0.86,0.98]:
		box(n,"BackSlat",Vector3(0,y,0.185),Vector3(0.40,0.07,0.035),p.wood,owner_root)

static func cabinet(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node, angle: float = 0.0) -> void:
	var n:=node(parent,"OldTimberDresser",pos,owner_root)
	n.rotation.y=angle
	box(n,"CabinetCollision",Vector3(0,0.65,0),Vector3(1.65,1.25,0.52),p.wood,owner_root,true)
	box(n,"DarkShelfBack",Vector3(0,1.86,-0.20),Vector3(1.62,1.2,0.08),p.dark,owner_root)
	for x in [-0.81,0.81]:
		box(n,"SideStile",Vector3(x,1.29,0),Vector3(0.095,2.57,0.56),p.wood,owner_root)
	for y in [1.25,1.66,2.06,2.52]:
		box(n,"Shelf",Vector3(0,y,0),Vector3(1.75,0.065,0.62),p.wood,owner_root)
	for x in [-0.39,0.39]:
		box(n,"DoorPanel",Vector3(x,0.57,0.29),Vector3(0.71,0.88,0.045),p.wood,owner_root)
		box(n,"DoorInset",Vector3(x,0.57,0.318),Vector3(0.57,0.71,0.014),p.paint,owner_root)
		box(n,"Handle",Vector3(x+0.24,0.85,0.35),Vector3(0.035,0.11,0.04),p.metal,owner_root)
		box(n,"Drawer",Vector3(x,1.10,0.29),Vector3(0.71,0.16,0.06),p.wood,owner_root)
		box(n,"DrawerPull",Vector3(x,1.10,0.35),Vector3(0.12,0.025,0.025),p.metal,owner_root)
	books(n,Vector3(-0.67,2.095,0.07),p,owner_root,6)
	books(n,Vector3(0.18,1.695,0.07),p,owner_root,4)
	bottle(n,Vector3(-0.5,1.29,0.08),p,owner_root,0.30)
	bottle(n,Vector3(0.25,1.29,0.10),p,owner_root,0.34)

static func shelf(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node, width: float = 2.4) -> void:
	var n:=node(parent,"WallShelf",pos,owner_root)
	box(n,"ShelfPlank",Vector3.ZERO,Vector3(width,0.055,0.35),p.wood,owner_root)
	for x in [-width*0.35,width*0.35]:
		box(n,"Bracket",Vector3(x,-0.16,-0.09),Vector3(0.055,0.29,0.07),p.metal,owner_root)
	books(n,Vector3(-width*0.4,0.03,0),p,owner_root,4)
	bottle(n,Vector3(0.12,0.03,0),p,owner_root,0.33)
	bottle(n,Vector3(0.42,0.03,0),p,owner_root,0.26)

static func tableware(parent: Node, pos: Vector3, p: Dictionary, owner_root: Node) -> void:
	var n:=node(parent,"AbandonedTableware",pos,owner_root)
	for i in 3:
		cylinder(n,"StackedPlate",Vector3(0,0.015+i*0.022,0),0.13,0.16,0.018,p.ceramic,owner_root,16)
	bottle(n,Vector3(0.4,0,0.1),p,owner_root,0.40)
	cylinder(n,"Cup",Vector3(-0.30,0.055,0.05),0.045,0.055,0.11,p.ceramic,owner_root)
	cylinder(n,"CupDarkOpening",Vector3(-0.30,0.111,0.05),0.043,0.043,0.003,p.dark,owner_root)
	cylinder(n,"ClayCookingPot",Vector3(-0.65,0.10,-0.03),0.13,0.16,0.20,p.rust,owner_root)
	cylinder(n,"PotLid",Vector3(-0.65,0.21,-0.03),0.18,0.08,0.045,p.rust,owner_root)
	cylinder(n,"PotHandle",Vector3(-0.65,0.245,-0.03),0.03,0.025,0.035,p.metal,owner_root)
