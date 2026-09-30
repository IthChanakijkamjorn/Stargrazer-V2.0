extends RefCounted
class_name GameData
## Stargazer - GameData
## Static, data-driven definitions for items, crafting recipes, crops, upgrades
## and boss encounters. Everything the rest of the game needs to know about
## "content" lives here so new chapters/bosses can be added without touching
## gameplay code.

# ---------------------------------------------------------------------------
# ITEMS
# ---------------------------------------------------------------------------
const ITEMS := {
	"stardust": {
		"name": "Stardust",
		"desc": "Crystallised starlight chipped from sky-crystals.",
		"color": Color(0.55, 0.85, 1.0),
	},
	"voidstone": {
		"name": "Voidstone",
		"desc": "Dense rock that fell from between the constellations.",
		"color": Color(0.62, 0.6, 0.78),
	},
	"emberseed": {
		"name": "Emberseed",
		"desc": "A seed that only sprouts in tilled astral soil.",
		"color": Color(1.0, 0.66, 0.35),
	},
	"ember_bloom": {
		"name": "Ember Bloom",
		"desc": "A harvested bloom, warm to the touch.",
		"color": Color(1.0, 0.45, 0.3),
	},
	"salve": {
		"name": "Astral Salve",
		"desc": "Restores health instantly. Press Q to use.",
		"color": Color(0.5, 1.0, 0.7),
	},
	"cinder_sigil": {
		"name": "Cinder Sigil",
		"desc": "Summons Mars, The Cinder Warlord, at the altar.",
		"color": Color(1.0, 0.4, 0.28),
	},
	"mars_core": {
		"name": "Cinder Core",
		"desc": "The still-burning heart of a fallen warlord.",
		"color": Color(1.0, 0.55, 0.25),
	},
	"ring_sigil": {
		"name": "Ring Sigil",
		"desc": "Summons Saturn, The Ringbound Sovereign, at the altar.",
		"color": Color(1.0, 0.85, 0.45),
	},
	"saturn_crown": {
		"name": "Ringbound Crown",
		"desc": "Proof that the Sovereign's rings were broken.",
		"color": Color(1.0, 0.92, 0.6),
	},
}

static func item_name(id: String) -> String:
	return String(ITEMS.get(id, {}).get("name", id))

static func item_desc(id: String) -> String:
	return String(ITEMS.get(id, {}).get("desc", ""))

static func item_color(id: String) -> Color:
	return ITEMS.get(id, {}).get("color", Color(0.85, 0.85, 0.9))

# ---------------------------------------------------------------------------
# UPGRADES
# Applied once; crafting an upgrade sets a persistent flag instead of adding
# an inventory item, so it can never be stacked or duplicated.
# ---------------------------------------------------------------------------
const UPGRADES := {
	"starforged_edge": {
		"name": "Starforged Edge",
		"desc": "Reforges your blade. +10 melee damage.",
		"damage_bonus": 10,
		"max_health_bonus": 0,
	},
	"astral_vitality": {
		"name": "Astral Vitality",
		"desc": "Star-touched resilience. +40 maximum health.",
		"damage_bonus": 0,
		"max_health_bonus": 40,
	},
	"void_lining": {
		"name": "Void Lining",
		"desc": "Woven voidstone cloak. +20 maximum health, +4 melee damage.",
		"damage_bonus": 4,
		"max_health_bonus": 20,
	},
}

# ---------------------------------------------------------------------------
# RECIPES
# `cost` is an exact material requirement. `kind` decides what happens on a
# successful craft: "item" grants `output` x `amount`, "upgrade" unlocks
# `upgrade`. `requires` is an optional progression flag gate.
# ---------------------------------------------------------------------------
const RECIPES := [
	{
		"id": "salve",
		"name": "Astral Salve",
		"desc": "Bottled bloom-light. Heals 40 HP.",
		"kind": "item",
		"output": "salve",
		"amount": 2,
		"cost": {"ember_bloom": 2, "stardust": 1},
		"requires": "",
	},
	{
		"id": "cinder_sigil",
		"name": "Cinder Sigil",
		"desc": "Opens the way to Mars at the altar.",
		"kind": "item",
		"output": "cinder_sigil",
		"amount": 1,
		"cost": {"stardust": 4, "voidstone": 3, "ember_bloom": 2},
		"requires": "",
	},
	{
		"id": "starforged_edge",
		"name": "Starforged Edge",
		"desc": "+10 melee damage. Crafted once.",
		"kind": "upgrade",
		"upgrade": "starforged_edge",
		"cost": {"stardust": 8, "voidstone": 4},
		"requires": "",
	},
	{
		"id": "astral_vitality",
		"name": "Astral Vitality",
		"desc": "+40 maximum health. Crafted once.",
		"kind": "upgrade",
		"upgrade": "astral_vitality",
		"cost": {"ember_bloom": 5, "voidstone": 6},
		"requires": "",
	},
	{
		"id": "void_lining",
		"name": "Void Lining",
		"desc": "+20 max health, +4 damage. Needs a Cinder Core.",
		"kind": "upgrade",
		"upgrade": "void_lining",
		"cost": {"mars_core": 1, "voidstone": 8, "stardust": 6},
		"requires": "mars_defeated",
	},
	{
		"id": "ring_sigil",
		"name": "Ring Sigil",
		"desc": "Opens the way to Saturn. Needs Cinder Cores.",
		"kind": "item",
		"output": "ring_sigil",
		"amount": 1,
		"cost": {"mars_core": 2, "stardust": 6, "voidstone": 4},
		"requires": "mars_defeated",
	},
]

