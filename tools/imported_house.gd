extends RefCounted
const SOURCE := "res://3Dmodel_import/low-poly_furnished_abandoned_house.glb"
const PLAYABLE := "res://assets/abandoned_house_playable.glb"
const Kit = preload("res://tools/abandoned_kit.gd")
static var material_cache: Dictionary={}

static func copy_meshes(source: Node, accumulated: Transform3D, parent: Node3D, owner_root: Node) -> void:
	var transform:=accumulated
	if source is Node3D:
		transform=accumulated*source.transform
	if source is MeshInstance3D and source.mesh:
		var mesh_node:=MeshInstance3D.new()
		mesh_node.name=source.name
		mesh_node.mesh=source.mesh
		mesh_node.transform=transform
		mesh_node.layers=2
		for surface in source.mesh.get_surface_count():
			var original: Material=source.get_active_material(surface)
			if original is StandardMaterial3D:
				if not material_cache.has(original.get_instance_id()):
					var adapted: StandardMaterial3D=original.duplicate()
					adapted.normal_scale=0.20
					adapted.roughness=maxf(adapted.roughness,0.82)
					adapted.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					if "Parede" in adapted.resource_name or "Forro" in adapted.resource_name or "Madeira" in adapted.resource_name:
						adapted.metallic=0.0
					material_cache[original.get_instance_id()]=adapted
				mesh_node.set_surface_override_material(surface,material_cache[original.get_instance_id()])
		Kit.add(parent,mesh_node,owner_root)
		# Keep the asset's authored UVs and materials. Collision is reserved for
		# architecture and large furnishings; cups and loose rubble won't snag feet.
		var n:=str(source.name)
		var structural:=n.begins_with("HouseWalls_Playable") or n.begins_with("polySurface3_") or n.begins_with("piso") or n.begins_with("porta1_") or n.begins_with("porta2_") or n.begins_with("porta3_") or n.begins_with("porta4_")
		var furniture:=n.begins_with("mesa") or n.begins_with("armario") or n.begins_with("guardaRoupa_") or n.begins_with("sofa_") or n.begins_with("banheira_") or n.begins_with("piaCozinha_") or n.begins_with("geladeira")
		if structural or furniture:
			var body:=StaticBody3D.new()
			body.name=n+"_Collision"
			var collision:=CollisionShape3D.new()
			var shape:=ConcavePolygonShape3D.new()
			var faces: PackedVector3Array=source.mesh.get_faces()
			for i in faces.size():
				faces[i]=transform*faces[i]
			shape.set_faces(faces)
			shape.backface_collision=true
			collision.shape=shape
			Kit.add(parent,body,owner_root)
			Kit.add(body,collision,owner_root)
	for child in source.get_children():
		copy_meshes(child,transform,parent,owner_root)

static func populate(parent: Node, owner_root: Node) -> Node3D:
	var house:=Kit.node(parent,"GrandmaHouse_Editable",Vector3(24,0.03,-140),owner_root)
	house.rotation.y=PI
	house.set_meta("source_author","NeoKG")
	house.set_meta("source_license","CC BY 4.0")
	house.set_meta("source_url","https://sketchfab.com/3d-models/low-poly-furnished-abandoned-house-ab6c142e1c494c8e84dd82c852138501")
	var source: Node3D=load(PLAYABLE).instantiate()
	copy_meshes(source,Transform3D.IDENTITY,house,owner_root)
	source.free()
	for item in [
		["KitchenWarmPractical",Vector3(2.6,2.02,8.5),Color(1.0,0.75,0.49),0.15,4.5],
		["HallwayFill",Vector3(-0.15,2.05,3.0),Color(0.61,0.73,0.71),0.10,4.5],
		["LivingRoomFill",Vector3(-4.4,2.1,4.0),Color(0.88,0.67,0.49),0.14,4.5],
		["BedroomFill",Vector3(4.2,2.1,1.3),Color(0.60,0.68,0.73),0.09,4.0]
	]:
		var lamp:=OmniLight3D.new()
		lamp.name=item[0]
		lamp.position=item[1]
		lamp.light_color=item[2]
		lamp.light_energy=item[3]
		lamp.omni_range=item[4]
		lamp.shadow_enabled=true
		lamp.shadow_bias=0.04
		lamp.shadow_blur=3
		Kit.add(house,lamp,owner_root)
	return house

static func find_surface(root: Node, wanted: String) -> StandardMaterial3D:
	if root is MeshInstance3D:
		for i in root.mesh.get_surface_count():
			var m: Material=root.get_active_material(i)
			if m is StandardMaterial3D and m.resource_name==wanted:
				return m
	for child in root.get_children():
		var found:=find_surface(child,wanted)
		if found:
			return found
	return null
