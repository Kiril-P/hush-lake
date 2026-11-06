class_name FishYard
extends Node3D
## Fish that are really on the ice. A catch pops out of the hole, falls, bounces and slides; you push it
## around (walk into it, or kick it) and the Eye pulls in whatever gets close. Small hand-rolled physics:
## it is cheaper and far more predictable than rigid bodies for a few dozen sliding discs.

signal swallowed(f: Dictionary, holder: Node3D, pos: Vector3)
signal landed(f: Dictionary, impact: float)
signal bumped(f: Dictionary)
signal overflowed(f: Dictionary, holder: Node3D, pos: Vector3)
signal sunk(f: Dictionary, holder: Node3D, pos: Vector3, id: String)   # a fish was thrown into a machine (depot, smoker)
signal touched(pos: Vector3, impact: float)   # a fish hit the ice (for the landing puff)
signal trail(pos: Vector3, speed: float)       # a fish is sliding fast (for the snow it kicks up)
signal kicked(pos: Vector3, dir: Vector3, power: float)

const GROUND := 0.05
const GRAVITY := 18.0
const MAX_LOOSE := 60
const FRICTION_BASE := 1.4        # ice is slippery: a constant drag plus a drag that grows with speed
const FRICTION_SPEED := 0.35
const PLAYER_R := 0.85
const EDGE := 108.0
const PULL_RANGE := 6.0           # the Eye pulls fish this far past its rim (weaker with distance)

var fish: Array = []              # {f, node, fm, pos, vel, r, yaw, roll, flop, flop_t, still}
var obstacles: Array = []         # Vector3(x, z, radius)
var eye_r := 10.0
var pupil_r := 4.8
var pull := 3.8                   # the Eye's suction (m/s^2), grows with its stage
var player_speed := 0.0
var player_vel := Vector3.ZERO       # flat velocity of the player: a walk-push goes the way you are moving
var edge_fn := Callable()            # (x, z) -> the shoreline radius in that direction
var swallow_enabled := true
var sinks: Array = []             # machines that take a fish thrown at them: {pos, r, h, id, accept: Callable}
var fans: Array = []              # wind fans: {pos: Vector2, dir: Vector2 (unit), r: reach, k: push (m/s^2)}; they blow fish along the ice
var last_collected: Array = []      # where the fish of the last collect() lay (for the pickup flight)

func count() -> int:
	return fish.size()

func spawn(f: Dictionary, pos: Vector3, vel: Vector3) -> Dictionary:
	if fish.size() >= MAX_LOOSE:
		var old: Dictionary = fish[0]   # the ice never clogs: the oldest fish is taken off it (and paid at half rate, see the game)
		fish.erase(old)
		(old.shadow as Node).queue_free()
		overflowed.emit(old.f, old.node, old.pos)
	var holder := Node3D.new()
	add_child(holder)
	var lenk := float(f.get("lenk", 1.0))
	var fm := FishModel.build(f.name, f.color, 0.34 * 2.4 * lenk)
	holder.add_child(fm)
	_lift(fm)
	var e := {"f": f, "node": holder, "fm": fm, "pos": pos, "vel": vel, "r": clampf(0.56 * lenk, 0.38, 1.15),
		"puff_t": 0.0, "yaw": randf() * TAU, "roll": 0.0, "flop": 0.0, "flop_t": randf_range(1.0, 3.0), "still": 0.0, "spin": randf_range(-6.0, 6.0)}
	holder.position = pos
	e["shadow"] = _make_shadow(e.r)
	fish.append(e)
	return e

## Everything moves here. `player` is the player's position, `look` the flat direction they face.
func step(delta: float, player: Vector3) -> void:
	if delta > 0.025:   # a long frame (or a sped-up test) is several short physics steps, so fish move the same at any frame rate
		var n := mini(ceili(delta / 0.0167), 8)
		for i in n:
			_step(delta / n, player)
		return
	_step(delta, player)

