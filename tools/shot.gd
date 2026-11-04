extends Node
## Renders screenshots of the real game (needs a window; not headless).
## Usage: tools/shot.sh  -> writes renders/shot_*.png
## Views are [name, player_pos(x,z), yaw_deg, pitch_deg, time_of_day(0-1)]

const VIEWS := [
	# name, player pos, yaw, pitch, time of day, [eye height]
	["start", Vector3(-8.2, 0, 14.3), -30.0, -5.0, 0.0],
	["rim", Vector3(-8.2, 0, 14.3), -30.0, -30.0, 0.0],
	["eyetop", Vector3(0, 0, 0.1), 0.0, -89.0, 0.0, 34.0],
	["camp", Vector3(-8.2, 0, 14.3), 40.0, -3.0, 0.0],
	["hutview", Vector3(-8.2, 0, 14.3), -95.0, -3.0, 0.0],
	["aerial", Vector3(0, 0, 190), 0.0, -38.0, 0.0, 130.0],
	["night", Vector3(-8.2, 0, 14.3), -30.0, 4.0, 0.5],
]

func _ready() -> void:
	GameState.save_slot = "test_shot"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	g.test_capture = true   # no pause card over the pictures
	var only := OS.get_environment("SHOT_ONLY")
	for v in VIEWS:
		if only != "" and v[0] != only:
			continue
		var p: Node3D = g.get_node("Player")
		p.position = Vector3(v[1].x, v[5] if v.size() > 5 else 1.7, v[1].z)
		p.rotation.y = deg_to_rad(v[2])
		g.cam.rotation.x = deg_to_rad(v[3])
		g.day_t = v[4]
		g.scenery.set_time(v[4])
		for i in 8:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://renders/shot_%s.png" % v[0])
		print("saved ", v[0])
	# onboarding: the intro flyover at four moments, then the first objective with its marker
	if only == "guide":
		var gd = g.guide
		gd.want_intro = true
		for i in 3:
			await get_tree().process_frame
		for tt in [1.8, 5.0, 9.0, 11.6]:
			gd.intro_t = tt
			for i in 5:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_guide_intro_%d.png" % int(tt))
			print("saved intro ", tt)
		gd.skip_intro()
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_guide_drill.png")
		var pg: Node3D = g.get_node("Player")
		pg.rotation.y = deg_to_rad(120.0)
		for i in 6:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_guide_arrow.png")
		print("saved guide")
	# fish on the ice: a catch dropping out of a hole, a pile near the Eye, and a kick
	if only == "yard":
		var py: Node3D = g.get_node("Player")
		py.position = Vector3(-26.0, 1.7, 22.0)
		py.rotation.y = deg_to_rad(-40.0)
		g.cam.rotation.x = deg_to_rad(-30.0)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		var fw := -py.global_basis.z
		var rt := py.global_basis.x
		for i in 7:
			var sp: Dictionary = g._make_fish(g.SPECIES[i % 4])
			var at := py.position + fw * (3.0 + (i % 3) * 0.9) + rt * (-1.6 + i * 0.5)
			g.yard.spawn(sp, Vector3(at.x, g.yard.GROUND, at.z), Vector3.ZERO)
		g.test_capture = true
		for step in [["a", 0.5], ["b", 1.2]]:
			await get_tree().create_timer(step[1]).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_yard_%s.png" % step[0])
			print("saved yard ", step[0])
		g._start_kick()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_yard_wind.png")
		g.kick_charge = 1.0
		g._release_kick()
		for step in [["c", 0.1], ["d", 0.4]]:
			await get_tree().create_timer(step[1]).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_yard_%s.png" % step[0])
			print("saved yard ", step[0])
	# the hand-off: a bucket of fish thrown at the Eye one by one, a belt fish diving, then a stage reveal
	if only == "handoff":
		var ph: Node3D = g.get_node("Player")
		ph.position = Vector3(-6.0, 1.7, 11.0)
		ph.rotation.y = deg_to_rad(-30.0)
		g.cam.rotation.x = deg_to_rad(-14.0)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		for i in 10:
			g.carry.append(g._make_fish(g.SPECIES[i % 4]))
		g._refresh_view()
		for i in 20:
			await get_tree().process_frame
		g._feed_by_hand()
		for step in [["a", 0.7], ["b", 0.9], ["c", 0.7]]:
			await get_tree().create_timer(step[1]).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_handoff_%s.png" % step[0])
			print("saved handoff ", step[0])
		await get_tree().create_timer(2.5).timeout
		g._stage_reveal(3)
		for step in [["rev1", 0.9], ["rev2", 1.3]]:
			await get_tree().create_timer(step[1]).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_handoff_%s.png" % step[0])
			print("saved handoff ", step[0])
	# the awakening cutscene at six moments
	if only == "awaken":
		g.stats.eye_fed = 7000
		g.eye_seen_stage = 4
		g.scenery.set_eye_stage(4)
		g.scenery.set_eye_open(0.8)
		g.awaken_hold = true
		for i in 10:
			await get_tree().process_frame
		g.guide.play_awakening(true)
		for tt in [1.8, 3.2, 3.75, 4.9, 9.0, 13.2]:
			g.guide.intro_t = tt - 0.05 if tt != 3.75 else g.guide.AWAKEN_OPEN - 0.02
			await get_tree().create_timer(0.12 if tt != 3.75 else 0.35).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_awaken_%d.png" % int(tt * 10))
			print("saved awaken ", tt)
	# staged mid-game: auto-rods with belts running into the Eye, fish riding them, the Eye partly fed
	if only == "" or only == "belts":
		GameState.currency = 99999.0
		g.unlocked["t_auto"] = true
		g.unlocked["t_belt"] = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for c in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]:
			var hp: Vector3 = g._hex_pos(c) * 1.3
			var h: Dictionary = g._make_hole(hp)
			if h.is_empty():
				continue
			g._build_auto(h)
			g._build_belt(h, false)
			for k in 7:
				g._belt_spawn(h, g._make_fish(g.SPECIES[rng.randi() % 3]))
				g.belt_fish[g.belt_fish.size() - 1].d = rng.randf() * h.belt.len
		for k in 12:
			var hp2 := Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))
			if g._can_drill_at(hp2):
				g._make_hole(hp2)
		g.stats.eye_fed = 220
		g.eye_seen_stage = g.eye_stage()
		g.scenery.set_eye_open(g.eye_open_frac())
		g._refresh()
		var pb: Node3D = g.get_node("Player")
		for v2 in [["belts", Vector3(-8.2, 1.7, 14.3), -30.0, -14.0], ["belts_top", Vector3(0, 55, 0.1), 0.0, -89.0], ["belts_low", Vector3(14, 1.7, -4), 100.0, -4.0]]:
			pb.position = v2[1]
			pb.rotation.y = deg_to_rad(v2[2])
			g.cam.rotation.x = deg_to_rad(v2[3])
			g.day_t = 0.0
			g.scenery.set_time(0.0)
			g._update_belt_fish(0.0)
			for i in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % v2[0])
			print("saved ", v2[0])
	# stage 2 things: snowmobile cockpit, machines on belts, a depot, an ice-breaker
	if only == "" or only == "stage2":
		GameState.currency = 99999.0
		g.unlocked["t_auto"] = true
		g.unlocked["t_belt"] = true
		g.unlocked["t_build"] = true
		g.unlocked["snowmobile"] = true
		for id in g.model.sectors:
			g.model.sectors[id].unlocked = true
		var h1: Dictionary = g._make_hole(g._hex_pos(Vector2i(1, 0)) * 1.25)
		g._build_auto(h1)
		g._build_belt(h1, false)
		g._install_machine(h1, "cannery", false)
		var h2: Dictionary = g._make_hole(g._hex_pos(Vector2i(-1, 1)) * 1.25)
		g._build_auto(h2)
		g._build_belt(h2, false)
		g._install_machine(h2, "sorter", false)
		g._build_depot(Vector3(-17.5, 0, 0), false)
		g._build_rig(g._hex_pos(Vector2i(2, 1)) * 1.1, false)
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 9
		for hh in [h1, h2]:
			for k in 10:
				g._belt_spawn(hh, g._make_fish(g.SPECIES[rng2.randi() % 4]))
				g.belt_fish[g.belt_fish.size() - 1].d = rng2.randf() * hh.belt.len
		for k in 14:
			g._belt_push(g.rigs[0].belt, g._make_fish(g.SPECIES[rng2.randi() % 3]))
			g.belt_fish[g.belt_fish.size() - 1].d = rng2.randf() * g.rigs[0].belt.len
		g.stats.eye_fed = 70
		g.eye_seen_stage = g.eye_stage()
		g.scenery.set_eye_open(g.eye_open_frac())
		g._refresh()
		var ps: Node3D = get_node("/root/Shot/IceFishing/Player") if false else g.get_node("Player")
		var views2 := [["ride", Vector3(-8.2, 1.7, 14.3), -30.0, -6.0], ["machines", Vector3(10, 1.7, 20), -14.0, -9.0],
			["depot", Vector3(-8, 1.7, 8), 50.0, -6.0], ["rig", Vector3(26, 1.7, -3), -159.0, -4.0],
			["stall", Vector3(-12, 1.7, -22), -12.0, -2.0]]
		for v3 in views2:
			g.riding = v3[0] == "ride"
			g.ride_view.visible = g.riding
			ps.position = v3[1]
			ps.rotation.y = deg_to_rad(v3[2])
			g.cam.rotation.x = deg_to_rad(v3[3])
			g.day_t = 0.0
			g.scenery.set_time(0.0)
			g._update_belt_fish(0.0)
			for i in 6:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % v3[0])
			print("saved ", v3[0])
	# Olga at her hut, from a few steps away
	if only == "olga":
		var po: Node3D = g.get_node("Player")
		var ol: Node3D = g.scenery.olga.root
		var target: Vector3 = ol.global_position + Vector3(0, 1.1, 0)
		var from: Vector3 = target + (Vector3.ZERO - target).normalized() * 7.5
		po.position = Vector3(from.x, 1.7, from.z)
		var dv: Vector3 = target - Vector3(from.x, 1.7, from.z)
		po.rotation.y = atan2(-dv.x, -dv.z)
		g.cam.rotation.x = atan2(dv.y, Vector2(dv.x, dv.z).length())
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		g.goal_done.fill(true)
		for i in 40:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_olga.png")
		print("saved olga")
	# sectors: the border of the open Shallows seen from the ice, a cleared sector next to a locked one, and at night
	if only == "sectors":
		var pz: Node3D = g.get_node("Player")
		g.goal_done.fill(true)
		g.test_capture = true
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		pz.position = Vector3(0, 1.7, 8.0)
		pz.rotation.y = deg_to_rad(180.0)
		g.cam.rotation.x = deg_to_rad(-9.0)
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_sectors_a.png")   # facing the closed ring from inside the Shallows
		# open one neighbour, clear another
		var ids: Array = g.model.sectors.keys()
		for id in ids:
			var sec: Dictionary = g.model.sectors[id]
			if sec.ring == 1 and sec.center.y > 0 and sec.center.x <= 1:
				sec.unlocked = true
				for tc in sec.tiles:
					g.model.stock[tc] = {}
				sec.cleared = true
				break
		g._update_sector_labels()
		for i in 70:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_sectors_b.png")   # one sector cleared (gold), the rest closed
		pz.position = Vector3(0, 40.0, 60.0)
		pz.rotation.y = deg_to_rad(0.0)
		g.cam.rotation.x = deg_to_rad(-38.0)
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_sectors_c.png")   # from above
		g.day_t = 0.5
		g.scenery.set_time(0.5)
		pz.position = Vector3(0, 1.7, 8.0)
		pz.rotation.y = deg_to_rad(180.0)
		g.cam.rotation.x = deg_to_rad(-9.0)
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_sectors_d.png")   # night
		print("saved sectors")
	# the hands: a fish in hand, winding up a throw with the arc preview, and the throw in flight
	if only == "hands":
		var ph: Node3D = g.get_node("Player")
		ph.position = Vector3(-8.0, 1.7, 17.0)
		ph.rotation.y = deg_to_rad(-25.0)
		g.cam.rotation.x = deg_to_rad(4.0)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		g.goal_done.fill(true)
		g.test_capture = true
		var fw := -ph.global_basis.z
		for i in 3:
			var at: Vector3 = ph.position + fw * (3.0 + i * 0.9) + ph.global_basis.x * (i - 1) * 1.1
			g.yard.spawn(g._make_fish(g.SPECIES[i % 4]), Vector3(at.x, g.yard.GROUND, at.z), Vector3.ZERO)
		g.cam.rotation.x = deg_to_rad(-22.0)
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_hands_a.png")   # the crosshair is on a fish: "Click: grab"
		g._grab_fish()
		g.cam.rotation.x = deg_to_rad(6.0)
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_hands_b.png")   # holding it
		g._start_kick()
		g.kick_charge = 0.7
		for i in 10:
			await get_tree().process_frame
		g.kick_charge = 0.7
		get_viewport().get_texture().get_image().save_png("res://renders/shot_hands_c.png")   # winding up: the arc preview
		g._release_kick()
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_hands_d.png")   # in flight
		print("saved hands")
	# the panels: journal, catch card, refreeze
	if only == "ui":
		var pu: Node3D = g.get_node("Player")
		pu.position = Vector3(-8.2, 1.7, 14.3)
		pu.rotation.y = deg_to_rad(-30)
		g.cam.rotation.x = deg_to_rad(-6)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		g.goal_done.fill(true)
		g.stats.caught = 120
		g.stats.eye_fed = 500
		g.eye_seen_stage = g.eye_stage()
		for i in g.SPECIES.size():
			g.journal[g.SPECIES[i].name] = 3 + i * 4
			g.records[g.SPECIES[i].name] = 20.0 + i * 11.0
		g._refresh()
		g.journal_panel.visible = true
		g._update_journal()
		for i in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_ui_journal.png")
		g.journal_panel.visible = false
		var best: Dictionary = g._make_fish(g.SPECIES[3])
		g._show_card(best, 2, true, true)
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_ui_card.png")
		g.test_capture = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # (the game captures the mouse itself when the window has focus)
		g.card_panel.visible = false
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_ui_pause.png")
		g.test_capture = true
		print("saved ui")
	# every machine up close, in daylight
	if only == "machines2":
		GameState.currency = 99999.0
		g.unlocked["t_auto"] = true
		g.unlocked["t_belt"] = true
		g.unlocked["t_build"] = true
		g.unlocked["t_smoker"] = true
		g.unlocked["t_table"] = true
		for id in g.model.sectors:
			g.model.sectors[id].unlocked = true
		var m1: Dictionary = g._make_hole(Vector3(30, 0, 8))
		g._build_auto(m1)
		g._build_belt(m1, false)
		g._install_machine(m1, "cannery", false)
		var m2: Dictionary = g._make_hole(Vector3(30, 0, -16))
		g._build_auto(m2)
		g._build_belt(m2, false)
		g._install_machine(m2, "sorter", false)
		var m3: Dictionary = g._make_hole(Vector3(26, 0, 26))
		g._build_smoker(m3)
		var m4: Dictionary = g._make_hole(Vector3(33, 0, 26))
		g._build_table(m4)
		var m5: Dictionary = g._make_hole(Vector3(40, 0, 17))
		g._build_auto(m5)
		g._build_depot(Vector3(20, 0, 34), false)
		g._build_rig(Vector3(-5, 0, -42), false)
		var rngm := RandomNumberGenerator.new()
		rngm.seed = 4
		for hh in [m1, m2]:
			for k in 8:
				g._belt_spawn(hh, g._make_fish(g.SPECIES[rngm.randi() % 4]))
				g.belt_fish[g.belt_fish.size() - 1].d = rngm.randf() * hh.belt.len
		m3.slot = [g._make_fish(g.SPECIES[0])]
		m3.smoke_t = 5.0
		g.stats.eye_fed = 300
		g.eye_seen_stage = g.eye_stage()
		g.scenery.set_eye_open(g.eye_open_frac())
		g._refresh()
		var pm: Node3D = g.get_node("Player")
		g.goal_done.fill(true)   # (no goal banners over the pictures)
		for v4 in [["m_belt", Vector3(26, 1.7, 22), Vector3(18, 1.0, 5)], ["m_sorter", Vector3(26, 1.7, -22), Vector3(18, 1.4, -9.6)], ["m_smoker", Vector3(20, 1.7, 36), Vector3(26, 0.8, 26)],
				["m_table", Vector3(40, 1.7, 34), Vector3(33, 0.6, 26)], ["m_depot", Vector3(8, 1.7, 44), Vector3(20, 1.0, 34)], ["m_rig", Vector3(14, 1.7, -30), Vector3(-5, 2.0, -42)], ["m_auto", Vector3(46, 1.7, 26), Vector3(40, 1.0, 17)]]:
			pm.position = v4[1]
			var dv: Vector3 = v4[2] - v4[1]
			pm.rotation.y = atan2(-dv.x, -dv.z)
			g.cam.rotation.x = atan2(dv.y, Vector2(dv.x, dv.z).length())
			g.day_t = 0.0
			g.scenery.set_time(0.0)
			g._update_belt_fish(0.0)
			for i in 8:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % v4[0])
			print("saved ", v4[0])
	# the tools in hand, big: auger tiers, rod tiers, builder kit
	if only == "tools":
		var pt: Node3D = g.get_node("Player")
		pt.position = Vector3(-8.2, 1.7, 14.3)
		pt.rotation.y = deg_to_rad(-30)
		g.cam.rotation.x = deg_to_rad(-10)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		g.unlocked["t_auto"] = true
		g.unlocked["t_build"] = true
		for combo in [["tool_auger0", 0, 0], ["tool_auger3", 0, 3], ["tool_rod0", 1, 0], ["tool_rod3", 1, 3], ["tool_build", 6, 0]]:
			g.tool = combo[1]
			GameState.upgrades["drill"] = combo[2] if combo[1] == 0 else 0
			GameState.upgrades["lines"] = combo[2] if combo[1] == 1 else 0
			g._sync_tool_view()
			for i in 12:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % combo[0])
			print("saved ", combo[0])
	# the whole fishing sequence, frame by frame
	if only == "fishing":
		var pf2: Node3D = g.get_node("Player")
		pf2.position = Vector3(-8.2, 1.7, 14.3)
		pf2.rotation.y = deg_to_rad(-30)
		g.cam.rotation.x = deg_to_rad(-24)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		g.unlocked["lines"] = true
		var fwd: Vector3 = -pf2.global_basis.z
		var hp3: Vector3 = pf2.position * Vector3(1, 0, 1) + fwd * Vector3(1, 0, 1) * 4.5
		var hh: Dictionary = g._make_hole(hp3)
		g.tool = 1
		g._sync_tool_view()
		g._refresh()
		await get_tree().create_timer(0.3).timeout
		g._cast(hh)
		for step in [["fishing_1_cast", 0.28], ["fishing_2_wait", 0.9]]:
			await get_tree().create_timer(step[1]).timeout
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % step[0])
		var dbg := Camera3D.new()
		g.add_child(dbg)
		dbg.global_position = pf2.global_position + Vector3(5.5, 1.2, 0.5)
		dbg.look_at(hh.pos * 0.5 + pf2.global_position * 0.5 + Vector3(0, 0.8, 0), Vector3.UP)
		dbg.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fishing_side.png")
		g.cam.current = true
		dbg.queue_free()
		hh.nib = []
		hh.timer = 0.0
		await get_tree().create_timer(0.12).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fishing_3_bite.png")
		g._click("hole:%d" % hh.idx)
		await get_tree().create_timer(0.35).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fishing_4_fight.png")
		while hh.cast == 3:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fishing_5_launch.png")
		await get_tree().create_timer(0.5).timeout
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fishing_6_card.png")
		print("saved fishing")
	# every catch lined up in front of the camera
	if only == "fish":
		var pf: Node3D = g.get_node("Player")
		pf.position = Vector3(-8.2, 1.7, 14.3)
		pf.rotation.y = deg_to_rad(-30)
		g.cam.rotation.x = deg_to_rad(-8)
		g.day_t = 0.0
		g.scenery.set_time(0.0)
		var i := 0
		for sp in g.SPECIES:
			var fish: Dictionary = g._make_fish(sp)
			fish.lenk = 1.0
			var node: Node3D = g._fish_mesh(fish, g, 3.6)
			var base: Vector3 = pf.position + (-pf.global_basis.z) * 3.0
			var right: Vector3 = pf.global_basis.x
			node.global_position = base + right * (float(i % 4) - 1.5) * 1.5 + Vector3(0, 0.15 - float(i / 4) * 1.15, 0)
			node.rotation.y = deg_to_rad(pf.rotation_degrees.y + 200.0)
			i += 1
		for k in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://renders/shot_fish.png")
		print("saved fish")
	# the Eye at each stage, day and night, plus a feed reaction
	if only == "eye":
		var pe: Node3D = g.get_node("Player")
		pe.position = Vector3(-9, 1.7, 17)
		pe.rotation.y = deg_to_rad(-28)
		g.cam.rotation.x = deg_to_rad(-14)
		for cfg in [["eye_s0", 0, 0.0, 1.7], ["eye_s3", 3, 0.0, 1.7], ["eye_s5_night", 5, 0.5, 1.7], ["eye_catch", 5, 0.5, 1.7], ["eye_high", 5, 0.5, 14.0], ["eye_high_day", 3, 0.0, 14.0], ["eye_top5", 5, 0.5, 52.0, true]]:
			pe.position.y = cfg[3]
			g.cam.rotation.x = deg_to_rad(-14 if cfg[3] < 5.0 else -30)
			if cfg.size() > 4:
				pe.position = Vector3(0, cfg[3], 0.1)
				pe.rotation.y = 0.0
				g.cam.rotation.x = deg_to_rad(-89)
			else:
				pe.position = Vector3(-9, cfg[3], 17)
				pe.rotation.y = deg_to_rad(-28)
			g.stats.eye_fed = [0, 10, 60, 200, 600, 1500][cfg[1]]
			g.eye_seen_stage = cfg[1]
			g.scenery.set_eye_open(g.eye_open_frac())
			g.scenery.set_eye_stage(cfg[1])
			g.scenery.set_eye_glow(0.7 if cfg[1] > 0 else 0.0)
			g.day_t = cfg[2]
			g.scenery.set_time(cfg[2])
			if cfg[0] == "eye_catch":
				g.scenery.eye_catch(Color(1.0, 0.8, 0.3), 1.0)
				g.scenery.eye.stage_up(5)
			for i in (14 if cfg[0] == "eye_catch" else 10):
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("res://renders/shot_%s.png" % cfg[0])
			print("saved ", cfg[0])
	# progress view: pretend 9 sectors are cleared so the shore lanterns are lit
	var n := 0
	for id in g.model.sectors:
		g.model.sectors[id].cleared = n < 9
		n += 1
	g._update_sector_labels()
	var p2: Node3D = g.get_node("Player")
	p2.position = Vector3(0, p2.position.y, 6)
	p2.rotation.y = deg_to_rad(-20)
	g.cam.rotation.x = deg_to_rad(-3)
	g.day_t = 0.5
	g.scenery.set_time(0.5)
	for i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://renders/shot_lanterns.png")
	print("saved lanterns")
	GameState.delete_save()
	get_tree().quit()
