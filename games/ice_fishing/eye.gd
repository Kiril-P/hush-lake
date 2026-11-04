extends Node3D
## The Eye of Hush Lake: a living thing under the ice.
##
## Layers (top to bottom): frosted eyelids (a shader that closes and opens), a fibrous iris with a gold
## collarette, an open pupil hole, a swirling funnel, and a dark inner pupil that follows you.
## Around it: ice petals that flex, crystals that grow with every stage, a light shaft, drifting motes.
##
## Interaction hooks for the game:
##   set_stage / stage_up   how awake it is (lids, warmth, crystals)
##   catch(color, weight)   a fish went in: gulp, ripple, flare, sparks (throttled, safe to spam from belts)
##   landing_point(from)    where a thrown fish should enter the pupil
##   set_offering(on, pos)  show an amber "feed here" marker on the iris toward the player
##   look(pp, delta)        the inner pupil tracks the player

const EYE_R := 10.0
const PUPIL_R := 4.8
const FUNNEL_H := 8.6
const CORE_Y := -2.0
const CORE_R := 3.45

const NOISE_GLSL := """
float h21(vec2 p){ p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vn(vec2 p){
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
"""

const IRIS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float t = 0.0;
uniform float glow = 0.5;
uniform float warmth = 0.0;
uniform float lid = 0.0;
uniform float wave = -1.0;
uniform float wave_amp = 0.0;
uniform float flare = 0.0;
uniform float r_in = 4.8;
uniform float r_out = 10.0;
uniform vec3 c_deep = vec3(0.03, 0.24, 0.42);
uniform vec3 c_mid = vec3(0.09, 0.56, 0.72);
uniform vec3 c_rim = vec3(0.45, 0.88, 0.95);
uniform vec3 c_gold = vec3(1.0, 0.78, 0.35);
uniform vec3 c_lid = vec3(0.50, 0.72, 0.94);
varying vec2 lp;
%s
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp);
	vec2 dir = lp / max(r, 0.001);
	float u = clamp((r - r_in) / (r_out - r_in), 0.0, 1.0);
	float fib = vn(dir * 24.0 + vec2(u * 0.7, t * 0.02));
	float fib2 = vn(dir * 9.0 + vec2(u * 0.5 + 3.0, -t * 0.03));
	vec3 col = mix(c_deep, c_mid, smoothstep(0.0, 0.5, u));
	col = mix(col, c_rim, smoothstep(0.6, 1.0, u) * 0.85);
	col *= 0.62 + 0.75 * fib;
	col += c_gold * pow(fib2, 3.0) * (0.04 + 0.9 * warmth) * (1.0 - u);
	float cw = 0.035 + 0.055 * warmth;
	float ring = exp(-pow((u - 0.11) / cw, 2.0));
	col = mix(col, c_gold, ring * (0.2 + 0.7 * warmth));
	col += c_gold * exp(-pow(u / 0.03, 2.0)) * 0.95;
	col *= 1.0 - 0.35 * exp(-pow((u - 0.9) / 0.03, 2.0));
	float tw = vn(lp * 3.0 + vec2(t * 0.6, -t * 0.4));
	col += vec3(1.0) * smoothstep(0.88, 0.98, tw) * 0.18 * u;
	float w = wave >= 0.0 ? exp(-pow((u - (1.0 - wave)) / 0.09, 2.0)) * wave_amp : 0.0;
	col += mix(c_rim, c_gold, 0.45) * w;
	col *= 0.62 + glow * 0.38 + flare * 0.45;
	// eyelids: frosted ice that closes from the top and bottom
	float x = lp.x / r_out;
	float thr = r_out * (1.25 - 1.25 * lid) * (1.0 - 0.5 * x * x * lid);
	float cover = lid > 0.002 ? smoothstep(thr - 0.3, thr + 0.1, abs(lp.y)) : 0.0;
	float edge = lid > 0.002 ? exp(-pow((abs(lp.y) - thr) / 0.16, 2.0)) : 0.0;
	float frost = vn(lp * 2.3) * 0.5 + vn(lp * 6.0) * 0.25;
	float vein = smoothstep(0.93, 1.0, 1.0 - abs(vn(lp * 1.1 + 4.0) - 0.5) * 2.0);
	float lash = 0.5 + 0.5 * sin(lp.x * 6.0);
	vec3 lidcol = c_lid * (0.5 + frost * 0.4) + vec3(0.7, 0.9, 1.0) * vein * 0.35 + c_gold * edge * (0.5 + 0.5 * lash);
	float a_outer = 1.0 - smoothstep(r_out - 0.3, r_out + 0.5, r);
	float a_pupil = smoothstep(r_in - 0.12, r_in + 0.04, r);
	ALBEDO = mix(col, lidcol, cover * 0.96);
	ALPHA = a_outer * mix(a_pupil, 1.0, cover);
}
""" % NOISE_GLSL

const FUNNEL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float t = 0.0;
uniform float glow = 0.5;
uniform float h = 8.6;
uniform vec3 c_a = vec3(0.0, 0.02, 0.06);
uniform vec3 c_b = vec3(0.06, 0.62, 0.74);
uniform vec3 c_g = vec3(1.0, 0.78, 0.35);
varying vec2 xz;
varying float depth;
void vertex() { xz = VERTEX.xz; depth = clamp(0.5 - VERTEX.y / h, 0.0, 1.0); }
void fragment() {
	float a = atan(xz.y, xz.x);
	float s = 0.5 + 0.5 * sin(a * 4.0 + depth * 11.0 - t * 1.3);
	float band = smoothstep(0.55, 0.95, s);
	float fine = 0.5 + 0.5 * sin(a * 11.0 - depth * 17.0 + t * 0.8);
	vec3 col = mix(c_a, c_b * 0.55, band * (0.1 + 0.6 * depth) * (0.4 + glow));
	col += c_b * fine * 0.06 * depth;
	col += c_g * pow(depth, 7.0) * (0.25 + glow * 0.6);
	ALBEDO = col;
}
"""

