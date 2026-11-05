class_name Story
extends RefCounted
## The Eye's story, told in small things instead of cutscenes: letters Olga leaves in the mailbox as you reach milestones,
## keepsakes you fish up (each was once a gift to the Eye, and ends up on Olga's shelf), dreams between lakes, and an ending
## that lights the village across the lake. Pure data and pure functions (no scene nodes) so tests can drive it.
##
## The arc: the Eye is not hungry, it is lonely. The village fed it so it would not be alone; Anton fed it for thirty-nine
## winters; the fish were how people said "we are still here". Progress is kept in GameState.meta["story"] so it survives
## refreezing: {got: [letter ids], read: [letter ids], keeps: [keepsake ids], dreams: n, ending: bool}.

## id, title, when {k: ctx key, n: needed}, body (plain text; \n = line break)
const LETTERS := [
	{"id": "welcome", "title": "To whoever comes next", "when": {"k": "eye_fed", "n": 1},
		"body": "Dear you,\n\nIf you are reading this, you fed it, and it let you. That is more than most managed.\n\nI will not pretend to understand the Eye. Anton fed it for thirty-nine winters and he did not understand it either. He said it was not hungry. Only polite.\n\nPut the fish in. Keep warm. Do not stare into it after dark.\n\n- Olga"},
	{"id": "rules", "title": "Anton's rules", "when": {"k": "eye_fed", "n": 25},
		"body": "Three rules, pinned inside the hut door in his handwriting:\n\n1. Feed it before you feed yourself.\n2. Never take back what you have given.\n3. Say goodnight.\n\nI never understood the third. I say it anyway, every evening, to the window. You might try.\n\n- O."},
	{"id": "shore", "title": "The lights across the lake", "when": {"k": "sectors", "n": 3},
		"body": "The windows across the lake are Kestrel Landing. Nobody has lived there since the thaw. You will see them glow at night, some nights, and I have stopped telling myself it is the moon.\n\nDo not walk over. It is farther than it looks. It is always farther than it looks.\n\n- O."},
	{"id": "shelf", "title": "Where did you find that?", "when": {"k": "keeps", "n": 1},
		"body": "That was in the water? I know that. I know all of them.\n\nEverything the lake gives back was a gift once, left at the rim by someone from the Landing, one winter at a time. It kept them. I never knew it kept them.\n\nBring them to me. I have cleared a shelf by the door.\n\n- O."},
	{"id": "look", "title": "It looked at you", "when": {"k": "stage", "n": 2},
		"body": "I saw it from the window. It turned and looked straight at you.\n\nIt looked at Anton like that, the first time. After a few winters it looked at him the way a dog looks at the door when it hears a step it knows.\n\nI do not say that to frighten you. I say it because it is a kind of look.\n\n- O."},
	{"id": "visitors", "title": "Visitors", "when": {"k": "visitors", "n": 1},
		"body": "Not everything that comes up is from this lake. Some come with the hour, or with the weather, or with the lights in the sky.\n\nAnton called them visitors and left the door unlocked for them. I think the Eye lets them through the way you let a friend's friend into the party.\n\nBe polite to the ones with lanterns.\n\n- O."},
	{"id": "anton", "title": "His last winter", "when": {"k": "stage", "n": 3},
		"body": "His last winter, Anton fed it every night. I asked why so many. He said: it is nearly awake, Olga. It should not wake alone.\n\nIn the morning he walked out across the ice and it held him all the way. I watched from the window. It never let him fall.\n\nI think that is what he wanted me to see.\n\n- O."},
	{"id": "giving", "title": "On giving", "when": {"k": "tithe", "n": 5},
		"body": "You tithe it now. Coins down into the Eye, nothing to show for it. Good.\n\nAnton said giving is the only kind of money that stays. He said a lot of things. Half of them were true and the other half were kind.\n\n- O."},
	{"id": "forty", "title": "I lied about the forty winters", "when": {"k": "stage", "n": 4},
		"body": "I always said forty winters. Anton fed it thirty-nine. The fortieth was me, alone, the winter after, and I did it badly.\n\nYou are doing better than either of us. I wanted you to know that before it wakes.\n\n- O."},
	{"id": "things", "title": "The shelf", "when": {"k": "keeps", "n": 4},
		"body": "Four things on my shelf now, each from a different winter, each from someone who wanted the ice to hold.\n\nI have been thinking about it all week. I do not think the Eye was ever hungry. I think it was lonely, and the fish were how people told it: we are still here.\n\n- O."},
	{"id": "awake", "title": "It is awake", "when": {"k": "stage", "n": 5},
		"body": "Do you hear it? The ice does not hum any more. It hums back.\n\nIt is awake, and it is not hungry. It never was. Look at it properly. It is counting what you gave.\n\nThank you for not stopping.\n\n- O."},
	{"id": "again", "title": "The lake froze again", "when": {"k": "lakes", "n": 1},
		"body": "The lake froze again overnight, thicker than before, and the Eye is nearly closed. It does that. Anton said it sleeps between visitors.\n\nI put the kettle on. Come in when you are ready.\n\n- O."},
	{"id": "return", "title": "You came back", "when": {"k": "lakes", "n": 2},
		"body": "You came back. Most do not.\n\nDo you know what the Landing is like at night now? One more window lit each winter you stay. I have been counting from the hut.\n\n- O."},
	{"id": "anton_last", "title": "From Anton", "when": {"k": "keeps_all", "n": 1},
		"ending": true,
		"body": "(an envelope found under the thermos, in Anton's hand)\n\nOlga,\n\nIf this reached you, somebody finally brought the last of it home.\n\nI fed it so it would not be alone. Please tell whoever came after me that it never needed the fish. It needed the walking out, the saying goodnight, the coming back. It needed to be remembered while it was still small.\n\nTell it goodnight from me.\n\n- A."},
]

