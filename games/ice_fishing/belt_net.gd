class_name BeltNet
extends RefCounted
## The physics of fish on belts, with no scene nodes so tests can drive it headless.
##  - Fish keep a gap (GAP metres) behind the fish ahead: a lane carries at most speed / GAP fish a second, and a blocked head backs the queue up.
##  - A spur belt ends on the side of a trunk belt (parent, join_d): its fish merge in when there is a gap, else they wait at the spur's end.
##  - A splitter on a belt (twin, split_d) sends every other fish down a second lane (the twin) when that lane has room, and every fish
##    while the main lane is backed up.
##  - A chute is a sloped channel with no motor: its fish speed up as they slide (speed_at), capped at CHUTE_VMAX.
## A belt is a Dictionary: {id (unique int: belts are compared by id, never by content), len, kind ("belt" | "chute"), parent, join_d, twin, split_d, flip}. A riding fish is {belt, d, f, m}.

const GAP := 0.9
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
			var pre := d0 + speed_at(b, d0, base) * delta
			var nd := pre
			var cap := prev_d - GAP
			if nd > cap:
				nd = maxf(d0, cap)
				held += 1
			# the splitter: crossing its mark, every other fish takes the twin lane if it has room
			var twin = b.get("twin", null)
			var jammed := cap < pre   # the main lane is backed up: the free lane takes the fish
			if twin != null and d0 < b.split_d and (pre >= b.split_d or (jammed and d0 >= b.split_d - GAP)):
				b["flip"] = not b.get("flip", false)
				if (b.flip or jammed) and _room_in(buckets, twin, 0.0):
					leave.call(it, b)
					it.belt = twin
					it.d = 0.0
					_bucket(buckets, twin).append(it)
					continue
			if nd >= b.len:
				var parent = b.get("parent", null)
				if parent != null:
					if _room_in(buckets, parent, b.join_d):
						leave.call(it, b)
						it.belt = parent
						it.d = b.join_d
						_bucket(buckets, parent).append(it)
						continue
					nd = b.len   # blocked: it waits at the end of the spur
					held += 1
				else:
					leave.call(it, b)
					gone.append(it)
					continue
			it.d = nd
			prev_d = nd
	for it in gone:
		fish.erase(it)
		arrive.call(it)
	return held

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
