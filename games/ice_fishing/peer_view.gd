class_name PeerView
extends Control
## Peering into a hole. Hold C while looking at a hole within arm's reach and a round window opens on the screen: the water under that very tile, with
## its real stock swimming in it (species and shares come from the lake model), junk lying on the bottom, kelp swaying, light shafts from above, and an
## amber glow if the hole is near the Eye. It renders from one shared little world (a SubViewport with its own 3D world), so it costs nothing until
## it is open and a few dozen animated fish while it is.
## Pure helpers (fish_plan) decide what is down there so tests can check it; the rest builds nodes.

const MAX_FISH := 24
const JUNK := ["Old Boot", "Old Coin", "Glass Pearl"]
const FLOOR_Y := -9.0

var viewport: SubViewport
var tex_rect: TextureRect
var world_root: Node3D
var cam: Camera3D
var fish_nodes: Array = []     # {node, r, y, a, speed, wob}
var junk_nodes: Array = []
var kelp: Array = []
var shafts: Array = []
var glow_light: OmniLight3D
var open_amount := 0.0         # 0..1 (the window fades and grows in)
var want_open := false
var near_eye := false
var tile_name := ""
var _t := 0.0
var colors := {}               # species name -> Color (set by the game)

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 640)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	_build_world()
	tex_rect = TextureRect.new()
	tex_rect.texture = viewport.get_texture()
	tex_rect.custom_minimum_size = Vector2(560, 560)
	tex_rect.size = Vector2(560, 560)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float alpha = 1.0;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = 1.0 - smoothstep(0.955, 1.0, r);
	vec4 c = texture(TEXTURE, UV);
	float rim = smoothstep(0.84, 0.965, r);
	c.rgb = mix(c.rgb, vec3(0.78, 0.93, 1.0), rim * 0.85);   // the frosted lip of the hole
	c.rgb *= 1.0 - 0.4 * smoothstep(0.45, 0.9, r);
	COLOR = vec4(c.rgb, a * alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	tex_rect.material = mat
	add_child(tex_rect)

## What is down there: a list of {name, junk: bool} for up to MAX_FISH, drawn in proportion to the tile's stock. Pure and deterministic given the rng.
static func fish_plan(stock: Dictionary, rng: RandomNumberGenerator) -> Array:
	var total := 0
	for k in stock:
		total += int(stock[k])
	var out := []
	if total <= 0:
		return out
	var n := mini(MAX_FISH, total)
	var names: Array = stock.keys()
	var counts := {}
	for k in names:
		counts[k] = int(stock[k])
	for i in n:
		var r := rng.randi() % maxi(total, 1)
		var pick := ""
		for k in names:
			r -= counts[k]
			if r < 0:
				pick = k
				break
		if pick == "":
			pick = names[0]
		counts[pick] -= 1
		total -= 1
		out.append({"name": pick, "junk": JUNK.has(pick)})
		if total <= 0:
			break
	return out

func _build_world() -> void:
	world_root = Node3D.new()
	viewport.add_child(world_root)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.09, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.6, 0.7)
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.2, 0.3)
	env.fog_density = 0.045
	var we := WorldEnvironment.new()
	we.environment = env
	world_root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.6, 0.9, 1.0)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-80, 20, 0)
	world_root.add_child(sun)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.6, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)   # looking straight down the hole
	cam.fov = 78.0
	viewport.add_child(cam)
	cam.current = true
	# the bottom: a sandy disc with a few rocks
	var floor_m := CylinderMesh.new()
	floor_m.top_radius = 12.0
	floor_m.bottom_radius = 12.0
	floor_m.height = 0.4
	floor_m.radial_segments = 24
	var fm := MeshInstance3D.new()
	fm.mesh = floor_m
	fm.position = Vector3(0, FLOOR_Y - 0.2, 0)
	fm.material_override = _mat(Color(0.22, 0.3, 0.3), 0.0)
	world_root.add_child(fm)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var rm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.9), rng.randf_range(0.5, 1.2))
		rm.mesh = bm
		var a := rng.randf() * TAU
		rm.position = Vector3(cos(a) * rng.randf_range(2.0, 9.0), FLOOR_Y + 0.2, sin(a) * rng.randf_range(2.0, 9.0))
		rm.rotation.y = rng.randf() * TAU
		rm.material_override = _mat(Color(0.16, 0.22, 0.24).lerp(Color(0.3, 0.38, 0.38), rng.randf()), 0.0)
		world_root.add_child(rm)
	# kelp: stacked slabs that sway
	for i in 16:
		var a := rng.randf() * TAU
		var d := rng.randf_range(3.0, 10.0)
		var strand := Node3D.new()
		strand.position = Vector3(cos(a) * d, FLOOR_Y, sin(a) * d)
		world_root.add_child(strand)
		var segs := rng.randi_range(4, 7)
		for s in segs:
			var sm := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.14, 0.7, 0.05)
			sm.mesh = b
			sm.position = Vector3(0, 0.35 + s * 0.68, 0)
			sm.material_override = _mat(Color(0.1, 0.38, 0.3).lerp(Color(0.2, 0.6, 0.4), s / 7.0), 0.15)
			strand.add_child(sm)
		kelp.append({"node": strand, "ph": rng.randf() * TAU})
	# slanting shafts of light from the hole
	for i in 4:
		var q := MeshInstance3D.new()
		var qm := BoxMesh.new()
		qm.size = Vector3(0.9, 9.5, 0.04)
		q.mesh = qm
		q.position = Vector3(rng.randf_range(-2.0, 2.0), FLOOR_Y * 0.5, rng.randf_range(-2.0, 2.0))
		q.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * PI, rng.randf_range(-0.15, 0.15))
		var sm2 := StandardMaterial3D.new()
		sm2.albedo_color = Color(0.5, 0.9, 1.0, 0.07)
		sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm2.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		q.material_override = sm2
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world_root.add_child(q)
		shafts.append(q)
	glow_light = OmniLight3D.new()
	glow_light.position = Vector3(0, FLOOR_Y + 2.0, 0)
	glow_light.omni_range = 14.0
	glow_light.light_color = Color(1.0, 0.75, 0.35)
	glow_light.light_energy = 0.0
	world_root.add_child(glow_light)

