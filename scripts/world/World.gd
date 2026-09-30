extends Node2D
class_name World
## Stargazer - World
## The hub chapter: a bounded astral clearing with a safe spawn, renewable
## resource nodes, farmable soil and the summoning altar. Keeps itself small
## by delegating drawing to GroundRenderer, UI to the HUD/panels and boss
## logic to the arena scene.

const MAP_W := 46
const MAP_H := 30
const SAFE_RADIUS := 110.0

@onready var ground: GroundRenderer = $Ground
@onready var props: Node2D = $Props
@onready var player: Player = $Player
@onready var altar: Altar = $Altar
@onready var hud: HUD = $HUD

var _bounds: Rect2

func _ready() -> void:
	randomize()
	ground.configure(MAP_W, MAP_H)
	_bounds = ground.world_rect().grow(-18.0)
	_populate()

	altar.requested_open.connect(_on_altar_used)
	player.health_changed.connect(hud.set_health)
	player.dash_changed.connect(hud.set_dash)
	player.died.connect(_on_player_died)
	GameState.inventory_changed.connect(_on_inventory_changed)
	GameState.progression_changed.connect(_refresh_objective)

	hud.bind_player(player)
	hud.summon_requested.connect(_on_summon_requested)
	_refresh_objective()
	_report_encounter_result()
	GameState.save_game()

func _process(_delta: float) -> void:
	_clamp_player()
	hud.set_prompt(_current_prompt())
	if GameState.consume_crop_tick():
		ground.queue_redraw()

func _clamp_player() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.global_position = player.global_position.clamp(_bounds.position, _bounds.end)

# ---------------------------------------------------------------------------
# WORLD BUILDING
# ---------------------------------------------------------------------------
func _populate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var placed: Array = []

	# Renewable resource nodes, spread evenly so no run can dead-end.
	var plan := [
		{"kind": "crystal", "count": 12},
		{"kind": "rock", "count": 12},
		{"kind": "shrub", "count": 10},
	]
	for entry in plan:
		var made := 0
		var attempts := 0
		while made < int(entry["count"]) and attempts < 400:
			attempts += 1
			var pos := _random_spot(rng)
			if not _is_free(pos, placed, 60.0):
				continue
			var node := ResourceNode.make(String(entry["kind"]), rng.randf())
			node.position = pos
			props.add_child(node)
			node.z_index = int(pos.y)
			placed.append(pos)
			made += 1

	# Decorative scenery.
	var kinds := [Prop.Kind.SPIRE, Prop.Kind.SHARD, Prop.Kind.MOSS, Prop.Kind.BLOOM, Prop.Kind.MONOLITH]
	for i in range(58):
		var pos := _random_spot(rng)
		if not _is_free(pos, placed, 34.0):
			continue
		var p := Prop.make(kinds[rng.randi() % kinds.size()], rng.randf())
		p.position = pos
		props.add_child(p)
		p.z_index = int(pos.y)
		placed.append(pos)

func _random_spot(rng: RandomNumberGenerator) -> Vector2:
	var cx := rng.randi_range(-MAP_W / 2 + 2, MAP_W / 2 - 3)
	var cy := rng.randi_range(-MAP_H / 2 + 2, MAP_H / 2 - 3)
	return ground.cell_center(Vector2i(cx, cy))

## Keeps the spawn plaza and the altar clear, and stops props overlapping.
func _is_free(pos: Vector2, placed: Array, spacing: float) -> bool:
	if pos.length() < SAFE_RADIUS:
		return false
	if pos.distance_to(altar.position) < 130.0:
		return false
	for other in placed:
		if pos.distance_to(other) < spacing:
			return false
	return true

