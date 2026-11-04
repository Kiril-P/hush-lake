class_name MachineModels
extends RefCounted
## The machines of the lake, built from primitives with one design language: dark blued steel for the working body,
## teal trim, wood for anything a person touches, a cap of snow on every flat top, and warm amber lamps (the only warm
## note: amber means "alive"). Builders only add visuals; the game keeps its own click colliders.

const STEEL := Color(0.36, 0.42, 0.53)
const STEEL_LIGHT := Color(0.6, 0.66, 0.76)
const STEEL_DARK := Color(0.2, 0.23, 0.31)
const TEAL := Color(0.16, 0.6, 0.68)
const TEAL_LIGHT := Color(0.35, 0.82, 0.86)
const WOOD := Color(0.43, 0.29, 0.19)
const WOOD_DARK := Color(0.28, 0.19, 0.14)
const BRICK := Color(0.74, 0.34, 0.25)
const SNOW := Color(0.9, 0.94, 1.0)
const AMBER := Color(1.0, 0.76, 0.32)

const BELT_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float speed = 2.0;
uniform float len = 20.0;
uniform vec3 base : source_color = vec3(0.1, 0.12, 0.17);
uniform vec3 chevron : source_color = vec3(0.22, 0.6, 0.66);
void fragment() {
	float v = UV.y * len;
	float x = abs(UV.x - 0.5) * 2.0;
	// chevrons (>) marching toward the Eye: pattern phase grows with time so features move toward smaller v (-Z)
	float ph = fract((v + x * 0.9) / 1.6 + TIME * speed / 1.6);
	float stripe = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.28, 0.4, ph));
	ALBEDO = mix(base, chevron, stripe * 0.9);
	EMISSION = chevron * stripe * 0.35;
	ROUGHNESS = 0.7;
}
"""

static func mat(c: Color, emit := 0.0, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	return ToolModels.mat(c, emit, rough, metal)

static func box(parent: Node, pos: Vector3, size: Vector3, c: Color, emit := 0.0, rough := 0.6, metal := 0.0) -> MeshInstance3D:
	var m := ToolModels.box(parent, pos, size, c, emit, rough, metal)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return m

## A vertical cylinder centred at `pos`.
static func post(parent: Node, pos: Vector3, r: float, h: float, c: Color, metal := 0.0, emit := 0.0, r_top := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat(c, emit, 0.55, metal)
	mi.position = pos
	parent.add_child(mi)
	return mi

## A cylinder lying along X.
static func roll(parent: Node, pos: Vector3, r: float, length: float, c: Color, metal := 0.0) -> MeshInstance3D:
	var mi := post(parent, pos, r, length, c, metal)
	mi.rotation_degrees.z = 90.0
	return mi

## A bar from `a` to `b` (square section `thick`), for frames and braces.
static func strut(parent: Node, a: Vector3, b: Vector3, thick: float, c: Color, metal := 0.0) -> MeshInstance3D:
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis.looking_at(d.normalized(), up), (a + b) * 0.5)
	parent.add_child(holder)
	return box(holder, Vector3.ZERO, Vector3(thick, thick, d.length()), c, 0.0, 0.55, metal)

static func snow_cap(parent: Node, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var m := ToolModels.ball(parent, pos, size, SNOW, 0.0, 0.9)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

## A glowing lamp: a bright amber bead in a small cage.
static func lamp(parent: Node, pos: Vector3, r := 0.07) -> void:
	ToolModels.ball(parent, pos, Vector3.ONE * r * 2.0, AMBER, 2.2)
	post(parent, pos + Vector3(0, -r * 1.1, 0), r * 0.55, r * 0.8, STEEL_DARK)
	post(parent, pos + Vector3(0, r * 1.1, 0), r * 0.9, r * 0.35, STEEL_DARK)

static func _belt_material(blen: float, speed: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = BELT_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("len", blen)
	m.set_shader_parameter("speed", speed)
	return m

# ---------------------------------------------------------------- the machines

## Auto-Rod: a little drill derrick over the hole with a pumping walking-beam. Local units are about one metre; the game
## scales it by 1.5. Returns {arm}: the beam node the game rocks.
static func auto_rod(root: Node3D) -> Dictionary:
	post(root, Vector3(0, 0.03, 0), 0.5, 0.06, STEEL_DARK)   # base plate over the hole
	for ang in [45.0, 135.0, 225.0, 315.0]:
		var d := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
		strut(root, d * 0.34 + Vector3(0, 0.05, 0), Vector3(d.x * 0.07, 1.25, d.z * 0.07), 0.045, STEEL, 0.4)
		ToolModels.ball(root, d * 0.34 + Vector3(0, 0.06, 0), Vector3.ONE * 0.07, STEEL_LIGHT, 0.0, 0.4)   # foot bolts
	for y in [0.4, 0.82]:
		var w := lerpf(0.34, 0.14, y / 1.25)
		for k in 4:
			var a0 := deg_to_rad(45.0 + 90.0 * k)
			var a1 := deg_to_rad(45.0 + 90.0 * (k + 1))
			strut(root, Vector3(cos(a0), y, sin(a0)) * w * 0.72 , Vector3(cos(a1), y, sin(a1)) * w * 0.72, 0.025, TEAL, 0.3)
	box(root, Vector3(0, 1.3, 0), Vector3(0.3, 0.16, 0.3), TEAL, 0.0, 0.5, 0.3)   # crown block
	snow_cap(root, Vector3(0, 1.4, 0), Vector3(0.34, 0.09, 0.34))
	lamp(root, Vector3(0, 1.55, 0), 0.06)
	# the winch: a drum on the front with a crank
	roll(root, Vector3(0, 0.55, -0.26), 0.07, 0.3, STEEL_LIGHT, 0.6)
	ToolModels.ball(root, Vector3(0.17, 0.55, -0.26), Vector3.ONE * 0.05, AMBER, 0.8)
	# the walking beam: pivots on a post; a horse-head hangs the line down to the hole
	post(root, Vector3(-0.4, 0.5, 0.0), 0.025, 1.0, STEEL, 0.4)
	var arm := Node3D.new()
	arm.position = Vector3(-0.4, 1.0, 0.0)
	root.add_child(arm)
	box(arm, Vector3(0, 0, 0), Vector3(0.8, 0.055, 0.07), STEEL_LIGHT, 0.0, 0.45, 0.6)
	ToolModels.ball(arm, Vector3(0.4, -0.01, 0), Vector3(0.1, 0.12, 0.08), TEAL_LIGHT, 0.5)   # horse head, over the hole
	box(arm, Vector3(-0.38, -0.05, 0), Vector3(0.16, 0.14, 0.1), STEEL_DARK)   # counterweight
	post(root, Vector3(0.0, 0.5, 0.0), 0.006, 0.95, Color(0.85, 0.92, 1.0), 0.0, 0.4)   # the line, down the hole
	# the stash crate with slats and a snow lid, a fish tail poking out
	var crate := Node3D.new()
	crate.position = Vector3(0.58, 0.0, 0.0)
	root.add_child(crate)
	box(crate, Vector3(0, 0.13, 0), Vector3(0.42, 0.26, 0.34), WOOD)
	for z in [-0.1, 0.0, 0.1]:
		box(crate, Vector3(0, 0.14, z + 0.0), Vector3(0.435, 0.03, 0.02), WOOD_DARK)
	for x in [-0.19, 0.19]:
		box(crate, Vector3(x, 0.13, 0), Vector3(0.03, 0.28, 0.36), STEEL_DARK)
	snow_cap(crate, Vector3(0, 0.27, 0), Vector3(0.44, 0.07, 0.36))
	ToolModels.ball(crate, Vector3(0.05, 0.31, 0.04), Vector3(0.1, 0.06, 0.04), Color(0.7, 0.85, 0.95), 0.1)
	return {"arm": arm}

## Smoker: a wooden smokehouse with an iron chimney and a glowing hatch. Returns {smoke}: a CPUParticles3D to switch on while smoking.
static func smoker(root: Node3D) -> Dictionary:
	box(root, Vector3(0, 0.5, 0), Vector3(0.85, 1.0, 0.8), WOOD)
	for i in 5:   # vertical planks
		box(root, Vector3(-0.34 + i * 0.17, 0.5, 0.405), Vector3(0.012, 0.98, 0.01), WOOD_DARK)
	for y in [0.18, 0.82]:   # iron bands
		box(root, Vector3(0, y, 0), Vector3(0.88, 0.05, 0.84), STEEL_DARK, 0.0, 0.5, 0.5)
	box(root, Vector3(0, 0.48, 0.41), Vector3(0.44, 0.58, 0.03), STEEL, 0.0, 0.5, 0.5)   # the door
	box(root, Vector3(0, 0.62, 0.43), Vector3(0.3, 0.07, 0.02), AMBER, 1.8)   # ember slit
	ToolModels.ball(root, Vector3(0.14, 0.4, 0.43), Vector3.ONE * 0.05, STEEL_LIGHT, 0.0, 0.3)   # latch
	# pitched roof with snow
	var r1 := box(root, Vector3(-0.22, 1.08, 0), Vector3(0.58, 0.05, 0.92), STEEL)
	r1.rotation_degrees.z = 22.0
	var r2 := box(root, Vector3(0.22, 1.08, 0), Vector3(0.58, 0.05, 0.92), STEEL)
	r2.rotation_degrees.z = -22.0
	snow_cap(root, Vector3(0, 1.17, 0), Vector3(0.8, 0.07, 0.86))
	post(root, Vector3(0.25, 1.35, -0.15), 0.07, 0.6, STEEL_DARK, 0.5)   # chimney
	post(root, Vector3(0.25, 1.68, -0.15), 0.1, 0.05, STEEL_LIGHT, 0.5)
	var smoke := _smoke_emitter(Vector3(0.25, 1.75, -0.15), 0.12, 0.4)
	smoke.emitting = false
	root.add_child(smoke)
	return {"smoke": smoke}

## A slow plume of grey smoke / steam, one shared look.
static func _smoke_emitter(pos: Vector3, size: float, rise: float) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.position = pos
	smoke.amount = 14
	smoke.lifetime = 2.4
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = rise * 0.7
	smoke.initial_velocity_max = rise * 1.4
	smoke.gravity = Vector3(0.12, 0.15, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(0.8, 0.8, 0.85, 0.0), Color(0.85, 0.85, 0.9, 0.55), Color(0.9, 0.9, 0.95, 0.0)])
	smoke.color_ramp = ramp
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	smoke.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.vertex_color_use_as_albedo = true
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smat
	return smoke

## Gut table: a trestle table with a pale cutting board, a knife, a bucket of scraps and a lamp on a pole.
static func gut_table(root: Node3D) -> void:
	box(root, Vector3(0, 0.74, 0), Vector3(1.05, 0.07, 0.62), WOOD)
	box(root, Vector3(0, 0.79, 0), Vector3(0.82, 0.03, 0.46), Color(0.9, 0.88, 0.8), 0.0, 0.8)
	for sx in [-0.42, 0.42]:
		strut(root, Vector3(sx, 0.7, -0.24), Vector3(sx * 1.12, 0.0, -0.3), 0.06, WOOD_DARK)
		strut(root, Vector3(sx, 0.7, 0.24), Vector3(sx * 1.12, 0.0, 0.3), 0.06, WOOD_DARK)
	box(root, Vector3(0, 0.28, 0), Vector3(0.96, 0.04, 0.05), WOOD_DARK)   # stretcher
	box(root, Vector3(0.12, 0.83, 0.06), Vector3(0.26, 0.012, 0.045), STEEL_LIGHT, 0.0, 0.3, 0.8)   # knife
	box(root, Vector3(-0.04, 0.835, 0.06), Vector3(0.1, 0.03, 0.05), WOOD_DARK)
	ToolModels.ball(root, Vector3(-0.2, 0.84, -0.04), Vector3(0.2, 0.05, 0.08), Color(0.7, 0.82, 0.92), 0.1)   # a fish on the board
	var bucket := post(root, Vector3(0.62, 0.17, 0.2), 0.14, 0.34, TEAL, 0.2, 0.0, 0.17)
	bucket.mesh.top_radius = 0.17
	post(root, Vector3(0.62, 0.35, 0.2), 0.15, 0.03, STEEL_LIGHT, 0.5)
	ToolModels.ball(root, Vector3(0.6, 0.37, 0.2), Vector3(0.12, 0.05, 0.05), Color(0.7, 0.85, 0.95), 0.1)
	post(root, Vector3(-0.55, 0.6, -0.34), 0.02, 1.2, STEEL_DARK, 0.5)
	lamp(root, Vector3(-0.55, 1.26, -0.34), 0.06)
	snow_cap(root, Vector3(-0.55, 1.36, -0.34), Vector3(0.2, 0.04, 0.2))

## The belt: a long steel trough with teal rails, chevrons marching toward the Eye, amber lamps and legs.
## The node's -Z points at the Eye. Returns nothing.
static func belt(node: Node3D, blen: float, speed: float) -> void:
	box(node, Vector3(0, -0.02, 0), Vector3(1.08, 0.16, blen), STEEL)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.78, blen)
	top.mesh = pm
	top.material_override = _belt_material(blen, speed)
	top.position = Vector3(0, 0.07, 0)
	node.add_child(top)
	for sx in [-0.5, 0.5]:
		box(node, Vector3(sx, 0.14, 0), Vector3(0.09, 0.2, blen), TEAL, 0.0, 0.5, 0.3)
		box(node, Vector3(sx, 0.255, 0), Vector3(0.05, 0.03, blen), TEAL_LIGHT, 0.4)
	var n := maxi(int(blen / 5.0), 1)
	for i in n + 1:
		var z := -blen * 0.5 + i * (blen / n)
		for sx in [-0.4, 0.4]:
			strut(node, Vector3(sx, -0.1, z), Vector3(sx * 1.5, -0.55, z), 0.1, STEEL_DARK, 0.3)   # splayed legs
		box(node, Vector3(0, -0.1, z), Vector3(0.9, 0.08, 0.14), STEEL_DARK)
		if i % 2 == 0:
			post(node, Vector3(0.62, 0.38, z), 0.025, 0.5, STEEL_DARK, 0.5)
			lamp(node, Vector3(0.62, 0.7, z), 0.06)

## Cannery: a brick works with a corrugated roof, a smokestack and a lit hatch where the belt runs through. Local +Z faces away from the Eye.
static func cannery(m: Node3D) -> void:
	box(m, Vector3(0, 1.1, 0), Vector3(2.7, 2.0, 2.9), BRICK)
	for i in 6:   # brick courses
		box(m, Vector3(0, 0.3 + i * 0.32, 0), Vector3(2.74, 0.025, 2.94), BRICK.darkened(0.25))
	for sx in [-1.35, 1.35]:
		box(m, Vector3(sx, 1.1, 0), Vector3(0.14, 2.1, 3.0), STEEL_DARK, 0.0, 0.5, 0.4)   # corner posts
	box(m, Vector3(0, 2.18, 0), Vector3(3.0, 0.18, 3.2), TEAL, 0.0, 0.5, 0.2)   # roof
	for i in 7:
		box(m, Vector3(-1.2 + i * 0.4, 2.3, 0), Vector3(0.1, 0.1, 3.2), TEAL.lightened(0.15))   # corrugation
	snow_cap(m, Vector3(0, 2.42, 0), Vector3(3.0, 0.2, 3.2))
	post(m, Vector3(0.9, 3.0, 0.8), 0.28, 1.6, STEEL_DARK, 0.4)
	post(m, Vector3(0.9, 3.85, 0.8), 0.34, 0.14, AMBER.darkened(0.2), 0.3, 0.3)
	var puff := _smoke_emitter(Vector3(0.9, 4.0, 0.8), 0.3, 0.5)   # the works breathes out a little steam
	m.add_child(puff)
	puff.emitting = true
	snow_cap(m, Vector3(0.9, 3.95, 0.8), Vector3(0.7, 0.14, 0.7))
	for sz in [-1.46, 1.46]:   # the tunnel mouths the belt runs through
		box(m, Vector3(0, 0.95, sz), Vector3(1.3, 1.1, 0.12), STEEL_DARK)
		box(m, Vector3(0, 0.95, sz + (0.03 if sz > 0 else -0.03)), Vector3(1.0, 0.85, 0.1), Color(0.02, 0.03, 0.06))
		box(m, Vector3(0, 1.55, sz + (0.05 if sz > 0 else -0.05)), Vector3(1.4, 0.12, 0.08), AMBER, 1.6)
	for sx in [-0.85, 0.85]:   # lit windows
		box(m, Vector3(sx, 1.4, 1.46), Vector3(0.5, 0.5, 0.05), AMBER, 1.5)
	# a stack of cans
	for i in 3:
		post(m, Vector3(-1.55, 0.14 + i * 0.28, 0.9), 0.17, 0.26, STEEL_LIGHT, 0.7)

## Sorter: a gantry over the belt with a scanner head and a row of paddle arms.
static func sorter(m: Node3D) -> void:
	for sx in [-1.5, 1.5]:
		box(m, Vector3(sx, 1.4, 0), Vector3(0.34, 2.8, 0.34), STEEL, 0.0, 0.5, 0.4)
		box(m, Vector3(sx, 0.05, 0), Vector3(0.7, 0.1, 0.7), STEEL_DARK)
		box(m, Vector3(sx, 2.0, 0), Vector3(0.42, 0.16, 0.42), TEAL)
	box(m, Vector3(0, 2.8, 0), Vector3(3.4, 0.34, 0.4), STEEL, 0.0, 0.5, 0.4)
	box(m, Vector3(0, 2.62, 0), Vector3(3.4, 0.05, 0.42), TEAL_LIGHT, 0.5)
	box(m, Vector3(0, 2.38, 0), Vector3(0.9, 0.42, 0.6), STEEL_DARK)   # scanner head
	box(m, Vector3(0, 2.22, 0.31), Vector3(0.7, 0.1, 0.03), Color(0.4, 1.0, 0.7), 2.4)
	var scan := box(m, Vector3(0, 2.1, 0), Vector3(0.04, 0.3, 0.04), Color(0.4, 1.0, 0.7), 1.2)   # the scan beam sweeps side to side
	var sw := scan.create_tween().set_loops()
	sw.tween_property(scan, "position:x", 0.38, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sw.tween_property(scan, "position:x", -0.38, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in 5:   # paddle arms
		var px := -1.0 + i * 0.5
		box(m, Vector3(px, 1.95, 0.0), Vector3(0.05, 0.05, 0.8), STEEL_LIGHT, 0.0, 0.4, 0.7)
		box(m, Vector3(px, 1.9, -0.4), Vector3(0.18, 0.14, 0.05), TEAL_LIGHT, 0.4)
	snow_cap(m, Vector3(0, 3.0, 0), Vector3(3.4, 0.12, 0.44))
	lamp(m, Vector3(-1.5, 2.15, 0.3), 0.07)
	lamp(m, Vector3(1.5, 2.15, 0.3), 0.07)

## Depot: a snow-roofed wooden shed with a loading deck, crates, a lamp post and a sled waiting on the landing.
static func depot(node: Node3D) -> void:
	box(node, Vector3(0, 0.08, 0), Vector3(3.2, 0.16, 2.2), WOOD_DARK)   # deck
	for i in 6:
		box(node, Vector3(-1.35 + i * 0.54, 0.17, 0), Vector3(0.05, 0.02, 2.2), WOOD)
	box(node, Vector3(-0.3, 0.9, -0.2), Vector3(2.2, 1.5, 1.5), WOOD)   # the shed
	for i in 7:
		box(node, Vector3(-1.3 + i * 0.34, 0.9, 0.56), Vector3(0.015, 1.46, 0.01), WOOD_DARK)
	box(node, Vector3(-0.3, 0.8, 0.57), Vector3(0.7, 1.1, 0.04), STEEL_DARK)   # door
	box(node, Vector3(-0.3, 1.1, 0.6), Vector3(0.5, 0.18, 0.02), AMBER, 1.4)
	var r1 := box(node, Vector3(-1.0, 1.82, -0.2), Vector3(1.4, 0.08, 1.8), STEEL)
	r1.rotation_degrees.z = 20.0
	var r2 := box(node, Vector3(0.4, 1.82, -0.2), Vector3(1.4, 0.08, 1.8), STEEL)
	r2.rotation_degrees.z = -20.0
	snow_cap(node, Vector3(-0.3, 2.0, -0.2), Vector3(2.5, 0.14, 1.9))
	box(node, Vector3(1.05, 0.42, 0.1), Vector3(0.7, 0.5, 0.6), WOOD)   # crates
	box(node, Vector3(1.1, 0.88, 0.1), Vector3(0.5, 0.4, 0.5), WOOD.lightened(0.1))
	snow_cap(node, Vector3(1.1, 1.1, 0.1), Vector3(0.55, 0.06, 0.55))
	post(node, Vector3(1.5, 1.05, -0.85), 0.04, 1.8, STEEL_DARK, 0.5)
	lamp(node, Vector3(1.5, 2.0, -0.85), 0.09)
	# the sled on its landing
	box(node, Vector3(0, 0.1, 2.0), Vector3(2.6, 0.08, 1.6), SNOW)   # landing snow
	box(node, Vector3(0, 0.3, 2.0), Vector3(1.5, 0.12, 0.8), TEAL)
	for sx in [-0.38, 0.38]:
		box(node, Vector3(sx, 0.17, 2.0), Vector3(0.05, 0.05, 1.7), STEEL_LIGHT, 0.0, 0.4, 0.8)
	box(node, Vector3(0, 0.45, 2.0), Vector3(1.4, 0.2, 0.7), WOOD)

## Ice-Breaker: a hull of dark steel with a teal waterline stripe, a crew cabin with a lit bridge, a smokestack, a mast, a
## crane and a spinning amber beacon. Local +Z faces the Eye. Returns {beacon}.
static func rig(node: Node3D) -> Dictionary:
	box(node, Vector3(0, 0.7, 0), Vector3(5.6, 1.5, 11.0), STEEL)
	box(node, Vector3(0, 0.2, 0), Vector3(5.7, 0.28, 11.1), TEAL, 0.0, 0.5, 0.2)
	var bow := box(node, Vector3(0, 0.8, 5.9), Vector3(5.0, 1.3, 2.4), STEEL.lightened(0.05))   # the prow slopes down to the ice
	bow.rotation_degrees.x = 24.0
	box(node, Vector3(0, 1.55, 0), Vector3(5.8, 0.2, 11.2), TEAL.darkened(0.2))   # deck edge
	for i in 6:   # deck plating and rivets
		box(node, Vector3(0, 1.67, -4.6 + i * 1.8), Vector3(5.4, 0.02, 0.08), STEEL_DARK)
	box(node, Vector3(0, 2.8, 2.2), Vector3(3.6, 2.4, 3.6), Color(0.84, 0.86, 0.9))   # the cabin
	box(node, Vector3(0, 3.35, 4.04), Vector3(3.0, 0.9, 0.06), AMBER, 1.6)   # the bridge window
	for sx in [-1.2, 0.0, 1.2]:
		box(node, Vector3(sx, 3.35, 4.07), Vector3(0.05, 0.9, 0.03), STEEL_DARK)
	box(node, Vector3(0, 4.15, 2.2), Vector3(3.9, 0.22, 3.9), TEAL)
	snow_cap(node, Vector3(0, 4.35, 2.2), Vector3(4.0, 0.22, 4.0))
	post(node, Vector3(1.2, 5.5, 0.9), 0.45, 2.8, STEEL_DARK, 0.4)   # smokestack with an amber band
	post(node, Vector3(1.2, 6.6, 0.9), 0.5, 0.18, AMBER.darkened(0.15), 0.3, 0.3)
	post(node, Vector3(0, 6.2, 2.2), 0.06, 3.6, STEEL, 0.5)   # mast
	box(node, Vector3(0, 7.6, 2.2), Vector3(1.6, 0.07, 0.07), STEEL)
	var beacon := Node3D.new()
	beacon.position = Vector3(0, 8.1, 2.2)
	node.add_child(beacon)
	ToolModels.ball(beacon, Vector3.ZERO, Vector3.ONE * 0.4, AMBER, 3.0)
	box(beacon, Vector3(0.0, 0.0, 0.34), Vector3(0.06, 0.06, 0.6), AMBER, 2.0)
	# the crane at the back
	box(node, Vector3(0, 3.0, -2.6), Vector3(0.5, 3.0, 0.5), STEEL_DARK)
	var arm := box(node, Vector3(0, 5.1, -4.4), Vector3(0.28, 0.28, 6.0), Color(0.78, 0.4, 0.2), 0.2)
	arm.rotation_degrees.x = 10.0
	post(node, Vector3(0, 3.9, -6.9), 0.02, 2.6, Color(0.85, 0.92, 1.0), 0.0, 0.3)
	box(node, Vector3(0, 2.5, -6.9), Vector3(0.7, 0.4, 0.7), AMBER.darkened(0.2), 0.6)   # the grab
	for sx in [-2.9, 2.9]:   # side running lights
		for sz in [-4.0, 0.0, 4.0]:
			box(node, Vector3(sx, 1.9, sz), Vector3(0.2, 0.34, 0.2), AMBER, 1.8)
	return {"beacon": beacon}
