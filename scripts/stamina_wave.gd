extends Control
## Stamina as a sound wave. Full: the whole wave is white. Running turns it black
## from the right, and resting lets the white run back. The wave always moves a
## little, like breathing; harder while running and fast and shallow when spent.
## Created by player.gd; reads player.stamina and player.sprinting.

const WIDTH := 360.0
const HEIGHT := 44.0
const POINTS := 180
const WHITE := Color(.94, .94, .90, .92)
const BLACK := Color(.02, .02, .02, .95)
const SPENT_EDGE := Color(.55, .55, .52, .55)   # keeps the black part readable on a dark scene
const BLEND := .045                              # soft white/black boundary (fraction of the width)

var player   # the player.gd CharacterBody3D (stamina, sprinting, game, held)
var shown := 1.0            # 0..1, eased toward player.stamina / 100
var energy := 0.0           # 0 resting .. 1 running hard
var time := 0.0
var _shape := PackedFloat32Array()   # fixed envelope: thin line with a few bursts, like the sketch
var _phase := PackedFloat32Array()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 407
	var bursts: Array[Vector2] = []    # x (0..1), strength
	for x in [.04, .27, .45, .61, .76, .95]:
		bursts.append(Vector2(x + rng.randf_range(-.02, .02), rng.randf_range(.7, 1.0)))
	_shape.resize(POINTS)
	_phase.resize(POINTS)
	for i in POINTS:
		var x := float(i) / (POINTS - 1)
		var amp := .12 + rng.randf_range(0.0, .06)
		for b in bursts:
			amp = maxf(amp, b.y * exp(-pow((x - b.x) / .035, 2.0)))
		_shape[i] = amp
		_phase[i] = rng.randf_range(0.0, TAU)

func _process(delta: float) -> void:
	if player == null: return
	var game: Node = player.game as Node
	var active: bool = game != null and bool(game.get("playing")) and not bool(player.held)
	visible = active
	if get_tree().paused or not active: return
	time += delta
	shown = move_toward(shown, clampf(float(player.stamina) / 100.0, 0.0, 1.0), delta * 1.5)
	var running: bool = bool(player.sprinting)
	energy = move_toward(energy, 1.0 if running else 0.0, delta * (3.0 if running else 1.2))
	queue_redraw()

func fraction() -> float:
	return shown

# Height of the wave at sample i (−1..1 of the half height).
func sample(i: int) -> float:
	var spent := 1.0 - shown
	var speed := 5.0 + energy * 9.0 + spent * spent * 14.0      # breathing → running → panting
	var strength := .55 + energy * .4 - spent * spent * .25
	return _shape[i] * strength * sin(time * speed + _phase[i] + i * .9)

func _draw() -> void:
	var mid := HEIGHT * .5
	var step := WIDTH / (POINTS - 1)
	var cut := shown      # white left of cut, black right of it
	for i in POINTS - 1:
		var x0 := i * step
		var x1 := (i + 1) * step
		var a := Vector2(x0, mid - sample(i) * mid)
		var b := Vector2(x1, mid - sample(i + 1) * mid)
		var t := clampf((float(i) / (POINTS - 1) - cut) / BLEND + .5, 0.0, 1.0)   # 0 white .. 1 black
		if t > 0.0:
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(SPENT_EDGE, SPENT_EDGE.a * t), 3.0, true)
		draw_line(a, b, WHITE.lerp(BLACK, t), 1.6, true)
	# A faint centre line so a nearly flat stretch still reads as part of the bar.
	draw_line(Vector2(0, mid), Vector2(WIDTH, mid), Color(1, 1, 1, .08), 1.0)
