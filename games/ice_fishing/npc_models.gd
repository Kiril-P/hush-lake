class_name NpcModels
extends RefCounted
## Olga, who has watched the Eye for forty winters: a low-poly figure in a teal parka with an amber scarf and a knitted
## hat, standing by her hut. She breathes, turns her head to follow you and waves when you come near.

const PARKA := Color(0.14, 0.5, 0.58)
const PARKA_DARK := Color(0.1, 0.34, 0.42)
const CREAM := Color(0.95, 0.92, 0.84)
const SKIN := Color(0.94, 0.76, 0.62)
const AMBER := Color(1.0, 0.76, 0.32)
const ROSE := Color(0.9, 0.45, 0.45)
const BOOT := Color(0.2, 0.15, 0.14)

static func _mat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

static func _mesh(parent: Node, mesh: Mesh, c: Color, pos: Vector3, scale3 := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scale3
	parent.add_child(mi)
	return mi

static func _ball(parent: Node, c: Color, pos: Vector3, r: float, squash := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	return _mesh(parent, sm, c, pos, squash)

static func _cyl(parent: Node, c: Color, pos: Vector3, r_top: float, r_bot: float, h: float) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 10
	return _mesh(parent, cm, c, pos)

## Returns {root, body, head, arm} (arm is the waving right arm, pivoting at the shoulder). Faces +Z, about 1.6 m tall.
static func olga() -> Dictionary:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	# boots and the long parka
	for sx in [-0.1, 0.1]:
		_mesh(body, BoxMesh.new(), BOOT, Vector3(sx, 0.07, 0.04), Vector3(0.14, 0.14, 0.26))
	_cyl(body, PARKA, Vector3(0, 0.62, 0), 0.2, 0.33, 0.95)
	_cyl(body, CREAM, Vector3(0, 0.17, 0), 0.34, 0.345, 0.1)   # the fur hem
	_cyl(body, AMBER.darkened(0.15), Vector3(0, 0.72, 0), 0.245, 0.25, 0.07)   # belt
	_cyl(body, PARKA_DARK, Vector3(0, 0.62, 0.0), 0.012, 0.012, 0.95).position.z = 0.27   # front seam
	# scarf: a ring at the neck and a tail over one shoulder
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.1
	scarf.outer_radius = 0.19
	scarf.rings = 12
	scarf.ring_segments = 6
	_mesh(body, scarf, AMBER, Vector3(0, 1.12, 0))
	_mesh(body, BoxMesh.new(), AMBER, Vector3(0.12, 0.95, 0.17), Vector3(0.09, 0.3, 0.04))
	# head: face, hood trim, knitted hat with a pom-pom
	var head := Node3D.new()
	head.position = Vector3(0, 1.3, 0)
	body.add_child(head)
	_ball(head, SKIN, Vector3.ZERO, 0.17, Vector3(1.0, 1.05, 0.95))
	for sx in [-0.065, 0.065]:
		_ball(head, Color(0.1, 0.08, 0.12), Vector3(sx, 0.02, 0.15), 0.022)
		_ball(head, ROSE.lightened(0.15), Vector3(sx * 1.9, -0.05, 0.12), 0.034, Vector3(1.0, 0.7, 0.5))
	_ball(head, Color(0.85, 0.6, 0.5), Vector3(0, -0.01, 0.17), 0.025)
	var hood := TorusMesh.new()
	hood.inner_radius = 0.15
	hood.outer_radius = 0.23
	hood.rings = 14
	hood.ring_segments = 6
	var hood_mi := _mesh(head, hood, CREAM, Vector3(0, 0.0, -0.02))
	hood_mi.rotation_degrees.x = 90.0
	hood_mi.scale = Vector3(1.0, 1.0, 1.15)
	_ball(head, ROSE, Vector3(0, 0.12, -0.02), 0.19, Vector3(1.0, 0.75, 1.0))
	_cyl(head, CREAM, Vector3(0, 0.07, 0.0), 0.185, 0.185, 0.045)   # the hat's cuff
	_ball(head, CREAM, Vector3(0, 0.3, -0.02), 0.06)
	# arms: the left rests, the right pivots at the shoulder so it can wave
	var arm_l := Node3D.new()
	arm_l.position = Vector3(-0.22, 1.0, 0.0)
	arm_l.rotation_degrees.z = -14.0
	body.add_child(arm_l)
	_cyl(arm_l, PARKA, Vector3(0, -0.2, 0), 0.06, 0.07, 0.42)
	_ball(arm_l, AMBER, Vector3(0, -0.45, 0), 0.075)
	var arm := Node3D.new()
	arm.position = Vector3(0.22, 1.0, 0.0)
	arm.rotation_degrees.z = 14.0
	body.add_child(arm)
	_cyl(arm, PARKA, Vector3(0, -0.2, 0), 0.06, 0.07, 0.42)
	_ball(arm, AMBER, Vector3(0, -0.45, 0), 0.075)
	# a small lantern at her feet
	var lan := Node3D.new()
	lan.position = Vector3(0.5, 0.0, 0.2)
	root.add_child(lan)
	_cyl(lan, Color(0.2, 0.2, 0.26), Vector3(0, 0.02, 0), 0.09, 0.1, 0.04)
	_cyl(lan, Color(0.2, 0.2, 0.26), Vector3(0, 0.28, 0), 0.05, 0.1, 0.05)
	var glow := _ball(lan, AMBER, Vector3(0, 0.15, 0), 0.085)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = AMBER
	gm.emission_enabled = true
	gm.emission = AMBER
	gm.emission_energy_multiplier = 2.4
	glow.material_override = gm
	return {"root": root, "body": body, "head": head, "arm": arm}
