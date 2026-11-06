extends Node
## Headless test for the first five minutes (first_five.gd): each beat fires once, in order, one at a time; the recap lands at five minutes of
## hands-on play with a sensible next step; old saves do not replay them. Run: tools/run_first.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	# --- pure
	check("nothing is reached at the start", FirstFive.reached({}).is_empty())
	var f := {"holes": 1, "caught": 1, "eye_fed": 1, "bucket": true, "autos": 1, "belts": 1}
	check("everything is reached once all are true, in story order", FirstFive.reached(f) == ["hole", "catch", "feed", "bucket", "auto", "belt"])
	var shown := {}
	var order := []
	var t := 0.0
	for i in 40:
		t += 1.0
		var id := FirstFive.next_beat(f, shown, t)
		if id != "":
			shown[id] = t
			order.append(id)
			t = 0.0
	check("the beats come one at a time, in order, never twice (%s)" % str(order), order == ["hole", "catch", "feed", "bucket", "auto", "belt"])
	check("a beat waits for the gap", FirstFive.next_beat(f, {}, 1.0) == "" and FirstFive.next_beat(f, {}, 5.0) == "hole")
	check("every beat has a banner, a line and a sound", FirstFive.BEATS.all(func(b): return b.size() == 4 and String(b[1]) != "" and String(b[2]).begins_with("Olga:")))
	check("clock formats", FirstFive.clock(6.2) == "0:06" and FirstFive.clock(248.0) == "4:08")
	var n0 := FirstFive.next_step({"eye_fed": 0}, 0.0, 15.0, 6.0)
	var n1 := FirstFive.next_step({"eye_fed": 3}, 7.0, 15.0, 6.0)
	var n2 := FirstFive.next_step({"eye_fed": 3, "bucket": true}, 5.0, 15.0, 6.0)
	var n3 := FirstFive.next_step({"eye_fed": 3, "bucket": true}, 40.0, 15.0, 6.0)
	var n4 := FirstFive.next_step({"eye_fed": 3, "bucket": true, "autos": 1}, 40.0, 15.0, 6.0)
	var n5 := FirstFive.next_step({"eye_fed": 3, "bucket": true, "autos": 1, "belts": 1}, 40.0, 15.0, 6.0)
	check("the next step follows the state", n0.find("Eye") >= 0 and n1.find("Bucket") >= 0 and n2.find("Save 10 coins") >= 0 and n3.find("afford an Auto-Rod") >= 0 and n4.find("belt") >= 0 and n5.find("spur") >= 0)
	var r := FirstFive.recap({"caught": 31, "eye_fed": 32, "autos": 0, "bucket": true}, {"catch": 6.0, "feed": 9.0}, 104.0, 15.0, 6.0)
	check("the recap has the counts, the times and the next step", r.find("31 fish caught") >= 0 and r.find("0:06") >= 0 and r.find("0:09") >= 0 and r.find("Next:") >= 0)
	# --- in the game
	GameState.save_slot = "test_first"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g.title_active = false
	g.guide.intro_active = false
	g.stats.erase("firsts")
	g.stats.holes = 0
	g.stats.caught = 0
	g.stats.eye_fed = 0
	g.stats.autos = 0
	g.stats.belts = 0
	g.stats["fa_clock"] = 0.0
	g.firsts_gap = 99.0
	for i in 20:
		g._update_firsts(0.25)
	check("a new game fires no beat with nothing done", g.stats.get("firsts", {}).is_empty())
	g.stats.holes = 1
	g._update_firsts(0.1)
	check("drilling the first hole fires its banner and Olga's line", g.stats.firsts.has("hole") and g.banner_label.text == "FIRST HOLE" and g.msg_label.text.begins_with("Olga:"))
	g.stats.caught = 1
	g.stats.eye_fed = 1
	g._update_firsts(0.5)
	check("a second beat waits its turn", not g.stats.firsts.has("catch"))
	for i in 40:
		g._update_firsts(0.25)
	check("then the catch beat, then the feed beat", g.stats.firsts.has("catch") and g.stats.firsts.has("feed"))
	var n: int = g.stats.firsts.size()
	for i in 80:
		g._update_firsts(0.25)
	check("nothing fires twice", g.stats.firsts.size() == n)
	# the recap at five minutes of hands-on play
	check("no recap yet", not g.stats.get("recap_done", false))
	g.stats["fa_clock"] = 299.0
	g._update_firsts(2.0)
	check("the recap appears at five minutes with a next step", g.stats.get("recap_done", false) and g.banner_label.text == "FIVE MINUTES ON THE ICE" and g.msg_label.text.find("Next:") >= 0)
	g.banner_label.text = ""
	g._update_firsts(10.0)
	check("and only once", g.banner_label.text == "")
	# the clock waits through the opening
	g.guide.intro_active = true
	var c0: float = g.stats.fa_clock
	g._update_firsts(5.0)
	check("the first-five clock does not run during the opening", g.stats.fa_clock == c0)
	g.guide.intro_active = false
	# a returning save: nothing replays
	GameState.currency = 500.0
	g.stats["caught"] = 40
	g.stats["eye_fed"] = 40
	g.stats["holes"] = 4
	g.stats.erase("firsts")
	g.stats.erase("recap_done")
	g.stats["fa_clock"] = 0.0
	g.banner_label.text = ""
	for i in 40:
		g._update_firsts(0.5)
	check("an old save does not replay the celebrations", g.banner_label.text == "" and g.stats.get("recap_done", false))
	# saved and loaded
	g.stats["firsts"] = {"hole": 2.0, "catch": 6.0}
	g._on_about_to_save()
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("the beats you have seen are saved and loaded", g2.stats.get("firsts", {}).has("catch") and float(g2.stats.firsts.catch) == 6.0)
	print("FIRST %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
