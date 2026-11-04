extends Node
## Writes every generated sound to WAV files (for offline spectral analysis). Usage: AUDIO_OUT=/dir tools/audio_dump.tscn
func _ready() -> void:
	var sfx = load("res://shared/sfx.gd").new()
	add_child(sfx)
	await get_tree().process_frame
	var out := OS.get_environment("AUDIO_OUT")
	for n in sfx.streams:
		(sfx.streams[n] as AudioStreamWAV).save_to_wav("%s/%s.wav" % [out, n])
	get_tree().quit()
