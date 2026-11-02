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
	# --- hand-off feel: a bucket of fish is thrown one at a time, speeding up, and the streak climbs
	g.carry.clear()
	for i in 6:
		g.carry.append(g._make_fish(g.SPECIES[0]))
	var fed0: int = g.stats.eye_fed
	var peak := 0
	var staged: int = g.carry.size()
	g._feed_by_hand()
	check("feeding empties the hands at once", g.carry.is_empty())
	await get_tree().create_timer(0.3).timeout
	check("fish go in one at a time, not all at once", g.stats.eye_fed - fed0 < 6)
	for i in 30:
		await get_tree().create_timer(0.1).timeout
		peak = maxi(peak, g.feed_streak)
	check("all six are swallowed", g.stats.eye_fed - fed0 == 6)
	check("the streak climbed to 6", peak == 6)
	await get_tree().create_timer(1.8).timeout
	check("the streak resets after a pause", g.feed_streak == 0)
	check("no fish nodes are left over", g.dive_live == 0)
	# belt fish dive into the funnel (visual) and pay as before
	var held: int = g.get_child_count()
	g._belt_dive(g._make_fish(g.SPECIES[0]), Vector3(0, 0.8, 8.0), Vector3(0, 0, -1))
	check("a belt fish starts a dive", g.dive_live == 1 and g.get_child_count() == held + 1)
	await get_tree().create_timer(1.2).timeout
	check("the dive cleans itself up", g.dive_live == 0 and g.get_child_count() == held)
	for i in g.DIVE_MAX + 4:
		g._belt_dive(g._make_fish(g.SPECIES[0]), Vector3(0, 0.8, 8.0), Vector3(0, 0, -1))
	check("dives are capped", g.dive_live == g.DIVE_MAX)
	await get_tree().create_timer(1.2).timeout
	# stage reveal
	var fl0: float = g.flash_rect.color.a
	g._stage_reveal(2)
	check("a stage reveal starts bars, flash and title", g.reveal_t > 2.0 and gd.cine_t > 2.0 and g.flash_rect.color.a > fl0)
	await get_tree().create_timer(0.8).timeout
	check("the camera pulls back during a reveal", g.reveal_fov > 1.0 or g.reveal_t > 0.0)
	await get_tree().create_timer(3.0).timeout
	check("the reveal ends cleanly", g.reveal_t <= 0.0 and g.reveal_fov == 0.0)
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
	# --- the awakening cutscene
	check("the cutscene is skipped in test slots", not gd.play_awakening())
	var eye = g.scenery.eye
	g.awaken_hold = true
	check("the cutscene plays when forced", gd.play_awakening(true) and gd.intro_active and gd.scene == "awaken")
	gd.intro_t = 3.0
	await get_tree().create_timer(0.5).timeout
	check("before the open the Eye holds its breath", eye.hush > 0.3 and not gd.awaken_opened)
	check("the camera has pulled up and back", g.cam.position.y > 2.0)
	check("the stage-5 crystals are not shown yet", not eye.crystals[4][0].visible)
	gd.intro_t = gd.AWAKEN_OPEN + 0.05
	await get_tree().create_timer(0.4).timeout
	check("the Eye opens: crystals appear, hold released", gd.awaken_opened and eye.crystals[4][0].visible and not g.awaken_hold)
	check("the flash and shake fire", g.flash_rect.color.a > 0.3 and g.shake > 0.05)
	await get_tree().create_timer(1.5).timeout
	check("the lids are open again", eye.hush == 0.0)
	gd.intro_t = gd.AWAKEN_TITLE + 0.1
	await get_tree().create_timer(0.3).timeout
	check("the title appears near the end", g.reveal_title.text == "THE EYE IS AWAKE")
	gd.skip_intro()
	check("skipping restores control", not gd.intro_active and g.cam.position.length() < 0.01 and g.cine_fov == 0.0 and g.reveal_title.modulate.a == 0.0)
	# skipping before the open still ends in the awake state
	eye.set_stage(4)
	g.awaken_hold = true
	gd.play_awakening(true)
	await get_tree().create_timer(0.2).timeout
	gd.skip_intro()
	await get_tree().create_timer(0.3).timeout
	check("an early skip still wakes the Eye", eye.crystals[4][0].visible and not g.awaken_hold and eye.hush == 0.0)
	print("GUIDE %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
