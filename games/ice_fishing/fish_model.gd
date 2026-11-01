class_name FishModel
extends RefCounted
## Procedural low-poly fish. One recognisable silhouette per species, built as a lofted body (vertex-coloured
## back, belly and markings), a tail that wags, dorsal and pectoral fins, and eyes.
## `build(name, color, length)` returns a FishNode (see fish_node.gd) that animates itself.
## Modelled with the nose at +X, up = +Y, about 1.3 units long before scaling.

const SPECS := {
	"Minnow": {"kind": "fish", "size": 0.8,
		"prof": [[0.0, 0.03, 0.025], [0.12, 0.08, 0.06], [0.35, 0.125, 0.09], [0.65, 0.13, 0.09], [0.88, 0.09, 0.065], [1.0, 0.025, 0.025]],
		"back": Color(0.45, 0.55, 0.62), "belly": Color(0.93, 0.96, 0.98), "pattern": "lateral", "pat": Color(0.2, 0.28, 0.36),
		"fin": Color(0.8, 0.88, 0.92), "tail": "fork", "dorsal": "soft", "shine": 0.0},
	"Perch": {"kind": "fish", "size": 1.0,
		"prof": [[0.0, 0.04, 0.03], [0.15, 0.11, 0.06], [0.4, 0.19, 0.09], [0.65, 0.19, 0.09], [0.88, 0.12, 0.06], [1.0, 0.03, 0.03]],
		"back": Color(0.3, 0.45, 0.2), "belly": Color(0.95, 0.9, 0.6), "pattern": "bands", "pat": Color(0.12, 0.2, 0.1),
		"fin": Color(0.95, 0.45, 0.2), "tail": "fork", "dorsal": "spiky", "shine": 0.0},
	"Silver Pike": {"kind": "fish", "size": 1.5,
		"prof": [[0.0, 0.04, 0.03], [0.2, 0.08, 0.055], [0.5, 0.1, 0.065], [0.78, 0.085, 0.055], [0.93, 0.05, 0.045], [1.0, 0.018, 0.03]],
		"back": Color(0.5, 0.58, 0.62), "belly": Color(0.95, 0.97, 1.0), "pattern": "spots", "pat": Color(0.82, 0.88, 0.92),
		"fin": Color(0.62, 0.7, 0.76), "tail": "round", "dorsal": "back", "shine": 0.15},
	"Golden Trout": {"kind": "fish", "size": 1.25,
		"prof": [[0.0, 0.035, 0.03], [0.15, 0.09, 0.06], [0.4, 0.14, 0.08], [0.7, 0.13, 0.08], [0.9, 0.08, 0.05], [1.0, 0.025, 0.025]],
		"back": Color(0.95, 0.65, 0.12), "belly": Color(1.0, 0.92, 0.55), "pattern": "stripe_spots", "pat": Color(0.9, 0.3, 0.12),
		"fin": Color(1.0, 0.75, 0.25), "tail": "round", "dorsal": "soft", "shine": 0.55},
	"Ancient Fish": {"kind": "fish", "size": 2.2,
		"prof": [[0.0, 0.04, 0.03], [0.12, 0.1, 0.07], [0.35, 0.17, 0.1], [0.62, 0.16, 0.1], [0.85, 0.1, 0.07], [1.0, 0.03, 0.04]],
		"back": Color(0.05, 0.28, 0.32), "belly": Color(0.3, 0.75, 0.7), "pattern": "runes", "pat": Color(0.5, 1.0, 0.9),
		"fin": Color(0.3, 0.9, 0.85), "tail": "grand", "dorsal": "crest", "shine": 1.0},
	"Old Boot": {"kind": "boot", "size": 0.9},
	"Old Coin": {"kind": "coin", "size": 0.5},
	"Glass Pearl": {"kind": "pearl", "size": 0.42},
}

static var _cache := {}

static func build(species: String, color: Color, length: float) -> Node3D:
	var spec: Dictionary = SPECS.get(species, SPECS["Minnow"])
	var root := FishNode.new()
	root.kind = spec.kind
	match spec.kind:
		"fish":
			_build_fish(root, species, spec)
		"boot":
			_build_boot(root)
		"coin":
			_build_coin(root)
		"pearl":
			_build_pearl(root)
	root.scale = Vector3.ONE * length * spec.size
	return root

