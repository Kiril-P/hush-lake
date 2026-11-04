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

## Spectrum of a stream: {centroid Hz, share of energy above 5 kHz, share below 150 Hz}. A naive DFT over the first 1024 samples keeps it cheap.
func spectrum(w: AudioStreamWAV) -> Dictionary:
	var d: PackedByteArray = w.data
	var n := mini(d.size() / 2, 1024)
	var x := PackedFloat64Array()
	x.resize(n)
	for i in n:
		x[i] = d.decode_s16(i * 2) / 32768.0 * (0.5 - 0.5 * cos(TAU * i / n))
	var tot := 1e-12
	var cen := 0.0
	var hi := 0.0
	var lo := 0.0
	for k in range(1, n / 2, 2):
		var re := 0.0
		var im := 0.0
		for i in n:
			var a := TAU * k * i / n
			re += x[i] * cos(a)
			im -= x[i] * sin(a)
		var e := re * re + im * im
		var f := float(k) * w.mix_rate / n
		tot += e
		cen += e * f
		if f > 5000.0:
			hi += e
		if f < 150.0:
			lo += e
	return {"centroid": cen / tot, "hi": hi / tot, "lo": lo / tot}

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
	# spectra: nothing that repeats may be shrill, and ambience must have body small speakers can reproduce
	var sp := {}
	for n in ["reel", "drill", "step", "slide", "wind", "gust", "thud", "kick"]:
		sp[n] = spectrum(sfx.streams[n])
		print("SPECTRUM %-6s centroid %5.0f Hz  >5k %4.1f%%  <150 %4.1f%%" % [n, sp[n].centroid, sp[n].hi * 100.0, sp[n].lo * 100.0])
	check("repeating sounds are not shrill (reel and drill: <20% of energy above 5 kHz)", sp.reel.hi < 0.2 and sp.drill.hi < 0.2)
	check("wind and gusts have body above 150 Hz (audible on laptop speakers; the noise is random, so the bound is loose)", sp.wind.lo < 0.7 and sp.gust.lo < 0.7)
	check("thuds and kicks keep some mid knock (not only sub-bass)", sp.thud.lo < 0.9 and sp.kick.lo < 0.85)
	var has_lim := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectLimiter:
			has_lim = true
	check("the master bus has a limiter", has_lim)
	check("ambience sits far below the effects", st.wind.rms < st.kick.rms and st.pad.rms < st.kick.rms)
	print("AUDIO %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails > 0 else 0)
