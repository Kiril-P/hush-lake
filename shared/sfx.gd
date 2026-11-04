extends Node
## Procedural sound effects + ambient loops (no audio assets needed).
## Usage: sfx.play("catch"), sfx.start_ambient(). M toggles mute (handled by the game).

const RATE := 22050
const POOL := 10

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false

func _ready() -> void:
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	streams["cast"] = _wav(_noise(0.28, 0.12, 11.0, 0.5))
	streams["bite"] = _wav(_tone(660.0, 990.0, 0.14, 16.0, 0.5))
	streams["catch"] = _wav(_mix([_tone(880.0, 880.0, 0.3, 8.0, 0.4), _tone(1320.0, 1320.0, 0.3, 9.0, 0.25)]))
	streams["rare"] = _wav(_arp([784.0, 988.0, 1175.0, 1568.0], 0.09, 0.45))
	streams["coin"] = _wav(_arp([1400.0, 1900.0], 0.05, 0.35))
	streams["goal"] = _wav(_arp([523.0, 659.0, 784.0, 1047.0], 0.12, 0.45))
	streams["buy"] = _wav(_tone(520.0, 780.0, 0.18, 10.0, 0.45))
	streams["deny"] = _wav(_tone(200.0, 150.0, 0.16, 12.0, 0.4))
	streams["drill"] = _wav(_noise(0.1, 0.35, 28.0, 0.35))
	streams["tick"] = _wav(_tone(1900.0, 1500.0, 0.035, 60.0, 0.5))
	streams["splash"] = _wav(_mix([_noise(0.4, 0.45, 8.0, 0.55), _tone(300.0, 140.0, 0.22, 14.0, 0.25)]))
	streams["plop"] = _wav(_tone(420.0, 160.0, 0.16, 18.0, 0.6))
	streams["hook"] = _wav(_mix([_noise(0.16, 0.5, 20.0, 0.45), _tone(500.0, 1100.0, 0.1, 22.0, 0.35)]))
	streams["reel"] = _wav(_noise(0.04, 0.8, 70.0, 0.55))
	streams["rumble"] = _wav(_mix([_noise(3.4, 0.012, 0.25, 0.55), _tone(48.0, 38.0, 3.4, 0.3, 0.4)]))
	streams["swell"] = _wav(_swell(110.0, 330.0, 3.5, 0.4))
	streams["awaken"] = _wav(_mix([_tone(110.0, 110.0, 3.2, 1.0, 0.32), _tone(220.0, 220.0, 3.0, 1.2, 0.26), _tone(330.0, 330.0, 2.8, 1.4, 0.2),
		_tone(440.0, 440.0, 2.6, 1.6, 0.17), _tone(660.0, 660.0, 2.2, 2.0, 0.12), _tone(1320.0, 1320.0, 1.6, 3.0, 0.08), _noise(0.7, 0.25, 4.0, 0.45)]))
	# physical sounds of the new fish-on-ice play
	streams["kick"] = _wav(_mix([_tone(150.0, 55.0, 0.18, 22.0, 0.7), _noise(0.22, 0.1, 12.0, 0.45)]))
	streams["thud"] = _wav(_mix([_tone(190.0, 75.0, 0.13, 28.0, 0.7), _noise(0.06, 0.25, 40.0, 0.25)]))
	streams["step"] = _wav(_noise(0.07, 0.2, 38.0, 0.5))
	streams["slide"] = _wav(_noise(0.3, 0.06, 7.0, 0.3))
	streams["creak"] = _wav(_creak(1.3))
	streams["gust"] = _wav(_swell_noise(4.5))
	streams["wind"] = _wav(_wind(6.0), true)
	streams["pad"] = _wav(_pad(8.0), true)
	_mix_pass()
	# the master bus gets a limiter so a stack of simultaneous sounds can never clip
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)

## Loudness targets (peak, 0..1) by role, so nothing is accidentally ten times louder than its neighbours:
## quiet UI ticks < everyday action sounds < impacts < stingers. The ambient loops are set far below all of them.
const PEAK := {"tick": 0.28, "reel": 0.3, "drill": 0.32, "step": 0.18, "slide": 0.2, "coin": 0.38, "deny": 0.4, "buy": 0.45, "bite": 0.5,
	"cast": 0.42, "plop": 0.5, "thud": 0.55, "kick": 0.65, "hook": 0.55, "splash": 0.6, "catch": 0.55, "rare": 0.62, "goal": 0.62,
	"rumble": 0.7, "swell": 0.6, "awaken": 0.8, "creak": 0.3, "gust": 0.35, "wind": 0.5, "pad": 0.3}

