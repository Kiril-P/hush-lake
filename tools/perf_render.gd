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
	await action_phase(g, p)
	print("PERF %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)

func key_down(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

## Hitch hunt: walk, switch tools, kick a pile, build things and pick fish up, timing every frame. Spikes (first-time effects,
## shader compiles, spawn bursts) show up as frames far above the average.
func action_phase(g: Node, p: Node3D) -> void:
	p.position = Vector3(-30.0, 1.7, 14.0)
	p.rotation.y = deg_to_rad(-90.0)
	g.cam.rotation.x = deg_to_rad(-12.0)
	g.yard.clear_all()
	for i in 30:
		g.yard.spawn(g._make_fish(g.SPECIES[i % 4]), Vector3(-34 - (i % 6) * 0.9, 0.05, 14 + floorf(i / 6.0) * 0.9), Vector3.ZERO)
	var times: Array = []
	var labels: Array = []
	var step := func(label: String, frames: int):
		for i in frames:
			await get_tree().process_frame
			times.append(get_process_delta_time() * 1000.0)
			labels.append(label)
	await step.call("settle", 30)
	key_down(KEY_W, true)
	await step.call("walk", 90)
	key_down(KEY_W, false)
	for tk in [KEY_2, KEY_1, KEY_3, KEY_2, KEY_1, KEY_B]:
		g.unlocked["t_auto"] = true
		key_down(tk, true)
		key_down(tk, false)
		await step.call("tool swap", 12)
	g._start_kick()
	await step.call("kick charge", 20)
	g.kick_charge = 1.0
	g._release_kick()
	await step.call("kick + 30 fish sliding", 90)
	g._sweep_fish()
	await step.call("pickup", 20)
	var h: Dictionary = g._make_hole(Vector3(-20, 0, 30))
	await step.call("drill hole", 6)
	g._build_auto(h)
	await step.call("build auto-rod", 20)
	g._build_belt(h, false)
	await step.call("build belt", 20)
	g._install_machine(h, "cannery", false)
	await step.call("build cannery", 20)
	g._build_depot(Vector3(-50, 0, 10), false)
	await step.call("build depot", 20)
	for i in 70:   # overflow burst: more fish than the ice holds, each one fading out
		g.yard.spawn(g._make_fish(g.SPECIES[i % 4]), Vector3(-40 + (i % 10) * 1.1, 0.05, 40 + floorf(i / 10.0) * 1.1), Vector3(0, 6, 0))
	await step.call("70-fish burst", 60)
	var sorted := times.duplicate()
	sorted.sort()
	var worst := 0.0
	var worst_label := ""
	var spikes := 0
	for i in times.size():
		if times[i] > worst:
			worst = times[i]
			worst_label = labels[i]
		if times[i] > 25.0:
			spikes += 1
	print("PERF actions  frames %d  p99 %.2f ms  worst %.2f ms during '%s'  frames over 25 ms: %d" % [times.size(), sorted[int(sorted.size() * 0.99)], worst, worst_label, spikes])
	check("actions: no frame over 50 ms (a visible hitch)", worst <= 50.0)
	check("actions: at most 3 frames over 25 ms", spikes <= 3)
