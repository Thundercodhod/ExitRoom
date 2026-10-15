extends SceneTree
## The current Level 06 art builder. Writes only levels/06_dream_field/scenes/world.tscn.
const Terrain=preload("res://levels/06_dream_field/scripts/dream_field_terrain.gd")
var world:Node3D
var stone:StandardMaterial3D
var bark:StandardMaterial3D
var foliage:StandardMaterial3D
var rng:=RandomNumberGenerator.new()

func put(node:Node,parent:Node=null)->void:
	(parent if parent else world).add_child(node)
	node.owner=world

func _initialize()->void: call_deferred("build")

func build()->void:
	# The dummy renderer discards MultiMesh transforms and colours when baking.
	if DisplayServer.get_name()=="headless":
		push_error("Bake the valley with a real renderer; omit --headless.")
		quit(1)
		return
	rng.seed=64016
	world=Node3D.new()
	world.name="SunsetDreamValley"
	root.add_child(world)
	make_atmosphere()
	make_terrain()
	make_materials()
	make_cat()
	var props:=Node3D.new()
	props.name="RocksAndTrees"
	put(props)
	for data in [[Vector2(-10,0),Vector3(2.1,1.5,1.8)],[Vector2(7,4),Vector3(1.6,1.0,1.3)],[Vector2(10,-2),Vector3(2.2,1.6,1.8)],[Vector2(-18,-30),Vector3(1.6,1.0,1.4)],[Vector2(22,-43),Vector3(2.6,1.2,1.8)]]:
		add_rock(data[0],data[1],props,true)
	make_autumn_tree(Vector2(-12,-8),.85,props)
	make_autumn_tree(Vector2(-27,-46),.74,props)
	make_autumn_tree(Vector2(36,-96),.7,props)
	make_autumn_tree(Vector2(-52,-80),.65,props)
	make_pines()
	make_flowers()
	await process_frame
	await process_frame
	var packed:=PackedScene.new()
	var error:=packed.pack(world)
	if error==OK: error=ResourceSaver.save(packed,"res://levels/06_dream_field/scenes/world.tscn")
	print("SUNSET_VALLEY_BUILD=",error," nodes=",world.find_children("*","",true,false).size())
	world.free()
	quit(0 if error==OK else 1)

func make_atmosphere()->void:
	var sky_material:=ShaderMaterial.new()
	sky_material.shader=load("res://levels/06_dream_field/assets/sunset_sky.gdshader")
	sky_material.set_shader_parameter("panorama",load("res://levels/06_dream_field/assets/sunset_clouds.png"))
	var sky:=Sky.new()
	sky.sky_material=sky_material
	sky.radiance_size=Sky.RADIANCE_SIZE_128
	var env:=Environment.new()
	env.background_mode=Environment.BG_SKY
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(.48,.37,.54)
	env.ambient_light_energy=.70
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled=true
	env.fog_density=.0028
	env.fog_light_color=Color(.56,.32,.35)
	env.fog_sky_affect=0.0
	env.fog_height=-3.0
	env.fog_height_density=.012
	var atmosphere:=WorldEnvironment.new()
	atmosphere.name="SunsetAtmosphere"
	atmosphere.environment=env
	put(atmosphere)
	var sun:=DirectionalLight3D.new()
	sun.name="WarmEveningSun"
	sun.rotation_degrees=Vector3(-8,135,0)
	sun.light_color=Color(1.0,.63,.29)
	sun.light_energy=1.15
	sun.light_specular=.15
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65
	put(sun)
	var fill:=DirectionalLight3D.new()
	fill.name="SoftFrontFill"
	fill.rotation_degrees=Vector3(-25,-35,0)
	fill.light_color=Color(1.0,.82,.65)
	fill.light_energy=.68
	fill.light_specular=.08
	put(fill)

