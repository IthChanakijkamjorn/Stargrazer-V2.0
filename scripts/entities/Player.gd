extends CharacterBody2D
class_name Player
## Stargazer - Player
## Top-down movement, mouse-aimed (or keyboard-facing) arc melee, a dash with
## bounded invulnerability, hurt invulnerability, knockback from the real
## damage source, and healing consumables.
## All timers are delta-based so pausing the tree freezes the player cleanly.

signal health_changed(current: int, maximum: int)
signal dash_changed(ready_fraction: float)
signal died()

@export var move_speed: float = 230.0

const DASH_SPEED := 720.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.1
## Invulnerability lasts slightly beyond the dash so escapes feel fair.
const DASH_IFRAMES := 0.26
const HURT_IFRAMES := 0.75
const ATTACK_WINDUP := 0.07
const ATTACK_ACTIVE := 0.12
const ATTACK_RECOVERY := 0.16
const ATTACK_RANGE := 62.0
const ATTACK_ARC := deg_to_rad(105.0)
const SALVE_COOLDOWN := 0.5

enum State { IDLE, MOVE, ATTACK, DASH, HURT, DEAD }

var max_health: int = 100
var health: int = 100
var facing: Vector2 = Vector2.DOWN
var state: int = State.IDLE
var damage: int = 14
## When false the player cannot act (intros, menus, death screens).
var control_enabled: bool = true
## Optional radius the player is confined to (boss arenas). 0 = unbounded.
var arena_radius: float = 0.0
var arena_center: Vector2 = Vector2.ZERO

var _attack_timer: float = 0.0
var _attack_phase: int = 0          # 0 none, 1 windup, 2 active, 3 recovery
var _attack_dir: Vector2 = Vector2.DOWN
var _attack_hit: Array = []
var _dash_timer: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _iframes: float = 0.0
var _salve_timer: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _use_mouse_aim: bool = false

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var interact_area: Area2D = $InteractArea
@onready var hit_area: Area2D = $HitArea

func _ready() -> void:
	add_to_group("player")
	refresh_stats(true)
	_update_art_state()

## Re-reads upgrades from the save state. Keeps the current health ratio when
## the maximum changes so buying vitality never feels like a punishment.
func refresh_stats(full_heal: bool = false) -> void:
	var new_max: int = GameState.data.max_health()
	damage = GameState.data.melee_damage()
	if full_heal:
		max_health = new_max
		health = new_max
	else:
		var ratio := float(health) / float(max_health) if max_health > 0 else 1.0
		max_health = new_max
		health = clampi(int(round(new_max * ratio)), 1, new_max)
	health_changed.emit(health, max_health)

# ---------------------------------------------------------------------------
# LOOP
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	if state == State.DEAD:
		velocity = _knockback
		move_and_slide()
		return

	match state:
		State.DASH:
			_process_dash(delta)
		State.ATTACK:
			_process_attack(delta)
		_:
			_process_free()

	_apply_bounds()
	_animate(delta)

func _tick_timers(delta: float) -> void:
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_salve_timer = maxf(0.0, _salve_timer - delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)
	dash_changed.emit(dash_ready_fraction())

func dash_ready_fraction() -> float:
	if DASH_COOLDOWN <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cooldown / DASH_COOLDOWN, 0.0, 1.0)

func is_invulnerable() -> bool:
	return _iframes > 0.0 or state == State.DEAD

func _input_vector() -> Vector2:
	if not control_enabled:
		return Vector2.ZERO
	var v := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	return v.normalized() if v.length() > 0.1 else Vector2.ZERO

func _process_free() -> void:
	var input_dir := _input_vector()
	if input_dir != Vector2.ZERO:
		facing = input_dir
		state = State.MOVE
	else:
		state = State.IDLE
	velocity = input_dir * move_speed + _knockback
	move_and_slide()
	_update_art_state()

func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity = _dash_dir * DASH_SPEED
	move_and_slide()
	if _dash_timer <= 0.0:
		state = State.IDLE
		_update_art_state()

func _process_attack(delta: float) -> void:
	# The player can still drift slowly while swinging, which keeps combat
	# responsive without removing commitment.
	velocity = _input_vector() * move_speed * 0.35 + _knockback
	move_and_slide()
	_attack_timer -= delta
	if _attack_phase == 1 and _attack_timer <= 0.0:
		_attack_phase = 2
		_attack_timer = ATTACK_ACTIVE
		_spawn_slash()
	elif _attack_phase == 2:
		_resolve_attack_hits()
		if _attack_timer <= 0.0:
			_attack_phase = 3
			_attack_timer = ATTACK_RECOVERY
	elif _attack_phase == 3 and _attack_timer <= 0.0:
		_attack_phase = 0
		state = State.IDLE
		_update_art_state()

func _apply_bounds() -> void:
	if arena_radius <= 0.0:
		return
	var offset := global_position - arena_center
	if offset.length() > arena_radius:
		global_position = arena_center + offset.normalized() * arena_radius

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not control_enabled or state == State.DEAD:
		return
	if event is InputEventMouseMotion:
		_use_mouse_aim = true
	elif event is InputEventKey and event.pressed:
		# Any movement key returns aiming to the keyboard so the game stays
		# fully playable without a mouse.
		for action in ["move_up", "move_down", "move_left", "move_right"]:
			if event.is_action_pressed(action):
				_use_mouse_aim = false

	if event.is_action_pressed("attack"):
		if _try_attack():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dash"):
		if _try_dash():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_try_interact()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("use_salve"):
		use_salve()
		get_viewport().set_input_as_handled()

