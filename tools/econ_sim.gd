extends Node
## Headless economy simulation. A rational "active player" plays the real game rules with simulated time:
## it fishes by hand, buys whatever pays back fastest, builds auto-rods + belts and rigs, and moves outward as sectors clear.
## Uses the real model, prices, multipliers and stock; only the clock and walking are modelled.
## Run: tools/run_econ.sh   (env ECON_SEED, ECON_ACTIVE for the share of time you are actually fishing, default 1.0)

const COMBO_AVG := 1.8        # an active player keeps the combo alive: average x1.8 on hand-caught fish
const BELT_COST := 32.0       # a belt of ~25 m
const FIGHT_T := 0.85
const MAX_T := 8.0 * 3600.0

var g
var t := 0.0
var autos := 0               # auto-rods on belts
var cans := 0                # cannery machines on belts
var rigs := 0
var manual_acc := 0.0
var auto_acc := 0.0
var rig_acc := 0.0
var active := 1.0
var log_lines: Array = []
var milestones := {}
var last_buy_t := 0.0
var max_gap := 0.0
var gap_at := ""
var avg_e := 3.0

func _ready() -> void:
	seed(int(OS.get_environment("ECON_SEED")) if OS.get_environment("ECON_SEED") != "" else 7)
	active = float(OS.get_environment("ECON_ACTIVE")) if OS.get_environment("ECON_ACTIVE") != "" else 1.0
	GameState.save_slot = "test_econ"
	GameState.delete_save()
	GameState.reset()
	if OS.get_environment("ECON_LAKES") != "":
		GameState.meta = {"lakes": int(OS.get_environment("ECON_LAKES"))}   # simulate a later lake
	g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	for id in g.UPGRADES:
		g.unlocked[id] = true   # assume the goals that unlock them are done early
	run()
	get_tree().quit()

func stamp() -> String:
	return "%02d:%02d" % [int(t / 60.0), int(t) % 60]

func mark(key: String) -> void:
	if not milestones.has(key):
		milestones[key] = t

# ---------- rates ----------
func unlocked_cells() -> Array:
	var out := []
	for c in g.model.stock:
		var sid: Vector2i = g.model.tile_sector[c]
		if g.model.sectors[sid].unlocked and g.model.tile_left(c) > 0:
			out.append(c)
	return out

func nearest_cell(cells: Array) -> Vector2i:
	var best: Vector2i = cells[0]
	var bd := 1e9
	for c in cells:
		var d: float = g._hex_pos(c).length()
		if d < bd:
			bd = d
			best = c
	return best

func avg_value() -> float:
	var tot := 0.0
	var n := 0.0
	for c in unlocked_cells():
		for sp in g.model.stock[c]:
			tot += g.model.stock[c][sp] * g._species(sp).value
			n += g.model.stock[c][sp]
	return tot / maxf(n, 1.0)

var wf_cache := 1.0

func refresh_cache() -> void:
	var cells := unlocked_cells()
	wf_cache = g.model.wait_factor(nearest_cell(cells)) if not cells.is_empty() else 1.0
	avg_e = avg_value()

func wf_here() -> float:
	return wf_cache

func manual_fish_rate() -> float:
	var wf := wf_here()
	var catch_t: float = 0.3 + 3.5 * float(g.bite_mult()) * wf + 0.5 + FIGHT_T
	var cap: int = g.capacity()
	var ln: int = g.lines()
	var catches := ceili(float(cap) / ln)
	var walk: float = (6.0 + 1.6 * GameState.level("boots")) * g.RIDE_SPEED[mini(GameState.level("snowmobile"), 3)]
	var trip_t: float = 2.0 * 9.0 / walk + 0.9 + float(g.drill_time()) * 0.5
	var fish: float = mini(cap, catches * ln)
	return active * fish / (catches * catch_t + trip_t)

func auto_fish_rate() -> float:
	return autos / ((g.AUTO_WAIT[0] + g.AUTO_WAIT[1]) * 0.5 * g.bite_mult() * wf_here())

func rig_fish_rate() -> float:
	return rigs / ((g.RIG_INTERVAL * wf_here() * 0.6 + 0.6))

func belt_mult() -> float:
	return g._belt_mult()

func income() -> float:
	var e: float = avg_e * g.sale_mult()
	var hand: float = manual_fish_rate() * e * COMBO_AVG * g.EYE_MULT
	var can_share := float(mini(cans, autos)) / maxf(float(autos), 1.0)
	var auto_mult: float = belt_mult() * (1.0 + (g.CANNERY_MULT - 1.0) * can_share)
	var belts: float = (auto_fish_rate() + rig_fish_rate()) * e * auto_mult
	return hand + belts

# ---------- the simulated second ----------
## A sensible player works one sector until it is empty (the clear bonus and the next ring are the reward).
func focus_cell(cells: Array) -> Vector2i:
	var best_sid: Vector2i = g.model.tile_sector[cells[0]]
	var best_left := 1 << 30
	for c in cells:
		var sid: Vector2i = g.model.tile_sector[c]
		var left: int = g.model.sectors[sid].left
		if left > 0 and left < best_left:
			best_left = left
			best_sid = sid
	var in_sector := []
	for c in cells:
		if g.model.tile_sector[c] == best_sid:
			in_sector.append(c)
	return in_sector[randi() % in_sector.size()]

func draw_fish(cells_pick_nearest: bool) -> Dictionary:
	var cells := unlocked_cells()
	if cells.is_empty():
		return {}
	var c: Vector2i = focus_cell(cells)
	var sp: String = g.model.draw(c)
	if sp == "":
		return {}
	var sid: Vector2i = g.model.tile_sector[c]
	if g.model.refresh_sector(sid):
		g.stats.sectors = g.model.cleared_count()
		GameState.add(g.SECTOR_REWARD[g.model.sectors[sid].ring])
		log_lines.append("%s  SECTOR CLEARED %s (%d/%d)" % [stamp(), g.model.sectors[sid].name, g.stats.sectors, g.model.sectors.size()])
		mark("sector%d" % g.stats.sectors)
	return g._make_fish(g._species(sp))

