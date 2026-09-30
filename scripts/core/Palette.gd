extends RefCounted
class_name Palette
## Stargazer - Palette
## The single source of truth for the game's cosmic visual identity:
## deep indigo/violet environments with restrained cyan and gold highlights.
## Every drawing script pulls from here so the look stays coherent.

# Environment
const VOID := Color(0.043, 0.047, 0.11)
const VOID_DEEP := Color(0.027, 0.03, 0.078)
const GROUND_A := Color(0.13, 0.12, 0.24)
const GROUND_B := Color(0.16, 0.14, 0.29)
const GROUND_C := Color(0.10, 0.10, 0.20)
const GROUND_EDGE := Color(0.08, 0.08, 0.17)
const SOIL := Color(0.20, 0.14, 0.24)
const SOIL_DARK := Color(0.14, 0.10, 0.18)
const SHADOW := Color(0.0, 0.0, 0.05, 0.32)

# Highlights
const CYAN := Color(0.45, 0.88, 1.0)
const CYAN_DIM := Color(0.28, 0.6, 0.78)
const GOLD := Color(1.0, 0.84, 0.46)
const GOLD_DIM := Color(0.72, 0.58, 0.3)
const VIOLET := Color(0.56, 0.42, 0.92)
const EMBER := Color(1.0, 0.45, 0.26)
const EMBER_DARK := Color(0.6, 0.18, 0.14)

# Feedback
const DANGER := Color(1.0, 0.32, 0.3)
const TELEGRAPH := Color(1.0, 0.36, 0.28, 0.32)
const TELEGRAPH_EDGE := Color(1.0, 0.62, 0.4, 0.9)
const HEAL := Color(0.45, 1.0, 0.68)

# UI
const PANEL_BG := Color(0.07, 0.07, 0.15, 0.94)
const PANEL_EDGE := Color(0.42, 0.38, 0.7, 0.9)
const TEXT := Color(0.9, 0.93, 1.0)
const TEXT_DIM := Color(0.62, 0.64, 0.78)

## A soft additive-looking halo drawn as stacked translucent circles.
## Compatibility-renderer safe: no shaders, no WorldEnvironment glow.
static func draw_halo(canvas: CanvasItem, center: Vector2, radius: float, color: Color, layers: int = 4) -> void:
	for i in range(layers, 0, -1):
		var t := float(i) / float(layers)
		var c := color
		c.a = color.a * (1.0 - t) * 0.9 + 0.04
		canvas.draw_circle(center, radius * t, c)

## Builds a rounded-corner panel StyleBox in the cosmic palette.
static func panel_style(bg: Color = PANEL_BG, edge: Color = PANEL_EDGE, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(14)
	return sb

static func button_style(bg: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb
