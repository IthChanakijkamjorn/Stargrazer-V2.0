extends Node2D
## Stargazer - World
## Owns the tile-based ground and handles "farming" (tilling soil).

@onready var ground: TileMapLayer = $Ground
@onready var hud_health: ProgressBar = $HUD/HealthBar
@onready var player: CharacterBody2D = $Player

# Tile atlas coordinates inside the generated TileSet.
const TILE_GRASS := Vector2i(0, 0)
const TILE_SOIL := Vector2i(1, 0)
const SOURCE_ID := 0

func _ready() -> void:
	_generate_ground(40, 24)
	player.health_changed.connect(_on_player_health_changed)
	hud_health.max_value = player.max_health
	hud_health.value = player.health

func _generate_ground(width: int, height: int) -> void:
	# Fill a rectangle of grass tiles centered on the origin.
	for x in range(-width / 2, width / 2):
		for y in range(-height / 2, height / 2):
			ground.set_cell(Vector2i(x, y), SOURCE_ID, TILE_GRASS)

func till_soil_at(world_pos: Vector2) -> void:
	# Convert a world position to a tile cell and turn it into soil.
	var cell := ground.local_to_map(ground.to_local(world_pos))
	ground.set_cell(cell, SOURCE_ID, TILE_SOIL)

func _on_player_health_changed(current: int, _maximum: int) -> void:
	hud_health.value = current
