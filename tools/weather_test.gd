extends Node
## Headless test for the living lake: the weather state machine (data), how the scene wears it (snow layers, fog, gloom, stars, clouds,
## gulls, cracks), the camp that grows with the Eye, the small gameplay hooks (bites, rare fish), saving and the setting. Run: tools/run_weather.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	# ---------- the state machine, as data ----------
	var w := Weather.new(7)
	for i in 1800:   # 180 s at 10 Hz
		w.tick(0.1, 0.0)
	check("the first three minutes are always clear", w.cur == "clear" and w.vals.snow < 0.31)
	var seen := {}
	var legal := true
	var prev := w.cur
	var bounded := true
	for i in 36000:   # an hour
		w.tick(0.1, 0.0)
		seen[w.cur] = true
		if w.cur != prev:
			if not Weather.NEXT[prev].has(w.cur) and not (w.cur == "clear" and w.hold > 0):
				legal = false
			prev = w.cur
		for k in Weather.KEYS:
			if w.vals[k] < -0.001 or w.vals[k] > 13.0:
				bounded = false
	check("every transition is one the graph allows (storms build and fade)", legal)
	check("in an hour the weather moves through its kinds (%d of 5 seen)" % seen.size(), seen.size() >= 4)
	check("every blended number stays in range", bounded)
	var a := Weather.new(99)
	var b := Weather.new(99)
	for i in 6000:
		a.tick(0.1, 0.0)
		b.tick(0.1, 0.0)
	check("the same seed gives the same weather", a.cur == b.cur and absf(a.vals.snow - b.vals.snow) < 0.0001)
	# a forced storm blends in smoothly (no jumps bigger than the blend allows)
	var c := Weather.new(3)
	c.elapsed = 999.0
	c.force("blizzard")
	var last: float = c.vals.snow
	var max_step := 0.0
	for i in 400:
		c.tick(0.05, 0.0)
		max_step = maxf(max_step, absf(c.vals.snow - last))
		last = c.vals.snow
	check("a blizzard builds smoothly (largest step %.3f per 0.05 s) and arrives" % max_step, max_step < 0.12 and c.vals.snow > 1.95)
	check("a blizzard is colder, windier, greyer and bites sooner than a clear day", c.vals.wind > 0.95 and c.vals.gloom > 0.55 and c.vals.bite < 0.85 and c.temp_offset() < -5.0)
	var d := Weather.new(5)
	d.force("snowfall")
	d.enabled = false
	d.tick(0.1, 0.0)
	check("with weather switched off it is clear again", d.cur == "clear")
	# the aurora: decided once per night, only under a quiet sky, never by day
	var au := Weather.new(11)
	au.elapsed = 999.0
	var nights_with := 0
	for n in 40:
		for i in 10:
			au.tick(0.5, 0.0)   # a day goes by
		au.force("clear")
		au.tick(0.1, 0.9)
		if au.aurora_on():
			nights_with += 1
		au.tick(0.1, 0.0)
	check("an aurora shows on some nights but not all (%d of 40)" % nights_with, nights_with > 8 and nights_with < 36)
	au.force("blizzard")
	au.aurora = false
	au.aurora_decided = false
	au.tick(0.1, 0.0)
	au.tick(0.1, 0.9)
	check("no aurora under a storm", not au.aurora_on())
	au.aurora = true
	au.tick(0.1, 0.0)
	check("and it is gone by day", not au.aurora_on())
	var rm := Weather.new(2)
	rm.aurora = true
	check("an aurora night raises rare-fish odds by 40%", absf(rm.rare_mult() - 1.4) < 0.001)
	var rt := Weather.new(2)
	rt.force("snowfall")
	for i in 400:
		rt.tick(0.1, 0.0)
	var rt2 := Weather.new(1)
	rt2.from_dict(rt.to_dict())
	check("weather survives a save", rt2.cur == "snowfall" and absf(rt2.vals.snow - rt.vals.snow) < 0.01 and absf(rt2.hold - rt.hold) < 0.001)

	# ---------- the scene ----------
	GameState.save_slot = "test_weather"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var sc = g.scenery
	var lv = g.living
	check("the lake has weather, a living layer and a world chip", g.weather != null and lv != null and g.world_label.text != "")
	check("it starts clear, on a golden-hour afternoon", g.weather.cur == "clear" and g.day_phase(0.0) == "Golden hour")
	check("three snow layers: only the light one falls on a clear day", sc.snow_layers.size() == 3 and sc.snow_layers[0].emitting and not sc.snow_layers[1].emitting and not sc.snow_layers[2].emitting)
	var fog0: float = sc.env_ref.fog_density
	g.weather.elapsed = 999.0
	g.weather.force("blizzard")
	for i in 60:
		g.weather.tick(0.5, 0.0)
		lv.update(0.5, 0.0, g.get_node("Player").global_position)
		sc.set_time(g.day_t)
	check("a blizzard switches the storm snow layer on and leans it with the wind", sc.snow_layers[2].emitting and sc.snow_layers[2].gravity.x > 3.0)
	check("the fog thickens but never past the readable limit (%.4f)" % sc.env_ref.fog_density, sc.env_ref.fog_density > fog0 * 6.0 and sc.env_ref.fog_density <= LivingLake.FOG_MAX + 0.00001)
	check("the sky greys and the sun weakens", sc.gloom > 0.55 and g.sun_light.light_energy < 0.8)
	var clouds_up := 0
	for cl in lv.clouds:
		if cl.node.visible:
			clouds_up += 1
	check("clouds fill the sky in a storm (%d of %d)" % [clouds_up, lv.clouds.size()], clouds_up >= lv.clouds.size() - 2)
	check("gulls stay home in a storm", lv.bird_vis < 0.05)
	check("the world chip names the weather and warns about the view", g.world_text().contains("Blizzard") and g.world_text().contains("see far"))
	check("a blizzard makes bites come sooner (wait x %.2f)" % g.world_bite(), g.world_bite() < 0.85)
	g.weather.force("clear")
	for i in 80:
		g.weather.tick(0.5, 0.0)
		lv.update(0.5, 0.0, g.get_node("Player").global_position)
	sc.set_time(g.day_t)
	check("clear again: the storm layer stops, the fog thins, gulls return", not sc.snow_layers[2].emitting and sc.env_ref.fog_density < fog0 * 1.3 and lv.bird_vis > 0.9)
	var any_bird: bool = lv.birds.any(func(bd): return bd.node.visible)
	check("gulls are in the sky by day", any_bird)

	# night: stars, aurora, owls
	g.day_t = 0.5
	sc.set_time(0.5)
	for i in 20:
		g.weather.tick(0.5, 1.0)
		lv.update(0.5, 1.0, g.get_node("Player").global_position)
	check("stars come out at night", lv.star_mm[0].visible and lv.star_mat[0].albedo_color.a > 0.3)
	check("gulls go to sleep at night", lv.bird_vis < 0.05)
	g.weather.aurora = true
	for i in 12:
		lv.update(0.5, 1.0, g.get_node("Player").global_position)
	check("an aurora night brightens the curtains", sc.aurora_level > 0.7)
	check("...and the chip says rare fish stir", g.world_text().contains("rare fish stir"))
	g.day_t = 0.0
	sc.set_time(0.0)
	lv.update(0.1, 0.0, g.get_node("Player").global_position)
	check("by day there are no stars", not lv.star_mm[0].visible)
	g.weather.aurora = false

	# hooks
	g.day_t = 0.0
	check("golden hour: bites come a little sooner", absf(g.hour_bite() - 0.92) < 0.001)
	g.day_t = 0.4
	check("deep night: no hour bonus", g.hour_bite() == 1.0)
	g.day_t = 0.0
	g.weather.force("clear")
	for i in 80:
		g.weather.tick(0.5, 0.0)
	var luck_runs := 0
	g.weather.aurora = true
	var rare0 := 0
	var rare1 := 0
	seed(5)
	for i in 4000:
		if g.roll_fish().base >= 5.0:
			rare1 += 1
	g.weather.aurora = false
	seed(5)
	for i in 4000:
		if g.roll_fish().base >= 5.0:
			rare0 += 1
	check("aurora nights bring more rare fish (%d vs %d of 4000)" % [rare1, rare0], rare1 > rare0 * 1.2)
	check("temperature is colder at night", g.temperature() > -9 and (func(): g.scenery._night = 1.0; return g.temperature()).call() < -14)
	g.scenery._night = 0.0

	# cracks
	var cracks_seen := [0]
	lv.cracked.connect(func(_p, _n): cracks_seen[0] += 1)
	lv.crack_t = 0.01
	lv.update(0.05, 0.0, Vector3(-8, 1.7, 14))
	check("the ice cracks now and then: a line appears and the sound is announced", cracks_seen[0] == 1 and lv.cracks.any(func(cr): return cr.node.visible))
	for i in 60:
		lv.update(0.05, 0.0, Vector3(-8, 1.7, 14))
	check("...and it fades away again", not lv.cracks.any(func(cr): return cr.node.visible))
	var lim_ok := true
	for i in 40:
		lv.crack_t = 0.01
		lv.update(0.05, 0.0, Vector3(-80, 1.7, 5))
		for cr in lv.cracks:
			if cr.node.visible and Vector2(cr.node.position.x, cr.node.position.z).length() > sc.edge_at(cr.node.position.x, cr.node.position.z):
				lim_ok = false
	check("cracks stay on the ice", lim_ok)

	# camp
	check("no camp at the start", lv.camp_level == 0 and lv.camp.is_empty())
	g.stats.eye_fed = g.EYE_STAGES[0]
	g._refresh()
	check("stage 1: a campfire with a light and seats", lv.camp.has("fire") and lv.fire_light != null)
	g.stats.eye_fed = g.EYE_STAGES[1]
	g._refresh()
	check("stage 2: string lights", lv.camp.has("lights"))
	g.stats.eye_fed = g.EYE_STAGES[2]
	g._refresh()
	check("stage 3: a woodpile, a sled and a sleeping dog", lv.camp.has("yard") and lv.dog != null)
	g.stats.eye_fed = g.EYE_STAGES[3]
	g._refresh()
	check("stage 4: lantern posts", lv.camp.has("posts"))
	var n_camp: int = lv.camp.size()
	g._refresh()
	check("pieces are only added once", lv.camp.size() == n_camp)
	lv.update(0.1, 1.0, g.get_node("Player").global_position)
	check("the campfire flickers and burns brighter at night", lv.fire_light.light_energy > 1.0)
	check("the camp pieces are solid for fish and feet", g.scenery.obstacles.size() > 10)

	# stage 5: an awake Eye gives every quiet night an aurora
	g.stats.eye_fed = g.EYE_STAGES[4]
	g._refresh()
	check("with the Eye awake the aurora comes every quiet night", g.weather.always_aurora)
	var all_nights := 0
	g.weather.elapsed = 999.0
	for n in 12:
		g.weather.force("clear")
		g.weather.tick(0.1, 0.0)
		g.weather.tick(0.1, 0.9)
		if g.weather.aurora_on():
			all_nights += 1
	check("...12 of 12 nights (%d)" % all_nights, all_nights == 12)
	g.stats.eye_fed = g.EYE_STAGES[3]
	g._refresh()
	g.weather.always_aurora = false

	# the review's findings: nothing overlaps, nothing flies in from the Eye, an aurora is decided once per night
	var rack_o := Vector2(g.rack_pos.x, g.rack_pos.z)
	var yard_p: Vector3 = lv.camp.yard.position
	check("the sled and woodpile stand clear of the tool rack (%.1f m)" % Vector2(yard_p.x, yard_p.z).distance_to(rack_o), Vector2(yard_p.x, yard_p.z).distance_to(rack_o) > 8.0)
	var fire_p: Vector3 = lv.camp.fire.position
	check("...and the campfire is clear of the rack and the yard", Vector2(fire_p.x, fire_p.z).distance_to(rack_o) > 8.0 and Vector2(fire_p.x, fire_p.z).distance_to(Vector2(yard_p.x, yard_p.z)) > 4.0)
	check("the string lights and posts are not scaled around the origin (no fly-in)", lv.camp.lights.scale == Vector3.ONE and lv.camp.posts.scale == Vector3.ONE)
	var night_w := Weather.new(21)
	night_w.elapsed = 999.0
	night_w.force("clear")
	night_w.tick(0.1, 0.0)
	night_w.tick(0.1, 0.9)
	var was_on := night_w.aurora_on()
	var dec_key := night_w.to_dict()
	var reroll := 0
	for i in 20:
		var nw2 := Weather.new(100 + i)
		nw2.from_dict(dec_key)
		nw2.tick(0.1, 0.9)
		if nw2.aurora_on() != was_on:
			reroll += 1
	check("reloading in the middle of a night does not re-roll its aurora", reroll == 0)
	var sw := Weather.new(5)
	sw.elapsed = 999.0
	sw.force("clear")
	sw.tick(0.1, 0.0)
	sw.tick(0.1, 0.9)
	sw.aurora = true
	sw.force("blizzard")
	check("a storm that rolls in puts the aurora (and its rare bonus) out", not sw.aurora_on() and sw.rare_mult() < 1.4 * 1.0 + 0.01 and absf(sw.rare_mult() - sw.vals.rare) < 0.001)
	var crack_ok := true
	for i in 60:
		lv.crack_t = 0.01
		lv.update(0.05, 0.0, Vector3(randf_range(-30, 30), 1.7, randf_range(-30, 30)))
		for cr in lv.cracks:
			if cr.node.visible:
				var cp: Vector3 = cr.node.position
				if Vector2(cp.x, cp.z).length() < 20.0:
					crack_ok = false
				for o in g.scenery.obstacles:
					if Vector2(cp.x, cp.z).distance_to(Vector2(o.x, o.y)) < o.z + 8.0:
						crack_ok = false
	check("cracks stay off the Eye, stalls and machines", crack_ok)
	g.day_t = 0.0
	var offline_a: float = g.bite_mult_base()
	g.weather.force("blizzard")
	for i in 60:
		g.weather.tick(0.5, 0.0)
	check("offline pacing ignores the weather (base %.3f) while live bites follow it (%.3f)" % [offline_a, g.bite_mult()], absf(g.bite_mult_base() - offline_a) < 0.0001 and g.bite_mult() < offline_a * 0.9)
	g.weather.force("clear")
	for i in 60:
		g.weather.tick(0.5, 0.0)

	# save and restore
	g.weather.force("snowfall")
	for i in 40:
		g.weather.tick(0.5, 0.0)
	g._on_about_to_save()
	var sv: Dictionary = GameState.extra
	check("the weather is saved", sv.has("weather") and sv.weather.cur == "snowfall")
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	check("a loaded game is in the same weather", g2.weather.cur == "snowfall" and g2.weather.vals.snow > 1.1 and g2.living.camp_level >= 4)

	# the setting
	GameSettings.set_value("weather", 0.0)
	g2.weather.elapsed = 999.0
	g2.weather.force("blizzard")
	g2._animate(0.1)
	check("with Weather switched off the sky clears at once", g2.weather.cur == "clear")
	GameSettings.set_value("weather", 1.0)

	# three days with random weather: nothing errors, particles stay few
	var gdn = g2
	gdn.weather.elapsed = 999.0
	gdn.weather.hold = 1.0
	var max_nodes := 0
	for i in 2400:   # 3 days at 3x speed
		gdn.day_t = fmod(gdn.day_t + 0.0015, 1.0)
		gdn.scenery.set_time(gdn.day_t)
		gdn.weather.tick(0.25, gdn.scenery._night)
		gdn.living.update(0.25, gdn.scenery._night, Vector3(randf_range(-60, 60), 1.7, randf_range(-60, 60)))
		max_nodes = maxi(max_nodes, gdn.get_child_count())
	check("three simulated days run clean; the scene does not grow (%d nodes)" % max_nodes, max_nodes < 600 and gdn.scenery.snow_layers.size() == 3)
	GameState.delete_save()
	print("WEATHER %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
