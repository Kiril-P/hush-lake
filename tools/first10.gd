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
	"kick_tries": 0, "kick_hits": 0, "scan_time": 0.0, "stalls": 0, "stall_time": 0.0, "pushes": 0, "buys": []}
var last_progress := 0.0
var last_sig := ""
var stall_open := false
var frame_us := 0.0
var frames_n := 0
var last_us := 0
var last_print := -1
var hole_catches := {}   # hole idx -> bot-counted catches

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
	var now := Time.get_ticks_usec()
	frame_us += (now - last_us) / maxf(Engine.time_scale, 1.0)
	frames_n += 1
	last_us = now
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
	var sig := "%d %d %d %d %d %d" % [s.holes, s.caught, s.eye_fed, GameState.level("bucket"), s.autos, int(GameState.currency / 5.0)]
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
	# a new hole somewhere sensible: 3-5 m from where we stand, on legal ice (the game says "Too close..." otherwise)
	var p := flat(player.global_position)
	var spot := Vector3.ZERO
	var found := false
	for i in 40:
		var a := randf() * TAU
		var cand := p + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 5.0)
		if g._can_drill_at(cand):
			spot = cand
			found = true
			break
	if not found:
		await walk_to(p + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 1.0, 8.0)
		return
	await drill_at(spot)

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
	for i in 60:
		var a := randf() * TAU
		var r := randf_range(22.0, 34.0)
		var cand := Vector3(cos(a) * r, 0, sin(a) * r)
		if g._can_drill_at(cand):
			await walk_to(cand + (flat(player.global_position) - cand).normalized() * 3.5, 1.5, 40.0)
			await drill_at(cand)
			return
	await do_drill_near()

func best_hole() -> Dictionary:
	var best: Dictionary = {}
	var bd := 1e9
	for t in g.holes:
		if t.state != "hole" or g.model.tile_left(t.c) == 0:
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
		if h.state == "hole" and h.cast == 2:
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

func do_buy(id: String) -> void:
	var where: Variant = g.guide._resolve("stall:" + id)
	if where == null:
		return
	await walk_to(where, 4.0, 90.0)
	var board := Vector3(where.x, 1.6, where.z)
	await aim_click(board, "buy:" + id, 5.0)

func do_generic(st: Dictionary) -> void:
	# unlocked upgrades worth a walk (cheap, early): buy in a fixed order when affordable
	for id in ["bait", "kick", "boots", "drill"]:
		var u: Dictionary = g.UPGRADES[id]
		if GameState.level(id) == 0 and GameState.currency >= GameState.cost(id, u.base, u.growth) and g.stats.eye_fed >= 3:
			var l0 := GameState.level(id)
			await do_buy(id)
			if GameState.level(id) > l0:
				rep.buys.append("%s@%d" % [id, int(T)])
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
	var fps_ms := frame_us / maxf(float(frames_n), 1.0) / 1000.0
	print("REPORT first hole %s s, first cast %s s, first catch %s s, first feed %s s" % [rep.first_hole, rep.first_cast, rep.first_catch, rep.first_feed])
	print("REPORT bucket %s s, auto-rod %s s, belt %s s, purchases %s" % [rep.bucket, rep.auto_rod, rep.belt, rep.buys])
	print("REPORT fish fed %d, caught %d, coins %d, eye stage %d, holes %d" % [g.stats.eye_fed, g.stats.caught, int(GameState.currency), g.eye_stage(), g.holes.size()])
	print("REPORT pushes %d, kicks %d/%d hit, scan time %.1f s, stalls %d (%.0f s)" % [rep.pushes, rep.kick_hits, rep.kick_tries, rep.scan_time, rep.stalls, rep.stall_time])
	print("REPORT sim cost per frame (headless, whole game): %.2f ms" % fps_ms)
	# the bound checks: the opening must be quick and nothing may stall for long
	check("first catch within 90 s", rep.first_catch > 0.0 and rep.first_catch <= 90.0)
	check("first delivery to the Eye within 120 s", rep.first_feed > 0.0 and rep.first_feed <= 120.0)
	check("no more than 3 stalls in 10 minutes", rep.stalls <= 3)
	check("the bot made real progress: 20+ fish fed", g.stats.eye_fed >= 20)
	print("FIRST10 %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