const CORE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
uniform float t = 0.0;
uniform float glow = 0.5;
uniform float flare = 0.0;
uniform float R = 3.0;
uniform vec3 c_gold = vec3(1.0, 0.78, 0.35);
uniform vec3 c_aqua = vec3(0.3, 0.95, 0.9);
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp) / R;
	vec3 col = vec3(0.0, 0.008, 0.03);
	float rim = smoothstep(0.5, 1.0, r);
	col += mix(c_aqua, c_gold, 0.3 + 0.3 * sin(t * 0.8)) * rim * rim * (0.55 + glow * 0.9 + flare * 0.8);
	float sp = 1.0 - smoothstep(0.06, 0.15, length(lp / R - vec2(-0.3, -0.28)));
	col += vec3(1.0) * sp * 0.85;
	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.94, 1.0, r);
}
"""

const SHAFT_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float amount = 0.3;
uniform float t = 0.0;
uniform float H = 34.0;
uniform vec3 c = vec3(0.35, 0.95, 0.9);
varying vec2 xz;
varying float hh;
void vertex() { xz = VERTEX.xz; hh = clamp((VERTEX.y + H * 0.5) / H, 0.0, 1.0); }
void fragment() {
	float a = atan(xz.y, xz.x);
	float streak = 0.55 + 0.45 * sin(a * 7.0 + t * 0.5 + hh * 4.0) * sin(a * 3.0 - t * 0.3);
	float fade = pow(1.0 - hh, 2.4);
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = c * streak * fade * amount * (0.25 + 0.75 * face);
	ALPHA = 1.0;
}
"""

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float a = 1.0;
uniform vec3 c = vec3(0.5, 1.0, 0.95);
void fragment() { ALBEDO = c * a; ALPHA = 1.0; }
"""

const MARKER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float a = 0.0;
uniform float t = 0.0;
uniform vec3 c = vec3(1.0, 0.78, 0.35);
varying vec2 lp;
void vertex() { lp = VERTEX.xz; }
void fragment() {
	float r = length(lp);
	float ang = abs(atan(lp.x, -lp.y)) / 0.42;
	float chev = 0.5 + 0.5 * sin((r + ang * 0.9) * 3.4 + t * 5.0);
	float side = 1.0 - smoothstep(0.6, 1.0, ang);
	float rad = smoothstep(4.3, 5.2, r) * (1.0 - smoothstep(8.2, 9.3, r));
	ALBEDO = c * a * side * rad * (0.3 + 0.7 * chev);
	ALPHA = 1.0;
}
"""

