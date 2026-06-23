extends CharacterBody2D
## Stargazer - Boss (Saturn)
## A simple boss that idles until the player gets close, then chases.
## Star/planet-themed bosses are the core of Stargazer.
## Now with a code-drawn ringed-planet visual, ring spin, hit flash & juice.

@export var boss_name: String = "Saturn"
@export var max_health: int = 200
@export var move_speed: float = 90.0
@export var aggro_range: float = 260.0
@export var contact_damage: int = 10

var health: int = max_health
var player: Node2D = null
var is_aggro: bool = false
var _attack_cooldown: float = 0.0

@onready var visual: Node2D = $Visual          # The code-drawn planet (BossArt).
@onready var health_bar: ProgressBar = $HealthBar
@onready var name_label: Label = $NameLabel

func _ready() -> void:
	health = max_health
	name_label.text = boss_name
	health_bar.max_value = max_health
	health_bar.value = health
	player = get_tree().get_first_node_in_group("player")
	# Gentle idle pulse on the planet.
	Juice.pulse(visual, 0.05, 1.4)

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		return

	var dist := global_position.distance_to(player.global_position)
	is_aggro = dist <= aggro_range

	# Always spin the rings; faster when aggro.
	if visual:
		visual.rotation += delta * (1.5 if is_aggro else 0.4)

	if is_aggro:
		var dir := (player.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()

		# Contact damage on a cooldown.
		_attack_cooldown -= delta
		if dist <= 56.0 and _attack_cooldown <= 0.0:
			if player.has_method("take_damage"):
				player.take_damage(contact_damage)
			_attack_cooldown = 1.0
	else:
		velocity = Vector2.ZERO

func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	health_bar.value = health
	# Flash + squash on hit.
	if visual:
		Juice.flash(visual, Color(1, 1, 1), 0.07)
		Juice.pop(visual, 0.18, 0.16)
	if health <= 0:
		_die()

func _die() -> void:
	# Boss defeated! A little pop, then remove it.
	if visual:
		var t := create_tween()
		t.tween_property(visual, "scale", Vector2(1.6, 1.6), 0.15)
		t.parallel().tween_property(visual, "modulate:a", 0.0, 0.25)
		t.tween_callback(queue_free)
	else:
		queue_free()
