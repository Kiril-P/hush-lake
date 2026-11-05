class_name ItemModels
extends RefCounted
## Things you carry that are not tools: the bucket (with the fish heaped inside it) and the tool rack. Built from primitives
## like everything else; palette rule (docs/STYLE.md): galvanized steel and dark wood, warm amber only on what is yours.

const PAIL := Color(0.58, 0.64, 0.74)
const PAIL_DARK := Color(0.3, 0.34, 0.44)
const AMBER := Color(1.0, 0.78, 0.35)

## A bucket standing on the ice (origin at its base). Returns {root, pile}: `pile` holds the fish heaped inside, see set_pile().
static func bucket(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	var body := CylinderMesh.new()
	body.top_radius = 0.5
	body.bottom_radius = 0.4
	body.height = 0.7
	body.radial_segments = 12
	var bm := ToolModels._add(root, body, ToolModels.mat(PAIL, 0.0, 0.45, 0.6), Vector3(0, 0.35, 0))
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var inner := CylinderMesh.new()   # the dark mouth: you can see it is hollow
	inner.top_radius = 0.43
	inner.bottom_radius = 0.43
	inner.height = 0.02
	inner.radial_segments = 12
	ToolModels._add(root, inner, ToolModels.mat(Color(0.06, 0.08, 0.14), 0.0, 0.9), Vector3(0, 0.69, 0))
	for y in [0.16, 0.5]:   # two dark bands
		var band := CylinderMesh.new()
		band.top_radius = lerpf(0.4, 0.5, y / 0.7) + 0.012
		band.bottom_radius = band.top_radius
		band.height = 0.045
		band.radial_segments = 12
		ToolModels._add(root, band, ToolModels.mat(PAIL_DARK, 0.0, 0.5, 0.5), Vector3(0, y, 0))
	var rim := TorusMesh.new()   # the amber lip: the one warm note, and what makes it read on white ice
	rim.inner_radius = 0.47
	rim.outer_radius = 0.54
	rim.rings = 16
	rim.ring_segments = 5
	ToolModels._add(root, rim, ToolModels.mat(AMBER, 0.45, 0.5), Vector3(0, 0.7, 0))
	var handle := TorusMesh.new()   # the bail: a half ring across the top
	handle.inner_radius = 0.49
	handle.outer_radius = 0.52
	handle.rings = 18
	handle.ring_segments = 4
	var hm := ToolModels._add(root, handle, ToolModels.mat(PAIL_DARK, 0.0, 0.4, 0.7), Vector3(0, 0.7, 0))
	hm.rotation_degrees = Vector3(90, 0, 0)
	hm.scale = Vector3(1.0, 1.0, 0.6)
	var pile := Node3D.new()
	root.add_child(pile)
	return {"root": root, "pile": pile}

## Heaps the fish into the mouth: a lump per fish (up to 9), in their own colours, higher the fuller the bucket.
static func set_pile(pile: Node3D, colors: Array, frac: float) -> void:
	for c in pile.get_children():
		c.queue_free()
	var n := mini(colors.size(), 9)
	for i in n:
		var a := float(i) * 2.4 + 0.5
		var rr := 0.0 if i == 0 else 0.1 + 0.2 * (float(i % 4) / 3.0)
		var y := 0.44 + 0.34 * clampf(frac, 0.0, 1.0) + 0.05 * (i % 3)
		var lump := ToolModels.ball(pile, Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(0.32, 0.13, 0.15), colors[i], 0.25)
		lump.rotation.y = a * 1.7
		var tail := ToolModels.box(lump, Vector3(0.55, 0.0, 0.0), Vector3(0.28, 0.5, 0.12), (colors[i] as Color).darkened(0.15), 0.1)
		tail.rotation.y = 0.0

## The tool rack: a weathered board on two posts, one row per tool (drill, rod, kit), each on two pegs with a lamp over the board.
## Returns the local centre of each row.
static func rack(parent: Node3D) -> Array:
	var wood := Color(0.78, 0.66, 0.5)   # a pale weathered board: dark steel and amber tools read against it
	var dark := Color(0.3, 0.21, 0.16)
	var snow := Color(0.9, 0.95, 1.0)
	for x in [-2.0, 2.0]:
		ToolModels.box(parent, Vector3(x, 1.65, 0.0), Vector3(0.24, 3.3, 0.24), dark, 0.0, 0.85)
	ToolModels.box(parent, Vector3(0, 1.75, 0.03), Vector3(3.9, 2.7, 0.14), wood, 0.0, 0.85)   # the board
	for k in 6:
		ToolModels.box(parent, Vector3(-1.62 + k * 0.65, 1.75, 0.11), Vector3(0.03, 2.64, 0.03), wood.darkened(0.22), 0.0, 0.9)   # plank lines
	ToolModels.box(parent, Vector3(0, 3.18, 0.0), Vector3(4.4, 0.2, 0.6), dark, 0.0, 0.85)   # roof beam
	ToolModels.box(parent, Vector3(0, 3.33, 0.0), Vector3(4.3, 0.16, 0.54), snow, 0.3)   # snow on it
	var lamp := ToolModels.box(parent, Vector3(1.75, 3.0, 0.3), Vector3(0.22, 0.3, 0.22), AMBER, 1.6)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rows := []
	for y in [2.55, 1.75, 0.95]:
		ToolModels.box(parent, Vector3(0, y - 0.28, 0.12), Vector3(3.5, 0.05, 0.05), AMBER.darkened(0.35), 0.35)   # an amber rule under each row
		for dx in [-0.75, 0.75]:   # two pegs per tool
			ToolModels.box(parent, Vector3(dx, y, 0.2), Vector3(0.08, 0.08, 0.24), PAIL_DARK, 0.0, 0.5, 0.6)
		rows.append(Vector3(0, y, 0.3))
	return rows

## A tool lying on the ice: the first-person model without its mittens, laid flat and a little larger so it reads from a distance.
static func ground_tool(parent: Node3D, t: int, tier: int, tier_color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	match t:
		0: ToolModels.auger(body, tier_color, tier, false)
		1: ToolModels.rod(body, tier_color, tier, false)
		_: ToolModels.builder(body, accent, false)
	body.scale = Vector3.ONE * 1.35
	body.position = Vector3(0, 0.1, 0.45)
	return root
