extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	change_scene_to_file("res://prologue_village.tscn")
	await scene_changed
	for i in 3:
		await physics_frame
	var house: Node3D=current_scene.get_node("02_HousesAndVillageLandmarks/GrandmaHouse_Editable")
	var seen: Dictionary={}
	for n in house.get_children():
		if n is MeshInstance3D:
			for i in n.mesh.get_surface_count():
				var m: Material=n.get_active_material(i)
				if m is StandardMaterial3D and not seen.has(m.resource_name) and ("Parede" in m.resource_name or "Forro" in m.resource_name):
					seen[m.resource_name]=true
					print("MATERIAL ",m.resource_name," ALBEDO ",m.albedo_texture.resource_path," NORMAL ",m.normal_scale," METAL ",m.metallic," ROUGH ",m.roughness)
	var shape:=CapsuleShape3D.new()
	shape.radius=0.28
	shape.height=1.7
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape
	query.collision_mask=1
	var space: PhysicsDirectSpaceState3D=current_scene.get_world_3d().direct_space_state
	for z in range(-2,12):
		var row:="z=%2d " % z
		for ix in range(-16,17):
			var x:=ix*0.5
			query.transform=Transform3D(Basis(),house.to_global(Vector3(x,0.96,z)))
			row+="#" if not space.intersect_shape(query,1).is_empty() else "."
		print(row)
	var cells: Dictionary={}
	for z in 61:
		for x in 77:
			var point:=Vector2i(x,z)
			var at:=Vector3(-9.5+x*0.25,0.96,-2.0+z*0.25)
			query.transform=Transform3D(Basis(),house.to_global(at))
			if space.intersect_shape(query,1).is_empty():
				cells[point]=true
	var start:=Vector2i(38,0)
	var target:=Vector2i(38,38)
	var queue: Array[Vector2i]=[start]
	var previous: Dictionary={start:start}
	var cursor:=0
	while cursor<queue.size() and not previous.has(target):
		var at:=queue[cursor]
		cursor+=1
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i=at+d
			if cells.has(next) and not previous.has(next):
				previous[next]=at
				queue.append(next)
	if previous.has(target):
		var path: Array[Vector2i]=[target]
		while path[-1]!=start:
			path.append(previous[path[-1]])
		path.reverse()
		var turns: Array=[]
		for i in range(1,path.size()-1):
			if path[i]-path[i-1]!=path[i+1]-path[i]:
				turns.append([-9.5+path[i].x*0.25,-2+path[i].y*0.25])
		print("WALKABLE HOUSE ROUTE SOURCE XZ ",turns)
	else:
		print("NO HOUSE ROUTE: exterior-connected cells ",previous.size()," free ",cells.size())
	quit()
