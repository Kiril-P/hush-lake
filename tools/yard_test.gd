extends Node
## Headless test for fish as real objects: one line at a time, falling catches, friction, pushing, kicks, the Eye's pull.
## Run: tools/run_yard.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func sim(g, secs: float, player: Vector3 = Vector3(0, 0, 90)) -> void:
	for i in int(secs * 60.0):
		g.yard.step(1.0 / 60.0, player)

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func _ready() -> void:
	GameState.save_slot = "test_yard"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	var yard = g.yard
	var far := Vector3(0, 1.7, 95)   # the player, parked out of the way
	var walls: Array = yard.obstacles.duplicate()
	yard.obstacles = []   # (camp walls come back for their own test)

	# --- one line at a time
	var t1: Dictionary = g._make_hole(g.guide.drill_spot)
	var t2: Dictionary = g._make_hole(g.guide.drill_spot + Vector3(0, 0, 4.0))
	g.tool = 1
	g._click("hole:%d" % t1.idx)
	check("first cast lands", t1.cast == 1)
	g._click("hole:%d" % t2.idx)
	check("casting a second hole reels the first in: only one line is ever out", t2.cast == 1 and t1.cast == 0)
	check("the prompt warns that a new cast reels the other line in", g._tile_action_text(t1).contains("reels in"))
	t2.timer = 0.0
	g._tick_hole(t2, 0.1)
	g._click("hole:%d" % t2.idx)
	check("hooked: fighting", t2.cast == 3)
	g._click("hole:%d" % t1.idx)
	check("cannot start another line mid-fight", t1.cast == 0 and t2.cast == 3)

	# --- the catch is a real object that falls
	t2.fight = 0.0
	g._tick_hole(t2, 0.1)
	check("the catch is a loose fish, not in your hands", yard.count() == 1 and g.carry.is_empty())
	var e: Dictionary = yard.fish[0]
	check("it is above the ice and rising out of the hole", e.pos.y > 0.2 and e.vel.y > 3.0)
	var hole_p: Vector3 = t2.node.global_position
	var landed := [0]
	yard.landed.connect(func(_f, _i): landed[0] += 1)
	sim(g, 0.3, far)
	var y_mid: float = e.pos.y
	sim(g, 0.2, far)
	check("it arcs up and comes back down", y_mid > 1.0 and e.pos.y < y_mid)
	sim(g, 1.2, far)
	check("it lands (and makes a landing sound event)", is_equal_approx(e.pos.y, yard.GROUND) and landed[0] >= 1)
	sim(g, 12.0, far)
	await get_tree().create_timer(0.3).timeout
	check("the first catch at the tutorial hole is pulled in and swallowed with no input", yard.count() == 0 and g.stats.eye_fed >= 1)

	# --- friction: a fast fish glides a good while, then stops
	yard.clear_all()
	var f1: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-40, yard.GROUND, 40), Vector3(10, 0, 0))
	sim(g, 0.2, far)
	var x_early: float = f1.pos.x
	sim(g, 10.0, far)
	var glide: float = f1.pos.x + 40.0
	check("a fast fish keeps sliding for several metres", x_early + 40.0 > 1.0 and glide > 8.0 and glide < 25.0)
	check("and then rests", Vector2(f1.vel.x, f1.vel.z).length() < 0.05)

	# --- walking into a fish pushes it
	yard.clear_all()
	var f2: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-40, yard.GROUND, 40), Vector3.ZERO)
	var pl := Vector3(-42.0, 1.7, 40.0)
	yard.player_speed = 6.0
	for i in 60:
		pl.x += 6.0 / 60.0
		yard.step(1.0 / 60.0, pl)
	yard.player_speed = 0.0
	check("walking into a fish shoves it ahead of you", f2.pos.x > -40.0 + 1.0 and f2.pos.x - pl.x < 3.5)
	var standing_before: float = f2.pos.x
	for i in 30:
		yard.step(1.0 / 60.0, pl + Vector3(0, 0, 8.0))
	check("standing still does not move it again (apart from sliding out)", f2.pos.x - standing_before < 6.0)

	# --- a kick
	yard.clear_all()
	var pk := Vector3(-30.0, 1.7, 30.0)
	var f3: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30.0, yard.GROUND, 28.5), Vector3.ZERO)
	var behind: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30.0, yard.GROUND, 32.0), Vector3.ZERO)
	var n_hit: int = yard.kick(pk, Vector3(0, 0, -1), 12.0)
	check("a kick hits the fish in front of you, not the one behind", n_hit == 1 and f3.vel.z < -8.0 and behind.vel.length() < 0.01)
	sim(g, 5.0, pk + Vector3(30, 0, 0))
	check("the kicked fish flew the way you were facing", f3.pos.z < 28.5 - 6.0 and absf(f3.pos.x + 30.0) < 4.0)
	# charge: a held kick goes farther than a tap
	g.kick_charge = 0.0
	yard.clear_all()
	var f4: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(g.get_node("Player").global_position.x, yard.GROUND, g.get_node("Player").global_position.z), Vector3.ZERO)
	g.get_node("Player").rotation.y = 0.0
	g.get_node("Player").global_position = Vector3(-30, g.EYE_H, 60)
	f4.pos = Vector3(-30, yard.GROUND, 58.5)
	g._release_kick()
	var tap_speed := Vector2(f4.vel.x, f4.vel.z).length()
	f4.vel = Vector3.ZERO
	g.kick_charge = 1.0
	g._release_kick()
	var full_speed := Vector2(f4.vel.x, f4.vel.z).length()
	check("a tap kicks at KICK_MIN and a full charge kicks harder", tap_speed > 6.0 and full_speed > tap_speed + 5.0 and g.kick_charge < 0.0)
	GameState.upgrades["kick"] = 3
	f4.vel = Vector3.ZERO
	g.kick_charge = 1.0
	g._release_kick()
	check("Kick Power makes the full kick go farther", Vector2(f4.vel.x, f4.vel.z).length() > full_speed + 5.0)
	GameState.upgrades["kick"] = 0
	g.get_node("Player").global_position = Vector3(-8.2, g.EYE_H, 14.3)

	# --- fish bump into fish
	yard.clear_all()
	var fa: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-50, yard.GROUND, 50), Vector3(9, 0, 0))
	var fb: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-46, yard.GROUND, 50), Vector3.ZERO)
	sim(g, 1.5, far)
	check("a sliding fish knocks a resting one along", fb.pos.x > -45.0 and fa.pos.x < fb.pos.x)

	# --- the Eye pulls fish in and eats them
	yard.clear_all()
	var fed0: int = g.stats.eye_fed
	var coins0 := GameState.currency
	var fe: Dictionary = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(g.EYE_R + 0.5, yard.GROUND, 0), Vector3.ZERO)
	var worth: float = fe.f.base * fe.f.mult * g.sale_mult() * g.EYE_MULT
	sim(g, 12.0, far)
	await get_tree().create_timer(0.3).timeout
	check("a fish resting at the rim is pulled in and swallowed", yard.count() == 0 and g.stats.eye_fed == fed0 + 1)
	check("the Eye paid for it at the usual rate", GameState.currency >= coins0 + worth - 0.01)
	var fs: Dictionary = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(g.EYE_R + 14.0, yard.GROUND, 0), Vector3.ZERO)
	sim(g, 15.0, far)
	check("a fish far from the Eye is not pulled", yard.count() == 1 and fs.pos.x > g.EYE_R + 10.0)
	# thrown: a long kick toward the Eye
	var fk: Dictionary = yard.spawn(g._make_fish(g.SPECIES[2]), Vector3(g.EYE_R + 14.0, yard.GROUND, 0), Vector3(-13.0, 0, 0))
	var fed1: int = g.stats.eye_fed
	sim(g, 8.0, far)
	await get_tree().create_timer(0.3).timeout
	check("a kicked fish reaching the pupil is swallowed", g.stats.eye_fed == fed1 + 1 and not yard.fish.has(fk))
	check("hand-style streak counts for pushed fish", g.feed_streak >= 1)

	# --- walls: stalls and the hut stop fish
	yard.clear_all()
	yard.obstacles = walls
	var ob: Vector3 = g.scenery.obstacles[0]
	var fw: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(ob.x + ob.z + 5.0, yard.GROUND, ob.y), Vector3(-8.0, 0, 0))
	sim(g, 3.0, far)
	check("fish bounce off the hut instead of going through it", Vector2(fw.pos.x - ob.x, fw.pos.z - ob.y).length() >= ob.z + fw.r - 0.01)

	# --- walk-push follows where you are heading
	yard.clear_all()
	yard.obstacles = []
	var fo: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-50, yard.GROUND, 60.5), Vector3.ZERO)
	var pw := Vector3(-52.0, 1.7, 60.0)
	yard.player_speed = 6.0
	yard.player_vel = Vector3(6, 0, 0)
	for i in 100:
		pw.x += 6.0 / 60.0
		yard.step(1.0 / 60.0, pw)
	yard.player_speed = 0.0
	yard.player_vel = Vector3.ZERO
	check("an off-centre fish is carried along your path, not squirted sideways", fo.pos.x > -50.0 + 4.0 and absf(fo.pos.z - 60.0) < 1.6)

	# --- the real shoreline
	yard.clear_all()
	var bank_dir := Vector3(0, 0, 1)
	var edge_r: float = g.scenery.edge_at(0, 1)
	var fe2: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(0, yard.GROUND, edge_r - 6.0), Vector3(0, 0, 30.0))
	sim(g, 8.0, far)
	check("a hard kick toward the bank stops on the ice, inside the real shoreline", Vector2(fe2.pos.x, fe2.pos.z).length() <= g.scenery.edge_at(fe2.pos.x, fe2.pos.z) - 1.4)

	# --- pushing keeps the combo alive; overflow pays half and breaks no streak
	g.combo = 3
	g.combo_t = 2.0
	g.feed_streak = 0
	g.feed_streak_t = 0.0
	yard.clear_all()
	var fc: Dictionary = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(g.EYE_R - 3.0, yard.GROUND, 0), Vector3.ZERO)
	sim(g, 4.0, far)
	await get_tree().create_timer(0.2).timeout
	check("swallowing a pushed fish refreshes the combo window", g.combo_t > 13.0)
	g.combo = 0
	g.combo_t = 0.0
	yard.clear_all()
	GameState.currency = 0.0
	var first: Dictionary = g._make_fish(g.SPECIES[1])
	yard.spawn(first, Vector3(-60, yard.GROUND, 60), Vector3.ZERO)
	var half: float = first.base * first.mult * g.sale_mult() * g.EYE_MULT * 0.5
	var streak0: int = g.feed_streak
	for i in yard.MAX_LOOSE:
		yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-60 + (i % 10) * 1.3, yard.GROUND, 62 + floorf(i / 10.0) * 1.3), Vector3.ZERO)
	check("the 61st fish takes the oldest off the ice", yard.count() == yard.MAX_LOOSE)
	check("overflow pays half the Eye rate and does not touch the streak", absf(GameState.currency - half) < 400.0 and GameState.currency >= half - 0.01 and g.feed_streak == streak0)
	yard.clear_all()

	# --- the kick is forgiving and shows what it hits
	yard.clear_all()
	var pk2 := Vector3(-30.0, 1.7, 80.0)
	var ahead := Vector3(0, 0, -1)
	var near_side: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30.0 + 2.8, yard.GROUND, 80.0 - 1.0), Vector3.ZERO)
	check("a fish well off to the side still counts as a kick target (assist)", yard.targets(pk2, ahead, 3.4).size() == 1)
	yard.clear_all()
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30.0, yard.GROUND, 80.0 + 2.5), Vector3.ZERO)
	check("a fish behind you is not", yard.targets(pk2, ahead, 3.4).is_empty())
	yard.clear_all()

	# --- an Auto-Rod's stash does not wait for free hands
	yard.obstacles = walls
	g.carry.clear()
	var ta: Dictionary = g._make_hole(g.guide.drill_spot + Vector3(0, 0, 14))
	g._build_auto(ta, false)
	for i in 3:
		ta.stash.append(g._make_fish(g.SPECIES[0]))
	g.tool = 2
	g.unlocked["t_auto"] = true
	g._click("hole:%d" % ta.idx)
	check("collecting a stash fills your hands and spills the rest onto the ice", g.carry.size() == 1 and yard.count() == 2 and ta.stash.is_empty())
	g.carry.clear()
	yard.clear_all()
	yard.obstacles = []

	# --- the cap: the ice never clogs
	yard.obstacles = []
	yard.clear_all()
	var fed2: int = g.stats.eye_fed
	for i in 70:
		yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-60 + (i % 10) * 1.2, yard.GROUND, 60 + floorf(i / 10.0) * 1.2), Vector3.ZERO)
	check("no more than MAX_LOOSE fish lie around", yard.count() <= yard.MAX_LOOSE)
	check("the overflow went to the Eye", g.stats.eye_fed >= fed2 + 10)
	sim(g, 3.0, far)
	check("a pile does not explode (all fish stay on the lake)", yard.fish.all(func(x): return flat(x.pos).length() < yard.EDGE + 1.0 and is_finite(x.pos.x)))

	# --- picking up with E
	yard.clear_all()
	g.carry.clear()
	var pp: Vector3 = g.get_node("Player").global_position
	for i in 3:
		yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(pp.x + 1.0 + i * 0.5, yard.GROUND, pp.z), Vector3.ZERO)
	g._pick_up_fish()
	check("E scoops up only what the bucket holds (starts at 1)", g.carry.size() == 1 and yard.count() == 2)
	g._pick_up_fish()
	check("a full bucket says so and takes nothing more", g.carry.size() == 1 and yard.count() == 2)
	GameState.upgrades["bucket"] = 2
	g._pick_up_fish()
	check("with a bigger bucket E takes more", g.carry.size() == 3 and yard.count() == 0)
	GameState.upgrades["bucket"] = 0
	g.carry.clear()

	# --- guide and saving
	yard.clear_all()
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-20, yard.GROUND, 20), Vector3.ZERO)
	check("guide: loose fish -> push it into the Eye (after the first, 'push')", g.guide.current().id in ["push0", "push"] and g.guide.current().where != null)
	g.stats.eye_fed = 0
	check("guide: the very first fish gets the push0 step", g.guide.current().id == "push0")
	g._on_about_to_save()
	check("loose fish are saved", GameState.extra.loose.size() == 1)
	yard.clear_all()
	for ld in GameState.extra.loose:
		yard.spawn(g._fish_from(ld.f), Vector3(ld.p[0], yard.GROUND, ld.p[1]), Vector3.ZERO)
	check("and come back where they lay", yard.count() == 1 and absf(yard.fish[0].pos.x + 20.0) < 0.1)
	print("YARD %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