## id, name, which junk catches it can hide in, Olga's line, the colour of its little model on the shelf
const KEEPS := [
	{"id": "thermos", "name": "Anton's thermos", "in": ["Old Boot"], "text": "A dented red thermos. It still smells of cocoa.", "color": Color(0.8, 0.2, 0.2)},
	{"id": "mitten", "name": "A child's mitten", "in": ["Old Boot"], "text": "Orange wool. Somebody came back for it and never did.", "color": Color(0.95, 0.55, 0.2)},
	{"id": "key", "name": "A brass key", "in": ["Old Coin"], "text": "To a door at the Landing that is not there any more.", "color": Color(0.9, 0.72, 0.25)},
	{"id": "ring", "name": "A wedding ring", "in": ["Old Coin", "Glass Pearl"], "text": "Too big for any finger in the village.", "color": Color(1.0, 0.82, 0.3)},
	{"id": "logbook", "name": "The ice log", "in": ["Old Boot"], "text": "Thickness and weather, and one line every winter: it looked at me.", "color": Color(0.2, 0.4, 0.3)},
	{"id": "compass", "name": "A brass compass", "in": ["Glass Pearl", "Old Coin"], "text": "The needle points at the Eye. Not north.", "color": Color(0.85, 0.65, 0.3)},
	{"id": "photo", "name": "A photograph", "in": ["Glass Pearl", "Old Boot"], "text": "The whole village on the ice, waving. Everyone is looking down.", "color": Color(0.92, 0.88, 0.78)},
	{"id": "whistle", "name": "A tin whistle", "in": ["Old Coin", "Old Boot"], "text": "One note left in it. An A, I think.", "color": Color(0.75, 0.8, 0.85)},
]

## Dreams between lakes: three short lines each (the lake you just finished picks the dream), then a line about this winter.
const DREAMS := [
	["...warm hands on cold water.", "Someone says goodnight.", "It tries to say it back."],
	["The village stands on the ice, waving.", "Everyone is looking down.", "It counts them. It counts again."],
	["There is a lantern at the bottom of the lake.", "It is not a fish.", "It is being carried upward."],
	["A door opens in the ice.", "Snow comes in. So does someone's laugh.", "The door stays open."],
	["It dreams of the first fish you gave it.", "Small. Silver. Frightened.", "Fed."],
]

const ENDING_LINES := ["Anton's letter says goodnight.", "The Eye closes, slowly, the way you close a book you will read again.",
	"Across the lake, one by one, the windows of Kestrel Landing light.", "Olga puts the kettle on.", "\"Goodnight,\" you say.\nIt says it back."]

static func letter(id: String) -> Dictionary:
	for l in LETTERS:
		if l.id == id:
			return l
	return {}

static func keep(id: String) -> Dictionary:
	for k in KEEPS:
		if k.id == id:
			return k
	return {}

## A fresh story record.
static func blank() -> Dictionary:
	return {"got": [], "read": [], "keeps": [], "dreams": 0, "ending": false}

## The context a game passes: {eye_fed, stage, sectors, tithe, lakes, keeps (count), visitors (count found), keeps_all (0/1)}.
static func due(ctx: Dictionary, story: Dictionary) -> Array:
	var out := []
	for l in LETTERS:
		if story.got.has(l.id):
			continue
		var w: Dictionary = l.when
		if float(ctx.get(w.k, 0)) >= float(w.n):
			out.append(l.id)
	return out

static func unread(story: Dictionary) -> Array:
	return story.got.filter(func(i): return not story.read.has(i))

## The next keepsake to find among a junk catch: a random one that fits `junk` and is not found yet. {} when none.
static func roll_keep(junk: String, story: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var pool := KEEPS.filter(func(k): return k.in.has(junk) and not story.keeps.has(k.id))
	if pool.is_empty():
		return {}
	return pool[rng.randi() % pool.size()]

## The three lines of the dream after finishing lake number `lakes_done` (0 = the first), plus how much you fed it.
static func dream_lines(lakes_done: int, fed: int) -> Array:
	var d: Array = DREAMS[lakes_done % DREAMS.size()].duplicate()
	d.append("This winter you gave it %d. It kept count." % fed)
	return d