static func size_mult(species: String) -> float:
	return SPECS.get(species, SPECS["Minnow"]).size

# ---------- fish ----------
static func _profile(prof: Array, u: float) -> Vector2:
	for i in prof.size() - 1:
		var a: Array = prof[i]
		var b: Array = prof[i + 1]
		if u <= b[0]:
			var k := inverse_lerp(a[0], b[0], u)
			k = k * k * (3.0 - 2.0 * k)
			return Vector2(lerpf(a[1], b[1], k), lerpf(a[2], b[2], k))
	var l: Array = prof[prof.size() - 1]
	return Vector2(l[1], l[2])

static func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) % 1000003
	return float(absi(h)) / 1000003.0

static func _color_at(spec: Dictionary, u: float, a: float) -> Color:
	# a: 0 = back, PI = belly, PI/2 = flank
	var belly_k := smoothstep(0.3, 0.75, (1.0 - cos(a)) * 0.5)
	var c: Color = spec.back.lerp(spec.belly, belly_k)
	var flank := exp(-pow((a - PI * 0.5) / 0.55, 2.0))
	match spec.pattern:
		"lateral":
			c = c.lerp(spec.pat, exp(-pow((a - PI * 0.55) / 0.22, 2.0)) * 0.75)
		"bands":
			var band := 1.0 if fmod(u * 6.5, 1.0) < 0.42 else 0.0
			c = c.lerp(spec.pat, band * smoothstep(2.4, 1.2, a) * 0.85)
		"spots":
			var h := _hash(int(u * 16.0), int(a * 4.0))
			if h > 0.62 and a > 0.5 and a < 2.5:
				c = c.lerp(spec.pat, 0.8)
		"stripe_spots":
			c = c.lerp(spec.pat, exp(-pow((a - PI * 0.5) / 0.2, 2.0)) * 0.9)
			if _hash(int(u * 18.0), int(a * 5.0)) > 0.8 and a < 1.7:
				c = c.lerp(Color(0.45, 0.2, 0.05), 0.7)
		"runes":
			var rune := 1.0 if (fmod(u * 9.0, 1.0) < 0.2 and a > 0.7 and a < 2.4) else 0.0
			c = c.lerp(spec.pat, rune * (0.5 + 0.5 * flank))
	return c

static func _body_mesh(spec: Dictionary) -> ArrayMesh:
	var secs := 14
	var sides := 10
	var rings := []
	for i in secs + 1:
		var u := float(i) / secs
		var hw := _profile(spec.prof, u)
		var x := lerpf(-0.5, 0.5, u)
		var ring := []
		for k in sides:
			var a := TAU * k / sides   # 0 = top
			var pos := Vector3(x, cos(a) * hw.x, sin(a) * hw.y)
			ring.append([pos, _color_at(spec, u, absf(a if a <= PI else TAU - a))])
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in secs:
		for k in sides:
			var k2 := (k + 1) % sides
			for q in [[i, k], [i + 1, k], [i, k2], [i, k2], [i + 1, k], [i + 1, k2]]:
				var v: Array = rings[q[0]][q[1]]
				st.set_color(v[1])
				st.add_vertex(v[0])
	# nose cap
	var nose: Array = rings[secs][0]
	var tip := Vector3(0.5 + 0.03, nose[0].y * 0.2 - 0.003, 0)
	for k in sides:
		var k2 := (k + 1) % sides
		for v in [rings[secs][k], rings[secs][k2]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
		st.set_color(rings[secs][0][1])
		st.add_vertex(tip)
	st.generate_normals()
	return st.commit()

static func _poly(points: Array, col: Color, plane := "xy") -> ArrayMesh:
	## flat convex polygon, fan-triangulated from the first point, double sided via the material
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size() - 1):
		for p in [points[0], points[i], points[i + 1]]:
			st.set_color(col)
			st.add_vertex(Vector3(p.x, p.y, 0) if plane == "xy" else Vector3(p.x, 0, p.y))
	st.generate_normals()
	return st.commit()

