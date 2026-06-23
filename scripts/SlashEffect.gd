extends Node2D
class_name SlashEffect
## Stargazer - SlashEffect
## A quick white arc that sweeps in the attack direction, then fades.
## Purely code-drawn (uses _draw), so no art assets are needed.

var _angle_start: float = -0.6
var _angle_end: float = 0.6
var _radius: float = 46.0
var _progress: float = 0.0
var _color: Color = Color(1, 1, 1, 0.9)

# Factory: spawn a slash at `world_pos`, pointing along `dir`.
static func spawn(parent: Node, world_pos: Vector2, dir: Vector2) -> void:
	var scene: PackedScene = load("res://scenes/SlashEffect.tscn")
	if scene == null:
		return
	var fx := scene.instantiate()
	parent.add_child(fx)
	fx.global_position = world_pos
	fx.rotation = dir.angle()
	fx._play()

func _play() -> void:
	_progress = 0.0
	var t := create_tween()
	t.tween_method(_set_progress, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.18).set_delay(0.06)
	t.tween_callback(queue_free)

func _set_progress(v: float) -> void:
	_progress = v
	queue_redraw()

func _draw() -> void:
	# Draw an arc whose sweep grows with progress, like a blade swing.
	var points := PackedVector2Array()
	var sweep_end: float = lerp(_angle_start, _angle_end, _progress)
	var steps := 16
	for i in range(steps + 1):
		var a: float = lerp(_angle_start, sweep_end, float(i) / steps)
		points.append(Vector2(cos(a), sin(a)) * _radius)
	if points.size() >= 2:
		draw_polyline(points, _color, 4.0, true)
