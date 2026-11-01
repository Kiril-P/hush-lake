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
- Top-left card: coin chip, bucket bar, Eye stage bar, lake facts. Top-right: goals. Bottom: tool cards (amber ring = active, dim = locked). Messages sit above the tool cards, not over the cards.
- Crosshair is a small cream ring. Title card (`HUSH LAKE`) shows whenever the mouse is free.
- Font: system rounded sans (Avenir Next Rounded, falling back to Trebuchet/Verdana). No font files bundled yet.

## Still to do
Minimap and 3D plaques still use the old colors and fonts. Machines (cannery, sorter, depot, rig) need a consistent trim color. Add icons for tools.
