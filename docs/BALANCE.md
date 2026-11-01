# Balance

Run `tools/run_econ.sh` (headless, takes a few seconds). It plays the real rules (stock, prices, multipliers) with a simulated
clock and a rational player: fishes by hand, buys whatever pays back fastest, builds auto-rods + belts + rigs + canneries, and works one sector at a time.
`ECON_ACTIVE=0.5` models a player who is only fishing half the time; `ECON_SEED` changes the lake.

## What the first run showed
With the old numbers an optimal player emptied the whole lake in **10.5 minutes**. Coins stopped mattering after ~5 minutes, and automation
(22 auto-rods, 3 rigs) outran the finite stock. The economy was fish-limited, not coin-limited.

## What changed (numbers live in `ice_fishing.gd` / `lake_model.gd`)
| Knob | Before | After |
|---|---|---|
| Fish per patch (`COUNT_SCALE`) | x1 (1.8k fish) | x4.5 (about 8k fish) |
| Eye stages (fish fed) | 10 / 60 / 200 / 600 / 1500 | 40 / 240 / 800 / 3000 / 6400 |
| Auto-rod wait | 6-9 s | 16-22 s |
| Auto-rod price | 35 x 1.35^n | 60 x 1.55^n (plus belt) |
| Rig interval / price | 2.4 s / 600 x 2^n | 7 s / 900 x 2.4^n |
| Cannery / sorter price growth | 1.6 | 1.9 |
| Cannery multiplier | x1.8 | x1.5 |
| Lure Polish | +15% per level | +10% |
| Belt Motor value | +25% per level | +15% |
| Sector value perk | +3% per sector | +2% |
| Sector rewards | 60 / 180 / 420 | 200 / 700 / 1800 |
| Refreeze needs | 3 sectors | 6 sectors |

## Result for the optimal player (first lake)
| Milestone | Active 100% | Active 50% |
|---|---|---|
| Eye stage 1 / 2 / 3 | 2 / 7.5 / 13 min | 4 / 14 / 22 min |
| First sector cleared | 6.5 min | 14 min |
| Refreeze unlocked (6 sectors) | 23 min | 32 min |
| Eye stage 4 / 5 | 29 / 46 min | 39 / 58 min |
| Lake emptied | 53 min | 66 min |

A real player will be slower than the sim (placing machines, walking, hesitating), so expect roughly 1.3-1.6x these times.

## Known gaps
- **Late-game coin glut**: after ~35 min coins pile up (100k at the end) because rigs are capped at 3 and autos get very expensive. Needs late sinks: rig/depot upgrades, a second tier of machines.
- The sim ignores goal rewards and unlocks (it assumes all upgrades are available), snowmobile/sorter/depot/wide drill/sonar, and real walking.
- Dead stretch: the longest wait between purchases is about 5-6 minutes near the end.
- Offline income uses the same constants but has not been re-tuned.

## Late game update
Added tithes (endless value sink), Eye-stage rig slots (up to 7), goal rewards, an awakening bonus and lake-to-lake scaling. Fish per patch is now x6 and Eye stages are 50 / 300 / 1050 / 4000 / 8500 (scaled up 30% per finished lake).

| Lake | Eye stage 5 | Lake emptied (always active) |
|---|---|---|
| 1st | 52 min | 61 min |
| 2nd (1 finished) | 62 min | 74 min |
| 4th (3 finished) | 81 min | 98 min |

Half-active play on the first lake: about 76 minutes. Run `ECON_LAKES=3 tools/run_econ.sh` to see a later lake.
Still true: a few tens of thousands of unspent coins at the very end of a lake. A second machine tier would absorb them.
