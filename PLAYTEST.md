# Playtest guide — Ice Fishing prototype

**Run**
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kirilpetrovski/game-dev-prototypes/cozy-incrementals
```

**Controls**
- Mouse: look · WASD: walk · Click: use what is in your hand / interact · 1 2 3 or the wheel: pick one of your three slots · Q: put down what you hold · E: pick up / sweep fish into buckets · Z: take a fish out of the bucket · B: switch what the Builder's Kit builds · V: ride the snowmobile · Tab: journal
- R: Refreeze (after 3 sectors): bank pearls, buy perks, start a new lake with a modifier · M: mute · Esc: free the mouse (click to resume) · N (while paused): erase save & start over
- H: where do I go? (Olga repeats the current step)
- Debug: F2 +1000 coins · F3 unlock everything · F4 skip time of day

**The goal:** feed the Eye. The lake is ~180 m of open ice with a huge hole at the centre. Drill anywhere, fish, and push what you catch into the Eye (it pays 25% more than Olga). Later, take the Builder's Kit from the tool rack by Olga's hut (B switches what it builds), build an Auto-Rod on a hole and lay a belt so its catch rides into the Eye by itself. The Eye wakes in 5 stages as it eats. The lake still holds ~1,800 fish in 19 hidden sectors: fish a sector dry to thaw it and open the next ones (pale frost = locked). Clear them all to finish.

**Start here:** a new game opens with a short flyover (click to skip). Then follow the NEXT strip at the top of the screen: it always says the one thing to do, and an amber pin plus an edge arrow point at where. Press H any time and Olga tells you the step again (her window does too). The opening is: drill the marked spot (hold the Drill) -> cast (the Rod) -> click when it bites -> the fish drops onto the ice: push it into the Eye (walk into it, or hold right mouse and let go to kick it; E picks it up) -> buy a Bucket. Only one line can be out at a time. Esc pauses (sliders for mouse, volume, FOV); tithing the Eye and starting over (N) need a second click/press; F is an alternate kick key. The GOALS card (top right) tracks the longer list. The camp (Olga's hut + first stalls) is on the ice beside the Eye; later stalls are further out.

**What I want to know after ~30 minutes**
0. Onboarding: did the intro grab you or drag? Did you ever not know what to do next? Did the NEXT strip and pin help or nag?
1. When did you first feel bored? When did you first feel hooked?
2. Which moment felt best / worst?
3. Was anything confusing or hard to find?
4. Did walking back and forth feel fun or like a chore? When did it stop being needed?
5. Anything that looked, sounded, or felt wrong?
6. Did "empty the lake" feel like a goal worth chasing? Did clearing a sector feel good?
7. Did the lake feel too big, too small, or just right? Did the last fish in a tile feel tense or tedious?

8. After refreezing: did lake 2 feel different (modifier) and faster (perks), or the same game again? Did you want to do a third?
10. World: did the shore/landmarks make you want to explore? Did you find the lighthouse, the plaques, the shacks? Was the walk to the hatch or stalls now too long, and when did boots fix it?
9. Did you ever have coins with nothing worth buying? When?

**Data we get for free:** the game appends milestones (goals, purchases, discoveries, orders) with timestamps to
`~/Library/Application Support/Godot/app_userdata/Cozy Incrementals/playtest_log.txt`. Send me that file too.
The save is `ice_fishing.save.json` in the same folder.

**Dev check:** `tools/run_smoke.sh` runs a headless self-test (rules, save/load, 4000 random actions). `tools/play_bot.sh` plays the real input path in a window. `tools/shot.sh` renders screenshots.

**Slice-1 questions**
11. Did drilling anywhere feel better than clicking hexes? Did you ever want a grid back?
12. Did the lake feel big and open now, or just empty? Where did you feel lost?
13. The first belt: how long until you wanted it, and did watching fish ride into the Eye feel good?
14. Did the Eye feel alive (it turns toward you, it brightens, it stirs at each stage)? What stage did you reach?
15. Did you want a faster way to get around the lake before you could afford boots?

**Slice-2 questions**
16. When did you buy the snowmobile? Did riding feel like a reward or a chore? Did the speed make the lake feel smaller (good or bad)?
17. Did you build a depot? Did it replace walking to the Eye, or did you still walk?
18. Cannery / sorter: did you notice the payout change? Did you want to see the number on the fish?
19. The ice-breaker: when did you build it, and did it feel like a payoff or like it played the game for you?
20. Did anything stop you from knowing what to do next (goals, prompts, the B key)?



## What to judge by hand (nothing else can)
Play 10-15 minutes with a real mouse and speakers or headphones, then write down: (1) does walking into fish and kicking them feel good, or fiddly? (2) is the kick charge (0.9 s) and range right? (3) are any sounds annoying when repeated (fight reel, drill, footsteps)? is the wind/ice ambience pleasant or distracting? (4) does anything feel janky: camera, tool swap, build pop-in, the snow puffs? (5) is it clear what to do at every moment? (6) where did you get bored? Tools that already cover the measurable side: tools/run_yard.sh, run_safety.sh, run_guide.sh, run_audio.sh, run_smoke.sh, first10.sh, play_bot.sh, perf_render.sh.

## Hands (new): what to try
Click a fish to grab it; walk with it (does it sway nicely?); click empty ice to drop it; hold right mouse and watch the dotted arc, look up a little for a lob, let go to throw it at the Eye. Try E (stow) and Z (take out). Is grabbing too picky (it needs the crosshair near the fish) or too loose? Does the throw feel powerful or floaty? Is the arc preview clear?

## Three slots, buckets, the tool rack: what to try
You hold up to THREE things: tools, fish, buckets (slots 1-3, shown at the bottom middle; wheel or number keys). Start: Drill, Rod, one empty slot. Buy a Bucket (stall) and it lands in the free slot. Questions: (1) is "grab a fish into a free slot, throw it, and you are back on the rod" fluid, or fiddly? (2) with Drill + Rod + Bucket you are full: did Q (put down) and the rack feel fair, or did you get stuck juggling? (3) buckets: click fish into one, E sweeps, throw fish into a placed bucket, click a placed bucket to take a fish out, kick it to tip it over: which of these did you actually use? (4) did you buy a second bucket and set it somewhere useful? (5) the Builder's Kit hangs on the rack by Olga's hut (click it; your hands swap): was it clear where to find it, and was walking back for it a chore? (6) did anything get lost or stuck (a tool you could not find, a bucket in the way)?
