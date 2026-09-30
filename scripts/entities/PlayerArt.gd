extends Node2D
class_name PlayerArt
## Stargazer - PlayerArt
## A fully code-drawn "Stargazer": a hooded astral wanderer with a floating
## star-shard blade. Everything is procedural polygons + math-driven motion,
## so no sprite sheets are required and the art scales cleanly.
##
## Animation states mirror Player.State: idle breathing, directional walk
## cycle with leg swing and bob, attack windup/slash/recovery, dash stretch,
## hurt recoil and a death collapse.

const BODY_R := 9.0

# Palette (cosmic indigo cloak, cyan trim, gold star motif).
const COL_CLOAK := Color(0.19, 0.18, 0.38)
const COL_CLOAK_HI := Color(0.29, 0.28, 0.55)
const COL_CLOAK_LO := Color(0.12, 0.11, 0.26)
const COL_TRIM := Color(0.45, 0.88, 1.0)
const COL_SKIN := Color(0.86, 0.79, 0.72)
const COL_HOOD := Color(0.24, 0.23, 0.47)
const COL_EYE := Color(0.55, 0.95, 1.0)
const COL_BLADE := Color(0.78, 0.95, 1.0)
const COL_BLADE_HI := Color(1.0, 1.0, 1.0)
const COL_BOOT := Color(0.16, 0.15, 0.3)

var facing: Vector2 = Vector2.DOWN
var state: int = 0

var _time: float = 0.0
var _walk_cycle: float = 0.0
var _swing: float = 0.0            # 0..1 blade sweep progress
var _swing_dir: Vector2 = Vector2.RIGHT
var _swinging: bool = false
var _recoil: float = 0.0
var _stretch: Vector2 = Vector2.ONE
var _dead: bool = false
var _blade_orbit: float = 0.0

func _ready() -> void:
	z_index = 5
	set_process(true)

func set_state(p_state: int, p_facing: Vector2) -> void:
	state = p_state
	if p_facing != Vector2.ZERO:
		facing = p_facing

## Called every physics frame by Player.
func animate(delta: float, p_state: int, p_facing: Vector2, speed: float) -> void:
	state = p_state
	if p_facing != Vector2.ZERO:
		facing = p_facing
	_time += delta
	_blade_orbit += delta * (5.5 if _swinging else 1.4)
	if speed > 12.0 and not _dead:
		_walk_cycle += delta * clampf(speed / 40.0, 4.0, 14.0)
	else:
		_walk_cycle = lerpf(_walk_cycle, 0.0, delta * 8.0)
	_recoil = maxf(0.0, _recoil - delta * 4.0)
	_stretch = _stretch.lerp(Vector2.ONE, delta * 10.0)
	queue_redraw()

func play_attack(dir: Vector2, windup: float, sweep: float) -> void:
	_swing_dir = dir
	_swinging = true
	_swing = 0.0
	var t := create_tween()
	# Windup pulls the blade back, then it sweeps through and settles.
	t.tween_method(_set_swing, -0.35, 0.0, maxf(windup, 0.01))
	t.tween_method(_set_swing, 0.0, 1.0, maxf(sweep, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_swinging = false
		_swing = 0.0
		queue_redraw())

func _set_swing(v: float) -> void:
	_swing = v
	queue_redraw()

func play_dash(dir: Vector2, _time_unused: float) -> void:
	# Stretch along the dash axis for a smear-frame feel. `animate()` eases it
	# back to normal, so no tween is needed (and none can fight the ease).
	var horizontal := absf(dir.x) >= absf(dir.y)
	_stretch = Vector2(1.35, 0.72) if horizontal else Vector2(0.72, 1.35)
	queue_redraw()

func play_hurt() -> void:
	_recoil = 1.0
	queue_redraw()

func play_death() -> void:
	_dead = true
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "rotation", deg_to_rad(-75.0), 0.45).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2(1.15, 0.8), 0.45)
	t.tween_property(self, "modulate", Color(0.6, 0.6, 0.8, 0.75), 0.45)

func revive() -> void:
	_dead = false
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE
	_recoil = 0.0
	queue_redraw()

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	var bob := 0.0
	var lean := 0.0
	if _walk_cycle > 0.01:
		bob = -absf(sin(_walk_cycle)) * 2.6
		lean = sin(_walk_cycle * 0.5) * 0.05
	else:
		bob = sin(_time * 2.2) * 0.9

	var recoil_offset := -facing * _recoil * 5.0
	var root := Vector2(0, bob) + recoil_offset

	# Contact shadow stays on the ground, unaffected by bob.
	draw_circle(Vector2(0, 13), 10.0, Palette.SHADOW)

	draw_set_transform(root, lean, _stretch)
	_draw_legs()
	_draw_cloak()
	_draw_body()
	_draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_blade(root)

func _draw_legs() -> void:
	var swing := sin(_walk_cycle) * 4.0
	var back_swing := sin(_walk_cycle + PI) * 4.0
	draw_circle(Vector2(-4 + swing * 0.5, 12 + absf(swing) * 0.2), 3.2, COL_BOOT)
	draw_circle(Vector2(4 + back_swing * 0.5, 12 + absf(back_swing) * 0.2), 3.2, COL_BOOT)

