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
		HudWidgets.paint_tool(self, kind, col)

## The line art of a tool icon (kind 0..6, see TOOLS in the game) on any CanvasItem, inside its _draw().
static func paint_tool(c: CanvasItem, kind: int, col: Color) -> void:
	var w := 2.2
	var o := Vector2(2, 2)
	match kind:
		0:   # hand auger: shaft, spiral flights, T-handle
			c.draw_line(o + Vector2(7, 24), o + Vector2(21, 6), col, w, true)
			for i in 4:
				var p := o + Vector2(9 + i * 3.3, 21 - i * 4.4)
				c.draw_line(p + Vector2(-3, -2.2), p + Vector2(3, 2.2), col, w * 0.8, true)
			c.draw_line(o + Vector2(17, 5), o + Vector2(25, 9), col, w, true)
		1:   # rod: a bending blank, reel and line with a hook
			c.draw_polyline(PackedVector2Array([o + Vector2(5, 25), o + Vector2(14, 14), o + Vector2(22, 6), o + Vector2(26, 8)]), col, w, true)
			c.draw_circle(o + Vector2(9, 20), 3.0, col)
			c.draw_line(o + Vector2(26, 8), o + Vector2(26, 18), col, 1.2, true)
			c.draw_arc(o + Vector2(24.5, 20), 1.8, 0.0, PI, 8, col, 1.5, true)
		2:   # auto-rod: a derrick
			c.draw_line(o + Vector2(6, 25), o + Vector2(14, 5), col, w, true)
			c.draw_line(o + Vector2(22, 25), o + Vector2(14, 5), col, w, true)
			c.draw_line(o + Vector2(9, 18), o + Vector2(19, 18), col, 1.6, true)
			c.draw_line(o + Vector2(4, 12), o + Vector2(24, 12), col, w, true)
			c.draw_circle(o + Vector2(14, 4), 2.0, col)
		3:   # smoker: a hut with a chimney and a curl of smoke
			c.draw_rect(Rect2(o + Vector2(6, 12), Vector2(16, 13)), col, false, w)
			c.draw_line(o + Vector2(4, 13), o + Vector2(14, 7), col, w, true)
			c.draw_line(o + Vector2(24, 13), o + Vector2(14, 7), col, w, true)
			c.draw_line(o + Vector2(19, 9), o + Vector2(19, 3), col, w, true)
			c.draw_arc(o + Vector2(21, 2), 2.5, PI, TAU, 8, col, 1.4, true)
		4:   # gut table: a top, legs and a knife
			c.draw_line(o + Vector2(3, 12), o + Vector2(25, 12), col, w + 0.6, true)
			c.draw_line(o + Vector2(6, 12), o + Vector2(4, 25), col, w, true)
			c.draw_line(o + Vector2(22, 12), o + Vector2(24, 25), col, w, true)
			c.draw_line(o + Vector2(9, 8), o + Vector2(19, 8), col, 1.6, true)
			c.draw_line(o + Vector2(19, 8), o + Vector2(22, 5), col, 1.6, true)
		5:   # belt: rails and marching chevrons
			c.draw_line(o + Vector2(2, 10), o + Vector2(26, 10), col, w, true)
			c.draw_line(o + Vector2(2, 20), o + Vector2(26, 20), col, w, true)
			for i in 3:
				var x := 7.0 + i * 7.0
				c.draw_polyline(PackedVector2Array([o + Vector2(x - 2, 12), o + Vector2(x + 2, 15), o + Vector2(x - 2, 18)]), col, 1.8, true)
		_:   # builder: a hammer
			c.draw_line(o + Vector2(6, 25), o + Vector2(18, 10), col, w + 0.6, true)
			c.draw_rect(Rect2(o + Vector2(13, 3), Vector2(13, 8)), col, true)