# ---------------------------------------------------------------------------
# INTERACTION
# ---------------------------------------------------------------------------
## Called by the player when nothing interactable is in range: till, plant or
## harvest the ground cell underneath.
func interact_ground(from: Node) -> void:
	if not (from is Node2D):
		return
	var cell := ground.cell_at((from as Node2D).global_position)
	if not ground.in_bounds(cell):
		GameState.show_notice("The void will not hold a seed.", Palette.TEXT_DIM)
		return
	var state := GameState.data

	if state.has_crop(cell):
		var bundle := state.harvest(cell)
		if bundle.is_empty():
			var left := GameData.crop_total_seconds() - state.crop_elapsed(cell)
			GameState.show_notice("Still growing (%ds left)." % int(ceil(left)), Palette.TEXT_DIM)
			return
		GameState.inventory_changed.emit()
		var parts: Array = []
		for id in bundle.keys():
			parts.append("+%d %s" % [int(bundle[id]), GameData.item_name(String(id))])
		GameState.show_notice(", ".join(parts), Palette.EMBER)
		ImpactFX.burst(self, ground.cell_center(cell), Palette.EMBER, 44.0, 0.35)
		ground.queue_redraw()
		GameState.save_game()
		return

	if state.is_tilled(cell):
		if state.plant(cell):
			GameState.inventory_changed.emit()
			GameState.show_notice("Planted an Emberseed.", Palette.EMBER)
			ImpactFX.burst(self, ground.cell_center(cell), Palette.CYAN, 30.0, 0.3)
			ground.queue_redraw()
			GameState.save_game()
		else:
			GameState.show_notice("No Emberseeds. Harvest a shrub first.", Palette.DANGER)
		return

	if state.till(cell):
		GameState.show_notice("Soil tilled. Press E again to plant.", Palette.TEXT)
		ImpactFX.burst(self, ground.cell_center(cell), Palette.VIOLET, 26.0, 0.25)
		ground.queue_redraw()
		GameState.save_game()

func _current_prompt() -> String:
	if player == null or not is_instance_valid(player):
		return ""
	var target := player.nearest_interactable()
	if target != null and target.has_method("interact_prompt"):
		return target.interact_prompt()
	var cell := ground.cell_at(player.global_position)
	if not ground.in_bounds(cell):
		return ""
	var state := GameState.data
	if state.has_crop(cell):
		if GameData.crop_is_ripe(state.crop_elapsed(cell)):
			return "E  Harvest Ember Bloom"
		return "Growing... (%d/%d)" % [state.crop_stage_at(cell) + 1, GameData.CROP_STAGES]
	if state.is_tilled(cell):
		return "E  Plant Emberseed (%d)" % state.count("emberseed")
	return "E  Till soil"

# ---------------------------------------------------------------------------
# ENCOUNTERS
# ---------------------------------------------------------------------------
func _on_altar_used() -> void:
	hud.open_summon_panel()

func _on_summon_requested(boss_id: String) -> void:
	if not GameState.begin_encounter(boss_id):
		GameState.show_notice(GameState.data.summon_blocker(boss_id), Palette.DANGER)
		return
	get_tree().change_scene_to_file("res://scenes/BossArena.tscn")

## Shows the outcome of the fight the player just came back from.
func _report_encounter_result() -> void:
	var result := GameState.last_result
	GameState.last_result = {}
	if result.is_empty():
		return
	if bool(result.get("victory", false)):
		hud.show_banner("%s defeated!" % String(result.get("boss_name", "The boss")), Palette.GOLD)
	else:
		hud.show_banner("You fell to %s. Prepare and try again." % String(result.get("boss_name", "the boss")), Palette.DANGER)

func _on_inventory_changed() -> void:
	_refresh_objective()

func _refresh_objective() -> void:
	hud.set_objective(GameState.objective_text())
	if player and is_instance_valid(player):
		player.refresh_stats()

func _on_player_died() -> void:
	# The hub has no hazards, but a death here should still be recoverable.
	hud.show_banner("You collapsed. Recovering...", Palette.DANGER)
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(player):
		return
	player.global_position = Vector2.ZERO
	player.state = Player.State.IDLE
	player.control_enabled = true
	player.refresh_stats(true)
	if player.visual and player.visual.has_method("revive"):
		player.visual.revive()
