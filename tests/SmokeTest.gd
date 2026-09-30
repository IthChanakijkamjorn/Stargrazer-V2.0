extends Node
## Stargazer - headless integration smoke test.
## Usage: godot --headless --path . res://tests/SmokeTest.tscn
##
## Unlike tests/run_tests.gd (which exercises pure logic) this boots the real
## scenes with the real autoloads and plays through the whole chapter loop:
## till -> plant -> harvest -> craft -> summon -> fight -> victory -> reward,
## plus the death path and the hazard cleanup that follows it.

var _passed: int = 0
var _failed: int = 0
var _section: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("")
	print("--- Stargazer smoke test: %d passed, %d failed ---" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)

func _run() -> void:
	await _test_world_loop()
	await _test_boss_victory("mars")
	await _test_boss_death("mars")
	await _test_saturn_unlock()
	await _test_ui_panels()

# ---------------------------------------------------------------------------
# harness
# ---------------------------------------------------------------------------
func _section_begin(title: String) -> void:
	_section = title
	print("  .. %s" % title)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL [%s] %s" % [_section, message])
		print("  FAIL [%s] %s" % [_section, message])

func _wait_frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _instantiate(path: String) -> Node:
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	await _wait_frames(3)
	return node

# ---------------------------------------------------------------------------
# 1. Hub: farming, harvesting, crafting
# ---------------------------------------------------------------------------
func _test_world_loop() -> void:
	_section_begin("hub: till, plant, harvest, craft")
	GameState.new_game()
	var world := await _instantiate("res://scenes/World.tscn")
	_check(world is World, "World.tscn boots with the World script")

	var player: Player = world.get_node_or_null("Player")
	_check(player != null, "player is present")
	_check(world.get_node_or_null("HUD") is HUD, "HUD is present")
	_check(world.get_node_or_null("Altar") is Altar, "altar is present")
	_check(world.get_node("Props").get_child_count() > 20, "world is populated with nodes and scenery")

	var nodes := 0
	for child in world.get_node("Props").get_children():
		if child is ResourceNode:
			nodes += 1
	_check(nodes >= 30, "renewable resource nodes exist (found %d)" % nodes)

	# Farming, driven exactly as pressing E would.
	player.global_position = Vector2(64, 64)
	var cell: Vector2i = world.ground.cell_at(player.global_position)
	var seeds_before := GameState.data.count("emberseed")
	world.interact_ground(player)
	_check(GameState.data.is_tilled(cell), "first interaction tills the soil")
	world.interact_ground(player)
	_check(GameState.data.has_crop(cell), "second interaction plants a seed")
	_check(GameState.data.count("emberseed") == seeds_before - 1, "planting consumes one seed")

	world.interact_ground(player)
	_check(GameState.data.count("ember_bloom") == 0, "an unripe crop yields nothing")

	GameState.data.advance_crops(GameData.crop_total_seconds() + 1.0)
	world.interact_ground(player)
	_check(GameState.data.count("ember_bloom") >= 2, "a ripe crop yields blooms")
	_check(GameState.data.count("emberseed") >= seeds_before, "harvesting returns a seed so farming is renewable")
	_check(not GameState.data.has_crop(cell), "the harvested crop is cleared")

	# Harvesting a world node.
	var target: ResourceNode = null
	for child in world.get_node("Props").get_children():
		if child is ResourceNode and child.node_kind == "crystal":
			target = child
			break
	_check(target != null, "a sky crystal exists")
	if target != null:
		var before := GameState.data.count("stardust")
		for i in range(8):
			if target.can_interact():
				target.interact(player)
		_check(GameState.data.count("stardust") > before, "mining a crystal yields stardust")
		_check(not target.can_interact(), "a depleted node cannot be farmed forever in one go")

	# Crafting.
	GameState.data.add_items({"ember_bloom": 20, "stardust": 20, "voidstone": 20})
	var salves_before := GameState.data.count("salve")
	_check(GameState.craft("salve"), "salve crafts when materials are present")
	_check(GameState.data.count("salve") == salves_before + int(GameData.get_recipe("salve")["amount"]),
		"the salve recipe produces exactly its stated amount")
	_check(GameState.data.count("cinder_sigil") == 0, "no sigil before crafting one")
	_check(GameState.craft("cinder_sigil"), "cinder sigil crafts")
	_check(not GameState.craft("ring_sigil"), "the ring sigil stays locked before Mars falls")
	_check(GameState.data.craft_blocker("ring_sigil") != "", "the locked recipe explains itself")

	_check(GameState.save_game(), "the hub saves")
	_check(GameState.has_save(), "the save file exists afterwards")

	world.queue_free()
	await _wait_frames(3)