func _mix_pass() -> void:
	for n in PEAK:
		if streams.has(n):
			streams[n] = _renormalise(streams[n], PEAK[n])

## Rescales a 16-bit mono stream so its loudest sample is `peak` (0..1).
func _renormalise(w: AudioStreamWAV, peak: float) -> AudioStreamWAV:
	var data: PackedByteArray = w.data
	var m := 1
	for i in range(0, data.size(), 2):
		m = maxi(m, absi(data.decode_s16(i)))
	var k := peak * 32000.0 / float(m)
	var out := PackedByteArray()
	out.resize(data.size())
	for i in range(0, data.size(), 2):
		out.encode_s16(i, clampi(int(data.decode_s16(i) * k), -32767, 32767))
	w.data = out
	return w

var _creak_t := 12.0
var _gust_t := 6.0
var _wind_player: AudioStreamPlayer

func _process(delta: float) -> void:
	if _wind_player == null or muted:
		return
	# the wind breathes slowly, and now and then the ice creaks or a gust rolls across the lake
	var tm := Time.get_ticks_msec() * 0.001
	_wind_player.volume_db = -17.0 + sin(tm * 0.21) * 2.5 + sin(tm * 0.067) * 1.5
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(14.0, 34.0)
		play("creak", -10.0, randf_range(0.7, 1.3))
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(20.0, 50.0)
		play("gust", -12.0, randf_range(0.85, 1.1))

func start_ambient() -> void:
	_wind_player = _play_loop("wind", -17.0)
	_play_loop("pad", -24.0)

func _play_loop(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if muted or not streams.has(name):
		return
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = streams[name]
	p.volume_db = db - 6.0
	p.pitch_scale = pitch
	p.play()

func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	return muted

# ----- synthesis -----
func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w

func _tone(f0: float, f1: float, dur: float, decay: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(f0, f1, t / dur) / RATE
		out[i] = sin(phase) * exp(-decay * t) * minf(1.0, t / 0.004) * vol
	return out

func _noise(dur: float, k: float, decay: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += (randf_range(-1.0, 1.0) - y) * k
		out[i] = y * exp(-decay * t) * vol * 3.0
	return out

## A tone that grows from nothing: tension before something happens.
func _swell(f0: float, f1: float, dur: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		phase += TAU * lerpf(f0, f1, k * k) / RATE
		out[i] = (sin(phase) + 0.5 * sin(phase * 1.5)) * k * k * vol * minf(1.0, (dur - t) / 0.05)
	return out

func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out

func _arp(freqs: Array, step: float, vol: float) -> PackedFloat32Array:
	var parts := []
	for i in freqs.size():
		var tone := _tone(freqs[i], freqs[i], 0.25, 9.0, vol)
		var pad := PackedFloat32Array()
		pad.resize(int(i * step * RATE))
		pad.append_array(tone)
		parts.append(pad)
	return _mix(parts)

# seamless loops: amplitude is zero at both ends so there is no click
func _wind(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * 0.03
		out[i] = y * (0.5 - 0.5 * cos(TAU * t)) * 2.2
	return out

func _pad(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var freqs := [220.0, 262.0, 330.0, 440.0]  # A minor, whole cycles in `dur`
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t) * 0.18
		var env := sin(PI * t / dur)
		out[i] = s * env * env
	return out

## The long groan of ice under stress: a falling, wobbling tone with a bit of grit.
func _creak(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / dur
		var f := lerpf(520.0, 190.0, k) * (1.0 + 0.06 * sin(TAU * 9.0 * t) + 0.03 * sin(TAU * 23.0 * t))
		phase += TAU * f / RATE
		var env := sin(PI * k)
		out[i] = (sin(phase) * 0.6 + sin(phase * 2.01) * 0.25 + randf_range(-0.08, 0.08)) * env * env * 0.5
	return out

## A gust: filtered noise that swells and fades (not a loop).
func _swell_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * 0.045
		y2 += (y - y2) * 0.2
		out[i] = y2 * sin(PI * t) * sin(PI * t) * 2.4
	return out
