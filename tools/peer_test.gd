extends Node
## Headless test for peering into a hole: what is down there (a pure plan from the tile's stock), the window opening and closing, the
## junk on the bottom, the Eye's glow, and the input rules (C near a hole opens it; far away or at a panel it does not; clicks and walking are blocked meanwhile).
## Run: tools/run_peer.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	check("an empty tile has nothing in the water", PeerView.fish_plan({}, rng).is_empty())
	var small := PeerView.fish_plan({"Minnow": 3}, rng)
	check("a tile with 3 minnows shows exactly 3", small.size() == 3 and small.all(func(f): return f.name == "Minnow" and not f.junk))
	var big := PeerView.fish_plan({"Minnow": 400, "Perch": 100, "Old Boot": 20}, rng)
	check("a full tile shows at most %d fish" % PeerView.MAX_FISH, big.size() == PeerView.MAX_FISH)
	var mix := {"Minnow": 0, "Perch": 0, "Old Boot": 0}
	for i in 200:
		for f in PeerView.fish_plan({"Minnow": 700, "Perch": 250, "Old Boot": 50}, rng):
			mix[f.name] += 1
	var tot := float(mix.Minnow + mix.Perch + mix.get("Old Boot"))
	check("the picture follows the stock (minnow %.0f%%, perch %.0f%%, boot %.0f%%; stock 70/25/5)" % [100.0 * mix.Minnow / tot, 100.0 * mix.Perch / tot, 100.0 * mix["Old Boot"] / tot], absf(mix.Minnow / tot - 0.7) < 0.06 and absf(mix.Perch / tot - 0.25) < 0.06 and mix["Old Boot"] / tot < 0.1)
	var a := PeerView.fish_plan({"Minnow": 50, "Perch": 50}, RandomNumberGenerator.new())
	check("junk is flagged so it lies on the bottom", PeerView.fish_plan({"Old Coin": 2}, rng).all(func(f): return f.junk))
	# the window
	var pv := PeerView.new()
	add_child(pv)
	pv.colors = {"Minnow": Color(0.7, 0.8, 0.9), "Perch": Color(0.5, 0.8, 0.6), "Old Boot": Color(0.4, 0.3, 0.2)}
	check("closed it is invisible and does not render", not pv.visible and pv.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	pv.open({"Minnow": 30, "Perch": 10, "Old Boot": 4}, false)
	check("opening fills the water (%d swimmers, %d junk) and starts rendering" % [pv.fish_count(), pv.junk_nodes.size()], pv.fish_count() + pv.junk_nodes.size() == 24 and pv.visible and pv.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS)
	for i in 30:
		pv.update(0.05)
	check("the window fades in", pv.open_amount >= 0.99)
	var y0 := (pv.fish_nodes[0].node as Node3D).position
	for i in 40:
		pv.update(0.05)
	check("fish swim (they move between frames)", (pv.fish_nodes[0].node as Node3D).position.distance_to(y0) > 0.3)
	var inside := true
	for f in pv.fish_nodes:
		var p: Vector3 = (f.node as Node3D).position
		if p.y > -1.0 or p.y < PeerView.FLOOR_Y or Vector2(p.x, p.z).length() > 9.0:
			inside = false
	check("every fish stays in the water, above the floor", inside)
	check("no eye glow away from the Eye", pv.glow_light.light_energy == 0.0)
	pv.close()
	for i in 40:
		pv.update(0.05)
	check("closing fades the window out and stops rendering", not pv.visible and pv.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	pv.open({"Minnow": 5}, true)
	for i in 10:
		pv.update(0.05)
	check("near the Eye the bottom glows amber", pv.glow_light.light_energy > 1.0)
	pv.open({"Perch": 4}, false)
	check("opening again replaces the old life (no leak): 4 fish", pv.fish_count() == 4 and pv.junk_nodes.is_empty())
	# in the game
	GameState.save_slot = "test_peer"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var h: Dictionary = g._make_hole(g._hex_pos(Vector2i(1, 0)) * 1.25)
	var raw := "hole:%d" % h.idx
	g.aim_flat = 2.0
	g.peer_test_hold = false
	g._update_peer(0.05, raw)
	check("without C nothing opens", not g.peer.want_open)
	g.peer_test_hold = true
	g.aim_flat = 9.0
	g._update_peer(0.05, raw)
	check("C too far from the hole (9 m) does nothing", not g.peer.want_open)
	g.aim_flat = 2.0
	g._update_peer(0.05, "ice")
	check("C while looking at plain ice does nothing", not g.peer.want_open)
	g._update_peer(0.05, raw)
	check("C beside a hole opens the window on that tile's stock (%d things below)" % (g.peer.fish_count() + g.peer.junk_nodes.size()), g.peer.want_open and g.peer.fish_count() + g.peer.junk_nodes.size() > 0 and g.peer_cell == h.c)
	check("while peering, clicks and walking are blocked", g._overlay_blocks_click() and g._overlay_blocks_walk())
	g.peer_test_hold = false
	g._update_peer(0.05, raw)
	check("letting go closes it", not g.peer.want_open and not g._overlay_blocks_click())
	g.model.stock[h.c] = {}
	g.peer_test_hold = true
	g._update_peer(0.05, raw)
	check("a fished-out tile shows empty water", g.peer.want_open and g.peer.fish_count() == 0 and g.peer.junk_nodes.is_empty())
	g.peer_test_hold = false
	g._update_peer(0.05, raw)
	g.letters_panel.visible = true
	g.peer_test_hold = true
	g._update_peer(0.05, raw)
	check("with a letter open C does not peer", not g.peer.want_open)
	g.letters_panel.visible = false
	g.peer_test_hold = false
	print("PEER %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
