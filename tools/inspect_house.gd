extends SceneTree
var rows: Array = []
var total := AABB()
var first := true

func _initialize() -> void:
	call_deferred("run")

func scan(n: Node) -> void:
	if n is MeshInstance3D:
		var a: AABB = n.global_transform * n.get_aabb()
		total=a if first else total.merge(a)
		first=false
		var names: Array=[]
		for i in n.mesh.get_surface_count():
			var m: Material=n.get_active_material(i)
			names.append(m.resource_name if m else "")
		rows.append({"name":str(n.name),"path":str(n.get_path()),"min":[a.position.x,a.position.y,a.position.z],"size":[a.size.x,a.size.y,a.size.z],"materials":names})
	for c in n.get_children():
		scan(c)

func run() -> void:
	var model: Node3D=load("res://3Dmodel_import/low-poly_furnished_abandoned_house.glb").instantiate()
	root.add_child(model)
	scan(model)
	var file:=FileAccess.open("res://tools/house-inspection.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"bounds_min":[total.position.x,total.position.y,total.position.z],"bounds_size":[total.size.x,total.size.y,total.size.z],"meshes":rows},"\t"))
	print("HOUSE BOUNDS ",total)
	print("MESHES ",rows.size())
	quit()
