extends Node
## Procedural sound effects + ambient loops (no audio assets needed).
## Usage: sfx.play("catch"), sfx.start_ambient(). M toggles mute (handled by the game).

const RATE := 22050
const POOL := 10

var streams := {}
var players: Array[AudioStreamPlayer] = []
var _next := 0
var muted := false
var sfx_db := 0.0
var amb_db := 0.0
var _pad_player: AudioStreamPlayer
var score: Score   # the adaptive music (shared/score.gd)

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
	streams["drill"] = _wav(_mix([_noise(0.1, 0.22, 26.0, 0.35), _tone(240.0, 200.0, 0.1, 30.0, 0.18)]))
	streams["tick"] = _wav(_tone(1900.0, 1500.0, 0.035, 60.0, 0.5))
	streams["splash"] = _wav(_mix([_noise(0.4, 0.45, 8.0, 0.55), _tone(300.0, 140.0, 0.22, 14.0, 0.25)]))
	streams["plop"] = _wav(_tone(420.0, 160.0, 0.16, 18.0, 0.6))
	streams["hook"] = _wav(_mix([_noise(0.16, 0.5, 20.0, 0.45), _tone(500.0, 1100.0, 0.1, 22.0, 0.35)]))
	streams["reel"] = _wav(_mix([_noise(0.045, 0.3, 60.0, 0.5), _tone(520.0, 440.0, 0.045, 55.0, 0.3)]))   # a soft ratchet click, not a hiss: it repeats all fight long
	streams["rumble"] = _wav(_mix([_noise(3.4, 0.012, 0.25, 0.55), _tone(48.0, 38.0, 3.4, 0.3, 0.4)]))
	streams["swell"] = _wav(_swell(110.0, 330.0, 3.5, 0.4))
	streams["awaken"] = _wav(_mix([_tone(110.0, 110.0, 3.2, 1.0, 0.32), _tone(220.0, 220.0, 3.0, 1.2, 0.26), _tone(330.0, 330.0, 2.8, 1.4, 0.2),
		_tone(440.0, 440.0, 2.6, 1.6, 0.17), _tone(660.0, 660.0, 2.2, 2.0, 0.12), _tone(1320.0, 1320.0, 1.6, 3.0, 0.08), _noise(0.7, 0.25, 4.0, 0.45)]))
	# physical sounds of the new fish-on-ice play
	streams["kick"] = _wav(_mix([_tone(150.0, 55.0, 0.18, 22.0, 0.6), _tone(320.0, 160.0, 0.08, 30.0, 0.3), _noise(0.22, 0.14, 12.0, 0.45)]))
	streams["thud"] = _wav(_mix([_tone(190.0, 75.0, 0.13, 28.0, 0.7), _tone(340.0, 240.0, 0.06, 45.0, 0.3), _noise(0.06, 0.3, 40.0, 0.25)]))   # the mid knock keeps it audible on laptop speakers
	streams["step"] = _wav(_mix([_noise(0.07, 0.45, 34.0, 0.45), _tone(170.0, 120.0, 0.05, 50.0, 0.25)]))
	streams["slide"] = _wav(_noise(0.3, 0.2, 6.0, 0.3))
	# surfaces and tin: a soft crunch on the snow bank, a dry tick with a ring on the ice, and the bucket's clank
	streams["step_snow"] = _wav(_mix([_noise(0.13, 0.16, 16.0, 0.55), _tone(130.0, 95.0, 0.07, 36.0, 0.22)]))
	streams["step_ice"] = _wav(_mix([_noise(0.05, 0.55, 45.0, 0.32), _tone(2100.0, 1750.0, 0.05, 55.0, 0.22), _tone(190.0, 140.0, 0.05, 50.0, 0.22)]))
	streams["clank"] = _wav(_mix([_tone(1180.0, 1140.0, 0.38, 9.0, 0.42), _tone(1760.0, 1700.0, 0.28, 12.0, 0.28), _tone(2650.0, 2600.0, 0.2, 18.0, 0.18), _noise(0.03, 0.5, 60.0, 0.4)]))
	streams["creak"] = _wav(_creak(1.3))
	streams["gust"] = _wav(_swell_noise(4.5))
	streams["owl"] = _wav(_owl())
	streams["hum"] = _wav(_hum(8.0), true)
	streams["bells"] = _wav(_bells())
	streams["bark"] = _wav(_bark())
	streams["caw"] = _wav(_caw())
	streams["wind"] = _wav(_wind(6.0), true)
	streams["pad"] = _wav(_pad(8.0), true)
	_mix_pass()
	# the master bus gets a limiter so a stack of simultaneous sounds can never clip
	var rv := AudioEffectReverb.new()   # a hint of open cold air around everything
	rv.room_size = 0.35
	rv.damping = 0.7
	rv.wet = 0.1
	rv.dry = 1.0
	AudioServer.add_bus_effect(0, rv)
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, lim)
	score = Score.new()
	add_child(score)

