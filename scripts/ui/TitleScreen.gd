extends Control
## Stargazer - Title screen
## The entry point: a drifting starfield, the game's wordmark and the run
## options. "Continue" only appears when a save actually exists, and starting
## a new game asks before overwriting it.

var _settings_layer: Control
var _confirm_layer: Control
var _menu: VBoxContainer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Palette.VOID_DEEP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var stars := Starfield.new()
	stars.static_background = true
	stars.area = Vector2(1800, 1100)
	stars.star_count = 300
	stars.nebula_count = 5
	add_child(stars)

	var emblem := TitleEmblem.new()
	emblem.set_anchors_preset(Control.PRESET_FULL_RECT)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emblem)

	var column := UIKit.vbox(10)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.anchor_left = 0.5
	column.anchor_right = 0.5
	column.anchor_top = 0.5
	column.anchor_bottom = 0.5
	column.offset_left = -150
	column.offset_right = 150
	column.offset_top = 10
	column.offset_bottom = 260
	add_child(column)
	_menu = column

	var title := UIKit.title("STARGAZER", 58)
	title.position = Vector2.ZERO
	var title_wrap := Control.new()
	title_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_wrap.offset_top = 120
	title_wrap.offset_bottom = 230
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_wrap)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_wrap.add_child(title)
	var subtitle := UIKit.title("Chapter One — The Ringbound Sky", 18, Palette.CYAN)
	subtitle.set_anchors_preset(Control.PRESET_FULL_RECT)
	subtitle.offset_top = 66
	title_wrap.add_child(subtitle)

	if GameState.has_save():
		var cont := UIKit.button("Continue", Palette.GOLD)
		cont.pressed.connect(_continue_game)
		column.add_child(cont)

	var new_game := UIKit.button("New Game")
	new_game.pressed.connect(_request_new_game)
	column.add_child(new_game)

	var settings := UIKit.button("Settings")
	settings.pressed.connect(_open_settings)
	column.add_child(settings)

	var quit := UIKit.button("Quit", Palette.DANGER)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)

	var hint := UIKit.label(
		"WASD move  •  Left mouse / Space attack  •  Shift dash  •  E interact  •  C forge",
		13, Palette.TEXT_DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46
	hint.offset_bottom = -20
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	column.get_child(0).grab_focus()

func _continue_game() -> void:
	if not GameState.load_game():
		GameState.new_game()
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _request_new_game() -> void:
	if not GameState.has_save():
		_start_new_game()
		return
	_confirm_layer = UIKit.scrim(0.7)
	add_child(_confirm_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := UIKit.panel(Vector2(420, 0))
	center.add_child(panel)
	var box := UIKit.vbox(10)
	panel.add_child(box)
	box.add_child(UIKit.label("Overwrite your save?", 22, Palette.GOLD))
	box.add_child(UIKit.wrapped(
		"A new game erases your materials, upgrades, crops and defeated bosses.", 380.0))
	var row := UIKit.hbox(10)
	var yes := UIKit.button("Start over", Palette.DANGER)
	yes.pressed.connect(_start_new_game)
	row.add_child(yes)
	var no := UIKit.button("Cancel")
	no.pressed.connect(func() -> void:
		_confirm_layer.queue_free()
		_confirm_layer = null
		_menu.get_child(0).grab_focus())
	row.add_child(no)
	box.add_child(row)
	no.grab_focus()

func _start_new_game() -> void:
	GameState.new_game()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/World.tscn")

func _open_settings() -> void:
	if _settings_layer != null and is_instance_valid(_settings_layer):
		return
	_settings_layer = UIKit.scrim(0.7)
	add_child(_settings_layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_layer.add_child(center)
	var panel := UIKit.panel(Vector2(440, 0))
	center.add_child(panel)
	var box := UIKit.vbox(10)
	panel.add_child(box)
	var settings := SettingsPanel.new()
	settings.custom_minimum_size = Vector2(400, 260)
	box.add_child(settings)
	var back := UIKit.button("Back")
	back.pressed.connect(func() -> void:
		_settings_layer.queue_free()
		_settings_layer = null
		_menu.get_child(0).grab_focus())
	box.add_child(back)
	back.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _settings_layer != null and is_instance_valid(_settings_layer):
			_settings_layer.queue_free()
			_settings_layer = null
			get_viewport().set_input_as_handled()
		elif _confirm_layer != null and is_instance_valid(_confirm_layer):
			_confirm_layer.queue_free()
			_confirm_layer = null
			get_viewport().set_input_as_handled()
