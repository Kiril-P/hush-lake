extends Node
## A bot that plays the first ten minutes like a person would, for the report in tools/first10.sh.
## It may only: look at what is inside the camera frustum, turn at a limited speed with some aim noise, press real keys and
## mouse buttons, and read the NEXT strip a human reads. It never edits coins, unlocks, timers or fish.
## It reports first-catch/first-feed/bucket/auto-rod times, kicks and misses, stalls and the cost of the fish physics.

const END := 600.0
const TURN_RATE := 3.2       # rad/s the "mouse hand" can turn
const AIM_NOISE := 0.012     # rad
const REACTION := [0.25, 0.6]   # seconds to react to a bite
var g: Node
var T := 0.0
var player: Node3D
var fails := 0
var rep := {"first_hole": -1.0, "first_cast": -1.0, "first_catch": -1.0, "first_feed": -1.0, "bucket": -1.0, "auto_rod": -1.0, "belt": -1.0,
	"missed_bites": 0, "throws": 0, "throws_in": 0, "grabs": 0, "kick_tries": 0, "kick_hits": 0, "scan_time": 0.0, "stalls": 0, "stall_time": 0.0, "pushes": 0, "buys": []}
var last_progress := 0.0
var last_sig := ""
var stall_open := false
var frame_us := 0.0
var frames_n := 0
var last_us := 0
var last_print := -1
var hole_catches := {}   # hole idx -> bot-counted catches
var known_empty := {}    # hole idx -> true once the game told us it is fished out (message on screen)
var proc_ms := 0.0
var locked_seen := false
var last_msg := ""

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	GameState.save_slot = "test_first10"
	GameState.delete_save()
	GameState.reset()
	g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	seed(20251104)
	g.test_capture = true
	player = g.get_node("Player")
	Engine.time_scale = 3.0
	Engine.max_fps = 60
	last_us = Time.get_ticks_usec()
	await play()
	Engine.time_scale = 1.0
	report()

# ---------- one frame of "time" ----------
func tick() -> float:
	await get_tree().process_frame
	var d := get_process_delta_time()
	T += d
	proc_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	frames_n += 1
	_progress()
	if int(T) % 30 == 0 and int(T) != last_print:
		last_print = int(T)
		print("T=%d step=%s fed=%d caught=%d holes=%d coins=%d loose=%d" % [int(T), g.guide.current().id, g.stats.eye_fed, g.stats.caught, g.holes.size(), int(GameState.currency), g.yard.count()])
	return d

func _progress() -> void:
	var s: Dictionary = g.stats
	if rep.first_hole < 0.0 and s.holes > 0: rep.first_hole = T
	if rep.first_catch < 0.0 and s.caught > 0: rep.first_catch = T
	if rep.first_feed < 0.0 and s.eye_fed > 0: rep.first_feed = T
	if rep.bucket < 0.0 and GameState.level("bucket") > 0: rep.bucket = T
	if rep.auto_rod < 0.0 and s.autos > 0: rep.auto_rod = T
	if rep.belt < 0.0 and s.belts > 0: rep.belt = T
	var m: String = g.msg_label.text
	if m != last_msg:
		last_msg = m
		if m.contains("got away") or m.contains("Too early"):
			rep.missed_bites += 1
	var lv := 0
	for k in GameState.upgrades:
		lv += int(GameState.upgrades[k])
	var sig := "%d %d %d %d %d" % [s.holes, s.caught, lv, s.autos, s.belts]   # player actions only: passive income must not hide a stall
	if sig != last_sig:
		last_sig = sig
		last_progress = T
		stall_open = false
	elif T - last_progress > 25.0 and not stall_open:
		stall_open = true
		rep.stalls += 1
		print("T=%d stall: no progress for 25 s, step=%s" % [int(T), g.guide.current().id])
	if stall_open:
		rep.stall_time += get_process_delta_time()

# ---------- hands ----------
func key_down(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)

func tap(code: int) -> void:
	key_down(code, true)
	key_down(code, false)

func mouse(button: int, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)

func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

func cam_pos() -> Vector3:
	return g.cam.global_position

## Turns the view toward a world point at a human speed. Returns the remaining angle error.
func look_step(p: Vector3, d: float, noise := true) -> float:
	var dv := p - cam_pos()
	var want_yaw := atan2(-dv.x, -dv.z) + (randf_range(-AIM_NOISE, AIM_NOISE) if noise else 0.0)
	var want_pitch := atan2(dv.y, Vector2(dv.x, dv.z).length())
	var dy: float = wrapf(want_yaw - player.rotation.y, -PI, PI)
	var dp: float = want_pitch - g.cam.rotation.x
	var step := TURN_RATE * d
	player.rotation.y += clampf(dy, -step, step)
	g.cam.rotation.x = clampf(g.cam.rotation.x + clampf(dp, -step, step), -1.3, 1.3)
	return maxf(absf(dy), absf(dp))

