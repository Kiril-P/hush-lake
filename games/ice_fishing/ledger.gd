class_name Ledger
extends RefCounted
## The Ledger: lifetime goals that outlast any one lake. Each entry counts something across every winter, and each tier you pass
## pays pearls once (pearls buy perks at the refreeze). Pure data and pure functions, so tests can drive them.
## `value_of` is a Callable(key) -> float supplied by the game (lifetime = banked totals + the lake in progress).

## id, name, what it counts, tier thresholds, pearls per tier
const LIST := [
	{"id": "fed", "name": "The Long Feeding", "desc": "fish fed to the Eye", "tiers": [500, 5000, 25000, 100000], "pearls": [1, 2, 4, 8]},
	{"id": "caught", "name": "Cold Hands", "desc": "fish caught", "tiers": [200, 2000, 10000, 50000], "pearls": [1, 2, 3, 5]},
	{"id": "lakes", "name": "Winters", "desc": "lakes refrozen", "tiers": [1, 3, 6, 10], "pearls": [2, 3, 5, 8]},
	{"id": "sectors", "name": "Open Water", "desc": "sectors cleared", "tiers": [6, 30, 80], "pearls": [1, 3, 6]},
	{"id": "species", "name": "Field Naturalist", "desc": "species in the journal", "tiers": [4, 8, 14], "pearls": [1, 3, 6]},
	{"id": "visitors", "name": "Hosts", "desc": "visitor species met", "tiers": [1, 3, 6], "pearls": [1, 3, 5]},
	{"id": "keeps", "name": "Keeper of Things", "desc": "keepsakes on the shelf", "tiers": [1, 4, 8], "pearls": [1, 3, 5]},
	{"id": "letters", "name": "Correspondence", "desc": "letters read", "tiers": [1, 7, 14], "pearls": [1, 2, 4]},
	{"id": "tithe", "name": "Generous", "desc": "tithes given to the Eye", "tiers": [5, 25, 100], "pearls": [1, 2, 4]},
	{"id": "rigs", "name": "Heavy Industry", "desc": "Ice-Breakers built", "tiers": [1, 4, 10], "pearls": [1, 3, 5]},
	{"id": "ending", "name": "The Eye Remembers", "desc": "Anton's letter read", "tiers": [1], "pearls": [5]},
]

static func entry(id: String) -> Dictionary:
	for e in LIST:
		if e.id == id:
			return e
	return {}

## Tiers passed for a value (0..tiers.size()).
static func tier_of(e: Dictionary, value: float) -> int:
	var n := 0
	for t in e.tiers:
		if value >= float(t):
			n += 1
	return n

## What can be paid out now: [{id, tier (1-based), pearls}] for every tier passed and not yet claimed. `claimed`: id -> tiers paid.
static func claimable(value_of: Callable, claimed: Dictionary) -> Array:
	var out := []
	for e in LIST:
		var have := tier_of(e, float(value_of.call(e.id)))
		for t in range(int(claimed.get(e.id, 0)), have):
			out.append({"id": e.id, "tier": t + 1, "pearls": int(e.pearls[t]), "name": e.name})
	return out

## Rows for the panel: {name, desc, value, next (the next threshold or -1), tier, tiers}.
static func rows(value_of: Callable) -> Array:
	var out := []
	for e in LIST:
		var v := float(value_of.call(e.id))
		var tr := tier_of(e, v)
		out.append({"name": e.name, "desc": e.desc, "value": v, "next": float(e.tiers[tr]) if tr < e.tiers.size() else -1.0, "tier": tr, "tiers": e.tiers.size(),
			"prev": float(e.tiers[tr - 1]) if tr > 0 else 0.0})
	return out

## Every tier marked as paid (tests that count pearls exactly use this so the ledger stays out of their way).
static func all_claimed() -> Dictionary:
	var d := {}
	for e in LIST:
		d[e.id] = e.tiers.size()
	return d

static func total_pearls() -> int:
	var n := 0
	for e in LIST:
		for p in e.pearls:
			n += int(p)
	return n
