class_name Wildlife
extends Node3D
## The shore comes alive: a fox slips along the bank at dusk and by night, deer graze at the treeline by day and at dawn, a hare hops
## about on clear days, and an owl sits on a perch pole at night and turns its head to follow you. Everything is bounded (one fox, one
## small deer group, one hare, one owl), keeps off the ice and out of the camp, flees from the player and is removed again once far away.
## No gameplay: it is life, not a system. `rules` (pure, static) decides who may be out; the nodes only pose and walk.

const MAX_FOX := 1
const MAX_DEER := 3
const MAX_HARE := 1
const FLEE := {"fox": 10.0, "deer": 17.0, "hare": 7.0}
const DESPAWN_DIST := 150.0
const MIN_SPAWN_DIST := 24.0
const MAX_SPAWN_DIST := 62.0     # foxes and hares: out on the far ice, in sight but never in your way
const MAX_SPAWN_DIST_DEER := 125.0   # deer keep to the bank, which is a long way from the camp
const CAMP_R := 52.0             # nobody walks through the camp

var scenery: Node3D
var rng := RandomNumberGenerator.new()
var animals: Array = []        # {kind, node, vel, state, t, speed, dir, hop}
var spawn_t := 6.0
var owl: Node3D
var owl_head: Node3D
var owl_eyes: Array = []
var owl_pos := Vector3.ZERO
var night := 0.0
var clear_sky := true
var time_of_day := 0.0

func setup(sc: Node3D, seed_in := 41) -> void:
	scenery = sc
	rng.seed = seed_in
	_build_owl()

## Who may be about, as pure data. `night` 0..1 (0 golden hour .. 1 midnight), `dawn` true in the dawn window, `weather` a Weather state name.
static func rules(night_in: float, dawn: bool, weather: String) -> Dictionary:
	var calm := weather in ["clear", "flurry", "fog"]
	return {
		"fox": (night_in > 0.12 or dawn) and weather != "blizzard",
		"deer": (night_in < 0.3 or dawn) and calm,
		"hare": night_in < 0.5 and weather in ["clear", "flurry"],
		"owl": night_in > 0.35,
	}

static func count_of(list: Array, kind: String) -> int:
	var n := 0
	for a in list:
		if a.kind == kind:
			n += 1
	return n

## A spawn point. Deer: on the bank (7-26 m beyond the shore), up to 125 m from the player. Fox and hare: on the outer ice or the bank, 24-62 m from the
## player and outside the camp. Vector3.INF if the draw fails.
func pick_spawn(player: Vector3, kind := "fox") -> Vector3:
	for i in 24:
		var a := rng.randf() * TAU
		var deg := rad_to_deg(a)
		var edge: float = scenery.edge_at_bearing(a)
		var r: float
		var maxd := MAX_SPAWN_DIST
		if kind == "deer":
			r = edge + rng.randf_range(7.0, 26.0)
			maxd = MAX_SPAWN_DIST_DEER
		else:
			r = rng.randf_range(CAMP_R + 4.0, edge + 20.0)
		var p: Vector3 = scenery.bearing_pos(deg, r)
		var d := Vector2(p.x - player.x, p.z - player.z).length()
		if d < MIN_SPAWN_DIST or d > maxd or r > 135.0:
			continue
		p.y = scenery.ground_h(p.x, p.z)
		return p
	return Vector3.INF

func update(delta: float, night_in: float, dawn: bool, weather: String, player: Vector3, cutscene := false) -> void:
	night = night_in
	var rl := rules(night_in, dawn, weather)
	# the owl on its pole: shown at night, head follows you, eyes glow
	if owl != null:
		owl.visible = rl.owl and not cutscene
		if owl.visible:
			var to := Vector2(player.x - owl_pos.x, player.z - owl_pos.z)
			var want := wrapf(atan2(-to.x, to.y) + PI * 0.5 - owl.rotation.y, -PI, PI)   # the head turns, the body stays
			owl_head.rotation.y = lerp_angle(owl_head.rotation.y, clampf(want, -1.9, 1.9), minf(1.0, delta * 2.5))
			for e in owl_eyes:
				(e as MeshInstance3D).visible = true
	if cutscene:
		return
	# who is out
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = rng.randf_range(8.0, 20.0)
		_try_spawn(rl, player)
	var keep := []
	for a in animals:
		var gone := _step_animal(a, delta, player, rl)
		if gone:
			a.node.queue_free()
		else:
			keep.append(a)
	animals = keep