static func _tail_points(kind: String) -> Array:
	match kind:
		"fork":
			return [Vector2(0, 0.025), Vector2(-0.26, 0.17), Vector2(-0.18, 0.0), Vector2(-0.26, -0.17), Vector2(0, -0.025)]
		"round":
			return [Vector2(0, 0.03), Vector2(-0.2, 0.13), Vector2(-0.3, 0.05), Vector2(-0.3, -0.05), Vector2(-0.2, -0.13), Vector2(0, -0.03)]
		_:  # grand: long, flowing
			return [Vector2(0, 0.03), Vector2(-0.22, 0.2), Vector2(-0.45, 0.12), Vector2(-0.36, 0.0), Vector2(-0.45, -0.12), Vector2(-0.22, -0.2), Vector2(0, -0.03)]

static func _dorsal_points(kind: String, spec: Dictionary) -> Array:
	var prof: Array = spec.prof
	var pts := []
	match kind:
		"spiky":
			var x0 := 0.12
			pts.append(Vector2(x0, _profile(prof, 0.62).x * 0.9))
			for i in 5:
				var u := 0.62 + 0.07 * i
				pts.append(Vector2(lerpf(-0.5, 0.5, u) - 0.02, _profile(prof, u).x + 0.12 - 0.012 * i))
				pts.append(Vector2(lerpf(-0.5, 0.5, u + 0.035), _profile(prof, u + 0.035).x + 0.02))
			pts.append(Vector2(-0.04, _profile(prof, 0.46).x * 0.95))
			pts = [Vector2(0.22, _profile(prof, 0.72).x * 0.9), Vector2(0.14, _profile(prof, 0.7).x + 0.13), Vector2(0.06, _profile(prof, 0.6).x + 0.09),
				Vector2(-0.02, _profile(prof, 0.5).x + 0.11), Vector2(-0.1, _profile(prof, 0.4).x + 0.05), Vector2(-0.12, _profile(prof, 0.38).x * 0.9)]
		"back":
			pts = [Vector2(-0.18, _profile(prof, 0.3).x * 0.9), Vector2(-0.27, _profile(prof, 0.2).x + 0.1), Vector2(-0.4, _profile(prof, 0.1).x + 0.05), Vector2(-0.4, _profile(prof, 0.1).x * 0.9)]
		"crest":
			pts = [Vector2(0.3, _profile(prof, 0.8).x * 0.9), Vector2(0.18, _profile(prof, 0.68).x + 0.18), Vector2(0.02, _profile(prof, 0.52).x + 0.26),
				Vector2(-0.14, _profile(prof, 0.36).x + 0.2), Vector2(-0.3, _profile(prof, 0.2).x + 0.1), Vector2(-0.3, _profile(prof, 0.2).x * 0.9)]
		_:
			pts = [Vector2(0.12, _profile(prof, 0.62).x * 0.9), Vector2(0.0, _profile(prof, 0.5).x + 0.1), Vector2(-0.14, _profile(prof, 0.36).x + 0.05), Vector2(-0.16, _profile(prof, 0.34).x * 0.9)]
	return pts

static func _mat(shine: float, translucent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.32
	m.metallic = 0.25
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if shine > 0.0:
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.35) if shine < 0.9 else Color(0.3, 1.0, 0.9)
		m.emission_energy_multiplier = shine * 0.5
	if translucent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.0
		m.roughness = 0.7
		m.albedo_color = Color(1, 1, 1, 0.92)
	return m

