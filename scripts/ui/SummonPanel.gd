extends Control
class_name SummonPanel
## Stargazer - Altar summoning panel
## Lists the cosmic encounters, what each one still needs, and lets the player
## commit the materials. Locked bosses explain their requirement instead of
## silently refusing.

signal closed()
signal summon_requested(boss_id: String)

var _rows: Array = []
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.scrim(0.6))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UIKit.panel(Vector2(660, 0))
	center.add_child(panel)

	var root := UIKit.vbox(10)
	panel.add_child(root)
	root.add_child(UIKit.label("Altar of Distant Suns", 24, Palette.GOLD))
	root.add_child(UIKit.label("Offer the materials to call a world down into the arena.", 14, Palette.TEXT_DIM))
	root.add_child(UIKit.separator())

	for boss in GameData.BOSSES:
		root.add_child(_build_row(boss))

	_status = UIKit.label("", 14, Palette.TEXT_DIM)
	root.add_child(_status)

	var close := UIKit.button("Back  (Esc)")
	close.pressed.connect(func() -> void: closed.emit())
	root.add_child(close)

	GameState.inventory_changed.connect(refresh)
	GameState.progression_changed.connect(refresh)
	refresh()

func _build_row(boss: Dictionary) -> Control:
	var accent: Color = boss.get("accent", Palette.GOLD)
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", Palette.panel_style(Color(0.1, 0.1, 0.2, 0.92), Color(accent.r, accent.g, accent.b, 0.6), 8))
	var row := UIKit.hbox(14)
	row_panel.add_child(row)

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(String(boss["name"]), 19, accent))
	info.add_child(UIKit.label(String(boss.get("title", "")), 13, Palette.TEXT_DIM))
	var req := UIKit.label("", 13, Palette.CYAN)
	info.add_child(req)
	row.add_child(info)

	var button := UIKit.button("Summon", accent)
	var boss_id := String(boss["id"])
	button.pressed.connect(func() -> void: _summon(boss_id))
	row.add_child(button)

	_rows.append({"id": boss_id, "req": req, "button": button})
	return row_panel

func _summon(boss_id: String) -> void:
	var blocker := GameState.data.summon_blocker(boss_id)
	if blocker != "":
		_status.text = blocker
		_status.add_theme_color_override("font_color", Palette.DANGER)
		return
	summon_requested.emit(boss_id)

func refresh() -> void:
	for entry in _rows:
		var boss_id := String(entry["id"])
		var boss := GameData.get_boss(boss_id)
		var blocker := GameState.data.summon_blocker(boss_id)
		var defeated := GameState.data.boss_defeated(boss_id)
		var sigil := String(boss.get("sigil", ""))
		var text := "Offering: %s %d/1" % [GameData.item_name(sigil), GameState.data.count(sigil)]
		if defeated:
			text = "Defeated once — challenge again.  " + text
		if blocker != "":
			text = blocker + "\n" + text
		var req: Label = entry["req"]
		req.text = text
		var button: Button = entry["button"]
		button.disabled = blocker != ""
		button.text = "Summon" if blocker == "" else "Locked"
		button.tooltip_text = blocker if blocker != "" else "Begin the encounter"