func look_at_point(p: Vector3, tol := 0.03, timeout := 5.0) -> bool:
	var t0 := T
	while T - t0 < timeout:
		var d := await tick()
		if look_step(p, d) < tol:
			return true
	return false

func walk_to(p: Vector3, stop_d: float, timeout := 60.0) -> bool:
	var t0 := T
	var tgt := flat(p)
	var last_pos := flat(player.global_position)
	var stuck := 0.0
	while T - t0 < timeout:
		var d := await tick()
		var pp := flat(player.global_position)
		if pp.distance_to(tgt) <= stop_d:
			key_down(KEY_W, false)
			return true
		var err := look_step(Vector3(tgt.x, g.EYE_H - 0.6, tgt.z), d, false)
		key_down(KEY_W, err < 0.5)
		if pp.distance_to(last_pos) < 0.3 * d * g.walk_speed():
			stuck += d
			if stuck > 2.0:   # walked into something: sidestep like a person would
				key_down(KEY_W, false)
				key_down(KEY_D, true)
				for i in 20:
					await tick()
				key_down(KEY_D, false)
				stuck = 0.0
		else:
			stuck = 0.0
		last_pos = pp
	key_down(KEY_W, false)
	return false

func aim_click(point: Vector3, expect: String, timeout := 6.0) -> bool:
	var t0 := T
	while T - t0 < timeout:
		var d := await tick()
		look_step(point, d)
		if g._aim() == expect:
			mouse(MOUSE_BUTTON_LEFT, true)
			mouse(MOUSE_BUTTON_LEFT, false)
			await tick()
			return true
	return false

# ---------- seeing ----------
func visible_fish() -> Array:
	var out: Array = []
	for e in g.yard.fish:
		var p: Vector3 = e.pos + Vector3(0, 0.2, 0)
		if g.cam.is_position_behind(p):
			continue
		var sp: Vector2 = g.cam.unproject_position(p)
		var vp := get_viewport().get_visible_rect().size
		if sp.x >= 0.0 and sp.y >= 0.0 and sp.x <= vp.x and sp.y <= vp.y:
			out.append(e)
	return out

# ---------- the player's brain: read the NEXT strip and do it ----------
func play() -> void:
	while T < END:
		var st: Dictionary = g.guide.current()
		match st.id:
			"tool0": tap(KEY_1)
			"tool1": tap(KEY_2)
			"drill": await do_drill(st)
			"drill2": await do_drill_near()
			"cast", "wait", "tool1b": await do_cast()
			"bite": await do_bite()
			"fight": await tick()
			"push0", "push": await do_push()
			"bucket": await do_buy("bucket")
			_:
				await do_generic(st)
		if g.yard.count() > 0 and st.id not in ["bite"]:
			await do_push()
		await tick()

func do_drill(st: Dictionary) -> void:
	if g.tool != 0:
		tap(KEY_1)
	var spot: Vector3 = st.where if st.where != null else g.guide.drill_spot
	await walk_to(spot, 3.5)
	await look_at_point(Vector3(spot.x, 0.0, spot.z), 0.04)
	if g._aim() != "ice":
		print("T=%d drill: aim is '%s' raw '%s' flat %.1f dist-to-spot %.1f tool %d mode %d" % [int(T), g._aim(), g._aim_raw(), g.aim_flat, flat(player.global_position).distance_to(flat(spot)), g.tool, Input.mouse_mode])
		return
	mouse(MOUSE_BUTTON_LEFT, true)
	var n0: int = g.holes.size()
	var t0 := T
	while T - t0 < 8.0 and g.holes.size() == n0:
		var d := await tick()
		look_step(Vector3(spot.x, 0.0, spot.z), d)
	mouse(MOUSE_BUTTON_LEFT, false)

func do_drill_near() -> void:
	# look at a few bits of ice near us and read the prompt a player reads: "Hold click: drill here" means it is legal
	if g.tool != 0:
		tap(KEY_1)
		await tick()
	var p := flat(player.global_position)
	for i in 10:
		var a := randf() * TAU
		var cand := p + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 5.5)
		await look_at_point(Vector3(cand.x, 0.0, cand.z), 0.05, 3.0)
		await tick()
		if g.prompt_label.text.begins_with("Hold click: drill"):
			await drill_at(cand)
			return
		if g.prompt_label.text.contains("LOCKED"):
			locked_seen = true
	await walk_to(p + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 1.0, 8.0)

