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
	var keep_extra: Dictionary = GameState.extra.duplicate(true)   # (a deep copy now: the old game must not keep editing what was saved)
	var keep_meta: Dictionary = GameState.meta.duplicate(true)
	var keep_up: Dictionary = GameState.upgrades.duplicate(true)
	var keep_cur: float = GameState.currency
	g.process_mode = Node.PROCESS_MODE_DISABLED
	for tw in get_tree().get_processed_tweens():
		tw.kill()
	g.queue_free()
	await get_tree().process_frame
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
	var earned_b: float = g.stats.earned
	g = await reload(g, slot)
	check("a quit mid-throw: the fish are paid on load, once, at exactly their worth", g.stats.eye_fed == 3 and absf(g.stats.earned - earned_b - worth) < 0.01)
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
	g.order = {"type": "any", "need": 50, "have": 0, "reward": 99, "species": ""}
	g.quiet_notice = ""
	g._offline(3600.0)
	check("offline deliveries leave Olga's order alone (no burst of banners on load)", g.order.get("have", -1) == 0)
	check("the welcome-back line tells you the Eye woke while you were away", g.msg_label.text.contains("woke while you were away"))
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

	# --- fish in the air do not land while paused
	g.stats.eye_fed = 0
	g.carry.clear()
	for i in 2:
		g.carry.append(g._make_fish(g.SPECIES[0]))
	g._feed_by_hand()
	g.ever_captured = true
	await get_tree().create_timer(0.2).timeout
	var fed_p: int = g.stats.eye_fed
	await get_tree().create_timer(2.0).timeout
	check("paused: thrown fish hang in the air and nothing is paid", g.sim_paused and g.stats.eye_fed == fed_p and g.flying.size() > 0)
	g.ever_captured = false
	await get_tree().create_timer(2.5).timeout
	check("resumed: they land and pay", g.stats.eye_fed == fed_p + g.flying.size() + (2 - fed_p - g.flying.size()) and g.flying.is_empty() and g.stats.eye_fed == 2)

	# --- an order is credited by fish settled from a save
	g.order = {"type": "any", "need": 2, "have": 1, "reward": 7, "species": ""}
	var coins_o: float = GameState.currency
	g._settle_fish(g._make_fish(g.SPECIES[0]), g.EYE_MULT)
	check("a fish settled on load counts toward the open order", g.orders_done >= 1 or int(g.order.get("have", 0)) == 2 or GameState.currency >= coins_o + 7.0)

	# --- the last fish of a species still completes the order that asked for it
	for c in g.model.stock:
		g.model.stock[c].erase("Perch")
	g.order = {"type": "species", "species": "Perch", "need": 1, "have": 0, "reward": 5}
	var od_c: int = g.orders_done
	var pf: Dictionary = g._make_fish(g.SPECIES[1])
	g._settle_fish(pf, 1.0)
	check("the lake's last Perch delivered from outside still completes a Perch order", g.orders_done == od_c + 1)
	g.yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(-20, 0.05, 20), Vector3.ZERO)
	check("fish lying on the ice count as 'held' for orders", g._species_held("Perch") == 1)
	g.yard.clear_all()

	# --- fish delivered after the Eye wakes mid-batch are paid with the awakened bonus
	g.stats.awakened = 0
	g.stats.eye_fed = g.eye_stage_at(4) - 1
	g.eye_seen_stage = g.eye_stage()
	var f1: Dictionary = g._make_fish(g.SPECIES[1])
	var f2: Dictionary = g._make_fish(g.SPECIES[1])
	var sm0: float = g.sale_mult()
	var w1: float = g._settle_fish(f1, 1.0)
	var w2: float = g._settle_fish(f2, 1.0)
	check("the fish that wakes the Eye is paid at the old rate, the next one at the new rate", absf(w1 - f1.base * f1.mult * sm0) < 0.001 and w2 > w1 * (1.0 + g.AWAKEN_BONUS * 0.8 / sm0 * 1.0 - 0.001) - 0.001)

	# --- settings persist and apply
	g._set_setting("sens", 0.004)
	g._set_setting("fov", 90.0)
	g._set_setting("inv", 1.0)
	g = await reload(g, slot)
	check("settings survive a restart", absf(g.get_node("Player").sensitivity - 0.004) < 0.0001 and g.fov_base == 90.0 and g.get_node("Player").invert_y)

	# --- a belt fish in transit survives a save
	var tb: Dictionary = g._make_hole(g.guide.drill_spot + Vector3(0, 0, 5))
	g._build_auto(tb, false)
	g._build_belt(tb, false)
	g.belt_fish.clear()
	g._belt_push(tb.belt, g._make_fish(g.SPECIES[1]))
	g.stats.eye_fed = 0
	check("a fish is riding the belt", g.belt_fish.size() == 1)
	g = await reload(g, slot)
	check("a belt fish in transit is paid once on load", g.stats.eye_fed == 1 and g.belt_fish.is_empty())

	# --- N asks twice, F kicks
	g.test_capture = false
	var nev := InputEventKey.new()
	nev.keycode = KEY_N
	nev.pressed = true
	g.reset_armed_t = 0.0
	g._unhandled_input(nev)
	check("N once only warns", g.reset_armed_t > 0.0 and is_instance_valid(g) and not g.is_queued_for_deletion())
	g.test_capture = true
	var fev := InputEventKey.new()
	fev.keycode = KEY_F
	fev.pressed = true
	g._unhandled_input(fev)
	check("holding F charges a kick", g.kick_charge >= 0.0)
	fev = InputEventKey.new()
	fev.keycode = KEY_F
	fev.pressed = false
	g._unhandled_input(fev)
	check("letting go releases it", g.kick_charge < 0.0)

	# --- a save with more fish than the ice holds (or an old save) does not replay the Eye's reveal
	g.yard.clear_all()
	g.stats.eye_fed = g.eye_stage_at(0) + 1
	g.eye_seen_stage = g.eye_stage()
	for i in g.yard.MAX_LOOSE:
		g.yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-60 + (i % 10) * 1.3, 0.05, 60 + floorf(i / 10.0) * 1.3), Vector3.ZERO)
	var th: Dictionary = g.holes[0]
	g._end_cast(th)
	th.cast = 3
	th.hooked = [g._make_fish(g.SPECIES[1])]
	var fed_b: int = g.stats.eye_fed
	g.order = {"type": "any", "need": 2, "have": 1, "reward": 9, "species": ""}
	var od_b: int = g.orders_done
	g = await reload(g, slot)
	check("restoring 60 loose fish plus a hooked one: the ice holds 60, the extra is paid, no stage reveal", g.yard.count() == g.yard.MAX_LOOSE and g.stats.eye_fed == fed_b + 1 and g.reveal_t <= 0.0)
	check("...and the excess fish still counts toward the open order (orders come back first)", g.orders_done == od_b + 1)
	g.yard.clear_all()

	# --- a depot sled in flight is saved too
	g.carry.clear()
	g.carry.append(g._make_fish(g.SPECIES[0]))
	var dp: Vector3 = Vector3(-17.5, 0.0, 0.0)
	g._build_depot(dp, false)
	var fed_d: int = g.stats.eye_fed
	g._use_depot(g.depots[0])
	check("a sled run is tracked until it pays", g.flying.size() == 1)
	g = await reload(g, slot)
	check("a quit mid-sled: the fish is paid on load, once", g.stats.eye_fed == fed_d + 1 and g.flying.is_empty())

	# --- the click that resumes play does not also drill
	g.sim_paused = false
	g._on_pause_changed()
	check("resuming blocks the held button until it is released", g.hold_block)
	g._update_hold("", 0.01)
	check("...and lets go once it is up", not g.hold_block)

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
	check("with fish lying near the Eye the click tells you to push them", g.stats.tithe == tc)
	g.yard.clear_all()
	g.yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(45, 0.05, 0), Vector3.ZERO)
	g.tithe_armed_t = 0.0
	g._tithe()
	check("a fish far from the Eye (not headed in) does not block the tithe", g.tithe_armed_t > 0.0)
	g.tithe_armed_t = 0.0
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
	var ids := {}
	for r in g.rigs:
		ids[r.idx] = true
	check("rig ids stay unique after moving", ids.size() == g.rigs.size())

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
	var cur: Dictionary = g3.guide.current()
	check("a fished-out hole is not a place to cast: the strip says cast, at the other hole", cur.id == "cast" and absf(cur.where.z - far_h.pos.z) < 0.1)
	GameState.upgrades["bucket"] = 1
	g3.unlocked["t_auto"] = true
	g3.stats.autos = 0
	for gi in 5:
		g3.goal_done[gi] = true
	check("the unlocked Auto-Rod comes before emptying a patch", g3.guide.current().id.begins_with("goal") and "Auto-Rod" in g3.guide.current().title)
	g3.stats.autos = 1
	print("SAFETY %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
