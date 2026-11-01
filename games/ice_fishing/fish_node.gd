class_name FishNode
extends Node3D
## A fish that swims in place: tail wag, body sway, fin flaps. `amp` scales the motion
## (0.3 = lying in a bucket, 1 = swimming, 2.5 = thrashing on the line).

var kind := "fish"
var sway: Node3D
var tail: Node3D
var fins: Array = []
var glow_mat: StandardMaterial3D
var amp := 0.7
var rate := 7.0
var t := 0.0
var phase := 0.0

func _ready() -> void:
	phase = randf() * TAU

func _process(delta: float) -> void:
	t += delta
	var w := t * rate + phase
	match kind:
		"fish":
			if tail:
				tail.rotation.y = sin(w) * 0.5 * amp
			if sway:
				sway.rotation.y = sin(w - 0.9) * 0.1 * amp
			for i in fins.size():
				fins[i].rotation.x = sin(w * 0.5 + i * PI) * 0.35 * amp
		"coin":
			if sway:
				sway.rotation.y += delta * 3.0
		"pearl":
			if glow_mat:
				glow_mat.emission_energy_multiplier = 1.0 + sin(t * 3.0 + phase) * 0.4
		"boot":
			if sway:
				sway.rotation.z = -0.35 + sin(w * 0.35) * 0.08 * amp
