extends Node3D
## Pure scenery for the ice lake, built from primitives to match docs/concept/ice_*.png:
## sunset over a glassy lake, purple low-poly mountains, pines, a warm lit hut with chimney smoke,
## and a deep glowing "eye" under the ice that wakes up as you progress.

# World layout (metres from the lake centre). The lake is a disc of ice; a snowy bank rises to land, which is flat
# out to FLAT_R (so walking stays level) and then rolls up into foothills and the far mountains.
const LAKE_R := 90.0      # mean radius of the ice (a lake about 180 m across)
const BANK_R := 96.0
const LAND_Y := 0.12
const FLAT_R := 130.0
const EYE_R := 10.0       # outer edge of the Eye's iris
const PUPIL_R := 4.8      # the open hole in the middle

# shop id -> [bearing in degrees (0 = north, + = east), distance from the Eye]. The first four stalls and Olga's
# own market sit in a camp on the ice beside the Eye ("Market Row"); the later ones are outposts out on the lake that
# you find as goals unlock them.
const SHOP_SPOTS := {
	"bucket":   [38.0, 24.0],
	"bait":     [55.0, 24.0],
	"boots":    [72.0, 24.0],
	"drill":    [89.0, 24.0],
	"market":   [-92.0, 25.0],
	"lines":    [-32.0, 46.0],
	"sonar":    [128.0, 54.0],
	"wide":     [168.0, 44.0],
	"conveyor": [-140.0, 50.0],
	"snowmobile": [-14.0, 36.0],
	"kick":     [21.0, 24.0],
}

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var shore_noise := FastNoiseLite.new()
var obstacles: Array[Vector3] = []   # (x, z, radius): things the player cannot walk through
var olga := {}                      # {root, body, head, arm}: see npc_models.gd
var snow_node: CPUParticles3D
var lanterns: Array = []             # {mat, light, on}
var glow_mats: Array = []            # [material, day energy, night energy]
var blinkers: Array = []
var spinners: Array = []
var beam: Node3D
var beam_mat: StandardMaterial3D
var beacon_light: OmniLight3D
var crane: Node3D
var sky_mat: ProceduralSkyMaterial
var env_ref: Environment
var sun_light: DirectionalLight3D
var sun_disc: MeshInstance3D
var sun_path: MeshInstance3D
var moon: MeshInstance3D
var aurora_mats: Array[ShaderMaterial] = []
var _night := 0.0

# golden hour -> dusk -> night -> dawn -> golden hour
const KEYS := [
	{"top": Color(0.17, 0.25, 0.55), "hor": Color(1.0, 0.68, 0.52), "fog": Color(0.60, 0.66, 0.86), "sun": Color(1.0, 0.86, 0.72), "e": 1.0},
	{"top": Color(0.10, 0.15, 0.40), "hor": Color(0.78, 0.42, 0.50), "fog": Color(0.38, 0.42, 0.64), "sun": Color(0.9, 0.55, 0.55), "e": 0.7},
	{"top": Color(0.03, 0.05, 0.16), "hor": Color(0.10, 0.16, 0.34), "fog": Color(0.08, 0.13, 0.27), "sun": Color(0.55, 0.65, 1.0), "e": 0.55},
	{"top": Color(0.24, 0.34, 0.62), "hor": Color(1.00, 0.72, 0.60), "fog": Color(0.66, 0.68, 0.88), "sun": Color(1.0, 0.8, 0.7), "e": 0.85},
]
var crane_arm: Node3D
var _time := 0.0

