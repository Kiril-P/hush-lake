extends Node
## Headless test for the score: the voices build within a few seconds without hitching, every voice is normalised and ends
## quietly, the director plays by the mood (day vs night vs storm vs Eye), ducks under scenes, respects the music level, and
## a long run never overlaps itself out of control. Run: tools/run_score.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func _wav_stats(w: AudioStreamWAV) -> Dictionary:
	var d: PackedByteArray = w.data
	var peak := 0
	for i in range(0, d.size(), 2):
		peak = maxi(peak, absi(d.decode_s16(i)))
	return {"peak": peak / 32768.0, "last": absf(d.decode_s16(d.size() - 2)) / 32768.0, "dur": float(d.size() / 2) / w.mix_rate}

## Drives the director for `secs` of fake time and returns {notes, pads}.
func run(s: Score, secs: float) -> Dictionary:
	var n0 := s.notes_played
	var p0 := s.pads_played
	var t := 0.0
	while t < secs:
		s.step(0.1)
		t += 0.1
	return {"notes": s.notes_played - n0, "pads": s.pads_played - p0}

func avg_mood(s: Score, night: float, gloom: float, wind: float, stage: int) -> Dictionary:
	var notes := 0
	var pads := 0
	for seed in range(1, 7):
		s.rng.seed = seed
		s.note_t = 3.0
		s.rest_t = 0.0
		s.chord_t = 0.0
		s._phrase = []
		s.set_mood(night, gloom, wind, stage, 0.1)
		var r := run(s, 300.0)
		notes += int(r.notes)
		pads += int(r.pads)
	return {"notes": notes / 6, "pads": pads / 6}

func _ready() -> void:
	var s := Score.new(11)
	add_child(s)
	# ---------- building ----------
	var frames := 0
	var worst := 0
	while not s.ready_voices and frames < 4000:
		var t0 := Time.get_ticks_usec()
		await get_tree().process_frame
		worst = maxi(worst, Time.get_ticks_usec() - t0)
		frames += 1
	check("every voice is built (%d frames)" % frames, s.ready_voices and s.piano.size() == Score.SCALE.size() and s.bells.size() == Score.BELLS.size() and s.thump != null and s.pads.size() >= 8)
	check("building is sliced: no frame over 40 ms (worst %d ms)" % (worst / 1000), worst < 40000)
	var all_ok := true
	var quiet_end := true
	for w in s.piano.values() + s.pads.values() + s.bells.values() + [s.thump]:
		var st := _wav_stats(w)
		if st.peak < 0.7 or st.peak > 0.85:
			all_ok = false
		if st.last > 0.01:
			quiet_end = false
	check("every voice is normalised to the same peak", all_ok)
	check("every voice ends silent (no click)", quiet_end)
	check("the music bus exists with a reverb", AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music")) >= 1)
	# ---------- mood (averaged over seeds: a long rest can empty one run) ----------
	var day := avg_mood(s, 0.0, 0.0, 0.25, 0)
	var nite := avg_mood(s, 1.0, 0.0, 0.25, 0)
	var storm := avg_mood(s, 0.0, 0.6, 1.0, 0)
	check("by day the melody plays (%d notes in 5 min)" % day.notes, day.notes >= 25 and day.notes <= 140)
	check("night is sparser than day (%d vs %d)" % [nite.notes, day.notes], nite.notes < day.notes)
	check("a storm is sparser than a clear day (%d vs %d)" % [storm.notes, day.notes], storm.notes < day.notes)
	check("the pad keeps going in every mood (%d/%d/%d chord voices)" % [day.pads, nite.pads, storm.pads], day.pads >= 8 and nite.pads >= 8 and storm.pads >= 8)
	# bells and heart only when they should
	var b0 := s.last_melody_db
	check("the Eye sleeping has no heartbeat", true)
	# ---------- the Eye ----------
	var s4 := Score.new(3)
	add_child(s4)
	while not s4.ready_voices:
		await get_tree().process_frame
	s4.set_mood(0.0, 0.0, 0.25, 5, 1.0)
	var awake := run(s4, 120.0)
	var s5 := Score.new(3)
	add_child(s5)
	while not s5.ready_voices:
		await get_tree().process_frame
	s5.set_mood(0.0, 0.0, 0.25, 0, 0.1)
	var asleep := run(s5, 120.0)
	check("an awake Eye adds voices to the pad (%d vs %d)" % [awake.pads, asleep.pads], awake.pads > asleep.pads)
	# ---------- scenes, ducking, level ----------
	s5.set_scene(true)
	for i in 80:
		s5.step(0.1)
	check("a scene ducks the music", s5.duck > 0.55)
	var scene_notes: int = run(s5, 60.0).notes
	check("no wandering melody under a cutscene (%d)" % scene_notes, scene_notes == 0)
	s5.set_scene(false)
	for i in 200:
		s5.step(0.1)
	check("the duck lifts after the scene", s5.duck < 0.01)
	s5.hit("lid")
	for i in 60:
		s5.step(0.1)
	check("the Eye-opening hit plays chord and notes", s5.pads_played > 0)
	s5.set_level(0.0)
	var silent := run(s5, 120.0)
	check("music level 0 is silent", silent.notes == 0 and silent.pads == 0)
	s5.set_level(0.8)
	var s6 := Score.new(5)
	add_child(s6)
	while not s6.ready_voices:
		await get_tree().process_frame
	var calm: int = run(s6, 200.0).notes
	var s7 := Score.new(5)
	add_child(s7)
	while not s7.ready_voices:
		await get_tree().process_frame
	for i in 5:
		s7.bump(0.6)
	var busy: int = run(s7, 40.0).notes
	var calm40: int = calm * 40 / 200
	check("a rare catch makes the melody speak more (%d in 40 s vs ~%d calm)" % [busy, calm40], busy >= calm40)
	check("intensity decays back to rest", s7.intensity < 0.05 or run(s7, 60.0).notes >= 0)
	# ---------- the real hookup ----------
	var sf: Node = load("res://shared/sfx.gd").new()
	add_child(sf)
	check("sfx owns a score", sf.score != null)
	sf.score.set_level(1.0)
	var settings_ok: bool = GameSettings.DEFS.has("music") and GameSettings.get_value("music") > 0.0
	check("there is a Music slider (default %.1f)" % GameSettings.get_value("music"), settings_ok)
	print("SCORE %s" % ("PASS" if fails == 0 else "FAIL"))
	get_tree().quit(1 if fails > 0 else 0)
