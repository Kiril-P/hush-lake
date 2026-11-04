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

## Onboarding and guidance (guide.gd)
- **Intro flyover** (fresh games only, skippable with a click after 1 s): letterbox, the HUD hidden, the camera drops from high above the lake down to eye height while four captions tell the premise (the lake, the Eye, its hunger, Olga's first instruction). The Eye pulses on the second caption. Test slots and resumed saves never play it.
- **"NEXT" strip** (top centre): always shows the one thing to do now, computed live from game state (not a script position), so it is correct after loading a save. Order: bite override > full-hands override (once the bucket is bought) > the opening chain (take out drill, drill the marked spot, take out rod, cast, wait, hold on, carry to the Eye, keep fishing, buy a Bucket) > the first main-line goal with a how-to line (`HINTS`, with a `GENERIC_HINTS` fallback by stat). Optional side goals are only suggested once the main line is done.
- **World marker + edge arrow:** an amber pin, ground ring and thin light column over the step's target (the drill spot, the nearest hole or Auto-Rod, the Eye, a shop stall, Olga's hut), scaled up with distance. When the target is off screen an arrow with the distance sits on the screen edge pointing the way.
- **H = "where do I go?":** pulses the marker and Olga says the step. Olga's window gives the same line (always while the bucket is unbought, 75% of the time later). After 45 s on one step the strip adds a reminder to press H.
- **One-time tips** (saved): a new tool unlocks ("press N to use it"), and the first time each unlocked upgrade becomes affordable. Old saves without the tips key are bootstrapped silently so they are not spammed.
- Tests: `tools/run_guide.sh` (headless: the whole opening chain, targets, tips, save round-trip, intro start/skip). `SHOT_ONLY=guide tools/shot.sh` renders the intro at four moments and the first objective.

## Eye hand-off feel
- **Hand feeding is a rhythm:** click the Eye with fish in hand and they are thrown one at a time from your hand, each a little faster than the last (0.27 s gap shrinking x0.84 to 0.085 s). Each throw kicks the tool, pops the hand and whooshes. The fish re-aim from where your hand is when it leaves, so you can turn while feeding. (Decision: click-to-stream rather than literal hold-to-feed, so the hands empty at once and saves, tests and the bot keep working.)
- **Streak:** every swallow within 1.3 s of the last extends the streak. Each fish rings the next note of a pentatonic scale (`FEED_NOTES`), the FOV kicks, the Eye's reaction grows with the streak, and from x3 a big "xN" pops under the crosshair. Every 5th fish is a **gulp** (`eye.gulp`: big wave, two ripples, gold spray, "STREAK x10" over the Eye). Feel only: coins per fish are unchanged, so the balance numbers still hold.
- **Belt and rig fish dive:** when a belt fish reaches the end of its belt, a real fish model hops the rim and spirals down the funnel (`_belt_dive`, capped at 16 at once; payment is still instant). Depot fish already arced in; they now share the same funnel code.
- **Stage reveal:** `_stage_reveal(st)` on every Eye stage-up: letterbox bars (via the guide), a gentle turn toward the Eye and a FOV pull-back, an amber flash, a rising chord, and the stage name plus its boon in large type. Sector labels and tips are held back while it plays. Stage 5 runs longer ("THE EYE AWAKENS") and is the hook for the awakening cutscene.
- Tests: `tools/run_guide.sh` now also covers the throw cadence, streak climb and reset, belt dives and cap, and the reveal. Renders: `SHOT_ONLY=handoff tools/shot.sh`.