func make_terrain()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offset:=0
	for config in [[256.0,128],[1024.0,64]]:
		var half:float=config[0]
		var cells:int=config[1]
		var spacing:=half*2/cells
		for z in cells+1:
			for x in cells+1:
				var wx:=x*spacing-half
				var wz:=z*spacing-half
				surface.set_uv(Vector2(wx/3.1,wz/3.1))
				surface.add_vertex(Vector3(wx,Terrain.height_raw(wx,wz),wz))
		for z in cells:
			for x in cells:
				if half>256 and absf((x+.5)*spacing-half)<256 and absf((z+.5)*spacing-half)<256: continue
				var a:=offset+z*(cells+1)+x
				for index in [a,a+1,a+cells+1,a+1,a+cells+2,a+cells+1]: surface.add_index(index)
		offset+=(cells+1)*(cells+1)
	surface.generate_normals()
	var mesh:=surface.commit()
	ResourceSaver.save(mesh,"res://levels/06_dream_field/assets/terrain.res")
	var material:=ShaderMaterial.new()
	material.shader=load("res://levels/06_dream_field/assets/sunset_ground.gdshader")
	material.set_shader_parameter("grass_map",load("res://levels/06_dream_field/assets/psx_grass.png"))
	material.set_shader_parameter("dirt_map",load("res://levels/06_dream_field/assets/psx_dirt.png"))
	var ground:=MeshInstance3D.new()
	ground.name="MeadowAndHills"
	ground.mesh=load("res://levels/06_dream_field/assets/terrain.res")
	ground.material_override=material
	ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(ground)
	var body:=StaticBody3D.new()
	body.name="WalkableTerrain"
	put(body)
	var collision:=CollisionShape3D.new()
	collision.name="GroundShape"
	collision.shape=mesh.create_trimesh_shape()
	put(collision,body)
	var lake:=MeshInstance3D.new()
	lake.name="SunsetLake"
	var plane:=PlaneMesh.new()
	plane.size=Vector2(136,154)
	lake.mesh=plane
	lake.position=Vector3(48,Terrain.WATER_LEVEL,-60)
	var water:=ShaderMaterial.new()
	water.shader=load("res://levels/06_dream_field/assets/sunset_water.gdshader")
	lake.material_override=water
	lake.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(lake)

func make_materials()->void:
	stone=StandardMaterial3D.new()
	stone.albedo_texture=load("res://levels/06_dream_field/assets/psx_stone.png")
	stone.albedo_color=Color(.49,.43,.45)
	stone.roughness=1.0
	stone.uv1_triplanar=true
	stone.uv1_scale=Vector3.ONE*.4
	stone.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	bark=StandardMaterial3D.new()
	bark.albedo_texture=load("res://levels/06_dream_field/assets/psx_forest_floor.png")
	bark.albedo_color=Color(.60,.43,.28)
	bark.roughness=1.0
	bark.uv1_triplanar=true
	bark.uv1_scale=Vector3(.6,.2,.6)
	bark.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	foliage=StandardMaterial3D.new()
	foliage.vertex_color_use_as_albedo=true
	foliage.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	foliage.cull_mode=BaseMaterial3D.CULL_DISABLED

func make_cat()->void:
	var monument:=Node3D.new()
	monument.name="WakeMonument"
	monument.position=Vector3(0,Terrain.height_at(0,-16),-16)
	put(monument)
	var socket:=Marker3D.new()
	socket.name="StatueSocket"
	put(socket,monument)
	var cat=(load("res://levels/06_dream_field/scenes/cat_statue.tscn") as PackedScene).instantiate()
	put(cat,socket)
	for i in 9:
		var angle:float=i*TAU/10.0+.5
		var position:=Vector2(sin(angle)*2.55,cos(angle)*2.55-16)
		if position.y>-13.9 and absf(position.x)<1.8: continue
		add_rock(position,Vector3(rng.randf_range(.55,.85),rng.randf_range(.35,.6),rng.randf_range(.5,.8)),world,false)

