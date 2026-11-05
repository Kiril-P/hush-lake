class_name Weather
extends RefCounted
## The lake's weather as plain data: a small state machine that drifts between clear, flurries, snowfall, blizzard and fog, blending every
## number smoothly so nothing pops. It knows nothing about nodes; the scenery, the sound and the game read its numbers.
##   snow  how much it snows (0 .. 2): 0.3 is the old gentle flurry, 2 is a blizzard
##   fog   multiplier on the fog density (1 = clear air)
##   wind  0..1: howl volume, gusts, how far the snow leans
##   gloom 0..1: how grey and dark the sky goes
##   bite  multiplier on the wait for a bite (below 1 = bites come sooner)
##   rare  multiplier on the odds of rare fish
## Nothing is hostile: even a blizzard only costs you the long view.

const STATES := {
	"clear":    {"label": "Clear",     "snow": 0.30, "fog": 1.0, "wind": 0.25, "gloom": 0.00, "bite": 1.00, "rare": 1.00, "temp": 0.0},
	"flurry":   {"label": "Flurries",  "snow": 0.75, "fog": 1.6, "wind": 0.35, "gloom": 0.15, "bite": 0.96, "rare": 1.00, "temp": -1.0},
	"snowfall": {"label": "Snowfall",  "snow": 1.25, "fog": 3.5, "wind": 0.50, "gloom": 0.35, "bite": 0.90, "rare": 1.05, "temp": -2.0},
	"blizzard": {"label": "Blizzard",  "snow": 2.00, "fog": 9.0, "wind": 1.00, "gloom": 0.60, "bite": 0.82, "rare": 1.15, "temp": -6.0},
	"fog":      {"label": "Fog",       "snow": 0.15, "fog": 12.0, "wind": 0.10, "gloom": 0.30, "bite": 0.95, "rare": 0.95, "temp": 1.0},
}
## What can follow what (weights). Storms build and fade; fog comes on still air.
const NEXT := {
	"clear":    {"clear": 3, "flurry": 4, "fog": 1.5, "snowfall": 1},
	"flurry":   {"clear": 3, "flurry": 1, "snowfall": 4, "fog": 0.5},
	"snowfall": {"flurry": 4, "snowfall": 1, "blizzard": 2, "clear": 1},
	"blizzard": {"snowfall": 5, "flurry": 1},
	"fog":      {"clear": 4, "flurry": 2},
}
const KEYS := ["snow", "fog", "wind", "gloom", "bite", "rare"]
const CALM_START := 180.0     # seconds of play at the start that are always clear (onboarding must not fight a storm)
const BLEND_SECS := 14.0
const AURORA_RARE := 1.4

var cur := "clear"
var nxt := "clear"
var hold := 90.0              # seconds left in the current state
var blend := 1.0              # 0..1 from the previous numbers toward `cur`
var vals: Dictionary = {}     # the live, blended numbers (see KEYS)
var from_vals: Dictionary = {}
var aurora := false           # an aurora night is on (set once per night)
var aurora_decided := false
var always_aurora := false    # the Eye is awake (stage 5): every night under a quiet sky has an aurora
var was_night := false
var enabled := true
var rng := RandomNumberGenerator.new()
var elapsed := 0.0

func _init(seed_in := 0) -> void:
	rng.seed = seed_in if seed_in != 0 else int(Time.get_ticks_usec())
	for k in KEYS:
		vals[k] = STATES.clear[k]
	from_vals = vals.duplicate()
	hold = rng.randf_range(80.0, 150.0)

func label() -> String:
	return STATES[cur].label

func temp_offset() -> float:
	return lerpf(float(STATES[cur].temp), float(STATES[nxt].temp), 1.0 - blend) if blend < 1.0 else float(STATES[cur].temp)

## Starts blending toward a state right now (debug key, tests, saves).
func force(state: String) -> void:
	if not STATES.has(state):
		return
	from_vals = vals.duplicate()
	cur = state
	nxt = state
	blend = 0.0
	hold = rng.randf_range(70.0, 150.0)

func _pick_next() -> String:
	var opts: Dictionary = NEXT[cur]
	var total := 0.0
	for k in opts:
		total += float(opts[k])
	var r := rng.randf() * total
	for k in opts:
		r -= float(opts[k])
		if r <= 0.0:
			return k
	return "clear"

## Advance by `delta` seconds of play. `night` is the sky's 0..1 darkness (for the aurora). `allow_change` is false in cutscenes.
func tick(delta: float, night: float, allow_change := true) -> void:
	elapsed += delta
	if not enabled:
		if cur != "clear":
			force("clear")
		aurora = false
	elif allow_change and elapsed > CALM_START:
		hold -= delta
		if hold <= 0.0:
			var n := _pick_next()
			if n != cur:
				force(n)
			else:
				hold = rng.randf_range(70.0, 150.0)
	if blend < 1.0:
		blend = minf(blend + delta / BLEND_SECS, 1.0)
	var k := smoothstep(0.0, 1.0, blend)
	var tgt: Dictionary = STATES[cur]
	for key in KEYS:
		vals[key] = lerpf(float(from_vals[key]), float(tgt[key]), k)
	# the aurora: decided once as night falls; only under a quiet sky
	var is_night := night > 0.6
	if is_night and not was_night:
		aurora_decided = false
	if is_night and not aurora_decided:
		aurora_decided = true
		aurora = enabled and (cur in ["clear", "flurry"]) and (always_aurora or rng.randf() < 0.55)
	if not is_night and night < 0.3:
		aurora = false
		aurora_decided = false
	was_night = is_night

func aurora_on() -> bool:
	return aurora and enabled and cur in ["clear", "flurry"]   # a storm that rolls in puts it out (the curtains are hidden, so is the bonus)

func rare_mult() -> float:
	return float(vals.rare) * (AURORA_RARE if aurora_on() else 1.0)

func to_dict() -> Dictionary:
	return {"cur": cur, "hold": hold, "blend": blend, "from": from_vals, "aurora": aurora, "decided": aurora_decided, "was": was_night, "el": elapsed}

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	cur = String(d.get("cur", "clear"))
	if not STATES.has(cur):
		cur = "clear"
	nxt = cur
	hold = float(d.get("hold", 90.0))
	blend = float(d.get("blend", 1.0))
	var fv: Dictionary = d.get("from", {})
	for key in KEYS:
		from_vals[key] = float(fv.get(key, STATES[cur][key]))
	aurora = bool(d.get("aurora", false))
	aurora_decided = bool(d.get("decided", false))
	was_night = bool(d.get("was", false))
	elapsed = float(d.get("el", 0.0))
	var k := smoothstep(0.0, 1.0, blend)
	for key in KEYS:
		vals[key] = lerpf(float(from_vals[key]), float(STATES[cur][key]), k)
