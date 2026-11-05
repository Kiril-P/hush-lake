class_name Score
extends Node
## The lake's score: a generative, adaptive piece in A minor played on procedural felt-piano, pad and glass-bell voices,
## sent through its own "Music" bus (a long cold reverb) so it sits inside the wind rather than on top of it.
##
## Nothing here is a loop. A slow chord clock (Am - F - C - G, longer at night) holds a pad underneath, and a melody wanders
## the pentatonic scale with rests, little phrases and chord-tone gravity. The mood decides how much of it you hear:
##   day      a note every few seconds, warm and open
##   night    sparse, longer silences, glass bells on top (more under an aurora)
##   weather  gloom and wind thin the melody and darken the pad; a blizzard is mostly drone
##   Eye      from stage 3 a slow heartbeat under the ice; awake (stage 5) an octave of voices joins the pad
##   scenes   the music ducks under cutscenes and plays set pieces (hit("arrival"), hit("lid"), ...)
##   catches  a rare catch or a goal bumps "intensity" and the melody briefly speaks more
## All voices are synthesised in small time slices after launch (no hitch), so the score fades in a few seconds in.

const RATE := 16000
const PAD_RATE := 11025
const BUS := "Music"

# A minor pentatonic across three octaves, low to high (Hz)
const SCALE := [110.0, 130.81, 146.83, 164.81, 196.0, 220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]
# chords: pad voices (Hz) and which scale indices are "chord tones" for the melody
const CHORDS := [
	{"name": "Am", "pad": [110.0, 164.81, 220.0, 261.63], "tones": [0, 1, 3, 5, 6, 8, 10, 11, 13, 15]},
	{"name": "F",  "pad": [87.31, 130.81, 220.0, 329.63], "tones": [1, 5, 6, 8, 10, 11, 13, 15]},
	{"name": "C",  "pad": [130.81, 196.0, 261.63, 329.63], "tones": [1, 3, 4, 6, 8, 9, 11, 13, 14]},
	{"name": "G",  "pad": [98.0, 146.83, 196.0, 293.66], "tones": [2, 4, 7, 9, 12, 14]},
]
const PHRASES := [[0, 2, 1], [0, 1, 3], [2, 1, 0], [0, 3, 2, 1], [1, 0, 2], [0, 2, 4]]   # steps relative to the first note (scale indices)
const BELLS := [1174.66, 1318.51, 1567.98, 1760.0, 2093.0]

var piano := {}        # scale index -> AudioStreamWAV
var pads := {}         # Hz -> AudioStreamWAV
var bells := {}        # index -> AudioStreamWAV
var thump: AudioStreamWAV
var ready_voices := false
var _jobs: Array = []           # [kind, key, freq] still to synthesise
var _job_cur: Dictionary = {}   # the sample being built: {kind,key,freq,i,n,buf,rate}
var _players: Array[AudioStreamPlayer] = []
var _pad_players: Array[AudioStreamPlayer] = []
var _next_p := 0
var _next_pad := 0
var rng := RandomNumberGenerator.new()

# mood (set by the game each frame)
var night := 0.0
var gloom := 0.0
var wind := 0.25
var eye_stage := 0
var eye_open := 0.0
var aurora := false
var in_scene := false
var title_mode := false
var intensity := 0.0         # 0..1, decays: catches and goals make the melody speak more for a moment
var level := 1.0             # the player's music volume (0..1)
var duck := 0.0              # smoothed 0..1: how far the music sits under a cutscene

# clocks
var chord_i := 0
var chord_t := 0.0
var note_t := 3.0
var rest_t := 0.0
var bell_t := 6.0
var beat_t := 4.0
var _idx := 8                # where the melody currently sits on SCALE
var _phrase: Array = []
var _phrase_t := 0.0
var notes_played := 0        # test hooks
var pads_played := 0
var last_melody_db := -99.0

func _init(seed_in := 0) -> void:
	rng.seed = seed_in if seed_in != 0 else int(Time.get_ticks_usec())

