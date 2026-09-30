extends Node2D
class_name SlashEffect
## Stargazer - SlashEffect
## A crescent blade arc that sweeps through the swing direction and fades.
## Purely code-drawn, self-freeing, and safe under the Compatibility renderer.

var _arc: float = deg_to_rad(105.0)
var _radius: float = 52.0
var _progress: float = 0.0
var _color: Color = Palette.CYAN

static func spawn(parent: Node, world_pos: Vector2, dir: Vector2, arc: float = deg_to_rad(105.0), radius: float = 52.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var fx := SlashEffect.new()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx.rotation = dir.angle()
	fx._arc = arc
	fx._radius = radius
	fx.z_index = 60
	fx._play()

func _play() -> void:
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.05)
	t.tween_callback(queue_free)

func _set_progress(v: float) -> void:
	_progress = v
	queue_redraw()

func _draw() -> void:
	if _progress <= 0.001:
		return
	var start := -_arc * 0.5
	var end: float = lerpf(start, _arc * 0.5, _progress)
	var steps := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(steps + 1):
		var a: float = lerpf(start, end, float(i) / float(steps))
		# The crescent is fattest in the middle of the sweep.
		var thickness: float = 9.0 * sin(PI * float(i) / float(steps)) + 2.0
		var d := Vector2(cos(a), sin(a))
		outer.append(d * (_radius + thickness * 0.5))
		inner.append(d * (_radius - thickness * 0.5))
	inner.reverse()
	var poly := outer
	for p in inner:
		poly.append(p)
	if poly.size() >= 3:
		draw_colored_polygon(poly, Color(_color.r, _color.g, _color.b, 0.55))
		draw_polyline(outer, Color(1, 1, 1, 0.85), 2.0, true)
