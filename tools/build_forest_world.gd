extends SceneTree
## Builds levels/05_realization/forest_world.tscn for Episode 05 from the PSX Forest Free pieces.
## godot --script res://tools/build_forest_world.gd
## NOT --headless: the headless dummy renderer drops MultiMesh transforms, and the
## ground, trail, ferns and grass would all be saved at the origin.
## Seeded, so re-running gives the same forest. Edit the constants, not the scene.

const OUT := "res://levels/05_realization/forest_world.tscn"
const P := "res://levels/05_realization/assets/psx_forest/"
const SEED := 505
const WORLD := Rect2(-44, -160, 88, 176)        # x, z, width, depth (ground area)
# The walk, start to campfire. The chapter script reads this curve from World/Trail.
const TRAIL := [Vector3(0,0,2), Vector3(1.5,0,-8), Vector3(4,0,-20), Vector3(-1,0,-33),
	Vector3(-5,0,-46), Vector3(1,0,-60), Vector3(4,0,-72), Vector3(0,0,-84),
	Vector3(-6,0,-96), Vector3(-9,0,-108), Vector3(-3,0,-120), Vector3(0,0,-132)]
const CAMPFIRE := Vector3(0, 0, -136)
# The false fork: at (4,-72) the real trail bends left, this one carries straight on
# and dies in the trees. The frog waits at its end. Read from World/FalseTrail.
const FALSE_TRAIL := [Vector3(4,0,-72), Vector3(7.5,0,-84), Vector3(11,0,-95), Vector3(13,0,-104)]
# Things from Phakin's childhood beside the walk: [name, fraction of the trail, side offset (m)].
const MEMORIES := [["Bicycle", .27, 2.6], ["FishingChair", .62, -3.0], ["CatfishToy", .86, 0.0]]
const GIANT_TREE := Vector3(-4.6, 0, -8.2)
const TREE_SPACING := 6.2
const TRAIL_CLEAR := 4.5       # no trunks closer than this to the trail centre
const CLEARING := 9.0          # open ground around the campfire

var rng := RandomNumberGenerator.new()
var forest: Node3D
var trail: Curve3D
var false_trail: Curve3D

func _initialize() -> void:
	rng.seed = SEED
	forest = Node3D.new()
	forest.name = "ForestWorld"
	build_trail()
	build_environment()
	build_ground()
	build_trail_tiles()
	build_trees()
	build_undergrowth()
	build_giant_tree()
	build_memories()
	build_campsite()
	build_bounds()
	var packed := PackedScene.new()
	var err := packed.pack(forest)
	if err == OK: err = ResourceSaver.save(packed, OUT)
	print("levels/05_realization/forest_world.tscn: ", "saved" if err == OK else "FAILED %d" % err)
	forest.free()
	quit(0 if err == OK else 1)

# ---------------------------------------------------------------- helpers

func add(node: Node, parent: Node = null) -> Node:
	(parent if parent else forest).add_child(node)
	node.owner = forest
	return node