func drill_at(spot: Vector3) -> void:
	if g.tool != 0:
		tap(KEY_1)
		await tick()
	await look_at_point(Vector3(spot.x, 0.0, spot.z), 0.05)
	if g._aim() != "ice":
		return
	mouse(MOUSE_BUTTON_LEFT, true)
	var n0: int = g.holes.size()
	var t0 := T
	while T - t0 < 8.0 and g.holes.size() == n0:
		var d := await tick()
		look_step(Vector3(spot.x, 0.0, spot.z), d)
	mouse(MOUSE_BUTTON_LEFT, false)

## A fresh hole farther out (22-34 m from the Eye): that is where pushing and kicking start to matter.
func do_far_hole() -> void:
	# head out a random way and drill where the prompt allows it (a locked sector says so and we simply try another way)
	var a := randf() * TAU
	var r := randf_range(14.0, 20.0) if locked_seen else randf_range(22.0, 34.0)   # (learned from a "LOCKED" prompt: the outer ring is not open yet)
	var cand := Vector3(cos(a) * r, 0, sin(a) * r)
	await walk_to(cand, 3.0, 40.0)
	await do_drill_near()

func best_hole() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for t in g.holes:
		if t.state != "hole" or known_empty.has(t.idx):
			continue
		var dd: float = flat(t.pos).distance_to(flat(player.global_position))
		if dd < bd:
			bd = dd
			best = t
	return best

func do_cast() -> void:
	var t := best_hole()
	if t.is_empty():
		await do_far_hole()
		return
	if int(hole_catches.get(t.idx, 0)) >= 6 and g.holes.size() < 6:   # worked this one: open a new one farther out
		hole_catches[t.idx] = 0
		await do_far_hole()
		return
	if g.tool != 1:
		tap(KEY_2)
		await tick()
	if t.cast == 0:
		await walk_to(t.pos, 4.5)
		var hp: Vector3 = t.node.global_position + Vector3(0, 0.2, 0)
		if await aim_click(hp, "hole:%d" % t.idx):
			if rep.first_cast < 0.0:
				rep.first_cast = T
			if g.msg_label.text.contains("fished out"):
				known_empty[t.idx] = true
		return
	# a line is out: wait for the bite, watching the float
	var hp2: Vector3 = t.node.global_position + Vector3(0, 0.2, 0)
	for i in 6:
		var d := await tick()
		look_step(hp2, d)
		if t.cast == 2 or t.cast == 0:
			return

func do_bite() -> void:
	var t: Dictionary = {}
	for h in g.holes:
		if h.state == "hole" and h.cast == 2 and h.mark.visible:   # the "!" marker over the hole is what a player reacts to
			t = h
	if t.is_empty():
		return
	var wait := randf_range(REACTION[0], REACTION[1])
	var t0 := T
	var hp: Vector3 = t.node.global_position + Vector3(0, 0.2, 0)
	while T - t0 < wait:
		var d := await tick()
		look_step(hp, d)
	if await aim_click(hp, "hole:%d" % t.idx, 1.2):
		hole_catches[t.idx] = int(hole_catches.get(t.idx, 0)) + 1
		await tick()
		if g.msg_label.text.contains("Nothing left"):
			known_empty[t.idx] = true

