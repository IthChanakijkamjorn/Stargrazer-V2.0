extends Control
class_name TitleEmblem
## Stargazer - Title emblem
## A slowly rotating ringed world drawn behind the menu. Purely decorative,
## but it establishes the palette and the "ringbound" motif immediately.

var _time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * Vector2(0.5, 0.42)
	var r := minf(size.x, size.y) * 0.22

	Palette.draw_halo(self, center, r * 3.0, Color(Palette.VIOLET.r, Palette.VIOLET.g, Palette.VIOLET.b, 0.10), 5)

	# Back half of the ring.
	_draw_ring(center, r, false)
	draw_circle(center, r, Color(0.16, 0.14, 0.3, 0.92))
	draw_circle(center - Vector2(r * 0.18, r * 0.2), r * 0.8, Color(0.24, 0.2, 0.42, 0.9))
	for i in range(4):
		var y := center.y - r * 0.5 + float(i) * r * 0.33
		var half := sqrt(maxf(r * r - pow(y - center.y, 2.0), 0.0)) * 0.9
		draw_line(Vector2(center.x - half, y), Vector2(center.x + half, y), Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.12), r * 0.12)
	_draw_ring(center, r, true)

	# A handful of orbiting motes.
	for i in range(5):
		var a := _time * 0.35 + TAU * float(i) / 5.0
		var p := center + Vector2(cos(a) * r * 2.6, sin(a) * r * 0.7)
		draw_circle(p, 2.5, Color(Palette.CYAN.r, Palette.CYAN.g, Palette.CYAN.b, 0.7))

func _draw_ring(center: Vector2, r: float, front: bool) -> void:
	var tilt := 0.26 + sin(_time * 0.2) * 0.04
	for band in range(3):
		var rr := r * (1.55 + float(band) * 0.28)
		var pts := PackedVector2Array()
		for i in range(65):
			var a := TAU * float(i) / 64.0
			var sy := sin(a)
			if front and sy < 0.0:
				continue
			if not front and sy > 0.0:
				continue
			pts.append(center + Vector2(cos(a) * rr, sy * rr * tilt))
		if pts.size() < 2:
			continue
		var col := Palette.GOLD if band == 0 else (Palette.VIOLET if band == 1 else Palette.CYAN_DIM)
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.5 - float(band) * 0.12), 5.0 - float(band), true)