func _try_spawn(rl: Dictionary, player: Vector3) -> void:
	var options := []
	if rl.fox and count_of(animals, "fox") < MAX_FOX:
		options.append("fox")
	if rl.deer and count_of(animals, "deer") == 0:
		options.append("deer")
	if rl.hare and count_of(animals, "hare") < MAX_HARE:
		options.append("hare")
	if options.is_empty():
		return
	var kind: String = options[rng.randi() % options.size()]
	var p := pick_spawn(player, kind)
	if p == Vector3.INF:
		return
	var n := 3 if kind == "deer" else 1
	for i in n:
		var off := Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0)) if i > 0 else Vector3.ZERO
		var node := _make(kind)
		add_child(node)
		var q := p + off
		q.y = scenery.ground_h(q.x, q.z)
		node.position = q
		var dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		node.rotation.y = atan2(-dir.z, dir.x)
		animals.append({"kind": kind, "node": node, "state": "wander" if kind != "deer" else "graze", "t": rng.randf_range(1.0, 4.0),
			"speed": 0.0, "dir": dir, "hop": 0.0, "vel": Vector3.ZERO, "age": 0.0})

## Moves one animal. Returns true when it should be removed (far away, or no longer wanted and out of sight).
func _step_animal(a: Dictionary, delta: float, player: Vector3, rl: Dictionary) -> bool:
	var node: Node3D = a.node
	var p := node.position
	var to_p := Vector3(player.x - p.x, 0.0, player.z - p.z)
	var dist := to_p.length()
	a.age += delta
	if dist > DESPAWN_DIST or (not rl.get(a.kind, true) and dist > 35.0) or a.age > 240.0 and dist > 30.0:
		return true
	if dist < FLEE[a.kind] and a.state != "flee":
		a.state = "flee"
		a.t = 5.0
		a.dir = (-to_p).normalized() if dist > 0.01 else Vector3.RIGHT
	a.t -= delta
	match a.state:
		"flee":
			a.speed = move_toward(a.speed, 8.0 if a.kind != "hare" else 7.0, delta * 20.0)
			if a.t <= 0.0 and dist > FLEE[a.kind] * 1.6:
				a.state = "wander" if a.kind != "deer" else "graze"
				a.t = 4.0
		"graze":   # deer: head down, a slow step now and then
			a.speed = move_toward(a.speed, 0.0, delta * 4.0)
			if a.t <= 0.0:
				a.t = rng.randf_range(3.0, 7.0)
				a.state = "wander"
				a.dir = a.dir.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0))
		"stare":   # fox: stops and looks at you
			a.speed = move_toward(a.speed, 0.0, delta * 6.0)
			if a.t <= 0.0:
				a.state = "wander"
				a.t = rng.randf_range(5.0, 9.0)
		_:   # wander
			var want := 1.5 if a.kind == "fox" else (0.9 if a.kind == "deer" else 2.5)
			a.speed = move_toward(a.speed, want, delta * 3.0)
			a.dir = a.dir.rotated(Vector3.UP, sin(a.age * 0.7 + p.x) * delta * 0.6)
			if a.t <= 0.0:
				if a.kind == "fox":
					a.state = "stare"
					a.t = rng.randf_range(2.0, 4.0)
				elif a.kind == "deer":
					a.state = "graze"
					a.t = rng.randf_range(4.0, 9.0)
				else:
					a.t = rng.randf_range(1.0, 3.0)
					a.dir = a.dir.rotated(Vector3.UP, rng.randf_range(-1.5, 1.5))
	# step, staying on the bank (never onto the ice, never into the camp)
	var np: Vector3 = p + a.dir * a.speed * delta
	var ang := atan2(np.x, -np.z)
	var edge: float = scenery.edge_at_bearing(ang)
	var r := Vector2(np.x, np.z).length()
	var too_close := (r < edge + 4.0) if a.kind == "deer" else (r < CAMP_R)   # deer keep to the bank; everyone keeps out of the camp
	if too_close:
		a.dir = Vector3(np.x, 0.0, np.z).normalized()   # outward, away from the middle
		np = p + a.dir * a.speed * delta
	np.y = scenery.ground_h(np.x, np.z)
	if a.kind == "hare":
		a.hop += delta * a.speed * 2.6
		np.y += absf(sin(a.hop * PI)) * 0.35 * clampf(a.speed / 2.5, 0.0, 1.0)
	node.position = np
	var face: Vector3 = a.dir
	if a.state == "stare" or a.state == "graze":
		face = a.dir if a.state == "graze" else to_p.normalized()
	if face.length() > 0.01:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-face.z, face.x), minf(1.0, delta * 5.0))
	_pose(a, delta)
	return false

