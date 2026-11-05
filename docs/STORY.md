# The Eye's story

**The secret:** the Eye is not hungry, it is lonely. Kestrel Landing fed it so it would not be alone; Anton fed it for thirty-nine
winters; Olga did the fortieth badly; the fish were how people said "we are still here". The game never says this outright:
it is found in letters, objects and dreams.

## How it is told (all in `games/ice_fishing/story.gd`, pure data)
| Layer | What | Where |
|---|---|---|
| **Letters** | 14 letters from Olga, delivered to a mailbox by her hut at milestones (first feeding, 25 fed, 3 sectors, Eye stages 2-5, a first visitor fish, 5 tithes, a refreeze, a second refreeze, and the last one). The flag goes up; click the box; the page writes itself in; A/D turn pages | `letters_panel.gd`, mailbox in `camp_dressing.gd` |
| **Keepsakes** | 8 objects (thermos, mitten, brass key, ring, ice log, compass, photograph, tin whistle) hide in the junk you fish up (30% of boots, coins and pearls). Each was once a gift to the Eye. They stand on a shelf on the hut wall and persist across lakes | `Story.KEEPS`, `_found_keep`, `CampDressing.set_keeps` |
| **Dreams** | Refreezing plays the Eye's dream of the winter you finished (5 dreams, then a line with how many fish you fed it) before the lake freezes again | `DreamOverlay`, `Story.DREAMS` |
| **Ending** | All 8 keepsakes + an awake Eye bring Anton's own letter. Reading it plays "THE EYE REMEMBERS", gives 10 pearls, and Kestrel Landing's windows stay lit by day for ever. Nothing locks: the lake is still yours | `_play_ending`, `Scenery.light_village` |

## Rules of the telling
- Never a wall of text on its own: a letter is one page, typed in, with a title; skippable (E finishes the writing, E again closes).
- Everything persists in `GameState.meta["story"]` so the story survives refreezing (new lakes are the same lake, again).
- The opening already planted the hook (Olga, the Eye opening one lid); the letters pay it off.

## Tone check for the human playtest
Letters should read as warm, dry, a little eerie. If they read as sad, cut lines, not letters. The ending should feel like a door
being left open, not a credits roll.
