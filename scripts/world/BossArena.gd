extends Node2D
class_name BossArena
## Stargazer - Boss arena
## A self-contained encounter scene. It reads the queued boss from GameState,
## builds a bounded circular arena, plays the (skippable) introduction and
## owns the whole lifecycle: victory, death, retry and the trip home. Because
## the arena is its own scene, leaving it guarantees no projectile, telegraph
## or timer leaks back into the hub.

const ARENA_RADIUS := 470.0
const PLAYER_SCENE := "res://scenes/Player.tscn"

@onready var floor_node: ArenaFloor = $Floor
@onready var entities: Node2D = $Entities

var boss_id: String = ""
var definition: Dictionary = {}
var boss: BossBase = null
var player: Player = null
var hud: BossHUD = null

var _resolved: bool = false
var _pause_menu: PauseMenu = null

func _ready() -> void:
	boss_id = GameState.take_pending_boss()
	definition = GameData.get_boss(boss_id)
	if definition.is_empty():
		# Nothing queued (for example a direct scene launch): go home safely.
		call_deferred("_return_to_world")
		return

	var stars := Starfield.new()
	add_child(stars)

	floor_node.configure(ARENA_RADIUS, definition.get("accent", Palette.GOLD))

	hud = BossHUD.new()
	add_child(hud)

	_spawn_player()
	_spawn_boss()
	_start_intro()

func _spawn_player() -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.position = Vector2(0, ARENA_RADIUS * 0.55)
	player.arena_center = Vector2.ZERO
	player.arena_radius = ARENA_RADIUS - 26.0
	player.control_enabled = false
	entities.add_child(player)
	player.died.connect(_on_player_died)
	hud.bind_player(player)

func _spawn_boss() -> void:
	var packed := load(String(definition["scene"])) as PackedScene
	boss = packed.instantiate()
	boss.position = Vector2(0, -ARENA_RADIUS * 0.35)
	boss.arena_center = Vector2.ZERO
	boss.arena_radius = ARENA_RADIUS - 40.0
	boss.player = player
	entities.add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	hud.bind_boss(boss, definition)

func _start_intro() -> void:
	var intro := BossIntro.new(definition)
	add_child(intro)
	intro.finished.connect(_begin_fight)

func _begin_fight() -> void:
	if _resolved or boss == null or not is_instance_valid(boss):
		return
	player.control_enabled = true
	boss.begin_fight()
	hud.show_banner("PHASE 1", definition.get("accent", Palette.GOLD))

# ---------------------------------------------------------------------------
# RESOLUTION
# ---------------------------------------------------------------------------
func _on_boss_defeated() -> void:
	if _resolved:
		return
	_resolved = true
	player.control_enabled = false
	var reward := GameState.register_victory(boss_id)
	GameState.save_game()

	var lines: Array = ["The %s is undone." % String(definition.get("name", "boss"))]
	for id in reward.keys():
		lines.append("+%d %s" % [int(reward[id]), GameData.item_name(String(id))])
	if boss_id == "mars":
		lines.append("The altar now answers to Saturn.")
	await get_tree().create_timer(1.6).timeout
	_show_result(true, "VICTORY", lines)

func _on_player_died() -> void:
	if _resolved:
		return
	_resolved = true
	_cleanup_encounter()
	await get_tree().create_timer(1.2).timeout
	_show_result(false, "YOU FELL", [
		"%s remains." % String(definition.get("name", "The boss")),
		"Your materials were spent on the summoning.",
	])

## Stops the fight dead: frees every hazard and halts the boss so nothing
## keeps ticking behind the overlay.
func _cleanup_encounter() -> void:
	if boss != null and is_instance_valid(boss):
		boss.clear_hazards()
		boss.set_physics_process(false)
	else:
		for node in get_tree().get_nodes_in_group("projectile"):
			node.queue_free()
		for node in get_tree().get_nodes_in_group("telegraph"):
			node.queue_free()

func _show_result(victory: bool, heading: String, lines: Array) -> void:
	_cleanup_encounter()
	GameState.last_result = {
		"boss_id": boss_id,
		"boss_name": String(definition.get("name", "the boss")),
		"victory": victory,
	}
	var overlay := ResultOverlay.new(victory, heading, lines, definition.get("accent", Palette.GOLD))
	add_child(overlay)
	overlay.retry_pressed.connect(_on_retry)
	overlay.leave_pressed.connect(_return_to_world)
	get_tree().paused = true

## A retry costs another sigil, exactly like summoning from the altar. If the
## player cannot pay, they are sent home to gather instead of being stranded.
func _on_retry() -> void:
	get_tree().paused = false
	if GameState.begin_encounter(boss_id):
		get_tree().change_scene_to_file("res://scenes/BossArena.tscn")
	else:
		GameState.show_notice(GameState.data.summon_blocker(boss_id), Palette.DANGER)
		_return_to_world()

func _return_to_world() -> void:
	get_tree().paused = false
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/World.tscn")

# ---------------------------------------------------------------------------
# PAUSE
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or _resolved:
		return
	get_viewport().set_input_as_handled()
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_close_pause()
		return
	_pause_menu = PauseMenu.new()
	var layer := CanvasLayer.new()
	layer.layer = 22
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_pause_menu)
	add_child(layer)
	_pause_menu.resumed.connect(_close_pause)
	_pause_menu.quit_to_title.connect(_quit_to_title)
	get_tree().paused = true

func _close_pause() -> void:
	if _pause_menu != null and is_instance_valid(_pause_menu):
		_pause_menu.get_parent().queue_free()
	_pause_menu = null
	get_tree().paused = false

func _quit_to_title() -> void:
	_cleanup_encounter()
	_close_pause()
	GameState.last_result = {}
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
