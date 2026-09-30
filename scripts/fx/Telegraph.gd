extends Node2D
class_name Telegraph
## Stargazer - Telegraph
## Highly readable attack warnings drawn under the combatants: a filling
## circle for impact zones and a sweeping bar for charges. When the warning
## completes it optionally deals damage inside the shape, then fades.
##
## Telegraphs are deliberately high-contrast (bright rim + dark inner fill) so
## they stay legible over the textured indigo ground.

enum Kind { CIRCLE, BEAM }

var kind: int = Kind.CIRCLE
var radius: float = 70.0
var length: float = 300.0
var width: float = 60.0
var direction: Vector2 = Vector2.RIGHT
var warn_time: float = 1.0
var damage: int = 0
var color: Color = Palette.TELEGRAPH_EDGE
## Emitted when the warning finishes, before the fade-out.
signal detonated(node: Telegraph)

var _elapsed: float = 0.0
var _done: bool = false

static func circle(parent: Node, pos: Vector2, p_radius: float, p_warn: float, p_damage: int, p_color: Color = Palette.TELEGRAPH_EDGE) -> Telegraph:
	if parent == null or not is_instance_valid(parent):
		return null
	var t := Telegraph.new()
	t.kind = Kind.CIRCLE
	t.radius = p_radius
	t.warn_time = p_warn
	t.damage = p_damage
	t.color = p_color
	parent.add_child(t)
	t.global_position = pos
	return t

static func beam(parent: Node, pos: Vector2, dir: Vector2, p_length: float, p_width: float, p_warn: float, p_damage: int, p_color: Color = Palette.TELEGRAPH_EDGE) -> Telegraph:
	if parent == null or not is_instance_valid(parent):
		return null
	var t := Telegraph.new()
	t.kind = Kind.BEAM
	t.direction = dir.normalized()
	t.length = p_length
	t.width = p_width
	t.warn_time = p_warn
	t.damage = p_damage
	t.color = p_color
	parent.add_child(t)
	t.global_position = pos
	return t

func _ready() -> void:
	add_to_group("telegraph")
	# Below characters, above the ground, so it never hides the fight.
	z_index = 20

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	queue_redraw()
	if _elapsed >= warn_time:
		_detonate()

func progress() -> float:
	return clampf(_elapsed / maxf(warn_time, 0.001), 0.0, 1.0)

func _detonate() -> void:
	_done = true
	detonated.emit(self)
	if damage > 0:
		_apply_damage()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.28)
	t.tween_callback(queue_free)

func _apply_damage() -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if not (p is Node2D) or not p.has_method("take_damage"):
			continue
		var local: Vector2 = (p as Node2D).global_position - global_position
		var hit := false
		if kind == Kind.CIRCLE:
			hit = local.length() <= radius
		else:
			var along := local.dot(direction)
			var across := absf(local.dot(Vector2(-direction.y, direction.x)))
			hit = along >= -width * 0.5 and along <= length and across <= width * 0.5
		if hit:
			p.take_damage(damage, global_position)

func _draw() -> void:
	var t := progress()
	if kind == Kind.CIRCLE:
		_draw_circle_warning(t)
	else:
		_draw_beam_warning(t)

func _draw_circle_warning(t: float) -> void:
	# Dark base keeps the bright rim readable over any scenery.
	draw_circle(Vector2.ZERO, radius, Color(0.05, 0.02, 0.06, 0.45))
	draw_circle(Vector2.ZERO, radius * t, Color(color.r, color.g, color.b, 0.3))
	_draw_ring(radius, 3.0, Color(color.r, color.g, color.b, 0.95))
	_draw_ring(radius * t, 2.0, Color(1, 1, 1, 0.7))
	# Crosshair ticks emphasise the centre of the impact.
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var d := Vector2(cos(a), sin(a))
		draw_line(d * radius * 0.82, d * radius, Color(color.r, color.g, color.b, 0.9), 2.0)

func _draw_beam_warning(t: float) -> void:
	var forward := direction
	var side := Vector2(-forward.y, forward.x) * width * 0.5
	var base := PackedVector2Array([
		-side, side, side + forward * length, -side + forward * length,
	])
	draw_colored_polygon(base, Color(0.05, 0.02, 0.06, 0.45))
	var filled := PackedVector2Array([
		-side, side, side + forward * length * t, -side + forward * length * t,
	])
	draw_colored_polygon(filled, Color(color.r, color.g, color.b, 0.3))
	draw_polyline(PackedVector2Array([
		-side, -side + forward * length, side + forward * length, side, -side,
	]), Color(color.r, color.g, color.b, 0.95), 3.0, true)

func _draw_ring(r: float, thickness: float, c: Color) -> void:
	if r <= 0.5:
		return
	var pts := PackedVector2Array()
	for i in range(33):
		var a := TAU * float(i) / 32.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, c, thickness, true)
