class_name FirstFive
extends RefCounted
## The first five minutes as a string of small celebrations. Each "firsts" beat fires once, the moment its condition becomes true: a banner, one of
## Olga's lines and a chime. At five minutes of play a recap says what you have done and points at the one next thing worth doing.
## Everything here is pure (numbers in, text out) so a headless test can walk a whole opening without a window; the game only shows the result.

const RECAP_AT := 300.0
const GAP := 4.0          # at most one beat every this many seconds (they wait their turn, nothing is lost)

## id, banner, Olga's line, sfx
const BEATS := [
	["hole", "FIRST HOLE", "Olga: There. Now the lake knows you.", "tick"],
	["catch", "FIRST CATCH", "Olga: Ha! Look at that. Now carry it to the Eye, dear.", "goal"],
	["feed", "THE EYE BLINKS", "Olga: It likes you. Keep feeding it, it pays in coins.", "goal"],
	["bucket", "A BUCKET", "Olga: Now you can carry a whole haul.", "buy"],
	["auto", "THE LAKE FISHES FOR YOU", "Olga: An Auto-Rod! Even when you are not looking.", "goal"],
	["belt", "FIRST BELT", "Olga: A belt to the Eye. Watch them ride.", "goal"],
]

## Which beats are true given the facts? `facts`: holes, caught, eye_fed, bucket (bool), autos, belts.
static func reached(facts: Dictionary) -> Array:
	var out := []
	if int(facts.get("holes", 0)) >= 1:
		out.append("hole")
	if int(facts.get("caught", 0)) >= 1:
		out.append("catch")
	if int(facts.get("eye_fed", 0)) >= 1:
		out.append("feed")
	if bool(facts.get("bucket", false)):
		out.append("bucket")
	if int(facts.get("autos", 0)) >= 1:
		out.append("auto")
	if int(facts.get("belts", 0)) >= 1:
		out.append("belt")
	return out

## The next beat to show, or "": a reached beat not yet shown, in story order, if `since_last` seconds have passed since the last one.
static func next_beat(facts: Dictionary, shown: Dictionary, since_last: float) -> String:
	if since_last < GAP:
		return ""
	var got := reached(facts)
	for b in BEATS:
		if got.has(b[0]) and not shown.has(b[0]):
			return String(b[0])
	return ""

static func beat(id: String) -> Array:
	for b in BEATS:
		if b[0] == id:
			return b
	return []

## "0:06"
static func clock(secs: float) -> String:
	var s := int(maxf(secs, 0.0))
	return "%d:%02d" % [s / 60, s % 60]

## What to do next: the single most useful nudge for this state.
static func next_step(facts: Dictionary, coins: float, auto_cost: float, bucket_cost: float) -> String:
	if int(facts.get("eye_fed", 0)) < 1:
		return "Carry a fish to the Eye and click its rim."
	if not bool(facts.get("bucket", false)) and coins >= bucket_cost:
		return "Buy a Bucket at the stalls: it carries a whole haul."
	if int(facts.get("autos", 0)) < 1:
		if coins >= auto_cost:
			return "You can afford an Auto-Rod: take the Builder's Kit from the rack and build one on a hole."
		return "Save %d coins for an Auto-Rod: it fishes while you walk." % int(ceil(auto_cost - coins))
	if int(facts.get("belts", 0)) < 1:
		return "Lay a belt (kit: Belt) from your Auto-Rod to the Eye."
	return "Build more Auto-Rods and spur belts: the lake is big and the Eye is hungry."

## The five-minute card text.
static func recap(facts: Dictionary, times: Dictionary, coins: float, auto_cost: float, bucket_cost: float) -> String:
	var bits := []
	if times.has("catch"):
		bits.append("first catch at %s" % clock(float(times.catch)))
	if times.has("feed"):
		bits.append("first fish to the Eye at %s" % clock(float(times.feed)))
	if times.has("auto"):
		bits.append("an Auto-Rod at %s" % clock(float(times.auto)))
	var head := "Five minutes on the ice: %d fish caught, %d fed to the Eye" % [int(facts.get("caught", 0)), int(facts.get("eye_fed", 0))]
	if not bits.is_empty():
		head += " (%s)" % ", ".join(bits)
	return head + ".\nNext: " + next_step(facts, coins, auto_cost, bucket_cost)
