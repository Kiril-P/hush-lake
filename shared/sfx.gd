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
	streams["wind"] = _wav(_wind(6.0), true)
	streams["pad"] = _wav(_pad(8.0), true)

func start_ambient() -> void:
	_play_loop("wind", -14.0)
	_play_loop("pad", -20.0)

func _play_loop(name: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	add_child(p)
	p.play()

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
