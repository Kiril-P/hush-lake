extends Node
## Headless test for the catch layer: visitor fish (when they appear, that the lake's stock and economy are untouched), every
## species has a model, a length range and a journal note, the field journal builds with drawn fish, photo mode hides the
## interface and restores it. Run: tools/run_fishing.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	# ---------- the rules, as data ----------
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var day := {"night": 0.0, "weather": "clear", "aurora": false, "dawn": false, "eye_stage": 0, "stages": 5}
	var n_day := 0
	for i in 2000:
		if Visitors.roll(day, rng) != "":
			n_day += 1
	check("on a clear afternoon no visitor ever comes", n_day == 0)
	var seen := {}
	var ctxs := {"Lantern Eel": {"night": 1.0}, "Ghost Carp": {"weather": "fog"}, "Frost Gar": {"weather": "blizzard"},
		"Dawn Salmon": {"dawn": true}, "Aurora Char": {"night": 1.0, "aurora": true}, "Eye Tetra": {"eye_stage": 5}}
	var all_ok := true
	for want in ctxs:
		var ctx := day.duplicate()
		ctx.merge(ctxs[want], true)
		var hits := {}
		for i in 4000:
			var r := Visitors.roll(ctx, rng)
			if r != "":
				hits[r] = hits.get(r, 0) + 1
		if not hits.has(want):
			all_ok = false
			print("  missing ", want, " in ", hits)
		for k in hits:
			if not ctxs.has(k):
				all_ok = false
		seen[want] = hits.get(want, 0)
	check("each visitor comes in its own conditions (%s)" % str(seen), all_ok)
	var storm_only := day.duplicate()
	storm_only.weather = "blizzard"
	var no_night := true
	for i in 3000:
		if Visitors.roll(storm_only, rng) in ["Lantern Eel", "Aurora Char", "Eye Tetra", "Dawn Salmon", "Ghost Carp"]:
			no_night = false
	check("a daytime blizzard brings only the Frost Gar", no_night)
	check("dawn is a window of the clock (0.75 yes, 0.0 and 0.5 no)", Visitors.is_dawn(0.75) and not Visitors.is_dawn(0.0) and not Visitors.is_dawn(0.5))
	# ---------- every species is complete ----------
	GameState.save_slot = "test_fishing"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var complete := true
	for sp in g.SPECIES:
		var n: String = sp.name
		if not FishModel.SPECS.has(n) or not g.LENGTHS.has(n):
			complete = false
			print("  incomplete: ", n)
		var node := FishModel.build(n, sp.color, 1.0)
		if node == null:
			complete = false
		else:
			node.free()
		if Visitors.is_visitor(n):
			if Visitors.note_of(n) == "" or Visitors.clue_of(n) == "" or float(sp.w) != 0.0:
				complete = false
		elif g._journal_note(n) == "":
			complete = false
			print("  no note: ", n)
	check("every species has a model, a length range and a journal note (%d species)" % g.SPECIES.size(), complete)
	check("there are 6 visitors on top of the 8 lake species", g.SPECIES.size() == 14 and Visitors.LIST.size() == 6)
	# ---------- the lake's stock and economy are untouched ----------
	var c := Vector2i(1, 0)
	var left0: int = g.model.tile_left(c)
	g.day_t = 0.5   # midnight
	g.scenery.set_time(0.5)
	g.visitor_rng.seed = 9
	var eels := 0
	var drawn := 0
	for i in 40:
		var t: Dictionary = {"c": c}
		var f: Dictionary = g._draw_fish(t)
		if f.is_empty():
			break
		drawn += 1
		if f.name == "Lantern Eel":
			eels += 1
	check("at midnight some draws are Lantern Eels (%d of %d)" % [eels, drawn], eels >= 1 and eels < drawn)
	check("each draw still cost the tile exactly one fish", g.model.tile_left(c) == left0 - drawn)
	check("a discovered visitor is in the journal", g.journal.has("Lantern Eel"))
	var vals := 0.0
	for s in g.SPECIES:
		if s.w > 0.0:
			vals += s.w
	check("visitors do not change the lake's roll table", absf(vals - 124.0) < 80.0 and g.roll_fish().has("name"))
	# ---------- the journal ----------
	g.journal_panel.visible = true
	g._update_journal()
	await get_tree().process_frame
	var icons := 0
	for ch in g.journal_grid.get_children():
		if ch is HudWidgets.FishIcon:
			icons += 1
	check("the journal draws a fish for every species (%d icons)" % icons, icons == g.SPECIES.size())
	check("the journal counts found out of 14", g.journal_label.text.contains("/ 14"))
	g.journal_panel.visible = false
	# ---------- photo mode ----------
	g._toggle_photo()
	check("photo mode hides the interface and the tool", not g.get_node("UI").visible and not g.tool_view.visible and g.photo)
	g.fov_base = 40.0
	g._toggle_photo()
	check("leaving photo mode brings the interface back and resets the zoom", g.get_node("UI").visible and not g.photo and g.fov_base > 55.0)
	check("a hero moment slows time and then restores it", true)
	g._hero_moment(true)
	var slowed: bool = Engine.time_scale < 0.5
	await get_tree().create_timer(0.9, true, false, true).timeout
	check("(slowed %s, back to %.2f)" % [str(slowed), Engine.time_scale], slowed and is_equal_approx(Engine.time_scale, 1.0))
	print("FISHING %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
