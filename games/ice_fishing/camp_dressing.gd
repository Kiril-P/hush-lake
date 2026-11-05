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
var mailbox_flag: Node3D     # raised when there is an unread letter (see story.gd)
var mailbox_body: StaticBody3D
var shelf: Node3D            # Olga's keepsake shelf by the door
var _unread := -1
var _keeps_sig := ""
var hut_node: Node3D

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
	hut_node = hut
	_mailbox(hp - hb.x * 2.3 + hb.z * 4.0, hut.rotation.y)
	_build_shelf(hut)
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

## Olga's mailbox: a post, a tin box with a rounded lid, a flag that goes up when a letter waits. The click target is "mailbox".
func _mailbox(at: Vector3, yaw: float) -> void:
	var g := Node3D.new()
	g.position = Vector3(at.x, 0.0, at.z)
	g.rotation.y = yaw
	root.add_child(g)
	ToolModels.box(g, Vector3(0, 0.7, 0), Vector3(0.14, 1.4, 0.14), WOOD_DARK, 0.0, 0.85)
	ToolModels.box(g, Vector3(0, 1.5, 0), Vector3(0.62, 0.34, 0.9), Color(0.25, 0.36, 0.5), 0.0, 0.5, 0.4)
	var lid := CylinderMesh.new()
	lid.top_radius = 0.32
	lid.bottom_radius = 0.32
	lid.height = 0.9
	lid.radial_segments = 10
	var lm := ToolModels._add(g, lid, ToolModels.mat(Color(0.25, 0.36, 0.5), 0.0, 0.5, 0.4), Vector3(0, 1.67, 0))
	lm.rotation_degrees = Vector3(90, 0, 0)
	lm.scale = Vector3(1.0, 1.0, 0.55)
	ToolModels.box(g, Vector3(0, 1.5, 0.46), Vector3(0.56, 0.28, 0.03), Color(0.1, 0.14, 0.2), 0.0, 0.6)   # the slot door
	_snow_cap(g, Vector3(0, 1.88, 0), Vector3(0.5, 0.06, 0.8))
	mailbox_flag = Node3D.new()
	mailbox_flag.position = Vector3(0.34, 1.62, -0.1)
	g.add_child(mailbox_flag)
	ToolModels.box(mailbox_flag, Vector3(0, 0.18, 0), Vector3(0.04, 0.36, 0.04), WOOD_DARK, 0.0, 0.8)
	ToolModels.box(mailbox_flag, Vector3(0.0, 0.36, 0.12), Vector3(0.03, 0.14, 0.26), AMBER, 0.8, 0.6)
	mailbox_flag.rotation_degrees.x = 90.0   # down until a letter comes
	mailbox_body = StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.0, 1.6, 1.2)
	cs.shape = bx
	mailbox_body.add_child(cs)
	mailbox_body.position = Vector3(0, 0.9, 0)
	mailbox_body.set_meta("action", "mailbox")
	g.add_child(mailbox_body)

## A little wall shelf on the hut front, left of the door, two planks on brackets. Keepsakes appear on it as you find them.
func _build_shelf(hut: Node3D) -> void:
	shelf = Node3D.new()
	shelf.position = Vector3(-1.95, 0.0, 2.1)   # hut local: the front wall faces +Z
	hut.add_child(shelf)
	for y in [1.35, 1.85]:
		ToolModels.box(shelf, Vector3(0, y, 0.12), Vector3(1.5, 0.05, 0.28), WOOD, 0.0, 0.85)
		for x in [-0.6, 0.6]:
			ToolModels.box(shelf, Vector3(x, y - 0.1, 0.04), Vector3(0.05, 0.16, 0.05), WOOD_DARK, 0.0, 0.85)

