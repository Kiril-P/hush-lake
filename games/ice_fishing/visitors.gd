class_name Visitors
extends RefCounted
## Visitor fish: species that are not in the lake's finite stock but turn up when the lake is in a certain mood. When you draw a
## fish and the conditions fit, the draw may be a visitor instead (the tile still loses one fish, so the economy is unchanged).
## Plain data + a pure roll(), so tests can drive it. The species themselves (value, colour) live in ice_fishing.gd SPECIES,
## the shapes in fish_model.gd, Olga's journal notes below.

## name -> {when, chance, clue (shown in the journal until found), note (Olga, shown once found), lens [min,max] cm}
const LIST := {
	"Lantern Eel": {"when": "night", "chance": 0.14, "lens": [60.0, 110.0],
		"clue": "Something under the ice carries a lamp. It only comes after dark.",
		"note": "Carries its own little lantern. I never ask where it got the oil."},
	"Ghost Carp": {"when": "fog", "chance": 0.2, "lens": [30.0, 62.0],
		"clue": "Pale shapes drift under the ice on foggy days.",
		"note": "You only see them when you cannot see anything else."},
	"Dawn Salmon": {"when": "dawn", "chance": 0.16, "lens": [50.0, 85.0],
		"clue": "Something warm-coloured rises with the first light.",
		"note": "Up before the birds. Good manners for a fish."},
	"Frost Gar": {"when": "blizzard", "chance": 0.24, "lens": [80.0, 140.0],
		"clue": "Only a real blizzard brings it up, with its long jaw.",
		"note": "Armoured and rude. It likes the storm because nobody argues."},
	"Aurora Char": {"when": "aurora", "chance": 0.3, "lens": [35.0, 60.0],
		"clue": "On nights when the sky is on fire, the water answers.",
		"note": "Wears the sky. I have stopped trying to describe the colour."},
	"Eye Tetra": {"when": "eye5", "chance": 0.14, "lens": [3.0, 6.0],
		"clue": "Tiny sparks that only live near an awake Eye.",
		"note": "They were never fish. They were the Eye's eyelashes, I think."},
}

static func is_visitor(name: String) -> bool:
	return LIST.has(name)

static func note_of(name: String) -> String:
	return String(LIST[name].note) if LIST.has(name) else ""

static func clue_of(name: String) -> String:
	return String(LIST[name].clue) if LIST.has(name) else ""

## ctx: {night 0..1, weather "clear"|..., aurora bool, dawn bool, eye_stage int, stages int}. Returns the visitor's name or "".
static func roll(ctx: Dictionary, rng: RandomNumberGenerator) -> String:
	for n in LIST:
		var v: Dictionary = LIST[n]
		var ok := false
		match String(v.when):
			"night": ok = float(ctx.get("night", 0.0)) > 0.6
			"fog": ok = ctx.get("weather", "") == "fog"
			"blizzard": ok = ctx.get("weather", "") == "blizzard"
			"aurora": ok = bool(ctx.get("aurora", false)) and float(ctx.get("night", 0.0)) > 0.5
			"dawn": ok = bool(ctx.get("dawn", false))
			"eye5": ok = int(ctx.get("eye_stage", 0)) >= int(ctx.get("stages", 5))
		if ok and rng.randf() < float(v.chance) * float(ctx.get("mult", 1.0)):
			return n
	return ""

## True when the clock is in the dawn window (day_t: 0 golden hour, .25 dusk, .5 night, .75 dawn).
static func is_dawn(day_t: float) -> bool:
	var t := fposmod(day_t, 1.0)
	return t > 0.68 and t < 0.84
