extends Node2D
class_name Prop
## Stargazer - Prop
## Purely decorative cosmic scenery drawn in code: glass-spire trees, drifting
## shard clusters, moon-moss tufts and starlight flowers. Living props sway,
## crystalline ones shimmer. No art files required.

enum Kind { SPIRE, SHARD, MOSS, BLOOM, MONOLITH }

@export var kind: Kind = Kind.SHARD
@export var variation: float = 0.0

var _time: float = 0.0

static func make(p_kind: Kind, p_variation: float = -1.0) -> Prop:
	var p := Prop.new()
	p.kind = p_kind
	p.variation = randf() if p_variation < 0.0 else p_variation
	return p

func _ready() -> void:
	if variation <= 0.0:
		variation = randf()
	if kind == Kind.SPIRE or kind == Kind.MOSS or kind == Kind.BLOOM:
		_start_sway()
	set_process(kind == Kind.SHARD or kind == Kind.MONOLITH)
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _start_sway() -> void:
	var amount := 0.03 + variation * 0.03
	var speed := 1.8 + variation * 1.2
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation", amount, speed)
	t.tween_property(self, "rotation", -amount, speed)

func _draw() -> void:
	match kind:
		Kind.SPIRE:
			_draw_spire()
		Kind.SHARD:
			_draw_shard()
		Kind.MOSS:
			_draw_moss()
		Kind.BLOOM:
			_draw_bloom()
		Kind.MONOLITH:
			_draw_monolith()

func _shadow(offset_y: float, radius: float) -> void:
	draw_circle(Vector2(0, offset_y), radius, Palette.SHADOW)

## A tall glass tree whose canopy is a cluster of translucent leaves.
func _draw_spire() -> void:
	_shadow(20, 15)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3, 22), Vector2(3, 22), Vector2(2, -6), Vector2(-2, -6),
	]), Color(0.22, 0.2, 0.34))
	var leaf := Color(0.2, 0.42, 0.52)
	var leaf_hi := Color(0.32, 0.62, 0.7)
	for i in range(5):
		var a := TAU * float(i) / 5.0 + variation * TAU
		var c := Vector2(cos(a) * 11.0, sin(a) * 7.0 - 12.0)
		draw_circle(c, 10.0 - float(i) * 0.7, leaf)
	draw_circle(Vector2(-2, -19), 8.0, leaf_hi)
	draw_circle(Vector2(-4, -22), 3.4, Color(0.55, 0.85, 0.9, 0.8))

## A cluster of floating starlight shards.
func _draw_shard() -> void:
	_shadow(9, 11)
	var bob := sin(_time * 1.6 + variation * TAU) * 2.0
	Palette.draw_halo(self, Vector2(0, -6 + bob), 22.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.18), 3)
	var crystal := PackedVector2Array([
		Vector2(0, -20 + bob), Vector2(7, -4 + bob), Vector2(3, 9 + bob),
		Vector2(-3, 9 + bob), Vector2(-7, -4 + bob),
	])
	draw_colored_polygon(crystal, Color(0.42, 0.68, 0.95))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -20 + bob), Vector2(7, -4 + bob), Vector2(0, -3 + bob),
	]), Color(0.72, 0.92, 1.0))
	draw_circle(Vector2(-9, 2 + bob * 0.6), 3.0, Color(0.5, 0.75, 1.0))
	draw_circle(Vector2(9, 4 - bob * 0.6), 2.2, Color(0.5, 0.75, 1.0))

func _draw_moss() -> void:
	_shadow(7, 11)
	var c := Color(0.22, 0.34, 0.46)
	var hi := Color(0.32, 0.5, 0.6)
	draw_circle(Vector2(-7, 2), 8.0, c)
	draw_circle(Vector2(7, 2), 8.0, c)
	draw_circle(Vector2(0, -3), 10.0, c)
	draw_circle(Vector2(-2, -6), 4.6, hi)
	for i in range(3):
		var x := -6.0 + float(i) * 6.0
		draw_line(Vector2(x, -4), Vector2(x + 1.5, -12), hi, 1.2)

func _draw_bloom() -> void:
	_shadow(9, 8)
	draw_line(Vector2(0, 9), Vector2(0, -3), Color(0.28, 0.42, 0.46), 1.8)
	var petal_colors := [Palette.CYAN, Palette.VIOLET, Palette.GOLD, Color(0.95, 0.55, 0.75)]
	var petal: Color = petal_colors[int(variation * petal_colors.size()) % petal_colors.size()]
	for i in range(6):
		var a := TAU * float(i) / 6.0
		draw_circle(Vector2(cos(a), sin(a)) * 5.0 + Vector2(0, -7), 3.2, petal)
	draw_circle(Vector2(0, -7), 2.2, Color(1, 0.95, 0.8))

## A tall standing stone: adds silhouette variety and blocks sight lines.
func _draw_monolith() -> void:
	_shadow(20, 16)
	var sway := sin(_time * 0.6 + variation * TAU) * 0.6
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 20), Vector2(10, 20), Vector2(7, -24 + sway), Vector2(-6, -20 + sway),
	]), Color(0.17, 0.16, 0.3))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10, 20), Vector2(-4, 20), Vector2(-3, -21 + sway), Vector2(-6, -20 + sway),
	]), Color(0.24, 0.23, 0.42))
	# Faint engraved constellation.
	var marks := [Vector2(0, -12), Vector2(3, -4), Vector2(-2, 3), Vector2(2, 11)]
	for i in range(marks.size()):
		draw_circle(marks[i] + Vector2(0, sway), 1.4, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.6))
		if i > 0:
			draw_line(marks[i - 1] + Vector2(0, sway), marks[i] + Vector2(0, sway), Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.25), 1.0)
