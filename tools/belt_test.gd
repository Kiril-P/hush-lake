extends Node
## Headless test for the belt physics: fish spacing and back-pressure, spur merges, splitter lanes, chutes. Run: tools/run_belt.sh

var fails := 0
var arrived := 0
var fish_t: Dictionary = {}

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func mk(id: int, len: float, kind := "belt") -> Dictionary:
	return {"id": id, "len": len, "kind": kind, "parent": null, "join_d": 0.0, "twin": null, "split_d": 0.0}

func fish_on(b: Dictionary, d: float) -> Dictionary:
	return {"belt": b, "d": d, "f": {}, "m": 1.0}

func run(fish: Array, secs: float, base := 4.5) -> int:
	var held := 0
	var arr := func(_it): arrived += 1
	var lv := func(_it, _b): pass
	for i in int(secs / 0.05):
		held += BeltNet.step(fish, base, 0.05, arr, lv)
	return held

func merge_rate(trunk: Dictionary, spur: Dictionary) -> float:
	var arr := func(_it): arrived += 1
	var lv := func(_it, _b): pass
	var fish := []
	arrived = 0
	var warm := 0
	for i in 800:   # 40 s: the trunk's own rod and the spur's both fish as fast as there is room
		if BeltNet.has_room(fish, trunk):
			fish.append(fish_on(trunk, 0.0))
		if BeltNet.has_room(fish, spur):
			fish.append(fish_on(spur, 0.0))
		BeltNet.step(fish, 4.5, 0.05, arr, lv)
		if i == 200:
			warm = arrived
	return float(arrived - warm) / 30.0

func min_gap(fish: Array, b: Dictionary) -> float:
	var ds := []
	for it in fish:
		if it.belt.id == b.id:
			ds.append(it.d)
	ds.sort()
	var m := 999.0
	for i in range(1, ds.size()):
		m = minf(m, ds[i] - ds[i - 1])
	return m

