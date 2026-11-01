class_name Style
extends RefCounted
## One look for the whole game ("Hush Lake dusk"; see docs/STYLE.md).
## Cold teal/blue world, ONE warm amber for anything lit, owned or interactive, deep-indigo UI with cream text.

const INK := Color(0.07, 0.09, 0.19)          # panel base
const INK_SOFT := Color(0.12, 0.15, 0.29)      # inset / slot base
const CREAM := Color(0.97, 0.94, 0.86)         # primary text
const MUTED := Color(0.66, 0.71, 0.85)         # secondary text
const AMBER := Color(1.0, 0.78, 0.35)          # the accent: coins, selection, lanterns, goals
const AMBER_DEEP := Color(0.85, 0.5, 0.18)
const AQUA := Color(0.45, 0.95, 0.9)           # the Eye, fish flowing to it, "good" feedback
const TEAL := Color(0.08, 0.52, 0.66)
const ROSE := Color(1.0, 0.55, 0.55)           # warnings, "too far"
const ICE_HI := Color(0.82, 0.95, 1.0)
const ICE_LO := Color(0.35, 0.6, 0.88)

static var _font: Font

static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Avenir Next Rounded", "Avenir Next", "Nunito", "Trebuchet MS", "Verdana"])
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_font = f
	return _font

static func box(bg: Color, radius := 14, border := Color(0, 0, 0, 0), border_w := 0, pad := Vector2(14, 8)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb

static func card() -> StyleBoxFlat:
	return box(Color(INK.r, INK.g, INK.b, 0.84), 16, Color(1, 1, 1, 0.10), 1, Vector2(16, 10))

static func slot(selected: bool, locked: bool) -> StyleBoxFlat:
	if selected:
		return box(Color(0.2, 0.17, 0.2, 0.92), 12, AMBER, 2, Vector2(10, 6))
	var bg := Color(INK_SOFT.r, INK_SOFT.g, INK_SOFT.b, 0.55 if locked else 0.85)
	return box(bg, 12, Color(1, 1, 1, 0.07), 1, Vector2(10, 6))

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.03, 0.1, 0.75))
	t.set_constant("outline_size", "Label", 5)
	t.set_stylebox("panel", "PanelContainer", card())
	var bg := box(Color(0, 0, 0, 0.45), 6, Color(1, 1, 1, 0.08), 1, Vector2(0, 0))
	bg.shadow_size = 0
	var fill := box(AMBER, 6, Color(0, 0, 0, 0), 0, Vector2(0, 0))
	fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	return t

## A thin themed bar (carry / Eye progress / drill progress).
static func bar(color := AMBER, h := 8.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(0, h)
	var fill := box(color, 5, Color(0, 0, 0, 0), 0, Vector2(0, 0))
	fill.shadow_size = 0
	b.add_theme_stylebox_override("fill", fill)
	return b
