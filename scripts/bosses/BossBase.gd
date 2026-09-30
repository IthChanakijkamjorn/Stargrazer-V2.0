extends CharacterBody2D
class_name BossBase
## Stargazer - BossBase
## Shared foundation for every cosmic encounter. Owns the EncounterState
## (health/phases/lifecycle), an arena-aware movement helper, and a simple
## data-driven attack scheduler with explicit windup -> active -> recovery
## timing so every pattern is learnable and every fight has openings.
##
## Subclasses declare their patterns in `patterns()` and implement
## `_begin_pattern` / `_tick_pattern`. They never touch health bookkeeping.

signal health_changed(fraction: float, phase: int)
signal phase_changed(phase: int)
signal defeated()

@export var boss_id: String = "mars"
@export var max_health: int = 700
@export var phase_thresholds: Array = [0.5]
@export var move_speed: float = 95.0
@export var contact_damage: int = 12
@export var body_radius: float = 44.0

var encounter := EncounterState.new()
var player: Node2D = null
var arena_center: Vector2 = Vector2.ZERO
var arena_radius: float = 460.0

var _pattern: String = ""
var _pattern_t: float = 0.0
var _pattern_len: float = 0.0
var _recover: float = 1.2
var _contact_cd: float = 0.0
var _last_pattern: String = ""
var _hurt_flash: float = 0.0

@onready var visual: Node2D = $Visual
@onready var hurt_area: Area2D = $HurtArea

func _ready() -> void:
	add_to_group("boss")
	encounter.configure(max_health, phase_thresholds)
	health_changed.emit(1.0, 0)
	player = get_tree().get_first_node_in_group("player")
	_configure_visual()

## Subclass hook: set up art, colours, extra child nodes.
func _configure_visual() -> void:
	pass

## Subclass hook: ordered list of {id, phase, duration, recovery} dictionaries.
func patterns() -> Array:
	return []

## Subclass hook: called once when a pattern starts.
func _begin_pattern(_id: String) -> void:
	pass

## Subclass hook: called each physics frame while a pattern runs.
## `t` is seconds since the pattern began.
func _tick_pattern(_id: String, _delta: float, _t: float) -> void:
	pass

## Subclass hook: idle drifting between attacks.
func _idle_move(delta: float) -> void:
	_drift_towards_player(delta, move_speed * 0.55, 150.0)

## Subclass hook: called once when a phase transition happens.
func _on_phase(_phase: int) -> void:
	pass

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------
func begin_fight() -> void:
	encounter.begin_fight()
	_recover = 0.9

func _physics_process(delta: float) -> void:
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")

	if encounter.consume_phase_change():
		_enter_phase(encounter.phase)

	if not encounter.can_act():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _pattern == "":
		_recover -= delta
		_idle_move(delta)
		if _recover <= 0.0:
			_choose_pattern()
	else:
		_pattern_t += delta
		_tick_pattern(_pattern, delta, _pattern_t)
		if _pattern_t >= _pattern_len:
			_finish_pattern()

	_apply_contact_damage()
	_clamp_to_arena()

func _enter_phase(phase: int) -> void:
	# Phase changes interrupt the current pattern and give a readable beat.
	_pattern = ""
	_pattern_t = 0.0
	_recover = 1.4
	_on_phase(phase)
	phase_changed.emit(phase)
	ImpactFX.burst(get_parent(), global_position, accent_color(), 220.0, 0.7)
	if visual and visual.has_method("play_phase_change"):
		visual.play_phase_change(phase)

func _choose_pattern() -> void:
	var options: Array = []
	for p in patterns():
		if int(p.get("phase", 0)) <= encounter.phase and String(p.get("id", "")) != _last_pattern:
			options.append(p)
	if options.is_empty():
		for p in patterns():
			if int(p.get("phase", 0)) <= encounter.phase:
				options.append(p)
	if options.is_empty():
		_recover = 1.0
		return
	var chosen: Dictionary = options[randi() % options.size()]
	_pattern = String(chosen["id"])
	_last_pattern = _pattern
	_pattern_t = 0.0
	_pattern_len = float(chosen.get("duration", 2.0))
	_recover = float(chosen.get("recovery", 1.1))
	_begin_pattern(_pattern)

