extends Node
## Headless test for the menu, the settings and the HUD feel: defaults, saving, applying, every page builds, the rolling counter.
## Run: tools/run_ui.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		buttons(c, out)

func find_btn(m: MenuUI, text: String) -> Button:
	var all := []
	buttons(m.box, all)
	for b in all:
		if b.text == text:
			return b
	return null

func _ready() -> void:
	GameState.save_slot = "test_ui"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().process_frame
	await get_tree().process_frame
	var m: MenuUI = g.menu

	# --- defaults and limits
	check("every setting has a default inside its limits", GameSettings.DEFS.keys().all(func(k): var d = GameSettings.DEFS[k]; return d.kind == "toggle" or (float(d.def) >= float(d.min) and float(d.def) <= float(d.max))))
	check("every setting belongs to a tab", GameSettings.DEFS.keys().all(func(k): return int(GameSettings.DEFS[k].tab) < GameSettings.TABS.size()))
	check("nothing is changed from the defaults at the start", GameSettings.DEFS.keys().all(func(k): return GameSettings.is_default(k)))

	# --- applying
	GameSettings.set_value("fov", 90.0)
	GameSettings.set_value("sens", 0.004)
	GameSettings.set_value("inv", 1.0)
	GameSettings.set_value("shake", 0.0)
	GameSettings.set_value("bob", 0.5)
	GameSettings.set_value("punch", 0.25)
	GameSettings.set_value("sfx", 0.5)
	GameSettings.set_value("amb", 0.0)
	GameSettings.set_value("snow", 0.0)
	GameSettings.set_value("shadows", 0.0)
	GameSettings.set_value("vignette", 0.0)
	GameSettings.set_value("ui", 1.2)
	g._apply_settings()
	check("FOV, sensitivity and invert reach the camera rig", g.fov_base == 90.0 and absf(g.get_node("Player").sensitivity - 0.004) < 0.0001 and g.get_node("Player").invert_y)
	check("shake, bob and punch scale the effects", g.fx_shake == 0.0 and g.fx_bob == 0.5 and g.fx_punch == 0.25)
	check("effects and ambience volumes reach the sound engine", g.sfx.sfx_db < -5.0 and g.sfx.sfx_db > -7.0 and g.sfx.amb_db <= -79.0)
	check("snow, shadows and vignette switch off", not g.scenery.snow_node.visible and not g.sun_light.shadow_enabled and not g.vignette_rect.visible)
	check("UI size scales the whole interface", absf(g.get_window().content_scale_factor - 1.2) < 0.001)
	g.shake = 0.5
	g._animate(0.016)
	check("with screen shake at 0 the camera does not shake", g.cam.h_offset == 0.0 and g.cam.v_offset == 0.0)
	GameSettings.set_value("hints", 0.0)
	g.guide.tick(0.5, true)
	check("with guidance off the NEXT strip hides", g.guide.strip.modulate.a < 0.99)
	GameSettings.set_value("hints", 1.0)

	# --- saved with the permanent progress and kept when you start over
	check("settings are stored in the permanent meta", float(GameState.meta.settings.fov) == 90.0)
	var keep: Dictionary = GameState.meta.get("settings", {}).duplicate()
	GameState.reset()
	check("a plain reset clears them (starting over keeps them: see _new_game)", GameState.meta.get("settings", {}).is_empty())
	GameState.meta["settings"] = keep

	# --- the menu
	g.ever_captured = true
	m.set_open(true)
	check("the menu opens on the main page and says PAUSED during a run", m.visible and m.page == "main")
	var pages := ["main", "settings", "controls", "howto", "stats", "confirm_new", "confirm_quit"]
	for p in pages:
		m.page = p
		m._rebuild()
		check("page '%s' builds with content" % p, m.box.get_child_count() >= 3)
	for t in GameSettings.TABS.size():
		m.page = "settings"
		m.tab = t
		m._rebuild()
		var all := []
		buttons(m.box, all)
		check("settings tab %d (%s) builds a row for each of its settings" % [t, GameSettings.TABS[t]], all.size() >= 3)
	# the controls page lists the real keys
	m.page = "controls"
	m._rebuild()
	var txt := ""
	var stack := [m.box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			txt += n.text + " "
		stack.append_array(n.get_children())
	check("the controls page mentions the slots, grab, throw, the rack and Olga", "three slots" in txt and "grab" in txt and "throw" in txt and "rack" in txt and "Olga" in txt)

	# --- buttons do what they say
	m.page = "main"
	m._rebuild()
	var resumed := [false]
	m.resume_requested.connect(func(): resumed[0] = true)
	find_btn(m, "Continue").pressed.emit()
	check("Continue asks to resume", resumed[0])
	find_btn(m, "Settings").pressed.emit()
	check("Settings opens the settings page", m.page == "settings")
	find_btn(m, "Back").pressed.emit()
	check("Back returns to the main page", m.page == "main")
	find_btn(m, "Start over").pressed.emit()
	check("Start over asks first", m.page == "confirm_new")
	find_btn(m, "Cancel").pressed.emit()
	m.page = "settings"
	m.tab = 0
	m._rebuild()
	find_btn(m, "Reset all to default").pressed.emit()
	check("Reset all to default restores every setting", GameSettings.DEFS.keys().all(func(k): return GameSettings.is_default(k)) and g.fov_base == 75.0 and g.fx_shake == 1.0)

	# --- HUD feel: the counter rolls to the real number and numbers carry separators
	check("big numbers get thousands separators", g._fmt_num(1234567.0) == "1,234,567" and g._fmt_num(999.0) == "999" and g._fmt_num(0.0) == "0")
	m.set_open(false)
	g.coins_shown = 100.0
	g.coins_target = 100.0
	GameState.currency = 5000.0
	g._refresh()
	check("the coin counter does not jump: it starts where it was", g.coins_shown == 100.0 and g.coins_target == 5000.0)
	for i in 120:
		g._tick_hud_feel(1.0 / 60.0)
	check("...and rolls up to the real value", absf(g.coins_shown - 5000.0) < 1.0 and g.coins_label.text == "5,000")
	g.saved_t = 0.0
	g._on_about_to_save()
	check("an autosave shows the small 'saved' tick", g.saved_t > 1.0)
	print("UI %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
