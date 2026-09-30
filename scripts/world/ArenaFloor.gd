extends Node2D
class_name ArenaFloor
## Stargazer - Arena floor
## A bounded circular battlefield drawn procedurally: a cracked astral plate
## with a bright rim so the arena edge is unmistakable, plus faint guide rings
## that help the player read distance during telegraphed attacks.

var radius: float = 470.0
var accent: Color = Palette.GOLD

var _time: float = 0.0
var _cracks: Array = []
var _motes: Array = []

func _ready() -> void:
	z_index = -50
	set_process(true)

func configure(p_radius: float, p_accent: Color) -> void:
	radius = p_radius
	accent = p_accent
	_bake()
	queue_redraw()

func _bake() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_cracks.clear()
	for i in range(30):
		var a := rng.randf() * TAU
		var start := Vector2(cos(a), sin(a)) * rng.randf_range(radius * 0.1, radius * 0.85)
		var pts := PackedVector2Array([start])
		var dir := Vector2(cos(a), sin(a)).rotated(rng.randf_range(-1.2, 1.2))
		var p := start
		for step in range(rng.randi_range(2, 4)):
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			p += dir * rng.randf_range(20.0, 52.0)
			if p.length() > radius * 0.94:
				break
			pts.append(p)
		if pts.size() > 1:
			_cracks.append(pts)
	_motes.clear()
	for i in range(46):
		_motes.append({
			"angle": rng.randf() * TAU,
			"dist": rng.randf_range(radius * 0.2, radius * 0.98),
			"speed": rng.randf_range(-0.16, 0.16),
			"size": rng.randf_range(1.0, 2.6),
			"phase": rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Plate.
	draw_circle(Vector2.ZERO, radius + 14.0, Color(0.05, 0.05, 0.11, 0.9))
	draw_circle(Vector2.ZERO, radius, Palette.GROUND_C)
	draw_circle(Vector2(0, -radius * 0.12), radius * 0.86, Palette.GROUND_A)
	draw_circle(Vector2(0, -radius * 0.24), radius * 0.6, Palette.GROUND_B)

	for pts in _cracks:
		draw_polyline(pts, Color(0.06, 0.06, 0.13, 0.75), 2.4, true)

	# Guide rings: subtle, evenly spaced, useful for judging attack ranges.
	for i in range(1, 5):
		var rr := radius * float(i) / 5.0
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 72, Color(1, 1, 1, 0.045), 1.5, true)

	# Bright, pulsing rim so the boundary reads over any effect.
	var pulse := 0.55 + 0.2 * sin(_time * 1.4)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 128, Color(accent.r, accent.g, accent.b, pulse), 5.0, true)
	draw_arc(Vector2.ZERO, radius - 7.0, 0.0, TAU, 128, Color(accent.r, accent.g, accent.b, pulse * 0.35), 2.0, true)

	# Drifting motes for a sense of motion.
	for m in _motes:
		var a: float = float(m["angle"]) + _time * float(m["speed"])
		var p := Vector2(cos(a), sin(a)) * float(m["dist"])
		var twinkle: float = 0.4 + 0.6 * sin(_time * 1.6 + float(m["phase"]))
		draw_circle(p, float(m["size"]), Color(accent.r, accent.g, accent.b, 0.25 * twinkle))
