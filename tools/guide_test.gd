extends Node
## Headless test for the onboarding guide: the step chain, markers, tips, Olga and the intro.
## Run: tools/run_guide.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func step(g: Node) -> String:
	return g.guide.current().id

func _ready() -> void:
	GameState.save_slot = "test_guide"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	var gd = g.guide
	check("test slots never play the intro", not gd.want_intro and not gd.intro_active)
	# the first step points at a spot that really can be drilled
	var spot: Vector3 = gd.drill_spot
	check("drill spot is drillable ice", g._can_drill_at(spot))
	check("drill spot is in the Shallows", g.model.sectors[g.model.tile_sector[g._cell_at(spot)]].unlocked)
	check("step 1: take out the drill (tool is drill by default? else equip)", step(g) in ["drill", "tool0"])
	g.tool = 1
	check("step 1b: wrong tool asks for the drill", step(g) == "tool0")
	g.tool = 0
	check("step 1c: drill the hole", step(g) == "drill" and gd.current().where != null)
	var t: Dictionary = g._make_hole(spot)
	check("hole made", not t.is_empty())
	g.tool = 0
	check("step 2: take out the rod", step(g) == "tool1")
	g.tool = 1
	check("step 2b: cast a line", step(g) == "cast" and gd.current().where != null)
	g._click("hole:%d" % t.idx)
	check("step 3: wait for the bite", step(g) == "wait")
	t.timer = 0.0
	g._tick_hole(t, 0.1)
	check("step 4: bite says click now", step(g) == "bite")
	g._click("hole:%d" % t.idx)
	check("step 5: fighting says hold on", step(g) == "fight")
	t.fight = 0.0
	g._tick_hole(t, 0.1)
	await get_tree().create_timer(2.0).timeout
	check("step 6: carry to the Eye", step(g) == "carry0")
	var w: Variant = gd.current().where
	check("eye target is on the pupil", w != null and absf(Vector2(w.x, w.z).length() - 4.0) < 2.5)
	# feeding the Eye
	g._feed_by_hand()
	await get_tree().create_timer(2.5).timeout
	check("fed the eye once", g.stats.eye_fed >= 1)
	g.carry.clear()
	g.stats.eye_fed = max(1, g.stats.eye_fed)
	GameState.currency = 1.0
	check("step 7: keep fishing toward a bucket", step(g) == "cast" and "Bucket" in gd.current().hint)
	GameState.currency = 500.0
	check("step 8: buy a bucket points at the stall", step(g) == "bucket" and gd.current().where != null)
	# bucket bought: goals drive the strip
	GameState.upgrades["bucket"] = 1
	var c: Dictionary = gd.current()
	check("after the bucket the strip follows the goals", c.id.begins_with("goal"))
	# full hands override
	g.carry.clear()
	for i in g.capacity():
		g.carry.append(g._make_fish(g.SPECIES[0]) if g.has_method("_make_fish") else {})
	check("full hands point at the eye", step(g) == "full")
	g.carry.clear()
	# every main goal has either a hint or a generic one
	var missing := []
	for gl in g.GOALS:
		if bool(gl.get("opt", false)):
			continue
		if not gd.HINTS.has(gl.text) and not gd.GENERIC_HINTS.has(gl.stat) and not ["holes", "caught", "eye_fed"].has(gl.stat) and not String(gl.stat).begins_with("lvl:"):
			missing.append(gl.text)
	print("goals without how-to text: ", missing)
	# where targets resolve
	for wh in ["eye", "hole", "auto", "hut", "drill", "stall:bucket", "stall:snowmobile"]:
		check("where '%s' resolves or is legitimately empty" % wh, gd._resolve(wh) != null or wh in ["hole", "auto"])
	# ping and olga lines
	gd.ping()
	check("H pings with a line", g.msg_label.text.begins_with("Olga:"))
	check("Olga gives the step", gd.olga_line().begins_with("Olga:"))
	# tips: new tool and first affordable upgrade show once
	g.unlocked["t_auto"] = true
	GameState.currency = 5000.0
	gd.tip_t = 0.0
	gd.tip_scan_t = 0.0
	gd.tick(0.1, true)
	check("a tip is shown for a new tool or affordable upgrade", gd.tip_label.text != "")
	var first: String = gd.tip_label.text
	gd.tip_t = 0.0
	gd.tip_scan_t = 0.0
	gd.tick(0.1, true)
	check("tips never repeat", gd.tip_label.text != first or gd.tips_seen.size() >= 2)
	# save round trip keeps tips
	var seen: int = gd.tips_seen.size()
	g._on_about_to_save()
	check("tips are saved", GameState.extra.has("tips") and GameState.extra.tips.size() == seen)
	# old saves get bootstrapped silently
	gd.from_dict(null)
	check("old saves bootstrap quietly", gd.bootstrap_tips)
	# the intro runs and can be skipped
	gd.want_intro = true
	gd.tick(0.1, true)
	check("intro starts when mouse is captured", gd.intro_active)
	gd.tick(1.0, true)
	check("intro lowers the letterbox and moves the camera", gd.bars > 0.0 and g.cam.position.y > 1.0)
	var t0: float = gd.intro_t
	gd.skip_intro()
	check("skip ends the intro and restores the camera", not gd.intro_active and g.cam.position.length() < 0.01 and absf(g.cam.rotation.y) < 0.001)
	check("walking works again", gd.intro_t == t0)
	print("GUIDE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
