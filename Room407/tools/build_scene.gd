extends SceneTree

var scene_root: Node3D
var mats := {}

func _initialize() -> void:
	call_deferred("build")

func material(name: String, file: String, tint:=Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name=name
	m.albedo_texture=load("res://Room407/assets/textures/"+file)
	m.albedo_color=tint
	m.roughness=.9
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar=true
	m.uv1_scale=Vector3.ONE*.7
	mats[name]=m
	return m

func box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material, solid:=true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name=name
	var mesh := BoxMesh.new()
	mesh.size=size
	n.mesh=mesh
	n.material_override=mat
	n.position=pos
	parent.add_child(n)
	if solid:
		var b := StaticBody3D.new()
		n.add_child(b)
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size=size
		c.shape=s
		b.add_child(c)
	return n

func asset(parent: Node3D, file: String, pos: Vector3, angle:=0.0, solid:=true) -> Node3D:
	var n := (load("res://Room407/assets/models/"+file+".glb") as PackedScene).instantiate()
	# Store editable children explicitly, without also retaining an inherited instance.
	n.scene_file_path=""
	n.name=file.to_pascal_case()
	n.position=pos
	n.rotation.y=deg_to_rad(angle)
	parent.add_child(n)
	if solid: collision(n)
	return n

func collision(n: Node) -> void:
	if n is MeshInstance3D: n.create_trimesh_collision()
	for c in n.get_children():
		if not c is StaticBody3D: collision(c)

func label(parent: Node3D, value: String, pos: Vector3, size:=42) -> Label3D:
	var l := Label3D.new()
	l.text=value
	l.font_size=size
	l.pixel_size=.003
	l.position=pos
	l.modulate=Color(.87,.82,.64)
	l.outline_size=0
	parent.add_child(l)
	return l

func light(parent: Node3D,pos: Vector3,color: Color,energy: float,radius: float) -> OmniLight3D:
	var l:=OmniLight3D.new()
	l.position=pos
	l.light_color=color
	l.light_energy=energy
	l.omni_range=radius
	l.omni_attenuation=1.25
	l.shadow_enabled=true
	parent.add_child(l)
	return l

func build() -> void:
	scene_root=Node3D.new()
	scene_root.name="Room407"
	get_root().add_child(scene_root)
	var wood=material("Oak","wood_table_001_albedo.jpg",Color(.67,.54,.41))
	material("Wall","wallpaper.jpg",Color(.7,.73,.7))
	material("Plaster","plastered_wall_albedo.jpg",Color(.7,.72,.71))
	material("Floor","apartment_floor.jpg",Color(.72,.61,.48))
	material("Rug","rug.jpeg" if FileAccess.file_exists("res://Room407/assets/textures/rug.jpeg") else "rug.jpg")
	var env:=WorldEnvironment.new()
	env.name="WorldEnvironment"
	var e:=Environment.new()
	e.background_mode=Environment.BG_COLOR
	e.background_color=Color(.02,.027,.042)
	e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color=Color(.42,.51,.66)
	e.ambient_light_energy=.3
	e.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	e.fog_enabled=true
	e.fog_light_color=Color(.1,.13,.17)
	e.fog_density=.008
	env.environment=e
	scene_root.add_child(env)
	var corridor:=Node3D.new()
	corridor.name="Corridor"
	scene_root.add_child(corridor)
	box(corridor,"Floor",Vector3(0,-.12,1.5),Vector3(17,.24,3.3),mats.Floor)
	box(corridor,"BackWall",Vector3(0,1.45,3),Vector3(17,2.9,.2),mats.Wall)
	box(corridor,"Ceiling",Vector3(0,2.95,1.5),Vector3(17,.15,3.3),mats.Plaster)
	for x in [-8.5,8.5]:box(corridor,"EndWall",Vector3(x,1.45,1.5),Vector3(.2,2.9,3),mats.Plaster)
	box(corridor,"FrontCentralWall",Vector3(0,1.45,0),Vector3(2,2.9,.18),mats.Wall)
	for x in [-7.7,7.7]:box(corridor,"FrontEnd",Vector3(x,1.45,0),Vector3(1.4,2.9,.18),mats.Wall)
	box(corridor,"Skirting",Vector3(0,.1,2.86),Vector3(17,.2,.05),wood,false)
	for x in [-6.0,0.0,6.0]:
		asset(corridor,"ceiling_light",Vector3(x,2.78,1.5),0,false)
		var l=light(corridor,Vector3(x,2.5,1.5),Color(1,.72,.43),.8,5.5)
		l.name="HallLight"+str(int(x+6))
	label(corridor,"4 F   /   EAST WING",Vector3(-7,2.1,2.86),32).rotation.y=PI
	for x in [-4.0,4.0]: make_room(x,406 if x<0 else 407)
	var door406=make_door(-4,406)
	door406.rotation.y=deg_to_rad(-96)
	make_door(4,407)
	var hidden_wall=box(scene_root,"Wall407",Vector3(4,1.45,0),Vector3(1.55,2.9,.2),mats.Wall)
	hidden_wall.set_meta("action","wall")
	hidden_wall.set_meta("hint","สำรวจผนัง")
	for i in range(3):asset(corridor,"closedbox",Vector3(-7.9+.4*(i%2),0 if i<2 else .5,2.4),i*12)
	var figure=asset(scene_root,"male_animated",Vector3(7.4,0,1.65),90,false)
	figure.name="HallFigure"
	figure.visible=false
	var player:=CharacterBody3D.new()
	player.name="Player"
	player.position=Vector3(-6.3,.03,1.5)
	player.rotation.y=.65
	scene_root.add_child(player)
	player.set_script(load("res://Room407/scripts/player.gd"))
	scene_root.set_script(load("res://Room407/scripts/story.gd"))
	own(scene_root)
	var packed:=PackedScene.new()
	packed.pack(scene_root)
	ResourceSaver.save(packed,"res://Room407/main.tscn")
	print("SCENE_BUILT")
	quit()

func make_room(x: float, number: int) -> void:
	var room:=Node3D.new()
	room.name="Room"+str(number)
	room.position.x=x
	scene_root.add_child(room)
	box(room,"Floor",Vector3(0,-.1,-3),Vector3(6,.2,6),mats.Floor)
	box(room,"Ceiling",Vector3(0,2.95,-3),Vector3(6,.15,6),mats.Plaster)
	for side in [-1,1]:
		box(room,"SideWall",Vector3(side*3,1.45,-3),Vector3(.16,2.9,6),mats.Wall)
		box(room,"Skirting",Vector3(side*2.9,.1,-3),Vector3(.06,.2,6),mats.Oak,false)
		box(room,"DoorSide",Vector3(side*1.85,1.45,0),Vector3(2.3,2.9,.18),mats.Wall)
	box(room,"DoorHeader",Vector3(0,2.65,0),Vector3(1.4,.6,.18),mats.Wall)
	box(room,"WindowLeft",Vector3(-2,1.45,-6),Vector3(2,2.9,.15),mats.Wall)
	box(room,"WindowRight",Vector3(2,1.45,-6),Vector3(2,2.9,.15),mats.Wall)
	box(room,"WindowBottom",Vector3(0,.45,-6),Vector3(2,.9,.15),mats.Wall)
	box(room,"WindowTop",Vector3(0,2.7,-6),Vector3(2,.5,.15),mats.Wall)
	var glass:=StandardMaterial3D.new()
	glass.albedo_color=Color(.065,.12,.19)
	glass.emission_enabled=true
	glass.emission=Color(.03,.055,.095)
	box(room,"NightWindow",Vector3(0,1.68,-6.03),Vector3(2,1.6,.05),glass)
	for a in [-1.0,0.0,1.0]:box(room,"WindowFrame",Vector3(a,1.7,-5.94),Vector3(.055,1.7,.1),mats.Oak,false)
	for h in [.86,1.7,2.54]:box(room,"WindowFrame",Vector3(0,h,-5.94),Vector3(2.1,.05,.1),mats.Oak,false)
	box(room,"WindowSill",Vector3(0,.88,-5.84),Vector3(2.2,.08,.35),mats.Oak,false)
	curtains(room)
	light(room,Vector3(0,2,-5.3),Color(.39,.59,1),.65,5)
	var bed=asset(room,"bed",Vector3(-1.7,0,-4.25),180)
	bed.set_meta("action","bed" if number==406 else "double")
	bed.set_meta("hint","พักผ่อน" if number==406 else "มองคนบนเตียง")
	asset(room,"nightstand",Vector3(-.65,0,-4.95))
	asset(room,"lamp",Vector3(-.65,.55,-4.95),0,false)
	var lamp=light(room,Vector3(-.65,1,-4.95),Color(1,.66,.34),1.4,4.3)
	lamp.name="BedLight"
	asset(room,"wardrobe",Vector3(2.58,0,-4.8),-90)
	asset(room,"dresser",Vector3(2.58,0,-1.8),-90)
	asset(room,"shelf",Vector3(-2.7,1.65,-1.5),90)
	asset(room,"closedbox",Vector3(1.85,0,-4.65),-8)
	var unpack=asset(room,"openbox",Vector3(1.4,0,-1.55),18)
	unpack.set_meta("action","unpack")
	unpack.set_meta("hint","เปิดกล่องย้ายบ้าน")
	box(room,"Rug",Vector3(0,.006,-3),Vector3(1.7,.012,2.4),mats.Rug,false)
	var paper:=StandardMaterial3D.new()
	paper.albedo_color=Color(.8,.77,.62)
	var note=box(room,"Note",Vector3(2.55,1.115,-1.8),Vector3(.21,.015,.29),paper)
	note.set_meta("action","note" if number==406 else "future_note")
	note.set_meta("hint","อ่านเอกสารบนตู้")
	# A small real framed painting, using a texture extracted from the existing licensed house.
	box(room,"PictureFrame",Vector3(0,1.7,-.14),Vector3(.82,.63,.06),mats.Oak,false)
	var art:=StandardMaterial3D.new()
	art.albedo_texture=load("res://Room407/assets/textures/painting.jpg")
	art.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var pic:=MeshInstance3D.new()
	var qm:=QuadMesh.new()
	qm.size=Vector2(.72,.53)
	pic.mesh=qm
	pic.material_override=art
	pic.position=Vector3(0,1.7,-.18)
	pic.rotation.y=PI
	room.add_child(pic)
	if number==407:
		var body=asset(room,"male_sleeping",Vector3(-1.7,.43,-4.25),0,false)
		body.name="SleepingDouble"

func make_door(x: float,number: int) -> Node3D:
	var pivot:=Node3D.new()
	pivot.name="Door"+str(number)
	pivot.position=Vector3(x-.59,0,-.06)
	pivot.set_meta("action","door"+str(number))
	pivot.set_meta("hint","เปิด / ปิดประตู "+str(number))
	scene_root.add_child(pivot)
	asset(pivot,"wooden_door",Vector3(.59,0,0))
	box(pivot,"NumberPlate",Vector3(.59,1.85,.19),Vector3(.38,.17,.025),mats.Oak,false)
	label(pivot,str(number),Vector3(.59,1.85,.21))
	return pivot

func own(n: Node) -> void:
	for c in n.get_children():
		c.owner=scene_root
		own(c)

func curtains(room: Node3D) -> void:
	var fabric:=StandardMaterial3D.new()
	fabric.albedo_texture=load("res://Room407/assets/textures/curtain.jpg")
	fabric.albedo_color=Color(.62,.62,.52)
	fabric.roughness=1
	fabric.cull_mode=BaseMaterial3D.CULL_DISABLED
	for side in [-1,1]:
		var st:=SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(fabric)
		for i in range(10):
			var a:=float(i)/10
			var b:=float(i+1)/10
			var x1:float=side*(.69+a*.55)
			var x2:float=side*(.69+b*.55)
			var z1:=-5.69+sin(a*PI*8)*.055
			var z2:=-5.69+sin(b*PI*8)*.055
			var vertices:=[Vector3(x1,.58,z1),Vector3(x2,.58,z2),Vector3(x2,2.63,z2),Vector3(x1,.58,z1),Vector3(x2,2.63,z2),Vector3(x1,2.63,z1)]
			var uvs:=[Vector2(a,1),Vector2(b,1),Vector2(b,0),Vector2(a,1),Vector2(b,0),Vector2(a,0)]
			for j in range(6):
				st.set_uv(uvs[j])
				st.add_vertex(vertices[j])
		st.generate_normals()
		var mesh:=MeshInstance3D.new()
		mesh.name="Curtain"
		mesh.mesh=st.commit()
		room.add_child(mesh)
	box(room,"CurtainRail",Vector3(0,2.65,-5.7),Vector3(2.65,.035,.035),mats.Oak,false)
