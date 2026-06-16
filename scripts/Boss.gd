extends CharacterBody2D
## Stargazer - Boss (Saturn)
## A simple boss that idles until the player gets close, then chases.
## Star/planet-themed bosses are the core of Stargazer.

@export var boss_name: String = "Saturn"
@export var max_health: int = 200
@export var move_speed: float = 90.0
@export var aggro_range: float = 260.0
@export var contact_damage: int = 10

var health: int = max_health
var player: Node2D = null
var is_aggro: bool = false
var _attack_cooldown: float = 0.0

@onready var ring: Polygon2D = $Ring
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

func _ready() -> void:
	health = max_health
	name_label.text = boss_name
	health_bar.max_value = max_health
	health_bar.value = health
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	is_aggro = dist <= aggro_range

	if is_aggro:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()

		# Slowly rotate the ring for a bit of flair.
		ring.rotation += delta * 1.5

		# Contact damage on a cooldown.
		_attack_cooldown -= delta
		if dist <= 48.0 and _attack_cooldown <= 0.0:
			if player.has_method("take_damage"):
				player.take_damage(contact_damage)
			_attack_cooldown = 1.0
	else:
		velocity = Vector2.ZERO
		ring.rotation += delta * 0.4

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	health_bar.value = health
	# Flash on hit.
	ring.color = Color(1, 1, 1)
	await get_tree().create_timer(0.06).timeout
	ring.color = Color(0.88, 0.67, 1.0)
	if health <= 0:
		_die()

func _die() -> void:
	# Boss defeated! For now just remove it.
	queue_free()