## Puts the found keepsakes on the shelf (a small primitive model each). Rebuilds only when the set changes.
func set_keeps(ids: Array) -> void:
	var sig := ",".join(ids)
	if sig == _keeps_sig or shelf == null:
		return
	_keeps_sig = sig
	for c in shelf.get_children():
		if c.has_meta("keep"):
			shelf.remove_child(c)   # (out of the tree now, so a second rebuild in the same frame never double-counts)
			c.queue_free()
	var slot := 0
	for k in Story.KEEPS:
		if not ids.has(k.id):
			continue
		var row := slot / 4
		var col := slot % 4
		var p := Node3D.new()
		p.set_meta("keep", k.id)
		p.position = Vector3(-0.54 + col * 0.36, 1.375 + row * 0.5, 0.14)
		shelf.add_child(p)
		_keep_model(p, k.id, k.color)
		slot += 1

func _keep_model(p: Node3D, id: String, c: Color) -> void:
	match id:
		"thermos":
			var m := CylinderMesh.new()
			m.top_radius = 0.06
			m.bottom_radius = 0.06
			m.height = 0.26
			m.radial_segments = 8
			ToolModels._add(p, m, ToolModels.mat(c, 0.0, 0.4, 0.3), Vector3(0, 0.15, 0))
			ToolModels.box(p, Vector3(0, 0.3, 0), Vector3(0.1, 0.04, 0.1), AMBER, 0.2)
		"mitten":
			ToolModels.box(p, Vector3(0, 0.1, 0), Vector3(0.13, 0.18, 0.05), c, 0.0, 0.95)
			ToolModels.box(p, Vector3(-0.08, 0.08, 0), Vector3(0.05, 0.08, 0.05), c, 0.0, 0.95)
		"key":
			ToolModels.box(p, Vector3(0, 0.03, 0), Vector3(0.2, 0.025, 0.03), c, 0.3, 0.3, 0.7)
			var t := TorusMesh.new()
			t.inner_radius = 0.025
			t.outer_radius = 0.05
			ToolModels._add(p, t, ToolModels.mat(c, 0.3, 0.3, 0.7), Vector3(-0.1, 0.035, 0)).rotation_degrees.x = 90.0
		"ring":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.035
			t2.outer_radius = 0.06
			ToolModels._add(p, t2, ToolModels.mat(c, 0.6, 0.2, 0.9), Vector3(0, 0.07, 0)).rotation_degrees.x = 80.0
		"logbook":
			ToolModels.box(p, Vector3(0, 0.1, 0), Vector3(0.22, 0.2, 0.05), c, 0.0, 0.8)
			ToolModels.box(p, Vector3(-0.1, 0.1, 0.03), Vector3(0.025, 0.2, 0.01), AMBER, 0.3)
		"compass":
			var m2 := CylinderMesh.new()
			m2.top_radius = 0.08
			m2.bottom_radius = 0.08
			m2.height = 0.03
			m2.radial_segments = 12
			var cm := ToolModels._add(p, m2, ToolModels.mat(c, 0.2, 0.3, 0.7), Vector3(0, 0.1, 0))
			cm.rotation_degrees.x = 80.0
			ToolModels.box(p, Vector3(0, 0.1, 0.02), Vector3(0.012, 0.1, 0.01), Color(0.9, 0.2, 0.2), 0.4)
		"photo":
			ToolModels.box(p, Vector3(0, 0.11, 0), Vector3(0.2, 0.15, 0.02), c, 0.1, 0.9)
			ToolModels.box(p, Vector3(0, 0.11, 0.012), Vector3(0.16, 0.11, 0.01), Color(0.35, 0.5, 0.6), 0.0, 0.9)
		_:
			var m3 := CylinderMesh.new()
			m3.top_radius = 0.025
			m3.bottom_radius = 0.025
			m3.height = 0.22
			m3.radial_segments = 6
			var wm := ToolModels._add(p, m3, ToolModels.mat(c, 0.0, 0.3, 0.7), Vector3(0, 0.04, 0))
			wm.rotation_degrees.z = 90.0

## Raises the mailbox flag when there are unread letters.
func set_unread(n: int) -> void:
	if n == _unread or mailbox_flag == null:
		return
	_unread = n
	var to := 0.0 if n > 0 else 90.0
	if not mailbox_flag.is_inside_tree():
		mailbox_flag.rotation_degrees.x = to
		return
	mailbox_flag.create_tween().tween_property(mailbox_flag, "rotation_degrees:x", to, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
