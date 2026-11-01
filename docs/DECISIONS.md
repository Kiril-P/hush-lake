# Decisions
- Order: Ice Fishing, then Kelp Diver (shared core in shared/).
- Camera: stationary FIRST PERSON (like Moon Sweepers / A Game About Chopping Trees), not isometric. Concept art in docs/concept is isometric: use for mood/palette only.
- Movement: mouse look + WASD walking inside the lake (added after playtest feedback: pure stationary felt like 'can't move').
- Point of the game: EMPTY THE LAKE. Finite fish per tile, 19 sectors x 7 hex tiles; clear a sector (every fish out) to open its neighbours; clear all 19 to finish (the eye under the ice opens).
- You must walk: interaction range limits (tiles 8m, hatch 6m, signs 7m) so carry capacity and boots matter.
- Stations (smoker, gut table) are built on fished-out tiles only; auto-rods work a tile until it is empty, then can be picked up (60% refund).
- Fish get warier as a tile empties (longer bites), so the last fish take longest.
- Repeatability (2026-11-01): R = Refreeze. Bank pearls (1/sector, +5 empty lake), buy permanent perks, start a new lake with a random modifier. Permanent progress lives in `GameState.meta`, which a normal reset keeps and `N` (erase everything) wipes. See docs/AUDIT.md.
- Orders only ask for fish still in the lake.
- World pass (2026-11-01): the lake is a 25 m ice disc with a real shore (bank, flat land to 55 m, foothills, forests on land). Walk limit 42 m. Hut at 30 m. Each upgrade has a themed stall at `Scenery.SHOP_SPOTS`: the first four are "Market Row" by the hut, the rest are spread around the shore so unlocking them sends you exploring. Stalls, hut, shacks and plaques block walking (`scenery.obstacles`).
- Landmarks: HUSH LAKE welcome sign (dead ahead at start), lighthouse with night beam (bearing 150), Kestrel Landing village lights (bearing -128), 3 abandoned shacks on the ice, 5 lore plaques. 19 shore lanterns, one per sector, light up as sectors clear.
- `tools/shot.sh` renders screenshots (renders/shot_*.png) so world changes can be reviewed without playing.
- SLICE 1 "Feed the Eye" (2026-11-01): the hex board is gone. The lake is ~180 m of open ice with the Eye (a real open hole, 10 m iris, 4.8 m pupil) at the centre. You stand at eye height 1.7 m and drill ANYWHERE (`_can_drill_at`); every hole is a dict in `holes[]` (the old per-tile dict, now with a world `pos`). Hex "cells" (TILE 7 m) still exist but are invisible: they only hold fish stock and the shoal shadows under the ice. Locked sectors show as a soft frost patch, cleared ones thaw into dark water.
- The Eye is the delivery point and pays 1.25x Olga (hand feed or belt). Belts (tool 6) run from an Auto-Rod straight to the Eye; fish ride them as ONE MultiMesh (cap 600), so thousands are cheap. 5 Eye stages at 10/60/200/600/1500 fed: shake, banner, Olga line, wider iris, brighter light. The iris drifts toward the player.
- Olga's hut and the first four stalls form a camp on the ice beside the Eye; the other stalls are outposts further out (`Scenery.SHOP_SPOTS`). "Conveyor" upgrade is now "Belt Motor": faster belts, +25% value.
- Test tools: `tools/run_smoke.sh` (logic, 106 checks incl. 4000-action fuzz), `tools/play_bot.sh` (opens a window; drives the real input path: aim, hold-to-drill, cast, catch, feed Eye, auto-rod, belt), `tools/shot.sh` (screenshots, SHOT_ONLY=<name> for one).
- NOT in slice 1 (next): snowmobile+sled, sorters/cannery on belts, depots, ice-breaker rig, co-op. Old Rod/Auto-Rod/Smoker/Gut Table/refreeze/pearls/orders all still work.
- SLICE 2 (2026-11-01), all unlocked by the "Feed the Eye 25 fish" goal: 
  * Snowmobile (stall upgrade, 3 levels, key V): ride speed x2.4/3.0/3.6, FOV push while moving, a cockpit in view; level 3 tows a sled (+10 carry while riding).
  * Build tool (7, Q cycles the item): Cannery (belt fish x1.8), Sorter (belt fish worth 5+ x1.6, stacks with cannery), Depot (drop fish, a sled runs them to the Eye at 1.05x the Eye price: kills the walk-back chore), Ice-Breaker (600 coins, doubles each, max 3: a rig on open ice that mines its cell + 6 neighbours and feeds the Eye over its own line, no hole or belt needed). 
  * Belts are now generic lines `{a,b,len,dir}` (+ optional `cannery`/`sorter` flags); rigs own a line each. `belt_fish` rides all of them in the one MultiMesh.
  * Save format adds `depots`, `rigs`, per-hole `cn`/`so`. Offline progress does NOT yet include rigs (only belt-fed auto-rods).
  * Open work: co-op, ice-breaker upgrades/eras beyond the first rig, depot upgrades, rig offline income, sound for the new machines (they reuse existing sfx).


## Style pass + rig offline income
- Added `shared/style.gd` and `docs/STYLE.md` (palette, theme, card/slot/bar helpers). HUD rebuilt around it: coin chip, bucket and Eye bars, goals card, tool cards, toast area above the hotbar, title card.
- Recolored sky, fog, ice, mountains, forest and the Eye to the cold-teal/one-amber rule; Eye now reads as aqua rim + amber ring + teal + black pupil.
- Ice-breaker rigs now earn while you are away (40% of live pace). Added a smoke test for it.
- Locked-sector labels only show within 22 m, which cuts the "LOCKED" clutter.
- New class_name scripts need `godot --headless --import` once before headless tests see them.

## The Eye, rebuilt (games/ice_fishing/eye.gd)
- The Eye is now its own script. Layers: iris shader (radial fibres, gold collarette, travelling "gulp" wave, frosted eyelids that close from top and bottom), open pupil, swirling funnel shader, a dark inner pupil with a catchlight that tracks the player, ice-lash petals that flex, crystals (4 per stage, 20 total) that burst out at each stage, a light shaft (strong at night), drifting motes.
- It starts drowsy (lids about half shut) and wakes as `open` grows; blinks every 6-13 s. Warmth (gold) rises with stage.
- Hooks for interaction work: `catch(color, weight)` (throttled, safe for belts), `stage_up`, `set_stage` (instant sync), `landing_point(from)`, `set_offering(on, pos)` (amber chevrons toward the player while carrying fish near the Eye), `look`.
- Hand-fed fish now arc to the pupil rim facing the thrower, pay and trigger `catch` as they cross it, then spiral down the funnel.
- Bug found on the way: the sun-glitter strip lay over the pupil hole (tan disc); it now starts beyond the Eye. Frost/thaw sector patches also fade out around the Eye.
- Shader changes only show in windowed runs (`tools/shot.sh`, `SHOT_ONLY=eye`); headless can't render. Frame times are spiky for the first couple of seconds while shaders compile; the bot now waits 3 s.

## Fishing overhaul (fish_model.gd, fish_node.gd, fishing_fx.gd)
- Every catch has its own procedural model: lofted body with vertex-coloured markings (minnow lateral stripe, perch bands and orange spiky dorsal, pike long with pale spots, golden trout gold with red stripe and shimmer, ancient fish glowing cyan runes), tails, dorsals, pectorals, eyes. Boot, coin and pearl are their own objects. FishNode animates tail wag, sway and fin flaps; `amp` sets the energy (bucket 0.3 .. thrashing 3).
- Fish have a cosmetic length in cm (per-species range) and the game keeps personal records (saved). Length scales the model, shows on the catch card, and in the journal.
- The cast: the float arcs out from the rod tip with a visible line (ribbon mesh: slack while waiting, taut and trembling on a bite) and lands with a plop, droplets and a ripple.
- Nibbles (1-2 dips with ripples and a tick) before the real bite, which plunges the float, pops a "!" and yanks the rod.
- Clicking the bite now HOOKS the fish (state `cast == 3`): a 0.7-1.5 s fight whose length and violence depend on the species (`_fight_intensity`): float circles and thrashes, splashes, reel ratchet clicks, rod bends, view shakes; rare hooks add coloured ripples and the ancient fish makes the Eye flare. The stock is drawn at hook time; the fish lands in hand when the fight ends (`_catch`).
- Landing: the fish leaps out of the hole in a spinning, flapping arc into your hands, splash and rings; rare finds (value 14+) add a light beam and sparks. A catch card (rarity, name, length, worth, NEW SPECIES / NEW RECORD) pops at the bottom of the screen.
- The spawn moved from 13.4 m to 16.5 m from the Eye so you no longer start inside its ice lashes.
- Tests: smoke test covers hook, fight, landing, length and records; the bot waits for the fight to end.

## Balance pass (docs/BALANCE.md)
- Added `tools/econ_sim.gd` + `tools/run_econ.sh`: a headless economy simulation using the real rules. It found the lake could be emptied in 10.5 minutes; after retuning (bigger lake, slower automation, steeper prices, smaller multipliers, later Eye stages) an optimal player needs about 53 minutes and a half-active one about 66.
- Auto-rod, rig and cannery prices and the lake size are now named constants (`AUTO_*`, `RIG_*`, `COUNT_SCALE`) that the sim reads, so retuning is one edit plus one run.
- Refreeze now needs 6 sectors.

## The point of the game, and the late game (Eye-driven)
- **The point from the first minute:** wake the Eye. The left HUD card shows its stage bar and, under it, what the NEXT stage gives you (`EYE_BOONS`). The goals card ends in "Wake the Eye (stage 5)".
- **Stage boons:** 1 = tithes unlock; 2, 3, 4 = one more Ice-Breaker slot each (3 -> 6); 5 = the Eye wakes: +25% fish value, +3 pearls, a 7th rig, and the next lake is bigger. `rig_cap() = 3 + max(stage - 1, 0)`.
- **Tithe (endless sink):** with empty hands, click the Eye to offer `150 x 1.8^n` coins; each level adds +7% to every fish's value for this lake. Gold flare, banner, sparks.
- **Rigs as a sink:** the 4th to 7th rig cost 12k / 30k / 72k / 172k coins (`900 x 2.4^n`).
- **Going out and scaling:** every lake you finish makes the next one 30% bigger (`DEPTH_FISH`), its fish 25% richer (`DEPTH_VALUE`) and the Eye 30% hungrier (`eye_stage_at`). The refreeze panel previews it. Pearl perks and the Eye's awakening reward carry over.
- **Goals:** 12 new late goals (Eye stages 3/4/5, tithes 1/5/12, 2 and 4 rigs, 12 auto-rods, 10k and 100k coins, 15 sectors) with 100-10000 coin rewards. Side goals (species, gutting, smoking, journal) are flagged `opt` and only show when fewer than 3 main-line goals remain, so a hard side goal can no longer hide the main line.
- Old saves: only the last goal ("Empty the lake") shifted index; goals are saved by position.
- `tools/econ_sim.gd` now models tithes, rig caps, goal rewards and later lakes (`ECON_LAKES=n`).