func _mat(color: Color, emit := 0.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

func _mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m

func _box(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mesh(parent, bm, mat, pos)

func _cone(parent: Node, pos: Vector3, radius: float, height: float, sides: int, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return _mesh(parent, cm, mat, pos + Vector3(0, height * 0.5, 0))

func build(env: Environment, sun: DirectionalLight3D, hut: Node3D) -> void:
	# atmosphere
	env.fog_enabled = true
	env.fog_light_color = Color(0.60, 0.66, 0.86)
	env.fog_density = 0.0009
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.adjustment_enabled = true   # a gentle grade that ties sky, ice and lamps together: a touch more contrast and colour
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	# sun disc low on the horizon, light aimed from it
	var sun_dir := Vector3(sin(deg_to_rad(25.0)), 0.045, -cos(deg_to_rad(25.0))).normalized()
	var sun_pos := sun_dir * 700.0
	var sm := SphereMesh.new()
	sm.radius = 36.0
	sm.height = 72.0
	sun_disc = _mesh(self, sm, _mat(Color(1.0, 0.92, 0.6), 2.0, true), sun_pos)
	env_ref = env
	sun_light = sun
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sun.look_at_from_position(sun_pos, Vector3.ZERO)
	# glittering sun path on the ice
	var path := _box(self, Vector3.ZERO, Vector3(14, 0.02, 80), _mat(Color(1.0, 0.8, 0.5, 0.3), 0.0, true))
	sun_path = path
	path.position = (sun_dir * Vector3(1, 0, 1)).normalized() * 56.0 + Vector3(0, 0.03, 0)  # glitter only on the ice
	path.rotation.y = atan2(-sun_dir.x, -sun_dir.z)
	var mm := SphereMesh.new()
	mm.radius = 15.0
	mm.height = 30.0
	moon = _mesh(self, mm, _mat(Color(0.85, 0.9, 1.0), 1.4, true), Vector3(-240, 260, -540))
	moon.visible = false
	noise.seed = 21
	noise.frequency = 0.011
	noise.fractal_octaves = 3
	detail.seed = 5
	detail.frequency = 0.05
	shore_noise.seed = 9
	shore_noise.frequency = 0.05
	_aurora()
	_ice_and_eye()
	_terrain()
	_mountains()
	_decorate_hut(hut)
	obstacles.append(Vector3(hut.position.x, hut.position.z, 4.0))   # (a little wider: the camera must not hug the walls)
	_build_crane(hut)
	_snow()
	var clear: Array[Vector3] = []
	var lh := bearing_pos(150.0, LIGHTHOUSE_R)
	var vg := bearing_pos(-128.0, VILLAGE_R)
	clear.append(Vector3(lh.x, lh.z, 30.0))
	clear.append(Vector3(vg.x, vg.z, 50.0))
	var ws := shore(0.0, 22.0)
	clear.append(Vector3(ws.x, ws.z, 14.0))
	_forest(clear)
	_shore_clutter(clear)
	_ice_ridges()
	_shacks()
	_welcome_sign()
	_plaques()
	_lighthouse()
	_village()

const LIGHTHOUSE_R := 265.0
const VILLAGE_R := 335.0

## A point `off` metres beyond the shoreline in the given bearing.
func shore(deg: float, off: float) -> Vector3:
	return bearing_pos(deg, edge_at_bearing(deg_to_rad(deg)) + off)

static func bearing_pos(deg: float, r: float) -> Vector3:
	var a := deg_to_rad(deg)
	return Vector3(sin(a) * r, 0.0, -cos(a) * r)

## Radius of the lake edge in a given direction (bearing in radians): an irregular, lobed shoreline.
func edge_at_bearing(a: float) -> float:
	return LAKE_R + shore_noise.get_noise_2d(cos(a) * 30.0, sin(a) * 30.0) * 4.5

func edge_at(x: float, z: float) -> float:
	return edge_at_bearing(atan2(x, -z))

## Ground height: ice in the lake, a bank, flat land, then hills that grow with distance.
func ground_h(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var e := edge_at(x, z)
	if r <= e:
		return -0.1
	var h := lerpf(-0.1, LAND_Y, smoothstep(e, e + 2.5, r))
	var far := smoothstep(FLAT_R, 340.0, r)
	h += far * (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 18.0
	h += smoothstep(FLAT_R, 200.0, r) * (detail.get_noise_2d(x, z) * 0.5 + 0.5) * 2.5
	return h

func _shore_pts(offset: float, y: float, segs := 96) -> Array:
	var pts := []
	for j in segs:
		var a := TAU * j / segs
		var r := edge_at_bearing(a) + offset
		pts.append(Vector3(sin(a) * r, y, -cos(a) * r))
	return pts

## The lake's ice: the vertex colour (pale at the shore, deep in the middle) plus a living surface: soft mottling, fine
## cracks, drifting frost, a sky sheen toward the horizon and tiny glints that twinkle near you.
const ICE_SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec3 sky_tint : source_color = vec3(0.62, 0.74, 0.95);
uniform float glint_amount = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 17.3)); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5; float s = 0.0; for (int i = 0; i < 4; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; } return s; }
// distance to the nearest cell edge of a jittered grid: thin crack lines
float cracks(vec2 p) {
	vec2 g = floor(p); vec2 f = fract(p);
	float d1 = 8.0; float d2 = 8.0;
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 r = o + hash2(g + o) - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
	}
	return sqrt(d2) - sqrt(d1);
}
void fragment() {
	vec2 w = wpos.xz;
	float cdist = length(VERTEX);
	float mott = fbm(w * 0.09) * 0.7 + fbm(w * 0.5) * 0.3;
	vec3 base = COLOR.rgb * (0.88 + 0.22 * mott);
	// big slow frost clouds lighten some areas, deep blue shows in others
	float frost = smoothstep(0.52, 0.82, fbm(w * 0.035 + 7.0));
	base = mix(base, vec3(0.7, 0.86, 1.0), frost * 0.2);
	// fine cracks, strongest close up and in the paler ice
	float cr = cracks(w * 0.11);
	float crack = (1.0 - smoothstep(0.0, 0.035, cr)) * 0.35;
	float cr2 = cracks(w * 0.42 + 3.1);
	crack += (1.0 - smoothstep(0.0, 0.04, cr2)) * 0.16 * (1.0 - smoothstep(10.0, 40.0, cdist));
	base = mix(base, vec3(0.85, 0.95, 1.0), crack * (0.4 + 0.6 * mott));
	// sky sheen toward grazing angles
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 6.0);
	ALBEDO = pow(base, vec3(1.55));   // the mesh colours are chosen as screen colours: darken to linear like the old material did
	ROUGHNESS = 0.4 - 0.1 * mott;
	SPECULAR = 0.12;
	EMISSION = sky_tint * fres * 0.10;
	// glints: tiny stars that twinkle on the ice near the camera
	vec2 gp = w * 3.2;
	vec2 gc = floor(gp);
	float h = hash(gc);
	float tw = smoothstep(0.9, 1.0, sin(TIME * (1.5 + 2.0 * h) + h * 40.0) * 0.5 + 0.5);
	float spot = smoothstep(0.14, 0.0, length(fract(gp) - 0.5)) * step(0.955, h);
	float near = 1.0 - smoothstep(6.0, 34.0, length(VERTEX));
	EMISSION += vec3(0.8, 0.95, 1.0) * spot * tw * near * glint_amount * 0.8;
}
"""
var ice_mat: ShaderMaterial

func _ice_and_eye() -> void:
	# glassy ice with a lobed shoreline: pale and cool at the edges, deeper blue toward the middle
	var segs := 96
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var factors := [0.0, 0.45, 0.88, 1.0]   # the pale shore band is wider now, so the ice meets the bank softly
	var cols := [Color(0.5, 0.68, 0.85, 1.0), Color(0.58, 0.75, 0.9, 1.0), Color(0.7, 0.85, 0.95, 1.0), Color(0.84, 0.94, 0.99, 1.0)]   # less saturated: it read as ocean
	var rings := []
	for k in factors.size():
		var ring := []
		for j in segs:
			var a := TAU * j / segs
			var r: float = lerpf(PUPIL_R, edge_at_bearing(a) + 0.4, factors[k])  # the ice stops at the pupil: an open hole
			ring.append(Vector3(sin(a) * r, -0.1, -cos(a) * r))
		rings.append(ring)
	for k in factors.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			var q := [[k, j], [k + 1, j], [k, j2], [k, j2], [k + 1, j], [k + 1, j2]]
			for v in q:
				st.set_normal(Vector3.UP)
				st.set_color(cols[v[0]])
				st.add_vertex(rings[v[0]][v[1]])
	var ish := Shader.new()
	ish.code = ICE_SHADER
	var im := ShaderMaterial.new()
	im.shader = ish
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = im
	ice_mat = im
	add_child(mi)
	# basin walls + floor under the ice
	var top := _shore_pts(0.3, -0.1, segs)
	var bot := _shore_pts(0.3, -9.0, segs)
	var ws := SurfaceTool.new()
	ws.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segs:
		var j2 := (j + 1) % segs
		for v in [top[j], bot[j], top[j2], top[j2], bot[j], bot[j2]]:
			ws.set_normal(Vector3.UP)
			ws.add_vertex(v)
	var wm := _mat(Color(0.05, 0.16, 0.28))
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wi := MeshInstance3D.new()
	wi.mesh = ws.commit()
	wi.material_override = wm
	add_child(wi)
	var floor_m := CylinderMesh.new()
	floor_m.top_radius = BANK_R + 3.0
	floor_m.bottom_radius = BANK_R + 3.0
	floor_m.height = 0.4
	floor_m.radial_segments = 48
	_mesh(self, floor_m, _mat(Color(0.05, 0.16, 0.28)), Vector3(0, -9.0, 0))
	_build_eye()

# The Eye lives in eye.gd (iris shader, lids, petals, crystals, funnel, reactions); these are the facade calls.
const EyeScript = preload("res://games/ice_fishing/eye.gd")
var eye: Node3D

func _build_eye() -> void:
	eye = EyeScript.new()
	add_child(eye)

func set_eye_glow(amount: float) -> void:
	eye.set_glow(amount)

## 0 = barely stirring .. 1 = fully open: the eyelids lift.
func set_eye_open(x: float) -> void:
	eye.set_open(x)

func set_eye_stage(st: int) -> void:
	eye.set_stage(st)

func eye_stage_up(st: int) -> void:
	eye.stage_up(st)

func eye_prelude(on: bool) -> void:
	eye.prelude(on)

func eye_awaken() -> void:
	eye.awaken()

func eye_gulp(power := 1.0) -> void:
	eye.gulp(power)

func eye_catch(c: Color, weight := 0.3) -> void:
	eye.catch(c, weight)

func eye_landing(from: Vector3) -> Vector3:
	return eye.landing_point(from)

func set_eye_offering(on: bool, from: Vector3) -> void:
	eye.set_offering(on, from)

func pulse_eye() -> void:
	eye.catch(Color(0.6, 1.0, 0.95), 0.2)

## The inner pupil drifts toward whoever is on the ice, so the Eye seems to watch you.
func set_eye_look(pp: Vector2, delta: float) -> void:
	eye.look(pp, delta)

## Mountain ranges as single flat-shaded meshes: jagged peaks with a real snow line, no overlapping solids.
## Two ranks: tall back range, lower front range. Radius is capped by the arc length so neighbours never intersect.
func _mountains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var light := Vector3(0.45, 0.75, -0.5).normalized()
	var ranks := [
		{"n": 22, "dist": 640.0, "rad": [64.0, 80.0], "h": [100.0, 165.0]},
		{"n": 30, "dist": 500.0, "rad": [36.0, 48.0], "h": [45.0, 95.0]},
	]
	for rank in ranks:
		for i in rank.n:
			var a: float = TAU * (float(i) + rng.randf_range(-0.12, 0.12)) / rank.n + (0.0 if rank.dist > 560.0 else PI / rank.n)
			var dist: float = rank.dist + rng.randf_range(-14.0, 14.0)
			var r: float = rng.randf_range(rank.rad[0], rank.rad[1])
			var h: float = rng.randf_range(rank.h[0], rank.h[1])
			var tone := rng.randf()
			var rock := Color(0.24, 0.31, 0.55).lerp(Color(0.46, 0.52, 0.74), tone)
			var cx := sin(a) * dist
			var cz := -cos(a) * dist
			var sides := 7
			# rings: base, snow line, upper, apex
			var specs := [[-2.0, 1.0], [0.52, 0.5], [0.82, 0.2]]
			var rings := []
			for ri in specs.size():
				var ring := []
				for k in sides:
					var ang := TAU * (k + rng.randf_range(-0.25, 0.25)) / sides + ri * 0.4
					var rr: float = r * specs[ri][1] * rng.randf_range(0.82, 1.18)
					var yy: float = h * specs[ri][0] if ri > 0 else -2.0
					ring.append(Vector3(cx + cos(ang) * rr, yy + (rng.randf_range(-0.06, 0.06) * h if ri > 0 else 0.0), cz + sin(ang) * rr))
				rings.append(ring)
			var apex := Vector3(cx + rng.randf_range(-0.1, 0.1) * r, h, cz + rng.randf_range(-0.1, 0.1) * r)
			for ri in 3:
				for k in sides:
					var k2 := (k + 1) % sides
					var snow := ri >= 1
					var tris: Array = []
					if ri < 2:
						tris = [[rings[ri][k], rings[ri + 1][k], rings[ri][k2]], [rings[ri][k2], rings[ri + 1][k], rings[ri + 1][k2]]]
					else:
						tris = [[rings[2][k], apex, rings[2][k2]]]
					for t in tris:
						var n: Vector3 = (t[1] - t[0]).cross(t[2] - t[0]).normalized()
						var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
						if n.dot(mid - Vector3(cx, 0, cz)) < 0.0:
							n = -n
						var lit := 0.7 + 0.5 * maxf(0.0, n.dot(light))
						var base := Color(0.9, 0.87, 1.0) if snow else rock
						var col := Color(base.r * lit, base.g * lit, base.b * lit)
						for v in t:
							st.set_color(col)
							st.add_vertex(v)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)

func _decorate_hut(hut: Node3D) -> void:
	var wood := _mat(Color(0.28, 0.17, 0.12))
	var glow := _mat(Color(1.0, 0.72, 0.3), 1.8)
	var roof := PrismMesh.new()
	roof.size = Vector3(6.0, 1.8, 4.8)
	_mesh(hut, roof, _mat(Color(0.18, 0.2, 0.34)), Vector3(0, 3.9, 0))
	_box(hut, Vector3(1.5, 4.7, -1.0), Vector3(0.6, 1.6, 0.6), _mat(Color(0.3, 0.22, 0.2)))
	# windows
	_box(hut, Vector3(-1.4, 1.8, 2.03), Vector3(0.9, 0.8, 0.08), glow)
	_box(hut, Vector3(2.53, 1.8, 0.0), Vector3(0.08, 0.8, 0.9), glow)
	_box(hut, Vector3(-2.53, 1.8, 0.0), Vector3(0.08, 0.8, 0.9), glow)
	# log courses, corner posts, window and door frames, a snow ledge on the eaves and a soft glow around each window:
	# flat walls were the biggest "untextured" surfaces in the camp
	var trim := _mat(Color(0.3, 0.19, 0.14))
	for y in [0.5, 1.0, 1.5, 2.0, 2.5]:
		_box(hut, Vector3(0, y, 0), Vector3(5.05, 0.05, 4.05), trim)
	for cx in [-2.5, 2.5]:
		for cz in [-2.0, 2.0]:
			_box(hut, Vector3(cx, 1.55, cz), Vector3(0.28, 3.1, 0.28), trim)
	_box(hut, Vector3(-1.4, 2.25, 2.06), Vector3(1.15, 0.1, 0.1), trim)   # window head and sill
	_box(hut, Vector3(-1.4, 1.35, 2.06), Vector3(1.15, 0.1, 0.1), trim)
	_box(hut, Vector3(0, 2.1, 2.1), Vector3(1.55, 0.14, 0.12), trim)       # door head
	for gx in [[-1.4, 1.8, 2.0], [2.55, 1.8, 0.0], [-2.55, 1.8, 0.0]]:
		var halo := _box(hut, Vector3(gx[0], gx[1], gx[2]), Vector3(1.5, 1.4, 0.02) if absf(gx[0]) < 2.0 else Vector3(0.02, 1.4, 1.5), _mat(Color(1.0, 0.72, 0.3, 0.14), 0.8))
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ledge := _box(hut, Vector3(0, 3.0, 0), Vector3(6.2, 0.14, 5.0), _mat(Color(0.9, 0.95, 1.0)))   # snow along the eaves
	ledge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# lantern + warm light
	_box(hut, Vector3(1.4, 1.7, 2.2), Vector3(0.22, 0.34, 0.22), glow)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.35)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position = Vector3(0, 2.0, 3.2)
	hut.add_child(light)
	# fish drying rack
	for x in [-2.2, -3.8]:
		_box(hut, Vector3(x, 0.9, 2.8), Vector3(0.12, 1.8, 0.12), wood)
	_box(hut, Vector3(-3.0, 1.75, 2.8), Vector3(1.8, 0.08, 0.08), wood)
	for i in 4:
		_box(hut, Vector3(-2.6 - i * 0.35, 1.4, 2.8), Vector3(0.14, 0.55, 0.05), _mat(Color(0.7, 0.78, 0.85)))
	# crates and snow around the base
	_box(hut, Vector3(2.8, 0.35, 2.8), Vector3(0.7, 0.7, 0.7), wood)
	_box(hut, Vector3(3.6, 0.25, 2.4), Vector3(0.5, 0.5, 0.5), wood)
	_box(hut, Vector3(3.2, 0.9, 2.7), Vector3(0.5, 0.4, 0.5), wood)
	var snow := CylinderMesh.new()
	snow.top_radius = 5.5
	snow.bottom_radius = 6.2
	snow.height = 0.2
	snow.radial_segments = 16
	_mesh(hut, snow, _mat(Color(0.84, 0.91, 1.0), 0.3, false), Vector3(0, 0.0, 1.2))   # a little self-light keeps trampled snow blue-white instead of lilac under the golden sun
	# Olga herself, beside her counter
	var op: Dictionary = NpcModels.olga()
	olga = op
	var ol: Node3D = op.root
	ol.position = Vector3(1.55, 0.0, 3.2)
	ol.rotation_degrees.y = -20.0
	hut.add_child(ol)
	# chimney smoke
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(1.5, 5.6, -1.0)
	smoke.amount = 28
	smoke.lifetime = 5.0
	smoke.direction = Vector3(0.2, 1, 0)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.4, 0.3, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.8
	var sp := SphereMesh.new()
	sp.radius = 0.3
	sp.height = 0.6
	smoke.mesh = sp
	smoke.material_override = _mat(Color(0.95, 0.9, 0.95, 0.35), 0.0, true)
	hut.add_child(smoke)

func _snow() -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 14, 0)
	p.amount = 500
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(34, 0.5, 34)
	p.direction = Vector3(0, -1, 0)
	p.spread = 5.0
	p.gravity = Vector3(0.3, -1.2, 0.1)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	var sp := SphereMesh.new()
	sp.radius = 0.03
	sp.height = 0.06
	sp.radial_segments = 4
	sp.rings = 2
	p.mesh = sp
	p.material_override = _mat(Color(1, 1, 1, 0.8), 0.0, true)
	add_child(p)
	snow_node = p

# crane beside the hut, shown once the conveyor network is big enough
func _build_crane(hut: Node3D) -> void:
	crane = Node3D.new()
	crane.position = Vector3(-4.6, 0.0, 1.0)
	crane.visible = false
	hut.add_child(crane)
	var iron := _mat(Color(0.22, 0.2, 0.26))
	var rust := _mat(Color(0.7, 0.35, 0.18))
	_box(crane, Vector3(0, 3.5, 0), Vector3(0.45, 7.0, 0.45), iron)
	_box(crane, Vector3(0, 0.2, 0), Vector3(1.4, 0.4, 1.4), rust)
	crane_arm = Node3D.new()
	crane_arm.position = Vector3(0, 7.0, 0)
	crane.add_child(crane_arm)
	_box(crane_arm, Vector3(2.4, 0, 0), Vector3(5.2, 0.3, 0.3), rust)
	_box(crane_arm, Vector3(-0.9, 0, 0), Vector3(1.4, 0.5, 0.5), iron)
	_box(crane_arm, Vector3(4.2, -1.9, 0), Vector3(0.05, 3.6, 0.05), iron)
	_box(crane_arm, Vector3(4.2, -3.8, 0), Vector3(0.8, 0.6, 0.8), _mat(Color(1.0, 0.8, 0.3), 1.0))
	_box(crane, Vector3(0, 7.2, 0), Vector3(0.2, 0.2, 0.2), _mat(Color(1.0, 0.3, 0.2), 2.5))

func set_crane(on: bool) -> void:
	if crane:
		crane.visible = on

func _process(delta: float) -> void:
	_time += delta
	for i in aurora_mats.size():
		aurora_mats[i].set_shader_parameter("strength", _night * (0.55 + 0.35 * sin(_time * 0.5 + i * 2.1)))
	if crane and crane.visible:
		crane_arm.rotation.y = sin(_time * 0.35) * 0.9
	if beam:
		beam.rotation.y = _time * 0.7
		beam_mat.albedo_color.a = 0.24 * clampf((_night - 0.25) / 0.5, 0.0, 1.0)  # invisible by day
		beam.visible = _night > 0.25
		beacon_light.light_energy = _night * 2.5
	for sp in spinners:
		sp.rotation.z += delta * 0.8
	for bl in blinkers:
		bl.emission_energy_multiplier = 3.0 if fmod(_time, 1.6) < 0.25 else 0.2

const AURORA_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.2, 1.0, 0.6);
uniform float strength = 0.0;
void fragment() {
	float v = smoothstep(0.0, 0.45, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float h = smoothstep(0.0, 0.25, UV.x) * (1.0 - smoothstep(0.75, 1.0, UV.x));
	float rays = 0.82 + 0.18 * sin(UV.x * 22.0 + TIME * 0.5 + UV.y * 5.0);
	ALBEDO = tint * (0.8 + 0.4 * v);
	ALPHA = v * h * rays * strength;
}
"""