static func get_recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == id:
			return r
	return {}

# ---------------------------------------------------------------------------
# CROPS
# ---------------------------------------------------------------------------
const CROP_STAGES := 4
## Seconds of growth needed to advance one stage.
const CROP_STAGE_SECONDS := 7.0
const CROP_SEED := "emberseed"
const CROP_YIELD := {"ember_bloom": 2, "emberseed": 1}

## Total seconds from planting to fully grown.
static func crop_total_seconds() -> float:
	return CROP_STAGE_SECONDS * float(CROP_STAGES - 1)

## Growth stage (0 .. CROP_STAGES-1) for a crop that has been growing
## `elapsed` seconds. Stage CROP_STAGES-1 is harvestable.
static func crop_stage(elapsed: float) -> int:
	if elapsed <= 0.0:
		return 0
	return clampi(int(elapsed / CROP_STAGE_SECONDS), 0, CROP_STAGES - 1)

static func crop_is_ripe(elapsed: float) -> bool:
	return crop_stage(elapsed) >= CROP_STAGES - 1

# ---------------------------------------------------------------------------
# RESOURCE NODES
# Renewable: every node respawns, so summon materials can never run out.
# ---------------------------------------------------------------------------
const RESOURCE_NODES := {
	"crystal": {
		"name": "Sky Crystal",
		"item": "stardust",
		"amount_min": 1,
		"amount_max": 2,
		"hits": 2,
		"respawn": 22.0,
	},
	"rock": {
		"name": "Voidstone Boulder",
		"item": "voidstone",
		"amount_min": 1,
		"amount_max": 2,
		"hits": 2,
		"respawn": 22.0,
	},
	"shrub": {
		"name": "Emberseed Shrub",
		"item": "emberseed",
		"amount_min": 1,
		"amount_max": 2,
		"hits": 1,
		"respawn": 16.0,
	},
}

# ---------------------------------------------------------------------------
# BOSS ENCOUNTERS
# Data-driven so additional chapters only need a new entry plus a scene.
# ---------------------------------------------------------------------------
const BOSSES := [
	{
		"id": "mars",
		"name": "Mars",
		"title": "The Cinder Warlord",
		"scene": "res://scenes/bosses/Mars.tscn",
		"sigil": "cinder_sigil",
		"requires": "",
		"defeat_flag": "mars_defeated",
		"reward": {"mars_core": 3, "stardust": 6},
		"intro": "A cracked crimson core drags its orbit down to meet you.",
		"accent": Color(1.0, 0.42, 0.3),
	},
	{
		"id": "saturn",
		"name": "Saturn",
		"title": "The Ringbound Sovereign",
		"scene": "res://scenes/bosses/Saturn.tscn",
		"sigil": "ring_sigil",
		"requires": "mars_defeated",
		"defeat_flag": "saturn_defeated",
		"reward": {"saturn_crown": 1, "stardust": 10, "voidstone": 6},
		"intro": "The rings unspool. The Sovereign has been waiting a long time.",
		"accent": Color(1.0, 0.85, 0.45),
	},
]

static func get_boss(id: String) -> Dictionary:
	for b in BOSSES:
		if b["id"] == id:
			return b
	return {}

# ---------------------------------------------------------------------------
# OBJECTIVES (lightweight tutorial / progression guide)
# The first unsatisfied step is shown in the HUD.
# ---------------------------------------------------------------------------
static func current_objective(state) -> String:
	if state.has_flag("saturn_defeated"):
		return "Chapter one complete. Re-challenge either boss from the altar."
	if state.has_flag("mars_defeated"):
		if state.count("ring_sigil") > 0:
			return "Use the altar (E) to summon Saturn, The Ringbound Sovereign."
		if state.can_craft("ring_sigil"):
			return "Craft a Ring Sigil (C) to challenge Saturn."
		return "Gather Stardust and Voidstone for a Ring Sigil (needs 2 Cinder Cores)."
	if state.count("cinder_sigil") > 0:
		return "Use the altar (E) to summon Mars, The Cinder Warlord."
	if state.can_craft("cinder_sigil"):
		return "Craft a Cinder Sigil (C), then summon Mars at the altar."
	if state.count("ember_bloom") < 2:
		if state.count("emberseed") > 0:
			return "Till soil with E, plant Emberseeds, then harvest Ember Blooms."
		return "Harvest Emberseed Shrubs (E) to get seeds for farming."
	return "Mine Sky Crystals and Voidstone Boulders (E) for sigil materials."
