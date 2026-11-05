# Living Lake: world, weather and day cycle (plan)

Goal: the lake should feel like a place that has moods, not a still painting with a clock. Today: a 10-minute day with sky keys, sun/moon, aurora at night, one constant snowfall, a wind loop. Missing: weather, stars and clouds, life, a camp that grows, and any reason to notice the sky.

## Levels (each ends with tests + screenshots before the next)
1. **Weather** (`weather.gd`, data only): clear, flurries, snowfall, blizzard, fog. Smooth blends, seeded, saved. Drives snow emitters (3 layers), fog density, sky gloom, wind (audio + snow lean), clouds. Always clear for the first 3 minutes and during cutscenes. Setting "Weather" (Video) turns it off (always clear).
2. **Day cycle**: stars (twinkle, night only), drifting clouds (density follows gloom), golden-hour windows, a clock + temperature + weather chip in the HUD, F5 debug cycles weather.
3. **Life**: gulls by day (circling the shore), ice cracks (a bright line + creak, more at night), owl at night, crow by day (procedural sounds), sleeping/awake camp dog.
4. **Camp grows with the Eye**: stage 1 campfire (flicker light, embers, smoke), stage 2 string lights, stage 3 woodpile + sled, stage 4 lantern posts, stage 5 aurora every clear night.
5. **Gameplay hooks** (small, readable): golden hour and snowfall make bites come sooner, blizzards sooner still but you cannot see far; aurora nights raise rare-fish odds (x1.4). The HUD chip says so in words ("bites sooner", "rare fish stir").
6. **Evidence**: `tools/run_weather.sh` (state machine, blends, scene application, hooks, save/restore, three simulated days), shots (`SHOT_ONLY=weather`), perf check, docs.

## Rules
- No effect may hide the Eye, the crosshair target or the HUD. Blizzard fog density is capped so 50 m is still readable.
- Everything is seeded/randomised but saved: reload mid-storm returns the same storm.
- Palette stays teal/amber/slate: storms are cold grey-blue, never violet or brown.
