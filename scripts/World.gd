extends Node2D
## Stargazer - World
## Owns a code-drawn textured ground (no TileSet), a starfield background,
## scattered props, and handles "farming" (tilling soil) by recoloring cells.

@onready var hud_health: ProgressBar = $HUD/HealthBar
@onready var player: CharacterBody2D = $Player
@onready var ground: Node2D = $Ground
@onready var props: Node2D = $Props

const TILE := 32                 # Pixel size of one ground cell.
const MAP_W := 40
const MAP_H := 24

# Tilled cells (in cell coordinates) get drawn as dark soil.
var _tilled: Dictionary = {}
# Cached per-cell grass shade so the ground doesn't shimmer each frame.
var _grass_seed: Dictionary = {}

func _ready() -> void:
	randomize()
	_bake_ground_shades()
	ground.draw.connect(_draw_ground)
	ground.queue_redraw()
	_scatter_props()

	player.health_changed.connect(_on_player_health_changed)
	hud_health.max_value = player.max_health
	hud_health.value = player.health

func _bake_ground_shades() -> void:
	for x in range(-MAP_W / 2, MAP_W / 2):
		for y in range(-MAP_H / 2, MAP_H / 2):
			_grass_seed[Vector2i(x, y)] = randf()

# --- Ground drawing -------------------------------------------------------

func _draw_ground() -> void:
	var grass_a := Color(0.18, 0.42, 0.26)
	var grass_b := Color(0.22, 0.48, 0.3)
	var grass_c := Color(0.16, 0.38, 0.24)
	var soil := Color(0.33, 0.22, 0.14)
	var soil_dark := Color(0.27, 0.18, 0.11)

	for x in range(-MAP_W / 2, MAP_W / 2):
		for y in range(-MAP_H / 2, MAP_H / 2):
			var cell := Vector2i(x, y)
			var rect := Rect2(x * TILE, y * TILE, TILE, TILE)
			if _tilled.has(cell):
				ground.draw_rect(rect, soil)
				# Furrow lines for tilled soil.
				ground.draw_line(Vector2(rect.position.x, rect.position.y + 10), Vector2(rect.end.x, rect.position.y + 10), soil_dark, 2.0)
				ground.draw_line(Vector2(rect.position.x, rect.position.y + 22), Vector2(rect.end.x, rect.position.y + 22), soil_dark, 2.0)
			else:
				var s: float = _grass_seed.get(cell, 0.5)
				var col := grass_a
				if s > 0.66:
					col = grass_b
				elif s < 0.33:
					col = grass_c
				ground.draw_rect(rect, col)
				# A few blades for texture on some tiles.
				if s > 0.8:
					var bx := rect.position.x + 8 + s * 10.0
					var by := rect.position.y + 20
					ground.draw_line(Vector2(bx, by), Vector2(bx - 2, by - 7), grass_b, 1.5)
					ground.draw_line(Vector2(bx + 4, by), Vector2(bx + 5, by - 6), grass_b, 1.5)

# --- Props ----------------------------------------------------------------

func _scatter_props() -> void:
	var kinds := [Prop.Kind.ROCK, Prop.Kind.TREE, Prop.Kind.BUSH, Prop.Kind.FLOWER, Prop.Kind.CRYSTAL]
	var count := 46
	for i in range(count):
		var cx := randi_range(-MAP_W / 2 + 1, MAP_W / 2 - 2)
		var cy := randi_range(-MAP_H / 2 + 1, MAP_H / 2 - 2)
		var pos := Vector2(cx * TILE + TILE / 2, cy * TILE + TILE / 2)
		# Keep a clear spawn area around the origin (where the player starts).
		if pos.length() < 90.0:
			continue
		var p := Prop.make(kinds[randi() % kinds.size()])
		p.position = pos
		# Sort by Y so lower props overlap higher ones (fake depth).
		p.z_index = int(pos.y)
		props.add_child(p)

func till_soil_at(world_pos: Vector2) -> void:
	var cell := Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))
	_tilled[cell] = true
	ground.queue_redraw()

func _on_player_health_changed(current: int, _maximum: int) -> void:
	hud_health.value = current
