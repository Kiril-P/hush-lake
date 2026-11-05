extends Node
## The reference-shot manifest: a fixed set of captures (fixed place, time, weather, Eye stage) for the art-reference workflow.
## Usage: tools/refshots.sh [--out DIR]  -> docs/refs/shots/NN_name.png + manifest.json   (needs a window)
## Same manifest every round, so before/after sheets compare like with like. See docs/ART_PIPELINE.md.

const OUT := "res://docs/refs/shots/"
## id, what it is (for the agents), player (x,z), yaw, pitch, time of day (0 noon..1), weather, eye stage (0-5), eye height
const SHOTS := [
	["01_camp_noon", "the camp on the ice beside the Eye, clear midday", Vector3(-8.2, 0, 14.3), 40.0, -3.0, 0.0, "clear", 0],
	["02_start_view", "first view of Hush Lake: Olga's hut, the lake and mountains", Vector3(-8.2, 0, 14.3), -30.0, -5.0, 0.0, "clear", 0],
	["03_lake_aerial", "the whole lake from above: Eye in the middle, shore, mountains", Vector3(0, 0, 190), 0.0, -38.0, 0.0, "clear", 0, 130.0],
	["04_eye_top", "straight down on the Eye: its rings and pupil, nothing else", Vector3(0, 0, 0.1), 0.0, -89.0, 0.0, "clear", 2, 34.0],
	["05_eye_close", "standing at the rim of the Eye looking down into it", Vector3(-8.2, 0, 14.3), -30.0, -30.0, 0.0, "clear", 3],
	["06_market_row", "the market row of stalls in the camp", Vector3(4.0, 0, -4.0), -52.0, -2.0, 0.0, "clear", 1],
	["07_hut_view", "Olga's hut from the ice", Vector3(-8.2, 0, 14.3), -95.0, -3.0, 0.0, "clear", 0],
	["08_dusk", "the camp at dusk, lanterns lit", Vector3(-8.2, 0, 14.3), 40.0, -3.0, 0.25, "clear", 1],
	["09_night", "the lake at night, stars out", Vector3(-8.2, 0, 14.3), -30.0, 4.0, 0.5, "clear", 1],
	["10_aurora", "an aurora night over the lake", Vector3(-8.2, 0, 14.3), -30.0, 18.0, 0.5, "clear", 5],
	["11_snowfall", "snowfall in the camp", Vector3(-8.2, 0, 14.3), 40.0, -3.0, 0.1, "snowfall", 1],
	["12_blizzard", "a blizzard: the long view lost", Vector3(-8.2, 0, 14.3), -30.0, -3.0, 0.1, "blizzard", 1],
	["13_fog", "fog on the lake", Vector3(-8.2, 0, 14.3), 140.0, -2.0, 0.1, "fog", 1],
	["14_eye_awake", "the Eye fully awake, stage 5, from the camp", Vector3(-8.2, 0, 14.3), -30.0, -10.0, 0.0, "clear", 5],
	["15_eye_awake_night", "the awake Eye at night", Vector3(-8.2, 0, 14.3), -30.0, -10.0, 0.5, "clear", 5],
	["16_machines", "belts, auto-rods and machines running into the Eye", Vector3(-8.2, 1.7, 14.3), -30.0, -14.0, 0.0, "clear", 2],
	["17_machines_top", "machines seen from far above", Vector3(0, 0, 0.1), 0.0, -89.0, 0.0, "clear", 2, 55.0],
	["18_machines_low", "a belt line seen low from the side", Vector3(14, 0, -4), 100.0, -4.0, 0.0, "clear", 2],
	["19_shore", "the far shore: treeline, snow, mountains", Vector3(0, 0, 70), 0.0, 4.0, 0.0, "clear", 1],
	["20_sunrise", "dawn over the lake", Vector3(-8.2, 0, 14.3), 80.0, 2.0, 0.75, "clear", 1],
]

func _ready() -> void:
	var out := OUT
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--out":
		out = args[1]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	GameState.save_slot = "test_refshots"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	g.test_capture = true
	var only := OS.get_environment("REF_ONLY")
	var manifest := []
	var p: Node3D = g.get_node("Player")
	var staged_machines := false
	if OS.get_environment("REF_HUD") == "":   # clean frames: no HUD, no mittens (the agents are judging the world, not the interface)
		g.tool_view.visible = false
		for c in g.guide.ui_root.get_children():
			if c is Control:
				c.visible = false
	for s in SHOTS:
		if only != "" and not String(s[0]).begins_with(only):
			continue
		var stage: int = s[7]
		g.stats.eye_fed = 0 if stage == 0 else g.eye_stage_at(stage - 1) + 5
		g.eye_seen_stage = g.eye_stage()
		g.scenery.set_eye_stage(g.eye_seen_stage)
		g.scenery.set_eye_open(g.eye_open_frac())
		if String(s[0]).begins_with("16") or String(s[0]).begins_with("17") or String(s[0]).begins_with("18"):
			if not staged_machines:
				staged_machines = true
				_stage_machines(g)
		g.weather.always_aurora = (s[0] == "10_aurora")
		g.weather.aurora_decided = false
		g.weather.force(s[6])
		g.weather.blend = 1.0
		g.weather.from_vals = g.weather.vals.duplicate()
		p.position = Vector3(s[2].x, s[8] if s.size() > 8 else 1.7, s[2].z)
		p.rotation.y = deg_to_rad(s[3])
		g.cam.rotation.x = deg_to_rad(s[4])
		g.day_t = s[5]
		g.scenery.set_time(s[5])
		for i in 24:
			g.weather.tick(0.5, g.scenery._night)
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out + "%s.png" % s[0])
		manifest.append({"id": s[0], "what": s[1], "time_of_day": s[5], "weather": s[6], "eye_stage": stage, "file": "%s.png" % s[0]})
		print("saved ", s[0])
	var f := FileAccess.open(out + "manifest.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"game": "Hush Lake", "shots": manifest}, "\t"))
	f.close()
	get_tree().quit()

func _stage_machines(g) -> void:
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
	g._refresh()
