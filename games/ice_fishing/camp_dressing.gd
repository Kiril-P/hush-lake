class_name CampDressing
extends RefCounted
## The small lived-in things round the camp that the reference pass asked for: crates and sacks by every stall, a sled, a barrel
## and a woodpile by Olga's hut, a snowman with an amber scarf, a flag on a pole, and soft amber light pools on the ice under the
## lamps (strong at dusk and night, a whisper by day). All primitives, no per-frame work except the lights' fade (see fade()).

const AMBER := Color(1.0, 0.78, 0.35)
const WOOD := Color(0.48, 0.33, 0.22)
const WOOD_DARK := Color(0.3, 0.21, 0.16)
const SNOW := Color(0.9, 0.96, 1.0)

var lights: Array = []   # [OmniLight3D, day energy, night energy]
var root: Node3D

func build(parent: Node3D, scn, hut: Node3D, spots: Dictionary) -> void:
	root = Node3D.new()
	root.name = "CampDressing"
	parent.add_child(root)
	# --- Olga's hut: a sled, crates, a barrel, a woodpile, a snowman, and a light on the door
	var hp := hut.global_position
	var hb := hut.global_basis   # local +Z faces the lake centre
	_sled(hp + hb.x * 4.4 + hb.z * 2.2, hut.rotation.y + 0.5)
	_crates(hp - hb.x * 3.7 + hb.z * 1.9, 3, 0.3)
	_barrel(hp - hb.x * 4.6 + hb.z * 0.6)
	_woodpile(hp - hb.x * 2.8 - hb.z * 2.6, hut.rotation.y)
	_snowman(hp + hb.x * 6.6 + hb.z * 3.4)
	_light(hp + hb.z * 3.3 + Vector3(0, 2.1, 0), 11.0, 0.35, 3.6)
	# --- every stall: a crate stack and a sack to one side, a lamp pool in front
	for id in spots:
		if id in ["lines", "sonar", "wide", "conveyor", "snowmobile"]:
			continue   # the outposts are far out: they get their own dressing when they are found
		var sp: Array = spots[id]
		var deg: float = sp[0]
		var d: float = sp[1]
		var side := 4.0 / maxf(d, 1.0) * 57.3
		var base: Vector3 = scn.bearing_pos(deg + side, d + 0.6)
		_crates(base, 2, deg_to_rad(-deg))
		_sack(scn.bearing_pos(deg - side * 0.8, d + 0.9), 0.6)
		_light(scn.bearing_pos(deg, d - 2.4) + Vector3(0, 2.4, 0), 7.5, 0.1, 2.4)
	# --- a flag on a tall pole at the camp's edge (teal cloth, amber stripe: the palette in the wind)
	_flag(scn.bearing_pos(-12.0, 33.0))