func _draw_cloak() -> void:
	# Cloak flares out while moving, giving the walk cycle weight.
	var flare := 2.0 + absf(sin(_walk_cycle)) * 2.5
	var hem := sin(_walk_cycle * 2.0) * 1.2
	var cloak := PackedVector2Array([
		Vector2(-8, -8),
		Vector2(8, -8),
		Vector2(9 + flare, 8 + hem),
		Vector2(4, 13),
		Vector2(-4, 13),
		Vector2(-9 - flare, 8 - hem),
	])
	draw_colored_polygon(cloak, COL_CLOAK)
	# Left-side highlight so the silhouette reads against dark ground.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -8), Vector2(-2, -8), Vector2(-1, 13), Vector2(-4, 13), Vector2(-9 - flare, 8 - hem),
	]), COL_CLOAK_HI)
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, -8), Vector2(8, -8), Vector2(9 + flare, 8 + hem), Vector2(4, 13),
	]), COL_CLOAK_LO)
	# Cyan trim along the hem keeps the cosmic accent restrained but present.
	draw_polyline(PackedVector2Array([
		Vector2(-9 - flare, 8 - hem), Vector2(-4, 13), Vector2(4, 13), Vector2(9 + flare, 8 + hem),
	]), COL_TRIM, 1.4, true)

func _draw_body() -> void:
	draw_circle(Vector2(0, -1), BODY_R * 0.78, COL_CLOAK_HI)
	# Chest star: the Stargazer's sigil.
	_draw_star(Vector2(0, -1), 3.6, 1.6, 4, Palette.GOLD)

func _draw_head() -> void:
	var head := Vector2(0, -11)
	var look := facing
	if look == Vector2.ZERO:
		look = Vector2.DOWN
	# Hood.
	draw_circle(head, 7.2, COL_HOOD)
	draw_circle(head + Vector2(-1.6, -1.6), 5.4, COL_CLOAK_HI)
	if look.y < -0.45:
		# Facing away: closed hood with a star clasp.
		draw_circle(head, 5.6, COL_HOOD)
		_draw_star(head + Vector2(0, 1.0), 2.4, 1.0, 4, Palette.CYAN_DIM)
		return
	# Face shadow inside the hood.
	var face_offset := Vector2(look.x, maxf(look.y, 0.0) * 0.5) * 1.6
	draw_circle(head + face_offset + Vector2(0, 1.0), 4.6, COL_SKIN.darkened(0.45))
	draw_circle(head + face_offset + Vector2(0, 1.2), 3.9, COL_SKIN)
	# Glowing eyes.
	var eye_y := 0.8
	if look.x > 0.45:
		draw_circle(head + face_offset + Vector2(1.9, eye_y), 1.25, COL_EYE)
	elif look.x < -0.45:
		draw_circle(head + face_offset + Vector2(-1.9, eye_y), 1.25, COL_EYE)
	else:
		draw_circle(head + face_offset + Vector2(-1.9, eye_y), 1.15, COL_EYE)
		draw_circle(head + face_offset + Vector2(1.9, eye_y), 1.15, COL_EYE)

## The blade is a floating star-shard that orbits the player and snaps into a
## sweeping arc during an attack.
func _draw_blade(root: Vector2) -> void:
	var angle: float
	var distance: float
	if _swinging:
		# -0.35 .. 0.0 is the windup (blade drawn back), 0..1 is the sweep.
		var sweep_t: float = clampf(_swing, 0.0, 1.0)
		var wind: float = clampf(-_swing, 0.0, 1.0)
		var base := _swing_dir.angle()
		angle = base + lerpf(-0.95, 0.95, sweep_t) + wind * -0.7
		distance = 20.0 + sweep_t * 12.0 - wind * 6.0
	else:
		angle = _blade_orbit * 0.9
		distance = 15.0 + sin(_time * 2.0) * 1.5

	var pos := root + Vector2(cos(angle), sin(angle) * 0.75) * distance + Vector2(0, -4)
	var tip := pos + Vector2(cos(angle), sin(angle)) * 9.0
	var back := pos - Vector2(cos(angle), sin(angle)) * 5.0
	var side := Vector2(-sin(angle), cos(angle)) * 3.0

	Palette.draw_halo(self, pos, 9.0, Color(COL_TRIM.r, COL_TRIM.g, COL_TRIM.b, 0.22), 3)
	draw_colored_polygon(PackedVector2Array([tip, pos + side, back, pos - side]), COL_BLADE)
	draw_colored_polygon(PackedVector2Array([tip, pos + side * 0.4, back]), COL_BLADE_HI)

func _draw_star(center: Vector2, outer: float, inner: float, points: int, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(points * 2):
		var r := outer if i % 2 == 0 else inner
		var a := TAU * float(i) / float(points * 2) - PI * 0.5
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