var t := 0.0
var glow := 0.4
var open := 0.0
var warmth := 0.0
var night := 0.0
var stage := 0
var flare := 0.0
var flinch := 0.0
var core_pulse := 0.0
var wave := -1.0
var wave_amp := 0.0
var wave_cd := 0.0
var ripple_cd := 0.0
var spark_cd := 0.0
var blink_k := 0.0
var blink_t := 5.0
var gaze := Vector2.ZERO
var offer_on := false
var offer_a := 0.0
var offer_bearing := 0.0
var ripples_live := 0
var hush := 0.0          # 0..1: the Eye holds its breath before waking (lids shut, glow low)
var hush_target := 0.0

var iris_mat: ShaderMaterial
var funnel_mat: ShaderMaterial
var core_mat: ShaderMaterial
var shaft_mat: ShaderMaterial
var marker_mat: ShaderMaterial
var ring_mesh: ArrayMesh
var core: MeshInstance3D
var marker: MeshInstance3D
var petals: Array = []
var crystals: Array = []   # one Array of Node3D per stage
var crystal_mats: Array[StandardMaterial3D] = []
var petal_mat: StandardMaterial3D
var top_light: OmniLight3D
var deep_light: OmniLight3D
var motes: CPUParticles3D
var sparks: CPUParticles3D

func _ready() -> void:
	_build_iris()
	_build_depths()
	_build_petals()
	_build_crystals()
	_build_shaft()
	_build_particles()
	_build_marker()
	top_light = OmniLight3D.new()
	top_light.position = Vector3(0, 3.0, 0)
	top_light.omni_range = 26.0
	top_light.light_color = Color(0.45, 0.95, 0.95)
	add_child(top_light)
	deep_light = OmniLight3D.new()
	deep_light.position = Vector3(0, -5.0, 0)
	deep_light.omni_range = 14.0
	deep_light.light_color = Color(1.0, 0.75, 0.35)
	add_child(deep_light)
	ring_mesh = _annulus(0.9, 1.0, 64)
	_apply_uniforms()