func group(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	return add(n) as Node3D

func prop(piece: String, parent: Node, pos: Vector3, yaw := 0.0, size := 1.0) -> Node3D:
	var n := (load(P + "props/" + piece + ".tscn") as PackedScene).instantiate() as Node3D
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * size
	add(n, parent)
	return n

func mesh_of(piece: String) -> Mesh:
	var model := (load(P + "models/" + piece + "_model.glb") as PackedScene).instantiate()
	var found := model.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh if found.size() else null
	model.free()
	return mesh

func multimesh(name: String, piece: String, transforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_of(piece)
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i, transforms[i])
	var n := MultiMeshInstance3D.new()
	n.name = name
	n.multimesh = mm
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add(n)

func trail_distance(p: Vector3) -> float:
	var best := INF
	for curve in [trail, false_trail]:
		var q: Vector3 = curve.get_closest_point(Vector3(p.x, 0, p.z))
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best

func spot(min_trail := 0.0, max_trail := INF) -> Variant:
	for attempt in 40:
		var p := Vector3(rng.randf_range(WORLD.position.x + 2, WORLD.end.x - 2), 0,
			rng.randf_range(WORLD.position.y + 2, WORLD.end.y - 2))
		var d := trail_distance(p)
		if d >= min_trail and d <= max_trail and p.distance_to(CAMPFIRE) > CLEARING * .7:
			return p
	return null

# ---------------------------------------------------------------- pieces

func smooth_curve(points: Array) -> Curve3D:
	var curve := Curve3D.new()
	for i in points.size():
		var prev: Vector3 = points[max(i - 1, 0)]
		var next: Vector3 = points[min(i + 1, points.size() - 1)]
		var handle := (next - prev) * .22
		curve.add_point(points[i], -handle, handle)
	return curve

func build_trail() -> void:
	trail = smooth_curve(TRAIL)
	var path := Path3D.new()
	path.name = "Trail"
	path.curve = trail
	add(path)
	false_trail = smooth_curve(FALSE_TRAIL)
	var fork := Path3D.new()
	fork.name = "FalseTrail"
	fork.curve = false_trail
	add(fork)
	var dead_end := Marker3D.new()
	dead_end.name = "FalseTrailEnd"
	dead_end.position = FALSE_TRAIL[-1]
	add(dead_end)
	# Moonlight on the dead end, so the frog waiting there is seen from down the fork.
	var beam := SpotLight3D.new()
	beam.name = "FalseEndBeam"
	beam.light_color = Color(.62, .70, .90)
	beam.light_energy = 2.4
	beam.spot_range = 12
	beam.spot_angle = 12
	beam.position = FALSE_TRAIL[-1] + Vector3(.5, 9, 1.2)
	beam.rotation = Vector3(deg_to_rad(-82), 0, 0)
	add(beam)
	var fire := Marker3D.new()
	fire.name = "CampfireSpot"
	fire.position = CAMPFIRE
	add(fire)

func build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.008, .011, .016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.22, .27, .34)
	env.ambient_light_energy = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(.025, .032, .04)
	env.fog_density = .045
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.name = "Night"
	world_env.environment = env
	add(world_env)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(.55, .62, .85)
	moon.light_energy = .34
	moon.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	add(moon)

func build_ground() -> void:
	var tiles: Array[Transform3D] = []
	var x := WORLD.position.x + 2.0
	while x < WORLD.end.x:
		var z := WORLD.position.y + 2.0
		while z < WORLD.end.y:
			tiles.append(Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI / 2), Vector3(x, 0, z)))
			z += 4.0
		x += 4.0
	multimesh("Ground", "ground_grass", tiles)
	# One flat collider under the whole forest; the tiles' tops are 1 cm up.
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	add(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WORLD.size.x, 1, WORLD.size.y)
	shape.shape = box
	shape.position = Vector3(WORLD.get_center().x, -.49, WORLD.get_center().y)
	add(shape, body)

func build_trail_tiles() -> void:
	# Straight path tiles laid end to end along each curve, turned to its direction.
	var tiles: Array[Transform3D] = []
	for curve in [trail, false_trail]:
		var length: float = curve.get_baked_length()
		var step := 3.0
		var offset := 0.0
		var i := 0
		while offset < length:
			var a: Vector3 = curve.sample_baked(offset)
			var b: Vector3 = curve.sample_baked(minf(offset + .5, length))
			var yaw := atan2(b.x - a.x, b.z - a.z)
			tiles.append(Transform3D(Basis(Vector3.UP, yaw), a + Vector3.UP * (.004 + (i % 2) * .003)))
			offset += step
			i += 1
	multimesh("TrailTiles", "path_straight", tiles)

func build_trees() -> void:
	var trees := group("Trees")
	var x := WORLD.position.x + 3.0
	while x < WORLD.end.x - 2:
		var z := WORLD.position.y + 3.0
		while z < WORLD.end.y - 2:
			var p := Vector3(x + rng.randf_range(-2.2, 2.2), 0, z + rng.randf_range(-2.2, 2.2))
			z += TREE_SPACING
			if trail_distance(p) < TRAIL_CLEAR + rng.randf_range(0, 2.5): continue
			if p.distance_to(CAMPFIRE) < CLEARING or p.distance_to(GIANT_TREE) < 7.5: continue
			var roll := rng.randf()
			var piece := "pine" if roll < .55 else "pine_small" if roll < .8 else "tree_dead" if roll < .9 else "oak"
			prop(piece, trees, p, rng.randf() * TAU, rng.randf_range(.95, 1.45))
		x += TREE_SPACING