func _step(delta: float, player: Vector3) -> void:
	var dt := minf(delta, 0.05)
	var n := fish.size()
	var swallow_now: Array = []
	var sink_now: Array = []
	for e in fish:
		var p: Vector3 = e.pos
		var v: Vector3 = e.vel
		var airborne: bool = p.y > GROUND + 0.01 or v.y > 0.1
		if airborne:
			v.y -= GRAVITY * dt
			p += v * dt
			if p.y <= GROUND:
				p.y = GROUND
				var impact := -v.y
				if impact > 2.5:
					v.y = impact * 0.3   # a small bounce
					var keep := clampf(0.8 - impact * 0.025, 0.4, 0.8)   # a hard landing (a throw) skids far less than a gentle one
					v.x *= keep
					v.z *= keep
					landed.emit(e.f, impact)
					touched.emit(p, impact)
				else:
					v.y = 0.0
		else:
			p += Vector3(v.x, 0, v.z) * dt
			p.y = GROUND
			var sp := Vector2(v.x, v.z).length()
			if sp > 0.0:
				var dec := (FRICTION_BASE + FRICTION_SPEED * sp) * dt
				var nsp := maxf(sp - dec, 0.0)
				v.x *= nsp / sp
				v.z *= nsp / sp
		# the Eye pulls fish that get close
		var d := Vector2(p.x, p.z).length()
		if d < eye_r + PULL_RANGE and d > 0.01 and not airborne:
			var k := 1.0 - clampf((d - pupil_r) / (eye_r + PULL_RANGE - pupil_r), 0.0, 1.0) * 0.45
			v.x -= p.x / d * pull * k * dt
			v.z -= p.z / d * pull * k * dt
		if p.y < 1.4 and not fans.is_empty():   # a fan blows a cone of wind: fish lying (or skidding) in it drift downwind
			for fn in fans:
				var fo := Vector2(p.x - fn.pos.x, p.z - fn.pos.y)
				var along: float = fo.dot(fn.dir)
				if along > 0.0 and along < fn.r:
					var lat := absf(fo.x * fn.dir.y - fo.y * fn.dir.x)
					if lat < 2.4 + 0.3 * along:
						var gust: float = fn.k * (1.0 - along / fn.r) * (1.0 - lat / (2.4 + 0.3 * along) * 0.5)
						v.x += fn.dir.x * gust * dt
						v.z += fn.dir.y * gust * dt
		if d < pupil_r * 0.92 and swallow_enabled and p.y < 1.6:
			swallow_now.append(e)
		# the lake's edge and the camp's walls
		var edge: float = (edge_fn.call(p.x, p.z) - 1.5) if edge_fn.is_valid() else EDGE
		if d > edge:
			var nrm := Vector2(p.x, p.z) / d
			p.x = nrm.x * edge
			p.z = nrm.y * edge
			var vn := v.x * nrm.x + v.z * nrm.y
			if vn > 0.0:
				v.x -= nrm.x * vn * 1.6
				v.z -= nrm.y * vn * 1.6
		for o in obstacles:
			var off := Vector2(p.x - o.x, p.z - o.y)
			var lim: float = o.z + e.r
			if off.length() < lim:
				var nrm2 := off.normalized() if off.length() > 0.01 else Vector2.RIGHT
				p.x = o.x + nrm2.x * lim
				p.z = o.y + nrm2.y * lim
				var vn2 := v.x * nrm2.x + v.z * nrm2.y
				if vn2 < 0.0:
					v.x -= nrm2.x * vn2 * 1.5
					v.z -= nrm2.y * vn2 * 1.5
		# the player is a solid thing: walk into a fish and it slides ahead of you
		if p.y < 1.4:
			var po := Vector2(p.x - player.x, p.z - player.z)
			var lim2: float = PLAYER_R + e.r
			if po.length() < lim2:
				var nrm3 := po.normalized() if po.length() > 0.01 else Vector2.RIGHT
				p.x = player.x + nrm3.x * lim2
				p.z = player.z + nrm3.y * lim2
				if player_speed > 0.4:
					var push := maxf(player_speed * 1.3, 2.5)
					var mv := Vector2(player_vel.x, player_vel.z)
					var pd := nrm3
					if mv.length() > 0.1:   # follow where you are heading, not just away from your centre
						pd = (nrm3 * 0.2 + mv.normalized() * 0.8).normalized()
					v.x = lerpf(v.x, pd.x * push, 0.75)
					v.z = lerpf(v.z, pd.y * push, 0.75)
					if e.still > 0.0:
						bumped.emit(e.f)
						e.still = 0.0
		e.pos = p
		e.vel = v
		for sk in sinks:   # a fish that reaches a machine's mouth goes in (if the machine will take it)
			if p.y < sk.h and Vector2(p.x - sk.pos.x, p.z - sk.pos.z).length() < sk.r and sk.accept.call():
				sink_now.append([e, sk.id])
				break
	# fish against fish: shove apart and swap some momentum, so a pile shoulders itself along
	for i in n:
		var a: Dictionary = fish[i]
		for j in range(i + 1, n):
			var b: Dictionary = fish[j]
			var dx: float = b.pos.x - a.pos.x
			var dz: float = b.pos.z - a.pos.z
			var lim3: float = a.r + b.r
			var d2 := dx * dx + dz * dz
			if d2 >= lim3 * lim3 or absf(a.pos.y - b.pos.y) > 0.8:
				continue
			var dd := sqrt(d2)
			var nx := dx / dd if dd > 0.001 else 1.0
			var nz := dz / dd if dd > 0.001 else 0.0
			var over := (lim3 - dd) * 0.5
			a.pos.x -= nx * over
			a.pos.z -= nz * over
			b.pos.x += nx * over
			b.pos.z += nz * over
			var rv: float = (b.vel.x - a.vel.x) * nx + (b.vel.z - a.vel.z) * nz
			if rv < 0.0:
				var imp := -rv * 0.75
				a.vel.x -= nx * imp
				a.vel.z -= nz * imp
				b.vel.x += nx * imp
				b.vel.z += nz * imp
	for e in fish:
		_pose(e, dt)
	for e in swallow_now:
		if fish.has(e):
			_swallow(e)
	for pair in sink_now:
		var se: Dictionary = pair[0]
		if fish.has(se):
			fish.erase(se)
			(se.shadow as Node).queue_free()
			sunk.emit(se.f, se.node, se.pos, pair[1])

