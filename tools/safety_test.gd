extends Node
## Headless test for progress safety: nothing is lost on save, offline stages pay once, pause freezes the lake,
## tithes and resets need a second click, the guide points at the right hole, idle rigs can be moved.
## Run: tools/run_safety.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func fresh(slot: String):
	GameState.save_slot = slot
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	return g

func reload(g, slot: String):
	GameState.save_game()
	for tw in get_tree().get_processed_tweens():
		tw.kill()
	g.queue_free()
	await get_tree().process_frame
	var keep_extra: Dictionary = GameState.extra.duplicate(true)
	var keep_meta: Dictionary = GameState.meta.duplicate(true)
	var keep_up: Dictionary = GameState.upgrades.duplicate(true)
	var keep_cur: float = GameState.currency
	GameState.reset()
	GameState.save_slot = slot
	GameState.extra = keep_extra
	GameState.meta = keep_meta
	GameState.upgrades = keep_up
	GameState.currency = keep_cur
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	await get_tree().process_frame
	await get_tree().process_frame
	return g2

func _ready() -> void:
	var slot := "test_safety"
	var g = await fresh(slot)

	# --- a fish drawn from the lake is never lost on save/load
	var t: Dictionary = g._make_hole(g.guide.drill_spot)
	g.tool = 1
	g._click("hole:%d" % t.idx)
	t.timer = 0.0
	g._tick_hole(t, 0.1)
	g._click("hole:%d" % t.idx)
	check("mid-fight: a hooked fish is out of the lake", t.cast == 3 and t.hooked.size() == 1)
	var left0: int = g.model.total_left()
	g = await reload(g, slot)
	check("mid-fight save: the fish comes back as a fish on the ice", g.yard.count() == 1)
	check("mid-fight save: the lake stock is unchanged (no duplicate, no loss)", g.model.total_left() == left0)

	# --- hand-fed fish that have not landed yet are paid exactly once
	g.yard.clear_all()
	GameState.currency = 0.0
	g.stats.eye_fed = 0
	g.carry.clear()
	for i in 3:
		g.carry.append(g._make_fish(g.SPECIES[0]))
	var worth := 0.0
	for f in g.carry:
		worth += f.base * f.mult * g.sale_mult() * g.EYE_MULT
	g._feed_by_hand()
	check("thrown fish are tracked until they pay", g.flying.size() == 3 and g.carry.is_empty())
	g = await reload(g, slot)
	check("a quit mid-throw: the fish are paid on load, once", g.stats.eye_fed == 3 and GameState.currency >= worth - 0.5 and GameState.currency < worth + 400.0)
	check("and nothing is left over", g.flying.is_empty() and g.carry.is_empty())

	# --- offline: crossing the last stage pays the awakening exactly once
	var pearls0: int = int(GameState.meta.get("pearls", 0))
	g.stats.awakened = 0
	g._reward_stages_quietly(4, 5)
	check("stage 5 reached out of sight: +3 pearls and awakened", g.stats.awakened == 1 and int(GameState.meta.get("pearls", 0)) == pearls0 + g.AWAKEN_PEARLS)
	g._reward_stages_quietly(4, 5)
	check("...and never twice", int(GameState.meta.get("pearls", 0)) == pearls0 + g.AWAKEN_PEARLS)
	g.stats.awakened = 0
	g.stats.eye_fed = g.eye_stage_at(4) - 2
	g.eye_seen_stage = g.eye_stage()
	var rg_pos: Vector3 = g._hex_pos(Vector2i(1, 0)) + Vector3(0, 0, 3)
	g._build_rig(rg_pos, false)
	var pearls1: int = int(GameState.meta.get("pearls", 0))
	g._offline(3600.0)
	check("a rig feeding the Eye offline across stage 5 pays the awakening bonus", g.eye_stage() >= 5 and g.stats.awakened == 1 and int(GameState.meta.get("pearls", 0)) == pearls1 + g.AWAKEN_PEARLS)

	# --- pause freezes the lake
	var t2: Dictionary = g.holes[0]
	g.tool = 1
	g._end_cast(t2)
	t2.cast = 2
	t2.timer = 1.0
	g.ever_captured = true
	var t_before: float = t2.timer
	await get_tree().create_timer(0.5).timeout
	check("Esc: the game is paused", g.sim_paused)
	check("paused: a bite window does not tick down", t2.cast == 2 and absf(t2.timer - t_before) < 0.001)
	var combo_t0 := 5.0
	g.combo_t = combo_t0
	await get_tree().create_timer(0.3).timeout
	check("paused: the combo timer holds", absf(g.combo_t - combo_t0) < 0.001)
	g.ever_captured = false
	await get_tree().create_timer(0.4).timeout
	check("resumed: timers run again", not g.sim_paused and t2.timer < t_before - 0.1)
	g._end_cast(t2)

	# --- tithe and reset need confirming
	g.yard.clear_all()
	g.stats.eye_fed = g.eye_stage_at(1)
	GameState.currency = 99999.0
	g.stats.tithe = 0
	g._tithe()
	check("a first click on the Eye with empty hands only arms the tithe", g.stats.tithe == 0 and GameState.currency == 99999.0 and g.tithe_armed_t > 0.0)
	g._tithe()
	check("a second click inside the window pays it", g.stats.tithe == 1 and GameState.currency < 99999.0)
	g.tithe_armed_t = 0.0
	g._tithe()
	await get_tree().create_timer(2.2).timeout
	check("the arming window expires", g.tithe_armed_t == 0.0)
	var tc: int = g.stats.tithe
	g._tithe()
	g.yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-10, 0.05, 15), Vector3.ZERO)
	g._tithe()
	check("with fish lying around the click tells you to push them", g.stats.tithe == tc)
	g.yard.clear_all()

	# --- an idle ice-breaker can be lifted and re-placed for free
	g.stats.rigs = 1
	for r in g.rigs.duplicate():
		g._pick_up_rig(r)
	g.stats.rig_moves = 0
	var far_p := Vector3(0, 0, 80)   # a spot with no unlocked fish nearby: the rig is idle
	g._build_rig(far_p, false)
	var rg: Dictionary = g.rigs[g.rigs.size() - 1]
	check("a rig with nothing in reach is idle", g._rig_best(rg).x == 9999)
	check("the prompt offers to pick it up", g._prompt_for("rig:%d" % rg.idx).contains("pick it up"))
	var n_rigs: int = g.rigs.size()
	var obstacles0: int = g.scenery.obstacles.size()
	g._click("rig:%d" % rg.idx)
	check("clicking an idle rig lifts it", g.rigs.size() == n_rigs - 1 and g.scenery.obstacles.size() == obstacles0 - 1 and g.stats.rig_moves == 1)
	check("placing it again costs nothing", g._build_cost(3) == 0)
	var coins_b: float = GameState.currency
	var rigs_stat: int = g.stats.rigs
	g._build_rig(Vector3(30, 0, 30), true)
	check("it goes down free and does not count as a second purchase", GameState.currency == coins_b and g.stats.rigs == rigs_stat and g.stats.rig_moves == 0 and g.rigs.size() == n_rigs)
	check("rig ids stay unique after moving", g.rigs.map(func(x): return x.idx).size() == g.rigs.size())

	# --- guidance points at the right hole
	var g3 = await fresh("test_safety2")
	var near_h: Dictionary = g3._make_hole(g3.guide.drill_spot)
	var far_h: Dictionary = g3._make_hole(g3.guide.drill_spot + Vector3(0, 0, 9.0))
	g3.tool = 1
	g3.get_node("Player").position = Vector3(near_h.pos.x, g3.EYE_H, near_h.pos.z + 2.0)
	far_h.cast = 2
	var gw: Variant = g3.guide.current().where
	check("the bite marker is on the biting hole, not the nearest hole", g3.guide.current().id == "bite" and absf(gw.z - far_h.pos.z) < 0.1)
	far_h.cast = 0
	g3.model.stock[near_h.c] = {}
	g3.stats.holes = 2
	g3.stats.eye_fed = 0
	var s0: String = g3.guide.current().id
	check("a fished-out hole is not a place to cast", s0 != "cast" or absf(g3.guide.current().where.z - near_h.pos.z) > 0.1)
	GameState.upgrades["bucket"] = 1
	g3.unlocked["t_auto"] = true
	g3.stats.autos = 0
	check("the unlocked Auto-Rod comes before emptying a patch", g3.guide.current().id.begins_with("goal") and "Auto-Rod" in g3.guide.current().title)
	g3.stats.autos = 1
	print("SAFETY %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
