extends RefCounted
## Shared deterministic placement for terrain, grass roots and player spawn.
const HALF_SIZE := 1024.0
const STATUE_POSITION := Vector3(0.0, 0.0, -16.0)
const WATER_LEVEL := -0.70
const GRID_STEP := 4.0

static func height_raw(x: float, z: float) -> float:
	var hill := 3.4 * exp(-pow(x/25.0,2.0)-pow((z+16.0)/27.0,2.0))
	hill += 1.35 * exp(-pow((x+6.0)/14.0,2.0)-pow((z-6.0)/13.0,2.0))
	var lake := -6.3 * exp(-2.0*(pow((x-48.0)/58.0,2.0)+pow((z+60.0)/66.0,2.0)))
	var mountain := 57.0 * exp(-pow((x+165.0)/115.0,2.0)-pow((z+265.0)/82.0,2.0))
	mountain += 34.0 * exp(-pow((x-175.0)/150.0,2.0)-pow((z+330.0)/95.0,2.0))
	var distance := Vector2(x,z).length()
	var ridges := (sin(x*.024+cos(z*.014))*3.2+sin(z*.021)*2.1)*smoothstep(65.0,170.0,distance)
	return maxf(hill + lake + mountain + ridges + sin(x*.019)*.7 + cos(z*.018)*.4, WATER_LEVEL-.75)

static func height_at(x: float, z: float) -> float:
	# Match the rendered/collision triangles, so grass roots never float on slopes.
	var step_size := GRID_STEP if absf(x)<256.0 and absf(z)<256.0 else 32.0
	var gx := floorf(x/step_size)*step_size
	var gz := floorf(z/step_size)*step_size
	var u := (x-gx)/step_size
	var v := (z-gz)/step_size
	var a := height_raw(gx,gz)
	var b := height_raw(gx+step_size,gz)
	var c := height_raw(gx,gz+step_size)
	if u+v<=1.0: return a+(b-a)*u+(c-a)*v
	var d := height_raw(gx+step_size,gz+step_size)
	return d+(c-d)*(1.0-u)+(b-d)*(1.0-v)

static func grass_density(x: float, z: float) -> float:
	var clearing := Vector2(x, z + 16.0).length()
	if height_at(x,z)<WATER_LEVEL+.08: return 0.0
	var density := smoothstep(2.9, 5.1, clearing)
	# A faint flattened approach, not a paved path or a quest marker.
	if z > -16.0 and z < 28.0:
		var centre := sin((z + 16.0) * 0.12) * 0.65
		density *= lerpf(0.30, 1.0, smoothstep(0.35, 1.2, absf(x - centre)))
	return density