func _finish_pattern() -> void:
	_pattern = ""
	_pattern_t = 0.0
	if visual and visual.has_method("play_recover"):
		visual.play_recover()

func take_damage(amount: int, _source_position: Vector2 = Vector2.INF) -> void:
	if not encounter.is_alive():
		return
	var dealt := encounter.damage(amount)
	if dealt <= 0:
		return
	_hurt_flash = 0.12
	health_changed.emit(encounter.health_fraction(), encounter.phase)
	if visual:
		if not bool(GameState.data.get_setting("reduced_flash")):
			Juice.flash(visual, Color(1, 1, 1), 0.07)
		Juice.pop(visual, 0.12, 0.14)
	DamageNumber.spawn(get_parent(), global_position + Vector2(randf_range(-20, 20), -body_radius - 10), dealt)
	if not encounter.is_alive():
		_die()

func _die() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	if is_instance_valid(hurt_area):
		hurt_area.set_deferred("monitorable", false)
	clear_hazards()
	if visual and visual.has_method("play_death"):
		visual.play_death()
	# A short, dramatic collapse before the victory screen takes over.
	var t := create_tween()
	t.tween_interval(0.45)
	t.tween_callback(func() -> void:
		ImpactFX.burst(get_parent(), global_position, accent_color(), 320.0, 0.9))
	t.tween_interval(0.5)
	t.tween_callback(func() -> void: defeated.emit())

## Removes every projectile and telegraph this fight created, so nothing can
## damage the player after the encounter ends.
func clear_hazards() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for p in tree.get_nodes_in_group("projectile"):
		if is_instance_valid(p):
			p.queue_free()
	for t in tree.get_nodes_in_group("telegraph"):
		if is_instance_valid(t):
			t.queue_free()

# ---------------------------------------------------------------------------
# HELPERS FOR SUBCLASSES
# ---------------------------------------------------------------------------
func accent_color() -> Color:
	return GameData.get_boss(boss_id).get("accent", Palette.EMBER)

func player_position() -> Vector2:
	if player and is_instance_valid(player):
		return player.global_position
	return global_position + Vector2(0, 120)

func direction_to_player() -> Vector2:
	var d := player_position() - global_position
	return d.normalized() if d.length() > 1.0 else Vector2.DOWN

func _drift_towards_player(delta: float, speed: float, preferred_distance: float) -> void:
	var to_player := player_position() - global_position
	var distance := to_player.length()
	var dir := to_player.normalized() if distance > 1.0 else Vector2.ZERO
	var desired := Vector2.ZERO
	if distance > preferred_distance + 30.0:
		desired = dir * speed
	elif distance < preferred_distance - 30.0:
		desired = -dir * speed
	else:
		# Strafe so the boss never sits perfectly still.
		desired = Vector2(-dir.y, dir.x) * speed * 0.5
	velocity = velocity.move_toward(desired, speed * 4.0 * delta)
	move_and_slide()

func _apply_contact_damage() -> void:
	if _contact_cd > 0.0 or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > body_radius + 18.0:
		return
	if player.has_method("is_invulnerable") and player.is_invulnerable():
		return
	if player.has_method("take_damage"):
		player.take_damage(contact_damage, global_position)
		_contact_cd = 0.9

func _clamp_to_arena() -> void:
	var offset := global_position - arena_center
	var limit := arena_radius - body_radius * 0.5
	if offset.length() > limit:
		global_position = arena_center + offset.normalized() * limit

## Spawns a projectile into the arena (the boss's parent), pre-bounded.
func shoot(pos: Vector2, vel: Vector2, cfg: Dictionary = {}) -> Projectile:
	var merged := cfg.duplicate()
	merged["bounds_center"] = arena_center
	merged["bounds_radius"] = arena_radius
	return Projectile.fire(get_parent(), pos, vel, merged)
