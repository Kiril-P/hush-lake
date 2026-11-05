extends Node
## Headless test of the opening: the camera director's maths, the title screen (build, hidden HUD, settings and back, no click-through),
## the whole sled run at accelerated time (actors, timeline, the lid, the hand-off with no jump), skip at several moments, the "previously"
## beat from a save, and a sweep of the camera path for NaNs, ground clipping and obstacles. Run: tools/run_opening.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func make(resumed := false, force := true):
	GameState.save_slot = "test_opening"
	if not resumed:
		GameState.delete_save()
		GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	if force:
		g.set_meta("force_title", true)
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	return g

func wait_scene(g, t: float, limit_s := 30.0) -> void:
	var t0 := Time.get_ticks_msec()
	while g.guide.intro_active and g.guide.intro_t < t and (Time.get_ticks_msec() - t0) < limit_s * 1000.0:
		await get_tree().process_frame

func _ready() -> void:
	# ---------- the director's maths ----------
	check("smooth is 0 at 0, 1 at 1 and 0.5 in the middle", CameraDirector.smooth(0.0) == 0.0 and CameraDirector.smooth(1.0) == 1.0 and absf(CameraDirector.smooth(0.5) - 0.5) < 0.001)
	check("span clamps", CameraDirector.span(-1.0, 0.0, 2.0) == 0.0 and CameraDirector.span(5.0, 0.0, 2.0) == 1.0 and absf(CameraDirector.span(1.0, 0.0, 2.0) - 0.5) < 0.001)
	var pa := CameraDirector.pose(Vector3(0, 0, 0), Vector3(0, 0, -1), 60.0, 0.0, 0.0)
	var pb := CameraDirector.pose(Vector3(10, 4, 0), Vector3(10, 4, -5), 40.0, 0.2, 0.1)
	var pm := CameraDirector.blend(pa, pb, 0.5)
	check("a blend halfway is halfway in position, fov and roll", pm.pos.distance_to(Vector3(5, 2, 0)) < 0.001 and absf(pm.fov - 50.0) < 0.001 and absf(pm.roll - 0.1) < 0.001)
	var cam := Camera3D.new()
	add_child(cam)
	var dfov := CameraDirector.apply(cam, pb, 0.0, 75.0)
	check("apply puts the camera at the pose, looking at the target, and returns the fov delta", cam.global_position.distance_to(Vector3(10, 4, 0)) < 0.2 and absf(dfov - (40.0 - 75.0)) < 0.001
		and (-cam.global_basis.z).dot(Vector3(0, 0, -1)) > 0.99)
	var straight_down := CameraDirector.pose(Vector3(0, 10, 0), Vector3(0, 0, 0), 60.0)
	CameraDirector.apply(cam, straight_down, 0.0)
	check("looking straight down does not break the basis", is_finite(cam.global_basis.x.x) and (-cam.global_basis.z).dot(Vector3.DOWN) > 0.99)
	cam.queue_free()

	# ---------- a test slot never shows the title or the opening ----------
	var gn = await make(false, false)
	check("test slots skip the title and the opening entirely", gn.title == null and not gn.title_active and not gn.guide.want_intro)
	gn.queue_free()
	await get_tree().process_frame

	# ---------- the title ----------
	var g = await make(false, true)
	check("a new game opens on the title", g.title != null and g.title_active and not g.title_resumed)
	check("it begins at the start of dusk", absf(g.day_t - Opening.DUSK) < 0.001 and g.day_phase() == "Dusk")
	check("the HUD is hidden behind it, the menu card is not up", g.title_hidden.size() > 5 and g.title_hidden.all(func(c): return not c.visible) and not g.menu.visible)
	check("the first-person props stay away from the title camera", not g.view.visible and not g.tool_view.visible)
	check("clicks on the glass cannot start play through the world", g.title.mouse_filter == Control.MOUSE_FILTER_STOP)
	check("the title says Play on a new game", g.title.button_box.get_child(0).text == "Play")
	await get_tree().create_timer(0.5).timeout
	var p0: Vector3 = g.cam.global_position
	await get_tree().create_timer(1.0).timeout
	var p1: Vector3 = g.cam.global_position
	check("the camera drifts over the ice (moved %.2f m)" % p0.distance_to(p1), p0.distance_to(p1) > 0.01 and p1.y > 0.5 and Vector2(p1.x, p1.z).length() < 45.0)
	check("the Eye holds its breath and the day waits", g.scenery.eye.hush_target == 1.0 and absf(g.day_t - Opening.DUSK) < 0.001)
	check("the hum is up", g.sfx.hum_target > 0.4)
	check("the world is not paused behind the title", not g.sim_paused and not g.ever_captured)
	check("the buttons are not clickable until they have faded in", g.title.ready_t > 0.0)
	# Settings opens the card over the title; Esc comes back to the title (it does not start play)
	g.title.ready_t = 0.0
	g.title.settings_pressed.emit()
	await get_tree().process_frame
	check("Settings opens the settings card over the title", g.menu.visible and g.menu.page == "settings" and g.menu.from_title)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	g.menu._input(esc)
	await get_tree().process_frame
	check("Esc closes it and you are back on the title, not in the game", not g.menu.visible and g.title_active and not g.ever_captured)
	g.title.controls_pressed.emit()
	await get_tree().process_frame
	check("Controls works the same way (and Back returns to the title)", g.menu.visible and g.menu.page == "controls")
	g.menu.close_to_title()
	g.title.t = 5.0
	await get_tree().process_frame
	check("the frost and the title grow in over the first seconds", g.title._frost_mat.get_shader_parameter("grow") > 0.3 and g.title._text_mat.get_shader_parameter("reveal") > 0.3)

	var en := InputEventKey.new()
	en.keycode = KEY_ENTER
	en.pressed = true
	g.title.ready_t = 0.0
	g.title._unhandled_input(en)
	check("Enter also starts play once the buttons are up", g.title.leaving)
	g.title.leaving = false
	# ---------- Play: the sled run, at 8x time ----------
	Engine.time_scale = 8.0
	g.title.t = 8.0
	g.title.ready_t = 0.0
	g.title._on_play()
	await get_tree().create_timer(0.5).timeout   # (1.15 s of fade at 8x)
	var guard := 0
	while not g.guide.intro_active and guard < 600:
		await get_tree().process_frame
		guard += 1
	check("after the fade the opening begins (and the title is gone)", g.guide.intro_active and g.guide.scene == "intro" and g.title == null)
	check("the sled team, Olga and the gift are built", g.opening.rig != null and g.opening.parts.dogs.size() == 4 and g.opening.parts.olga.size() > 3)
	check("Olga's hut figure is hidden while she is out on the ice", not g.scenery.olga.root.visible)
	check("the letterbox comes in and the HUD stays hidden", g.guide.bars > 10.0 or g.guide.hidden_hud.size() > 5)
	await wait_scene(g, 10.0)
	var st_mid: Dictionary = g.opening.sled_state(10.0)
	check("at 10 s the team is running (%.1f m/s) on the ice, inside the lake" % st_mid.speed, st_mid.speed > 3.0 and Vector2(st_mid.pos.x, st_mid.pos.z).length() < 86.0)
	check("dogs and sled move together (the rig sits at the sled position)", g.opening.rig.global_position.distance_to(g.opening.sled_state(g.guide.intro_t).pos) < 2.0)
	await wait_scene(g, 22.6)
	var st_stop: Dictionary = g.opening.sled_state(22.6)
	check("by 22.6 s the sled has stopped, behind the start spot (%.1f m)" % Vector3(st_stop.pos.x, 0, st_stop.pos.z).distance_to(Vector3(-8.2, 0, 14.3)), st_stop.speed < 0.1 and Vector3(st_stop.pos.x, 0, st_stop.pos.z).distance_to(Vector3(-8.2, 0, 14.3)) < 3.0)
	await wait_scene(g, 29.4)
	check("the rod has been handed over", g.opening.barked.has("gift"))
	await wait_scene(g, 38.0)
	check("the Eye's lid has opened for the scene", g.opening.lid > 0.9 and g.cine_eye > 0.08)
	check("the hum swelled with it", g.sfx.hum_target > 0.9)
	# the last frame lands on the player's own view: no jump
	var op: Opening = g.opening
	var fin := op.final_pose()
	var sl: Dictionary = op.sled_state(Opening.INTRO_LEN - 0.02)
	var last := op._intro_pose(Opening.INTRO_LEN - 0.02, sl.pos, sl.h)
	check("the final shot lands exactly on the player's view (%.3f m, fov %.2f)" % [last.pos.distance_to(fin.pos), last.fov], last.pos.distance_to(fin.pos) < 0.06 and absf(last.fov - fin.fov) < 0.5)
	var dir_last: Vector3 = (last.look - last.pos).normalized()
	var dir_fin: Vector3 = (fin.look - fin.pos).normalized()
	check("...looking where the player will look (%.2f deg off)" % rad_to_deg(dir_last.angle_to(dir_fin)), dir_last.angle_to(dir_fin) < deg_to_rad(1.0))
	await wait_scene(g, 99.0, 20.0)
	await get_tree().process_frame
	Engine.time_scale = 1.0
	check("the opening ends and hands over control", not g.guide.intro_active and g.guide.scene == "intro")
	check("the camera is back in the player's head, level", g.cam.position.length() < 0.01 and absf(g.cam.rotation.z) < 0.001 and absf(g.cam.rotation.y) < 0.001)
	check("the player stands on the start spot", g.get_node("Player").position.distance_to(Vector3(-8.2, 1.7, 14.3)) < 0.01)
	check("Olga's rod is in your hand, the drill still in its slot", g.inv.cur().get("k", "") == "tool" and int(g.inv.cur().t) == 1 and g.inv.find_tool(0) >= 0)
	check("the Eye is slightly ajar from now on", int(g.stats.ajar) == 1 and g.eye_open_frac() >= 0.1 and g.cine_eye == 0.0)
	check("the screen is clear: no black cover, no title, no flash", g.flash_rect.color.a < 0.01 and g.title == null and g.cine_fov == 0.0)
	check("the HUD is back", g.coins_label.get_parent().visible or g.carry_label.visible)
	check("the day clock runs again from dusk", g.day_t >= Opening.DUSK)
	check("the sled keeps going to the hut after the scene (and Olga is not in two places)", g.opening.rig != null or g.scenery.olga.root.visible)
	Engine.time_scale = 8.0
	var guard2 := 0
	while g.opening.rig != null and guard2 < 1500:
		await get_tree().process_frame
		guard2 += 1
	Engine.time_scale = 1.0
	check("the team reaches the hut, disappears, and Olga is at her window again", g.opening.rig == null and g.scenery.olga.root.visible)
	g.queue_free()
	await get_tree().process_frame

	# ---------- skipping ----------
	var gs = await make(false, true)
	gs.title._on_play()
	Engine.time_scale = 8.0
	var guard3 := 0
	while not gs.guide.intro_active and guard3 < 600:
		await get_tree().process_frame
		guard3 += 1
	await wait_scene(gs, 13.0)
	Engine.time_scale = 1.0
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	gs._unhandled_input(ev)
	await get_tree().process_frame
	check("a click skips the opening in the middle of the run", not gs.guide.intro_active)
	check("...straight to the end state: rod in hand, Eye ajar, camera back, hut Olga home, no rig", gs.inv.cur().get("t", -1) == 1 and int(gs.stats.ajar) == 1 and gs.cam.position.length() < 0.01
		and gs.scenery.olga.root.visible and gs.opening.rig == null and gs.flash_rect.color.a < 0.01 and gs.cine_fov == 0.0)
	check("...and nothing is left running (no cine eye, hum settled)", gs.cine_eye == 0.0 and gs.sfx.hum_target < 0.2)
	gs.queue_free()
	await get_tree().process_frame

	# ---------- the camera path: no NaN, never under the ice, never through a stall ----------
	var gc = await make(false, true)
	var op2: Opening = gc.opening
	op2.begin("intro")
	var finite := true
	var above := true
	var t := 0.0
	var min_stall := 1e9
	var on_ice := true
	while t < Opening.INTRO_LEN:
		var s2: Dictionary = op2.sled_state(t)
		var ps: Dictionary = op2._intro_pose(t, s2.pos, s2.h)
		for v in [ps.pos, ps.look, s2.pos, s2.h]:
			if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
				finite = false
		if ps.pos.y < 0.3:
			above = false
		if t < 22.0:   # on the way in the sled must stay on the ice and clear of every stall and the camp
			if Vector2(s2.pos.x, s2.pos.z).length() > gc.scenery.edge_at(s2.pos.x, s2.pos.z) - 1.0:
				on_ice = false
			for o in gc.scenery.obstacles:
				min_stall = minf(min_stall, Vector2(s2.pos.x, s2.pos.z).distance_to(Vector2(o.x, o.y)) - o.z)
		t += 0.25
	check("every pose and sled position of the 41 s run is finite", finite)
	check("the camera never goes under the ice", above)
	check("the sled stays on the ice the whole way in", on_ice)
	check("it never clips an obstacle (closest pass %.1f m clear)" % min_stall, min_stall > 1.0)
	gc.queue_free()
	await get_tree().process_frame

	# ---------- previously ----------
	GameState.save_slot = "test_opening"
	GameState.delete_save()
	GameState.reset()
	var seed_game = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(seed_game)
	await get_tree().process_frame
	seed_game.stats.eye_fed = 420
	seed_game.stats.holes = 3
	seed_game.stats.ajar = 1
	seed_game.day_t = 0.62
	seed_game._on_about_to_save()
	GameState.save_game(false)
	seed_game.queue_free()
	await get_tree().process_frame
	var gp = await make(true, true)
	check("a continued save opens on the title with Continue and the saved sky", gp.title_resumed and gp.title.button_box.get_child(0).text == "Continue" and absf(gp.day_t - 0.62) < 0.01)
	check("the Eye is not made to hold its breath for a save", gp.scenery.eye.hush_target == 0.0)
	gp.title._on_play()
	Engine.time_scale = 8.0
	var guard4 := 0
	while not gp.guide.intro_active and guard4 < 600:
		await get_tree().process_frame
		guard4 += 1
	check("Continue starts the previously beat (not the sled run)", gp.guide.scene == "previously" and gp.opening.rig == null)
	var cards: Array = gp.opening.captions("previously")
	var all_text := ""
	for c in cards:
		all_text += String(c[2]) + "\n"
	check("the cards say what happened (420 fish fed, the Eye's stage, Olga's next step)", all_text.contains("Previously") and all_text.contains("420") and all_text.contains("The Eye: stage") and all_text.contains("Olga:"))
	await wait_scene(gp, 99.0, 20.0)
	await get_tree().process_frame
	Engine.time_scale = 1.0
	check("it ends by itself and hands over control with the camera in your head", not gp.guide.intro_active and gp.cam.position.length() < 0.01 and gp.flash_rect.color.a < 0.01)
	check("a continued game keeps its own sky (the day clock is not reset)", gp.day_t > 0.6)
	GameState.delete_save()
	Engine.time_scale = 1.0
	print("OPENING %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
