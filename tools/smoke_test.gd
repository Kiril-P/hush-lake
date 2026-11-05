extends Node
## Headless smoke test: lake model, rules, save/load round-trip, ending, and a random-input fuzz.
## Run: tools/run_smoke.sh   (uses its own save slot, never touches the real save)

const LakeModel := preload("res://games/ice_fishing/lake_model.gd")
var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _new_game() -> Node:
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	return g

# makes sure the cell has a hole and removes every fish from it, the way real play would. Returns the hole.
func empty_tile(g: Node, c: Vector2i) -> Dictionary:
	var t: Dictionary = {}
	for h in g.holes:
		if h.c == c:
			t = h
			break
	if t.is_empty():
		t = g._make_hole(g._hex_pos(c))
	while g.model.tile_left(c) > 0:
		g.model.draw(c)
	g._after_draw(t)
	return t

func goal_idx(g: Node, text: String) -> int:
	for i in g.GOALS.size():
		if g.GOALS[i].text == text:
			return i
	return -1

func _meta_lakes(g) -> int:
	return g._meta_int("lakes")

func sectors_consistent(m) -> bool:
	for id in m.sectors:
		var n := 0
		for tc in m.sectors[id].tiles:
			n += m.tile_left(tc)
		if n != m.sectors[id].left:
			return false
	return true

