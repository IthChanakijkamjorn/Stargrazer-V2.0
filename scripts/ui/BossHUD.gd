extends CanvasLayer
class_name BossHUD
## Stargazer - Boss encounter HUD
## The player's health and dash sit bottom-left as usual; the boss gets a
## named bar with phase pips across the top so the fight's structure is always
## legible.

var _boss_name: Label
var _boss_title: Label
var _boss_bar: ProgressBar
var _phase_row: HBoxContainer
var _health_bar: ProgressBar
var _health_label: Label
var _dash_bar: ProgressBar
var _salve_label: Label
var _banner: Label
var _root: Control
var _phase_count: int = 2
var _accent: Color = Palette.GOLD

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_boss_bar()
	_build_player_bar()
	GameState.inventory_changed.connect(_refresh_salve)

func _build_boss_bar() -> void:
	var box := UIKit.vbox(2)
	box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = 18
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	_boss_name = UIKit.title("", 22, Palette.GOLD)
	box.add_child(_boss_name)
	_boss_title = UIKit.title("", 13, Palette.TEXT_DIM)
	box.add_child(_boss_title)

	var bar_row := CenterContainer.new()
	_boss_bar = UIKit.bar(600, 16, Palette.DANGER)
	bar_row.add_child(_boss_bar)
	box.add_child(bar_row)

	var pip_wrap := CenterContainer.new()
	_phase_row = UIKit.hbox(6)
	pip_wrap.add_child(_phase_row)
	box.add_child(pip_wrap)

func _build_player_bar() -> void:
	var box := UIKit.vbox(6)
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 20
	box.offset_top = -92
	box.offset_bottom = -20
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)

	var row := UIKit.hbox(8)
	_health_bar = UIKit.bar(260, 18, Palette.HEAL)
	row.add_child(_health_bar)
	_health_label = UIKit.label("100 / 100", 14)
	row.add_child(_health_label)
	box.add_child(row)

	var dash_row := UIKit.hbox(8)
	_dash_bar = UIKit.bar(150, 8, Palette.CYAN)
	dash_row.add_child(_dash_bar)
	dash_row.add_child(UIKit.label("Dash", 12, Palette.TEXT_DIM))
	box.add_child(dash_row)

	_salve_label = UIKit.label("", 14, Palette.HEAL)
	box.add_child(_salve_label)
	_refresh_salve()

	_banner = UIKit.label("", 30, Palette.GOLD)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_top = -40
	_banner.offset_bottom = 40
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

# ---------------------------------------------------------------------------
func bind_boss(boss: BossBase, definition: Dictionary) -> void:
	_accent = definition.get("accent", Palette.GOLD)
	_phase_count = boss.encounter.phase_count()
	_boss_name.text = String(definition.get("name", "Boss")).to_upper()
	_boss_name.add_theme_color_override("font_color", _accent)
	_boss_title.text = String(definition.get("title", ""))
	_rebuild_pips(0)
	boss.health_changed.connect(set_boss_health)
	boss.phase_changed.connect(_on_phase_changed)

func bind_player(player: Player) -> void:
	player.health_changed.connect(set_health)
	player.dash_changed.connect(set_dash)
	set_health(player.health, player.max_health)

func set_boss_health(fraction: float, phase: int) -> void:
	_boss_bar.value = clampf(fraction, 0.0, 1.0)
	_rebuild_pips(phase)

func _on_phase_changed(phase: int) -> void:
	_rebuild_pips(phase)
	show_banner("PHASE %d" % (phase + 1), _accent)

func _rebuild_pips(phase: int) -> void:
	for child in _phase_row.get_children():
		child.free()
	for i in range(_phase_count):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(34, 5)
		pip.color = _accent if i <= phase else Color(0.3, 0.3, 0.44, 0.7)
		_phase_row.add_child(pip)

func set_health(current: int, maximum: int) -> void:
	var f := 0.0 if maximum <= 0 else clampf(float(current) / float(maximum), 0.0, 1.0)
	_health_bar.value = f
	_health_label.text = "%d / %d" % [maxi(current, 0), maximum]

func set_dash(ready_fraction: float) -> void:
	_dash_bar.value = clampf(ready_fraction, 0.0, 1.0)

func _refresh_salve() -> void:
	if _salve_label == null:
		return
	_salve_label.text = "Q  Starlight Salve x%d" % GameState.data.count("salve")

func show_banner(text: String, color: Color = Palette.GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_banner, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.1)
	t.tween_property(_banner, "modulate:a", 0.0, 0.5)
