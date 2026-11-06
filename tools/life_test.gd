extends Node
## Headless test for the living shore: Juniper the dog (wakes, follows, sits, sniffs, barks, goes home) and the wildlife (who may be out,
## bounded numbers, kept off the ice, flee and leave). All headless: pure brains plus node poses. Run: tools/run_life.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func run_brain(b: Companion.Brain, secs: float, player: Vector3, vel := Vector3.ZERO, night := 0.0) -> void:
	var t := 0.0
	while t < secs:
		b.step(0.05, player, vel, night)
		t += 0.05

func _ready() -> void:
	# ---------- Juniper's brain ----------
	var home := Vector3(-20, 0, 10)
	var b := Companion.Brain.new(home)
	run_brain(b, 5.0, Vector3(40, 0, 40))
	check("she sleeps while you are far away", b.state == "sleep" and b.pos == home)
	run_brain(b, 0.5, home + Vector3(4, 0, 0))
	check("walking near is not enough on its own: she wakes after a beat", b.state == "sleep")
	run_brain(b, 1.0, home + Vector3(4, 0, 0))
	check("then she wakes with a woof", b.state in ["follow", "sit"] and b.bark_req)
	b.bark_req = false
	var pl := home + Vector3(30, 0, 0)
	run_brain(b, 6.0, pl, Vector3(5, 0, 0))
	check("walking away she trots after you and catches up (%.1f m behind)" % Vector2(pl.x - b.pos.x, pl.z - b.pos.z).length(), Vector2(pl.x - b.pos.x, pl.z - b.pos.z).length() < 6.0 and b.speed >= 0.0)
	var vel_frames := 0
	var maxsp := 0.0
	var b2 := Companion.Brain.new(home)
	b2.state = "follow"
	for i in 200:
		b2.step(0.05, home + Vector3(40, 0, 0), Vector3(6, 0, 0), 0.0)
		maxsp = maxf(maxsp, b2.speed)
	check("she never outruns her top speed (%.1f m/s)" % maxsp, maxsp <= Companion.Brain.MAX_SPEED + 0.01)
	run_brain(b, 6.0, b.pos + Vector3(1.0, 0, 1.0), Vector3.ZERO)
	check("when you stop she settles and sits", b.state == "sit")
	var at := b.pos + Vector3(5, 0, 2)
	b.notice(at, b.pos + Vector3(1, 0, 1))
	check("a fish landing nearby sends her to sniff it", b.state == "sniff")
	run_brain(b, 6.0, b.pos, Vector3.ZERO)
	check("she looks, then comes back to you", b.state in ["follow", "sit"])
	var b3 := Companion.Brain.new(home)
	b3.state = "sit"
	b3.pos = home + Vector3(10, 0, 0)
	b3.notice(home + Vector3(60, 0, 0), b3.pos)
	check("a far fish is ignored", b3.state == "sit")
	var b4 := Companion.Brain.new(home)
	b4.state = "follow"
	b4.pos = home + Vector3(5, 0, 0)
	run_brain(b4, 3.0, home + Vector3(200, 0, 0), Vector3.ZERO)
	check("lose sight of you (200 m) and she goes home to sleep", b4.state in ["home", "sleep"])
	run_brain(b4, 20.0, home + Vector3(200, 0, 0), Vector3.ZERO)
	check("and sleeps there", b4.state == "sleep" and b4.pos.distance_to(home) < 1.0)
	var b5 := Companion.Brain.new(home)
	b5.state = "follow"
	b5.pos = home + Vector3(3, 0, 0)
	b5.step(0.1, Vector3(0, 0, 0), Vector3.ZERO, 0.0, true)
	check("in a cutscene she holds still", b5.speed == 0.0 and b5.pos == home + Vector3(3, 0, 0))
	var asleep := Companion.Brain.new(home)
	asleep.bark()
	check("a sleeping dog does not bark at a letter", not asleep.bark_req)
	# ---------- the world ----------
	GameState.save_slot = "test_life"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var lv = g.living
	check("the living lake owns a wildlife layer", lv.wildlife != null and lv.wildlife.owl != null)
	lv.set_camp_level(5, false)
	check("at camp level 4+ the sleeping lump gives way to a real dog", lv.companion != null and lv.companion.brain != null and not lv.dog.visible)
	var barks := [0]
	lv.sfx_cb = func(n): if n == "bark": barks[0] += 1
	lv.companion.sfx_cb = func(n): if lv.sfx_cb.is_valid(): lv.sfx_cb.call(n)
	var pp: Vector3 = lv.companion.brain.home + Vector3(3, 1.7, 0)
	for i in 60:
		lv.companion.update(0.05, pp, 0.0)
	check("walk up to her in the real scene and she wakes and barks (%d)" % barks[0], lv.companion.brain.state != "sleep" and barks[0] == 1)
	lv.companion.brain.state = "follow"
	var far := pp + Vector3(25, 0, 0)
	for i in 160:
		pp += Vector3(0.25, 0, 0)
		lv.companion.update(0.05, pp, 0.0)
	check("she follows across the ice (%.1f m behind)" % Vector2(pp.x - lv.companion.position.x, pp.z - lv.companion.position.z).length(), Vector2(pp.x - lv.companion.position.x, pp.z - lv.companion.position.z).length() < 8.0)
	# ---------- the rules for wildlife ----------
	var rl := Wildlife.rules(0.0, false, "clear")
	check("by day: deer and hares, no fox, no owl", rl.deer and rl.hare and not rl.fox and not rl.owl)
	var rn := Wildlife.rules(1.0, false, "clear")
	check("at night: a fox and an owl, no deer", rn.fox and rn.owl and not rn.deer and not rn.hare)
	var rd := Wildlife.rules(0.1, true, "clear")
	check("at dawn: deer and a fox", rd.deer and rd.fox)
	var rb := Wildlife.rules(0.0, false, "blizzard")
	check("in a blizzard nobody is out", not (rb.fox or rb.deer or rb.hare))
	# ---------- who actually turns up ----------
	var w: Wildlife = lv.wildlife
	var player := Vector3(-8.2, 1.7, 14.3)
	var max_deer := 0
	var max_fox := 0
	var on_ice := false
	var in_camp := false
	var seen := {}
	w.spawn_t = 0.0
	for i in 20000:   # ~ 5.5 minutes at 60 ms, by day
		w.update(0.06, 0.0, false, "clear", player)
		max_deer = maxi(max_deer, Wildlife.count_of(w.animals, "deer"))
		for a in w.animals:
			seen[a.kind] = true
			var p: Vector3 = a.node.position
			if a.kind == "deer" and Vector2(p.x, p.z).length() < g.scenery.edge_at(p.x, p.z) + 2.0:
				on_ice = true
			if Vector2(p.x, p.z).length() < Wildlife.CAMP_R - 6.0:
				in_camp = true
	check("by day deer and hares come, never a fox (%s)" % str(seen.keys()), seen.has("deer") and seen.has("hare") and not seen.has("fox"))
	check("at most one group of deer (3) at a time (%d)" % max_deer, max_deer <= Wildlife.MAX_DEER)
	check("deer keep to the bank (never onto the ice)", not on_ice)
	check("nobody walks through the camp", not in_camp)
	seen.clear()
	w.spawn_t = 0.0
	for i in 20000:
		w.update(0.06, 1.0, false, "clear", player)
		max_fox = maxi(max_fox, Wildlife.count_of(w.animals, "fox"))
		for a in w.animals:
			seen[a.kind] = true
	check("at night a fox comes, and only one at a time (%d)" % max_fox, seen.has("fox") and max_fox <= Wildlife.MAX_FOX)
	check("the owl shows at night and hides by day", w.owl.visible)
	w.update(0.06, 0.0, false, "clear", player)
	check("by day the owl is off its pole", not w.owl.visible)
	# fleeing and leaving
	for a in w.animals:
		a.node.queue_free()
	w.animals.clear()
	var fox_node := w._make("fox")
	w.add_child(fox_node)
	var fx: Vector3 = g.scenery.bearing_pos(120.0, g.scenery.edge_at_bearing(deg_to_rad(120.0)) + 12.0)
	fox_node.position = fx
	var fa := {"kind": "fox", "node": fox_node, "state": "wander", "t": 5.0, "speed": 1.5, "dir": Vector3(1, 0, 0), "hop": 0.0, "vel": Vector3.ZERO, "age": 0.0}
	w.animals.append(fa)
	var near_player := fx + Vector3(6.0, 0, 0)
	var d0 := fox_node.position.distance_to(near_player)
	for i in 40:
		w.update(0.06, 1.0, false, "clear", near_player)
	check("a fox 6 m from you runs away (%.1f -> %.1f m)" % [d0, fox_node.position.distance_to(near_player)], fa.state == "flee" and fox_node.position.distance_to(near_player) > d0 + 3.0)
	for i in 2000:
		w.update(0.06, 1.0, false, "clear", near_player + Vector3(300, 0, 0))
	check("animals that end up far away are removed (no leak)", w.animals.filter(func(a): return a.kind == "fox" and a.node == fox_node).is_empty())
	check("the owl does not turn its body, only its head toward you", absf(w.owl_head.rotation.y) <= 1.91)
	print("LIFE %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
