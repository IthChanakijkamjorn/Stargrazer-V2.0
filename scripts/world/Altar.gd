extends Node2D
class_name Altar
## Stargazer - Altar
## The summoning stone at the centre of the hub. Interacting with it opens the
## boss selection panel, where the player can see each encounter's
## requirements and spend a sigil to begin the fight.

signal requested_open()

var _time: float = 0.0

@onready var area: Area2D = $Area

func _ready() -> void:
	add_to_group("altar")
	z_index = int(position.y)
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func can_interact() -> bool:
	return true

func interact_prompt() -> String:
	return "E  Star Altar"

func interact(_player: Node) -> void:
	requested_open.emit()

func _draw() -> void:
	draw_circle(Vector2(0, 16), 34.0, Palette.SHADOW)

	# Stepped stone base.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-40, 18), Vector2(40, 18), Vector2(30, 2), Vector2(-30, 2),
	]), Color(0.16, 0.15, 0.28))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-28, 2), Vector2(28, 2), Vector2(20, -12), Vector2(-20, -12),
	]), Color(0.21, 0.2, 0.36))

	# Four standing shards, tilting slowly.
	for i in range(4):
		var lean := sin(_time * 0.7 + float(i)) * 1.6
		var x := -24.0 + float(i) * 16.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 4, -12), Vector2(x + 4, -12),
			Vector2(x + 3 + lean, -34), Vector2(x - 3 + lean, -34),
		]), Color(0.27, 0.25, 0.46))

	# Floating sigil ring.
	var lift := sin(_time * 1.4) * 3.0
	var center := Vector2(0, -46 + lift)
	var unlocked := GameState.data.count("cinder_sigil") > 0 or GameState.data.count("ring_sigil") > 0
	var accent: Color = Palette.GOLD if unlocked else Palette.CYAN_DIM
	Palette.draw_halo(self, center, 30.0, Color(accent.r, accent.g, accent.b, 0.3), 4)

	var pts := PackedVector2Array()
	for i in range(41):
		var a := TAU * float(i) / 40.0 + _time * 0.5
		pts.append(center + Vector2(cos(a) * 20.0, sin(a) * 7.0))
	draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.9), 2.5, true)

	# Orbiting motes mark the three chapter slots (two filled, one reserved).
	for i in range(3):
		var a := TAU * float(i) / 3.0 + _time * 0.9
		var p := center + Vector2(cos(a) * 20.0, sin(a) * 7.0)
		var filled := i < GameData.BOSSES.size()
		var c: Color = accent if filled else Palette.TEXT_DIM
		draw_circle(p, 3.4, c)

	# Core star.
	_draw_star(center, 9.0, 3.6, 5, Color(accent.r, accent.g, accent.b, 0.95))

func _draw_star(center: Vector2, outer: float, inner: float, points: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var r := outer if i % 2 == 0 else inner
		var a := TAU * float(i) / float(points * 2) - PI * 0.5 + _time * 0.3
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
