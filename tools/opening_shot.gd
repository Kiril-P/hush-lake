extends Node
## Renders the opening for review (needs a window): the title forming out of the frost, the sled run beat by beat, the "previously" cards.
## Usage: tools/opening_shot.sh  (env OPEN_ONLY=title|intro|previously)  -> renders/open_*.png

func make_game(resumed: bool):
	GameState.save_slot = "test_opening_shot"
	if not resumed:
		GameState.delete_save()
		GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	g.set_meta("force_title", true)
	add_child(g)
	g.test_capture = true
	return g

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://renders/open_%s.png" % name)
	print("saved ", name)

func until_scene(g, t: float, limit := 2000) -> void:
	var n := 0
	while g.guide.intro_active and g.guide.intro_t < t and n < limit:
		await get_tree().process_frame
		n += 1

func _ready() -> void:
	DisplayServer.window_move_to_foreground()   # a window behind others stops redrawing on macOS and the captures come back stale
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	var only := OS.get_environment("OPEN_ONLY")
	if only == "" or only == "title":
		var g = make_game(false)
		for step in [[0.9, "title_0"], [2.6, "title_1"], [4.4, "title_2"], [6.0, "title_3"], [8.5, "title_4"]]:
			while g.title != null and g.title.t < step[0]:
				await get_tree().process_frame
			shot(step[1])
		g.queue_free()
		await get_tree().process_frame
	if only == "" or only == "intro":
		var g2 = make_game(false)
		while g2.title.t < 7.5:
			await get_tree().process_frame
		g2.title._on_play()
		Engine.time_scale = 2.0
		var marks := [[2.5, "intro_a"], [8.0, "intro_b"], [12.0, "intro_c"], [18.0, "intro_d"], [21.0, "intro_e"], [25.0, "intro_f"], [27.8, "intro_g"], [32.5, "intro_h"], [37.8, "intro_i"], [40.0, "intro_j"]]
		for m in marks:
			while not g2.guide.intro_active:
				await get_tree().process_frame
			await until_scene(g2, m[0])
			var cp: Vector3 = g2.cam.global_position
			var near := ""
			for c in g2.dressing.root.get_children():
				if c is Node3D and (c as Node3D).global_position.distance_to(cp) < 2.5:
					near += " %s@%.1f" % [c.name if c.name != "" else str(c.get_class()), (c as Node3D).global_position.distance_to(cp)]
			print("CAM ", m[1], " ", cp, near, " flash=", g2.flash_rect.color, " dream=", g2.dream.visible, " photo=", g2.photo, " ts=", Engine.time_scale, " t=", g2.guide.intro_t, " fov=", g2.cam.fov, " cine=", g2.cine_eye)
			shot(m[1])
		await until_scene(g2, 99.0)
		Engine.time_scale = 1.0
		for i in 20:
			await get_tree().process_frame
		shot("intro_end")
		g2.queue_free()
		await get_tree().process_frame
	if only == "" or only == "previously":
		GameState.save_slot = "test_opening_shot"
		GameState.delete_save()
		GameState.reset()
		var seed_game = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
		add_child(seed_game)
		seed_game.stats.eye_fed = 420
		seed_game.stats.holes = 3
		seed_game.stats.caught = 90
		seed_game.stats.ajar = 1
		seed_game.day_t = 0.62
		seed_game.goal_done[0] = true
		seed_game._on_about_to_save()
		GameState.save_game(false)
		seed_game.queue_free()
		await get_tree().process_frame
		var g3 = make_game(true)
		while g3.title.t < 7.5:
			await get_tree().process_frame
		shot("prev_title")
		g3.title._on_play()
		Engine.time_scale = 2.0
		for m in [[1.5, "prev_a"], [4.2, "prev_b"], [7.5, "prev_c"], [10.0, "prev_d"]]:
			while not g3.guide.intro_active:
				await get_tree().process_frame
			await until_scene(g3, m[0])
			shot(m[1])
		Engine.time_scale = 1.0
	GameState.delete_save()
	get_tree().quit()