## Direction the next swing will travel in: toward the mouse when it was moved
## most recently, otherwise the movement facing.
func aim_direction() -> Vector2:
	if _use_mouse_aim:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			return to_mouse.normalized()
	return facing if facing != Vector2.ZERO else Vector2.DOWN

func _try_attack() -> bool:
	if state == State.ATTACK or state == State.DASH or state == State.DEAD:
		return false
	_attack_dir = aim_direction()
	facing = _attack_dir
	_attack_hit.clear()
	_attack_phase = 1
	_attack_timer = ATTACK_WINDUP
	state = State.ATTACK
	if visual and visual.has_method("play_attack"):
		visual.play_attack(_attack_dir, ATTACK_WINDUP, ATTACK_ACTIVE + ATTACK_RECOVERY)
	return true

func _try_dash() -> bool:
	if _dash_cooldown > 0.0 or state == State.DASH or state == State.DEAD:
		return false
	var dir := _input_vector()
	if dir == Vector2.ZERO:
		dir = aim_direction()
	_dash_dir = dir
	facing = dir
	_dash_timer = DASH_TIME
	_dash_cooldown = DASH_COOLDOWN
	_iframes = maxf(_iframes, DASH_IFRAMES)
	state = State.DASH
	_attack_phase = 0
	if visual and visual.has_method("play_dash"):
		visual.play_dash(dir, DASH_TIME)
	return true

func _try_interact() -> void:
	var target := nearest_interactable()
	if target != null:
		target.interact(self)
		return
	var world := get_parent()
	if world and world.has_method("interact_ground"):
		world.interact_ground(self)

## Nearest node inside the interact area exposing `interact(player)`.
func nearest_interactable() -> Node:
	var best: Node = null
	var best_dist := INF
	for area in interact_area.get_overlapping_areas():
		var holder: Node = area.get_parent()
		if holder == null or not holder.has_method("interact"):
			continue
		if holder.has_method("can_interact") and not holder.can_interact():
			continue
		if not (holder is Node2D):
			continue
		var d: float = global_position.distance_to((holder as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = holder
	return best

func use_salve() -> bool:
	if _salve_timer > 0.0 or state == State.DEAD:
		return false
	if health >= max_health:
		GameState.show_notice("Already at full health.", Palette.TEXT_DIM)
		return false
	if not GameState.consume_item("salve", 1):
		GameState.show_notice("No Astral Salve. Craft one with C.", Palette.DANGER)
		return false
	_salve_timer = SALVE_COOLDOWN
	health = mini(max_health, health + GameStateData.SALVE_HEAL)
	health_changed.emit(health, max_health)
	if visual:
		Juice.flash(visual, Palette.HEAL, 0.18)
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -20), GameStateData.SALVE_HEAL, false, Palette.HEAL)
	return true

# ---------------------------------------------------------------------------
# COMBAT
# ---------------------------------------------------------------------------
func _spawn_slash() -> void:
	SlashEffect.spawn(get_parent(), global_position + _attack_dir * 26.0, _attack_dir, ATTACK_ARC, ATTACK_RANGE * 0.85)

## Damages every valid target inside the swing arc, once per swing.
func _resolve_attack_hits() -> void:
	for area in hit_area.get_overlapping_areas():
		var target: Node = area.get_parent()
		if target == null or _attack_hit.has(target) or not target.has_method("take_damage"):
			continue
		if not (target is Node2D):
			continue
		var to_target: Vector2 = (target as Node2D).global_position - global_position
		if to_target.length() > ATTACK_RANGE + 26.0:
			continue
		if to_target.length() > 1.0 and absf(to_target.normalized().angle_to(_attack_dir)) > ATTACK_ARC * 0.5:
			continue
		_attack_hit.append(target)
		target.take_damage(damage, global_position)
		shake(3.5, 0.14)

func take_damage(amount: int, source_position: Vector2 = Vector2.INF) -> void:
	if is_invulnerable() or amount <= 0 or state == State.DEAD:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	_iframes = HURT_IFRAMES

	var away := -facing
	if source_position != Vector2.INF:
		var offset := global_position - source_position
		if offset.length() > 1.0:
			away = offset.normalized()
	_knockback = away * 190.0

	if visual:
		if not bool(GameState.data.get_setting("reduced_flash")):
			Juice.flash(visual, Palette.DANGER, 0.14)
		if visual.has_method("play_hurt"):
			visual.play_hurt()
	shake(7.0, 0.28)

	if health <= 0:
		_die()
	else:
		state = State.IDLE
		_attack_phase = 0
		_update_art_state()

func _die() -> void:
	state = State.DEAD
	control_enabled = false
	velocity = Vector2.ZERO
	_attack_phase = 0
	if visual and visual.has_method("play_death"):
		visual.play_death()
	died.emit()

## Screen shake honouring the player's accessibility setting.
func shake(strength: float, duration: float) -> void:
	var scale_factor := float(GameState.data.get_setting("screen_shake"))
	if scale_factor <= 0.01:
		return
	Juice.shake(camera, strength * scale_factor, duration)

func _update_art_state() -> void:
	if visual and visual.has_method("set_state"):
		visual.set_state(state, facing)

func _animate(delta: float) -> void:
	if visual == null:
		return
	if visual.has_method("animate"):
		visual.animate(delta, state, facing, velocity.length())
	# Blink while invulnerable so the window is readable.
	if _iframes > 0.0 and state != State.DEAD:
		visual.modulate.a = 0.45 + 0.55 * absf(sin(_iframes * 24.0))
	else:
		visual.modulate.a = 1.0
