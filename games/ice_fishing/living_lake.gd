class_name LivingLake
extends Node3D
## Everything that makes the lake feel alive around the player: the weather's look (snow layers, fog, clouds), stars, gulls by day,
## ice cracks, the camp that grows as the Eye wakes (campfire, string lights, woodpile, sled, a sleeping dog, lantern posts).
## It reads a Weather (numbers) and the sky's night value and moves nodes; sounds are announced by signals, the game plays them.

signal cracked(pos: Vector3, near: float)   # the ice groaned at `pos`; `near` 0..1 is how close to the player
signal owl_called
signal crow_called

const LAKE_R := 90.0
const FOG_BASE := 0.0009
const FOG_MAX := 0.0115   # the thickest fog still lets you read the Eye and the stalls from 30 m

var scenery: Node3D
var weather: Weather
var hut: Node3D
var clouds: Array = []        # {node, speed, y}
var cloud_mat: StandardMaterial3D
var star_mm: Array = []       # two MultiMeshInstance3D (they twinkle in turns)
var star_mat: Array = []
var birds: Array = []         # {node, wing_l, wing_r, r, a, w, y, phase}
var bird_vis := 0.0
var cracks: Array = []        # {node, mat, t}
var crack_t := 20.0
var owl_t := 30.0
var crow_t := 40.0
var _t := 0.0
var camp_level := 0
var camp: Dictionary = {}     # piece name -> Node3D
var flames: Array = []
var fire_light: OmniLight3D
var dog: Node3D
var dog_breath := 0.0
var night := 0.0
var wind_dir := Vector2(1.0, 0.25).normalized()
var rng := RandomNumberGenerator.new()

func setup(sc: Node3D, w: Weather, hut_node: Node3D) -> void:
	scenery = sc
	weather = w
	hut = hut_node
	rng.seed = 4242
	_build_stars()
	_build_clouds()
	_build_birds()
	_build_cracks()

# ---------- the sky: stars and clouds ----------
func _build_stars() -> void:
	for g in 2:
		var q := QuadMesh.new()
		q.size = Vector2(4.6, 4.6)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.9, 0.95, 1.0, 0.0)
		m.disable_fog = true
		m.no_depth_test = false
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = q
		mm.instance_count = 170
		for i in mm.instance_count:
			var az := rng.randf() * TAU
			var el := asin(rng.randf_range(0.07, 0.98))
			var dir := Vector3(cos(el) * sin(az), sin(el), -cos(el) * cos(az))
			var s := rng.randf_range(0.6, 1.5) * (1.0 if rng.randf() < 0.9 else 1.8)
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), dir * 1500.0))
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = m
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.extra_cull_margin = 4000.0
		inst.visible = false
		add_child(inst)
		star_mm.append(inst)
		star_mat.append(m)

func _build_clouds() -> void:
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1, 1, 1, 0.5)
	cloud_mat.disable_fog = true
	for i in 18:
		var n := Node3D.new()
		var a := rng.randf() * TAU
		var r := rng.randf_range(260.0, 760.0)
		var y := rng.randf_range(150.0, 300.0)
		n.position = Vector3(sin(a) * r, y, -cos(a) * r)
		add_child(n)
		for k in rng.randi_range(3, 5):   # a cloud is a few flattened lumps
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 8
			sm.rings = 4
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = cloud_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(rng.randf_range(-45.0, 45.0), rng.randf_range(-4.0, 6.0), rng.randf_range(-20.0, 20.0))
			mi.scale = Vector3(rng.randf_range(60.0, 110.0), rng.randf_range(12.0, 22.0), rng.randf_range(34.0, 60.0))
			n.add_child(mi)
		clouds.append({"node": n, "speed": rng.randf_range(2.0, 5.5), "y": y, "base": rng.randf_range(0.55, 1.0)})

