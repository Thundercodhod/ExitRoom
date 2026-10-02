extends SceneTree
func _initialize() -> void:
	var p=load("res://Room407/main.tscn").instantiate()
	var b=p.get_node("Room406/Bed")
	print("BED_ROOT ",b.transform)
	for n in b.find_children("*","MeshInstance3D",true,false):print("BED_MESH ",n.name," ",n.get_aabb()," ",n.transform)
	var a=load("res://Room407/assets/models/bed.glb").instantiate()
	for n in a.find_children("*","MeshInstance3D",true,false):print("ASSET_MESH ",n.name," ",n.get_aabb()," ",n.transform)
	p.free()
	a.free()
	quit()
