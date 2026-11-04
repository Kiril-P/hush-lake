extends Control
## Minimap of the lake: one hexagon per tile, coloured by state. Redraws a few times a second.
## Locked = dim, fresh = blue, emptied = pale, cleared sector = gold. White dot = you, orange square = Olga's hut.

const PX := 1.45
var game: Node
var _t := 0.0

func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.1
		queue_redraw()

func _hex(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 6:
		var a := deg_to_rad(60.0 * k - 30.0)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, color)

func _draw() -> void:
	if game == null or game.model == null or game.tiles.is_empty():
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 3.0
	# a round porthole: dark indigo glass with a thin amber rim and a compass tick
	draw_circle(c, r + 2.0, Color(0.02, 0.03, 0.1, 0.55))
	draw_circle(c, r, Color(0.07, 0.09, 0.2, 0.86))
	for tc in game.tiles:
		var wp: Vector3 = game._hex_pos(tc)
		var q := Vector2(wp.x, wp.z) * PX
		if q.length() > r - 1.0:
			continue
		_hex(c + q, game.TILE * PX * 0.94, game.tile_map_color(game.tiles[tc]))
	# sector borders, the same lines you see on the ice: white = locked, gold = cleared, faint teal = open
	if game.sector_view:
		for id in game.sector_view.patches:
			for e in game.sector_view.owned_edges(id):
				var a: Vector2 = e.a * PX
				var b: Vector2 = e.b * PX
				if a.length() > r or b.length() > r:
					continue
				var colr := Color(0.96, 0.99, 1.0, 0.95) if e.st == 0 else (Color(0.95, 0.84, 0.55, 0.9) if e.st == 2 else Color(0.42, 0.9, 0.88, 0.35))
				draw_line(c + a, c + b, colr, 1.8 if e.st == 0 else 1.2, true)
	# the Eye, your holes and belts
	draw_circle(c, game.EYE_R * PX, Color(0.1, 0.6, 0.75, 0.9))
	draw_circle(c, game.PUPIL_R * PX, Color(0.02, 0.05, 0.1))
	draw_arc(c, game.EYE_R * PX, 0.0, TAU, 32, Color(1.0, 0.8, 0.4, 0.7), 1.2, true)
	for b in game.belts:
		draw_line(c + Vector2(b.a.x, b.a.z) * PX, c + Vector2(b.b.x, b.b.z) * PX, Color(1.0, 0.85, 0.4, 0.8), 1.5)
	for h in game.holes:
		var hq := Vector2(h.pos.x, h.pos.z) * PX
		if hq.length() < r - 2.0:
			draw_circle(c + hq, 1.8, Color(1.0, 0.6, 0.2) if h.state == "auto" else Color(0.9, 0.95, 1.0))
	for rg in game.rigs:
		var rq := Vector2(rg.pos.x, rg.pos.z) * PX
		if rq.length() < r - 3.0:
			draw_rect(Rect2(c + rq - Vector2(3, 3), Vector2(6, 6)), Color(0.45, 0.95, 0.9))
	for e in game.yard.fish:   # fish lying on the ice: little aqua specks
		var fq := Vector2(e.pos.x, e.pos.z) * PX
		if fq.length() < r - 2.0:
			draw_circle(c + fq, 1.3, Color(0.45, 0.95, 0.9, 0.9))
	var hp: Vector3 = game.hut_pos
	var hq2 := Vector2(hp.x, hp.z) * PX
	if hq2.length() > r - 5.0:
		hq2 = hq2.normalized() * (r - 5.0)
	draw_rect(Rect2(c + hq2 - Vector2(3.5, 3.5), Vector2(7, 7)), Color(1.0, 0.6, 0.2))
	var pl: Node3D = game.get_node("Player")
	var pq := Vector2(pl.position.x, pl.position.z) * PX
	if pq.length() > r - 4.0:
		pq = pq.normalized() * (r - 4.0)
	var fwd := Vector2(-sin(pl.rotation.y), -cos(pl.rotation.y))
	var side := Vector2(-fwd.y, fwd.x)
	var pv := c + pq
	draw_colored_polygon(PackedVector2Array([pv + fwd * 7.0, pv - fwd * 4.0 + side * 4.5, pv - fwd * 1.5, pv - fwd * 4.0 - side * 4.5]), Color(1.0, 0.8, 0.4))
	draw_polyline(PackedVector2Array([pv + fwd * 7.0, pv - fwd * 4.0 + side * 4.5, pv - fwd * 1.5, pv - fwd * 4.0 - side * 4.5, pv + fwd * 7.0]), Color(0.02, 0.03, 0.1, 0.8), 1.2, true)
	draw_arc(c, r, 0.0, TAU, 64, Color(1.0, 0.78, 0.35, 0.65), 2.0, true)
	draw_string(ThemeDB.fallback_font, Vector2(c.x - 3.5, 13.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.95, 0.93, 0.85, 0.85))