# ---------- life: gulls, cracks ----------
func _build_birds() -> void:
	var body_m := StandardMaterial3D.new()
	body_m.albedo_color = Color(0.92, 0.94, 0.98)
	body_m.roughness = 0.9
	var tip_m := StandardMaterial3D.new()
	tip_m.albedo_color = Color(0.22, 0.26, 0.36)
	for i in 9:
		var n := Node3D.new()
		var body := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.5
		bm.height = 1.0
		bm.radial_segments = 6
		bm.rings = 3
		body.mesh = bm
		body.scale = Vector3(0.38, 0.3, 1.1)
		body.material_override = body_m
		n.add_child(body)
		var wings := []
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.18, 0.05, 0.0)
			n.add_child(pivot)
			var wing := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(1.5, 0.04, 0.5)
			wing.mesh = wm
			wing.position = Vector3(side * 0.75, 0.0, 0.0)
			wing.material_override = body_m
			pivot.add_child(wing)
			var tip := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.35, 0.045, 0.42)
			tip.mesh = tm
			tip.position = Vector3(side * 1.55, 0.0, 0.0)
			tip.material_override = tip_m
			pivot.add_child(tip)
			wings.append(pivot)
		n.scale = Vector3.ONE * 2.4
		n.visible = false
		add_child(n)
		birds.append({"node": n, "wl": wings[0], "wr": wings[1], "r": rng.randf_range(48.0, 92.0), "a": rng.randf() * TAU,
			"w": rng.randf_range(0.03, 0.07) * (1.0 if rng.randf() < 0.5 else -1.0), "y": rng.randf_range(14.0, 30.0), "ph": rng.randf() * TAU})

func _build_cracks() -> void:
	for i in 3:
		var n := Node3D.new()
		n.visible = false
		add_child(n)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.75, 0.95, 1.0, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.disable_fog = true
		for s in 9:   # a zig-zag of thin flat segments
			var bm := BoxMesh.new()
			bm.size = Vector3(0.09, 0.01, 2.2)
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(mi)
		cracks.append({"node": n, "mat": m, "t": 0.0})

func _spawn_crack(player: Vector3) -> void:
	var c: Dictionary = {}
	for k in cracks:
		if float(k.t) <= 0.0:
			c = k
	if c.is_empty():
		return
	var a := rng.randf() * TAU
	var d := rng.randf_range(10.0, 32.0)
	var pos := Vector3(player.x + cos(a) * d, 0.04, player.z + sin(a) * d)
	var flat := Vector2(pos.x, pos.z)
	var lim: float = scenery.edge_at(pos.x, pos.z) - 6.0
	if flat.length() > lim:
		flat = flat.normalized() * lim
	if flat.length() < 15.0:
		flat = (flat.normalized() if flat.length() > 0.1 else Vector2.RIGHT) * 15.0
	pos = Vector3(flat.x, 0.04, flat.y)
	var n: Node3D = c.node
	n.position = pos
	n.rotation.y = rng.randf() * TAU
	var yaw := 0.0
	var cur := Vector3.ZERO
	for i in n.get_child_count():
		var seg: Node3D = n.get_child(i)
		yaw += rng.randf_range(-0.55, 0.55)
		var dirv := Vector3(sin(yaw), 0, cos(yaw))
		seg.position = cur + dirv * 1.1
		seg.rotation.y = yaw
		cur += dirv * 2.0
	for i in n.get_child_count():   # centre the zig-zag on the spot, so the whole crack stays on the ice
		(n.get_child(i) as Node3D).position -= cur * 0.5
	n.visible = true
	c.t = 2.4
	cracked.emit(pos, clampf(1.0 - Vector2(pos.x - player.x, pos.z - player.z).length() / 40.0, 0.0, 1.0))

# ---------- the camp grows with the Eye ----------
func _hut_point(local: Vector3) -> Vector3:
	return hut.to_global(local)

func _wood(parent: Node, pos: Vector3, size: Vector3, c := Color(0.36, 0.24, 0.17)) -> MeshInstance3D:
	var mi = scenery._box(parent, pos, size, scenery._mat(c))
	return mi

