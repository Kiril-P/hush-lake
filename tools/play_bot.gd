extends Node
## Plays the real game through its real input path: raycast aim, hold-to-drill, click-to-cast, feed the Eye, lay a belt.
## Needs a window (not headless). Run: tools/play_bot.sh   Prints PASS/FAIL lines and exits non-zero on any failure.

var fails := 0
var g: Node

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func aim_at(p: Vector3) -> void:
	var cam: Camera3D = g.cam
	var player: Node3D = g.get_node("Player")
	var d := p - cam.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	cam.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func mouse(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = get_viewport().get_visible_rect().size * 0.5
	Input.parse_input_event(ev)

func key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	GameState.save_slot = "test_bot"
	GameState.delete_save()
	GameState.reset()
	g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(3.0).timeout  # let shaders compile so frame times are steady
	await frames(5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	g.test_capture = true   # the window may not be focused (then the OS frees the mouse and the game would pause)
	await frames(3)
	var player: Node3D = g.get_node("Player")
	var out_dir := Vector3(0.5, 0, -0.866)   # toward the Eye, still inside the Shallows
	var spot: Vector3 = player.global_position * Vector3(1, 0, 1) + out_dir * 2.5

	# 1. aim at open ice and hold click: a hole appears where we aimed
	aim_at(Vector3(spot.x, 0.0, spot.z))
	await frames(3)
	check("aiming at the ice finds the ice", g._aim() == "ice")
	check("the prompt offers to drill", g.prompt_label.text.begins_with("Hold click: drill"))
	mouse(true)
	var held := 0.0
	while g.holes.is_empty() and held < 10.0:   # wait for the drill, not for a fixed time (first launch can stutter)
		await get_tree().create_timer(0.1).timeout
		held += 0.1
	mouse(false)
	await frames(3)
	check("holding click drilled exactly one hole", g.holes.size() == 1)
	var h: Dictionary = g.holes[0] if g.holes.size() > 0 else {}
	check("the hole is where we aimed", not h.is_empty() and Vector2(h.pos.x - spot.x, h.pos.z - spot.z).length() < 2.5)

	# 2. pick the rod with the real key, cast, wait for the bite, catch
	key(KEY_2)
	await frames(3)
	check("key 2 selects the rod", g.tool == 1)
	aim_at(h.pos + Vector3(0, 0.2, 0))
	await frames(3)
	check("aiming at the hole finds the hole", g._aim() == "hole:0")
	mouse(true)
	mouse(false)
	await frames(3)
	check("click casts the line", h.cast == 1)
	var waited := 0.0
	while h.cast != 2 and waited < 12.0:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	check("a fish bites", h.cast == 2)
	mouse(true)
	mouse(false)
	await frames(3)
	check("clicking on the bite hooks it", h.cast == 3)
	var fought := 0.0
	while g.yard.count() == 0 and fought < 4.0:
		await get_tree().create_timer(0.1).timeout
		fought += 0.1
	check("the fish drops onto the ice after the fight", g.yard.count() == 1 and g.carry.is_empty())
	await get_tree().create_timer(1.5).timeout
	g.carry.append_array(g.yard.collect(Vector3.ZERO, 9999.0, 1))
	check("(bot scoops it up for the hand-feed check)", g.carry.size() == 1)

	# 3. carry it to the Eye and click on it
	aim_at(Vector3(0, 0.2, 0))
	await frames(3)
	check("aiming at the Eye finds the Eye in reach", g._aim() == "eye")
	mouse(true)
	mouse(false)
	var fed_wait := 0.0
	while g.stats.eye_fed < 1 and fed_wait < 6.0:
		await get_tree().create_timer(0.1).timeout
		fed_wait += 0.1
	check("the Eye ate the fish", g.stats.eye_fed == 1 and g.carry.is_empty())

	# 4. auto-rod + belt: the catch rides into the Eye on its own
	GameState.currency = 500.0
	g.unlocked["t_auto"] = true
	g.unlocked["t_belt"] = true
	key(KEY_3)
	aim_at(h.pos + Vector3(0, 0.2, 0))
	await frames(3)
	mouse(true)
	mouse(false)
	await frames(3)
	check("click builds an auto-rod on the hole", h.state == "auto")
	key(KEY_6)
	await frames(3)
	check("key 6 selects the belt", g.tool == 5)
	mouse(true)
	mouse(false)
	await frames(3)
	check("click lays a belt to the Eye", h.belt != null)
	h.auto_t = 0.0
	var fed_before: int = g.stats.eye_fed
	var seen_on_belt := false
	var t_wait := 0.0
	while g.stats.eye_fed == fed_before and t_wait < 15.0:
		await get_tree().create_timer(0.1).timeout
		t_wait += 0.1
		if g.belt_fish.size() > 0:
			seen_on_belt = true
	check("a fish rode the belt", seen_on_belt)
	check("the belt fed the Eye with no hands on it", g.stats.eye_fed == fed_before + 1)

	# 5. snowmobile: V rides, holding W covers ground fast
	GameState.upgrades["snowmobile"] = 1
	g.unlocked["snowmobile"] = true
	g._refresh()
	var start_pos: Vector3 = player.global_position
	key(KEY_V)
	await frames(3)
	check("key V gets on the snowmobile", g.riding)
	var wev := InputEventKey.new()
	wev.keycode = KEY_W
	wev.physical_keycode = KEY_W
	wev.pressed = true
	Input.parse_input_event(wev)
	player.rotation.y = deg_to_rad(180.0)   # away from the Eye so we stay on the ice
	await get_tree().create_timer(1.0).timeout
	wev.pressed = false
	Input.parse_input_event(wev)
	await frames(3)
	var moved := Vector2(player.global_position.x - start_pos.x, player.global_position.z - start_pos.z).length()
	check("riding covers more than 9 m in one second (walking is ~6)", moved > 9.0)
	key(KEY_V)
	await frames(3)
	check("key V hops off", not g.riding)

	# 6. build a depot through the real click path
	g.unlocked["t_build"] = true
	GameState.currency = 500.0
	key(KEY_7)
	await frames(3)
	check("key 7 selects Build", g.tool == 6)
	key(KEY_Q)
	key(KEY_Q)
	await frames(3)
	check("Q cycles to Depot", g.build_item == 2)
	var dspot := Vector3(-17.5, 0.0, 0.0)
	player.global_position = Vector3(-14.0, g.EYE_H, 5.0)
	aim_at(dspot)
	await frames(3)
	check("the prompt offers to build the depot", g.prompt_label.text.contains("build Depot"))
	mouse(true)
	mouse(false)
	await frames(3)
	check("click builds a depot on open ice", g.depots.size() == 1)
	await get_tree().create_timer(0.6).timeout   # (new buildings grow in for a third of a second)
	g.carry.append(g.roll_fish())
	aim_at(g.depots[0].pos + Vector3(0, 1.0, 0)) if g.depots.size() > 0 else null
	await frames(3)
	check("aiming at the depot finds it", g._aim() == "depot:0")
	var fed_dep: int = g.stats.eye_fed
	mouse(true)
	mouse(false)
	var dep_wait := 0.0
	while g.stats.eye_fed == fed_dep and dep_wait < 8.0:
		await get_tree().create_timer(0.1).timeout
		dep_wait += 0.1
	check("the depot sled fed the Eye", g.stats.eye_fed == fed_dep + 1)

	mouse(false)
	GameState.delete_save()
	print("BOT %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
