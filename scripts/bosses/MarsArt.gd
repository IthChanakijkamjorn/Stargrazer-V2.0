extends Node2D
class_name MarsArt
## Stargazer - MarsArt
## Mars, The Cinder Warlord: a cracked crimson core sealed inside floating
## armour plates, ringed by orbiting fragments that pull in during a windup
## and scatter when enraged. Entirely procedural.

const CORE_R := 30.0

var accent: Color = Palette.EMBER
var phase: int = 0

var _time: float = 0.0
var _windup: float = 0.0        # 0..1 while charging up
var _windup_dir: Vector2 = Vector2.RIGHT
var _cast: float = 0.0
var _charge_lean: Vector2 = Vector2.ZERO
var _fragments: Array = []
var _missing_fragments: int = 0
var _crack: float = 0.0
var _dying: bool = false

func _ready() -> void:
	z_index = 80
	for i in range(6):
		_fragments.append({
			"angle": TAU * float(i) / 6.0,
			"dist": 58.0 + randf_range(-6.0, 6.0),
			"size": randf_range(7.0, 12.0),
			"spin": randf_range(-2.0, 2.0),
		})
	set_process(true)

func set_accent(c: Color) -> void:
	accent = c
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_windup = maxf(0.0, _windup - delta)
	_cast = maxf(0.0, _cast - delta)
	_charge_lean = _charge_lean.lerp(Vector2.ZERO, delta * 6.0)
	_crack = lerpf(_crack, float(phase), delta * 2.0)
	if _dying:
		queue_redraw()
		return
	for f in _fragments:
		f["angle"] = float(f["angle"]) + delta * (0.7 + float(phase) * 0.8) * (1.0 + float(f["spin"]) * 0.1)
	queue_redraw()

func play_windup(duration: float, dir: Vector2) -> void:
	_windup = duration
	_windup_dir = dir

func play_cast(duration: float) -> void:
	_cast = duration

func play_charge(dir: Vector2) -> void:
	_charge_lean = dir * 8.0

func play_recover() -> void:
	# A visible exhale: the plates drop open, inviting a counterattack.
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.08, 0.92), 0.18).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_SINE)

func play_phase_change(p: int) -> void:
	phase = p
	_missing_fragments = 0
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC)

func consume_fragment(count: int) -> void:
	_missing_fragments = count

func play_death() -> void:
	_dying = true
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.2, 0.2), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "rotation", TAU, 0.9)
	t.tween_property(self, "modulate:a", 0.0, 0.9)

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	var pulse := 1.0 + sin(_time * (2.4 + float(phase))) * 0.04
	var offset := _charge_lean

	draw_circle(Vector2(0, CORE_R + 16), CORE_R * 0.9, Palette.SHADOW)

	_draw_fragments()

	# Outer heat halo, stronger while charging or enraged.
	var heat := 0.18 + float(phase) * 0.1 + (0.2 if _windup > 0.0 else 0.0)
	Palette.draw_halo(self, offset, CORE_R * 2.4 * pulse, Color(accent.r, accent.g, accent.b, heat), 5)

	_draw_armour(offset, pulse)
	_draw_core(offset, pulse)
	_draw_crown(offset)

## Four heavy plates that separate as Mars takes damage.
func _draw_armour(offset: Vector2, pulse: float) -> void:
	var separation := 2.0 + _crack * 7.0 + (3.0 if _windup > 0.0 else 0.0)
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25 + sin(_time * 0.6) * 0.05
		var out := Vector2(cos(a), sin(a))
		var mid := offset + out * (CORE_R * 0.78 + separation)
		var side := Vector2(-out.y, out.x)
		var plate := PackedVector2Array([
			mid + out * 15.0 * pulse,
			mid + side * 16.0,
			mid - out * 13.0,
			mid - side * 16.0,
		])
		draw_colored_polygon(plate, Color(0.34, 0.15, 0.16))
		draw_colored_polygon(PackedVector2Array([
			mid + out * 15.0 * pulse, mid + side * 16.0, mid,
		]), Color(0.46, 0.2, 0.2))
		draw_polyline(plate, Color(accent.r, accent.g, accent.b, 0.55), 1.6, true)

func _draw_core(offset: Vector2, pulse: float) -> void:
	var r := CORE_R * pulse
	draw_circle(offset, r, Color(0.52, 0.16, 0.14))
	draw_circle(offset + Vector2(r * 0.22, r * 0.22), r * 0.86, Color(0.38, 0.11, 0.11))
	draw_circle(offset - Vector2(r * 0.18, r * 0.24), r * 0.62, Color(0.68, 0.23, 0.17))

	# Molten fissures: they widen and brighten as the fight progresses.
	var glow := Color(accent.r, accent.g, accent.b, 0.55 + 0.35 * _crack + 0.2 * sin(_time * 5.0))
	var seams := [
		[Vector2(-0.8, -0.5), Vector2(-0.1, 0.0), Vector2(0.4, 0.7)],
		[Vector2(-0.3, 0.85), Vector2(0.05, 0.2), Vector2(0.75, -0.3)],
		[Vector2(-0.85, 0.35), Vector2(-0.2, 0.45), Vector2(0.3, 0.95)],
	]
	for seam in seams:
		var pts := PackedVector2Array()
		for p in seam:
			pts.append(offset + (p as Vector2) * r)
		draw_polyline(pts, glow, 2.0 + 2.0 * _crack, true)

	# The exposed heart.
	var heart := r * (0.22 + 0.05 * sin(_time * 4.0))
	Palette.draw_halo(self, offset, heart * 3.0, Color(1.0, 0.8, 0.5, 0.35), 3)
	draw_circle(offset, heart, Color(1.0, 0.86, 0.6))

## A ring of jagged spikes above the core; it flares during a cast.
func _draw_crown(offset: Vector2) -> void:
	var flare := 1.0 + (0.35 if _cast > 0.0 else 0.0)
	for i in range(8):
		var a := TAU * float(i) / 8.0 + _time * 0.4
		var base := offset + Vector2(cos(a), sin(a)) * CORE_R * 1.05
		var tip := offset + Vector2(cos(a), sin(a)) * CORE_R * (1.32 * flare)
		var side := Vector2(-sin(a), cos(a)) * 4.0
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
			Color(accent.r, accent.g, accent.b, 0.85))

## Orbiting shards; phase two flings them wider and they deplete during the
## fragment volley so the attack reads on the boss itself.
func _draw_fragments() -> void:
	var orbit_scale := 1.0 + float(phase) * 0.25 - (0.28 if _windup > 0.0 else 0.0)
	var available: int = maxi(0, _fragments.size() - _missing_fragments)
	for i in range(_fragments.size()):
		if i >= available:
			continue
		var f: Dictionary = _fragments[i]
		var a := float(f["angle"])
		var d := float(f["dist"]) * orbit_scale
		var p := Vector2(cos(a) * d, sin(a) * d * 0.72)
		var s := float(f["size"])
		Palette.draw_halo(self, p, s * 2.0, Color(accent.r, accent.g, accent.b, 0.22), 2)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -s), p + Vector2(s * 0.8, 0),
			p + Vector2(0, s * 0.75), p + Vector2(-s * 0.8, 0),
		]), Color(0.42, 0.18, 0.17))
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(0, -s), p + Vector2(s * 0.8, 0), p,
		]), Color(accent.r * 0.9, accent.g * 0.6, accent.b * 0.5))