func _pop(n: Node3D) -> void:
	var target := n.scale
	n.scale = target * 0.2
	var tw := n.create_tween()
	tw.tween_property(n, "scale", target * 1.06, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", target, 0.15)

## level 0..5 (the Eye's stage). Pieces are only ever added.
func set_camp_level(level: int, animate := true) -> void:
	if hut == null:
		return
	while camp_level < level:
		camp_level += 1
		match camp_level:
			1: _build_campfire(animate)
			2: _build_string_lights(animate)
			3: _build_woodpile_sled_dog(animate)
			4: _build_lantern_posts(animate)

func _build_campfire(animate: bool) -> void:
	var root := Node3D.new()
	root.position = _hut_point(Vector3(-3.6, 0.0, 6.4))
	add_child(root)
	camp["fire"] = root
	for i in 7:   # a ring of stones
		var a := TAU * i / 7.0
		var st = scenery._box(root, Vector3(cos(a) * 0.85, 0.12, sin(a) * 0.85), Vector3(0.38, 0.24, 0.3), scenery._mat(Color(0.42, 0.45, 0.55)))
		st.rotation.y = a
	for i in 3:   # crossed logs
		var lg = scenery._box(root, Vector3(0, 0.22, 0), Vector3(1.3, 0.2, 0.2), scenery._mat(Color(0.3, 0.2, 0.14)))
		lg.rotation.y = i * 1.05
	var cols := [Color(1.0, 0.45, 0.12), Color(1.0, 0.7, 0.2), Color(1.0, 0.92, 0.55)]
	for i in 3:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.42 - i * 0.1
		cm.height = 1.1 - i * 0.22
		cm.radial_segments = 6
		var fm := MeshInstance3D.new()
		fm.mesh = cm
		var mt = scenery._mat(cols[i], 2.6, true)
		fm.material_override = mt
		fm.position = Vector3(0, 0.55 + 0.1 * i, 0)
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(fm)
		flames.append(fm)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0, 1.1, 0)
	fire_light.light_color = Color(1.0, 0.6, 0.28)
	fire_light.omni_range = 11.0
	fire_light.light_energy = 0.8
	root.add_child(fire_light)
	var emb := CPUParticles3D.new()   # embers rise and wink out
	emb.position = Vector3(0, 0.7, 0)
	emb.amount = 18
	emb.lifetime = 2.2
	emb.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emb.emission_sphere_radius = 0.35
	emb.direction = Vector3(0, 1, 0)
	emb.spread = 18.0
	emb.gravity = Vector3(0.4, 0.8, 0.1)
	emb.initial_velocity_min = 0.6
	emb.initial_velocity_max = 1.5
	var es := SphereMesh.new()
	es.radius = 0.035
	es.height = 0.07
	es.radial_segments = 4
	es.rings = 2
	emb.mesh = es
	emb.material_override = scenery._mat(Color(1.0, 0.7, 0.3), 3.0, true)
	root.add_child(emb)
	var sm := CPUParticles3D.new()   # and a thin grey smoke
	sm.position = Vector3(0, 1.2, 0)
	sm.amount = 10
	sm.lifetime = 4.0
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 10.0
	sm.gravity = Vector3(0.5, 0.5, 0.1)
	sm.initial_velocity_min = 0.5
	sm.initial_velocity_max = 0.9
	var ss := SphereMesh.new()
	ss.radius = 0.28
	ss.height = 0.56
	ss.radial_segments = 6
	ss.rings = 3
	sm.mesh = ss
	var smat = scenery._mat(Color(0.7, 0.74, 0.82, 0.16), 0.0, true)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material_override = smat
	sm.scale_amount_min = 0.7
	sm.scale_amount_max = 1.7
	root.add_child(sm)
	for i in 3:   # logs to sit on
		var a2 := 2.6 + i * 1.15
		var seat = scenery._box(root, Vector3(cos(a2) * 2.6, 0.22, sin(a2) * 2.6), Vector3(1.4, 0.4, 0.45), scenery._mat(Color(0.4, 0.27, 0.19)))
		seat.rotation.y = -a2 + PI * 0.5
		var cap = scenery._box(root, Vector3(cos(a2) * 2.6, 0.45, sin(a2) * 2.6), Vector3(1.3, 0.07, 0.4), scenery._mat(Color(0.92, 0.96, 1.0)))
		cap.rotation.y = -a2 + PI * 0.5
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scenery.obstacles.append(Vector3(root.position.x, root.position.z, 1.6))
	if animate:
		_pop(root)

