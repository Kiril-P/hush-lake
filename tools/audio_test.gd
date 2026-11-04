extends Node
## Headless audio sanity: every generated sound has a sane level (no clipping, none inaudible, quiet UI vs loud stingers in
## the right order), loops end quietly (no click), and the master limiter exists. Prints a level table.
## Run: tools/run_audio.sh

var fails := 0

func check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		fails += 1

func stats(w: AudioStreamWAV) -> Dictionary:
	var d: PackedByteArray = w.data
	var peak := 0
	var sum := 0.0
	var n := d.size() / 2
	for i in range(0, d.size(), 2):
		var v := d.decode_s16(i)
		peak = maxi(peak, absi(v))
		sum += float(v) * float(v)
	return {"peak": peak / 32768.0, "rms": sqrt(sum / maxf(n, 1.0)) / 32768.0, "dur": float(n) / w.mix_rate,
		"first": absf(d.decode_s16(0)) / 32768.0, "last": absf(d.decode_s16(d.size() - 2)) / 32768.0}

func _ready() -> void:
	var sfx = load("res://shared/sfx.gd").new()
	add_child(sfx)
	await get_tree().process_frame
	var st := {}
	for n in sfx.streams:
		st[n] = stats(sfx.streams[n])
		print("LEVEL %-8s peak %.2f  rms %.3f  %.2fs" % [n, st[n].peak, st[n].rms, st[n].dur])
	check("every sound exists", sfx.streams.size() >= 25)
	var clipped := []
	var silent := []
	for n in st:
		if st[n].peak > 0.95:
			clipped.append(n)
		if st[n].peak < 0.1:
			silent.append(n)
	check("nothing clips (peak <= 0.95): %s" % [clipped], clipped.is_empty())
	check("nothing is inaudible (peak >= 0.1): %s" % [silent], silent.is_empty())
	check("UI ticks are quieter than impacts", st.tick.peak < st.thud.peak and st.step.peak < st.kick.peak)
	check("stingers are the loudest everyday sounds", st.awaken.peak >= st.rare.peak and st.rare.peak > st.coin.peak)
	check("a kick is felt more than a footstep", st.kick.rms > st.step.rms * 2.0)
	check("loops start and end quietly (no click)", st.wind.first < 0.02 and st.wind.last < 0.02 and st.pad.first < 0.02 and st.pad.last < 0.02)
	check("the wind loop is a loop", (sfx.streams.wind as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD)
	var has_lim := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLimiter:
			has_lim = true
	check("the master bus has a limiter", has_lim)
	check("ambience sits far below the effects", st.wind.rms < st.kick.rms and st.pad.rms < st.kick.rms)
	print("AUDIO %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