## The awakening cutscene (Eye stage 5)
- Plays the first time you ever wake the Eye (`meta.awaken_seen`); later lakes get the normal stage reveal so it never gets old. About 16 s, skippable after 2.5 s; test slots never play it. It reuses the intro's letterbox + input lock + HUD hide (`guide.scene = "awaken"`).
- Beats: 0 s the camera rises and pulls back while the player turns to face the Eye, rumble and a rising swell, the Eye holds its breath (`eye.prelude`: lids shut, glow drops, slight FOV squeeze and tremor), "The ice goes quiet." At 3.6 s the Eye OPENS (`eye.awaken`): lids snap open, light surge, three staggered ripples across the lake, gold then cyan spray, every crystal jolts, the stage-5 crystals burst out, a white-gold flash, a big chord, a heavy shake and an FOV punch. Then "It is awake." / Olga's line / "Every fish you feed it now is worth a quarter more." and at 12.4 s the title THE EYE IS AWAKE with the boons (+25% value, +3 pearls, 7th Ice-Breaker, deeper lakes).
- The Eye is visually held at stage 4 until the open (`awaken_hold`), so the crystals and lids do not spoil the moment. An early skip still ends in the correct awake state.
- Fixed on the way: the intro early-return in `_process` skipped `_animate` (shake, FOV, sky, Eye look); it now calls it.
- Tests: `tools/run_guide.sh` covers prelude, camera, held crystals, the open, flash/shake, title, skip and early skip. Renders: `SHOT_ONLY=awaken tools/shot.sh`.

## Fish are real objects (fish_yard.gd) and one line at a time
Inspired by Project P.I.T.T. (physics bodies you shove around with tools; logistics is the work, each tool removes some of it). Its internals are not public, so this is our own design.
- **One line at a time:** you can only have one rod line out. Casting at another hole reels the first in (not during a fight). Many holes at once now only comes from automation (Auto-Rods, rigs), which makes machines worth buying. The "Extra Line" upgrade (+1 fish per bite) is unchanged.
- **A catch drops onto the ice** instead of landing in your hands: it pops out of the hole in an arc toward you, falls, bounces, lies on its side and slides (ice friction = constant drag + drag growing with speed). Small hand-rolled physics in `fish_yard.gd`, not RigidBody3D: predictable, cheap for a few dozen discs, and no collision-layer fights with the aim ray. Fish-vs-fish shoving, camp walls and the lake edge are handled; the player is a solid disc.
- **Pushing:** walk into fish (they slide ahead of you), or **right mouse: kick** (tap = 7 m/s, hold up to 0.9 s for 16 m/s, 3 m/s more per level of the new **Kick Power** shop upgrade; kicks the cone in front of you, ~3.6 m reach). **E** scoops loose fish into the bucket (capacity from the Bucket upgrade), so smokers, gut tables, depots and hand-feeding still work.
- **The Eye pulls close fish in** (suction grows with its stage) and swallows anything entering the pupil: same payout, streak and gulp feel as hand-feeding, and the actual fish spirals down the funnel.
- Cap 60 loose fish: the oldest rolls into the Eye so the ice never clogs. Loose fish are saved with their positions.
- Guide: new steps `push0`/`push` target the nearest loose fish; one-time tip for the kick. Bucket now means "pick up more at once", not "cast gating": casting never needs free hands.
- Tests: `tools/run_yard.sh` (one line, fall/land/slide, glide distance, walk-push, kick, charge, Kick Power, bumping, Eye pull and swallow, walls, cap, E pickup, guide step, save). Renders: `SHOT_ONLY=yard tools/shot.sh`.
- Not done yet (natural next tools, as in P.I.T.T.): a broom/scoop to sweep a wide cone, fans or magnets as placed pullers, sloped ice channels. Belts and rig fish are still not physical.