## Loudness targets (peak, 0..1) by role, so nothing is accidentally ten times louder than its neighbours:
## quiet UI ticks < everyday action sounds < impacts < stingers. The ambient loops are set far below all of them.
const PEAK := {"tick": 0.28, "reel": 0.3, "drill": 0.32, "step": 0.18, "step_snow": 0.16, "step_ice": 0.2, "clank": 0.5, "slide": 0.2, "coin": 0.38, "deny": 0.4, "buy": 0.45, "bite": 0.5,
	"cast": 0.42, "plop": 0.5, "thud": 0.55, "kick": 0.65, "hook": 0.55, "splash": 0.6, "catch": 0.55, "rare": 0.62, "goal": 0.62,
	"rumble": 0.7, "swell": 0.6, "awaken": 0.8, "creak": 0.3, "gust": 0.35, "wind": 0.5, "pad": 0.3, "owl": 0.3, "caw": 0.3, "hum": 0.5, "bells": 0.3, "bark": 0.4}

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
var _hum_player: AudioStreamPlayer
var hum_level := 0.0     # 0..1: the Eye's low hum under the ice (title screen, the Eye opening, a little more as it wakes)
var hum_target := 0.0

func set_hum(level: float) -> void:
	hum_target = clampf(level, 0.0, 1.0)

var wx_wind := 0.25     # the weather's wind (0..1): the howl swells and gusts come sooner in a storm
var wx_snow := 0.3
var wx_night := 0.0

## The weather's numbers (the game passes them each frame): the wind loop follows them.
func set_weather(wind: float, snow: float, night: float) -> void:
	wx_wind = wind
	wx_snow = snow
	wx_night = night

func _process(delta: float) -> void:
	if _hum_player != null:
		hum_level = move_toward(hum_level, hum_target, delta * 0.35)
		_hum_player.volume_db = -60.0 if hum_level < 0.005 else (-34.0 + 22.0 * hum_level + amb_db)
	if _wind_player == null or muted:
		return
	# the wind breathes slowly, and now and then the ice creaks or a gust rolls across the lake
	var tm := Time.get_ticks_msec() * 0.001
	# the howl follows the weather (a hush in still fog, a roar in a blizzard) and a little more at night
	var storm_db := (wx_wind - 0.25) * 16.0 + wx_night * 1.5 - maxf(wx_snow - 1.0, 0.0) * 0.0
	_wind_player.volume_db = -17.0 + amb_db + storm_db + sin(tm * 0.21) * 2.5 + sin(tm * 0.067) * 1.5
	_wind_player.pitch_scale = 0.9 + 0.25 * wx_wind
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(14.0, 34.0)
		play("creak", -10.0, randf_range(0.7, 1.3))
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(20.0, 50.0) * lerpf(1.4, 0.25, wx_wind)
		play("gust", -12.0 + wx_wind * 5.0, randf_range(0.85, 1.1))

func start_ambient() -> void:
	_hum_player = _play_loop("hum", -60.0)
	_wind_player = _play_loop("wind", -17.0)
	_pad_player = _play_loop("pad", -24.0 + amb_db)