func _build_string_lights(animate: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	camp["lights"] = root
	var a := _hut_point(Vector3(2.4, 3.1, 2.1))   # from the hut's eave...
	var pole_pos := _hut_point(Vector3(-3.6, 0.0, 6.4)) + Vector3(2.0, 0.0, 1.0)
	var b := pole_pos + Vector3(0, 3.4, 0)
	scenery._box(root, pole_pos + Vector3(0, 1.7, 0), Vector3(0.14, 3.4, 0.14), scenery._mat(Color(0.2, 0.17, 0.2)))
	var wire_m = scenery._mat(Color(0.15, 0.15, 0.2))
	var prev := a
	var n := 14
	for i in range(1, n + 1):
		var k := float(i) / n
		var pt := a.lerp(b, k) + Vector3(0, -sin(k * PI) * 0.9, 0)   # the wire sags
		var mid := (prev + pt) * 0.5
		var seg = scenery._box(root, mid, Vector3(0.04, 0.04, prev.distance_to(pt)), wire_m)
		seg.look_at_from_position(mid, pt, Vector3.UP)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i % 2 == 0 and i < n:   # a warm bead every second link
			var bm = scenery._mat(Color(1.0, 0.8, 0.4), 0.5)
			var bead = scenery._box(root, pt + Vector3(0, -0.12, 0), Vector3(0.16, 0.2, 0.16), bm)
			bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scenery.glow_mats.append([bm, 0.5, 3.4])
		prev = pt
	scenery.obstacles.append(Vector3(pole_pos.x, pole_pos.z, 0.5))
	if animate:
		_pop(root)

func _build_woodpile_sled_dog(animate: bool) -> void:
	var root := Node3D.new()
	root.position = _hut_point(Vector3(4.2, 0.0, 4.6))
	root.rotation.y = hut.rotation.y
	add_child(root)
	camp["yard"] = root
	for row in 3:   # a woodpile with a snow cap
		for i in (4 - row):
			_wood(root, Vector3(-1.0 + i * 0.5 + row * 0.25, 0.14 + row * 0.26, 0.0), Vector3(0.44, 0.24, 0.9), Color(0.42, 0.28, 0.19) if (i + row) % 2 == 0 else Color(0.34, 0.23, 0.16))
	var cap = scenery._box(root, Vector3(-0.4, 0.86, 0.0), Vector3(1.9, 0.1, 1.0), scenery._mat(Color(0.92, 0.96, 1.0)))
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# the sled: two runners, a deck and a lashed crate
	for sx in [-0.32, 0.32]:
		_wood(root, Vector3(2.2 + sx, 0.1, 0.0), Vector3(0.08, 0.12, 2.0), Color(0.3, 0.3, 0.38))
	_wood(root, Vector3(2.2, 0.22, 0.0), Vector3(0.9, 0.08, 1.6), Color(0.45, 0.3, 0.2))
	_wood(root, Vector3(2.2, 0.55, -0.1), Vector3(0.7, 0.55, 0.8), Color(0.5, 0.36, 0.24))
	_wood(root, Vector3(2.2, 0.85, -0.1), Vector3(0.74, 0.07, 0.84), Color(0.92, 0.96, 1.0))
	# Olga's dog, asleep by the fire: a curled body, a head on its paws, ears, a tail
	dog = Node3D.new()
	dog.position = _hut_point(Vector3(-3.6, 0.0, 6.4)) + Vector3(1.4, 0.0, -0.6)
	add_child(dog)
	var fur := Color(0.72, 0.58, 0.42)
	var fur2 := Color(0.9, 0.84, 0.74)
	var body = scenery._mesh(dog, _ball_mesh(), scenery._mat(fur), Vector3(0, 0.3, 0))
	body.scale = Vector3(1.1, 0.55, 0.7)
	var head = scenery._mesh(dog, _ball_mesh(), scenery._mat(fur2), Vector3(0.62, 0.26, 0.12))
	head.scale = Vector3(0.42, 0.34, 0.36)
	for s in [-1.0, 1.0]:
		var ear = scenery._box(dog, Vector3(0.58, 0.46, 0.12 + s * 0.14), Vector3(0.1, 0.18, 0.08), scenery._mat(Color(0.38, 0.28, 0.2)))
		ear.rotation.x = s * 0.25
	var tail = scenery._box(dog, Vector3(-0.62, 0.22, 0.2), Vector3(0.5, 0.1, 0.12), scenery._mat(fur))
	tail.rotation.y = 0.5
	camp["dog"] = dog
	scenery.obstacles.append(Vector3(root.position.x, root.position.z, 1.4))
	if animate:
		_pop(root)
		_pop(dog)

func _ball_mesh() -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	return sm

func _build_lantern_posts(animate: bool) -> void:
	var root := Node3D.new()
	add_child(root)
	camp["posts"] = root
	for spot in [Vector3(-7.2, 0.0, 8.8), Vector3(5.6, 0.0, 9.2)]:
		var pos := _hut_point(spot)
		scenery._box(root, pos + Vector3(0, 1.5, 0), Vector3(0.16, 3.0, 0.16), scenery._mat(Color(0.2, 0.17, 0.2)))
		var lm = scenery._mat(Color(0.16, 0.17, 0.26))
		lm.emission_enabled = true
		lm.emission = Color(1.0, 0.75, 0.35)
		lm.emission_energy_multiplier = 0.6
		scenery._box(root, pos + Vector3(0, 3.2, 0), Vector3(0.4, 0.5, 0.4), lm)
		scenery.glow_mats.append([lm, 0.6, 2.2])
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 3.2, 0)
		light.light_color = Color(1.0, 0.75, 0.4)
		light.omni_range = 8.0
		light.light_energy = 0.0
		root.add_child(light)
		camp["post_light_%d" % camp.size()] = light
		scenery.obstacles.append(Vector3(pos.x, pos.z, 0.4))
	if animate:
		_pop(root)

