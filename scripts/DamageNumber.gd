extends Node2D
class_name DamageNumber
## Stargazer - DamageNumber
## A floating number that pops up, drifts upward, and fades out.
## Spawn it with DamageNumber.spawn(parent, position, amount).

@onready var label: Label = $Label

# Convenience factory: creates, configures, and adds a damage number to `parent`.
static func spawn(parent: Node, world_pos: Vector2, amount: int, crit: bool = false) -> void:
	var scene: PackedScene = load("res://scenes/DamageNumber.tscn")
	if scene == null:
		return
	var dn := scene.instantiate()
	parent.add_child(dn)
	dn.global_position = world_pos
	dn.setup(amount, crit)

func setup(amount: int, crit: bool = false) -> void:
	if label == null:
		label = $Label
	label.text = str(amount)

	# Crits are bigger and gold; normal hits are white.
	var color := Color(1, 0.85, 0.3) if crit else Color(1, 1, 1)
	label.add_theme_color_override("font_color", color)
	var start_scale := 1.6 if crit else 1.1
	scale = Vector2(start_scale, start_scale)

	# A little random horizontal drift so stacked hits don't overlap perfectly.
	var drift_x := randf_range(-18.0, 18.0)
	var rise := -42.0

	var t := create_tween().set_parallel(true)
	# Pop in.
	t.tween_property(self, "scale", Vector2(1, 1), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Float up and out.
	t.tween_property(self, "position", position + Vector2(drift_x, rise), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Fade away.
	t.tween_property(self, "modulate:a", 0.0, 0.7).set_delay(0.15)
	# Clean up.
	t.chain().tween_callback(queue_free)
