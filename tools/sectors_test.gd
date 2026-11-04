extends Node
## Headless test for how sectors are drawn: every sector has a closed 18-edge outline, each shared edge is drawn exactly once
## (by the sector that matters more), state changes restyle the right pieces, and the HUD pill names the sector you look at.
## Run: tools/run_sectors.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	GameState.save_slot = "test_sectors"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	var v: SectorView = g.sector_view
	var model = g.model
	check("there is one patch per sector (19)", v.patches.size() == 19 and model.sectors.size() == 19)
	var all_18 := true
	for id in v.edges:
		if v.edges[id].size() != 18:
			all_18 = false
	check("every sector outline is 18 hex edges (the perimeter of a 7-tile flower)", all_18)
	# an edge shared by two sectors appears in both lists, once each
	var shared_ok := true
	var shared := 0
	for id in v.edges:
		for e in v.edges[id]:
			if e.other == null:
				continue
			shared += 1
			var found := false
			for e2 in v.edges[e.other]:
				if e2.other == id and ((e2.a - e.a).length() < 0.01 and (e2.b - e.b).length() < 0.01 or (e2.a - e.b).length() < 0.01 and (e2.b - e.a).length() < 0.01):
					found = true
			if not found:
				shared_ok = false
	check("shared edges match up exactly between neighbouring sectors (%d of them)" % shared, shared_ok and shared > 0)
	# ownership: each shared edge is drawn by exactly one of the two sectors
	var owned_total := 0
	var edges_total := 0
	for id in v.edges:
		owned_total += v.owned_edges(id).size()
		edges_total += v.edges[id].size()
	var outer := 0
	for id in v.edges:
		for e in v.edges[id]:
			if e.other == null:
				outer += 1
	check("every shared edge is drawn once, every lake-edge segment once", owned_total == (edges_total - outer) / 2 + outer)

	# initial state: only the Shallows is open
	var locked := 0
	for id in v.states:
		if v.states[id] == 0:
			locked += 1
	check("at the start 18 sectors are frosted and the Shallows is open", locked == 18 and v.states[Vector2i.ZERO] == 1)
	check("frost is visible on a locked sector and not on the open one", v.patches[Vector2i(1, 0)].frost.visible and not v.patches[Vector2i.ZERO].frost.visible)
	check("the open Shallows' border belongs to the locked neighbours (white wins)", v.owned_edges(Vector2i.ZERO).size() == 0 or v.owned_edges(Vector2i.ZERO).all(func(e): return e.st == 1))
	var gates := 0
	for id in v.patches:
		for e in v.owned_edges(id):
			if e.gate:
				gates += 1
	check("the gate curtain stands exactly where a locked sector meets open ground (%d edges)" % gates, gates > 0)

	# unlock one: frost goes, the border flashes and restyles
	var nid: Vector2i = Vector2i(1, 0)
	for id in model.sectors:
		if model.sectors[id].ring == 1:
			nid = id
			break
	model.sectors[nid].unlocked = true
	g._update_sector_labels()
	check("an unlocked sector loses its frost", not v.patches[nid].frost.visible and v.states[nid] == 1)
	var ghost_exists := false
	for c in v.get_children():
		if c is MeshInstance3D and c.mesh == v.patches[nid].frost.mesh and c != v.patches[nid].frost and c != v.patches[nid].thaw:
			ghost_exists = true
	check("the frost melts away instead of vanishing (a fading copy is left behind)", ghost_exists)
	# clear it: thawed water and a gold border
	model.sectors[nid].cleared = true
	g._update_sector_labels()
	check("a cleared sector shows thawed water", v.patches[nid].thaw.visible and v.states[nid] == 2)
	var cleared_edges: Array = v.owned_edges(nid)
	check("...and owns its border edges toward open ground in gold", cleared_edges.size() > 0 and cleared_edges.all(func(e): return e.st == 2))
	# the minimap uses the same edges
	check("the minimap draws the same owned edges", g.map_ctrl.game.sector_view == v)

	# HUD pill: names the sector under your feet or crosshair
	g.aim_flat = 9999.0
	g.aim_pos = Vector3.ZERO
	g.sector_hud_t = 0.0
	g.get_node("Player").position = Vector3(-8.2, 1.7, 14.3)
	g._update_sector_hud(1.0)
	check("the pill names the Shallows and its fish count", g.sector_hud_label.text.begins_with("The Shallows") and "fish left" in g.sector_hud_label.text)
	var far_cell: Vector2i = model.sectors[Vector2i(1, 0)].center
	for id in model.sectors:
		if not model.sectors[id].unlocked:
			far_cell = model.sectors[id].center
			break
	g.aim_flat = 3.0
	g.aim_pos = g._hex_pos(far_cell)
	g.sector_hud_t = 0.0
	g._update_sector_hud(1.0)
	check("looking at a closed sector the pill says LOCKED and its name", g.sector_hud_label.text.begins_with("LOCKED"))
	model.sectors[nid].cleared = true
	g.aim_pos = g._hex_pos(model.sectors[nid].center)
	g.sector_hud_t = 0.0
	g._update_sector_hud(1.0)
	check("and a cleared sector says cleared", "cleared" in g.sector_hud_label.text)
	print("SECTORS %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