func _play_loop(name: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	add_child(p)
	p.play()
	return p

## How much a sound makes the music speak for a moment (a rare catch, a goal, the Eye waking).
const MUSIC_BUMP := {"catch": 0.12, "rare": 0.5, "goal": 0.4, "awaken": 0.9, "buy": 0.06}

func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if muted or not streams.has(name):
		return
	if score != null and MUSIC_BUMP.has(name):
		score.bump(MUSIC_BUMP[name])
	var p := players[_next]
	_next = (_next + 1) % POOL
	p.stream = streams[name]
	p.volume_db = db - 6.0 + sfx_db
	p.pitch_scale = pitch
	p.play()

## Effects and ambience have their own volumes (0..1) on top of the master volume.
func set_levels(effects: float, ambience: float) -> void:
	sfx_db = linear_to_db(maxf(effects, 0.0001)) if effects > 0.0 else -80.0
	amb_db = linear_to_db(maxf(ambience, 0.0001)) if ambience > 0.0 else -80.0
	if _pad_player:
		_pad_player.volume_db = -24.0 + amb_db

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
	var y2 := 0.0
	for i in n:
		var t := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * 0.11   # a howl around 350 Hz, not a 40 Hz rumble that small speakers drop
		y2 += (y - y2) * 0.25
		out[i] = y2 * (0.5 - 0.5 * cos(TAU * t)) * (0.7 + 0.3 * sin(TAU * 3.0 * t)) * 3.6
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

## The Eye's hum: two slightly detuned low tones that beat slowly, a soft fifth above, a slow swell. Whole cycles, so it loops without a click.
func _hum(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 56.0 * t) * 0.45   # 1 Hz beating
		s += sin(TAU * 82.5 * t) * 0.2 + sin(TAU * 110.0 * t) * 0.14
		s += sin(TAU * 220.0 * t + sin(TAU * 0.25 * t) * 1.5) * 0.04   # a faint shimmer
		var swell := 0.75 + 0.25 * sin(TAU * 0.25 * t)
		out[i] = s * swell * 0.5
	return out

## Sled bells: a quick scatter of small bright pings.
func _bells() -> PackedFloat32Array:
	var parts: Array = []
	var starts := [0.0, 0.07, 0.15, 0.22, 0.31]
	var freqs := [2349.0, 2794.0, 2637.0, 3136.0, 2489.0]
	for i in 5:
		var n := int(0.5 * RATE)
		var tone := PackedFloat32Array()
		tone.resize(n)
		for j in n:
			var t := float(j) / RATE
			tone[j] = (sin(TAU * freqs[i] * t) * 0.6 + sin(TAU * freqs[i] * 2.76 * t) * 0.25) * exp(-t * 11.0) * 0.5
		var pad := PackedFloat32Array()
		pad.resize(int(starts[i] * RATE))
		pad.append_array(tone)
		parts.append(pad)
	return _mix(parts)

## A short sled-dog bark: a rough, quickly falling tone.
func _bark() -> PackedFloat32Array:
	var n := int(0.22 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for j in n:
		var t := float(j) / RATE
		var k := t / 0.22
		phase += TAU * lerpf(520.0, 280.0, k) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		out[j] = (saw * 0.45 + sin(phase) * 0.35 + randf_range(-0.12, 0.12)) * sin(PI * minf(k * 1.6, 1.0)) * exp(-k * 2.2)
	return out

## A night owl: two soft falling hoots, then a longer one.
func _owl() -> PackedFloat32Array:
	var parts: Array = []
	var starts := [0.0, 0.42, 0.95]
	var lens := [0.28, 0.28, 0.5]
	for i in 3:
		var n := int(lens[i] * RATE)
		var tone := PackedFloat32Array()
		tone.resize(n)
		var phase := 0.0
		for j in n:
			var t := float(j) / RATE
			var k: float = t / float(lens[i])
			var fr := lerpf(430.0, 360.0, k) * (1.0 + 0.012 * sin(TAU * 7.0 * t))
			phase += TAU * fr / RATE
			var env := sin(PI * k)
			tone[j] = (sin(phase) * 0.8 + sin(phase * 2.0) * 0.12) * env * env * 0.6
		var pad := PackedFloat32Array()
		pad.resize(int(starts[i] * RATE))
		pad.append_array(tone)
		parts.append(pad)
	return _mix(parts)

## A crow: two rough, falling caws (a buzzy tone with grit).
func _caw() -> PackedFloat32Array:
	var parts: Array = []
	for i in 2:
		var dur := 0.2
		var n := int(dur * RATE)
		var tone := PackedFloat32Array()
		tone.resize(n)
		var phase := 0.0
		for j in n:
			var t := float(j) / RATE
			var k := t / dur
			var fr := lerpf(780.0, 520.0, k)
			phase += TAU * fr / RATE
			var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
			tone[j] = (saw * 0.4 + sin(phase) * 0.3 + randf_range(-0.1, 0.1)) * sin(PI * k) * 0.8
		var pad := PackedFloat32Array()
		pad.resize(int(i * 0.28 * RATE))
		pad.append_array(tone)
		parts.append(pad)
	return _mix(parts)

## A gust: filtered noise that swells and fades (not a loop).
func _swell_noise(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / n
		y += (randf_range(-1.0, 1.0) - y) * 0.13
		y2 += (y - y2) * 0.3
		out[i] = y2 * sin(PI * t) * sin(PI * t) * 3.4
	return out