func _aurora() -> void:
	var cols := [Color(0.2, 1.0, 0.6), Color(0.3, 0.85, 1.0), Color(0.25, 1.0, 0.85)]   # (no violet: the palette is teal and amber)
	var angs := [-35.0, 15.0, 65.0]
	var sh := Shader.new()
	sh.code = AURORA_SHADER
	for i in 3:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tint", Vector3(cols[i].r, cols[i].g, cols[i].b))
		m.set_shader_parameter("strength", 0.0)
		aurora_mats.append(m)
		var q := QuadMesh.new()
		q.size = Vector2(700, 160)
		var a := deg_to_rad(angs[i])
		var mi := _mesh(self, q, m, Vector3(sin(a) * 540.0, 230.0 + i * 16.0, -cos(a) * 540.0))
		mi.look_at(Vector3(0, 170, 0), Vector3.UP, true)

## t in [0,1): 0 golden hour, .25 dusk, .5 night, .75 dawn
func set_time(t: float) -> void:
	var f := t * 4.0
	var i := int(f) % 4
	var k := f - floorf(f)
	var a: Dictionary = KEYS[i]
	var b: Dictionary = KEYS[(i + 1) % 4]
	sky_mat.sky_top_color = a.top.lerp(b.top, k)
	sky_mat.sky_horizon_color = a.hor.lerp(b.hor, k)
	sky_mat.ground_horizon_color = a.hor.lerp(b.hor, k)
	env_ref.fog_light_color = a.fog.lerp(b.fog, k)
	sun_light.light_color = a.sun.lerp(b.sun, k)
	sun_light.light_energy = lerpf(a.e, b.e, k)
	_night = clampf(1.0 - absf(t - 0.5) * 4.0, 0.0, 1.0)
	env_ref.ambient_light_energy = 1.0 + _night * 0.8
	if eye:
		eye.set_night(_night)
	sun_disc.visible = _night < 0.85
	sun_path.visible = _night < 0.6
	moon.visible = _night > 0.15
	for g in glow_mats:
		g[0].emission_energy_multiplier = lerpf(g[1], g[2], _night)

