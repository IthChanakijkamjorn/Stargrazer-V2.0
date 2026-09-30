extends Node2D
class_name GroundRenderer
## Stargazer - GroundRenderer
## Draws the bounded astral clearing: textured indigo soil with per-cell
## variation, a glowing boundary where the ground falls away into the void,
## tilled plots, and every crop's growth stage.
##
## All variation is baked once from a fixed seed so the ground never shimmers
## and looks identical between sessions.

const TILE := 32

var map_w: int = 46
var map_h: int = 30
var seed_value: int = 20260930

var _shade: Dictionary = {}
var _detail: Dictionary = {}

func configure(p_w: int, p_h: int) -> void:
	map_w = p_w
	map_h = p_h
	_bake()
	queue_redraw()

func _ready() -> void:
	z_index = -50
	if _shade.is_empty():
		_bake()

func _bake() -> void:
	_shade.clear()
	_detail.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for x in range(-map_w / 2, map_w / 2):
		for y in range(-map_h / 2, map_h / 2):
			var cell := Vector2i(x, y)
			_shade[cell] = rng.randf()
			_detail[cell] = rng.randf()

## True when the cell is inside the playable clearing.
func in_bounds(cell: Vector2i) -> bool:
	return _shade.has(cell)

func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)

func world_rect() -> Rect2:
	return Rect2(
		-map_w / 2 * TILE, -map_h / 2 * TILE,
		map_w * TILE, map_h * TILE
	)

func _draw() -> void:
	var rect := world_rect()
	# Void beyond the clearing, with a soft rim of light at the edge.
	draw_rect(rect.grow(TILE * 3), Palette.VOID_DEEP)
	draw_rect(rect.grow(6), Color(Palette.VIOLET.r, Palette.VIOLET.g, Palette.VIOLET.b, 0.16))

	for cell in _shade.keys():
		_draw_cell(cell)

	_draw_crops()

func _draw_cell(cell: Vector2i) -> void:
	var s: float = _shade[cell]
	var d: float = _detail[cell]
	var rect := Rect2(cell.x * TILE, cell.y * TILE, TILE, TILE)
	var tilled: bool = GameState.data.is_tilled(cell)

	if tilled:
		draw_rect(rect, Palette.SOIL)
		for i in range(3):
			var y := rect.position.y + 7.0 + float(i) * 9.0
			draw_line(Vector2(rect.position.x + 2, y), Vector2(rect.end.x - 2, y), Palette.SOIL_DARK, 2.0)
		return

	var base := Palette.GROUND_A
	if s > 0.68:
		base = Palette.GROUND_B
	elif s < 0.32:
		base = Palette.GROUND_C
	draw_rect(rect, base)

	# Subtle dithered speckle so large areas never look flat.
	if d > 0.86:
		draw_rect(Rect2(rect.position + Vector2(6 + d * 12.0, 8 + s * 12.0), Vector2(2, 2)), Palette.GROUND_B.lightened(0.12))
	if d < 0.08:
		# Rare embedded starlight fleck.
		draw_circle(rect.get_center() + Vector2(s * 10.0 - 5.0, d * 60.0 - 3.0), 1.3, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.45))
	# Moss tufts.
	if s > 0.92:
		var bx := rect.position.x + 9.0 + d * 12.0
		var by := rect.position.y + 24.0
		draw_line(Vector2(bx, by), Vector2(bx - 2, by - 7), Color(0.26, 0.4, 0.46, 0.8), 1.4)
		draw_line(Vector2(bx + 4, by), Vector2(bx + 5, by - 6), Color(0.26, 0.4, 0.46, 0.6), 1.4)

func _draw_crops() -> void:
	for crop in GameState.data.crops:
		var raw = crop.get("cell", null)
		if typeof(raw) != TYPE_ARRAY or raw.size() != 2:
			continue
		var cell := Vector2i(int(raw[0]), int(raw[1]))
		var elapsed := float(crop.get("elapsed", 0.0))
		_draw_crop(cell_center(cell), GameData.crop_stage(elapsed), GameData.crop_is_ripe(elapsed))

## Four clearly distinct growth stages: sprout, shoot, budding, ripe.
func _draw_crop(center: Vector2, stage: int, ripe: bool) -> void:
	var base := center + Vector2(0, 8)
	match stage:
		0:
			draw_line(base, base + Vector2(0, -5), Color(0.4, 0.62, 0.5), 2.0)
			draw_circle(base + Vector2(0, -6), 2.0, Color(0.5, 0.75, 0.6))
		1:
			draw_line(base, base + Vector2(0, -11), Color(0.4, 0.62, 0.5), 2.2)
			draw_circle(base + Vector2(-4, -8), 3.0, Color(0.44, 0.68, 0.54))
			draw_circle(base + Vector2(4, -10), 3.0, Color(0.44, 0.68, 0.54))
		2:
			draw_line(base, base + Vector2(0, -16), Color(0.4, 0.62, 0.5), 2.4)
			draw_circle(base + Vector2(-5, -11), 3.6, Color(0.44, 0.68, 0.54))
			draw_circle(base + Vector2(5, -13), 3.6, Color(0.44, 0.68, 0.54))
			draw_circle(base + Vector2(0, -18), 3.4, Color(0.8, 0.5, 0.35))
		_:
			draw_line(base, base + Vector2(0, -18), Color(0.42, 0.64, 0.52), 2.6)
			draw_circle(base + Vector2(-6, -12), 3.8, Color(0.44, 0.68, 0.54))
			draw_circle(base + Vector2(6, -14), 3.8, Color(0.44, 0.68, 0.54))
			var head := base + Vector2(0, -22)
			Palette.draw_halo(self, head, 13.0, Color(Palette.EMBER.r, Palette.EMBER.g, Palette.EMBER.b, 0.32), 3)
			for i in range(5):
				var a := TAU * float(i) / 5.0 - PI * 0.5
				draw_circle(head + Vector2(cos(a), sin(a)) * 4.6, 3.2, Palette.EMBER)
			draw_circle(head, 3.0, Palette.GOLD)
	if ripe:
		# A small chevron marks harvestable crops from a distance.
		var tip := center + Vector2(0, -34)
		draw_colored_polygon(PackedVector2Array([
			tip, tip + Vector2(-5, -6), tip + Vector2(5, -6),
		]), Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.9))