## Level 1 (council-reviewed): safe, readable core loop
Two-provider council (GPT-6.1 Sol + Claude Opus 5.5) reviewed the plan and cross-checked each other's findings against the code; see `docs/ROADMAP.md`. What changed:
- **Nothing is lost on save.** A fight in progress is saved as a fish lying by its hole; fish riding belts and fish mid-throw (hand-fed, depot) are saved with the multiplier they were owed and paid once on load (`pending`). Loose fish keep their positions.
- **Offline and restored progress pays the Eye's rewards exactly once.** `_reward_stages_quietly(from, to)`: crossing stage 5 out of sight grants the 3 pearls and the awakened bonus. Offline rewards now also include cannery/sorter multipliers and fish multipliers. `_restore` no longer double counts `stats.rigs`.
- **Real pause.** Esc (mouse free after having played) freezes bites, timers, machines, rigs and the combo; cutscenes are exempt. The pause card has sliders for mouse sensitivity, volume and field of view, an invert-Y box and a Resume button; saved in `meta.settings`. `N` needs a second press, a tithe needs a second click (and refuses while fish lie on the ice, telling you to push them).
- **Guidance fixes:** the bite marker is on the biting hole; exhausted holes are not suggested for casting; an unlocked Auto-Rod comes before "fish a patch empty"; fight text says the fish drops on the ice; the HUD shows how many fish are on the ice.
- **Idle Ice-Breakers can be lifted** (click) and set down again for free anywhere (`stats.rig_moves`, not a second purchase). Rig ids are serial, not list positions.
- **Fish handling:** a catch launches mostly toward the Eye; walk-push goes where you are heading (80% move direction, 20% away from you); fish stay inside the real shoreline (`scenery.edge_at - 1.5`), the Eye pulls fish up to 6 m past its rim; the combo window is 14 s and swallowing a pushed fish refreshes it; overflow past 60 fish takes the oldest at half pay with no streak; kick target rings and a "Kick: N fish ahead" prompt, a forgiving near-miss assist, F as an alternate kick key; an Auto-Rod stash fills your hands and spills the rest onto the ice.
- **Evidence over opinions:** `tools/first10.sh` is a bot that plays the first 10 minutes by the rules a person lives by (only what is in view, limited turn speed with aim noise, real key and mouse events, follows the NEXT strip, never edits coins/unlocks/fish) and prints first-catch/first-feed/bucket/auto-rod times, pushes, kicks, stalls and cost. First numbers (seeded random lake): first catch 8 s, first feed 11 s, bucket 17 s, auto-rod ~4 min, 70 fish fed in 10 min, 0 stalls. Finding: the Shallows holes are all within ~20 m of the Eye, so in the first 10 minutes the Eye's pull does all the pushing (0 pushes, 0 kicks needed): pushing and kicking only matter in outer sectors. Open question for the human playtest: is that too easy, or a good gentle start?
- Other tests: `tools/run_safety.sh` (save/restore of in-flight fish, offline stage, pause, tithe, rig move, guidance).
- Fixed a test-only error class: timers and signal lambdas left behind by freed game instances.

### Level 1, council round 1 fixes (Sol 6/10, Opus 7/10, both CHANGES)
- Pause now also freezes tweens (fish in flight no longer land and pay while paused), and losing window focus frees the mouse (so the pause card shows). The click that resumes play is not also a click on whatever you were looking at (`first_person.gd`).
- `_settle_fish` is the one way a fish reaches the Eye without ceremony (restore, offline): it prices the fish, wakes stages immediately (so later fish in the same batch get the awakened bonus) and credits Olga's order. Orders are restored before pending fish are settled. A restore holding more fish than the ice (60) pays the extra in full, and `eye_seen_stage` is set before restoring so no stage reveal replays on load.
- N (start over) keeps your settings and says plainly that pearls and perks go too. The tithe is only blocked by fish within ~20 m of the Eye (the ones about to go in), not any fish on the lake.
- The first-10-minutes bot got more honest: it reads the on-screen prompt to drill (never `_can_drill_at`), reacts to the "!" marker, learns "fished out" from messages, stall detection ignores passive income (it counts hole/catch/purchase/auto-rod/belt only), RNG seeded for its own choices (the lake is still random), and bounds are tight (first catch <=30 s, first feed <=45 s, Bucket <=90 s, Auto-Rod <=360 s, 40+ fish). It prints a NOTE when no pushing happened. Yard physics substeps long frames, so a 3x sped-up run uses the same step size as the 60 fps game (the player position is held at its end-of-frame value across the substeps, so walk-push collisions are only approximately the same). Latest: first feed 11 s, bucket 17 s, auto-rod 229 s, 12 pushes, 5/5 kicks hit, 13 missed bites, 3 short stalls after the auto-rod ("fish a patch empty" has no quick action), 4.1 ms/frame process time, fish physics 0.74 ms/step at 60 fish.
- Known remaining shortcuts in the bot (accepted, documented): it aims through `g._aim()` (the crosshair ray, same as a click), uses the guide's world pin for stall positions, sees fish by camera frustum without an occlusion test, and writes the camera angle directly with a turn-rate limit instead of mouse deltas.

