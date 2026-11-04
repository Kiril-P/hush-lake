class_name SectorView
extends Node3D
## How the lake's sectors look. A sector is a flower of 7 hex tiles; what the player needs to see is where the sector ends and
## what state it is in, so this draws exactly that and nothing else:
##   LOCKED   a flat frosted sheet over the whole sector, a bright crisp border, and a thin glowing "gate" curtain where it meets
##            ground you can already fish. It reads from far away as "closed".
##   OPEN     only a faint thin teal line along its edge (you know where you are, it does not shout).
##   CLEARED  a deep thawed-water tint and a warm gold border: finished.
## An edge between two sectors is drawn once, by whichever of the two matters more (locked > cleared > open).
## Everything is flat shaded geometry with unshaded shaders: crisp, cheap and independent of the sun.

const Y_FILL := 0.03
const Y_LINE := 0.045
const CURTAIN_H := 0.8

const COL_LOCKED_FILL := Color(0.82, 0.91, 0.99)
const COL_LOCKED_LINE := Color(0.96, 0.99, 1.0)
const COL_GATE := Color(0.6, 0.92, 1.0)
const COL_OPEN_LINE := Color(0.42, 0.9, 0.88)
const COL_CLEARED_FILL := Color(0.06, 0.32, 0.42)   # thawed water: teal, not slate
const COL_CLEARED_LINE := Color(0.95, 0.84, 0.55)   # a softer, paler gold: the strong amber stays for what you can act on

const FILL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;
uniform vec3 tint : source_color = vec3(0.9, 0.95, 1.0);
uniform float alpha = 0.6;
uniform float stripes = 1.0;
uniform float fade = 1.0;
uniform float dim = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	// a quiet diagonal hatch, so a closed sector is also readable as a pattern and not only as a colour
	float band = step(0.5, fract((wpos.x + wpos.z) * 0.45));
	float k = smoothstep(11.0, 14.0, length(wpos.xz));   // never over the Eye's own pupil
	float near = 1.0 - smoothstep(18.0, 45.0, distance(wpos, CAMERA_POSITION_WORLD));   // the hatch fades out with distance: it is a close-up texture
	float st = stripes * near;
	ALBEDO = tint * dim * mix(1.0, 0.96 + 0.04 * band, st);
	ALPHA = alpha * mix(1.0, 0.86 + 0.14 * band, st) * fade * k;
}
"""

const LINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;
uniform vec4 col : source_color = vec4(1.0);
uniform float glow = 1.25;
uniform float fade = 1.0;
uniform float dim = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float k = smoothstep(11.0, 14.0, length(wpos.xz));
	float sheen = 0.82 + 0.18 * sin(TIME * 1.6 - (wpos.x + wpos.z) * 0.12);   // a slow light travelling along the border
	ALBEDO = col.rgb * glow * sheen * dim;
	ALPHA = col.a * fade * k;
}
"""