static func _build_fish(root: FishNode, species: String, spec: Dictionary) -> void:
	if not _cache.has(species):
		var c := {}
		c.body = _body_mesh(spec)
		c.tail = _poly(_tail_points(spec.tail), spec.fin)
		c.dorsal = _poly(_dorsal_points(spec.dorsal, spec), spec.fin)
		c.pec = _poly([Vector2(0, 0), Vector2(-0.16, 0.08), Vector2(-0.06, 0.14), Vector2(0.03, 0.05)], spec.fin, "xz")
		c.mat = _mat(spec.shine)
		c.fin_mat = _mat(spec.shine * 0.8, true)
		var eye := SphereMesh.new()
		eye.radius = 0.5
		eye.height = 1.0
		eye.radial_segments = 8
		eye.rings = 4
		c.eye = eye
		_cache[species] = c
	var c: Dictionary = _cache[species]
	var sway := Node3D.new()
	root.add_child(sway)
	root.sway = sway
	var body := MeshInstance3D.new()
	body.mesh = c.body
	body.material_override = c.mat
	sway.add_child(body)
	var tail_pivot := Node3D.new()
	tail_pivot.position = Vector3(-0.5, 0, 0)
	sway.add_child(tail_pivot)
	var tail := MeshInstance3D.new()
	tail.mesh = c.tail
	tail.material_override = c.fin_mat
	tail_pivot.add_child(tail)
	root.tail = tail_pivot
	var dorsal := MeshInstance3D.new()
	dorsal.mesh = c.dorsal
	dorsal.material_override = c.fin_mat
	sway.add_child(dorsal)
	var prof: Array = spec.prof
	for side in [1.0, -1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.22, -_profile(prof, 0.72).x * 0.45, _profile(prof, 0.72).y * 0.85 * side)
		pivot.rotation.y = 0.0 if side > 0.0 else PI
		sway.add_child(pivot)
		var pec := MeshInstance3D.new()
		pec.mesh = c.pec
		pec.material_override = c.fin_mat
		pivot.add_child(pec)
		root.fins.append(pivot)
		var eye_white := MeshInstance3D.new()
		eye_white.mesh = c.eye
		eye_white.material_override = _plain(Color(0.96, 0.96, 0.9))
		var eh := _profile(prof, 0.86)
		eye_white.position = Vector3(0.36, eh.x * 0.3, eh.y * 0.82 * side)
		eye_white.scale = Vector3.ONE * 0.045
		sway.add_child(eye_white)
		var pupil := MeshInstance3D.new()
		pupil.mesh = c.eye
		pupil.material_override = _plain(Color(0.02, 0.02, 0.05))
		pupil.position = Vector3(0.012, 0.0, 0.012 * side) * 1.0
		pupil.scale = Vector3.ONE * 0.55
		eye_white.add_child(pupil)

static func _plain(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

# ---------- the non-fish catches ----------
static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _build_boot(root: FishNode) -> void:
	var leather := _plain(Color(0.42, 0.27, 0.16))
	var dark := _plain(Color(0.18, 0.11, 0.08))
	var weed := _plain(Color(0.2, 0.5, 0.3))
	var sway := Node3D.new()
	root.add_child(sway)
	root.sway = sway
	sway.rotation.z = -0.35
	_box(sway, Vector3(0.05, -0.2, 0), Vector3(0.9, 0.12, 0.34), dark)
	_box(sway, Vector3(-0.2, 0.05, 0), Vector3(0.38, 0.55, 0.32), leather)
	_box(sway, Vector3(0.2, -0.08, 0), Vector3(0.45, 0.22, 0.32), leather)
	_box(sway, Vector3(-0.2, 0.34, 0), Vector3(0.42, 0.06, 0.36), dark)
	for i in 3:
		_box(sway, Vector3(-0.02, 0.1 + i * 0.1, 0.17), Vector3(0.05, 0.03, 0.02), _plain(Color(0.9, 0.85, 0.7)))
	_box(sway, Vector3(0.1, -0.12, -0.18), Vector3(0.14, 0.05, 0.1), weed)
	_box(sway, Vector3(-0.28, 0.1, 0.17), Vector3(0.05, 0.3, 0.03), weed)

static func _build_coin(root: FishNode) -> void:
	var sway := Node3D.new()
	root.add_child(sway)
	root.sway = sway
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 0.07
	cm.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = _plain(Color(0.95, 0.75, 0.2), 0.7)
	mi.rotation.x = PI * 0.5
	sway.add_child(mi)
	var rim := CylinderMesh.new()
	rim.top_radius = 0.3
	rim.bottom_radius = 0.3
	rim.height = 0.085
	rim.radial_segments = 20
	var ri := MeshInstance3D.new()
	ri.mesh = rim
	ri.material_override = _plain(Color(1.0, 0.9, 0.5), 0.9)
	ri.rotation.x = PI * 0.5
	sway.add_child(ri)

static func _build_pearl(root: FishNode) -> void:
	var sway := Node3D.new()
	root.add_child(sway)
	root.sway = sway
	var sm := SphereMesh.new()
	sm.radius = 0.4
	sm.height = 0.8
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.97, 1.0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = Color(0.5, 0.95, 1.0)
	m.emission_energy_multiplier = 1.2
	mi.material_override = m
	sway.add_child(mi)
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.16
	cs.height = 0.32
	core.mesh = cs
	core.material_override = _plain(Color(1, 1, 1), 2.0)
	sway.add_child(core)
	root.glow_mat = m