func _mat(c: Color, emit: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

## Fills the water with what is under this tile and opens the window.
func open(stock: Dictionary, near_eye_in: bool, tile_label := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(stock)) + 7
	clear_life()
	near_eye = near_eye_in
	tile_name = tile_label
	var plan := fish_plan(stock, rng)
	for item in plan:
		var col: Color = colors.get(item.name, Color(0.7, 0.8, 0.9))
		if item.junk:
			var j := FishModel.build(item.name, col, 1.3)
			j.position = Vector3(rng.randf_range(-6.0, 6.0), FLOOR_Y + 0.25, rng.randf_range(-6.0, 6.0))
			j.rotation.y = rng.randf() * TAU
			world_root.add_child(j)
			junk_nodes.append(j)
		else:
			var f := FishModel.build(item.name, col, 1.6)
			world_root.add_child(f)
			fish_nodes.append({"node": f, "r": rng.randf_range(2.0, 8.0), "y": rng.randf_range(FLOOR_Y + 1.2, -1.8), "a": rng.randf() * TAU,
				"speed": rng.randf_range(0.18, 0.5) * (1.0 if rng.randf() < 0.5 else -1.0), "wob": rng.randf() * TAU})
	glow_light.light_energy = 1.6 if near_eye else 0.0
	want_open = true
	visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_place()

func close() -> void:
	want_open = false

func clear_life() -> void:
	for f in fish_nodes:
		(f.node as Node3D).queue_free()
	for j in junk_nodes:
		(j as Node3D).queue_free()
	fish_nodes.clear()
	junk_nodes.clear()

func fish_count() -> int:
	return fish_nodes.size()

func _place() -> void:
	var s := minf(get_viewport_rect().size.y * 0.7, 600.0)
	var grow := lerpf(0.6, 1.0, open_amount)
	tex_rect.size = Vector2(s, s) * grow
	tex_rect.position = get_viewport_rect().size * Vector2(0.5, 0.46) - tex_rect.size * 0.5
	(tex_rect.material as ShaderMaterial).set_shader_parameter("alpha", open_amount)

func update(delta: float) -> void:
	_t += delta
	open_amount = move_toward(open_amount, 1.0 if want_open else 0.0, delta * 4.0)
	if open_amount <= 0.0 and not want_open:
		if visible:
			visible = false
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	for f in fish_nodes:
		f.a += f.speed * delta
		var node: Node3D = f.node
		var p := Vector3(cos(f.a) * f.r, f.y + sin(_t * 0.8 + f.wob) * 0.35, sin(f.a) * f.r)
		node.position = p
		var tangent := Vector3(-sin(f.a), 0.0, cos(f.a)) * signf(f.speed)   # nose along the way it swims
		node.rotation.y = atan2(-tangent.z, tangent.x)
	for k in kelp:
		(k.node as Node3D).rotation.z = sin(_t * 0.9 + k.ph) * 0.08
		(k.node as Node3D).rotation.x = cos(_t * 0.7 + k.ph) * 0.06
	for s in shafts:
		var m: StandardMaterial3D = (s as MeshInstance3D).material_override
		m.albedo_color.a = 0.05 + 0.04 * sin(_t * 0.6 + s.position.x * 3.0)
	if near_eye:
		glow_light.light_energy = 1.4 + 0.5 * sin(_t * 1.1)
	_place()
