extends RefCounted
## The finite lake: 19 sectors x 7 hex tiles ("flowers"), every tile holds a fixed stock of fish/items.
## Clear every fish from a sector to clear it; clearing a sector opens its neighbours.
## Pure data + rules (no nodes) so it can be unit-tested headless.

const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const SECTOR_DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
const LATTICE_U := Vector2i(2, 1)    # 7-hex flowers tile the plane with these two vectors
const LATTICE_V := Vector2i(-1, 3)
const SECTOR_RADIUS := 2             # sectors form a hexagon of radius 2 -> 19 sectors, 133 tiles
const SHELF_NAMES := ["Whitecap Shelf", "Drift Shelf", "Hollow Shelf", "Cairn Shelf", "Mirror Shelf", "Lantern Shelf"]
const DEEP_NAMES := ["Black Reach", "Pale Reach", "Wren Deep", "Salt Deep", "Hush Deep", "Anchor Deep",
	"Needle Deep", "Gloam Deep", "Echo Deep", "Frost Deep", "Cinder Deep", "Last Deep"]
const RARE := ["Golden Trout", "Old Coin", "Glass Pearl", "Ancient Fish"]

# species weights per ring (0 = Shallows, 1 = Shelves, 2 = Deeps) and fish-per-tile ranges
const MIX := {
	0: {"Minnow": 70, "Perch": 25, "Old Boot": 5},
	1: {"Minnow": 36, "Perch": 34, "Silver Pike": 15, "Old Boot": 5, "Golden Trout": 6, "Old Coin": 4},
	2: {"Minnow": 4, "Perch": 26, "Silver Pike": 32, "Golden Trout": 20, "Old Coin": 9, "Glass Pearl": 5, "Old Boot": 4},
}
const COUNT_RANGE := {0: [6, 9], 1: [9, 14], 2: [12, 18]}
const DEPTH_FISH := 0.3    # each earlier lake makes the next one 30% bigger
const COUNT_SCALE := 6.0   # fish per patch multiplier: sets how long a lake takes (tuned with tools/run_econ.sh)

# Lake modifiers: every lake after the first rolls one, so each run plays a little differently.
#   count = fish per tile x, rare = rare-species weight x, wait = bite wait x, value = sale price x
const MODS := {
	"": {"name": "Calm Lake", "desc": "an ordinary lake", "count": 1.0, "rare": 1.0, "wait": 1.0, "value": 1.0},
	"crowded": {"name": "Crowded Lake", "desc": "+35% fish, but a longer job", "count": 1.35, "rare": 1.0, "wait": 1.0, "value": 1.0},
	"treasure": {"name": "Treasure Lake", "desc": "twice the rare finds, 20% fewer fish", "count": 0.8, "rare": 2.0, "wait": 1.0, "value": 1.0},
	"skittish": {"name": "Skittish Lake", "desc": "bites take 50% longer, fish sell for +40%", "count": 1.0, "rare": 1.0, "wait": 1.5, "value": 1.4},
	"glass": {"name": "Glass Lake", "desc": "bites come 30% sooner, fish sell for -20%", "count": 1.0, "rare": 1.0, "wait": 0.7, "value": 0.8},
}

var seed_value := 0
var mod := ""
var sectors := {}       # Vector2i -> {id, ring, name, center, tiles, unlocked, cleared, total, left}
var tile_sector := {}   # Vector2i (tile) -> Vector2i (sector)
var stock := {}         # Vector2i (tile) -> {species: count}
var initial := {}       # Vector2i (tile) -> fish at generation

static func ring_of(u: int, v: int) -> int:
	return maxi(maxi(absi(u), absi(v)), absi(u + v))

static func _angle(tile: Vector2i) -> float:
	return atan2(1.5 * tile.y, sqrt(3.0) * (tile.x + tile.y / 2.0))

func mod_info() -> Dictionary:
	return MODS.get(mod, MODS[""])

func generate(seed_in: int, mod_in := "", depth := 0) -> void:
	seed_value = seed_in
	mod = mod_in if MODS.has(mod_in) else ""
	sectors.clear()
	tile_sector.clear()
	stock.clear()
	initial.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_in
	var by_ring := {1: [], 2: []}
	for u in range(-SECTOR_RADIUS, SECTOR_RADIUS + 1):
		for v in range(-SECTOR_RADIUS, SECTOR_RADIUS + 1):
			var r := ring_of(u, v)
			if r > SECTOR_RADIUS:
				continue
			var id := Vector2i(u, v)
			var center := LATTICE_U * u + LATTICE_V * v
			var tl: Array = [center]
			for d in DIRS:
				tl.append(center + d)
			sectors[id] = {"id": id, "ring": r, "name": "The Shallows", "center": center, "tiles": tl,
				"unlocked": r == 0, "cleared": false, "total": 0, "left": 0}
			for tc in tl:
				tile_sector[tc] = id
			if r > 0:
				by_ring[r].append(id)
	for r in [1, 2]:
		var ids: Array = by_ring[r]
		ids.sort_custom(func(a, b): return _angle(sectors[a].center) < _angle(sectors[b].center))
		for i in ids.size():
			sectors[ids[i]].name = (SHELF_NAMES if r == 1 else DEEP_NAMES)[i]
	for id in sectors:
		var sec: Dictionary = sectors[id]
		for tc in sec.tiles:
			var st := {}
			if tc != Vector2i.ZERO:  # the centre tile is the player's platform
				var rr: Array = COUNT_RANGE[sec.ring]
				var mix: Dictionary = MIX[sec.ring].duplicate()
				for k in RARE:
					if mix.has(k):
						mix[k] = int(round(mix[k] * mod_info().rare))
				for i in int(round(rng.randi_range(rr[0], rr[1]) * mod_info().count * COUNT_SCALE * (1.0 + DEPTH_FISH * depth))):
					var sp := _pick(rng, mix)
					st[sp] = st.get(sp, 0) + 1
			stock[tc] = st
		# one Ancient Fish hides in each of the six outermost corner sectors
		if sec.ring == 2 and (id.x == 0 or id.y == 0 or id.x + id.y == 0):
			var tc2: Vector2i = sec.tiles[rng.randi_range(0, 6)]
			stock[tc2]["Ancient Fish"] = stock[tc2].get("Ancient Fish", 0) + 1
	for tc in stock:
		initial[tc] = tile_left(tc)
	_recount()

