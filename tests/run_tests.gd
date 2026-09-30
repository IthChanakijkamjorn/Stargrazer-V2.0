extends SceneTree
## Stargazer - headless test runner.
## Usage: godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 0 when every check passes, 1 otherwise.

var _passed := 0
var _failed := 0
var _current := ""

func _initialize() -> void:
	_run("inventory add/remove never goes negative", _test_inventory)
	_run("crafting consumes exact materials", _test_crafting)
	_run("crafting failure consumes nothing", _test_craft_failure)
	_run("upgrades apply once and change stats", _test_upgrades)
	_run("crop growth stages and harvest", _test_crops)
	_run("crops cannot be planted without seeds or soil", _test_crop_rules)
	_run("progression locks and unlocks", _test_progression)
	_run("summoning consumes a sigil exactly once", _test_summoning)
	_run("save round-trip preserves state", _test_save_roundtrip)
	_run("corrupt save falls back to defaults", _test_save_corruption)
	_run("malformed fields are sanitised", _test_save_sanitising)
	_run("objective text follows progression", _test_objectives)
	_run("encounter phase thresholds", _test_phases)
	_run("encounter lifecycle states", _test_encounter_lifecycle)

	print("")
	print("--- Stargazer tests: %d passed, %d failed ---" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

# ---------------------------------------------------------------------------
# harness
# ---------------------------------------------------------------------------
func _run(title: String, fn: Callable) -> void:
	_current = title
	var before := _failed
	fn.call()
	if _failed == before:
		print("  ok   %s" % title)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		printerr("  FAIL %s -> %s" % [_current, message])

func _eq(actual, expected, message: String) -> void:
	_check(actual == expected, "%s (got %s, expected %s)" % [message, actual, expected])

# ---------------------------------------------------------------------------
# inventory / crafting
# ---------------------------------------------------------------------------
func _test_inventory() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	s.add_item("stardust", 3)
	_eq(s.count("stardust"), 3, "add")
	_check(not s.remove_item("stardust", 4), "over-removal rejected")
	_eq(s.count("stardust"), 3, "count unchanged after failed removal")
	_check(s.remove_item("stardust", 3), "exact removal")
	_eq(s.count("stardust"), 0, "emptied")
	_check(not s.inventory.has("stardust"), "zero entries pruned")
	s.add_item("stardust", -5)
	_eq(s.count("stardust"), 0, "negative add ignored")
	_check(not s.has_items({"voidstone": 1}), "missing bundle detected")

func _test_crafting() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	s.add_items({"ember_bloom": 2, "stardust": 1})
	_check(s.can_craft("salve"), "salve craftable with exact materials")
	_check(s.craft("salve"), "craft succeeds")
	_eq(s.count("salve"), 2, "salve output amount")
	_eq(s.count("ember_bloom"), 0, "blooms consumed")
	_eq(s.count("stardust"), 0, "stardust consumed")
	_check(not s.can_craft("salve"), "cannot craft again without materials")

func _test_craft_failure() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	s.add_items({"ember_bloom": 1, "stardust": 5})
	var before: Dictionary = s.to_dict()["inventory"]
	_check(not s.craft("salve"), "craft blocked when short")
	_eq(s.to_dict()["inventory"], before, "nothing consumed on failure")
	_check(s.craft_blocker("salve").contains("Ember Bloom"), "blocker names the missing item")
	_check(s.craft_blocker("does_not_exist") != "", "unknown recipe blocked")
	_check(not s.craft("does_not_exist"), "unknown recipe cannot be crafted")

func _test_upgrades() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	_eq(s.max_health(), GameStateData.BASE_MAX_HEALTH, "base health")
	_eq(s.melee_damage(), GameStateData.BASE_DAMAGE, "base damage")
	s.add_items({"stardust": 8, "voidstone": 4})
	_check(s.craft("starforged_edge"), "upgrade crafted")
	_eq(s.melee_damage(), GameStateData.BASE_DAMAGE + 10, "damage bonus applied")
	s.add_items({"stardust": 8, "voidstone": 4})
	_check(not s.can_craft("starforged_edge"), "upgrade cannot be crafted twice")
	_eq(s.craft_blocker("starforged_edge"), "Already crafted.", "duplicate upgrade message")
	_check(not s.can_craft("void_lining"), "gated upgrade locked before Mars")
	s.set_flag("mars_defeated")
	s.add_items({"mars_core": 1, "voidstone": 8, "stardust": 6})
	_check(s.can_craft("void_lining"), "gated upgrade unlocked after Mars")
	_check(s.craft("void_lining"), "gated upgrade crafted")
	_eq(s.max_health(), GameStateData.BASE_MAX_HEALTH + 20, "health bonus applied")

# ---------------------------------------------------------------------------
# farming
# ---------------------------------------------------------------------------
func _test_crops() -> void:
	var s := GameStateData.new()
	var cell := Vector2i(2, -3)
	_check(s.till(cell), "soil tilled")
	_check(not s.till(cell), "tilling twice is a no-op")
	_check(s.plant(cell), "seed planted")
	_eq(s.crop_stage_at(cell), 0, "starts at stage 0")
	s.advance_crops(GameData.CROP_STAGE_SECONDS + 0.1)
	_eq(s.crop_stage_at(cell), 1, "advances one stage")
	_check(s.harvest(cell).is_empty(), "unripe harvest yields nothing")
	s.advance_crops(GameData.crop_total_seconds())
	_check(GameData.crop_is_ripe(s.crop_elapsed(cell)), "ripe after full growth")
	_eq(s.crop_stage_at(cell), GameData.CROP_STAGES - 1, "clamped to final stage")
	var seeds_before := s.count("emberseed")
	var yield_bundle := s.harvest(cell)
	_check(not yield_bundle.is_empty(), "ripe harvest yields items")
	_check(s.count("ember_bloom") >= 2, "blooms gained")
	_check(s.count("emberseed") > seeds_before, "seeds are renewable")
	_check(not s.has_crop(cell), "crop cleared after harvest")
	_check(s.is_tilled(cell), "soil stays tilled after harvest")

func _test_crop_rules() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	var cell := Vector2i(0, 0)
	_check(not s.plant(cell), "cannot plant on untilled soil")
	s.till(cell)
	_check(not s.plant(cell), "cannot plant without a seed")
	s.add_item("emberseed", 1)
	_check(s.plant(cell), "plants with a seed")
	_eq(s.count("emberseed"), 0, "seed consumed")
	s.add_item("emberseed", 1)
	_check(not s.plant(cell), "cannot stack two crops on one cell")
	_eq(s.count("emberseed"), 1, "seed not consumed by rejected planting")

# ---------------------------------------------------------------------------
# progression
# ---------------------------------------------------------------------------
func _test_progression() -> void:
	var s := GameStateData.new()
	_check(s.boss_unlocked("mars"), "Mars available from the start")
	_check(not s.boss_unlocked("saturn"), "Saturn locked before Mars")
	_check(not s.can_craft("ring_sigil"), "Ring Sigil locked before Mars")
	var reward := s.register_victory("mars")
	_check(not reward.is_empty(), "Mars grants a reward")
	_check(s.count("mars_core") >= 2, "Cinder Cores awarded")
	_check(s.boss_defeated("mars"), "Mars defeat recorded")
	_check(s.boss_unlocked("saturn"), "Saturn unlocked after Mars")
	_check(s.register_victory("nobody").is_empty(), "unknown boss grants nothing")

func _test_summoning() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	_check(not s.can_summon("mars"), "cannot summon without a sigil")
	_check(s.summon_blocker("mars").contains("Cinder Sigil"), "blocker names the sigil")
	s.add_item("cinder_sigil", 1)
	_check(s.can_summon("mars"), "summon allowed with a sigil")
	_check(s.consume_summon("mars"), "summon consumes the sigil")
	_eq(s.count("cinder_sigil"), 0, "sigil spent exactly once")
	_check(not s.consume_summon("mars"), "cannot summon twice on one sigil")
	s.add_item("ring_sigil", 1)
	_check(not s.can_summon("saturn"), "Saturn still sealed without Mars")

# ---------------------------------------------------------------------------
# persistence
# ---------------------------------------------------------------------------
func _test_save_roundtrip() -> void:
	var path := "user://test_roundtrip.json"
	var s := GameStateData.new()
	s.add_items({"stardust": 7, "voidstone": 2})
	s.set_flag("mars_defeated")
	s.upgrades["starforged_edge"] = true
	s.till(Vector2i(1, 1))
	s.add_item("emberseed", 1)
	s.plant(Vector2i(1, 1))
	s.advance_crops(GameData.CROP_STAGE_SECONDS)
	s.set_setting("screen_shake", 0.25)
	_check(SaveIO.save_state(s, path), "save written")
	var result := SaveIO.load_state(path)
	_check(result["ok"], "save loaded")
	var loaded: GameStateData = result["state"]
	_eq(loaded.count("stardust"), 7, "inventory restored")
	_check(loaded.has_flag("mars_defeated"), "flags restored")
	_check(loaded.has_upgrade("starforged_edge"), "upgrades restored")
	_check(loaded.is_tilled(Vector2i(1, 1)), "tilled soil restored")
	_eq(loaded.crop_stage_at(Vector2i(1, 1)), 1, "crop growth restored")
	_eq(loaded.get_setting("screen_shake"), 0.25, "settings restored")
	_eq(loaded.melee_damage(), GameStateData.BASE_DAMAGE + 10, "derived stats restored")
	SaveIO.delete_save(path)
	_check(not SaveIO.has_save(path), "save deleted")

func _test_save_corruption() -> void:
	var path := "user://test_corrupt.json"
	SaveIO.delete_save(path)
	SaveIO.delete_save(path.get_basename() + ".bak.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json ][")
	file.close()
	var result := SaveIO.load_state(path)
	_check(not result["ok"], "corrupt save reported")
	_eq(result["reason"], "corrupt", "corruption reason")
	var s: GameStateData = result["state"]
	_eq(s.max_health(), GameStateData.BASE_MAX_HEALTH, "defaults after corruption")
	_check(not s.has_flag("mars_defeated"), "no phantom progression")
	SaveIO.delete_save(path)

	var missing := SaveIO.load_state("user://test_does_not_exist.json")
	_check(not missing["ok"], "missing save reported")
	_eq(missing["reason"], "missing", "missing reason")
	_check(missing["state"] != null, "missing save still returns a usable state")

func _test_save_sanitising() -> void:
	var s := GameStateData.new()
	_check(not s.from_dict("not a dictionary"), "non-dictionary rejected")
	_check(not s.from_dict({"version": 999}), "future version rejected")
	_check(s.from_dict({
		"version": GameStateData.SAVE_VERSION,
		"inventory": {"stardust": -4, "bogus_item": 10, "voidstone": 3},
		"upgrades": {"not_a_real_upgrade": true, "starforged_edge": true},
		"flags": {"nonsense": true, "mars_defeated": true},
		"tilled": [[1, 2], "junk", [1, 2], [3]],
		"crops": [{"cell": [1, 2], "elapsed": 9999.0}, {"cell": [8, 8]}, "junk"],
		"settings": {"screen_shake": "loud", "reduced_flash": true},
		"play_seconds": "abc",
	}), "sanitised load accepted")
	_eq(s.count("stardust"), 0, "negative counts dropped")
	_eq(s.count("bogus_item"), 0, "unknown items dropped")
	_eq(s.count("voidstone"), 3, "valid counts kept")
	_check(not s.has_upgrade("not_a_real_upgrade"), "unknown upgrades dropped")
	_check(s.has_upgrade("starforged_edge"), "valid upgrade kept")
	_check(not s.has_flag("nonsense"), "unknown flags dropped")
	_check(s.has_flag("mars_defeated"), "valid flag kept")
	_eq(s.tilled.size(), 1, "malformed/duplicate cells dropped")
	_eq(s.crops.size(), 1, "crops without tilled soil dropped")
	_check(s.crop_elapsed(Vector2i(1, 2)) <= GameData.crop_total_seconds(), "crop time clamped")
	_eq(s.get_setting("screen_shake"), GameStateData.default_settings()["screen_shake"], "bad setting reset")
	_check(bool(s.get_setting("reduced_flash")), "valid setting kept")
	_eq(s.play_seconds, 0.0, "bad play time reset")

func _test_objectives() -> void:
	var s := GameStateData.new()
	s.inventory.clear()
	_check(GameData.current_objective(s).contains("Shrub"), "first objective is foraging")
	s.add_items({"cinder_sigil": 1})
	_check(GameData.current_objective(s).contains("altar"), "altar objective with a sigil")
	s.register_victory("mars")
	s.register_victory("saturn")
	_check(GameData.current_objective(s).contains("complete"), "chapter completion objective")

# ---------------------------------------------------------------------------
# encounters
# ---------------------------------------------------------------------------
func _test_phases() -> void:
	_eq(EncounterState.phase_for(1.0, [0.55]), 0, "full health is phase 0")
	_eq(EncounterState.phase_for(0.6, [0.55]), 0, "above threshold stays phase 0")
	_eq(EncounterState.phase_for(0.55, [0.55]), 1, "at threshold enters phase 1")
	_eq(EncounterState.phase_for(0.1, [0.7, 0.35]), 2, "multiple thresholds")
	_eq(EncounterState.phase_for(0.0, [0.5]), 1, "dead boss reports final phase")

func _test_encounter_lifecycle() -> void:
	var e := EncounterState.new()
	e.configure(500, [0.5])
	_eq(e.phase, 0, "starts in phase 0")
	_check(e.is_alive(), "starts alive")
	_check(not e.can_act(), "cannot act during the intro")
	e.begin_fight()
	_check(e.can_act(), "can act once the fight begins")
	_eq(e.damage(100), 100, "damage applied")
	_eq(e.health, 400, "health reduced")
	_eq(e.phase, 0, "still phase 0")
	var changed := e.damage(200)
	_eq(e.health, 200, "health reduced past threshold")
	_eq(e.phase, 1, "phase advanced")
	_check(e.consume_phase_change(), "phase change reported once")
	_check(not e.consume_phase_change(), "phase change not repeated")
	_check(changed > 0, "damage returned")
	_eq(e.damage(9999), 200, "overkill clamped to remaining health")
	_check(not e.is_alive(), "boss dies at zero")
	_check(not e.can_act(), "dead boss cannot act")
	_eq(e.damage(50), 0, "dead boss takes no further damage")
	_check(e.victory_pending, "victory pending after death")
	_check(e.consume_victory(), "victory consumed once")
	_check(not e.consume_victory(), "victory cannot be double-claimed")
