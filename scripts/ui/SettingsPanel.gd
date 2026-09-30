extends Control
class_name SettingsPanel
## Stargazer - SettingsPanel
## Accessibility and audio options, shared by the title screen and the pause
## menu. Every change is written straight to the save slot so settings survive
## a crash and apply immediately.

func _ready() -> void:
	var box := UIKit.vbox(10)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)

	box.add_child(UIKit.label("Settings", 22, Palette.GOLD))
	box.add_child(UIKit.separator())

	_add_slider(box, "Effects volume", "effects_volume")
	_add_slider(box, "Music volume", "music_volume")
	_add_slider(box, "Screen shake", "screen_shake")
	_add_toggle(box, "Reduced flashing", "reduced_flash")
	_add_toggle(box, "Show damage numbers", "show_damage_numbers")

	box.add_child(UIKit.wrapped(
		"Stargazer ships with no audio yet, so the volume sliders are stored for future builds.",
		320.0, 12))

func _add_slider(parent: Control, text: String, key: String) -> void:
	var row := UIKit.hbox(10)
	var name_label := UIKit.label(text, 15)
	name_label.custom_minimum_size = Vector2(170, 0)
	row.add_child(name_label)
	var s := UIKit.slider(0.0, 1.0, 0.05, float(GameState.data.get_setting(key)))
	var value_label := UIKit.label("%d%%" % int(s.value * 100.0), 15, Palette.CYAN)
	value_label.custom_minimum_size = Vector2(52, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float) -> void:
		GameState.set_setting(key, v)
		value_label.text = "%d%%" % int(v * 100.0))
	row.add_child(s)
	row.add_child(value_label)
	parent.add_child(row)

func _add_toggle(parent: Control, text: String, key: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.button_pressed = bool(GameState.data.get_setting(key))
	cb.focus_mode = Control.FOCUS_ALL
	cb.add_theme_font_size_override("font_size", 15)
	cb.add_theme_color_override("font_color", Palette.TEXT)
	cb.toggled.connect(func(pressed: bool) -> void: GameState.set_setting(key, pressed))
	parent.add_child(cb)
