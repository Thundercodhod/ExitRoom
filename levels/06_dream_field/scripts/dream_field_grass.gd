extends Node3D
## A bounded pool follows the player; the field never allocates more tiles as you walk.
const Terrain = preload("res://levels/06_dream_field/scripts/dream_field_terrain.gd")
const TILE_SIZE := 18.0
const RADIUS := 4
const SIDE := RADIUS * 2 + 1
@export var follow: NodePath
var tiles: Dictionary = {}
var pending: Array[Vector2i] = []
var centre := Vector2i(100000, 100000)
var material: ShaderMaterial
var clump_mesh: ArrayMesh
var density := 1000
var draw_distance := 76.0

func _ready() -> void:
	density = 500 if OS.has_feature("web") else 1300
	draw_distance = 64.0 if OS.has_feature("web") else 76.0
	material = ShaderMaterial.new()
	material.shader = preload("res://levels/06_dream_field/assets/dry_grass.gdshader")
	material.set_shader_parameter("draw_distance", draw_distance)
	clump_mesh = make_clump()
	for index in SIDE * SIDE:
		var tile := MultiMeshInstance3D.new()
		tile.name = "StrawTile_%02d" % index
		tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tile.visibility_range_end = draw_distance + 15.0
		tile.material_override = material
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = clump_mesh
		multi.instance_count = density
		tile.multimesh = multi
		add_child(tile)
		tiles[index] = {"node": tile, "coordinate": Vector2i(100000, 100000)}
	update_centre()
	# Show the nearby meadow first on Web; fill the outer ring over later frames.
	# This keeps the entry transition responsive on slower browser runtimes.
	var initial_tiles := mini(pending.size(), 25) if OS.has_feature("web") else pending.size()
	for index in initial_tiles: fill_tile(pending.pop_front())

func make_clump() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6406
	# Actual tapered blades keep the foreground fine and avoid opaque card blobs.
	# Each blade has only three triangles; all clumps share this one mesh.
	for blade in 8:
		var angle := rng.randf() * TAU
		var right := Vector3(cos(angle),0,sin(angle))
		var root_position := Vector3(rng.randf_range(-.20,.20),0,rng.randf_range(-.20,.20))
		var height := rng.randf_range(.76,1.22)
		var lean := Vector3(rng.randf_range(-.30,.30),0,rng.randf_range(-.30,.30))
		var width := rng.randf_range(.014,.023)
		var middle := root_position + Vector3(0,height*.62,0) + lean*.36
		var tip := root_position + Vector3(0,height,0) + lean
		var corners := [root_position-right*width,root_position+right*width,middle+right*width*.58,middle-right*width*.58,tip]
		var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,.38),Vector2(0,.38),Vector2(.5,0)]
		var shade := rng.randf_range(.76,1.0)
		for index in [0,1,2,0,2,3,3,2,4]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(uv[index])
			surface.set_color(Color(shade,shade,shade,1))
			surface.add_vertex(corners[index])
	return surface.commit()

func update_centre() -> void:
	var player := get_node_or_null(follow) as Node3D
	if not player: return
	var next := Vector2i(floori(player.global_position.x / TILE_SIZE), floori(player.global_position.z / TILE_SIZE))
	if next == centre: return
	centre = next
	pending.clear()
	for z in range(centre.y - RADIUS, centre.y + RADIUS + 1):
		for x in range(centre.x - RADIUS, centre.x + RADIUS + 1):
			var coordinate := Vector2i(x,z)
			if tiles[slot(coordinate)].coordinate != coordinate: pending.append(coordinate)
	pending.sort_custom(func(a, b): return a.distance_squared_to(centre) < b.distance_squared_to(centre))

func slot(coordinate: Vector2i) -> int:
	return posmod(coordinate.y, SIDE) * SIDE + posmod(coordinate.x, SIDE)

func fill_tile(coordinate: Vector2i) -> void:
	var item: Dictionary = tiles[slot(coordinate)]
	var node: MultiMeshInstance3D = item.node
	var origin := Vector3(coordinate.x * TILE_SIZE, 0, coordinate.y * TILE_SIZE)
	node.position = origin
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coordinate) ^ 640716
	var minimum_y := INF
	var maximum_y := -INF
	for i in density:
		var x := rng.randf() * TILE_SIZE
		var z := rng.randf() * TILE_SIZE
		var wx := origin.x + x
		var wz := origin.z + z
		var ground_height := Terrain.height_at(wx,wz)
		minimum_y = minf(minimum_y,ground_height)
		maximum_y = maxf(maximum_y,ground_height)
		var width := rng.randf_range(.65, 1.20)
		var height := rng.randf_range(.28, .65)
		if rng.randf() > Terrain.grass_density(wx, wz): height *= .09
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(width, height, width))
		node.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, ground_height-.025, z)))
		node.multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randi_range(0,3), 0, 1))
	node.custom_aabb = AABB(Vector3(-.8,minimum_y-2.0,-.8),Vector3(TILE_SIZE+1.6,maximum_y-minimum_y+4.0,TILE_SIZE+1.6))
	item.coordinate = coordinate

func _process(_delta: float) -> void:
	update_centre()
	# The recycled outer ring is behind the haze. Limit uploads per frame on Web.
	for i in mini(pending.size(), 2): fill_tile(pending.pop_front())
