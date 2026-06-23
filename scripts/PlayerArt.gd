extends Node2D
## Stargazer - PlayerArt
## A code-drawn top-down character: shadow, cloak, body, head, eyes.
## Faces a direction set via set_facing(). No art files required.

var facing: Vector2 = Vector2.DOWN

# Palette
const COL_SHADOW := Color(0, 0, 0, 0.22)
const COL_CLOAK := Color(0.18, 0.36, 0.62)
const COL_CLOAK_HI := Color(0.28, 0.5, 0.8)
const COL_BODY := Color(0.4, 0.8, 1.0)
const COL_SKIN := Color(0.98, 0.85, 0.7)
const COL_EYE := Color(0.1, 0.12, 0.2)

func set_facing(dir: Vector2) -> void:
	facing = dir
	queue_redraw()

func _draw() -> void:
	# Ground shadow (slightly offset down).
	draw_circle(Vector2(0, 12), 11, COL_SHADOW)

	# Cloak behind the body.
	var cloak := PackedVector2Array([
		Vector2(-12, -6), Vector2(12, -6), Vector2(9, 14), Vector2(-9, 14)
	])
	draw_colored_polygon(cloak, COL_CLOAK)
	# Cloak highlight stripe.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -6), Vector2(-4, -6), Vector2(-3, 14), Vector2(-9, 14)
	]), COL_CLOAK_HI)

	# Body (rounded square torso).
	draw_circle(Vector2(0, 2), 9, COL_BODY)

	# Head.
	draw_circle(Vector2(0, -8), 7, COL_SKIN)

	# Eyes — placed based on facing so the character "looks" where it moves.
	_draw_eyes()

func _draw_eyes() -> void:
	# Default (facing down / toward camera): two eyes on the face.
	var head_center := Vector2(0, -8)
	var look := facing
	if look == Vector2.ZERO:
		look = Vector2.DOWN

	# Offset eyes toward the facing direction.
	var look_offset := look * 2.0

	if look.y < -0.5:
		# Facing up: show back of head (no eyes), maybe a hair tuft.
		draw_circle(head_center + Vector2(0, -2), 3, COL_CLOAK)
		return

	var eye_l := head_center + Vector2(-2.6, -0.5) + look_offset
	var eye_r := head_center + Vector2(2.6, -0.5) + look_offset

	if look.x > 0.5:
		# Facing right: only the right side eye is prominent.
		draw_circle(eye_r, 1.6, COL_EYE)
	elif look.x < -0.5:
		# Facing left.
		draw_circle(eye_l, 1.6, COL_EYE)
	else:
		# Facing down/forward.
		draw_circle(eye_l, 1.5, COL_EYE)
		draw_circle(eye_r, 1.5, COL_EYE)