func _snow_cap(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	ToolModels.box(parent, pos, size, SNOW, 0.0, 0.9)

func _crates(at: Vector3, n: int, yaw: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(at.x, 0.0, at.z)
	g.rotation.y = yaw
	root.add_child(g)
	for i in n:
		var s := 0.78 - 0.06 * i
		var o := Vector3((i % 2) * 0.82 - 0.2, s * 0.5 + (0.78 if i == 2 else 0.0), (i % 3) * 0.2)
		ToolModels.box(g, o, Vector3(s, s, s), WOOD, 0.0, 0.85)
		ToolModels.box(g, o + Vector3(0, s * 0.5 - 0.02, 0), Vector3(s + 0.04, 0.05, s + 0.04), WOOD_DARK, 0.0, 0.85)   # lid rim
		ToolModels.box(g, o + Vector3(0, 0, s * 0.5), Vector3(s, 0.08, 0.03), WOOD_DARK, 0.0, 0.85)
		if i == n - 1 or i == 1:
			_snow_cap(g, o + Vector3(0, s * 0.5 + 0.03, 0), Vector3(s * 0.92, 0.07, s * 0.92))

func _sack(at: Vector3, s: float) -> void:
	var b := ToolModels.ball(root, Vector3(at.x, s * 0.42, at.z), Vector3(s * 0.9, s * 0.8, s * 0.8), Color(0.62, 0.55, 0.42), 0.0, 0.9)
	b.rotation.y = at.x
	ToolModels.ball(root, Vector3(at.x, s * 0.88, at.z), Vector3(s * 0.32, s * 0.24, s * 0.32), Color(0.52, 0.45, 0.34), 0.0, 0.9)   # the tied neck

func _barrel(at: Vector3) -> void:
	var m := CylinderMesh.new()
	m.top_radius = 0.42
	m.bottom_radius = 0.42
	m.height = 0.95
	m.radial_segments = 10
	ToolModels._add(root, m, ToolModels.mat(WOOD, 0.0, 0.85), Vector3(at.x, 0.475, at.z))
	for y in [0.18, 0.77]:
		var band := CylinderMesh.new()
		band.top_radius = 0.44
		band.bottom_radius = 0.44
		band.height = 0.07
		band.radial_segments = 10
		ToolModels._add(root, band, ToolModels.mat(Color(0.3, 0.34, 0.44), 0.0, 0.5, 0.6), Vector3(at.x, y, at.z))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.38
	lid.bottom_radius = 0.38
	lid.height = 0.05
	lid.radial_segments = 10
	ToolModels._add(root, lid, ToolModels.mat(SNOW, 0.0, 0.9), Vector3(at.x, 0.97, at.z))

func _woodpile(at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(at.x, 0.0, at.z)
	g.rotation.y = yaw
	root.add_child(g)
	for row in 3:
		for k in 4 - row:
			var m := CylinderMesh.new()
			m.top_radius = 0.17
			m.bottom_radius = 0.17
			m.height = 1.5
			m.radial_segments = 6
			var mi := ToolModels._add(g, m, ToolModels.mat(WOOD.lightened(0.1 * (k % 2)), 0.0, 0.9), Vector3(-0.5 * (3 - row) * 0.5 + k * 0.38 + row * 0.19 - 0.3, 0.17 + row * 0.32, 0.0))
			mi.rotation_degrees = Vector3(0, 0, 90)
	_snow_cap(g, Vector3(0, 1.0, 0), Vector3(1.9, 0.08, 1.6))

func _sled(at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(at.x, 0.0, at.z)
	g.rotation.y = yaw
	root.add_child(g)
	for x in [-0.42, 0.42]:   # runners
		ToolModels.box(g, Vector3(x, 0.09, 0.0), Vector3(0.09, 0.16, 2.0), WOOD_DARK, 0.0, 0.8)
		var tip := ToolModels.box(g, Vector3(x, 0.2, -1.05), Vector3(0.09, 0.09, 0.4), WOOD_DARK, 0.0, 0.8)
		tip.rotation_degrees.x = 35.0
	ToolModels.box(g, Vector3(0, 0.22, 0.0), Vector3(1.02, 0.07, 1.8), WOOD, 0.0, 0.85)   # the bed
	ToolModels.box(g, Vector3(0, 0.55, 0.2), Vector3(0.78, 0.5, 0.9), Color(0.5, 0.18, 0.2), 0.0, 0.95)   # a rolled red blanket
	ToolModels.box(g, Vector3(0, 0.55, 0.2), Vector3(0.8, 0.5, 0.12), AMBER.darkened(0.2), 0.1, 0.95)   # its amber stripe
	ToolModels.box(g, Vector3(0, 0.82, 0.2), Vector3(0.7, 0.07, 0.8), SNOW, 0.0, 0.9)
	ToolModels.box(g, Vector3(0.1, 0.5, -0.55), Vector3(0.5, 0.36, 0.36), Color(0.22, 0.4, 0.34), 0.0, 0.6)   # a green cooler

func _snowman(at: Vector3) -> void:
	ToolModels.ball(root, Vector3(at.x, 0.45, at.z), Vector3(0.85, 0.8, 0.85), SNOW, 0.0, 0.9)
	ToolModels.ball(root, Vector3(at.x, 1.15, at.z), Vector3(0.62, 0.58, 0.62), SNOW, 0.0, 0.9)
	ToolModels.ball(root, Vector3(at.x, 1.68, at.z), Vector3(0.44, 0.42, 0.44), SNOW, 0.0, 0.9)
	ToolModels.box(root, Vector3(at.x, 1.43, at.z), Vector3(0.56, 0.1, 0.56), AMBER, 0.5, 0.8)   # the scarf: the one warm note
	ToolModels.box(root, Vector3(at.x, 1.64, at.z + 0.2), Vector3(0.06, 0.06, 0.2), Color(0.9, 0.5, 0.2), 0.0, 0.8)   # a carrot nose
	for e in [-0.1, 0.1]:
		ToolModels.box(root, Vector3(at.x + e, 1.75, at.z + 0.18), Vector3(0.05, 0.05, 0.03), Color(0.08, 0.08, 0.1), 0.0, 0.8)

func _flag(at: Vector3) -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.1
	pole.height = 7.0
	pole.radial_segments = 6
	ToolModels._add(root, pole, ToolModels.mat(WOOD_DARK, 0.0, 0.8), Vector3(at.x, 3.5, at.z))
	var cloth := Node3D.new()
	cloth.position = Vector3(at.x, 6.0, at.z)
	root.add_child(cloth)
	ToolModels.box(cloth, Vector3(0.9, 0, 0), Vector3(1.7, 1.0, 0.04), Color(0.1, 0.45, 0.55), 0.1, 0.8)
	ToolModels.box(cloth, Vector3(0.9, 0.0, 0.03), Vector3(1.7, 0.14, 0.02), AMBER, 0.5, 0.7)
	ToolModels.box(root, Vector3(at.x, 7.05, at.z), Vector3(0.18, 0.18, 0.18), AMBER, 1.2, 0.5)

func _light(pos: Vector3, rng: float, day_e: float, night_e: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = Color(1.0, 0.72, 0.38)
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.shadow_enabled = false
	l.light_energy = day_e
	root.add_child(l)
	lights.append([l, day_e, night_e])

## Lamp pools breathe with the hour: `night` is Scenery._night (0 by day, 1 at midnight); dusk and dawn get a share too.
func fade(night: float, golden: float) -> void:
	for e in lights:
		e[0].light_energy = lerpf(float(e[1]), float(e[2]), clampf(night + golden * 0.45, 0.0, 1.0))
