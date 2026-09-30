extends BossBase
class_name MarsBoss
## Stargazer - Mars, The Cinder Warlord
## A cracked crimson core wrapped in armour plates, orbited by broken
## fragments. Fights aggressively at close range with telegraphed charges,
## meteor impact zones, and - once enraged - fissure rings and fragment
## volleys.
##
## Openings: every pattern ends with a clear recovery window where Mars slows
## to a crawl and its core is exposed.

const CHARGE_WINDUP := 0.85
const CHARGE_TIME := 0.5
const CHARGE_SPEED := 620.0
const METEOR_WARN := 1.15

var _charge_dir: Vector2 = Vector2.RIGHT
var _charge_telegraph: Telegraph = null
var _meteors_spawned: int = 0
var _volley_index: int = 0
var _fan_angle: float = 0.0

func _configure_visual() -> void:
	if visual and visual.has_method("set_accent"):
		visual.set_accent(accent_color())

func patterns() -> Array:
	return [
		{"id": "charge", "phase": 0, "duration": CHARGE_WINDUP + CHARGE_TIME, "recovery": 1.25},
		{"id": "meteors", "phase": 0, "duration": 2.2, "recovery": 1.35},
		{"id": "fissure", "phase": 1, "duration": 2.4, "recovery": 1.15},
		{"id": "fragments", "phase": 1, "duration": 1.9, "recovery": 1.2},
	]

func _on_phase(phase: int) -> void:
	if phase >= 1:
		move_speed = 130.0
		contact_damage = 16

func _idle_move(delta: float) -> void:
	_drift_towards_player(delta, move_speed, 170.0)

func _begin_pattern(id: String) -> void:
	_meteors_spawned = 0
	_volley_index = 0
	match id:
		"charge":
			_charge_dir = direction_to_player()
			_charge_telegraph = Telegraph.beam(
				get_parent(), global_position, _charge_dir,
				CHARGE_SPEED * CHARGE_TIME, body_radius * 2.0,
				CHARGE_WINDUP, 0, accent_color()
			)
			if visual and visual.has_method("play_windup"):
				visual.play_windup(CHARGE_WINDUP, _charge_dir)
		"meteors":
			if visual and visual.has_method("play_cast"):
				visual.play_cast(2.2)
		"fissure":
			_fan_angle = randf() * TAU
			if visual and visual.has_method("play_cast"):
				visual.play_cast(2.4)
		"fragments":
			if visual and visual.has_method("play_windup"):
				visual.play_windup(0.5, direction_to_player())

func _tick_pattern(id: String, delta: float, t: float) -> void:
	match id:
		"charge":
			_tick_charge(delta, t)
		"meteors":
			_tick_meteors(t)
		"fissure":
			_tick_fissure(t)
		"fragments":
			_tick_fragments(t)

# ---------------------------------------------------------------------------
# PATTERN: telegraphed charge
# ---------------------------------------------------------------------------
func _tick_charge(delta: float, t: float) -> void:
	if t < CHARGE_WINDUP:
		# Wind up in place, leaning back against the charge direction.
		velocity = velocity.move_toward(-_charge_dir * 40.0, 600.0 * delta)
		move_and_slide()
		if is_instance_valid(_charge_telegraph):
			_charge_telegraph.global_position = global_position
			_charge_telegraph.direction = _charge_dir
		return
	if is_instance_valid(_charge_telegraph):
		_charge_telegraph = null
	velocity = _charge_dir * CHARGE_SPEED
	move_and_slide()
	if visual and visual.has_method("play_charge"):
		visual.play_charge(_charge_dir)
	# Scorch trail: small embers left in the wake, short-lived and harmless.
	if randf() < 0.5:
		ImpactFX.burst(get_parent(), global_position, accent_color(), 34.0, 0.3)

# ---------------------------------------------------------------------------
# PATTERN: meteor impact zones
# ---------------------------------------------------------------------------
func _tick_meteors(t: float) -> void:
	var total := 5 if encounter.phase == 0 else 7
	var interval := 0.32
	while _meteors_spawned < total and t >= float(_meteors_spawned) * interval:
		var spread := 40.0 + float(_meteors_spawned) * 22.0
		var target := player_position() + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		target = _clamp_to_arena_point(target)
		var tele := Telegraph.circle(get_parent(), target, 62.0, METEOR_WARN, 18, accent_color())
		if tele:
			tele.detonated.connect(_on_meteor_landed)
		_meteors_spawned += 1

func _on_meteor_landed(tele: Telegraph) -> void:
	if not is_instance_valid(tele):
		return
	ImpactFX.burst(get_parent(), tele.global_position, accent_color(), 92.0, 0.45)
	if player and is_instance_valid(player) and player.has_method("shake"):
		player.shake(4.0, 0.2)

# ---------------------------------------------------------------------------
# PATTERN: enraged fissure rings (phase 2)
# ---------------------------------------------------------------------------
func _tick_fissure(t: float) -> void:
	var interval := 0.75
	while _volley_index < 3 and t >= float(_volley_index) * interval:
		var gap := _fan_angle + float(_volley_index) * 0.9
		var count := 16
		for i in range(count):
			var a := TAU * float(i) / float(count)
			# Leave a clearly dodgeable gap in every ring.
			if absf(angle_difference(a, gap)) < 0.55:
				continue
			shoot(global_position, Vector2(cos(a), sin(a)) * 185.0, {
				"damage": 12,
				"radius": 8.0,
				"color": accent_color(),
				"shape": Projectile.Shape.EMBER,
				"lifetime": 3.4,
			})
		ImpactFX.burst(get_parent(), global_position, accent_color(), 120.0, 0.35)
		_volley_index += 1

# ---------------------------------------------------------------------------
# PATTERN: fragment volley (phase 2)
# ---------------------------------------------------------------------------
func _tick_fragments(t: float) -> void:
	var interval := 0.22
	while _volley_index < 6 and t >= 0.45 + float(_volley_index) * interval:
		var base := direction_to_player()
		var spread := deg_to_rad(11.0) * (float(_volley_index) - 2.5)
		var dir := base.rotated(spread)
		shoot(global_position + dir * body_radius, dir * 310.0, {
			"damage": 10,
			"radius": 7.0,
			"color": Color(1.0, 0.62, 0.3),
			"shape": Projectile.Shape.ORB,
			"lifetime": 3.0,
		})
		_volley_index += 1
	if visual and visual.has_method("consume_fragment"):
		visual.consume_fragment(_volley_index)

func _clamp_to_arena_point(p: Vector2) -> Vector2:
	var offset := p - arena_center
	if offset.length() > arena_radius - 40.0:
		return arena_center + offset.normalized() * (arena_radius - 40.0)
	return p
