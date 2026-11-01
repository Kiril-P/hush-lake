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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.09, 0.2, 0.7))
	var c := size * 0.5
	for tc in game.tiles:
		var wp: Vector3 = game._hex_pos(tc)
		_hex(c + Vector2(wp.x, wp.z) * PX, game.TILE * PX * 0.94, game.tile_map_color(game.tiles[tc]))
	# the Eye, your holes and belts
	draw_circle(c, game.EYE_R * PX, Color(0.1, 0.6, 0.75, 0.9))
	draw_circle(c, game.PUPIL_R * PX, Color(0.02, 0.05, 0.1))
	for b in game.belts:
		draw_line(c + Vector2(b.a.x, b.a.z) * PX, c + Vector2(b.b.x, b.b.z) * PX, Color(1.0, 0.85, 0.4, 0.8), 1.5)
	for h in game.holes:
		draw_circle(c + Vector2(h.pos.x, h.pos.z) * PX, 1.8, Color(1.0, 0.6, 0.2) if h.state == "auto" else Color(0.9, 0.95, 1.0))
	var hp: Vector3 = game.hut_pos
	var hv := c + Vector2(hp.x, hp.z) * PX
	hv = hv.clamp(Vector2(6, 6), size - Vector2(6, 6))
	draw_rect(Rect2(hv - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.6, 0.2))
	var pl: Node3D = game.get_node("Player")
	var pv := c + Vector2(pl.position.x, pl.position.z) * PX
	pv = pv.clamp(Vector2(4, 4), size - Vector2(4, 4))
	var fwd := Vector2(-sin(pl.rotation.y), -cos(pl.rotation.y))
	draw_line(pv, pv + fwd * 12.0, Color(1, 1, 1, 0.9), 2.0)
	draw_circle(pv, 3.5, Color.WHITE)
