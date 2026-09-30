extends CanvasLayer
class_name HUD
## Stargazer - HUD
## Health, dash readiness, carried materials, the current objective and the
## contextual interaction prompt, plus the overlay panels (satchel/forge,
## altar, pause). Everything here is built in code from UIKit so the layout
## reflows cleanly at any desktop resolution.

signal summon_requested(boss_id: String)

const TRACKED_ITEMS := ["astral_shard", "void_ore", "ember_bloom", "emberseed", "salve"]

var _health_bar: ProgressBar
var _health_label: Label
var _dash_bar: ProgressBar
var _objective_label: Label
var _prompt_label: Label
var _notice_box: VBoxContainer
var _banner: Label
var _resource_box: HBoxContainer
var _root: Control

var _crafting: CraftingPanel
var _summon: SummonPanel
var _pause: PauseMenu
var _player: Player

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_status()
	_build_objective()
	_build_prompt()
	_build_notices()

	GameState.inventory_changed.connect(_refresh_resources)
	GameState.notice.connect(_push_notice)
	_refresh_resources()

func _build_status() -> void:
	var box := UIKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	box.position = Vector2(20, 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	var health_row := UIKit.hbox(8)
	_health_bar = UIKit.bar(260, 18, Palette.DANGER)
	health_row.add_child(_health_bar)
	_health_label = UIKit.label("100 / 100", 14, Palette.TEXT)
	health_row.add_child(_health_label)
	box.add_child(health_row)

	var dash_row := UIKit.hbox(8)
	_dash_bar = UIKit.bar(150, 8, Palette.CYAN)
	dash_row.add_child(_dash_bar)
	dash_row.add_child(UIKit.label("Dash", 12, Palette.TEXT_DIM))
	box.add_child(dash_row)

	_resource_box = UIKit.hbox(12)
	box.add_child(_resource_box)

func _build_objective() -> void:
	var panel := UIKit.panel(Vector2(300, 0))
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.offset_left = -320
	panel.offset_top = 18
	panel.offset_right = -20
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)

	var box := UIKit.vbox(2)
	panel.add_child(box)
	box.add_child(UIKit.label("Objective", 14, Palette.GOLD))
	_objective_label = UIKit.label("", 14, Palette.TEXT)
	box.add_child(_objective_label)
	box.add_child(UIKit.label("C  satchel & forge     Esc  pause", 11, Palette.TEXT_DIM))

func _build_prompt() -> void:
	_prompt_label = UIKit.label("", 16, Palette.CYAN)
	_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_top = -74
	_prompt_label.offset_bottom = -46
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt_label)

func _build_notices() -> void:
	_notice_box = UIKit.vbox(2)
	_notice_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice_box.anchor_left = 0.5
	_notice_box.anchor_right = 0.5
	_notice_box.anchor_top = 1.0
	_notice_box.anchor_bottom = 1.0
	_notice_box.offset_left = -220
	_notice_box.offset_right = 220
	_notice_box.offset_top = -190
	_notice_box.offset_bottom = -90
	_notice_box.alignment = BoxContainer.ALIGNMENT_END
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notice_box)

	_banner = UIKit.label("", 28, Palette.GOLD)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = 96
	_banner.offset_bottom = 140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
func bind_player(player: Player) -> void:
	_player = player
	set_health(player.health, player.max_health)

func set_health(current: int, maximum: int) -> void:
	_health_bar.value = 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	_health_label.text = "%d / %d" % [maxi(current, 0), maximum]

func set_dash(ready_fraction: float) -> void:
	_dash_bar.value = clampf(ready_fraction, 0.0, 1.0)

func set_prompt(text: String) -> void:
	_prompt_label.text = text

func set_objective(text: String) -> void:
	_objective_label.text = text

func show_banner(text: String, color: Color = Palette.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.4)
	t.tween_property(_banner, "modulate:a", 0.0, 0.6)

func open_summon_panel() -> void:
	if _summon != null and is_instance_valid(_summon):
		return
	_close_crafting()
	_summon = SummonPanel.new()
	_summon.closed.connect(_close_summon)
	_summon.summon_requested.connect(_on_summon_requested)
	_root.add_child(_summon)
	_set_player_control(false)

func is_panel_open() -> bool:
	return (_crafting != null and is_instance_valid(_crafting)) \
		or (_summon != null and is_instance_valid(_summon)) \
		or (_pause != null and is_instance_valid(_pause))

# ---------------------------------------------------------------------------
# PANELS
# ---------------------------------------------------------------------------
func _on_summon_requested(boss_id: String) -> void:
	_close_summon()
	summon_requested.emit(boss_id)

func _close_summon() -> void:
	if _summon != null and is_instance_valid(_summon):
		_summon.queue_free()
	_summon = null
	_set_player_control(true)

func _toggle_crafting() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_close_crafting()
		return
	_close_summon()
	_crafting = CraftingPanel.new()
	_crafting.closed.connect(_close_crafting)
	_root.add_child(_crafting)
	_set_player_control(false)

func _close_crafting() -> void:
	if _crafting != null and is_instance_valid(_crafting):
		_crafting.queue_free()
	_crafting = null
	_set_player_control(true)

func _toggle_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		_close_pause()
		return
	_pause = PauseMenu.new()
	_pause.resumed.connect(_close_pause)
	_pause.quit_to_title.connect(_quit_to_title)
	_root.add_child(_pause)
	get_tree().paused = true

func _close_pause() -> void:
	if _pause != null and is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null
	get_tree().paused = false

func _quit_to_title() -> void:
	GameState.save_game()
	_close_pause()
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")

func _set_player_control(enabled: bool) -> void:
	if _player != null and is_instance_valid(_player):
		_player.control_enabled = enabled

# ---------------------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------------------
## Runs before the player because the HUD sits on a CanvasLayer that processes
## input first; consuming the event here stops a menu keystroke also swinging
## the blade.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _summon != null and is_instance_valid(_summon):
			_close_summon()
		elif _crafting != null and is_instance_valid(_crafting):
			_close_crafting()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	if event.is_action_pressed("toggle_craft") or event.is_action_pressed("toggle_inventory"):
		_toggle_crafting()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# FEEDBACK
# ---------------------------------------------------------------------------
func _refresh_resources() -> void:
	for child in _resource_box.get_children():
		child.queue_free()
	for id in TRACKED_ITEMS:
		var amount := GameState.data.count(id)
		if amount <= 0 and id != "salve":
			continue
		var chip := UIKit.label("%s %d" % [GameData.item_name(id), amount], 13, GameData.item_color(id))
		chip.tooltip_text = GameData.item_desc(id)
		_resource_box.add_child(chip)

func _push_notice(text: String, color: Color) -> void:
	var label := UIKit.label(text, 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_box.add_child(label)
	while _notice_box.get_child_count() > 4:
		_notice_box.get_child(0).free()
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_property(label, "modulate:a", 0.0, 0.8)
	t.tween_callback(label.queue_free)
