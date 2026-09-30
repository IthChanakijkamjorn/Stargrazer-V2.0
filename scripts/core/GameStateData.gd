extends RefCounted
class_name GameStateData
## Stargazer - GameStateData
## Pure, engine-independent game state: inventory, upgrades, crops,
## progression flags and settings, plus versioned (de)serialisation.
## Kept free of scene-tree dependencies so it can be unit tested headlessly.

const SAVE_VERSION := 1

## Baseline player stats before upgrades are applied.
const BASE_MAX_HEALTH := 100
const BASE_DAMAGE := 14
const SALVE_HEAL := 40

## Starting kit for a brand new game. Deliberately small but enough that the
## first boss is reachable inside a short session.
const STARTING_INVENTORY := {"emberseed": 2}

var inventory: Dictionary = {}      # item_id -> int (always > 0)
var upgrades: Dictionary = {}       # upgrade_id -> true
var flags: Dictionary = {}          # progression flag -> true
var crops: Array = []               # [{cell = Vector2i-as-[x,y], elapsed = float}]
var tilled: Array = []              # [[x, y], ...]
var settings: Dictionary = {}
var play_seconds: float = 0.0

func _init() -> void:
	reset()

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------
func reset() -> void:
	inventory = STARTING_INVENTORY.duplicate(true)
	upgrades = {}
	flags = {}
	crops = []
	tilled = []
	play_seconds = 0.0
	settings = default_settings()

static func default_settings() -> Dictionary:
	return {
		"effects_volume": 0.7,
		"music_volume": 0.5,
		"screen_shake": 1.0,
		"reduced_flash": false,
		"show_damage_numbers": true,
	}

func get_setting(key: String):
	var defaults := default_settings()
	if settings.has(key) and typeof(settings[key]) == typeof(defaults.get(key)):
		return settings[key]
	return defaults.get(key)

func set_setting(key: String, value) -> void:
	if default_settings().has(key):
		settings[key] = value