func build_undergrowth() -> void:
	var props := group("Undergrowth")
	for n in 200:
		var p: Variant = spot(2.4)
		if p == null: continue
		var roll := rng.randf()
		var piece := "bush" if roll < .45 else "boulder" if roll < .65 else "stump" if roll < .82 else "log"
		prop(piece, props, p, rng.randf() * TAU, rng.randf_range(.8, 1.25))
	var ferns: Array[Transform3D] = []
	var grass: Array[Transform3D] = []
	for n in 1300:
		var p: Variant = spot(1.6)
		if p == null: continue
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(.8, 1.3)), p)
		if n % 3 == 0: ferns.append(t)
		else: grass.append(t)
	multimesh("Ferns", "fern", ferns)
	multimesh("Grass", "grass", grass)

func build_giant_tree() -> void:
	# The frog's tree: the first thing Phakin sees when he wakes up.
	var tree := prop("oak", forest, GIANT_TREE, deg_to_rad(35), 2.4)
	tree.name = "GiantTree"
	var peek := Marker3D.new()
	peek.name = "FrogPeek"
	# Just past the right edge of the trunk as seen from the start.
	peek.position = GIANT_TREE + Vector3(1.35, 0, .55)
	add(peek)
	# A thin shaft of moonlight through the canopy, onto the frog's spot.
	var beam := SpotLight3D.new()
	beam.name = "MoonBeam"
	beam.light_color = Color(.62, .70, .90)
	beam.light_energy = 2.6
	beam.spot_range = 12
	beam.spot_angle = 11
	beam.spot_attenuation = .6
	beam.position = peek.position + Vector3(.6, 9, 1.5)
	beam.rotation = Vector3(deg_to_rad(-80), deg_to_rad(20), 0)
	add(beam)