# ---------- construction ----------
func _shader_mat(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _annulus(r_in: float, r_out: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in segs:
		var a0 := TAU * j / segs
		var a1 := TAU * (j + 1) / segs
		var p0 := Vector3(sin(a0) * r_in, 0, -cos(a0) * r_in)
		var p1 := Vector3(sin(a0) * r_out, 0, -cos(a0) * r_out)
		var p2 := Vector3(sin(a1) * r_in, 0, -cos(a1) * r_in)
		var p3 := Vector3(sin(a1) * r_out, 0, -cos(a1) * r_out)
		for v in [p0, p1, p2, p2, p1, p3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()

func _disc(radius: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	for k in rings:
		var r0 := radius * float(k) / rings
		var r1 := radius * float(k + 1) / rings
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var p0 := Vector3(sin(a0) * r0, 0, -cos(a0) * r0)
			var p1 := Vector3(sin(a0) * r1, 0, -cos(a0) * r1)
			var p2 := Vector3(sin(a1) * r0, 0, -cos(a1) * r0)
			var p3 := Vector3(sin(a1) * r1, 0, -cos(a1) * r1)
			for v in [p0, p1, p2, p2, p1, p3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	return st.commit()

func _build_iris() -> void:
	iris_mat = _shader_mat(IRIS_SHADER)
	iris_mat.render_priority = 2
	var mi := MeshInstance3D.new()
	mi.mesh = _disc(EYE_R + 0.7, 96)
	mi.material_override = iris_mat
	mi.position = Vector3(0, 0.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_depths() -> void:
	var fn := CylinderMesh.new()
	fn.top_radius = PUPIL_R + 0.1
	fn.bottom_radius = 0.9
	fn.height = FUNNEL_H
	fn.radial_segments = 48
	fn.cap_top = false
	fn.cap_bottom = false
	funnel_mat = _shader_mat(FUNNEL_SHADER)
	var fi := MeshInstance3D.new()
	fi.mesh = fn
	fi.material_override = funnel_mat
	fi.position = Vector3(0, -FUNNEL_H * 0.5, 0)
	fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fi)
	core_mat = _shader_mat(CORE_SHADER)
	core = MeshInstance3D.new()
	core.mesh = _disc(CORE_R, 48)
	core.material_override = core_mat
	core.position = Vector3(0, CORE_Y, 0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

func _petal_mesh(length: float, width: float, thick: float) -> ArrayMesh:
	var A := Vector3(0, thick * 0.55, -length)
	var B := Vector3(-width, thick * 0.4, -length * 0.3)
	var C := Vector3(width, thick * 0.4, -length * 0.3)
	var D := Vector3(0, thick, 0.5)
	var A2 := Vector3(0, 0, -length)
	var B2 := Vector3(-width, 0, -length * 0.3)
	var C2 := Vector3(width, 0, -length * 0.3)
	var D2 := Vector3(0, 0, 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[A, B, D], [A, D, C], [A2, D2, B2], [A2, C2, D2], [A, A2, B], [B, A2, B2], [A, C, A2], [C, C2, A2], [B, B2, D], [D, B2, D2], [C, D, C2], [D, D2, C2]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _build_petals() -> void:
	petal_mat = StandardMaterial3D.new()
	petal_mat.albedo_color = Color(0.78, 0.9, 0.98)
	petal_mat.roughness = 0.78   # matte, like the rest of the low-poly world (they used to be glassy and loud)
	petal_mat.emission_enabled = true
	petal_mat.emission = Color(0.25, 0.8, 0.9)
	petal_mat.emission_energy_multiplier = 0.2
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	petal_mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA   # petals fade out as you walk up to them, so they never wall off the Eye
	petal_mat.distance_fade_min_distance = 2.5
	petal_mat.distance_fade_max_distance = 7.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var rings := [[20, EYE_R + 2.2, 2.6, 0.5], [20, EYE_R + 3.4, 2.2, 0.42]]
	var ri := 0
	for rg in rings:
		var n: int = rg[0]
		for k in n:
			var a := TAU * (float(k) + 0.5 * ri) / n + rng.randf_range(-0.05, 0.05)
			var len: float = rg[2] * rng.randf_range(0.8, 1.25)
			var pivot := Node3D.new()
			pivot.position = Vector3(sin(a) * rg[1], 0.05, -cos(a) * rg[1])
			pivot.rotation = Vector3(0.1, PI - a, 0)
			var mi := MeshInstance3D.new()
			mi.mesh = _petal_mesh(len * 0.62, float(rg[3]) * rng.randf_range(0.8, 1.2), 0.45)
			mi.material_override = petal_mat
			pivot.add_child(mi)
			add_child(pivot)
			petals.append({"pivot": pivot, "ph": rng.randf() * TAU, "ring": ri})
		ri += 1

func _crystal_mesh(h: float, w: float) -> ArrayMesh:
	var sides := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var apex := Vector3(0, h, 0)
	var low := Vector3(0, -w * 0.5, 0)
	var ring := []
	for k in sides:
		var a := TAU * k / sides
		ring.append(Vector3(cos(a) * w, h * 0.22, sin(a) * w))
	for k in sides:
		var k2 := (k + 1) % sides
		for v in [ring[k], apex, ring[k2], ring[k2], low, ring[k]]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()

func _build_crystals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	for g in 5:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.88, 0.96, 0.86)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.5   # matte, like the petals
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.8, 0.95).lerp(Color(1.0, 0.8, 0.45), g * 0.15)
		mat.emission_energy_multiplier = 0.6
		crystal_mats.append(mat)
		var group := []
		# two clusters per stage, each a tall crystal with a shorter one beside it
		for k in 4:
			var cluster := k / 2
			var a := TAU * (0.5 * g + 0.23 * cluster + 0.5 * cluster + rng.randf_range(-0.04, 0.04)) + (k % 2) * 0.09
			var rr := EYE_R + 4.8 + g * 0.9 + (k % 2) * 1.2 + rng.randf_range(0.0, 0.6)
			var h := (rng.randf_range(3.4, 4.2) + g * 0.8) * (1.0 if k % 2 == 0 else 0.6)   # kept under the camp roofline: they used to out-tower the hut
			var node := Node3D.new()
			node.position = Vector3(sin(a) * rr, 0.0, -cos(a) * rr)
			node.rotation = Vector3(rng.randf_range(-0.22, 0.22), rng.randf() * TAU, rng.randf_range(-0.22, 0.22))
			var mi := MeshInstance3D.new()
			mi.mesh = _crystal_mesh(h, h * rng.randf_range(0.2, 0.27))
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
			node.scale = Vector3.ZERO
			node.visible = false
			add_child(node)
			group.append(node)
		crystals.append(group)

func _build_shaft() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 4.6
	cm.height = 34.0
	cm.radial_segments = 40
	cm.cap_top = false
	cm.cap_bottom = false
	shaft_mat = _shader_mat(SHAFT_SHADER)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = shaft_mat
	mi.position = Vector3(0, 17.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _spark_mesh_mat(unshaded_color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = unshaded_color
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _build_particles() -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _spark_mesh_mat(Color(0.6, 1.0, 0.95))
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	motes = CPUParticles3D.new()
	motes.mesh = sm
	motes.amount = 70
	motes.lifetime = 5.5
	motes.preprocess = 5.5
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_height = 0.2
	motes.emission_ring_radius = PUPIL_R * 0.95
	motes.emission_ring_inner_radius = PUPIL_R * 0.35
	motes.direction = Vector3.UP
	motes.spread = 18.0
	motes.initial_velocity_min = 1.2
	motes.initial_velocity_max = 3.0
	motes.gravity = Vector3(0, 0.25, 0)
	motes.scale_amount_min = 0.05
	motes.scale_amount_max = 0.16
	motes.color_ramp = fade
	motes.position = Vector3(0, 0.1, 0)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)
	var sm2 := sm.duplicate() as SphereMesh
	sm2.material = _spark_mesh_mat(Color(1, 1, 1))
	var fade2 := Gradient.new()
	fade2.set_color(0, Color(1, 1, 1, 1))
	fade2.set_color(1, Color(1, 1, 1, 0))
	sparks = CPUParticles3D.new()
	sparks.mesh = sm2
	sparks.amount = 28
	sparks.lifetime = 1.0
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 1.4
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 4.0
	sparks.initial_velocity_max = 9.0
	sparks.gravity = Vector3(0, -7.0, 0)
	sparks.scale_amount_min = 0.08
	sparks.scale_amount_max = 0.2
	sparks.color_ramp = fade2
	sparks.position = Vector3(0, 0.3, 0)
	sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sparks)

func _build_marker() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24
	var half := 0.42
	var r0 := 4.2
	var r1 := 9.4
	for j in segs:
		var a0 := -half + 2.0 * half * j / segs
		var a1 := -half + 2.0 * half * (j + 1) / segs
		var p0 := Vector3(sin(a0) * r0, 0, -cos(a0) * r0)
		var p1 := Vector3(sin(a0) * r1, 0, -cos(a0) * r1)
		var p2 := Vector3(sin(a1) * r0, 0, -cos(a1) * r0)
		var p3 := Vector3(sin(a1) * r1, 0, -cos(a1) * r1)
		for v in [p0, p1, p2, p2, p1, p3]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	marker_mat = _shader_mat(MARKER_SHADER)
	marker_mat.render_priority = 3
	marker = MeshInstance3D.new()
	marker.mesh = st.commit()
	marker.material_override = marker_mat
	marker.position = Vector3(0, 0.09, 0)
	marker.visible = false
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)

# ---------- game-facing API ----------
func set_glow(x: float) -> void:
	glow = clampf(x, 0.0, 1.0)

func set_open(x: float) -> void:
	open = clampf(x, 0.0, 1.0)

func set_night(n: float) -> void:
	night = n

## Instant sync (load / refreeze / screenshots): shows exactly `st` stages of crystals, no fanfare.
func set_stage(st: int) -> void:
	if st == stage and not crystals.is_empty() and crystals[0][0].visible == (st >= 1):
		return
	stage = st
	warmth = float(st) / 5.0
	for g in crystals.size():
		for n in crystals[g]:
			n.visible = g < st
			n.scale = Vector3.ONE if g < st else Vector3.ZERO

## Fanfare: the Eye wakes a little more. Crystals burst out of the ice, a big wave runs through it.
func stage_up(st: int) -> void:
	stage = st
	var g := clampi(st - 1, 0, crystals.size() - 1)
	var i := 0
	for n in crystals[g]:
		n.visible = true
		n.scale = Vector3.ZERO
		var tw := create_tween()
		tw.tween_interval(0.12 * i + 0.25)
		tw.tween_property(n, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	var wt := create_tween()
	wt.tween_property(self, "warmth", float(st) / 5.0, 2.0)
	flare = 1.6
	flinch = 1.0
	core_pulse = 1.0
	wave = 0.0
	wave_amp = 1.6
	_spawn_ripple(2.2)
	create_tween().tween_callback(func(): _spawn_ripple(1.6)).set_delay(0.35)
	create_tween().tween_callback(func(): _spawn_ripple(1.2)).set_delay(0.7)
	_emit_sparks(Color(1.0, 0.85, 0.45), 1.0)

## A fish went in. Safe to call as fast as belts deliver.
func catch(c: Color, weight := 0.3) -> void:
	flare = minf(flare + 0.3 + weight * 0.3, 1.4)
	flinch = minf(flinch + 0.45, 1.0)
	core_pulse = 1.0
	if wave_cd <= 0.0:
		wave = 0.0
		wave_amp = 0.7 + weight * 0.7
		wave_cd = 0.5
	if ripple_cd <= 0.0:
		_spawn_ripple(1.0 + weight)
		ripple_cd = 0.4
	if spark_cd <= 0.0:
		_emit_sparks(c.lerp(Color(0.6, 1.0, 0.95), 0.5), weight)
		spark_cd = 0.14

## A big swallow: a streak milestone. Bigger wave, two ripples, a spray of gold.
func gulp(power := 1.0) -> void:
	flare = 1.5
	flinch = 1.0
	core_pulse = 1.0
	wave = 0.0
	wave_amp = 1.0 + 0.6 * clampf(power, 0.0, 2.0)
	_spawn_ripple(1.4 + power)
	create_tween().tween_callback(func(): _spawn_ripple(1.0 + power * 0.6)).set_delay(0.25)
	_emit_sparks(Color(1.0, 0.88, 0.5), 1.0)

## The long breath before the awakening: lids close, glow drops.
func prelude(on: bool) -> void:
	hush_target = 1.0 if on else 0.0

## THE moment: the lids snap open, the light surges, ripples roll out across the whole lake, the crystals jolt.
func awaken() -> void:
	hush_target = 0.0
	flare = 2.4
	flinch = 1.0
	core_pulse = 1.0
	wave = 0.0
	wave_amp = 2.6
	_spawn_ripple(3.0)
	for pair in [[0.3, 2.2], [0.65, 1.7], [1.0, 1.3]]:
		create_tween().tween_callback(func(): _spawn_ripple(pair[1])).set_delay(pair[0])
	_emit_sparks(Color(1.0, 0.9, 0.55), 1.0)
	create_tween().tween_callback(func(): _emit_sparks(Color(0.7, 1.0, 0.95), 1.0)).set_delay(0.5)
	for g in crystals:
		for n in g:
			if n.visible:
				var tw := create_tween()
				tw.tween_property(n, "scale", Vector3.ONE * 1.3, 0.18).set_trans(Tween.TRANS_SINE)
				tw.tween_property(n, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func landing_point(from: Vector3) -> Vector3:
	var d := Vector2(from.x, from.z)
	d = d.normalized() if d.length() > 0.1 else Vector2(0, 1)
	return Vector3(d.x * PUPIL_R * 0.72, 0.6, d.y * PUPIL_R * 0.72)

## Amber chevrons on the iris pointing at the player: "feed here".
func set_offering(on: bool, from: Vector3) -> void:
	offer_on = on
	if on:
		offer_bearing = atan2(from.x, -from.z)

func look(pp: Vector2, delta: float) -> void:
	var want := Vector2.ZERO
	if pp.length() > 0.5:
		want = pp.normalized() * minf(pp.length() / 28.0, 1.0) * (CORE_R * 0.22)
	gaze = gaze.move_toward(want, delta * 1.4)

# ---------- internals ----------
func _emit_sparks(c: Color, weight: float) -> void:
	sparks.color = c
	sparks.amount = int(18 + 18 * clampf(weight, 0.0, 1.0))
	sparks.restart()
	sparks.emitting = true

func _spawn_ripple(power: float) -> void:
	if ripples_live >= 6 or ring_mesh == null:
		return
	ripples_live += 1
	var mi := MeshInstance3D.new()
	mi.mesh = ring_mesh
	var m := _shader_mat(RING_SHADER)
	m.render_priority = 1
	mi.material_override = m
	mi.position = Vector3(0, 0.07, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var end_r := EYE_R + 7.0 + power * 3.0
	var dur := 1.5 + power * 0.25
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var r := lerpf(PUPIL_R, end_r, 1.0 - pow(1.0 - k, 2.0))
		mi.scale = Vector3(r, 1.0, r)
		m.set_shader_parameter("a", (1.0 - k) * (0.35 + 0.3 * power)), 0.0, 1.0, dur)
	tw.tween_callback(func():
		ripples_live -= 1
		mi.queue_free())

func _blink() -> void:
	var tw := create_tween()
	tw.tween_property(self, "blink_k", 1.0, 0.13).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "blink_k", 0.0, 0.3).set_trans(Tween.TRANS_SINE)
	blink_t = randf_range(6.0, 13.0)

func _lid_amount() -> float:
	var rest := lerpf(0.5, 0.0, clampf(open * 1.3, 0.0, 1.0))
	return clampf(maxf(rest + blink_k * (1.0 - rest), hush), 0.0, 1.0)

func _apply_uniforms() -> void:
	var g := clampf(0.25 + glow * 0.75, 0.0, 1.0) * (1.0 - 0.55 * hush)
	iris_mat.set_shader_parameter("t", t)
	iris_mat.set_shader_parameter("glow", g)
	iris_mat.set_shader_parameter("warmth", warmth)
	iris_mat.set_shader_parameter("lid", _lid_amount())
	iris_mat.set_shader_parameter("wave", wave)
	iris_mat.set_shader_parameter("wave_amp", wave_amp)
	iris_mat.set_shader_parameter("flare", flare)
	funnel_mat.set_shader_parameter("t", t)
	funnel_mat.set_shader_parameter("glow", g + flare * 0.5)
	core_mat.set_shader_parameter("t", t)
	core_mat.set_shader_parameter("glow", g)
	core_mat.set_shader_parameter("flare", flare)
	shaft_mat.set_shader_parameter("t", t)
	shaft_mat.set_shader_parameter("amount", clampf(0.1 + g * 0.3 + open * 0.3 + flare * 0.45, 0.0, 1.3) * (0.14 + night * 1.2))   # by day the shaft is faint: it used to stand behind the crosshair all the time
	marker_mat.set_shader_parameter("t", t)
	marker_mat.set_shader_parameter("a", offer_a * (0.8 + 0.2 * sin(t * 6.0)))

func _process(delta: float) -> void:
	t += delta
	wave_cd = maxf(wave_cd - delta, 0.0)
	ripple_cd = maxf(ripple_cd - delta, 0.0)
	spark_cd = maxf(spark_cd - delta, 0.0)
	if wave >= 0.0:
		wave += delta * 1.15
		if wave > 1.1:
			wave = -1.0
	flare = move_toward(flare, 0.0, delta * 1.5)
	flinch = move_toward(flinch, 0.0, delta * 1.9)
	core_pulse = move_toward(core_pulse, 0.0, delta * 3.0)
	hush = move_toward(hush, hush_target, delta * (0.7 if hush_target > hush else 4.5))
	blink_t -= delta
	if blink_t <= 0.0 and hush <= 0.0:
		_blink()
	offer_a = move_toward(offer_a, 1.0 if offer_on else 0.0, delta * 3.0)
	marker.visible = offer_a > 0.01
	marker.rotation.y = -offer_bearing
	core.position = Vector3(gaze.x, CORE_Y, gaze.y)
	var cs := 1.0 - core_pulse * 0.14
	core.scale = Vector3(cs, 1.0, cs)
	var oe := clampf(open * 1.3, 0.0, 1.0)
	for p in petals:
		var base := lerpf(0.1, 0.26, oe) + (0.12 if p.ring == 1 else 0.0)
		p.pivot.rotation.x = base + flinch * 0.4 + sin(t * 1.1 + p.ph) * 0.025
	petal_mat.emission_energy_multiplier = 0.12 + glow * 0.3 + flare * 0.8
	for m in crystal_mats:
		m.emission_energy_multiplier = 0.5 + glow * 0.5 + flare * 1.0 + night * 0.6
	top_light.light_energy = (0.7 + glow * 1.5 + open * 2.2) * (1.0 + flare * 1.8)
	deep_light.light_energy = (0.8 + glow * 1.2 + open * 1.5) * (1.0 + flare * 1.2)
	motes.speed_scale = 0.7 + glow * 0.8 + flare
	_apply_uniforms()