func _ready() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.85
		rv.damping = 0.55
		rv.wet = 0.38
		rv.dry = 0.85
		rv.hipass = 0.08
		AudioServer.add_bus_effect(idx, rv)
	for i in 8:
		_players.append(_voice(false))
	for i in 5:
		_pad_players.append(_voice(true))
	# the build order: the pad chord tones first (they carry the piece), then the melody notes, then bells and the heart
	var seen := {}
	for c in CHORDS:
		for f in c.pad:
			if not seen.has(f):
				seen[f] = true
				_jobs.append(["pad", f, f])
	for i in SCALE.size():
		_jobs.append(["piano", i, SCALE[i]])
	for i in BELLS.size():
		_jobs.append(["bell", i, BELLS[i]])
	_jobs.append(["thump", 0, 52.0])

func _voice(_is_pad: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	add_child(p)
	return p

# ---------- the game's side ----------
func set_mood(night_in: float, gloom_in: float, wind_in: float, stage: int, open_frac: float, aurora_in := false) -> void:
	night = night_in
	gloom = gloom_in
	wind = wind_in
	eye_stage = stage
	eye_open = open_frac
	aurora = aurora_in

func set_scene(on: bool) -> void:
	in_scene = on

func set_title(on: bool) -> void:
	title_mode = on

func set_level(v: float) -> void:
	level = clampf(v, 0.0, 1.0)

func bump(amount: float) -> void:
	intensity = clampf(intensity + amount, 0.0, 1.0)

## Set pieces for scenes. "arrival": the sled coming in (a slow rising Am arpeggio). "lid": the Eye opens (a big chord and the heart).
## "awaken": the Eye wakes (the whole chord, an octave up). "stage": a new stage (a short bright run).
func hit(kind: String) -> void:
	if not ready_voices:
		return
	match kind:
		"arrival":
			for k in 5:
				_later(0.9 * k, func(): _note([3, 5, 6, 8, 10][k], -9.0 + k))
			_pad_chord(0, 0.0, -14.0)
		"lid":
			_pad_chord(0, 0.0, -9.0)
			_pad_chord(0, 0.4, -11.0, 2.0)
			_thump(-6.0)
			_later(1.2, func(): _note(13, -8.0))
			_later(2.2, func(): _note(10, -9.0))
		"awaken":
			_pad_chord(2, 0.0, -8.0)
			_pad_chord(2, 0.3, -10.0, 2.0)
			for k in 6:
				_later(0.4 + 0.45 * k, func(): _note([6, 8, 9, 11, 13, 14][k], -9.0))
		"stage":
			for k in 4:
				_later(0.18 * k, func(): _note([8, 9, 11, 13][k], -9.0))
		"catch":
			_note(rng.randi_range(9, 12), -13.0)

var _later_q: Array = []   # [time left, Callable]
func _later(sec: float, f: Callable) -> void:
	_later_q.append([sec, f])

# ---------- synthesis (time-sliced) ----------
func _build_slice(budget_us: int) -> void:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < budget_us:
		if _job_cur.is_empty():
			if _jobs.is_empty():
				ready_voices = true
				return
			var j: Array = _jobs.pop_front()
			var rate := PAD_RATE if j[0] == "pad" else RATE
			var dur := 5.5 if j[0] == "pad" else (3.0 if j[0] == "piano" else (2.6 if j[0] == "bell" else 0.7))
			var n := int(dur * rate)
			var buf := PackedFloat32Array()
			buf.resize(n)
			_job_cur = {"kind": j[0], "key": j[1], "f": float(j[2]), "i": 0, "n": n, "buf": buf, "rate": rate, "dur": dur}
		var jc := _job_cur
		var n2: int = jc.n
		var stop := mini(int(jc.i) + 1500, n2)
		var buf2: PackedFloat32Array = jc.buf
		for i in range(int(jc.i), stop):
			buf2[i] = _sample(String(jc.kind), float(jc.f), float(i) / float(jc.rate), float(jc.dur))
		jc.i = stop
		if stop >= n2:
			_finish(jc)
			_job_cur = {}

func _sample(kind: String, f: float, t: float, dur: float) -> float:
	match kind:
		"piano":   # felt piano: a soft hammer, partials that die faster the higher they are, a touch of detune for warmth
			var k := 1.5 + f / 420.0
			var s := 0.0
			var amps := [1.0, 0.55, 0.28, 0.14, 0.07]
			for h in 5:
				var fh: float = f * (h + 1) * (1.0 + 0.0004 * h * h)
				s += sin(TAU * fh * t) * amps[h] * exp(-t * k * (1.0 + 0.7 * h))
			s += sin(TAU * f * 1.003 * t) * 0.3 * exp(-t * k)
			var att := minf(t / 0.006, 1.0)
			var fade := clampf((dur - t) / 0.3, 0.0, 1.0)
			return s * att * fade * 0.45
		"pad":     # two slightly detuned voices, a soft fifth, a long swell in and out
			var s2 := sin(TAU * f * t) * 0.5 + sin(TAU * (f + 0.45) * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.18 + sin(TAU * f * 1.5 * t) * 0.1
			var env := sin(PI * clampf(t / dur, 0.0, 1.0))
			return s2 * env * env * 0.34
		"bell":    # glass: inharmonic partials, long shimmer
			var s3 := sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.76 * t) * 0.22 * exp(-t * 2.0) + sin(TAU * f * 5.4 * t) * 0.1 * exp(-t * 4.0)
			var fade3 := clampf((dur - t) / 0.4, 0.0, 1.0)
			return s3 * exp(-t * 1.5) * minf(t / 0.003, 1.0) * fade3 * 0.5
		_:         # the heart under the ice: a thump with a falling sine and a quiet second beat
			var s4 := sin(TAU * (f - 14.0 * minf(t, 0.2) * 3.0) * t) * exp(-t * 9.0)
			s4 += sin(TAU * f * 0.9 * (t - 0.22)) * exp(-(t - 0.22) * 11.0) * 0.55 if t > 0.22 else 0.0
			return s4 * 0.8

func _finish(jc: Dictionary) -> void:
	var buf: PackedFloat32Array = jc.buf
	var peak := 0.0001
	for v in buf:
		peak = maxf(peak, absf(v))
	var k := 0.8 / peak   # every voice normalised to the same peak: the mix is set only by the volumes below
	var out := PackedByteArray()
	out.resize(buf.size() * 2)
	for i in buf.size():
		out.encode_s16(i * 2, clampi(int(buf[i] * k * 32767.0), -32767, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(jc.rate)
	w.data = out
	match String(jc.kind):
		"piano": piano[int(jc.key)] = w
		"pad": pads[jc.f] = w
		"bell": bells[int(jc.key)] = w
		_: thump = w

# ---------- playing ----------
func _note(scale_i: int, db: float) -> void:
	var w: AudioStreamWAV = piano.get(clampi(scale_i, 0, SCALE.size() - 1))
	if w == null:
		return
	var p := _players[_next_p]
	_next_p = (_next_p + 1) % _players.size()
	p.stream = w
	p.volume_db = db + _music_db()
	p.pitch_scale = 1.0
	p.play()
	notes_played += 1
	last_melody_db = p.volume_db

func _pad_chord(ci: int, delay: float, db: float, octave := 1.0) -> void:
	var c: Dictionary = CHORDS[ci % CHORDS.size()]
	var k := 0
	for f in c.pad:
		var w: AudioStreamWAV = pads.get(f)
		if w == null:
			continue
		var pl := _pad_players[_next_pad]
		_next_pad = (_next_pad + 1) % _pad_players.size()
		var d := delay + 0.9 * k
		k += 1
		var wv := w
		var oct := octave
		var vol := db - k * 0.8
		_later(d, func():
			pl.stream = wv
			pl.pitch_scale = oct
			pl.volume_db = vol + _music_db()
			pl.play()
			pads_played += 1)

func _thump(db: float) -> void:
	if thump == null:
		return
	var p := _players[_next_p]
	_next_p = (_next_p + 1) % _players.size()
	p.stream = thump
	p.volume_db = db + _music_db()
	p.pitch_scale = 1.0
	p.play()

func _bell(db: float) -> void:
	if bells.is_empty():
		return
	var i := rng.randi_range(0, BELLS.size() - 1)
	var w: AudioStreamWAV = bells.get(i)
	if w == null:
		return
	var p := _players[_next_p]
	_next_p = (_next_p + 1) % _players.size()
	p.stream = w
	p.volume_db = db + _music_db()
	p.pitch_scale = 1.0
	p.play()

## Overall music level in dB: the player's slider, minus the cutscene duck, minus a little in a storm (the wind is the music then).
func _music_db() -> float:
	var l := -80.0 if level <= 0.001 else linear_to_db(level)
	return l - 14.0 * duck - 5.0 * gloom

func _chord_len() -> float:
	return lerpf(22.0, 32.0, night) * (1.0 + 0.4 * gloom)

# ---------- the director ----------
func _process(delta: float) -> void:
	if not ready_voices:
		_build_slice(2500)
		return
	step(delta)

## One tick of the director (also called directly by tests with a fake delta).
func step(delta: float) -> void:
	duck = move_toward(duck, 0.6 if in_scene else 0.0, delta * 0.5)
	intensity = maxf(intensity - delta * 0.08, 0.0)
	for q in _later_q:
		q[0] -= delta
	var due := _later_q.filter(func(q): return q[0] <= 0.0)
	_later_q = _later_q.filter(func(q): return q[0] > 0.0)
	for q in due:
		q[1].call()
	if level <= 0.001:
		return
	# the chord clock and the pad
	chord_t -= delta
	if chord_t <= 0.0:
		chord_t = _chord_len()
		chord_i = (chord_i + 1) % CHORDS.size()
		var pdb := -17.0 + 2.5 * night + 3.0 * gloom - (4.0 if in_scene else 0.0)
		_pad_chord(chord_i, 0.0, pdb)
		if eye_stage >= 5:
			_pad_chord(chord_i, 0.6, pdb - 3.0, 2.0)   # awake: a second octave of voices
		elif eye_stage >= 3:
			_pad_chord(chord_i, 1.4, pdb - 7.0, 2.0)
	# the melody
	if title_mode or not in_scene:
		note_t -= delta
		if note_t <= 0.0:
			var density := lerpf(1.0, 0.45, night) * lerpf(1.0, 0.5, gloom) * (1.0 + 1.2 * intensity)
			if title_mode:
				density = 0.55
			note_t = rng.randf_range(2.6, 6.5) / maxf(density, 0.1)
			if rest_t > 0.0:
				rest_t = maxf(rest_t - note_t, 0.0)   # a long rest: let the silence work
			elif rng.randf() < 0.12 and intensity < 0.2:
				rest_t = rng.randf_range(14.0, 26.0)
			else:
				_melody_step()
	# phrase notes fall in a beat apart
	if not _phrase.is_empty():
		_phrase_t -= delta
		if _phrase_t <= 0.0:
			_idx = clampi(_phrase.pop_front(), 0, SCALE.size() - 1)
			_note(_idx, -12.0 + rng.randf_range(-2.0, 1.0))
			_phrase_t = rng.randf_range(0.42, 0.7)
	# glass bells over the night (and an aurora)
	var bell_amt := clampf((night - 0.45) * 2.0, 0.0, 1.0) * (1.0 if aurora else 0.55) * (1.0 - gloom)
	if bell_amt > 0.02 and not in_scene:
		bell_t -= delta
		if bell_t <= 0.0:
			bell_t = rng.randf_range(3.5, 9.0) / maxf(bell_amt, 0.2)
			_bell(-19.0 + 5.0 * bell_amt)
	# the heart under the ice, slower and softer when the Eye sleeps, steady once it is awake
	if eye_stage >= 3 and not in_scene:
		beat_t -= delta
		if beat_t <= 0.0:
			beat_t = lerpf(5.0, 2.8, clampf(eye_open, 0.0, 1.0))
			_thump(-17.0 + 5.0 * clampf(eye_open, 0.0, 1.0))

## A melody step: usually one note, often the start of a short phrase, drifting toward chord tones.
func _melody_step() -> void:
	var tones: Array = CHORDS[chord_i].tones
	var target: int = _idx + rng.randi_range(-3, 3)
	target = clampi(target, 3, SCALE.size() - 2)
	if rng.randf() < 0.65:   # gravitate to the nearest chord tone
		var best: int = tones[0]
		for t in tones:
			if absi(t - target) < absi(best - target):
				best = t
		target = best
	_idx = target
	_note(_idx, -12.0 + rng.randf_range(-2.5, 1.0))
	if rng.randf() < 0.4 + 0.3 * intensity:
		var ph: Array = PHRASES[rng.randi() % PHRASES.size()]
		_phrase = []
		for s in ph:
			if s == 0:
				continue
			_phrase.append(clampi(_idx + s * (1 if rng.randf() < 0.65 else -1), 0, SCALE.size() - 1))
		_phrase_t = rng.randf_range(0.45, 0.7)