func build_campsite() -> void:
	var camp := group("Campsite")
	var fire := prop("campfire", camp, CAMPFIRE)
	fire.name = "Campfire"
	prop("log", camp, CAMPFIRE + Vector3(0, 0, -2.6), 0.08)
	prop("log", camp, CAMPFIRE + Vector3(-2.7, 0, .4), PI / 2.2)
	prop("stump", camp, CAMPFIRE + Vector3(2.5, 0, 1.4), .7, .8)
	prop("tent", camp, CAMPFIRE + Vector3(4.6, 0, -3.6), -.65)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1, .55, .22)
	light.light_energy = 2.4
	light.omni_range = 13
	light.omni_attenuation = 1.4
	light.position = CAMPFIRE + Vector3(0, .9, 0)
	add(light, camp)
	# A soft glow that ignores fog, so the fire is visible from the start of the walk.
	var glow := MeshInstance3D.new()
	glow.name = "FireGlow"
	var quad := QuadMesh.new()
	quad.size = Vector2(4.5, 4.5)
	glow.mesh = quad
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, .62, .28, .85))
	gradient.set_color(1, Color(1, .4, .1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(.5, .5)
	tex.fill_to = Vector2(1, .5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_fog = true
	mat.albedo_texture = tex
	glow.material_override = mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = CAMPFIRE + Vector3(0, 2.2, 0)   # bottom edge at the ground, where it is clear
	add(glow, camp)

func build_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	add(body)
	var c := WORLD.get_center()
	for side in [[Vector3(c.x, 2, WORLD.position.y), Vector3(WORLD.size.x, 4, 1)],
			[Vector3(c.x, 2, WORLD.end.y), Vector3(WORLD.size.x, 4, 1)],
			[Vector3(WORLD.position.x, 2, c.y), Vector3(1, 4, WORLD.size.y)],
			[Vector3(WORLD.end.x, 2, c.y), Vector3(1, 4, WORLD.size.y)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = side[1]
		shape.shape = box
		shape.position = side[0]
		add(shape, body)


# ---------------------------------------------------------------- memories

func solid(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .8
	return m

func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add(mi, parent)
	return mi

func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	mi.mesh = mesh
	mi.material_override = mat
	add(mi, parent)
	mi.position = (a + b) * .5
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > .001: mi.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
	return mi

func wheel(parent: Node3D, center: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - .035
	mesh.outer_radius = radius
	mesh.rings = 18
	mesh.ring_segments = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = center
	mi.rotation = Vector3(0, 0, PI / 2)     # stand the ring up in the YZ plane
	add(mi, parent)
	return mi

# A thin pale beam from above, so each memory can be found in the dark.
func memory_light(parent: Node3D) -> void:
	var beam := SpotLight3D.new()
	beam.name = "Beam"
	beam.light_color = Color(.70, .76, .92)
	beam.light_energy = 1.6
	beam.spot_range = 9
	beam.spot_angle = 14
	beam.position = Vector3(.4, 7.5, .6)
	beam.rotation = Vector3(deg_to_rad(-86), 0, 0)
	add(beam, parent)

func build_memories() -> void:
	var memories := group("Memories")
	for m in MEMORIES:
		var at := trail.sample_baked(trail.get_baked_length() * float(m[1]))
		var ahead := trail.sample_baked(minf(trail.get_baked_length() * float(m[1]) + 1.0, trail.get_baked_length()))
		var forward := (ahead - at).normalized()
		var side := forward.cross(Vector3.UP).normalized()
		var root := Node3D.new()
		root.name = m[0]
		root.position = at + side * float(m[2])
		root.rotation.y = atan2(forward.x, forward.z)
		add(root, memories)
		memory_light(root)
		match String(m[0]):
			"Bicycle": build_bicycle(root)
			"FishingChair": build_chair(root, side * signf(float(m[2])), root.rotation.y)
			"CatfishToy": build_toy(root)

# A child's bicycle leaning on a pine; the back wheel buckled.
func build_bicycle(root: Node3D) -> void:
	prop("tree_dead", root, Vector3(-.75, 0, -.2), .4, .9)   # bare trunk: nothing hides the bike
	var bike := Node3D.new()
	bike.name = "Bike"
	bike.position = Vector3(-.2, 0, .1)
	bike.rotation = Vector3(0, PI / 2, deg_to_rad(14))   # side-on to the trail, leaning on the trunk
	add(bike, root)
	var paint := solid(Color(.55, .13, .12))
	var tyre := solid(Color(.06, .06, .06))
	wheel(bike, Vector3(0, .26, .42), .26, tyre)
	var back := wheel(bike, Vector3(0, .25, -.42), .26, tyre)
	back.rotation = Vector3(.25, .18, PI / 2 + .12)        # bent
	rod(bike, Vector3(0, .26, -.42), Vector3(0, .55, .05), .022, paint)
	rod(bike, Vector3(0, .55, .05), Vector3(0, .26, .42), .022, paint)
	rod(bike, Vector3(0, .26, -.42), Vector3(0, .3, .02), .02, paint)
	rod(bike, Vector3(0, .55, .05), Vector3(0, .6, -.25), .022, paint)
	box(bike, Vector3(.1, .04, .2), Vector3(0, .64, -.28), solid(Color(.1, .09, .08)))
	rod(bike, Vector3(0, .26, .42), Vector3(0, .72, .36), .02, paint)
	rod(bike, Vector3(-.2, .74, .36), Vector3(.2, .74, .36), .016, solid(Color(.5, .5, .48)))

# Dad's canvas fishing chair, turned to face the dark between the trees.
func build_chair(root: Node3D, away: Vector3, root_yaw: float) -> void:
	var chair := Node3D.new()
	chair.name = "Chair"
	add(chair, root)
	chair.rotation.y = atan2(away.x, away.z) - root_yaw
	var frame := solid(Color(.32, .32, .3))
	var canvas := solid(Color(.16, .26, .22))
	for x in [-.24, .24]:
		rod(chair, Vector3(x, 0, -.22), Vector3(x, .42, .2), .014, frame)
		rod(chair, Vector3(x, 0, .22), Vector3(x, .42, -.2), .014, frame)
		rod(chair, Vector3(x, .4, -.22), Vector3(x, .9, -.32), .014, frame)
	box(chair, Vector3(.5, .03, .42), Vector3(0, .41, 0), canvas, Vector3(-.08, 0, 0))
	box(chair, Vector3(.5, .46, .03), Vector3(0, .66, -.27), canvas, Vector3(-.2, 0, 0))

# The toy catfish he slept with, lying in the middle of the trail.
func build_toy(root: Node3D) -> void:
	var toy := (load("res://levels/05_realization/assets/pladuk.glb") as PackedScene).instantiate() as Node3D
	toy.name = "Toy"
	toy.scale = Vector3.ONE * .34
	toy.rotation = Vector3(0, .9, PI / 2.3)               # lying on its side
	toy.position = Vector3(0, .09, 0)
	add(toy, root)
