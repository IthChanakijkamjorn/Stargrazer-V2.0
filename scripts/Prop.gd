extends Node2D
class_name Prop
## Stargazer - Prop
## A single code-drawn decoration/obstacle (rock, tree, bush, flower, crystal).
## Everything is drawn in _draw(), so NO art files are needed.
## Set `kind` before adding to the tree, or use Prop.make(kind).

enum Kind { ROCK, TREE, BUSH, FLOWER, CRYSTAL }

@export var kind: Kind = Kind.ROCK
## A per-instance random seed so identical kinds still look slightly different.
@export var variation: float = 0.0

func _ready() -> void:
	if variation == 0.0:
		variation = randf()
	# Slight idle sway for living things (trees, bushes, flowers).
	if kind in [Kind.TREE, Kind.BUSH, Kind.FLOWER]:
		_start_sway()
	queue_redraw()

# Factory helper.
static func make(p_kind: Kind) -> Prop:
	var p := Prop.new()
	p.kind = p_kind
	return p

func _start_sway() -> void:
	var amount := 0.04 + variation * 0.03
	var speed := 1.6 + variation * 0.8
	var t := create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation", amount, speed)
	t.tween_property(self, "rotation", -amount, speed)

func _draw() -> void:
	match kind:
		Kind.ROCK:
			_draw_rock()
		Kind.TREE:
			_draw_tree()
		Kind.BUSH:
			_draw_bush()
		Kind.FLOWER:
			_draw_flower()
		Kind.CRYSTAL:
			_draw_crystal()

# --- Individual drawings -------------------------------------------------

func _draw_rock() -> void:
	var body := PackedVector2Array([
		Vector2(-16, 6), Vector2(-12, -8), Vector2(-2, -13),
		Vector2(10, -9), Vector2(16, 2), Vector2(11, 10), Vector2(-6, 12)
	])
	# Soft shadow.
	draw_circle(Vector2(0, 12), 14, Color(0, 0, 0, 0.18))
	draw_colored_polygon(body, Color(0.42, 0.45, 0.52))
	# Top highlight.
	var top := PackedVector2Array([
		Vector2(-12, -8), Vector2(-2, -13), Vector2(10, -9), Vector2(2, -4), Vector2(-6, -4)
	])
	draw_colored_polygon(top, Color(0.55, 0.58, 0.66))

func _draw_tree() -> void:
	# Shadow.
	draw_circle(Vector2(0, 20), 16, Color(0, 0, 0, 0.18))
	# Trunk.
	draw_rect(Rect2(-4, 2, 8, 22), Color(0.4, 0.26, 0.16))
	# Canopy: three overlapping circles, star-themed teal-green.
	var leaf := Color(0.2, 0.55, 0.45)
	var leaf_hi := Color(0.3, 0.7, 0.55)
	draw_circle(Vector2(-10, -4), 14, leaf)
	draw_circle(Vector2(10, -4), 14, leaf)
	draw_circle(Vector2(0, -16), 16, leaf)
	draw_circle(Vector2(-2, -20), 9, leaf_hi)

func _draw_bush() -> void:
	draw_circle(Vector2(0, 8), 12, Color(0, 0, 0, 0.15))
	var c := Color(0.24, 0.5, 0.32)
	var hi := Color(0.34, 0.62, 0.4)
	draw_circle(Vector2(-8, 2), 9, c)
	draw_circle(Vector2(8, 2), 9, c)
	draw_circle(Vector2(0, -3), 11, c)
	draw_circle(Vector2(-2, -6), 5, hi)

func _draw_flower() -> void:
	# Stem.
	draw_line(Vector2(0, 10), Vector2(0, -2), Color(0.3, 0.6, 0.35), 2.0)
	# Petals — color depends on variation for a wildflower field feel.
	var petal_colors := [
		Color(0.95, 0.5, 0.6), Color(0.7, 0.6, 0.95),
		Color(0.95, 0.85, 0.4), Color(0.6, 0.85, 0.95)
	]
	var petal: Color = petal_colors[int(variation * petal_colors.size()) % petal_colors.size()]
	for i in range(5):
		var a := TAU * i / 5.0
		draw_circle(Vector2(cos(a), sin(a)) * 5.0 + Vector2(0, -6), 3.5, petal)
	draw_circle(Vector2(0, -6), 2.5, Color(1, 0.9, 0.5))

func _draw_crystal() -> void:
	# Glowing star-crystal that ties into the cosmic theme.
	draw_circle(Vector2(0, 8), 10, Color(0, 0, 0, 0.15))
	var glow := Color(0.5, 0.8, 1.0, 0.25)
	draw_circle(Vector2(0, -2), 16, glow)
	var crystal := PackedVector2Array([
		Vector2(0, -18), Vector2(7, -2), Vector2(3, 10),
		Vector2(-3, 10), Vector2(-7, -2)
	])
	draw_colored_polygon(crystal, Color(0.55, 0.8, 1.0))
	# Facet highlight.
	var facet := PackedVector2Array([Vector2(0, -18), Vector2(7, -2), Vector2(0, -2)])
	draw_colored_polygon(facet, Color(0.8, 0.95, 1.0))
