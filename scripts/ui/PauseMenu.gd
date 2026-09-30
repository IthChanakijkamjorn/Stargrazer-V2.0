extends Control
class_name PauseMenu
## Stargazer - Pause menu
## Pauses the tree, shows the control reference and settings, and offers a
## clean exit back to the title screen. Saving is explicit so leaving a boss
## fight can never overwrite hub progress with a half-finished encounter.

signal resumed()
signal quit_to_title()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(UIKit.scrim(0.72))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UIKit.panel(Vector2(720, 0))
	center.add_child(panel)

	var root := UIKit.vbox(12)
	panel.add_child(root)
	root.add_child(UIKit.title("Paused", 30))
	root.add_child(UIKit.separator())

	var columns := UIKit.hbox(24)
	root.add_child(columns)

	var left := UIKit.vbox(8)
	left.custom_minimum_size = Vector2(300, 0)
	left.add_child(UIKit.label("Controls", 22, Palette.GOLD))
	for line in _control_lines():
		left.add_child(UIKit.label(line, 14, Palette.TEXT_DIM))
	columns.add_child(left)

	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings := SettingsPanel.new()
	settings.custom_minimum_size = Vector2(340, 250)
	right.add_child(settings)
	columns.add_child(right)

	root.add_child(UIKit.separator())

	var buttons := UIKit.hbox(10)
	var resume := UIKit.button("Resume  (Esc)")
	resume.pressed.connect(func() -> void: resumed.emit())
	buttons.add_child(resume)

	var save := UIKit.button("Save now", Palette.HEAL)
	var saved_label := UIKit.label("", 13, Palette.HEAL)
	save.pressed.connect(func() -> void:
		saved_label.text = "Progress saved." if GameState.save_game() else "Could not write the save file.")
	buttons.add_child(save)

	var quit := UIKit.button("Quit to title", Palette.DANGER)
	quit.pressed.connect(func() -> void: quit_to_title.emit())
	buttons.add_child(quit)
	root.add_child(buttons)
	root.add_child(saved_label)

	resume.grab_focus()

static func _control_lines() -> Array:
	return [
		"Move — WASD or arrow keys",
		"Attack — Left mouse or Space",
		"Aim — move the mouse (keyboard aim also works)",
		"Dash — Shift or right mouse",
		"Interact / till / plant / harvest — E",
		"Use Astral Salve — Q",
		"Satchel & Star Forge — C",
		"Inventory summary — Tab or I",
		"Skip boss intro — Enter or Space",
		"Pause — Esc",
	]
