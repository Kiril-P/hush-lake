extends Node
## Renders screenshots of the real game (needs a window; not headless).
## Usage: tools/shot.sh  -> writes renders/shot_*.png
## Views are [name, player_pos(x,z), yaw_deg, pitch_deg, time_of_day(0-1)]

const VIEWS := [
	# name, player pos, yaw, pitch, time of day, [eye height]
	["start", Vector3(-6.7, 0, 11.6), -30.0, -5.0, 0.0],
	["rim", Vector3(-6.7, 0, 11.6), -30.0, -30.0, 0.0],
	["eyetop", Vector3(0, 0, 0.1), 0.0, -89.0, 0.0, 34.0],
	["camp", Vector3(-6.7, 0, 11.6), 40.0, -3.0, 0.0],
	["hutview", Vector3(-6.7, 0, 11.6), -95.0, -3.0, 0.0],
	["aerial", Vector3(0, 0, 190), 0.0, -38.0, 0.0, 130.0],
	["night", Vector3(-6.7, 0, 11.6), -30.0, 4.0, 0.5],
]

func _ready() -> void:
	GameState.save_slot = "test_shot"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
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
		for v2 in [["belts", Vector3(-6.7, 1.7, 11.6), -30.0, -14.0], ["belts_top", Vector3(0, 55, 0.1), 0.0, -89.0], ["belts_low", Vector3(14, 1.7, -4), 100.0, -4.0]]:
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
		var views2 := [["ride", Vector3(-6.7, 1.7, 11.6), -30.0, -6.0], ["machines", Vector3(10, 1.7, 20), -14.0, -9.0],
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
