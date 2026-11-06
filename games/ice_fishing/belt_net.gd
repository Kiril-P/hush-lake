class_name BeltNet
extends RefCounted
## The physics of fish on belts, with no scene nodes so tests can drive it headless.
##  - Fish keep a gap (GAP metres) behind the fish ahead: a lane carries at most speed / GAP fish a second, and a blocked head backs the queue up.
##  - A spur belt ends on the side of a trunk belt (parent, join_d): its fish merge in when there is a gap, else they wait at the spur's end.
##  - A splitter gives a trunk a second lane alongside it (twin): a rod or a spur puts its fish on whichever lane has room, so the trunk carries twice as much.
##  - A chute is a sloped channel with no motor: its fish speed up as they slide (speed_at), capped at CHUTE_VMAX.
## A belt is a Dictionary: {id (unique int: belts are compared by id, never by content), len, kind ("belt" | "chute"), parent, join_d, twin}. A riding fish is {belt, d, f, m}.

const GAP := 2.0          # a lane carries speed / GAP fish a second: 2.25 at base speed, 4.5 with Belt Motor 4. A boosted rod makes ~0.3/s, so 8-15 of them fill a lane
const CHUTE_V0 := 1.1
const CHUTE_A := 0.55
const CHUTE_VMAX := 3.4

## Speed of a fish at distance d along belt b. `base` is the motorised belt speed.
static func speed_at(b: Dictionary, d: float, base: float) -> float:
	if b.get("kind", "belt") == "chute":
		return minf(sqrt(CHUTE_V0 * CHUTE_V0 + 2.0 * CHUTE_A * maxf(d, 0.0)), CHUTE_VMAX)
	return base

## Lane capacity in fish per second at the start of a belt.
static func capacity(b: Dictionary, base: float) -> float:
	return speed_at(b, 0.0, base) / GAP

## True when a fish put on b at distance d would not touch another.
static func has_room(fish: Array, b: Dictionary, d := 0.0) -> bool:
	for it in fish:
		if it.belt.id == b.id and absf(it.d - d) < GAP:
			return false
	return true

## The lane of b (itself or its splitter's second lane) that has room for a fish at d, or {} if both are full.
static func pick_lane(fish: Array, b: Dictionary, d := 0.0) -> Dictionary:
	if has_room(fish, b, d):
		return b
	var tw = b.get("twin", null)
	if tw != null and has_room(fish, tw, d):
		return tw
	return {}

## How many fish ride belt b.
static func count_on(fish: Array, b: Dictionary) -> int:
	var n := 0
	for it in fish:
		if it.belt.id == b.id:
			n += 1
	return n

## One step of all riding fish. `arrive` is called as arrive.call(item) for a fish that leaves the network into the Eye (already removed from
## `fish`); `leave` is called as leave.call(item, belt) whenever a fish leaves a belt (to apply that belt's machines). Returns the number of
## fish that were held back this step (a queue or a blocked merge).
static func step(fish: Array, base: float, delta: float, arrive: Callable, leave: Callable) -> int:
	var buckets := {}
	for it in fish:
		_bucket(buckets, it.belt).append(it)
	var held := 0
	var gone := []
	var held_on := {}   # belt id -> true when a fish was held back on it this step
	for key in buckets.keys():
		var items: Array = buckets[key]
		var b: Dictionary = items[0].belt if not items.is_empty() else {}
		if items.is_empty():
			continue
		items.sort_custom(func(x, y): return x.d > y.d)
		var prev_d := INF
		for it in items:
			if it.belt.id != b.id:
				continue   # (it was moved by a merge or a split earlier this step)
			var d0: float = it.d
			var nd := d0 + speed_at(b, d0, base) * delta
			var cap := prev_d - GAP
			if nd > cap:
				nd = maxf(d0, cap)
				held += 1
				held_on[b.id] = true
			if nd >= b.len:
				var parent = b.get("parent", null)
				if parent != null:
					var lane = parent if _room_in(buckets, parent, b.join_d) else null
					var ptwin = parent.get("twin", null)
					if lane == null and ptwin != null and _room_in(buckets, ptwin, b.join_d):
						lane = ptwin
					if lane != null:
						_left(leave, it, b)
						it.belt = lane
						it.d = b.join_d
						_bucket(buckets, lane).append(it)
						continue
					nd = b.len   # blocked: it waits at the end of the spur
					held += 1
					held_on[b.id] = true
				else:
					_left(leave, it, b)
					gone.append(it)
					continue
			it.d = nd
			prev_d = nd
	for key in held_on:
		var lane: Dictionary = buckets[key][0].belt if not buckets[key].is_empty() else {}
		if not lane.is_empty():
			lane["held_acc"] = float(lane.get("held_acc", 0.0)) + delta
	for it in gone:
		fish.erase(it)
		arrive.call(it)
	return held

