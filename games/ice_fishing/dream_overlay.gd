class_name DreamOverlay
extends CanvasLayer
## Full-screen moments: the Eye's dream between lakes, and the ending. The screen falls to black, an eye of aqua rings opens in the
## middle, and the lines appear one at a time under it. Any key (after a beat) skips to the end. `ending` tints it amber.
## play() returns when it has faded out. See story.gd for the words.

signal finished

var active := false
var t := 0.0
var lines: Array = []
var per_line := 3.4
var warm := 0.0
var skip_ok := false
var fade_in := 1.4
var hold_end := 2.0
var bg: ColorRect
var eye: Control
var label: Label
var title_label: Label
var _done := false

func _init() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	bg = ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.03, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	eye = Control.new()
	eye.set_anchors_preset(Control.PRESET_FULL_RECT)
	eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
	eye.draw.connect(_draw_eye)
	add_child(eye)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 38)
	title_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_label.offset_top = 70
	title_label.offset_left = -400
	title_label.offset_right = 400
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.modulate.a = 0.0
	add_child(title_label)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.85, 0.96, 0.98))
	label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_top = -190
	label.offset_left = -480
	label.offset_right = 480
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	add_child(label)
	visible = false

## Starts it. `warmth` 0 = a dream (aqua), 1 = the ending (amber).
func play(lines_in: Array, title := "", warmth := 0.0, per := 3.4) -> void:
	lines = lines_in
	per_line = per
	warm = warmth
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45) if warmth > 0.5 else Color(0.5, 0.95, 0.95))
	t = 0.0
	active = true
	_done = false
	skip_ok = false
	visible = true
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

func total_time() -> float:
	return fade_in + per_line * lines.size() + hold_end + 1.0

func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	skip_ok = t > 1.5
	var k := clampf(t / fade_in, 0.0, 1.0)
	bg.color.a = k
	var li := int((t - fade_in) / per_line)
	var lt := fmod(t - fade_in, per_line) if t > fade_in else 0.0
	if t > fade_in and li < lines.size():
		label.text = String(lines[li])
		label.modulate.a = clampf(lt / 0.9, 0.0, 1.0) * clampf((per_line - lt) / 0.7, 0.0, 1.0)
	else:
		label.modulate.a = 0.0
	title_label.modulate.a = clampf((t - 0.6) / 1.2, 0.0, 1.0) * (1.0 if t < total_time() - 1.0 else clampf(total_time() - t, 0.0, 1.0))
	eye.queue_redraw()
	if t >= total_time():
		_end()

func _end() -> void:
	if _done:
		return
	_done = true
	active = false
	visible = false
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	get_viewport().set_input_as_handled()
	if skip_ok and ((event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)):
		t = maxf(t, total_time() - 1.0)   # jump to the last second: it still fades out

func _draw_eye() -> void:
	var c := eye.size * Vector2(0.5, 0.42)
	var open := clampf((t - 0.4) / 2.5, 0.0, 1.0)
	var breathe := 1.0 + 0.04 * sin(t * 1.3)
	var col_a := Color(0.35, 0.95, 0.92).lerp(Color(1.0, 0.78, 0.35), warm)
	var fade := 1.0 if t < total_time() - 1.0 else clampf(total_time() - t, 0.0, 1.0)
	for i in 7:
		var r := (70.0 + i * 26.0) * open * breathe
		var a := (0.5 - i * 0.065) * open * fade
		eye.draw_arc(c, r, 0.0, TAU, 64, Color(col_a.r, col_a.g, col_a.b, maxf(a, 0.0)), 2.0 + (6 - i) * 0.5, true)
	var amber := Color(1.0, 0.78, 0.35, 0.8 * open * fade)
	eye.draw_arc(c, 62.0 * open * breathe, 0.0, TAU, 64, amber, 3.0, true)
	eye.draw_circle(c, 54.0 * open * breathe, Color(0, 0.005, 0.02, fade))
	eye.draw_circle(c + Vector2(-14, -16) * open, 5.0 * open, Color(1, 1, 1, 0.75 * open * fade))
