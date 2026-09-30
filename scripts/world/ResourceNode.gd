extends Node2D
class_name ResourceNode
## Stargazer - ResourceNode
## A harvestable/minable world object (sky crystal, voidstone boulder,
## emberseed shrub). Takes a configurable number of interactions to deplete,
## drops its item, then regrows after a timer so summon materials and seeds can
## never permanently run out.

signal harvested(item_id: String, amount: int)

@export var node_kind: String = "crystal"
@export var variation: float = 0.0

var _definition: Dictionary = {}
var _hits_left: int = 1
var _respawn_left: float = 0.0
var _depleted: bool = false
var _time: float = 0.0
var _shake: float = 0.0

@onready var area: Area2D = $Area

static func make(kind: String, p_variation: float = -1.0) -> ResourceNode:
	var n := ResourceNode.new()
	n.node_kind = kind
	n.variation = randf() if p_variation < 0.0 else p_variation
	# The interaction area must exist before _ready runs.
	var a := Area2D.new()
	a.name = "Area"
	# Layer 1 so the player's interact area (mask 1) can see it.
	a.collision_layer = 1
	a.collision_mask = 0
	a.monitoring = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	a.add_child(shape)
	n.add_child(a)
	return n

func _ready() -> void:
	add_to_group("resource_node")
	if variation <= 0.0:
		variation = randf()
	_definition = GameData.RESOURCE_NODES.get(node_kind, GameData.RESOURCE_NODES["crystal"])
	_hits_left = int(_definition.get("hits", 1))
	z_index = int(global_position.y)
	set_process(true)

func display_name() -> String:
	return String(_definition.get("name", "Resource"))

func can_interact() -> bool:
	return not _depleted

func interact_prompt() -> String:
	return "E  Harvest %s" % display_name()

func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 4.0)
	if _depleted:
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			_respawn()
	queue_redraw()

func interact(_player: Node) -> void:
	if _depleted:
		return
	_hits_left -= 1
	_shake = 1.0
	Juice.pop(self, 0.22, 0.16)
	if _hits_left > 0:
		ImpactFX.burst(get_parent(), global_position + Vector2(0, -6), _accent(), 26.0, 0.25)
		return
	_yield_resource()

func _yield_resource() -> void:
	var item := String(_definition.get("item", "stardust"))
	var amount := randi_range(int(_definition.get("amount_min", 1)), int(_definition.get("amount_max", 1)))
	GameState.add_item(item, amount)
	GameState.show_notice("+%d %s" % [amount, GameData.item_name(item)], GameData.item_color(item))
	harvested.emit(item, amount)
	ImpactFX.burst(get_parent(), global_position + Vector2(0, -8), _accent(), 52.0, 0.4)
	_deplete()

func _deplete() -> void:
	_depleted = true
	_respawn_left = float(_definition.get("respawn", 20.0))
	if is_instance_valid(area):
		area.set_deferred("monitorable", false)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.1, 0.2), 0.16).set_trans(Tween.TRANS_BACK)
	t.tween_property(self, "modulate:a", 0.25, 0.12)

func _respawn() -> void:
	_depleted = false
	_hits_left = int(_definition.get("hits", 1))
	if is_instance_valid(area):
		area.set_deferred("monitorable", true)
	modulate.a = 1.0
	scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _accent() -> Color:
	return GameData.item_color(String(_definition.get("item", "stardust")))

# ---------------------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------------------
func _draw() -> void:
	if _depleted:
		_draw_stump()
		return
	var jitter := Vector2(sin(_time * 60.0) * _shake * 2.0, 0)
	draw_set_transform(jitter, 0.0, Vector2.ONE)
	match node_kind:
		"rock":
			_draw_rock()
		"shrub":
			_draw_shrub()
		_:
			_draw_crystal()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Damage read-out: a chip is knocked off after the first hit.
	if _hits_left < int(_definition.get("hits", 1)):
		draw_circle(Vector2(10, -4) + jitter, 3.0, Palette.GROUND_C)

func _draw_stump() -> void:
	draw_circle(Vector2(0, 8), 10.0, Palette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8, 8), Vector2(8, 8), Vector2(6, 2), Vector2(-6, 2),
	]), Palette.GROUND_C)

func _draw_crystal() -> void:
	draw_circle(Vector2(0, 10), 12.0, Palette.SHADOW)
	var pulse := 0.5 + 0.5 * sin(_time * 1.8 + variation * TAU)
	Palette.draw_halo(self, Vector2(0, -4), 26.0 + pulse * 4.0, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.22), 4)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -26), Vector2(9, -6), Vector2(5, 11), Vector2(-5, 11), Vector2(-9, -6),
	]), Color(0.38, 0.66, 0.96))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -26), Vector2(9, -6), Vector2(0, -4),
	]), Color(0.75, 0.94, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, 11), Vector2(-9, -2), Vector2(-5, 11),
	]), Color(0.32, 0.56, 0.86))
	draw_circle(Vector2(0, -10), 2.4 + pulse * 1.2, Color(1, 1, 1, 0.75))

func _draw_rock() -> void:
	draw_circle(Vector2(0, 12), 15.0, Palette.SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17, 8), Vector2(-13, -8), Vector2(-2, -15),
		Vector2(11, -10), Vector2(17, 2), Vector2(12, 11), Vector2(-7, 13),
	]), Color(0.24, 0.23, 0.38))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13, -8), Vector2(-2, -15), Vector2(11, -10), Vector2(2, -5), Vector2(-6, -5),
	]), Color(0.33, 0.31, 0.5))
	# Embedded voidstone veins.
	draw_line(Vector2(-6, -2), Vector2(2, 5), Color(Palette.VIOLET.r, Palette.VIOLET.g, Palette.VIOLET.b, 0.8), 2.0)
	draw_line(Vector2(2, 5), Vector2(9, 1), Color(Palette.VIOLET.r, Palette.VIOLET.g, Palette.VIOLET.b, 0.55), 1.6)

func _draw_shrub() -> void:
	draw_circle(Vector2(0, 10), 12.0, Palette.SHADOW)
	var c := Color(0.26, 0.29, 0.42)
	draw_circle(Vector2(-8, 3), 9.0, c)
	draw_circle(Vector2(8, 3), 9.0, c)
	draw_circle(Vector2(0, -3), 11.0, c)
	# Ripe emberseed pods.
	for i in range(3):
		var a := TAU * float(i) / 3.0 + _time * 0.4 + variation * TAU
		var p := Vector2(cos(a) * 8.0, sin(a) * 5.0 - 4.0)
		Palette.draw_halo(self, p, 7.0, Color(Palette.EMBER.r, Palette.EMBER.g, Palette.EMBER.b, 0.3), 2)
		draw_circle(p, 3.0, Palette.EMBER)