func _pose(a: Dictionary, _delta: float) -> void:
	var node: Node3D = a.node
	var head: Node3D = node.get_node_or_null("head")
	if head == null:
		return
	match a.state:
		"graze":
			head.rotation.z = lerpf(head.rotation.z, -0.85, 0.15)   # nose to the snow
		"stare":
			head.rotation.z = lerpf(head.rotation.z, 0.1, 0.2)
		_:
			head.rotation.z = lerpf(head.rotation.z, 0.0, 0.15)
	var legs := node.get_node_or_null("legs")
	if legs != null:
		var ph: float = a.age * a.speed * 2.2
		var i := 0
		for l in legs.get_children():
			(l as Node3D).rotation.z = sin(ph + (0.0 if i % 3 == 0 else PI)) * 0.6 * clampf(a.speed / 3.0, 0.0, 1.0)
			i += 1

# ---------- the models (primitives, nose along +X) ----------
func _make(kind: String) -> Node3D:
	var root := Node3D.new()
	match kind:
		"fox":
			var c := Color(0.88, 0.44, 0.16)
			ToolModels.ball(root, Vector3(0, 0.42, 0), Vector3(0.5, 0.26, 0.24), c, 0.0, 0.9)
			var head := Node3D.new()
			head.name = "head"
			head.position = Vector3(0.5, 0.52, 0)
			root.add_child(head)
			ToolModels.ball(head, Vector3.ZERO, Vector3(0.2, 0.16, 0.16), c, 0.0, 0.9)
			ToolModels.ball(head, Vector3(0.17, -0.03, 0), Vector3(0.14, 0.07, 0.07), Color(0.95, 0.92, 0.88), 0.0, 0.9)
			ToolModels.ball(head, Vector3(0.3, -0.01, 0), Vector3(0.03, 0.03, 0.03), Color(0.05, 0.05, 0.08), 0.0, 0.5)
			for s in [-1.0, 1.0]:
				ToolModels.box(head, Vector3(-0.05, 0.17, s * 0.08), Vector3(0.05, 0.14, 0.05), Color(0.2, 0.12, 0.08), 0.0, 0.9)
			ToolModels.ball(root, Vector3(-0.55, 0.46, 0), Vector3(0.45, 0.14, 0.14), c, 0.0, 0.9)
			ToolModels.ball(root, Vector3(-0.92, 0.48, 0), Vector3(0.14, 0.11, 0.11), Color(0.96, 0.95, 0.92), 0.0, 0.9)   # the white tail tip
			_legs(root, Color(0.2, 0.12, 0.08), 0.3, 0.2, 0.12)
		"deer":
			var cd := Color(0.62, 0.46, 0.32)
			ToolModels.ball(root, Vector3(0, 0.95, 0), Vector3(0.7, 0.34, 0.3), cd, 0.0, 0.9)
			ToolModels.ball(root, Vector3(0.3, 0.9, 0), Vector3(0.28, 0.28, 0.26), Color(0.92, 0.88, 0.8), 0.0, 0.9)   # pale chest
			var hd := Node3D.new()
			hd.name = "head"
			hd.position = Vector3(0.62, 1.3, 0)
			root.add_child(hd)
			ToolModels.box(hd, Vector3(0, -0.2, 0), Vector3(0.12, 0.45, 0.12), cd, 0.0, 0.9)   # the neck hangs from the shoulder (the head pivots with it)
			ToolModels.ball(hd, Vector3(0.1, 0.02, 0), Vector3(0.2, 0.14, 0.13), cd, 0.0, 0.9)
			ToolModels.ball(hd, Vector3(0.26, -0.01, 0), Vector3(0.03, 0.03, 0.03), Color(0.05, 0.05, 0.08), 0.0, 0.5)
			for s in [-1.0, 1.0]:
				ToolModels.box(hd, Vector3(0.0, 0.2, s * 0.09), Vector3(0.04, 0.22, 0.04), Color(0.55, 0.45, 0.35), 0.0, 0.9)   # antler
			_legs(root, Color(0.34, 0.24, 0.17), 0.75, 0.3, 0.12)
			ToolModels.ball(root, Vector3(-0.42, 1.0, 0), Vector3(0.12, 0.12, 0.1), Color(0.95, 0.93, 0.9), 0.0, 0.9)
		"hare":
			var ch := Color(0.82, 0.8, 0.76)
			ToolModels.ball(root, Vector3(0, 0.2, 0), Vector3(0.26, 0.17, 0.14), ch, 0.0, 0.9)
			var hh := Node3D.new()
			hh.name = "head"
			hh.position = Vector3(0.25, 0.3, 0)
			root.add_child(hh)
			ToolModels.ball(hh, Vector3.ZERO, Vector3(0.1, 0.09, 0.08), ch, 0.0, 0.9)
			for s in [-1.0, 1.0]:
				ToolModels.box(hh, Vector3(-0.03, 0.17, s * 0.04), Vector3(0.03, 0.22, 0.03), ch, 0.0, 0.9)
			ToolModels.ball(root, Vector3(-0.28, 0.24, 0), Vector3(0.07, 0.07, 0.07), Color(0.98, 0.98, 0.98), 0.0, 0.9)
	return root

