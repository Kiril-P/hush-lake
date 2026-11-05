extends Node
## Headless test for progression: the Ledger (lifetime goals that pay pearls once), the choice of the next lake at refreeze, the new
## modifiers, Overdrive Coils (a late coin sink), and the new perks. Run: tools/run_progress.sh

const LakeModel := preload("res://games/ice_fishing/lake_model.gd")

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	# ---------- the ledger as data ----------
	var sane := true
	for e in Ledger.LIST:
		if e.tiers.size() != e.pearls.size() or e.tiers.size() < 1:
			sane = false
		for i in range(1, e.tiers.size()):
			if e.tiers[i] <= e.tiers[i - 1]:
				sane = false
	check("%d ledger entries, tiers ascending, one pearl payout per tier (%d pearls in all)" % [Ledger.LIST.size(), Ledger.total_pearls()], sane and Ledger.total_pearls() >= 60)
	var vals := {"fed": 600.0, "caught": 0.0}
	var vf := func(k): return float(vals.get(k, 0.0))
	var pay := Ledger.claimable(vf, {})
	check("600 fish fed pays the first tier of The Long Feeding only", pay.size() == 1 and pay[0].id == "fed" and pay[0].tier == 1 and pay[0].pearls == 1)
	check("a claimed tier does not pay again", Ledger.claimable(vf, {"fed": 1}).is_empty())
	vals.fed = 30000.0
	var pay2 := Ledger.claimable(vf, {"fed": 1})
	check("a jump pays every tier passed (tiers 2 and 3: 2 + 4 pearls)", pay2.size() == 2 and pay2[0].pearls + pay2[1].pearls == 6)
	var rows := Ledger.rows(vf)
	check("rows give the next threshold and the bar's floor", rows[0].tier == 3 and rows[0].next == 100000.0 and rows[0].prev == 25000.0 and rows[1].next == 200.0)
	# ---------- in the game ----------
	GameState.save_slot = "test_progress"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var p0: int = g._meta_int("pearls")
	g.stats.eye_fed = 600
	g._refresh()
	check("feeding 600 fish pays 1 pearl from the ledger", g._meta_int("pearls") == p0 + 1 and GameState.meta.ledger.fed == 1)
	g._refresh()
	check("and only once", g._meta_int("pearls") == p0 + 1)
	g.stats.eye_fed = 700
	g.stats.caught = 40
	g.stats.tithe = 3
	g._bank_life()
	var life: Dictionary = GameState.meta.life
	check("banking a lake adds it to the lifetime record", life.fed == 700 and life.caught == 40 and life.tithe == 3)
	g.stats.eye_fed = 100
	check("lifetime = banked + the lake in progress (800 fed)", is_equal_approx(g.ledger_value("fed"), 800.0))
	g.ledger_panel.visible = true
	g._update_ledger()
	await get_tree().process_frame
	check("the ledger panel shows a bar per entry (%d rows)" % (g.ledger_panel.grid.get_child_count() / 4), g.ledger_panel.grid.get_child_count() == Ledger.LIST.size() * 4 and g.ledger_panel.title.text.contains("LEDGER"))
	g.ledger_panel.visible = false
	g.journal["Minnow"] = 1
	g.journal["Lantern Eel"] = 1
	check("species and visitors count over all lakes", g.ledger_value("species") >= 2 and g.ledger_value("visitors") >= 1)
	# ---------- choosing the next lake ----------
	GameState.meta.erase("offers")
	var offs: Array = g.lake_offers()
	var distinct := {}
	for o in offs:
		distinct[o] = true
	check("three different lake characters are offered (%s)" % str(offs), offs.size() == 3 and distinct.size() == 3 and offs.all(func(o): return LakeModel.MODS.has(o) and o != ""))
	check("the offer is stable until the lake is banked", g.lake_offers() == offs)
	g.stats.ended = 1
	g._toggle_refreeze()
	var ev := InputEventKey.new()
	ev.keycode = KEY_X
	ev.pressed = true
	var used: bool = g._refreeze_key(KEY_X)
	check("X picks the second offer", used and g.lake_pick() == 1)
	check("the refreeze card lists the three with the choice marked", g.refreeze_label.text.contains("Choose its character") and g.refreeze_label.text.contains("> "))
	g._bank_and_reset()
	check("banking starts the chosen lake next", String(GameState.meta.next_mod) == offs[1])
	check("the next lake rolls fresh offers", not GameState.meta.has("offers") or int(GameState.meta.get("offers_for", -1)) != g._meta_int("lakes"))
	# ---------- the new modifiers ----------
	var ln: Dictionary = LakeModel.MODS["longnight"]
	check("Long Night doubles visitors, Deep adds 60% fish", float(ln.visitors) == 2.0 and float(LakeModel.MODS["deep"].count) == 1.6)
	var m = LakeModel.new()
	m.generate(5, "deep")
	var m0 = LakeModel.new()
	m0.generate(5, "")
	check("a Deep lake really holds more fish (%d vs %d)" % [m.total_left(), m0.total_left()], m.total_left() > m0.total_left() * 1.4)
	# ---------- overdrive and perks ----------
	g.model.generate(7, "")
	check("Overdrive Coils is a shop upgrade with a stall and unlocks at Eye stage 3", g.UPGRADES.has("overdrive") and g.SceneryScript.SHOP_SPOTS.has("overdrive") and g.GOALS.any(func(x): return x.get("unlock", []).has("overdrive")))
	GameState.upgrades["overdrive"] = 0
	var t := {"c": Vector2i(1, 0)}
	var base_wait := 0.0
	for i in 200:
		base_wait += g._auto_wait(t)
	GameState.upgrades["overdrive"] = 5
	var fast_wait := 0.0
	for i in 200:
		fast_wait += g._auto_wait(t)
	check("five Overdrive levels halve an auto-rod's wait (x%.2f)" % (fast_wait / base_wait), fast_wait / base_wait < 0.58 and fast_wait / base_wait > 0.42 and is_equal_approx(g.overdrive_mult(), 2.0))
	GameState.upgrades["overdrive"] = 0
	GameState.meta["perks"] = {"coils": 2, "lantern": 2, "ears": 1}
	check("Lantern Lore raises the visitor multiplier by 25% a level", is_equal_approx(float(g.visitor_ctx().mult), 1.5))
	g._bank_and_reset()
	check("Spare Coils start the next lake with Overdrive 2", GameState.level("overdrive") == 2)
	check("seven perks are on the refreeze card", g.PERKS.size() == 7)
	print("PROGRESS %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
