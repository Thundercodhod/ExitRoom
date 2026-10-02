extends RefCounted
# Walkable-area grid for enemies that must path around walls. The grid is built
# from physics shape queries (so it works with trimesh level geometry), paths
# are A* over the free cells and then string-pulled so they do not zig-zag.
#
#   var nav := NavGrid.new()
#   nav.bounds = Rect2(x, z, width, depth)      # XZ rectangle of the floor
#   nav.build(get_world_3d().direct_space_state)   # after colliders are in the tree
#   var waypoints := nav.plan(from, to)

var bounds := Rect2()
var cell_size := 0.4
var radius := 0.42      # clearance a walker needs around its centre
var height := 0.45      # height of the probe sphere above the floor
var mask := 1
var grid: AStarGrid2D


func is_ready() -> bool:
	return grid != null


func build(space: PhysicsDirectSpaceState3D) -> void:
	var size := Vector2i(ceili(bounds.size.x / cell_size), ceili(bounds.size.y / cell_size))
	grid = AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, size)
	grid.cell_size = Vector2(cell_size, cell_size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = mask
	for x in size.x:
		for y in size.y:
			var c := cell_center(Vector2i(x, y))
			query.transform = Transform3D(Basis.IDENTITY, Vector3(c.x, height, c.y))
			if not space.intersect_shape(query, 1).is_empty():
				grid.set_point_solid(Vector2i(x, y), true)


func cell_center(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func world_to_cell(p: Vector3) -> Vector2i:
	var cell := Vector2i(floori((p.x - bounds.position.x) / cell_size), floori((p.z - bounds.position.y) / cell_size))
	return Vector2i(clampi(cell.x, 0, grid.region.size.x - 1), clampi(cell.y, 0, grid.region.size.y - 1))


func nearest_free_cell(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell):
		return cell
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if grid.region.has_point(c) and not grid.is_point_solid(c):
					return c
	return cell


func line_free(a: Vector2i, b: Vector2i) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	if steps == 0:
		return true
	for i in range(steps + 1):
		var t := float(i) / steps
		var c := Vector2i(roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)))
		if grid.is_point_solid(c):
			return false
	return true


# Waypoints (y = 0) from `from` to `to`, empty when there is no route or when
# the two points share a cell.
func plan(from: Vector3, to: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if grid == null:
		return result
	var a := nearest_free_cell(world_to_cell(from))
	var b := nearest_free_cell(world_to_cell(to))
	var cells := grid.get_id_path(a, b)
	if cells.is_empty():
		return result
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not line_free(cells[i], cells[j]):
			j -= 1
		var c := cell_center(cells[j])
		result.append(Vector3(c.x, 0.0, c.y))
		i = j
	return result


func random_free_position(rng: RandomNumberGenerator, min_distance: float, max_distance: float, around: Vector3) -> Variant:
	for attempt in 40:
		var cell := Vector2i(rng.randi_range(0, grid.region.size.x - 1), rng.randi_range(0, grid.region.size.y - 1))
		if grid.is_point_solid(cell):
			continue
		var c := cell_center(cell)
		var p := Vector3(c.x, 0.0, c.y)
		var d := Vector2(p.x - around.x, p.z - around.z).length()
		if d >= min_distance and d <= max_distance:
			return p
	return null