# ---------- terrain, forest, shore ----------
func _ground_color(p: Vector3) -> Color:
	var r := Vector2(p.x, p.z).length()
	var col := Color(0.93, 0.96, 1.0)
	var v := detail.get_noise_2d(p.x * 3.0, p.z * 3.0) * 0.035
	col = Color(col.r + v, col.g + v, col.b + v * 0.5)
	var e := edge_at(p.x, p.z)
	if r < e + 3.0:
		col = col.lerp(Color(0.62, 0.88, 1.0), 0.75)  # packed blue-white ice on the bank
	col = col.lerp(Color(0.52, 0.6, 0.82), clampf((p.y - 4.0) / 14.0, 0.0, 0.8))
	return col

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	var col := _ground_color((a + b + c) / 3.0)
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(v)

func _terrain() -> void:
	var radii := [-1.0, -2.0, -3.0, 108.0, 122.0, 138.0, 156.0, 178.0, 204.0, 234.0, 268.0, 306.0, 350.0, 400.0, 460.0, 530.0, 620.0, 740.0, 900.0]
	var offs := [0.0, 1.2, 2.5]  # negative entries above = rows that follow the shoreline
	var segs := 128
	var rows := []
	for i in radii.size():
		var row := []
		for j in segs:
			var a := TAU * j / segs
			var rr: float = radii[i] if radii[i] > 0.0 else edge_at_bearing(a) + offs[int(-radii[i]) - 1]
			var x: float = sin(a) * rr
			var z: float = -cos(a) * rr
			row.append(Vector3(x, ground_h(x, z), z))
		rows.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in radii.size() - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			_tri(st, rows[i][j], rows[i + 1][j], rows[i][j2])
			_tri(st, rows[i][j2], rows[i + 1][j], rows[i + 1][j2])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	add_child(mi)