# ---------- every frame ----------
## `night` is the sky's darkness 0..1, `player` the player's position, `cutscene` freezes birds and cracks quietly.
func update(delta: float, night_in: float, player: Vector3, cutscene := false) -> void:
	_t += delta
	night = night_in
	var w: Dictionary = weather.vals
	_apply_weather(delta, w)
	_update_stars()
	_update_clouds(delta, w)
	_update_birds(delta, w, player)
	_update_cracks(delta, player, cutscene)
	_update_camp(delta, player)
	_update_calls(delta, w, cutscene)

func _apply_weather(delta: float, w: Dictionary) -> void:
	var snow := float(w.snow)
	var layers: Array = scenery.snow_layers
	if layers.size() == 3:
		layers[0].emitting = snow > 0.05
		layers[1].emitting = snow > 0.55
		layers[2].emitting = snow > 1.5
		var lean := Vector3(0.3 + 5.5 * float(w.wind), -1.2 - 0.5 * snow, 0.1 + 1.8 * float(w.wind))
		for l in layers:
			l.gravity = lean
	scenery.gloom = float(w.gloom)
	scenery.aurora_level = lerpf(scenery.aurora_level, 1.0 if weather.aurora_on() else 0.3, minf(1.0, delta * 0.6))
	var env: Environment = scenery.env_ref
	env.fog_density = minf(FOG_BASE * float(w.fog), FOG_MAX)

func _update_stars() -> void:
	var a := night * (1.0 - float(weather.vals.gloom) * 1.1)
	a = clampf(a - 0.15, 0.0, 1.0)
	for i in star_mm.size():
		var tw := 0.78 + 0.22 * sin(_t * (1.3 + i * 0.7) + i * 1.7)   # the two groups twinkle out of step
		star_mat[i].albedo_color.a = a * tw * 0.95
		star_mm[i].visible = a > 0.02

func _update_clouds(delta: float, w: Dictionary) -> void:
	var gloom := float(w.gloom)
	var sky: ProceduralSkyMaterial = scenery.sky_mat
	var lit := sky.sky_horizon_color.lerp(Color.WHITE, 0.45)
	var slate := Color(0.5, 0.56, 0.66)
	var col := lit.lerp(slate, gloom * 0.8)
	col = col.lerp(Color(0.1, 0.13, 0.24), night * 0.85)
	cloud_mat.albedo_color = Color(col.r, col.g, col.b, clampf(0.32 + 0.6 * gloom, 0.0, 0.92) * (1.0 - 0.45 * night))
	var drift := wind_dir * (1.0 + 4.0 * float(w.wind))
	for c in clouds:
		var n: Node3D = c.node
		n.position.x += drift.x * c.speed * delta
		n.position.z += drift.y * c.speed * delta
		var flat := Vector2(n.position.x, n.position.z)
		if flat.length() > 820.0:   # off the far edge: come back in on the other side
			var back := -flat.normalized() * 700.0
			n.position.x = back.x
			n.position.z = back.y
		# fewer clouds on a clear day, all of them in a storm
		n.visible = gloom + 0.35 >= c.base * 0.9

