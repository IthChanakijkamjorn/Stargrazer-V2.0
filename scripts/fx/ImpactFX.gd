extends Node2D
class_name ImpactFX
## Stargazer - ImpactFX
## Short-lived, self-freeing impact flourishes: an expanding shockwave ring
## plus a handful of sparks. Used for meteor landings, boss phase changes and
## victory pops. Drawn in code, so it renders correctly in the Compatibility
## renderer where glow/shader effects are unavailable.

var color: Color = Palette.EMBER
var max_radius: float = 90.0
var duration: float = 0.45
var spark_count: int = 10

var _t: float = 0.0
var _sparks: Array = []

static func burst(parent: Node, pos: Vector2, p_color: Color = Palette.EMBER, p_radius: float = 90.0, p_duration: float = 0.45) -> ImpactFX:
	if parent == null or not is_instance_valid(parent):
		return null
	var fx := ImpactFX.new()
	fx.color = p_color
	fx.max_radius = p_radius
	fx.duration = p_duration
	parent.add_child(fx)
	fx.global_position = pos
	return fx

func _ready() -> void:
	z_index = 140
	for i in range(spark_count):
		var a := randf() * TAU
		_sparks.append({
			"dir": Vector2(cos(a), sin(a)),
			"speed": randf_range(0.55, 1.0),
			"size": randf_range(2.0, 4.5),
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= duration:
		queue_free()

func _draw() -> void:
	var t: float = clampf(_t / maxf(duration, 0.001), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var fade: float = 1.0 - t

	# Core flash.
	draw_circle(Vector2.ZERO, max_radius * 0.28 * (1.0 - eased), Color(1, 1, 1, fade * 0.8))
	# Shockwave ring.
	var r := max_radius * eased
	var pts := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, Color(color.r, color.g, color.b, fade * 0.9), 4.0 * fade + 1.0, true)
	# Sparks.
	for s in _sparks:
		var p: Vector2 = s["dir"] * r * float(s["speed"])
		draw_circle(p, float(s["size"]) * fade, Color(color.r, color.g, color.b, fade))