func rock_mesh(seed_value:int)->ArrayMesh:
	var sphere:=SphereMesh.new()
	sphere.radial_segments=8
	sphere.rings=4
	sphere.radius=1.0
	sphere.height=2.0
	var arrays:=sphere.surface_get_arrays(0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0,indices.size(),3):
		var triangle:Array[Vector3]=[]
		for j in 3:
			var v:=vertices[indices[t+j]]
			var rough:=.84+.18*sin(v.dot(Vector3(17,11,23))+seed_value)
			triangle.append(v*rough)
		var normal:Vector3=(triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
		for v in triangle:
			surface.set_normal(normal)
			surface.add_vertex(v)
	return surface.commit()

func add_rock(point:Vector2,size:Vector3,parent:Node,solid:bool)->void:
	var rock:=MeshInstance3D.new()
	rock.name="Boulder_%d"%rng.randi_range(1000,9999)
	rock.mesh=rock_mesh(rng.randi_range(0,1000))
	rock.material_override=stone
	rock.position=Vector3(point.x,Terrain.height_at(point.x,point.y)+size.y*.40,point.y)
	rock.scale=size
	rock.rotation.y=rng.randf()*TAU
	put(rock,parent)
	if solid:
		var body:=StaticBody3D.new()
		body.name="RockCollision"
		put(body,rock)
		var shape:=CollisionShape3D.new()
		shape.name="Shape"
		shape.shape=rock.mesh.create_convex_shape()
		put(shape,body)

func branch(parent:Node,a:Vector3,b:Vector3,radius:float)->void:
	var trunk:=MeshInstance3D.new()
	trunk.name="Branch_%d"%parent.get_child_count()
	var mesh:=CylinderMesh.new()
	mesh.bottom_radius=radius
	mesh.top_radius=radius*.54
	mesh.height=a.distance_to(b)
	mesh.radial_segments=6
	mesh.rings=1
	trunk.mesh=mesh
	trunk.material_override=bark
	trunk.position=(a+b)*.5
	trunk.basis=Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	put(trunk,parent)

func make_autumn_tree(point:Vector2,scale_value:float,parent:Node)->void:
	var tree:=Node3D.new()
	tree.name="AutumnTree_%d"%parent.get_child_count()
	tree.position=Vector3(point.x,Terrain.height_at(point.x,point.y),point.y)
	tree.scale=Vector3.ONE*scale_value
	put(tree,parent)
	branch(tree,Vector3.ZERO,Vector3(.3,6,0),.44)
	var ends:=[Vector3(-3,6.8,.5),Vector3(-2,8.8,-1.5),Vector3(.5,9.5,-.8),Vector3(3.5,7.4,.5),Vector3(4.4,8.7,-1.4),Vector3(1.6,10,-1.6)]
	for end in ends: branch(tree,Vector3(.3,4.2,0),end,.18)
	var body:=StaticBody3D.new()
	body.name="TrunkCollision"
	put(body,tree)
	var shape:=CollisionShape3D.new()
	shape.name="Trunk"
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=.44
	cylinder.height=5.0
	shape.shape=cylinder
	shape.position.y=2.5
	put(shape,body)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var palette:=[Color(.49,.19,.035),Color(.76,.32,.045),Color(.95,.47,.08),Color(.61,.27,.035),Color(.88,.57,.16)]
	for end in ends:
		for leaf in 135:
			var centre:Vector3=end+Vector3(rng.randf_range(-1.6,1.6),rng.randf_range(-.9,1.0),rng.randf_range(-1.35,1.35))
			var width:=rng.randf_range(.16,.33)
			var right:=Vector3(cos(leaf*2.4),0,sin(leaf*2.4))*width
			var up:=Vector3(0,width*.8,0)
			var corners:=[centre-right-up,centre+right-up,centre+right+up,centre-right+up]
			var color:Color=palette[rng.randi_range(0,palette.size()-1)]
			for index in [0,1,2,0,2,3]:
				surface.set_normal(Vector3.UP)
				surface.set_color(color)
				surface.add_vertex(corners[index])
	var leaves:=MeshInstance3D.new()
	leaves.name="OrangeLeafCanopy"
	leaves.mesh=surface.commit()
	leaves.material_override=foliage
	leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(leaves,tree)

func make_pines()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 4:
		var y:=.12+layer*.19
		var radius:=.27-layer*.048
		for side in 6:
			var a:float=side*TAU/6
			var b:float=(side+1)*TAU/6
			var triangle:=[Vector3(sin(a)*radius,y,cos(a)*radius),Vector3(0,y+.43,0),Vector3(sin(b)*radius,y,cos(b)*radius)]
			for v in triangle:
				surface.set_normal(Vector3.UP)
				surface.set_color(Color(.26,.25,.20))
				surface.add_vertex(v)
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=surface.commit()
	multi.instance_count=150
	for i in 150:
		var x:=rng.randf_range(-210,240)
		var z:=rng.randf_range(-310,-95)
		if i<18:
			x=rng.randf_range(-65,-28)
			z=rng.randf_range(-95,-48)
		var height:=rng.randf_range(5.5,13.0)
		var basis:=Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*height)
		multi.set_instance_transform(i,Transform3D(basis,Vector3(x,Terrain.height_at(x,z),z)))
		multi.set_instance_color(i,Color.WHITE)
	var forest:=MultiMeshInstance3D.new()
	forest.name="DistantPineForest"
	forest.multimesh=multi
	forest.material_override=foliage
	forest.custom_aabb=AABB(Vector3(-230,-5,-330),Vector3(490,130,300))
	forest.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(forest)

