extends Node
## Stargazer - Juice
## A small library of reusable, code-driven "game feel" animations.
## All effects use Tweens, so NO external art/sprites are required.
## Add this as an Autoload singleton named "Juice" (Project > Project Settings > Autoload)
## OR call the static helpers directly: Juice.squash(node), etc.

# ---------------------------------------------------------------------------
# SQUASH & STRETCH
# A quick squash-and-stretch pop. Great for impacts, spawns, and pickups.
# ---------------------------------------------------------------------------
static func pop(node: Node2D, amount: float = 0.25, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.scale
	var t := node.create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.scale = base * (1.0 + amount)
	t.tween_property(node, "scale", base, time)

# A directional squash: squashes along the hit/move direction.
static func squash(node: Node2D, dir: Vector2, amount: float = 0.2, time: float = 0.12) -> void:
	if not is_instance_valid(node):
		return
	var base: Vector2 = node.scale
	var horizontal := absf(dir.x) >= absf(dir.y)
	var squashed := base
	if horizontal:
		squashed = Vector2(base.x * (1.0 + amount), base.y * (1.0 - amount))
	else:
		squashed = Vector2(base.x * (1.0 - amount), base.y * (1.0 + amount))
	var t := node.create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", squashed, time * 0.5)
	t.tween_property(node, "scale", base, time)

# ---------------------------------------------------------------------------
# FLASH
# Briefly flash a node to a color and back (hit feedback).
# Works on any node with a "modulate" or "color" property.
# ---------------------------------------------------------------------------
static func flash(node: CanvasItem, color: Color = Color(1, 1, 1), time: float = 0.08) -> void:
	if not is_instance_valid(node):
		return
	var base: Color = node.modulate
	var t := node.create_tween()
	node.modulate = color
	t.tween_property(node, "modulate", base, time)

# ---------------------------------------------------------------------------
# KNOCKBACK
# Shove a node in a direction and ease it back to where it started.
# Use for "got hit" reactions. Returns immediately; runs over `time`.
# ---------------------------------------------------------------------------
static func knockback(node: Node2D, dir: Vector2, distance: float = 16.0, time: float = 0.18) -> void:
	if not is_instance_valid(node):
		return
	var start: Vector2 = node.position
	var target := start + dir.normalized() * distance
	var t := node.create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", target, time * 0.4)
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(node, "position", start, time * 0.6)

# ---------------------------------------------------------------------------
# PULSE (looping)
# A gentle continuous "breathing" pulse. Returns the Tween so you can kill it
# later with `tween.kill()` when state changes.
# ---------------------------------------------------------------------------
static func pulse(node: Node2D, amount: float = 0.06, time: float = 0.9) -> Tween:
	if not is_instance_valid(node):
		return null
	var base: Vector2 = node.scale
	var t := node.create_tween().set_loops()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", base * (1.0 + amount), time)
	t.tween_property(node, "scale", base, time)
	return t

# ---------------------------------------------------------------------------
# CAMERA SHAKE
# Shake the active Camera2D. Call from anything; it finds the player's camera.
# Pass the camera explicitly for best results.
# ---------------------------------------------------------------------------
static func shake(camera: Camera2D, strength: float = 6.0, duration: float = 0.25) -> void:
	if not is_instance_valid(camera):
		return
	var original := camera.offset
	var elapsed := 0.0
	var tree := camera.get_tree()
	while elapsed < duration:
		var decay := 1.0 - (elapsed / duration)
		camera.offset = original + Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * strength * decay
		await tree.process_frame
		elapsed += tree.root.get_process_delta_time()
	camera.offset = original