static func _left(leave: Callable, it: Dictionary, b: Dictionary) -> void:
	leave.call(it, b)
	b["moved"] = int(b.get("moved", 0)) + 1

static func _bucket(buckets: Dictionary, b: Dictionary) -> Array:
	if not buckets.has(b.id):
		buckets[b.id] = []
	return buckets[b.id]

static func _room_in(buckets: Dictionary, b: Dictionary, d: float) -> bool:
	for it in _bucket(buckets, b):
		if it.belt.id == b.id and absf(it.d - d) < GAP:
			return false
	return true

## Where on segment a->b is point p closest (0..1 along it), and how far off the line is it? Used to join a spur onto a trunk.
static func project(a: Vector3, b: Vector3, p: Vector3) -> Dictionary:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var l2 := maxf(ab.length_squared(), 0.0001)
	var t := clampf(ap.dot(ab) / l2, 0.0, 1.0)
	var q := Vector2(a.x, a.z) + ab * t
	return {"t": t, "perp": Vector2(p.x, p.z).distance_to(q), "point": Vector3(q.x, 0.0, q.y)}

## A rod or rig had to wait for a gap on this lane for `secs`: that counts as the lane being backed up.
static func note_wait(b: Dictionary, secs: float) -> void:
	b["held_acc"] = float(b.get("held_acc", 0.0)) + secs

## Once a second: turn the counters into a rate (fish/s, smoothed), a load (rate / capacity) and how much of the time the lane was backed up.
static func sample(belts: Array, dt: float, base: float) -> void:
	for b in belts:
		var rate := float(b.get("moved", 0)) / maxf(dt, 0.001)
		b["moved"] = 0
		b["rate"] = lerpf(float(b.get("rate", 0.0)), rate, 0.4)
		b["load"] = float(b.rate) / maxf(capacity(b, base), 0.001)
		b["backed"] = lerpf(float(b.get("backed", 0.0)), minf(float(b.get("held_acc", 0.0)) / maxf(dt, 0.001), 1.0), 0.5)
		b["held_acc"] = 0.0
	for b in belts:   # a trunk with a second lane: its load is both lanes' traffic over both lanes' capacity
		var tw = b.get("twin", null)
		if tw != null:
			b["load"] = (float(b.rate) + float(tw.get("rate", 0.0))) / maxf(capacity(b, base) * 2.0, 0.001)

## "idle", "ok", "busy" (over 60% of the lane) or "full" (backed up: the lane is the bottleneck).
static func status(b: Dictionary) -> String:
	if float(b.get("backed", 0.0)) > 0.3:
		return "full"
	if float(b.get("load", 0.0)) >= 0.6:
		return "busy"
	return "idle" if float(b.get("rate", 0.0)) < 0.02 else "ok"

static func status_color(st: String) -> Color:
	match st:
		"full": return Color(1.0, 0.35, 0.3)
		"busy": return Color(1.0, 0.8, 0.3)
		"ok": return Color(0.45, 0.95, 0.7)
	return Color(0.6, 0.7, 0.75)

## How many boosted rods (each making `per_rod` fish/s) fill one lane of this belt?
static func rods_to_fill(b: Dictionary, base: float, per_rod: float) -> int:
	return int(ceil(capacity(b, base) / maxf(per_rod, 0.001)))
