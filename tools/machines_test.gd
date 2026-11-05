extends Node
## Headless test for the second layer of play: the Bait Grinder (a fish thrown in becomes bait: faster bites for a while) and the
## Wind Fan (blows loose fish along the ice toward the Eye), both built from the kit and saved. Run: tools/run_machines.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func sim(g, secs: float, player := Vector3(0, 1.7, 95)) -> void:
	for i in int(secs * 60.0):
		g.yard.step(1.0 / 60.0, player)

func _ready() -> void:
	GameState.save_slot = "test_machines"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var yard = g.yard
	yard.obstacles = []
	yard.clear_all()
	for sid in g.model.sectors:
		g.model.sectors[sid].unlocked = true
	g.unlocked["t_build"] = true
	GameState.currency = 99999.0
	g.stats.eye_fed = 0

	# --- the kit offers both, B cycles to them, the prompts say what they do
	g.equip(6, 4)
	check("the kit can be set to Bait Grinder (build 5 of 6)", g.tool == 6 and g.build_item == 4 and g._kit_name(g.bmode) == "Bait Grinder")
	g.equip(6, 5)
	check("...and to Wind Fan", g.build_item == 5 and g._kit_name(g.bmode) == "Wind Fan")
	check("both have a price that rises with each one", g._build_cost(4) == 110 and g._build_cost(5) == 140)

	# --- Bait Grinder
	g.equip(6, 4)
	var gp := Vector3(-17.5, 0, 0)   # open Shallows ice (the depot tests use the same spot)
	check("a grinder can go on open ice", g._can_place_at(gp, 2.2))
	g.aim_pos = gp
	var coins0 := GameState.currency
	g._click("ice")
	check("clicking open ice builds it and charges the price", g.props.size() == 1 and g.props[0].kind == "grinder" and GameState.currency < coins0 and g.stats.grinders == 1)
	check("the next grinder costs more", g._build_cost(4) > 110)
	check("a second one cannot overlap the first", not g._can_place_at(gp + Vector3(1.5, 0, 0), 2.2))
	var base_bite: float = g.bite_mult()
	check("with no bait bites come at the normal pace", g.bait_t == 0.0)
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(gp.x, 1.2, gp.z + 6.0), Vector3(0, 0, -8.0))   # lobbed at it
	sim(g, 2.0)
	check("a fish thrown into the grinder goes in and becomes bait", yard.count() == 0 and g.bait_t > 10.0 and g.stats.grinds == 1)
	check("with bait every bite comes sooner (x0.6)", absf(g.bite_mult() - base_bite * g.BAIT_MULT) < 0.0001)
	var b1: float = g.bait_t
	g.inv.clear()
	g.inv.slots[0] = Inventory.fish_item(g._make_fish(g.SPECIES[2]))
	g.inv.active = 0
	g._hands_changed()
	g._click("prop:0")
	check("clicking the grinder with a fish in hand grinds it (a richer fish makes more bait)", g.inv.cargo_count() == 0 and g.bait_t > b1 + 12.0)
	g.inv.clear()
	g.inv.slots[0] = Inventory.bucket_item([g._make_fish(g.SPECIES[0]), g._make_fish(g.SPECIES[0])])
	g._hands_changed()
	var bb: float = g.bait_t
	g._click("prop:0")
	check("with a bucket in hand the grinder refuses: the fish in it are safe", g.inv.cargo_count() == 2 and g.bait_t == bb)
	g.bait_t = 175.0
	g._grind(g._make_fish(g.SPECIES[0]), g.props[0].pos)
	check("bait is capped", g.bait_t <= g.BAIT_MAX)
	# bait speeds up the real bite timer
	var h: Dictionary = g._make_hole(g.guide.drill_spot)
	g.bait_t = 0.0
	var slow := 0.0
	for i in 200:
		slow += g.wait_time(h)
	g.bait_t = 60.0
	var fast := 0.0
	for i in 200:
		fast += g.wait_time(h)
	check("a cast waits clearly less with bait (%.2f vs %.2f)" % [fast / 200.0, slow / 200.0], fast < slow * 0.8)
	g.bait_t = 3.0
	g._process(1.0)
	check("bait runs down in play", g.bait_t < 2.5 and g.bait_label.text.contains("Bait"))
	g.bait_t = 0.0
	g._process(0.1)
	check("...and the label goes away when it is gone", g.bait_label.text == "")

	# --- Wind Fan
	g.equip(6, 5)
	var fp := Vector3.ZERO   # the first legal spot west of the Eye
	for fx in [-27.0, -30.0, -34.0, -38.0, -42.0]:
		for fz in [0.0, 5.0, -5.0, 10.0, -10.0, 15.0]:
			if fp == Vector3.ZERO and g._can_place_at(Vector3(fx, 0, fz), 2.2):
				fp = Vector3(fx, 0, fz)
	check("there is a legal spot for a fan", fp != Vector3.ZERO)
	g.aim_pos = fp
	g._click("ice")
	check("a fan builds on open ice", g.props.size() == 2 and g.props[1].kind == "fan" and yard.fans.size() == 1)
	var dir: Vector2 = yard.fans[0].dir
	check("it faces the Eye", dir.dot(Vector2(-fp.x, -fp.z).normalized()) > 0.99)
	yard.clear_all()
	var fd := Vector3(dir.x, 0, dir.y)
	var perp := Vector3(-dir.y, 0, dir.x)
	var f2: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), fp + fd * 4.0, Vector3.ZERO)
	var off: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), fp + fd * 4.0 + perp * 14.0, Vector3.ZERO)   # out of the cone
	var behind: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), fp - fd * 6.0, Vector3.ZERO)   # upwind
	var p0: Vector3 = f2.pos
	var o0: Vector3 = off.pos
	var b0: Vector3 = behind.pos
	sim(g, 1.5)
	check("a fish in the wind drifts toward the Eye (moved %.1f m in 1.5 s)" % ((f2.pos - p0).dot(fd)), (f2.pos - p0).dot(fd) > 4.0)
	check("a fish out of the cone is not pushed", (off.pos - o0).length() < 0.5)
	check("a fish behind the fan is not pushed", (behind.pos - b0).length() < 0.5)
	var rot0: float = g.props[1].part.rotation.z
	g._process(0.1)
	check("the fan rotor turns each frame", g.props[1].part.rotation.z != rot0)
	for i in 6:
		g.equip(6, 5)
		g.aim_pos = Vector3(-30.0 - i * 6.0, 0, 18.0 + i * 9.0)
		g._click("ice")
	check("fans are limited (max %d)" % g.MAX_FANS, g._prop_count("fan") <= g.MAX_FANS)

	# --- saving
	g.bait_t = 42.0
	g._on_about_to_save()
	var sv: Dictionary = GameState.extra
	var np: int = g.props.size()
	var nf: int = yard.fans.size()
	check("props and bait are saved", sv.props.size() == np and absf(float(sv.bait) - 42.0) < 0.01)
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	check("a loaded game has the same machines, the same wind and the same bait", g2.props.size() == np and g2.yard.fans.size() == nf and absf(g2.bait_t - 42.0) < 1.0)
	check("a loaded grinder still takes fish", g2.yard.sinks.any(func(sk): return String(sk.id).begins_with("grinder:")))
	check("goals count them once (not doubled by the load)", g2.stats.grinders == 1 and g2.stats.fans >= 1)
	GameState.delete_save()
	print("MACHINES %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
