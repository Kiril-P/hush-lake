extends Node
## Headless test for the machine spectacle: Overdrive coil auras (numbers per level, created, updated, removed), the Ice-Breaker's working
## effects (chunks while it has something to chew, rumble that fades with distance). Run: tools/run_fx.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	var prev := MachineFX.od_params(0)
	check("level 0: no coils, no sparks", not prev.visible and prev.sparks == 0)
	var mono := true
	for l in range(1, 6):
		var p := MachineFX.od_params(l)
		if not (p.visible and p.glow > prev.glow - 0.001 and p.spin >= prev.spin and p.sparks > prev.sparks - 1):
			mono = false
		prev = p
	check("every level glows, spins and sparks more than the last", mono and MachineFX.od_params(5).sparks == 20)
	check("levels past 5 or below 0 are clamped", MachineFX.od_params(99).sparks == 20 and not MachineFX.od_params(-3).visible)
	var near := MachineFX.rumble_for(3.0)
	var mid := MachineFX.rumble_for(25.0)
	var far := MachineFX.rumble_for(60.0)
	check("rumble: loud beside it, quieter at 25 m, silent beyond 45 m", near.vol_db > mid.vol_db and mid.vol_db > far.vol_db and far.shake == 0.0 and near.shake > mid.shake and near.shake <= 0.05)
	var m := Node3D.new()
	add_child(m)
	MachineFX.sync_overdrive(m, 2, 1.3)
	var a: Node3D = m.get_node_or_null("od_aura")
	check("an aura appears at level 2 with a ring and sparks", a != null and a.get_node_or_null("ring") != null and (a.get_node("sparks") as CPUParticles3D).amount == 8)
	MachineFX.sync_overdrive(m, 5, 1.3)
	check("the same aura is updated at level 5 (20 sparks, one aura)", (a.get_node("sparks") as CPUParticles3D).amount == 20 and m.get_children().filter(func(c): return c.name == "od_aura").size() == 1)
	var yaw0 := a.rotation.y
	MachineFX.spin(m, 0.5)
	check("it spins", a.rotation.y > yaw0)
	MachineFX.sync_overdrive(m, 0)
	check("level 0 removes it", m.get_node_or_null("od_aura") == null)
	# in the game
	GameState.save_slot = "test_fx"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.currency = 99999.0
	for id in g.model.sectors:
		g.model.sectors[id].unlocked = true
	g.unlocked["t_auto"] = true
	var h: Dictionary = g._make_hole(g._hex_pos(Vector2i(1, 0)) * 1.25)
	g._build_auto(h)
	g.stats.eye_fed = g.eye_stage_at(3) + 5
	g._build_rig(g._hex_pos(Vector2i(2, 1)) * 1.1, false)
	var rg: Dictionary = g.rigs[0]
	check("an Ice-Breaker has its chewing effect, silent until it works", rg.has("fx") and (rg.fx as CPUParticles3D).emitting == false)
	GameState.upgrades["overdrive"] = 0
	g._refresh()
	check("no Overdrive: no coils on the machines", h.node.get_node_or_null("od_aura") == null and rg.node.get_node_or_null("od_aura") == null)
	GameState.upgrades["overdrive"] = 3
	g._refresh()
	check("Overdrive 3: coils on the Auto-Rod and the Ice-Breaker", h.node.get_node_or_null("od_aura") != null and rg.node.get_node_or_null("od_aura") != null)
	GameState.upgrades["overdrive"] = 5
	g._refresh()
	check("Overdrive 5: the coils update in place", (h.node.get_node("od_aura/sparks") as CPUParticles3D).amount == 20)
	# the rig chews: effects switch on when there is something to take
	for i in 400:
		g._tick_rigs(0.05)
	check("a rig with fish in reach is chewing (chunks flying)", (rg.fx as CPUParticles3D).emitting)
	for c in g.model.stock.keys():
		g.model.stock[c] = {}
	rg.t = 0.0
	for i in 400:
		g._tick_rigs(0.05)
	check("with nothing left to chew the chunks stop", not (rg.fx as CPUParticles3D).emitting)
	# the review's ghost coil: picking up an Auto-Rod takes its aura with it
	GameState.upgrades["overdrive"] = 3
	g._refresh()
	check("the Auto-Rod wears a coil", h.node.get_node_or_null("od_aura") != null)
	g._pickup_auto(h)
	check("picking the rod up removes the coil (no ghost emitter on the empty hole)", h.node.get_node_or_null("od_aura") == null)
	# sparks only run near the viewer
	var m2 := Node3D.new()
	add_child(m2)
	MachineFX.sync_overdrive(m2, 3, 1.0)
	m2.global_position = Vector3(0, 0, 0)
	MachineFX.spin(m2, 0.1, Vector3(10, 0, 0))
	check("a machine near you has sparks", (m2.get_node("od_aura/sparks") as CPUParticles3D).emitting)
	MachineFX.spin(m2, 0.1, Vector3(500, 0, 0))
	check("a machine far from you has none", not (m2.get_node("od_aura/sparks") as CPUParticles3D).emitting)
	# ---- machine tiers ----
	check("tier speed: x1.0 / 1.3 / 1.6 and clamped", is_equal_approx(MachineFX.tier_speed(1), 1.0) and is_equal_approx(MachineFX.tier_speed(2), 1.3) and is_equal_approx(MachineFX.tier_speed(3), 1.6) and is_equal_approx(MachineFX.tier_speed(9), 1.6))
	check("costs: Auto-Rod 250 / 750, Ice-Breaker 4000 / 12000, nothing past tier 3", MachineFX.upgrade_cost("auto", 1) == 250 and MachineFX.upgrade_cost("auto", 2) == 750 and MachineFX.upgrade_cost("rig", 1) == 4000 and MachineFX.upgrade_cost("rig", 2) == 12000 and MachineFX.upgrade_cost("auto", 3) == -1)
	check("invested coins add up (rod at tier 3: 1000)", MachineFX.invested("auto", 3) == 1000 and MachineFX.invested("auto", 1) == 0)
	GameState.upgrades["overdrive"] = 0
	GameState.currency = 99999.0
	var h2: Dictionary = g._make_hole(g._hex_pos(Vector2i(-1, 1)) * 1.25)
	g._build_auto(h2)
	var plain := 0.0
	for i in 300:
		plain += g._auto_wait(h2)
	var c0: float = GameState.currency
	check("U on an Auto-Rod pays 250 and makes it tier 2", g.upgrade_machine(h2) and int(h2.tier) == 2 and is_equal_approx(GameState.currency, c0 - 250.0))
	var fast := 0.0
	for i in 300:
		fast += g._auto_wait(h2)
	check("tier 2 shortens its wait by ~23%% (x%.2f)" % (fast / plain), fast / plain < 0.82 and fast / plain > 0.72)
	check("tier 2 wears gold trim", h2.node.get_node_or_null("tier_trim") != null)
	check("tier 3 for 750, then it is done", g.upgrade_machine(h2) and int(h2.tier) == 3 and not g.upgrade_machine(h2) and int(h2.tier) == 3)
	check("tier 3 adds the lamp crown (4 studs, band, crown)", h2.node.get_node("tier_trim").get_child_count() == 6)
	check("the prompt names the next step or says it is done", g.machine_prompt_suffix("hole:%d" % h2.idx).contains("fully upgraded"))
	var h3: Dictionary = g._make_hole(g._hex_pos(Vector2i(0, 1)) * 1.25)
	g._build_auto(h3)
	check("the prompt offers tier 2 with its price", g.machine_prompt_suffix("hole:%d" % h3.idx).contains("tier 2 for 250"))
	GameState.currency = 100.0
	check("without the coins it refuses and keeps the tier", not g.upgrade_machine(h3) and int(h3.get("tier", 1)) == 1 and is_equal_approx(GameState.currency, 100.0))
	GameState.currency = 99999.0
	check("an Ice-Breaker upgrades for 4000", g.upgrade_machine(rg) and int(rg.tier) == 2 and rg.node.get_node_or_null("tier_trim") != null)
	var saved_dict_ok := true
	g._on_about_to_save()
	var ex: Dictionary = GameState.extra
	check("the save keeps tiers (rod tier 3, rig tier 2)", ex.holes.any(func(x): return x.get("tr", 1) == 3) and ex.rigs.any(func(x): return x.size() > 2 and x[2] == 2))
	var before := GameState.currency
	g._pickup_auto(h2)
	check("picking up a tier-3 rod refunds a share of the upgrades too (>= +600)", GameState.currency - before >= 600.0)
	# a rig that is moved keeps its tier
	g.stats["rig_tier"] = 1
	g._pick_up_rig(rg)
	check("a moved Ice-Breaker remembers its tier", int(g.stats.rig_tier) == 2)
	g._build_rig(g._hex_pos(Vector2i(2, 1)) * 1.1, true)
	check("and goes back down at tier 2, free", g.rigs.size() == 1 and int(g.rigs[0].get("tier", 1)) == 2 and g.rigs[0].node.get_node_or_null("tier_trim") != null)
	# round trip: a saved game comes back with its tiers
	var h4: Dictionary = g._make_hole(g._hex_pos(Vector2i(-1, 0)) * 1.25)
	g._build_auto(h4)
	g.upgrade_machine(h4)
	g.upgrade_machine(g.rigs[0])
	g._on_about_to_save()   # (save_game(false) does not rebuild the data: refresh it first or an older snapshot is written)
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var tiers := []
	for t in g2.holes:
		if t.state == "auto":
			tiers.append(int(t.get("tier", 1)))
	tiers.sort()
	check("a loaded game has the same Auto-Rod tiers (%s) and the rig at tier 3" % str(tiers), tiers == [1, 2] and g2.rigs.size() == 1 and int(g2.rigs[0].get("tier", 1)) == 3 and g2.rigs[0].node.get_node_or_null("tier_trim") != null)
	print("FX %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