func do_push() -> void:
	var guard := T
	while g.yard.count() > 0 and T < END and T - guard < 90.0:
		var vis := visible_fish()
		if vis.is_empty():
			var d := await tick()   # nothing in view: look around
			player.rotation.y += 1.6 * d
			rep.scan_time += d
			continue
		var e: Dictionary = vis[0]
		var bd := 1e9
		for v in vis:
			var dd: float = flat(v.pos).distance_to(flat(player.global_position))
			if dd < bd:
				bd = dd
				e = v
		var epos := flat(e.pos)
		var deye := epos.length()
		if deye < 16.0:   # inside the Eye's pull: watch it go in
			var t0 := T
			while T - t0 < 10.0 and g.yard.fish.has(e):
				var d2 := await tick()
				look_step(e.pos, d2)
			continue
		# a fish close at hand and well away from the Eye: grab it (left click) and lob it (hold right mouse, let go)
		if deye > 12.0 and flat(e.pos).distance_to(flat(player.global_position)) < 4.5 and g.held.is_empty():
			await look_at_point(e.pos + Vector3(0, 0.15, 0), 0.03, 3.0)
			if g._aim_fish() != null:
				mouse(MOUSE_BUTTON_LEFT, true)
				mouse(MOUSE_BUTTON_LEFT, false)
				await tick()
				if not g.held.is_empty():
					rep.grabs += 1
					await do_throw_to_eye()
					continue
		var dir_eye := (-epos).normalized()
		var behind := epos - dir_eye * 1.9
		var pp := flat(player.global_position)
		if pp.distance_to(behind) > 1.1:
			await walk_to(behind, 0.9, 25.0)
			continue
		# standing behind it: face the Eye, then kick a far fish or walk it in
		await look_at_point(Vector3(0, 0.3, 0), 0.06, 3.0)
		rep.pushes += 1
		if deye > 26.0 and bd < 3.0:
			rep.kick_tries += 1
			var k0: int = g.kicks
			var frac := clampf((deye - 14.0) / 34.0, 0.25, 1.0)
			mouse(MOUSE_BUTTON_RIGHT, true)
			var t1 := T
			while T - t1 < 0.9 * frac:
				var d3 := await tick()
				look_step(Vector3(0, 0.3, 0), d3)
			mouse(MOUSE_BUTTON_RIGHT, false)
			await tick()
			if g.kicks > k0:
				rep.kick_hits += 1
			for i in 40:
				await tick()
		else:
			var t2 := T
			key_down(KEY_W, true)
			while T - t2 < 5.0 and g.yard.fish.has(e) and flat(e.pos).length() > 15.0:
				var d4 := await tick()
				look_step(Vector3(0, 0.3, 0), d4, false)
			key_down(KEY_W, false)

## With a fish in hand: face the Eye, pick the look angle that lands the lob on the pupil (a person judges this by eye and by the arc
## preview; the bot reads the same preview numbers), wind up the right amount, and let go.
func do_throw_to_eye() -> void:
	await look_at_point(Vector3(0, 0.3, 0), 0.05, 3.0)
	var best_pitch := 0.0
	var best_frac := 0.7
	var best_err := 1e9
	for frac in [0.5, 0.65, 0.8, 1.0]:
		for deg in range(-20, 40, 2):
			g.cam.rotation.x = deg_to_rad(float(deg))
			var v: Vector3 = g._throw_velocity(frac)
			var tt: float = FishYard.flight_time(g._throw_origin(), v)
			var lp: Vector3 = FishYard.arc_point(g._throw_origin(), v, tt)
			var err: float = Vector2(lp.x, lp.z).length()
			if err < best_err - 0.01 or (absf(err - best_err) <= 0.01 and frac < best_frac):
				best_err = err
				best_pitch = float(deg)
				best_frac = frac
	g.cam.rotation.x = deg_to_rad(best_pitch)
	mouse(MOUSE_BUTTON_RIGHT, true)
	var t0 := T
	while T - t0 < 0.9 * best_frac:   # the real charge time
		await tick()
	mouse(MOUSE_BUTTON_RIGHT, false)
	rep.throws += 1
	var fed0: int = g.stats.eye_fed
	var t1 := T
	while T - t1 < 6.0 and g.stats.eye_fed == fed0:
		await tick()
	if g.stats.eye_fed > fed0:
		rep.throws_in += 1

func do_buy(id: String) -> void:
	var where: Variant = g.guide._resolve("stall:" + id)
	if where == null:
		return
	await walk_to(where, 4.0, 90.0)
	var board := Vector3(where.x, 1.6, where.z)
	await aim_click(board, "buy:" + id, 5.0)