func _legs(root: Node3D, c: Color, h: float, half_len: float, half_w: float) -> void:
	var legs := Node3D.new()
	legs.name = "legs"
	root.add_child(legs)
	for p in [Vector2(half_len, half_w), Vector2(half_len, -half_w), Vector2(-half_len, half_w), Vector2(-half_len, -half_w)]:
		var piv := Node3D.new()
		piv.position = Vector3(p.x, h, p.y)
		legs.add_child(piv)
		ToolModels.box(piv, Vector3(0, -h * 0.5, 0), Vector3(0.06, h, 0.06), c, 0.0, 0.9)

func _build_owl() -> void:
	# a bare perch pole on the bank (bearing 205 deg), the owl on top: a round body, a head that turns, two amber eyes
	var deg := 205.0
	var r: float = scenery.edge_at_bearing(deg_to_rad(deg)) + 13.0
	var p: Vector3 = scenery.bearing_pos(deg, r)
	p.y = scenery.ground_h(p.x, p.z)
	var pole := Node3D.new()
	pole.position = p
	add_child(pole)
	ToolModels.box(pole, Vector3(0, 2.6, 0), Vector3(0.22, 5.2, 0.22), Color(0.3, 0.24, 0.26), 0.0, 0.9)
	ToolModels.box(pole, Vector3(0.5, 4.3, 0), Vector3(1.0, 0.1, 0.1), Color(0.3, 0.24, 0.26), 0.0, 0.9).rotation.z = 0.2
	owl = Node3D.new()
	owl.position = Vector3(0, 5.3, 0)
	pole.add_child(owl)
	owl_pos = p
	var fur := Color(0.5, 0.42, 0.36)
	ToolModels.ball(owl, Vector3(0, 0.22, 0), Vector3(0.24, 0.3, 0.22), fur, 0.0, 0.95)
	owl_head = Node3D.new()
	owl_head.position = Vector3(0, 0.55, 0)
	owl.add_child(owl_head)
	ToolModels.ball(owl_head, Vector3.ZERO, Vector3(0.2, 0.17, 0.2), Color(0.62, 0.54, 0.46), 0.0, 0.95)
	for s in [-1.0, 1.0]:
		ToolModels.box(owl_head, Vector3(0.0, 0.17, s * 0.12), Vector3(0.05, 0.1, 0.05), fur, 0.0, 0.95)   # ear tufts
		var eye := ToolModels.ball(owl_head, Vector3(0.17, 0.02, s * 0.08), Vector3(0.045, 0.045, 0.045), Color(1.0, 0.8, 0.3), 2.5, 0.4)
		owl_eyes.append(eye)
	ToolModels.box(owl_head, Vector3(0.2, -0.04, 0), Vector3(0.05, 0.07, 0.04), Color(0.85, 0.65, 0.3), 0.0, 0.6)   # beak
	owl.rotation.y = atan2(-(0.0 - p.z), 0.0 - p.x)   # facing the middle of the lake
	owl.visible = false
