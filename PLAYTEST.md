# Playtest guide — Ice Fishing prototype

**Run**
```
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/kirilpetrovski/game-dev-prototypes/cozy-incrementals
```

**Controls**
- Mouse: look · WASD: walk · Click: use tool / interact · 1-7: pick tool, V: ride the snowmobile, Q: cycle what Build (7) builds · Tab: journal
- R: Refreeze (after 3 sectors): bank pearls, buy perks, start a new lake with a modifier · M: mute · Esc: free the mouse (click to resume) · N (while paused): erase save & start over
- H: where do I go? (Olga repeats the current step)
- Debug: F2 +1000 coins · F3 unlock everything · F4 skip time of day

**The goal:** feed the Eye. The lake is ~180 m of open ice with a huge hole at the centre. Drill anywhere, fish, and push what you catch into the Eye (it pays 25% more than Olga). Later, build an Auto-Rod on a hole and lay a belt (tool 6) so its catch rides into the Eye by itself. The Eye wakes in 5 stages as it eats. The lake still holds ~1,800 fish in 19 hidden sectors: fish a sector dry to thaw it and open the next ones (pale frost = locked). Clear them all to finish.

**Start here:** a new game opens with a short flyover (click to skip). Then follow the NEXT strip at the top of the screen: it always says the one thing to do, and an amber pin plus an edge arrow point at where. Press H any time and Olga tells you the step again (her window does too). The opening is: drill the marked spot (1) -> cast (2) -> click when it bites -> the fish drops onto the ice: push it into the Eye (walk into it, or hold right mouse and let go to kick it; E picks it up) -> buy a Bucket. Only one line can be out at a time. The GOALS card (top right) tracks the longer list. The camp (Olga's hut + first stalls) is on the ice beside the Eye; later stalls are further out.

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
20. Did anything stop you from knowing what to do next (goals, prompts, the Q key)?