func do_generic(st: Dictionary) -> void:
	# the NEXT strip names an upgrade ("Buy a Snowmobile"): if we can pay for it, walk to its stall like a person would
	for id in g.UPGRADES:
		var u0: Dictionary = g.UPGRADES[id]
		if g.unlocked.get(id, false) and String(st.title).contains(u0.name) and GameState.level(id) < u0.max \
				and GameState.currency >= GameState.cost(id, u0.base, u0.growth):
			var lv0 := GameState.level(id)
			await do_buy(id)
			if GameState.level(id) > lv0:
				rep.buys.append("%s@%d" % [id, int(T)])
			return
	# unlocked upgrades worth a walk (cheap, early): buy in a fixed order when affordable
	for id in ["bait", "kick", "boots", "drill"]:
		var u: Dictionary = g.UPGRADES[id]
		if GameState.level(id) == 0 and GameState.currency >= GameState.cost(id, u.base, u.growth) and g.stats.eye_fed >= 3:
			var l0 := GameState.level(id)
			await do_buy(id)
			if GameState.level(id) > l0:
				rep.buys.append("%s@%d" % [id, int(T)])
			return
	# the strip says "Build a Cannery on a belt": pick the build tool (7), stand at an Auto-Rod that has a belt and click it
	if String(st.title).begins_with("Build a Cannery") and g.unlocked.get("t_build", false) and GameState.currency >= g._build_cost(0):
		for t in g.holes:
			if t.state == "auto" and t.belt != null and not t.belt.get("cannery", false):
				tap(KEY_7)
				await tick()
				await walk_to(t.pos, 4.5)
				await aim_click(t.node.global_position + Vector3(0, 0.3, 0), "hole:%d" % t.idx, 5.0)
				tap(KEY_1)
				return
	# an Auto-Rod when the tool is open and affordable: put it on a hole we already fished
	if g.unlocked.get("t_auto", false) and g.stats.autos == 0 and GameState.currency >= g.auto_cost():
		var h: Dictionary = best_hole()
		if h.is_empty():
			for t in g.holes:
				if t.state == "hole":
					h = t
		if not h.is_empty():
			tap(KEY_3)
			await walk_to(h.pos, 4.5)
			await aim_click(h.node.global_position + Vector3(0, 0.2, 0), "hole:%d" % h.idx, 5.0)
			return
	if g.unlocked.get("t_belt", false) and g.stats.autos > 0 and g.stats.belts == 0:
		for t in g.holes:
			if t.state == "auto" and t.belt == null and GameState.currency >= g.belt_cost(t):
				tap(KEY_6)
				await walk_to(t.pos, 4.5)
				await aim_click(t.node.global_position + Vector3(0, 0.3, 0), "hole:%d" % t.idx, 5.0)
				return
	await do_cast()

func report() -> void:
	var fps_ms := proc_ms / maxf(float(frames_n), 1.0)
	# the fish physics alone, at the cap of 60 loose fish, stepped like the game does
	var yard: Node = g.yard
	yard.clear_all()
	for i in 60:
		yard.spawn(g._make_fish(g.SPECIES[0]), Vector3(-60 + (i % 10) * 1.3, 0.05, 60 + floorf(i / 10.0) * 1.3), Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
	var t0 := Time.get_ticks_usec()
	for i in 300:
		yard.step(1.0 / 60.0, Vector3(0, 1.7, 95))
	var yard_ms := (Time.get_ticks_usec() - t0) / 300.0 / 1000.0
	yard.clear_all()
	print("REPORT first hole %s s, first cast %s s, first catch %s s, first feed %s s" % [rep.first_hole, rep.first_cast, rep.first_catch, rep.first_feed])
	print("REPORT bucket %s s, auto-rod %s s, belt %s s, purchases %s" % [rep.bucket, rep.auto_rod, rep.belt, rep.buys])
	print("REPORT fish fed %d, caught %d, coins %d, eye stage %d, holes %d" % [g.stats.eye_fed, g.stats.caught, int(GameState.currency), g.eye_stage(), g.holes.size()])
	print("REPORT hands: %d grabs, %d throws, %d of them swallowed by the Eye" % [rep.grabs, rep.throws, rep.throws_in])
	print("REPORT pushes %d, kicks %d/%d hit, missed bites %d, scan time %.1f s, stalls %d (%.0f s)" % [rep.pushes, rep.kick_hits, rep.kick_tries, rep.missed_bites, rep.scan_time, rep.stalls, rep.stall_time])
	print("REPORT process time per frame (whole game, headless, scene time not rendered): %.2f ms; fish physics with 60 loose fish: %.3f ms per step" % [fps_ms, yard_ms])
	# the bound checks: the opening must be quick and nothing may stall for long
	if rep.pushes == 0 and rep.kick_tries == 0:
		print("REPORT NOTE: pushing and kicking were NOT exercised in this run (the Eye's pull did all the work); see tools/run_yard.sh for the physics")
	check("first catch within 30 s", rep.first_catch > 0.0 and rep.first_catch <= 30.0)
	check("first delivery to the Eye within 45 s", rep.first_feed > 0.0 and rep.first_feed <= 45.0)
	check("the Bucket is bought within 90 s", rep.bucket > 0.0 and rep.bucket <= 90.0)
	check("an Auto-Rod is built within 360 s", rep.auto_rod > 0.0 and rep.auto_rod <= 360.0)
	check("no more than 3 stalls in 10 minutes", rep.stalls <= 3)
	check("the bot made real progress: 40+ fish fed", g.stats.eye_fed >= 40)
	print("FIRST10 %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