func _multi(mesh: Mesh, items: Array) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	add_child(mi)

func _xf(pos: Vector3, scl: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(0, yaw, 0)).scaled(scl), pos)

func _blocked(x: float, z: float, clear: Array[Vector3]) -> bool:
	for c in clear:
		if Vector2(x - c.x, z - c.y).length() < c.z:
			return true
	return false

func _forest(clear: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fnoise := FastNoiseLite.new()
	fnoise.seed = 3
	fnoise.frequency = 0.02
	var trunks := []
	var tiers := [[], [], []]
	var caps := [[], [], []]   # snow lying on each tier
	var bare := []             # a few dead trees and stumps
	var bare_branches := []
	for k in 3400:
		var a := rng.randf() * TAU
		var r := rng.randf_range(112.0, 400.0)
		var x := sin(a) * r
		var z := -cos(a) * r
		var f := fnoise.get_noise_2d(x, z)
		if (r < 190.0 and f < 0.42) or f < 0.15:
			continue  # clearings, and only a few groves near the lake
		if _blocked(x, z, clear):
			continue
		var y := ground_h(x, z)
		var sc := rng.randf_range(1.9, 3.2) * (1.0 + r / 260.0)
		if rng.randf() < 0.05 and r < 260.0:   # a dead tree: grey trunk, a few bare branches
			var h0 := rng.randf_range(3.5, 6.5) * (1.0 + r / 400.0)
			bare.append([_xf(Vector3(x, y + h0 * 0.5, z), Vector3(0.28, h0, 0.28)), Color(0.34, 0.3, 0.38)])
			for b in 4:
				var ang := rng.randf() * TAU
				var by := y + h0 * rng.randf_range(0.45, 0.95)
				var bl := rng.randf_range(1.2, 2.4)
				bare_branches.append([Transform3D(Basis.from_euler(Vector3(0.0, ang, 0.9 + rng.randf() * 0.3)).scaled(Vector3(bl, 0.12, 0.12)), Vector3(x + cos(ang) * bl * 0.3, by, z - sin(ang) * bl * 0.3)), Color(0.34, 0.3, 0.38)])
			continue
		var tint := Color(0.09, 0.26, 0.30).lerp(Color(0.14, 0.2, 0.38), rng.randf() * 0.7)
		trunks.append([_xf(Vector3(x, y + 0.4 * sc, z), Vector3(0.3, 0.8, 0.3) * sc), Color(0.2, 0.15, 0.15)])
		for t in 3:
			var rad := (1.5 - t * 0.4) * sc
			var h := 1.8 * sc
			var yaw := rng.randf() * TAU
			tiers[t].append([_xf(Vector3(x, y + (0.7 + t) * sc + h * 0.5, z), Vector3(rad, h, rad), yaw), tint])
			# the upper two thirds of every tier carry snow: a smaller, paler cone sitting on top of it
			caps[t].append([_xf(Vector3(x, y + (0.7 + t) * sc + h * 0.68, z), Vector3(rad * 0.7, h * 0.66, rad * 0.7), yaw), Color(0.88, 0.94, 1.0)])
	var bm := BoxMesh.new()
	_multi(bm, trunks)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	for t in 3:
		_multi(cone, tiers[t])
		_multi(cone, caps[t])
	_multi(bm, bare)
	_multi(bm, bare_branches)

func _shore_clutter(clear: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var rocks := []
	var drifts := []
	var reeds := []
	for k in 140:
		var a := rng.randf() * TAU
		var r := rng.randf_range(edge_at_bearing(a) + 1.5, edge_at_bearing(a) + 42.0)
		var x := sin(a) * r
		var z := -cos(a) * r
		if _blocked(x, z, clear):
			continue
		var s := rng.randf_range(0.8, 2.6)
		rocks.append([_xf(Vector3(x, ground_h(x, z) + s * 0.1, z), Vector3(s * 1.3, s * 0.8, s), rng.randf() * TAU),
			Color(0.4, 0.46, 0.62).lerp(Color(0.6, 0.66, 0.8), rng.randf())])
	for k in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(105.0, 270.0)
		var x := sin(a) * r
		var z := -cos(a) * r
		if _blocked(x, z, clear):
			continue
		var s := rng.randf_range(4.0, 11.0)
		drifts.append([_xf(Vector3(x, ground_h(x, z) - s * 0.05, z), Vector3(s * 1.5, s * 0.5, s), rng.randf() * TAU), Color(0.9, 0.88, 0.99)])
	for k in 60:  # frozen reed clumps right at the water line
		var a := rng.randf() * TAU
		var r := edge_at_bearing(a) + rng.randf_range(0.2, 1.4)
		for n in 5:
			var x := sin(a + rng.randf_range(-0.02, 0.02)) * (r + rng.randf_range(-0.4, 0.4))
			var z := -cos(a + rng.randf_range(-0.02, 0.02)) * (r + rng.randf_range(-0.4, 0.4))
			var hh := rng.randf_range(1.2, 2.6)
			reeds.append([_xf(Vector3(x, ground_h(x, z) + hh * 0.5, z), Vector3(0.07, hh, 0.07)), Color(0.62, 0.5, 0.44).lerp(Color(0.8, 0.76, 0.86), rng.randf() * 0.4)])
	_multi(rock, rocks)
	var drift := SphereMesh.new()
	drift.radial_segments = 8
	drift.rings = 4
	_multi(drift, drifts)
	_multi(BoxMesh.new(), reeds)

func _ice_ridges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var items := []
	for k in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(55.0, edge_at_bearing(a) - 1.2)
		var len := rng.randf_range(5.0, 14.0)
		items.append([_xf(Vector3(sin(a) * r, 0.02, -cos(a) * r), Vector3(len, 0.14, 0.18), -a + rng.randf_range(-0.6, 0.6) + PI * 0.5),
			Color(0.62, 0.72, 0.86)])
	_multi(BoxMesh.new(), items)

# ---------- landmarks ----------
func _shacks() -> void:
	# abandoned fishing shacks frozen into the ice: other people who tried to empty the lake
	var spots := [[96.0, 22.0, 0.10], [168.0, 22.5, -0.08], [214.0, 21.5, 0.12]]
	for sp in spots:
		var pos := bearing_pos(sp[0], edge_at_bearing(deg_to_rad(sp[0])) - 3.4)
		var sh := Node3D.new()
		sh.position = Vector3(pos.x, -0.35, pos.z)
		add_child(sh)
		sh.look_at(Vector3(0, -0.35, 0), Vector3.UP, true)
		sh.rotation.z = sp[2]
		var wood := _mat(Color(0.3, 0.26, 0.28))
		_box(sh, Vector3(0, 1.2, 0), Vector3(3.4, 2.4, 2.8), wood)
		var roof := PrismMesh.new()
		roof.size = Vector3(3.8, 1.1, 3.2)
		_mesh(sh, roof, _mat(Color(0.22, 0.22, 0.3)), Vector3(0, 2.95, 0))
		_box(sh, Vector3(0, 3.55, 0), Vector3(3.5, 0.18, 1.0), _mat(Color(0.86, 0.85, 0.97)))
		_box(sh, Vector3(0.6, 1.1, 1.41), Vector3(0.8, 1.7, 0.06), _mat(Color(0.05, 0.05, 0.1)))  # dark doorway
		_box(sh, Vector3(-0.9, 1.5, 1.41), Vector3(0.6, 0.5, 0.06), _mat(Color(0.04, 0.05, 0.12)))
		obstacles.append(Vector3(pos.x, pos.z, 2.6))

func _plaque_at(pos: Vector3, text: String, size := 0.0065) -> void:
	var node := Node3D.new()
	node.position = Vector3(pos.x, ground_h(pos.x, pos.z), pos.z)
	add_child(node)
	node.look_at(Vector3(0, node.position.y, 0), Vector3.UP, true)
	_box(node, Vector3(0, 0.7, 0), Vector3(2.0, 1.4, 0.3), _mat(Color(0.5, 0.48, 0.64)))
	_box(node, Vector3(0, 1.45, 0), Vector3(2.1, 0.12, 0.38), _mat(Color(0.88, 0.94, 1.0)))
	var l := Label3D.new()
	l.text = text
	l.font_size = 34
	l.pixel_size = size
	l.width = 280.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.outline_size = 6
	l.modulate = Color(1.0, 0.95, 0.85)
	l.position = Vector3(0, 0.7, 0.17)
	l.visibility_range_end = 18.0
	node.add_child(l)
	obstacles.append(Vector3(pos.x, pos.z, 1.3))

func _plaques() -> void:
	_plaque_at(shore(72.0, 10.0), "Marren fished here forty winters.\nHis lamp is still down there somewhere.")
	_plaque_at(shore(128.0, 10.0), "Wren Deep: the fish out there are older than the town.")
	_plaque_at(shore(190.0, 10.0), "Olga's rule:\nnever take the last one alone.")
	_plaque_at(shore(-92.0, 10.0), "Kestrel Landing, three days by sled.\nNobody comes back with the same story.")
	_plaque_at(shore(-150.0, 10.0), "Somebody scratched this in the stone:\nTHE LAKE WAS NEVER MEANT TO BE EMPTY.")

func _welcome_sign() -> void:
	var pos := shore(0.0, 22.0)
	var node := Node3D.new()
	node.position = Vector3(pos.x, LAND_Y, pos.z)
	add_child(node)
	node.look_at(Vector3(0, LAND_Y, 0), Vector3.UP, true)
	var wood := _mat(Color(0.3, 0.19, 0.13))
	for x in [-2.6, 2.6]:
		_box(node, Vector3(x, 3.5, 0), Vector3(0.34, 7.0, 0.34), wood)
	_box(node, Vector3(0, 5.5, 0.05), Vector3(6.6, 2.3, 0.2), _mat(Color(0.42, 0.28, 0.2)))
	_box(node, Vector3(0, 6.75, 0.05), Vector3(6.9, 0.25, 0.55), _mat(Color(0.88, 0.94, 1.0)))
	var t := Label3D.new()
	t.text = "HUSH LAKE"
	t.font_size = 96
	t.pixel_size = 0.015
	t.outline_size = 14
	t.modulate = Color(1.0, 0.9, 0.7)
	t.position = Vector3(0, 5.8, 0.2)
	node.add_child(t)
	var t2 := Label3D.new()
	t2.text = "population: 1 (and a great many fish)"
	t2.font_size = 40
	t2.pixel_size = 0.0085
	t2.outline_size = 8
	t2.modulate = Color(0.9, 0.9, 1.0)
	t2.position = Vector3(0, 4.8, 0.2)
	node.add_child(t2)
	obstacles.append(Vector3(pos.x, pos.z, 3.2))

func _lighthouse() -> void:
	# on a far headland: the beacon you can see from anywhere on the lake
	var pos := bearing_pos(150.0, LIGHTHOUSE_R)
	var base_y := ground_h(pos.x, pos.z)
	var node := Node3D.new()
	node.position = Vector3(pos.x, base_y - 1.0, pos.z)
	add_child(node)
	var white := _mat(Color(0.92, 0.9, 0.98))
	var red := _mat(Color(0.75, 0.25, 0.25))
	for i in 5:
		var cm := CylinderMesh.new()
		cm.bottom_radius = 3.6 - i * 0.45
		cm.top_radius = 3.6 - (i + 1) * 0.45
		cm.height = 5.0
		cm.radial_segments = 8
		_mesh(node, cm, red if i % 2 == 0 else white, Vector3(0, 2.5 + i * 5.0, 0))
	_box(node, Vector3(0, 25.4, 0), Vector3(5.2, 0.5, 5.2), _mat(Color(0.2, 0.2, 0.28)))
	var lamp := _mat(Color(1.0, 0.85, 0.5), 3.0)
	_box(node, Vector3(0, 27.0, 0), Vector3(2.2, 2.6, 2.2), lamp)
	var cap := PrismMesh.new()
	cap.size = Vector3(3.6, 2.0, 3.6)
	_mesh(node, cap, _mat(Color(0.2, 0.2, 0.3)), Vector3(0, 29.3, 0))
	glow_mats.append([lamp, 2.0, 6.0])
	beacon_light = OmniLight3D.new()
	beacon_light.position = Vector3(0, 27.0, 0)
	beacon_light.omni_range = 70.0
	beacon_light.light_color = Color(1.0, 0.85, 0.55)
	beacon_light.light_energy = 0.0
	node.add_child(beacon_light)
	beam = Node3D.new()
	beam.position = Vector3(0, 27.0, 0)
	node.add_child(beam)
	beam_mat = StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_mat.albedo_color = Color(1.0, 0.9, 0.6, 0.0)
	for sgn in [-1, 1]:
		var bx := _box(beam, Vector3(0, 0, 60.0 * sgn), Vector3(3.0, 3.0, 120.0), beam_mat)
		bx.scale = Vector3(1, 1, 1)

func _village() -> void:
	# Kestrel Landing: a far shore settlement. Seen only as lit windows across the lake, mostly at night.
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var win := _mat(Color(1.0, 0.72, 0.3), 1.0)
	glow_mats.append([win, 0.8, 4.0])
	for i in 8:
		var pos := bearing_pos(-128.0 + rng.randf_range(-9.0, 9.0), VILLAGE_R + rng.randf_range(-18.0, 18.0))
		var y := ground_h(pos.x, pos.z) - 0.3
		var node := Node3D.new()
		node.position = Vector3(pos.x, y, pos.z)
		node.rotation.y = rng.randf() * TAU
		add_child(node)
		var w := rng.randf_range(3.2, 4.6)
		_box(node, Vector3(0, 1.3, 0), Vector3(w, 2.6, 3.0), _mat(Color(0.3, 0.2, 0.28).lerp(Color(0.5, 0.3, 0.3), rng.randf())))
		var roof := PrismMesh.new()
		roof.size = Vector3(w + 0.5, 1.4, 3.5)
		_mesh(node, roof, _mat(Color(0.2, 0.2, 0.34)), Vector3(0, 3.3, 0))
		_box(node, Vector3(0, 1.5, 1.52), Vector3(0.9, 0.8, 0.06), win)
		_box(node, Vector3(w * 0.3, 4.1, -0.5), Vector3(0.5, 1.4, 0.5), _mat(Color(0.3, 0.22, 0.2)))

# ---------- shop stalls ----------
func decorate_stall(s: Node3D, id: String) -> void:
	# s is the sign board node, facing the lake (+Z toward the centre); its local origin is the board centre
	var gy := -0.05 - s.position.y            # local y of the ice
	var wood := _mat(Color(0.3, 0.19, 0.13))
	var snow := _mat(Color(0.88, 0.94, 1.0), 0.3)
	var lamp := _mat(Color(1.0, 0.72, 0.3), 1.4)
	glow_mats.append([lamp, 1.4, 3.5])
	for x in [-2.0, 2.0]:
		_box(s, Vector3(x, (gy + 1.2) * 0.5, 0.0), Vector3(0.2, 1.2 - gy, 0.2), wood)
	var roof := _box(s, Vector3(0, 1.25, 0.3), Vector3(4.6, 0.14, 2.8), wood)
	roof.rotation.x = -0.12
	var cap := _box(s, Vector3(0, 1.38, 0.3), Vector3(4.7, 0.12, 2.9), snow)
	cap.rotation.x = -0.12
	_box(s, Vector3(0, gy + 0.45, 1.1), Vector3(3.4, 0.9, 0.7), wood)
	_box(s, Vector3(2.0, 1.0, 0.5), Vector3(0.22, 0.34, 0.22), lamp)
	var pad := CylinderMesh.new()
	pad.top_radius = 3.4
	pad.bottom_radius = 3.6
	pad.height = 0.12
	pad.radial_segments = 16
	_mesh(s, pad, snow, Vector3(0, gy + 0.04, 0.5))
	var dark := _mat(Color(0.16, 0.14, 0.22))
	var iron := _mat(Color(0.3, 0.3, 0.36))
	# the sign board gets a wooden frame, a lit lamp underneath and a darker kick-plate at the bottom
	for fy in [-0.9, 0.9]:
		_box(s, Vector3(0, fy, 0.02), Vector3(3.6, 0.13, 0.22), wood)
	for fx in [-1.75, 1.75]:
		_box(s, Vector3(fx, 0, 0.02), Vector3(0.13, 1.85, 0.22), wood)
	_box(s, Vector3(0, 0.0, 0.085), Vector3(3.3, 0.02, 0.03), _mat(Color(1.0, 0.78, 0.35), 0.6))   # a thin amber rule under the name
	match id:
		"bucket":
			for k in 4:
				var cm := CylinderMesh.new()
				cm.top_radius = 0.38
				cm.bottom_radius = 0.34
				cm.height = 0.8
				cm.radial_segments = 8
				_mesh(s, cm, wood, Vector3(-3.0 - (k % 2) * 0.8, gy + 0.4, -0.4 + floorf(k / 2.0) * 0.9))
		"bait":
			_box(s, Vector3(3.4, gy + 0.9, -1.0), Vector3(1.8, 1.8, 1.6), wood)
			var rp := PrismMesh.new()
			rp.size = Vector3(2.1, 0.8, 1.9)
			_mesh(s, rp, _mat(Color(0.2, 0.2, 0.32)), Vector3(3.4, gy + 2.2, -1.0))
			for k in 4:
				_box(s, Vector3(-2.6 + k * 0.4, 1.0, 0.4), Vector3(0.1, 0.5, 0.04), _mat(Color(0.7, 0.8, 0.9)))
		"boots":
			_box(s, Vector3(-3.0, gy + 1.0, -0.2), Vector3(2.4, 0.1, 0.1), wood)
			for x in [-4.0, -2.0]:
				_box(s, Vector3(x, gy + 0.5, -0.2), Vector3(0.12, 1.0, 0.12), wood)
			for k in 5:
				_box(s, Vector3(-3.9 + k * 0.45, gy + 0.65, -0.2), Vector3(0.2, 0.5, 0.3), dark)
		"drill":
			var shaft := CylinderMesh.new()
			shaft.top_radius = 0.1
			shaft.bottom_radius = 0.1
			shaft.height = 3.0
			_mesh(s, shaft, iron, Vector3(3.2, gy + 1.5, -0.4))
			for k in 6:
				_box(s, Vector3(3.2, gy + 0.5 + k * 0.4, -0.4), Vector3(0.6, 0.06, 0.2), _mat(Color(0.95, 0.55, 0.2))).rotation.y = k * 1.0
			_box(s, Vector3(-3.0, gy + 0.5, -0.5), Vector3(1.4, 1.0, 0.9), wood)
		"market":
			for k in 6:
				var stripe := _box(s, Vector3(-2.0 + k * 0.8, 1.31, 0.3), Vector3(0.8, 0.06, 2.9), _mat(Color(0.8, 0.25, 0.25) if k % 2 == 0 else Color(0.95, 0.9, 0.85)))
				stripe.rotation.x = -0.12
			for k in 3:
				_box(s, Vector3(-3.2 + k * 0.75, gy + 0.3 + (k % 2) * 0.3, 0.2), Vector3(0.65, 0.6 + (k % 2) * 0.6, 0.65), wood)
		"lines":
			for k in 4:
				var rod := _box(s, Vector3(3.0 + k * 0.45, gy + 1.5, -0.6), Vector3(0.05, 3.0, 0.05), _mat(Color(0.45, 0.3, 0.2)))
				rod.rotation.z = 0.15 - k * 0.1
		"sonar":
			_box(s, Vector3(3.4, gy + 3.0, -1.0), Vector3(0.18, 6.0, 0.18), iron)
			var dish := SphereMesh.new()
			dish.radius = 0.8
			dish.height = 1.0
			var dm := _mesh(s, dish, iron, Vector3(3.4, gy + 5.6, -1.0))
			dm.rotation.z = 0.5
			var blink := _mat(Color(1.0, 0.25, 0.2), 3.0)
			_box(s, Vector3(3.4, gy + 6.2, -1.0), Vector3(0.3, 0.3, 0.3), blink)
			blinkers.append(blink)
		"wide":
			var bit := _cone(s, Vector3(3.4, gy, -0.8), 1.1, 4.0, 8, _mat(Color(0.7, 0.72, 0.8)))
			bit.rotation.z = 0.0
			for k in 4:
				var ring := CylinderMesh.new()
				ring.top_radius = 1.0 - k * 0.2
				ring.bottom_radius = 1.0 - k * 0.2
				ring.height = 0.08
				_mesh(s, ring, _mat(Color(0.95, 0.55, 0.2)), Vector3(3.4, gy + 0.6 + k * 0.8, -0.8))
		"snowmobile":
			var orange := _mat(Color(0.95, 0.5, 0.12))
			_box(s, Vector3(3.5, gy + 0.55, -0.8), Vector3(2.6, 0.7, 1.1), orange)
			_box(s, Vector3(4.6, gy + 0.8, -0.8), Vector3(0.9, 0.4, 0.9), orange)
			_box(s, Vector3(2.6, gy + 0.98, -0.8), Vector3(1.0, 0.18, 0.7), dark)
			var wsh := _box(s, Vector3(4.2, gy + 1.2, -0.8), Vector3(0.05, 0.5, 0.8), _mat(Color(0.75, 0.92, 1.0, 0.45)))
			wsh.rotation.z = -0.4
			for sz in [-0.35, -1.25]:
				_box(s, Vector3(3.7, gy + 0.12, sz), Vector3(3.2, 0.08, 0.2), iron)
			_box(s, Vector3(5.0, gy + 0.55, -0.8), Vector3(0.1, 0.18, 0.4), _mat(Color(1.0, 0.92, 0.6), 3.0))
			_box(s, Vector3(1.0, gy + 0.3, -0.8), Vector3(1.6, 0.5, 1.0), wood)   # the sled behind it
		"kick":
			for k in 3:   # a rack of shove boards and a heavy boot to try
				_box(s, Vector3(3.0 + k * 0.5, gy + 0.6, -0.6), Vector3(0.12, 1.2, 0.9), wood)
			_box(s, Vector3(3.5, gy + 1.25, -0.6), Vector3(1.4, 0.08, 1.0), iron)
			_box(s, Vector3(-3.2, gy + 0.25, -0.5), Vector3(0.9, 0.5, 0.4), dark)
			_box(s, Vector3(-3.2, gy + 0.55, -0.6), Vector3(0.5, 0.5, 0.3), dark)
		"conveyor":
			var gear := CylinderMesh.new()
			gear.top_radius = 1.3
			gear.bottom_radius = 1.3
			gear.height = 0.3
			gear.radial_segments = 10
			var gm := _mesh(s, gear, _mat(Color(0.7, 0.35, 0.18)), Vector3(3.4, gy + 1.6, -0.8))
			gm.rotation.x = PI * 0.5
			spinners.append(gm)
			_box(s, Vector3(3.4, gy + 0.6, -0.8), Vector3(0.4, 1.2, 0.4), iron)
			for k in 5:
				_box(s, Vector3(-2.2 - k * 0.7, gy + 0.2, 0.8), Vector3(0.6, 0.12, 0.5), dark)
	obstacles.append(Vector3(s.position.x, s.position.z, 2.8))

# ---------- shore lanterns: one per sector, lit as you clear them ----------
func place_lanterns(bearings: Array) -> void:
	# bearings: degrees of each sector's direction from the lake centre. Spread them so they never overlap or crowd the hut.
	var b: Array = bearings.duplicate()
	var order := range(b.size())
	order.sort_custom(func(i, j): return b[i] < b[j])
	var sorted: Array = order.map(func(i): return b[i])
	var gap := 360.0 / (b.size() + 3.0)
	for pass_i in 60:
		for k in sorted.size():
			var nxt: int = (k + 1) % sorted.size()
			var d: float = fposmod(sorted[nxt] - sorted[k], 360.0)
			if d < gap:
				sorted[k] -= (gap - d) * 0.25
				sorted[nxt] += (gap - d) * 0.25
		for k in sorted.size():  # keep clear of the hut at -45 deg
			var hd: float = fposmod(sorted[k] + 45.0 + 180.0, 360.0) - 180.0
			if absf(hd) < 9.0:
				sorted[k] += (9.0 if hd >= 0.0 else -9.0) - hd
	var slot := {}
	for k in order.size():
		slot[order[k]] = sorted[k]
	lanterns.clear()
	lanterns.resize(b.size())
	for i in b.size():
		var pos := bearing_pos(slot[i], edge_at_bearing(deg_to_rad(slot[i])) + 3.3)
		var node := Node3D.new()
		node.position = Vector3(pos.x, LAND_Y, pos.z)
		add_child(node)
		_box(node, Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), _mat(Color(0.2, 0.17, 0.2)))
		var lm := _mat(Color(0.16, 0.17, 0.26))
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.75, 0.35)
		lm.emission_energy_multiplier = 0.0
		_box(node, Vector3(0, 3.0, 0), Vector3(0.5, 0.6, 0.5), lm)
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.0, 0)
		light.light_color = Color(1.0, 0.75, 0.4)
		light.omni_range = 7.0
		light.light_energy = 0.0
		light.visible = false
		node.add_child(light)
		lanterns[i] = {"mat": lm, "light": light, "on": false}

