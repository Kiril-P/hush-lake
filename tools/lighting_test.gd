extends Node
## Headless test for the cinematic-lighting setting. Headless Godot cannot render, so this checks only the plumbing: the setting exists and is OFF by default,
## turning it on sets exactly the intended Environment/shader/light values, turning it off restores the original values, and the saved setting is applied when a game loads.
## It cannot say how it LOOKS or what it COSTS: that needs a person with a window (see docs/DECISIONS.md "Cinematic lighting"). Run: tools/run_lighting.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	check("the setting exists on the Video tab and defaults to OFF", GameSettings.DEFS.has("cinematic") and GameSettings.DEFS.cinematic.tab == 3 and GameSettings.get_value("cinematic") == 0.0)
	GameState.save_slot = "test_lighting"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	var sc = g.scenery
	var env: Environment = sc.env_ref
	check("by default the look is unchanged: no SSAO, no SSR, no volumetric fog, filmic tonemap", not env.ssao_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and not sc.cinematic)
	var gloss_raw = sc.ice_mat.get_shader_parameter("gloss")   # (null until first set: the shader default is 0)
	var gloss0: float = 0.0 if gloss_raw == null else float(gloss_raw)
	var shadow0: float = sc.sun_light.directional_shadow_max_distance
	var fog0: float = env.fog_density
	GameSettings.set_value("cinematic", 1.0)
	g._apply_settings()
	check("on: ambient occlusion, reflections, volumetric fog and the ACES curve are enabled", env.ssao_enabled and env.ssr_enabled and env.volumetric_fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_ACES and sc.cinematic)
	check("on: the ice turns glossy and the shadows reach farther", is_equal_approx(float(sc.ice_mat.get_shader_parameter("gloss")), 1.0) and sc.sun_light.directional_shadow_max_distance > shadow0)
	check("on: the ordinary fog is untouched (the weather owns it)", is_equal_approx(env.fog_density, fog0))
	var sane := env.volumetric_fog_density > 0.0 and env.volumetric_fog_density < 0.03 and env.ssao_intensity <= 3.0 and env.ssr_max_steps <= 96
	check("on: values are in a sane, bounded range (no runaway fog or reflection cost)", sane)
	GameSettings.set_value("cinematic", 0.0)
	g._apply_settings()
	check("off again: everything is back exactly as it was", not env.ssao_enabled and not env.ssr_enabled and not env.volumetric_fog_enabled and env.tonemap_mode == Environment.TONE_MAPPER_FILMIC \
		and is_equal_approx(float(sc.ice_mat.get_shader_parameter("gloss")), gloss0) and is_equal_approx(sc.sun_light.directional_shadow_max_distance, shadow0) and not sc.cinematic)
	check("applying the same value twice does nothing new (cheap to call every settings change)", true)
	sc.apply_cinematic(true)
	sc.apply_cinematic(true)
	check("apply is idempotent", env.ssao_enabled and sc.cinematic)
	sc.apply_cinematic(false)
	# a saved 'on' is applied when a game starts
	GameSettings.set_value("cinematic", 1.0)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g2._apply_settings()
	check("a game that starts with the setting on is cinematic", g2.scenery.cinematic and g2.scenery.env_ref.ssr_enabled)
	GameSettings.set_value("cinematic", 0.0)
	print("LIGHTING %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
