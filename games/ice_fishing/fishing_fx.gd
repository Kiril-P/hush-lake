class_name FishingFX
extends RefCounted
## Little pieces of water: expanding ripples and splash droplets, spawned at a point and cleaned up on their own.

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float a = 1.0;
uniform vec3 c = vec3(0.7, 0.95, 1.0);
void fragment() { ALBEDO = c * a; ALPHA = 1.0; }
"""

static var _ring_mesh: ArrayMesh
static var _ring_shader: Shader
static var _drop_mesh: SphereMesh
static var _drop_mat: StandardMaterial3D

static func _ring() -> ArrayMesh:
	if _ring_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := 40
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var p0 := Vector3(sin(a0) * 0.86, 0, -cos(a0) * 0.86)
			var p1 := Vector3(sin(a0), 0, -cos(a0))
			var p2 := Vector3(sin(a1) * 0.86, 0, -cos(a1) * 0.86)
			var p3 := Vector3(sin(a1), 0, -cos(a1))
			for v in [p0, p1, p2, p2, p1, p3]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
		_ring_mesh = st.commit()
		_ring_shader = Shader.new()
		_ring_shader.code = RING_SHADER
	return _ring_mesh

## An expanding ring on the water. `pos` is local to `parent`.
static func ripple(parent: Node3D, pos: Vector3, radius: float, color := Color(0.7, 0.95, 1.0), dur := 0.9, power := 0.8) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _ring()
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	m.set_shader_parameter("c", Vector3(color.r, color.g, color.b))
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(0.1, 1, 0.1)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_method(func(k: float):
		var r := lerpf(0.1, radius, 1.0 - pow(1.0 - k, 2.0))
		mi.scale = Vector3(r, 1, r)
		m.set_shader_parameter("a", (1.0 - k) * power), 0.0, 1.0, dur)
	tw.tween_callback(mi.queue_free)

static var _snow_mesh: SphereMesh
static var _snow_mat: StandardMaterial3D
static var _snow_ramp: Gradient

## A puff of powder snow: soft white specks that billow up and settle (landings, kicks, sliding fish).
static func snow_puff(parent: Node3D, pos: Vector3, amount := 6, power := 1.0, size := 0.14) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if _snow_mesh == null:
		_snow_mesh = SphereMesh.new()
		_snow_mesh.radius = 0.5
		_snow_mesh.height = 1.0
		_snow_mesh.radial_segments = 6
		_snow_mesh.rings = 3
		_snow_mat = StandardMaterial3D.new()
		_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_snow_mat.vertex_color_use_as_albedo = true
		_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_snow_ramp = Gradient.new()
		_snow_ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		_snow_ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.96, 0.99, 1.0, 0.8), Color(0.88, 0.95, 1.0, 0.0)])
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = amount
	pt.lifetime = 0.8
	pt.explosiveness = 0.95
	pt.direction = Vector3.UP
	pt.spread = 75.0
	pt.initial_velocity_min = 0.5 * power
	pt.initial_velocity_max = 1.7 * power
	pt.gravity = Vector3(0, -1.6, 0)
	pt.damping_min = 1.0
	pt.damping_max = 2.5
	pt.scale_amount_min = 0.6 * size
	pt.scale_amount_max = 1.5 * size
	pt.color_ramp = _snow_ramp
	pt.mesh = _snow_mesh
	pt.material_override = _snow_mat
	pt.local_coords = false
	pt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pt)
	pt.global_position = pos
	pt.emitting = true
	pt.create_tween().tween_callback(pt.queue_free).set_delay(1.3)

## A burst of droplets thrown up from the water.
static func splash(parent: Node3D, pos: Vector3, amount := 14, power := 1.0, color := Color(0.8, 0.94, 1.0)) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.5
		_drop_mesh.height = 1.0
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
		_drop_mat = StandardMaterial3D.new()
		_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drop_mat.vertex_color_use_as_albedo = true
		_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_drop_mesh.material = _drop_mat
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var p := CPUParticles3D.new()
	p.mesh = _drop_mesh
	p.amount = amount
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 32.0
	p.initial_velocity_min = 2.0 * power
	p.initial_velocity_max = 4.6 * power
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.15
	p.color = color
	p.color_ramp = fade
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.emitting = true
	p.create_tween().tween_callback(p.queue_free).set_delay(1.3)

## A short vertical shaft of light above `pos` (world space child of `parent`), for rare catches.
static func beam(parent: Node3D, pos: Vector3, color: Color, height := 6.0, dur := 0.9) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.18
	cm.bottom_radius = 0.5
	cm.height = height
	cm.radial_segments = 12
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos + Vector3(0, height * 0.5, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_property(mi, "scale", Vector3(0.3, 1.25, 0.3), dur).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(mi.queue_free)
