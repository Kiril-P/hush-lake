# Art delta list (round 1 -> 2)

Distilled from 20 reference sets (GPT agents, 3 variants each) in `docs/refs/gen/`. Order = how many scenes asked for it.
Status: DONE = in the build and visible in `docs/refs/sheets/r2` (before | reference | after), LATER = parked.

| # | Win (asked by) | What we changed | Status |
|---|---|---|---|
| 1 | Deep teal grade, kill the lavender wash (20/20) | Sky keys retuned to teal tops with thin warm horizon bands; `sky_curve` 0.07; ambient is now a cool colour fill (was sky-sourced, which turned snow pink); ice, bank and terrain colours deeper and bluer; saturation back to 1.0 | DONE |
| 2 | Blue layered distance fog between forest and mountains (19/20) | `fog_density` 0.0016, `fog_aerial_perspective` 0.45, `fog_sky_affect` 0.3 | DONE |
| 3 | Amber lantern pools on ice and snow (17/20) | `camp_dressing.gd`: omni lights at the hut and every camp stall, fade with the hour (day whisper, dusk/night strong) | DONE |
| 4 | Eye reads: black pupil, tight rim, less bloom (15/20) | Basin and floor near-black, funnel walls darker, iris rim less white, glow 0.8 -> 0.6, bloom 0.1 -> 0.06 | DONE |
| 5 | Lived-in props: crates, sacks, sled, barrel, woodpile, snowman, flag (14/20) | `camp_dressing.gd` (all primitives) | DONE |
| 6 | White hex/sector borders too loud (9/20) | Locked-sector frost now cold blue, line alpha .95 -> .8 | DONE |
| 7 | Blizzard should lose the long view (3/3 weather shots) | Fog + gloom already did most; the new fog makes trees dissolve | DONE (verify in play) |
| 8 | Ice facets, thin cracks, softer shard edges | Shader already has cracks; shard softening | LATER |
| 9 | Chimney smoke and low ground fog | Chimney plume exists; ground fog layer | LATER |
| 10 | Snow caps on machines, cyan edge light on belts | | LATER |

Rejected as fantasy: painterly clouds, mirror reflections (no SSR), volumetric god-rays beyond the Eye's shaft, invented sign text.
