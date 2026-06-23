extends CharacterBody2D
## Stargazer - Player
## Top-down (Core Keeper style) 8-directional movement + interaction + attack.
## Now with code-drawn character art, walk-bob, attack lunge, hit flash & juice.

@export var move_speed: float = 220.0
@export var max_health: int = 100

var health: int = max_health
var facing: Vector2 = Vector2.DOWN
var _walk_time: float = 0.0
var _is_attacking: bool = false
var _attack_cooldown: float = 0.0

@onready var interact_area: Area2D = $InteractArea
@onready var visual: Node2D = $Visual          # Holds the code-drawn art (PlayerArt).
@onready var camera: Camera2D = $Camera2D

signal health_changed(current: int, maximum: int)

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)

func _physics_process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		facing = input_dir
		# Tell the art which way we're facing so it can orient.
		if visual and visual.has_method("set_facing"):
			visual.set_facing(facing)

	velocity = input_dir * move_speed
	move_and_slide()

	_animate_movement(delta, input_dir.length() > 0.0)

func _animate_movement(delta: float, moving: bool) -> void:
	if visual == null:
		return
	if moving and not _is_attacking:
		# Bob up and down + slight tilt while walking.
		_walk_time += delta * 12.0
		visual.position.y = -sin(_walk_time) * 2.5
		visual.rotation = sin(_walk_time * 0.5) * 0.04
	elif not _is_attacking:
		# Idle "breathing": settle back and gently scale.
		_walk_time = 0.0
		visual.position.y = lerp(visual.position.y, 0.0, delta * 10.0)
		visual.rotation = lerp(visual.rotation, 0.0, delta * 10.0)
		var breathe := 1.0 + sin(Time.get_ticks_msec() / 600.0) * 0.02
		visual.scale = Vector2(breathe, breathe)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("attack"):
		_attack()

func _try_interact() -> void:
	# Interact with the nearest body that has an `interact` method.
	for body in interact_area.get_overlapping_bodies():
		if body.has_method("interact"):
			body.interact(self)
			return
	# If nothing to interact with, till the soil under the player.
	var world := get_parent()
	if world and world.has_method("till_soil_at"):
		world.till_soil_at(global_position)
		# Little pop so tilling feels responsive.
		Juice.pop(visual, 0.15, 0.15)

func _attack() -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = 0.35
	_is_attacking = true

	# Spawn the slash arc effect in front of the player.
	var origin := global_position + facing * 22.0
	SlashEffect.spawn(get_parent(), origin, facing)

	# A quick lunge in the facing direction for weighty feel.
	if visual:
		var t := create_tween()
		t.tween_property(visual, "position", facing * 8.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(visual, "position", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func(): _is_attacking = false)

	# Melee hit: damage any boss in range in the facing direction.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + facing * 60.0
	)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result and result.collider and result.collider.has_method("take_damage"):
		var dmg := 15
		result.collider.take_damage(dmg)
		# Floating damage number + screen shake on a solid hit.
		DamageNumber.spawn(get_parent(), result.position, dmg)
		Juice.shake(camera, 4.0, 0.18)

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)

	# Hit reactions: red flash, knockback away from center, screen shake.
	if visual:
		Juice.flash(visual, Color(1, 0.4, 0.4), 0.12)
		var away := (global_position).normalized()
		if away == Vector2.ZERO:
			away = -facing
		Juice.knockback(visual, away, 10.0, 0.18)
	Juice.shake(camera, 6.0, 0.25)

	if health <= 0:
		_die()

func _die() -> void:
	# Respawn at center for now.
	global_position = Vector2.ZERO
	health = max_health
	emit_signal("health_changed", health, max_health)
	if visual:
		Juice.pop(visual, 0.4, 0.3)
