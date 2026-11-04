class_name ToolModels
extends RefCounted
## The tools you hold, built from primitives: a hand auger with real flights, a rod with cork grip, reel and guides, a work
## hammer, and the knitted mittens that hold them. Everything points along -Z (away from you); the game rotates the body.
## Palette rule (docs/STYLE.md): cold steel and dark wood, warm amber only on what is yours (mittens, grip bands, the lit tip).

const MITTEN := Color(0.96, 0.66, 0.26)
const MITTEN_CUFF := Color(0.16, 0.5, 0.58)   # teal knit: the one cold note on the warm mitten
const CORK := Color(0.8, 0.62, 0.4)
const WOOD := Color(0.42, 0.28, 0.19)
const WOOD_DARK := Color(0.26, 0.18, 0.14)
const STEEL := Color(0.62, 0.66, 0.74)
const STEEL_DARK := Color(0.36, 0.4, 0.5)
const BRASS := Color(0.86, 0.66, 0.3)
const AMBER := Color(1.0, 0.78, 0.35)

static func mat(c: Color, emit := 0.0, rough := 0.55, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

static func _add(parent: Node, mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # first-person props: no shadows (they would flicker on the ice)
	parent.add_child(mi)
	return mi

static func box(parent: Node, pos: Vector3, size: Vector3, c: Color, emit := 0.0, rough := 0.55, metal := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(parent, bm, mat(c, emit, rough, metal), pos)

static func ball(parent: Node, pos: Vector3, scale3: Vector3, c: Color, emit := 0.0, rough := 0.6) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	var mi := _add(parent, sm, mat(c, emit, rough), pos)
	mi.scale = scale3
	return mi

## A cylinder running along Z from z_back (+, near you) to z_front (-, away). Radii at the back and the front.
static func rod_seg(parent: Node, z_back: float, z_front: float, r_back: float, r_front: float, c: Color, emit := 0.0, metal := 0.0, x := 0.0, y := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_back
	cm.bottom_radius = r_front
	cm.height = absf(z_back - z_front)
	cm.radial_segments = 8
	var mi := _add(parent, cm, mat(c, emit, 0.5, metal), Vector3(x, y, (z_back + z_front) * 0.5))
	mi.rotation_degrees.x = 90.0
	return mi

## A cylinder running along X (a crossbar).
static func bar_x(parent: Node, pos: Vector3, length: float, r: float, c: Color, metal := 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = length
	cm.radial_segments = 8
	var mi := _add(parent, cm, mat(c, 0.0, 0.5, metal), pos)
	mi.rotation_degrees.z = 90.0
	return mi

## A knitted mitten gripping something at `pos`: palm, thumb, a cuff and a cream band. `side` is -1 (left) or +1 (right).
static func mitten(parent: Node, pos: Vector3, side := 1.0, tilt := 0.0) -> Node3D:
	var m := Node3D.new()
	m.position = pos
	m.rotation_degrees.x = tilt
	m.scale = Vector3.ONE * 0.8
	parent.add_child(m)
	ball(m, Vector3(0, 0, 0), Vector3(0.1, 0.075, 0.13), MITTEN)   # the mitten is the warm, readable part: amber, big
	ball(m, Vector3(0.0, -0.005, -0.085), Vector3(0.09, 0.065, 0.08), MITTEN.darkened(0.06))   # the fingers, rounded off
	ball(m, Vector3(-0.06 * side, 0.014, -0.03), Vector3(0.045, 0.045, 0.08), MITTEN.lightened(0.05))   # thumb
	rod_seg(m, 0.16, 0.09, 0.03, 0.033, MITTEN_CUFF)   # a slim teal cuff
	rod_seg(m, 0.12, 0.105, 0.036, 0.036, Color(0.93, 0.9, 0.82))   # the cream stripe
	return m

## Hand auger. Returns {spin, tip: null}. The spinning part (shaft, flights, bit) is `spin`, the T-handle stays put.
static func auger(body: Node3D, tc: Color, tier: int) -> Dictionary:
	# T-handle: a crossbar with turned wooden grips, a brass collar and the neck
	bar_x(body, Vector3(0, 0.005, 0.12), 0.26, 0.014, WOOD)
	for sx in [-0.125, 0.125]:
		bar_x(body, Vector3(sx, 0.005, 0.12), 0.06, 0.02, WOOD_DARK)
	rod_seg(body, 0.15, 0.0, 0.02, 0.02, WOOD)
	rod_seg(body, 0.03, -0.03, 0.03, 0.026, BRASS, 0.0, 0.7)
	var spin := Node3D.new()
	body.add_child(spin)
	# shaft and the flights that wind around it (flattened blades, each turned a little more than the last, narrowing to the bit)
	rod_seg(spin, -0.02, -0.78, 0.016, 0.014, STEEL, 0.0, 0.8)
	for i in 8:
		var w := lerpf(0.15, 0.08, float(i) / 7.0)
		var blade := box(spin, Vector3(0, 0, -0.13 - i * 0.085), Vector3(w, 0.013, 0.05), tc.lerp(STEEL, 0.35), 0.25, 0.4, 0.4)
		blade.rotation.z = i * 0.95
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.04
	tip_mesh.height = 0.16
	tip_mesh.radial_segments = 8
	var tip := _add(spin, tip_mesh, mat(tc, 0.5, 0.35, 0.5), Vector3(0, 0, -0.85))
	tip.rotation_degrees.x = -90.0
	if tier >= 2:   # power augers get a motor housing
		box(body, Vector3(0, 0.0, -0.01), Vector3(0.11, 0.1, 0.15), STEEL_DARK, 0.0, 0.45, 0.4)
		box(body, Vector3(0, 0.07, -0.01), Vector3(0.06, 0.02, 0.1), AMBER, 0.8)
	mitten(body, Vector3(0.125, 0.005, 0.12), 1.0, 0.0)
	mitten(body, Vector3(-0.125, 0.005, 0.12), -1.0, 0.0)
	return {"spin": spin, "tip": null}

## Fishing rod. Returns {spin: null, tip: Node3D at the rod tip} (the line is drawn from the tip).
static func rod(body: Node3D, tc: Color, tier: int) -> Dictionary:
	var blank := tc if tier > 0 else WOOD
	# cork grip with a brass end cap, then three tapering blank sections with wraps between them
	rod_seg(body, 0.2, 0.0, 0.024, 0.021, CORK)
	rod_seg(body, 0.215, 0.2, 0.026, 0.026, BRASS, 0.0, 0.7)
	rod_seg(body, 0.0, -0.32, 0.019, 0.014, blank, 0.15 if tier > 0 else 0.0)
	rod_seg(body, -0.32, -0.66, 0.014, 0.0095, blank, 0.15 if tier > 0 else 0.0)
	rod_seg(body, -0.66, -0.97, 0.0095, 0.0045, blank, 0.15 if tier > 0 else 0.0)
	for z in [-0.32, -0.66]:
		rod_seg(body, z + 0.015, z - 0.015, 0.017 if z > -0.5 else 0.012, 0.017 if z > -0.5 else 0.012, AMBER.darkened(0.2))
	# line guides: little rings underneath
	for z in [-0.18, -0.4, -0.62, -0.84]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.011
		ring.outer_radius = 0.016
		ring.rings = 8
		ring.ring_segments = 5
		var gi := _add(body, ring, mat(STEEL, 0.0, 0.4, 0.8), Vector3(0, -0.025 + z * 0.012, z))
		gi.rotation_degrees.x = 90.0
	# the reel: seat, spool, side plate and a crank with an amber knob
	box(body, Vector3(0, -0.035, 0.07), Vector3(0.03, 0.02, 0.07), STEEL_DARK, 0.0, 0.5, 0.6)
	var spool := bar_x(body, Vector3(0.0, -0.065, 0.075), 0.05, 0.034, STEEL, 0.8)
	bar_x(body, Vector3(0.03, -0.065, 0.075), 0.012, 0.038, STEEL_DARK, 0.8)
	var crank := box(body, Vector3(0.055, -0.065, 0.075), Vector3(0.012, 0.012, 0.05), STEEL, 0.0, 0.4, 0.8)
	crank.rotation_degrees.x = 25.0
	ball(body, Vector3(0.055, -0.045, 0.058), Vector3(0.022, 0.022, 0.022), AMBER, 0.6)
	var tip := Node3D.new()
	tip.position = Vector3(0, 0, -0.97)
	body.add_child(tip)
	ball(tip, Vector3.ZERO, Vector3(0.016, 0.016, 0.016), AMBER, 1.4)   # a lit bead: you can see where the line leaves
	mitten(body, Vector3(0.0, -0.005, 0.1), 1.0, 0.0)
	mitten(body, Vector3(-0.01, -0.07, 0.06), -1.0, 10.0)
	return {"spin": null, "tip": tip}

## A work hammer-and-wrench set for the build tools: `accent` says which machine you are about to place.
static func builder(body: Node3D, accent: Color) -> Dictionary:
	rod_seg(body, 0.1, -0.34, 0.022, 0.018, WOOD)
	rod_seg(body, 0.1, 0.02, 0.026, 0.026, CORK)
	box(body, Vector3(0, 0.0, -0.4), Vector3(0.2, 0.085, 0.09), STEEL, 0.0, 0.35, 0.7)
	box(body, Vector3(0, 0.0, -0.4), Vector3(0.05, 0.095, 0.095), accent, 0.7)
	box(body, Vector3(0.12, 0.0, -0.4), Vector3(0.05, 0.06, 0.07), STEEL_DARK, 0.0, 0.4, 0.7)
	mitten(body, Vector3(0.0, 0.0, 0.07), 1.0, 0.0)
	return {"spin": null, "tip": null}

## Your boot, for kicking: a chunky leather boot with amber laces and a fur cuff. Points along -Z (the toe leads).
static func boot(parent: Node3D) -> Node3D:
	var b := Node3D.new()
	parent.add_child(b)
	var leather := Color(0.6, 0.42, 0.3)
	box(b, Vector3(0, -0.07, -0.02), Vector3(0.15, 0.05, 0.36), WOOD_DARK, 0.0, 0.8)   # sole
	box(b, Vector3(0, 0.0, -0.05), Vector3(0.14, 0.1, 0.3), leather, 0.0, 0.7)   # foot
	ball(b, Vector3(0, -0.01, -0.2), Vector3(0.14, 0.1, 0.12), leather.lightened(0.05), 0.0, 0.7)   # toe cap
	box(b, Vector3(0, 0.12, 0.05), Vector3(0.13, 0.2, 0.14), leather, 0.0, 0.7)   # ankle
	for i in 3:   # laces
		box(b, Vector3(0, 0.06 + i * 0.04, -0.03 - i * 0.025), Vector3(0.1, 0.012, 0.012), AMBER, 0.5)
	var cuff := TorusMesh.new()
	cuff.inner_radius = 0.06
	cuff.outer_radius = 0.1
	cuff.rings = 12
	cuff.ring_segments = 5
	_add(b, cuff, mat(Color(0.95, 0.92, 0.84), 0.0, 0.9), Vector3(0, 0.23, 0.05))
	return b