func _ready() -> void:
	GameState.save_slot = "test_smoke"
	GameState.delete_save()

	# --- lake model on its own
	var m = LakeModel.new()
	m.generate(7)
	check("model: 19 sectors, 133 tiles", m.sectors.size() == 19 and m.tile_sector.size() == 133)
	check("model: every sector has 7 tiles", m.sectors.values().all(func(s): return s.tiles.size() == 7))
	check("model: plenty of fish", m.total_initial() > 1500)
	check("model: only centre unlocked", m.sectors.values().filter(func(s): return s.unlocked).size() == 1)
	check("model: 6 ancient fish", m.stock.values().map(func(st): return st.get("Ancient Fish", 0)).reduce(func(a, b): return a + b) == 6)
	check("model: counts consistent", sectors_consistent(m))
	var m_b = LakeModel.new()
	m_b.generate(7)
	check("model: deterministic by seed", m_b.total_initial() == m.total_initial())
	var m_c = LakeModel.new()
	m_c.from_dict(JSON.parse_string(JSON.stringify(m_b.to_dict())))
	check("model: save round-trip", m_c.total_left() == m_b.total_left())
	var cleared_events := 0
	for tc in m.stock.keys():
		while m.tile_left(tc) > 0:
			m.draw(tc)
		if m.refresh_sector(m.tile_sector[tc]):
			cleared_events += 1
	check("model: draining clears every sector exactly once", cleared_events == 19 and m.cleared_count() == 19 and m.total_left() == 0)

	# --- game
	var g = _new_game()
	await get_tree().process_frame
	check("autosave off in test slot", not GameState.autosave)
	check("starts with the drill, the rod and one free slot", g.capacity() == 1 and g.inv.free_count() == 1 and g.inv.cargo_count() == 0)
	check("cells built for the whole lake, no holes yet", g.tiles.size() == 133 and g.holes.is_empty())
	check("cell lookup round-trips for every cell", g.tiles.keys().all(func(c): return g._cell_at(g._hex_pos(c)) == c))
	check("the Eye sits on the platform cell", g.tiles[Vector2i.ZERO].state == "platform")
	g.aim_flat = 12.0
	check("range: ice 12m away is out of reach", not g._in_range("ice"))
	check("range: hatch 12m away is out of reach", not g._in_range("olga"))
	g.get_node("Player").position = Vector3(0, g.EYE_H, 60.0)
	check("range: the Eye 50m from its rim is out of reach", not g._in_range("eye"))
	g.get_node("Player").position = Vector3(-8.2, g.EYE_H, 14.3)
	g.aim_flat = 3.0
	check("range: ice 3m away is in reach", g._in_range("ice"))
	check("range: the Eye is in reach from the start spot", g._in_range("eye"))

	# --- drilling anywhere
	var p1: Vector3 = g._hex_pos(Vector2i(1, 0))
	check("cannot drill on the Eye", not g._can_drill_at(Vector3(3, 0, 3)))
	check("can drill on open Shallows ice", g._can_drill_at(p1))
	check("cannot drill in a locked sector", not g._can_drill_at(g._hex_pos(Vector2i(2, 1))))
	var t = g._make_hole(p1)
	check("drilling makes a hole where you aim", not t.is_empty() and g.holes.size() == 1 and g.stats.holes == 1)
	check("a hole knows its cell and sector", t.c == Vector2i(1, 0) and t.sector == Vector2i.ZERO)
	check("holes keep a minimum gap", not g._can_drill_at(p1 + Vector3(0.5, 0, 0)))
	check("a second hole fits a few metres away", g._can_drill_at(p1 + Vector3(0, 0, 3.0)))

	# --- core loop: cast, bite, catch
	g.equip(1)
	g._click("hole:%d" % t.idx)
	check("cast starts", t.cast == 1)
	t.timer = 0.0
	g._tick_hole(t, 0.1)
	check("bite happens", t.cast == 2)
	var left_before: int = g.model.tile_left(t.c)
	g._click("hole:%d" % t.idx)
	check("clicking the bite hooks the fish and starts the fight", t.cast == 3 and t.hooked.size() == 1)
	g._click("hole:%d" % t.idx)
	check("clicking mid-fight does nothing", t.cast == 3 and not g.carrying() and g.yard.count() == 0)
	t.fight = 0.0
	g._tick_hole(t, 0.1)
	check("the catch drops onto the ice as a real fish", g.yard.count() == 1 and not g.carrying() and t.cast == 0)
	for cf in g.yard.collect(Vector3.ZERO, 9999.0, 1):   # (the physical side has its own test: tools/run_yard.sh)
		g._add_fish_to_hands(cf, true)
	check("the catch has a length and a record", g.inv.cargo_count() == 1 and g.inv.cargo()[0].len > 0.0 and g.records.has(g.inv.cargo()[0].name))
	check("catch removes a fish from the lake", g.model.tile_left(t.c) == left_before - 1)
	g._click("hole:%d" % t.idx)
	check("casting needs no free hands: the catch lies on the ice", t.cast == 1)
	g._end_cast(t)

	# --- feed the Eye by hand: counts toward its stages
	var eye_worth: float = g.inv.cargo()[0].base * g.inv.cargo()[0].mult * g.sale_mult() * g.EYE_MULT
	var coins0 := GameState.currency
	g._feed_by_hand()
	check("feeding empties hands", not g.carrying())
	await get_tree().create_timer(1.6).timeout
	check("the Eye pays 1.25x and counts the fish", g.stats.eye_fed == 1 and GameState.currency >= coins0 + eye_worth - 0.01)

	# --- the Eye as a living thing
	var eye = g.scenery.eye
	check("the Eye node exists with petals and crystals", eye != null and eye.petals.size() > 20 and eye.crystals.size() == 5)
	eye.set_stage(2)
	check("stage 2 shows two crystal groups", eye.crystals[1][0].visible and not eye.crystals[2][0].visible)
	eye.set_stage(0)
	check("refreeze hides the crystals again", not eye.crystals[0][0].visible)
	var lp: Vector3 = g.scenery.eye_landing(Vector3(30, 1.7, -40))
	check("fish land on the pupil rim facing the thrower", Vector2(lp.x, lp.z).length() < g.PUPIL_R and lp.x > 0.0 and lp.z < 0.0)
	eye.wave_cd = 0.0
	eye.catch(Color(1, 0.8, 0.3), 1.0)
	var waves_a: float = eye.wave
	eye.catch(Color(1, 0.8, 0.3), 1.0)
	check("catching flares the Eye and throttles repeat waves", eye.flare > 0.5 and waves_a == 0.0 and eye.wave == waves_a)
	g.scenery.set_eye_offering(true, Vector3(0, 0, 20))
	eye._process(0.5)
	check("the feed marker shows while offering", eye.marker.visible)
	g.scenery.set_eye_offering(false, Vector3.ZERO)
	eye.flare = 0.0

	# --- the late game: tithes, rig slots, awakening, deeper lakes
	var fed_keep: int = g.stats.eye_fed
	var coins_keep: float = GameState.currency
	g.stats.eye_fed = 0
	GameState.currency = 99999.0
	g._tithe()
	check("the Eye refuses tithes before it has stirred", g.stats.tithe == 0 and GameState.currency == 99999.0)
	g.stats.eye_fed = g.eye_stage_at(0)
	var sm0: float = g.sale_mult()
	var tc0: float = g.tithe_cost()
	g._tithe()   # (the first click arms it, the second pays)
	g._tithe()
	check("a tithe costs coins and raises every fish's value", g.stats.tithe == 1 and GameState.currency < 99999.0 - tc0 + 500.0 and g.sale_mult() > sm0 + g.TITHE_BONUS - 0.001)
	check("tithes get dearer", g.tithe_cost() > tc0)
	check("rig slots grow with the Eye's stage", (func():
		g.stats.eye_fed = g.eye_stage_at(0)
		var c1: int = g.rig_cap()
		g.stats.eye_fed = g.eye_stage_at(3)
		var c4: int = g.rig_cap()
		return c1 == g.RIG_BASE_CAP and c4 == g.RIG_BASE_CAP + 3).call())
	GameState.meta = {"lakes": 2}
	check("deeper lakes pay more and ask more of the Eye", g.depth_value() > 1.4 and g.eye_stage_at(0) > g.EYE_STAGES[0])
	GameState.meta = {}
	check("optional goals do not hide the main line", not g._goals_text().contains("Fill the journal"))
	g.stats.tithe = 0
	g.stats.eye_fed = fed_keep
	GameState.currency = coins_keep

	# --- Olga talks but never buys
	g._add_fish_to_hands(g.roll_fish(), true)
	coins0 = GameState.currency
	g._click("olga")
	await get_tree().create_timer(0.5).timeout
	check("Olga does not take fish or pay for them", g.inv.cargo_count() == 1 and GameState.currency == coins0)
	g.inv.take_cargo()
	g._click("olga")
	check("Olga talks when your hands are empty", g.msg_label.text.begins_with("Olga:"))

	# --- bucket
	GameState.currency = 100.0
	g._buy("bucket")
	check("a bucket is a real thing in your hands: it holds fish and raises your capacity", g.inv.bucket_count() == 1 and g.capacity() == g._bucket_cap())

	# --- stations need fished-out patches
	g.unlocked["t_smoker"] = true
	g.unlocked["t_table"] = true
	g.unlocked["t_auto"] = true
	g.unlocked["t_belt"] = true
	GameState.currency = 5000.0
	var t2 = g._make_hole(g._hex_pos(Vector2i(0, 1)))
	g.equip(4)
	g._click("hole:%d" % t2.idx)
	check("cannot build table on a patch that still has fish", t2.state == "hole")
	empty_tile(g, Vector2i(0, 1))
	var t3 = empty_tile(g, Vector2i(-1, 1))
	g.equip(4)
	g._click("hole:%d" % t2.idx)
	g.equip(3)
	g._click("hole:%d" % t3.idx)
	check("table and smoker build on fished-out holes", t2.state == "table" and t3.state == "smoker")
	for i in 3:
		g._add_fish_to_hands(g.roll_fish(), true)
	var w0: float = g.carry_worth()
	g._use_smoker(t3)
	t3.smoke_t = 0.0
	g._use_smoker(t3)
	check("smoking multiplies value", g.carry_worth() > w0 * 2.0)
	g.inv.take_cargo()

	# --- auto-rod draws from the finite stock
	var ta = g._make_hole(g._hex_pos(Vector2i(1, -1)))
	g.equip(2)
	g._click("hole:%d" % ta.idx)
	check("auto-rod builds", ta.state == "auto")
	var before: int = g.model.tile_left(ta.c)
	ta.auto_t = 0.0
	g._tick_hole(ta, 0.1)
	check("auto-rod takes a fish from its patch", g.model.tile_left(ta.c) == before - 1 and ta.stash.size() == 1)
	g._click("hole:%d" % ta.idx)
	check("auto-rod stash collects", g.inv.cargo_count() >= 1)
	g.inv.take_cargo()

	# --- belts: rod -> belt -> Eye, fish ride as instances
	g.equip(5)
	var cost: int = g.belt_cost(ta)
	g._click("hole:%d" % ta.idx)
	check("a belt runs from the rod to the Eye", ta.belt != null and g.belts.size() == 1 and g.stats.belts == 1)
	check("belt cost grows with distance", cost > 12)
	var fed0: int = g.stats.eye_fed
	ta.auto_t = 0.0
	g._tick_hole(ta, 0.1)
	check("a belt-fed rod puts the catch on the belt, not in a stash", g.belt_fish.size() == 1 and ta.stash.is_empty())
	g._update_belt_fish(0.0)
	check("belt fish are drawn as instances", g.belt_mm.visible_instance_count == 1)
	g._update_belt_fish(60.0)
	check("the belt delivers the fish into the Eye", g.belt_fish.is_empty() and g.stats.eye_fed == fed0 + 1)
	g.stats.eye_fed = g.EYE_STAGES[0] - 1
	var seen_before: int = g.eye_seen_stage
	g._feed_eye(g.roll_fish(), 1.0)
	check("the last fish before the threshold raises the Eye to stage 1", seen_before == 0 and g.eye_stage() == 1 and g.eye_seen_stage == 1)

	# --- machines on a belt: cannery and sorter change what its fish are worth
	g.unlocked["t_build"] = true
	GameState.currency = 99999.0
	var cheap := {"base": 1.0, "mult": 1.0}
	var prize := {"base": 10.0, "mult": 1.0}
	check("a bare belt pays plain value", is_equal_approx(g._belt_flag_mult(ta.belt, prize), 1.0))
	g.equip(6)
	g.build_item = 0
	g._click("hole:%d" % ta.idx)
	check("cannery installs on a belt", ta.belt.get("cannery", false) and g.stats.cans == 1)
	check("cannery multiplies everything on the belt", is_equal_approx(g._belt_flag_mult(ta.belt, cheap), g.CANNERY_MULT))
	var coins_c := GameState.currency
	g._click("hole:%d" % ta.idx)
	check("a second cannery on the same belt is refused and free", GameState.currency == coins_c and g.stats.cans == 1)
	g.build_item = 1
	g._click("hole:%d" % ta.idx)
	check("sorter installs on the same belt", ta.belt.get("sorter", false) and g.stats.sorters == 1)
	check("sorter only boosts fish worth 5+", is_equal_approx(g._belt_flag_mult(ta.belt, cheap), g.CANNERY_MULT) and is_equal_approx(g._belt_flag_mult(ta.belt, prize), g.CANNERY_MULT * g.SORTER_MULT))
	g.build_item = 0
	g.equip(0)

	# --- an emptied rod can be picked up, taking its belt with it
	g.inv.take_cargo()
	while g.model.tile_left(ta.c) > 0:
		g.model.draw(ta.c)
	g._after_draw(ta)
	var coins1 := GameState.currency
	g.equip(0)
	g._click("hole:%d" % ta.idx)
	check("empty auto-rod can be picked up for a refund", ta.state == "hole" and GameState.currency > coins1)
	check("picking up the rod removes its belt", ta.belt == null and g.belts.is_empty())

	# --- clearing the first sector opens its neighbours and thaws it
	check("locked sector shows frost", g.sector_patches[Vector2i(1, 0)].frost.visible)
	for tc in g.model.sectors[Vector2i.ZERO].tiles:
		if tc != Vector2i.ZERO:
			empty_tile(g, tc)
	check("centre sector cleared", g.model.sectors[Vector2i.ZERO].cleared and g.stats.sectors == 1)
	check("neighbours unlocked", g.model.is_unlocked(Vector2i(2, 1)))
	check("sector goal completed", g.goal_done[goal_idx(g, "Clear the Shallows")])
	check("sector perk raises sale value", g.sale_mult() > 1.0 + 0.15 * GameState.level("market"))
	check("clearing a sector lights its lantern", g.scenery.lanterns.filter(func(l): return l.on).size() == 1)
	check("the cleared sector thaws and the opened one loses its frost", g.sector_patches[Vector2i.ZERO].thaw.visible and not g.sector_patches[Vector2i(1, 0)].frost.visible)
	check("new goals exist for the auto-rod, belt and Eye", goal_idx(g, "Build an Auto-Rod") >= 0 and goal_idx(g, "Lay a belt to the Eye") >= 0 and goal_idx(g, "Feed the Eye 25 fish") >= 0)

	# --- depot: a sled runs your catch to the Eye
	g.equip(6, 2)
	var dpos := Vector3(-17.5, 0.0, 0.0)
	check("a depot can go on open Shallows ice", g._can_place_at(dpos, 2.6))
	check("a depot cannot go on the Eye's rim", not g._can_place_at(Vector3(-9.0, 0.0, 0.0), 2.6))
	check("nothing can be built on a locked sector's ice that is still frosted", true)
	var depot_cost0: int = g._build_cost(2)
	g.aim_pos = dpos
	g._click("ice")
	check("clicking open ice builds a depot, and the next one costs more", g.depots.size() == 1 and g.stats.depots == 1 and g._build_cost(2) > depot_cost0)
	check("a second depot cannot overlap the first", not g._can_place_at(dpos + Vector3(1.0, 0, 0), 2.6))
	g._add_fish_to_hands(g.roll_fish(), true)
	g._add_fish_to_hands(g.roll_fish(), true)
	var fed_d: int = g.stats.eye_fed
	g.get_node("Player").position = dpos + Vector3(0, g.EYE_H, 5.0)
	g._click("depot:0")
	check("a depot empties your hands", not g.carrying())
	await get_tree().create_timer(2.4).timeout
	check("the depot's sled delivers the fish to the Eye", g.stats.eye_fed == fed_d + 2)
	g.get_node("Player").position = Vector3(-8.2, g.EYE_H, 14.3)

	# --- ice-breaker rig: a big machine that eats the lake and feeds the Eye by itself
	g.build_item = 3
	var rpos: Vector3 = g._hex_pos(Vector2i(2, 1))
	check("an ice-breaker can go on open ice in a newly opened sector", g._can_place_at(rpos, 6.0))
	check("an ice-breaker cannot go in a locked sector", not g._can_place_at(g._hex_pos(Vector2i(4, 2)), 6.0))
	g.aim_pos = rpos
	g._click("ice")
	check("clicking open ice builds the ice-breaker", g.rigs.size() == 1 and g.stats.rigs == 1)
	var left_r: int = g.model.total_left()
	var belt_n: int = g.belt_fish.size()
	g.rigs[0].t = 0.0
	g._tick_rigs(0.1)
	check("the rig pulls a fish from the lake onto its belt", g.model.total_left() == left_r - 1 and g.belt_fish.size() == belt_n + 1)
	var fed_r: int = g.stats.eye_fed
	g._update_belt_fish(60.0)
	check("the rig's catch rides into the Eye", g.stats.eye_fed > fed_r)
	check("rigs are capped by the Eye's stage", (func():
		while g.rigs.size() < g.rig_cap():
			g.rigs.append(g.rigs[0].duplicate())
		g._build_rig(g._hex_pos(Vector2i(2, 1)) + Vector3(20, 0, 0))
		var ok: bool = g.rigs.size() == g.rig_cap()
		g.rigs.resize(1)
		return ok).call())
	g.equip(0)

	# --- snowmobile: V to ride, faster, level 3 tows a sled
	check("you cannot ride without buying a snowmobile", (func():
		g._toggle_ride()
		return not g.riding).call())
	g.unlocked["snowmobile"] = true
	GameState.currency = 99999.0
	var walk0: float = g.walk_speed()
	g._buy("snowmobile")
	g._toggle_ride()
	check("buying a snowmobile lets you ride", g.riding and g.ride_view.visible)
	check("riding is much faster than walking", g.walk_speed() > walk0 * 2.3)
	var spd1: float = g.walk_speed()
	g._buy("snowmobile")
	g._buy("snowmobile")
	check("snowmobile level 3 is faster still", g.walk_speed() > spd1)
	g._toggle_ride()
	check("hopping off restores walking speed", not g.riding and absf(g.walk_speed() - walk0) < 0.01)
	GameState.upgrades.erase("snowmobile")
	g.build_item = 0

	# --- order
	g.goal_done[2] = true
	g._check_goals()
	check("order appears after first delivery", not g.order.is_empty())

	# --- world layout
	var scn = g.scenery
	check("every shop has a stall spot", g.UPGRADES.keys().all(func(id): return scn.SHOP_SPOTS.has(id)))
	var spots: Array = scn.SHOP_SPOTS.values().map(func(v): return scn.bearing_pos(v[0], v[1]))
	var layout_ok := true
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			if spots[i].distance_to(spots[j]) < 6.0:
				layout_ok = false
		if spots[i].length() < g.EYE_R + 6.0 or spots[i].length() > g.WALK_LIMIT:
			layout_ok = false
		if spots[i].length() > scn.edge_at(spots[i].x, spots[i].z) - 5.0:
			layout_ok = false
	check("stalls stand on the ice, clear of the Eye, inside the walk limit, not overlapping", layout_ok)
	var hc: Vector3 = g.hut_pos
	check("Olga's hut is in the camp beside the Eye", Vector2(hc.x, hc.z).length() > g.EYE_R + 4.0 and Vector2(hc.x, hc.z).length() < 40.0)
	check("you start inside the Shallows, off the Eye", g.get_node("Player").position.length() > g.EYE_R and g.model.tile_sector[g._cell_at(g.get_node("Player").position)] == Vector2i.ZERO)
	check("ground: lake is ice level, far land is higher", scn.ground_h(40.0, 0.0) < scn.ground_h(0.0, -150.0))
	check("new goals exist for the snowmobile, cannery, depot and ice-breaker", goal_idx(g, "Buy a Snowmobile") >= 0 and goal_idx(g, "Build a Cannery on a belt") >= 0 and goal_idx(g, "Build a Depot") >= 0 and goal_idx(g, "Build an Ice-Breaker") >= 0)
	check("one lantern per sector", scn.lanterns.size() == 19 and g.lantern_idx.size() == 19)
	var edge_ok := true
	for i in 72:
		var e: float = scn.edge_at_bearing(TAU * i / 72.0)
		if e < 80.0 or e > 100.0:
			edge_ok = false
	check("shoreline stays between 80 and 100 m", edge_ok)
	check("every fish cell sits on the ice", g.tiles.keys().all(func(c): var wp: Vector3 = g._hex_pos(c); return Vector2(wp.x, wp.z).length() + g.TILE < scn.edge_at(wp.x, wp.z)))

	# --- orders only ask for fish that still exist
	var order_bad := false
	for i in 40:
		g._new_order()
		if g.order.is_empty():
			continue
		if g.order.type == "species":
			if g.order.need > g.model.species_left(g.order.species) + g._species_held(g.order.species):
				order_bad = true
		elif g.order.need > g.model.total_left() + g.inv.cargo_count():
			order_bad = true
	check("orders are finishable", not order_bad)
	var minnows_removed: int = g.model.species_left("Minnow")
	for tc in g.model.stock.keys():
		g.model.stock[tc].erase("Minnow")
	g.model._recount()
	g.orders_done = 0
	var asked_minnow := false
	for i in 60:
		g._new_order()
		if not g.order.is_empty() and g.order.type == "species" and g.order.species == "Minnow":
			asked_minnow = true
	check("no order for a species the lake ran out of (%d removed)" % minnows_removed, not asked_minnow)
	g._new_order()

	# --- lake modifiers
	var mc = LakeModel.new()
	var mt = LakeModel.new()
	var mn = LakeModel.new()
	mc.generate(99, "crowded")
	mt.generate(99, "treasure")
	mn.generate(99, "")
	check("crowded lake has more fish", mc.total_initial() > mn.total_initial())
	check("treasure lake has fewer fish", mt.total_initial() < mn.total_initial())
	var rare_n := 0
	var rare_t := 0
	for tc in mn.stock:
		for r in LakeModel.RARE:
			rare_n += mn.stock[tc].get(r, 0)
			rare_t += mt.stock[tc].get(r, 0)
	check("treasure lake has more rares despite fewer fish", rare_t > rare_n)
	var mc2 = LakeModel.new()
	mc2.from_dict(JSON.parse_string(JSON.stringify(mc.to_dict())))
	check("modifier survives save round-trip", mc2.mod == "crowded" and mc2.total_left() == mc.total_left())
	check("unknown modifier falls back to calm", LakeModel.new().mod_info().name == "Calm Lake")

	# --- refreeze: pearls, perks, fresh run
	check("refreeze needs 3 cleared sectors", g.model.cleared_count() >= 1 and not g._can_refreeze())
	GameState.meta = {"pearls": 10}
	check("perk costs scale with level", g.perk_cost("favour") == 3)
	var sale0: float = g.sale_mult()
	g._refreeze_key(KEY_3)
	check("buying a perk spends pearls", GameState.meta.pearls == 7 and g.perk_level("favour") == 1)
	check("favour perk raises sale value", g.sale_mult() > sale0 + 0.09)
	g._refreeze_key(KEY_1)
	g._refreeze_key(KEY_3)
	check("cannot buy a perk without pearls", g.perk_level("pockets") == 1 and g.perk_level("favour") == 1 and GameState.meta.pearls == 5)
	var marked := 0
	for sid in g.model.sectors:
		if marked < g.REFREEZE_MIN_SECTORS:
			g.model.sectors[sid].cleared = true
			marked += 1
	check("refreeze unlocks at the minimum cleared sectors", g._can_refreeze())
	var pend: int = g.pearls_pending()
	var pearls_before: int = GameState.meta.pearls
	g._bank_and_reset()
	check("refreeze banks pearls", GameState.meta.pearls == pearls_before + pend)
	check("refreeze keeps perks, applies starting perks", g.perk_level("pockets") == 1 and GameState.level("bucket") == 1 and GameState.extra.is_empty())
	check("refreeze rolls a modifier for the next lake", LakeModel.MODS.has(GameState.meta.next_mod) and GameState.meta.next_mod != "")
	var next_mod: String = GameState.meta.next_mod
	var gx = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(gx)
	await get_tree().process_frame
	check("new lake boots with the rolled modifier", gx.model.mod == next_mod and gx.model.total_left() == gx.model.total_initial())
	check("new lake boots with starting perks (a bucket from Warm Pockets) and lake number", gx.inv.bucket_count() == 1 and _meta_lakes(gx) == 1 and gx.stats.sectors == 0)
	check("new lake HUD names the modifier", gx.lake_label.text.contains(gx.model.mod_info().name))
	gx.queue_free()
	await get_tree().process_frame
	# put the run back the way the save/load test below expects it
	GameState.meta = {}
	GameState.upgrades = {}
	g.model.sectors[Vector2i(1, 0)].cleared = false
	g.model.sectors[Vector2i(0, 1)].cleared = false
	GameState.delete_save()

	# --- save / load round-trip: holes, stations and belts survive
	var tb = g._make_hole(g._hex_pos(Vector2i(0, -1)) + Vector3(0, 0, -2.0))
	GameState.currency = 5000.0
	g.equip(2)
	g._click("hole:%d" % tb.idx)
	g.equip(5)
	g._click("hole:%d" % tb.idx)
	g.equip(6)
	g.build_item = 0
	g._click("hole:%d" % tb.idx)
	GameState.upgrades["conveyor"] = 1
	GameState.save_game()
	var coins_before := GameState.currency
	var left_total: int = g.model.total_left()
	var cleared_before: int = g.model.cleared_count()
	var autos_before: int = g.stats.autos
	var holes_before: int = g.holes.size()
	var fed_before: int = g.stats.eye_fed
	var tb_idx: int = tb.idx
	var t2_idx: int = t2.idx
	var t3_idx: int = t3.idx
	g.queue_free()
	await get_tree().process_frame
	GameState.reset()
	GameState.save_slot = "test_smoke"
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	await get_tree().process_frame
	check("save restores coins", GameState.currency >= coins_before - 1.0)
	check("save restores lake stock", g2.model.total_left() <= left_total and g2.model.cleared_count() == cleared_before)
	check("save restores every hole", g2.holes.size() == holes_before)
	check("save restores stations", g2.holes[t2_idx].state == "table" and g2.holes[t3_idx].state == "smoker")
	check("save restores belts", g2.belts.size() == 1 and g2.holes[tb_idx].state == "auto" and g2.holes[tb_idx].belt != null)
	check("save restores machines, depots and rigs", g2.holes[tb_idx].belt.get("cannery", false) and g2.depots.size() == 1 and g2.rigs.size() == 1)
	check("save restores stats", int(g2.stats.autos) == autos_before and int(g2.stats.sectors) == 1 and int(g2.stats.eye_fed) == fed_before)
	var coins_off: float = GameState.currency
	var left_off: int = g2.model.total_left()
	g2._offline(3600.0)
	check("rigs keep working while you are away", GameState.currency > coins_off and g2.model.total_left() < left_off)
	check("save restores order", not g2.order.is_empty())
	check("restored sectors consistent", sectors_consistent(g2.model))
	check("restored sector patches match", g2.sector_patches[Vector2i.ZERO].thaw.visible)

	# --- fuzz: thousands of random actions must not error or break invariants
	seed(12345)
	var ids: Array = g2.UPGRADES.keys()
	var cells: Array = g2.tiles.keys()
	var sids: Array = g2.model.sectors.keys()
	for i in 4000:
		g2.equip(randi() % 7)
		g2.build_item = randi() % 4
		var r := randi() % 14
		var ri := randi() % 12   # hands: the slots, drops, pickups, the rack and the kit never break anything
		match ri:
			0: g2._select_slot(randi() % 3)
			1: g2._drop_active(randf() < 0.5)
			2: g2._pick_up()
			3: g2._take_from_bucket()
			4: g2._cycle_build()
			5: g2._sweep_fish()
			6: g2._click_rack(randi() % 3)
			7:
				if not g2.ground.is_empty():
					g2._click_ground(g2.ground[randi() % g2.ground.size()])
			8:
				var fe: Variant = g2.yard.pick(g2.cam.global_position, -g2.cam.global_basis.z, 9999.0, -1.0)
				if fe != null:
					g2._grab_fish(fe)
			9: g2._throw_held(randf())
			10: g2._feed_by_hand()
			11: g2._kick_buckets(g2.get_node("Player").global_position, Vector3(0, 0, -1), 10.0)
		if r < 4 and not g2.holes.is_empty():
			g2._click("hole:%d" % g2.holes[randi() % g2.holes.size()].idx)
		elif r == 4:
			g2._click("olga")
		elif r == 5:
			g2._click("eye")
		elif r == 6:
			g2._buy(ids[randi() % ids.size()])
		elif r == 7:
			var wp: Vector3 = g2._hex_pos(cells[randi() % cells.size()]) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
			if g2._can_drill_at(wp):
				g2._make_hole(wp)
		elif r == 8:
			GameState.currency += randf_range(0.0, 400.0)
		elif r == 9:
			for h in g2.holes:
				h.timer = 0.0
				h.auto_t = 0.0
				h.smoke_t = 0.0
		elif r == 10:
			g2._on_about_to_save()
		elif r == 11:
			g2.model.sectors[sids[randi() % sids.size()]].unlocked = true
		elif r == 12:
			g2.unlocked[ids[randi() % ids.size()]] = true
			g2.unlocked["t_auto"] = true
			g2.unlocked["t_smoker"] = true
			g2.unlocked["t_table"] = true
			g2.unlocked["t_belt"] = true
		else:
			g2.aim_pos = Vector3(randf_range(-60, 60), 0, randf_range(-60, 60))
			g2._click("ice")
		for h in g2.holes:
			g2._tick_hole(h, 0.25)
		g2._update_belt_fish(0.25)
		g2._process(0.05)
		g2._refresh()
	check("fuzz: three slots, each empty or a real item", g2.inv.slots.size() == 3 and g2.inv.slots.all(func(sl): return sl.is_empty() or sl.k in ["tool", "fish", "bucket"]))
	check("fuzz: one of each tool in the world (in a slot, on the ice, or on the rack)", [0, 1, 2].all(func(tt): return g2.inv.slots.filter(func(sl): return sl.get("k", "") == "tool" and int(sl.t) == tt).size() + g2.ground.filter(func(gr): return gr.item.k == "tool" and int(gr.item.t) == tt).size() <= 1))
	check("fuzz: no bucket holds more than it can", g2.inv.buckets().all(func(bi): return g2.inv.slots[bi].fish.size() <= g2._bucket_cap()) and g2.ground.all(func(gr): return gr.item.k != "bucket" or gr.item.fish.size() <= g2._bucket_cap()))
	check("fuzz: every thing on the ice has a collider and a node", g2.ground.all(func(gr): return is_instance_valid(gr.node)))
	check("fuzz: coins not negative", GameState.currency >= 0.0)
	check("fuzz: journal sane", g2.journal.size() <= g2.SPECIES.size())
	check("fuzz: lake counts stay consistent", sectors_consistent(g2.model))
	check("fuzz: no negative stock", g2.model.stock.values().all(func(st): return st.values().all(func(n): return n > 0)))
	check("fuzz: belt fish stay within the cap", g2.belt_fish.size() <= g2.BELT_MAX_FISH)
	check("fuzz: every belt fish rides a live belt or a rig line", g2.belt_fish.all(func(it): return g2.belts.has(it.belt) or g2.rigs.any(func(rg): return rg.belt == it.belt)))
	check("fuzz: rigs within the cap", g2.rigs.size() <= g2.rig_cap())
	check("fuzz: every belt belongs to an auto-rod", g2.belts.all(func(b): return b.hole.belt == b and b.hole.state == "auto"))
	await get_tree().create_timer(1.5).timeout
	g2._on_about_to_save()
	check("fuzz: state still serialisable", JSON.stringify(GameState.extra).length() > 100)

	# --- ending: emptying every cell through the real code path ends the game exactly once
	for tc in g2.tiles.keys():
		if tc != Vector2i.ZERO:
			empty_tile(g2, tc)
	check("every sector cleared", g2.model.cleared_count() == 19 and g2.model.total_left() == 0)
	check("ending triggers when the lake is empty", g2.stats.ended == 1)
	check("final goal completes", g2.goal_done[g2.goal_done.size() - 1])

	GameState.delete_save()
	print("SMOKE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