func _pose(e: Dictionary, dt: float) -> void:
	var v: Vector3 = e.vel
	var sp := Vector2(v.x, v.z).length()
	var airborne: bool = e.pos.y > GROUND + 0.01
	if sp > 0.6:
		e.yaw = lerp_angle(e.yaw, atan2(-v.z, v.x), minf(1.0, dt * 9.0))
		e.still = 0.0
	else:
		e.still += dt
	if airborne:
		e.yaw += e.spin * dt
	if sp > 3.5 and not airborne:
		e.puff_t -= dt
		if e.puff_t <= 0.0:
			e.puff_t = 0.09
			trail.emit(e.pos, sp)
	var roll_target := 0.25 if (sp > 1.5 or airborne) else 1.35   # lies on its side once it stops
	e.roll = lerpf(e.roll, roll_target, minf(1.0, dt * 6.0))
	e.flop_t -= dt
	if e.flop_t <= 0.0 and sp < 0.6 and not airborne:
		e.flop = 0.45
		e.flop_t = randf_range(1.5, 4.0)
		e.vel.y = 1.6   # a little hop
		e.yaw += randf_range(-0.7, 0.7)
	e.flop = maxf(e.flop - dt, 0.0)
	var node: Node3D = e.node
	node.position = e.pos
	node.basis = Basis(Vector3.UP, e.yaw) * Basis(Vector3.RIGHT, e.roll)
	var sh: MeshInstance3D = e.shadow
	sh.position = Vector3(e.pos.x, -0.03, e.pos.z)
	sh.rotation.y = e.yaw
	var lift := clampf((e.pos.y - GROUND) / 3.0, 0.0, 1.0)   # a fish in the air casts a smaller, fainter shadow
	sh.scale = Vector3(e.r * 1.5, 1.0, e.r * 0.8) * (1.0 - 0.4 * lift)
	(e.fm as FishNode).amp = clampf(0.2 + sp * 0.25 + e.flop * 5.0 + (1.0 if airborne else 0.0), 0.2, 3.0)

static var _shadow_mat: StandardMaterial3D
static var _shadow_mesh: CylinderMesh

## A soft dark disc on the ice under a fish, so a pale fish on pale snow is grounded and easy to find.
func _make_shadow(r: float) -> MeshInstance3D:
	if _shadow_mat == null:
		_shadow_mat = StandardMaterial3D.new()
		_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shadow_mat.albedo_color = Color(0.05, 0.1, 0.3, 0.32)
		_shadow_mat.disable_fog = true
		_shadow_mesh = CylinderMesh.new()
		_shadow_mesh.top_radius = 1.0
		_shadow_mesh.bottom_radius = 1.0
		_shadow_mesh.height = 0.01
		_shadow_mesh.radial_segments = 14
	var m := MeshInstance3D.new()
	m.mesh = _shadow_mesh
	m.material_override = _shadow_mat
	m.scale = Vector3(r * 1.5, 1.0, r * 0.8)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

static var _lift_mat: StandardMaterial3D

## Fish lie on their side in their own shadow on white ice and read as dark slivers: a faint additive lift keeps their colours alive.
static func _lift(n: Node) -> void:
	if _lift_mat == null:
		_lift_mat = StandardMaterial3D.new()
		_lift_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lift_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_lift_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_lift_mat.albedo_color = Color(0.1, 0.13, 0.17, 1.0)
		_lift_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is ArrayMesh:
			(c as MeshInstance3D).material_overlay = _lift_mat
		_lift(c)

