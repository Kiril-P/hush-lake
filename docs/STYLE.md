# Hush Lake style guide

One rule: **cold teal/blue world, one warm amber for anything lit, owned, or interactive.**
All UI colors and widgets live in `shared/style.gd` (`Style`); do not hardcode UI colors in game scripts.

## Palette
| Role | Color | Use |
|---|---|---|
| INK / INK_SOFT | deep indigo | panels, slots |
| CREAM | warm white | primary text |
| MUTED | dusty periwinkle | secondary text |
| AMBER | (1.0, 0.78, 0.35) | coins, selected tool, goals header, lanterns, Eye's thin ring |
| AQUA / TEAL | (0.45, 0.95, 0.9) / (0.08, 0.52, 0.66) | the Eye, Eye progress, fish flowing to it |
| ROSE | soft red | warnings only |

## World
- Sky: deep blue top into a peach horizon (no violet). Fog is blue-grey, not lilac.
- Ice: cool blue, low specular so the sky does not wash it pink. Pale at the shore, deeper in the middle.
- Eye: pale aqua rim, thin amber ring, two teal bands, black pupil. Brightness (not hue) tracks progress.
- Mountains/trees: blue-slate and teal-green. Wood and lit windows are the warm notes.

## HUD
- Top-left card: coin chip, bucket bar, Eye stage bar, lake facts. Top-right: goals. Bottom middle: three slots (amber ring = the one in your hand, its name above it). Messages sit above the slots, not over them. The tool rack by Olga's hut is a pale board so dark steel and amber tools read against it.
- Crosshair is a small cream ring. Title card (`HUSH LAKE`) shows whenever the mouse is free.
- Font: system rounded sans (Avenir Next Rounded, falling back to Trebuchet/Verdana). No font files bundled yet.

## Assets (code-built, one design language)
- **Machines** (`machine_models.gd`): blued steel body, teal trim, wood only where a person touches it, a snow cap on every flat top, amber lamps as the only warm note. Auto-Rod = derrick with a pumping beam and a stash crate; Smoker = smokehouse with a chimney (smokes while working); Gut Table = trestle table with a lamp; Belt = steel trough with teal rails and chevrons marching toward the Eye (shader); Cannery = brick works with a steaming stack; Sorter = gantry with a sweeping scanner; Depot = snow-roofed shed with a sled; Ice-Breaker = hull with a lit bridge, crane and a spinning amber beacon.
- **Tools in hand** (`tool_models.gd`): auger with real flights, rod with cork grip, reel, guides and a lit tip bead, builder kit; knitted amber mittens with teal cuffs on every tool; a leather boot swings in for kicks.
- **People:** Olga (`npc_models.gd`): teal parka, amber scarf, rose knitted hat; she breathes, turns her head to follow you and waves when you are near.
- **Ice** (shader in `scenery.gd`): colour from the lake model plus soft mottling, drifting frost, fine cracks and glints that twinkle near you. Holes have a pale lip and rippling dark water.
- **HUD widgets** (`hud_widgets.gd`): reactive crosshair (cream / amber when you can act / aqua on the Eye and kickable fish, with a progress ring), drawn tool icons, round minimap with a compass tick and fish specks, field journal table, themed sliders and buttons. A soft cold vignette frames the view.
- Juice: snow puffs on landings, kicks, fast slides and footsteps; walking head-bob.
- **Fish:** every species has ray-shaded fins (base darker, tip lighter, alternating rays) and a belly fin; belt and rig fish are real little fish (`FishModel.bead_mesh`, instanced, tinted per species, they wriggle as they ride).
- **Trees:** snow-laden pines (every tier carries a paler snow cone), a few dead trees with bare branches.
- **Audio** (`shared/sfx.gd`): all sounds are loudness-normalised per role (`PEAK` table: UI ticks < actions < impacts < stingers), a limiter on the master bus, ambience breathes (wind level drifts, occasional ice creaks and gusts), new kick / thud / footstep / slide sounds. `tools/run_audio.sh` checks levels, clipping, loop clicks and the limiter.
- **Motion:** tools swap with a dip, new buildings grow in with overshoot and a snow puff, picked-up fish hop into your hand, a boot swings for kicks, head-bob and footstep snow while walking.
- Judge assets in isolation with `tools/showroom.sh` (renders/room_*.png) and in the world with `tools/shot.sh` (`SHOT_ONLY=tools|machines2|yard|olga|ui|fishing`).

## Still to do
3D plaques and the welcome sign use the old fonts. Audio is procedural and has only been level-checked, never heard. Draw calls are high (4-6k on a busy lake; 7-9 ms per frame on an M-series Mac): merge machine meshes if a weaker GPU struggles.

## Guidance
The amber accent also means 'go here': the NEXT strip border, the world pin and the edge arrow are all amber on ink. Tips use the aqua accent. Nothing guiding the player is ever red or blocks the crosshair.
