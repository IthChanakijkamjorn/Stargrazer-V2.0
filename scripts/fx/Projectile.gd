extends Area2D
class_name Projectile
## Stargazer - Projectile
## A single code-drawn hazard orb/blade used by every boss. Supports straight
## flight, gravity-style curving, and "boomerang" blades that return to their
## owner. Self-frees on lifetime expiry, on leaving the arena, or after it hits
## the player, so nothing can accumulate across an encounter.

enum Shape { ORB, BLADE, EMBER }

const MAX_ACTIVE := 220

var velocity: Vector2 = Vector2.RIGHT
var damage: int = 10
var radius: float = 8.0
var lifetime: float = 6.0
var color: Color = Palette.EMBER
var shape: int = Shape.ORB
var spin: float = 6.0
## Optional curve applied every second (used for fan spread / homing arcs).
var acceleration: Vector2 = Vector2.ZERO
## When set, the projectile flies out then returns to this node and vanishes.
var return_to: Node2D = null
var return_after: float = 0.9
## Arena bounds; the projectile despawns outside them.
var bounds_center: Vector2 = Vector2.ZERO
var bounds_radius: float = 0.0

var _age: float = 0.0
var _angle: float = 0.0
var _returning: bool = false
var _spent: bool = false

static func active_count(tree: SceneTree) -> int:
	return tree.get_nodes_in_group("projectile").size()

## Creates and registers a projectile. Returns null when the safety cap is hit,
## which keeps effects bounded even if a pattern misbehaves.
static func fire(parent: Node, pos: Vector2, vel: Vector2, cfg: Dictionary = {}) -> Projectile:
	if parent == null or not is_instance_valid(parent) or parent.get_tree() == null:
		return null
	if active_count(parent.get_tree()) >= MAX_ACTIVE:
		return null
	var p := Projectile.new()
	p.velocity = vel
	for key in cfg.keys():
		if key in p:
			p.set(key, cfg[key])
	parent.add_child(p)
	p.global_position = pos
	return p

func _ready() -> void:
	add_to_group("projectile")
	z_index = 120
	# Layer 0: nothing needs to detect projectiles.
	# Mask 2: the player's body layer, so hits are resolved here.
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	add_child(shape_node)
	_angle = velocity.angle()
	scale = Vector2.ZERO
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	_age += delta
	if _spent:
		return
	if return_to != null and is_instance_valid(return_to):
		if not _returning and _age >= return_after:
			_returning = true
		if _returning:
			var to_owner := return_to.global_position - global_position
			if to_owner.length() < 26.0:
				_despawn()
				return
			velocity = velocity.move_toward(to_owner.normalized() * velocity.length(), 2400.0 * delta)
	elif return_to != null:
		# The owner died mid-flight: keep flying rather than crash, and expire.
		return_to = null

	velocity += acceleration * delta
	global_position += velocity * delta
	_angle = velocity.angle()
	rotation = _angle if shape == Shape.BLADE else 0.0
	queue_redraw()

	if bounds_radius > 0.0 and global_position.distance_to(bounds_center) > bounds_radius + 90.0:
		_despawn()
		return
	if _age >= lifetime:
		_despawn()
		return
	_check_player_hit()

func _check_player_hit() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			if body.has_method("is_invulnerable") and body.is_invulnerable():
				continue
			body.take_damage(damage, global_position)
			_burst()
			return

func _burst() -> void:
	_spent = true
	set_deferred("monitoring", false)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE * 1.8, 0.12)
	t.tween_property(self, "modulate:a", 0.0, 0.12)
	t.chain().tween_callback(queue_free)

func _despawn() -> void:
	_spent = true
	set_deferred("monitoring", false)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.1)
	t.tween_callback(queue_free)

func _draw() -> void:
	match shape:
		Shape.BLADE:
			_draw_blade()
		Shape.EMBER:
			_draw_ember()
		_:
			_draw_orb()

func _draw_orb() -> void:
	Palette.draw_halo(self, Vector2.ZERO, radius * 2.1, Color(color.r, color.g, color.b, 0.4), 4)
	draw_circle(Vector2.ZERO, radius, color)
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.4, Color(1, 1, 1, 0.85))

func _draw_ember() -> void:
	Palette.draw_halo(self, Vector2.ZERO, radius * 2.4, Color(color.r, color.g, color.b, 0.35), 4)
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0 + _age * spin
		var r: float = radius * (1.0 if i % 2 == 0 else 0.55)
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)
	draw_circle(Vector2.ZERO, radius * 0.42, Color(1, 0.95, 0.8))

func _draw_blade() -> void:
	Palette.draw_halo(self, Vector2.ZERO, radius * 2.0, Color(color.r, color.g, color.b, 0.3), 3)
	var length := radius * 2.4
	draw_colored_polygon(PackedVector2Array([
		Vector2(length, 0), Vector2(0, radius * 0.8),
		Vector2(-length * 0.45, 0), Vector2(0, -radius * 0.8),
	]), color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(length, 0), Vector2(0, radius * 0.3), Vector2(-length * 0.45, 0),
	]), Color(1, 1, 1, 0.8))