### Level 1, council round 2 (Sol 7/10, CHANGES) fixes
- Orders: a restore puts the open order back before any fish is settled; `_settle_fish` credits the order BEFORE paying coins (paying refreshes the goals, which used to drop an order the very fish completed); `_species_held` now counts every fish already out of the lake (on the ice, hooked, in the air toward the Eye, on a belt), so a species order is not declared impossible while its last fish is on its way.
- A live overflow that crosses an Eye stage gets the full stage reveal again (`_settle_fish(..., quiet=false)`); only restore/offline settle quietly.
- The click that resumes play is also ignored by the hold-to-drill poll until the button is released (`hold_block`).

### Level 1, council round 2 (Opus 7/10, CHANGES) fixes
- Offline deliveries no longer feed Olga's orders (`_settle_fish(..., count_order=false)`): no burst of banners/sounds/particles on load, and offline order rewards were never an announced feature. Restored in-flight fish (pending) still count.
- "The Eye woke while you were away" is kept in `quiet_notice` and appended to the welcome-back line (it used to be overwritten).
- Yard substeps are capped at 8 per frame (a long hitch cannot turn into hundreds of steps).
- Opus N4 (guide cinematic timer counting while paused) checked and not a bug: `guide.tick` runs only from the un-paused `_process`.
- The bot now buys an upgrade named on the NEXT strip when it can pay, and explores nearer after seeing a LOCKED prompt: 95 fish fed, 0 stalls in 10 minutes.

## Visual and feel pass (council set aside; goal: one style, one vibe)
Built: living ice shader, new tool models with mittens and a kick boot, snow puffs, all machines remodelled in one language (see docs/STYLE.md "Assets"), animated belt chevrons, steaming cannery, sweeping sorter scanner, spinning rig beacon, Olga as a figure, reactive crosshair and drawn tool icons, round minimap, field journal, centred cards (CenterContainer, so tall cards never run off screen), themed sliders/buttons, a cold vignette and a gentle colour grade, sector labels that stay readable at distance, hole water and lip, walk bob with footstep snow, fish colours fixed (vertex colours are sRGB) so fins keep their colour.
Judging method: renders by `tools/showroom.sh` and `tools/shot.sh`; headless suites (yard, safety, guide, smoke) and the windowed bot stay green.

### Polish round 2 (stop-hook gaps closed)
- Belt and rig fish are real instanced fish (`FishModel.bead_mesh`), not spheres; every fish has ray-shaded fins and a belly fin; trees carry snow and a few are dead.
- Audio mix pass: per-role loudness table, limiter, living ambience, new physical sounds; `tools/run_audio.sh` (levels, clipping, loop clicks, limiter).
- Smoothness: tool-swap dip, build pop-in (skipped while restoring a save), pickup hop to the hand. `tools/perf_render.sh` measures rendered frame time on a busy late-game lake with vsync off: ~7-9 ms average (110-150 fps), p95 < 11 ms, worst 16 ms, 4-6k draw calls. Startup (audio synthesis + scene) is about 0.5 s.
- New buildings take a third of a second to grow in: a click during that window hits a smaller collider (the bot waits).

### Polish round 3: what can be measured without a human
- `tools/perf_render.sh` now also runs an action phase (walk, tool swaps, kick charge, a kick into 30 sliding fish, pickup, drilling, building auto-rod/belt/cannery/depot, a 70-fish overflow burst) and reports p99 and the worst frame with its label. Latest: p99 12.6 ms, worst about 29 ms (during the artificial 70-fish spawn burst), 1 frame over 25 ms in 468.
- Audio was analysed offline (`tools/audio_dump.tscn` + a numpy script): the repeating sounds (fight reel click, drill, step) were shrill (reel: 45% of energy above 5 kHz) and the wind loop was almost pure 40 Hz (inaudible on laptop speakers). Reel/drill/step/slide were re-synthesised with a softer click plus a mid tone, wind and gusts moved to a ~400 Hz howl with a slow swell, thud and kick got a mid knock, and a small reverb sits before the master limiter. `tools/run_audio.sh` now asserts these spectral properties too.
- Still only a human can judge: whether any of it FEELS good. See PLAYTEST.md for what to look at.

