extends Node2D
## Stargazer - Starfield
## A code-drawn, twinkling, parallax starfield background.
## No art files needed. Add it as the first child of World so it sits behind everything.
## It follows the camera loosely to create a subtle depth/parallax effect.

@export var star_count: int = 220
@export var area: Vector2 = Vector2(3000, 2000)
@export var parallax: float = 0.15  ## 0 = fixed sky, 1 = moves with world.

var _stars: Array = []          # Each: {pos, size, base_alpha, phase, speed}
var _time: float = 0.0
var _camera: Camera2D = null

func _ready() -> void:
	# Draw behind everything else.
	z_index = -100
	_generate_stars()
	# Cache the player's camera for parallax (optional).
	await get_tree().process_frame
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0].has_node("Camera2D"):
		_camera = players[0].get_node("Camera2D")

func _generate_stars() -> void:
	_stars.clear()
	for i in range(star_count):
		_stars.append({
			"pos": Vector2(
				randf_range(-area.x * 0.5, area.x * 0.5),
				randf_range(-area.y * 0.5, area.y * 0.5)
			),
			"size": randf_range(0.6, 2.2),
			"base_alpha": randf_range(0.3, 1.0),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.8, 2.4),
		})

func _process(delta: float) -> void:
	_time += delta
	# Parallax: shift the whole field a little opposite to the camera.
	if _camera:
		global_position = _camera.get_screen_center_position() * (1.0 - parallax)
	queue_redraw()

func _draw() -> void:
	for s in _stars:
		# Twinkle by modulating alpha with a sine wave.
		var twinkle: float = 0.5 + 0.5 * sin(_time * s["speed"] + s["phase"])
		var a: float = s["base_alpha"] * (0.4 + 0.6 * twinkle)
		var col := Color(1, 1, 1, a)
		# A few stars get a faint cosmic tint.
		if s["size"] > 1.8:
			col = Color(0.7, 0.85, 1.0, a)
		draw_circle(s["pos"], s["size"], col)
