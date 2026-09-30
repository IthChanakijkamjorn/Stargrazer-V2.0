extends Node2D
class_name DamageNumber
## Stargazer - DamageNumber
## A floating number that pops, drifts and fades. Built entirely in code so no
## extra scene file can go missing, and it self-frees on completion.

static func spawn(parent: Node, world_pos: Vector2, amount: int, crit: bool = false, color: Color = Color.WHITE) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not bool(GameState.data.get_setting("show_damage_numbers")):
		return
	var dn := DamageNumber.new()
	parent.add_child(dn)
	dn.global_position = world_pos
	dn.setup(amount, crit, color)

func setup(amount: int, crit: bool = false, color: Color = Color.WHITE) -> void:
	z_index = 400
	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-30, -12)
	label.size = Vector2(60, 24)
	var tint := color
	if tint == Color.WHITE:
		tint = Palette.GOLD if crit else Color(1, 1, 1)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20 if crit else 16)
	add_child(label)

	scale = Vector2.ONE * (1.5 if crit else 1.15)
	var drift := Vector2(randf_range(-20.0, 20.0), -46.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", position + drift, 0.66).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.42).set_delay(0.24)
	t.chain().tween_callback(queue_free)
