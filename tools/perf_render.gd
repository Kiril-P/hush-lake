extends Node
## Rendered frame-time check (needs a window; vsync off so we see the real cost): a busy late-game lake from three viewpoints.
## Run: tools/perf_render.sh   Prints avg / p95 / worst frame time and draw calls. Fails if the average is over budget.

const BUDGET_AVG_MS := 16.7
const BUDGET_P95_MS := 25.0
var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func measure(label: String, g: Node, frames := 240) -> void:
	for i in 40:
		await get_tree().process_frame
	var times: Array = []
	var calls := 0
	var objs := 0
	for i in frames:
		await get_tree().process_frame
		times.append(get_process_delta_time() * 1000.0)
		calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		objs = maxi(objs, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))
	times.sort()
	var sum := 0.0
	for t in times:
		sum += t
	var avg := sum / times.size()
	var p95: float = times[int(times.size() * 0.95)]
	print("PERF %-10s avg %.2f ms (%.0f fps)  p95 %.2f  worst %.2f  draw calls %d  objects %d" % [label, avg, 1000.0 / avg, p95, times[times.size() - 1], calls, objs])
	check("%s: average frame under %.1f ms" % [label, BUDGET_AVG_MS], avg <= BUDGET_AVG_MS)
	check("%s: p95 frame under %.0f ms" % [label, BUDGET_P95_MS], p95 <= BUDGET_P95_MS)

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	GameState.save_slot = "test_perf"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	GameState.currency = 99999.0
	for k in ["t_auto", "t_belt", "t_build", "t_smoker", "t_table"]:
		g.unlocked[k] = true
	for id in g.model.sectors:
		g.model.sectors[id].unlocked = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 0
	for c in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(1, 1), Vector2i(-1, -1)]:
		var h: Dictionary = g._make_hole(g._hex_pos(c) * 1.3)
		if h.is_empty():
			continue
		g._build_auto(h)
		g._build_belt(h, false)
		if n % 2 == 0:
			g._install_machine(h, "cannery", false)
		else:
			g._install_machine(h, "sorter", false)
		for k in 18:
			g._belt_spawn(h, g._make_fish(g.SPECIES[rng.randi() % 4]))
			g.belt_fish[g.belt_fish.size() - 1].d = rng.randf() * h.belt.len
		n += 1
	g._build_depot(Vector3(-17.5, 0, 0), false)
	g._build_rig(g._hex_pos(Vector2i(2, 1)) * 1.1, false)
	g._build_rig(g._hex_pos(Vector2i(-2, -1)) * 1.1, false)
	for k in 12:
		g._belt_push(g.rigs[k % 2].belt, g._make_fish(g.SPECIES[rng.randi() % 3]))
	for i in 60:
		g.yard.spawn(g._make_fish(g.SPECIES[i % 4]), Vector3(-30 + (i % 10) * 1.2, 0.05, 20 + floorf(i / 10.0) * 1.2), Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2)))
	g.stats.eye_fed = 8000
	g.eye_seen_stage = g.eye_stage()
	g.scenery.set_eye_stage(4)
	g.scenery.set_eye_open(g.eye_open_frac())
	g.goal_done.fill(true)
	var p: Node3D = g.get_node("Player")
	var views := [["camp", Vector3(-8.2, 1.7, 14.3), -30.0, -5.0], ["machines", Vector3(24, 1.7, 22), 110.0, -8.0], ["aerial", Vector3(0, 60.0, 120), 0.0, -30.0]]
	for v in views:
		p.position = v[1]
		p.rotation.y = deg_to_rad(v[2])
		g.cam.rotation.x = deg_to_rad(v[3])
		await measure(v[0], g)
	print("PERF %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
