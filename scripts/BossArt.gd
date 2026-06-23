extends Node2D
class_name BossArt
## Stargazer - BossArt
## A code-drawn ringed planet (Saturn). Glow halo, shaded sphere, tilted rings.
## No art files required. The owning Boss script rotates / animates this node.

@export var planet_radius: float = 22.0
@export var ring_tilt: float = 0.35   ## Vertical squash of the rings (0 = edge-on).

# Palette
const COL_GLOW := Color(0.95, 0.8, 0.45, 0.18)
const COL_PLANET := Color(0.95, 0.78, 0.42)
const COL_PLANET_DARK := Color(0.78, 0.6, 0.3)
const COL_PLANET_HI := Color(1.0, 0.9, 0.6)
const COL_RING_OUTER := Color(0.85, 0.72, 0.55, 0.9)
const COL_RING_INNER := Color(0.7, 0.58, 0.42, 0.9)

func _draw() -> void:
	# --- Back half of the rings (drawn first so the planet overlaps them) ---
	_draw_ring(false)

	# --- Glow halo ---
	draw_circle(Vector2.ZERO, planet_radius * 1.7, COL_GLOW)
	draw_circle(Vector2.ZERO, planet_radius * 1.35, COL_GLOW)

	# --- Planet sphere ---
	draw_circle(Vector2.ZERO, planet_radius, COL_PLANET)
	# Shaded lower-right crescent for a sense of volume.
	draw_circle(Vector2(planet_radius * 0.28, planet_radius * 0.28), planet_radius * 0.82, COL_PLANET_DARK)
	draw_circle(Vector2.ZERO, planet_radius * 0.78, COL_PLANET)
	# Banding stripes (Saturn's atmosphere).
	var band := Color(0.88, 0.7, 0.36, 0.5)
	draw_line(Vector2(-planet_radius * 0.85, -4), Vector2(planet_radius * 0.85, -4), band, 2.0)
	draw_line(Vector2(-planet_radius * 0.7, 4), Vector2(planet_radius * 0.7, 4), band, 2.0)
	# Upper-left highlight.
	draw_circle(Vector2(-planet_radius * 0.35, -planet_radius * 0.35), planet_radius * 0.22, COL_PLANET_HI)

	# --- Front half of the rings (over the planet) ---
	_draw_ring(true)

func _draw_ring(front: bool) -> void:
	# Draw an elliptical ring as a band between two ellipses.
	# We approximate with line segments around the ellipse.
	var r_outer := planet_radius * 2.05
	var r_inner := planet_radius * 1.45
	var segments := 48
	var pts_outer := PackedVector2Array()
	var pts_inner := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * i / segments
		# Only the front (lower) or back (upper) half depending on `front`.
		var sy := sin(a)
		if front and sy < 0.0:
			continue
		if not front and sy > 0.0:
			continue
		pts_outer.append(Vector2(cos(a) * r_outer, sin(a) * r_outer * ring_tilt))
		pts_inner.append(Vector2(cos(a) * r_inner, sin(a) * r_inner * ring_tilt))
	if pts_outer.size() >= 2:
		draw_polyline(pts_outer, COL_RING_OUTER, 5.0, true)
		draw_polyline(pts_inner, COL_RING_INNER, 4.0, true)
