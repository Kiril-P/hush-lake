extends Node
## Headless test for the hands and the three slots: grab a fish by looking at it, carry it in a slot, drop it, charge and throw it along
## an arc (land it in the Eye), buckets (hold, scoop, set down, throw fish into, take fish out of, tip over), tools on the ice and the
## rack, deliver from your hands, and save it all. Run: tools/run_hands.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func sim(g, secs: float, player := Vector3(0, 1.7, 95)) -> void:
	for i in int(secs * 60.0):
		g.yard.step(1.0 / 60.0, player)

## A fish straight into your hand (slot 3, made active), the way a grab leaves it.
func hold(g, f: Dictionary) -> void:
	g.inv.slots[2] = Inventory.fish_item(f)
	g.inv.active = 2
	g._hands_changed()

func empty_hand(g) -> void:
	g.inv.slots[g.inv.active] = {}
	g._hands_changed()

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
	check("you start with the drill and the rod in slots 1 and 2, the drill in hand", g.inv.slots[0].t == 0 and g.inv.slots[1].t == 1 and g.inv.active == 0 and g.tool == 0)
	check("grab puts the fish in your free slot and makes it your hand", g._grab_fish() and g._held_kind() == "fish" and g.inv.active == 2 and yard.count() == 0)
	check("...and shows it in front of you", g.hold_node.get_child_count() > 0)
	check("with all three slots full a grab is refused", not g._grab_fish())

	# --- the held fish sways when you turn
	g._update_hand(0.016)
	var rest_x: float = g.hold_node.position.x
	g.get_node("Player").rotation.y += 0.3
	g._update_hand(0.016)
	check("turning makes the held fish lag behind", absf(g.hold_sway.x) > 0.01 and absf(g.hold_node.position.x - rest_x) > 0.0 or absf(g.hold_sway.x) > 0.01)

	# --- drop
	face(g, Vector3(-30, 1.7, 70), 0.0, -10.0)
	check("clicking on empty ice drops it at your feet (and you are back to the drill)", g._drop_active() and g._held_fish().is_empty() and yard.count() == 1 and g.tool == 0)
	var dropped: Dictionary = yard.fish[0]
	sim(g, 3.0)
	check("it lands and rests a metre or two ahead of you", absf(dropped.pos.z - 70.0) < 6.0 and dropped.pos.y < 0.2)
	g._grab_fish(dropped)

	# --- things put down never hide a hole from your crosshair
	var hole_t: Dictionary = g._make_hole(Vector3(-30, 0, 66))
	var spot: Vector3 = g._valid_spot(Vector3(hole_t.pos.x + 0.4, 0, hole_t.pos.z))
	check("a drop spot is nudged off a hole", Vector2(spot.x - hole_t.pos.x, spot.z - hole_t.pos.z).length() >= 1.85)
	g.holes.erase(hole_t)
	hole_t.node.queue_free()

	# --- throw: farther with more charge, and where you look
	var dist := {}
	for frac in [0.1, 0.5, 1.0]:
		yard.clear_all()
		if g._held_fish().is_empty():
			g._grab_fish(yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO))
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
	hold(g, g._make_fish(g.SPECIES[0]))
	face(g, Vector3(-30, 1.7, 70), 0.0, 0.0)
	var v_flat: Vector3 = g._throw_velocity(1.0)
	var t_flat: float = FishYard.flight_time(g._throw_origin(), v_flat)
	var land_flat: float = (FishYard.arc_point(g._throw_origin(), v_flat, t_flat) - g._throw_origin()).length()
	face(g, Vector3(-30, 1.7, 70), 0.0, 14.0)
	var v_up: Vector3 = g._throw_velocity(1.0)
	var t_up: float = FishYard.flight_time(g._throw_origin(), v_up)
	var land_up: float = (FishYard.arc_point(g._throw_origin(), v_up, t_up) - g._throw_origin()).length()
	check("looking up a little lobs it farther", land_up > land_flat + 3.0)
	empty_hand(g)

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
	hold(g, g._make_fish(g.SPECIES[1]))
	var coins0 := GameState.currency
	g._throw_held(0.8)
	sim(g, 6.0, Vector3(0, 1.7, 95))
	await get_tree().create_timer(0.3).timeout
	check("the fish you threw is swallowed by the Eye and paid", g.stats.eye_fed == 1 and GameState.currency > coins0)

	# --- two grabs in a row still return you to what you held
	yard.clear_all()
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g._hands_changed()
	face(g, Vector3(-30, 1.7, 70), 0.0, -18.0)
	var q1: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)
	g._grab_fish(q1)
	var q2: Dictionary = yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)
	g._grab_fish(q2)
	check("two fish grabbed: both are in slots, the second in your hand", g.inv.cargo_count() == 2 and g._held_kind() == "fish")
	g._throw_held(0.2)
	g._throw_held(0.2) if g._held_kind() == "fish" else null
	check("throwing them away puts the drill back in your hand", g._held_kind() == "tool" and g.tool == 0 and g.inv.active == 0)
	yard.clear_all()

	# --- the hand keys do nothing while the menu is up
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.bucket_item()
	g._hands_changed()
	g._select_slot(1)
	g.test_capture = false
	var kq := InputEventKey.new()
	kq.keycode = KEY_Q
	kq.pressed = true
	g._unhandled_input(kq)
	var k1 := InputEventKey.new()
	k1.keycode = KEY_1
	k1.pressed = true
	g._unhandled_input(k1)
	check("Q and 1 are ignored when the mouse is free (the menu is up)", g.ground.is_empty() and g.inv.slots[1].get("k", "") == "bucket" and g.inv.active == 1)
	g.test_capture = true
	g._unhandled_input(k1)
	check("...and work as soon as you are playing again", g.inv.active == 0)
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.tool_item(1)
	g._hands_changed()
	g.inv.active = 2   # (the next block starts from an empty third slot in hand, like after a throw)
	g._hands_changed()

	# --- slots: select, cycle
	empty_hand(g)
	g._select_slot(0)
	check("number keys pick a slot (1 = the drill)", g.inv.active == 0 and g.tool == 0)
	g._select_slot(1)
	check("2 = the rod in your hand", g.inv.active == 1 and g.tool == 1)
	g._cycle_slot(1)
	check("the wheel cycles to the third slot: empty hands", g.inv.active == 2 and g.tool == -1 and g._held_kind() == "")
	g._cycle_slot(1)
	check("...and wraps around to the first", g.inv.active == 0)

	# --- a bucket: buying gives you one in your free slot
	GameState.currency = 500.0
	g._buy("bucket")
	check("buying a bucket puts a real bucket in your free slot", g.inv.slots[2].get("k", "") == "bucket" and GameState.level("bucket") == 1)
	check("a bucket holds %d fish" % g._bucket_cap(), g._bucket_cap() >= 4)
	g._select_slot(2)
	check("holding the bucket shows it in front of you", g._held_kind() == "bucket" and g.hold_node.get_child_count() > 0 and g.tool == -1)
	yard.clear_all()
	face(g, Vector3(-30, 1.7, 70), 0.0, -18.0)
	var f1: Dictionary = yard.spawn(g._make_fish(g.SPECIES[1]), Vector3(-30, yard.GROUND, 66.5), Vector3.ZERO)
	check("clicking a fish while holding a bucket scoops it into the bucket (not a slot)", g._grab_fish() and g.inv.slots[2].fish.size() == 1 and g.inv.active == 2 and g.inv.free_count() == 0)
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-30, yard.GROUND, 69), Vector3.ZERO)
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-29, yard.GROUND, 69.5), Vector3.ZERO)
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-31, yard.GROUND, 69.5), Vector3.ZERO)
	g._sweep_fish()
	check("E sweeps up the fish at your feet into the bucket", g.inv.slots[2].fish.size() == 4 and yard.count() == 0)
	check("carrying shows up everywhere you would look", g.carrying() and g.inv.cargo_count() == 4 and g.carry_label.text.contains("4 fish"))
	check("a held bucket takes fish up to its size", g.free_space() == g._bucket_cap() - 4)
	var bucket_fish: int = g.inv.slots[2].fish.size()
	check("Z with no free slot says so and keeps the fish in the bucket", not g._take_from_bucket() and g.inv.slots[2].fish.size() == bucket_fish)

	# --- put the rod down to free a slot, take one out with Z
	g._select_slot(1)
	g._drop_active()
	check("Q puts the rod down on the ice, it lies there as a thing you can pick up", g.inv.slots[1].is_empty() and g.ground.size() == 1 and g.ground[0].item.k == "tool" and g.ground[0].item.t == 1)
	var rod_g: Dictionary = g.ground[0]
	g._select_slot(2)
	check("Z takes one fish out of the bucket into your hand", g._take_from_bucket() and g._held_kind() == "fish" and g.inv.active == 1 and g.inv.slots[2].fish.size() == bucket_fish - 1)
	check("throwing it sends you back to the bucket you were holding", g._throw_held(0.3) and g.inv.active == 2 and g._held_kind() == "bucket")
	yard.clear_all()

	# --- set the bucket down: it stays where it lands, and takes fish thrown into it
	face(g, Vector3(-30, 1.7, 70), 0.0, -5.0)
	g._drop_active(false)
	check("Q sets the bucket down in front of you, fish and all", g.ground.size() == 2 and g.inv.slots[2].is_empty() and g.ground[1].item.k == "bucket" and g.ground[1].item.fish.size() == bucket_fish - 1)
	var bg: Dictionary = g.ground[1]
	while bg.item.fish.size() > 1:   # (room for two more whatever the bucket size is)
		bg.item.fish.pop_back()
	var bpos: Vector3 = bg.pos
	var before: int = bg.item.fish.size()
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(bpos.x, 1.0, bpos.z + 5.0), Vector3(0, 0, -7.0))   # lobbed at it
	sim(g, 2.0)
	check("a fish thrown at the bucket lands in it", bg.item.fish.size() == before + 1 and yard.count() == 0)
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(bpos.x + 5.0, yard.GROUND, bpos.z), Vector3(-6.0, 0, 0))   # slid along the ice
	sim(g, 2.0)
	check("a fish kicked along the ice into it goes in too", bg.item.fish.size() == before + 2)
	g.inv.slots[2] = {}
	var cap: int = g._bucket_cap()
	while bg.item.fish.size() < cap:
		bg.item.fish.append(g._make_fish(g.SPECIES[0]))
	yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(bpos.x, 1.0, bpos.z + 5.0), Vector3(0, 0, -7.0))
	sim(g, 2.0)
	check("a full bucket lets the fish slide past", bg.item.fish.size() == cap and yard.count() == 1)
	yard.clear_all()

	# --- take a fish out of a bucket on the ice, and pick the bucket up
	g._select_slot(2)
	var n_before: int = bg.item.fish.size()
	g._click_ground(bg)
	check("clicking a bucket on the ice takes a fish out into your hand", g._held_kind() == "fish" and bg.item.fish.size() == n_before - 1)
	g._click_ground(bg)
	check("...and a held fish clicked on it goes back in", g._held_fish().is_empty() and bg.item.fish.size() == n_before)
	g.inv.slots[0] = {}
	g.inv.slots[1] = {}
	g.inv.slots[2] = {}
	g._take_ground(bg)
	check("E picks the whole bucket up with its fish", g.inv.cargo_count() == n_before and g.ground.size() == 1 and g.inv.find_tool(2) == -1 and g.inv.buckets().size() == 1)

	# --- tools on the ice: pick up, and swap when your hands are full
	g._take_ground(rod_g)
	check("a tool on the ice is picked up into a free slot", g.inv.find_tool(1) >= 0 and g.ground.is_empty())
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.tool_item(1)
	g.inv.slots[2] = Inventory.bucket_item([g._make_fish(g.SPECIES[0]), g._make_fish(g.SPECIES[1]), g._make_fish(g.SPECIES[0])])
	g._hands_changed()
	var full_bucket_slot := 2
	check("now all three slots are full (drill, rod, bucket)", g.inv.free_count() == 0)
	g._select_slot(1)
	g._drop_active()
	check("with the rod put down, a slot is free again", g.ground.size() == 1 and g.inv.free_count() == 1)
	g._remove_ground(g.ground[0])
	g.inv.slots[1] = Inventory.tool_item(1)   # (hands full again)
	g._place_ground(Inventory.tool_item(2), Vector3(-30, 0, 60), false)
	g._select_slot(0)
	g._take_ground(g.ground[0])
	check("picking something up with full hands swaps it with what you hold (the drill goes down where it lay)", g.ground.size() == 1 and g.ground[0].item.t == 0 and g.inv.slots[0].t == 2)
	g._remove_ground(g.ground[0])
	g.inv.slots[0] = Inventory.tool_item(0)
	g._hands_changed()

	# --- kick a placed bucket over
	yard.clear_all()
	g._select_slot(full_bucket_slot)
	face(g, Vector3(-30, 1.7, 70), 0.0, -5.0)
	g._drop_active(false)
	var kb: Dictionary = g.ground[0]
	face(g, Vector3(-30, 1.7, kb.pos.z + 2.0), 0.0, -5.0)
	g.get_node("Player").position.x = kb.pos.x
	var had: int = kb.item.fish.size()
	g._start_kick()
	g.kick_charge = 0.8
	g._release_kick()
	check("kicking a placed bucket tips its fish out onto the ice", kb.item.fish.is_empty() and yard.count() == had)
	sim(g, 1.5)
	check("...and they stay out: the bucket does not swallow them straight back", kb.item.fish.is_empty() and yard.count() == had)
	yard.clear_all()
	g._remove_ground(kb)

	# --- the rack: tools you do not hold hang there
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.tool_item(1)
	g._hands_changed()
	check("the rack shows no tool you are carrying", not g.rack_mounts[0].visible and not g.rack_mounts[1].visible)
	g.inv.slots[0] = {}
	g._hands_changed()
	check("...and shows the drill once you put it down", g.rack_mounts[0].visible)
	g._click_rack(0)
	check("clicking the drill on the rack puts it in a free slot", g.inv.find_tool(0) >= 0 and g.tool == 0)
	g._click_rack(2)
	check("the kit stays on the rack, empty, until a build tool is unlocked", g.inv.find_tool(2) < 0)
	g.unlocked["t_auto"] = true
	g.unlocked["t_smoker"] = true
	g._refresh()
	check("once unlocked the kit hangs on the rack", g.rack_mounts[2].visible)
	g._click_rack(2)
	check("taking it uses the free slot; its mode starts on what you have unlocked", g.inv.find_tool(2) >= 0 and g.tool == 2)
	g._cycle_build()
	check("B switches what the kit builds", g.tool == 3)
	g.inv.slots[2] = {}
	g.inv.slots[2] = Inventory.bucket_item([g._make_fish(g.SPECIES[0])])
	g._click_rack(2)
	check("taking a tool with full hands swaps: your active item goes down", g.inv.find_tool(2) >= 0)
	g.unlocked["t_auto"] = false
	g.unlocked["t_smoker"] = false
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.tool_item(1)
	g._hands_changed()

	# --- deliver from your hand
	g.stats.eye_fed = 0
	hold(g, g._make_fish(g.SPECIES[1]))
	g._feed_by_hand()
	check("clicking the Eye with a fish in hand feeds it (moved to the throw queue)", g._held_fish().is_empty() and g.flying.size() == 1)
	await get_tree().create_timer(2.0).timeout
	check("...and it pays", g.stats.eye_fed == 1)
	# a bucketful in one click
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.bucket_item([g._make_fish(g.SPECIES[0]), g._make_fish(g.SPECIES[0]), g._make_fish(g.SPECIES[1])])
	g.inv.slots[2] = Inventory.fish_item(g._make_fish(g.SPECIES[0]))
	g._hands_changed()
	g.stats.eye_fed = 0
	g._feed_by_hand()
	check("clicking the Eye feeds everything you carry: the bucket's fish and the loose one", g.flying.size() == 4 and g.inv.cargo_count() == 0 and g.inv.slots[1].k == "bucket")
	await get_tree().create_timer(3.0).timeout
	check("...and all of them pay", g.stats.eye_fed == 4)

	# --- species orders, prompts, save
	g.inv.clear()
	g.inv.slots[0] = Inventory.tool_item(0)
	g.inv.slots[1] = Inventory.tool_item(1)
	hold(g, g._make_fish(g.SPECIES[1]))
	check("the prompt on the Eye says it will be put in", g._prompt_for("eye").contains("put it in"))
	check("Olga's prompt knows you carry fish", g._prompt_for("olga").contains("doesn't buy"))
	check("a held Perch counts as out of the lake for orders", g._species_held("Perch") >= 1)
	for leftover in g.ground.duplicate():
		g._remove_ground(leftover)
	g._place_ground(Inventory.bucket_item([g._make_fish(g.SPECIES[2])]), Vector3(-40, 0, 70), false)
	g.bmode = 1
	g._on_about_to_save()
	var sv: Dictionary = GameState.extra
	check("the slots, the bucket on the ice and its fish are saved", sv.slots.size() == 3 and sv.slots[2].k == "fish" and sv.ground.size() == 1 and sv.ground[0].item.fish.size() == 1 and sv.active == 2)
	g._remove_ground(g.ground[0])
	g.inv.clear()
	g._restore(sv)
	check("...and come back as they were (fish in slot 3, the bucket and its fish back on the ice)", g.inv.slots[2].k == "fish" and g.inv.slots[0].t == 0 and g.ground.size() == 1 and g.ground[0].item.fish.size() == 1 and g.bmode == 1)
	g._remove_ground(g.ground[0])
	empty_hand(g)

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
	g._select_slot(0)
	g._update_hand(0.016)
	check("with empty hands nothing hangs in front of you", not g.hold_node.visible)
	print("HANDS %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