func make_flowers()->void:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for petal in 5:
		var angle:float=petal*TAU/5
		var centre:=Vector3(sin(angle)*.075,.82,cos(angle)*.075)
		var right:=Vector3(cos(angle),0,-sin(angle))*.045
		var along:=Vector3(sin(angle),0,cos(angle))*.085
		var corners:=[centre-right-along,centre+right-along,centre+right+along,centre-right+along]
		for index in [0,1,2,0,2,3]:
			surface.set_normal(Vector3.UP)
			surface.set_color(Color(.98,.88,.61))
			surface.add_vertex(corners[index])
	for side in 6:
		var a:float=side*TAU/6
		var b:float=(side+1)*TAU/6
		for vertex in [Vector3(0,.825,0),Vector3(sin(a)*.045,.825,cos(a)*.045),Vector3(sin(b)*.045,.825,cos(b)*.045)]:
			surface.set_normal(Vector3.UP)
			surface.set_color(Color(.85,.45,.045))
			surface.add_vertex(vertex)
	for angle in [0.0,PI*.5]:
		var right:=Vector3(cos(angle),0,sin(angle))*.012
		var corners:=[-right,right,right+Vector3(0,.82,0),-right+Vector3(0,.82,0)]
		for index in [0,1,2,0,2,3]:
			surface.set_normal(Vector3.UP)
			surface.set_color(Color(.23,.26,.07))
			surface.add_vertex(corners[index])
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	multi.mesh=surface.commit()
	multi.instance_count=240
	var centres:=[Vector2(-7,5),Vector2(8,3),Vector2(11,-11),Vector2(-16,-23),Vector2(24,-44)]
	for i in 240:
		var point:Vector2=centres[i%centres.size()]+Vector2(rng.randf_range(-3.4,3.4),rng.randf_range(-3.4,3.4))
		var scale_value:=rng.randf_range(.65,1.20)
		multi.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(point.x,Terrain.height_at(point.x,point.y),point.y)))
		multi.set_instance_color(i,Color.WHITE)
	var flowers:=MultiMeshInstance3D.new()
	flowers.name="MeadowFlowers"
	flowers.multimesh=multi
	flowers.material_override=foliage
	flowers.custom_aabb=AABB(Vector3(-25,-5,-52),Vector3(60,15,65))
	flowers.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	put(flowers)
