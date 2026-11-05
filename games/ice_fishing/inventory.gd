class_name Inventory
extends RefCounted
## Your hands: three slots and the one you are holding. Nothing else is "inventory" in this game.
## A slot holds one item:
##   {"k": "tool",   "t": 0|1|2}      Drill, Rod, Builder's kit
##   {"k": "fish",   "f": fish dict}  one fish (carried, throwable)
##   {"k": "bucket", "fish": [..]}    a bucket and the fish inside it
## An empty slot is {}. This class is plain data (no scene nodes), so tests can drive it directly.

const SLOTS := 3

const TOOL_DRILL := 0
const TOOL_ROD := 1
const TOOL_BUILDER := 2

var slots: Array = []
var active := 0

func _init() -> void:
	clear()

func clear() -> void:
	slots = []
	for i in SLOTS:
		slots.append({})
	active = 0

static func tool_item(t: int) -> Dictionary:
	return {"k": "tool", "t": t}

static func fish_item(f: Dictionary) -> Dictionary:
	return {"k": "fish", "f": f}

static func bucket_item(fish: Array = []) -> Dictionary:
	return {"k": "bucket", "fish": fish}

func cur() -> Dictionary:
	return slots[active]

func kind() -> String:
	return String(slots[active].get("k", ""))

func is_empty_slot(i: int) -> bool:
	return slots[i].is_empty()

## The first free slot, starting from the active one (so a pickup lands in your hand when it can), or -1.
func free_slot() -> int:
	for k in SLOTS:
		var i := (active + k) % SLOTS
		if slots[i].is_empty():
			return i
	return -1

func free_count() -> int:
	var n := 0
	for s in slots:
		if s.is_empty():
			n += 1
	return n

func select(i: int) -> bool:
	if i < 0 or i >= SLOTS or i == active:
		return false
	active = i
	return true

func cycle(dir: int) -> void:
	active = posmod(active + dir, SLOTS)

## Puts an item in the first free slot; returns the slot or -1 when full.
func put(item: Dictionary) -> int:
	var i := free_slot()
	if i >= 0:
		slots[i] = item
	return i

## Removes and returns what is in slot i.
func take(i: int) -> Dictionary:
	var it: Dictionary = slots[i]
	slots[i] = {}
	return it

func find_tool(t: int) -> int:
	for i in SLOTS:
		if slots[i].get("k", "") == "tool" and int(slots[i].t) == t:
			return i
	return -1

func buckets() -> Array:   # slot indices holding a bucket, the active one first
	var out := []
	for k in SLOTS:
		var i := (active + k) % SLOTS
		if slots[i].get("k", "") == "bucket":
			out.append(i)
	return out

func bucket_count() -> int:
	return buckets().size()

## Every fish you carry: loose fish items and what is inside the buckets (the same dicts, so changing one changes it everywhere).
func cargo() -> Array:
	var out := []
	for s in slots:
		match String(s.get("k", "")):
			"fish": out.append(s.f)
			"bucket": out.append_array(s.fish)
	return out

func cargo_count() -> int:
	var n := 0
	for s in slots:
		match String(s.get("k", "")):
			"fish": n += 1
			"bucket": n += s.fish.size()
	return n

## Fish that would still fit: free room in every carried bucket (each holds `cap`) plus every empty slot (one fish each).
func room(cap: int) -> int:
	var n := free_count()
	for s in slots:
		if s.get("k", "") == "bucket":
			n += maxi(cap - s.fish.size(), 0)
	return n

## Empties everything carried (buckets stay, tools stay, loose fish items go). Returns the fish.
func take_cargo() -> Array:
	var out := []
	for i in SLOTS:
		var s: Dictionary = slots[i]
		match String(s.get("k", "")):
			"fish":
				out.append(s.f)
				slots[i] = {}
			"bucket":
				out.append_array(s.fish)
				s.fish = []
	return out

## Adds one fish to the best place that has room. A held bucket first, then an empty slot (the fish is in your hand),
## then any other bucket. `to_bucket_first` flips that (a sweep with E fills buckets before your hands).
## Returns the slot it went to, or -1 when everything is full.
func add_fish(f: Dictionary, cap: int, to_bucket_first := false) -> int:
	var act: Dictionary = slots[active]
	if act.get("k", "") == "bucket" and act.fish.size() < cap:
		act.fish.append(f)
		return active
	if not to_bucket_first:
		var fs := free_slot()
		if fs >= 0:
			slots[fs] = fish_item(f)
			return fs
	for i in buckets():
		if slots[i].fish.size() < cap:
			slots[i].fish.append(f)
			return i
	if to_bucket_first:
		var fs2 := free_slot()
		if fs2 >= 0:
			slots[fs2] = fish_item(f)
			return fs2
	return -1

## Takes one fish out of what you carry: a loose fish item first (it frees a slot), else the last fish of the fullest bucket.
## Returns {} when you carry none.
func pop_fish() -> Dictionary:
	for i in SLOTS:
		if slots[i].get("k", "") == "fish":
			var f: Dictionary = slots[i].f
			slots[i] = {}
			return f
	var best := -1
	for i in buckets():
		if best < 0 or slots[i].fish.size() > slots[best].fish.size():
			best = i
	if best >= 0 and not slots[best].fish.is_empty():
		return slots[best].fish.pop_back()
	return {}