func feed(f: Dictionary, mult: float, combo: float) -> void:
	var worth: float = f.base * combo * g.sale_mult() * mult
	g.stats.eye_fed += 1
	g.stats.earned += worth
	GameState.add(worth)
	var st: int = g.eye_stage()
	if st > 0:
		mark("eye%d" % st)

func step() -> void:
	manual_acc += manual_fish_rate()
	while manual_acc >= 1.0:
		manual_acc -= 1.0
		var f := draw_fish(true)
		if f.is_empty():
			break
		g.stats.caught += 1
		feed(f, g.EYE_MULT, COMBO_AVG)
	auto_acc += auto_fish_rate()
	while auto_acc >= 1.0:
		auto_acc -= 1.0
		var f2 := draw_fish(false)
		if f2.is_empty():
			break
		var can_share := float(mini(cans, autos)) / maxf(float(autos), 1.0)
		feed(f2, belt_mult() * (1.0 + (g.CANNERY_MULT - 1.0) * can_share), 1.0)
	rig_acc += rig_fish_rate()
	while rig_acc >= 1.0:
		rig_acc -= 1.0
		var f3 := draw_fish(false)
		if f3.is_empty():
			break
		var can_share := float(mini(cans, autos)) / maxf(float(autos), 1.0)
		feed(f3, belt_mult() * (1.0 + (g.CANNERY_MULT - 1.0) * can_share), 1.0)

# ---------- shopping ----------
func candidates() -> Array:
	var out := []
	for id in g.UPGRADES:
		var u: Dictionary = g.UPGRADES[id]
		if GameState.level(id) >= u.max or id in ["sonar", "wide", "drill"]:
			continue
		out.append({"k": id, "cost": GameState.cost(id, u.base, u.growth), "name": u.name})
	out.append({"k": "auto", "cost": ceil(g.AUTO_BASE * pow(g.AUTO_GROWTH, autos)) + BELT_COST, "name": "Auto-Rod + belt"})
	if autos > cans:
		out.append({"k": "can", "cost": ceil(120.0 * pow(1.9, cans)), "name": "Cannery"})
	if g.eye_stage() >= g.TITHE_MIN_STAGE:
		out.append({"k": "tithe", "cost": g.tithe_cost(), "name": "Tithe"})
	if rigs < g.rig_cap():
		out.append({"k": "rig", "cost": ceil(g.RIG_BASE * pow(g.RIG_GROWTH, rigs)), "name": "Ice-Breaker rig"})
	return out

func apply(k: String, dir: int) -> void:
	if k == "auto": autos += dir
	elif k == "can": cans += dir
	elif k == "rig": rigs += dir
	elif k == "tithe": g.stats.tithe += dir
	else: GameState.upgrades[k] = GameState.level(k) + dir

func shop() -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		var base := income()
		var best := {}
		var best_pb := 1e18
		for c in candidates():
			apply(c.k, 1)
			var gain := income() - base
			apply(c.k, -1)
			if gain <= 0.0001:
				continue
			var pb: float = c.cost / gain
			if pb < best_pb:
				best_pb = pb
				best = c
		if best.is_empty() or GameState.currency < best.cost:
			return
		GameState.currency -= best.cost
		apply(best.k, 1)
		var gap := t - last_buy_t
		if gap > max_gap and t > 60.0:
			max_gap = gap
			gap_at = stamp()
		last_buy_t = t
		log_lines.append("%s  buy %-18s cost %6d  payback %5ds  income %.2f/s  (autos %d rigs %d)" % [stamp(), best.name, int(best.cost), int(best_pb), income(), autos, rigs])

func snapshot() -> void:
	var left: int = g.model.total_left()
	log_lines.append("%s  -- coins %d | fed %d (stage %d) | sectors %d/%d | lake left %d | income %.1f/s (hand %.1f)" % [stamp(), GameState.currency, g.stats.eye_fed, g.eye_stage(), g.stats.sectors, g.model.sectors.size(), left, income(), manual_fish_rate() * avg_e * g.sale_mult() * COMBO_AVG * g.EYE_MULT])

func run() -> void:
	snapshot()
	while t < MAX_T:
		t += 1.0
		if int(t) % 5 == 0:
			refresh_cache()
		step()
		if int(t) % 5 == 0:
			g.stats.autos = autos
			g.stats.belts = autos
			g.stats.cans = cans
			g.stats.rigs = rigs
			g.stats.holes = autos + 4
			g.stats.tiles_cleared = g.stats.sectors * 7
			g._check_goals()   # goal rewards are part of the real income
		if int(t) % 3 == 0:
			shop()
		if int(t) % 300 == 0:
			snapshot()
		if g.model.total_left() == 0:
			mark("empty")
			break
	snapshot()
	for l in log_lines:
		print(l)
	print("")
	print("=== MILESTONES (active %.0f%%) ===" % (active * 100.0))
	for k in milestones:
		print("%-8s %s" % [k, "%02d:%02d" % [int(milestones[k] / 60.0), int(milestones[k]) % 60]])
	print("longest wait between purchases: %ds at %s" % [int(max_gap), gap_at])
	print("tithe level %d | rigs %d | autos %d | awakened %d | coins left %d" % [g.stats.tithe, rigs, autos, g.stats.awakened, int(GameState.currency)])
	print("lake emptied: %s" % ("yes at " + stamp() if milestones.has("empty") else "NO within 8h (left %d)" % g.model.total_left()))
