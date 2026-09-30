extends Node2D
class_name SaturnArt
## Stargazer - Saturn, The Ringbound Sovereign (art)
## A large layered silhouette: a banded golden-violet sphere, a crowned
## "face" of light, and three independently animated orbital rings. In phase
## two the rings detach and orbit on their own axes, which visually sells the
## mechanical change without a palette swap.

const BODY_R := 46.0

var accent: Color = Palette.GOLD

var _time: float = 0.0
var _rings: Array = []
var _separated: bool = false
var _cast: float = 0.0
var _cast_dir: float = 1.0
var _windup: float = 0.0
var _dying: bool = false

func _ready() -> void:
	z_index = 80
	_rings = [
		{"radius": 1.55, "tilt": 0.34, "speed": 0.55, "phase": 0.0, "thickness": 6.0, "color": Palette.GOLD},
		{"radius": 1.85, "tilt": 0.30, "speed": -0.4, "phase": 1.1, "thickness": 5.0, "color": Palette.VIOLET},
		{"radius": 2.2, "tilt": 0.26, "speed": 0.28, "phase": 2.3, "thickness": 4.0, "color": Palette.CYAN_DIM},
	]
	set_process(true)

func set_accent(c: Color) -> void:
	accent = c
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_cast = maxf(0.0, _cast - delta)
	_windup = maxf(0.0, _windup - delta)
	var speed_scale := 1.0 + (1.6 if _cast > 0.0 else 0.0) + (1.0 if _separated else 0.0)
	for r in _rings:
		r["phase"] = float(r["phase"]) + delta * float(r["speed"]) * speed_scale * (_cast_dir if _cast > 0.0 else 1.0)
	queue_redraw()

func play_cast(duration: float, direction: float = 1.0) -> void:
	_cast = duration
	_cast_dir = 1.0 if direction >= 0.0 else -1.0

func play_windup(duration: float) -> void:
	_windup = duration
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.88, 1.12), maxf(duration, 0.05) * 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)

func play_recover() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.06, 0.94), 0.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_SINE)

func separate_rings() -> void:
	_separated = true

func play_phase_change(_phase: int) -> void:
	_separated = true
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.35, 1.35), 0.22).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

func play_death() -> void:
	_dying = true
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(1.5, 0.05), 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 1.0)

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	draw_circle(Vector2(0, BODY_R + 22), BODY_R * 0.95, Palette.SHADOW)

	# Back halves of the rings first, so the planet occludes them.
	for i in range(_rings.size()):
		_draw_ring(i, false)

	_draw_body()

	for i in range(_rings.size()):
		_draw_ring(i, true)

func _draw_body() -> void:
	var breathe := 1.0 + sin(_time * 1.3) * 0.02
	var r := BODY_R * breathe

	Palette.draw_halo(self, Vector2.ZERO, r * 1.9, Color(accent.r, accent.g, accent.b, 0.16 + (0.12 if _cast > 0.0 else 0.0)), 5)

	draw_circle(Vector2.ZERO, r, Color(0.72, 0.58, 0.34))
	draw_circle(Vector2(r * 0.2, r * 0.22), r * 0.9, Color(0.5, 0.38, 0.26))
	draw_circle(Vector2(-r * 0.1, -r * 0.12), r * 0.78, Color(0.85, 0.7, 0.42))

	# Atmospheric bands, gently rippling.
	for i in range(5):
		var y := -r * 0.62 + float(i) * r * 0.31
		var half := sqrt(maxf(r * r - y * y, 0.0)) * 0.94
		var wobble := sin(_time * 0.9 + float(i)) * 2.0
		var band := Color(0.38, 0.3, 0.46, 0.55) if i % 2 == 0 else Color(0.95, 0.82, 0.5, 0.35)
		draw_line(Vector2(-half, y + wobble), Vector2(half, y - wobble), band, r * 0.14)

	# The Sovereign's "face": a crowned slit of light.
	var eye_y := -r * 0.12
	var eye_w := r * 0.52
	Palette.draw_halo(self, Vector2(0, eye_y), r * 0.6, Color(1, 0.95, 0.8, 0.3), 3)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-eye_w, eye_y), Vector2(0, eye_y - r * 0.16),
		Vector2(eye_w, eye_y), Vector2(0, eye_y + r * 0.16),
	]), Color(1.0, 0.95, 0.75))
	draw_circle(Vector2(0, eye_y), r * 0.09, Color(0.25, 0.14, 0.3))

	# Crown spikes flare during a windup.
	var flare := 1.0 + (0.4 if _windup > 0.0 else 0.0)
	for i in range(7):
		var a := PI + TAU * (float(i) + 0.5) / 14.0
		var base := Vector2(cos(a), sin(a)) * r * 0.95
		var tip := Vector2(cos(a), sin(a)) * r * 1.25 * flare
		var side := Vector2(-sin(a), cos(a)) * r * 0.07
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(accent.r, accent.g, accent.b, 0.9))

## Each ring is a band between two ellipses; in phase two the rings gain their
## own tilt offsets so they visibly detach from the planet's axis.
func _draw_ring(index: int, front: bool) -> void:
	var ring: Dictionary = _rings[index]
	var r_outer := BODY_R * float(ring["radius"])
	var r_inner := r_outer - float(ring["thickness"]) * 2.2
	var tilt := float(ring["tilt"])
	var spin := float(ring["phase"])
	var axis := 0.0
	if _separated:
		axis = sin(spin * 0.5 + float(index)) * 0.55
		tilt += sin(spin * 0.3) * 0.12

	var segments := 56
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		var sy := sin(a)
		if front and sy < 0.0:
			continue
		if not front and sy > 0.0:
			continue
		var po := Vector2(cos(a) * r_outer, sin(a) * r_outer * tilt).rotated(axis)
		var pi_pt := Vector2(cos(a) * r_inner, sin(a) * r_inner * tilt).rotated(axis)
		outer.append(po)
		inner.append(pi_pt)
	if outer.size() < 2:
		return
	var col: Color = ring["color"]
	draw_polyline(outer, Color(col.r, col.g, col.b, 0.9), float(ring["thickness"]), true)
	draw_polyline(inner, Color(col.r, col.g, col.b, 0.55), float(ring["thickness"]) * 0.7, true)

	# Ring "stones" that rotate with the band; they make the spin direction
	# readable, which matters because the fans follow it.
	var stones := 10
	for i in range(stones):
		var a := TAU * float(i) / float(stones) + spin
		var sy := sin(a)
		if front and sy < 0.0:
			continue
		if not front and sy > 0.0:
			continue
		var mid := (r_outer + r_inner) * 0.5
		var p := Vector2(cos(a) * mid, sin(a) * mid * tilt).rotated(axis)
		draw_circle(p, float(ring["thickness"]) * 0.55, Color(1, 1, 1, 0.75))

func is_dying() -> bool:
	return _dying
