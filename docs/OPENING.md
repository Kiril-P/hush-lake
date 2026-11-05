# Opening sequence and title screen (plan)

Goal: the first minute sets the style for everything after it. Today: a menu card over the world, then a 13 s overhead flyover with captions. Now: a place you arrive at.

## The beats
1. **Title** (launch, real slots only): Hush Lake at dusk, a slow low orbit over the ice toward the Eye (the camera never repeats: it breathes back and forth on slow sines). Frost grows in from the screen edges like breath on a window; the title "HUSH LAKE" forms out of the frost (crystals reach in, the letters crystallise from the middle), an amber line draws under "Feed the Eye", a faint hum rises from under the ice (the Eye pulses with it). Quiet text buttons fade in under it: Play / Continue, Settings, Controls, Quit. The HUD is hidden.
2. **Play (new game)**: the title cracks to black and the sled run starts (about 40 s, skippable after 1 s):
   - aerial chase of Olga's dog-sled team crossing the lake toward the Eye at dusk (snow plumes, bells, runner hiss, lantern swinging) with the narration;
   - low side track beside the dogs at speed;
   - first person from the sled basket: the team's backs, the Eye glow growing ahead; Olga calls the dogs down; the sled slides to a stop;
   - you turn: close on Olga ("Forty winters I've watched it. It never once looked back."), she hands you a rod ("Take this. Feed it, and it pays.");
   - you step off the sled and walk onto the ice while the sled pulls away; a dolly-zoom on the Eye as ONE LID opens under the ice (hum swell, shiver, aqua pulse, the Eye stays slightly ajar from now on);
   - the letterbox lifts, the HUD fades in, the camera lands on exactly the player's start view: no loading cut.
3. **Continue (a save)**: a "previously" beat (about 9 s): fade up from black over the Eye, a slow crane down and across the camp to where you stand, four cards: "Previously, on Hush Lake...", what you fed and cleared, what the Eye does now, Olga's next step. Skippable.
4. **Camera director** (`camera_director.gd`): poses (position, look-at, fov, roll, handheld shake), smooth blends and dissolves, used by the title orbit, the sled run and the previously beat. Letterbox bars, captions and the skip hint are the guide's existing machinery.

## Style rules
Dusk palette (teal, slate, amber), no violet. Sound before picture: the hum starts first. Everything skippable, nothing blocks input after the hand-off. No new state survives except "the Eye is slightly ajar".

## Evidence
`tools/run_opening.sh` (director maths, title build and signals, sled run timeline headless, skip at every beat restores camera/HUD/player, previously text from a save), screenshots (`SHOT_ONLY=opening`), perf, review.