const CURTAIN_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform vec4 col : source_color = vec4(0.6, 0.92, 1.0, 0.35);
uniform float fade = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float up = pow(1.0 - UV.y, 1.7);   // bright at the ice, gone at the top
	float k = smoothstep(11.0, 14.0, length(wpos.xz));
	float shimmer = 0.8 + 0.2 * sin(TIME * 1.2 + (wpos.x - wpos.z) * 0.35);
	ALBEDO = col.rgb * col.a * up * shimmer * fade * k;
	ALPHA = 1.0;
}
"""

var game: Node
var tile_r := 7.0
var edges := {}              # sector id -> Array of {a: Vector2, b: Vector2, other: Variant (sector id or null)}
var patches := {}            # sector id -> {frost: MeshInstance3D, thaw: MeshInstance3D, line: MeshInstance3D, gate: MeshInstance3D}
var states := {}             # sector id -> 0 locked, 1 open, 2 cleared (what is drawn right now)
var _fill_shader: Shader
var _line_shader: Shader
var _curtain_shader: Shader

static func state_of(sec: Dictionary) -> int:
	if not sec.unlocked:
		return 0
	return 2 if sec.cleared else 1

## 3 = locked (always on top), 2 = cleared, 1 = open.
static func priority(st: int) -> int:
	return 3 if st == 0 else (2 if st == 2 else 1)

func build(g: Node) -> void:
	game = g
	tile_r = g.TILE
	_fill_shader = Shader.new()
	_fill_shader.code = FILL_SHADER
	_line_shader = Shader.new()
	_line_shader.code = LINE_SHADER
	_curtain_shader = Shader.new()
	_curtain_shader.code = CURTAIN_SHADER
	_compute_edges()
	for id in game.model.sectors:
		_make_patch(id)
	refresh(true)

# ---------------------------------------------------------------- geometry

func _corner(c: Vector3, k: int) -> Vector2:
	var a := deg_to_rad(60.0 * k - 30.0)
	return Vector2(c.x + cos(a) * tile_r, c.z + sin(a) * tile_r)

func _compute_edges() -> void:
	var model = game.model
	# which of a tile's six edges faces each axial neighbour direction (matched by the real world direction, not assumed)
	var dir_edge := {}
	var o: Vector3 = game._hex_pos(Vector2i.ZERO)
	for d in game.HEX_DIRS:
		var v: Vector3 = game._hex_pos(d) - o
		dir_edge[d] = posmod(int(round(atan2(v.z, v.x) / (PI / 3.0))), 6)
	for id in model.sectors:
		var list := []
		for t in model.sectors[id].tiles:
			var c: Vector3 = game._hex_pos(t)
			for d in game.HEX_DIRS:
				var n: Vector2i = t + d
				var other: Variant = model.tile_sector.get(n, null)
				if other != null and other == id:
					continue
				var k: int = dir_edge[d]
				list.append({"a": _corner(c, k), "b": _corner(c, k + 1), "other": other})
		edges[id] = list

func _fill_mesh(id: Vector2i) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in game.model.sectors[id].tiles:
		var c: Vector3 = game._hex_pos(t)
		for k in 6:
			var p0 := _corner(c, k)
			var p1 := _corner(c, k + 1)
			for v in [Vector3(c.x, Y_FILL, c.z), Vector3(p1.x, Y_FILL, p1.y), Vector3(p0.x, Y_FILL, p0.y)]:
				st.add_vertex(v)
	return st.commit()

func _ribbon(st: SurfaceTool, a: Vector2, b: Vector2, w: float, y: float) -> void:
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x) * (w * 0.5)
	var a2 := a - dir * (w * 0.5)
	var b2 := b + dir * (w * 0.5)
	var q := [a2 + n, b2 + n, b2 - n, a2 - n]
	for i in [0, 1, 2, 0, 2, 3]:
		st.add_vertex(Vector3(q[i].x, y, q[i].y))

func _curtain(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var pts := [Vector3(a.x, Y_LINE, a.y), Vector3(b.x, Y_LINE, b.y), Vector3(b.x, CURTAIN_H, b.y), Vector3(a.x, CURTAIN_H, a.y)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])

func _mat(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

func _make_patch(id: Vector2i) -> void:
	var fm := _fill_mesh(id)
	var frost := MeshInstance3D.new()
	frost.mesh = fm
	var fmat := _mat(_fill_shader)
	fmat.set_shader_parameter("tint", COL_LOCKED_FILL)
	fmat.set_shader_parameter("alpha", 0.48)
	frost.material_override = fmat
	frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frost)
	var thaw := MeshInstance3D.new()
	thaw.mesh = fm
	var tmat := _mat(_fill_shader)
	tmat.set_shader_parameter("tint", COL_CLEARED_FILL)
	tmat.set_shader_parameter("alpha", 0.34)
	tmat.set_shader_parameter("stripes", 0.0)
	thaw.material_override = tmat
	thaw.position.y = 0.004
	thaw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(thaw)
	var line := MeshInstance3D.new()
	line.material_override = _mat(_line_shader)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	var gate := MeshInstance3D.new()
	gate.material_override = _mat(_curtain_shader)
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gate)
	patches[id] = {"frost": frost, "thaw": thaw, "line": line, "gate": gate}

# ---------------------------------------------------------------- state

## Which edges does sector `id` draw (it "owns" them), and how? [{a, b, st: "locked"|"open"|"cleared", gate: bool}]
func owned_edges(id: Vector2i) -> Array:
	var model = game.model
	var s: int = state_of(model.sectors[id])
	var out := []
	for e in edges[id]:
		var o: Variant = e.other
		var os := -1
		if o != null:
			os = state_of(model.sectors[o])
			var ps := priority(s)
			var po := priority(os)
			if ps < po or (ps == po and (id.x > o.x or (id.x == o.x and id.y > o.y))):
				continue   # the other sector draws this edge
		out.append({"a": e.a, "b": e.b, "st": s, "gate": s == 0 and os > 0})
	return out

var _dim_t := 0.0

func _process(delta: float) -> void:
	_dim_t -= delta
	if _dim_t > 0.0 or game == null or game.scenery == null:
		return
	_dim_t = 0.25
	var night: float = game.scenery._night
	var d := lerpf(1.0, 0.42, night)   # unshaded white would glare at night: it follows the light of the day
	for id in patches:
		for k in ["frost", "thaw", "line"]:
			((patches[id][k] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("dim", d)

func refresh(first := false) -> void:
	var model = game.model
	for id in patches:
		var s: int = state_of(model.sectors[id])
		var p: Dictionary = patches[id]
		var was: int = states.get(id, -1)
		if s != was:
			if was == 0 and s > 0 and not first:
				_unlock_flash(id)
			states[id] = s
		(p.frost as MeshInstance3D).visible = s == 0
		(p.thaw as MeshInstance3D).visible = s == 2
		_rebuild_lines(id, s)

func _rebuild_lines(id: Vector2i, s: int) -> void:
	var p: Dictionary = patches[id]
	var line_st := SurfaceTool.new()
	line_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gate_st := SurfaceTool.new()
	gate_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.14 if s == 1 else (0.3 if s == 0 else 0.24)
	var n_line := 0
	var n_gate := 0
	for e in owned_edges(id):
		_ribbon(line_st, e.a, e.b, w, Y_LINE)
		n_line += 1
		if e.gate:
			_curtain(gate_st, e.a, e.b)
			n_gate += 1
	var lm: ShaderMaterial = (p.line as MeshInstance3D).material_override
	match s:
		0:
			lm.set_shader_parameter("col", Color(COL_LOCKED_LINE.r, COL_LOCKED_LINE.g, COL_LOCKED_LINE.b, 0.95))
		1:
			lm.set_shader_parameter("col", Color(COL_OPEN_LINE.r, COL_OPEN_LINE.g, COL_OPEN_LINE.b, 0.34))
		_:
			lm.set_shader_parameter("col", Color(COL_CLEARED_LINE.r, COL_CLEARED_LINE.g, COL_CLEARED_LINE.b, 0.75))
	(p.line as MeshInstance3D).mesh = line_st.commit() if n_line > 0 else null
	(p.gate as MeshInstance3D).mesh = gate_st.commit() if n_gate > 0 else null
	(p.gate.material_override as ShaderMaterial).set_shader_parameter("col", Color(COL_GATE.r, COL_GATE.g, COL_GATE.b, 0.3))

## A sector opens: its frost melts away and the border flashes once.
func _unlock_flash(id: Vector2i) -> void:
	var p: Dictionary = patches[id]
	var ghost := MeshInstance3D.new()
	ghost.mesh = (p.frost as MeshInstance3D).mesh
	var gm: ShaderMaterial = ((p.frost as MeshInstance3D).material_override as ShaderMaterial).duplicate()
	ghost.material_override = gm
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_method(func(v: float): gm.set_shader_parameter("fade", v), 1.0, 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(ghost.queue_free)
	var ring := MeshInstance3D.new()   # the border, flashing white and fading to its new colour
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for e in edges[id]:
		_ribbon(st, e.a, e.b, 0.9, Y_LINE + 0.01)
	ring.mesh = st.commit()
	var rm := _mat(_line_shader)
	rm.set_shader_parameter("col", Color(1.0, 0.95, 0.7, 0.95))
	rm.set_shader_parameter("glow", 1.6)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tw2 := ring.create_tween()
	tw2.tween_method(func(v: float): rm.set_shader_parameter("fade", v), 1.0, 0.0, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.tween_callback(ring.queue_free)