func set_lantern(i: int, on: bool) -> void:
	if i < 0 or i >= lanterns.size() or lanterns[i].on == on:
		return
	lanterns[i].on = on
	var lm: StandardMaterial3D = lanterns[i].mat
	lm.emission_energy_multiplier = 3.0 if on else 0.0
	lm.albedo_color = Color(1.0, 0.85, 0.5) if on else Color(0.16, 0.17, 0.26)
	lanterns[i].light.visible = on
	lanterns[i].light.light_energy = 1.4 if on else 0.0

## Olga: she breathes, her head follows you when you are near, and she waves when you come close.
func animate_olga(pos: Vector3) -> void:
	if olga.is_empty():
		return
	var root: Node3D = olga.root
	var body: Node3D = olga.body
	var head: Node3D = olga.head
	var arm: Node3D = olga.arm
	body.scale = Vector3(1.0, 1.0 + sin(_time * 1.7) * 0.012, 1.0)
	var to := root.to_local(pos)
	var dist := Vector2(to.x, to.z).length()
	var want := clampf(atan2(to.x, to.z), -1.0, 1.0) if dist < 24.0 else 0.0
	head.rotation.y = lerp_angle(head.rotation.y, want, 0.08)
	head.rotation.x = lerpf(head.rotation.x, 0.0 if dist > 6.0 else -0.1, 0.08)
	var near := dist < 12.0
	if near:
		arm.rotation_degrees.z = lerpf(arm.rotation_degrees.z, 150.0 + sin(_time * 7.0) * 14.0, 0.12)
	else:
		arm.rotation_degrees.z = lerpf(arm.rotation_degrees.z, 14.0, 0.1)

func follow(pos: Vector3) -> void:
	animate_olga(pos)
	if snow_node:
		snow_node.global_position = Vector3(pos.x, 14.0, pos.z)
