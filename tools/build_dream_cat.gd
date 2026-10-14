extends SceneTree
## Bake only the new cat statue; source GLB is not required by the exported game.
func _initialize() -> void: call_deferred("build")
func build() -> void:
	var statue := Node3D.new()
	statue.name="CatStatue"
	root.add_child(statue)
	var original=(load("res://handpainted_fat_cat_statue_-_ghibli_style.glb") as PackedScene).instantiate()
	statue.add_child(original)
	var visual:=Node3D.new()
	visual.name="HandpaintedCat"
	statue.add_child(visual)
	visual.owner=statue
	var minimum:=Vector3(INF,INF,INF)
	var maximum:=Vector3(-INF,-INF,-INF)
	for source in original.find_children("*","MeshInstance3D",true,false):
		var upright:Transform3D=source.global_transform
		var mesh:=source.mesh.duplicate() as ArrayMesh
		for s in mesh.get_surface_count():
			for vertex in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var point:Vector3=upright*vertex
				minimum=minimum.min(point)
				maximum=maximum.max(point)
			mesh.surface_set_material(s,null)
		ResourceSaver.save(mesh,"res://assets/dream_field/cat_mesh.res")
		var body:=MeshInstance3D.new()
		body.name="Cat"
		body.mesh=load("res://assets/dream_field/cat_mesh.res")
		body.transform=upright
		var stone:=ShaderMaterial.new()
		stone.shader=load("res://assets/dream_field/cat_stone.gdshader")
		stone.set_shader_parameter("handpaint",load("res://assets/dream_field/cat_albedo.png"))
		body.material_override=stone
		visual.add_child(body)
		body.owner=statue
	var bounds:=AABB(minimum,maximum-minimum)
	var factor:=5.6/bounds.size.y
	visual.scale=Vector3.ONE*factor
	visual.position=Vector3(-bounds.get_center().x*factor,-minimum.y*factor,-bounds.get_center().z*factor)
	visual.rotation.y=0.0
	# The OBJ's front points along +Z after its supplied import transform.
	print("CAT_BOUNDS=",bounds," scale=",factor)
	original.free()
	var solid:=StaticBody3D.new()
	solid.name="StatueCollision"
	statue.add_child(solid)
	solid.owner=statue
	var shape:=CollisionShape3D.new()
	var cylinder:=CylinderShape3D.new()
	cylinder.radius=2.0
	cylinder.height=4.7
	shape.shape=cylinder
	shape.position.y=2.35
	shape.position.z=.65
	solid.add_child(shape)
	shape.owner=statue
	var focus:=Marker3D.new()
	focus.name="WakeFocus"
	focus.position=Vector3(0,1.65,0)
	statue.add_child(focus)
	focus.owner=statue
	var packed:=PackedScene.new()
	var result:=packed.pack(statue)
	if result==OK: result=ResourceSaver.save(packed,"res://scenes/dream_field/cat_statue.tscn")
	print("CAT_BUILD=",result)
	statue.free()
	quit(0 if result==OK else 1)