func _update_birds(delta: float, w: Dictionary, player: Vector3) -> void:
	var want := 1.0 if (night < 0.35 and float(w.gloom) < 0.35 and float(w.wind) < 0.6) else 0.0
	bird_vis = move_toward(bird_vis, want, delta * 0.25)
	for b in birds:
		var n: Node3D = b.node
		n.visible = bird_vis > 0.05
		if not n.visible:
			continue
		b.a += b.w * delta
		var pos := Vector3(sin(b.a) * b.r, b.y + sin(_t * 0.4 + b.ph) * 1.5, -cos(b.a) * b.r)
		n.position = pos
		n.rotation.y = -b.a - (PI * 0.5 if b.w > 0.0 else -PI * 0.5)
		n.rotation.z = -0.25 * signf(b.w)   # banking into the turn
		var flap := sin(_t * 5.5 + b.ph) * 0.55
		b.wl.rotation.z = flap
		b.wr.rotation.z = -flap
		n.scale = Vector3.ONE * 2.4 * bird_vis

func _update_cracks(delta: float, player: Vector3, cutscene: bool) -> void:
	for c in cracks:
		if float(c.t) > 0.0:
			c.t -= delta
			var k: float = clampf(c.t / 2.4, 0.0, 1.0)
			c.mat.albedo_color.a = (k * k) * 0.85 * (0.6 + 0.4 * sin(_t * 30.0)) if k > 0.85 else k * 0.7
			if c.t <= 0.0:
				c.node.visible = false
	if cutscene:
		return
	crack_t -= delta
	if crack_t <= 0.0:
		crack_t = rng.randf_range(24.0, 60.0) * lerpf(1.0, 0.55, night) * lerpf(1.0, 0.7, float(weather.vals.wind) * 0.5)
		_spawn_crack(player)

func _update_camp(delta: float, player: Vector3) -> void:
	if fire_light and flames.size() > 0:
		var f := 0.85 + 0.25 * sin(_t * 9.0) + 0.12 * sin(_t * 23.0 + 1.0)
		fire_light.light_energy = (0.5 + 1.5 * night) * f
		for i in flames.size():
			var m: MeshInstance3D = flames[i]
			var s := 0.9 + 0.22 * sin(_t * (8.0 + i * 3.0) + i * 2.0)
			m.scale = Vector3(1.0 + 0.1 * (1.0 - s), s, 1.0 + 0.1 * (1.0 - s))
	if dog:
		dog_breath += delta
		var near := Vector2(player.x - dog.position.x, player.z - dog.position.z).length() < 7.0
		dog.scale.y = 1.0 + 0.04 * sin(dog_breath * (2.6 if near else 1.6))
		dog.rotation.y = lerp_angle(dog.rotation.y, atan2(player.x - dog.position.x, player.z - dog.position.z) - PI * 0.5 if near else dog.rotation.y, minf(1.0, delta * 1.5))
	for k in camp:   # lantern posts glow with the night
		if String(k).begins_with("post_light_"):
			(camp[k] as OmniLight3D).light_energy = night * 2.2

func _update_calls(delta: float, w: Dictionary, cutscene: bool) -> void:
	if cutscene:
		return
	owl_t -= delta
	if owl_t <= 0.0:
		owl_t = rng.randf_range(35.0, 95.0)
		if night > 0.7 and float(w.wind) < 0.7:
			owl_called.emit()
	crow_t -= delta
	if crow_t <= 0.0:
		crow_t = rng.randf_range(30.0, 80.0)
		if bird_vis > 0.8:
			crow_called.emit()