## One slot of the dock: a tool, a bucket with a fish heap, a fish in its own colour, or a faint empty ring.
class ItemIcon extends Control:
	var item := {}
	var kind := -1       # the tool art to draw when the item is a tool
	var active := false

	func _init() -> void:
		custom_minimum_size = Vector2(46, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_item(it: Dictionary, tool_kind: int) -> void:
		item = it
		kind = tool_kind

	func _draw() -> void:
		var col := Color(1.0, 0.78, 0.35) if active else Color(0.9, 0.9, 0.95, 0.95)
		match String(item.get("k", "")):
			"tool":
				draw_set_transform(Vector2(4, 4), 0.0, Vector2(1.3, 1.3))
				HudWidgets.paint_tool(self, kind, col)
			"bucket":
				var pail := Color(0.72, 0.78, 0.9) if not active else Color(1.0, 0.85, 0.5)
				var n := int(item.fish.size()) if item.has("fish") else 0
				var top := PackedVector2Array([Vector2(8, 15), Vector2(38, 15), Vector2(34, 40), Vector2(12, 40)])
				draw_colored_polygon(top, Color(pail.r * 0.35, pail.g * 0.38, pail.b * 0.45, 0.9))
				for i in mini(n, 5):   # fish tails poking out of the mouth
					var fx := 14.0 + i * 5.0
					draw_colored_polygon(PackedVector2Array([Vector2(fx, 16), Vector2(fx + 4, 6 + (i % 2) * 3), Vector2(fx + 7, 16)]), Color(0.45, 0.95, 0.9, 0.95))
				draw_polyline(PackedVector2Array([Vector2(8, 15), Vector2(12, 40), Vector2(34, 40), Vector2(38, 15)]), pail, 2.4, true)
				draw_line(Vector2(6, 15), Vector2(40, 15), pail, 3.0, true)
				draw_arc(Vector2(23, 15), 15.0, PI, TAU, 16, pail, 1.8, true)
			"fish":
				var fc: Color = item.f.color if item.has("f") else Color(0.6, 0.9, 0.9)
				var body := PackedVector2Array([Vector2(6, 22), Vector2(14, 14), Vector2(28, 14), Vector2(36, 22), Vector2(28, 30), Vector2(14, 30)])
				draw_colored_polygon(body, fc)
				draw_colored_polygon(PackedVector2Array([Vector2(36, 22), Vector2(44, 14), Vector2(44, 30)]), fc.darkened(0.2))
				draw_circle(Vector2(13, 20), 1.8, Color(0.05, 0.08, 0.15))
				if active:
					draw_polyline(PackedVector2Array([Vector2(6, 22), Vector2(14, 14), Vector2(28, 14), Vector2(36, 22), Vector2(28, 30), Vector2(14, 30), Vector2(6, 22)]), Color(1.0, 0.78, 0.35), 1.8, true)
			_:
				draw_arc(Vector2(23, 22), 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.14), 2.0, true)