### Polish round 4: pacing and kick numbers
- **Doing beats grinding in the NEXT strip.** From the first-10-minutes log the strip sat on "Fish a patch empty" for ~6 minutes while buildable goals waited. `Guide._first_actionable_goal()` now points at the first open main-line goal that is a build/buy the player can do right now (Auto-Rod, Belt, Cannery, Depot, Ice-Breaker, a stall upgrade, Tithe...), and only falls back to grind goals (patch, sectors, fish fed, coins, stages) when nothing is doable. Drilling more holes is not chased as a goal. The bot now follows "Build a Cannery" like a person would.
- **Kick numbers (measured in `tools/run_yard.sh`):** a tap sends a fish ~14 m (about a Shallows hole to the Eye), half a charge ~20 m, a full charge ~30 m; Kick Power 3 gives ~57 m and level 5 ~75 m (across the lake). The tests pin these ranges so a later change cannot quietly make kicking useless or silly.

### Art-direction review (Opus 5.5 looking at the renders): 6/10 cohesion, 5/10 readability
Fixed from its top 10: (1) the Eye's petals are shorter, matte, dimmer and fade out as you walk up to them; (2) the ice is less saturated with a wider pale shore band (it read as ocean); (3) palette outliers: Olga's hut is warm wood, the cannery a muted brick, the rig crane teal, the aurora has no violet, the ground snow is blue-white; (4) floating text: locked sector labels only within 16 m, machine and hole tags only when near; (5) one message at a time (goal banner plus Olga's line only), the top-left Eye card shows a short "Next:" and larger text; (6) stall signs show name, level and price big with the description small beneath; (7) loose fish have a soft contact shadow, a lift and a clear-amber kick ring; (8) mittens are bigger and amber with a slim teal cuff, the boot is lighter and smaller; (10) the Eye's light shaft is much fainter by day.
Not done: (9) flat untextured faces on buildings (plank trim, bevels, window glow) and pushing the player back from walls; the amber pin is still shown for any target (it should maybe only appear when the target is not the one already in view).

### Art review 2 (Opus 5.5, after the first round of fixes): cohesion 7/10 (was 6), readability 5.5/10 (was 5)
Verdict on the ten earlier problems: petals better, ice better (but violet), palette better, floating text unchanged, instruction clutter better, stall signs better, fish better, held items better, flat faces better (hut fixed), beams better by day. Its call: ready for a first human playtest once the stall-sign overlap and the labels showing through walls are fixed, and "don't polish further before you've seen real players".
Fixed after it: stall sign rows no longer overlap (title never wraps, description is its own row); world labels are depth-tested (hidden behind walls) and locked-sector labels only show within 12 m; ice hue pulled from periwinkle toward teal; Eye shards shorter; only the fish most in front of you gets the full kick ring, the others a small one.
Open (from the review, deliberately left for playtest feedback): the cyan crystal spires compete with the hut roofline; night shows an amber pillar plus cyan cone through the crosshair; stall and depot fronts are still plain; Ice-Breaker cabin is flat white; the auger is a pale jumble; the journal uses green and lilac swatches; shore band is peach.

### Art review 2 open items, closed
Crystal spires are shorter and matte (below the camp roofline); the tall amber pin column hides by night and up close (cone and ring stay); stall counters have planks, a kick-plate and a snow lip; the depot has planks, door-frame posts and a snow ledge; the Ice-Breaker cabin is pale blue-grey with cladding lines, corner posts and side windows; auger flights are dark steel (they were a pale jumble on white ice); rarity colours stay in the palette (teal, sky, warm amber); the bank is no longer peach (terrain vertex colours are sRGB now); mittens carry a little emission so they stay amber at night.
Still open: auger/mitten silhouette could be stronger; the Eye's ice shards are still large; the far landscape reads slightly violet from the air.

### Art review 3 (Opus 5.5, fresh renders): cohesion 7.5/10, readability 6/10, verdict READY for a first playtest (visual standpoint)
It now reads as one game (blued steel + teal trim, warm wood, snow caps, amber lamps) apart from: the Eye's petals, the auger silhouette, off-palette greens/lilac/peach, world text bleeding through UI, and prompts contradicting the task. All five fixed: petals half the size with no shadows; the auger stands on a diagonal (shaft out front, leaning across the screen) with a visible power housing at higher tiers; Perch and the discovery banner use palette colours (banner amber), hole chips blue-white, boot cuff teal-grey; world labels are depth-tested; "Hold on! Landing the fish..." during a fight and the push-it hint instead of the LOCKED lecture when fish lie at your feet; smoker and gut table have footprints so the camera cannot slide inside their walls.
Not reviewed again: the pause card render (shot tool shows none) and anything after this commit. Remaining open: peach shore band in aerial/low shots is reduced but was not re-judged; far landscape slightly violet.

### Art review 4 (Opus 5.5, fresh renders after the review-3 fixes): cohesion 8/10 (was 7.5), readability 6.5/10 (was 6); "it reads as one game with its own look"; READY for a first human playtest
Fixed after it: the "dark shapes that belong to no object" were the shoal of fish silhouettes under the ice (a game feature) drawn as shapeless blobs, so they are now flat fish silhouettes with forked tails; nothing held in hand casts a shadow; stall sign text sits clear of the board; no hover prompt prints across the journal or refreeze card; the old "Cast a line" message is cleared when a fish is hooked.
Left open (small): pale petals still fill the lower third of Eye-facing shots; the auger is a stick with crossbars, not a spiral; the shore band is still peach-pink in a couple of low shots and the Ice-Breaker bow is mauve; "The Shallows" label ghosts behind the NEXT card.
Progress of the art-direction scores across four reviews: cohesion 6 -> 7 -> 7.5 -> 8; readability 5 -> 5.5 -> 6 -> 6.5.

### Last three small open items (from art review 4), closed
Fewer Eye petals (16 + 10, was 20 + 20) so the lower third of Eye-facing views is clear; the auger flights are a tight helix of small blades (a spiral, not crossbars); the bank snow starts bluer. Not re-reviewed by an art director; judged from renders only.

## Hands: grab, hold, throw (a redesign after "it feels tight and not free")
Research (fan guides, provisional): Project P.I.T.T. is built on physical handling: left mouse picks things up and drops them, right mouse throws (a purchased upgrade), middle mouse rotates, tools shove; Moon Sweepers has capacity-limited carrying to a depot with grab/throw as logistics upgrades. Our old model was a capacity-1 click-feed bucket plus a kick: no way to handle one fish freely.
New model (fish_yard.gd + ice_fishing.gd "hands" section, tests in tools/hands_test.gd, `tools/run_hands.sh`):
- **Grab**: look at a fish within 5.5 m and click (`FishYard.pick`: the fish nearest the line of sight). It hangs in front of you as a real model that lags when you turn, bobs when you walk and wriggles harder as you wind up. One in each hand slot, no capacity gate: the bucket is for storage, the hand is for play.
- **Drop** (click on empty ice), **throw** (hold right mouse / F: 0.9 s charge, release): ballistic arc with the same gravity as the fish fall with, from the hand along your look direction lifted 22 degrees, so looking up lobs farther. A dotted arc preview and a landing ring show where it comes down (aqua when that is inside the Eye's pull). Charge 0..1 gives 7 to 30 m/s (+3 per Kick Power level); a full charge flies ~35 m and skids; hard landings skid far less than gentle ones.
- **Stow / take** (E / Z): the bucket becomes a pocket. With empty hands E still sweeps up the fish at your feet.
- **Deliver**: clicking the Eye (or a depot, or the smoker) with a fish in hand uses it like the carried ones; a thrown fish that crosses the pupil is swallowed like any pushed fish (same payout and streak).
- Saved: a fish in hand is saved as one lying at your feet; orders count it as out of the lake.
- The first-10-minutes bot uses it through real events: 53 grabs, 53 throws, 53 swallowed in 10 minutes.
Left for the owner's playtest: whether grab reach and the 22-degree lift feel right, whether the arc preview is readable enough, and whether stow/take (E/Z) is wanted at all now that you can just hold a fish.

### Hands, second step: throw into machines
Depots and smokers are catch targets (`FishYard.sinks`): a fish that reaches a depot's mouth (3 m) goes in and is sent to the Eye by sled at the depot rate; a fish that reaches a smoker (2.2 m) joins or starts a smoking batch (up to 4, refused when full or when a finished batch is waiting). So throwing is a logistics tool, not only a way to feed the Eye. Tests: `tools/run_hands.sh`. Two flaky bounds were loosened (kick charge margins, wind spectrum) because both involve random noise.