# ---------------------------------------------------------------------------
# INVENTORY
# ---------------------------------------------------------------------------
func count(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func add_item(item_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[item_id] = count(item_id) + amount

func add_items(bundle: Dictionary) -> void:
	for id in bundle.keys():
		add_item(String(id), int(bundle[id]))

func has_item(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount

func has_items(bundle: Dictionary) -> bool:
	for id in bundle.keys():
		if count(String(id)) < int(bundle[id]):
			return false
	return true

## Removes items only if all of them are available. Never goes negative.
func remove_item(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if count(item_id) < amount:
		return false
	var left := count(item_id) - amount
	if left > 0:
		inventory[item_id] = left
	else:
		inventory.erase(item_id)
	return true

func remove_items(bundle: Dictionary) -> bool:
	if not has_items(bundle):
		return false
	for id in bundle.keys():
		remove_item(String(id), int(bundle[id]))
	return true

## Item ids the player currently owns, in a stable display order.
func sorted_inventory() -> Array:
	var ids: Array = []
	for id in GameData.ITEMS.keys():
		if count(String(id)) > 0:
			ids.append(String(id))
	for id in inventory.keys():
		if not ids.has(String(id)) and count(String(id)) > 0:
			ids.append(String(id))
	return ids

# ---------------------------------------------------------------------------
# FLAGS & UPGRADES
# ---------------------------------------------------------------------------
func has_flag(flag: String) -> bool:
	return flag != "" and bool(flags.get(flag, false))

func set_flag(flag: String) -> void:
	if flag != "":
		flags[flag] = true

func has_upgrade(upgrade_id: String) -> bool:
	return bool(upgrades.get(upgrade_id, false))

func max_health() -> int:
	var total := BASE_MAX_HEALTH
	for id in upgrades.keys():
		total += int(GameData.UPGRADES.get(id, {}).get("max_health_bonus", 0))
	return total

func melee_damage() -> int:
	var total := BASE_DAMAGE
	for id in upgrades.keys():
		total += int(GameData.UPGRADES.get(id, {}).get("damage_bonus", 0))
	return total

# ---------------------------------------------------------------------------
# CRAFTING
# ---------------------------------------------------------------------------
## Human readable reason the recipe cannot be crafted, or "" if it can.
func craft_blocker(recipe_id: String) -> String:
	var recipe := GameData.get_recipe(recipe_id)
	if recipe.is_empty():
		return "Unknown recipe."
	var gate := String(recipe.get("requires", ""))
	if gate != "" and not has_flag(gate):
		return "Locked: defeat %s first." % gate.replace("_defeated", "").capitalize()
	if recipe.get("kind", "item") == "upgrade" and has_upgrade(String(recipe.get("upgrade", ""))):
		return "Already crafted."
	var missing: Array = []
	var cost: Dictionary = recipe.get("cost", {})
	for id in cost.keys():
		var need := int(cost[id]) - count(String(id))
		if need > 0:
			missing.append("%d %s" % [need, GameData.item_name(String(id))])
	if not missing.is_empty():
		return "Needs " + ", ".join(missing)
	return ""

func can_craft(recipe_id: String) -> bool:
	return craft_blocker(recipe_id) == ""

## Consumes the exact cost and grants the result. Returns true on success;
## on failure nothing at all is consumed.
func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var recipe := GameData.get_recipe(recipe_id)
	if not remove_items(recipe.get("cost", {})):
		return false
	if recipe.get("kind", "item") == "upgrade":
		upgrades[String(recipe["upgrade"])] = true
	else:
		add_item(String(recipe["output"]), int(recipe.get("amount", 1)))
	return true

# ---------------------------------------------------------------------------
# FARMING
# ---------------------------------------------------------------------------
static func _cell_key(cell: Vector2i) -> Array:
	return [cell.x, cell.y]

func is_tilled(cell: Vector2i) -> bool:
	return tilled.has(_cell_key(cell))

func till(cell: Vector2i) -> bool:
	if is_tilled(cell):
		return false
	tilled.append(_cell_key(cell))
	return true

func crop_index(cell: Vector2i) -> int:
	var key := _cell_key(cell)
	for i in range(crops.size()):
		if crops[i].get("cell", []) == key:
			return i
	return -1

func has_crop(cell: Vector2i) -> bool:
	return crop_index(cell) >= 0

## Plants a seed on tilled, empty soil. Consumes exactly one seed.
func plant(cell: Vector2i) -> bool:
	if not is_tilled(cell) or has_crop(cell):
		return false
	if not remove_item(GameData.CROP_SEED, 1):
		return false
	crops.append({"cell": _cell_key(cell), "elapsed": 0.0})
	return true

func advance_crops(delta: float) -> void:
	if delta <= 0.0:
		return
	var cap := GameData.crop_total_seconds()
	for c in crops:
		c["elapsed"] = minf(float(c.get("elapsed", 0.0)) + delta, cap)

func crop_elapsed(cell: Vector2i) -> float:
	var i := crop_index(cell)
	return 0.0 if i < 0 else float(crops[i].get("elapsed", 0.0))

func crop_stage_at(cell: Vector2i) -> int:
	return GameData.crop_stage(crop_elapsed(cell))

## Harvests a ripe crop, returning the yielded bundle (empty when not ripe).
func harvest(cell: Vector2i) -> Dictionary:
	var i := crop_index(cell)
	if i < 0:
		return {}
	if not GameData.crop_is_ripe(float(crops[i].get("elapsed", 0.0))):
		return {}
	crops.remove_at(i)
	var bundle: Dictionary = GameData.CROP_YIELD.duplicate(true)
	add_items(bundle)
	return bundle

# ---------------------------------------------------------------------------
# BOSS PROGRESSION
# ---------------------------------------------------------------------------
func boss_unlocked(boss_id: String) -> bool:
	var boss := GameData.get_boss(boss_id)
	if boss.is_empty():
		return false
	var gate := String(boss.get("requires", ""))
	return gate == "" or has_flag(gate)

func boss_defeated(boss_id: String) -> bool:
	var boss := GameData.get_boss(boss_id)
	return not boss.is_empty() and has_flag(String(boss.get("defeat_flag", "")))

func summon_blocker(boss_id: String) -> String:
	var boss := GameData.get_boss(boss_id)
	if boss.is_empty():
		return "Unknown encounter."
	if not boss_unlocked(boss_id):
		return "Sealed: defeat Mars first."
	var sigil := String(boss.get("sigil", ""))
	if not has_item(sigil, 1):
		return "Needs 1 %s" % GameData.item_name(sigil)
	return ""

func can_summon(boss_id: String) -> bool:
	return summon_blocker(boss_id) == ""

## Consumes the sigil. Returns true if the encounter may start.
func consume_summon(boss_id: String) -> bool:
	if not can_summon(boss_id):
		return false
	var boss := GameData.get_boss(boss_id)
	return remove_item(String(boss.get("sigil", "")), 1)

## Grants rewards once per victory and records the defeat flag.
## Repeat victories still grant loot but never re-award first-clear bonuses.
func register_victory(boss_id: String) -> Dictionary:
	var boss := GameData.get_boss(boss_id)
	if boss.is_empty():
		return {}
	var reward: Dictionary = boss.get("reward", {}).duplicate(true)
	add_items(reward)
	set_flag(String(boss.get("defeat_flag", "")))
	return reward

# ---------------------------------------------------------------------------
# SERIALISATION
# ---------------------------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"inventory": inventory.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"flags": flags.duplicate(true),
		"crops": crops.duplicate(true),
		"tilled": tilled.duplicate(true),
		"settings": settings.duplicate(true),
		"play_seconds": play_seconds,
	}

## Restores from a dictionary, falling back to safe defaults for anything
## missing, malformed or from an unknown version. Never throws.
func from_dict(data) -> bool:
	reset()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var version := int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		# Unknown//future save: keep defaults but still try the settings block,
		# which is forward compatible.
		_load_settings(data.get("settings", null))
		return false
	inventory = _sanitised_counts(data.get("inventory", null), STARTING_INVENTORY)
	upgrades = _sanitised_flags(data.get("upgrades", null), GameData.UPGRADES.keys())
	flags = _sanitised_flags(data.get("flags", null), _known_flags())
	tilled = _sanitised_cells(data.get("tilled", null))
	crops = _sanitised_crops(data.get("crops", null))
	_load_settings(data.get("settings", null))
	var seconds = data.get("play_seconds", 0.0)
	play_seconds = maxf(0.0, float(seconds)) if typeof(seconds) in [TYPE_FLOAT, TYPE_INT] else 0.0
	return true

func _known_flags() -> Array:
	var known: Array = []
	for b in GameData.BOSSES:
		known.append(String(b.get("defeat_flag", "")))
	return known

func _load_settings(raw) -> void:
	settings = default_settings()
	if typeof(raw) != TYPE_DICTIONARY:
		return
	for key in settings.keys():
		if raw.has(key) and typeof(raw[key]) == typeof(settings[key]):
			settings[key] = raw[key]
		elif raw.has(key) and typeof(settings[key]) == TYPE_FLOAT and typeof(raw[key]) == TYPE_INT:
			settings[key] = float(raw[key])
	settings["effects_volume"] = clampf(float(settings["effects_volume"]), 0.0, 1.0)
	settings["music_volume"] = clampf(float(settings["music_volume"]), 0.0, 1.0)
	settings["screen_shake"] = clampf(float(settings["screen_shake"]), 0.0, 1.0)

static func _sanitised_counts(raw, fallback: Dictionary) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return fallback.duplicate(true)
	var out: Dictionary = {}
	for id in raw.keys():
		if typeof(id) != TYPE_STRING:
			continue
		if not GameData.ITEMS.has(id):
			continue
		var value = raw[id]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var amount := int(value)
		if amount > 0:
			out[id] = amount
	return out

static func _sanitised_flags(raw, allowed: Array) -> Dictionary:
	var out: Dictionary = {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	for id in raw.keys():
		if typeof(id) == TYPE_STRING and allowed.has(id) and bool(raw[id]):
			out[id] = true
	return out

static func _sanitised_cells(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for entry in raw:
		if typeof(entry) != TYPE_ARRAY or entry.size() != 2:
			continue
		if typeof(entry[0]) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		if typeof(entry[1]) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var key := [int(entry[0]), int(entry[1])]
		if not out.has(key):
			out.append(key)
	return out

func _sanitised_crops(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	var cap := GameData.crop_total_seconds()
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var cell = entry.get("cell", null)
		if typeof(cell) != TYPE_ARRAY or cell.size() != 2:
			continue
		if typeof(cell[0]) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		if typeof(cell[1]) not in [TYPE_INT, TYPE_FLOAT]:
			continue
		var key := [int(cell[0]), int(cell[1])]
		# Crops can only exist on tilled soil and never stack.
		if not tilled.has(key):
			continue
		var dup := false
		for o in out:
			if o["cell"] == key:
				dup = true
				break
		if dup:
			continue
		var elapsed = entry.get("elapsed", 0.0)
		var seconds := float(elapsed) if typeof(elapsed) in [TYPE_INT, TYPE_FLOAT] else 0.0
		out.append({"cell": key, "elapsed": clampf(seconds, 0.0, cap)})
	return out

func duplicate_state() -> GameStateData:
	var copy := GameStateData.new()
	copy.from_dict(to_dict())
	return copy