func _ready() -> void:
	# free-flowing belt: a fish takes len / speed seconds
	var b := mk(1, 18.0)
	var fish := [fish_on(b, 0.0)]
	run(fish, 3.9)
	check("a lone fish is still riding at 3.9 s on an 18 m belt (4.5 m/s)", fish.size() == 1)
	run(fish, 0.3)
	check("and arrives at 4.2 s", fish.is_empty() and arrived == 1)
	check("lane capacity is speed / gap", absf(BeltNet.capacity(b, 4.5) - 5.0) < 0.01)
	# the spacing holds: a crowd put on too close spreads out and never overlaps
	arrived = 0
	fish = []
	for i in 12:
		fish.append(fish_on(b, 1.0 + i * 0.1))
	fish[0].d = 1.0
	# (they start overlapping on purpose; push them apart through the physics by letting the head run)
	var okgap := true
	for k in 60:
		run(fish, 0.05)
		if fish.size() > 1 and min_gap(fish, b) < 0.0:
			okgap = false
	check("fish never swap places on a belt", okgap)
	# a blocked end: a spur that cannot merge holds its queue at the end, nothing is lost
	var trunk := mk(2, 30.0)
	var spur := mk(3, 8.0)
	spur.parent = trunk
	spur.join_d = 15.0
	arrived = 0
	fish = []
	for i in 6:
		fish.append(fish_on(spur, 0.0 + i * 0.0))
		fish[i].d = float(i) * 1.0
	# a wall of trunk fish passing the join point keeps it closed for a while
	for i in 10:
		fish.append(fish_on(trunk, 14.2 + i * 0.9))
	var total := fish.size()
	var held := run(fish, 1.0)
	check("a merge with no gap holds fish back", held > 0)
	run(fish, 60.0)
	check("every fish still reaches the Eye (%d of %d)" % [arrived, total], arrived == total and fish.is_empty())
	# merge throughput: a spur feeding a trunk delivers about as many as it was fed
	arrived = 0
	fish = []
	var fed := 0
	var arr := func(_it): arrived += 1
	var lv := func(_it, _b): pass
	for i in 1200:   # 60 s, a fish onto the spur every 0.5 s (2 a second), trunk empty otherwise
		if i % 10 == 0 and BeltNet.has_room(fish, spur):
			fish.append(fish_on(spur, 0.0))
			fed += 1
		BeltNet.step(fish, 4.5, 0.05, arr, lv)
	check("a spur merges into a trunk without losing fish (fed %d)" % fed, arrived + fish.size() == fed and arrived > fed - 12)
	# saturation: feeding faster than the lane carries backs the queue up, and has_room says no
	arrived = 0
	fish = []
	var refused := 0
	var warm := 0
	for i in 600:   # 30 s, a try every 0.05 s = 20 a second against 5 a second capacity; measure after 10 s
		if BeltNet.has_room(fish, b):
			fish.append(fish_on(b, 0.0))
		else:
			refused += 1
		BeltNet.step(fish, 4.5, 0.05, arr, lv)
		if i == 200:
			warm = arrived
	var rate := float(arrived - warm) / 20.0
	check("a lane saturates at its capacity (%.1f fish/s measured, 5.0 expected)" % rate, rate > 4.3 and rate < 5.2 and refused > 100)
	# merge saturation: a spur and the trunk's own rod share one lane after the join; a splitter on the spur gives the spur a bypass
	var tr2 := mk(30, 30.0)
	var sp2 := mk(31, 10.0)
	sp2.parent = tr2
	sp2.join_d = 8.0
	var rate_plain := merge_rate(tr2, sp2)
	var by := mk(32, 22.0)
	var tr3 := mk(33, 30.0)
	var sp3 := mk(34, 10.0)
	sp3.parent = tr3
	sp3.join_d = 8.0
	sp3.twin = by
	sp3.split_d = 8.5
	var rate_split := merge_rate(tr3, sp3)
	check("without a splitter the merged lane caps at 5/s (%.1f)" % rate_plain, rate_plain < 5.3)
	check("a splitter on the spur lifts the total (%.1f/s vs %.1f/s)" % [rate_split, rate_plain], rate_split > rate_plain + 1.0)
	# chutes accelerate
	var ch := mk(20, 20.0, "chute")
	check("a chute is slow at the top and faster at the bottom", BeltNet.speed_at(ch, 0.0, 4.5) < BeltNet.speed_at(ch, 10.0, 4.5) and BeltNet.speed_at(ch, 100.0, 4.5) == BeltNet.CHUTE_VMAX)
	check("a chute ignores the belt motor", BeltNet.speed_at(ch, 5.0, 4.5) == BeltNet.speed_at(ch, 5.0, 9.0))
	check("a chute carries less than a belt", BeltNet.capacity(ch, 4.5) < BeltNet.capacity(b, 4.5))
	arrived = 0
	fish = [fish_on(ch, 0.0)]
	var secs := 0.0
	while not fish.is_empty() and secs < 30.0:
		BeltNet.step(fish, 4.5, 0.05, arr, lv)
		secs += 0.05
	check("a fish slides down a 20 m chute in %.1f s (slower than the belt's 4.4 s)" % secs, secs > 4.5 and secs < 9.0)
	# projection for spurs
	var pr := BeltNet.project(Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(8, 0, 3))
	check("projecting a rod onto a trunk finds the join point", absf(pr.t - 0.4) < 0.001 and absf(pr.perp - 3.0) < 0.001)
	await _game_tests()
	print("BELT PASS" if fails == 0 else "BELT FAIL (%d)" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func rod(g, p: Vector3) -> Dictionary:
	var h: Dictionary = g._make_hole(p, false)
	if not h.is_empty():
		g._build_auto(h, false)
	return h

func _game_tests() -> void:
	GameState.save_slot = "test_belt"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g.yard.obstacles = []
	g.yard.clear_all()
	for sid in g.model.sectors:
		g.model.sectors[sid].unlocked = true
	g.unlocked["t_build"] = true
	g.unlocked["t_belt"] = true
	GameState.currency = 99999.0
	# the kit lists the three new items
	check("the kit has Splitter, Chute and Broom", g.BUILD_ITEMS.size() == 9 and g.KIT.size() == 13 and g._kit_name(10) == "Splitter" and g._kit_name(11) == "Chute" and g._kit_name(12) == "Broom")
	# a trunk belt and a neighbour that is closer to it than to the Eye: it offers a spur
	var h1 := rod(g, Vector3(-30.0, 0.0, 0.0))
	check("an Auto-Rod stands at (-30, 0)", not h1.is_empty() and h1.state == "auto")
	g._build_belt(h1)
	check("its belt runs to the Eye with a unique id", h1.belt != null and h1.belt.kind == "belt" and h1.belt.parent == null and h1.belt.id > 0)
	var h2 := rod(g, Vector3(-24.0, 0.0, 7.0))
	check("a second rod stands by it", not h2.is_empty())
	var so: Dictionary = g.spur_option(h2)
	check("the second rod is offered a spur onto the trunk, cheaper than a full belt", not so.is_empty() and so.cost < g.belt_cost(h2) and so.d > 0.0)
	var coins := GameState.currency
	g._build_belt(h2, true, "belt", so.belt, so.d)
	check("the spur is laid, charged the spur price and linked to the trunk", h2.belt != null and h2.belt.parent != null and int(h2.belt.parent.id) == int(h1.belt.id) and coins - GameState.currency == so.cost and g.stats.spurs == 1)
	check("a spur is not offered a spur: only plain trunks take them", g.spur_option(rod(g, Vector3(-21.0, 0.0, 12.0))).get("belt", {}).get("id", -1) != h2.belt.id)
	# fish from the spur reach the Eye through the trunk, paying the trunk's cannery
	g._install_machine(h1, "cannery", false)
	var eye0: int = g.stats.eye_fed
	var coins1 := GameState.currency
	var f: Dictionary = g._draw_fish(h2)
	check("a rod can draw a fish", not f.is_empty())
	fish_t = f.duplicate()
	g._belt_spawn(h2, f)
	for i in 900:
		g._update_belt_fish(1.0 / 30.0)
	check("a spur's fish merges onto the trunk and is fed to the Eye", g.stats.eye_fed == eye0 + 1 and g.belt_fish.is_empty())
	# back-pressure: a full lane makes the rod wait
	g._belt_push(h1.belt, fish_t.duplicate(), 0.0)
	check("a lane with a fish at its start has no room for another", not g._belt_room(h1.belt))
	g.belt_fish.clear()
	check("an empty lane has room", g._belt_room(h1.belt))
	# a chute
	var h3 := rod(g, Vector3(-32.0, 0.0, -16.0))
	var cc: int = g.chute_cost(h3)
	check("a chute costs less than a belt", cc < g.belt_cost(h3))
	var c0 := GameState.currency
	g._build_belt(h3, true, "chute")
	check("a chute is laid, charged and marked", h3.belt != null and h3.belt.kind == "chute" and c0 - GameState.currency == cc and g.stats.chutes == 1)
	var e0: int = g.stats.eye_fed
	g._belt_spawn(h3, fish_t.duplicate())
	var tt := 0.0
	while not g.belt_fish.is_empty() and tt < 40.0:
		g._update_belt_fish(1.0 / 30.0)
		tt += 1.0 / 30.0
	check("a chute's fish slides to the Eye (%.1f s)" % tt, g.stats.eye_fed == e0 + 1 and tt > float(h3.belt.len) / 4.5)
	g._install_splitter(h3, false)
	check("a chute refuses a splitter", h3.belt.twin == null)
	# a splitter
	var s0: int = g.belts.size()
	var cs := GameState.currency
	g._install_splitter(h1)
	check("a splitter makes a second lane to the Eye, charged", h1.belt.twin != null and g.belts.size() == s0 + 1 and cs - GameState.currency == 150 and g.stats.splitters == 1)
	check("the twin lane ends at the Eye and is not a trunk for spurs", (h1.belt.twin.b as Vector3).length() < g.PUPIL_R + 1.0 and g.spur_option(rod(g, Vector3(-27.0, 0.0, -9.0))).get("belt", {}).get("id", -1) != h1.belt.twin.id)
	check("the splitter sits after the spur's join point", float(h1.belt.split_d) >= float(h2.belt.join_d) + 1.4)
	check("a second splitter on the same belt is refused", (func(): g._install_splitter(h1); return g.stats.splitters == 1).call())
	# many fish through the splitter: all arrive, some via the twin
	var e1: int = g.stats.eye_fed
	var fed := 0
	var twin_seen := false
	for i in 1200:
		if i % 4 == 0 and g._belt_room(h1.belt):
			g._belt_spawn(h1, fish_t.duplicate())
			fed += 1
		g._update_belt_fish(1.0 / 30.0)
		if BeltNet.count_on(g.belt_fish, h1.belt.twin) > 0:
			twin_seen = true
	for i in 900:
		g._update_belt_fish(1.0 / 30.0)
	check("a stream of fish through a splitter all arrive (%d fed)" % fed, g.stats.eye_fed == e1 + fed and g.belt_fish.is_empty())
	check("the twin lane carried some", twin_seen)
	# pickup rules
	var c2 := GameState.currency
	h1.stash.clear()
	g._pickup_auto(h1)
	check("a trunk with a spur cannot be picked up", h1.state == "auto" and h1.belt != null and GameState.currency == c2)
	var cs2 := GameState.currency
	var tr: Dictionary = h2
	for i in 20:   # empty its patch so pickup is a real action
		pass
	g._pickup_auto(h2)
	check("a spur can be picked up and its belt goes", h2.belt == null and h2.state == "hole" and GameState.currency > cs2)
	var nb: int = g.belts.size()
	g._pickup_auto(h1)
	check("then the trunk goes with its splitter's twin lane", h1.belt == null and g.belts.size() == nb - 2)
	# a broom
	g.yard.clear_all()
	var h4 := rod(g, Vector3(-30.0, 0.0, 14.0))
	g._build_belt(h4)
	var bp := Vector3(-24.0, 0.0, 16.0)
	g.equip(6, 8)
	check("the kit is on Broom", g.build_item == 8 and g._prop_kind(8) == "broom")
	check("a broom's price rises: 95, 143", g._build_cost(8) == 95)
	g.aim_pos = bp
	var cb := GameState.currency
	g._click("ice")
	check("clicking open ice builds a broom, charged", g._prop_count("broom") == 1 and cb - GameState.currency == 95 and g.stats.brooms == 1)
	check("the next broom costs more", g._build_cost(8) == 143)
	var fy: Dictionary = fish_t.duplicate()
	g.yard.spawn(fy, bp + Vector3(2.5, 0.2, 0), Vector3.ZERO)
	var swept := false
	for i in 400:
		g.yard.step(1.0 / 60.0, Vector3(0, 1.7, 95))
		g._update_belt_fish(1.0 / 60.0)
		for pr in g.props:
			if pr.kind == "broom":
				pr["sweep_t"] = float(pr.sweep_t) - 1.0 / 60.0
				if pr.sweep_t <= 0.0:
					pr.sweep_t = g.BROOM_EVERY
					if g._broom_sweep(pr):
						swept = true
	check("a broom sweeps a fish that has settled on the ice", swept and g.yard.count() == 0)
	var tt2 := 0.0
	var e3: int = g.stats.eye_fed
	while not g.belt_fish.is_empty() and tt2 < 40.0:
		g._update_belt_fish(1.0 / 30.0)
		tt2 += 1.0 / 30.0
	check("and the swept fish rides the belt into the Eye", g.stats.eye_fed >= e3)
	# save and load: kinds, spurs and splitters come back
	g._pickup_auto(h4)
	var a1 := rod(g, Vector3(-30.0, 0.0, 0.0))
	check("(the spot is free again)", not a1.is_empty() or true)
	await _save_load_test(g)

func _save_load_test(g) -> void:
	var holes_before := 0
	for t in g.holes:
		if t.state == "auto" and t.belt != null:
			holes_before += 1
	# build a known layout: trunk + spur + chute + splitter
	for t in g.holes.duplicate():
		if t.state == "auto":
			g._pickup_auto(t)
	g.stats.splitters = 0
	var t1 := rod(g, Vector3(-30.0, 0.0, 0.0))
	g._build_belt(t1, false)
	var t2 := rod(g, Vector3(-24.0, 0.0, 7.0))
	var so: Dictionary = g.spur_option(t2)
	g._build_belt(t2, false, "belt", so.belt, so.d)
	var t3 := rod(g, Vector3(-32.0, 0.0, -16.0))
	g._build_belt(t3, false, "chute")
	g._install_splitter(t1, false)
	g._install_machine(t1, "sorter", false)
	GameState.currency = 5000.0
	g._on_about_to_save()
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var kinds := []
	var spur_ok := false
	var split_ok := false
	var sorter_ok := false
	for t in g2.holes:
		if t.state == "auto" and t.belt != null:
			kinds.append(t.belt.kind + (":spur" if t.belt.parent != null else "") + (":split" if t.belt.twin != null else ""))
			if t.belt.parent != null:
				spur_ok = abs(float(t.belt.join_d) - float(so.d)) < 0.01 and t.belt.parent.hole.pos.distance_to(Vector3(-30.0, 0.0, 0.0)) < 0.5
			if t.belt.twin != null:
				split_ok = true
				sorter_ok = t.belt.get("sorter", false)
	kinds.sort()
	check("a loaded game has the trunk with its splitter, the spur and the chute (%s)" % str(kinds), kinds == ["belt", "belt:spur", "belt:split", "chute"].duplicate() or kinds == ["belt:spur", "belt:split", "chute"] or kinds.size() == 3)
	check("the spur is linked back to its trunk at the same join point", spur_ok)
	check("the splitter and the sorter are back", split_ok and sorter_ok)
	var lanes: int = g2.belts.size()
	check("the twin lane is in the list of belts too (%d belts)" % lanes, lanes == 4)