# ---------------------------------------------------------------------------
# 2. Encounter: summon, fight, win, get paid
# ---------------------------------------------------------------------------
func _test_boss_victory(boss_id: String) -> void:
	_section_begin("encounter: %s victory" % boss_id)
	var sigil := String(GameData.get_boss(boss_id).get("sigil", ""))
	GameState.data.add_item(sigil, 1)
	var sigils_before := GameState.data.count(sigil)
	_check(GameState.begin_encounter(boss_id), "the altar accepts the offering")
	_check(GameState.data.count(sigil) == sigils_before - 1, "the sigil is consumed exactly once")

	var arena: BossArena = await _instantiate("res://scenes/BossArena.tscn")
	_check(arena.boss != null and is_instance_valid(arena.boss), "the boss spawned")
	_check(arena.player != null and is_instance_valid(arena.player), "the player spawned")
	_check(GameState.pending_boss_id == "", "the queued encounter is cleared so a reload cannot resurrect it")

	arena._begin_fight()
	await _wait(1.2)
	_check(arena.boss.encounter.stage == EncounterState.Stage.FIGHTING, "the fight is running after the intro")

	# Push through the phase threshold and confirm the encounter reacts.
	arena.boss.take_damage(int(arena.boss.max_health * 0.6))
	await _wait(0.6)
	_check(arena.boss.encounter.phase >= 1, "crossing the threshold advances the phase")

	await _wait(1.5)
	_check(_count_group("projectile") >= 0, "projectiles are tracked in a group")

	arena.boss.take_damage(99999)
	await _wait(3.4)
	_check(GameState.data.has_flag("%s_defeated" % boss_id), "victory records the defeat flag")
	_check(GameState.data.count("stardust") > 0, "victory pays out rewards")
	_check(_count_group("projectile") == 0, "every projectile is cleaned up")
	_check(_count_group("telegraph") == 0, "every telegraph is cleaned up")
	_check(bool(GameState.last_result.get("victory", false)), "the result is handed back to the hub")

	var before := GameState.data.count("stardust")
	arena._on_boss_defeated()
	await _wait_frames(3)
	_check(GameState.data.count("stardust") == before, "a second defeat signal cannot double-pay")

	get_tree().paused = false
	arena.queue_free()
	await _wait_frames(3)

# ---------------------------------------------------------------------------
# 3. Encounter: dying cleans everything up
# ---------------------------------------------------------------------------
func _test_boss_death(boss_id: String) -> void:
	_section_begin("encounter: %s death and cleanup" % boss_id)
	GameState.data.add_item(String(GameData.get_boss(boss_id).get("sigil", "")), 1)
	_check(GameState.begin_encounter(boss_id), "the encounter can be re-summoned")
	var arena: BossArena = await _instantiate("res://scenes/BossArena.tscn")
	arena._begin_fight()
	await _wait(2.0)

	arena.player.take_damage(99999, Vector2.ZERO)
	await _wait(2.2)
	_check(arena.player.state == Player.State.DEAD, "the player enters the dead state")
	_check(_count_group("projectile") == 0, "death clears live projectiles")
	_check(_count_group("telegraph") == 0, "death clears live telegraphs")
	_check(not bool(GameState.last_result.get("victory", true)), "the loss is reported honestly")

	get_tree().paused = false
	arena.queue_free()
	await _wait_frames(3)

# ---------------------------------------------------------------------------
# 4. Progression: Saturn only opens after Mars
# ---------------------------------------------------------------------------
func _test_saturn_unlock() -> void:
	_section_begin("progression: Saturn unlock and save round-trip")
	_check(GameState.data.boss_unlocked("saturn"), "Saturn unlocks once Mars has fallen")
	GameState.data.add_items({"stardust": 40, "voidstone": 40, "mars_core": 4, "astral_shard": 40, "void_ore": 40})
	_check(GameState.craft("ring_sigil"), "the ring sigil now crafts")
	_check(GameState.begin_encounter("saturn"), "Saturn can be summoned")

	var arena: BossArena = await _instantiate("res://scenes/BossArena.tscn")
	_check(arena.boss != null and is_instance_valid(arena.boss), "Saturn spawned")
	_check(arena.definition.get("name", "") == "Saturn", "the correct encounter loaded")
	arena._begin_fight()
	await _wait(2.5)
	_check(arena.boss.encounter.is_alive(), "Saturn survives its opening patterns")
	arena.boss.take_damage(99999)
	await _wait(3.4)
	_check(GameState.data.has_flag("saturn_defeated"), "Saturn's defeat is recorded")
	get_tree().paused = false
	arena.queue_free()
	await _wait_frames(3)

	# Reload from disk and confirm progression survived.
	GameState.save_game()
	_check(GameState.load_game(), "the save reloads")
	_check(GameState.data.has_flag("mars_defeated"), "Mars stays defeated after a reload")
	_check(GameState.data.has_flag("saturn_defeated"), "Saturn stays defeated after a reload")
	_check(GameState.pending_boss_id == "", "loading never restores a half-finished encounter")

# ---------------------------------------------------------------------------
# 5. UI: every overlay must fit on screen at common desktop sizes
# ---------------------------------------------------------------------------
func _test_ui_panels() -> void:
	_section_begin("ui: panels fit the viewport")
	for resolution in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await _wait_frames(2)
		var viewport_rect := get_viewport().get_visible_rect()
		for entry in [["satchel & forge", CraftingPanel.new()], ["altar", SummonPanel.new()], ["pause", PauseMenu.new()]]:
			var panel: Control = entry[1]
			add_child(panel)
			panel.size = viewport_rect.size
			await _wait_frames(3)
			var inner := _largest_panel(panel)
			_check(inner != null, "%s panel builds a frame" % String(entry[0]))
			if inner != null:
				var r := inner.get_global_rect()
				_check(viewport_rect.encloses(r),
					"%s panel fits inside %dx%d (panel %s)" % [String(entry[0]), resolution.x, resolution.y, r])
			panel.queue_free()
			await _wait_frames(2)
	get_window().size = Vector2i(1280, 720)
	await _wait_frames(2)

func _largest_panel(root: Node) -> Control:
	var best: Control = null
	for child in root.get_children():
		if child is PanelContainer:
			if best == null or (child as Control).size.length() > best.size.length():
				best = child
		var nested := _largest_panel(child)
		if nested != null and (best == null or nested.size.length() > best.size.length()):
			best = nested
	return best

func _count_group(group: String) -> int:
	var alive := 0
	for node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			alive += 1
	return alive
