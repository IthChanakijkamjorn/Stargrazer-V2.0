extends Node
## Stargazer - GameState (autoload)
## Scene-tree facing wrapper around GameStateData. Owns the single live save
## slot, broadcasts change signals for the UI, and ticks crop growth so farms
## keep growing while the player is off fighting a boss.

signal inventory_changed()
signal progression_changed()
signal settings_changed()
signal notice(text: String, color: Color)

var data: GameStateData = GameStateData.new()

## Which encounter the boss arena should build. Cleared as soon as it is read
## so a crash/reload can never resurrect a half-finished fight.
var pending_boss_id: String = ""
## Result of the last encounter, consumed by the world when returning.
var last_result: Dictionary = {}

var _crop_accumulator: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()

func _process(delta: float) -> void:
	# Crops advance on real (unpaused) gameplay time only.
	if get_tree().paused:
		return
	data.play_seconds += delta
	data.advance_crops(delta)
	_crop_accumulator += delta

## True when a crop tick worth redrawing has accumulated.
func consume_crop_tick() -> bool:
	if _crop_accumulator >= 0.5:
		_crop_accumulator = 0.0
		return true
	return false

# ---------------------------------------------------------------------------
# SAVE SLOT
# ---------------------------------------------------------------------------
func has_save() -> bool:
	return SaveIO.has_save()

func new_game() -> void:
	var kept_settings := data.settings.duplicate(true)
	data = GameStateData.new()
	data.settings = kept_settings
	pending_boss_id = ""
	last_result = {}
	save_game()
	inventory_changed.emit()
	progression_changed.emit()

func load_game() -> bool:
	var result := SaveIO.load_state()
	data = result["state"]
	pending_boss_id = ""
	last_result = {}
	inventory_changed.emit()
	progression_changed.emit()
	settings_changed.emit()
	return bool(result["ok"])

func save_game() -> bool:
	return SaveIO.save_state(data)

# ---------------------------------------------------------------------------
# CONVENIENCE PASS-THROUGHS (each emits the right signal)
# ---------------------------------------------------------------------------
func add_items(bundle: Dictionary) -> void:
	data.add_items(bundle)
	inventory_changed.emit()

func add_item(id: String, amount: int = 1) -> void:
	data.add_item(id, amount)
	inventory_changed.emit()

func consume_item(id: String, amount: int = 1) -> bool:
	var ok := data.remove_item(id, amount)
	if ok:
		inventory_changed.emit()
	return ok

func craft(recipe_id: String) -> bool:
	var ok := data.craft(recipe_id)
	if ok:
		inventory_changed.emit()
		progression_changed.emit()
		save_game()
	return ok

func register_victory(boss_id: String) -> Dictionary:
	var reward := data.register_victory(boss_id)
	inventory_changed.emit()
	progression_changed.emit()
	save_game()
	return reward

func set_setting(key: String, value) -> void:
	data.set_setting(key, value)
	settings_changed.emit()
	save_game()

func objective_text() -> String:
	return GameData.current_objective(data)

func show_notice(text: String, color: Color = Color(0.85, 0.95, 1.0)) -> void:
	notice.emit(text, color)

# ---------------------------------------------------------------------------
# ENCOUNTER HAND-OFF
# ---------------------------------------------------------------------------
func begin_encounter(boss_id: String) -> bool:
	if not data.consume_summon(boss_id):
		return false
	pending_boss_id = boss_id
	last_result = {}
	save_game()
	return true

## Reads and clears the queued encounter id.
func take_pending_boss() -> String:
	var id := pending_boss_id
	pending_boss_id = ""
	return id
