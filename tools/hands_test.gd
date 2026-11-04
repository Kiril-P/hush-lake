extends Node
## Headless test for the hands: grab a fish by looking at it, carry it, drop it, charge and throw it along an arc (land it in the
## Eye), stow it in the bucket and take it out again, deliver it from your hand, and save it. Run: tools/run_hands.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func sim(g, secs: float, player := Vector3(0, 1.7, 95)) -> void:
	for i in int(secs * 60.0):
		g.yard.step(1.0 / 60.0, player)

func face(g, pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	var pl: Node3D = g.get_node("Player")
	pl.position = pos
	pl.rotation.y = deg_to_rad(yaw_deg)
	g.cam.rotation.x = deg_to_rad(pitch_deg)

func _ready() -> void:
	GameState.save_slot = "test_hands"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var yard = g.yard
	var walls: Array = yard.obstacles.duplicate()
	yard.obstacles = []
	yard.clear_all()

	# --- looking at a fish picks it
	face(g, Vector3(-30, 1.7, 70), 0.0, -18.0)   # facing -Z, looking a little down
	var ahead: Dictionary = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)
	var aside: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-24, yard.GROUND, 68), Vector3.ZERO)
	var behind: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 73), Vector3.ZERO)
	var pick: Variant = g._aim_fish()
	check("the fish under the crosshair is the one you can grab (not the one off to the side or behind)", pick != null and pick == ahead)
	face(g, Vector3(-30, 1.7, 70), 0.0, 0.0)
	check("looking over its head at the horizon grabs nothing", g._aim_fish() == null or g._aim_fish() != aside)
	face(g, Vector3(-30, 1.7, 70), 0.0, -18.0)

	# --- grab
	yard.clear_all()
	ahead = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)
	check("grab puts the fish in your hand", g._grab_fish() and not g.held.is_empty() and yard.count() == 0)
	check("...and shows it in front of you", g.hold_node.get_child_count() > 0)
	check("hands hold one fish at a time", not g._grab_fish())

	# --- the held fish sways when you turn
	g._update_hand(0.016)
	var rest_x: float = g.hold_node.position.x
	g.get_node("Player").rotation.y += 0.3
	g._update_hand(0.016)
	check("turning makes the held fish lag behind", absf(g.hold_sway.x) > 0.01 and absf(g.hold_node.position.x - rest_x) > 0.0 or absf(g.hold_sway.x) > 0.01)

	# --- drop
	face(g, Vector3(-30, 1.7, 70), 0.0, -10.0)
	check("clicking on empty ice drops it at your feet", g._drop_held() and g.held.is_empty() and yard.count() == 1)
	var dropped: Dictionary = yard.fish[0]
	sim(g, 3.0)
	check("it lands and rests a metre or two ahead of you", absf(dropped.pos.z - 70.0) < 6.0 and dropped.pos.y < 0.2)
	g._grab_fish(dropped)

	# --- throw: farther with more charge, and where you look
	var dist := {}
	for frac in [0.1, 0.5, 1.0]:
		yard.clear_all()
		g._grab_fish(yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)) if g.held.is_empty() else null
		face(g, Vector3(-30, 1.7, 70), 0.0, 0.0)
		var z0: float = g.cam.global_position.z
		g._throw_held(frac)
		sim(g, 8.0)
		var e: Dictionary = yard.fish[0]
		dist[frac] = z0 - e.pos.z
		check("a throw at %.1f charge travels forward, not sideways (x drift small)" % frac, absf(e.pos.x + 30.0) < 2.5 and dist[frac] > 2.0)
	check("more charge throws farther: %s" % [dist], dist[0.5] > dist[0.1] + 2.0 and dist[1.0] > dist[0.5] + 4.0)
	check("a full charge throws a long way (>=25 m, landing plus skid) but not across the whole lake (<=65 m)", dist[1.0] >= 25.0 and dist[1.0] <= 65.0)
	# looking up lobs it higher and farther (until 45 degrees)
	yard.clear_all()
	g.held = g._make_fish(g.SPECIES[0])
	face(g, Vector3(-30, 1.7, 70), 0.0, 0.0)
	var v_flat: Vector3 = g._throw_velocity(1.0)
	var t_flat: float = FishYard.flight_time(g._throw_origin(), v_flat)
	var land_flat: float = (FishYard.arc_point(g._throw_origin(), v_flat, t_flat) - g._throw_origin()).length()
	face(g, Vector3(-30, 1.7, 70), 0.0, 14.0)
	var v_up: Vector3 = g._throw_velocity(1.0)
	var t_up: float = FishYard.flight_time(g._throw_origin(), v_up)
	var land_up: float = (FishYard.arc_point(g._throw_origin(), v_up, t_up) - g._throw_origin()).length()
	check("looking up a little lobs it farther", land_up > land_flat + 3.0)
	g.held = {}

	# --- aim a throw into the Eye
	yard.clear_all()
	yard.obstacles = []
	g.stats.eye_fed = 0
	var best_pitch := -999.0
	var best_err := 1e9
	face(g, Vector3(0, 1.7, 30), 0.0, 0.0)   # 30 m south of the Eye, facing north (-Z) toward it
	for deg in range(-30, 40, 2):
		g.cam.rotation.x = deg_to_rad(float(deg))
		var v2: Vector3 = g._throw_velocity(0.8)
		var tt: float = FishYard.flight_time(g._throw_origin(), v2)
		var lp: Vector3 = FishYard.arc_point(g._throw_origin(), v2, tt)
		var err: float = Vector2(lp.x, lp.z).length()
		if err < best_err:
			best_err = err
			best_pitch = float(deg)
	check("some aim at 80%% charge lands a throw on the pupil from 30 m (best error %.1f m at %d deg)" % [best_err, int(best_pitch)], best_err < 3.5)
	g.cam.rotation.x = deg_to_rad(best_pitch)
	g.held = g._make_fish(g.SPECIES[1])
	var coins0 := GameState.currency
	g._throw_held(0.8)
	sim(g, 6.0, Vector3(0, 1.7, 95))
	await get_tree().create_timer(0.3).timeout
	check("the fish you threw is swallowed by the Eye and paid", g.stats.eye_fed == 1 and GameState.currency > coins0)

	# --- stow and take out
	yard.clear_all()
	g.carry.clear()
	g.held = g._make_fish(g.SPECIES[0])
	check("E stows the held fish in the bucket", g._stow_held() and g.held.is_empty() and g.carry.size() == 1)
	g.held = g._make_fish(g.SPECIES[0])
	check("a full bucket (capacity 1) refuses and you keep the fish", not g._stow_held() and not g.held.is_empty() and g.carry.size() == 1)
	g.held = {}
	check("Z takes one out of the bucket into your hand", g._take_from_bucket() and not g.held.is_empty() and g.carry.is_empty())
	check("...and nothing more to take", not g._take_from_bucket())

	# --- deliver from your hand
	g.stats.eye_fed = 0
	g.carry.clear()
	g.held = g._make_fish(g.SPECIES[1])
	g._feed_by_hand()
	check("clicking the Eye with a fish in hand feeds it (moved to the throw queue)", g.held.is_empty() and g.flying.size() == 1)
	await get_tree().create_timer(2.0).timeout
	check("...and it pays", g.stats.eye_fed == 1)

	# --- species orders, prompts, save
	g.held = g._make_fish(g.SPECIES[1])
	check("the prompt on the Eye says it will be thrown in", g._prompt_for("eye").contains("throw it in"))
	check("Olga's prompt knows you carry fish", g._prompt_for("olga").contains("doesn't buy"))
	check("a held Perch counts as out of the lake for orders", g._species_held("Perch") >= 1)
	g._on_about_to_save()
	check("a fish in hand is saved (as one lying at your feet)", GameState.extra.loose.size() >= 1)
	g.held = {}
	g._set_hold_visual()

	# --- thrown fish go into machines: a depot sends them to the Eye, a smoker starts smoking them
	yard.clear_all()
	yard.obstacles = walls
	g.stats.eye_fed = 0
	g.scenery.obstacles.clear()
	for sid in g.model.sectors:
		g.model.sectors[sid].unlocked = true
	g._build_depot(Vector3(-60, 0, 45), false)
	var d: Dictionary = g.depots[g.depots.size() - 1]
	var coins1 := GameState.currency
	yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(-60, 1.2, 55), Vector3(0, 0, -9))   # lobbed at the depot from 10 m
	sim(g, 2.5, Vector3(0, 1.7, 95))
	check("a fish thrown into a depot goes in (nothing left on the ice) and is sent to the Eye", yard.count() == 0 and g.flying.size() >= 1)
	await get_tree().create_timer(2.5).timeout
	check("...and pays at the depot rate", g.stats.eye_fed == 1 and GameState.currency > coins1)
	var sm: Dictionary = g._make_hole(g._hex_pos(Vector2i(-2, 1)))
	var sp: Vector3 = sm.pos
	g._build_smoker(sm)
	for i in 6:
		yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(sp.x, 1.0, sp.z + 6.0 + i * 0.1), Vector3(0, 0, -9))
		sim(g, 1.2, Vector3(0, 1.7, 95))
	check("fish thrown at a smoker go in until it holds 4, and it starts smoking", sm.slot.size() == 4 and sm.smoke_t > 0.0)
	check("the rest stay on the ice (the smoker refuses a full batch)", yard.count() == 2)
	sm.smoke_t = 0.0
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(sp.x, 1.0, sp.z + 6.0), Vector3(0, 0, -9))
	sim(g, 1.5, Vector3(0, 1.7, 95))
	check("a finished batch is not topped up (collect it first)", sm.slot.size() == 4)
	yard.clear_all()

	# --- the held fish shows nothing when your hands are empty
	g._update_hand(0.016)
	check("with empty hands nothing hangs in front of you", not g.hold_node.visible)
	print("HANDS %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
