extends RefCounted
class_name UIKit
## Stargazer - UIKit
## Small helpers for building the game's interface in code with a consistent
## cosmic look: readable fonts, high-contrast text, rounded panels and buttons
## that respond to focus as well as the mouse (so menus stay keyboard usable).

static func label(text: String, size: int = 16, color: Color = Palette.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 4)
	l.clip_text = true
	return l

## A label that wraps inside a fixed width. Autowrap is opt-in because an
## unconstrained wrapping label inflates its container's minimum height.
static func wrapped(text: String, width: float, size: int = 14, color: Color = Palette.TEXT_DIM) -> Label:
	var l := label(text, size, color)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size_flags_horizontal = Control.SIZE_FILL
	return l

static func title(text: String, size: int = 34, color: Color = Palette.GOLD) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, accent: Color = Palette.CYAN) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Palette.TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM)
	b.add_theme_stylebox_override("normal", Palette.button_style(Color(0.12, 0.12, 0.24, 0.95), Color(accent.r, accent.g, accent.b, 0.55)))
	b.add_theme_stylebox_override("hover", Palette.button_style(Color(0.18, 0.19, 0.34, 0.98), accent))
	b.add_theme_stylebox_override("pressed", Palette.button_style(Color(0.08, 0.08, 0.18, 1.0), accent))
	b.add_theme_stylebox_override("focus", Palette.button_style(Color(0.16, 0.17, 0.32, 0.98), Color.WHITE))
	b.add_theme_stylebox_override("disabled", Palette.button_style(Color(0.09, 0.09, 0.16, 0.9), Color(0.3, 0.3, 0.4, 0.6)))
	return b

static func panel(min_size: Vector2 = Vector2.ZERO) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Palette.panel_style())
	p.custom_minimum_size = min_size
	return p

static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v

static func hbox(separation: int = 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

## A slim progress bar with a themed fill colour.
static func bar(width: float, height: float, fill: Color, bg: Color = Color(0.08, 0.08, 0.16, 0.9)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(width, height)
	p.show_percentage = false
	p.max_value = 1.0
	p.value = 1.0
	p.step = 0.0001
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg
	bg_style.border_color = Color(0.4, 0.4, 0.6, 0.7)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(int(height * 0.4))
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(int(height * 0.4))
	p.add_theme_stylebox_override("background", bg_style)
	p.add_theme_stylebox_override("fill", fill_style)
	return p

## A full-screen dimming backdrop that blocks clicks from reaching the world.
static func scrim(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.06, alpha)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

static func slider(min_v: float, max_v: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 24)
	s.focus_mode = Control.FOCUS_ALL
	return s

static func separator() -> HSeparator:
	var s := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.62, 0.35)
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", style)
	return s