func _pick(rng: RandomNumberGenerator, mix: Dictionary) -> String:
	var total := 0
	for k in mix:
		total += mix[k]
	var r := rng.randi_range(1, total)
	for k in mix:
		r -= mix[k]
		if r <= 0:
			return k
	return mix.keys()[0]

func _recount() -> void:
	for id in sectors:
		var sec: Dictionary = sectors[id]
		sec.total = 0
		sec.left = 0
		for tc in sec.tiles:
			sec.total += initial[tc]
			sec.left += tile_left(tc)

func tile_left(c: Vector2i) -> int:
	var n := 0
	var st: Dictionary = stock.get(c, {})
	for k in st:
		n += st[k]
	return n

func species_left(sp: String) -> int:
	var n := 0
	for c in stock:
		n += stock[c].get(sp, 0)
	return n

func sector_left(id: Vector2i) -> int:
	return sectors[id].left

func total_left() -> int:
	var n := 0
	for id in sectors:
		n += sectors[id].left
	return n

func total_initial() -> int:
	var n := 0
	for id in sectors:
		n += sectors[id].total
	return n

func cleared_count() -> int:
	var n := 0
	for id in sectors:
		if sectors[id].cleared:
			n += 1
	return n

func is_unlocked(c: Vector2i) -> bool:
	return sectors[tile_sector[c]].unlocked

func neighbors(id: Vector2i) -> Array:
	var out := []
	for d in SECTOR_DIRS:
		if sectors.has(id + d):
			out.append(id + d)
	return out

func has_rare(c: Vector2i) -> bool:
	var st: Dictionary = stock.get(c, {})
	for k in RARE:
		if st.has(k):
			return true
	return false

func band(c: Vector2i) -> String:
	var n := tile_left(c)
	if n == 0: return "none"
	if n <= 3: return "a few"
	if n <= 8: return "some"
	return "plenty"

## Fish get warier as a tile empties: the last few take noticeably longer to bite.
func wait_factor(c: Vector2i) -> float:
	var init: int = initial.get(c, 0)
	if init <= 0:
		return 1.0
	var gone := 1.0 - float(tile_left(c)) / init
	return (1.0 + 1.2 * gone * gone) * mod_info().wait

## Removes one random fish/item from the tile. Returns its species name, or "" if the tile is empty.
func draw(c: Vector2i) -> String:
	var n := tile_left(c)
	if n == 0:
		return ""
	var st: Dictionary = stock[c]
	var k := randi() % n
	for sp in st.keys():
		k -= st[sp]
		if k < 0:
			st[sp] -= 1
			if st[sp] <= 0:
				st.erase(sp)
			sectors[tile_sector[c]].left -= 1
			return sp
	return ""

## Call after a draw. Returns true exactly once, when the sector first becomes empty.
func refresh_sector(id: Vector2i) -> bool:
	var sec: Dictionary = sectors[id]
	if sec.cleared or sec.left > 0:
		return false
	sec.cleared = true
	for nb in neighbors(id):
		sectors[nb].unlocked = true
	return true

# ----- save / load -----
static func _key(v: Vector2i) -> String:
	return "%d,%d" % [v.x, v.y]

static func _parse(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1]))

func to_dict() -> Dictionary:
	var st := {}
	for tc in stock:
		st[_key(tc)] = stock[tc]
	var un := []
	var cl := []
	for id in sectors:
		if sectors[id].unlocked:
			un.append(_key(id))
		if sectors[id].cleared:
			cl.append(_key(id))
	return {"seed": seed_value, "mod": mod, "stock": st, "unlocked": un, "cleared": cl}

func from_dict(d: Dictionary) -> void:
	generate(int(d.get("seed", 0)), String(d.get("mod", "")))
	for key in d.get("stock", {}):
		var st := {}
		for sp in d.stock[key]:
			st[sp] = int(d.stock[key][sp])
		stock[_parse(key)] = st
	for key in d.get("unlocked", []):
		sectors[_parse(key)].unlocked = true
	for key in d.get("cleared", []):
		sectors[_parse(key)].cleared = true
	_recount()
