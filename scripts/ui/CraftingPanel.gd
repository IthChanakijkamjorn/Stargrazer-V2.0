extends Control
class_name CraftingPanel
## Stargazer - Crafting & Inventory panel
## Lists everything the player is carrying alongside the recipe book. Each
## recipe shows its exact cost, why it is unavailable, and crafts only on an
## explicit button press so a click can never also swing the blade.

signal closed()

var _recipe_rows: Array = []
var _inventory_box: VBoxContainer
var _status: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UIKit.scrim(0.55))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UIKit.panel(Vector2(760, 0))
	center.add_child(panel)

	var root := UIKit.vbox(10)
	panel.add_child(root)

	var header := UIKit.hbox(12)
	header.add_child(UIKit.label("Satchel & Star Forge", 24, Palette.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := UIKit.button("Close  (C)")
	close.pressed.connect(func() -> void: closed.emit())
	header.add_child(close)
	root.add_child(header)
	root.add_child(UIKit.separator())

	var columns := UIKit.hbox(18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# --- Inventory column -------------------------------------------------
	var left := UIKit.vbox(6)
	left.custom_minimum_size = Vector2(250, 300)
	left.add_child(UIKit.label("Carrying", 18, Palette.CYAN))
	var inv_scroll := ScrollContainer.new()
	inv_scroll.custom_minimum_size = Vector2(250, 280)
	inv_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inventory_box = UIKit.vbox(4)
	_inventory_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_scroll.add_child(_inventory_box)
	left.add_child(inv_scroll)
	columns.add_child(left)

	# --- Recipe column ----------------------------------------------------
	var right := UIKit.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UIKit.label("Star Forge recipes", 18, Palette.CYAN))
	var recipe_scroll := ScrollContainer.new()
	recipe_scroll.custom_minimum_size = Vector2(430, 280)
	recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var recipe_box := UIKit.vbox(8)
	recipe_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.add_child(recipe_box)
	right.add_child(recipe_scroll)
	columns.add_child(right)

	for recipe in GameData.RECIPES:
		recipe_box.add_child(_build_recipe_row(recipe))

	_status = UIKit.label("", 14, Palette.TEXT_DIM)
	root.add_child(_status)

	GameState.inventory_changed.connect(refresh)
	GameState.progression_changed.connect(refresh)
	refresh()

func _build_recipe_row(recipe: Dictionary) -> Control:
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", Palette.panel_style(Color(0.1, 0.1, 0.2, 0.9), Color(0.3, 0.3, 0.5, 0.7), 8))
	var row := UIKit.hbox(12)
	row_panel.add_child(row)

	var info := UIKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := UIKit.label(String(recipe["name"]), 17, Palette.TEXT)
	info.add_child(name_label)
	info.add_child(UIKit.label(String(recipe.get("desc", "")), 13, Palette.TEXT_DIM))
	var cost_label := UIKit.label("", 13, Palette.CYAN)
	info.add_child(cost_label)
	row.add_child(info)

	var craft_button := UIKit.button("Craft", Palette.GOLD)
	var recipe_id := String(recipe["id"])
	craft_button.pressed.connect(func() -> void: _craft(recipe_id))
	row.add_child(craft_button)

	_recipe_rows.append({
		"id": recipe_id,
		"cost_label": cost_label,
		"button": craft_button,
	})
	return row_panel

func _craft(recipe_id: String) -> void:
	var blocker := GameState.data.craft_blocker(recipe_id)
	if blocker != "":
		_status.text = blocker
		_status.add_theme_color_override("font_color", Palette.DANGER)
		return
	if GameState.craft(recipe_id):
		var recipe := GameData.get_recipe(recipe_id)
		_status.text = "Crafted %s." % String(recipe.get("name", recipe_id))
		_status.add_theme_color_override("font_color", Palette.HEAL)
		GameState.show_notice("Crafted %s" % String(recipe.get("name", recipe_id)), Palette.GOLD)

func refresh() -> void:
	if _inventory_box == null:
		return
	for child in _inventory_box.get_children():
		child.queue_free()
	var ids := GameState.data.sorted_inventory()
	if ids.is_empty():
		_inventory_box.add_child(UIKit.label("Nothing yet. Harvest shrubs and crystals with E.", 13, Palette.TEXT_DIM))
	for id in ids:
		var row := UIKit.hbox(8)
		var swatch := ColorRect.new()
		swatch.color = GameData.item_color(String(id))
		swatch.custom_minimum_size = Vector2(12, 12)
		var wrapper := CenterContainer.new()
		wrapper.add_child(swatch)
		row.add_child(wrapper)
		var name_label := UIKit.label(GameData.item_name(String(id)), 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.tooltip_text = GameData.item_desc(String(id))
		row.add_child(name_label)
		row.add_child(UIKit.label("x%d" % GameState.data.count(String(id)), 15, Palette.GOLD))
		_inventory_box.add_child(row)

	for entry in _recipe_rows:
		var recipe := GameData.get_recipe(String(entry["id"]))
		var parts: Array = []
		for cost_id in recipe.get("cost", {}).keys():
			var need := int(recipe["cost"][cost_id])
			var have := GameState.data.count(String(cost_id))
			parts.append("%s %d/%d" % [GameData.item_name(String(cost_id)), have, need])
		var blocker := GameState.data.craft_blocker(String(entry["id"]))
		var cost_label: Label = entry["cost_label"]
		cost_label.text = "  •  ".join(parts)
		cost_label.add_theme_color_override("font_color", Palette.CYAN if blocker == "" else Palette.TEXT_DIM)
		var button: Button = entry["button"]
		button.disabled = blocker != ""
		button.tooltip_text = blocker if blocker != "" else "Craft this now"
		button.text = "Craft" if blocker == "" else "Locked"