func _swallow(e: Dictionary) -> void:
	fish.erase(e)
	(e.shadow as Node).queue_free()
	swallowed.emit(e.f, e.node, e.pos)

## A kick: every fish in the cone in front of `origin` flies off along `dir` (flat, normalised). Returns how many.
func kick(origin: Vector3, dir: Vector3, power: float, reach := 3.4, cone := 0.5) -> int:
	var hit := 0
	for e in targets(origin, dir, reach, cone):
		var spread := dir.rotated(Vector3.UP, randf_range(-0.07, 0.07))
		e.vel = spread * power * randf_range(0.92, 1.08) + Vector3(0, 1.6 + power * 0.1, 0)
		e.spin = randf_range(-9.0, 9.0)
		e.pos.y = maxf(e.pos.y, GROUND + 0.02)
		kicked.emit(e.pos, dir, power)
		hit += 1
	return hit

## The fish a kick from `origin` along `dir` would hit. If the cone is empty the nearest fish within 4.5 m
## that is at least roughly ahead of you still counts (a forgiving kick, so near misses do not feel broken).
func targets(origin: Vector3, dir: Vector3, reach := 3.4, cone := 0.5) -> Array:
	var out: Array = []
	var assist: Dictionary = {}
	var assist_d := 1e9
	for e in fish:
		var off: Vector3 = e.pos - origin
		off.y = 0.0
		var dist := off.length()
		var dt := off.normalized().dot(dir) if dist > 0.01 else 1.0
		if dist <= reach + e.r and (dist <= 0.5 or dt >= cone):
			out.append(e)
		elif dist <= 4.5 and dt >= 0.17 and dist < assist_d:
			assist = e
			assist_d = dist
	if out.is_empty() and not assist.is_empty():
		out.append(assist)
	return out

## Fish lying within `radius` of the Eye's centre.
func near_eye(radius: float) -> int:
	var n := 0
	for e in fish:
		if Vector2(e.pos.x, e.pos.z).length() <= radius:
			n += 1
	return n

## The fish nearest the line of sight: within `reach` metres and a small cone around where you look (3D `dir`). Null if none.
func pick(origin: Vector3, dir: Vector3, reach := 5.5, min_cos := 0.965) -> Variant:
	var best: Variant = null
	var best_score := -1.0
	for e in fish:
		var off: Vector3 = (e.pos + Vector3(0, 0.15, 0)) - origin
		var dist := off.length()
		if dist > reach + e.r or dist < 0.2:
			continue
		var c := off.normalized().dot(dir)
		if c < min_cos - e.r * 0.05:
			continue
		var score := c - dist * 0.01
		if score > best_score:
			best_score = score
			best = e
	return best

## Takes one specific fish off the ice (it goes into your hands). Returns its dict.
func take(e: Dictionary) -> Dictionary:
	fish.erase(e)
	e.node.queue_free()
	(e.shadow as Node).queue_free()
	return e.f

## Where a ballistic throw from `from` with velocity `v` is at time `t` (the same gravity the fish fall with).
static func arc_point(from: Vector3, v: Vector3, t: float) -> Vector3:
	return from + v * t + Vector3(0, -0.5 * GRAVITY * t * t, 0)

## Time until a throw from `from` with velocity `v` comes down to the ice.
static func flight_time(from: Vector3, v: Vector3) -> float:
	var a := 0.5 * GRAVITY
	var disc := v.y * v.y + 4.0 * a * (from.y - GROUND)
	return (v.y + sqrt(maxf(disc, 0.0))) / (2.0 * a)

func near(pos: Vector3, radius: float) -> int:
	var n := 0
	for e in fish:
		if Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length() <= radius:
			n += 1
	return n

func nearest(pos: Vector3) -> Variant:
	var best: Variant = null
	var bd := 1e9
	for e in fish:
		var d := Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length()
		if d < bd:
			bd = d
			best = e.pos
	return best

## Picks up to `limit` fish within `radius` (nearest first) and removes them from the ice.
func collect(pos: Vector3, radius: float, limit: int, still_min := 0.0) -> Array:
	last_collected.clear()
	var cands := []
	for e in fish:
		var d := Vector2(e.pos.x - pos.x, e.pos.z - pos.z).length()
		if d <= radius and e.still >= still_min:
			cands.append([d, e])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var got := []
	for c in cands:
		if got.size() >= limit:
			break
		var e: Dictionary = c[1]
		fish.erase(e)
		e.node.queue_free()
		(e.shadow as Node).queue_free()
		last_collected.append(e.pos)
		got.append(e.f)
	return got

func clear_all() -> void:
	for e in fish:
		e.node.queue_free()
		(e.shadow as Node).queue_free()
	fish.clear()
