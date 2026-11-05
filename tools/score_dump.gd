extends Node
## Renders the score to WAV files you can listen to without starting the game (headless is fine). Each file is 120 s of the
## director under one mood, mixed offline from the very voices the game plays (volume, pitch and timing as the game would send
## them; the room reverb is approximated with two feedback echoes). Prints peak and RMS per file so level problems show up as numbers.
## Usage: tools/score_dump.sh -> renders/score_{day,dusk,night,aurora,blizzard,eye}.wav

const RATE := 22050
const SECS := 120.0

func _ready() -> void:
	var moods := {
		"day": [0.0, 0.0, 0.25, 0, 0.1, false], "dusk": [0.45, 0.0, 0.3, 1, 0.3, false], "night": [1.0, 0.0, 0.25, 1, 0.3, false],
		"aurora": [1.0, 0.0, 0.2, 2, 0.5, true], "blizzard": [0.0, 0.7, 1.0, 1, 0.3, false], "eye": [0.8, 0.0, 0.2, 5, 1.0, true],
	}
	for name in moods:
		var m: Array = moods[name]
		var s := Score.new(7)
		add_child(s)
		while not s.ready_voices:
			await get_tree().process_frame
		s.set_mood(m[0], m[1], m[2], m[3], m[4], m[5])
		var buf := PackedFloat32Array()
		buf.resize(int((SECS + 8.0) * RATE))
		var clock := [0.0]
		s.tap = func(stream: AudioStreamWAV, db: float, pitch: float) -> void:
			var gain := db_to_linear(db)   # (the voices are stored at a peak of 0.8: the game plays them at exactly this gain)
			var d: PackedByteArray = stream.data
			var n := d.size() / 2
			var rate_ratio := float(stream.mix_rate) / RATE * pitch
			var start := int(clock[0] * RATE)
			var out_n := int(n / rate_ratio)
			for i in out_n:
				var si := int(i * rate_ratio)
				if si >= n or start + i >= buf.size():
					break
				buf[start + i] += d.decode_s16(si * 2) / 32768.0 * gain
		var t := 0.0
		while t < SECS:
			s.step(0.05)
			t += 0.05
			clock[0] = t
		# a cold room: two soft feedback echoes
		for i in range(int(0.29 * RATE), buf.size()):
			buf[i] += buf[i - int(0.29 * RATE)] * 0.22
		for i in range(int(0.47 * RATE), buf.size()):
			buf[i] += buf[i - int(0.47 * RATE)] * 0.16
		var peak := 0.0001
		var sum := 0.0
		for v in buf:
			peak = maxf(peak, absf(v))
			sum += v * v
		var rms := sqrt(sum / buf.size())
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		var bytes := PackedByteArray()
		bytes.resize(buf.size() * 2)
		var k := minf(1.0, 0.89 / peak)   # never clip; quiet pieces stay as quiet as they are
		for i in buf.size():
			bytes.encode_s16(i * 2, clampi(int(buf[i] * k * 32767.0), -32767, 32767))
		w.data = bytes
		w.save_to_wav("res://renders/score_%s.wav" % name)
		print("SCORE %-9s notes %3d  pad voices %3d  peak %.2f  rms %.3f (%.1f dBFS)" % [name, s.notes_played, s.pads_played, peak, rms, linear_to_db(rms)])
		s.queue_free()
	get_tree().quit()