## The day as a thin bar: golden hour, dusk, night and dawn in the sky's own colours, with a marker (a sun by day, a moon by night)
## where the day is now, and a small tick where the next phase starts.
class SkyClock extends Control:
	var t := 0.0          # the day clock, 0..1
	var night := 0.0
	const COLS := [Color(1.0, 0.72, 0.5), Color(0.62, 0.38, 0.55), Color(0.1, 0.16, 0.38), Color(0.55, 0.6, 0.85), Color(1.0, 0.72, 0.5)]

	func _init() -> void:
		custom_minimum_size = Vector2(170, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_time(day_t: float, night_v: float) -> void:
		t = day_t
		night = night_v
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var y := size.y * 0.5
		var seg := 24
		for i in seg:
			var k := float(i) / seg * 4.0
			var a: Color = COLS[int(k)]
			var b: Color = COLS[int(k) + 1]
			var col := a.lerp(b, k - floorf(k))
			draw_rect(Rect2(w * i / seg, y - 3.0, w / seg + 1.0, 6.0), Color(col.r, col.g, col.b, 0.9))
		draw_rect(Rect2(0, y - 3.0, w, 6.0), Color(0, 0, 0, 0.0), false)
		var x := w * clampf(t, 0.0, 1.0)
		var c := Vector2(x, y)
		draw_circle(c, 6.5, Color(0.02, 0.03, 0.1, 0.55))
		if night > 0.5:
			draw_circle(c, 4.6, Color(0.85, 0.9, 1.0))   # the moon, with a bite out of it
			draw_circle(c + Vector2(2.0, -1.2), 3.8, Color(0.1, 0.16, 0.38))
		else:
			draw_circle(c, 4.6, Color(1.0, 0.85, 0.45))

## A fish drawn from its model data (profile, colours, fin and tail shapes), side on, for the field journal: the same fish as in the
## world. `known` false draws the dark silhouette of a species you have not met. Boots, coins and pearls get simple glyphs.
class FishIcon extends Control:
	var species := ""
	var known := true

	func _init(name_in := "", known_in := true) -> void:
		species = name_in
		known = known_in
		custom_minimum_size = Vector2(76, 34)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ink(c: Color) -> Color:
		return c if known else Color(0.17, 0.2, 0.31)

	func _draw() -> void:
		var spec: Dictionary = FishModel.SPECS.get(species, {})
		var mid := Vector2(size.x * 0.5, size.y * 0.5)
		match String(spec.get("kind", "")):
			"coin":
				draw_circle(mid, 11.0, _ink(Color(0.95, 0.75, 0.2)))
				draw_arc(mid, 7.5, 0.0, TAU, 20, _ink(Color(0.7, 0.5, 0.1)), 1.6, true)
			"pearl":
				draw_circle(mid, 9.0, _ink(Color(0.75, 0.95, 1.0)))
				if known:
					draw_circle(mid + Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.9))
			"boot":
				draw_colored_polygon(PackedVector2Array([mid + Vector2(-8, -14), mid + Vector2(2, -14), mid + Vector2(4, 0), mid + Vector2(16, 5), mid + Vector2(16, 12), mid + Vector2(-8, 12)]), _ink(Color(0.4, 0.28, 0.2)))
				draw_line(mid + Vector2(-8, 12), mid + Vector2(16, 12), _ink(Color(0.2, 0.14, 0.1)), 2.0)
			"fish":
				var prof: Array = spec.prof
				var L := size.x * 0.62   # body length in px
				var x0 := mid.x - L * 0.42
				var top := PackedVector2Array()
				var bot := PackedVector2Array()
				var k := 14
				for i in k + 1:
					var u := float(i) / k
					var hw: Vector2 = FishModel._profile(prof, u)
					var px := x0 + u * L
					top.append(Vector2(px, mid.y - hw.x * L * 1.05))
					bot.append(Vector2(px, mid.y + hw.x * L * 1.05))
				# tail (nose is +x: the model's tail polygon runs to -x from the body's rear)
				var tp: Array = FishModel._tail_points(spec.tail)
				var tail := PackedVector2Array()
				for p in tp:
					tail.append(Vector2(x0 + (p.x) * L, mid.y - p.y * L))
				draw_colored_polygon(tail, _ink(spec.fin))
				# dorsal
				var dp: Array = FishModel._dorsal_points(spec.dorsal, spec)
				var dor := PackedVector2Array()
				for p in dp:
					dor.append(Vector2(mid.x + p.x * L, mid.y - p.y * L))
				if dor.size() >= 3:
					draw_colored_polygon(dor, _ink(spec.fin))
				var back_poly := PackedVector2Array()
				back_poly.append_array(top)
				for i in range(k, -1, -1):
					back_poly.append(Vector2(top[i].x, mid.y))
				draw_colored_polygon(back_poly, _ink(spec.back))
				var belly_poly := PackedVector2Array()
				for i in k + 1:
					belly_poly.append(Vector2(bot[i].x, mid.y))
				for i in range(k, -1, -1):
					belly_poly.append(bot[i])
				draw_colored_polygon(belly_poly, _ink(spec.belly))
				if known:
					var pat: Color = spec.pat if spec.has("pat") else Color(0, 0, 0, 0)
					draw_line(Vector2(x0 + L * 0.2, mid.y), Vector2(x0 + L * 0.88, mid.y), Color(pat.r, pat.g, pat.b, 0.55), 1.6, true)
					draw_circle(Vector2(x0 + L * 0.9, mid.y - 1.5), 1.8, Color(0.04, 0.04, 0.08))
					if spec.has("lure"):
						draw_circle(Vector2(x0 + L * 1.0, mid.y - FishModel._profile(prof, 0.9).x * L - 6.0), 3.0, spec.lure)
				draw_polyline(top, Color(0, 0, 0, 0.35), 1.0, true)
			_:
				draw_circle(mid, 6.0, Color(0.3, 0.33, 0.45))
