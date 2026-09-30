extends BossBase
class_name SaturnBoss
## Stargazer - Saturn, The Ringbound Sovereign
## A slow, imperious silhouette that fights at range with rotating projectile
## fans (each with a dodgeable gap), returning ring blades, and - after its
## rings separate at 55% health - a sweeping double-stream and a collapsing
## ring that must be escaped through a single opening.
##
## Saturn is deliberately the opposite of Mars: it keeps its distance, punishes
## standing still, and rewards reading rotation direction rather than reflexes.

var _volley_index: int = 0
var _fan_rotation: float = 0.0
var _fan_direction: float = 1.0
var _gap_angle: float = 0.0
var _blades: Array = []

func _configure_visual() -> void:
	if visual and visual.has_method("set_accent"):
		visual.set_accent(accent_color())

func patterns() -> Array:
	return [
		{"id": "ring_fan", "phase": 0, "duration": 2.6, "recovery": 1.3},
		{"id": "ring_blades", "phase": 0, "duration": 2.0, "recovery": 1.4},
		{"id": "sweep", "phase": 1, "duration": 3.0, "recovery": 1.25},
		{"id": "collapse", "phase": 1, "duration": 2.8, "recovery": 1.5},
	]

func _on_phase(phase: int) -> void:
	if phase >= 1:
		move_speed = 115.0
		contact_damage = 15
		if visual and visual.has_method("separate_rings"):
			visual.separate_rings()

func _idle_move(delta: float) -> void:
	# Saturn hovers at range and orbits the player.
	_drift_towards_player(delta, move_speed, 260.0)

func _begin_pattern(id: String) -> void:
	_volley_index = 0
	_fan_rotation = randf() * TAU
	_fan_direction = 1.0 if randf() < 0.5 else -1.0
	_gap_angle = randf() * TAU
	match id:
		"ring_fan":
			if visual and visual.has_method("play_cast"):
				visual.play_cast(2.6, _fan_direction)
		"ring_blades":
			_blades.clear()
			if visual and visual.has_method("play_windup"):
				visual.play_windup(0.55)
		"sweep":
			if visual and visual.has_method("play_cast"):
				visual.play_cast(3.0, _fan_direction)
		"collapse":
			if visual and visual.has_method("play_windup"):
				visual.play_windup(0.9)
			# One very readable warning ring marks the safe opening.
			Telegraph.circle(get_parent(), global_position, 250.0, 0.9, 0, accent_color())

func _tick_pattern(id: String, delta: float, t: float) -> void:
	match id:
		"ring_fan":
			_tick_ring_fan(delta, t)
		"ring_blades":
			_tick_ring_blades(t)
		"sweep":
			_tick_sweep(delta, t)
		"collapse":
			_tick_collapse(t)

# ---------------------------------------------------------------------------
# PATTERN: rotating fan with a dodgeable gap
# ---------------------------------------------------------------------------
func _tick_ring_fan(delta: float, t: float) -> void:
	_fan_rotation += delta * 1.5 * _fan_direction
	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * delta)
	move_and_slide()
	var interval := 0.26
	var total := 8 if encounter.phase == 0 else 10
	while _volley_index < total and t >= 0.5 + float(_volley_index) * interval:
		var spokes := 3
		for i in range(spokes):
			var a := _fan_rotation + TAU * float(i) / float(spokes)
			shoot(global_position + Vector2(cos(a), sin(a)) * body_radius, Vector2(cos(a), sin(a)) * 210.0, {
				"damage": 11,
				"radius": 8.0,
				"color": accent_color(),
				"shape": Projectile.Shape.ORB,
				"lifetime": 3.6,
			})
		_volley_index += 1

# ---------------------------------------------------------------------------
# PATTERN: returning ring blades
# ---------------------------------------------------------------------------
func _tick_ring_blades(t: float) -> void:
	var total := 3 if encounter.phase == 0 else 5
	while _volley_index < total and t >= 0.55 + float(_volley_index) * 0.18:
		var spread := deg_to_rad(18.0) * (float(_volley_index) - float(total - 1) * 0.5)
		var dir := direction_to_player().rotated(spread)
		var blade := shoot(global_position + dir * body_radius, dir * 330.0, {
			"damage": 13,
			"radius": 11.0,
			"color": Palette.GOLD,
			"shape": Projectile.Shape.BLADE,
			"lifetime": 4.5,
			"return_to": self,
			"return_after": 0.85,
		})
		if blade:
			_blades.append(blade)
		_volley_index += 1

# ---------------------------------------------------------------------------
# PATTERN: separated-ring double sweep (phase 2)
# ---------------------------------------------------------------------------
func _tick_sweep(delta: float, t: float) -> void:
	_fan_rotation += delta * 2.1 * _fan_direction
	_drift_towards_player(delta, move_speed * 0.4, 300.0)
	var interval := 0.1
	while _volley_index < 24 and t >= 0.55 + float(_volley_index) * interval:
		for sign_i in [-1.0, 1.0]:
			var a: float = _fan_rotation * float(sign_i) + (0.0 if float(sign_i) > 0.0 else PI)
			shoot(global_position + Vector2(cos(a), sin(a)) * body_radius, Vector2(cos(a), sin(a)) * 240.0, {
				"damage": 10,
				"radius": 7.0,
				"color": Palette.VIOLET,
				"shape": Projectile.Shape.ORB,
				"lifetime": 3.2,
			})
		_volley_index += 1

# ---------------------------------------------------------------------------
# PATTERN: collapsing ring with one opening (phase 2)
# ---------------------------------------------------------------------------
func _tick_collapse(t: float) -> void:
	if _volley_index > 0 or t < 0.95:
		return
	_volley_index = 1
	var count := 26
	var spawn_radius := 250.0
	for i in range(count):
		var a := TAU * float(i) / float(count)
		if absf(angle_difference(a, _gap_angle)) < 0.42:
			continue
		var pos := global_position + Vector2(cos(a), sin(a)) * spawn_radius
		# Every orb converges on the boss, so the safe route is the gap.
		shoot(pos, -Vector2(cos(a), sin(a)) * 165.0, {
			"damage": 12,
			"radius": 8.5,
			"color": Palette.GOLD,
			"shape": Projectile.Shape.ORB,
			"lifetime": 2.6,
		})
	ImpactFX.burst(get_parent(), global_position, accent_color(), 180.0, 0.5)
