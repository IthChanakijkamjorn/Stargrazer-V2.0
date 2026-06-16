extends CharacterBody2D
## Stargazer - Player
## Top-down (Core Keeper style) 8-directional movement + interaction + attack.

@export var move_speed: float = 220.0
@export var max_health: int = 100

var health: int = max_health
var facing: Vector2 = Vector2.DOWN

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Polygon2D = $Body

signal health_changed(current: int, maximum: int)

func _ready() -> void:
	health = max_health
	emit_signal("health_changed", health, max_health)

func _physics_process(_delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		facing = input_dir

	velocity = input_dir * move_speed
	move_and_slide()

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

func _attack() -> void:
	# Simple melee: damage any boss in range in the facing direction.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + facing * 60.0
	)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result and result.collider and result.collider.has_method("take_damage"):
		result.collider.take_damage(15)

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	emit_signal("health_changed", health, max_health)
	# Brief flash to show the hit.
	if sprite:
		sprite.color = Color(1, 0.3, 0.3)
		await get_tree().create_timer(0.1).timeout
		sprite.color = Color(0.4, 0.8, 1.0)
	if health <= 0:
		_die()

func _die() -> void:
	# Respawn at center for now.
	global_position = Vector2.ZERO
	health = max_health
	emit_signal("health_changed", health, max_health)
