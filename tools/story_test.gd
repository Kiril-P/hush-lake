extends Node
## Headless test for the story layer: letters arrive at their milestones, the mailbox flag and the shelf follow the story, keepsakes
## come out of junk and persist, dreams and the ending work, and everything survives a save. Run: tools/run_story.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	# ---------- the data ----------
	var ids := {}
	var complete := true
	for l in Story.LETTERS:
		if ids.has(l.id) or String(l.title) == "" or String(l.body).length() < 60 or not l.has("when"):
			complete = false
		ids[l.id] = true
	check("%d letters, each with a title, a body and a trigger, ids unique" % Story.LETTERS.size(), complete and Story.LETTERS.size() >= 14)
	var junk_ok := true
	var kids := {}
	for k in Story.KEEPS:
		kids[k.id] = true
		for j in k.in:
			if not (j in ["Old Boot", "Old Coin", "Glass Pearl"]):
				junk_ok = false
	check("8 keepsakes hide only in junk (boots, coins, pearls)", Story.KEEPS.size() == 8 and kids.size() == 8 and junk_ok)
	var s := Story.blank()
	check("a fresh story has nothing due", Story.due({}, s).is_empty())
	var due := Story.due({"eye_fed": 30}, s)
	check("30 fish fed brings the first two letters in order (%s)" % str(due), due == ["welcome", "rules"])
	s.got = ["welcome", "rules"]
	check("a letter is delivered only once", Story.due({"eye_fed": 30}, s).is_empty())
	check("later milestones bring later letters", "anton" in Story.due({"stage": 3, "eye_fed": 99}, s) and not ("awake" in Story.due({"stage": 3}, s)))
	check("Anton's letter needs every keepsake and an awake Eye", not ("anton_last" in Story.due({"keeps_all": 0, "stage": 5}, s)) and "anton_last" in Story.due({"keeps_all": 1}, s))
	check("unread = got minus read", Story.unread({"got": ["a", "b", "c"], "read": ["b"]}) == ["a", "c"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var st2 := Story.blank()
	var seen := {}
	for i in 200:
		var k := Story.roll_keep("Old Boot", st2, rng)
		if k.is_empty():
			break
		seen[k.id] = true
		st2.keeps.append(k.id)
	check("keepsakes never repeat and each junk has its own (%d from boots)" % seen.size(), seen.size() >= 4 and seen.size() == st2.keeps.size() and Story.roll_keep("Old Boot", st2, rng).is_empty())
	check("a dream has three lines and then the count of what you fed", Story.dream_lines(0, 123).size() == 4 and String(Story.dream_lines(7, 5)[3]).contains("5"))
	# ---------- in the game ----------
	GameState.save_slot = "test_story"
	GameState.delete_save()
	GameState.reset()
	var g = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g)
	g.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	check("the mailbox is a click target by Olga's hut", g.dressing.mailbox_body != null and g.dressing.mailbox_body.get_meta("action") == "mailbox")
	check("an empty mailbox has its flag down", g.dressing._unread == 0 or g.dressing._unread == -1)
	g.stats.eye_fed = 1
	g._refresh()
	check("feeding the Eye once brings the first letter", g.story.got == ["welcome"] and Story.unread(g.story).size() == 1)
	check("the mailbox flag goes up", g.dressing._unread == 1)
	check("aiming at the mailbox says so", g._prompt_for("mailbox").contains("1 new") and g._in_range("mailbox") == (g.aim_flat <= g.RANGE_SIGN))
	g._open_letters()
	check("opening shows the letter writing itself in", g.letters_panel.visible and g.letters_panel.current_id() == "welcome" and g.letters_panel.typing())
	check("a letter is not read until its writing finishes", g.story.read.is_empty())
	g._close_letters()
	check("the first press finishes the writing, which marks it read and drops the flag", g.letters_panel.visible and not g.letters_panel.typing() and g.story.read == ["welcome"] and g.dressing._unread == 0)
	g._close_letters()
	check("the second press closes it", not g.letters_panel.visible)
	# Esc closes a letter without pausing: the game eats the key before the Player frees the mouse
	g._open_letters()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	g._input(esc)
	g._input(esc)
	check("Esc finishes then closes a letter", not g.letters_panel.visible)
	g._toggle_photo()
	g._input(esc)
	check("Esc leaves photo mode", not g.photo and g.get_node("UI").visible)
	g.ledger_panel.visible = true
	g._input(esc)
	check("Esc closes the ledger", not g.ledger_panel.visible)
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	g._open_letters()
	check("keys are eaten while a letter is open", g._letters_input(ev) and not g._letters_input(InputEventKey.new()) == false)
	g.letters_panel.visible = false
	# keepsakes out of junk
	var c := Vector2i(1, 0)
	g.model.stock[c] = {"Old Boot": 60}
	g.keep_rng.seed = 4
	var found0: int = g.story.keeps.size()
	for i in 40:
		g._draw_fish({"c": c})
	var got_keeps: int = g.story.keeps.size() - found0
	check("drawing junk turns up keepsakes (%d from 40 boots)" % got_keeps, got_keeps >= 2)
	check("a keepsake brings Olga's letter about the shelf", g.story.got.has("shelf"))
	check("the shelf shows what you found", g.dressing.shelf.get_children().filter(func(n): return n.has_meta("keep")).size() == g.story.keeps.size())
	check("keepsakes are in the meta (they persist across lakes)", GameState.meta.story.keeps == g.story.keeps)
	# save and load
	g.stats.eye_fed = 1100
	g._refresh()
	var n_got: int = g.story.got.size()
	GameState.save_game(false)
	var g2 = load("res://games/ice_fishing/ice_fishing.tscn").instantiate()
	add_child(g2)
	g2.test_capture = true
	await get_tree().process_frame
	await get_tree().process_frame
	g2._refresh()
	check("a loaded game has the same letters, keepsakes and shelf (%d letters)" % n_got, g2.story.got.size() >= n_got and g2.story.keeps == g.story.keeps and g2.dressing.shelf.get_children().filter(func(n): return n.has_meta("keep")).size() == g.story.keeps.size())
	g2.queue_free()
	# the ending
	for k in Story.KEEPS:
		if not g.story.keeps.has(k.id):
			g.story.keeps.append(k.id)
	g.stats.eye_fed = 9000
	g._refresh()
	check("with every keepsake and an awake Eye, Anton's letter comes", g.story.got.has("anton_last"))
	var pearls0: int = g._meta_int("pearls")
	g.letters_panel.open(["anton_last"], [], 8, 8)
	g.letters_panel.dismiss()
	g._close_letters()
	check("closing Anton's letter plays the ending: pearls, a lit village", g.story.ending and g._meta_int("pearls") == pearls0 + 10)
	g._sync_story_world()
	var lit := false
	for gm in g.scenery.glow_mats:
		if gm[0] == g.scenery.village_mat and gm[1] >= 4.0:
			lit = true
	check("Kestrel Landing's windows stay lit by day after the ending", lit)
	# the overlay itself
	var ov := DreamOverlay.new()
	add_child(ov)
	var done := [false]
	ov.finished.connect(func(): done[0] = true)
	ov.play(["a", "b"], "T", 0.0, 1.0)
	var steps := 0
	while not done[0] and steps < 2000:
		ov._process(0.05)
		steps += 1
	check("the dream plays through and ends (%d steps, total %.1f s)" % [steps, ov.total_time()], done[0] and not ov.visible and steps * 0.05 >= ov.total_time() - 0.1)
	var ov2 := DreamOverlay.new()
	add_child(ov2)
	ov2.play(["a", "b", "c"], "T", 1.0, 3.0)
	for i in 40:
		ov2._process(0.05)
	var ev2 := InputEventKey.new()
	ev2.pressed = true
	ev2.keycode = KEY_SPACE
	ov2._unhandled_input(ev2)
	check("a key skips ahead to the last second", ov2.t >= ov2.total_time() - 1.01)
	print("STORY %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
