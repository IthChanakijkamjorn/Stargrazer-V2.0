extends Node2D
class_name Starfield
## Stargazer - Starfield
## A layered, parallax, twinkling star background plus slow drifting nebula
## blobs. Three depth layers give the sky real depth without any art files.
## Drawn behind everything; follows the active camera.

@export var star_count: int = 260
@export var area: Vector2 = Vector2(4200, 3000)
@export var nebula_count: int = 7
## Menus have no camera, so the field centres itself on the viewport and
## drifts gently instead of tracking the player.
@export var static_background: bool = false

## Parallax factor per layer (0 = pinned to the sky, 1 = moves with the world).
const LAYER_PARALLAX := [0.06, 0.14, 0.26]

var _stars: Array = []
var _nebulae: Array = []
var _time: float = 0.0
var _camera: Camera2D = null

func _ready() -> void:
	z_index = -100
	top_level = true
	_generate()

func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_stars.clear()
	for i in range(star_count):
		_stars.append({
			"pos": Vector2(
				rng.randf_range(-area.x * 0.5, area.x * 0.5),
				rng.randf_range(-area.y * 0.5, area.y * 0.5)
			),
			"layer": i % LAYER_PARALLAX.size(),
			"size": rng.randf_range(0.7, 2.4),
			"alpha": rng.randf_range(0.25, 0.95),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.5, 2.2),
			"tint": rng.randf(),
		})
	_nebulae.clear()
	for i in range(nebula_count):
		_nebulae.append({
			"pos": Vector2(
				rng.randf_range(-area.x * 0.45, area.x * 0.45),
				rng.randf_range(-area.y * 0.45, area.y * 0.45)
			),
			"radius": rng.randf_range(180.0, 420.0),
			"tint": Palette.VIOLET if i % 2 == 0 else Palette.CYAN_DIM,
			"phase": rng.randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	_time += delta
	if static_background:
		var rect := get_viewport_rect()
		global_position = rect.size * 0.5 + Vector2(sin(_time * 0.05) * 60.0, _time * 6.0)
	else:
		if _camera == null or not is_instance_valid(_camera):
			_camera = _find_camera()
		if _camera:
			global_position = _camera.get_screen_center_position()
	queue_redraw()

func _find_camera() -> Camera2D:
	var viewport := get_viewport()
	return viewport.get_camera_2d() if viewport else null

func _draw() -> void:
	var cam_pos := global_position
	# Nebulae sit furthest back and drift the least.
	for n in _nebulae:
		var pulse: float = 0.5 + 0.5 * sin(_time * 0.2 + float(n["phase"]))
		var tint: Color = n["tint"]
		var c := Color(tint.r, tint.g, tint.b, 0.035 + 0.02 * pulse)
		var base: Vector2 = (n["pos"] as Vector2) - cam_pos * 0.96
		for ring in range(3):
			var r: float = float(n["radius"]) * (1.0 - ring * 0.28)
			draw_circle(base, r, c)

	for s in _stars:
		var parallax: float = LAYER_PARALLAX[int(s["layer"])]
		var p: Vector2 = (s["pos"] as Vector2) - cam_pos * (1.0 - parallax)
		# Wrap so the field never visibly ends.
		p.x = wrapf(p.x, -area.x * 0.5, area.x * 0.5)
		p.y = wrapf(p.y, -area.y * 0.5, area.y * 0.5)
		var twinkle: float = 0.55 + 0.45 * sin(_time * float(s["speed"]) + float(s["phase"]))
		var a: float = float(s["alpha"]) * twinkle
		var col := Color(1, 1, 1, a)
		var tint_roll: float = float(s["tint"])
		if tint_roll > 0.82:
			col = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, a)
		elif tint_roll > 0.6:
			col = Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, a)
		var size: float = float(s["size"]) * (0.7 + 0.3 * float(int(s["layer"])))
		draw_circle(p, size, col)
		# The brightest stars get a small cross flare.
		if size > 2.0 and twinkle > 0.85:
			draw_line(p + Vector2(-size * 2.4, 0), p + Vector2(size * 2.4, 0), Color(col.r, col.g, col.b, a * 0.5), 1.0)
			draw_line(p + Vector2(0, -size * 2.4), p + Vector2(0, size * 2.4), Color(col.r, col.g, col.b, a * 0.5), 1.0)
