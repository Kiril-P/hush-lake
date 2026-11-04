class_name HudWidgets
extends RefCounted
## Small drawn widgets for the HUD: the reactive crosshair and the tool icons. Drawn from lines so they stay crisp at any size
## and share the one palette (cream = neutral, amber = yours / interactive, aqua = the Eye and fish).

class Crosshair extends Control:
	var kind := 0           # 0 nothing, 1 interactive (amber), 2 the Eye (aqua), 3 fish you can kick (aqua + brackets)
	var progress := -1.0    # >= 0 draws a ring filling around the crosshair (drilling, gutting, charging a kick)
	var _t := 0.0
	var _r := 7.0

	func _process(delta: float) -> void:
		_t += delta
		var want := 7.0 if kind == 0 else (11.0 if kind != 3 else 13.0)
		_r = lerpf(_r, want, minf(1.0, delta * 14.0))
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var col := Color(0.97, 0.93, 0.85, 0.9)
		match kind:
			1: col = Color(1.0, 0.78, 0.35, 1.0)
			2, 3: col = Color(0.45, 0.95, 0.9, 1.0)
		draw_arc(c, _r, 0.0, TAU, 40, Color(0.02, 0.03, 0.1, 0.5), 4.0, true)   # soft shadow ring keeps it readable on white ice
		draw_arc(c, _r, 0.0, TAU, 40, col, 2.0, true)
		draw_circle(c, 1.6 if kind == 0 else 2.2, col)
		if kind == 1 or kind == 2:   # four ticks that breathe
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			for k in 4:
				var a := PI * 0.5 * k + PI * 0.25
				draw_line(c + Vector2(cos(a), sin(a)) * (_r + 3.0 + pulse * 1.5), c + Vector2(cos(a), sin(a)) * (_r + 7.0 + pulse * 1.5), col, 2.0, true)
		if kind == 3:   # kick brackets: corners that frame the target
			for k in 4:
				var a2 := PI * 0.5 * k + PI * 0.25
				var d := Vector2(cos(a2), sin(a2))
				var p0 := c + d * (_r + 6.0)
				draw_line(p0, p0 - d.rotated(PI * 0.5) * 6.0, col, 2.0, true)
				draw_line(p0, p0 - d.rotated(-PI * 0.5) * 6.0, col, 2.0, true)
		if progress >= 0.0:
			draw_arc(c, _r + 8.0, -PI * 0.5, -PI * 0.5 + TAU, 48, Color(0.02, 0.03, 0.1, 0.55), 5.0, true)
			draw_arc(c, _r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 48, Color(1.0, 0.78, 0.35) if progress < 0.98 else Color(1, 1, 1), 3.5, true)

class ToolIcon extends Control:
	var kind := 0
	var lit := true
	var active := false

	func _init(k: int) -> void:
		kind = k
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(1.0, 0.78, 0.35) if active else (Color(0.9, 0.9, 0.95, 0.95) if lit else Color(0.55, 0.58, 0.72, 0.7))
		var w := 2.2
		var o := Vector2(2, 2)
		match kind:
			0:   # hand auger: shaft, spiral flights, T-handle
				draw_line(o + Vector2(7, 24), o + Vector2(21, 6), col, w, true)
				for i in 4:
					var p := o + Vector2(9 + i * 3.3, 21 - i * 4.4)
					draw_line(p + Vector2(-3, -2.2), p + Vector2(3, 2.2), col, w * 0.8, true)
				draw_line(o + Vector2(17, 5), o + Vector2(25, 9), col, w, true)
			1:   # rod: a bending blank, reel and line with a hook
				draw_polyline(PackedVector2Array([o + Vector2(5, 25), o + Vector2(14, 14), o + Vector2(22, 6), o + Vector2(26, 8)]), col, w, true)
				draw_circle(o + Vector2(9, 20), 3.0, col)
				draw_line(o + Vector2(26, 8), o + Vector2(26, 18), col, 1.2, true)
				draw_arc(o + Vector2(24.5, 20), 1.8, 0.0, PI, 8, col, 1.5, true)
			2:   # auto-rod: a derrick
				draw_line(o + Vector2(6, 25), o + Vector2(14, 5), col, w, true)
				draw_line(o + Vector2(22, 25), o + Vector2(14, 5), col, w, true)
				draw_line(o + Vector2(9, 18), o + Vector2(19, 18), col, 1.6, true)
				draw_line(o + Vector2(4, 12), o + Vector2(24, 12), col, w, true)
				draw_circle(o + Vector2(14, 4), 2.0, col)
			3:   # smoker: a hut with a chimney and a curl of smoke
				draw_rect(Rect2(o + Vector2(6, 12), Vector2(16, 13)), col, false, w)
				draw_line(o + Vector2(4, 13), o + Vector2(14, 7), col, w, true)
				draw_line(o + Vector2(24, 13), o + Vector2(14, 7), col, w, true)
				draw_line(o + Vector2(19, 9), o + Vector2(19, 3), col, w, true)
				draw_arc(o + Vector2(21, 2), 2.5, PI, TAU, 8, col, 1.4, true)
			4:   # gut table: a top, legs and a knife
				draw_line(o + Vector2(3, 12), o + Vector2(25, 12), col, w + 0.6, true)
				draw_line(o + Vector2(6, 12), o + Vector2(4, 25), col, w, true)
				draw_line(o + Vector2(22, 12), o + Vector2(24, 25), col, w, true)
				draw_line(o + Vector2(9, 8), o + Vector2(19, 8), col, 1.6, true)
				draw_line(o + Vector2(19, 8), o + Vector2(22, 5), col, 1.6, true)
			5:   # belt: rails and marching chevrons
				draw_line(o + Vector2(2, 10), o + Vector2(26, 10), col, w, true)
				draw_line(o + Vector2(2, 20), o + Vector2(26, 20), col, w, true)
				for i in 3:
					var x := 7.0 + i * 7.0
					draw_polyline(PackedVector2Array([o + Vector2(x - 2, 12), o + Vector2(x + 2, 15), o + Vector2(x - 2, 18)]), col, 1.8, true)
			_:   # builder: a hammer
				draw_line(o + Vector2(6, 25), o + Vector2(18, 10), col, w + 0.6, true)
				draw_rect(Rect2(o + Vector2(13, 3), Vector2(13, 8)), col, true)
